-- DVD Store 3.6 - Post-Test Validation Queries (SQL Server)
-- Run this AFTER completing the benchmark to measure changes
-- Compare with validate_before.sql results to verify test harness functionality

USE DS3;
GO

PRINT '========================================================================';
PRINT 'DVD Store 3.6 - Post-Test Validation';
PRINT 'Timestamp: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '========================================================================';
PRINT '';

-- =======================================================================
-- TABLE ROW COUNTS
-- Purpose: Show data growth during benchmark
-- =======================================================================
PRINT '--- TABLE ROW COUNTS (Post-Test) ---';
PRINT 'Verifying: Data volume changes during benchmark execution';
PRINT 'Expected: CUSTOMERS, ORDERS, ORDERLINES, REVIEWS should increase';
PRINT 'Expected: PRODUCTS may increase if managers enabled';
PRINT 'Expected: REVIEWS may decrease if managers removed unhelpful reviews';
PRINT '';

-- Display current counts with deltas from baseline
SELECT
    LEFT(REPLACE(m.metric_name, '_COUNT', '') + REPLICATE(' ', 15), 15) AS [Table],
    RIGHT(REPLICATE(' ', 15) + CAST(m.metric_value AS VARCHAR), 15) AS [Pre],
    RIGHT(REPLICATE(' ', 15) + CAST(
        CASE REPLACE(m.metric_name, '_COUNT', '')
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
        END AS VARCHAR), 15) AS [Post],
    RIGHT(REPLICATE(' ', 15) + CAST(
        CASE REPLACE(m.metric_name, '_COUNT', '')
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
        END AS VARCHAR), 15) AS [Delta]
FROM VALIDATION_METRICS m
WHERE m.metric_name LIKE '%_COUNT'
    AND m.metric_name NOT IN ('MANAGER_PRODUCTS_COUNT', 'SPECIAL_PRODUCTS_COUNT')
ORDER BY [Table];

PRINT '';
PRINT '';

-- =======================================================================
-- TOP 5 CUSTOMERS BY PURCHASE HISTORY
-- Purpose: Verify CUST_HIST table growth during benchmark
-- Expected: Shows customers with most products ordered
-- =======================================================================
PRINT '--- TOP 5 CUSTOMERS BY PURCHASE HISTORY (CUST_HIST Verification) ---';
PRINT 'Verifying: Customer purchase history has grown during benchmark';
PRINT 'Expected: Product counts should be higher than pre-test';
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
-- Expected: Products divisible by 10000 should dominate top sales
-- =======================================================================
PRINT '--- TOP 10 INVENTORY BY SALES (GetSkewedProductId Verification) ---';
PRINT 'Verifying: Skewed product selection worked correctly';
PRINT 'Expected: Products divisible by 10000 should appear in top 10 with higher SALES';
PRINT 'Expected: SALES values should be significantly higher than pre-test baseline';
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

-- Summary statistics on popular vs non-popular products
DECLARE @PopularSales BIGINT, @NonPopularSales BIGINT, @PopularCount INT, @NonPopularCount INT;
SELECT @PopularSales = SUM(SALES), @PopularCount = COUNT(*)
FROM INVENTORY1
WHERE PROD_ID % 10000 = 0;

SELECT @NonPopularSales = SUM(SALES), @NonPopularCount = COUNT(*)
FROM INVENTORY1
WHERE PROD_ID % 10000 != 0;

PRINT 'GetSkewedProductId Effectiveness:';
PRINT '  Popular Products (ID % 10000 = 0):';
PRINT '    Count: ' + CAST(@PopularCount AS VARCHAR) + ', Total Sales: ' + CAST(@PopularSales AS VARCHAR);
IF @PopularCount > 0
    PRINT '    Avg Sales per Product: ' + CAST(@PopularSales / @PopularCount AS VARCHAR);
