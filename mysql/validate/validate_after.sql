-- DVD Store 3.6 - Post-Test Validation Queries (MySQL)
-- Run this AFTER completing the benchmark to measure changes
-- Compare with validate_before.sql results to verify test harness functionality

USE DS3;

SELECT '========================================================================';
SELECT 'DVD Store 3.6 - Post-Test Validation';
SELECT CONCAT('Timestamp: ', NOW());
SELECT '========================================================================';

-- =======================================================================
-- TABLE ROW COUNTS
-- Purpose: Show data growth during benchmark
-- =======================================================================
SELECT '--- TABLE ROW COUNTS (Post-Test) ---';
SELECT 'Verifying: Data volume changes during benchmark execution';
SELECT 'Expected: CUSTOMERS, ORDERS, ORDERLINES, REVIEWS should increase';
SELECT 'Expected: PRODUCTS may increase if managers enabled';
SELECT 'Expected: REVIEWS may decrease if managers removed unhelpful reviews';
SELECT '';

-- Display current counts with deltas from baseline
SELECT
    RPAD(REPLACE(m.metric_name, '_COUNT', ''), 20) AS `Table`,
    LPAD(m.metric_value, 12) AS `Pre`,
    LPAD(CASE REPLACE(m.metric_name, '_COUNT', '')
        WHEN 'CUSTOMERS' THEN (SELECT COUNT(*) FROM CUSTOMERS1)
        WHEN 'CUST_HIST' THEN (SELECT COUNT(*) FROM CUST_HIST1)
        WHEN 'PRODUCTS' THEN (SELECT COUNT(*) FROM PRODUCTS1)
        WHEN 'ORDERS' THEN (SELECT COUNT(*) FROM ORDERS1)
        WHEN 'ORDERLINES' THEN (SELECT COUNT(*) FROM ORDERLINES1)
        WHEN 'INVENTORY' THEN (SELECT COUNT(*) FROM INVENTORY1)
        WHEN 'REVIEWS' THEN (SELECT COUNT(*) FROM REVIEWS1)
        WHEN 'REVIEWS_HELPFULNESS' THEN (SELECT COUNT(*) FROM REVIEWS_HELPFULNESS1)
        WHEN 'MEMBERSHIP' THEN (SELECT COUNT(*) FROM MEMBERSHIP1)
        WHEN 'REORDER' THEN (SELECT COUNT(*) FROM REORDER1)
    END, 12) AS `Post`,
    LPAD(CASE REPLACE(m.metric_name, '_COUNT', '')
        WHEN 'CUSTOMERS' THEN (SELECT COUNT(*) FROM CUSTOMERS1) - m.metric_value
        WHEN 'CUST_HIST' THEN (SELECT COUNT(*) FROM CUST_HIST1) - m.metric_value
        WHEN 'PRODUCTS' THEN (SELECT COUNT(*) FROM PRODUCTS1) - m.metric_value
        WHEN 'ORDERS' THEN (SELECT COUNT(*) FROM ORDERS1) - m.metric_value
        WHEN 'ORDERLINES' THEN (SELECT COUNT(*) FROM ORDERLINES1) - m.metric_value
        WHEN 'INVENTORY' THEN (SELECT COUNT(*) FROM INVENTORY1) - m.metric_value
        WHEN 'REVIEWS' THEN (SELECT COUNT(*) FROM REVIEWS1) - m.metric_value
        WHEN 'REVIEWS_HELPFULNESS' THEN (SELECT COUNT(*) FROM REVIEWS_HELPFULNESS1) - m.metric_value
        WHEN 'MEMBERSHIP' THEN (SELECT COUNT(*) FROM MEMBERSHIP1) - m.metric_value
        WHEN 'REORDER' THEN (SELECT COUNT(*) FROM REORDER1) - m.metric_value
    END, 12) AS `Delta`
FROM VALIDATION_METRICS m
WHERE m.metric_name LIKE '%_COUNT'
    AND m.metric_name NOT IN ('MANAGER_PRODUCTS_COUNT', 'SPECIAL_PRODUCTS_COUNT')
