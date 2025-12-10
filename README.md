# Fake User Generator

A web application that generates deterministic fake user data using PostgreSQL stored procedures. All data generation logic is implemented in SQL, with Python/Flask handling the web interface.

## Features

- **Deterministic Generation**: Same seed always produces identical data
- **Multi-locale Support**: Currently supports en_US and de_DE
- **Comprehensive Data**: Names, addresses, coordinates, physical attributes, phone numbers, emails
- **Normal Distribution**: Height and weight use realistic statistical distributions
- **Uniform Sphere Distribution**: Geographic coordinates properly distributed on Earth's surface
- **Extensible Design**: Easy to add new locales and data types
- **Batch Processing**: Generate users in configurable batches

## Architecture

- **Database**: PostgreSQL stores all lookup tables and generation logic
- **Backend**: Python Flask reads from stored procedures
- **Frontend**: HTML/CSS/JavaScript for user interaction
- **All generation logic**: Implemented as SQL stored procedures

## Prerequisites

- Python 3.8+
- PostgreSQL 12+
- pip (Python package manager)

## Local Setup

### 1. Clone or Download Project Files

Create project directory structure:

```bash
mkdir fake-user-generator
cd fake-user-generator
mkdir database templates
```

Place files:
- `app.py` in root directory
- `requirements.txt` in root directory
- `database/schema.sql` in database folder
- `database/seed_data.sql` in database folder
- `database/procedures.sql` in database folder
- `templates/index.html` in templates folder

### 2. Install PostgreSQL

**macOS** (using Homebrew):
```bash
brew install postgresql@14
brew services start postgresql@14
```

**Ubuntu/Debian**:
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
```

**Windows**:
Download installer from https://www.postgresql.org/download/windows/

### 3. Create Database

```bash
# Access PostgreSQL
psql postgres

# In psql shell:
CREATE DATABASE fake_users_db;
\c fake_users_db
\q
```

### 4. Load Database Schema and Data

```bash
# Load schema
psql -d fake_users_db -f database/schema.sql

# Load seed data
psql -d fake_users_db -f database/seed_data.sql

# Load stored procedures
psql -d fake_users_db -f database/procedures.sql
```

### 5. Install Python Dependencies

```bash
# Create virtual environment (recommended)
python -m venv venv

# Activate virtual environment
# On macOS/Linux:
source venv/bin/activate
# On Windows:
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 6. Configure Database Connection

Create `.env` file in project root (optional - defaults work for local PostgreSQL):

```env
DB_NAME=fake_users_db
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=localhost
DB_PORT=5432
```

### 7. Run Application

```bash
python app.py
```

Access at: http://localhost:5000

## Usage

1. **Select Locale**: Choose between English (USA) or German (Germany)
2. **Set Seed**: Enter any integer (0 to 2,147,483,647)
3. **Set Batch Size**: Choose how many users to generate (1-100)
4. **Generate**: Click "Generate Users"
5. **Next Batch**: Get the next set of users with same parameters
6. **Reset**: Return to batch 0

## Deterministic Behavior

The system guarantees reproducibility:
- Same seed + same batch index = identical users
- User at position 0 in batch 5 (seed 100) = User at position 50 in batch 0 (seed 100)
- Global index formula: `batch_index * batch_size + position_in_batch`

## Testing Reproducibility

```bash
# Test in PostgreSQL directly
psql -d fake_users_db

# Generate same users multiple times
SELECT * FROM generate_fake_users('en_US', 12345, 0, 5);
SELECT * FROM generate_fake_users('en_US', 12345, 0, 5);
# Results should be identical

# Different batch, same seed
SELECT * FROM generate_fake_users('en_US', 12345, 1, 5);
# Users at positions 5-9

# Different seed
SELECT * FROM generate_fake_users('en_US', 99999, 0, 5);
# Completely different users
```

## Database Schema Overview

### Lookup Tables
- `locales`: Supported regions
- `first_names`: First names by locale and gender
- `last_names`: Surnames by locale
- `titles`: Name titles (Mr., Dr., etc.)
- `street_names`: Street names by locale
- `street_types`: Street type suffixes
- `cities`: Cities with postal code patterns
- `eye_colors`: Eye color options
- `email_domains`: Email domain names

