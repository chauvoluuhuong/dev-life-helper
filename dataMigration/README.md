# PostgreSQL Data Migration Script

A bash script for migrating all databases from a development environment to a local PostgreSQL environment.

## Project Structure

```
dataMigration/
├── dataMigration.sh          # Main migration script
├── setup-example.sh          # Automated example environment setup
├── demo-migration.sh         # Interactive demo script
├── docker-compose.yml        # Docker services for testing
├── example.env               # Example environment configuration
├── README.md                 # This documentation
├── test-setup-README.md      # Detailed testing documentation
├── dump/                     # Migration backup files (auto-created)
└── mock-data/
    ├── source/               # Sample data for source database
    │   ├── 01-create-sample-databases.sql
    │   ├── 02-populate-ecommerce.sql
    │   ├── 03-populate-blog.sql
    │   └── 04-populate-inventory.sql
    └── target/               # Target database initialization
        └── 01-init.sql
```

## Purpose

Automatically migrates all user databases from a remote PostgreSQL server to your local PostgreSQL instance. The script:

- Discovers all databases automatically
- Excludes system databases (template0, template1, postgres, rdsadmin)
- Creates timestamped backups
- Validates connections before migration
- Provides migration summary and cleanup options

## Usage

### Quick Start (Recommended)

1. **Setup example environment:**

   ```bash
   ./setup-example.sh
   ```

2. **Run migration or demo:**

   ```bash
   # Interactive migration
   ./dataMigration.sh

   # Or automated demo
   ./demo-migration.sh
   ```

### Manual Usage

1. **Make the script executable:**

   ```bash
   chmod +x dataMigration.sh
   ```

2. **Run the script:**

   ```bash
   ./dataMigration.sh
   ```

3. **Follow the interactive prompts:**
   - Enter source database connection details (host, username, password)
   - Enter target database connection details (host, username, password)
   - Review discovered databases and confirm migration

### Environment Configuration

You can use an environment file to pre-configure connection settings:

```bash
# Copy the example environment file
cp example.env .env

# Edit with your database settings
vim .env
```

The environment file supports these variables:

- `SOURCE_DB_HOST`, `SOURCE_DB_PORT`, `SOURCE_DB_USERNAME`, `SOURCE_DB_PASSWORD`
- `TARGET_DB_HOST`, `TARGET_DB_PORT`, `TARGET_DB_USERNAME`, `TARGET_DB_PASSWORD`

**Note**: The script automatically generates timestamps and uses a default backup directory (`./dump`), so these don't need to be configured.

## Prerequisites

- PostgreSQL client tools (`psql`, `pg_dump`, `pg_restore`, `pg_isready`, `createdb`)
- Network access to source PostgreSQL server
- Local PostgreSQL instance running

### Install PostgreSQL Client Tools

**macOS:**

```bash
brew install postgresql
```

**Ubuntu/Debian:**

```bash
sudo apt update && sudo apt install postgresql-client libpq-dev
```

**CentOS/RHEL/Fedora:**

```bash
# CentOS/RHEL
sudo yum install postgresql libpq-devel

# Fedora
sudo dnf install postgresql libpq-devel
```

## Example Environment

### Quick Start with Example Environment

The easiest way to test the migration tool is using our pre-configured example environment with Docker:

```bash
# 1. Setup the example environment (includes source and target databases with sample data)
./setup-example.sh

# 2. Run the migration
./dataMigration.sh

# 3. Or run the interactive demo
./demo-migration.sh
```

This will create:

- **Source Database** (port 5432): Contains sample databases with realistic data
- **Target Database** (port 5433): Empty PostgreSQL instance for migration testing

### Example Environment Features

- **Automated Setup**: One command sets up everything
- **Sample Data**: Three realistic databases (ecommerce, blog, inventory)
- **Interactive Demo**: Step-by-step migration demonstration
- **Verification**: Automated data integrity checking
- **Easy Cleanup**: Remove containers and data when done

### Sample Databases Included

1. **sample_ecommerce**: Users, products, orders with relationships
2. **sample_blog**: Authors, posts, comments with timestamps
3. **sample_inventory**: Locations, items, transactions with stock tracking

### Manual Docker Setup (Alternative)

If you prefer manual setup:

```bash
# Start source PostgreSQL (with sample data)
docker-compose up source-postgres

# Start target PostgreSQL (empty)
docker-compose up target-postgres

# Connection details:
# Source: localhost:5432, user: postgres, password: postgres
# Target: localhost:5433, user: postgres, password: postgres
```

## Testing with External Services

### Free PostgreSQL Services for Testing

**Recommended for remote source database:**

- **Neon**: https://neon.tech/ (500 MB free)
- **Supabase**: https://supabase.com/ (500 MB free)
- **ElephantSQL**: https://www.elephantsql.com/ (20 MB free)

### Custom Test Setup

1. Create test databases on your source server:

   ```sql
   CREATE DATABASE test_db1;
   CREATE DATABASE test_db2;
   ```

2. Add sample data:

   ```sql
   \c test_db1
   CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(100));
   INSERT INTO users (name) VALUES ('Test User 1'), ('Test User 2');
   ```

3. Run the migration script and verify data was transferred to your target PostgreSQL.

## Security Note

- Passwords are entered securely (no echo)
- Environment variables are cleared after use
- Backup files contain sensitive data - secure appropriately
