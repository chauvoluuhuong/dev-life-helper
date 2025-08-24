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

# Environment file for storing credentials
ENV_FILE="./.env"

# Databases to exclude from migration (system databases)
EXCLUDE_DBS=("template0" "template1" "postgres" "rdsadmin")

echo -e "${BLUE}=== PostgreSQL Migration: All Databases (Source to Target) ===${NC}"
echo ""

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to load credentials from environment file
load_credentials() {
    if [ -f "$ENV_FILE" ]; then
        echo -e "${BLUE}Found existing environment file. Loading credentials...${NC}"
        source "$ENV_FILE"
        
        # Set variables from environment file if they exist
        if [ -n "$TARGET_DB_HOST" ]; then TARGET_HOST="$TARGET_DB_HOST"; fi
        if [ -n "$TARGET_DB_PORT" ]; then TARGET_PORT="$TARGET_DB_PORT"; fi
        if [ -n "$TARGET_DB_USERNAME" ]; then TARGET_USERNAME="$TARGET_DB_USERNAME"; fi
        if [ -n "$TARGET_DB_PASSWORD" ]; then TARGET_PASSWORD="$TARGET_DB_PASSWORD"; fi
        
        if [ -n "$SOURCE_DB_HOST" ]; then SOURCE_HOST="$SOURCE_DB_HOST"; fi
        if [ -n "$SOURCE_DB_PORT" ]; then SOURCE_PORT="$SOURCE_DB_PORT"; fi
        if [ -n "$SOURCE_DB_USERNAME" ]; then SOURCE_USERNAME="$SOURCE_DB_USERNAME"; fi
        if [ -n "$SOURCE_DB_PASSWORD" ]; then SOURCE_PASSWORD="$SOURCE_DB_PASSWORD"; fi
        
        echo -e "${GREEN}✓ Credentials loaded from environment file${NC}"
        return 0
    fi
    return 1
}

# Function to save credentials to environment file
save_credentials() {
    echo -e "${YELLOW}=== Save Credentials ===${NC}"
    echo -e "${YELLOW}Do you want to save these credentials to an environment file for future use? (y/N):${NC}"
    read -r save_creds
    
    if [[ $save_creds =~ ^[Yy]$ ]]; then
        echo "# Database Migration Credentials" > "$ENV_FILE"
        echo "# Generated on $(date)" >> "$ENV_FILE"
        echo "" >> "$ENV_FILE"
        echo "# Target Database Configuration" >> "$ENV_FILE"
        echo "TARGET_DB_HOST=\"$TARGET_HOST\"" >> "$ENV_FILE"
        echo "TARGET_DB_PORT=\"$TARGET_PORT\"" >> "$ENV_FILE"
        echo "TARGET_DB_USERNAME=\"$TARGET_USERNAME\"" >> "$ENV_FILE"
        echo "TARGET_DB_PASSWORD=\"$TARGET_PASSWORD\"" >> "$ENV_FILE"
        
        if [ "$RESTORE_FROM_DUMP" = false ]; then
            echo "" >> "$ENV_FILE"
            echo "# Source Database Configuration" >> "$ENV_FILE"
            echo "SOURCE_DB_HOST=\"$SOURCE_HOST\"" >> "$ENV_FILE"
            echo "SOURCE_DB_PORT=\"$SOURCE_PORT\"" >> "$ENV_FILE"
            echo "SOURCE_DB_USERNAME=\"$SOURCE_USERNAME\"" >> "$ENV_FILE"
            echo "SOURCE_DB_PASSWORD=\"$SOURCE_PASSWORD\"" >> "$ENV_FILE"
        fi
        
        chmod 600 "$ENV_FILE"  # Restrict permissions for security
        echo -e "${GREEN}✓ Credentials saved to $ENV_FILE${NC}"
        echo -e "${YELLOW}Note: File permissions set to 600 for security${NC}"
    fi
}

# Check for existing credentials and ask if user wants to use them
USE_EXISTING_CREDS=false
if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}=== Existing Credentials Found ===${NC}"
    echo -e "${YELLOW}Found existing credentials file. Do you want to use saved credentials? (y/N):${NC}"
    read -r use_existing
    if [[ $use_existing =~ ^[Yy]$ ]]; then
        USE_EXISTING_CREDS=true
        load_credentials
    fi
    echo ""
fi

# Ask if user wants to remove all data in target database first
echo -e "${YELLOW}=== Target Database Cleanup ===${NC}"
echo -e "${YELLOW}Do you want to remove all data in target databases before migration? (y/N):${NC}"
read -r remove_target_data
echo ""

# Ask if user wants to restore from existing dump files
echo -e "${YELLOW}=== Migration Source Selection ===${NC}"
echo -e "${YELLOW}Do you want to restore from existing dump files in the dump folder? (y/N):${NC}"
read -r restore_from_dump

