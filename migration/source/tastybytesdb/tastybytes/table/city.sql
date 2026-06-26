USE TastyBytesDB;

GO

CREATE TABLE TastyBytes.City (
    CityID          INT IDENTITY(1,1),
    CityName        NVARCHAR(150) NOT NULL,
    CountryID       INT NOT NULL,
    StateProvince   NVARCHAR(100) NULL,
    Latitude        DECIMAL(9,6) NULL,
    Longitude       DECIMAL(9,6) NULL,
    PopulationSize  INT NULL,
    CreatedAt       DATETIME NOT NULL DEFAULT GETDATE()
);
