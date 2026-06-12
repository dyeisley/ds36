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
    END, 12) AS `Post`,
    LPAD(CASE REPLACE(m.metric_name, '_COUNT', '')
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
    END, 12) AS `Delta`
FROM VALIDATION_METRICS_{store_number} m
WHERE m.metric_name LIKE '%_COUNT'
    AND m.metric_name NOT IN ('MANAGER_PRODUCTS_COUNT', 'SPECIAL_PRODUCTS_COUNT', 'OLD_ORDERS_COUNT', 'SILVER_MEMBERS_COUNT', 'GOLD_MEMBERS_COUNT')
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
-- FROM CUST_HIST{store_number} ch
-- JOIN CUSTOMERS{store_number} c ON ch.CUSTOMERID = c.CUSTOMERID
-- GROUP BY ch.CUSTOMERID, c.FIRSTNAME, c.LASTNAME
-- ORDER BY COUNT(*) DESC
-- LIMIT 5;
--
-- SELECT '';
-- SELECT '';

-- =======================================================================
-- TOP 10 INVENTORY BY SALES
-- Purpose: Verify GetSkewedProductId distribution
-- Expected: Products divisible by {popular_modulo} should dominate top sales
-- =======================================================================
SELECT '--- TOP 10 INVENTORY BY SALES (GetSkewedProductId Verification) ---';
SELECT 'Verifying: Skewed product selection worked correctly';
SELECT 'Expected: Products divisible by {popular_modulo} should appear in top 10 with higher SALES';
SELECT 'Expected: SALES values should be significantly higher than pre-test baseline';
SELECT '';

SELECT
    i.PROD_ID,
    LEFT(p.TITLE, 30) AS TITLE,
    i.SALES,
    CASE
        WHEN i.PROD_ID % {popular_modulo} = 0 THEN '**POPULAR**'
        ELSE ''
    END AS IsPopularProduct
FROM INVENTORY{store_number} i
JOIN PRODUCTS{store_number} p ON i.PROD_ID = p.PROD_ID
ORDER BY i.SALES DESC
LIMIT 10;

SELECT '';
SELECT '';

-- Summary statistics on popular vs non-popular products
SET @popular_sales = (SELECT SUM(SALES) FROM INVENTORY{store_number} WHERE PROD_ID % {popular_modulo} = 0);
SET @popular_count = (SELECT COUNT(*) FROM INVENTORY{store_number} WHERE PROD_ID % {popular_modulo} = 0);
SET @non_popular_sales = (SELECT SUM(SALES) FROM INVENTORY{store_number} WHERE PROD_ID % {popular_modulo} != 0);
SET @non_popular_count = (SELECT COUNT(*) FROM INVENTORY{store_number} WHERE PROD_ID % {popular_modulo} != 0);

SELECT 'GetSkewedProductId Effectiveness:';
SELECT '  Popular Products (ID % {popular_modulo} = 0):';
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
SELECT '';

SELECT
    r.PROD_ID,
    LEFT(p.TITLE, 30) AS TITLE,
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
ORDER BY SUM(r.QUAN_REORDERED) DESC
LIMIT 20;

SELECT '';
SELECT '';

-- Reorder statistics
SET @total_reorders = (SELECT COUNT(*) FROM REORDER{store_number});
SET @popular_reorders = (SELECT COUNT(*) FROM REORDER{store_number} WHERE PROD_ID % {popular_modulo} = 0);

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
FROM VALIDATION_TOP_REVIEWS_{store_number} t
ORDER BY t.rank_position;

SELECT '';

SELECT 'Post-Test Top 10:';
SELECT
    @rownum := @rownum + 1 AS `Rank`,
    REVIEW_ID AS `ReviewID`,
    PROD_ID AS `ProdID`,
    TOTAL_HELPFULNESS AS `Helpfulness`,
    CASE WHEN PROD_ID % {popular_modulo} = 0 THEN '**POPULAR**' ELSE '' END AS `Popular`
FROM REVIEWS{store_number}
CROSS JOIN (SELECT @rownum := 0) AS init
ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID
LIMIT 10;

SELECT '';
SELECT '';

-- Review statistics
SET @total_reviews = (SELECT COUNT(*) FROM REVIEWS{store_number});
SET @avg_helpfulness = (SELECT AVG(TOTAL_HELPFULNESS) FROM REVIEWS{store_number});
SET @max_helpfulness = (SELECT MAX(TOTAL_HELPFULNESS) FROM REVIEWS{store_number});
SET @total_helpfulness = (SELECT IFNULL(SUM(TOTAL_HELPFULNESS), 0) FROM REVIEWS{store_number});
SET @total_helpfulness_pre = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'TOTAL_HELPFULNESS');
SELECT 'Review Statistics:';
SELECT CONCAT('  Total Reviews: ', @total_reviews);
SELECT CONCAT('  Avg Helpfulness: ', ROUND(@avg_helpfulness, 2));
SELECT CONCAT('  Max Helpfulness: ', @max_helpfulness);
SELECT '  Total Helpfulness (sum):';
SELECT CONCAT('    Pre:   ', @total_helpfulness_pre);
SELECT CONCAT('    Post:  ', @total_helpfulness);
SELECT CONCAT('    Delta: ', @total_helpfulness - @total_helpfulness_pre);
SELECT 'Reviews for Popular Products (ID % {popular_modulo} = 0):';

