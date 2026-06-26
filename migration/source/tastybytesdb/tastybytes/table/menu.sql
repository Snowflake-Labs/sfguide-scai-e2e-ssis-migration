USE TastyBytesDB;

GO

CREATE TABLE TastyBytes.Menu (
    MenuID          INT IDENTITY(1,1),
    MenuName        NVARCHAR(200) NOT NULL,
    TruckID         INT NOT NULL,
    CuisineType     NVARCHAR(100) NOT NULL,
    MenuDescription NTEXT NULL,
    BasePriceTier   MONEY NOT NULL DEFAULT 0.00,
    IsSeasonalMenu  BIT NOT NULL DEFAULT 0,
    EffectiveFrom   DATE NOT NULL DEFAULT GETDATE(),
    EffectiveTo     DATE NULL,
    CreatedAt       DATETIME NOT NULL DEFAULT GETDATE()
);
