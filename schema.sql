
-- Automated Sales Analytics & Reporting System
-- Database: SalesAnalytics
-- Run this script in SQL Server (SSMS). It creates schema, sample data, views, and a KPI stored procedure.

IF DB_ID('SalesAnalytics') IS NULL
BEGIN
    CREATE DATABASE SalesAnalytics;
END
GO

USE SalesAnalytics;
GO

-- Clean up if rerunning (optional)
IF OBJECT_ID('dbo.Sales', 'U') IS NOT NULL DROP TABLE dbo.Sales;
IF OBJECT_ID('dbo.Products', 'U') IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID('dbo.Customers', 'U') IS NOT NULL DROP TABLE dbo.Customers;
IF OBJECT_ID('dbo.Regions', 'U') IS NOT NULL DROP TABLE dbo.Regions;
GO

CREATE TABLE dbo.Regions(
    RegionID INT IDENTITY(1,1) PRIMARY KEY,
    RegionName NVARCHAR(100) NOT NULL
);

CREATE TABLE dbo.Customers(
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerName NVARCHAR(200) NOT NULL,
    Email NVARCHAR(255) NULL,
    RegionID INT NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Customers_Regions FOREIGN KEY(RegionID) REFERENCES dbo.Regions(RegionID)
);

CREATE TABLE dbo.Products(
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductName NVARCHAR(200) NOT NULL,
    Category NVARCHAR(100) NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1
);

CREATE TABLE dbo.Sales(
    SaleID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    UnitPrice DECIMAL(10,2) NOT NULL,
    DiscountPct DECIMAL(5,2) NOT NULL DEFAULT 0, -- e.g., 5.00 = 5%
    SaleDate DATE NOT NULL,
    CONSTRAINT FK_Sales_Customers FOREIGN KEY(CustomerID) REFERENCES dbo.Customers(CustomerID),
    CONSTRAINT FK_Sales_Products FOREIGN KEY(ProductID) REFERENCES dbo.Products(ProductID)
);

-- Helpful indexes
CREATE INDEX IX_Sales_SaleDate ON dbo.Sales(SaleDate);
CREATE INDEX IX_Sales_CustomerID ON dbo.Sales(CustomerID);
CREATE INDEX IX_Sales_ProductID ON dbo.Sales(ProductID);

-- Seed data
INSERT INTO dbo.Regions(RegionName) VALUES
('North'), ('South'), ('East'), ('West');

INSERT INTO dbo.Customers(CustomerName, Email, RegionID) VALUES
('Acme Retailers','contact@acmeretail.com',1),
('Bright Traders','info@bright.com',2),
('Crest Industries','hello@crest.io',3),
('Delta Wholesale','sales@deltawholesale.com',4),
('Everest Stores','support@evereststores.com',1),
('Futura Mart','care@futuramart.com',2);

INSERT INTO dbo.Products(ProductName, Category, UnitPrice) VALUES
('Alpha Phone','Electronics',399.00),
('Beta Laptop','Electronics',899.00),
('Gamma Headphones','Accessories',79.00),
('Delta Backpack','Accessories',49.00),
('Eco Bottle','Home',15.00),
('Fibre Chair','Home',119.00);

-- Sample sales across months
DECLARE @d1 DATE='2025-01-01', @d2 DATE='2025-06-30';

;WITH dates AS(
    SELECT CAST(@d1 AS DATE) AS dt
    UNION ALL
    SELECT DATEADD(DAY,1,dt) FROM dates WHERE dt < @d2
)
INSERT INTO dbo.Sales(CustomerID, ProductID, Quantity, UnitPrice, DiscountPct, SaleDate)
SELECT
    ABS(CHECKSUM(NEWID()))%6 + 1 AS CustomerID,
    ABS(CHECKSUM(NEWID()))%6 + 1 AS ProductID,
    ABS(CHECKSUM(NEWID()))%5 + 1 AS Qty,
    p.UnitPrice,
    CASE WHEN ABS(CHECKSUM(NEWID()))%10=0 THEN 10.00 ELSE 0.00 END AS DiscountPct,
    d.dt
FROM dates d
CROSS APPLY (SELECT ProductID, UnitPrice FROM dbo.Products WHERE ProductID = (ABS(CHECKSUM(NEWID()))%6 + 1)) p
OPTION (MAXRECURSION 32767);

-- View: Sales summary per day/product/region
IF OBJECT_ID('dbo.v_SalesSummary','V') IS NOT NULL DROP VIEW dbo.v_SalesSummary;
GO
CREATE VIEW dbo.v_SalesSummary AS
SELECT
    s.SaleDate,
    r.RegionName,
    c.CustomerName,
    p.ProductName,
    p.Category,
    s.Quantity,
    s.UnitPrice,
    s.DiscountPct,
    CAST(s.Quantity * s.UnitPrice * (1 - s.DiscountPct/100.0) AS DECIMAL(12,2)) AS NetSales
FROM dbo.Sales s
JOIN dbo.Customers c ON s.CustomerID=c.CustomerID
JOIN dbo.Products p ON s.ProductID=p.ProductID
JOIN dbo.Regions r ON c.RegionID=r.RegionID;
GO

-- KPI Stored Procedure: date range + optional region/category
IF OBJECT_ID('dbo.sp_GetSalesKPI','P') IS NOT NULL DROP PROCEDURE dbo.sp_GetSalesKPI;
GO
CREATE PROCEDURE dbo.sp_GetSalesKPI
    @StartDate DATE,
    @EndDate   DATE,
    @Region    NVARCHAR(100)=NULL,
    @Category  NVARCHAR(100)=NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH f AS(
        SELECT *
        FROM dbo.v_SalesSummary
        WHERE SaleDate BETWEEN @StartDate AND @EndDate
          AND (@Region IS NULL OR RegionName=@Region)
          AND (@Category IS NULL OR Category=@Category)
    )
    SELECT
        SUM(NetSales) AS TotalRevenue,
        SUM(Quantity) AS UnitsSold,
        COUNT(DISTINCT CustomerName) AS UniqueCustomers,
        COUNT(*) AS OrderLines
    FROM f;

    -- Top products
    SELECT TOP 10 ProductName, SUM(NetSales) AS Revenue
    FROM f
    GROUP BY ProductName
    ORDER BY Revenue DESC;

    -- Revenue trend
    SELECT CONVERT(DATE, SaleDate) AS [Date], SUM(NetSales) AS Revenue
    FROM f
    GROUP BY CONVERT(DATE, SaleDate)
    ORDER BY [Date];
END
GO
