# PostgreSQL Data Migration Script

A bash script for migrating all databases from a development environment to a local PostgreSQL environment.

## Purpose

Automatically migrates all user databases from a remote PostgreSQL server to your local PostgreSQL instance. The script:

- Discovers all databases automatically
- Excludes system databases (template0, template1, postgres, rdsadmin)
- Creates timestamped backups
- Validates connections before migration
- Provides migration summary and cleanup options

## Usage

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
sudo apt update && sudo apt install postgresql-client
```

## Testing

### Free PostgreSQL Services for Testing

**Recommended for source database:**

- **Neon**: https://neon.tech/ (500 MB free)
- **Supabase**: https://supabase.com/ (500 MB free)
- **ElephantSQL**: https://www.elephantsql.com/ (20 MB free)

### Local PostgreSQL with Docker

**For target database:**

```bash
# Start PostgreSQL locally
docker run --name postgres-test \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=testdb \
  -p 5432:5432 \
  -d postgres:15

# Connection details for script:
# Host: localhost
# Username: postgres
# Password: testpass
```

### Test Setup

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

3. Run the migration script and verify data was transferred to your local PostgreSQL.

## Security Note

- Passwords are entered securely (no echo)
- Environment variables are cleared after use
- Backup files contain sensitive data - secure appropriately
