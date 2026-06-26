USE TastyBytesDB;

GO

CREATE TABLE etl_results.etl_logs (
    LogID           INT IDENTITY(1,1),
    name            NVARCHAR(200) NOT NULL,
    execution_date  DATETIME NOT NULL
);
