-- DVD Store 3.6 - Pre-Test Validation Queries (SQL Server)
-- Run this BEFORE starting the benchmark to capture baseline metrics
-- Compare with validate_after.sql results to verify test harness functionality

USE DS3;
GO

-- Create validation metrics table if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'VALIDATION_METRICS') AND type = 'U')
BEGIN
    CREATE TABLE VALIDATION_METRICS (
        metric_name VARCHAR(100) NOT NULL,
        metric_value BIGINT,
        snapshot_date DATETIME DEFAULT GETDATE()
    );
END
GO

-- Create top reviews snapshot table if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'VALIDATION_TOP_REVIEWS') AND type = 'U')
BEGIN
    CREATE TABLE VALIDATION_TOP_REVIEWS (
        rank_position INT NOT NULL,
        review_id INT NOT NULL,
        prod_id INT NOT NULL,
        total_helpfulness INT NOT NULL,
        snapshot_date DATETIME DEFAULT GETDATE()
    );
END
GO

-- Create popular products review counts snapshot table if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'VALIDATION_POPULAR_REVIEWS') AND type = 'U')
BEGIN
    CREATE TABLE VALIDATION_POPULAR_REVIEWS (
        prod_id INT NOT NULL,
        title VARCHAR(50) NOT NULL,
        review_count INT NOT NULL,
        snapshot_date DATETIME DEFAULT GETDATE()
    );
END
GO

-- Clear previous baseline metrics
DELETE FROM VALIDATION_METRICS;
DELETE FROM VALIDATION_TOP_REVIEWS;
DELETE FROM VALIDATION_POPULAR_REVIEWS;
GO

PRINT '========================================================================';
PRINT 'DVD Store 3.6 - Pre-Test Validation';
PRINT 'Timestamp: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '========================================================================';
PRINT '';

-- =======================================================================
-- TABLE ROW COUNTS
-- Purpose: Establish baseline row counts for all tables
-- =======================================================================
PRINT '--- TABLE ROW COUNTS (Baseline) ---';
PRINT 'Verifying: Initial data volume before benchmark execution';
PRINT '';

SELECT 'CUSTOMERS' AS TableName, COUNT(*) AS [RowCount] FROM CUSTOMERS1
UNION ALL
SELECT 'CUST_HIST', COUNT(*) FROM CUST_HIST1
UNION ALL
SELECT 'PRODUCTS', COUNT(*) FROM PRODUCTS1
UNION ALL
SELECT 'ORDERS', COUNT(*) FROM ORDERS1
UNION ALL
SELECT 'ORDERLINES', COUNT(*) FROM ORDERLINES1
UNION ALL
SELECT 'INVENTORY', COUNT(*) FROM INVENTORY1
UNION ALL
SELECT 'REVIEWS', COUNT(*) FROM REVIEWS1
UNION ALL
SELECT 'REVIEWS_HELPFULNESS', COUNT(*) FROM REVIEWS_HELPFULNESS1
UNION ALL
SELECT 'MEMBERSHIP', COUNT(*) FROM MEMBERSHIP1
UNION ALL
SELECT 'REORDER', COUNT(*) FROM REORDER1
ORDER BY TableName;

-- Save table counts to metrics table
INSERT INTO VALIDATION_METRICS (metric_name, metric_value)
SELECT 'CUSTOMERS_COUNT', COUNT(*) FROM CUSTOMERS1
UNION ALL SELECT 'CUST_HIST_COUNT', COUNT(*) FROM CUST_HIST1
UNION ALL SELECT 'PRODUCTS_COUNT', COUNT(*) FROM PRODUCTS1
UNION ALL SELECT 'ORDERS_COUNT', COUNT(*) FROM ORDERS1
UNION ALL SELECT 'ORDERLINES_COUNT', COUNT(*) FROM ORDERLINES1
UNION ALL SELECT 'INVENTORY_COUNT', COUNT(*) FROM INVENTORY1
UNION ALL SELECT 'REVIEWS_COUNT', COUNT(*) FROM REVIEWS1
UNION ALL SELECT 'REVIEWS_HELPFULNESS_COUNT', COUNT(*) FROM REVIEWS_HELPFULNESS1
UNION ALL SELECT 'MEMBERSHIP_COUNT', COUNT(*) FROM MEMBERSHIP1
UNION ALL SELECT 'REORDER_COUNT', COUNT(*) FROM REORDER1
UNION ALL SELECT 'MAX_PROD_ID', ISNULL(MAX(PROD_ID), 0) FROM PRODUCTS1;

