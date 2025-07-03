-- Target database initialization
-- This database will receive the migrated data from source

-- Display PostgreSQL version
SELECT version();

-- Ensure postgres role has access to create databases
GRANT CREATE ON DATABASE postgres TO postgres;

-- Create a simple log table to track when target database was initialized
CREATE TABLE IF NOT EXISTS migration_log (
    id SERIAL PRIMARY KEY,
    event VARCHAR(100),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO migration_log (event) VALUES ('Target database initialized');

-- Show current database and role information
SELECT current_database(), current_user, session_user;

-- List all roles with their permissions
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolcanlogin 
FROM pg_roles 
WHERE rolname IN ('postgres', 'root', current_user); 