PRINT '  Non-Popular Products:';
PRINT '    Count: ' + CAST(@NonPopularCount AS VARCHAR) + ', Total Sales: ' + CAST(@NonPopularSales AS VARCHAR);
IF @NonPopularCount > 0
    PRINT '    Avg Sales per Product: ' + CAST(@NonPopularSales / @NonPopularCount AS VARCHAR);

PRINT '';
PRINT '';

-- =======================================================================
-- TOP 20 REORDER BY QUANTITY
-- Purpose: Verify restock trigger functionality
-- Expected: Reorder table should have new entries from benchmark
-- =======================================================================
PRINT '--- TOP 20 REORDER BY QUANTITY (Restock Trigger Verification) ---';
PRINT 'Verifying: Restock trigger fired for products that sold out';
PRINT 'Expected: REORDER table should show new restocking activity';
PRINT 'Expected: Popular products (ID % 10000 = 0) should appear frequently';
PRINT '';

SELECT TOP 20
    r.PROD_ID,
    p.TITLE,
    SUM(r.QUAN_REORDERED) AS TOTAL_REORDERED,
    COUNT(*) AS RESTOCK_COUNT,
    MAX(r.DATE_REORDERED) AS LAST_RESTOCK_DATE,
    CASE
        WHEN r.PROD_ID % 10000 = 0 THEN '**POPULAR**'
        ELSE ''
    END AS IsPopularProduct
FROM REORDER1 r
JOIN PRODUCTS1 p ON r.PROD_ID = p.PROD_ID
GROUP BY r.PROD_ID, p.TITLE
ORDER BY SUM(r.QUAN_REORDERED) DESC;

PRINT '';

-- Reorder statistics
DECLARE @TotalReorders INT, @PopularReorders INT;
SELECT @TotalReorders = COUNT(*) FROM REORDER1;
SELECT @PopularReorders = COUNT(*) FROM REORDER1 WHERE PROD_ID % 10000 = 0;

PRINT 'Restock Trigger Statistics:';
PRINT '  Total Reorder Events: ' + CAST(@TotalReorders AS VARCHAR);
PRINT '  Popular Product Reorders: ' + CAST(@PopularReorders AS VARCHAR);
IF @TotalReorders > 0
    PRINT '  Popular Product %: ' + CAST((100 * @PopularReorders / @TotalReorders) AS VARCHAR) + '%';

PRINT '';
PRINT '';

-- =======================================================================
-- TOP 10 REVIEWS BY HELPFULNESS
-- Purpose: Verify review and helpfulness operations
-- Expected: New reviews created, helpfulness ratings accumulated
-- =======================================================================
PRINT '--- TOP 10 REVIEWS BY HELPFULNESS (Review Operations Verification) ---';
PRINT 'Verifying: New reviews created and helpfulness ratings accumulated';
PRINT 'Expected: TOTAL_HELPFULNESS values should be higher than pre-test';
PRINT '';

PRINT 'Pre-Test Top 10:';
SELECT
    RIGHT(REPLICATE(' ', 5) + CAST(t.rank_position AS VARCHAR), 5) AS [Rank],
    RIGHT(REPLICATE(' ', 10) + CAST(t.review_id AS VARCHAR), 10) AS [ReviewID],
    RIGHT(REPLICATE(' ', 10) + CAST(t.prod_id AS VARCHAR), 10) AS [ProdID],
    RIGHT(REPLICATE(' ', 12) + CAST(t.total_helpfulness AS VARCHAR), 12) AS [Helpfulness]
FROM VALIDATION_TOP_REVIEWS t
ORDER BY t.rank_position;

PRINT '';
PRINT 'Post-Test Top 10:';
SELECT TOP 10
    RIGHT(REPLICATE(' ', 5) + CAST(ROW_NUMBER() OVER (ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID) AS VARCHAR), 5) AS [Rank],
    RIGHT(REPLICATE(' ', 10) + CAST(REVIEW_ID AS VARCHAR), 10) AS [ReviewID],
    RIGHT(REPLICATE(' ', 10) + CAST(PROD_ID AS VARCHAR), 10) AS [ProdID],
    RIGHT(REPLICATE(' ', 12) + CAST(TOTAL_HELPFULNESS AS VARCHAR), 12) AS [Helpfulness],
    LEFT(CASE WHEN PROD_ID % 10000 = 0 THEN '**POPULAR**' ELSE '' END + REPLICATE(' ', 12), 12) AS [Popular]
