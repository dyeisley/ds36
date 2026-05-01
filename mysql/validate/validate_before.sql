-- DVD Store 3.6 - Pre-Test Validation Queries (MySQL)
-- Run this BEFORE starting the benchmark to capture baseline metrics
-- Compare with validate_after.sql results to verify test harness functionality

USE DS3;

-- Create validation metrics table if it doesn't exist
CREATE TABLE IF NOT EXISTS VALIDATION_METRICS (
    metric_name VARCHAR(100) NOT NULL,
    metric_value BIGINT,
    snapshot_date DATETIME DEFAULT NOW()
);

-- Create top reviews snapshot table if it doesn't exist
CREATE TABLE IF NOT EXISTS VALIDATION_TOP_REVIEWS (
    rank_position INT NOT NULL,
    review_id INT NOT NULL,
    prod_id INT NOT NULL,
    total_helpfulness INT NOT NULL,
    snapshot_date DATETIME DEFAULT NOW()
);

-- Create popular products review counts snapshot table if it doesn't exist
CREATE TABLE IF NOT EXISTS VALIDATION_POPULAR_REVIEWS (
    prod_id INT NOT NULL,
    title VARCHAR(50) NOT NULL,
    review_count INT NOT NULL,
    snapshot_date DATETIME DEFAULT NOW()
);

-- Clear previous baseline metrics
DELETE FROM VALIDATION_METRICS;
DELETE FROM VALIDATION_TOP_REVIEWS;
DELETE FROM VALIDATION_POPULAR_REVIEWS;

SELECT '========================================================================';
SELECT 'DVD Store 3.6 - Pre-Test Validation';
SELECT CONCAT('Timestamp: ', NOW());
SELECT '========================================================================';

-- =======================================================================
-- TABLE ROW COUNTS
-- Purpose: Establish baseline row counts for all tables
-- =======================================================================
SELECT '--- TABLE ROW COUNTS (Baseline) ---';
SELECT 'Verifying: Initial data volume before benchmark execution';
SELECT '';

SELECT
    RPAD('CUSTOMERS', 20) AS TableName,
    LPAD(COUNT(*), 12) AS RowCount
FROM CUSTOMERS1
UNION ALL
SELECT RPAD('CUST_HIST', 20), LPAD(COUNT(*), 12) FROM CUST_HIST1
UNION ALL
SELECT RPAD('PRODUCTS', 20), LPAD(COUNT(*), 12) FROM PRODUCTS1
UNION ALL
SELECT RPAD('ORDERS', 20), LPAD(COUNT(*), 12) FROM ORDERS1
UNION ALL
SELECT RPAD('ORDERLINES', 20), LPAD(COUNT(*), 12) FROM ORDERLINES1
UNION ALL
SELECT RPAD('INVENTORY', 20), LPAD(COUNT(*), 12) FROM INVENTORY1
UNION ALL
SELECT RPAD('REVIEWS', 20), LPAD(COUNT(*), 12) FROM REVIEWS1
UNION ALL
SELECT RPAD('REVIEWS_HELPFULNESS', 20), LPAD(COUNT(*), 12) FROM REVIEWS_HELPFULNESS1
UNION ALL
SELECT RPAD('MEMBERSHIP', 20), LPAD(COUNT(*), 12) FROM MEMBERSHIP1
UNION ALL
SELECT RPAD('REORDER', 20), LPAD(COUNT(*), 12) FROM REORDER1
ORDER BY TableName;

-- Save table counts to metrics table
SELECT 'Saving baseline metrics...';
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
UNION ALL SELECT 'MAX_PROD_ID', IFNULL(MAX(PROD_ID), 0) FROM PRODUCTS1;
SELECT 'Baseline metrics saved.';

SELECT '';
SELECT '';

