#!/bin/bash

# PostgreSQL Migration Script: Source to Target (All Databases)
# This script migrates all databases from source PostgreSQL to target PostgreSQL

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default connection parameters
DEFAULT_HOST="localhost"
DEFAULT_PORT="5432"
DEFAULT_USERNAME="postgres"
DEFAULT_PASSWORD="postgres"

# Backup configuration
BACKUP_DIR="./dump"
DATE=$(date +"%Y%m%d_%H%M%S")

# Databases to exclude from migration (system databases)
EXCLUDE_DBS=("template0" "template1" "postgres" "rdsadmin")

echo -e "${BLUE}=== PostgreSQL Migration: All Databases (Source to Target) ===${NC}"
echo ""

# Prompt for database connection parameters
echo -e "${YELLOW}=== Database Connection Configuration ===${NC}"
echo ""

# Source Database Environment
echo -e "${YELLOW}Source Database Configuration:${NC}"
echo -n "Enter source database host (default: $DEFAULT_HOST): "
read SOURCE_HOST
if [ -z "$SOURCE_HOST" ]; then
    SOURCE_HOST="$DEFAULT_HOST"
fi
echo -n "Enter source database port (default: $DEFAULT_PORT): "
read SOURCE_PORT
if [ -z "$SOURCE_PORT" ]; then
    SOURCE_PORT="$DEFAULT_PORT"
fi
echo -n "Enter source database username (default: $DEFAULT_USERNAME): "
read SOURCE_USERNAME
if [ -z "$SOURCE_USERNAME" ]; then
    SOURCE_USERNAME="$DEFAULT_USERNAME"
fi
echo -n "Enter source database password (default: $DEFAULT_PASSWORD): "
read -s SOURCE_PASSWORD
if [ -z "$SOURCE_PASSWORD" ]; then
    SOURCE_PASSWORD="$DEFAULT_PASSWORD"
fi
echo ""

# Target Database Environment
echo ""
echo -e "${YELLOW}Target Database Configuration:${NC}"
echo -n "Enter target database host (default: $DEFAULT_HOST): "
read TARGET_HOST
if [ -z "$TARGET_HOST" ]; then
    TARGET_HOST="$DEFAULT_HOST"
fi
echo -n "Enter target database port (default: $DEFAULT_PORT): "
read TARGET_PORT
if [ -z "$TARGET_PORT" ]; then
    TARGET_PORT="$DEFAULT_PORT"
fi
echo -n "Enter target database username (default: $DEFAULT_USERNAME): "
read TARGET_USERNAME
if [ -z "$TARGET_USERNAME" ]; then
    TARGET_USERNAME="$DEFAULT_USERNAME"
fi
echo -n "Enter target database password (default: $DEFAULT_PASSWORD): "
read -s TARGET_PASSWORD
if [ -z "$TARGET_PASSWORD" ]; then
    TARGET_PASSWORD="$DEFAULT_PASSWORD"
fi
echo ""

echo ""
echo -e "${BLUE}Configuration Summary:${NC}"
echo "Source: $SOURCE_HOST:$SOURCE_PORT (user: $SOURCE_USERNAME)"
echo "Target: $TARGET_HOST:$TARGET_PORT (user: $TARGET_USERNAME)"
echo ""

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Validate required parameters
if [ -z "$SOURCE_HOST" ]; then
    echo -e "${RED}Error: Source database host cannot be empty${NC}"
    exit 1
fi

if [ -z "$SOURCE_USERNAME" ]; then
    echo -e "${RED}Error: Source database username cannot be empty${NC}"
    exit 1
fi

if [ -z "$SOURCE_PASSWORD" ]; then
    echo -e "${RED}Error: Source database password cannot be empty${NC}"
    exit 1
fi

if [ -z "$TARGET_HOST" ]; then
    echo -e "${RED}Error: Target database host cannot be empty${NC}"
    exit 1
fi

if [ -z "$TARGET_USERNAME" ]; then
    echo -e "${RED}Error: Target database username cannot be empty${NC}"
    exit 1
fi

if [ -z "$TARGET_PASSWORD" ]; then
    echo -e "${RED}Error: Target database password cannot be empty${NC}"
    exit 1
fi

# Test connection to source environment
echo -e "${YELLOW}Testing connection to source environment...${NC}"
export PGPASSWORD=$SOURCE_PASSWORD
if ! pg_isready -h $SOURCE_HOST -p $SOURCE_PORT -U $SOURCE_USERNAME -t 10; then
    echo -e "${RED}Error: Cannot connect to source environment${NC}"
    unset PGPASSWORD
    exit 1
fi
echo -e "${GREEN}✓ Connected to source environment${NC}"

# Get list of all databases from source environment
echo -e "${YELLOW}Discovering databases in source environment...${NC}"
DATABASES=$(psql -h $SOURCE_HOST -p $SOURCE_PORT -U $SOURCE_USERNAME -tAc "SELECT datname FROM pg_database WHERE datistemplate = false AND datallowconn = true;" 2>/dev/null)

if [ -z "$DATABASES" ]; then
    echo -e "${RED}Error: No databases found or failed to retrieve database list${NC}"
    unset PGPASSWORD
    exit 1
fi

# Filter out excluded databases
FILTERED_DATABASES=""
for db in $DATABASES; do
    skip=false
    for exclude in "${EXCLUDE_DBS[@]}"; do
        if [ "$db" = "$exclude" ]; then
            skip=true
            break
        fi
    done
    if [ "$skip" = false ]; then
        FILTERED_DATABASES="$FILTERED_DATABASES $db"
    fi
done

if [ -z "$FILTERED_DATABASES" ]; then
    echo -e "${RED}Error: No user databases found after filtering${NC}"
    unset PGPASSWORD
    exit 1