FROM REVIEWS1
ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID;

PRINT '';

-- Review statistics
DECLARE @TotalReviews INT, @AvgHelpfulness FLOAT, @MaxHelpfulness INT;
DECLARE @TotalHelpfulness BIGINT, @TotalHelpfulnessPre BIGINT;
DECLARE @PopularProductReviews INT, @PopularProductReviewsPre INT;

SELECT @TotalReviews = COUNT(*),
       @AvgHelpfulness = AVG(CAST(TOTAL_HELPFULNESS AS FLOAT)),
       @MaxHelpfulness = MAX(TOTAL_HELPFULNESS),
       @TotalHelpfulness = ISNULL(SUM(TOTAL_HELPFULNESS), 0)
FROM REVIEWS1;

SELECT @TotalHelpfulnessPre = metric_value
FROM VALIDATION_METRICS
WHERE metric_name = 'TOTAL_HELPFULNESS';

PRINT 'Review Statistics:';
PRINT '  Total Reviews: ' + CAST(@TotalReviews AS VARCHAR);
PRINT '  Avg Helpfulness: ' + CAST(CAST(@AvgHelpfulness AS DECIMAL(10,2)) AS VARCHAR);
PRINT '  Max Helpfulness: ' + CAST(@MaxHelpfulness AS VARCHAR);
PRINT '  Total Helpfulness (sum):';
PRINT '    Pre:   ' + CAST(@TotalHelpfulnessPre AS VARCHAR);
PRINT '    Post:  ' + CAST(@TotalHelpfulness AS VARCHAR);
PRINT '    Delta: ' + CAST(@TotalHelpfulness - @TotalHelpfulnessPre AS VARCHAR);
PRINT '';
PRINT 'Reviews for Popular Products (ID % 10000 = 0):';
PRINT '  Expected: Increase when managers disabled, increase at a slower rate when managers enabled';
PRINT '';

SELECT
    ISNULL(pre.prod_id, post.PROD_ID) AS PROD_ID,
    ISNULL(pre.title, post.TITLE) AS TITLE,
    ISNULL(pre.review_count, 0) AS Pre,
    ISNULL(post.ReviewCount, 0) AS Post,
    ISNULL(post.ReviewCount, 0) - ISNULL(pre.review_count, 0) AS Delta
FROM VALIDATION_POPULAR_REVIEWS pre
FULL OUTER JOIN (
    SELECT
        p.PROD_ID,
        p.TITLE,
        COUNT(r.REVIEW_ID) AS ReviewCount
    FROM PRODUCTS1 p
    LEFT JOIN REVIEWS1 r ON p.PROD_ID = r.PROD_ID
    WHERE p.PROD_ID % 10000 = 0
    GROUP BY p.PROD_ID, p.TITLE
) post ON pre.prod_id = post.PROD_ID
ORDER BY ISNULL(post.ReviewCount, 0) DESC, ISNULL(pre.prod_id, post.PROD_ID);

PRINT '';
PRINT '';

-- =======================================================================
-- UPDATE_HELPFULNESS TRIGGER VERIFICATION
-- =======================================================================
PRINT '--- UPDATE_HELPFULNESS TRIGGER VERIFICATION ---';
PRINT 'Verifying: TOTAL_HELPFULNESS matches sum of individual helpfulness ratings';
PRINT '';

DECLARE @MismatchCount INT;

SELECT @MismatchCount = COUNT(*)
FROM REVIEWS1 r
LEFT JOIN (
    SELECT REVIEW_ID, SUM(HELPFULNESS) AS CalculatedTotal
    FROM REVIEWS_HELPFULNESS1
    GROUP BY REVIEW_ID
) h ON r.REVIEW_ID = h.REVIEW_ID
WHERE ISNULL(r.TOTAL_HELPFULNESS, 0) != ISNULL(h.CalculatedTotal, 0);

