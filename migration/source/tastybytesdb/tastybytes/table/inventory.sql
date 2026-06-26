USE TastyBytesDB;

GO

CREATE TABLE TastyBytes.Inventory (
    InventoryID     INT IDENTITY(1,1),
    TruckID         INT NOT NULL,
    IngredientName  NVARCHAR(200) NOT NULL,
    QuantityOnHand  DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    UnitOfMeasure   VARCHAR(20) NOT NULL,
    ReorderLevel    DECIMAL(10,2) NOT NULL DEFAULT 10.00,
    SupplierNotes   NVARCHAR(500) SPARSE NULL
);
