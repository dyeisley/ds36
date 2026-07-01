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
            WHEN 'CUSTOMERS' THEN (SELECT COUNT(*) FROM CUSTOMERS{store_number})
            WHEN 'CUST_HIST' THEN (SELECT COUNT(*) FROM CUST_HIST{store_number})
            WHEN 'PRODUCTS' THEN (SELECT COUNT(*) FROM PRODUCTS{store_number})
            WHEN 'ORDERS' THEN (SELECT COUNT(*) FROM ORDERS{store_number})
            WHEN 'ORDERLINES' THEN (SELECT COUNT(*) FROM ORDERLINES{store_number})
            WHEN 'INVENTORY' THEN (SELECT COUNT(*) FROM INVENTORY{store_number})
            WHEN 'REVIEWS' THEN (SELECT COUNT(*) FROM REVIEWS{store_number})
            WHEN 'REVIEWS_HELPFULNESS' THEN (SELECT COUNT(*) FROM REVIEWS_HELPFULNESS{store_number})
            WHEN 'MEMBERSHIP' THEN (SELECT COUNT(*) FROM MEMBERSHIP{store_number})
            WHEN 'REORDER' THEN (SELECT COUNT(*) FROM REORDER{store_number})
        END AS VARCHAR), 15) AS [Post],
    RIGHT(REPLICATE(' ', 15) + CAST(
        CASE REPLACE(m.metric_name, '_COUNT', '')
            WHEN 'CUSTOMERS' THEN (SELECT COUNT(*) FROM CUSTOMERS{store_number}) - m.metric_value
            WHEN 'CUST_HIST' THEN (SELECT COUNT(*) FROM CUST_HIST{store_number}) - m.metric_value
            WHEN 'PRODUCTS' THEN (SELECT COUNT(*) FROM PRODUCTS{store_number}) - m.metric_value
            WHEN 'ORDERS' THEN (SELECT COUNT(*) FROM ORDERS{store_number}) - m.metric_value
            WHEN 'ORDERLINES' THEN (SELECT COUNT(*) FROM ORDERLINES{store_number}) - m.metric_value
            WHEN 'INVENTORY' THEN (SELECT COUNT(*) FROM INVENTORY{store_number}) - m.metric_value
            WHEN 'REVIEWS' THEN (SELECT COUNT(*) FROM REVIEWS{store_number}) - m.metric_value
            WHEN 'REVIEWS_HELPFULNESS' THEN (SELECT COUNT(*) FROM REVIEWS_HELPFULNESS{store_number}) - m.metric_value
            WHEN 'MEMBERSHIP' THEN (SELECT COUNT(*) FROM MEMBERSHIP{store_number}) - m.metric_value
            WHEN 'REORDER' THEN (SELECT COUNT(*) FROM REORDER{store_number}) - m.metric_value
        END AS VARCHAR), 15) AS [Delta]
FROM VALIDATION_METRICS_{store_number} m
WHERE m.metric_name LIKE '%_COUNT'
    AND m.metric_name NOT IN ('MANAGER_PRODUCTS_COUNT', 'SPECIAL_PRODUCTS_COUNT', 'OLD_ORDERS_COUNT', 'SILVER_MEMBERS_COUNT', 'GOLD_MEMBERS_COUNT')
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
FROM CUST_HIST{store_number} ch
JOIN CUSTOMERS{store_number} c ON ch.CUSTOMERID = c.CUSTOMERID
GROUP BY ch.CUSTOMERID, c.FIRSTNAME, c.LASTNAME
ORDER BY COUNT(*) DESC;

PRINT '';
PRINT '';

-- =======================================================================
-- TOP 10 INVENTORY BY SALES
-- Purpose: Verify GetSkewedProductId distribution
-- Expected: Products divisible by {popular_modulo} should dominate top sales
-- =======================================================================
PRINT '--- TOP 10 INVENTORY BY SALES (GetSkewedProductId Verification) ---';
PRINT 'Verifying: Skewed product selection worked correctly';
PRINT 'Expected: Products divisible by {popular_modulo} should appear in top 10 with higher SALES';
PRINT 'Expected: SALES values should be significantly higher than pre-test baseline';
PRINT '';

SELECT TOP 10
    i.PROD_ID,
    p.TITLE,
    i.SALES,
    CASE
        WHEN i.PROD_ID % {popular_modulo} = 0 THEN '**POPULAR**'
        ELSE ''
    END AS IsPopularProduct
FROM INVENTORY{store_number} i
JOIN PRODUCTS{store_number} p ON i.PROD_ID = p.PROD_ID
ORDER BY i.SALES DESC;

PRINT '';

-- Summary statistics on popular vs non-popular products
DECLARE @PopularSales BIGINT, @NonPopularSales BIGINT, @PopularCount INT, @NonPopularCount INT;
SELECT @PopularSales = SUM(SALES), @PopularCount = COUNT(*)
FROM INVENTORY{store_number}
WHERE PROD_ID % {popular_modulo} = 0;

SELECT @NonPopularSales = SUM(SALES), @NonPopularCount = COUNT(*)
FROM INVENTORY{store_number}
WHERE PROD_ID % {popular_modulo} != 0;

PRINT 'GetSkewedProductId Effectiveness:';
PRINT '  Popular Products (ID % {popular_modulo} = 0):';
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
PRINT '';

SELECT TOP 20
    r.PROD_ID,
    p.TITLE,
    SUM(r.QUAN_REORDERED) AS TOTAL_REORDERED,
    COUNT(*) AS RESTOCK_COUNT,
    MAX(r.DATE_REORDERED) AS LAST_RESTOCK_DATE,
    CASE
        WHEN r.PROD_ID % {popular_modulo} = 0 THEN '**POPULAR**'
        ELSE ''
    END AS IsPopularProduct
FROM REORDER{store_number} r
JOIN PRODUCTS{store_number} p ON r.PROD_ID = p.PROD_ID
GROUP BY r.PROD_ID, p.TITLE
ORDER BY SUM(r.QUAN_REORDERED) DESC;

PRINT '';

-- Reorder statistics
DECLARE @TotalReorders INT, @PopularReorders INT;
SELECT @TotalReorders = COUNT(*) FROM REORDER{store_number};
SELECT @PopularReorders = COUNT(*) FROM REORDER{store_number} WHERE PROD_ID % {popular_modulo} = 0;

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
FROM VALIDATION_TOP_REVIEWS_{store_number} t
ORDER BY t.rank_position;

