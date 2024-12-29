
CREATE TABLE DimTime (
    TimeKey INT PRIMARY KEY IDENTITY(1,1),
    Date DATE,
    Year INT,
    Month INT,
    MonthName VARCHAR(10),
    Quarter INT,
    YearMonth VARCHAR(7)
);

CREATE TABLE DimProduct (
    ProductKey INT PRIMARY KEY IDENTITY(1,1),
    ProductID VARCHAR(50),
    Description NVARCHAR(255),
    UnitPrice DECIMAL(10,2),
    Category VARCHAR(50),
    SubCategory VARCHAR(50)
);

CREATE TABLE DimCustomer (
    CustomerKey INT PRIMARY KEY IDENTITY(1,1),
    CustomerID VARCHAR(50),
    Country VARCHAR(50),
    Region VARCHAR(50)
);

CREATE TABLE FactSales (
    SalesKey INT PRIMARY KEY IDENTITY(1,1),
    TimeKey INT FOREIGN KEY REFERENCES DimTime(TimeKey),
    ProductKey INT FOREIGN KEY REFERENCES DimProduct(ProductKey),
    CustomerKey INT FOREIGN KEY REFERENCES DimCustomer(CustomerKey),
    InvoiceNumber VARCHAR(50),
    Quantity INT,
    UnitPrice DECIMAL(10,2),
    TotalAmount DECIMAL(10,2),
    
    Profit DECIMAL(10,2),
    DiscountAmount DECIMAL(10,2)
);

CREATE INDEX idx_time ON FactSales(TimeKey);
CREATE INDEX idx_product ON FactSales(ProductKey);
CREATE INDEX idx_customer ON FactSales(CustomerKey);

select * from DimTime


CREATE TABLE StagingRetail (
    InvoiceNo VARCHAR(50),
    StockCode VARCHAR(50),
    Description NVARCHAR(255),
    Quantity INT,
    InvoiceDate DATETIME,
    UnitPrice DECIMAL(10,2),
    CustomerID VARCHAR(50),
    Country VARCHAR(50)
);

INSERT INTO DimTime (Date, Year, Month, MonthName, Quarter, YearMonth)
SELECT DISTINCT
    CAST(InvoiceDate AS DATE) as Date,
    YEAR(InvoiceDate) as Year,
    MONTH(InvoiceDate) as Month,
    DATENAME(MONTH, InvoiceDate) as MonthName,
    DATEPART(QUARTER, InvoiceDate) as Quarter,
    FORMAT(InvoiceDate, 'yyyy-MM') as YearMonth
FROM StagingRetail;

INSERT INTO DimProduct (ProductID, Description, UnitPrice)
SELECT DISTINCT
    StockCode,
    Description,
    MAX(UnitPrice) 
FROM StagingRetail
GROUP BY StockCode, Description;

INSERT INTO DimCustomer (CustomerID, Country)
SELECT DISTINCT
    CustomerID,
    Country
FROM StagingRetail
WHERE CustomerID IS NOT NULL;

INSERT INTO FactSales (
    TimeKey, 
    ProductKey, 
    CustomerKey,
    InvoiceNumber,
    Quantity,
    UnitPrice,
    TotalAmount
)
SELECT
    t.TimeKey,
    p.ProductKey,
    c.CustomerKey,
    s.InvoiceNo,
    s.Quantity,
    s.UnitPrice,
    s.Quantity * s.UnitPrice as TotalAmount
FROM StagingRetail s
JOIN DimTime t ON CAST(s.InvoiceDate AS DATE) = t.Date
JOIN DimProduct p ON s.StockCode = p.ProductID
JOIN DimCustomer c ON s.CustomerID = c.CustomerID
WHERE s.CustomerID IS NOT NULL;

UPDATE FactSales
SET Profit = TotalAmount * 0.2, 
    DiscountAmount = CASE 
        WHEN TotalAmount > 1000 THEN TotalAmount * 0.1
        ELSE 0 
    END;

  CREATE PROCEDURE RefreshRetailData

AS
BEGIN
    BEGIN TRANSACTION;
    BEGIN TRY
        
        COMMIT;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        THROW;
    END CATCH;
END;

CREATE VIEW vw_DailySalesSummary AS
SELECT 
    t.Date,
    COUNT(DISTINCT f.InvoiceNumber) as TotalOrders,
    SUM(f.Quantity) as TotalItems,
    SUM(f.TotalAmount) as TotalRevenue,
    SUM(f.Profit) as TotalProfit,
    SUM(f.DiscountAmount) as TotalDiscounts
FROM FactSales f
JOIN DimTime t ON f.TimeKey = t.TimeKey
GROUP BY t.Date;

CREATE VIEW vw_ProductPerformance AS
SELECT 
    p.ProductID,
    p.Description,
    COUNT(DISTINCT f.InvoiceNumber) as TimesOrdered,
    SUM(f.Quantity) as TotalQuantitySold,
    SUM(f.TotalAmount) as TotalRevenue,
    SUM(f.Profit) as TotalProfit,
    AVG(f.UnitPrice) as AverageSellingPrice
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY p.ProductID, p.Description;

CREATE VIEW vw_CustomerAnalysis AS
SELECT 
    c.CustomerID,
    c.Country,
    COUNT(DISTINCT f.InvoiceNumber) as TotalOrders,
    SUM(f.TotalAmount) as TotalSpent,
    AVG(f.TotalAmount) as AverageOrderValue,
    MAX(t.Date) as LastOrderDate,
    COUNT(DISTINCT p.ProductID) as UniqueProductsBought
FROM FactSales f
JOIN DimCustomer c ON f.CustomerKey = c.CustomerKey
JOIN DimTime t ON f.TimeKey = t.TimeKey
JOIN DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY c.CustomerID, c.Country;

CREATE VIEW VM_MonthlyTrends AS 
SELECT
 
    t.Year,
    t.Month,
    t.MonthName,
    COUNT(DISTINCT f.InvoiceNumber) as TotalOrders,
    COUNT(DISTINCT c.CustomerID) as UniqueCustomers,
    SUM(f.TotalAmount) as Revenue,
    SUM(f.Profit) as Profit,
    SUM(f.Quantity) as ItemsSold
FROM FactSales f
JOIN DimTime t ON f.TimeKey = t.TimeKey
JOIN DimCustomer c ON f.CustomerKey = c.CustomerKey
GROUP BY t.Year, t.Month, t.MonthName;

CREATE VIEW vw_GeographicSales AS
SELECT 
    c.Country,
    COUNT(DISTINCT c.CustomerID) as TotalCustomers,
    SUM(f.TotalAmount) as TotalRevenue,
    AVG(f.TotalAmount) as AverageOrderValue,
    COUNT(DISTINCT f.InvoiceNumber) as TotalOrders
FROM FactSales f
JOIN DimCustomer c ON f.CustomerKey = c.CustomerKey
GROUP BY c.Country;


CREATE VIEW vw_CategoryPerformance AS
SELECT 
    p.Category,
    p.SubCategory,
    COUNT(DISTINCT f.InvoiceNumber) as TotalOrders,
    SUM(f.Quantity) as TotalQuantity,
    SUM(f.TotalAmount) as TotalRevenue,
    SUM(f.Profit) as TotalProfit
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY p.Category, p.SubCategory;