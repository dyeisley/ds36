-- DVD Store 3.6 - Pre-Test Validation Queries (Oracle)
-- Run this BEFORE starting the benchmark to capture baseline metrics
-- Compare with validate_after.sql results to verify test harness functionality

SET LINESIZE 200
SET PAGESIZE 1000
SET SERVEROUTPUT ON;

-- Set column widths for table count display
COLUMN TABLENAME FORMAT A20
COLUMN ROWCOUNT FORMAT 999999999999

-- Create validation metrics table if it doesn't exist
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM user_tables
    WHERE table_name = 'VALIDATION_METRICS';

    IF v_count = 0 THEN
        EXECUTE IMMEDIATE 'CREATE TABLE VALIDATION_METRICS (
            metric_name VARCHAR2(100) NOT NULL,
            metric_value NUMBER,
            snapshot_date DATE DEFAULT SYSDATE
        )';
    END IF;
END;
/

-- Create top reviews snapshot table if it doesn't exist
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM user_tables
    WHERE table_name = 'VALIDATION_TOP_REVIEWS';

    IF v_count = 0 THEN
        EXECUTE IMMEDIATE 'CREATE TABLE VALIDATION_TOP_REVIEWS (
            rank_position NUMBER NOT NULL,
            review_id NUMBER NOT NULL,
            prod_id NUMBER NOT NULL,
            total_helpfulness NUMBER NOT NULL,
            snapshot_date DATE DEFAULT SYSDATE
        )';
    END IF;
END;
/

-- Create popular products review counts snapshot table if it doesn't exist
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM user_tables
    WHERE table_name = 'VALIDATION_POPULAR_REVIEWS';

    IF v_count = 0 THEN
        EXECUTE IMMEDIATE 'CREATE TABLE VALIDATION_POPULAR_REVIEWS (
            prod_id NUMBER NOT NULL,
            title VARCHAR2(50) NOT NULL,
            review_count NUMBER NOT NULL,
            snapshot_date DATE DEFAULT SYSDATE
        )';
    END IF;
END;
/

-- Clear previous baseline metrics
DELETE FROM VALIDATION_METRICS;
DELETE FROM VALIDATION_TOP_REVIEWS;
DELETE FROM VALIDATION_POPULAR_REVIEWS;
COMMIT;