ORDER BY `Table`;

SELECT '';
SELECT '';

-- =======================================================================
-- TOP 5 CUSTOMERS BY PURCHASE HISTORY
-- Purpose: Verify CUST_HIST table growth during benchmark
-- Expected: Shows customers with most products ordered
-- COMMENTED OUT: Performance issue on large databases
-- =======================================================================
-- SELECT '--- TOP 5 CUSTOMERS BY PURCHASE HISTORY (CUST_HIST Verification) ---';
-- SELECT 'Verifying: Customer purchase history has grown during benchmark';
-- SELECT 'Expected: Product counts should be higher than pre-test';
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
-- Expected: Products divisible by 10000 should dominate top sales
-- =======================================================================
SELECT '--- TOP 10 INVENTORY BY SALES (GetSkewedProductId Verification) ---';
SELECT 'Verifying: Skewed product selection worked correctly';
SELECT 'Expected: Products divisible by 10000 should appear in top 10 with higher SALES';
SELECT 'Expected: SALES values should be significantly higher than pre-test baseline';
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

-- Summary statistics on popular vs non-popular products
SET @popular_sales = (SELECT SUM(SALES) FROM INVENTORY1 WHERE PROD_ID % 10000 = 0);
SET @popular_count = (SELECT COUNT(*) FROM INVENTORY1 WHERE PROD_ID % 10000 = 0);
SET @non_popular_sales = (SELECT SUM(SALES) FROM INVENTORY1 WHERE PROD_ID % 10000 != 0);
SET @non_popular_count = (SELECT COUNT(*) FROM INVENTORY1 WHERE PROD_ID % 10000 != 0);

SELECT 'GetSkewedProductId Effectiveness:';
SELECT '  Popular Products (ID % 10000 = 0):';
SELECT CONCAT('    Count: ', @popular_count, ', Total Sales: ', @popular_sales);
SELECT CONCAT('    Avg Sales per Product: ', @popular_sales DIV @popular_count);
SELECT '  Non-Popular Products:';
SELECT CONCAT('    Count: ', @non_popular_count, ', Total Sales: ', @non_popular_sales);
SELECT CONCAT('    Avg Sales per Product: ', @non_popular_sales DIV @non_popular_count);

SELECT '';
SELECT '';

-- =======================================================================
-- TOP 20 REORDER BY QUANTITY
-- Purpose: Verify restock trigger functionality
-- Expected: Reorder table should have new entries from benchmark
-- =======================================================================
SELECT '--- TOP 20 REORDER BY QUANTITY (Restock Trigger Verification) ---';
SELECT 'Verifying: Restock trigger fired for products that sold out';
SELECT 'Expected: REORDER table should show new restocking activity';
SELECT 'Expected: Popular products (ID % 10000 = 0) should appear frequently';
SELECT '';

SELECT
    LPAD(r.PROD_ID, 8) AS PROD_ID,
    RPAD(p.TITLE, 40) AS TITLE,
    LPAD(SUM(r.QUAN_REORDERED), 15) AS TOTAL_REORDERED,
    LPAD(COUNT(*), 13) AS RESTOCK_COUNT,
    MAX(r.DATE_REORDERED) AS LAST_RESTOCK_DATE,
    RPAD(CASE
        WHEN r.PROD_ID % 10000 = 0 THEN '**POPULAR**'
        ELSE ''
    END, 12) AS IsPopularProduct
FROM REORDER1 r
JOIN PRODUCTS1 p ON r.PROD_ID = p.PROD_ID
GROUP BY r.PROD_ID, p.TITLE
ORDER BY SUM(r.QUAN_REORDERED) DESC
LIMIT 20;

SELECT '';
SELECT '';

-- Reorder statistics
SET @total_reorders = (SELECT COUNT(*) FROM REORDER1);
SET @popular_reorders = (SELECT COUNT(*) FROM REORDER1 WHERE PROD_ID % 10000 = 0);

SELECT 'Restock Trigger Statistics:';
SELECT CONCAT('  Total Reorder Events: ', @total_reorders);
SELECT CONCAT('  Popular Product Reorders: ', @popular_reorders);
SELECT CONCAT('  Popular Product %: ', ROUND(100 * @popular_reorders / @total_reorders), '%');