SELECT
    IFNULL(pre.prod_id, post.PROD_ID) AS PROD_ID,
    LEFT(IFNULL(pre.title, post.TITLE), 30) AS TITLE,
    IFNULL(pre.review_count, 0) AS Pre,
    IFNULL(post.ReviewCount, 0) AS Post,
    IFNULL(post.ReviewCount, 0) - IFNULL(pre.review_count, 0) AS Delta
FROM VALIDATION_POPULAR_REVIEWS_{store_number} pre
LEFT JOIN (
    SELECT
        p.PROD_ID,
        p.TITLE,
        COUNT(r.REVIEW_ID) AS ReviewCount
    FROM PRODUCTS{store_number} p
    LEFT JOIN REVIEWS{store_number} r ON p.PROD_ID = r.PROD_ID
    WHERE p.PROD_ID % {popular_modulo} = 0
    GROUP BY p.PROD_ID, p.TITLE
) post ON pre.prod_id = post.PROD_ID
UNION
SELECT
    post.PROD_ID,
    LEFT(post.TITLE, 30),
    IFNULL(pre.review_count, 0),
    IFNULL(post.ReviewCount, 0),
    IFNULL(post.ReviewCount, 0) - IFNULL(pre.review_count, 0)
FROM VALIDATION_POPULAR_REVIEWS_{store_number} pre
RIGHT JOIN (
    SELECT
        p.PROD_ID,
        p.TITLE,
        COUNT(r.REVIEW_ID) AS ReviewCount
    FROM PRODUCTS{store_number} p
    LEFT JOIN REVIEWS{store_number} r ON p.PROD_ID = r.PROD_ID
    WHERE p.PROD_ID % {popular_modulo} = 0
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
    FROM REVIEWS{store_number} r
    LEFT JOIN (
        SELECT REVIEW_ID, SUM(HELPFULNESS) AS CalculatedTotal
        FROM REVIEWS_HELPFULNESS{store_number}
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
FROM REVIEWS{store_number} r
LEFT JOIN (
    SELECT REVIEW_ID, SUM(HELPFULNESS) AS CalculatedTotal
    FROM REVIEWS_HELPFULNESS{store_number}
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
SET @manager_products = (SELECT COUNT(*) FROM PRODUCTS{store_number} WHERE PRICE - FLOOR(PRICE) = 0.01);
SET @manager_products_pre = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MANAGER_PRODUCTS_COUNT');

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
FROM PRODUCTS{store_number}
WHERE PRICE - FLOOR(PRICE) = 0.01
ORDER BY PROD_ID DESC
LIMIT 10;

-- Products marked as SPECIAL
SET @special_products = (SELECT COUNT(*) FROM PRODUCTS{store_number} WHERE SPECIAL = 1);
SET @special_products_pre = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'SPECIAL_PRODUCTS_COUNT');

SELECT 'Products Marked Special (SPECIAL=1):';
SELECT CONCAT('  Pre:   ', @special_products_pre);
SELECT CONCAT('  Post:  ', @special_products);
SELECT CONCAT('  Delta: ', @special_products - @special_products_pre);
SELECT '  (MarkSpecials toggles SPECIAL flag)';

-- Price changes (detect products with non-standard pricing)
SET @adjusted_prices = (SELECT COUNT(*) FROM PRODUCTS{store_number} WHERE (PRICE - FLOOR(PRICE)) != 0.99 AND (PRICE - FLOOR(PRICE)) != 0.01);
SET @bulk_adjusted_prices = (SELECT COUNT(*) FROM PRODUCTS{store_number} WHERE (PRICE - FLOOR(PRICE)) = 0.77);

SELECT CONCAT('Products with Adjusted Prices (not ending in .99 or .01): ', @adjusted_prices);
SELECT CONCAT('  - Prices ending in .77: ', @bulk_adjusted_prices, ' (BulkPriceAdjustment: category-wide ±25%)');
SELECT CONCAT('  - Other endings: ', @adjusted_prices - @bulk_adjusted_prices, ' (AdjustPrices: individual ±10%)');

SELECT 'Sample Price-Adjusted Products (10 bulk .77 + 10 individual):';
(
    SELECT
        LPAD(PROD_ID, 8) AS PROD_ID,
        RPAD(TITLE, 40) AS TITLE,
        RPAD(ACTOR, 30) AS ACTOR,
        LPAD(FORMAT(PRICE, 2), 10) AS PRICE,
        LPAD(SPECIAL, 7) AS SPECIAL,
        LPAD(COMMON_PROD_ID, 13) AS COMMON_PROD_ID,
        'Bulk (.77)' AS adjustment_type
    FROM PRODUCTS{store_number}
    WHERE (PRICE - FLOOR(PRICE)) = 0.77
    ORDER BY PROD_ID
    LIMIT 10
)
UNION ALL
(
    SELECT
        LPAD(PROD_ID, 8) AS PROD_ID,
        RPAD(TITLE, 40) AS TITLE,
        RPAD(ACTOR, 30) AS ACTOR,
        LPAD(FORMAT(PRICE, 2), 10) AS PRICE,
        LPAD(SPECIAL, 7) AS SPECIAL,
        LPAD(COMMON_PROD_ID, 13) AS COMMON_PROD_ID,
        'Individual' AS adjustment_type
    FROM PRODUCTS{store_number}
    WHERE (PRICE - FLOOR(PRICE)) != 0.99
      AND (PRICE - FLOOR(PRICE)) != 0.01
      AND (PRICE - FLOOR(PRICE)) != 0.77
    ORDER BY PROD_ID
    LIMIT 10
)
ORDER BY adjustment_type DESC, PROD_ID;

-- Membership expirations
SET @total_memberships = (SELECT COUNT(*) FROM MEMBERSHIP{store_number});
SET @expired_memberships = (SELECT COUNT(*) FROM MEMBERSHIP{store_number} WHERE EXPIREDATE < NOW());
SET @total_memberships_pre = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'TOTAL_MEMBERSHIPS');
SET @expired_memberships_pre = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'EXPIRED_MEMBERSHIPS');

