USE TastyBytesDB;

GO

CREATE TABLE TastyBytes.Customer (
    CustomerID      INT IDENTITY(1,1),
    CustomerGUID    UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    FirstName       NVARCHAR(100) NOT NULL,
    LastName        NVARCHAR(100) NOT NULL,
    Email           VARCHAR(255) NULL,
    PhoneNumber     VARCHAR(20) NULL,
    PreferredCityID INT NULL,
    LoyaltyPoints   INT NOT NULL DEFAULT 0,
    MemberSince     DATE NOT NULL DEFAULT GETDATE(),
    IsActive        BIT NOT NULL DEFAULT 1,
    CreatedAt       DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedAt      DATETIME NULL
);
