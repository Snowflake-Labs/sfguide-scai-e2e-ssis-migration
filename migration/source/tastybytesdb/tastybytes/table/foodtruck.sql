USE TastyBytesDB;

GO

CREATE TABLE TastyBytes.FoodTruck (
    TruckID         INT IDENTITY(1,1),
    TruckGUID       UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL DEFAULT NEWID(),
    TruckName       NVARCHAR(200) NOT NULL,
    LicensePlate    VARCHAR(20) NOT NULL,
    CityID          INT NOT NULL,
    TruckConfig     NVARCHAR(MAX) NULL,
    YearPurchased   INT NULL,
    MaxCapacity     INT NOT NULL DEFAULT 500,
    IsOperational   BIT NOT NULL DEFAULT 1,
    CreatedAt       DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedAt      DATETIME NULL
);
