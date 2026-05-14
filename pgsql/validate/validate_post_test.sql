-- DVD Store 3.6 - Post-Test Validation Queries (PostgreSQL)
-- Run this AFTER completing the benchmark to measure changes
-- Compare with validate_before.sql results to verify test harness functionality

\c ds3

DO $$
BEGIN
    RAISE NOTICE '========================================================================';
    RAISE NOTICE 'DVD Store 3.6 - Post-Test Validation';
    RAISE NOTICE 'Timestamp: %', NOW();
    RAISE NOTICE '========================================================================';
    RAISE NOTICE '';

    -- =======================================================================
    -- TABLE ROW COUNTS
    -- Purpose: Show data growth during benchmark
    -- =======================================================================
    RAISE NOTICE '--- TABLE ROW COUNTS (Post-Test) ---';
    RAISE NOTICE 'Verifying: Data volume changes during benchmark execution';
    RAISE NOTICE 'Expected: CUSTOMERS, ORDERS, ORDERLINES, REVIEWS should increase';
    RAISE NOTICE 'Expected: PRODUCTS may increase if managers enabled';
    RAISE NOTICE 'Expected: REVIEWS may decrease if managers removed unhelpful reviews';
    RAISE NOTICE '';
END $$;

-- Display current counts with deltas from baseline
SELECT
    RPAD(REPLACE(m.metric_name, '_COUNT', ''), 15) AS "Table",
    LPAD(m.metric_value::TEXT, 15) AS "Pre",
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
    END::TEXT, 15) AS "Post",
    LPAD((CASE REPLACE(m.metric_name, '_COUNT', '')
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
    END - m.metric_value)::TEXT, 15) AS "Delta"
FROM VALIDATION_METRICS_{store_number} m
WHERE m.metric_name LIKE '%_COUNT'
    AND m.metric_name NOT IN ('MANAGER_PRODUCTS_COUNT', 'SPECIAL_PRODUCTS_COUNT', 'OLD_ORDERS_COUNT', 'SILVER_MEMBERS_COUNT', 'GOLD_MEMBERS_COUNT')
ORDER BY "Table";

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '';

    -- =======================================================================
    -- TOP 5 CUSTOMERS BY PURCHASE HISTORY
    -- Purpose: Verify CUST_HIST table growth during benchmark
    -- Expected: Shows customers with most products ordered
    -- =======================================================================
    RAISE NOTICE '--- TOP 5 CUSTOMERS BY PURCHASE HISTORY (CUST_HIST Verification) ---';
    RAISE NOTICE 'Verifying: Customer purchase history has grown during benchmark';
    RAISE NOTICE 'Expected: Product counts should be higher than pre-test';
    RAISE NOTICE '';
END $$;

SELECT
    LPAD(ch.CUSTOMERID::TEXT, 10, ' ') AS "CustID",
    RPAD(c.FIRSTNAME, 15, ' ') AS "FirstName",
    RPAD(c.LASTNAME, 15, ' ') AS "LastName",
    LPAD(COUNT(*)::TEXT, 8, ' ') AS "Products"
FROM CUST_HIST{store_number} ch
JOIN CUSTOMERS{store_number} c ON ch.CUSTOMERID = c.CUSTOMERID
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
    -- Expected: Products divisible by {popular_modulo} should dominate top sales
    -- =======================================================================
    RAISE NOTICE '--- TOP 10 INVENTORY BY SALES (GetSkewedProductId Verification) ---';
    RAISE NOTICE 'Verifying: Skewed product selection worked correctly';
    RAISE NOTICE 'Expected: Products divisible by {popular_modulo} should appear in top 10 with higher SALES';
    RAISE NOTICE 'Expected: SALES values should be significantly higher than pre-test baseline';
    RAISE NOTICE '';
END $$;

SELECT
    i.PROD_ID,
    p.TITLE,
    i.SALES,
    CASE
        WHEN i.PROD_ID % {popular_modulo} = 0 THEN '**POPULAR**'
        ELSE ''
    END AS IsPopularProduct
FROM INVENTORY{store_number} i
JOIN PRODUCTS{store_number} p ON i.PROD_ID = p.PROD_ID
ORDER BY i.SALES DESC
LIMIT 10;

DO $$
DECLARE
    v_popular_sales BIGINT;
    v_non_popular_sales BIGINT;
    v_popular_count INT;
    v_non_popular_count INT;