SELECT '';
SELECT 'Membership Status:';
SELECT 'Verifying: Membership changes during benchmark';
SELECT 'Expected: New memberships created, expired memberships may be deleted by ExpireMemberships manager';
SELECT '  Total Memberships:';
SELECT CONCAT('    Pre:   ', @total_memberships_pre);
SELECT CONCAT('    Post:  ', @total_memberships);
SELECT CONCAT('    Delta: ', @total_memberships - @total_memberships_pre);
SELECT '  Expired Memberships (EXPIREDATE < current date):';
SELECT CONCAT('    Pre:   ', @expired_memberships_pre);
SELECT CONCAT('    Post:  ', @expired_memberships);
SELECT CONCAT('    Delta: ', @expired_memberships - @expired_memberships_pre);
SELECT '  Active Memberships:';
SELECT CONCAT('    Pre:   ', @total_memberships_pre - @expired_memberships_pre);
SELECT CONCAT('    Post:  ', @total_memberships - @expired_memberships);
SELECT CONCAT('    Delta: ', (@total_memberships - @expired_memberships) - (@total_memberships_pre - @expired_memberships_pre));

SELECT '';
SELECT '';

-- =======================================================================
-- CASCADE DELETE VERIFICATION
-- Purpose: Verify REVIEWS_HELPFULNESS cascade deletes when reviews removed
-- Expected: Helpfulness votes deleted when reviews deleted by manager operations
-- =======================================================================
SELECT '--- CASCADE DELETE VERIFICATION (REVIEWS_HELPFULNESS) ---';
SELECT 'Verifying: Foreign key CASCADE DELETE when reviews are removed';
SELECT 'Expected: REVIEWS_HELPFULNESS records deleted automatically when parent review deleted';
SELECT 'Note: Users add reviews and managers delete reviews. Disable adding reviews with --ds2_mode=y';
SELECT '';

SET @reviews_before = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'REVIEWS_COUNT');
SET @reviews_helpfulness_before = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'REVIEWS_HELPFULNESS_COUNT');

SET @reviews_after = (SELECT COUNT(*) FROM REVIEWS{store_number});
SET @reviews_helpfulness_after = (SELECT COUNT(*) FROM REVIEWS_HELPFULNESS{store_number});

SET @reviews_delta = @reviews_after - @reviews_before;
SET @helpfulness_deleted = @reviews_helpfulness_before - @reviews_helpfulness_after;

SELECT 'Reviews:';
SELECT CONCAT('  Pre:        ', @reviews_before);
SELECT CONCAT('  Post:       ', @reviews_after);
SELECT CONCAT('  Net change: ', @reviews_delta);

SELECT 'Reviews Helpfulness (should cascade delete with reviews):';
SELECT CONCAT('  Pre:        ', @reviews_helpfulness_before);
SELECT CONCAT('  Post:       ', @reviews_helpfulness_after);
SELECT CONCAT('  Net change: ', -@helpfulness_deleted);

SELECT IF(@reviews_delta < 0,
    CONCAT('  Avg helpfulness votes per deleted review: ', ROUND(@helpfulness_deleted / -@reviews_delta, 2)),
    '  (Net positive change - cannot verify cascade ratio)') AS CascadeVerification;

SELECT '';
SELECT '';

-- =======================================================================
-- CASCADE DELETE VERIFICATION (ORDERLINES)
-- Purpose: Verify ORDERLINES cascade deletes when orders removed
-- Expected: Orderlines deleted when orders deleted by manager PurgeOldOrders operation
-- =======================================================================
SELECT '--- CASCADE DELETE VERIFICATION (ORDERLINES) ---';
SELECT 'Verifying: Foreign key CASCADE DELETE when orders are purged';
SELECT 'Expected: ORDERLINES records deleted automatically when parent order deleted';
SELECT 'Note: Users create orders and managers purge old orders.';
SELECT '';