### Key Stored Procedures

- `prng_int()`: Generate deterministic random integers
- `prng_float()`: Generate deterministic random floats
- `prng_normal()`: Normal distribution using Box-Muller transform
- `prng_sphere_coords()`: Uniform distribution on sphere
- `select_weighted_item()`: Weighted random selection from tables
- `generate_name()`: Create full name with variations
- `generate_address()`: Create formatted address
- `generate_phone()`: Create phone number with format variations
- `generate_email()`: Create email from name
- `generate_physical_attributes()`: Height, weight, eye color
- `generate_fake_users()`: Main procedure orchestrating all generation

## Extending the System

### Adding a New Locale

1. Add locale to `locales` table:
```sql
INSERT INTO locales (locale_code, locale_name, country_code) 
VALUES ('fr_FR', 'French (France)', 'FRA');
```

2. Populate lookup tables with locale-specific data:
```sql
INSERT INTO first_names (name, locale_code, gender, frequency) VALUES
('Jean', 'fr_FR', 'M', 10),
('Marie', 'fr_FR', 'F', 10);
-- Add 100+ more names
```

3. Add cities, street names, email domains, etc.

### Adding New Attributes

1. Create new lookup table if needed
2. Add generation function
3. Modify `generate_fake_users()` to call new function
4. Update frontend to display new attribute

## Deployment Options

### Option 1: Heroku

```bash
# Install Heroku CLI
# Login
heroku login

# Create app
heroku create your-app-name

# Add PostgreSQL addon
heroku addons:create heroku-postgresql:mini

# Deploy
git init
git add .
git commit -m "Initial commit"
git push heroku main

# Load database
heroku pg:psql < database/schema.sql
heroku pg:psql < database/seed_data.sql
heroku pg:psql < database/procedures.sql
```

Add `Procfile`:
```
web: gunicorn app:app
```

### Option 2: DigitalOcean App Platform

1. Push code to GitHub
2. Create new App in DigitalOcean
3. Connect GitHub repository
4. Add PostgreSQL database
5. Set environment variables
6. Deploy

### Option 3: AWS EC2 + RDS

1. Launch EC2 instance (Ubuntu)
2. Create RDS PostgreSQL instance
3. SSH to EC2 and clone repository
4. Install dependencies
5. Run with Gunicorn + Nginx

### Option 4: Docker

Create `Dockerfile`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:app"]
```

Create `docker-compose.yml`:
```yaml
version: '3.8'
services:
  db:
    image: postgres:14
    environment:
      POSTGRES_DB: fake_users_db
      POSTGRES_PASSWORD: postgres
    volumes:
      - ./database:/docker-entrypoint-initdb.d
  web:
    build: .
    ports:
      - "5000:5000"
    environment:
      DB_HOST: db
    depends_on:
      - db
```

Run:
```bash
docker-compose up
```

## API Reference

### POST /api/generate

Generate batch of fake users.

**Request Body**:
```json
{
  "locale": "en_US",
  "seed": 12345,
  "batch_index": 0,
  "batch_size": 10
}
```

**Response**:
```json
{
  "users": [
    {
      "batch_position": 0,
      "full_name": "John Smith",
      "address": "123 Main Street, New York, NY 10001",
      "latitude": 40.712776,
      "longitude": -74.005974,
      "height_cm": 175,
      "weight_kg": 72,
      "eye_color": "Brown",
      "phone_number": "(555) 123-4567",
      "email": "john.smith@gmail.com"
    }
  ],
  "locale": "en_US",
  "seed": 12345,
  "batch_index": 0,
  "batch_size": 10,
  "timestamp": "2024-01-01T12:00:00"
}
```

### GET /health

Health check endpoint.

**Response**:
```json
{
  "status": "healthy",
  "database": "connected"
}
```

## Performance

- Generates 10 users: ~50ms
- Generates 100 users: ~400ms
- Database size with seed data: ~5MB
- Can support generating 1M+ unique users with current lookup tables

## License

MIT License - feel free to use for any purpose.

## Support

For issues or questions:
1. Check PostgreSQL logs: `tail -f /var/log/postgresql/postgresql-14-main.log`
2. Check Flask logs in terminal
3. Verify database connection with health endpoint
4. Test stored procedures directly in psql