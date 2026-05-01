-- DVD Store 3.6 - Pre-Test Validation Queries (PostgreSQL)
-- Run this BEFORE starting the benchmark to capture baseline metrics
-- Compare with validate_after.sql results to verify test harness functionality

\c ds3

-- Create validation metrics table if it doesn't exist
CREATE TABLE IF NOT EXISTS VALIDATION_METRICS (
    metric_name VARCHAR(100) NOT NULL,
    metric_value BIGINT,
    snapshot_date TIMESTAMP DEFAULT NOW()
);

-- Create top reviews snapshot table if it doesn't exist
CREATE TABLE IF NOT EXISTS VALIDATION_TOP_REVIEWS (
    rank_position INT NOT NULL,
    review_id INT NOT NULL,
    prod_id INT NOT NULL,
    total_helpfulness INT NOT NULL,
    snapshot_date TIMESTAMP DEFAULT NOW()
);

-- Create popular products review counts snapshot table if it doesn't exist
CREATE TABLE IF NOT EXISTS VALIDATION_POPULAR_REVIEWS (
    prod_id INT NOT NULL,
    title VARCHAR(50) NOT NULL,
    review_count INT NOT NULL,
    snapshot_date TIMESTAMP DEFAULT NOW()
);

-- Clear previous baseline metrics
DELETE FROM VALIDATION_METRICS;
DELETE FROM VALIDATION_TOP_REVIEWS;
DELETE FROM VALIDATION_POPULAR_REVIEWS;

DO $$
BEGIN
    RAISE NOTICE '========================================================================';
    RAISE NOTICE 'DVD Store 3.6 - Pre-Test Validation';
    RAISE NOTICE 'Timestamp: %', NOW();
    RAISE NOTICE '========================================================================';
    RAISE NOTICE '';

    -- =======================================================================
    -- TABLE ROW COUNTS
    -- Purpose: Establish baseline row counts for all tables
    -- =======================================================================
    RAISE NOTICE '--- TABLE ROW COUNTS (Baseline) ---';
    RAISE NOTICE 'Verifying: Initial data volume before benchmark execution';
    RAISE NOTICE '';
END $$;

SELECT 'CUSTOMERS' AS TableName, COUNT(*) AS "RowCount" FROM CUSTOMERS1
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
UNION ALL SELECT 'MAX_PROD_ID', COALESCE(MAX(PROD_ID), 0) FROM PRODUCTS1;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '';

    -- =======================================================================
    -- TOP 5 CUSTOMERS BY PURCHASE HISTORY
    -- Purpose: Verify CUST_HIST table is populated correctly
    -- Expected: Shows customers with most products ordered
    -- =======================================================================
    RAISE NOTICE '--- TOP 5 CUSTOMERS BY PURCHASE HISTORY (CUST_HIST Verification) ---';
    RAISE NOTICE 'Verifying: Customer purchase history tracking';
    RAISE NOTICE 'Expected: After test, counts should increase as customers place orders';
    RAISE NOTICE '';
END $$;

SELECT
    LPAD(ch.CUSTOMERID::TEXT, 10, ' ') AS "CustID",
    RPAD(c.FIRSTNAME, 15, ' ') AS "FirstName",
    RPAD(c.LASTNAME, 15, ' ') AS "LastName",
    LPAD(COUNT(*)::TEXT, 8, ' ') AS "Products"
FROM CUST_HIST1 ch
JOIN CUSTOMERS1 c ON ch.CUSTOMERID = c.CUSTOMERID
GROUP BY ch.CUSTOMERID, c.FIRSTNAME, c.LASTNAME
ORDER BY COUNT(*) DESC
LIMIT 5;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '';

    -- =======================================================================
    -- TOP 10 INVENTORY BY SALES
    -- Purpose: Verify GetSkewedProductId distribution
    -- Expected: Products divisible by 10000 should have higher sales
    -- =======================================================================
    RAISE NOTICE '--- TOP 10 INVENTORY BY SALES (GetSkewedProductId Verification) ---';
    RAISE NOTICE 'Verifying: Skewed product selection (every 10,000th product should be popular)';
    RAISE NOTICE 'Expected: After test, PROD_ID values divisible by 10000 should appear in top sales';
    RAISE NOTICE '';
END $$;

SELECT
    i.PROD_ID,
    p.TITLE,
    i.SALES,
    CASE
        WHEN i.PROD_ID % 10000 = 0 THEN '**POPULAR**'
        ELSE ''
    END AS IsPopularProduct
FROM INVENTORY1 i
JOIN PRODUCTS1 p ON i.PROD_ID = p.PROD_ID
ORDER BY i.SALES DESC
LIMIT 10;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '';

    -- =======================================================================
    -- TOP 20 REORDER BY QUANTITY
    -- Purpose: Verify restock trigger functionality
    -- Expected: Products with high sales should trigger restocking
    -- =======================================================================
    RAISE NOTICE '--- TOP 20 REORDER BY QUANTITY (Restock Trigger Verification) ---';
    RAISE NOTICE 'Verifying: Restock trigger fires when inventory drops below threshold';
    RAISE NOTICE 'Expected: After test, reorder table should show restocking activity';
    RAISE NOTICE '';
END $$;