BEGIN
    RAISE NOTICE '';

    -- Summary statistics on popular vs non-popular products
    SELECT SUM(SALES), COUNT(*) INTO v_popular_sales, v_popular_count
    FROM INVENTORY{store_number}
    WHERE PROD_ID % {popular_modulo} = 0;

    SELECT SUM(SALES), COUNT(*) INTO v_non_popular_sales, v_non_popular_count
    FROM INVENTORY{store_number}
    WHERE PROD_ID % {popular_modulo} != 0;

    RAISE NOTICE 'GetSkewedProductId Effectiveness:';
    RAISE NOTICE '  Popular Products (ID %% {popular_modulo} = 0):';
    RAISE NOTICE '    Count: %, Total Sales: %', v_popular_count, v_popular_sales;
    IF v_popular_count > 0 THEN
        RAISE NOTICE '    Avg Sales per Product: %', v_popular_sales / v_popular_count;
    END IF;
    RAISE NOTICE '  Non-Popular Products:';
    RAISE NOTICE '    Count: %, Total Sales: %', v_non_popular_count, v_non_popular_sales;
    IF v_non_popular_count > 0 THEN
        RAISE NOTICE '    Avg Sales per Product: %', v_non_popular_sales / v_non_popular_count;
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE '';

    -- =======================================================================
    -- TOP 20 REORDER BY QUANTITY
    -- Purpose: Verify restock trigger functionality
    -- Expected: Reorder table should have new entries from benchmark
    -- =======================================================================
    RAISE NOTICE '--- TOP 20 REORDER BY QUANTITY (Restock Trigger Verification) ---';
    RAISE NOTICE 'Verifying: Restock trigger fired for products that sold out';
    RAISE NOTICE 'Expected: REORDER table should show new restocking activity';
    RAISE NOTICE '';
END $$;

SELECT
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
ORDER BY SUM(r.QUAN_REORDERED) DESC
LIMIT 20;

DO $$
DECLARE
    v_total_reorders INT;
    v_popular_reorders INT;
BEGIN
    RAISE NOTICE '';

    -- Reorder statistics
    SELECT COUNT(*) INTO v_total_reorders FROM REORDER{store_number};
    SELECT COUNT(*) INTO v_popular_reorders FROM REORDER{store_number} WHERE PROD_ID % {popular_modulo} = 0;

    RAISE NOTICE 'Restock Trigger Statistics:';
    RAISE NOTICE '  Total Reorder Events: %', v_total_reorders;
    RAISE NOTICE '  Popular Product Reorders: %', v_popular_reorders;
    IF v_total_reorders > 0 THEN
        RAISE NOTICE '  Popular Product %%: %%%', (100 * v_popular_reorders / v_total_reorders);
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE '';

    -- =======================================================================
    -- TOP 10 REVIEWS BY HELPFULNESS
    -- Purpose: Verify review and helpfulness operations
    -- Expected: New reviews created, helpfulness ratings accumulated
    -- =======================================================================
    RAISE NOTICE '--- TOP 10 REVIEWS BY HELPFULNESS (Review Operations Verification) ---';
    RAISE NOTICE 'Verifying: New reviews created and helpfulness ratings accumulated';
    RAISE NOTICE 'Expected: TOTAL_HELPFULNESS values should be higher than pre-test';
    RAISE NOTICE '';

    RAISE NOTICE 'Pre-Test Top 10:';
END $$;

SELECT
    LPAD(t.rank_position::TEXT, 5) AS "Rank",
    LPAD(t.review_id::TEXT, 10) AS "ReviewID",
    LPAD(t.prod_id::TEXT, 10) AS "ProdID",
    LPAD(t.total_helpfulness::TEXT, 12) AS "Helpfulness"
FROM VALIDATION_TOP_REVIEWS_{store_number} t
ORDER BY t.rank_position;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Post-Test Top 10:';
END $$;

SELECT
    LPAD(ROW_NUMBER() OVER (ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID)::TEXT, 5) AS "Rank",
    LPAD(REVIEW_ID::TEXT, 10) AS "ReviewID",
    LPAD(PROD_ID::TEXT, 10) AS "ProdID",
    LPAD(TOTAL_HELPFULNESS::TEXT, 12) AS "Helpfulness",
    RPAD(CASE WHEN PROD_ID % {popular_modulo} = 0 THEN '**POPULAR**' ELSE '' END, 12) AS "Popular"
FROM REVIEWS{store_number}
ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID
LIMIT 10;

DO $$
DECLARE
    v_total_reviews INT;
    v_avg_helpfulness NUMERIC;
    v_max_helpfulness INT;
    v_total_helpfulness BIGINT;
    v_total_helpfulness_pre BIGINT;
    v_popular_product_reviews INT;
BEGIN
    RAISE NOTICE '';

    -- Review statistics
    SELECT COUNT(*), AVG(TOTAL_HELPFULNESS), MAX(TOTAL_HELPFULNESS), COALESCE(SUM(TOTAL_HELPFULNESS), 0)
    INTO v_total_reviews, v_avg_helpfulness, v_max_helpfulness, v_total_helpfulness
    FROM REVIEWS{store_number};

    SELECT metric_value INTO v_total_helpfulness_pre
    FROM VALIDATION_METRICS_{store_number}
    WHERE metric_name = 'TOTAL_HELPFULNESS';

    RAISE NOTICE 'Review Statistics:';
    RAISE NOTICE '  Total Reviews: %', v_total_reviews;
    RAISE NOTICE '  Avg Helpfulness: %', ROUND(v_avg_helpfulness, 2);
    RAISE NOTICE '  Max Helpfulness: %', v_max_helpfulness;
    RAISE NOTICE '  Total Helpfulness (sum):';
    RAISE NOTICE '    Pre:   %', v_total_helpfulness_pre;
    RAISE NOTICE '    Post:  %', v_total_helpfulness;
    RAISE NOTICE '    Delta: %', v_total_helpfulness - v_total_helpfulness_pre;
    RAISE NOTICE '';
    RAISE NOTICE 'Reviews for Popular Products (ID %% {popular_modulo} = 0):';
    RAISE NOTICE '';

    RAISE NOTICE '';
