-- Core Random Number Generation Functions
-- All randomness is deterministic based on seed + position

-- Generate pseudo-random integer using linear congruential generator
CREATE OR REPLACE FUNCTION prng_int(seed BIGINT, pos INT, min_val INT, max_val INT)
RETURNS INT AS $$
DECLARE
    a BIGINT := 1664525;
    c BIGINT := 1013904223;
    m BIGINT := 4294967296;
    state BIGINT;
BEGIN
    state := (a * (seed + pos) + c) % m;
    RETURN min_val + (state % (max_val - min_val + 1))::INT;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Generate pseudo-random float between 0 and 1
CREATE OR REPLACE FUNCTION prng_float(seed BIGINT, pos INT)
RETURNS FLOAT AS $$
DECLARE
    a BIGINT := 1664525;
    c BIGINT := 1013904223;
    m BIGINT := 4294967296;
    state BIGINT;
BEGIN
    state := (a * (seed + pos) + c) % m;
    RETURN (state::FLOAT / m::FLOAT);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Box-Muller transform for normal distribution
CREATE OR REPLACE FUNCTION prng_normal(seed BIGINT, pos INT, mean FLOAT, stddev FLOAT)
RETURNS FLOAT AS $$
DECLARE
    u1 FLOAT;
    u2 FLOAT;
    z FLOAT;
BEGIN
    u1 := prng_float(seed, pos * 2);
    u2 := prng_float(seed, pos * 2 + 1);
    
    -- Avoid log(0)
    IF u1 < 0.000001 THEN
        u1 := 0.000001;
    END IF;
    
    z := sqrt(-2.0 * ln(u1)) * cos(2.0 * pi() * u2);
    RETURN mean + z * stddev;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Uniform distribution on sphere (lat/lon)
CREATE OR REPLACE FUNCTION prng_sphere_coords(seed BIGINT, pos INT)
RETURNS TABLE(latitude FLOAT, longitude FLOAT) AS $$
DECLARE
    u FLOAT;
    v FLOAT;
    lat FLOAT;
    lon FLOAT;
BEGIN
    u := prng_float(seed, pos * 2);
    v := prng_float(seed, pos * 2 + 1);
    
    -- Uniform on sphere: latitude uses arcsin of uniform distribution
    lat := degrees(asin(2.0 * u - 1.0));
    lon := 360.0 * v - 180.0;
    
    RETURN QUERY SELECT lat, lon;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Weighted selection from lookup table
CREATE OR REPLACE FUNCTION select_weighted_item(
    seed BIGINT,
    pos INT,
    table_name TEXT,
    locale VARCHAR(10),
    gender_filter CHAR(1) DEFAULT NULL
)
RETURNS INT AS $$
DECLARE
    total_weight INT;
    random_val INT;
    selected_id INT;
    query TEXT;
BEGIN
    -- Build dynamic query based on table
    IF table_name = 'first_names' AND gender_filter IS NOT NULL THEN
        query := format('SELECT SUM(frequency) FROM %I WHERE locale_code = %L AND (gender = %L OR gender = ''U'')',
                       table_name, locale, gender_filter);
    ELSE
        query := format('SELECT SUM(frequency) FROM %I WHERE locale_code = %L',
                       table_name, locale);
    END IF;
    
    EXECUTE query INTO total_weight;
    random_val := prng_int(seed, pos, 0, total_weight - 1);
    
    -- Select item based on weighted random
    IF table_name = 'first_names' AND gender_filter IS NOT NULL THEN
        query := format('
            WITH weighted AS (
                SELECT id, 
                       SUM(frequency) OVER (ORDER BY id) - frequency AS range_start,
                       SUM(frequency) OVER (ORDER BY id) AS range_end
                FROM %I 
                WHERE locale_code = %L AND (gender = %L OR gender = ''U'')
            )
            SELECT id FROM weighted WHERE %L >= range_start AND %L < range_end LIMIT 1',
            table_name, locale, gender_filter, random_val, random_val);
    ELSE
        query := format('
            WITH weighted AS (
                SELECT id, 
                       SUM(frequency) OVER (ORDER BY id) - frequency AS range_start,
                       SUM(frequency) OVER (ORDER BY id) AS range_end
                FROM %I 
                WHERE locale_code = %L
            )
            SELECT id FROM weighted WHERE %L >= range_start AND %L < range_end LIMIT 1',
            table_name, locale, random_val, random_val);
    END IF;
    
    EXECUTE query INTO selected_id;
    RETURN selected_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- Generate full name
