USE TastyBytesDB;

GO

CREATE TABLE TastyBytes.OrderDetail (
    OrderID         INT NOT NULL,
    LineNumber      INT NOT NULL,
    MenuItemID      INT NOT NULL,
    Quantity        INT NOT NULL DEFAULT 1,
    UnitPrice       SMALLMONEY NOT NULL,
    Discount        SMALLMONEY NOT NULL DEFAULT 0.00,
    LineTotal       AS (CAST((Quantity * UnitPrice) - Discount AS DECIMAL(10,2))),
    SpecialRequests NVARCHAR(300) NULL
);