SET @orders_before = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'ORDERS_COUNT');
SET @orderlines_before = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'ORDERLINES_COUNT');
SET @old_orders_before = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'OLD_ORDERS_COUNT');

SET @orders_after = (SELECT COUNT(*) FROM ORDERS{store_number});
SET @orderlines_after = (SELECT COUNT(*) FROM ORDERLINES{store_number});
SET @old_orders_after = (SELECT COUNT(*) FROM ORDERS{store_number} WHERE ORDERDATE < CURDATE());

SET @orders_delta = @orders_after - @orders_before;
SET @orderlines_deleted = @orderlines_before - @orderlines_after;
SET @old_orders_deleted = @old_orders_before - @old_orders_after;

SELECT 'Orders (all):';
SELECT CONCAT('  Pre:        ', @orders_before);
SELECT CONCAT('  Post:       ', @orders_after);
SELECT CONCAT('  Net change: ', @orders_delta);

SELECT 'Orders (old - prior to today):';
SELECT CONCAT('  Pre:        ', @old_orders_before);
SELECT CONCAT('  Post:       ', @old_orders_after);
SELECT CONCAT('  Deleted:    ', @old_orders_deleted);

SELECT 'Orderlines (should cascade delete with orders):';
SELECT CONCAT('  Pre:        ', @orderlines_before);
SELECT CONCAT('  Post:       ', @orderlines_after);
SELECT CONCAT('  Net change: ', -@orderlines_deleted);

SELECT IF(@orders_delta < 0,
    CONCAT('  Avg orderlines per purged order: ', ROUND(@orderlines_deleted / -@orders_delta, 2), ' (expected: ~5-6)'),
    '  (Net positive change - cannot verify cascade ratio)') AS CascadeVerification;

SELECT '';
SELECT '';

-- =======================================================================
-- MEMBERSHIP TIER
-- =======================================================================
SELECT '--- MEMBERSHIP TIER ---';

SET @silver_members_before = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'SILVER_MEMBERS_COUNT');
SET @gold_members_before = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'GOLD_MEMBERS_COUNT');

SET @silver_members_after = (SELECT COUNT(*) FROM MEMBERSHIP{store_number} WHERE MEMBERSHIPTYPE = 2);
SET @gold_members_after = (SELECT COUNT(*) FROM MEMBERSHIP{store_number} WHERE MEMBERSHIPTYPE = 3);

SET @silver_delta = @silver_members_after - @silver_members_before;
SET @gold_delta = @gold_members_after - @gold_members_before;

SELECT CONCAT('Silver Members (Level 2):');
SELECT CONCAT('  Pre:   ', @silver_members_before);
SELECT CONCAT('  Post:  ', @silver_members_after);
SELECT CONCAT('  Delta: ', @silver_delta);

SELECT CONCAT('Gold Members (Level 3):');
SELECT CONCAT('  Pre:   ', @gold_members_before);
SELECT CONCAT('  Post:  ', @gold_members_after);
SELECT CONCAT('  Delta: ', @gold_delta);

SELECT '';
SELECT '--- MEMBERSHIP CHANGE TRACKING (Full Snapshot Comparison) ---';
SELECT '';
SELECT 'Columns: total_changes | deleted | new_memberships | upgrades_1_to_2 | upgrades_2_to_3 | upgrades_1_to_3 | extended_only';
SELECT '';

-- Summary counts of all changes (optimized: separate queries instead of UNION)
SELECT
    (SELECT COUNT(*) FROM MEMBERSHIP_SNAPSHOT_{store_number} s
     LEFT JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
     WHERE m.CUSTOMERID IS NULL
        OR m.MEMBERSHIPTYPE > s.MEMBERSHIPTYPE
        OR m.EXPIREDATE > s.EXPIREDATE) +
    (SELECT COUNT(*) FROM MEMBERSHIP{store_number} m
     LEFT JOIN MEMBERSHIP_SNAPSHOT_{store_number} s ON m.CUSTOMERID = s.CUSTOMERID
     WHERE s.CUSTOMERID IS NULL)
    AS total_changes,

    (SELECT COUNT(*) FROM MEMBERSHIP_SNAPSHOT_{store_number} s
     LEFT JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
     WHERE m.CUSTOMERID IS NULL) AS deleted,

    (SELECT COUNT(*) FROM MEMBERSHIP{store_number} m
     LEFT JOIN MEMBERSHIP_SNAPSHOT_{store_number} s ON m.CUSTOMERID = s.CUSTOMERID
     WHERE s.CUSTOMERID IS NULL) AS new_memberships,

    (SELECT COUNT(*) FROM MEMBERSHIP_SNAPSHOT_{store_number} s
     INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
     WHERE s.MEMBERSHIPTYPE = 1 AND m.MEMBERSHIPTYPE = 2) AS upgrades_1_to_2,

    (SELECT COUNT(*) FROM MEMBERSHIP_SNAPSHOT_{store_number} s
     INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
     WHERE s.MEMBERSHIPTYPE = 2 AND m.MEMBERSHIPTYPE = 3) AS upgrades_2_to_3,

    (SELECT COUNT(*) FROM MEMBERSHIP_SNAPSHOT_{store_number} s
     INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
     WHERE s.MEMBERSHIPTYPE = 1 AND m.MEMBERSHIPTYPE = 3) AS upgrades_1_to_3,

    (SELECT COUNT(*) FROM MEMBERSHIP_SNAPSHOT_{store_number} s
     INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
     WHERE m.MEMBERSHIPTYPE = s.MEMBERSHIPTYPE AND m.EXPIREDATE > s.EXPIREDATE) AS extended_only;

