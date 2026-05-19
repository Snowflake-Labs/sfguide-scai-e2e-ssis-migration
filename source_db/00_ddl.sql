/*******************************************************************************
 * TASTY BYTES — Global Food Truck Network
 * SQL Server Workload (Transact-SQL)
 *
 * This script creates the full schema for Tasty Bytes: a fictitious global
 * food truck company with localized menu options, customer loyalty, order
 * management, inventory tracking, and employee scheduling.
 *
 * Object types: Tables, Views, Functions, Stored Procedures
 * Deliberately uses T-SQL constructs that generate SnowConvert EWIs.
 ******************************************************************************/

-- ============================================================================
-- DATABASE & SCHEMA SETUP
-- ============================================================================
USE master;
GO

IF DB_ID('TastyBytesDB') IS NOT NULL
BEGIN
    ALTER DATABASE TastyBytesDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE TastyBytesDB;
END
GO

CREATE DATABASE TastyBytesDB;
GO

USE TastyBytesDB;
GO

IF SCHEMA_ID('TastyBytes') IS NULL
    EXEC('CREATE SCHEMA TastyBytes');
GO

IF SCHEMA_ID('etl_results') IS NULL
    EXEC('CREATE SCHEMA etl_results');
GO

-- --------------------------------------------------------------------------
-- ETL audit log
-- Used by the SSIS package(s) to record start/end markers for each run.
-- The package executes:
--   INSERT INTO etl_results.etl_logs(name, execution_date)
--   VALUES ('start execution', CURRENT_TIMESTAMP);
--   INSERT INTO etl_results.etl_logs(name, execution_date)
--   VALUES ('endexecution',    CURRENT_TIMESTAMP);
-- --------------------------------------------------------------------------
CREATE TABLE etl_results.etl_logs (
    LogID           INT IDENTITY(1,1) PRIMARY KEY,
    name            NVARCHAR(200) NOT NULL,
    execution_date  DATETIME NOT NULL
);
GO

-- EWI: TS0002 — ANSI_PADDING OFF not supported in Snowflake
SET ANSI_PADDING OFF;
GO

-- EWI: TS0003 — ANSI_WARNINGS OFF not supported in Snowflake
SET ANSI_WARNINGS OFF;
GO

-- ============================================================================
-- TABLES
-- ============================================================================

-- --------------------------------------------------------------------------
-- 1. Country
--    EWI triggers: TS0077 (collation), FDM-TS0014 (computed column)
-- --------------------------------------------------------------------------
CREATE TABLE TastyBytes.Country (
    CountryID       INT IDENTITY(1,1) PRIMARY KEY,
    CountryName     NVARCHAR(100) COLLATE Albanian_BIN NOT NULL,
    CountryCode     CHAR(3) NOT NULL,
    CurrencyCode    CHAR(3) NOT NULL,
    TaxRate         DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    DisplayName     AS (CountryCode + N' - ' + CurrencyCode),
    IsActive        BIT NOT NULL DEFAULT 1,
    CreatedAt       DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedAt      DATETIME NULL
);
GO

-- --------------------------------------------------------------------------
-- 2. City
-- --------------------------------------------------------------------------
CREATE TABLE TastyBytes.City (
    CityID          INT IDENTITY(1,1) PRIMARY KEY,
    CityName        NVARCHAR(150) NOT NULL,
    CountryID       INT NOT NULL,
    StateProvince   NVARCHAR(100) NULL,
    Latitude        DECIMAL(9,6) NULL,
    Longitude       DECIMAL(9,6) NULL,
    PopulationSize  INT NULL,
    CreatedAt       DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_City_Country FOREIGN KEY (CountryID) REFERENCES TastyBytes.Country(CountryID),
    CONSTRAINT UQ_City_Name_Country UNIQUE (CityName, CountryID)
);
GO