CREATE OR REPLACE FUNCTION generate_name(
    seed INT,
    user_index INT,
    locale TEXT
) RETURNS TEXT AS $$
DECLARE
    first_name_text TEXT;
    middle_name_text TEXT;
    last_name_text TEXT;
    title_text TEXT;
    full_name TEXT;
    selected_gender TEXT;
BEGIN
    -- Pick gender
    selected_gender := CASE WHEN prng_int(seed, user_index * 100, 0, 1) = 0 THEN 'M' ELSE 'F' END;

    -- First name
    SELECT name INTO first_name_text
    FROM first_names
    WHERE id = select_weighted_item(seed, user_index * 100 + 1, 'first_names', locale, selected_gender);

    -- Last name
    SELECT name INTO last_name_text
    FROM last_names
    WHERE id = select_weighted_item(seed, user_index * 100 + 2, 'last_names', locale);

    full_name := first_name_text || ' ' || last_name_text;

    -- Middle full name (20% chance)
    IF prng_int(seed, user_index * 100 + 3, 0, 99) < 20 THEN
        SELECT name INTO middle_name_text
        FROM first_names
        WHERE id = select_weighted_item(seed, user_index * 100 + 4, 'first_names', locale, selected_gender);
        full_name := first_name_text || ' ' || middle_name_text || ' ' || last_name_text;
    END IF;

    -- Title (15% chance)
    IF prng_int(seed, user_index * 100 + 5, 0, 99) < 15 THEN
        SELECT title INTO title_text
        FROM titles
        WHERE id = select_weighted_item(seed, user_index * 100 + 6, 'titles', locale, selected_gender);
        full_name := title_text || ' ' || full_name;
    END IF;

    -- Suffix (10% chance)
    IF prng_int(seed, user_index * 100 + 7, 0, 99) < 10 THEN
        CASE prng_int(seed, user_index * 100 + 8, 0, 2)
            WHEN 0 THEN full_name := full_name || ' Jr.';
            WHEN 1 THEN full_name := full_name || ' Sr.';
            ELSE full_name := full_name || ' III';
        END CASE;
    END IF;

    -- Locale-specific ordering (Germany: sometimes Last, First)
    IF locale = 'de_DE' AND prng_int(seed, user_index * 100 + 9, 0, 1) = 1 THEN
        full_name := last_name_text || ', ' || first_name_text;
    END IF;

    RETURN full_name;
END;
$$ LANGUAGE plpgsql;

-- Generate address
CREATE OR REPLACE FUNCTION generate_address(
    seed INT,
    user_index INT,
    locale TEXT
) RETURNS TEXT AS $$
DECLARE
    street_name_text TEXT;
    street_type_text TEXT;
    city_text TEXT;
    postal_text TEXT;
    address_line TEXT;