END $$;

SELECT
    COALESCE(pre.prod_id, post.PROD_ID) AS "PROD_ID",
    COALESCE(pre.title, post.TITLE) AS "TITLE",
    COALESCE(pre.review_count, 0) AS "Pre",
    COALESCE(post.ReviewCount, 0) AS "Post",
    COALESCE(post.ReviewCount, 0) - COALESCE(pre.review_count, 0) AS "Delta"
FROM VALIDATION_POPULAR_REVIEWS_{store_number} pre
FULL OUTER JOIN (
    SELECT
        p.PROD_ID,
        p.TITLE,
        COUNT(r.REVIEW_ID)::INT AS ReviewCount
    FROM PRODUCTS{store_number} p
    LEFT JOIN REVIEWS{store_number} r ON p.PROD_ID = r.PROD_ID
    WHERE p.PROD_ID % {popular_modulo} = 0
    GROUP BY p.PROD_ID, p.TITLE
) post ON pre.prod_id = post.PROD_ID
ORDER BY COALESCE(post.ReviewCount, 0) DESC, COALESCE(pre.prod_id, post.PROD_ID);

DO $$
DECLARE
    v_mismatch_count INT;
BEGIN
    RAISE NOTICE '';

    -- =======================================================================
    -- UPDATE_HELPFULNESS TRIGGER VERIFICATION
    -- =======================================================================
    RAISE NOTICE '--- UPDATE_HELPFULNESS TRIGGER VERIFICATION ---';
    RAISE NOTICE 'Verifying: TOTAL_HELPFULNESS matches sum of individual helpfulness ratings';
    RAISE NOTICE '';

    SELECT COUNT(*) INTO v_mismatch_count
    FROM REVIEWS{store_number} r
    LEFT JOIN (
        SELECT REVIEW_ID, SUM(HELPFULNESS) AS CalculatedTotal
        FROM REVIEWS_HELPFULNESS{store_number}
        GROUP BY REVIEW_ID
    ) h ON r.REVIEW_ID = h.REVIEW_ID
    WHERE COALESCE(r.TOTAL_HELPFULNESS, 0) != COALESCE(h.CalculatedTotal, 0);

    RAISE NOTICE 'Reviews with TOTAL_HELPFULNESS mismatch: %', v_mismatch_count;
    RAISE NOTICE '  Expected: 0 (trigger should keep values in sync)';

    IF v_mismatch_count > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE 'WARNING: Found mismatches - showing first 10:';
    END IF;
END $$;

SELECT
    r.REVIEW_ID,
    r.PROD_ID,
    r.TOTAL_HELPFULNESS AS "Stored_Helpfulness",
    COALESCE(h.CalculatedTotal, 0) AS "Calculated_Helpfulness",
    COALESCE(h.CalculatedTotal, 0) - COALESCE(r.TOTAL_HELPFULNESS, 0) AS "Difference"
FROM REVIEWS{store_number} r
LEFT JOIN (
    SELECT REVIEW_ID, SUM(HELPFULNESS) AS CalculatedTotal
    FROM REVIEWS_HELPFULNESS{store_number}
    GROUP BY REVIEW_ID
) h ON r.REVIEW_ID = h.REVIEW_ID
WHERE COALESCE(r.TOTAL_HELPFULNESS, 0) != COALESCE(h.CalculatedTotal, 0)
LIMIT 10;

DO $$
BEGIN
    RAISE NOTICE '';

    -- =======================================================================
    -- MANAGER OPERATION VERIFICATION
    -- =======================================================================
    RAISE NOTICE '--- MANAGER OPERATION VERIFICATION ---';
    RAISE NOTICE 'Verifying: Manager operations executed correctly (if managers enabled)';
    RAISE NOTICE '';
END $$;

-- Manager-created products (price ends in .01)
DO $$
DECLARE
    v_manager_products INT;
    v_manager_products_pre INT;
BEGIN
    SELECT COUNT(*) INTO v_manager_products
    FROM PRODUCTS{store_number}
    WHERE (PRICE - FLOOR(PRICE)) = 0.01;

    SELECT metric_value INTO v_manager_products_pre
    FROM VALIDATION_METRICS_{store_number}
    WHERE metric_name = 'MANAGER_PRODUCTS_COUNT';

    RAISE NOTICE 'Manager-Created Products (price .01):';
    RAISE NOTICE '  Pre:   %', v_manager_products_pre;
    RAISE NOTICE '  Post:  %', v_manager_products;
    RAISE NOTICE '  Delta: %', v_manager_products - v_manager_products_pre;
    RAISE NOTICE '';

    RAISE NOTICE 'Sample Manager-Created Products (price ends in .01):';
END $$;

SELECT
    PROD_ID,
    TITLE,
    ACTOR,
    PRICE,
    SPECIAL,
    COMMON_PROD_ID
FROM PRODUCTS{store_number}
WHERE (PRICE - FLOOR(PRICE)) = 0.01
ORDER BY PROD_ID DESC
LIMIT 10;

-- Products marked as SPECIAL
DO $$
DECLARE
    v_special_products INT;
    v_special_products_pre INT;