-- --------------------------------------------------------------------------
-- 3. FoodTruck
--    EWI triggers: ROWGUIDCOL
-- --------------------------------------------------------------------------
CREATE TABLE TastyBytes.FoodTruck (
    TruckID         INT IDENTITY(1,1) PRIMARY KEY,
    TruckGUID       UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL DEFAULT NEWID(),
    TruckName       NVARCHAR(200) NOT NULL,
    LicensePlate    VARCHAR(20) NOT NULL,
    CityID          INT NOT NULL,
    TruckConfig     NVARCHAR(MAX) NULL,
    YearPurchased   INT NULL,
    MaxCapacity     INT NOT NULL DEFAULT 500,
    IsOperational   BIT NOT NULL DEFAULT 1,
    CreatedAt       DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedAt      DATETIME NULL,
    CONSTRAINT FK_FoodTruck_City FOREIGN KEY (CityID) REFERENCES TastyBytes.City(CityID)
);
GO

-- --------------------------------------------------------------------------
-- 4. Menu
--    EWI triggers: MONEY type, NTEXT (deprecated)
-- --------------------------------------------------------------------------
CREATE TABLE TastyBytes.Menu (
    MenuID          INT IDENTITY(1,1) PRIMARY KEY,
    MenuName        NVARCHAR(200) NOT NULL,
    TruckID         INT NOT NULL,
    CuisineType     NVARCHAR(100) NOT NULL,
    MenuDescription NTEXT NULL,
    BasePriceTier   MONEY NOT NULL DEFAULT 0.00,
    IsSeasonalMenu  BIT NOT NULL DEFAULT 0,
    EffectiveFrom   DATE NOT NULL DEFAULT GETDATE(),
    EffectiveTo     DATE NULL,
    CreatedAt       DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Menu_FoodTruck FOREIGN KEY (TruckID) REFERENCES TastyBytes.FoodTruck(TruckID)
);
GO

-- --------------------------------------------------------------------------
-- 5. MenuItem
--    EWI triggers: FDM-TS0014 (computed column), ROWVERSION
-- --------------------------------------------------------------------------
CREATE TABLE TastyBytes.MenuItem (
    MenuItemID      INT IDENTITY(1,1) PRIMARY KEY,
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
    CreatedAt       DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_MenuItem_Menu FOREIGN KEY (MenuID) REFERENCES TastyBytes.Menu(MenuID)
);
GO

-- --------------------------------------------------------------------------
-- 6. Customer
--    EWI triggers: UNIQUEIDENTIFIER + NEWID()
-- --------------------------------------------------------------------------
CREATE TABLE TastyBytes.Customer (
    CustomerID      INT IDENTITY(1,1) PRIMARY KEY,
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
    ModifiedAt      DATETIME NULL,
    CONSTRAINT FK_Customer_City FOREIGN KEY (PreferredCityID) REFERENCES TastyBytes.City(CityID)
);
GO

-- --------------------------------------------------------------------------
-- 7. OrderHeader
--    CompletedAt changed from DATETIMEOFFSET to DATETIME so the cloud data
--    migration ODBC/Arrow worker can convert the column without ArrowTypeError.
--    Timezone information is dropped intentionally.
-- --------------------------------------------------------------------------
CREATE TABLE TastyBytes.OrderHeader (
    OrderID         INT IDENTITY(1,1) PRIMARY KEY,
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
    ModifiedAt      DATETIME NULL,
    CONSTRAINT FK_OrderHeader_Customer FOREIGN KEY (CustomerID) REFERENCES TastyBytes.Customer(CustomerID),
    CONSTRAINT FK_OrderHeader_FoodTruck FOREIGN KEY (TruckID) REFERENCES TastyBytes.FoodTruck(TruckID),
    CONSTRAINT CK_OrderHeader_Status CHECK (OrderStatus IN ('Pending','InProgress','Completed','Cancelled','Refunded'))
);
GO