SELECT '';
SELECT 'Sample Changes by Type (Top 5 of each type):';
SELECT '';

-- Diverse sample: Top 5 of each change type (35 total max)
(
    -- 1->3 jumps (top 5)
    SELECT
        s.CUSTOMERID,
        s.MEMBERSHIPTYPE AS before_level,
        m.MEMBERSHIPTYPE AS after_level,
        DATE_FORMAT(s.EXPIREDATE, '%Y-%m-%d') AS before_expire,
        DATE_FORMAT(m.EXPIREDATE, '%Y-%m-%d') AS after_expire,
        '1->3 JUMP' AS status
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE s.MEMBERSHIPTYPE = 1 AND m.MEMBERSHIPTYPE = 3
    ORDER BY s.CUSTOMERID
    LIMIT 5
)
UNION ALL
(
    -- 2->3 upgrades (top 5)
    SELECT
        s.CUSTOMERID,
        s.MEMBERSHIPTYPE AS before_level,
        m.MEMBERSHIPTYPE AS after_level,
        DATE_FORMAT(s.EXPIREDATE, '%Y-%m-%d') AS before_expire,
        DATE_FORMAT(m.EXPIREDATE, '%Y-%m-%d') AS after_expire,
        '2->3 UPGRADE' AS status
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE s.MEMBERSHIPTYPE = 2 AND m.MEMBERSHIPTYPE = 3
    ORDER BY s.CUSTOMERID
    LIMIT 5
)
UNION ALL
(
    -- Deleted memberships (top 5)
    SELECT
        s.CUSTOMERID,
        s.MEMBERSHIPTYPE AS before_level,
        -1 AS after_level,
        DATE_FORMAT(s.EXPIREDATE, '%Y-%m-%d') AS before_expire,
        'N/A' AS after_expire,
        'DELETED' AS status
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    LEFT JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE m.CUSTOMERID IS NULL
    ORDER BY s.CUSTOMERID
    LIMIT 5
)
UNION ALL
(
    -- New memberships (top 5)
    SELECT
        m.CUSTOMERID,
        -1 AS before_level,
        m.MEMBERSHIPTYPE AS after_level,
        'N/A' AS before_expire,
        DATE_FORMAT(m.EXPIREDATE, '%Y-%m-%d') AS after_expire,
        'NEW' AS status
    FROM MEMBERSHIP{store_number} m
    LEFT JOIN MEMBERSHIP_SNAPSHOT_{store_number} s ON m.CUSTOMERID = s.CUSTOMERID
    WHERE s.CUSTOMERID IS NULL
    ORDER BY m.CUSTOMERID
    LIMIT 5
)
UNION ALL
(
    -- 1->2 upgrades (top 10 - most common)
    SELECT
        s.CUSTOMERID,
        s.MEMBERSHIPTYPE AS before_level,
        m.MEMBERSHIPTYPE AS after_level,
        DATE_FORMAT(s.EXPIREDATE, '%Y-%m-%d') AS before_expire,
        DATE_FORMAT(m.EXPIREDATE, '%Y-%m-%d') AS after_expire,
        '1->2 UPGRADE' AS status
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE s.MEMBERSHIPTYPE = 1 AND m.MEMBERSHIPTYPE = 2
    ORDER BY s.CUSTOMERID
    LIMIT 10
)
UNION ALL
(
    -- Extended only (top 5)
    SELECT
        s.CUSTOMERID,
        s.MEMBERSHIPTYPE AS before_level,
        m.MEMBERSHIPTYPE AS after_level,
        DATE_FORMAT(s.EXPIREDATE, '%Y-%m-%d') AS before_expire,
        DATE_FORMAT(m.EXPIREDATE, '%Y-%m-%d') AS after_expire,
        'EXTENDED' AS status
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE s.MEMBERSHIPTYPE = m.MEMBERSHIPTYPE AND m.EXPIREDATE > s.EXPIREDATE
    ORDER BY s.CUSTOMERID
    LIMIT 5
);

SELECT '';
SELECT '========================================================================';
SELECT '--- MEMBER-SPECIFIC PURCHASE BEHAVIOR ---';
SELECT 'Verifying: Members buy primarily from their membership tier';
SELECT 'Expected: ~70% of purchases match member tier (tier 1->tier 1, etc.)';
SELECT 'Expected: ~30% spillover to other tiers when cart exceeds browse results';
SELECT '========================================================================';
SELECT '';