-- =======================================================================
-- TOP 5 CUSTOMERS BY PURCHASE HISTORY
-- Purpose: Verify CUST_HIST table is populated correctly
-- Expected: Shows customers with most products ordered
-- COMMENTED OUT: Performance issue on large databases
-- =======================================================================
-- SELECT '--- TOP 5 CUSTOMERS BY PURCHASE HISTORY (CUST_HIST Verification) ---';
-- SELECT 'Verifying: Customer purchase history tracking';
-- SELECT 'Expected: After test, counts should increase as customers place orders';
-- SELECT '';
--
-- SELECT
--     ch.CUSTOMERID AS CustID,
--     c.FIRSTNAME AS FirstName,
--     c.LASTNAME AS LastName,
--     COUNT(*) AS Products
-- FROM CUST_HIST1 ch
-- JOIN CUSTOMERS1 c ON ch.CUSTOMERID = c.CUSTOMERID
-- GROUP BY ch.CUSTOMERID, c.FIRSTNAME, c.LASTNAME
-- ORDER BY COUNT(*) DESC
-- LIMIT 5;
--
-- SELECT '';
-- SELECT '';

-- =======================================================================
-- TOP 10 INVENTORY BY SALES
-- Purpose: Verify GetSkewedProductId distribution
-- Expected: Products divisible by 10000 should have higher sales
-- =======================================================================
SELECT '--- TOP 10 INVENTORY BY SALES (GetSkewedProductId Verification) ---';
SELECT 'Verifying: Skewed product selection (every 10,000th product should be popular)';
SELECT 'Expected: After test, PROD_ID values divisible by 10000 should appear in top sales';
SELECT '';

SELECT
    LPAD(i.PROD_ID, 8) AS PROD_ID,
    RPAD(p.TITLE, 40) AS TITLE,
    LPAD(i.SALES, 10) AS SALES,
    RPAD(CASE
        WHEN i.PROD_ID % 10000 = 0 THEN '**POPULAR**'
        ELSE ''
    END, 12) AS IsPopularProduct
FROM INVENTORY1 i
JOIN PRODUCTS1 p ON i.PROD_ID = p.PROD_ID
ORDER BY i.SALES DESC
LIMIT 10;

SELECT '';
SELECT '';

-- =======================================================================
-- TOP 20 REORDER BY QUANTITY
-- Purpose: Verify restock trigger functionality
-- Expected: Products with high sales should trigger restocking
-- =======================================================================
SELECT '--- TOP 20 REORDER BY QUANTITY (Restock Trigger Verification) ---';
SELECT 'Verifying: Restock trigger fires when inventory drops below threshold';
SELECT 'Expected: After test, reorder table should show restocking activity';
SELECT '';

SELECT
    LPAD(r.PROD_ID, 8) AS PROD_ID,
    RPAD(p.TITLE, 40) AS TITLE,
    LPAD(SUM(r.QUAN_REORDERED), 15) AS TOTAL_REORDERED,
    LPAD(COUNT(*), 13) AS RESTOCK_COUNT,
    MAX(r.DATE_REORDERED) AS LAST_RESTOCK_DATE
FROM REORDER1 r
JOIN PRODUCTS1 p ON r.PROD_ID = p.PROD_ID
GROUP BY r.PROD_ID, p.TITLE
ORDER BY SUM(r.QUAN_REORDERED) DESC
LIMIT 20;

SELECT '';
SELECT '';

-- =======================================================================
-- TOP 10 REVIEWS BY HELPFULNESS
-- Purpose: Verify review and helpfulness operations
-- Expected: Reviews should accumulate helpfulness ratings
-- NOTE: Use --ds2_mode=y to verify review removal (no new reviews, no helpfulness updates)
-- NOTE: Requires index on TOTAL_HELPFULNESS DESC for performance (created by index scripts)
-- =======================================================================
SELECT '--- TOP 10 REVIEWS BY HELPFULNESS (Review Operations Verification) ---';
SELECT 'Verifying: New reviews created and helpfulness ratings accumulated';
SELECT '';