DECLARE
    v_manager_products NUMBER;
    v_special_products NUMBER;
    v_total_helpfulness NUMBER;
    v_max_customerid NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE('DVD Store 3.6 - Pre-Test Validation');
    DBMS_OUTPUT.PUT_LINE('Timestamp: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- TABLE ROW COUNTS
    -- Purpose: Establish baseline row counts for all tables
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- TABLE ROW COUNTS (Baseline) ---');
    DBMS_OUTPUT.PUT_LINE('Verifying: Initial data volume before benchmark execution');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

SELECT TABLENAME, ROWCOUNT FROM (
    SELECT 'CUSTOMERS' AS TABLENAME, COUNT(*) AS ROWCOUNT FROM DS3.CUSTOMERS1
    UNION ALL
    SELECT 'CUST_HIST', COUNT(*) FROM DS3.CUST_HIST1
    UNION ALL
    SELECT 'PRODUCTS', COUNT(*) FROM DS3.PRODUCTS1
    UNION ALL
    SELECT 'ORDERS', COUNT(*) FROM DS3.ORDERS1
    UNION ALL
    SELECT 'ORDERLINES', COUNT(*) FROM DS3.ORDERLINES1
    UNION ALL
    SELECT 'INVENTORY', COUNT(*) FROM DS3.INVENTORY1
    UNION ALL
    SELECT 'REVIEWS', COUNT(*) FROM DS3.REVIEWS1
    UNION ALL
    SELECT 'REVIEWS_HELPFULNESS', COUNT(*) FROM DS3.REVIEWS_HELPFULNESS1
    UNION ALL
    SELECT 'MEMBERSHIP', COUNT(*) FROM DS3.MEMBERSHIP1
    UNION ALL
    SELECT 'REORDER', COUNT(*) FROM DS3.REORDER1
)
ORDER BY TABLENAME;

-- Save table counts to metrics table
INSERT INTO VALIDATION_METRICS (metric_name, metric_value)
SELECT 'CUSTOMERS_COUNT', COUNT(*) FROM DS3.CUSTOMERS1
UNION ALL SELECT 'CUST_HIST_COUNT', COUNT(*) FROM DS3.CUST_HIST1
UNION ALL SELECT 'PRODUCTS_COUNT', COUNT(*) FROM DS3.PRODUCTS1
UNION ALL SELECT 'ORDERS_COUNT', COUNT(*) FROM DS3.ORDERS1
UNION ALL SELECT 'ORDERLINES_COUNT', COUNT(*) FROM DS3.ORDERLINES1
UNION ALL SELECT 'INVENTORY_COUNT', COUNT(*) FROM DS3.INVENTORY1
UNION ALL SELECT 'REVIEWS_COUNT', COUNT(*) FROM DS3.REVIEWS1
UNION ALL SELECT 'REVIEWS_HELPFULNESS_COUNT', COUNT(*) FROM DS3.REVIEWS_HELPFULNESS1
UNION ALL SELECT 'MEMBERSHIP_COUNT', COUNT(*) FROM DS3.MEMBERSHIP1
UNION ALL SELECT 'REORDER_COUNT', COUNT(*) FROM DS3.REORDER1
UNION ALL SELECT 'MAX_PROD_ID', NVL(MAX(PROD_ID), 0) FROM DS3.PRODUCTS1;
COMMIT;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- TOP 5 CUSTOMERS BY PURCHASE HISTORY
    -- Purpose: Verify CUST_HIST table is populated correctly
    -- Expected: Shows customers with most products ordered
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- TOP 5 CUSTOMERS BY PURCHASE HISTORY (CUST_HIST Verification) ---');
    DBMS_OUTPUT.PUT_LINE('Verifying: Customer purchase history tracking');
    DBMS_OUTPUT.PUT_LINE('Expected: After test, counts should increase as customers place orders');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

SELECT * FROM (
    SELECT
        LPAD(TO_CHAR(ch.CUSTOMERID), 10) AS CustID,
        RPAD(c.FIRSTNAME, 15) AS FirstName,
        RPAD(c.LASTNAME, 15) AS LastName,
        LPAD(TO_CHAR(COUNT(*)), 8) AS Products
    FROM DS3.CUST_HIST1 ch
    JOIN DS3.CUSTOMERS1 c ON ch.CUSTOMERID = c.CUSTOMERID
    GROUP BY ch.CUSTOMERID, c.FIRSTNAME, c.LASTNAME
    ORDER BY COUNT(*) DESC
)
WHERE ROWNUM <= 5;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- TOP 10 INVENTORY BY SALES
    -- Purpose: Verify GetSkewedProductId distribution
    -- Expected: Products divisible by 10000 should have higher sales
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- TOP 10 INVENTORY BY SALES (GetSkewedProductId Verification) ---');
    DBMS_OUTPUT.PUT_LINE('Verifying: Skewed product selection (every 10,000th product should be popular)');
    DBMS_OUTPUT.PUT_LINE('Expected: After test, PROD_ID values divisible by 10000 should appear in top sales');
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
    FROM DS3.INVENTORY1 i
    JOIN DS3.PRODUCTS1 p ON i.PROD_ID = p.PROD_ID
    ORDER BY i.SALES DESC
)
WHERE ROWNUM <= 10;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- TOP 20 REORDER BY QUANTITY
    -- Purpose: Verify restock trigger functionality
    -- Expected: Products with high sales should trigger restocking
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- TOP 20 REORDER BY QUANTITY (Restock Trigger Verification) ---');
    DBMS_OUTPUT.PUT_LINE('Verifying: Restock trigger fires when inventory drops below threshold');
    DBMS_OUTPUT.PUT_LINE('Expected: After test, reorder table should show restocking activity');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

SELECT * FROM (
    SELECT
        r.PROD_ID,
        p.TITLE,
        SUM(r.QUAN_REORDERED) AS TOTAL_REORDERED,
        COUNT(*) AS RESTOCK_COUNT,
        MAX(r.DATE_REORDERED) AS LAST_RESTOCK_DATE
    FROM DS3.REORDER1 r
    JOIN DS3.PRODUCTS1 p ON r.PROD_ID = p.PROD_ID
    GROUP BY r.PROD_ID, p.TITLE
    ORDER BY SUM(r.QUAN_REORDERED) DESC
)
WHERE ROWNUM <= 20;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- TOP 10 REVIEWS BY HELPFULNESS
    -- Purpose: Verify review and helpfulness operations
    -- Expected: Reviews should accumulate helpfulness ratings
    -- NOTE: Use --ds2_mode=y to verify review removal (no new reviews, no helpfulness updates)
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- TOP 10 REVIEWS BY HELPFULNESS (Review Operations Verification) ---');
    DBMS_OUTPUT.PUT_LINE('Verifying: New reviews created and helpfulness ratings accumulated');
    DBMS_OUTPUT.PUT_LINE('Expected: After test, reviews should show positive helpfulness scores');
    DBMS_OUTPUT.PUT_LINE('NOTE: Use --ds2_mode=y to verify review removal (no adds, no helpfulness updates)');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