PRINT '';
PRINT '';

-- =======================================================================
-- TOP 5 CUSTOMERS BY PURCHASE HISTORY
-- Purpose: Verify CUST_HIST table is populated correctly
-- Expected: Shows customers with most products ordered
-- =======================================================================
PRINT '--- TOP 5 CUSTOMERS BY PURCHASE HISTORY (CUST_HIST Verification) ---';
PRINT 'Verifying: Customer purchase history tracking';
PRINT 'Expected: After test, counts should increase as customers place orders';
PRINT '';

SELECT TOP 5 WITH TIES
    RIGHT(REPLICATE(' ', 10) + CAST(ch.CUSTOMERID AS VARCHAR), 10) AS [CustID],
    LEFT(c.FIRSTNAME + REPLICATE(' ', 15), 15) AS [FirstName],
    LEFT(c.LASTNAME + REPLICATE(' ', 15), 15) AS [LastName],
    RIGHT(REPLICATE(' ', 8) + CAST(COUNT(*) AS VARCHAR), 8) AS [Products]
FROM CUST_HIST1 ch
JOIN CUSTOMERS1 c ON ch.CUSTOMERID = c.CUSTOMERID
GROUP BY ch.CUSTOMERID, c.FIRSTNAME, c.LASTNAME
ORDER BY COUNT(*) DESC;

PRINT '';
PRINT '';

-- =======================================================================
-- TOP 10 INVENTORY BY SALES
-- Purpose: Verify GetSkewedProductId distribution
-- Expected: Products divisible by 10000 should have higher sales
-- =======================================================================
PRINT '--- TOP 10 INVENTORY BY SALES (GetSkewedProductId Verification) ---';
PRINT 'Verifying: Skewed product selection (every 10,000th product should be popular)';
PRINT 'Expected: After test, PROD_ID values divisible by 10000 should appear in top sales';
PRINT '';

SELECT TOP 10
    i.PROD_ID,
    p.TITLE,
    i.SALES,
    CASE
        WHEN i.PROD_ID % 10000 = 0 THEN '**POPULAR**'
        ELSE ''
    END AS IsPopularProduct
FROM INVENTORY1 i
JOIN PRODUCTS1 p ON i.PROD_ID = p.PROD_ID
ORDER BY i.SALES DESC;

PRINT '';
PRINT '';

-- =======================================================================
-- TOP 20 REORDER BY QUANTITY
-- Purpose: Verify restock trigger functionality
-- Expected: Products with high sales should trigger restocking
-- =======================================================================
PRINT '--- TOP 20 REORDER BY QUANTITY (Restock Trigger Verification) ---';
PRINT 'Verifying: Restock trigger fires when inventory drops below threshold';
PRINT 'Expected: After test, reorder table should show restocking activity';
PRINT '';

SELECT TOP 20
    r.PROD_ID,
    p.TITLE,
    SUM(r.QUAN_REORDERED) AS TOTAL_REORDERED,
    COUNT(*) AS RESTOCK_COUNT,
    MAX(r.DATE_REORDERED) AS LAST_RESTOCK_DATE
FROM REORDER1 r
JOIN PRODUCTS1 p ON r.PROD_ID = p.PROD_ID
GROUP BY r.PROD_ID, p.TITLE
ORDER BY SUM(r.QUAN_REORDERED) DESC;

PRINT '';
PRINT '';

-- =======================================================================
-- TOP 10 REVIEWS BY HELPFULNESS
-- Purpose: Verify review and helpfulness operations
-- Expected: Reviews should accumulate helpfulness ratings
-- NOTE: Use --ds2_mode=y to verify review removal (no new reviews, no helpfulness updates)
-- =======================================================================
PRINT '--- TOP 10 REVIEWS BY HELPFULNESS (Review Operations Verification) ---';
PRINT 'Verifying: New reviews created and helpfulness ratings accumulated';
PRINT 'Expected: After test, reviews should show positive helpfulness scores';
PRINT 'NOTE: Use --ds2_mode=y to verify review removal (no adds, no helpfulness updates)';
PRINT '';

SELECT TOP 10
    RIGHT(REPLICATE(' ', 5) + CAST(ROW_NUMBER() OVER (ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID) AS VARCHAR), 5) AS [Rank],
    RIGHT(REPLICATE(' ', 10) + CAST(REVIEW_ID AS VARCHAR), 10) AS [ReviewID],
    RIGHT(REPLICATE(' ', 10) + CAST(PROD_ID AS VARCHAR), 10) AS [ProdID],
    RIGHT(REPLICATE(' ', 12) + CAST(TOTAL_HELPFULNESS AS VARCHAR), 12) AS [Helpfulness],
    LEFT(CASE WHEN PROD_ID % 10000 = 0 THEN '**POPULAR**' ELSE '' END + REPLICATE(' ', 12), 12) AS [Popular]