PRINT '';
PRINT 'Post-Test Top 10:';
SELECT TOP 10
    RIGHT(REPLICATE(' ', 5) + CAST(ROW_NUMBER() OVER (ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID) AS VARCHAR), 5) AS [Rank],
    RIGHT(REPLICATE(' ', 10) + CAST(REVIEW_ID AS VARCHAR), 10) AS [ReviewID],
    RIGHT(REPLICATE(' ', 10) + CAST(PROD_ID AS VARCHAR), 10) AS [ProdID],
    RIGHT(REPLICATE(' ', 12) + CAST(TOTAL_HELPFULNESS AS VARCHAR), 12) AS [Helpfulness],
    LEFT(CASE WHEN PROD_ID % {popular_modulo} = 0 THEN '**POPULAR**' ELSE '' END + REPLICATE(' ', 12), 12) AS [Popular]
FROM REVIEWS{store_number}
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
FROM REVIEWS{store_number};

SELECT @TotalHelpfulnessPre = metric_value
FROM VALIDATION_METRICS_{store_number}
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
PRINT 'Reviews for Popular Products (ID % {popular_modulo} = 0):';
PRINT '';

SELECT
    ISNULL(pre.prod_id, post.PROD_ID) AS PROD_ID,
    ISNULL(pre.title, post.TITLE) AS TITLE,
    ISNULL(pre.review_count, 0) AS Pre,
    ISNULL(post.ReviewCount, 0) AS Post,
    ISNULL(post.ReviewCount, 0) - ISNULL(pre.review_count, 0) AS Delta