SELECT * FROM (
    SELECT
        ROWNUM AS Rank,
        LPAD(TO_CHAR(REVIEW_ID), 10) AS ReviewID,
        LPAD(TO_CHAR(PROD_ID), 10) AS ProdID,
        LPAD(TO_CHAR(TOTAL_HELPFULNESS), 12) AS Helpfulness,
        RPAD(CASE WHEN MOD(PROD_ID, 10000) = 0 THEN '**POPULAR**' ELSE '' END, 12) AS Popular
    FROM DS3.REVIEWS1
    ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID
)
WHERE ROWNUM <= 10;

-- Save top reviews to snapshot table
INSERT INTO VALIDATION_TOP_REVIEWS (rank_position, review_id, prod_id, total_helpfulness)
SELECT * FROM (
    SELECT
        ROWNUM AS rank_position,
        REVIEW_ID,
        PROD_ID,
        TOTAL_HELPFULNESS
    FROM DS3.REVIEWS1
    ORDER BY TOTAL_HELPFULNESS DESC, REVIEW_ID
)
WHERE ROWNUM <= 10;
COMMIT;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Reviews for Popular Products (ID % 10000 = 0):');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

SELECT
    p.PROD_ID,
    p.TITLE,
    COUNT(r.REVIEW_ID) AS ReviewCount
FROM DS3.PRODUCTS1 p
LEFT JOIN DS3.REVIEWS1 r ON p.PROD_ID = r.PROD_ID
WHERE MOD(p.PROD_ID, 10000) = 0
GROUP BY p.PROD_ID, p.TITLE
ORDER BY COUNT(r.REVIEW_ID) DESC, p.PROD_ID;

-- Save popular product review counts to snapshot table
INSERT INTO VALIDATION_POPULAR_REVIEWS (prod_id, title, review_count)
SELECT
    p.PROD_ID,
    p.TITLE,
    COUNT(r.REVIEW_ID)
FROM DS3.PRODUCTS1 p
LEFT JOIN DS3.REVIEWS1 r ON p.PROD_ID = r.PROD_ID
WHERE MOD(p.PROD_ID, 10000) = 0
GROUP BY p.PROD_ID, p.TITLE;

COMMIT;

DECLARE
    v_manager_products NUMBER;
    v_special_products NUMBER;
    v_total_helpfulness NUMBER;
    v_max_customerid NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('');

    -- =======================================================================
    -- ADDITIONAL BASELINE METRICS
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('--- ADDITIONAL BASELINE METRICS ---');
    DBMS_OUTPUT.PUT_LINE('');

    -- Manager-created products (price ends in .01)
    SELECT COUNT(*) INTO v_manager_products
    FROM DS3.PRODUCTS1
    WHERE (PRICE - FLOOR(PRICE)) = 0.01;
    DBMS_OUTPUT.PUT_LINE('Manager-Created Products (price .01): ' || v_manager_products);

    -- Products marked as SPECIAL
    SELECT COUNT(*) INTO v_special_products
    FROM DS3.PRODUCTS1
    WHERE SPECIAL = 1;
    DBMS_OUTPUT.PUT_LINE('Products Marked Special (SPECIAL=1): ' || v_special_products);
    DBMS_OUTPUT.PUT_LINE('  ** Record this count to compare with post-test results **');

    -- Total helpfulness
    SELECT NVL(SUM(TOTAL_HELPFULNESS), 0) INTO v_total_helpfulness
    FROM DS3.REVIEWS1;

    -- Max customer ID
    SELECT MAX(CUSTOMERID) INTO v_max_customerid
    FROM DS3.CUSTOMERS1;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Top 10 Newest Customers (highest CUSTOMERID):');

    -- Save additional metrics to table
    INSERT INTO VALIDATION_METRICS (metric_name, metric_value)
    VALUES ('MANAGER_PRODUCTS_COUNT', v_manager_products);
    INSERT INTO VALIDATION_METRICS (metric_name, metric_value)
    VALUES ('SPECIAL_PRODUCTS_COUNT', v_special_products);
    INSERT INTO VALIDATION_METRICS (metric_name, metric_value)
    VALUES ('TOTAL_HELPFULNESS', v_total_helpfulness);
    INSERT INTO VALIDATION_METRICS (metric_name, metric_value)
    VALUES ('MAX_CUSTOMERID', v_max_customerid);
    COMMIT;
END;
/

SELECT * FROM (
    SELECT
        CUSTOMERID,
        FIRSTNAME,
        LASTNAME,
        CITY
    FROM DS3.CUSTOMERS1
    ORDER BY CUSTOMERID DESC
)
WHERE ROWNUM <= 10;

DECLARE
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE('Pre-Test Validation Complete');
    DBMS_OUTPUT.PUT_LINE('Baseline metrics saved to VALIDATION_METRICS table');
    DBMS_OUTPUT.PUT_LINE('Run validate_after.sql to compare with post-test results');
    DBMS_OUTPUT.PUT_LINE('========================================================================');
END;
/

EXIT;