FROM REVIEWS1
ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID;

-- Save top reviews to snapshot table
INSERT INTO VALIDATION_TOP_REVIEWS (rank_position, review_id, prod_id, total_helpfulness)
SELECT TOP 10
    ROW_NUMBER() OVER (ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID) AS rank_position,
    REVIEW_ID,
    PROD_ID,
    TOTAL_HELPFULNESS
FROM REVIEWS1
ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID;

PRINT '';

-- Count reviews for popular products (ID % 10000 = 0)
PRINT '';
PRINT 'Reviews for Popular Products (ID % 10000 = 0):';
PRINT '';

SELECT
    p.PROD_ID,
    p.TITLE,
    COUNT(r.REVIEW_ID) AS ReviewCount
FROM PRODUCTS1 p
LEFT JOIN REVIEWS1 r ON p.PROD_ID = r.PROD_ID
WHERE p.PROD_ID % 10000 = 0
GROUP BY p.PROD_ID, p.TITLE
ORDER BY ReviewCount DESC, p.PROD_ID;

-- Save popular product review counts to snapshot table
INSERT INTO VALIDATION_POPULAR_REVIEWS (prod_id, title, review_count)
SELECT
    p.PROD_ID,
    p.TITLE,
    COUNT(r.REVIEW_ID)
FROM PRODUCTS1 p
LEFT JOIN REVIEWS1 r ON p.PROD_ID = r.PROD_ID
WHERE p.PROD_ID % 10000 = 0
GROUP BY p.PROD_ID, p.TITLE;

PRINT '';
PRINT '';

-- =======================================================================
-- ADDITIONAL BASELINE METRICS
-- =======================================================================
PRINT '--- ADDITIONAL BASELINE METRICS ---';
PRINT '';

-- Manager-created products (price ends in .01)
DECLARE @ManagerProducts INT;
SELECT @ManagerProducts = COUNT(*)
FROM PRODUCTS1
WHERE PRICE - FLOOR(PRICE) = 0.01;
PRINT 'Manager-Created Products (price .01): ' + CAST(@ManagerProducts AS VARCHAR);

-- Products marked as SPECIAL
DECLARE @SpecialProducts INT;
SELECT @SpecialProducts = COUNT(*)
FROM PRODUCTS1
WHERE SPECIAL = 1;
PRINT 'Products Marked Special (SPECIAL=1): ' + CAST(@SpecialProducts AS VARCHAR);
PRINT '  ** Record this count to compare with post-test results **';

-- Total helpfulness across all reviews
DECLARE @TotalHelpfulness BIGINT;
SELECT @TotalHelpfulness = ISNULL(SUM(TOTAL_HELPFULNESS), 0)
FROM REVIEWS1;

-- Top 10 newest customers (by CUSTOMERID)
DECLARE @MaxCustomerID INT;
SELECT @MaxCustomerID = MAX(CUSTOMERID) FROM CUSTOMERS1;

PRINT '';
PRINT 'Top 10 Newest Customers (highest CUSTOMERID):';
SELECT TOP 10
    RIGHT(REPLICATE(' ', 10) + CAST(CUSTOMERID AS VARCHAR), 10) AS [CustomerID],
    LEFT(FIRSTNAME + REPLICATE(' ', 20), 20) AS [FirstName],
    LEFT(LASTNAME + REPLICATE(' ', 20), 20) AS [LastName],
    LEFT(CITY + REPLICATE(' ', 20), 20) AS [City]
FROM CUSTOMERS1
ORDER BY CUSTOMERID DESC;

-- Save additional metrics to table
INSERT INTO VALIDATION_METRICS (metric_name, metric_value)
VALUES ('MANAGER_PRODUCTS_COUNT', @ManagerProducts),
       ('SPECIAL_PRODUCTS_COUNT', @SpecialProducts),
       ('TOTAL_HELPFULNESS', @TotalHelpfulness),
       ('MAX_CUSTOMERID', @MaxCustomerID);

PRINT '';
PRINT '========================================================================';
PRINT 'Pre-Test Validation Complete';
PRINT 'Baseline metrics saved to VALIDATION_METRICS table';
PRINT 'Run validate_after.sql to compare with post-test results';
PRINT '========================================================================';
