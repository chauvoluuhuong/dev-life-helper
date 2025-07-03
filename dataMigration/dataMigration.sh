#!/bin/bash

# PostgreSQL Migration Script: Dev to Local (All Databases)
# This script migrates all databases from development environment to local environment

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default ports
DEV_PORT="5432"
LOCAL_PORT="5432"

# Backup configuration
BACKUP_DIR="./dump"
DATE=$(date +"%Y%m%d_%H%M%S")

# Databases to exclude from migration (system databases)
EXCLUDE_DBS=("template0" "template1" "postgres" "rdsadmin")

echo -e "${BLUE}=== PostgreSQL Migration: All Databases (Dev to Local) ===${NC}"
echo ""

# Prompt for database connection parameters
echo -e "${YELLOW}=== Database Connection Configuration ===${NC}"
echo ""

# Source (Development) Environment
echo -e "${YELLOW}Source Database Configuration:${NC}"
echo -n "Enter development database host: "
read DEV_HOST
echo -n "Enter development database username: "
read DEV_USERNAME

# Target (Local) Environment
echo ""
echo -e "${YELLOW}Target Database Configuration:${NC}"
echo -n "Enter local database host (default: localhost): "
read LOCAL_HOST
if [ -z "$LOCAL_HOST" ]; then
    LOCAL_HOST="localhost"
fi
echo -n "Enter local database username (default: postgres): "
read LOCAL_USERNAME
if [ -z "$LOCAL_USERNAME" ]; then
    LOCAL_USERNAME="postgres"
fi
echo -n "Enter local database password: "
read -s LOCAL_PASSWORD
echo ""

echo ""
echo -e "${BLUE}Configuration Summary:${NC}"
echo "Source: $DEV_HOST:$DEV_PORT (user: $DEV_USERNAME)"
echo "Target: $LOCAL_HOST:$LOCAL_PORT (user: $LOCAL_USERNAME)"
echo ""

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Validate required parameters
if [ -z "$DEV_HOST" ]; then
    echo -e "${RED}Error: Development database host cannot be empty${NC}"
    exit 1
fi

if [ -z "$DEV_USERNAME" ]; then
    echo -e "${RED}Error: Development database username cannot be empty${NC}"
    exit 1
fi

# Prompt for dev environment password
echo -e "${YELLOW}Enter password for dev environment user '$DEV_USERNAME':${NC}"
read -s DEV_PASSWORD
echo ""

if [ -z "$DEV_PASSWORD" ]; then
    echo -e "${RED}Error: Dev environment password cannot be empty${NC}"
    exit 1
fi

if [ -z "$LOCAL_PASSWORD" ]; then
    echo -e "${RED}Error: Local environment password cannot be empty${NC}"
    exit 1
fi

# Test connection to dev environment
echo -e "${YELLOW}Testing connection to dev environment...${NC}"
export PGPASSWORD=$DEV_PASSWORD
if ! pg_isready -h $DEV_HOST -p $DEV_PORT -U $DEV_USERNAME -t 10; then
    echo -e "${RED}Error: Cannot connect to dev environment${NC}"
    unset PGPASSWORD
    exit 1
fi
echo -e "${GREEN}✓ Connected to dev environment${NC}"

# Get list of all databases from dev environment
echo -e "${YELLOW}Discovering databases in dev environment...${NC}"
DATABASES=$(psql -h $DEV_HOST -p $DEV_PORT -U $DEV_USERNAME -tAc "SELECT datname FROM pg_database WHERE datistemplate = false AND datallowconn = true;" 2>/dev/null)

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
echo -e "${YELLOW}This will migrate all listed databases to your local environment.${NC}"
echo -e "${YELLOW}WARNING: This will overwrite existing local databases with the same names!${NC}"
echo -n "Continue? (y/N): "
read -r confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Migration cancelled"
    unset PGPASSWORD
    exit 0
fi

# Test connection to local environment
echo -e "${YELLOW}Testing connection to local environment...${NC}"
export PGPASSWORD=$LOCAL_PASSWORD
if ! pg_isready -h $LOCAL_HOST -p $LOCAL_PORT -U $LOCAL_USERNAME -t 10; then
    echo -e "${RED}Error: Cannot connect to local PostgreSQL${NC}"
    echo "Please ensure PostgreSQL is running locally"
    unset PGPASSWORD
    exit 1
fi
echo -e "${GREEN}✓ Connected to local environment${NC}"

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
    
    # Set password for dev environment
    export PGPASSWORD=$DEV_PASSWORD
    
    # Dump database from dev environment
    echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Dumping $DBNAME from dev environment...${NC}"
    if pg_dump -h $DEV_HOST -p $DEV_PORT -U $DEV_USERNAME -d $DBNAME \
        --verbose --no-owner --no-privileges -F c -f "$BACKUP_FILE"; then
        echo -e "${GREEN}✓ Backup successful: $BACKUP_FILE${NC}"
        echo "Backup size: $(du -h $BACKUP_FILE | cut -f1)"
    else
        echo -e "${RED}✗ Backup failed for $DBNAME${NC}"
        FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
        continue
    fi
    
    # Switch to local environment password
    export PGPASSWORD=$LOCAL_PASSWORD
    
    # Check if local database exists, create if not
    echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Checking if local database '$DBNAME' exists...${NC}"
    DB_EXISTS=$(psql -h $LOCAL_HOST -p $LOCAL_PORT -U $LOCAL_USERNAME -tAc "SELECT 1 FROM pg_database WHERE datname='$DBNAME'" 2>/dev/null || echo "")
    
    if [ "$DB_EXISTS" != "1" ]; then
        echo -e "${YELLOW}Database '$DBNAME' does not exist. Creating...${NC}"
        if createdb -h $LOCAL_HOST -p $LOCAL_PORT -U $LOCAL_USERNAME $DBNAME; then
            echo -e "${GREEN}✓ Database '$DBNAME' created${NC}"
        else
            echo -e "${RED}✗ Failed to create database '$DBNAME'${NC}"
            FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
            continue
        fi
    else
        echo -e "${YELLOW}Database '$DBNAME' already exists (will be overwritten)${NC}"
    fi
    
    # Restore database to local environment
    echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Restoring $DBNAME to local environment...${NC}"
    if pg_restore --exit-on-error -h $LOCAL_HOST -p $LOCAL_PORT -U $LOCAL_USERNAME \
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
echo "Source: $DEV_HOST"
echo "Target: $LOCAL_HOST"
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