FROM VALIDATION_POPULAR_REVIEWS_{store_number} pre
FULL OUTER JOIN (
    SELECT
        p.PROD_ID,
        p.TITLE,
        COUNT(r.REVIEW_ID) AS ReviewCount
    FROM PRODUCTS{store_number} p
    LEFT JOIN REVIEWS{store_number} r ON p.PROD_ID = r.PROD_ID
    WHERE p.PROD_ID % {popular_modulo} = 0
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
FROM REVIEWS{store_number} r
LEFT JOIN (
    SELECT REVIEW_ID, SUM(HELPFULNESS) AS CalculatedTotal
    FROM REVIEWS_HELPFULNESS{store_number}
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
    FROM REVIEWS{store_number} r
    LEFT JOIN (
        SELECT REVIEW_ID, SUM(HELPFULNESS) AS CalculatedTotal
        FROM REVIEWS_HELPFULNESS{store_number}
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
FROM PRODUCTS{store_number}
WHERE PRICE - FLOOR(PRICE) = 0.01;

SELECT @ManagerProductsPre = metric_value
FROM VALIDATION_METRICS_{store_number}
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
FROM PRODUCTS{store_number}
WHERE PRICE - FLOOR(PRICE) = 0.01
ORDER BY PROD_ID DESC;

-- Products marked as SPECIAL
DECLARE @SpecialProducts INT, @SpecialProductsPre INT;
SELECT @SpecialProducts = COUNT(*)
FROM PRODUCTS{store_number}
WHERE SPECIAL = 1;

SELECT @SpecialProductsPre = metric_value
FROM VALIDATION_METRICS_{store_number}
WHERE metric_name = 'SPECIAL_PRODUCTS_COUNT';

PRINT 'Products Marked Special (SPECIAL=1):';
PRINT '  Pre:   ' + CAST(@SpecialProductsPre AS VARCHAR);
PRINT '  Post:  ' + CAST(@SpecialProducts AS VARCHAR);
PRINT '  Delta: ' + CAST(@SpecialProducts - @SpecialProductsPre AS VARCHAR);
PRINT '  (MarkSpecials toggles SPECIAL flag)';

-- Price changes (detect products with non-standard pricing)
DECLARE @AdjustedPrices INT, @BulkAdjustedPrices INT;
SELECT @AdjustedPrices = COUNT(*)
FROM PRODUCTS{store_number}
WHERE PRICE - FLOOR(PRICE) != 0.99 AND PRICE - FLOOR(PRICE) != 0.01;
SELECT @BulkAdjustedPrices = COUNT(*)
FROM PRODUCTS{store_number}
WHERE PRICE - FLOOR(PRICE) = 0.77;
PRINT 'Products with Adjusted Prices (not ending in .99 or .01): ' + CAST(@AdjustedPrices AS VARCHAR);
PRINT '  - Prices ending in .77: ' + CAST(@BulkAdjustedPrices AS VARCHAR) + ' (BulkPriceAdjustment: category-wide ±25%)';
PRINT '  - Other endings: ' + CAST(@AdjustedPrices - @BulkAdjustedPrices AS VARCHAR) + ' (AdjustPrices: individual ±10%)';
PRINT '';

PRINT 'Sample Price-Adjusted Products (10 bulk .77 + 10 individual):';
SELECT * FROM (
    SELECT TOP 10
        PROD_ID,
        TITLE,
        ACTOR,
        PRICE,
        SPECIAL,
        COMMON_PROD_ID,
        'Bulk (.77)' AS adjustment_type
    FROM PRODUCTS{store_number}
    WHERE PRICE - FLOOR(PRICE) = 0.77
    ORDER BY PROD_ID
) AS bulk_adjustments
UNION ALL
SELECT * FROM (
    SELECT TOP 10
        PROD_ID,
        TITLE,
        ACTOR,
        PRICE,
        SPECIAL,
        COMMON_PROD_ID,
        'Individual' AS adjustment_type
    FROM PRODUCTS{store_number}
    WHERE PRICE - FLOOR(PRICE) != 0.99
      AND PRICE - FLOOR(PRICE) != 0.01
      AND PRICE - FLOOR(PRICE) != 0.77
    ORDER BY PROD_ID
) AS individual_adjustments
ORDER BY adjustment_type DESC, PROD_ID;

-- Membership expirations
DECLARE @TotalMemberships INT, @TotalMembershipsPre INT;
DECLARE @ExpiredMemberships INT, @ExpiredMembershipsPre INT;

SELECT @TotalMemberships = COUNT(*) FROM MEMBERSHIP{store_number};
SELECT @ExpiredMemberships = COUNT(*) FROM MEMBERSHIP{store_number} WHERE EXPIREDATE < GETDATE();

SELECT @TotalMembershipsPre = metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'TOTAL_MEMBERSHIPS';
SELECT @ExpiredMembershipsPre = metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'EXPIRED_MEMBERSHIPS';

PRINT '';
PRINT 'Membership Status:';
PRINT 'Verifying: Membership changes during benchmark';
PRINT 'Expected: New memberships created, expired memberships may be deleted by ExpireMemberships manager';
PRINT '  Total Memberships:';
PRINT '    Pre:   ' + CAST(@TotalMembershipsPre AS VARCHAR);
PRINT '    Post:  ' + CAST(@TotalMemberships AS VARCHAR);
PRINT '    Delta: ' + CAST(@TotalMemberships - @TotalMembershipsPre AS VARCHAR);
PRINT '  Expired Memberships (EXPIREDATE < current date):';
PRINT '    Pre:   ' + CAST(@ExpiredMembershipsPre AS VARCHAR);
PRINT '    Post:  ' + CAST(@ExpiredMemberships AS VARCHAR);
PRINT '    Delta: ' + CAST(@ExpiredMemberships - @ExpiredMembershipsPre AS VARCHAR);
PRINT '  Active Memberships:';
PRINT '    Pre:   ' + CAST(@TotalMembershipsPre - @ExpiredMembershipsPre AS VARCHAR);
PRINT '    Post:  ' + CAST(@TotalMemberships - @ExpiredMemberships AS VARCHAR);
PRINT '    Delta: ' + CAST((@TotalMemberships - @ExpiredMemberships) - (@TotalMembershipsPre - @ExpiredMembershipsPre) AS VARCHAR);

PRINT '';
PRINT '';

-- =======================================================================
-- BENCHMARK ACTIVITY SUMMARY
-- =======================================================================
PRINT '--- BENCHMARK ACTIVITY SUMMARY ---';
PRINT '';

-- Calculate deltas from baseline
-- =======================================================================
-- CASCADE DELETE VERIFICATION
-- Purpose: Verify REVIEWS_HELPFULNESS cascade deletes when reviews removed
-- Expected: Helpfulness votes deleted when reviews deleted by manager operations
-- =======================================================================
PRINT '';
PRINT '';
PRINT '--- CASCADE DELETE VERIFICATION (REVIEWS_HELPFULNESS) ---';
PRINT 'Verifying: Foreign key CASCADE DELETE when reviews are removed';
PRINT 'Expected: REVIEWS_HELPFULNESS records deleted automatically when parent review deleted';
PRINT 'Note: Users add reviews and managers delete reviews. Disable adding reviews with --ds2_mode=y';
PRINT '';

DECLARE @ReviewsBefore INT, @ReviewsAfter INT, @ReviewsDelta INT;
DECLARE @ReviewsHelpfulnessBefore INT, @ReviewsHelpfulnessAfter INT, @HelpfulnessDeleted INT;

SELECT @ReviewsBefore = metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'REVIEWS_COUNT';
SELECT @ReviewsHelpfulnessBefore = metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'REVIEWS_HELPFULNESS_COUNT';

SELECT @ReviewsAfter = COUNT(*) FROM REVIEWS{store_number};
SELECT @ReviewsHelpfulnessAfter = COUNT(*) FROM REVIEWS_HELPFULNESS{store_number};

SET @ReviewsDelta = @ReviewsAfter - @ReviewsBefore;
SET @HelpfulnessDeleted = @ReviewsHelpfulnessBefore - @ReviewsHelpfulnessAfter;

PRINT 'Reviews:';
PRINT '  Pre:        ' + CAST(@ReviewsBefore AS VARCHAR);
PRINT '  Post:       ' + CAST(@ReviewsAfter AS VARCHAR);
PRINT '  Net change: ' + CAST(@ReviewsDelta AS VARCHAR);

PRINT 'Reviews Helpfulness (should cascade delete with reviews):';
PRINT '  Pre:        ' + CAST(@ReviewsHelpfulnessBefore AS VARCHAR);
PRINT '  Post:       ' + CAST(@ReviewsHelpfulnessAfter AS VARCHAR);
PRINT '  Net change: ' + CAST(-@HelpfulnessDeleted AS VARCHAR);

IF @ReviewsDelta < 0
BEGIN
    DECLARE @AvgHelpfulnessPerReview DECIMAL(10,2);
    SET @AvgHelpfulnessPerReview = CAST(@HelpfulnessDeleted AS DECIMAL(10,2)) / CAST(-@ReviewsDelta AS DECIMAL(10,2));
    PRINT '  Avg helpfulness votes per deleted review: ' + CAST(@AvgHelpfulnessPerReview AS VARCHAR);
END
ELSE
BEGIN
    PRINT '  (Net positive change - cannot verify cascade ratio)';
END

PRINT '';
PRINT '';

-- =======================================================================
-- CASCADE DELETE VERIFICATION (ORDERLINES)
-- Purpose: Verify ORDERLINES cascade deletes when orders removed
-- Expected: Orderlines deleted when orders deleted by manager PurgeOldOrders operation
-- =======================================================================
PRINT '--- CASCADE DELETE VERIFICATION (ORDERLINES) ---';
PRINT 'Verifying: Foreign key CASCADE DELETE when orders are purged';
PRINT 'Expected: ORDERLINES records deleted automatically when parent order deleted';
PRINT 'Note: Users create orders and managers purge old orders.';
PRINT '';

DECLARE @OrdersCascadeBefore INT, @OrdersCascadeAfter INT, @OrdersCascadeDelta INT;
DECLARE @OrderlinesCascadeBefore INT, @OrderlinesCascadeAfter INT, @OrderlinesCascadeDeleted INT;
DECLARE @OldOrdersCascadeBefore INT, @OldOrdersCascadeAfter INT, @OldOrdersCascadeDeleted INT;

SELECT @OrdersCascadeBefore = metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'ORDERS_COUNT';
SELECT @OrderlinesCascadeBefore = metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'ORDERLINES_COUNT';
SELECT @OldOrdersCascadeBefore = metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'OLD_ORDERS_COUNT';

SELECT @OrdersCascadeAfter = COUNT(*) FROM ORDERS{store_number};
SELECT @OrderlinesCascadeAfter = COUNT(*) FROM ORDERLINES{store_number};
SELECT @OldOrdersCascadeAfter = COUNT(*) FROM ORDERS{store_number} WHERE ORDERDATE < CAST(GETDATE() AS DATE);

SET @OrdersCascadeDelta = @OrdersCascadeAfter - @OrdersCascadeBefore;
SET @OrderlinesCascadeDeleted = @OrderlinesCascadeBefore - @OrderlinesCascadeAfter;
SET @OldOrdersCascadeDeleted = @OldOrdersCascadeBefore - @OldOrdersCascadeAfter;

PRINT 'Orders (all):';
PRINT '  Pre:        ' + CAST(@OrdersCascadeBefore AS VARCHAR);
PRINT '  Post:       ' + CAST(@OrdersCascadeAfter AS VARCHAR);
PRINT '  Net change: ' + CAST(@OrdersCascadeDelta AS VARCHAR);

PRINT 'Orders (old - prior to today):';
PRINT '  Pre:        ' + CAST(@OldOrdersCascadeBefore AS VARCHAR);
PRINT '  Post:       ' + CAST(@OldOrdersCascadeAfter AS VARCHAR);
PRINT '  Deleted:    ' + CAST(@OldOrdersCascadeDeleted AS VARCHAR);

PRINT 'Orderlines (should cascade delete with orders):';
PRINT '  Pre:        ' + CAST(@OrderlinesCascadeBefore AS VARCHAR);
PRINT '  Post:       ' + CAST(@OrderlinesCascadeAfter AS VARCHAR);
PRINT '  Net change: ' + CAST(-@OrderlinesCascadeDeleted AS VARCHAR);

IF @OrdersCascadeDelta < 0
BEGIN
    DECLARE @AvgOrderlinesPerOrder DECIMAL(10,2);
    SET @AvgOrderlinesPerOrder = CAST(@OrderlinesCascadeDeleted AS DECIMAL(10,2)) / CAST(-@OrdersCascadeDelta AS DECIMAL(10,2));
    PRINT '  Avg orderlines per purged order: ' + CAST(@AvgOrderlinesPerOrder AS VARCHAR);
    PRINT '  Expected: ~5-6 orderlines per order';
END
ELSE
BEGIN
    PRINT '  (Net positive change - cannot verify cascade ratio)';
END

PRINT '';

-- =======================================================================
-- MEMBERSHIP TIER
-- =======================================================================
PRINT '--- MEMBERSHIP TIER ---';
-- Track net changes from upgrades and new member creation
DECLARE @SilverMembersBefore INT, @SilverMembersAfter INT, @SilverDelta INT;
DECLARE @GoldMembersBefore INT, @GoldMembersAfter INT, @GoldDelta INT;

SELECT @SilverMembersBefore = metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'SILVER_MEMBERS_COUNT';
SELECT @GoldMembersBefore = metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'GOLD_MEMBERS_COUNT';

SELECT @SilverMembersAfter = COUNT(*) FROM MEMBERSHIP{store_number} WHERE MEMBERSHIPTYPE = 2;
SELECT @GoldMembersAfter = COUNT(*) FROM MEMBERSHIP{store_number} WHERE MEMBERSHIPTYPE = 3;

SET @SilverDelta = @SilverMembersAfter - @SilverMembersBefore;
SET @GoldDelta = @GoldMembersAfter - @GoldMembersBefore;

PRINT 'Silver Members (Level 2):';
PRINT '  Pre:   ' + CAST(@SilverMembersBefore AS VARCHAR);
PRINT '  Post:  ' + CAST(@SilverMembersAfter AS VARCHAR);
PRINT '  Delta: ' + CAST(@SilverDelta AS VARCHAR);

PRINT 'Gold Members (Level 3):';
PRINT '  Pre:   ' + CAST(@GoldMembersBefore AS VARCHAR);
PRINT '  Post:  ' + CAST(@GoldMembersAfter AS VARCHAR);
PRINT '  Delta: ' + CAST(@GoldDelta AS VARCHAR);

PRINT '';
PRINT '--- MEMBERSHIP CHANGE TRACKING (Full Snapshot Comparison) ---';
PRINT '';

-- Summary counts of all changes
SELECT
    COUNT(*) AS total_changes,
    SUM(CASE WHEN s.CUSTOMERID IS NOT NULL AND m.CUSTOMERID IS NULL THEN 1 ELSE 0 END) AS deleted,
    SUM(CASE WHEN s.CUSTOMERID IS NULL AND m.CUSTOMERID IS NOT NULL THEN 1 ELSE 0 END) AS new_memberships,
    SUM(CASE WHEN s.MEMBERSHIPTYPE = 1 AND m.MEMBERSHIPTYPE = 2 THEN 1 ELSE 0 END) AS upgrades_1_to_2,
    SUM(CASE WHEN s.MEMBERSHIPTYPE = 2 AND m.MEMBERSHIPTYPE = 3 THEN 1 ELSE 0 END) AS upgrades_2_to_3,
    SUM(CASE WHEN s.MEMBERSHIPTYPE = 1 AND m.MEMBERSHIPTYPE = 3 THEN 1 ELSE 0 END) AS upgrades_1_to_3,
    SUM(CASE WHEN m.MEMBERSHIPTYPE = s.MEMBERSHIPTYPE AND m.EXPIREDATE > s.EXPIREDATE THEN 1 ELSE 0 END) AS extended_only
FROM MEMBERSHIP_SNAPSHOT_{store_number} s
FULL OUTER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
WHERE s.CUSTOMERID IS NULL
   OR m.CUSTOMERID IS NULL
   OR m.MEMBERSHIPTYPE > s.MEMBERSHIPTYPE
   OR m.EXPIREDATE > s.EXPIREDATE;

PRINT '';
PRINT 'Sample Changes by Type (Top 5 of each type):';
PRINT '';

-- Diverse sample: Top 5 of each change type (35 total max)
-- 1->3 jumps (top 5)
SELECT * FROM (
    SELECT TOP 5
        s.CUSTOMERID,
        s.MEMBERSHIPTYPE AS before_level,
        m.MEMBERSHIPTYPE AS after_level,
        CONVERT(VARCHAR(10), s.EXPIREDATE, 120) AS before_expire,
        CONVERT(VARCHAR(10), m.EXPIREDATE, 120) AS after_expire,
        '1->3 JUMP' AS status
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE s.MEMBERSHIPTYPE = 1 AND m.MEMBERSHIPTYPE = 3
    ORDER BY s.CUSTOMERID
) AS jumps_1_to_3

UNION ALL

-- 2->3 upgrades (top 5)
SELECT * FROM (
    SELECT TOP 5
        s.CUSTOMERID,
        s.MEMBERSHIPTYPE AS before_level,
        m.MEMBERSHIPTYPE AS after_level,
        CONVERT(VARCHAR(10), s.EXPIREDATE, 120) AS before_expire,
        CONVERT(VARCHAR(10), m.EXPIREDATE, 120) AS after_expire,
        '2->3 UPGRADE' AS status
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE s.MEMBERSHIPTYPE = 2 AND m.MEMBERSHIPTYPE = 3
    ORDER BY s.CUSTOMERID
) AS upgrades_2_to_3

UNION ALL

-- Deleted memberships (top 5)
SELECT * FROM (
    SELECT TOP 5
        s.CUSTOMERID,
        s.MEMBERSHIPTYPE AS before_level,
        -1 AS after_level,
        CONVERT(VARCHAR(10), s.EXPIREDATE, 120) AS before_expire,
        'N/A' AS after_expire,
        'DELETED' AS status
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    LEFT JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE m.CUSTOMERID IS NULL
    ORDER BY s.CUSTOMERID
) AS deleted_memberships

UNION ALL

-- New memberships (top 5)
SELECT * FROM (
    SELECT TOP 5
        m.CUSTOMERID,
        -1 AS before_level,
        m.MEMBERSHIPTYPE AS after_level,
        'N/A' AS before_expire,
        CONVERT(VARCHAR(10), m.EXPIREDATE, 120) AS after_expire,
        'NEW' AS status
    FROM MEMBERSHIP{store_number} m
    LEFT JOIN MEMBERSHIP_SNAPSHOT_{store_number} s ON m.CUSTOMERID = s.CUSTOMERID
    WHERE s.CUSTOMERID IS NULL
    ORDER BY m.CUSTOMERID
) AS new_memberships

UNION ALL

-- 1->2 upgrades (top 10 - most common)
SELECT * FROM (
    SELECT TOP 10
        s.CUSTOMERID,
        s.MEMBERSHIPTYPE AS before_level,
        m.MEMBERSHIPTYPE AS after_level,
        CONVERT(VARCHAR(10), s.EXPIREDATE, 120) AS before_expire,
        CONVERT(VARCHAR(10), m.EXPIREDATE, 120) AS after_expire,
        '1->2 UPGRADE' AS status
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE s.MEMBERSHIPTYPE = 1 AND m.MEMBERSHIPTYPE = 2
    ORDER BY s.CUSTOMERID
) AS upgrades_1_to_2

UNION ALL

-- Extended only (top 5)
SELECT * FROM (
    SELECT TOP 5
        s.CUSTOMERID,
        s.MEMBERSHIPTYPE AS before_level,
        m.MEMBERSHIPTYPE AS after_level,
        CONVERT(VARCHAR(10), s.EXPIREDATE, 120) AS before_expire,
        CONVERT(VARCHAR(10), m.EXPIREDATE, 120) AS after_expire,
        'EXTENDED' AS status
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE s.MEMBERSHIPTYPE = m.MEMBERSHIPTYPE AND m.EXPIREDATE > s.EXPIREDATE
    ORDER BY s.CUSTOMERID
) AS extended_only;

PRINT '';
PRINT '========================================================================';
PRINT '--- MEMBER-SPECIFIC PURCHASE BEHAVIOR ---';
PRINT 'Verifying: Members buy primarily from their membership tier';
PRINT 'Expected: ~70% of purchases match member tier (tier 1->tier 1, etc.)';
PRINT 'Expected: ~30% spillover to other tiers when cart exceeds browse results';
PRINT '========================================================================';
PRINT '';

SELECT
    member_tier,
    product_tier,
    purchase_count,
    CAST(ROUND(purchase_count * 100.0 / tier_total, 2) AS DECIMAL(10,2)) AS pct_of_tier_purchases
FROM (
    SELECT
        m.MEMBERSHIPTYPE AS member_tier,
        p.MEMBERSHIP_ITEM AS product_tier,
        COUNT(*) AS purchase_count,
        SUM(COUNT(*)) OVER (PARTITION BY m.MEMBERSHIPTYPE) AS tier_total
    FROM MEMBERSHIP{store_number} m
    INNER JOIN ORDERS{store_number} o ON m.CUSTOMERID = o.CUSTOMERID
    INNER JOIN ORDERLINES{store_number} ol ON o.ORDERID = ol.ORDERID
    INNER JOIN PRODUCTS{store_number} p ON ol.PROD_ID = p.PROD_ID
    WHERE o.ORDERID > (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'ORDERS_COUNT')
      AND m.EXPIREDATE > GETDATE()
    GROUP BY m.MEMBERSHIPTYPE, p.MEMBERSHIP_ITEM
) AS tier_purchases
ORDER BY member_tier, product_tier;

PRINT '';

-- =======================================================================
-- CART SIZE BY MEMBERSHIP TIER (validates unlimited cart feature)
-- =======================================================================
PRINT '';
PRINT '========================================================================';
PRINT '--- CART SIZE BY MEMBERSHIP TIER ---';
PRINT 'Verifying: Cart size formula and unlimited cart feature';
PRINT 'Expected: Average cart size = Random(1, 2*n_line_items) + tier';
PRINT 'Expected: Max cart size >10 when n_line_items >5 (proves PURCHASE_TVP works)';
PRINT 'Expected: Min cart size = 1 for N/A, 2 for tier 1, 3 for tier 2, 4 for tier 3';
PRINT 'NOTE: Customers becoming members or changing tiers after placing orders';
PRINT '      will cause historical orders to be classified by their current tier,';
PRINT '      potentially reducing Min cart size results.';
PRINT '========================================================================';
PRINT '';

SELECT
  CASE
    WHEN m.MEMBERSHIPTYPE IS NULL THEN 'N/A'
    ELSE CAST(m.MEMBERSHIPTYPE AS VARCHAR(3))
  END AS tier,
  COUNT(DISTINCT o.ORDERID) AS orders,
  SUM(ol_counts.item_count) AS total_items,
  MIN(ol_counts.item_count) AS min_items,
  CAST(AVG(CAST(ol_counts.item_count AS DECIMAL(10,2))) AS DECIMAL(10,2)) AS avg_items,
  MAX(ol_counts.item_count) AS max_items
FROM ORDERS{store_number} o
LEFT JOIN MEMBERSHIP{store_number} m ON o.CUSTOMERID = m.CUSTOMERID
  AND m.EXPIREDATE >= o.ORDERDATE  -- Only active memberships at order time
JOIN (
  SELECT ORDERID, COUNT(*) AS item_count
  FROM ORDERLINES{store_number}
  GROUP BY ORDERID
) ol_counts ON o.ORDERID = ol_counts.ORDERID
WHERE o.ORDERID > (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'ORDERS_COUNT')
GROUP BY m.MEMBERSHIPTYPE
ORDER BY ISNULL(m.MEMBERSHIPTYPE, -999);

PRINT '';

-- =======================================================================
-- PROMOTIONAL MEMBERSHIP AUDIT
-- =======================================================================
PRINT '';
PRINT '========================================================================';
PRINT '--- PROMOTIONAL MEMBERSHIP AUDIT ---';
PRINT 'Verifying: PromotionalMembership MERGE operations tracked correctly';
PRINT 'Expected: INSERT path creates tier 1 with 90-day expiration';
PRINT 'Expected: UPDATE path shows sequential upgrades (1->2, 2->3) or tier 3 extensions';
PRINT '========================================================================';
PRINT '';

-- Operation summary (INSERT vs UPDATE)
SELECT
    OPERATION_TYPE,
    COUNT(*) AS operation_count,
    CAST(AVG(CASE WHEN OLD_TIER IS NULL THEN 0 ELSE 1 END) * 100 AS DECIMAL(5,2)) AS pct_had_membership
FROM MEMBERSHIP_PROMO_AUDIT{store_number}
GROUP BY OPERATION_TYPE;

PRINT '';

-- Verify INSERT path: all new memberships are tier 1 with 90-day expiration
DECLARE @new_tier1_90day INT;
SELECT @new_tier1_90day = COUNT(*)
FROM MEMBERSHIP_PROMO_AUDIT{store_number}
WHERE OPERATION_TYPE = 'INSERT'
  AND NEW_TIER = 1
  AND NEW_EXPIREDATE BETWEEN DATEADD(day, 89, GETDATE()) AND DATEADD(day, 91, GETDATE());

PRINT 'New memberships (tier 1, 90-day expiration): ' + CAST(@new_tier1_90day AS VARCHAR);

PRINT '';

-- Verify UPDATE path: tier upgrades are sequential (1->2, 2->3)
SELECT
    OLD_TIER AS from_tier,
    NEW_TIER AS to_tier,
    COUNT(*) AS upgrade_count
FROM MEMBERSHIP_PROMO_AUDIT{store_number}
WHERE OPERATION_TYPE = 'UPDATE'
  AND OLD_TIER < 3
GROUP BY OLD_TIER, NEW_TIER
ORDER BY OLD_TIER, NEW_TIER;

PRINT '';

-- Verify tier 3 extensions are ~90 days
DECLARE @tier3_extensions INT;
SELECT @tier3_extensions = COUNT(*)
FROM MEMBERSHIP_PROMO_AUDIT{store_number}
WHERE OPERATION_TYPE = 'UPDATE'
  AND OLD_TIER = 3
  AND NEW_TIER = 3
  AND DATEDIFF(day, OLD_EXPIREDATE, NEW_EXPIREDATE) BETWEEN 89 AND 91;

PRINT 'Tier 3 extensions (90-day): ' + CAST(@tier3_extensions AS VARCHAR);

PRINT '';

-- Sample operations (3 of each type)
SELECT TOP 3
    CUSTOMERID,
    NULL AS old_tier,
    NEW_TIER AS new_tier,
    CONVERT(VARCHAR(10), NEW_EXPIREDATE, 120) AS new_expire,
    OPERATION_TYPE,
    OPERATION_TIMESTAMP
FROM MEMBERSHIP_PROMO_AUDIT{store_number}
WHERE OPERATION_TYPE = 'INSERT'

UNION ALL

SELECT TOP 3
    CUSTOMERID,
    OLD_TIER AS old_tier,
    NEW_TIER AS new_tier,
    CONVERT(VARCHAR(10), NEW_EXPIREDATE, 120) AS new_expire,
    'UPDATE (1->2)' AS OPERATION_TYPE,
    OPERATION_TIMESTAMP
FROM MEMBERSHIP_PROMO_AUDIT{store_number}
WHERE OPERATION_TYPE = 'UPDATE' AND OLD_TIER = 1 AND NEW_TIER = 2

UNION ALL

SELECT TOP 3
    CUSTOMERID,
    OLD_TIER AS old_tier,
    NEW_TIER AS new_tier,
    CONVERT(VARCHAR(10), NEW_EXPIREDATE, 120) AS new_expire,
    'UPDATE (2->3)' AS OPERATION_TYPE,
    OPERATION_TIMESTAMP
FROM MEMBERSHIP_PROMO_AUDIT{store_number}
WHERE OPERATION_TYPE = 'UPDATE' AND OLD_TIER = 2 AND NEW_TIER = 3

UNION ALL

SELECT TOP 3
    CUSTOMERID,
    OLD_TIER AS old_tier,
    NEW_TIER AS new_tier,
    CONVERT(VARCHAR(10), NEW_EXPIREDATE, 120) AS new_expire,
    'UPDATE (3->3 ext)' AS OPERATION_TYPE,
    OPERATION_TIMESTAMP
FROM MEMBERSHIP_PROMO_AUDIT{store_number}
WHERE OPERATION_TYPE = 'UPDATE' AND OLD_TIER = 3 AND NEW_TIER = 3

ORDER BY OPERATION_TYPE, OPERATION_TIMESTAMP;

PRINT '';

-- =======================================================================
-- NEW RECORDS CREATED DURING BENCHMARK
-- =======================================================================
DECLARE @CustomersBefore INT, @CustomersAfter INT, @CustomersDelta INT;
DECLARE @OrdersBefore INT, @OrdersAfter INT, @OrdersDelta INT;
DECLARE @ReviewsBeforeNew INT, @ReviewsAfterNew INT, @ReviewsDeltaNew INT;
DECLARE @ProductsBefore INT, @ProductsAfter INT, @ProductsDelta INT;
DECLARE @MembershipsBefore INT, @MembershipsAfter INT, @MembershipsDelta INT;

SELECT @CustomersBefore = metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'CUSTOMERS_COUNT';
SELECT @OrdersBefore = metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'ORDERS_COUNT';
SELECT @ReviewsBeforeNew = metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'REVIEWS_COUNT';
SELECT @ProductsBefore = metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'PRODUCTS_COUNT';
SELECT @MembershipsBefore = metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MEMBERSHIP_COUNT';

SELECT @CustomersAfter = COUNT(*) FROM CUSTOMERS{store_number};
SELECT @OrdersAfter = COUNT(*) FROM ORDERS{store_number};
SELECT @ReviewsAfterNew = COUNT(*) FROM REVIEWS{store_number};
SELECT @ProductsAfter = COUNT(*) FROM PRODUCTS{store_number};
SELECT @MembershipsAfter = COUNT(*) FROM MEMBERSHIP{store_number};

SET @CustomersDelta = @CustomersAfter - @CustomersBefore;
SET @OrdersDelta = @OrdersAfter - @OrdersBefore;
SET @ReviewsDeltaNew = @ReviewsAfterNew - @ReviewsBeforeNew;
SET @ProductsDelta = @ProductsAfter - @ProductsBefore;
SET @MembershipsDelta = @MembershipsAfter - @MembershipsBefore;

PRINT 'New Records Created During Benchmark:';
PRINT '  Customers:   ' + CAST(@CustomersDelta AS VARCHAR);
PRINT '  Orders:      ' + CAST(@OrdersDelta AS VARCHAR);
PRINT '  Reviews:     ' + CAST(@ReviewsDeltaNew AS VARCHAR);
PRINT '  Products:    ' + CAST(@ProductsDelta AS VARCHAR);
PRINT '  Memberships: ' + CAST(@MembershipsDelta AS VARCHAR);

SELECT @AdjustedPrices = COUNT(*)
FROM PRODUCTS{store_number}
WHERE (PRICE - FLOOR(PRICE)) != 0.99 AND (PRICE - FLOOR(PRICE)) != 0.01;

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

DECLARE @CustomersBaseline BIGINT;
SELECT @CustomersBaseline = metric_value
FROM VALIDATION_METRICS_{store_number}
WHERE metric_name = 'CUSTOMERS_COUNT';

SELECT TOP 10
    RIGHT(REPLICATE(' ', 10) + CAST(CUSTOMERID AS VARCHAR), 10) AS [CustomerID],
    LEFT(FIRSTNAME + REPLICATE(' ', 20), 20) AS [FirstName],
    LEFT(LASTNAME + REPLICATE(' ', 20), 20) AS [LastName],
    LEFT(CITY + REPLICATE(' ', 20), 20) AS [City]
FROM CUSTOMERS{store_number}
WHERE CUSTOMERID > @CustomersBaseline
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
FROM VALIDATION_METRICS_{store_number}
WHERE metric_name = 'MAX_PROD_ID';

DECLARE @NewProductsAdded INT;
DECLARE @NewProductsWithInventory INT;
DECLARE @NewProductsPurchased INT;
DECLARE @NewProductsReordered INT;

SELECT @NewProductsAdded = COUNT(*)
FROM PRODUCTS{store_number}
WHERE PROD_ID > @MaxProdIDPre;

SELECT @NewProductsWithInventory = COUNT(DISTINCT i.PROD_ID)
FROM INVENTORY{store_number} i
WHERE i.PROD_ID > @MaxProdIDPre;

SELECT @NewProductsPurchased = COUNT(DISTINCT ol.PROD_ID)
FROM ORDERLINES{store_number} ol
WHERE ol.PROD_ID > @MaxProdIDPre;

SELECT @NewProductsReordered = COUNT(DISTINCT r.PROD_ID)
FROM REORDER{store_number} r
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
FROM REORDER{store_number} r
JOIN PRODUCTS{store_number} p ON r.PROD_ID = p.PROD_ID
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
PRINT '--- MERGE/UPSERT VALIDATION: NEW_REVIEW_HELPFULNESS ---';
PRINT 'Verifies MERGE operations prevent duplicate (REVIEW_ID, CUSTOMERID) ratings';
PRINT '';

-- Check for duplicate helpfulness ratings (should be 0 after MERGE conversion)
DECLARE @duplicate_count INT;
SELECT @duplicate_count = COUNT(*)
FROM (
    SELECT REVIEW_ID, CUSTOMERID
    FROM REVIEWS_HELPFULNESS{store_number}
    GROUP BY REVIEW_ID, CUSTOMERID
    HAVING COUNT(*) > 1
) AS dupes;

PRINT 'Duplicate helpfulness ratings: ' + CAST(@duplicate_count AS VARCHAR);
IF @duplicate_count = 0
    PRINT 'SUCCESS: No duplicate ratings found (MERGE is working correctly)';
ELSE
BEGIN
    PRINT 'ERROR: Found ' + CAST(@duplicate_count AS VARCHAR) + ' duplicate (REVIEW_ID, CUSTOMERID) pairs!';
    PRINT 'Top 10 duplicates:';
    SELECT TOP 10
        REVIEW_ID,
        CUSTOMERID,
        COUNT(*) as rating_count,
        STRING_AGG(CAST(HELPFULNESS AS VARCHAR), ', ') as all_ratings
    FROM REVIEWS_HELPFULNESS{store_number}
    GROUP BY REVIEW_ID, CUSTOMERID
    HAVING COUNT(*) > 1
    ORDER BY rating_count DESC;
END

PRINT '';
PRINT 'MERGE Operation Statistics (INSERT vs UPDATE):';
SELECT
    OPERATION,
    COUNT(*) as operation_count,
    MIN(AUDIT_TIMESTAMP) as first_operation,
    MAX(AUDIT_TIMESTAMP) as last_operation
FROM MERGE_AUDIT{store_number}
WHERE TABLE_NAME = 'REVIEWS_HELPFULNESS'
GROUP BY OPERATION
ORDER BY OPERATION;

PRINT '';
DECLARE @insert_count INT, @update_count INT, @total_ops INT;
SELECT
    @insert_count = SUM(CASE WHEN OPERATION = 'INSERT' THEN 1 ELSE 0 END),
    @update_count = SUM(CASE WHEN OPERATION = 'UPDATE' THEN 1 ELSE 0 END),
    @total_ops = COUNT(*)
FROM MERGE_AUDIT{store_number}
WHERE TABLE_NAME = 'REVIEWS_HELPFULNESS';

IF @total_ops > 0
BEGIN
    PRINT 'Total MERGE operations: ' + CAST(@total_ops AS VARCHAR);
    PRINT '  INSERTs (new ratings): ' + CAST(@insert_count AS VARCHAR) + ' (' + CAST(ROUND(100.0 * @insert_count / @total_ops, 1) AS VARCHAR(20)) + '%)';
    PRINT '  UPDATEs (rating changes): ' + CAST(@update_count AS VARCHAR) + ' (' + CAST(ROUND(100.0 * @update_count / @total_ops, 1) AS VARCHAR(20)) + '%)';
    IF @update_count > 0
        PRINT 'SUCCESS: MERGE UPDATE path is working (customers changing their ratings)';
    ELSE
        PRINT 'INFO: No UPDATEs observed (expected with large databases - low collision probability)';

    PRINT '';
    PRINT 'Sample MERGE Operations (Top 5 INSERTs, Top 5 UPDATEs):';
    PRINT '';
    PRINT '--- Sample INSERTs (First Ratings) ---';
    SELECT TOP 5
        AUDIT_ID,
        REVIEW_ID,
        CUSTOMERID,
        NEW_HELPFULNESS as Helpfulness,
        AUDIT_TIMESTAMP as Timestamp
    FROM MERGE_AUDIT{store_number}
    WHERE TABLE_NAME = 'REVIEWS_HELPFULNESS' AND OPERATION = 'INSERT'
    ORDER BY AUDIT_ID;

    PRINT '';
    PRINT '--- Sample UPDATEs (Rating Changes) ---';
    SELECT TOP 5
        AUDIT_ID,
        REVIEW_ID,
        CUSTOMERID,
        OLD_HELPFULNESS as Old_Rating,
        NEW_HELPFULNESS as New_Rating,
        (NEW_HELPFULNESS - OLD_HELPFULNESS) as Change,
        AUDIT_TIMESTAMP as Timestamp
    FROM MERGE_AUDIT{store_number}
    WHERE TABLE_NAME = 'REVIEWS_HELPFULNESS' AND OPERATION = 'UPDATE'
    ORDER BY AUDIT_ID;
END
ELSE
    PRINT 'INFO: No MERGE operations recorded (pct_newhelpfulness may be 0 or disabled)';

PRINT '';
PRINT '';

-- =======================================================================
-- NEW CUSTOMER LOGIN VERIFICATION
-- Purpose: Verify new customers (created during test) can log in again
-- Expected: Some new customers should have multiple orders
-- =======================================================================
PRINT '--- NEW CUSTOMER LOGIN VERIFICATION (Returning New Customers) ---';
PRINT 'Verifying: New customers created during test make multiple purchases';
PRINT '';

-- Reuse @CustomersBaseline from earlier section
DECLARE @NewCustomersCreated INT;
DECLARE @NewCustomersWithMultipleOrders INT;
DECLARE @NewCustomersTotalOrders INT;

SELECT @NewCustomersCreated = COUNT(DISTINCT CUSTOMERID)
FROM CUSTOMERS{store_number}
WHERE CUSTOMERID > @CustomersBaseline;

SELECT @NewCustomersWithMultipleOrders = COUNT(DISTINCT CUSTOMERID)
FROM (
    SELECT CUSTOMERID, COUNT(*) as order_count
    FROM ORDERS{store_number}
    WHERE CUSTOMERID > @CustomersBaseline
    GROUP BY CUSTOMERID
    HAVING COUNT(*) > 1
) subq;

SELECT @NewCustomersTotalOrders = COUNT(*)
FROM ORDERS{store_number}
WHERE CUSTOMERID > @CustomersBaseline;

PRINT 'New Customers Created:                 ' + CAST(@NewCustomersCreated AS VARCHAR);
PRINT 'New Customers with Multiple Orders:    ' + CAST(@NewCustomersWithMultipleOrders AS VARCHAR);
PRINT 'Total Orders from New Customers:       ' + CAST(@NewCustomersTotalOrders AS VARCHAR);
PRINT '';

-- Distribution of orders per new customer
PRINT 'Order Distribution for New Customers:';
SELECT
    CASE
        WHEN order_count = 1 THEN '1 order'
        WHEN order_count = 2 THEN '2 orders'
        WHEN order_count = 3 THEN '3 orders'
        WHEN order_count >= 4 THEN '4+ orders'
    END as Order_Bucket,
    COUNT(*) as Customer_Count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as Percentage
FROM (
    SELECT CUSTOMERID, COUNT(*) as order_count
    FROM ORDERS{store_number}
    WHERE CUSTOMERID > @CustomersBaseline
    GROUP BY CUSTOMERID
) subq
GROUP BY
    CASE
        WHEN order_count = 1 THEN '1 order'
        WHEN order_count = 2 THEN '2 orders'
        WHEN order_count = 3 THEN '3 orders'
        WHEN order_count >= 4 THEN '4+ orders'
    END
ORDER BY Order_Bucket;

PRINT '';
PRINT 'Top 10 New Customers by Order Count:';
SELECT TOP 10
    CUSTOMERID,
    COUNT(*) as Order_Count,
    SUM(TOTALAMOUNT) as Total_Revenue,
    CONVERT(VARCHAR(10), MIN(ORDERDATE), 101) as First_Order,
    CONVERT(VARCHAR(10), MAX(ORDERDATE), 101) as Last_Order
FROM ORDERS{store_number}
WHERE CUSTOMERID > @CustomersBaseline
GROUP BY CUSTOMERID
ORDER BY COUNT(*) DESC, Total_Revenue DESC;

PRINT '';
PRINT '========================================================================';
PRINT 'Post-Test Validation Complete';
PRINT 'Compare these results with validate_before.sql to verify:';
PRINT '  1. GetSkewedProductId: Popular products (ID % {popular_modulo}) have highest sales';
PRINT '  2. Restock Trigger: REORDER table shows restocking for sold-out products';
PRINT '  3. Review Operations: New reviews created, helpfulness scores increased';
PRINT '  4. Manager Operations: New products added, prices adjusted, specials toggled';
PRINT '  5. Customer Growth: New customers and orders created during benchmark';
PRINT '  6. AddProduct Validation: New products have inventory and are being purchased';
PRINT '========================================================================';
