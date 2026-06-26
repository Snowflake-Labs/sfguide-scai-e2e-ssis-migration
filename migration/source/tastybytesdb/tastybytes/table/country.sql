USE TastyBytesDB;

GO

CREATE TABLE TastyBytes.Country (
    CountryID       INT IDENTITY(1,1),
    CountryName     NVARCHAR(100) NOT NULL,
    CountryCode     CHAR(3) NOT NULL,
    CurrencyCode    CHAR(3) NOT NULL,
    TaxRate         DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    DisplayName     AS (CountryCode + N' - ' + CurrencyCode),
    IsActive        BIT NOT NULL DEFAULT 1,
    CreatedAt       DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedAt      DATETIME NULL
);