PRINT 'Reviews with TOTAL_HELPFULNESS mismatch: ' + CAST(@MismatchCount AS VARCHAR);
PRINT '  Expected: 0 (trigger should keep values in sync)';

IF @MismatchCount > 0
BEGIN
    PRINT '';
    PRINT 'WARNING: Found mismatches - showing first 10:';
    SELECT TOP 10
        r.REVIEW_ID,
        r.PROD_ID,
        r.TOTAL_HELPFULNESS AS Stored_Helpfulness,
        ISNULL(h.CalculatedTotal, 0) AS Calculated_Helpfulness,
        ISNULL(h.CalculatedTotal, 0) - ISNULL(r.TOTAL_HELPFULNESS, 0) AS Difference
    FROM REVIEWS1 r
    LEFT JOIN (
        SELECT REVIEW_ID, SUM(HELPFULNESS) AS CalculatedTotal
        FROM REVIEWS_HELPFULNESS1
        GROUP BY REVIEW_ID
    ) h ON r.REVIEW_ID = h.REVIEW_ID
    WHERE ISNULL(r.TOTAL_HELPFULNESS, 0) != ISNULL(h.CalculatedTotal, 0);
END

PRINT '';
PRINT '';

-- =======================================================================
-- MANAGER OPERATION VERIFICATION
-- =======================================================================
PRINT '--- MANAGER OPERATION VERIFICATION ---';
PRINT 'Verifying: Manager operations executed correctly (if managers enabled)';
PRINT '';

-- Manager-created products (price ends in .01)
DECLARE @ManagerProducts INT, @ManagerProductsPre INT;
SELECT @ManagerProducts = COUNT(*)
FROM PRODUCTS1
WHERE PRICE - FLOOR(PRICE) = 0.01;

SELECT @ManagerProductsPre = metric_value
FROM VALIDATION_METRICS
WHERE metric_name = 'MANAGER_PRODUCTS_COUNT';

PRINT 'Manager-Created Products (price .01):';
PRINT '  Pre:   ' + CAST(@ManagerProductsPre AS VARCHAR);
PRINT '  Post:  ' + CAST(@ManagerProducts AS VARCHAR);
PRINT '  Delta: ' + CAST(@ManagerProducts - @ManagerProductsPre AS VARCHAR);
PRINT '';

PRINT 'Sample Manager-Created Products (price ends in .01):';
SELECT TOP 10
    PROD_ID,
    TITLE,
    ACTOR,
    PRICE,
    SPECIAL,
    COMMON_PROD_ID
FROM PRODUCTS1
WHERE PRICE - FLOOR(PRICE) = 0.01
ORDER BY PROD_ID DESC;

-- Products marked as SPECIAL
DECLARE @SpecialProducts INT, @SpecialProductsPre INT;
SELECT @SpecialProducts = COUNT(*)
FROM PRODUCTS1
WHERE SPECIAL = 1;

SELECT @SpecialProductsPre = metric_value
FROM VALIDATION_METRICS
WHERE metric_name = 'SPECIAL_PRODUCTS_COUNT';

PRINT 'Products Marked Special (SPECIAL=1):';
PRINT '  Pre:   ' + CAST(@SpecialProductsPre AS VARCHAR);
PRINT '  Post:  ' + CAST(@SpecialProducts AS VARCHAR);
PRINT '  Delta: ' + CAST(@SpecialProducts - @SpecialProductsPre AS VARCHAR);
PRINT '  (MarkSpecials toggles SPECIAL flag)';

-- Price changes (detect products with non-standard pricing)
DECLARE @AdjustedPrices INT;
SELECT @AdjustedPrices = COUNT(*)
FROM PRODUCTS1
WHERE PRICE - FLOOR(PRICE) != 0.99 AND PRICE - FLOOR(PRICE) != 0.01;
PRINT 'Products with Adjusted Prices (not ending in .99 or .01): ' + CAST(@AdjustedPrices AS VARCHAR);
PRINT '  (Indicates AdjustPrices manager operations changed product pricing)';
PRINT '';

