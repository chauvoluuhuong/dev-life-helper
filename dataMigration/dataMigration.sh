#!/bin/bash

# PostgreSQL Migration Script: Source to Target (Selective Database Migration)
# This script migrates selected databases from source PostgreSQL to target PostgreSQL
# Supports: PostgreSQL instance → PostgreSQL instance, PostgreSQL → Dump folder, Dump folder → PostgreSQL

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
BACKUP_BASE_DIR="./dump"
DATE=$(date +"%Y_%b_%d" | tr '[:upper:]' '[:lower:]')
BACKUP_DIR="$BACKUP_BASE_DIR/${DATE}_dump"

# Credentials file
CREDENTIAL_FILE="./.env"

# Databases to exclude from migration (system databases)
EXCLUDE_DBS=("template0" "template1" "postgres" "rdsadmin")

echo -e "${BLUE}=== PostgreSQL Migration: Source to Target ===${NC}"
echo ""

# Check if PostgreSQL tools are installed
if ! command -v pg_dump >/dev/null 2>&1 || ! command -v pg_restore >/dev/null 2>&1; then
    echo -e "${RED}Error: PostgreSQL tools (pg_dump, pg_restore) are not installed${NC}"
    echo -e "${YELLOW}Please install PostgreSQL client tools:${NC}"
    echo -e "${YELLOW}  macOS: brew install libpq${NC}"
    echo -e "${YELLOW}  Linux: sudo apt-get install postgresql-client${NC}"
    exit 1
fi

# Create backup base directory if it doesn't exist
mkdir -p "$BACKUP_BASE_DIR"

# Function to load credentials from credential file
load_credentials() {
    if [ -f "$CREDENTIAL_FILE" ]; then
        echo -e "${BLUE}Found existing credential file. Loading credentials...${NC}"
        source "$CREDENTIAL_FILE"
        
        # Set variables from credential file if they exist
        if [ -n "$TARGET_DB_HOST" ]; then TARGET_HOST="$TARGET_DB_HOST"; fi
        if [ -n "$TARGET_DB_PORT" ]; then TARGET_PORT="$TARGET_DB_PORT"; fi
        if [ -n "$TARGET_DB_USERNAME" ]; then TARGET_USERNAME="$TARGET_DB_USERNAME"; fi
        if [ -n "$TARGET_DB_PASSWORD" ]; then TARGET_PASSWORD="$TARGET_DB_PASSWORD"; fi
        
        if [ -n "$SOURCE_DB_HOST" ]; then SOURCE_HOST="$SOURCE_DB_HOST"; fi
        if [ -n "$SOURCE_DB_PORT" ]; then SOURCE_PORT="$SOURCE_DB_PORT"; fi
        if [ -n "$SOURCE_DB_USERNAME" ]; then SOURCE_USERNAME="$SOURCE_DB_USERNAME"; fi
        if [ -n "$SOURCE_DB_PASSWORD" ]; then SOURCE_PASSWORD="$SOURCE_DB_PASSWORD"; fi
        
        echo -e "${GREEN}✓ Credentials loaded from credential file${NC}"
        return 0
    fi
    return 1
}

# Function to save credentials to credential file
save_credentials() {
    echo -e "${YELLOW}=== Save Credentials ===${NC}"
    echo -e "${YELLOW}Do you want to save these credentials to .env for future use? (y/N):${NC}"
    read -r save_creds
    
    if [[ $save_creds =~ ^[Yy]$ ]]; then
        echo "# PostgreSQL Migration Credentials" > "$CREDENTIAL_FILE"
        echo "# Generated on $(date)" >> "$CREDENTIAL_FILE"
        echo "" >> "$CREDENTIAL_FILE"
        
        if [ "$TARGET_TYPE" = "instance" ]; then
            echo "# Target Database Configuration" >> "$CREDENTIAL_FILE"
            echo "TARGET_DB_HOST=\"$TARGET_HOST\"" >> "$CREDENTIAL_FILE"
            echo "TARGET_DB_PORT=\"$TARGET_PORT\"" >> "$CREDENTIAL_FILE"
            echo "TARGET_DB_USERNAME=\"$TARGET_USERNAME\"" >> "$CREDENTIAL_FILE"
            echo "TARGET_DB_PASSWORD=\"$TARGET_PASSWORD\"" >> "$CREDENTIAL_FILE"
        fi
        
        if [ "$SOURCE_TYPE" = "instance" ]; then
            echo "" >> "$CREDENTIAL_FILE"
            echo "# Source Database Configuration" >> "$CREDENTIAL_FILE"
            echo "SOURCE_DB_HOST=\"$SOURCE_HOST\"" >> "$CREDENTIAL_FILE"
            echo "SOURCE_DB_PORT=\"$SOURCE_PORT\"" >> "$CREDENTIAL_FILE"
            echo "SOURCE_DB_USERNAME=\"$SOURCE_USERNAME\"" >> "$CREDENTIAL_FILE"
            echo "SOURCE_DB_PASSWORD=\"$SOURCE_PASSWORD\"" >> "$CREDENTIAL_FILE"
        fi
        
        chmod 600 "$CREDENTIAL_FILE"
        echo -e "${GREEN}✓ Credentials saved to $CREDENTIAL_FILE${NC}"
        echo -e "${YELLOW}Note: File permissions set to 600 for security${NC}"
    fi
}