SELECT
    member_tier,
    product_tier,
    purchase_count,
    ROUND(purchase_count * 100.0 / tier_total, 2) AS pct_of_tier_purchases
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
      AND m.EXPIREDATE > NOW()
    GROUP BY m.MEMBERSHIPTYPE, p.MEMBERSHIP_ITEM
) AS tier_purchases
ORDER BY member_tier, product_tier;

SELECT '';

-- =======================================================================
-- BENCHMARK ACTIVITY SUMMARY
-- =======================================================================
SELECT '--- BENCHMARK ACTIVITY SUMMARY ---';
SELECT '';

-- Calculate deltas from baseline
SET @customers_before = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'CUSTOMERS_COUNT');
SET @orders_before = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'ORDERS_COUNT');
SET @products_before = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'PRODUCTS_COUNT');
SET @memberships_before = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MEMBERSHIP_COUNT');

SET @customers_after = (SELECT COUNT(*) FROM CUSTOMERS{store_number});
SET @orders_after = (SELECT COUNT(*) FROM ORDERS{store_number});
SET @products_after = (SELECT COUNT(*) FROM PRODUCTS{store_number});
SET @memberships_after = (SELECT COUNT(*) FROM MEMBERSHIP{store_number});

SELECT 'New Records Created During Benchmark:';
SELECT CONCAT('  Customers:   ', @customers_after - @customers_before);
SELECT CONCAT('  Orders:      ', @orders_after - @orders_before);
SELECT CONCAT('  Reviews:     ', @reviews_after - @reviews_before);
SELECT CONCAT('  Products:    ', @products_after - @products_before);
SELECT CONCAT('  Memberships: ', @memberships_after - @memberships_before);

SELECT 'Manager Operation Impact:';
SELECT CONCAT('  Products with Adjusted Prices: ', @adjusted_prices);


-- =======================================================================
-- PROMOTIONAL MEMBERSHIP AUDIT
-- =======================================================================
SELECT '';
SELECT '========================================================================';
SELECT '--- PROMOTIONAL MEMBERSHIP AUDIT ---';
SELECT 'Verifying: PromotionalMembership MERGE operations tracked correctly';
SELECT 'Expected: INSERT path creates tier 1 with 90-day expiration';
SELECT 'Expected: UPDATE path shows sequential upgrades (1->2, 2->3) or tier 3 extensions';
SELECT '========================================================================';
SELECT '';

-- Operation summary (INSERT vs UPDATE)
SELECT
    OPERATION_TYPE,
    COUNT(*) AS operation_count,
    CAST(AVG(CASE WHEN OLD_TIER IS NULL THEN 0 ELSE 1 END) * 100 AS DECIMAL(5,2)) AS pct_had_membership
FROM MEMBERSHIP_PROMO_AUDIT{store_number}
GROUP BY OPERATION_TYPE;

SELECT '';

-- Verify INSERT path: all new memberships are tier 1 with 90-day expiration
SET @new_tier1_90day = (
    SELECT COUNT(*)
    FROM MEMBERSHIP_PROMO_AUDIT{store_number}
    WHERE OPERATION_TYPE = 'INSERT'
      AND NEW_TIER = 1
      AND NEW_EXPIREDATE BETWEEN DATE_ADD(NOW(), INTERVAL 89 DAY) AND DATE_ADD(NOW(), INTERVAL 91 DAY)
);

SELECT CONCAT('New memberships (tier 1, 90-day expiration): ', @new_tier1_90day);

SELECT '';

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

SELECT '';

-- Verify tier 3 extensions are ~90 days
SET @tier3_extensions = (
    SELECT COUNT(*)
    FROM MEMBERSHIP_PROMO_AUDIT{store_number}
    WHERE OPERATION_TYPE = 'UPDATE'
      AND OLD_TIER = 3
      AND NEW_TIER = 3
      AND DATEDIFF(NEW_EXPIREDATE, OLD_EXPIREDATE) BETWEEN 89 AND 91
);

SELECT CONCAT('Tier 3 extensions (90-day): ', @tier3_extensions);

SELECT '';

-- Sample operations (3 of each type)
(SELECT
    CUSTOMERID,
    NULL AS old_tier,
    NEW_TIER AS new_tier,
    DATE_FORMAT(NEW_EXPIREDATE, '%Y-%m-%d') AS new_expire,
    OPERATION_TYPE,
    OPERATION_TIMESTAMP
FROM MEMBERSHIP_PROMO_AUDIT{store_number}
WHERE OPERATION_TYPE = 'INSERT'
LIMIT 3)

UNION ALL

(SELECT
    CUSTOMERID,
    OLD_TIER AS old_tier,
    NEW_TIER AS new_tier,
    DATE_FORMAT(NEW_EXPIREDATE, '%Y-%m-%d') AS new_expire,
    'UPDATE (1->2)' AS OPERATION_TYPE,
    OPERATION_TIMESTAMP
FROM MEMBERSHIP_PROMO_AUDIT{store_number}
WHERE OPERATION_TYPE = 'UPDATE' AND OLD_TIER = 1 AND NEW_TIER = 2
LIMIT 3)