BEGIN
    SELECT COUNT(*) INTO v_special_products
    FROM PRODUCTS{store_number}
    WHERE SPECIAL = 1;

    SELECT metric_value INTO v_special_products_pre
    FROM VALIDATION_METRICS_{store_number}
    WHERE metric_name = 'SPECIAL_PRODUCTS_COUNT';

    RAISE NOTICE 'Products Marked Special (SPECIAL=1):';
    RAISE NOTICE '  Pre:   %', v_special_products_pre;
    RAISE NOTICE '  Post:  %', v_special_products;
    RAISE NOTICE '  Delta: %', v_special_products - v_special_products_pre;
    RAISE NOTICE '  (MarkSpecials toggles SPECIAL flag)';
    RAISE NOTICE '';
END $$;

-- Price changes (detect products with non-standard pricing)
DO $$
DECLARE
    v_adjusted_prices INT;
    v_bulk_adjusted_prices INT;
BEGIN
    SELECT COUNT(*) INTO v_adjusted_prices
    FROM PRODUCTS{store_number}
    WHERE (PRICE - FLOOR(PRICE)) != 0.99 AND (PRICE - FLOOR(PRICE)) != 0.01;

    SELECT COUNT(*) INTO v_bulk_adjusted_prices
    FROM PRODUCTS{store_number}
    WHERE (PRICE - FLOOR(PRICE)) = 0.77;

    RAISE NOTICE 'Products with Adjusted Prices (not ending in .99 or .01): %', v_adjusted_prices;
    RAISE NOTICE '  - Prices ending in .77: % (BulkPriceAdjustment: category-wide ±25%%)', v_bulk_adjusted_prices;
    RAISE NOTICE '  - Other endings: % (AdjustPrices: individual ±10%%)', v_adjusted_prices - v_bulk_adjusted_prices;
    RAISE NOTICE '';

    RAISE NOTICE 'Sample Price-Adjusted Products (10 bulk .77 + 10 individual):';
END $$;

(
    SELECT
        PROD_ID,
        TITLE,
        ACTOR,
        PRICE,
        SPECIAL,
        COMMON_PROD_ID,
        'Bulk (.77)' AS adjustment_type
    FROM PRODUCTS{store_number}
    WHERE (PRICE - FLOOR(PRICE)) = 0.77
    ORDER BY PROD_ID
    LIMIT 10
)
UNION ALL
(
    SELECT
        PROD_ID,
        TITLE,
        ACTOR,
        PRICE,
        SPECIAL,
        COMMON_PROD_ID,
        'Individual' AS adjustment_type
    FROM PRODUCTS{store_number}
    WHERE (PRICE - FLOOR(PRICE)) != 0.99
      AND (PRICE - FLOOR(PRICE)) != 0.01
      AND (PRICE - FLOOR(PRICE)) != 0.77
    ORDER BY PROD_ID
    LIMIT 10
)
ORDER BY adjustment_type DESC, PROD_ID;

-- Membership Expiration Verification
DO $$
DECLARE
    v_total_memberships INT;
    v_expired_memberships INT;
    v_total_memberships_pre INT;
    v_expired_memberships_pre INT;
BEGIN
    -- Get current membership counts
    SELECT COUNT(*) INTO v_total_memberships FROM MEMBERSHIP{store_number};
    SELECT COUNT(*) INTO v_expired_memberships FROM MEMBERSHIP{store_number} WHERE EXPIREDATE < CURRENT_TIMESTAMP;

    -- Get pre-test membership counts
    SELECT metric_value INTO v_total_memberships_pre FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'TOTAL_MEMBERSHIPS';
    SELECT metric_value INTO v_expired_memberships_pre FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'EXPIRED_MEMBERSHIPS';

    RAISE NOTICE '';
    RAISE NOTICE 'Membership Status:';
    RAISE NOTICE 'Verifying: Membership changes during benchmark';
    RAISE NOTICE 'Expected: New memberships created, expired memberships may be deleted by ExpireMemberships manager';
    RAISE NOTICE '  Total Memberships:';
    RAISE NOTICE '    Pre:   %', v_total_memberships_pre;
    RAISE NOTICE '    Post:  %', v_total_memberships;
    RAISE NOTICE '    Delta: %', v_total_memberships - v_total_memberships_pre;
    RAISE NOTICE '  Expired Memberships (EXPIREDATE < current date):';
    RAISE NOTICE '    Pre:   %', v_expired_memberships_pre;
    RAISE NOTICE '    Post:  %', v_expired_memberships;
    RAISE NOTICE '    Delta: %', v_expired_memberships - v_expired_memberships_pre;
    RAISE NOTICE '  Active Memberships:';
    RAISE NOTICE '    Pre:   %', v_total_memberships_pre - v_expired_memberships_pre;
    RAISE NOTICE '    Post:  %', v_total_memberships - v_expired_memberships;
    RAISE NOTICE '    Delta: %', (v_total_memberships - v_expired_memberships) - (v_total_memberships_pre - v_expired_memberships_pre);
    RAISE NOTICE '  (ExpireMemberships deletes expired entries, reducing total count)';
END $$;