-- --------------------------------------------------------------------------
-- 8. OrderDetail
--    EWI triggers: Compound PK, SMALLMONEY
-- --------------------------------------------------------------------------
CREATE TABLE TastyBytes.OrderDetail (
    OrderID         INT NOT NULL,
    LineNumber      INT NOT NULL,
    MenuItemID      INT NOT NULL,
    Quantity        INT NOT NULL DEFAULT 1,
    UnitPrice       SMALLMONEY NOT NULL,
    Discount        SMALLMONEY NOT NULL DEFAULT 0.00,
    LineTotal       AS (CAST((Quantity * UnitPrice) - Discount AS DECIMAL(10,2))),
    SpecialRequests NVARCHAR(300) NULL,
    CONSTRAINT PK_OrderDetail PRIMARY KEY (OrderID, LineNumber),
    CONSTRAINT FK_OrderDetail_OrderHeader FOREIGN KEY (OrderID) REFERENCES TastyBytes.OrderHeader(OrderID),
    CONSTRAINT FK_OrderDetail_MenuItem FOREIGN KEY (MenuItemID) REFERENCES TastyBytes.MenuItem(MenuItemID)
);
GO

-- --------------------------------------------------------------------------
-- 9. Inventory
--    EWI triggers: SPARSE column
-- --------------------------------------------------------------------------
CREATE TABLE TastyBytes.Inventory (
    InventoryID     INT IDENTITY(1,1) PRIMARY KEY,
    TruckID         INT NOT NULL,
    IngredientName  NVARCHAR(200) NOT NULL,
    QuantityOnHand  DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    UnitOfMeasure   VARCHAR(20) NOT NULL,
    ReorderLevel    DECIMAL(10,2) NOT NULL DEFAULT 10.00,
    ExpirationDate  DATE NULL,
    SupplierNotes   NVARCHAR(500) SPARSE NULL,
    LastRestocked   DATETIME NULL,
    CONSTRAINT FK_Inventory_FoodTruck FOREIGN KEY (TruckID) REFERENCES TastyBytes.FoodTruck(TruckID)
);
GO

-- --------------------------------------------------------------------------
-- 10. EmployeeShift
--    StartTime/EndTime changed from TIME to DATETIME so the cloud data
--    migration ODBC/Arrow worker can convert these columns. The HoursWorked
--    computed column still works correctly because DATEDIFF(MINUTE, ...) is
--    valid on DATETIME values.
-- --------------------------------------------------------------------------
CREATE TABLE TastyBytes.EmployeeShift (
    ShiftID         INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeName    NVARCHAR(200) NOT NULL,
    TruckID         INT NOT NULL,
    ShiftDate       DATE NOT NULL,
    StartTime       DATETIME NOT NULL,
    EndTime         DATETIME NOT NULL,
    HoursWorked     AS (DATEDIFF(MINUTE, StartTime, EndTime) / 60.0),
    Role            VARCHAR(50) NOT NULL DEFAULT 'Cook',
    HourlyRate      SMALLMONEY NOT NULL,
    CreatedAt       DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_EmployeeShift_FoodTruck FOREIGN KEY (TruckID) REFERENCES TastyBytes.FoodTruck(TruckID),
    CONSTRAINT CK_EmployeeShift_Role CHECK (Role IN ('Cook','Driver','Cashier','Manager'))
);
GO

-- ============================================================================
-- VIEWS
-- ============================================================================

-- --------------------------------------------------------------------------
-- 1. vw_ActiveTrucks
--    EWI triggers: TS0044 (NOLOCK table hints)
-- --------------------------------------------------------------------------
CREATE VIEW TastyBytes.vw_ActiveTrucks
AS
SELECT
    ft.TruckID,
    ft.TruckName,
    ft.LicensePlate,
    c.CityName,
    co.CountryName,
    ft.YearPurchased,
    ft.MaxCapacity
