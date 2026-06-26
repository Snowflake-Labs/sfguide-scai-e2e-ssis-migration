USE TastyBytesDB;

GO

CREATE TABLE TastyBytes.OrderHeader (
    OrderID         INT IDENTITY(1,1),
    CustomerID      INT NOT NULL,
    TruckID         INT NOT NULL,
    OrderDate       DATETIME NOT NULL DEFAULT GETDATE(),
    CompletedAt     DATETIME NULL,
    OrderStatus     VARCHAR(20) NOT NULL DEFAULT 'Pending',
    TotalAmount     MONEY NOT NULL DEFAULT 0.00,
    TipAmount       MONEY NULL DEFAULT 0.00,
    PaymentMethod   VARCHAR(30) NULL,
    OrderNotes      NVARCHAR(500) NULL,
    CreatedAt       DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedAt      DATETIME NULL
);