-- New Product Verification
DO $$
DECLARE
    v_max_prod_id_pre INT;
    v_new_products_added INT;
    v_new_products_with_inventory INT;
    v_new_products_purchased INT;
    v_new_products_reordered INT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '';

    -- =======================================================================
    -- NEW PRODUCT VERIFICATION
    -- =======================================================================
    RAISE NOTICE '--- NEW PRODUCT VERIFICATION (Manager AddProduct Operations) ---';
    RAISE NOTICE 'Verifying: New products added by managers are being used in benchmark';
    RAISE NOTICE '';

    -- Get baseline max product ID
    SELECT metric_value INTO v_max_prod_id_pre
    FROM VALIDATION_METRICS_{store_number}
    WHERE metric_name = 'MAX_PROD_ID';

    -- Count new products added
    SELECT COUNT(*) INTO v_new_products_added
    FROM PRODUCTS{store_number}
    WHERE PROD_ID > v_max_prod_id_pre;

    -- Count new products with inventory
    SELECT COUNT(DISTINCT i.PROD_ID) INTO v_new_products_with_inventory
    FROM INVENTORY{store_number} i
    WHERE i.PROD_ID > v_max_prod_id_pre;

    -- Count new products that were purchased
    SELECT COUNT(DISTINCT ol.PROD_ID) INTO v_new_products_purchased
    FROM ORDERLINES{store_number} ol
    WHERE ol.PROD_ID > v_max_prod_id_pre;

    -- Count new products that were reordered
    SELECT COUNT(DISTINCT r.PROD_ID) INTO v_new_products_reordered
    FROM REORDER{store_number} r
    WHERE r.PROD_ID > v_max_prod_id_pre;

    RAISE NOTICE 'New Products Added (PROD_ID > %): %', v_max_prod_id_pre, v_new_products_added;
    RAISE NOTICE '  With Inventory Records:  %', v_new_products_with_inventory;
    RAISE NOTICE '  Purchased (in ORDERLINES): %', v_new_products_purchased;
    RAISE NOTICE '  Reordered (in REORDER):    %', v_new_products_reordered;
    RAISE NOTICE '';

    IF v_new_products_added > 0 THEN
        RAISE NOTICE 'Coverage:';
        RAISE NOTICE '  Inventory: %%% (% of %)',
            ROUND(100.0 * v_new_products_with_inventory / v_new_products_added, 1),
            v_new_products_with_inventory, v_new_products_added;
        RAISE NOTICE '  Purchased: %%% (% of %)',
            ROUND(100.0 * v_new_products_purchased / v_new_products_added, 1),
            v_new_products_purchased, v_new_products_added;
        RAISE NOTICE '  Reordered: %%% (% of %)',
            ROUND(100.0 * v_new_products_reordered / v_new_products_added, 1),
            v_new_products_reordered, v_new_products_added;
        RAISE NOTICE '';
        RAISE NOTICE 'Expected: 100%% inventory, >0%% purchased/reordered (confirms AddProduct integration)';
    ELSE
        RAISE NOTICE 'No new products added (managers may be disabled or no AddProduct operations)';
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE 'Sample New Products (PROD_ID > %):',v_max_prod_id_pre;
END $$;

SELECT
    p.PROD_ID,
    p.TITLE,
    p.PRICE,
    COALESCE(i.QUAN_IN_STOCK, 0) AS "Inventory",
    COALESCE(ol_count.purchases, 0) AS "Purchases",
    COALESCE(r_count.reorders, 0) AS "Reorders"