SELECT
    r.PROD_ID,
    p.TITLE,
    SUM(r.QUAN_REORDERED) AS TOTAL_REORDERED,
    COUNT(*) AS RESTOCK_COUNT,
    MAX(r.DATE_REORDERED) AS LAST_RESTOCK_DATE
FROM REORDER1 r
JOIN PRODUCTS1 p ON r.PROD_ID = p.PROD_ID
GROUP BY r.PROD_ID, p.TITLE
ORDER BY SUM(r.QUAN_REORDERED) DESC
LIMIT 20;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '';

    -- =======================================================================
    -- TOP 10 REVIEWS BY HELPFULNESS
    -- Purpose: Verify review and helpfulness operations
    -- Expected: Reviews should accumulate helpfulness ratings
    -- NOTE: Use --ds2_mode=y to verify review removal (no new reviews, no helpfulness updates)
    -- =======================================================================
    RAISE NOTICE '--- TOP 10 REVIEWS BY HELPFULNESS (Review Operations Verification) ---';
    RAISE NOTICE 'Verifying: New reviews created and helpfulness ratings accumulated';
    RAISE NOTICE 'Expected: After test, reviews should show positive helpfulness scores';
    RAISE NOTICE 'NOTE: Use --ds2_mode=y to verify review removal (no adds, no helpfulness updates)';
    RAISE NOTICE '';
END $$;

SELECT
    LPAD(ROW_NUMBER() OVER (ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID)::TEXT, 5) AS "Rank",
    LPAD(REVIEW_ID::TEXT, 10) AS "ReviewID",
    LPAD(PROD_ID::TEXT, 10) AS "ProdID",
    LPAD(TOTAL_HELPFULNESS::TEXT, 12) AS "Helpfulness",
    RPAD(CASE WHEN PROD_ID % 10000 = 0 THEN '**POPULAR**' ELSE '' END, 12) AS "Popular"
FROM REVIEWS1
ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID
LIMIT 10;

-- Save top reviews to snapshot table
INSERT INTO VALIDATION_TOP_REVIEWS (rank_position, review_id, prod_id, total_helpfulness)
SELECT
    ROW_NUMBER() OVER (ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID) AS rank_position,
    REVIEW_ID,
    PROD_ID,
    TOTAL_HELPFULNESS
FROM REVIEWS1
ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID
LIMIT 10;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Reviews for Popular Products (ID %% 10000 = 0):';
    RAISE NOTICE '';
END $$;

SELECT
    p.PROD_ID,
    p.TITLE,
    COUNT(r.REVIEW_ID) AS "ReviewCount"
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
    COUNT(r.REVIEW_ID)::INT
FROM PRODUCTS1 p
LEFT JOIN REVIEWS1 r ON p.PROD_ID = r.PROD_ID
WHERE p.PROD_ID % 10000 = 0
GROUP BY p.PROD_ID, p.TITLE;

DO $$
DECLARE
    v_manager_products INT;
    v_special_products INT;
    v_total_helpfulness BIGINT;
    v_max_customerid INT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '';

    -- =======================================================================
    -- ADDITIONAL BASELINE METRICS
    -- =======================================================================
    RAISE NOTICE '--- ADDITIONAL BASELINE METRICS ---';
    RAISE NOTICE '';

    -- Manager-created products (price ends in .01)
    SELECT COUNT(*) INTO v_manager_products
    FROM PRODUCTS1
    WHERE (PRICE - FLOOR(PRICE)) = 0.01;
    RAISE NOTICE 'Manager-Created Products (price .01): %', v_manager_products;

    -- Products marked as SPECIAL
    SELECT COUNT(*) INTO v_special_products
    FROM PRODUCTS1
    WHERE SPECIAL = 1;
    RAISE NOTICE 'Products Marked Special (SPECIAL=1): %', v_special_products;
    RAISE NOTICE '  ** Record this count to compare with post-test results **';

    -- Total helpfulness
    SELECT COALESCE(SUM(TOTAL_HELPFULNESS), 0) INTO v_total_helpfulness
    FROM REVIEWS1;

    -- Max customer ID
    SELECT MAX(CUSTOMERID) INTO v_max_customerid
    FROM CUSTOMERS1;

    RAISE NOTICE '';
    RAISE NOTICE 'Top 10 Newest Customers (highest CUSTOMERID):';

    -- Save additional metrics to table
    INSERT INTO VALIDATION_METRICS (metric_name, metric_value)
    VALUES ('MANAGER_PRODUCTS_COUNT', v_manager_products),
           ('SPECIAL_PRODUCTS_COUNT', v_special_products),
           ('TOTAL_HELPFULNESS', v_total_helpfulness),
           ('MAX_CUSTOMERID', v_max_customerid);
END $$;

SELECT
    CUSTOMERID,
    FIRSTNAME,
    LASTNAME,
    CITY
FROM CUSTOMERS1
ORDER BY CUSTOMERID DESC
LIMIT 10;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================================================';
    RAISE NOTICE 'Pre-Test Validation Complete';
    RAISE NOTICE 'Baseline metrics saved to VALIDATION_METRICS table';
    RAISE NOTICE 'Run validate_after.sql to compare with post-test results';
    RAISE NOTICE '========================================================================';
END $$;
