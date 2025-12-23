#!/bin/bash

# MongoDB Migration Script: Source to Target (Selective Database Migration)
# This script migrates selected databases from source MongoDB to target MongoDB
# Supports: MongoDB instance → MongoDB instance, MongoDB → Backup folder, Backup folder → MongoDB

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default connection parameters
DEFAULT_HOST="localhost"
DEFAULT_PORT="27017"
DEFAULT_USERNAME=""
DEFAULT_PASSWORD=""
DEFAULT_AUTH_DB="admin"

# Backup configuration
BACKUP_BASE_DIR="./backups"
DATE=$(date +"%Y_%b_%d" | tr '[:upper:]' '[:lower:]')
BACKUP_DIR="$BACKUP_BASE_DIR/${DATE}_backup"

# Credentials file
CREDENTIAL_FILE="./credential.txt"

# Databases to exclude from migration (system databases)
EXCLUDE_DBS=("admin" "local" "config")

echo -e "${BLUE}=== MongoDB Migration: Source to Target ===${NC}"
echo ""

# Check if MongoDB tools are installed
if ! command -v mongodump >/dev/null 2>&1 || ! command -v mongorestore >/dev/null 2>&1; then
    echo -e "${RED}Error: MongoDB tools (mongodump, mongorestore) are not installed${NC}"
    echo -e "${YELLOW}Please install MongoDB Database Tools:${NC}"
    echo -e "${YELLOW}  macOS: brew install mongodb-database-tools${NC}"
    echo -e "${YELLOW}  Linux: https://www.mongodb.com/try/download/database-tools${NC}"
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
        if [ -n "$TARGET_MONGO_HOST" ]; then TARGET_HOST="$TARGET_MONGO_HOST"; fi
        if [ -n "$TARGET_MONGO_PORT" ]; then TARGET_PORT="$TARGET_MONGO_PORT"; fi
        if [ -n "$TARGET_MONGO_USERNAME" ]; then TARGET_USERNAME="$TARGET_MONGO_USERNAME"; fi
        if [ -n "$TARGET_MONGO_PASSWORD" ]; then TARGET_PASSWORD="$TARGET_MONGO_PASSWORD"; fi
        if [ -n "$TARGET_MONGO_AUTH_DB" ]; then TARGET_AUTH_DB="$TARGET_MONGO_AUTH_DB"; fi
        
        if [ -n "$SOURCE_MONGO_HOST" ]; then SOURCE_HOST="$SOURCE_MONGO_HOST"; fi
        if [ -n "$SOURCE_MONGO_PORT" ]; then SOURCE_PORT="$SOURCE_MONGO_PORT"; fi
        if [ -n "$SOURCE_MONGO_USERNAME" ]; then SOURCE_USERNAME="$SOURCE_MONGO_USERNAME"; fi
        if [ -n "$SOURCE_MONGO_PASSWORD" ]; then SOURCE_PASSWORD="$SOURCE_MONGO_PASSWORD"; fi
        if [ -n "$SOURCE_MONGO_AUTH_DB" ]; then SOURCE_AUTH_DB="$SOURCE_MONGO_AUTH_DB"; fi
        
        echo -e "${GREEN}✓ Credentials loaded from credential file${NC}"
        return 0
    fi
    return 1
}