# Function to find a connectable database for admin queries
find_connect_db() {
    local host=$1
    local port=$2
    local username=$3
    local password=$4
    
    export PGPASSWORD="$password"
    # Try common default databases in order
    for db in postgres template1; do
        if timeout 5 psql -h "$host" -p "$port" -U "$username" -d "$db" -c "SELECT 1;" >/dev/null 2>&1; then
            echo "$db"
            return 0
        fi
    done
    
    # If none of the defaults work, try connecting without specifying a database
    # (psql defaults to a database named after the username)
    if timeout 5 psql -h "$host" -p "$port" -U "$username" -c "SELECT 1;" >/dev/null 2>&1; then
        echo "$username"
        return 0
    fi
    
    return 1
}

# Function to test PostgreSQL connection
test_pg_connection() {
    local host=$1
    local port=$2
    local username=$3
    local password=$4
    local label=$5
    
    echo -e "${YELLOW}Testing connection to $label...${NC}"
    
    export PGPASSWORD="$password"
    
    # Try connecting to postgres db first, then fall back to username-based db
    local connect_db
    connect_db=$(find_connect_db "$host" "$port" "$username" "$password")
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Connected to $label${NC}"
        return 0
    fi
    
    echo -e "${RED}✗ Cannot connect to $label${NC}"
    return 1
}

# Function to list databases from PostgreSQL instance
list_pg_databases() {
    local host=$1
    local port=$2
    local username=$3
    local password=$4
    
    export PGPASSWORD="$password"
    
    local connect_db
    connect_db=$(find_connect_db "$host" "$port" "$username" "$password")
    
    if [ -z "$connect_db" ]; then
        # Can't find a connectable database, try listing via the username db
        connect_db="$username"
    fi
    
    # Try to list all databases the user can see
    local result
    result=$(timeout 30 psql -h "$host" -p "$port" -U "$username" -d "$connect_db" -tAc \
        "SELECT datname FROM pg_database WHERE datistemplate = false AND datallowconn = true;" 2>/dev/null)
    
    if [ -n "$result" ]; then
        echo "$result"
        return 0
    fi
    
    # Fallback: if the user can't query pg_database, return the connected database name
    # (the user likely only has access to their own database)
    echo -e "${YELLOW}Note: Cannot list all databases. Falling back to accessible database(s).${NC}" >&2
    echo "$connect_db"
}

