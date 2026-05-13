-- DVD Store 3.6 - Post-Test Validation Queries (Oracle)
-- Run this AFTER completing the benchmark to measure changes
-- Compare with validate_before.sql results to verify test harness functionality

SET LINESIZE 200
SET PAGESIZE 1000
SET SERVEROUTPUT ON;

-- Set column widths for table count comparison
COLUMN TABLENAME FORMAT A20
COLUMN PRE FORMAT 999999999999
COLUMN POST FORMAT 999999999999
COLUMN DELTA FORMAT 999999999999

BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE('DVD Store 3.6 - Post-Test Validation');
    DBMS_OUTPUT.PUT_LINE('Timestamp: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- TABLE ROW COUNTS
    -- Purpose: Show data growth during benchmark
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- TABLE ROW COUNTS (Post-Test) ---');
    DBMS_OUTPUT.PUT_LINE('Verifying: Data volume changes during benchmark execution');
    DBMS_OUTPUT.PUT_LINE('Expected: CUSTOMERS, ORDERS, ORDERLINES, REVIEWS should increase');
    DBMS_OUTPUT.PUT_LINE('Expected: PRODUCTS may increase if managers enabled');
    DBMS_OUTPUT.PUT_LINE('Expected: REVIEWS may decrease if managers removed unhelpful reviews');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- Display current counts with deltas from baseline
SELECT
    RPAD(REPLACE(m.metric_name, '_COUNT', ''), 20) AS TABLENAME,
    LPAD(TO_CHAR(m.metric_value), 10) AS PRE,
    LPAD(TO_CHAR(CASE REPLACE(m.metric_name, '_COUNT', '')
        WHEN 'CUSTOMERS' THEN (SELECT COUNT(*) FROM DS3.CUSTOMERS{store_number})
        WHEN 'CUST_HIST' THEN (SELECT COUNT(*) FROM DS3.CUST_HIST{store_number})
        WHEN 'PRODUCTS' THEN (SELECT COUNT(*) FROM DS3.PRODUCTS{store_number})
        WHEN 'ORDERS' THEN (SELECT COUNT(*) FROM DS3.ORDERS{store_number})
        WHEN 'ORDERLINES' THEN (SELECT COUNT(*) FROM DS3.ORDERLINES{store_number})
        WHEN 'INVENTORY' THEN (SELECT COUNT(*) FROM DS3.INVENTORY{store_number})
        WHEN 'REVIEWS' THEN (SELECT COUNT(*) FROM DS3.REVIEWS{store_number})
        WHEN 'REVIEWS_HELPFULNESS' THEN (SELECT COUNT(*) FROM DS3.REVIEWS_HELPFULNESS{store_number})
        WHEN 'MEMBERSHIP' THEN (SELECT COUNT(*) FROM DS3.MEMBERSHIP{store_number})
        WHEN 'REORDER' THEN (SELECT COUNT(*) FROM DS3.REORDER{store_number})
    END), 10) AS POST,
    LPAD(TO_CHAR(CASE REPLACE(m.metric_name, '_COUNT', '')
        WHEN 'CUSTOMERS' THEN (SELECT COUNT(*) FROM DS3.CUSTOMERS{store_number}) - m.metric_value
        WHEN 'CUST_HIST' THEN (SELECT COUNT(*) FROM DS3.CUST_HIST{store_number}) - m.metric_value
        WHEN 'PRODUCTS' THEN (SELECT COUNT(*) FROM DS3.PRODUCTS{store_number}) - m.metric_value
        WHEN 'ORDERS' THEN (SELECT COUNT(*) FROM DS3.ORDERS{store_number}) - m.metric_value
        WHEN 'ORDERLINES' THEN (SELECT COUNT(*) FROM DS3.ORDERLINES{store_number}) - m.metric_value
        WHEN 'INVENTORY' THEN (SELECT COUNT(*) FROM DS3.INVENTORY{store_number}) - m.metric_value
        WHEN 'REVIEWS' THEN (SELECT COUNT(*) FROM DS3.REVIEWS{store_number}) - m.metric_value
        WHEN 'REVIEWS_HELPFULNESS' THEN (SELECT COUNT(*) FROM DS3.REVIEWS_HELPFULNESS{store_number}) - m.metric_value
        WHEN 'MEMBERSHIP' THEN (SELECT COUNT(*) FROM DS3.MEMBERSHIP{store_number}) - m.metric_value
        WHEN 'REORDER' THEN (SELECT COUNT(*) FROM DS3.REORDER{store_number}) - m.metric_value
    END), 10) AS DELTA
FROM VALIDATION_METRICS_{store_number} m
WHERE m.metric_name LIKE '%_COUNT'
    AND m.metric_name NOT IN ('MANAGER_PRODUCTS_COUNT', 'SPECIAL_PRODUCTS_COUNT', 'OLD_ORDERS_COUNT', 'SILVER_MEMBERS_COUNT', 'GOLD_MEMBERS_COUNT')
ORDER BY TABLENAME;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- TOP 5 CUSTOMERS BY PURCHASE HISTORY
    -- Purpose: Verify CUST_HIST table growth during benchmark
    -- Expected: Shows customers with most products ordered
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- TOP 5 CUSTOMERS BY PURCHASE HISTORY (CUST_HIST Verification) ---');
    DBMS_OUTPUT.PUT_LINE('Verifying: Customer purchase history has grown during benchmark');
    DBMS_OUTPUT.PUT_LINE('Expected: Product counts should be higher than pre-test');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

SELECT * FROM (
    SELECT
        LPAD(TO_CHAR(ch.CUSTOMERID), 10) AS CustID,
        RPAD(c.FIRSTNAME, 15) AS FirstName,
        RPAD(c.LASTNAME, 15) AS LastName,
        LPAD(TO_CHAR(COUNT(*)), 8) AS Products
    FROM DS3.CUST_HIST{store_number} ch
    JOIN DS3.CUSTOMERS{store_number} c ON ch.CUSTOMERID = c.CUSTOMERID
    GROUP BY ch.CUSTOMERID, c.FIRSTNAME, c.LASTNAME
    ORDER BY COUNT(*) DESC
)
WHERE ROWNUM <= 5;

DECLARE
    v_popular_sales NUMBER;
    v_non_popular_sales NUMBER;
    v_popular_count NUMBER;
    v_non_popular_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- TOP 10 INVENTORY BY SALES
    -- Purpose: Verify GetSkewedProductId distribution
    -- Expected: Products divisible by 10000 should dominate top sales
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- TOP 10 INVENTORY BY SALES (GetSkewedProductId Verification) ---');
    DBMS_OUTPUT.PUT_LINE('Verifying: Skewed product selection worked correctly');
    DBMS_OUTPUT.PUT_LINE('Expected: Products divisible by 10000 should appear in top 10 with higher SALES');
    DBMS_OUTPUT.PUT_LINE('Expected: SALES values should be significantly higher than pre-test baseline');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

SELECT * FROM (
    SELECT
        i.PROD_ID,
        p.TITLE,
        i.SALES,
        CASE
            WHEN MOD(i.PROD_ID, 10000) = 0 THEN '**POPULAR**'
            ELSE ''
        END AS IsPopularProduct
    FROM DS3.INVENTORY{store_number} i
    JOIN DS3.PRODUCTS{store_number} p ON i.PROD_ID = p.PROD_ID
    ORDER BY i.SALES DESC
)
WHERE ROWNUM <= 10;

DECLARE
    v_popular_sales NUMBER;
    v_non_popular_sales NUMBER;
    v_popular_count NUMBER;
    v_non_popular_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');

    -- Summary statistics on popular vs non-popular products
    SELECT SUM(SALES), COUNT(*) INTO v_popular_sales, v_popular_count
    FROM DS3.INVENTORY{store_number}
    WHERE MOD(PROD_ID, 10000) = 0;

    SELECT SUM(SALES), COUNT(*) INTO v_non_popular_sales, v_non_popular_count
    FROM DS3.INVENTORY{store_number}
    WHERE MOD(PROD_ID, 10000) != 0;

    DBMS_OUTPUT.PUT_LINE('GetSkewedProductId Effectiveness:');
    DBMS_OUTPUT.PUT_LINE('  Popular Products (ID % 10000 = 0):');
    DBMS_OUTPUT.PUT_LINE('    Count: ' || v_popular_count || ', Total Sales: ' || v_popular_sales);
    IF v_popular_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('    Avg Sales per Product: ' || ROUND(v_popular_sales / v_popular_count));
    END IF;
    DBMS_OUTPUT.PUT_LINE('  Non-Popular Products:');
    DBMS_OUTPUT.PUT_LINE('    Count: ' || v_non_popular_count || ', Total Sales: ' || v_non_popular_sales);
    IF v_non_popular_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('    Avg Sales per Product: ' || ROUND(v_non_popular_sales / v_non_popular_count));
    END IF;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- TOP 20 REORDER BY QUANTITY
    -- Purpose: Verify restock trigger functionality
    -- Expected: Reorder table should have new entries from benchmark
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- TOP 20 REORDER BY QUANTITY (Restock Trigger Verification) ---');
    DBMS_OUTPUT.PUT_LINE('Verifying: Restock trigger fired for products that sold out');
    DBMS_OUTPUT.PUT_LINE('Expected: REORDER table should show new restocking activity');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

SELECT * FROM (
    SELECT
        r.PROD_ID,
        p.TITLE,
        SUM(r.QUAN_REORDERED) AS TOTAL_REORDERED,
        COUNT(*) AS RESTOCK_COUNT,
        MAX(r.DATE_REORDERED) AS LAST_RESTOCK_DATE,
        CASE
            WHEN MOD(r.PROD_ID, 10000) = 0 THEN '**POPULAR**'
            ELSE ''
        END AS IsPopularProduct
    FROM DS3.REORDER{store_number} r
    JOIN DS3.PRODUCTS{store_number} p ON r.PROD_ID = p.PROD_ID
    GROUP BY r.PROD_ID, p.TITLE
    ORDER BY SUM(r.QUAN_REORDERED) DESC
)
WHERE ROWNUM <= 20;

DECLARE
    v_total_reorders NUMBER;
    v_popular_reorders NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');

    -- Reorder statistics
    SELECT COUNT(*) INTO v_total_reorders FROM DS3.REORDER{store_number};
    SELECT COUNT(*) INTO v_popular_reorders FROM DS3.REORDER{store_number} WHERE MOD(PROD_ID, 10000) = 0;

    DBMS_OUTPUT.PUT_LINE('Restock Trigger Statistics:');
    DBMS_OUTPUT.PUT_LINE('  Total Reorder Events: ' || v_total_reorders);
    DBMS_OUTPUT.PUT_LINE('  Popular Product Reorders: ' || v_popular_reorders);
    IF v_total_reorders > 0 THEN
        DBMS_OUTPUT.PUT_LINE('  Popular Product %: ' || ROUND(100 * v_popular_reorders / v_total_reorders) || '%');
    END IF;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- TOP 10 REVIEWS BY HELPFULNESS
    -- Purpose: Verify review and helpfulness operations
    -- Expected: New reviews created, helpfulness ratings accumulated
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- TOP 10 REVIEWS BY HELPFULNESS (Review Operations Verification) ---');
    DBMS_OUTPUT.PUT_LINE('Verifying: New reviews created and helpfulness ratings accumulated');
    DBMS_OUTPUT.PUT_LINE('Expected: TOTAL_HELPFULNESS values should be higher than pre-test');
    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('Pre-Test Top 10:');
END;
/

SELECT
    LPAD(TO_CHAR(t.rank_position), 5) AS Rank,
    LPAD(TO_CHAR(t.review_id), 10) AS ReviewID,
    LPAD(TO_CHAR(t.prod_id), 10) AS ProdID,
    LPAD(TO_CHAR(t.total_helpfulness), 12) AS Helpfulness
FROM VALIDATION_TOP_REVIEWS_{store_number} t
ORDER BY t.rank_position;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Post-Test Top 10:');
END;
/

SELECT
    ROWNUM AS Rank,
    LPAD(TO_CHAR(REVIEW_ID), 10) AS ReviewID,
    LPAD(TO_CHAR(PROD_ID), 10) AS ProdID,
    LPAD(TO_CHAR(TOTAL_HELPFULNESS), 12) AS Helpfulness,
    RPAD(CASE WHEN MOD(PROD_ID, 10000) = 0 THEN '**POPULAR**' ELSE '' END, 12) AS Popular
FROM (
    SELECT
        REVIEW_ID,
        PROD_ID,
        TOTAL_HELPFULNESS
    FROM DS3.REVIEWS{store_number}
    ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID
)
WHERE ROWNUM <= 10;

DECLARE
    v_total_reviews NUMBER;
    v_avg_helpfulness NUMBER;
    v_max_helpfulness NUMBER;
    v_total_helpfulness NUMBER;
    v_total_helpfulness_pre NUMBER;
    v_popular_product_reviews NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');

    -- Review statistics
    SELECT COUNT(*), AVG(TOTAL_HELPFULNESS), MAX(TOTAL_HELPFULNESS), NVL(SUM(TOTAL_HELPFULNESS), 0)
    INTO v_total_reviews, v_avg_helpfulness, v_max_helpfulness, v_total_helpfulness
    FROM DS3.REVIEWS{store_number};

    SELECT metric_value INTO v_total_helpfulness_pre
    FROM VALIDATION_METRICS_{store_number}
    WHERE metric_name = 'TOTAL_HELPFULNESS';

    DBMS_OUTPUT.PUT_LINE('Review Statistics:');
    DBMS_OUTPUT.PUT_LINE('  Total Reviews: ' || v_total_reviews);
    DBMS_OUTPUT.PUT_LINE('  Avg Helpfulness: ' || ROUND(v_avg_helpfulness, 2));
    DBMS_OUTPUT.PUT_LINE('  Max Helpfulness: ' || v_max_helpfulness);
    DBMS_OUTPUT.PUT_LINE('  Total Helpfulness (sum):');
    DBMS_OUTPUT.PUT_LINE('    Pre:   ' || v_total_helpfulness_pre);
    DBMS_OUTPUT.PUT_LINE('    Post:  ' || v_total_helpfulness);
    DBMS_OUTPUT.PUT_LINE('    Delta: ' || (v_total_helpfulness - v_total_helpfulness_pre));
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Reviews for Popular Products (ID % 10000 = 0):');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

SELECT
    NVL(pre.prod_id, post.PROD_ID) AS PROD_ID,
    NVL(pre.title, post.TITLE) AS TITLE,
    NVL(pre.review_count, 0) AS Pre,
    NVL(post.ReviewCount, 0) AS Post,
    NVL(post.ReviewCount, 0) - NVL(pre.review_count, 0) AS Delta
FROM VALIDATION_POPULAR_REVIEWS_{store_number} pre
FULL OUTER JOIN (
    SELECT
        p.PROD_ID,
        p.TITLE,
        COUNT(r.REVIEW_ID) AS ReviewCount
    FROM DS3.PRODUCTS{store_number} p
    LEFT JOIN DS3.REVIEWS{store_number} r ON p.PROD_ID = r.PROD_ID
    WHERE MOD(p.PROD_ID, 10000) = 0
    GROUP BY p.PROD_ID, p.TITLE
) post ON pre.prod_id = post.PROD_ID
ORDER BY NVL(post.ReviewCount, 0) DESC, NVL(pre.prod_id, post.PROD_ID);

DECLARE
    v_mismatch_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- UPDATE_HELPFULNESS TRIGGER VERIFICATION
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- UPDATE_HELPFULNESS TRIGGER VERIFICATION ---');
    DBMS_OUTPUT.PUT_LINE('Verifying: TOTAL_HELPFULNESS matches sum of individual helpfulness ratings');
    DBMS_OUTPUT.PUT_LINE('');

    SELECT COUNT(*) INTO v_mismatch_count
    FROM DS3.REVIEWS{store_number} r
    LEFT JOIN (
        SELECT REVIEW_ID, SUM(HELPFULNESS) AS CalculatedTotal
        FROM DS3.REVIEWS_HELPFULNESS{store_number}
        GROUP BY REVIEW_ID
    ) h ON r.REVIEW_ID = h.REVIEW_ID
    WHERE NVL(r.TOTAL_HELPFULNESS, 0) != NVL(h.CalculatedTotal, 0);

    DBMS_OUTPUT.PUT_LINE('Reviews with TOTAL_HELPFULNESS mismatch: ' || v_mismatch_count);
    DBMS_OUTPUT.PUT_LINE('  Expected: 0 (trigger should keep values in sync)');

    IF v_mismatch_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('WARNING: Found mismatches - showing first 10:');
    END IF;
END;
/

SELECT * FROM (
    SELECT
        r.REVIEW_ID,
        r.PROD_ID,
        r.TOTAL_HELPFULNESS AS Stored_Helpfulness,
        NVL(h.CalculatedTotal, 0) AS Calculated_Helpfulness,
        NVL(h.CalculatedTotal, 0) - NVL(r.TOTAL_HELPFULNESS, 0) AS Difference
    FROM DS3.REVIEWS{store_number} r
    LEFT JOIN (
        SELECT REVIEW_ID, SUM(HELPFULNESS) AS CalculatedTotal
        FROM DS3.REVIEWS_HELPFULNESS{store_number}
        GROUP BY REVIEW_ID
    ) h ON r.REVIEW_ID = h.REVIEW_ID
    WHERE NVL(r.TOTAL_HELPFULNESS, 0) != NVL(h.CalculatedTotal, 0)
)
WHERE ROWNUM <= 10;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- MANAGER OPERATION VERIFICATION
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- MANAGER OPERATION VERIFICATION ---');
    DBMS_OUTPUT.PUT_LINE('Verifying: Manager operations executed correctly (if managers enabled)');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- Manager-created products (price ends in .01)
DECLARE
    v_manager_products NUMBER;
    v_manager_products_pre NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_manager_products
    FROM DS3.PRODUCTS{store_number}
    WHERE (PRICE - FLOOR(PRICE)) = 0.01;

    SELECT metric_value INTO v_manager_products_pre
    FROM VALIDATION_METRICS_{store_number}
    WHERE metric_name = 'MANAGER_PRODUCTS_COUNT';

    DBMS_OUTPUT.PUT_LINE('Manager-Created Products (price .01):');
    DBMS_OUTPUT.PUT_LINE('  Pre:   ' || v_manager_products_pre);
    DBMS_OUTPUT.PUT_LINE('  Post:  ' || v_manager_products);
    DBMS_OUTPUT.PUT_LINE('  Delta: ' || (v_manager_products - v_manager_products_pre));
    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('Sample Manager-Created Products (price ends in .01):');
END;
/

SELECT * FROM (
    SELECT
        PROD_ID,
        TITLE,
        ACTOR,
        PRICE,
        SPECIAL,
        COMMON_PROD_ID
    FROM DS3.PRODUCTS{store_number}
    WHERE (PRICE - FLOOR(PRICE)) = 0.01
    ORDER BY PROD_ID DESC
)
WHERE ROWNUM <= 10;

-- Products marked as SPECIAL
DECLARE
    v_special_products NUMBER;
    v_special_products_pre NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_special_products
    FROM DS3.PRODUCTS{store_number}
    WHERE SPECIAL = 1;

    SELECT metric_value INTO v_special_products_pre
    FROM VALIDATION_METRICS_{store_number}
    WHERE metric_name = 'SPECIAL_PRODUCTS_COUNT';

    DBMS_OUTPUT.PUT_LINE('Products Marked Special (SPECIAL=1):');
    DBMS_OUTPUT.PUT_LINE('  Pre:   ' || v_special_products_pre);
    DBMS_OUTPUT.PUT_LINE('  Post:  ' || v_special_products);
    DBMS_OUTPUT.PUT_LINE('  Delta: ' || (v_special_products - v_special_products_pre));
    DBMS_OUTPUT.PUT_LINE('  (MarkSpecials toggles SPECIAL flag)');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- Price changes (detect products with non-standard pricing)
DECLARE
    v_adjusted_prices NUMBER;
    v_bulk_adjusted_prices NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_adjusted_prices
    FROM DS3.PRODUCTS{store_number}
    WHERE (PRICE - FLOOR(PRICE)) != 0.99 AND (PRICE - FLOOR(PRICE)) != 0.01;

    SELECT COUNT(*) INTO v_bulk_adjusted_prices
    FROM DS3.PRODUCTS{store_number}
    WHERE (PRICE - FLOOR(PRICE)) = 0.77;

    DBMS_OUTPUT.PUT_LINE('Products with Adjusted Prices (not ending in .99 or .01): ' || v_adjusted_prices);
    DBMS_OUTPUT.PUT_LINE('  - Prices ending in .77: ' || v_bulk_adjusted_prices || ' (BulkPriceAdjustment: category-wide ±25%)');
    DBMS_OUTPUT.PUT_LINE('  - Other endings: ' || (v_adjusted_prices - v_bulk_adjusted_prices) || ' (AdjustPrices: individual ±10%)');
    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('Sample Price-Adjusted Products (10 bulk .77 + 10 individual):');
END;
/

SELECT * FROM (
    SELECT * FROM (
        SELECT
            PROD_ID,
            TITLE,
            ACTOR,
            PRICE,
            SPECIAL,
            COMMON_PROD_ID,
            'Bulk (.77)' AS adjustment_type
        FROM DS3.PRODUCTS{store_number}
        WHERE (PRICE - FLOOR(PRICE)) = 0.77
        ORDER BY PROD_ID
    )
    WHERE ROWNUM <= 10
    UNION ALL
    SELECT * FROM (
        SELECT
            PROD_ID,
            TITLE,
            ACTOR,
            PRICE,
            SPECIAL,
            COMMON_PROD_ID,
            'Individual' AS adjustment_type
        FROM DS3.PRODUCTS{store_number}
        WHERE (PRICE - FLOOR(PRICE)) != 0.99
          AND (PRICE - FLOOR(PRICE)) != 0.01
          AND (PRICE - FLOOR(PRICE)) != 0.77
        ORDER BY PROD_ID
    )
    WHERE ROWNUM <= 10
)
ORDER BY adjustment_type DESC, PROD_ID;

-- Membership Expiration Verification
DECLARE
    v_total_memberships NUMBER;
    v_expired_memberships NUMBER;
    v_total_memberships_pre NUMBER;
    v_expired_memberships_pre NUMBER;
BEGIN
    -- Get current membership counts
    SELECT COUNT(*) INTO v_total_memberships FROM DS3.MEMBERSHIP{store_number};
    SELECT COUNT(*) INTO v_expired_memberships FROM DS3.MEMBERSHIP{store_number} WHERE EXPIREDATE < SYSDATE;

    -- Get pre-test membership counts
    SELECT metric_value INTO v_total_memberships_pre FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'TOTAL_MEMBERSHIPS';
    SELECT metric_value INTO v_expired_memberships_pre FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'EXPIRED_MEMBERSHIPS';

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Membership Status:');
    DBMS_OUTPUT.PUT_LINE('Verifying: Membership changes during benchmark');
    DBMS_OUTPUT.PUT_LINE('Expected: New memberships created, expired memberships may be deleted by ExpireMemberships manager');
    DBMS_OUTPUT.PUT_LINE('  Total Memberships:');
    DBMS_OUTPUT.PUT_LINE('    Pre:   ' || v_total_memberships_pre);
    DBMS_OUTPUT.PUT_LINE('    Post:  ' || v_total_memberships);
    DBMS_OUTPUT.PUT_LINE('    Delta: ' || (v_total_memberships - v_total_memberships_pre));
    DBMS_OUTPUT.PUT_LINE('  Expired Memberships (EXPIREDATE < current date):');
    DBMS_OUTPUT.PUT_LINE('    Pre:   ' || v_expired_memberships_pre);
    DBMS_OUTPUT.PUT_LINE('    Post:  ' || v_expired_memberships);
    DBMS_OUTPUT.PUT_LINE('    Delta: ' || (v_expired_memberships - v_expired_memberships_pre));
    DBMS_OUTPUT.PUT_LINE('  Active Memberships:');
    DBMS_OUTPUT.PUT_LINE('    Pre:   ' || (v_total_memberships_pre - v_expired_memberships_pre));
    DBMS_OUTPUT.PUT_LINE('    Post:  ' || (v_total_memberships - v_expired_memberships));
    DBMS_OUTPUT.PUT_LINE('    Delta: ' || ((v_total_memberships - v_expired_memberships) - (v_total_memberships_pre - v_expired_memberships_pre)));
    DBMS_OUTPUT.PUT_LINE('  (ExpireMemberships deletes expired entries, reducing total count)');
END;
/

-- New Product Verification
DECLARE
    v_max_prod_id_pre NUMBER;
    v_new_products_added NUMBER;
    v_new_products_with_inventory NUMBER;
    v_new_products_purchased NUMBER;
    v_new_products_reordered NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- NEW PRODUCT VERIFICATION
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- NEW PRODUCT VERIFICATION (Manager AddProduct Operations) ---');
    DBMS_OUTPUT.PUT_LINE('Verifying: New products added by managers are being used in benchmark');
    DBMS_OUTPUT.PUT_LINE('');

    -- Get baseline max product ID
    SELECT metric_value INTO v_max_prod_id_pre
    FROM VALIDATION_METRICS_{store_number}
    WHERE metric_name = 'MAX_PROD_ID';

    -- Count new products added
    SELECT COUNT(*) INTO v_new_products_added
    FROM DS3.PRODUCTS{store_number}
    WHERE PROD_ID > v_max_prod_id_pre;

    -- Count new products with inventory
    SELECT COUNT(DISTINCT i.PROD_ID) INTO v_new_products_with_inventory
    FROM DS3.INVENTORY{store_number} i
    WHERE i.PROD_ID > v_max_prod_id_pre;

    -- Count new products that were purchased
    SELECT COUNT(DISTINCT ol.PROD_ID) INTO v_new_products_purchased
    FROM DS3.ORDERLINES{store_number} ol
    WHERE ol.PROD_ID > v_max_prod_id_pre;

    -- Count new products that were reordered
    SELECT COUNT(DISTINCT r.PROD_ID) INTO v_new_products_reordered
    FROM DS3.REORDER{store_number} r
    WHERE r.PROD_ID > v_max_prod_id_pre;

    DBMS_OUTPUT.PUT_LINE('New Products Added (PROD_ID > ' || v_max_prod_id_pre || '): ' || v_new_products_added);
    DBMS_OUTPUT.PUT_LINE('  With Inventory Records:  ' || v_new_products_with_inventory);
    DBMS_OUTPUT.PUT_LINE('  Purchased (in ORDERLINES): ' || v_new_products_purchased);
    DBMS_OUTPUT.PUT_LINE('  Reordered (in REORDER):    ' || v_new_products_reordered);
    DBMS_OUTPUT.PUT_LINE('');

    IF v_new_products_added > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Coverage:');
        DBMS_OUTPUT.PUT_LINE('  Inventory: ' || ROUND(100.0 * v_new_products_with_inventory / v_new_products_added, 1) || '% (' || v_new_products_with_inventory || ' of ' || v_new_products_added || ')');
        DBMS_OUTPUT.PUT_LINE('  Purchased: ' || ROUND(100.0 * v_new_products_purchased / v_new_products_added, 1) || '% (' || v_new_products_purchased || ' of ' || v_new_products_added || ')');
        DBMS_OUTPUT.PUT_LINE('  Reordered: ' || ROUND(100.0 * v_new_products_reordered / v_new_products_added, 1) || '% (' || v_new_products_reordered || ' of ' || v_new_products_added || ')');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Expected: 100% inventory, >0% purchased/reordered (confirms AddProduct integration)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('No new products added (managers may be disabled or no AddProduct operations)');
    END IF;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Sample New Products (PROD_ID > ' || v_max_prod_id_pre || '):');
END;
/

SELECT * FROM (
    SELECT
        p.PROD_ID,
        p.TITLE,
        p.PRICE,
        NVL(i.QUAN_IN_STOCK, 0) AS Inventory,
        NVL(ol_count.purchases, 0) AS Purchases,
        NVL(r_count.reorders, 0) AS Reorders
    FROM DS3.PRODUCTS{store_number} p
    LEFT JOIN DS3.INVENTORY{store_number} i ON p.PROD_ID = i.PROD_ID
    LEFT JOIN (
        SELECT PROD_ID, COUNT(*) AS purchases
        FROM DS3.ORDERLINES{store_number}
        WHERE PROD_ID > (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MAX_PROD_ID')
        GROUP BY PROD_ID
    ) ol_count ON p.PROD_ID = ol_count.PROD_ID
    LEFT JOIN (
        SELECT PROD_ID, COUNT(*) AS reorders
        FROM DS3.REORDER{store_number}
        WHERE PROD_ID > (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MAX_PROD_ID')
        GROUP BY PROD_ID
    ) r_count ON p.PROD_ID = r_count.PROD_ID
    WHERE p.PROD_ID > (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MAX_PROD_ID')
    ORDER BY p.PROD_ID
)
WHERE ROWNUM <= 10;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Sample New Products in REORDER Table:');
END;
/

SELECT * FROM (
    SELECT
        r.PROD_ID,
        p.TITLE,
        SUM(r.QUAN_REORDERED) AS TOTAL_REORDERED,
        COUNT(*) AS REORDER_COUNT,
        MAX(r.DATE_REORDERED) AS LAST_REORDER
    FROM DS3.REORDER{store_number} r
    JOIN DS3.PRODUCTS{store_number} p ON r.PROD_ID = p.PROD_ID
    WHERE r.PROD_ID > (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MAX_PROD_ID')
    GROUP BY r.PROD_ID, p.TITLE
    ORDER BY MAX(r.DATE_REORDERED) DESC, r.PROD_ID
)
WHERE ROWNUM <= 10;

-- Final summary
DECLARE
    v_customers_before NUMBER;
    v_customers_after NUMBER;
    v_orders_before NUMBER;
    v_orders_after NUMBER;
    v_reviews_before NUMBER;
    v_reviews_after NUMBER;
    v_reviews_helpfulness_before NUMBER;
    v_reviews_helpfulness_after NUMBER;
    v_products_before NUMBER;
    v_products_after NUMBER;
    v_memberships_before NUMBER;
    v_memberships_after NUMBER;
    v_adjusted_prices NUMBER;
    v_max_customerid_pre NUMBER;
    v_reviews_delta NUMBER;
    v_helpfulness_deleted NUMBER;
    v_avg_helpfulness NUMBER;
    v_orderlines_before NUMBER;
    v_orderlines_after NUMBER;
    v_orders_delta NUMBER;
    v_orderlines_deleted NUMBER;
    v_avg_orderlines NUMBER;
    v_old_orders_before NUMBER;
    v_old_orders_after NUMBER;
    v_old_orders_deleted NUMBER;
    v_silver_members_before NUMBER;
    v_silver_members_after NUMBER;
    v_silver_delta NUMBER;
    v_gold_members_before NUMBER;
    v_gold_members_after NUMBER;
    v_gold_delta NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- CASCADE DELETE VERIFICATION
    -- Purpose: Verify REVIEWS_HELPFULNESS cascade deletes when reviews removed
    -- Expected: Helpfulness votes deleted when reviews deleted by manager operations
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- CASCADE DELETE VERIFICATION (REVIEWS_HELPFULNESS) ---');
    DBMS_OUTPUT.PUT_LINE('Verifying: Foreign key CASCADE DELETE when reviews are removed');
    DBMS_OUTPUT.PUT_LINE('Expected: REVIEWS_HELPFULNESS records deleted automatically when parent review deleted');
    DBMS_OUTPUT.PUT_LINE('Note: Users add reviews and managers delete reviews. Disable adding reviews with --ds2_mode=y');
    DBMS_OUTPUT.PUT_LINE('');

    SELECT metric_value INTO v_reviews_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'REVIEWS_COUNT';
    SELECT metric_value INTO v_reviews_helpfulness_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'REVIEWS_HELPFULNESS_COUNT';

    SELECT COUNT(*) INTO v_reviews_after FROM DS3.REVIEWS{store_number};
    SELECT COUNT(*) INTO v_reviews_helpfulness_after FROM DS3.REVIEWS_HELPFULNESS{store_number};

    v_reviews_delta := v_reviews_after - v_reviews_before;
    v_helpfulness_deleted := v_reviews_helpfulness_before - v_reviews_helpfulness_after;

    DBMS_OUTPUT.PUT_LINE('Reviews:');
    DBMS_OUTPUT.PUT_LINE('  Pre:        ' || v_reviews_before);
    DBMS_OUTPUT.PUT_LINE('  Post:       ' || v_reviews_after);
    DBMS_OUTPUT.PUT_LINE('  Net change: ' || v_reviews_delta);

    DBMS_OUTPUT.PUT_LINE('Reviews Helpfulness (should cascade delete with reviews):');
    DBMS_OUTPUT.PUT_LINE('  Pre:        ' || v_reviews_helpfulness_before);
    DBMS_OUTPUT.PUT_LINE('  Post:       ' || v_reviews_helpfulness_after);
    DBMS_OUTPUT.PUT_LINE('  Net change: ' || (-v_helpfulness_deleted));

    IF v_reviews_delta < 0 THEN
        v_avg_helpfulness := ROUND(v_helpfulness_deleted / (-v_reviews_delta), 2);
        DBMS_OUTPUT.PUT_LINE('  Avg helpfulness votes per deleted review: ' || v_avg_helpfulness);
    ELSE
        DBMS_OUTPUT.PUT_LINE('  (Net positive change - cannot verify cascade ratio)');
    END IF;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- CASCADE DELETE VERIFICATION (ORDERLINES)
    -- Purpose: Verify ORDERLINES cascade deletes when orders removed
    -- Expected: Orderlines deleted when orders deleted by manager PurgeOldOrders operation
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- CASCADE DELETE VERIFICATION (ORDERLINES) ---');
    DBMS_OUTPUT.PUT_LINE('Verifying: Foreign key CASCADE DELETE when orders are purged');
    DBMS_OUTPUT.PUT_LINE('Expected: ORDERLINES records deleted automatically when parent order deleted');
    DBMS_OUTPUT.PUT_LINE('Note: Users create orders and managers purge old orders.');
    DBMS_OUTPUT.PUT_LINE('');

    SELECT metric_value INTO v_orders_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'ORDERS_COUNT';
    SELECT metric_value INTO v_orderlines_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'ORDERLINES_COUNT';
    SELECT metric_value INTO v_old_orders_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'OLD_ORDERS_COUNT';

    SELECT COUNT(*) INTO v_orders_after FROM DS3.ORDERS{store_number};
    SELECT COUNT(*) INTO v_orderlines_after FROM DS3.ORDERLINES{store_number};
    SELECT COUNT(*) INTO v_old_orders_after FROM DS3.ORDERS{store_number} WHERE ORDERDATE < TRUNC(SYSDATE);

    v_orders_delta := v_orders_after - v_orders_before;
    v_orderlines_deleted := v_orderlines_before - v_orderlines_after;
    v_old_orders_deleted := v_old_orders_before - v_old_orders_after;

    DBMS_OUTPUT.PUT_LINE('Orders (all):');
    DBMS_OUTPUT.PUT_LINE('  Pre:        ' || v_orders_before);
    DBMS_OUTPUT.PUT_LINE('  Post:       ' || v_orders_after);
    DBMS_OUTPUT.PUT_LINE('  Net change: ' || v_orders_delta);

    DBMS_OUTPUT.PUT_LINE('Orders (old - prior to today):');
    DBMS_OUTPUT.PUT_LINE('  Pre:        ' || v_old_orders_before);
    DBMS_OUTPUT.PUT_LINE('  Post:       ' || v_old_orders_after);
    DBMS_OUTPUT.PUT_LINE('  Deleted:    ' || v_old_orders_deleted);

    DBMS_OUTPUT.PUT_LINE('Orderlines (should cascade delete with orders):');
    DBMS_OUTPUT.PUT_LINE('  Pre:        ' || v_orderlines_before);
    DBMS_OUTPUT.PUT_LINE('  Post:       ' || v_orderlines_after);
    DBMS_OUTPUT.PUT_LINE('  Net change: ' || (-v_orderlines_deleted));

    IF v_orders_delta < 0 THEN
        v_avg_orderlines := ROUND(v_orderlines_deleted / (-v_orders_delta), 2);
        DBMS_OUTPUT.PUT_LINE('  Avg orderlines per purged order: ' || v_avg_orderlines || ' (expected: ~5-6)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  (Net positive change - cannot verify cascade ratio)');
    END IF;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- MEMBERSHIP TIER
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- MEMBERSHIP TIER ---');

    SELECT metric_value INTO v_silver_members_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'SILVER_MEMBERS_COUNT';
    SELECT metric_value INTO v_gold_members_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'GOLD_MEMBERS_COUNT';

    SELECT COUNT(*) INTO v_silver_members_after FROM DS3.MEMBERSHIP{store_number} WHERE MEMBERSHIPTYPE = 2;
    SELECT COUNT(*) INTO v_gold_members_after FROM DS3.MEMBERSHIP{store_number} WHERE MEMBERSHIPTYPE = 3;

    v_silver_delta := v_silver_members_after - v_silver_members_before;
    v_gold_delta := v_gold_members_after - v_gold_members_before;

    DBMS_OUTPUT.PUT_LINE('Silver Members (Level 2):');
    DBMS_OUTPUT.PUT_LINE('  Pre:   ' || v_silver_members_before);
    DBMS_OUTPUT.PUT_LINE('  Post:  ' || v_silver_members_after);
    DBMS_OUTPUT.PUT_LINE('  Delta: ' || v_silver_delta);

    DBMS_OUTPUT.PUT_LINE('Gold Members (Level 3):');
    DBMS_OUTPUT.PUT_LINE('  Pre:   ' || v_gold_members_before);
    DBMS_OUTPUT.PUT_LINE('  Post:  ' || v_gold_members_after);
    DBMS_OUTPUT.PUT_LINE('  Delta: ' || v_gold_delta);

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- MEMBERSHIP CHANGE TRACKING (Full Snapshot Comparison) ---');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- Summary counts of all changes (optimized: separate queries instead of FULL OUTER JOIN)
DECLARE
    v_total NUMBER;
    v_deleted NUMBER;
    v_new NUMBER;
    v_up_1_2 NUMBER;
    v_up_2_3 NUMBER;
    v_up_1_3 NUMBER;
    v_extended NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_deleted
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    LEFT JOIN DS3.MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE m.CUSTOMERID IS NULL;

    SELECT COUNT(*) INTO v_new
    FROM DS3.MEMBERSHIP{store_number} m
    LEFT JOIN MEMBERSHIP_SNAPSHOT_{store_number} s ON m.CUSTOMERID = s.CUSTOMERID
    WHERE s.CUSTOMERID IS NULL;

    SELECT COUNT(*) INTO v_up_1_2
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN DS3.MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE s.MEMBERSHIPTYPE = 1 AND m.MEMBERSHIPTYPE = 2;

    SELECT COUNT(*) INTO v_up_2_3
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN DS3.MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE s.MEMBERSHIPTYPE = 2 AND m.MEMBERSHIPTYPE = 3;

    SELECT COUNT(*) INTO v_up_1_3
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN DS3.MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE s.MEMBERSHIPTYPE = 1 AND m.MEMBERSHIPTYPE = 3;

    SELECT COUNT(*) INTO v_extended
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN DS3.MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE m.MEMBERSHIPTYPE = s.MEMBERSHIPTYPE AND m.EXPIREDATE > s.EXPIREDATE;

    v_total := v_deleted + v_new + v_up_1_2 + v_up_2_3 + v_up_1_3 + v_extended;

    DBMS_OUTPUT.PUT_LINE(RPAD('TOTAL_CHANGES', 15) || RPAD('DELETED', 12) || RPAD('NEW_MEMBERSHIPS', 17) ||
                         RPAD('UPGRADES_1_TO_2', 17) || RPAD('UPGRADES_2_TO_3', 17) ||
                         RPAD('UPGRADES_1_TO_3', 17) || 'EXTENDED_ONLY');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 15, '-') || RPAD('-', 12, '-') || RPAD('-', 17, '-') ||
                         RPAD('-', 17, '-') || RPAD('-', 17, '-') || RPAD('-', 17, '-') || RPAD('-', 13, '-'));
    DBMS_OUTPUT.PUT_LINE(RPAD(v_total, 15) || RPAD(v_deleted, 12) || RPAD(v_new, 17) ||
                         RPAD(v_up_1_2, 17) || RPAD(v_up_2_3, 17) || RPAD(v_up_1_3, 17) || v_extended);
END;
/

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Top 30 Changes (Diverse Sample - Rarest First):');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- Top N of each change type for diverse representation
-- Top 5: 1->3 jumps (rarest)
SELECT * FROM (
    SELECT
        s.CUSTOMERID,
        s.MEMBERSHIPTYPE AS before_level,
        m.MEMBERSHIPTYPE AS after_level,
        TO_CHAR(s.EXPIREDATE, 'YYYY-MM-DD') AS before_expire,
        TO_CHAR(m.EXPIREDATE, 'YYYY-MM-DD') AS after_expire,
        '1->3 JUMP' AS status
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN DS3.MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE s.MEMBERSHIPTYPE = 1 AND m.MEMBERSHIPTYPE = 3
    ORDER BY s.CUSTOMERID
)
WHERE ROWNUM <= 5
UNION ALL
-- Top 5: 2->3 upgrades
SELECT * FROM (
    SELECT
        s.CUSTOMERID,
        s.MEMBERSHIPTYPE AS before_level,
        m.MEMBERSHIPTYPE AS after_level,
        TO_CHAR(s.EXPIREDATE, 'YYYY-MM-DD') AS before_expire,
        TO_CHAR(m.EXPIREDATE, 'YYYY-MM-DD') AS after_expire,
        '2->3 UPGRADE' AS status
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN DS3.MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE s.MEMBERSHIPTYPE = 2 AND m.MEMBERSHIPTYPE = 3
    ORDER BY s.CUSTOMERID
)
WHERE ROWNUM <= 5
UNION ALL
-- Top 5: DELETED (in snapshot but not in current table)
SELECT * FROM (
    SELECT
        s.CUSTOMERID,
        s.MEMBERSHIPTYPE AS before_level,
        -1 AS after_level,
        TO_CHAR(s.EXPIREDATE, 'YYYY-MM-DD') AS before_expire,
        'N/A' AS after_expire,
        'DELETED' AS status
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    LEFT JOIN DS3.MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE m.CUSTOMERID IS NULL
    ORDER BY s.CUSTOMERID
)
WHERE ROWNUM <= 5
UNION ALL
-- Top 5: NEW (in current table but not in snapshot)
SELECT * FROM (
    SELECT
        m.CUSTOMERID,
        -1 AS before_level,
        m.MEMBERSHIPTYPE AS after_level,
        'N/A' AS before_expire,
        TO_CHAR(m.EXPIREDATE, 'YYYY-MM-DD') AS after_expire,
        'NEW' AS status
    FROM DS3.MEMBERSHIP{store_number} m
    LEFT JOIN MEMBERSHIP_SNAPSHOT_{store_number} s ON m.CUSTOMERID = s.CUSTOMERID
    WHERE s.CUSTOMERID IS NULL
    ORDER BY m.CUSTOMERID
)
WHERE ROWNUM <= 5
UNION ALL
-- Top 10: 1->2 upgrades (most common, so show more)
SELECT * FROM (
    SELECT
        s.CUSTOMERID,
        s.MEMBERSHIPTYPE AS before_level,
        m.MEMBERSHIPTYPE AS after_level,
        TO_CHAR(s.EXPIREDATE, 'YYYY-MM-DD') AS before_expire,
        TO_CHAR(m.EXPIREDATE, 'YYYY-MM-DD') AS after_expire,
        '1->2 UPGRADE' AS status
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN DS3.MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE s.MEMBERSHIPTYPE = 1 AND m.MEMBERSHIPTYPE = 2
    ORDER BY s.CUSTOMERID
)
WHERE ROWNUM <= 10
UNION ALL
-- Top 5: EXTENDED (membership type unchanged but expiration date extended)
SELECT * FROM (
    SELECT
        s.CUSTOMERID,
        s.MEMBERSHIPTYPE AS before_level,
        m.MEMBERSHIPTYPE AS after_level,
        TO_CHAR(s.EXPIREDATE, 'YYYY-MM-DD') AS before_expire,
        TO_CHAR(m.EXPIREDATE, 'YYYY-MM-DD') AS after_expire,
        'EXTENDED' AS status
    FROM MEMBERSHIP_SNAPSHOT_{store_number} s
    INNER JOIN DS3.MEMBERSHIP{store_number} m ON s.CUSTOMERID = m.CUSTOMERID
    WHERE s.MEMBERSHIPTYPE = m.MEMBERSHIPTYPE AND m.EXPIREDATE > s.EXPIREDATE
    ORDER BY s.CUSTOMERID
)
WHERE ROWNUM <= 5;

DECLARE
    v_customers_before NUMBER;
    v_customers_after NUMBER;
    v_customers_delta NUMBER;
    v_orders_before NUMBER;
    v_orders_after NUMBER;
    v_orders_delta NUMBER;
    v_products_before NUMBER;
    v_products_after NUMBER;
    v_products_delta NUMBER;
    v_memberships_before NUMBER;
    v_memberships_after NUMBER;
    v_memberships_delta NUMBER;
    v_reviews_before NUMBER;
    v_reviews_after NUMBER;
    v_adjusted_prices NUMBER;
    v_max_customerid_pre NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- BENCHMARK ACTIVITY SUMMARY
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- BENCHMARK ACTIVITY SUMMARY ---');
    DBMS_OUTPUT.PUT_LINE('');

    -- Calculate deltas from baseline
    SELECT metric_value INTO v_customers_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'CUSTOMERS_COUNT';
    SELECT metric_value INTO v_orders_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'ORDERS_COUNT';
    SELECT metric_value INTO v_products_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'PRODUCTS_COUNT';
    SELECT metric_value INTO v_memberships_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MEMBERSHIP_COUNT';
    SELECT metric_value INTO v_reviews_before FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'REVIEWS_COUNT';

    SELECT COUNT(*) INTO v_customers_after FROM DS3.CUSTOMERS{store_number};
    SELECT COUNT(*) INTO v_orders_after FROM DS3.ORDERS{store_number};
    SELECT COUNT(*) INTO v_products_after FROM DS3.PRODUCTS{store_number};
    SELECT COUNT(*) INTO v_memberships_after FROM DS3.MEMBERSHIP{store_number};
    SELECT COUNT(*) INTO v_reviews_after FROM DS3.REVIEWS{store_number};

    DBMS_OUTPUT.PUT_LINE('New Records Created During Benchmark:');
    DBMS_OUTPUT.PUT_LINE('  Customers:   ' || (v_customers_after - v_customers_before));
    DBMS_OUTPUT.PUT_LINE('  Orders:      ' || (v_orders_after - v_orders_before));
    DBMS_OUTPUT.PUT_LINE('  Reviews:     ' || (v_reviews_after - v_reviews_before));
    DBMS_OUTPUT.PUT_LINE('  Products:    ' || (v_products_after - v_products_before));
    DBMS_OUTPUT.PUT_LINE('  Memberships: ' || (v_memberships_after - v_memberships_before));

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Manager Operation Impact:');
    SELECT COUNT(*) INTO v_adjusted_prices
    FROM DS3.PRODUCTS{store_number}
    WHERE (PRICE - FLOOR(PRICE)) != 0.99 AND (PRICE - FLOOR(PRICE)) != 0.01;
    DBMS_OUTPUT.PUT_LINE('  Products with Adjusted Prices: ' || v_adjusted_prices);

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- TOP 10 NEW CUSTOMERS
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- TOP 10 NEW CUSTOMERS (Created During Benchmark) ---');
    DBMS_OUTPUT.PUT_LINE('');

    SELECT metric_value INTO v_max_customerid_pre
    FROM VALIDATION_METRICS_{store_number}
    WHERE metric_name = 'MAX_CUSTOMERID';
END;
/

SELECT * FROM (
    SELECT
        CUSTOMERID,
        FIRSTNAME,
        LASTNAME,
        CITY
    FROM DS3.CUSTOMERS{store_number}
    WHERE CUSTOMERID > (SELECT metric_value FROM VALIDATION_METRICS_{store_number} WHERE metric_name = 'MAX_CUSTOMERID')
    ORDER BY CUSTOMERID
)
WHERE ROWNUM <= 10;

DECLARE
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE('Post-Test Validation Complete');
    DBMS_OUTPUT.PUT_LINE('Compare these results with validate_before.sql to verify:');
    DBMS_OUTPUT.PUT_LINE('  1. GetSkewedProductId: Popular products (ID % 10000) have highest sales');
    DBMS_OUTPUT.PUT_LINE('  2. Restock Trigger: REORDER table shows restocking for sold-out products');
    DBMS_OUTPUT.PUT_LINE('  3. Review Operations: New reviews created, helpfulness scores increased');
    DBMS_OUTPUT.PUT_LINE('  4. Manager Operations: New products added, prices adjusted, specials toggled');
    DBMS_OUTPUT.PUT_LINE('  5. Customer Growth: New customers and orders created during benchmark');
    DBMS_OUTPUT.PUT_LINE('========================================================================');
END;
/

EXIT;