FROM PRODUCTS{store_number} p
LEFT JOIN INVENTORY{store_number} i ON p.PROD_ID = i.PROD_ID
LEFT JOIN (
    SELECT PROD_ID, COUNT(*) AS purchases
    FROM ORDERLINES{store_number}
    WHERE PROD_ID > (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MAX_PROD_ID')
    GROUP BY PROD_ID
) ol_count ON p.PROD_ID = ol_count.PROD_ID
LEFT JOIN (
    SELECT PROD_ID, COUNT(*) AS reorders
    FROM REORDER{store_number}
    WHERE PROD_ID > (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MAX_PROD_ID')
    GROUP BY PROD_ID
) r_count ON p.PROD_ID = r_count.PROD_ID
WHERE p.PROD_ID > (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MAX_PROD_ID')
ORDER BY p.PROD_ID
LIMIT 10;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Sample New Products in REORDER Table:';
END $$;

SELECT
    r.PROD_ID,
    p.TITLE,
    SUM(r.QUAN_REORDERED) AS TOTAL_REORDERED,
    COUNT(*) AS REORDER_COUNT,
    MAX(r.DATE_REORDERED) AS LAST_REORDER
FROM REORDER{store_number} r
JOIN PRODUCTS{store_number} p ON r.PROD_ID = p.PROD_ID
WHERE r.PROD_ID > (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MAX_PROD_ID')
GROUP BY r.PROD_ID, p.TITLE
ORDER BY MAX(r.DATE_REORDERED) DESC, r.PROD_ID
LIMIT 10;

-- Final summary
DO $$
DECLARE
    v_customers_before INT;
    v_customers_after INT;
    v_orders_before INT;
    v_orders_after INT;
    v_reviews_before INT;
    v_reviews_after INT;
    v_reviews_helpfulness_before INT;
    v_reviews_helpfulness_after INT;
    v_products_before INT;
    v_products_after INT;
    v_memberships_before INT;
    v_memberships_after INT;
    v_max_customerid_pre INT;
    v_adjusted_prices INT;
    v_reviews_delta INT;
    v_helpfulness_deleted INT;
    v_avg_helpfulness NUMERIC(10,2);
    v_orderlines_before INT;
    v_orderlines_after INT;
    v_orders_delta INT;
    v_orderlines_deleted INT;
    v_avg_orderlines NUMERIC(10,2);
    v_old_orders_before INT;
    v_old_orders_after INT;
    v_old_orders_deleted INT;
    v_silver_members_before INT;
    v_silver_members_after INT;
    v_silver_delta INT;
    v_gold_members_before INT;
    v_gold_members_after INT;
    v_gold_delta INT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '';

    -- =======================================================================
    -- CASCADE DELETE VERIFICATION
    -- Purpose: Verify REVIEWS_HELPFULNESS cascade deletes when reviews removed
    -- Expected: Helpfulness votes deleted when reviews deleted by manager operations
    -- =======================================================================
    RAISE NOTICE '--- CASCADE DELETE VERIFICATION (REVIEWS_HELPFULNESS) ---';
    RAISE NOTICE 'Verifying: Foreign key CASCADE DELETE when reviews are removed';
    RAISE NOTICE 'Expected: REVIEWS_HELPFULNESS records deleted automatically when parent review deleted';
    RAISE NOTICE 'Note: Users add reviews and managers delete reviews. Disable adding reviews with --ds2_mode=y';
    RAISE NOTICE '';

    SELECT metric_value INTO v_reviews_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'REVIEWS_COUNT';
    SELECT metric_value INTO v_reviews_helpfulness_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'REVIEWS_HELPFULNESS_COUNT';

    SELECT COUNT(*) INTO v_reviews_after FROM REVIEWS{store_number};
    SELECT COUNT(*) INTO v_reviews_helpfulness_after FROM REVIEWS_HELPFULNESS{store_number};

    v_reviews_delta := v_reviews_after - v_reviews_before;
    v_helpfulness_deleted := v_reviews_helpfulness_before - v_reviews_helpfulness_after;

    RAISE NOTICE 'Reviews:';
    RAISE NOTICE '  Pre:        %', v_reviews_before;
    RAISE NOTICE '  Post:       %', v_reviews_after;
    RAISE NOTICE '  Net change: %', v_reviews_delta;

    RAISE NOTICE 'Reviews Helpfulness (should cascade delete with reviews):';
    RAISE NOTICE '  Pre:        %', v_reviews_helpfulness_before;
    RAISE NOTICE '  Post:       %', v_reviews_helpfulness_after;
    RAISE NOTICE '  Net change: %', -v_helpfulness_deleted;

    IF v_reviews_delta < 0 THEN
        v_avg_helpfulness := v_helpfulness_deleted::NUMERIC / (-v_reviews_delta)::NUMERIC;
        RAISE NOTICE '  Avg helpfulness votes per deleted review: %', v_avg_helpfulness;
    ELSE
        RAISE NOTICE '  (Net positive change - cannot verify cascade ratio)';
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE '';

    -- =======================================================================
    -- CASCADE DELETE VERIFICATION (ORDERLINES)
    -- Purpose: Verify ORDERLINES cascade deletes when orders removed
    -- Expected: Orderlines deleted when orders deleted by manager PurgeOldOrders operation
    -- =======================================================================
    RAISE NOTICE '--- CASCADE DELETE VERIFICATION (ORDERLINES) ---';
    RAISE NOTICE 'Verifying: Foreign key CASCADE DELETE when orders are purged';
    RAISE NOTICE 'Expected: ORDERLINES records deleted automatically when parent order deleted';
    RAISE NOTICE 'Note: Users create orders and managers purge old orders.';
    RAISE NOTICE '';

    SELECT metric_value INTO v_orders_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'ORDERS_COUNT';
    SELECT metric_value INTO v_orderlines_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'ORDERLINES_COUNT';
    SELECT metric_value INTO v_old_orders_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'OLD_ORDERS_COUNT';

    SELECT COUNT(*) INTO v_orders_after FROM ORDERS{store_number};
    SELECT COUNT(*) INTO v_orderlines_after FROM ORDERLINES{store_number};
    SELECT COUNT(*) INTO v_old_orders_after FROM ORDERS{store_number} WHERE ORDERDATE < CURRENT_DATE;

    v_orders_delta := v_orders_after - v_orders_before;
    v_orderlines_deleted := v_orderlines_before - v_orderlines_after;
    v_old_orders_deleted := v_old_orders_before - v_old_orders_after;

    RAISE NOTICE 'Orders (all):';
    RAISE NOTICE '  Pre:        %', v_orders_before;
    RAISE NOTICE '  Post:       %', v_orders_after;
    RAISE NOTICE '  Net change: %', v_orders_delta;

    RAISE NOTICE 'Orders (old - prior to today):';
    RAISE NOTICE '  Pre:        %', v_old_orders_before;
    RAISE NOTICE '  Post:       %', v_old_orders_after;
    RAISE NOTICE '  Deleted:    %', v_old_orders_deleted;

    RAISE NOTICE 'Orderlines (should cascade delete with orders):';
    RAISE NOTICE '  Pre:        %', v_orderlines_before;
    RAISE NOTICE '  Post:       %', v_orderlines_after;
    RAISE NOTICE '  Net change: %', -v_orderlines_deleted;

    IF v_orders_delta < 0 THEN
        v_avg_orderlines := v_orderlines_deleted::NUMERIC / (-v_orders_delta)::NUMERIC;
        RAISE NOTICE '  Avg orderlines per purged order: % (expected: ~5-6)', v_avg_orderlines;
    ELSE
        RAISE NOTICE '  (Net positive change - cannot verify cascade ratio)';
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE '';

    -- =======================================================================
    -- MEMBERSHIP TIER
    -- =======================================================================
    RAISE NOTICE '--- MEMBERSHIP TIER ---';

    SELECT metric_value INTO v_silver_members_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'SILVER_MEMBERS_COUNT';
    SELECT metric_value INTO v_gold_members_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'GOLD_MEMBERS_COUNT';

    SELECT COUNT(*) INTO v_silver_members_after FROM MEMBERSHIP{store_number} WHERE MEMBERSHIPTYPE = 2;
    SELECT COUNT(*) INTO v_gold_members_after FROM MEMBERSHIP{store_number} WHERE MEMBERSHIPTYPE = 3;

    v_silver_delta := v_silver_members_after - v_silver_members_before;
    v_gold_delta := v_gold_members_after - v_gold_members_before;

    RAISE NOTICE 'Silver Members (Level 2):';
    RAISE NOTICE '  Pre:   %', v_silver_members_before;
    RAISE NOTICE '  Post:  %', v_silver_members_after;
    RAISE NOTICE '  Delta: %', v_silver_delta;

    RAISE NOTICE 'Gold Members (Level 3):';
    RAISE NOTICE '  Pre:   %', v_gold_members_before;
    RAISE NOTICE '  Post:  %', v_gold_members_after;
    RAISE NOTICE '  Delta: %', v_gold_delta;

    RAISE NOTICE '';
    RAISE NOTICE '--- MEMBERSHIP CHANGE TRACKING (Full Snapshot Comparison) ---';
    RAISE NOTICE '';
END $$;

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

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Top 30 Changes (Diverse Sample - Rarest First):';
    RAISE NOTICE '';
END $$;

-- Top N of each change type for diverse representation
-- Top 5: 1->3 jumps (rarest)
(SELECT
    s.CUSTOMERID,
    s.MEMBERSHIPTYPE AS before_level,
    m.MEMBERSHIPTYPE AS after_level,
    TO_CHAR(s.EXPIREDATE, 'YYYY-MM-DD') AS before_expire,
    TO_CHAR(m.EXPIREDATE, 'YYYY-MM-DD') AS after_expire,
    '1->3 JUMP' AS status
FROM MEMBERSHIP_SNAPSHOT_{store_number} s
INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
WHERE s.MEMBERSHIPTYPE = 1 AND m.MEMBERSHIPTYPE = 3
ORDER BY s.CUSTOMERID
LIMIT 5)

UNION ALL

-- Top 5: 2->3 upgrades
(SELECT
    s.CUSTOMERID,
    s.MEMBERSHIPTYPE AS before_level,
    m.MEMBERSHIPTYPE AS after_level,
    TO_CHAR(s.EXPIREDATE, 'YYYY-MM-DD') AS before_expire,
    TO_CHAR(m.EXPIREDATE, 'YYYY-MM-DD') AS after_expire,
    '2->3 UPGRADE' AS status
FROM MEMBERSHIP_SNAPSHOT_{store_number} s
INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
WHERE s.MEMBERSHIPTYPE = 2 AND m.MEMBERSHIPTYPE = 3
ORDER BY s.CUSTOMERID
LIMIT 5)

UNION ALL

-- Top 5: DELETED (in snapshot but not in current table)
(SELECT
    s.CUSTOMERID,
    s.MEMBERSHIPTYPE AS before_level,
    -1 AS after_level,
    TO_CHAR(s.EXPIREDATE, 'YYYY-MM-DD') AS before_expire,
    'N/A' AS after_expire,
    'DELETED' AS status
FROM MEMBERSHIP_SNAPSHOT_{store_number} s
LEFT JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
WHERE m.CUSTOMERID IS NULL
ORDER BY s.CUSTOMERID
LIMIT 5)

UNION ALL

-- Top 5: NEW (in current table but not in snapshot)
(SELECT
    m.CUSTOMERID,
    -1 AS before_level,
    m.MEMBERSHIPTYPE AS after_level,
    'N/A' AS before_expire,
    TO_CHAR(m.EXPIREDATE, 'YYYY-MM-DD') AS after_expire,
    'NEW' AS status
FROM MEMBERSHIP_SNAPSHOT_{store_number} s
RIGHT JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
WHERE s.CUSTOMERID IS NULL
ORDER BY m.CUSTOMERID
LIMIT 5)

UNION ALL

-- Top 10: 1->2 upgrades (most common, so show more)
(SELECT
    s.CUSTOMERID,
    s.MEMBERSHIPTYPE AS before_level,
    m.MEMBERSHIPTYPE AS after_level,
    TO_CHAR(s.EXPIREDATE, 'YYYY-MM-DD') AS before_expire,
    TO_CHAR(m.EXPIREDATE, 'YYYY-MM-DD') AS after_expire,
    '1->2 UPGRADE' AS status
FROM MEMBERSHIP_SNAPSHOT_{store_number} s
INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
WHERE s.MEMBERSHIPTYPE = 1 AND m.MEMBERSHIPTYPE = 2
ORDER BY s.CUSTOMERID
LIMIT 10)

UNION ALL

-- Top 5: EXTENDED (membership type unchanged but expiration date extended)
(SELECT
    s.CUSTOMERID,
    s.MEMBERSHIPTYPE AS before_level,
    m.MEMBERSHIPTYPE AS after_level,
    TO_CHAR(s.EXPIREDATE, 'YYYY-MM-DD') AS before_expire,
    TO_CHAR(m.EXPIREDATE, 'YYYY-MM-DD') AS after_expire,
    'EXTENDED' AS status
FROM MEMBERSHIP_SNAPSHOT_{store_number} s
INNER JOIN MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
WHERE s.MEMBERSHIPTYPE = m.MEMBERSHIPTYPE AND m.EXPIREDATE > s.EXPIREDATE
ORDER BY s.CUSTOMERID
LIMIT 5);

DO $$
DECLARE
    v_customers_before INT;
    v_customers_after INT;
    v_orders_before INT;
    v_orders_after INT;
    v_products_before INT;
    v_products_after INT;
    v_memberships_before INT;
    v_memberships_after INT;
    v_reviews_before INT;
    v_reviews_after INT;
    v_adjusted_prices INT;
    v_max_customerid_pre INT;
BEGIN
    RAISE NOTICE '';

    -- =======================================================================
    -- BENCHMARK ACTIVITY SUMMARY
    -- =======================================================================
    RAISE NOTICE '--- BENCHMARK ACTIVITY SUMMARY ---';
    RAISE NOTICE '';

    -- Calculate deltas from baseline
    SELECT metric_value INTO v_customers_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'CUSTOMERS_COUNT';
    SELECT metric_value INTO v_orders_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'ORDERS_COUNT';
    SELECT metric_value INTO v_products_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'PRODUCTS_COUNT';
    SELECT metric_value INTO v_memberships_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MEMBERSHIP_COUNT';
    SELECT metric_value INTO v_reviews_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'REVIEWS_COUNT';

    SELECT COUNT(*) INTO v_customers_after FROM CUSTOMERS{store_number};
    SELECT COUNT(*) INTO v_orders_after FROM ORDERS{store_number};
    SELECT COUNT(*) INTO v_products_after FROM PRODUCTS{store_number};
    SELECT COUNT(*) INTO v_memberships_after FROM MEMBERSHIP{store_number};
    SELECT COUNT(*) INTO v_reviews_after FROM REVIEWS{store_number};

    SELECT COUNT(*) INTO v_adjusted_prices
    FROM PRODUCTS{store_number}
    WHERE (PRICE - FLOOR(PRICE)) != 0.99 AND (PRICE - FLOOR(PRICE)) != 0.01;

    RAISE NOTICE 'New Records Created During Benchmark:';
    RAISE NOTICE '  Customers:   %', v_customers_after - v_customers_before;
    RAISE NOTICE '  Orders:      %', v_orders_after - v_orders_before;
    RAISE NOTICE '  Reviews:     %', v_reviews_after - v_reviews_before;
    RAISE NOTICE '  Products:    %', v_products_after - v_products_before;
    RAISE NOTICE '  Memberships: %', v_memberships_after - v_memberships_before;

    RAISE NOTICE '';
    RAISE NOTICE 'Manager Operation Impact:';
    RAISE NOTICE '  Products with Adjusted Prices: %', v_adjusted_prices;

    RAISE NOTICE '';
    RAISE NOTICE '';

    -- =======================================================================
    -- TOP 10 NEW CUSTOMERS
    -- =======================================================================
    RAISE NOTICE '--- TOP 10 NEW CUSTOMERS (Created During Benchmark) ---';
    RAISE NOTICE '';

    SELECT metric_value INTO v_max_customerid_pre
    FROM VALIDATION_METRICS_{store_number}
    WHERE metric_name = 'MAX_CUSTOMERID';
END $$;

SELECT
    CUSTOMERID,
    FIRSTNAME,
    LASTNAME,
    CITY
FROM CUSTOMERS{store_number}
WHERE CUSTOMERID > (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MAX_CUSTOMERID')
ORDER BY CUSTOMERID
LIMIT 10;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================================================';
    RAISE NOTICE 'Post-Test Validation Complete';
    RAISE NOTICE 'Compare these results with validate_before.sql to verify:';
    RAISE NOTICE '  1. GetSkewedProductId: Popular products (ID %% {popular_modulo}) have highest sales';
    RAISE NOTICE '  2. Restock Trigger: REORDER table shows restocking for sold-out products';
    RAISE NOTICE '  3. Review Operations: New reviews created, helpfulness scores increased';
    RAISE NOTICE '  4. Manager Operations: New products added, prices adjusted, specials toggled';
    RAISE NOTICE '  5. Customer Growth: New customers and orders created during benchmark';
    RAISE NOTICE '========================================================================';
END $$;
