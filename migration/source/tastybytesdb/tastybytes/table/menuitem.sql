USE TastyBytesDB;

GO

CREATE TABLE TastyBytes.MenuItem (
    MenuItemID      INT IDENTITY(1,1),
    MenuID          INT NOT NULL,
    ItemName        NVARCHAR(200) NOT NULL,
    ItemDescription NVARCHAR(MAX) NULL,
    BasePrice       MONEY NOT NULL,
    CalorieCount    INT NULL,
    IsVegetarian    BIT NOT NULL DEFAULT 0,
    IsGlutenFree    BIT NOT NULL DEFAULT 0,
    IsSpicy         BIT NOT NULL DEFAULT 0,
    PriceWithTax    AS (CAST(BasePrice * 1.08 AS DECIMAL(10,2))),
    RowVer          ROWVERSION,
    CreatedAt       DATETIME NOT NULL DEFAULT GETDATE()
);