fi

echo -e "${GREEN}Found databases to migrate:${NC}"
for db in $FILTERED_DATABASES; do
    echo -e "  - ${BLUE}$db${NC}"
done
echo ""

# Confirm migration
echo -e "${YELLOW}This will migrate all listed databases to your target environment.${NC}"
echo -e "${YELLOW}WARNING: This will overwrite existing target databases with the same names!${NC}"
echo -n "Continue? (y/N): "
read -r confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Migration cancelled"
    unset PGPASSWORD
    exit 0
fi

# Test connection to target environment
echo -e "${YELLOW}Testing connection to target environment...${NC}"
export PGPASSWORD=$TARGET_PASSWORD
if ! pg_isready -h $TARGET_HOST -p $TARGET_PORT -U $TARGET_USERNAME -t 10; then
    echo -e "${RED}Error: Cannot connect to target PostgreSQL${NC}"
    echo "Please ensure PostgreSQL is running on target"
    unset PGPASSWORD
    exit 1
fi
echo -e "${GREEN}✓ Connected to target environment${NC}"

# Initialize counters
TOTAL_DBS=$(echo $FILTERED_DATABASES | wc -w)
CURRENT_DB=0
SUCCESSFUL_MIGRATIONS=0
FAILED_MIGRATIONS=0

echo -e "${BLUE}Starting migration of $TOTAL_DBS databases...${NC}"
echo ""

# Process each database
for DBNAME in $FILTERED_DATABASES; do
    CURRENT_DB=$((CURRENT_DB + 1))
    BACKUP_FILE="$BACKUP_DIR/${DBNAME}_${DATE}.sql"
    
    echo -e "${BLUE}=== Processing Database $CURRENT_DB/$TOTAL_DBS: $DBNAME ===${NC}"
    
    # Set password for source environment
    export PGPASSWORD=$SOURCE_PASSWORD
    
    # Dump database from source environment
    echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Dumping $DBNAME from source environment...${NC}"
    if pg_dump -h $SOURCE_HOST -p $SOURCE_PORT -U $SOURCE_USERNAME -d $DBNAME \
        --verbose --no-owner --no-privileges -F c -f "$BACKUP_FILE"; then
        echo -e "${GREEN}✓ Backup successful: $BACKUP_FILE${NC}"
        echo "Backup size: $(du -h $BACKUP_FILE | cut -f1)"
    else
        echo -e "${RED}✗ Backup failed for $DBNAME${NC}"
        FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
        continue
    fi
    
    # Switch to target environment password
    export PGPASSWORD=$TARGET_PASSWORD
    
    # Check if target database exists, create if not
    echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Checking if target database '$DBNAME' exists...${NC}"
    DB_EXISTS=$(psql -h $TARGET_HOST -p $TARGET_PORT -U $TARGET_USERNAME -tAc "SELECT 1 FROM pg_database WHERE datname='$DBNAME'" 2>/dev/null || echo "")
    
    if [ "$DB_EXISTS" != "1" ]; then
        echo -e "${YELLOW}Database '$DBNAME' does not exist. Creating...${NC}"
        if createdb -h $TARGET_HOST -p $TARGET_PORT -U $TARGET_USERNAME $DBNAME; then
            echo -e "${GREEN}✓ Database '$DBNAME' created${NC}"
        else
            echo -e "${RED}✗ Failed to create database '$DBNAME'${NC}"
            FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
            continue
        fi
    else
        echo -e "${YELLOW}Database '$DBNAME' already exists (will be overwritten)${NC}"
    fi
    
    # Restore database to target environment
    echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Restoring $DBNAME to target environment...${NC}"
    if pg_restore --exit-on-error -h $TARGET_HOST -p $TARGET_PORT -U $TARGET_USERNAME \
        -d $DBNAME --clean --if-exists --no-owner --no-privileges \
        --verbose "$BACKUP_FILE"; then
        echo -e "${GREEN}✓ Migration completed for $DBNAME${NC}"
        SUCCESSFUL_MIGRATIONS=$((SUCCESSFUL_MIGRATIONS + 1))
    else
        echo -e "${RED}✗ Migration failed for $DBNAME during restore${NC}"
        FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
    fi
    
    echo ""
done

# Cleanup
unset PGPASSWORD

echo -e "${BLUE}=== Migration Summary ===${NC}"
echo "Source: $SOURCE_HOST:$SOURCE_PORT"
echo "Target: $TARGET_HOST:$TARGET_PORT"
echo "Total databases: $TOTAL_DBS"
echo -e "Successful migrations: ${GREEN}$SUCCESSFUL_MIGRATIONS${NC}"
echo -e "Failed migrations: ${RED}$FAILED_MIGRATIONS${NC}"
echo "Backup location: $BACKUP_DIR"
echo ""

if [ $FAILED_MIGRATIONS -eq 0 ]; then
    echo -e "${GREEN}🎉 All databases migrated successfully!${NC}"
else
    echo -e "${YELLOW}⚠️  Some migrations failed. Check the output above for details.${NC}"
fi

echo ""
echo -e "${YELLOW}Note: All backup files have been kept in $BACKUP_DIR for your records${NC}"

# Ask if user wants to clear dump folder
echo ""
echo -e "${YELLOW}Do you want to clear the entire dump folder to save disk space? (y/N):${NC}"
read -r clear_dumps
if [[ $clear_dumps =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Clearing entire dump folder...${NC}"
    rm -f "$BACKUP_DIR"/*
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Dump folder cleared successfully${NC}"
    else
        echo -e "${RED}✗ Failed to clear dump folder${NC}"
    fi
else
    echo -e "${BLUE}Dump files preserved in $BACKUP_DIR${NC}"
fi