SELECT '';
SELECT '';

-- =======================================================================
-- TOP 10 REVIEWS BY HELPFULNESS
-- Purpose: Verify review and helpfulness operations
-- Expected: New reviews created, helpfulness ratings accumulated
-- =======================================================================
SELECT '--- TOP 10 REVIEWS BY HELPFULNESS (Review Operations Verification) ---';
SELECT 'Verifying: New reviews created and helpfulness ratings accumulated';
SELECT 'Expected: TOTAL_HELPFULNESS values should be higher than pre-test';
SELECT '';

SELECT 'Pre-Test Top 10:';
SELECT
    t.rank_position AS `Rank`,
    t.review_id AS `ReviewID`,
    t.prod_id AS `ProdID`,
    t.total_helpfulness AS `Helpfulness`
FROM VALIDATION_TOP_REVIEWS t
ORDER BY t.rank_position;

SELECT '';

SELECT 'Post-Test Top 10:';
SELECT
    @rownum := @rownum + 1 AS `Rank`,
    REVIEW_ID AS `ReviewID`,
    PROD_ID AS `ProdID`,
    TOTAL_HELPFULNESS AS `Helpfulness`,
    CASE WHEN PROD_ID % 10000 = 0 THEN '**POPULAR**' ELSE '' END AS `Popular`
FROM REVIEWS1
CROSS JOIN (SELECT @rownum := 0) AS init
ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID
LIMIT 10;

SELECT '';
SELECT '';

-- Review statistics
SET @total_reviews = (SELECT COUNT(*) FROM REVIEWS1);
SET @avg_helpfulness = (SELECT AVG(TOTAL_HELPFULNESS) FROM REVIEWS1);
SET @max_helpfulness = (SELECT MAX(TOTAL_HELPFULNESS) FROM REVIEWS1);
SET @total_helpfulness = (SELECT IFNULL(SUM(TOTAL_HELPFULNESS), 0) FROM REVIEWS1);
SET @total_helpfulness_pre = (SELECT metric_value FROM VALIDATION_METRICS WHERE metric_name = 'TOTAL_HELPFULNESS');
SELECT 'Review Statistics:';
SELECT CONCAT('  Total Reviews: ', @total_reviews);
SELECT CONCAT('  Avg Helpfulness: ', ROUND(@avg_helpfulness, 2));
SELECT CONCAT('  Max Helpfulness: ', @max_helpfulness);
SELECT '  Total Helpfulness (sum):';
SELECT CONCAT('    Pre:   ', @total_helpfulness_pre);
SELECT CONCAT('    Post:  ', @total_helpfulness);
SELECT CONCAT('    Delta: ', @total_helpfulness - @total_helpfulness_pre);
SELECT 'Reviews for Popular Products (ID % 10000 = 0):';
SELECT '  Expected: Increase when managers disabled, increase at a slower rate when managers enabled';

SELECT
    LPAD(IFNULL(pre.prod_id, post.PROD_ID), 8) AS PROD_ID,
    RPAD(IFNULL(pre.title, post.TITLE), 40) AS TITLE,
    LPAD(IFNULL(pre.review_count, 0), 10) AS Pre,
    LPAD(IFNULL(post.ReviewCount, 0), 10) AS Post,
    LPAD(IFNULL(post.ReviewCount, 0) - IFNULL(pre.review_count, 0), 10) AS Delta
FROM VALIDATION_POPULAR_REVIEWS pre
LEFT JOIN (
    SELECT
        p.PROD_ID,
        p.TITLE,
        COUNT(r.REVIEW_ID) AS ReviewCount
    FROM PRODUCTS1 p
    LEFT JOIN REVIEWS1 r ON p.PROD_ID = r.PROD_ID
    WHERE p.PROD_ID % 10000 = 0
    GROUP BY p.PROD_ID, p.TITLE
) post ON pre.prod_id = post.PROD_ID
UNION
SELECT
    LPAD(post.PROD_ID, 8),
    RPAD(post.TITLE, 40),
    LPAD(IFNULL(pre.review_count, 0), 10),
    LPAD(IFNULL(post.ReviewCount, 0), 10),
    LPAD(IFNULL(post.ReviewCount, 0) - IFNULL(pre.review_count, 0), 10)