# Function to save credentials to credential file
save_credentials() {
    echo -e "${YELLOW}=== Save Credentials ===${NC}"
    echo -e "${YELLOW}Do you want to save these credentials to credential.txt for future use? (y/N):${NC}"
    read -r save_creds
    
    if [[ $save_creds =~ ^[Yy]$ ]]; then
        echo "# MongoDB Migration Credentials" > "$CREDENTIAL_FILE"
        echo "# Generated on $(date)" >> "$CREDENTIAL_FILE"
        echo "" >> "$CREDENTIAL_FILE"
        echo "# Target MongoDB Configuration" >> "$CREDENTIAL_FILE"
        echo "TARGET_MONGO_HOST=\"$TARGET_HOST\"" >> "$CREDENTIAL_FILE"
        echo "TARGET_MONGO_PORT=\"$TARGET_PORT\"" >> "$CREDENTIAL_FILE"
        echo "TARGET_MONGO_USERNAME=\"$TARGET_USERNAME\"" >> "$CREDENTIAL_FILE"
        echo "TARGET_MONGO_PASSWORD=\"$TARGET_PASSWORD\"" >> "$CREDENTIAL_FILE"
        echo "TARGET_MONGO_AUTH_DB=\"$TARGET_AUTH_DB\"" >> "$CREDENTIAL_FILE"
        
        if [ "$SOURCE_TYPE" != "backup" ]; then
            echo "" >> "$CREDENTIAL_FILE"
            echo "# Source MongoDB Configuration" >> "$CREDENTIAL_FILE"
            echo "SOURCE_MONGO_HOST=\"$SOURCE_HOST\"" >> "$CREDENTIAL_FILE"
            echo "SOURCE_MONGO_PORT=\"$SOURCE_PORT\"" >> "$CREDENTIAL_FILE"
            echo "SOURCE_MONGO_USERNAME=\"$SOURCE_USERNAME\"" >> "$CREDENTIAL_FILE"
            echo "SOURCE_MONGO_PASSWORD=\"$SOURCE_PASSWORD\"" >> "$CREDENTIAL_FILE"
            echo "SOURCE_MONGO_AUTH_DB=\"$SOURCE_AUTH_DB\"" >> "$CREDENTIAL_FILE"
        fi
        
        chmod 600 "$CREDENTIAL_FILE"  # Restrict permissions for security
        echo -e "${GREEN}✓ Credentials saved to $CREDENTIAL_FILE${NC}"
        echo -e "${YELLOW}Note: File permissions set to 600 for security${NC}"
    fi
}

# Function to build MongoDB connection string
build_mongo_uri() {
    local host=$1
    local port=$2
    local username=$3
    local password=$4
    local auth_db=$5
    
    if [ -n "$username" ] && [ -n "$password" ]; then
        echo "mongodb://${username}:${password}@${host}:${port}/${auth_db}"
    else
        echo "mongodb://${host}:${port}"
    fi
}

# Function to build mongodump/mongorestore arguments
build_mongo_args() {
    local host=$1
    local port=$2
    local username=$3
    local password=$4
    local auth_db=$5
    
    local args="--host $host --port $port"
    if [ -n "$username" ] && [ -n "$password" ]; then
        args="$args --username $username --password $password --authenticationDatabase $auth_db"
    fi
    echo "$args"
}

# Function to test MongoDB connection
test_mongo_connection() {
    local host=$1
    local port=$2
    local username=$3
    local password=$4
    local auth_db=$5
    local label=$6
    
    echo -e "${YELLOW}Testing connection to $label...${NC}"
    
    local mongo_args=$(build_mongo_args "$host" "$port" "$username" "$password" "$auth_db")
    
    # Try mongosh first (newer MongoDB shell)
    if command -v mongosh >/dev/null 2>&1; then
        if mongosh $mongo_args --eval "db.adminCommand('ping')" --quiet >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Connected to $label${NC}"
            return 0
        fi
    # Fallback to mongo (legacy MongoDB shell)
    elif command -v mongo >/dev/null 2>&1; then
        if mongo $mongo_args --eval "db.adminCommand('ping')" --quiet >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Connected to $label${NC}"
            return 0
        fi
    # Use mongodump as fallback (always available if MongoDB tools are installed)
    else
        if mongodump $mongo_args --db admin --quiet >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Connected to $label${NC}"
            return 0
        fi
    fi
    
    echo -e "${RED}✗ Cannot connect to $label${NC}"
    return 1
}

# Function to list databases from MongoDB instance
list_mongo_databases() {
    local host=$1
    local port=$2
    local username=$3
    local password=$4
    local auth_db=$5
    
    local mongo_args=$(build_mongo_args "$host" "$port" "$username" "$password" "$auth_db")
    
    # Try mongosh first
    if command -v mongosh >/dev/null 2>&1; then
        mongosh $mongo_args --eval "db.adminCommand('listDatabases').databases.forEach(function(d) { print(d.name); })" --quiet 2>/dev/null | grep -v "^$" | grep -v "^MongoDB" | grep -v "^connecting" || echo ""
    # Fallback to mongo
    elif command -v mongo >/dev/null 2>&1; then
        mongo $mongo_args --eval "db.adminCommand('listDatabases').databases.forEach(function(d) { print(d.name); })" --quiet 2>/dev/null | grep -v "^$" | grep -v "^MongoDB" | grep -v "^connecting" || echo ""
    # Use mongodump to list databases (less reliable but works)
    else
        # Use mongodump with --listCollections to get database names
        mongodump $mongo_args --listCollections 2>&1 | grep -oP "namespace: '\K[^']+" | cut -d'.' -f1 | sort -u || echo ""
    fi
}