BEGIN
    -- Weighted street name/type
    SELECT name INTO street_name_text
    FROM street_names
    WHERE id = select_weighted_item(seed, user_index * 200 + 1, 'street_names', locale);

    SELECT type_name INTO street_type_text
    FROM street_types
    WHERE id = select_weighted_item(seed, user_index * 200 + 2, 'street_types', locale);

    -- Street number
    address_line := prng_int(seed, user_index * 200 + 3, 1, 9999)::TEXT;

    -- Locale-specific ordering
    IF locale = 'de_DE' THEN
        address_line := street_name_text || ' ' || street_type_text || ' ' || address_line;
    ELSE
        address_line := address_line || ' ' || street_name_text || ' ' || street_type_text;
    END IF;

    -- Apartment/Suite/Wohnung (30% chance)
    IF prng_int(seed, user_index * 200 + 4, 0, 99) < 30 THEN
        CASE locale
            WHEN 'de_DE' THEN
                address_line := address_line || ', Wohnung ' || prng_int(seed, user_index * 200 + 5, 1, 200)::TEXT;
            ELSE
                address_line := address_line || ', Apt ' || prng_int(seed, user_index * 200 + 5, 1, 200)::TEXT;
        END CASE;
    END IF;

    -- Building/Block (20% chance)
    IF prng_int(seed, user_index * 200 + 6, 0, 99) < 20 THEN
        address_line := address_line || ', Building ' || prng_int(seed, user_index * 200 + 7, 1, 50)::TEXT;
    END IF;

    -- City
    SELECT name INTO city_text
    FROM cities
    WHERE id = select_weighted_item(seed, user_index * 200 + 8, 'cities', locale);

    -- Postal code
    SELECT pattern INTO postal_text
    FROM postal_codes
    WHERE id = select_weighted_item(seed, user_index * 200 + 9, 'postal_codes', locale);

    postal_text := regexp_replace(postal_text, 'N', prng_int(seed, user_index * 200 + 10, 0, 9)::TEXT, 'g');

    -- US ZIP+4 variation
    IF locale = 'en_US' AND prng_int(seed, user_index * 200 + 11, 0, 99) < 15 THEN
        postal_text := postal_text || '-' || lpad(prng_int(seed, user_index * 200 + 12, 0, 9999)::TEXT, 4, '0');
    END IF;

    RETURN address_line || ', ' || city_text || ', ' || postal_text;
END;
$$ LANGUAGE plpgsql;

-- Generate phone number
CREATE OR REPLACE FUNCTION generate_phone(
    seed INT,
    user_index INT,
    locale TEXT
) RETURNS TEXT AS $$
DECLARE
    format_text TEXT;
    phone_number TEXT;
BEGIN
    -- Weighted format selection
    SELECT format_pattern INTO format_text
    FROM phone_formats
    WHERE id = select_weighted_item(seed, user_index * 300, 'phone_formats', locale);

    -- Replace placeholders
    phone_number := format_text;
    phone_number := regexp_replace(phone_number, 'N', prng_int(seed, user_index * 300 + 1, 0, 9)::TEXT, 'g');

    -- Optional country code (20% chance)
    IF prng_int(seed, user_index * 300 + 2, 0, 99) < 20 THEN
        CASE locale
            WHEN 'de_DE' THEN phone_number := '+49 ' || phone_number;
            ELSE phone_number := '+1 ' || phone_number;
        END CASE;
    END IF;

    -- Optional extension (10% chance)
    IF prng_int(seed, user_index * 300 + 3, 0, 99) < 10 THEN
        phone_number := phone_number || ' x' || prng_int(seed, user_index * 300 + 4, 100, 9999)::TEXT;
    END IF;

    RETURN phone_number;
END;
$$ LANGUAGE plpgsql;

-- Generate email
CREATE OR REPLACE FUNCTION generate_email(
    seed BIGINT,
    user_index INT,
    locale VARCHAR(10),
    first_name TEXT,
    last_name TEXT
)
RETURNS TEXT AS $$
DECLARE
    domain_text TEXT;
    username TEXT;
    format_variant INT;
    domain_id INT;
    random_num INT;
BEGIN
    -- Select domain
    domain_id := prng_int(seed, user_index * 400, 1, (SELECT COUNT(*) FROM email_domains WHERE locale_code = locale)::INT);
    SELECT domain INTO domain_text FROM email_domains WHERE locale_code = locale OFFSET domain_id - 1 LIMIT 1;
    
    format_variant := prng_int(seed, user_index * 400 + 1, 0, 5);
    random_num := prng_int(seed, user_index * 400 + 2, 10, 9999);
    
    -- Generate username variations
    CASE format_variant
        WHEN 0 THEN username := lower(first_name) || '.' || lower(last_name);
        WHEN 1 THEN username := lower(first_name) || lower(last_name);
        WHEN 2 THEN username := lower(substring(first_name from 1 for 1)) || lower(last_name);
        WHEN 3 THEN username := lower(first_name) || random_num::TEXT;
        WHEN 4 THEN username := lower(last_name) || random_num::TEXT;
        ELSE username := lower(first_name) || '_' || lower(last_name);
    END CASE;
    
    -- Remove spaces and special characters
    username := regexp_replace(username, '[^a-z0-9._-]', '', 'g');
    
    RETURN username || '@' || domain_text;