PRINT 'Sample Price-Adjusted Products (not .99 or .01):';
SELECT TOP 10
    PROD_ID,
    TITLE,
    ACTOR,
    PRICE,
    SPECIAL,
    COMMON_PROD_ID
FROM PRODUCTS1
WHERE PRICE - FLOOR(PRICE) != 0.99 AND PRICE - FLOOR(PRICE) != 0.01
ORDER BY PROD_ID;

PRINT '';
PRINT '';

-- =======================================================================
-- BENCHMARK ACTIVITY SUMMARY
-- =======================================================================
PRINT '--- BENCHMARK ACTIVITY SUMMARY ---';
PRINT '';

-- Calculate deltas from baseline
DECLARE @CustomersBefore INT, @CustomersAfter INT, @CustomersDelta INT;
DECLARE @OrdersBefore INT, @OrdersAfter INT, @OrdersDelta INT;
DECLARE @ReviewsBefore INT, @ReviewsAfter INT, @ReviewsDelta INT;
DECLARE @ProductsBefore INT, @ProductsAfter INT, @ProductsDelta INT;

SELECT @CustomersBefore = metric_value FROM VALIDATION_METRICS WHERE metric_name = 'CUSTOMERS_COUNT';
SELECT @OrdersBefore = metric_value FROM VALIDATION_METRICS WHERE metric_name = 'ORDERS_COUNT';
SELECT @ReviewsBefore = metric_value FROM VALIDATION_METRICS WHERE metric_name = 'REVIEWS_COUNT';
SELECT @ProductsBefore = metric_value FROM VALIDATION_METRICS WHERE metric_name = 'PRODUCTS_COUNT';

SELECT @CustomersAfter = COUNT(*) FROM CUSTOMERS1;
SELECT @OrdersAfter = COUNT(*) FROM ORDERS1;
SELECT @ReviewsAfter = COUNT(*) FROM REVIEWS1;
SELECT @ProductsAfter = COUNT(*) FROM PRODUCTS1;

SET @CustomersDelta = @CustomersAfter - @CustomersBefore;
SET @OrdersDelta = @OrdersAfter - @OrdersBefore;
SET @ReviewsDelta = @ReviewsAfter - @ReviewsBefore;
SET @ProductsDelta = @ProductsAfter - @ProductsBefore;

PRINT 'New Records Created During Benchmark:';
PRINT '  Customers: ' + CAST(@CustomersDelta AS VARCHAR);
PRINT '  Orders:    ' + CAST(@OrdersDelta AS VARCHAR);
PRINT '  Reviews:   ' + CAST(@ReviewsDelta AS VARCHAR);
PRINT '  Products:  ' + CAST(@ProductsDelta AS VARCHAR);
PRINT '';
PRINT 'Manager Operation Impact:';
PRINT '  Products with Adjusted Prices: ' + CAST(@AdjustedPrices AS VARCHAR);

PRINT '';
PRINT '';

-- =======================================================================
-- TOP 10 NEW CUSTOMERS
-- =======================================================================
PRINT '--- TOP 10 NEW CUSTOMERS (Created During Benchmark) ---';
PRINT '';

DECLARE @MaxCustomerIDPre INT;
SELECT @MaxCustomerIDPre = metric_value
FROM VALIDATION_METRICS
WHERE metric_name = 'MAX_CUSTOMERID';

SELECT TOP 10
    RIGHT(REPLICATE(' ', 10) + CAST(CUSTOMERID AS VARCHAR), 10) AS [CustomerID],
    LEFT(FIRSTNAME + REPLICATE(' ', 20), 20) AS [FirstName],
    LEFT(LASTNAME + REPLICATE(' ', 20), 20) AS [LastName],
    LEFT(CITY + REPLICATE(' ', 20), 20) AS [City]