UNION ALL

(SELECT
    CUSTOMERID,
    OLD_TIER AS old_tier,
    NEW_TIER AS new_tier,
    DATE_FORMAT(NEW_EXPIREDATE, '%Y-%m-%d') AS new_expire,
    'UPDATE (2->3)' AS OPERATION_TYPE,
    OPERATION_TIMESTAMP
FROM MEMBERSHIP_PROMO_AUDIT{store_number}
WHERE OPERATION_TYPE = 'UPDATE' AND OLD_TIER = 2 AND NEW_TIER = 3
LIMIT 3)

UNION ALL

(SELECT
    CUSTOMERID,
    OLD_TIER AS old_tier,
    NEW_TIER AS new_tier,
    DATE_FORMAT(NEW_EXPIREDATE, '%Y-%m-%d') AS new_expire,
    'UPDATE (3->3 ext)' AS OPERATION_TYPE,
    OPERATION_TIMESTAMP
FROM MEMBERSHIP_PROMO_AUDIT{store_number}
WHERE OPERATION_TYPE = 'UPDATE' AND OLD_TIER = 3 AND NEW_TIER = 3
LIMIT 3)

ORDER BY OPERATION_TYPE, OPERATION_TIMESTAMP;

SELECT '';


-- =======================================================================
-- TOP 10 NEW CUSTOMERS
-- =======================================================================
SELECT '--- TOP 10 NEW CUSTOMERS (Created During Benchmark) ---';
SELECT '';

SET @max_customerid_pre = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MAX_CUSTOMERID');

SELECT
    LPAD(CUSTOMERID, 10) AS CUSTOMERID,
    RPAD(FIRSTNAME, 20) AS FIRSTNAME,
    RPAD(LASTNAME, 20) AS LASTNAME,
    RPAD(CITY, 20) AS CITY
FROM CUSTOMERS{store_number}
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

SET @max_prod_id_pre = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MAX_PROD_ID');

SET @new_products_added = (SELECT COUNT(*) FROM PRODUCTS{store_number} WHERE PROD_ID > @max_prod_id_pre);
SET @new_products_with_inventory = (SELECT COUNT(DISTINCT i.PROD_ID) FROM INVENTORY{store_number} i WHERE i.PROD_ID > @max_prod_id_pre);
SET @new_products_purchased = (SELECT COUNT(DISTINCT ol.PROD_ID) FROM ORDERLINES{store_number} ol WHERE ol.PROD_ID > @max_prod_id_pre);
SET @new_products_reordered = (SELECT COUNT(DISTINCT r.PROD_ID) FROM REORDER{store_number} r WHERE r.PROD_ID > @max_prod_id_pre);

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
FROM REORDER{store_number} r
JOIN PRODUCTS{store_number} p ON r.PROD_ID = p.PROD_ID
WHERE r.PROD_ID > @max_prod_id_pre
GROUP BY r.PROD_ID, p.TITLE
ORDER BY MAX(r.DATE_REORDERED) DESC, r.PROD_ID
LIMIT 10;

-- =======================================================================
-- MERGE/UPSERT OPERATION VALIDATION (NEW_REVIEW_HELPFULNESS)
-- =======================================================================
SELECT '--- MERGE/UPSERT VALIDATION (NEW_REVIEW_HELPFULNESS) ---';
SELECT 'Verifying: No duplicate (REVIEW_ID, CUSTOMERID) combinations exist';
SELECT '';

-- Check for duplicates (should return 0 rows after MERGE conversion)
SELECT 'Checking for duplicate helpfulness ratings:';
SET @duplicate_count = (
    SELECT COUNT(*)
    FROM (
        SELECT REVIEW_ID, CUSTOMERID, COUNT(*) as rating_count
        FROM REVIEWS_HELPFULNESS{store_number}
        GROUP BY REVIEW_ID, CUSTOMERID
        HAVING COUNT(*) > 1
    ) AS duplicates
);

SELECT CASE
    WHEN @duplicate_count = 0 THEN 'SUCCESS: No duplicate ratings found'
    ELSE CONCAT('FAILURE: Found ', @duplicate_count, ' duplicate rating combinations!')
END AS DuplicateCheck;

SELECT '';
SELECT 'MERGE Operation Statistics (from MERGE_AUDIT table):';

SET @insert_count = (SELECT COUNT(*) FROM MERGE_AUDIT{store_number} WHERE OPERATION = 'INSERT');
SET @update_count = (SELECT COUNT(*) FROM MERGE_AUDIT{store_number} WHERE OPERATION = 'UPDATE');
SET @total_ops = @insert_count + @update_count;

SELECT CONCAT('Total MERGE Operations:  ', @total_ops);
SELECT CONCAT('  INSERTs (new ratings): ', @insert_count,
              ' (', ROUND(100.0 * @insert_count / NULLIF(@total_ops, 0), 1), '%)');
SELECT CONCAT('  UPDATEs (re-ratings):  ', @update_count,
              ' (', ROUND(100.0 * @update_count / NULLIF(@total_ops, 0), 1), '%)');