FROM VALIDATION_POPULAR_REVIEWS pre
RIGHT JOIN (
    SELECT
        p.PROD_ID,
        p.TITLE,
        COUNT(r.REVIEW_ID) AS ReviewCount
    FROM PRODUCTS1 p
    LEFT JOIN REVIEWS1 r ON p.PROD_ID = r.PROD_ID
    WHERE p.PROD_ID % 10000 = 0
    GROUP BY p.PROD_ID, p.TITLE
) post ON pre.prod_id = post.PROD_ID
WHERE pre.prod_id IS NULL
ORDER BY 4 DESC, 1;


-- =======================================================================
-- UPDATE_HELPFULNESS TRIGGER VERIFICATION
-- =======================================================================
SELECT '--- UPDATE_HELPFULNESS TRIGGER VERIFICATION ---';
SELECT 'Verifying: TOTAL_HELPFULNESS matches sum of individual helpfulness ratings';
SELECT '';

SET @mismatch_count = (
    SELECT COUNT(*)
    FROM REVIEWS1 r
    LEFT JOIN (
        SELECT REVIEW_ID, SUM(HELPFULNESS) AS CalculatedTotal
        FROM REVIEWS_HELPFULNESS1
        GROUP BY REVIEW_ID
    ) h ON r.REVIEW_ID = h.REVIEW_ID
    WHERE IFNULL(r.TOTAL_HELPFULNESS, 0) != IFNULL(h.CalculatedTotal, 0)
);

SELECT CONCAT('Reviews with TOTAL_HELPFULNESS mismatch: ', @mismatch_count);
SELECT '  Expected: 0 (trigger should keep values in sync)';

SELECT IF(@mismatch_count > 0, 'WARNING: Found mismatches - showing first 10:', '') AS '';

SELECT
    r.REVIEW_ID,
    r.PROD_ID,
    r.TOTAL_HELPFULNESS AS Stored_Helpfulness,
    IFNULL(h.CalculatedTotal, 0) AS Calculated_Helpfulness,
    IFNULL(h.CalculatedTotal, 0) - IFNULL(r.TOTAL_HELPFULNESS, 0) AS Difference
FROM REVIEWS1 r
LEFT JOIN (
    SELECT REVIEW_ID, SUM(HELPFULNESS) AS CalculatedTotal
    FROM REVIEWS_HELPFULNESS1
    GROUP BY REVIEW_ID
) h ON r.REVIEW_ID = h.REVIEW_ID
WHERE IFNULL(r.TOTAL_HELPFULNESS, 0) != IFNULL(h.CalculatedTotal, 0)
LIMIT 10;


-- =======================================================================
-- MANAGER OPERATION VERIFICATION
-- =======================================================================
SELECT '--- MANAGER OPERATION VERIFICATION ---';
SELECT 'Verifying: Manager operations executed correctly (if managers enabled)';
SELECT '';

-- Manager-created products (price ends in .01)
SET @manager_products = (SELECT COUNT(*) FROM PRODUCTS1 WHERE PRICE - FLOOR(PRICE) = 0.01);
SET @manager_products_pre = (SELECT metric_value FROM VALIDATION_METRICS WHERE metric_name = 'MANAGER_PRODUCTS_COUNT');

SELECT 'Manager-Created Products (price .01):';
SELECT CONCAT('  Pre:   ', @manager_products_pre);
SELECT CONCAT('  Post:  ', @manager_products);
SELECT CONCAT('  Delta: ', @manager_products - @manager_products_pre);

SELECT 'Sample Manager-Created Products (price ends in .01):';
SELECT
    LPAD(PROD_ID, 8) AS PROD_ID,
    RPAD(TITLE, 40) AS TITLE,
    RPAD(ACTOR, 30) AS ACTOR,
    LPAD(FORMAT(PRICE, 2), 10) AS PRICE,
    LPAD(SPECIAL, 7) AS SPECIAL,
    LPAD(COMMON_PROD_ID, 13) AS COMMON_PROD_ID