SELECT
    LPAD(@rownum := @rownum + 1, 4) AS `Rank`,
    LPAD(REVIEW_ID, 10) AS `ReviewID`,
    LPAD(PROD_ID, 10) AS `ProdID`,
    LPAD(TOTAL_HELPFULNESS, 12) AS `Helpfulness`,
    RPAD(CASE WHEN PROD_ID % 10000 = 0 THEN '**POPULAR**' ELSE '' END, 12) AS `Popular`
FROM REVIEWS1
CROSS JOIN (SELECT @rownum := 0) AS init
ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID
LIMIT 10;

-- Save top reviews to snapshot table
INSERT INTO VALIDATION_TOP_REVIEWS (rank_position, review_id, prod_id, total_helpfulness)
SELECT
    @rownum := @rownum + 1 AS rank_position,
    REVIEW_ID,
    PROD_ID,
    TOTAL_HELPFULNESS
FROM REVIEWS1
CROSS JOIN (SELECT @rownum := 0) AS init
ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID
LIMIT 10;

SELECT '';
SELECT '';

-- Count reviews for popular products (ID % 10000 = 0)
SELECT 'Reviews for Popular Products (ID % 10000 = 0):';
SELECT '';

SELECT
    LPAD(p.PROD_ID, 8) AS PROD_ID,
    RPAD(p.TITLE, 40) AS TITLE,
    LPAD(COUNT(r.REVIEW_ID), 12) AS ReviewCount
FROM PRODUCTS1 p
LEFT JOIN REVIEWS1 r ON p.PROD_ID = r.PROD_ID
WHERE p.PROD_ID % 10000 = 0
GROUP BY p.PROD_ID, p.TITLE
ORDER BY COUNT(r.REVIEW_ID) DESC, p.PROD_ID;

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


-- =======================================================================
-- ADDITIONAL BASELINE METRICS
-- =======================================================================
SELECT '--- ADDITIONAL BASELINE METRICS ---';

-- Manager-created products, special products, total helpfulness, max customer ID
SET @manager_products = (SELECT COUNT(*) FROM PRODUCTS1 WHERE PRICE - FLOOR(PRICE) = 0.01);
SET @special_products = (SELECT COUNT(*) FROM PRODUCTS1 WHERE SPECIAL = 1);
SET @total_helpfulness = (SELECT IFNULL(SUM(TOTAL_HELPFULNESS), 0) FROM REVIEWS1);
SET @max_customerid = (SELECT MAX(CUSTOMERID) FROM CUSTOMERS1);

SELECT CONCAT('Manager-Created Products (price .01): ', @manager_products);
SELECT CONCAT('Products Marked Special (SPECIAL=1): ', @special_products);
SELECT '  ** Record this count to compare with post-test results **';

SELECT 'Top 10 Newest Customers (highest CUSTOMERID):';
SELECT
    LPAD(CUSTOMERID, 10) AS CUSTOMERID,
    RPAD(FIRSTNAME, 20) AS FIRSTNAME,
    RPAD(LASTNAME, 20) AS LASTNAME,
    RPAD(CITY, 20) AS CITY
FROM CUSTOMERS1
ORDER BY CUSTOMERID DESC
LIMIT 10;

-- Save additional metrics to table
INSERT INTO VALIDATION_METRICS (metric_name, metric_value)
VALUES ('MANAGER_PRODUCTS_COUNT', @manager_products),
       ('SPECIAL_PRODUCTS_COUNT', @special_products),
       ('TOTAL_HELPFULNESS', @total_helpfulness),
       ('MAX_CUSTOMERID', @max_customerid);

SELECT '========================================================================';
SELECT 'Pre-Test Validation Complete';
SELECT 'Baseline metrics saved to VALIDATION_METRICS table';
SELECT 'Run validate_after.sql to compare with post-test results';
SELECT '========================================================================';
