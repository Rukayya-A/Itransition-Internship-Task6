-- Database Schema for Fake User Generator

CREATE TABLE IF NOT EXISTS locales (
    locale_code VARCHAR(10) PRIMARY KEY,
    locale_name VARCHAR(100) NOT NULL,
    country_code VARCHAR(3) NOT NULL
);

CREATE TABLE IF NOT EXISTS first_names (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    locale_code VARCHAR(10) NOT NULL REFERENCES locales(locale_code),
    gender CHAR(1) CHECK (gender IN ('M', 'F', 'U')),
    frequency INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS last_names (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    locale_code VARCHAR(10) NOT NULL REFERENCES locales(locale_code),
    frequency INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS titles (
    id SERIAL PRIMARY KEY,
    title VARCHAR(20) NOT NULL,
    locale_code VARCHAR(10) NOT NULL REFERENCES locales(locale_code),
    gender CHAR(1) CHECK (gender IN ('M', 'F', 'U')),
    frequency INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS street_names (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    locale_code VARCHAR(10) NOT NULL REFERENCES locales(locale_code)
);

CREATE TABLE IF NOT EXISTS street_types (
    id SERIAL PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL,
    locale_code VARCHAR(10) NOT NULL REFERENCES locales(locale_code),
    position VARCHAR(10) CHECK (position IN ('prefix', 'suffix'))
);

CREATE TABLE IF NOT EXISTS cities (
    id SERIAL PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL,
    locale_code VARCHAR(10) NOT NULL REFERENCES locales(locale_code),
    state_province VARCHAR(100),
    postal_code_pattern VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS eye_colors (
    id SERIAL PRIMARY KEY,
    color_name VARCHAR(50) NOT NULL,
    locale_code VARCHAR(10) NOT NULL REFERENCES locales(locale_code),
    frequency INTEGER DEFAULT 1
);

-- Phone Formats table
CREATE TABLE phone_formats (
    id SERIAL PRIMARY KEY,
    format_pattern TEXT NOT NULL,
    locale_code TEXT NOT NULL,
    frequency INT NOT NULL
);

CREATE TABLE IF NOT EXISTS email_domains (
    id SERIAL PRIMARY KEY,
    domain VARCHAR(100) NOT NULL,
    locale_code VARCHAR(10) NOT NULL REFERENCES locales(locale_code)
);

-- Indexes for performance
CREATE INDEX idx_first_names_locale ON first_names(locale_code);
CREATE INDEX idx_last_names_locale ON last_names(locale_code);
CREATE INDEX idx_titles_locale ON titles(locale_code);
CREATE INDEX idx_street_names_locale ON street_names(locale_code);
CREATE INDEX idx_street_types_locale ON street_types(locale_code);
CREATE INDEX idx_cities_locale ON cities(locale_code);
CREATE INDEX idx_eye_colors_locale ON eye_colors(locale_code);
CREATE INDEX idx_email_domains_locale ON email_domains(locale_code);
CREATE INDEX idx_phone_formats_locale ON phone_formats(locale_code);