# Function to list databases from backup folder
list_backup_databases() {
    local backup_path=$1
    
    if [ ! -d "$backup_path" ]; then
        return 1
    fi
    
    # List directories in backup folder (each directory is a database)
    ls -d "$backup_path"/*/ 2>/dev/null | xargs -n1 basename | grep -v "^$" || echo ""
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
echo "1) MongoDB instance"
echo "2) Backup folder"
echo -n "Select source type (1 or 2): "
read -r source_type_choice

SOURCE_TYPE=""
if [ "$source_type_choice" = "1" ]; then
    SOURCE_TYPE="instance"
elif [ "$source_type_choice" = "2" ]; then
    SOURCE_TYPE="backup"
else
    echo -e "${RED}Error: Invalid selection${NC}"
    exit 1
fi

# Determine target type
echo ""
echo -e "${YELLOW}=== Target Type Selection ===${NC}"
echo "1) MongoDB instance"
echo "2) Backup folder"
echo -n "Select target type (1 or 2): "
read -r target_type_choice

TARGET_TYPE=""
if [ "$target_type_choice" = "1" ]; then
    TARGET_TYPE="instance"
elif [ "$target_type_choice" = "2" ]; then
    TARGET_TYPE="backup"
else
    echo -e "${RED}Error: Invalid selection${NC}"
    exit 1
fi

# Get source configuration
if [ "$SOURCE_TYPE" = "instance" ]; then
    if [ "$USE_EXISTING_CREDS" = false ]; then
        echo ""
        echo -e "${YELLOW}=== Source MongoDB Configuration ===${NC}"
        echo -n "Enter source MongoDB host (default: $DEFAULT_HOST): "
        read SOURCE_HOST
        if [ -z "$SOURCE_HOST" ]; then
            SOURCE_HOST="$DEFAULT_HOST"
        fi
        echo -n "Enter source MongoDB port (default: $DEFAULT_PORT): "
        read SOURCE_PORT
        if [ -z "$SOURCE_PORT" ]; then
            SOURCE_PORT="$DEFAULT_PORT"
        fi
        echo -n "Enter source MongoDB username (leave empty if no auth): "
        read SOURCE_USERNAME
        if [ -z "$SOURCE_USERNAME" ]; then
            SOURCE_USERNAME=""
        fi
        if [ -n "$SOURCE_USERNAME" ]; then
            echo -n "Enter source MongoDB password: "
            read -s SOURCE_PASSWORD
            echo ""
            echo -n "Enter source MongoDB authentication database (default: $DEFAULT_AUTH_DB): "
            read SOURCE_AUTH_DB
            if [ -z "$SOURCE_AUTH_DB" ]; then
                SOURCE_AUTH_DB="$DEFAULT_AUTH_DB"
            fi
        else
            SOURCE_PASSWORD=""
            SOURCE_AUTH_DB=""
        fi
    fi
    
    # Test source connection
    if ! test_mongo_connection "$SOURCE_HOST" "$SOURCE_PORT" "$SOURCE_USERNAME" "$SOURCE_PASSWORD" "$SOURCE_AUTH_DB" "source MongoDB"; then
        echo -e "${RED}Error: Cannot connect to source MongoDB${NC}"
        exit 1
    fi
    
    # List databases from source
    echo -e "${YELLOW}Discovering databases in source MongoDB...${NC}"
    ALL_DATABASES=$(list_mongo_databases "$SOURCE_HOST" "$SOURCE_PORT" "$SOURCE_USERNAME" "$SOURCE_PASSWORD" "$SOURCE_AUTH_DB")
    
    if [ -z "$ALL_DATABASES" ]; then
        echo -e "${RED}Error: No databases found in source MongoDB${NC}"
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
        exit 1
    fi
    
    SOURCE_DATABASES="$FILTERED_DATABASES"
    
elif [ "$SOURCE_TYPE" = "backup" ]; then
    echo ""
    echo -e "${YELLOW}=== Source Backup Folder ===${NC}"
    echo -n "Enter backup folder path (format: <year>_mon_day_backup): "
    read SOURCE_BACKUP_PATH
    
    if [ -z "$SOURCE_BACKUP_PATH" ]; then
        echo -e "${RED}Error: Backup folder path cannot be empty${NC}"
        exit 1
    fi
    
    if [ ! -d "$SOURCE_BACKUP_PATH" ]; then
        echo -e "${RED}Error: Backup folder does not exist: $SOURCE_BACKUP_PATH${NC}"
        exit 1
    fi
    
    # List databases from backup folder
    echo -e "${YELLOW}Discovering databases in backup folder...${NC}"
    SOURCE_DATABASES=$(list_backup_databases "$SOURCE_BACKUP_PATH")
    
    if [ -z "$SOURCE_DATABASES" ]; then
        echo -e "${RED}Error: No databases found in backup folder${NC}"
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
    # Parse comma-separated numbers
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
        echo -e "${YELLOW}=== Target MongoDB Configuration ===${NC}"
        echo -n "Enter target MongoDB host (default: $DEFAULT_HOST): "
        read TARGET_HOST
        if [ -z "$TARGET_HOST" ]; then
            TARGET_HOST="$DEFAULT_HOST"
        fi
        echo -n "Enter target MongoDB port (default: $DEFAULT_PORT): "
        read TARGET_PORT
        if [ -z "$TARGET_PORT" ]; then
            TARGET_PORT="$DEFAULT_PORT"
        fi
        echo -n "Enter target MongoDB username (leave empty if no auth): "
        read TARGET_USERNAME
        if [ -z "$TARGET_USERNAME" ]; then
            TARGET_USERNAME=""
        fi
        if [ -n "$TARGET_USERNAME" ]; then
            echo -n "Enter target MongoDB password: "
            read -s TARGET_PASSWORD
            echo ""
            echo -n "Enter target MongoDB authentication database (default: $DEFAULT_AUTH_DB): "
            read TARGET_AUTH_DB
            if [ -z "$TARGET_AUTH_DB" ]; then
                TARGET_AUTH_DB="$DEFAULT_AUTH_DB"
            fi
        else
            TARGET_PASSWORD=""
            TARGET_AUTH_DB=""
        fi
    fi
    
    # Test target connection
    if ! test_mongo_connection "$TARGET_HOST" "$TARGET_PORT" "$TARGET_USERNAME" "$TARGET_PASSWORD" "$TARGET_AUTH_DB" "target MongoDB"; then
        echo -e "${RED}Error: Cannot connect to target MongoDB${NC}"
        exit 1
    fi
    
elif [ "$TARGET_TYPE" = "backup" ]; then
    echo ""
    echo -e "${YELLOW}=== Target Backup Folder ===${NC}"
    echo -n "Enter backup folder path (default: $BACKUP_DIR): "
    read TARGET_BACKUP_PATH
    if [ -z "$TARGET_BACKUP_PATH" ]; then
        TARGET_BACKUP_PATH="$BACKUP_DIR"
    fi
    
    # Create backup directory if it doesn't exist
    mkdir -p "$TARGET_BACKUP_PATH"
    echo -e "${GREEN}Backup folder: $TARGET_BACKUP_PATH${NC}"
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
    echo "Source: MongoDB instance at $SOURCE_HOST:$SOURCE_PORT"
else
    echo "Source: Backup folder at $SOURCE_BACKUP_PATH"
fi

if [ "$TARGET_TYPE" = "instance" ]; then
    echo "Target: MongoDB instance at $TARGET_HOST:$TARGET_PORT"
else
    echo "Target: Backup folder at $TARGET_BACKUP_PATH"
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
    echo -e "${RED}WARNING: This will drop existing databases in target MongoDB!${NC}"
fi
echo -n "Continue? (y/N): "
read -r confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Migration cancelled"
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
        # Dump from MongoDB instance
        TEMP_DUMP_DIR="/tmp/mongo_migration_${DBNAME}_$$"
        mkdir -p "$TEMP_DUMP_DIR"
        
        echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Dumping $DBNAME from source MongoDB...${NC}"
        
        SOURCE_ARGS=$(build_mongo_args "$SOURCE_HOST" "$SOURCE_PORT" "$SOURCE_USERNAME" "$SOURCE_PASSWORD" "$SOURCE_AUTH_DB")
        
        if mongodump $SOURCE_ARGS --db "$DBNAME" --out "$TEMP_DUMP_DIR" --quiet >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Dump successful${NC}"
        else
            echo -e "${RED}✗ Dump failed for $DBNAME${NC}"
            rm -rf "$TEMP_DUMP_DIR"
            FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
            continue
        fi
        
        DUMP_PATH="$TEMP_DUMP_DIR/$DBNAME"
        
    elif [ "$SOURCE_TYPE" = "backup" ]; then
        # Use backup folder as source
        DUMP_PATH="$SOURCE_BACKUP_PATH/$DBNAME"
        
        if [ ! -d "$DUMP_PATH" ]; then
            echo -e "${RED}✗ Backup folder not found for database '$DBNAME'${NC}"
            FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
            continue
        fi
        
        echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Using backup folder for $DBNAME...${NC}"
        TEMP_DUMP_DIR=""
    fi
    
    # Step 2: Restore to target
    if [ "$TARGET_TYPE" = "instance" ]; then
        # Restore to MongoDB instance
        if [ "$DROP_EXISTING" = true ]; then
            echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Dropping existing database '$DBNAME'...${NC}"
            TARGET_ARGS=$(build_mongo_args "$TARGET_HOST" "$TARGET_PORT" "$TARGET_USERNAME" "$TARGET_PASSWORD" "$TARGET_AUTH_DB")
            # Try mongosh first
            if command -v mongosh >/dev/null 2>&1; then
                mongosh $TARGET_ARGS --eval "db.getSiblingDB('$DBNAME').dropDatabase()" --quiet >/dev/null 2>&1 || true
            # Fallback to mongo
            elif command -v mongo >/dev/null 2>&1; then
                mongo $TARGET_ARGS --eval "db.getSiblingDB('$DBNAME').dropDatabase()" --quiet >/dev/null 2>&1 || true
            fi
        fi
        
        echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Restoring $DBNAME to target MongoDB...${NC}"
        
        TARGET_ARGS=$(build_mongo_args "$TARGET_HOST" "$TARGET_PORT" "$TARGET_USERNAME" "$TARGET_PASSWORD" "$TARGET_AUTH_DB")
        
        if mongorestore $TARGET_ARGS --db "$DBNAME" "$DUMP_PATH" --quiet >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Restore successful for $DBNAME${NC}"
            SUCCESSFUL_MIGRATIONS=$((SUCCESSFUL_MIGRATIONS + 1))
        else
            echo -e "${RED}✗ Restore failed for $DBNAME${NC}"
            FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
        fi
        
    elif [ "$TARGET_TYPE" = "backup" ]; then
        # Copy to backup folder
        echo -e "${YELLOW}[$CURRENT_DB/$TOTAL_DBS] Copying $DBNAME to backup folder...${NC}"
        
        TARGET_DB_PATH="$TARGET_BACKUP_PATH/$DBNAME"
        
        if [ -d "$TARGET_DB_PATH" ]; then
            echo -e "${YELLOW}Backup folder already exists. Removing old backup...${NC}"
            rm -rf "$TARGET_DB_PATH"
        fi
        
        if cp -r "$DUMP_PATH" "$TARGET_DB_PATH"; then
            echo -e "${GREEN}✓ Backup successful for $DBNAME${NC}"
            SUCCESSFUL_MIGRATIONS=$((SUCCESSFUL_MIGRATIONS + 1))
        else
            echo -e "${RED}✗ Backup failed for $DBNAME${NC}"
            FAILED_MIGRATIONS=$((FAILED_MIGRATIONS + 1))
        fi
    fi
    
    # Cleanup temp dump directory if created
    if [ -n "$TEMP_DUMP_DIR" ] && [ -d "$TEMP_DUMP_DIR" ]; then
        rm -rf "$TEMP_DUMP_DIR"
    fi
    
    echo ""
done

# Ask if user wants to save credentials (only if not using existing credentials)
if [ "$USE_EXISTING_CREDS" = false ]; then
    save_credentials
    echo ""
fi

# Display summary
echo -e "${BLUE}=== Migration Summary ===${NC}"
if [ "$SOURCE_TYPE" = "instance" ]; then
    echo "Source: MongoDB instance at $SOURCE_HOST:$SOURCE_PORT"
else
    echo "Source: Backup folder at $SOURCE_BACKUP_PATH"
fi

if [ "$TARGET_TYPE" = "instance" ]; then
    echo "Target: MongoDB instance at $TARGET_HOST:$TARGET_PORT"
else
    echo "Target: Backup folder at $TARGET_BACKUP_PATH"
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

