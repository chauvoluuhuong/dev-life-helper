-- Create postgres role with full permissions if it doesn't exist
-- This script runs first (00-prefix) to ensure the role exists

DO $$ 
BEGIN
    -- Check if postgres role exists
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgres') THEN
        -- Create postgres role with superuser privileges
        CREATE ROLE postgres WITH
            SUPERUSER
            CREATEDB
            CREATEROLE
            INHERIT
            LOGIN
            REPLICATION
            BYPASSRLS
            PASSWORD 'postgres';
        
        RAISE NOTICE 'postgres role created with full permissions';
    ELSE
        -- Role exists, ensure it has all necessary permissions
        ALTER ROLE postgres WITH
            SUPERUSER
            CREATEDB
            CREATEROLE
            INHERIT
            LOGIN
            REPLICATION
            BYPASSRLS
            PASSWORD 'postgres';
            
        RAISE NOTICE 'postgres role permissions updated';
    END IF;
END $$;

-- Grant all privileges on all databases to postgres role
GRANT ALL PRIVILEGES ON DATABASE postgres TO postgres;

-- Show current role information
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolcanlogin, rolreplication, rolbypassrls 
FROM pg_roles WHERE rolname = 'postgres'; 