# Function to list databases from dump folder
list_dump_databases() {
    local dump_path=$1
    
    if [ ! -d "$dump_path" ]; then
        return 1
    fi
    
    # List .sql files in dump folder and extract database names
    for file in "$dump_path"/*.sql; do
        [ -f "$file" ] || continue
        basename_file=$(basename "$file" .sql)
        # Remove timestamp suffix if present (format: dbname_YYYYMMDD_HHMMSS)
        echo "$basename_file" | sed 's/_[0-9]\{8\}_[0-9]\{6\}$//'
    done | sort -u
}

# Check for existing credentials and ask if user wants to use them
USE_EXISTING_CREDS=false
if [ -f "$CREDENTIAL_FILE" ]; then
    echo -e "${YELLOW}=== Existing Credentials Found ===${NC}"
    echo -e "${YELLOW}Found existing credential file. Do you want to use saved credentials? (y/N):${NC}"
    read -r use_existing
    if [[ $use_existing =~ ^[Yy]$ ]]; then
        USE_EXISTING_CREDS=true
        load_credentials
    fi
    echo ""
fi

# Determine source type
echo -e "${YELLOW}=== Source Type Selection ===${NC}"
echo "1) PostgreSQL instance"
echo "2) Dump folder"
echo -n "Select source type (1 or 2): "
read -r source_type_choice

SOURCE_TYPE=""
if [ "$source_type_choice" = "1" ]; then
    SOURCE_TYPE="instance"
elif [ "$source_type_choice" = "2" ]; then
    SOURCE_TYPE="dump"
else
    echo -e "${RED}Error: Invalid selection${NC}"
    exit 1
fi

# Determine target type
echo ""
echo -e "${YELLOW}=== Target Type Selection ===${NC}"
echo "1) PostgreSQL instance"
echo "2) Dump folder"
echo -n "Select target type (1 or 2): "
read -r target_type_choice

TARGET_TYPE=""
if [ "$target_type_choice" = "1" ]; then
    TARGET_TYPE="instance"
elif [ "$target_type_choice" = "2" ]; then
    TARGET_TYPE="dump"
else
    echo -e "${RED}Error: Invalid selection${NC}"
    exit 1
fi

# Get source configuration
if [ "$SOURCE_TYPE" = "instance" ]; then
    if [ "$USE_EXISTING_CREDS" = false ]; then
        echo ""
        echo -e "${YELLOW}=== Source PostgreSQL Configuration ===${NC}"
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
    
    # Test source connection
    if ! test_pg_connection "$SOURCE_HOST" "$SOURCE_PORT" "$SOURCE_USERNAME" "$SOURCE_PASSWORD" "source PostgreSQL"; then
        echo -e "${RED}Error: Cannot connect to source PostgreSQL${NC}"
        echo -e "${YELLOW}Please check:${NC}"
        echo -e "  - Network connectivity"
        echo -e "  - Security groups allow connections from your IP"
        echo -e "  - Username and password are correct"
        echo -e "  - PostgreSQL instance is running"
        unset PGPASSWORD
        exit 1
    fi
    
    # List databases from source
    echo -e "${YELLOW}Discovering databases in source PostgreSQL...${NC}"
    ALL_DATABASES=$(list_pg_databases "$SOURCE_HOST" "$SOURCE_PORT" "$SOURCE_USERNAME" "$SOURCE_PASSWORD")
    
    if [ -z "$ALL_DATABASES" ]; then
        echo -e "${RED}Error: No databases found in source PostgreSQL${NC}"
        unset PGPASSWORD
        exit 1
    fi
    
    # Filter out excluded databases
    FILTERED_DATABASES=""
    for db in $ALL_DATABASES; do
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
    
    SOURCE_DATABASES="$FILTERED_DATABASES"
    
elif [ "$SOURCE_TYPE" = "dump" ]; then
    echo ""
    echo -e "${YELLOW}=== Source Dump Folder ===${NC}"
    echo -n "Enter dump folder path (default: $BACKUP_BASE_DIR): "
    read SOURCE_DUMP_PATH
    
    if [ -z "$SOURCE_DUMP_PATH" ]; then
        SOURCE_DUMP_PATH="$BACKUP_BASE_DIR"
    fi
    
    if [ ! -d "$SOURCE_DUMP_PATH" ]; then
        echo -e "${RED}Error: Dump folder does not exist: $SOURCE_DUMP_PATH${NC}"
        exit 1
    fi
    
    # Check if dump files exist
    DUMP_FILE_COUNT=$(ls -1 "$SOURCE_DUMP_PATH"/*.sql 2>/dev/null | wc -l || echo "0")
    if [ "$DUMP_FILE_COUNT" -eq 0 ]; then
        echo -e "${RED}Error: No .sql dump files found in $SOURCE_DUMP_PATH${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Found dump files:${NC}"
    for file in "$SOURCE_DUMP_PATH"/*.sql; do
        [ -f "$file" ] || continue
        basename_file=$(basename "$file")
        file_size=$(du -h "$file" | cut -f1)
        echo -e "  - ${BLUE}$basename_file${NC} (Size: $file_size)"
    done
    
    # List databases from dump folder
    echo -e "${YELLOW}Discovering databases in dump folder...${NC}"
    SOURCE_DATABASES=$(list_dump_databases "$SOURCE_DUMP_PATH")
    
    if [ -z "$SOURCE_DATABASES" ]; then
        echo -e "${RED}Error: No databases found in dump folder${NC}"
        exit 1
    fi
fi

# Display available databases
echo ""
echo -e "${GREEN}Available databases:${NC}"
DB_ARRAY=()
DB_INDEX=1
for db in $SOURCE_DATABASES; do
    echo -e "  ${DB_INDEX}) ${BLUE}$db${NC}"
    DB_ARRAY+=("$db")
    DB_INDEX=$((DB_INDEX + 1))
done

# Select databases to migrate
echo ""
echo -e "${YELLOW}=== Database Selection ===${NC}"
echo -e "${YELLOW}Select databases to migrate (comma-separated numbers, e.g., 1,2,3) or 'all' for all databases:${NC}"
read -r db_selection

SELECTED_DATABASES=""
if [ "$db_selection" = "all" ] || [ "$db_selection" = "ALL" ]; then
    SELECTED_DATABASES="$SOURCE_DATABASES"
    echo -e "${GREEN}Selected all databases${NC}"
else
    IFS=',' read -ra SELECTED_INDICES <<< "$db_selection"
    for idx in "${SELECTED_INDICES[@]}"; do
        idx=$(echo "$idx" | xargs)  # trim whitespace
        if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 1 ] && [ "$idx" -le "${#DB_ARRAY[@]}" ]; then
            db_name="${DB_ARRAY[$((idx - 1))]}"
            SELECTED_DATABASES="$SELECTED_DATABASES $db_name"
        else
            echo -e "${RED}Warning: Invalid index '$idx' skipped${NC}"
        fi
    done
    
    if [ -z "$SELECTED_DATABASES" ]; then
        echo -e "${RED}Error: No valid databases selected${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Selected databases:${NC}"
    for db in $SELECTED_DATABASES; do
        echo -e "  - ${BLUE}$db${NC}"
    done
fi

# Get target configuration
if [ "$TARGET_TYPE" = "instance" ]; then
    if [ "$USE_EXISTING_CREDS" = false ]; then
        echo ""
        echo -e "${YELLOW}=== Target PostgreSQL Configuration ===${NC}"
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
    
    # Test target connection
    if ! test_pg_connection "$TARGET_HOST" "$TARGET_PORT" "$TARGET_USERNAME" "$TARGET_PASSWORD" "target PostgreSQL"; then
        echo -e "${RED}Error: Cannot connect to target PostgreSQL${NC}"
        unset PGPASSWORD
        exit 1
    fi
    
elif [ "$TARGET_TYPE" = "dump" ]; then
    echo ""
    echo -e "${YELLOW}=== Target Dump Folder ===${NC}"
    echo -n "Enter dump folder path (default: $BACKUP_DIR): "
    read TARGET_DUMP_PATH
    if [ -z "$TARGET_DUMP_PATH" ]; then
        TARGET_DUMP_PATH="$BACKUP_DIR"
    fi
    
    mkdir -p "$TARGET_DUMP_PATH"
    echo -e "${GREEN}Dump folder: $TARGET_DUMP_PATH${NC}"
fi

# Ask if user wants to drop existing databases in target
DROP_EXISTING=false
if [ "$TARGET_TYPE" = "instance" ]; then
    echo ""
    echo -e "${YELLOW}=== Target Database Cleanup ===${NC}"
    echo -e "${YELLOW}Do you want to drop existing databases in target before migration? (y/N):${NC}"
    read -r drop_existing
    if [[ $drop_existing =~ ^[Yy]$ ]]; then
        DROP_EXISTING=true
    fi
fi

# Display configuration summary
echo ""
echo -e "${BLUE}=== Configuration Summary ===${NC}"
if [ "$SOURCE_TYPE" = "instance" ]; then
    echo "Source: PostgreSQL instance at $SOURCE_HOST:$SOURCE_PORT (user: $SOURCE_USERNAME)"
else
    echo "Source: Dump folder at $SOURCE_DUMP_PATH"
fi

if [ "$TARGET_TYPE" = "instance" ]; then
    echo "Target: PostgreSQL instance at $TARGET_HOST:$TARGET_PORT (user: $TARGET_USERNAME)"
else
    echo "Target: Dump folder at $TARGET_DUMP_PATH"
fi

echo "Databases to migrate:"
for db in $SELECTED_DATABASES; do
    echo "  - $db"
done

if [ "$DROP_EXISTING" = true ]; then
    echo "Drop existing databases: Yes"
fi

echo ""

# Confirm migration
echo -e "${YELLOW}This will migrate the selected databases.${NC}"
if [ "$DROP_EXISTING" = true ]; then
    echo -e "${RED}WARNING: This will drop existing databases in target PostgreSQL!${NC}"
fi
echo -n "Continue? (y/N): "
read -r confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Migration cancelled"
    unset PGPASSWORD
    exit 0
fi

# Initialize counters
TOTAL_DBS=$(echo $SELECTED_DATABASES | wc -w | xargs)
CURRENT_DB=0
SUCCESSFUL_MIGRATIONS=0
FAILED_MIGRATIONS=0

echo ""
echo -e "${BLUE}Starting migration of $TOTAL_DBS databases...${NC}"
echo ""

# Process each database
for DBNAME in $SELECTED_DATABASES; do
    CURRENT_DB=$((CURRENT_DB + 1))
    
    echo -e "${BLUE}=== Processing Database $CURRENT_DB/$TOTAL_DBS: $DBNAME ===${NC}"
    
    # Step 1: Dump from source
    if [ "$SOURCE_TYPE" = "instance" ]; then
        TEMP_DUMP_FILE="/tmp/pg_migration_${DBNAME}_$$.sql"
        
        echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Dumping $DBNAME from source PostgreSQL...${NC}"
        
        export PGPASSWORD="$SOURCE_PASSWORD"
        
        if pg_dump -h "$SOURCE_HOST" -p "$SOURCE_PORT" -U "$SOURCE_USERNAME" -d "$DBNAME" \
            --verbose --no-owner --no-privileges -F c -f "$TEMP_DUMP_FILE"; then
            echo -e "${GREEN}✓ Dump successful (Size: $(du -h "$TEMP_DUMP_FILE" | cut -f1))${NC}"
        else
            echo -e "${RED}✗ Dump failed for $DBNAME${NC}"
            rm -f "$TEMP_DUMP_FILE"
            FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
            continue
        fi
        
        DUMP_FILE="$TEMP_DUMP_FILE"
        
    elif [ "$SOURCE_TYPE" = "dump" ]; then
        # Find the dump file for this database
        DUMP_FILE=""
        for file in "$SOURCE_DUMP_PATH"/*.sql; do
            [ -f "$file" ] || continue
            basename_file=$(basename "$file" .sql)
            db_name=$(echo "$basename_file" | sed 's/_[0-9]\{8\}_[0-9]\{6\}$//')
            if [ "$db_name" = "$DBNAME" ]; then
                DUMP_FILE="$file"
                break
            fi
        done
        
        if [ -z "$DUMP_FILE" ]; then
            echo -e "${RED}✗ No dump file found for database '$DBNAME'${NC}"
            FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
            continue
        fi
        
        echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Using dump file for $DBNAME: $(basename "$DUMP_FILE")${NC}"
        TEMP_DUMP_FILE=""
    fi
    
    # Step 2: Restore to target
    if [ "$TARGET_TYPE" = "instance" ]; then
        export PGPASSWORD="$TARGET_PASSWORD"
        
        # Check if target database exists
        echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Checking if target database '$DBNAME' exists...${NC}"
        DB_EXISTS=$(psql -h "$TARGET_HOST" -p "$TARGET_PORT" -U "$TARGET_USERNAME" -tAc \
            "SELECT 1 FROM pg_database WHERE datname='$DBNAME'" 2>/dev/null || echo "")
        
        if [ "$DB_EXISTS" = "1" ]; then
            if [ "$DROP_EXISTING" = true ]; then
                echo -e "${YELLOW}Dropping existing database '$DBNAME'...${NC}"
                if dropdb -h "$TARGET_HOST" -p "$TARGET_PORT" -U "$TARGET_USERNAME" "$DBNAME" && \
                   createdb -h "$TARGET_HOST" -p "$TARGET_PORT" -U "$TARGET_USERNAME" "$DBNAME"; then
                    echo -e "${GREEN}✓ Database '$DBNAME' dropped and recreated${NC}"
                else
                    echo -e "${RED}✗ Failed to drop/recreate database '$DBNAME'${NC}"
                    FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
                    [ -n "$TEMP_DUMP_FILE" ] && rm -f "$TEMP_DUMP_FILE"
                    continue
                fi
            else
                echo -e "${YELLOW}Database '$DBNAME' already exists, will overwrite${NC}"
            fi
        else
            echo -e "${YELLOW}Database '$DBNAME' does not exist. Creating...${NC}"
            if createdb -h "$TARGET_HOST" -p "$TARGET_PORT" -U "$TARGET_USERNAME" "$DBNAME"; then
                echo -e "${GREEN}✓ Database '$DBNAME' created${NC}"
            else
                echo -e "${RED}✗ Failed to create database '$DBNAME'${NC}"
                FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
                [ -n "$TEMP_DUMP_FILE" ] && rm -f "$TEMP_DUMP_FILE"
                continue
            fi
        fi
        
        echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Restoring $DBNAME to target PostgreSQL...${NC}"
        
        if pg_restore --exit-on-error -h "$TARGET_HOST" -p "$TARGET_PORT" -U "$TARGET_USERNAME" \
            -d "$DBNAME" --clean --if-exists --no-owner --no-privileges \
            --verbose "$DUMP_FILE"; then
            echo -e "${GREEN}✓ Restore successful for $DBNAME${NC}"
            SUCCESSFUL_MIGRATIONS=$((SUCCESSFUL_MIGRATIONS + 1))
        else
            echo -e "${RED}✗ Restore failed for $DBNAME${NC}"
            FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
        fi
        
    elif [ "$TARGET_TYPE" = "dump" ]; then
        if [ "$SOURCE_TYPE" = "instance" ]; then
            # Move the temp dump to target folder
            TARGET_FILE="$TARGET_DUMP_PATH/${DBNAME}_$(date +"%Y%m%d_%H%M%S").sql"
            echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Saving $DBNAME dump to target folder...${NC}"
            if cp "$DUMP_FILE" "$TARGET_FILE"; then
                echo -e "${GREEN}✓ Dump saved for $DBNAME ($(du -h "$TARGET_FILE" | cut -f1))${NC}"
                SUCCESSFUL_MIGRATIONS=$((SUCCESSFUL_MIGRATIONS + 1))
            else
                echo -e "${RED}✗ Failed to save dump for $DBNAME${NC}"
                FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
            fi
        else
            # Copy dump file to target folder
            TARGET_FILE="$TARGET_DUMP_PATH/$(basename "$DUMP_FILE")"
            echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Copying $DBNAME dump to target folder...${NC}"
            if cp "$DUMP_FILE" "$TARGET_FILE"; then
                echo -e "${GREEN}✓ Dump copied for $DBNAME ($(du -h "$TARGET_FILE" | cut -f1))${NC}"
                SUCCESSFUL_MIGRATIONS=$((SUCCESSFUL_MIGRATIONS + 1))
            else
                echo -e "${RED}✗ Failed to copy dump for $DBNAME${NC}"
                FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
            fi
        fi
    fi
    
    # Cleanup temp dump file if created
    if [ -n "$TEMP_DUMP_FILE" ] && [ -f "$TEMP_DUMP_FILE" ]; then
        rm -f "$TEMP_DUMP_FILE"
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

# Display summary
echo -e "${BLUE}=== Migration Summary ===${NC}"
if [ "$SOURCE_TYPE" = "instance" ]; then
    echo "Source: PostgreSQL instance at $SOURCE_HOST:$SOURCE_PORT"
else
    echo "Source: Dump folder at $SOURCE_DUMP_PATH"
fi

if [ "$TARGET_TYPE" = "instance" ]; then
    echo "Target: PostgreSQL instance at $TARGET_HOST:$TARGET_PORT"
else
    echo "Target: Dump folder at $TARGET_DUMP_PATH"
fi

echo "Total databases: $TOTAL_DBS"
echo -e "Successful migrations: ${GREEN}$SUCCESSFUL_MIGRATIONS${NC}"
echo -e "Failed migrations: ${RED}$FAILED_MIGRATIONS${NC}"
echo ""

if [ $FAILED_MIGRATIONS -eq 0 ]; then
    echo -e "${GREEN}🎉 All databases migrated successfully!${NC}"
else
    echo -e "${YELLOW}⚠️  Some migrations failed. Check the output above for details.${NC}"
fi