FROM PRODUCTS1
WHERE PRICE - FLOOR(PRICE) = 0.01
ORDER BY PROD_ID DESC
LIMIT 10;

-- Products marked as SPECIAL
SET @special_products = (SELECT COUNT(*) FROM PRODUCTS1 WHERE SPECIAL = 1);
SET @special_products_pre = (SELECT metric_value FROM VALIDATION_METRICS WHERE metric_name = 'SPECIAL_PRODUCTS_COUNT');

SELECT 'Products Marked Special (SPECIAL=1):';
SELECT CONCAT('  Pre:   ', @special_products_pre);
SELECT CONCAT('  Post:  ', @special_products);
SELECT CONCAT('  Delta: ', @special_products - @special_products_pre);
SELECT '  (MarkSpecials toggles SPECIAL flag)';

-- Price changes (detect products with non-standard pricing)
SET @adjusted_prices = (SELECT COUNT(*) FROM PRODUCTS1 WHERE (PRICE - FLOOR(PRICE)) != 0.99 AND (PRICE - FLOOR(PRICE)) != 0.01);

SELECT CONCAT('Products with Adjusted Prices (not ending in .99 or .01): ', @adjusted_prices);
SELECT '  (Indicates AdjustPrices manager operations changed product pricing)';

SELECT 'Sample Price-Adjusted Products (not .99 or .01):';
SELECT
    LPAD(PROD_ID, 8) AS PROD_ID,
    RPAD(TITLE, 40) AS TITLE,
    RPAD(ACTOR, 30) AS ACTOR,
    LPAD(FORMAT(PRICE, 2), 10) AS PRICE,
    LPAD(SPECIAL, 7) AS SPECIAL,
    LPAD(COMMON_PROD_ID, 13) AS COMMON_PROD_ID
FROM PRODUCTS1
WHERE (PRICE - FLOOR(PRICE)) != 0.99 AND (PRICE - FLOOR(PRICE)) != 0.01
ORDER BY PROD_ID
LIMIT 10;


-- =======================================================================
-- BENCHMARK ACTIVITY SUMMARY
-- =======================================================================
SELECT '--- BENCHMARK ACTIVITY SUMMARY ---';
SELECT '';

-- Calculate deltas from baseline
SET @customers_before = (SELECT metric_value FROM VALIDATION_METRICS WHERE metric_name = 'CUSTOMERS_COUNT');
SET @orders_before = (SELECT metric_value FROM VALIDATION_METRICS WHERE metric_name = 'ORDERS_COUNT');
SET @reviews_before = (SELECT metric_value FROM VALIDATION_METRICS WHERE metric_name = 'REVIEWS_COUNT');
SET @products_before = (SELECT metric_value FROM VALIDATION_METRICS WHERE metric_name = 'PRODUCTS_COUNT');

SET @customers_after = (SELECT COUNT(*) FROM CUSTOMERS1);
SET @orders_after = (SELECT COUNT(*) FROM ORDERS1);
SET @reviews_after = (SELECT COUNT(*) FROM REVIEWS1);
SET @products_after = (SELECT COUNT(*) FROM PRODUCTS1);

SELECT 'New Records Created During Benchmark:';
SELECT CONCAT('  Customers: ', @customers_after - @customers_before);
SELECT CONCAT('  Orders:    ', @orders_after - @orders_before);
SELECT CONCAT('  Reviews:   ', @reviews_after - @reviews_before);
SELECT CONCAT('  Products:  ', @products_after - @products_before);

SELECT 'Manager Operation Impact:';
SELECT CONCAT('  Products with Adjusted Prices: ', @adjusted_prices);


-- =======================================================================
-- TOP 10 NEW CUSTOMERS
-- =======================================================================
SELECT '--- TOP 10 NEW CUSTOMERS (Created During Benchmark) ---';
SELECT '';