SELECT '';
SELECT CASE
    WHEN @total_ops = 0 THEN 'INFO: No MERGE operations recorded (test may not have executed NEW_REVIEW_HELPFULNESS)'
    WHEN @update_count = 0 THEN 'INFO: All operations were INSERTs (expected for large databases - low collision probability)'
    WHEN @update_count > 0 THEN CONCAT('SUCCESS: MERGE UPDATE path validated (', @update_count, ' customers re-rated reviews)')
    ELSE ''
END AS MergeStatus;

SELECT '';
SELECT 'Sample MERGE Operations (5 INSERTs, 5 UPDATEs):';

SELECT '--- Recent INSERT Operations ---';
SELECT
    LPAD(AUDIT_ID, 10) AS AUDIT_ID,
    LPAD(REVIEW_HELPFULNESS_ID, 20) AS HELPFULNESS_ID,
    LPAD(REVIEW_ID, 12) AS REVIEW_ID,
    LPAD(CUSTOMERID, 14) AS CUSTOMERID,
    LPAD(NEW_HELPFULNESS, 11) AS HELPFULNESS,
    AUDIT_TIMESTAMP
FROM MERGE_AUDIT{store_number}
WHERE OPERATION = 'INSERT'
ORDER BY AUDIT_ID DESC
LIMIT 5;

SELECT '--- Recent UPDATE Operations ---';
SELECT
    LPAD(AUDIT_ID, 10) AS AUDIT_ID,
    LPAD(REVIEW_HELPFULNESS_ID, 20) AS HELPFULNESS_ID,
    LPAD(REVIEW_ID, 12) AS REVIEW_ID,
    LPAD(CUSTOMERID, 14) AS CUSTOMERID,
    LPAD(OLD_HELPFULNESS, 5) AS OLD,
    LPAD(NEW_HELPFULNESS, 5) AS NEW,
    AUDIT_TIMESTAMP
FROM MERGE_AUDIT{store_number}
WHERE OPERATION = 'UPDATE'
ORDER BY AUDIT_ID DESC
LIMIT 5;

SELECT '';
SELECT '';

-- =======================================================================
-- NEW CUSTOMER LOGIN VERIFICATION
-- Purpose: Verify new customers (created during test) can log in again
-- Expected: Some new customers should have multiple orders
-- =======================================================================
SELECT '--- NEW CUSTOMER LOGIN VERIFICATION (Returning New Customers) ---';
SELECT 'Verifying: New customers created during test make multiple purchases';
SELECT '';

SET @CustomersBaseline = (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'CUSTOMERS_COUNT');

SET @NewCustomersCreated = (
    SELECT COUNT(DISTINCT CUSTOMERID)
    FROM CUSTOMERS{store_number}
    WHERE CUSTOMERID > @CustomersBaseline
);

SET @NewCustomersWithMultipleOrders = (
    SELECT COUNT(DISTINCT CUSTOMERID)
    FROM (
        SELECT CUSTOMERID, COUNT(*) as order_count
        FROM ORDERS{store_number}
        WHERE CUSTOMERID > @CustomersBaseline
        GROUP BY CUSTOMERID
        HAVING COUNT(*) > 1
    ) subq
);

SET @NewCustomersTotalOrders = (
    SELECT COUNT(*)
    FROM ORDERS{store_number}
    WHERE CUSTOMERID > @CustomersBaseline
);

SELECT CONCAT('New Customers Created:                 ', @NewCustomersCreated);
SELECT CONCAT('New Customers with Multiple Orders:    ', @NewCustomersWithMultipleOrders);
SELECT CONCAT('Total Orders from New Customers:       ', @NewCustomersTotalOrders);
SELECT '';

SELECT 'Order Distribution for New Customers:';
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
GROUP BY Order_Bucket
ORDER BY Order_Bucket;

SELECT '';
SELECT 'Top 10 New Customers by Order Count:';
SELECT
    CUSTOMERID,
    COUNT(*) as Order_Count,
    SUM(TOTALAMOUNT) as Total_Revenue,
    MIN(ORDERDATE) as First_Order,
    MAX(ORDERDATE) as Last_Order
FROM ORDERS{store_number}
WHERE CUSTOMERID > @CustomersBaseline
GROUP BY CUSTOMERID
ORDER BY Order_Count DESC, Total_Revenue DESC
LIMIT 10;

SELECT '';
SELECT '========================================================================';
SELECT 'Post-Test Validation Complete';
SELECT 'Compare these results with validate_before.sql to verify:';
SELECT '  1. GetSkewedProductId: Popular products (ID % {popular_modulo}) have highest sales';
SELECT '  2. Restock Trigger: REORDER table shows restocking for sold-out products';
SELECT '  3. Review Operations: New reviews created, helpfulness scores increased';
SELECT '  4. Manager Operations: New products added, prices adjusted, specials toggled';
SELECT '  5. Customer Growth: New customers and orders created during benchmark';
SELECT '  6. AddProduct Validation: New products have inventory and are being purchased';
SELECT '========================================================================';