FROM CUSTOMERS1
WHERE CUSTOMERID > @MaxCustomerIDPre
ORDER BY CUSTOMERID;

PRINT '';
PRINT '';

-- =======================================================================
-- NEW PRODUCT VERIFICATION
-- Purpose: Verify products added by manager are actually used
-- Expected: New products should appear in INVENTORY, ORDERLINES, REORDER
-- =======================================================================
PRINT '--- NEW PRODUCT VERIFICATION (Manager AddProduct Validation) ---';
PRINT 'Verifying: Products added during test are purchased and reordered';
PRINT '';

DECLARE @MaxProdIDPre INT;
SELECT @MaxProdIDPre = metric_value
FROM VALIDATION_METRICS
WHERE metric_name = 'MAX_PROD_ID';

DECLARE @NewProductsAdded INT;
DECLARE @NewProductsWithInventory INT;
DECLARE @NewProductsPurchased INT;
DECLARE @NewProductsReordered INT;

SELECT @NewProductsAdded = COUNT(*)
FROM PRODUCTS1
WHERE PROD_ID > @MaxProdIDPre;

SELECT @NewProductsWithInventory = COUNT(DISTINCT i.PROD_ID)
FROM INVENTORY1 i
WHERE i.PROD_ID > @MaxProdIDPre;

SELECT @NewProductsPurchased = COUNT(DISTINCT ol.PROD_ID)
FROM ORDERLINES1 ol
WHERE ol.PROD_ID > @MaxProdIDPre;

SELECT @NewProductsReordered = COUNT(DISTINCT r.PROD_ID)
FROM REORDER1 r
WHERE r.PROD_ID > @MaxProdIDPre;

PRINT 'New Products Added:          ' + CAST(@NewProductsAdded AS VARCHAR);
PRINT 'New Products with Inventory: ' + CAST(@NewProductsWithInventory AS VARCHAR);
PRINT 'New Products Purchased:      ' + CAST(@NewProductsPurchased AS VARCHAR);
PRINT 'New Products Reordered:      ' + CAST(@NewProductsReordered AS VARCHAR);
PRINT '';

PRINT 'Sample New Products in REORDER Table:';
SELECT TOP 10
    r.PROD_ID,
    p.TITLE,
    SUM(r.QUAN_REORDERED) AS TOTAL_REORDERED,
    COUNT(*) AS REORDER_COUNT,
    MAX(r.DATE_REORDERED) AS LAST_REORDER
FROM REORDER1 r
JOIN PRODUCTS1 p ON r.PROD_ID = p.PROD_ID
WHERE r.PROD_ID > @MaxProdIDPre
GROUP BY r.PROD_ID, p.TITLE
ORDER BY MAX(r.DATE_REORDERED) DESC, r.PROD_ID;

IF @NewProductsAdded > 0
BEGIN
    IF @NewProductsWithInventory = 0
        PRINT 'WARNING: New products exist but have no inventory!';
    IF @NewProductsPurchased = 0
        PRINT 'INFO: New products have not been purchased yet (may need longer test run)';
    IF @NewProductsReordered > 0
        PRINT 'SUCCESS: New products are being purchased and reordered!';
END
ELSE
BEGIN
    PRINT 'INFO: No new products added (manager may be disabled or no AddProduct operations executed)';
END

PRINT '';
PRINT '========================================================================';
PRINT 'Post-Test Validation Complete';
PRINT 'Compare these results with validate_before.sql to verify:';
PRINT '  1. GetSkewedProductId: Popular products (ID % 10000) have highest sales';
PRINT '  2. Restock Trigger: REORDER table shows restocking for sold-out products';
PRINT '  3. Review Operations: New reviews created, helpfulness scores increased';
PRINT '  4. Manager Operations: New products added, prices adjusted, specials toggled';
PRINT '  5. Customer Growth: New customers and orders created during benchmark';
PRINT '  6. AddProduct Validation: New products have inventory and are being purchased';
PRINT '========================================================================';
