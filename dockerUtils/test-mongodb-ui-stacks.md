# MongoDB UI Test Stacks

This directory contains 3 different MongoDB + UI combinations for testing with the Docker Manager CLI.

## Stack 1: MongoDB + Mongo Express

**Location**: `test-mongo-express/docker-compose.yml`

- **MongoDB**: Port 27017
- **Mongo Express**: Port 8081
- **Login**: admin / pass123
- **Features**:
  - Web-based MongoDB admin interface
  - Database/collection management
  - Document editing
  - Query execution

**Access**: http://localhost:8081

## Stack 2: MongoDB + Mongoku

**Location**: `test-mongoku/docker-compose.yml`

- **MongoDB**: Port 27018
- **Mongoku**: Port 3100
- **Features**:
  - Modern, clean UI
  - Real-time updates
  - Advanced query builder
  - Sample data included

**Access**: http://localhost:3100

## Stack 3: MongoDB Replica Set + AdminMongo

**Location**: `test-nosqlbooster/docker-compose.yml`

- **MongoDB Primary**: Port 27019
- **MongoDB Secondary**: Port 27020
- **AdminMongo**: Port 1234
- **Features**:
  - Replica set configuration
  - Simple admin interface
  - Connection management
  - Basic CRUD operations

**Access**: http://localhost:1234

## Testing with Docker Manager CLI

1. Navigate to dockerUtils directory:

```bash
cd dockerUtils
./docker-manager.sh
```

2. Select option 1 to list docker-compose files
3. Choose any of the test stacks
4. Select "up -d" to start in detached mode

## MongoDB Connection Strings

**Stack 1**: `mongodb://admin:admin123@localhost:27017/`
**Stack 2**: `mongodb://root:rootpass@localhost:27018/`
**Stack 3**: `mongodb://superadmin:superpass@localhost:27019/`

## Clean Up

Use the Docker Manager CLI option 5 to clean up resources:

- Select option 2 to remove project-specific resources
- Or use docker-compose down -v in each directory