END;
$$ LANGUAGE plpgsql STABLE;

-- Generate physical attributes
CREATE OR REPLACE FUNCTION generate_physical_attributes(
    seed BIGINT,
    user_index INT,
    locale VARCHAR(10),
    gender CHAR(1)
)
RETURNS TABLE(
    height_cm INT,
    weight_kg INT,
    eye_color TEXT
) AS $$
DECLARE
    height FLOAT;
    weight FLOAT;
    eye_id INT;
    eye_text TEXT;
BEGIN
    -- Height: normal distribution, different by gender
    IF gender = 'M' THEN
        height := prng_normal(seed, user_index * 500, 175.0, 7.0);  -- Mean 175cm, stddev 7cm
    ELSE
        height := prng_normal(seed, user_index * 500, 162.0, 6.5);  -- Mean 162cm, stddev 6.5cm
    END IF;
    
    -- Weight: normal distribution based on height (BMI approach)
    -- BMI normal range 18.5-25, using 22 as mean
    weight := prng_normal(seed, user_index * 500 + 1, 22.0, 3.0) * (height / 100.0) * (height / 100.0);
    
    -- Clamp values to reasonable ranges
    height := GREATEST(150, LEAST(210, height));
    weight := GREATEST(45, LEAST(150, weight));
    
    -- Select eye color
    eye_id := select_weighted_item(seed, user_index * 500 + 2, 'eye_colors', locale);
    SELECT color_name INTO eye_text FROM eye_colors WHERE id = eye_id;
    
    RETURN QUERY SELECT height::INT, weight::INT, eye_text;
END;
$$ LANGUAGE plpgsql STABLE;

-- Main procedure: Generate batch of fake users
CREATE OR REPLACE FUNCTION generate_fake_users(
    p_locale VARCHAR(10),
    p_seed BIGINT,
    p_batch_index INT,
    p_batch_size INT DEFAULT 10
)
RETURNS TABLE(
    batch_position INT,
    full_name TEXT,
    address TEXT,
    latitude FLOAT,
    longitude FLOAT,
    height_cm INT,
    weight_kg INT,
    eye_color TEXT,
    phone_number TEXT,
    email TEXT
) AS $$
DECLARE
    i INT;
    global_index INT;
    name_rec RECORD;
    phys_rec RECORD;
    coords_rec RECORD;
BEGIN
    FOR i IN 0..p_batch_size - 1 LOOP
        global_index := p_batch_index * p_batch_size + i;
        
        -- Generate name and get gender
        SELECT * INTO name_rec FROM generate_name(p_seed, global_index, p_locale);
        
        -- Generate coordinates
        SELECT * INTO coords_rec FROM prng_sphere_coords(p_seed, global_index * 600);
        
        -- Generate physical attributes
        SELECT * INTO phys_rec FROM generate_physical_attributes(p_seed, global_index, p_locale, name_rec.gender);
        
        RETURN QUERY SELECT
            i,
            name_rec.full_name,
            generate_address(p_seed, global_index, p_locale),
            coords_rec.latitude,
            coords_rec.longitude,
            phys_rec.height_cm,
            phys_rec.weight_kg,
            phys_rec.eye_color,
            generate_phone(p_seed, global_index, p_locale),
            generate_email(p_seed, global_index, p_locale, 
                split_part(regexp_replace(name_rec.full_name, '^(Mr\.|Ms\.|Mrs\.|Dr\.|Prof\.|Herr|Frau|Prof\. Dr\.)\s+', ''), ' ', 1),
                split_part(regexp_replace(name_rec.full_name, '^(Mr\.|Ms\.|Mrs\.|Dr\.|Prof\.|Herr|Frau|Prof\. Dr\.)\s+', ''), ' ', -1)
            );
    END LOOP;
END;

$$ LANGUAGE plpgsql STABLE;
