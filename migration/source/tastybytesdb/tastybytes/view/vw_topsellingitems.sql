USE TastyBytesDB;

GO

CREATE VIEW TastyBytes.vw_TopSellingItems
AS
WITH ItemSales (MenuItemID, ItemName, TotalQuantitySold, TotalRevenue) AS
(
    SELECT
        mi.MenuItemID,
        mi.ItemName,
        SUM(od.Quantity),
        SUM(od.Quantity * od.UnitPrice)
    FROM TastyBytes.OrderDetail od
    INNER JOIN TastyBytes.OrderHeader oh ON od.OrderID = oh.OrderID
    INNER JOIN TastyBytes.MenuItem mi ON od.MenuItemID = mi.MenuItemID
    WHERE oh.OrderStatus = 'Completed'
    GROUP BY mi.MenuItemID, mi.ItemName
)
((SELECT
    MenuItemID,
    ItemName,
    TotalQuantitySold,
    TotalRevenue,
    'By Quantity' AS RankingBasis
  FROM ItemSales)
UNION
(SELECT
    MenuItemID,
    ItemName,
    TotalQuantitySold,
    TotalRevenue,
    'By Revenue' AS RankingBasis
  FROM ItemSales));