SET @max_customerid_pre = (SELECT metric_value FROM VALIDATION_METRICS WHERE metric_name = 'MAX_CUSTOMERID');

SELECT
    LPAD(CUSTOMERID, 10) AS CUSTOMERID,
    RPAD(FIRSTNAME, 20) AS FIRSTNAME,
    RPAD(LASTNAME, 20) AS LASTNAME,
    RPAD(CITY, 20) AS CITY
FROM CUSTOMERS1
WHERE CUSTOMERID > @max_customerid_pre
ORDER BY CUSTOMERID
LIMIT 10;


-- =======================================================================
-- NEW PRODUCT VERIFICATION
-- Purpose: Verify products added by manager are actually used
-- Expected: New products should appear in INVENTORY, ORDERLINES, REORDER
-- =======================================================================
SELECT '--- NEW PRODUCT VERIFICATION (Manager AddProduct Validation) ---';
SELECT 'Verifying: Products added during test are purchased and reordered';
SELECT '';

SET @max_prod_id_pre = (SELECT metric_value FROM VALIDATION_METRICS WHERE metric_name = 'MAX_PROD_ID');

SET @new_products_added = (SELECT COUNT(*) FROM PRODUCTS1 WHERE PROD_ID > @max_prod_id_pre);
SET @new_products_with_inventory = (SELECT COUNT(DISTINCT i.PROD_ID) FROM INVENTORY1 i WHERE i.PROD_ID > @max_prod_id_pre);
SET @new_products_purchased = (SELECT COUNT(DISTINCT ol.PROD_ID) FROM ORDERLINES1 ol WHERE ol.PROD_ID > @max_prod_id_pre);
SET @new_products_reordered = (SELECT COUNT(DISTINCT r.PROD_ID) FROM REORDER1 r WHERE r.PROD_ID > @max_prod_id_pre);

SELECT CONCAT('New Products Added:          ', @new_products_added);
SELECT CONCAT('New Products with Inventory: ', @new_products_with_inventory);
SELECT CONCAT('New Products Purchased:      ', @new_products_purchased);
SELECT CONCAT('New Products Reordered:      ', @new_products_reordered);

SELECT CASE
    WHEN @new_products_added = 0 THEN 'INFO: No new products added (manager may be disabled or no AddProduct operations executed)'
    WHEN @new_products_with_inventory = 0 THEN 'WARNING: New products exist but have no inventory!'
    WHEN @new_products_purchased = 0 THEN 'INFO: New products have not been purchased yet (may need longer test run)'
    WHEN @new_products_reordered > 0 THEN 'SUCCESS: New products are being purchased and reordered!'
    ELSE ''
END AS Status;

SELECT 'Sample New Products in REORDER Table:';
SELECT
    LPAD(r.PROD_ID, 8) AS PROD_ID,
    RPAD(p.TITLE, 40) AS TITLE,
    LPAD(SUM(r.QUAN_REORDERED), 15) AS TOTAL_REORDERED,
    LPAD(COUNT(*), 13) AS REORDER_COUNT,
    MAX(r.DATE_REORDERED) AS LAST_REORDER
FROM REORDER1 r
JOIN PRODUCTS1 p ON r.PROD_ID = p.PROD_ID
WHERE r.PROD_ID > @max_prod_id_pre
GROUP BY r.PROD_ID, p.TITLE
ORDER BY MAX(r.DATE_REORDERED) DESC, r.PROD_ID
LIMIT 10;

SELECT '========================================================================';
SELECT 'Post-Test Validation Complete';
SELECT 'Compare these results with validate_before.sql to verify:';
SELECT '  1. GetSkewedProductId: Popular products (ID % 10000) have highest sales';
SELECT '  2. Restock Trigger: REORDER table shows restocking for sold-out products';
SELECT '  3. Review Operations: New reviews created, helpfulness scores increased';
SELECT '  4. Manager Operations: New products added, prices adjusted, specials toggled';
SELECT '  5. Customer Growth: New customers and orders created during benchmark';
SELECT '  6. AddProduct Validation: New products have inventory and are being purchased';
SELECT '========================================================================';
