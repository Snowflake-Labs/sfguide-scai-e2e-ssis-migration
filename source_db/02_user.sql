-- =============================================================================
    -- Create a read-only + execute user (demo_user) for TastyBytesDB on SQL Server
    -- - SELECT on all tables and views (current and future) in every schema
    -- - EXECUTE on all stored procedures and scalar/table-valued UDFs
    -- =============================================================================

    USE [master];
    GO

    -- 1. Server-level login (SQL authentication). Replace the password before running.
    IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'demo_user')
    BEGIN
        CREATE LOGIN [demo_user]
            WITH PASSWORD = N'SnowflakeMigrations2026!',
                 DEFAULT_DATABASE = [tastybytesdb],
                 CHECK_EXPIRATION = ON,
                 CHECK_POLICY     = ON;
    END
    GO

    USE [tastybytesdb];
    GO

    -- 2. Database user mapped to the login
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'demo_user')
    BEGIN
        CREATE USER [demo_user] FOR LOGIN [demo_user];
    END
    GO

    -- 3. Database-wide grants
    --    SELECT covers every table and view in every schema (existing + future).
    GRANT SELECT   ON DATABASE::[tastybytesdb] TO [demo_user];

    --    EXECUTE covers every stored procedure and scalar/aggregate function (existing + future).
    GRANT EXECUTE  ON DATABASE::[tastybytesdb] TO [demo_user];

    --    Inline / multi-statement table-valued functions need SELECT on the object;
    --    the database-level SELECT above already covers them. If you also want the
    --    user to see object metadata (sys.* views, SSMS object explorer, etc.):
    GRANT VIEW DEFINITION ON DATABASE::[tastybytesdb] TO [demo_user];
    GO

    -- 4. (Optional) Explicit schema-level grants — keep these if your security
    --    policy prefers per-schema scoping over database-wide grants. Drop the
    --    database-level grants above if you use these instead.
    /*
    GRANT SELECT, EXECUTE ON SCHEMA::[dbo]          TO [demo_user];
    GRANT SELECT, EXECUTE ON SCHEMA::[TastyBytes]   TO [demo_user];
    GRANT SELECT, EXECUTE ON SCHEMA::[etl_results]  TO [demo_user];
    */
    GO

    -- 5. Verify
    SELECT
        perm.permission_name,
        perm.state_desc,
        perm.class_desc,
        OBJECT_SCHEMA_NAME(perm.major_id) AS schema_name,
        OBJECT_NAME(perm.major_id)        AS object_name
    FROM sys.database_permissions AS perm
    JOIN sys.database_principals  AS p ON p.principal_id = perm.grantee_principal_id
    WHERE p.name = N'demo_user'
    ORDER BY perm.class_desc, schema_name, object_name;
    GO