FROM TastyBytes.FoodTruck ft WITH (NOLOCK)
INNER JOIN TastyBytes.City c WITH (NOLOCK) ON ft.CityID = c.CityID
INNER JOIN TastyBytes.Country co WITH (NOLOCK) ON c.CountryID = co.CountryID
WHERE ft.IsOperational = 1;
GO

-- --------------------------------------------------------------------------
-- 2. vw_DailySalesSummary
--    EWI triggers: TS0044 (NOLOCK table hint)
-- --------------------------------------------------------------------------
CREATE VIEW TastyBytes.vw_DailySalesSummary
AS
SELECT
    CAST(oh.OrderDate AS DATE)          AS SaleDate,
    ft.TruckName,
    c.CityName,
    COUNT(*)                             AS TotalOrders,
    SUM(oh.TotalAmount)                  AS GrossRevenue,
    SUM(oh.TipAmount)                    AS TotalTips,
    AVG(oh.TotalAmount)                  AS AvgOrderValue
FROM TastyBytes.OrderHeader oh WITH (NOLOCK)
INNER JOIN TastyBytes.FoodTruck ft WITH (NOLOCK) ON oh.TruckID = ft.TruckID
INNER JOIN TastyBytes.City c ON ft.CityID = c.CityID
WHERE oh.OrderStatus = 'Completed'
GROUP BY CAST(oh.OrderDate AS DATE), ft.TruckName, c.CityName;
GO

-- --------------------------------------------------------------------------
-- 3. vw_MenuPricing
--    EWI triggers: TS0010 (CTE in view)
-- --------------------------------------------------------------------------
CREATE VIEW TastyBytes.vw_MenuPricing
AS
WITH MenuStats AS (
    SELECT
        m.MenuID,
        m.MenuName,
        m.CuisineType,
        COUNT(mi.MenuItemID)             AS ItemCount,
        MIN(mi.BasePrice)                AS MinPrice,
        MAX(mi.BasePrice)                AS MaxPrice,
        AVG(mi.BasePrice)                AS AvgPrice
    FROM TastyBytes.Menu m
    INNER JOIN TastyBytes.MenuItem mi ON m.MenuID = mi.MenuID
    GROUP BY m.MenuID, m.MenuName, m.CuisineType
)
SELECT
    ms.MenuID,
    ms.MenuName,
    ms.CuisineType,
    ms.ItemCount,
    ms.MinPrice,
    ms.MaxPrice,
    ms.AvgPrice,
    (ms.MaxPrice - ms.MinPrice) AS PriceRange
FROM MenuStats ms;
GO

-- --------------------------------------------------------------------------
-- 4. vw_TopSellingItems — CROSS APPLY
-- --------------------------------------------------------------------------
CREATE VIEW TastyBytes.vw_TopSellingItems
AS
SELECT
    ft.TruckID,
    ft.TruckName,
    TopItems.MenuItemID,
    TopItems.ItemName,
    TopItems.TotalQuantitySold,
    TopItems.TotalRevenue
FROM TastyBytes.FoodTruck ft
CROSS APPLY (
    SELECT TOP 5
        mi.MenuItemID,
        mi.ItemName,
        SUM(od.Quantity)                 AS TotalQuantitySold,
        SUM(od.Quantity * od.UnitPrice)  AS TotalRevenue
    FROM TastyBytes.OrderDetail od
    INNER JOIN TastyBytes.OrderHeader oh ON od.OrderID = oh.OrderID
    INNER JOIN TastyBytes.MenuItem mi ON od.MenuItemID = mi.MenuItemID
    WHERE oh.TruckID = ft.TruckID
      AND oh.OrderStatus = 'Completed'
    GROUP BY mi.MenuItemID, mi.ItemName
    ORDER BY SUM(od.Quantity) DESC
) TopItems;
GO