RESTORE_FROM_DUMP=false
if [[ $restore_from_dump =~ ^[Yy]$ ]]; then
    RESTORE_FROM_DUMP=true
    echo -e "${BLUE}Will restore from existing dump files in: $BACKUP_DIR${NC}"
    
    # Check if dump files exist
    DUMP_FILES=$(ls -1 "$BACKUP_DIR"/*.sql 2>/dev/null | head -20 || echo "")
    if [ -z "$DUMP_FILES" ]; then
        echo -e "${RED}Error: No .sql dump files found in $BACKUP_DIR${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Found dump files:${NC}"
    for file in $DUMP_FILES; do
        basename_file=$(basename "$file")
        file_size=$(du -h "$file" | cut -f1)
        echo -e "  - ${BLUE}$basename_file${NC} (Size: $file_size)"
    done
    echo ""
else
    echo -e "${BLUE}Will create new dump files from source database${NC}"
fi
echo ""

# Get target database credentials (always needed)
if [ "$USE_EXISTING_CREDS" = false ]; then
    echo -e "${YELLOW}=== Target Database Configuration ===${NC}"
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
fi

# Get source database credentials only if not restoring from dump and not using existing credentials
if [ "$RESTORE_FROM_DUMP" = false ] && [ "$USE_EXISTING_CREDS" = false ]; then
    echo ""
    echo -e "${YELLOW}=== Source Database Configuration ===${NC}"
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
fi

echo ""
echo -e "${BLUE}Configuration Summary:${NC}"
if [ "$RESTORE_FROM_DUMP" = false ]; then
    echo "Source: $SOURCE_HOST:$SOURCE_PORT (user: $SOURCE_USERNAME)"
fi
echo "Target: $TARGET_HOST:$TARGET_PORT (user: $TARGET_USERNAME)"
echo "Remove target data first: $remove_target_data"
echo "Restore from dump folder: $restore_from_dump"
echo ""

# Validate required parameters
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

if [ "$RESTORE_FROM_DUMP" = false ]; then
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
fi

# Test connection to target environment
echo -e "${YELLOW}Testing connection to target environment...${NC}"
export PGPASSWORD=$TARGET_PASSWORD
if ! timeout 10 psql -h $TARGET_HOST -p $TARGET_PORT -U $TARGET_USERNAME -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to target PostgreSQL${NC}"
    echo "Please ensure PostgreSQL is running on target"
    unset PGPASSWORD
    exit 1
fi
echo -e "${GREEN}✓ Connected to target environment${NC}"

# Get list of databases based on restore mode
if [ "$RESTORE_FROM_DUMP" = true ]; then
    # Extract database names from dump file names
    DATABASES=""
    for file in $DUMP_FILES; do
        basename_file=$(basename "$file" .sql)
        # Remove timestamp suffix if present (format: dbname_YYYYMMDD_HHMMSS)
        db_name=$(echo "$basename_file" | sed 's/_[0-9]\{8\}_[0-9]\{6\}$//')
        DATABASES="$DATABASES $db_name"
    done
    
    echo -e "${GREEN}Databases to restore from dump files:${NC}"
    for db in $DATABASES; do
        echo -e "  - ${BLUE}$db${NC}"
    done
else
    # Test connection to source environment
    echo -e "${YELLOW}Testing connection to source environment...${NC}"
    export PGPASSWORD=$SOURCE_PASSWORD
    if ! timeout 10 psql -h $SOURCE_HOST -p $SOURCE_PORT -U $SOURCE_USERNAME -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
        echo -e "${RED}Error: Cannot connect to source environment${NC}"
        echo -e "${YELLOW}Please check:${NC}"
        echo -e "  - Network connectivity to AWS RDS"
        echo -e "  - Security groups allow connections from your IP"
        echo -e "  - Username and password are correct"
        echo -e "  - RDS instance is running"
        unset PGPASSWORD
        exit 1
    fi
    echo -e "${GREEN}✓ Connected to source environment${NC}"

    # Get list of all databases from source environment
    echo -e "${YELLOW}Discovering databases in source environment...${NC}"
    DATABASES=$(timeout 30 psql -h $SOURCE_HOST -p $SOURCE_PORT -U $SOURCE_USERNAME -tAc "SELECT datname FROM pg_database WHERE datistemplate = false AND datallowconn = true;" 2>&1)
    DB_QUERY_EXIT_CODE=$?

    if [ $DB_QUERY_EXIT_CODE -eq 124 ]; then
        echo -e "${RED}Error: Database discovery timed out after 30 seconds${NC}"
        echo -e "${YELLOW}This could indicate:${NC}"
        echo -e "  - A locked pg_database table"
        echo -e "  - Long-running transactions"
        echo -e "  - Network connectivity issues"
        echo -e "  - Insufficient permissions"
        unset PGPASSWORD
        exit 1
    elif [ $DB_QUERY_EXIT_CODE -ne 0 ]; then
        echo -e "${RED}Error: Failed to retrieve database list. Exit code: $DB_QUERY_EXIT_CODE${NC}"
        echo -e "${YELLOW}Error output: $DATABASES${NC}"
        unset PGPASSWORD
        exit 1
    fi

    if [ -z "$DATABASES" ]; then
        echo -e "${RED}Error: No databases found${NC}"
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

    DATABASES="$FILTERED_DATABASES"
    echo -e "${GREEN}Found databases to migrate:${NC}"
    for db in $DATABASES; do
        echo -e "  - ${BLUE}$db${NC}"
    done
fi

echo ""

# Confirm migration
echo -e "${YELLOW}This will migrate all listed databases to your target environment.${NC}"
if [[ $remove_target_data =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}WARNING: This will first remove all data in target databases!${NC}"
    echo -e "${YELLOW}WARNING: This will overwrite existing target databases with the same names!${NC}"
    echo -n "Continue? (y/N): "
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Migration cancelled"
        unset PGPASSWORD
        exit 0
    fi
else
    echo -e "${YELLOW}WARNING: This will overwrite existing target databases with the same names!${NC}"
    echo -n "Continue? (y/N): "
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Migration cancelled"
        unset PGPASSWORD
        exit 0
    fi
fi

# Initialize counters
TOTAL_DBS=$(echo $DATABASES | wc -w)
CURRENT_DB=0
SUCCESSFUL_MIGRATIONS=0
FAILED_MIGRATIONS=0

echo -e "${BLUE}Starting migration of $TOTAL_DBS databases...${NC}"
echo ""

# Process each database
for DBNAME in $DATABASES; do
    CURRENT_DB=$((CURRENT_DB + 1))
    
    echo -e "${BLUE}=== Processing Database $CURRENT_DB/$TOTAL_DBS: $DBNAME ===${NC}"
    
    # Set password for target environment
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
        echo -e "${YELLOW}Database '$DBNAME' already exists${NC}"
        if [[ $remove_target_data =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Removing all data from '$DBNAME' as requested...${NC}"
            # Drop and recreate database to remove all data
            if dropdb -h $TARGET_HOST -p $TARGET_PORT -U $TARGET_USERNAME $DBNAME && \
               createdb -h $TARGET_HOST -p $TARGET_PORT -U $TARGET_USERNAME $DBNAME; then
                echo -e "${GREEN}✓ Database '$DBNAME' cleaned and recreated${NC}"
            else
                echo -e "${RED}✗ Failed to clean database '$DBNAME'${NC}"
                FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
                continue
            fi
        else
            echo -e "${YELLOW}Database '$DBNAME' will be overwritten${NC}"
        fi
    fi
    
    if [ "$RESTORE_FROM_DUMP" = true ]; then
        # Find the dump file for this database
        BACKUP_FILE=""
        for file in $DUMP_FILES; do
            basename_file=$(basename "$file" .sql)
            # Remove timestamp suffix if present (format: dbname_YYYYMMDD_HHMMSS)
            db_name=$(echo "$basename_file" | sed 's/_[0-9]\{8\}_[0-9]\{6\}$//')
            if [ "$db_name" = "$DBNAME" ]; then
                BACKUP_FILE="$file"
                break
            fi
        done
        
        if [ -z "$BACKUP_FILE" ]; then
            echo -e "${RED}✗ No dump file found for database '$DBNAME'${NC}"
            FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
            continue
        fi
        
        echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Restoring $DBNAME from dump file: $(basename $BACKUP_FILE)${NC}"
    else
        # Create new dump file (stored directly in dump folder)
        BACKUP_FILE="$BACKUP_DIR/${DBNAME}_${DATE}.sql"
        
        # Set password for source environment
        export PGPASSWORD=$SOURCE_PASSWORD
        
        # Dump database from source environment
        echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Dumping $DBNAME from source environment...${NC}"
        if pg_dump -h $SOURCE_HOST -p $SOURCE_PORT -U $SOURCE_USERNAME -d $DBNAME \
            --verbose --no-owner --no-privileges -F c -f "$BACKUP_FILE"; then
            echo -e "${GREEN}✓ Backup successful: $(basename $BACKUP_FILE)${NC}"
            echo "Backup size: $(du -h $BACKUP_FILE | cut -f1)"
        else
            echo -e "${RED}✗ Backup failed for $DBNAME${NC}"
            FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
            continue
        fi
        
        # Switch back to target environment password
        export PGPASSWORD=$TARGET_PASSWORD
        
        echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Restoring $DBNAME to target environment...${NC}"
    fi
    
    # Restore database to target environment
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

# Ask if user wants to save credentials (only if not using existing credentials)
if [ "$USE_EXISTING_CREDS" = false ]; then
    save_credentials
    echo ""
fi

echo -e "${BLUE}=== Migration Summary ===${NC}"
if [ "$RESTORE_FROM_DUMP" = false ]; then
    echo "Source: $SOURCE_HOST:$SOURCE_PORT"
fi
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