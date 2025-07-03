# PostgreSQL Migration Testing Setup

This Docker Compose setup provides a complete testing environment for the PostgreSQL migration script with two separate PostgreSQL databases and sample data.

## File Structure

```
dataMigration/
├── dataMigration.sh          # Main migration script
├── docker-compose.yml        # Docker services configuration
├── test-setup-README.md      # This file
├── dump/                     # Directory for backup files (auto-created)
└── mock-data/
    ├── source/
    │   ├── 01-create-sample-databases.sql
    │   ├── 02-populate-ecommerce.sql
    │   ├── 03-populate-blog.sql
    │   └── 04-populate-inventory.sql
    └── target/
        └── 01-init.sql
```

## Services Overview

### Source PostgreSQL Database

- **Container**: `source-postgres`
- **Host**: `localhost`
- **Port**: `5432`
- **Username**: `postgres`
- **Password**: `postgres`
- **Sample Databases**: `sample_ecommerce`, `sample_blog`, `sample_inventory`

### Target PostgreSQL Database

- **Container**: `target-postgres`
- **Host**: `localhost`
- **Port**: `5433`
- **Username**: `postgres`
- **Password**: `postgres`
- **Purpose**: Migration destination (initially empty)

## Sample Data

### sample_ecommerce

- **Tables**: users, products, orders
- **Sample Data**: 5 users, 7 products, 5 orders

### sample_blog

- **Tables**: authors, posts, comments
- **Sample Data**: 4 authors, 6 posts, 6 comments

### sample_inventory

- **Tables**: suppliers, items, stock, stock_movements
- **Sample Data**: 3 suppliers, 7 items, stock levels, movement history

## Quick Start

### 1. Start the databases

```bash
cd dataMigration
docker-compose up -d
```

### 2. Wait for services to be ready

```bash
docker-compose ps
```

Both services should show as "healthy".

### 3. Run the migration script

```bash
./dataMigration.sh
```

**When prompted, use these values:**

**Source Database Configuration:**

- Host: `localhost` (press Enter for default)
- Port: `5432` (press Enter for default)
- Username: `postgres` (press Enter for default)
- Password: `postgres` (press Enter for default)

**Target Database Configuration:**

- Host: `localhost` (press Enter for default)
- Port: `5433` (enter `5433`)
- Username: `postgres` (press Enter for default)
- Password: `postgres` (press Enter for default)

### 4. Verify the migration

Connect to the target database to verify the data was migrated:

```bash
# Connect to target database
psql -h localhost -p 5433 -U postgres -d sample_ecommerce

# Example queries
SELECT * FROM users;
SELECT * FROM products;
SELECT * FROM orders;
```

### 5. Clean up

```bash
docker-compose down -v
```

## Manual Testing Commands

### Connect to Source Database

```bash
# Connect to source database
psql -h localhost -p 5432 -U postgres -d sample_ecommerce

# List databases
\l

# Connect to different sample databases
\c sample_blog
\c sample_inventory
```

### Connect to Target Database

```bash
# Connect to target database
psql -h localhost -p 5433 -U postgres -d sample_ecommerce

# Verify migrated data
SELECT count(*) FROM users;
SELECT count(*) FROM products;
SELECT count(*) FROM orders;
```

### Check Database Sizes

```bash
# Check source database sizes
psql -h localhost -p 5432 -U postgres -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size FROM pg_database WHERE datname LIKE 'sample_%';"

# Check target database sizes (after migration)
psql -h localhost -p 5433 -U postgres -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size FROM pg_database WHERE datname LIKE 'sample_%';"
```

## Testing Different Scenarios

### 1. Test with different port configurations

- Start source on port 5434, target on port 5435
- Update docker-compose.yml ports mapping

### 2. Test with different credentials

- Modify environment variables in docker-compose.yml
- Test script with non-default credentials

### 3. Test partial migration

- Temporarily drop one of the sample databases
- Verify script handles missing databases gracefully

### 4. Test network connectivity issues

- Stop one service during migration
- Verify error handling

## Troubleshooting

### Services won't start

```bash
# Check service logs
docker-compose logs source-postgres
docker-compose logs target-postgres

# Check port conflicts
lsof -i :5432
lsof -i :5433
```

### Connection refused errors

```bash
# Verify services are healthy
docker-compose ps

# Test connections manually
pg_isready -h localhost -p 5432 -U postgres
pg_isready -h localhost -p 5433 -U postgres
```

### Migration script fails

```bash
# Check if PostgreSQL client tools are installed
which psql
which pg_dump
which pg_restore

# Install PostgreSQL client tools if needed (macOS)
brew install postgresql
```

### Reset everything

```bash
# Stop and remove all containers and volumes
docker-compose down -v

# Remove any leftover containers
docker container prune

# Start fresh
docker-compose up -d
```

## Advanced Testing

### Performance Testing

```bash
# Time the migration
time ./dataMigration.sh

# Monitor resource usage
docker stats
```

### Data Integrity Verification

```bash
# Compare row counts between source and target
./scripts/verify-migration.sh  # (create this script if needed)
```

### Backup File Analysis

```bash
# Check backup file sizes
ls -lh dump/

# Inspect backup file contents
pg_restore --list dump/sample_ecommerce_*.sql
```

## Notes

- All backup files are preserved in the `dump/` directory
- The script will create target databases if they don't exist
- Existing target databases will be overwritten
- Both databases use the same default credentials for testing simplicity