-- --------------------------------------------------------------------------
-- 5. vw_CustomerOrderHistory
-- --------------------------------------------------------------------------
CREATE VIEW TastyBytes.vw_CustomerOrderHistory
AS
SELECT TOP 1000
    cu.CustomerID,
    cu.FirstName + ' ' + cu.LastName    AS CustomerName,
    cu.Email,
    cu.LoyaltyPoints,
    oh.OrderID,
    oh.OrderDate,
    oh.TotalAmount,
    oh.OrderStatus,
    ft.TruckName
FROM TastyBytes.Customer cu
INNER JOIN TastyBytes.OrderHeader oh ON cu.CustomerID = oh.CustomerID
INNER JOIN TastyBytes.FoodTruck ft ON oh.TruckID = ft.TruckID
ORDER BY oh.OrderDate DESC;
GO

-- ============================================================================
-- USER-DEFINED FUNCTIONS
-- ============================================================================

-- --------------------------------------------------------------------------
-- 2. fn_GetTruckRevenue — scalar UDF
--    Converted from inline TVF to a scalar function. Returns the total
--    revenue (sum of TotalAmount) for a given truck within a date range,
--    counting only completed orders. Callers that previously consumed the
--    TVF row set should now SUM externally or use this aggregate directly.
-- --------------------------------------------------------------------------
CREATE FUNCTION TastyBytes.fn_GetTruckRevenue
(
    @TruckID    INT,
    @StartDate  DATE,
    @EndDate    DATE
)
RETURNS MONEY
AS
BEGIN
    DECLARE @Revenue MONEY;

    SELECT @Revenue = ISNULL(SUM(oh.TotalAmount), 0)
    FROM TastyBytes.OrderHeader oh
    WHERE oh.TruckID = @TruckID
      AND CAST(oh.OrderDate AS DATE) BETWEEN @StartDate AND @EndDate
      AND oh.OrderStatus = 'Completed';

    RETURN @Revenue;
END;
GO

-- --------------------------------------------------------------------------
-- 3. fn_FormatPhoneNumber — STUFF, PATINDEX
-- --------------------------------------------------------------------------
CREATE FUNCTION TastyBytes.fn_FormatPhoneNumber
(
    @RawPhone VARCHAR(20)
)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @CleanPhone VARCHAR(20);
    DECLARE @Formatted VARCHAR(20);

    -- Strip non-numeric characters
    SET @CleanPhone = @RawPhone;
    WHILE PATINDEX('%[^0-9]%', @CleanPhone) > 0
        SET @CleanPhone = STUFF(@CleanPhone, PATINDEX('%[^0-9]%', @CleanPhone), 1, '');

    IF LEN(@CleanPhone) = 10
        SET @Formatted = '(' + LEFT(@CleanPhone, 3) + ') ' +
                          SUBSTRING(@CleanPhone, 4, 3) + '-' +
                          RIGHT(@CleanPhone, 4);
    ELSE IF LEN(@CleanPhone) = 11
        SET @Formatted = '+' + LEFT(@CleanPhone, 1) + ' (' +
                          SUBSTRING(@CleanPhone, 2, 3) + ') ' +
                          SUBSTRING(@CleanPhone, 5, 3) + '-' +
                          RIGHT(@CleanPhone, 4);
    ELSE
        SET @Formatted = @CleanPhone;

    RETURN @Formatted;
END;
GO

-- --------------------------------------------------------------------------
-- 4. fn_ParseTruckConfigJSON — scalar UDF
--    Converted from multi-statement TVF to scalar. Returns the count of
--    operational equipment items declared in the truck's JSON config.
--    Returns 0 when TruckConfig is NULL or the truck does not exist.
-- --------------------------------------------------------------------------
CREATE FUNCTION TastyBytes.fn_ParseTruckConfigJSON
(
    @TruckID INT
)
RETURNS INT
AS
BEGIN
    DECLARE @EquipmentCount INT;

    SELECT @EquipmentCount = COUNT(*)
    FROM TastyBytes.FoodTruck ft
    CROSS APPLY OPENJSON(ft.TruckConfig, '$.Equipment') e
    WHERE ft.TruckID = @TruckID
      AND ft.TruckConfig IS NOT NULL
      AND CAST(JSON_VALUE(e.value, '$.IsOperational') AS BIT) = 1;

    RETURN ISNULL(@EquipmentCount, 0);
END;
GO

-- --------------------------------------------------------------------------
-- 5. fn_SplitString — scalar UDF
--    Converted from inline TVF to scalar. Returns the trimmed element at
--    the supplied 1-based @Position from @InputString split by @Delimiter,
--    or NULL when the position is out of range.
-- --------------------------------------------------------------------------
CREATE FUNCTION TastyBytes.fn_SplitString
(
    @InputString NVARCHAR(MAX),
    @Delimiter   NCHAR(1),
    @Position    INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Result NVARCHAR(MAX);

    SELECT @Result = LTRIM(RTRIM(value))
    FROM (
        SELECT
            value,
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowPos
        FROM STRING_SPLIT(@InputString, @Delimiter)
    ) AS Split
    WHERE Split.RowPos = @Position;

    RETURN @Result;
END;
GO

-- ============================================================================
-- STORED PROCEDURES
-- ============================================================================

-- --------------------------------------------------------------------------
-- 1. sp_ProcessDailyOrders
--    EWI triggers: TS0036 (GLOBAL cursor), TS0035 (uninitialized cursor variable)
-- --------------------------------------------------------------------------
CREATE PROCEDURE TastyBytes.sp_ProcessDailyOrders
    @ProcessDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OrderID        INT;
    DECLARE @TotalAmount    MONEY;
    DECLARE @CustomerID     INT;
    DECLARE @TruckID        INT;
    DECLARE @ProcessedCount INT = 0;

    -- EWI: TS0035 — Cursor variable declared but never initialized
    DECLARE @AuditCursor CURSOR;

    -- EWI: TS0036 — GLOBAL cursor not supported in Snowflake Scripting
    DECLARE OrderCursor CURSOR GLOBAL FOR
        SELECT OrderID, TotalAmount, CustomerID, TruckID
        FROM TastyBytes.OrderHeader
        WHERE CAST(OrderDate AS DATE) = @ProcessDate
          AND OrderStatus = 'Pending'
        ORDER BY OrderDate;

    OPEN OrderCursor;
    FETCH NEXT FROM OrderCursor INTO @OrderID, @TotalAmount, @CustomerID, @TruckID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        UPDATE TastyBytes.OrderHeader
        SET OrderStatus = 'Completed',
            CompletedAt = GETDATE(),
            ModifiedAt = GETDATE()
        WHERE OrderID = @OrderID;

        UPDATE TastyBytes.Customer
        SET LoyaltyPoints = LoyaltyPoints + CAST(@TotalAmount AS INT),
            ModifiedAt = GETDATE()
        WHERE CustomerID = @CustomerID;

        SET @ProcessedCount = @ProcessedCount + 1;

        FETCH NEXT FROM OrderCursor INTO @OrderID, @TotalAmount, @CustomerID, @TruckID;
    END

    CLOSE OrderCursor;
    DEALLOCATE OrderCursor;

    SELECT @ProcessedCount AS TotalProcessed;
END;
GO

-- --------------------------------------------------------------------------
-- 2. sp_UpdateInventory
-- --------------------------------------------------------------------------
CREATE PROCEDURE TastyBytes.sp_UpdateInventory
    @TruckID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RestockCount INT;

    UPDATE TastyBytes.Inventory
    SET QuantityOnHand = ReorderLevel * 2,
        LastRestocked = GETDATE()
    WHERE TruckID = @TruckID
      AND QuantityOnHand <= ReorderLevel;

    SET @RestockCount = @@ROWCOUNT;

    SELECT @RestockCount AS ItemsRestocked;
END;
GO

-- --------------------------------------------------------------------------
-- 3. sp_GenerateSalesReport
-- --------------------------------------------------------------------------
CREATE PROCEDURE TastyBytes.sp_GenerateSalesReport
    @StartDate DATE,
    @EndDate   DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ft.TruckID,
        ft.TruckName,
        COUNT(oh.OrderID)          AS OrderCount,
        SUM(oh.TotalAmount)        AS TotalRevenue
    FROM TastyBytes.FoodTruck ft
    INNER JOIN TastyBytes.OrderHeader oh ON ft.TruckID = oh.TruckID
    WHERE ft.IsOperational = 1
      AND oh.OrderStatus = 'Completed'
      AND CAST(oh.OrderDate AS DATE) BETWEEN @StartDate AND @EndDate
    GROUP BY ft.TruckID, ft.TruckName
    HAVING COUNT(oh.OrderID) > 0
    ORDER BY SUM(oh.TotalAmount) DESC;
END;
GO

-- --------------------------------------------------------------------------
-- 4. sp_MergeCustomerData
--    EWI triggers: TS0036 (GLOBAL cursor), TS0035 (uninitialized cursor variable)
-- --------------------------------------------------------------------------
CREATE PROCEDURE TastyBytes.sp_MergeCustomerData
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('TastyBytes.CustomerStaging') IS NULL
    BEGIN
        CREATE TABLE TastyBytes.CustomerStaging (
            Email           VARCHAR(255) NOT NULL,
            FirstName       NVARCHAR(100),
            LastName        NVARCHAR(100),
            PhoneNumber     VARCHAR(20),
            PreferredCityID INT
        );
    END

    DECLARE @Email       VARCHAR(255);
    DECLARE @FirstName   NVARCHAR(100);
    DECLARE @LastName    NVARCHAR(100);
    DECLARE @Phone       VARCHAR(20);
    DECLARE @CityID      INT;
    DECLARE @InsertCount INT = 0;
    DECLARE @UpdateCount INT = 0;

    -- EWI: TS0035 — Cursor variable declared but never initialized
    DECLARE @LogCursor CURSOR;

    -- EWI: TS0036 — GLOBAL cursor not supported in Snowflake Scripting
    DECLARE StagingCursor CURSOR GLOBAL FOR
        SELECT Email, FirstName, LastName, PhoneNumber, PreferredCityID
        FROM TastyBytes.CustomerStaging;

    OPEN StagingCursor;
    FETCH NEXT FROM StagingCursor INTO @Email, @FirstName, @LastName, @Phone, @CityID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF EXISTS (SELECT 1 FROM TastyBytes.Customer WHERE Email = @Email)
        BEGIN
            UPDATE TastyBytes.Customer
            SET FirstName = @FirstName,
                LastName = @LastName,
                PhoneNumber = @Phone,
                PreferredCityID = @CityID,
                ModifiedAt = GETDATE()
            WHERE Email = @Email;

            SET @UpdateCount = @UpdateCount + 1;
        END
        ELSE
        BEGIN
            INSERT INTO TastyBytes.Customer (FirstName, LastName, Email, PhoneNumber, PreferredCityID, CreatedAt)
            VALUES (@FirstName, @LastName, @Email, @Phone, @CityID, GETDATE());

            SET @InsertCount = @InsertCount + 1;
        END

        FETCH NEXT FROM StagingCursor INTO @Email, @FirstName, @LastName, @Phone, @CityID;
    END

    CLOSE StagingCursor;
    DEALLOCATE StagingCursor;

    SELECT @InsertCount AS Inserted, @UpdateCount AS Updated;
END;
GO

-- --------------------------------------------------------------------------
-- 5. sp_ArchiveOldOrders
-- --------------------------------------------------------------------------
CREATE PROCEDURE TastyBytes.sp_ArchiveOldOrders
    @CutoffDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('TastyBytes.OrderHeader_Archive') IS NULL
    BEGIN
        SELECT TOP 0 * INTO TastyBytes.OrderHeader_Archive
        FROM TastyBytes.OrderHeader;
    END

    INSERT INTO TastyBytes.OrderHeader_Archive
    SELECT * FROM TastyBytes.OrderHeader
    WHERE OrderStatus = 'Completed'
      AND CAST(OrderDate AS DATE) < @CutoffDate;

    DECLARE @ArchiveCount INT = @@ROWCOUNT;

    DELETE FROM TastyBytes.OrderHeader
    WHERE OrderStatus = 'Completed'
      AND CAST(OrderDate AS DATE) < @CutoffDate
      AND OrderID IN (SELECT OrderID FROM TastyBytes.OrderHeader_Archive);

    SELECT @ArchiveCount AS TotalArchived;
END;
GO

-- --------------------------------------------------------------------------
-- 6. sp_SendNotification
-- --------------------------------------------------------------------------
CREATE PROCEDURE TastyBytes.sp_SendNotification
    @TruckID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        @TruckID            AS TruckID,
        i.IngredientName,
        i.QuantityOnHand,
        i.ReorderLevel,
        GETDATE()           AS AlertDate
    FROM TastyBytes.Inventory i
    WHERE i.TruckID = @TruckID
      AND i.QuantityOnHand <= i.ReorderLevel;
END;
GO

-- --------------------------------------------------------------------------
-- 7. sp_ReconcileShifts
-- --------------------------------------------------------------------------
CREATE PROCEDURE TastyBytes.sp_ReconcileShifts
    @ReconcileDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ft.TruckID,
        ft.TruckName,
        (SELECT COUNT(*) FROM TastyBytes.EmployeeShift es
         WHERE es.TruckID = ft.TruckID AND es.ShiftDate = @ReconcileDate) AS ShiftsLogged,
        (SELECT COUNT(*) FROM TastyBytes.OrderHeader oh2
         WHERE oh2.TruckID = ft.TruckID
           AND CAST(oh2.OrderDate AS DATE) = @ReconcileDate
           AND oh2.OrderStatus IN ('Completed', 'InProgress')) AS OrdersFulfilled,
        ISNULL(SUM(oh.TotalAmount), 0) AS Revenue,
        CASE
            WHEN (SELECT COUNT(*) FROM TastyBytes.EmployeeShift es
                  WHERE es.TruckID = ft.TruckID AND es.ShiftDate = @ReconcileDate) = 0
             AND (SELECT COUNT(*) FROM TastyBytes.OrderHeader oh2
                  WHERE oh2.TruckID = ft.TruckID
                    AND CAST(oh2.OrderDate AS DATE) = @ReconcileDate
                    AND oh2.OrderStatus IN ('Completed', 'InProgress')) > 0 THEN 1
            WHEN (SELECT COUNT(*) FROM TastyBytes.EmployeeShift es
                  WHERE es.TruckID = ft.TruckID AND es.ShiftDate = @ReconcileDate) > 0
             AND (SELECT COUNT(*) FROM TastyBytes.OrderHeader oh2
                  WHERE oh2.TruckID = ft.TruckID
                    AND CAST(oh2.OrderDate AS DATE) = @ReconcileDate
                    AND oh2.OrderStatus IN ('Completed', 'InProgress')) = 0 THEN 1
            ELSE 0
        END AS HasDiscrepancy
    FROM TastyBytes.FoodTruck ft
    LEFT JOIN TastyBytes.OrderHeader oh
        ON ft.TruckID = oh.TruckID
       AND CAST(oh.OrderDate AS DATE) = @ReconcileDate
       AND oh.OrderStatus = 'Completed'
    WHERE ft.IsOperational = 1
    GROUP BY ft.TruckID, ft.TruckName
    ORDER BY ft.TruckName;
END;
GO

PRINT '=== Tasty Bytes workload deployment complete ===';
GO
