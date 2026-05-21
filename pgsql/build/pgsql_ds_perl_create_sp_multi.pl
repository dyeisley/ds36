# pgsql_ds_perl_create_sp_multi.pl
# Script to create a ds36 stored procedures in PostgresQL with a provided number of copies - supporting multiple stores
# Syntax to run - perl pgsql_ds_perl_create_sp_multi.pl <psql_target> <number_of_stores>

use strict;
use warnings;

my $pgsql_target = $ARGV[0];
my $numStores = $ARGV[1];
my $PGPASSWORD = "ds3";
my $DBNAME = "ds3";
my $SYSDBA = "ds3";

my $pathsep;

#Need seperate target directory so that mulitple DB Targets can be loaded at the same time
my $pgsql_targetdir;  

$pgsql_targetdir = $pgsql_target;

# remove any backslashes from string to be used for directory name
$pgsql_targetdir =~ s/\\//;

# This section enables support for Linux and Windows - detecting the type of OS, and then using the proper commands
if ("$^O" eq "linux")
        {
        $pathsep = "/";
        }
else
        {
        $pathsep = "\\\\";
        };

system ("mkdir -p $pgsql_targetdir");

foreach my $k (1 .. $numStores){
	open(my $OUT, ">$pgsql_targetdir${pathsep}pgsql_ds_createsp.sql") || die("Can't open pgsql_ds_createsp.sql");
	print $OUT "
\\c $DBNAME;

CREATE OR REPLACE FUNCTION new_customer$k (
    IN firstname_in VARCHAR(50),
    IN lastname_in VARCHAR(50),
    IN address1_in VARCHAR(50),
    IN address2_in VARCHAR(50),
    IN city_in VARCHAR(50),
    IN state_in VARCHAR(50),
    IN zip_in VARCHAR(9),
    IN country_in VARCHAR(50),
    IN region_in SMALLINT,
    IN email_in VARCHAR(50),
    IN phone_in VARCHAR(50),
    IN creditcardtype_in int,
    IN creditcard_in VARCHAR(50),
    IN creditcardexpiration_in VARCHAR(50),
    IN username_in VARCHAR(50),
    IN password_in VARCHAR(50),
    IN age_in SMALLINT,
    IN income_in int,
    IN gender_in VARCHAR(1)
)
RETURNS INTEGER
LANGUAGE plpgsql
AS \$\$
DECLARE
    customerid_out INTEGER;
BEGIN
    BEGIN
    INSERT INTO CUSTOMERS$k (
          firstname,
          lastname,
          email,
          phone,
          username,
          password,
          address1,
          address2,
          city,
          state,
          zip,
          country,
          region,
          creditcardtype,
          creditcard,
          creditcardexpiration,
          age,
          income,
          gender
    )
    VALUES (
          firstname_in,
          lastname_in,
          email_in,
          phone_in,
          username_in,
          password_in,
          address1_in,
          address2_in,
          city_in,
          state_in,
          zip_in,
          country_in,
          region_in,
          creditcardtype_in,
          creditcard_in,
          creditcardexpiration_in,
          age_in,
	  income_in,
	  gender_in
    )
    RETURNING customerid INTO customerid_out;
    RETURN customerid_out;
    EXCEPTION
    	WHEN unique_violation THEN
            RETURN 0;
    END;
    -- RETURN -1;
END;
\$\$
;

CREATE OR REPLACE FUNCTION login$k (
    IN username_in text,
    IN password_in text

)
RETURNS TABLE (r_customerid int, r_title text, r_actor text, r_relatedpurchase text)
LANGUAGE plpgsql
AS \$\$
DECLARE
    customerid_out INT;
BEGIN
    -- Authenticate user
    SELECT CUSTOMERID INTO customerid_out FROM CUSTOMERS$k WHERE USERNAME=username_in AND PASSWORD=password_in;

    IF FOUND THEN
        -- Execute complex query ONCE and return results
        -- If user has purchase history, return related products
        -- If no purchase history, return customerid with 'None' placeholders
        RETURN QUERY
        SELECT
            customerid_out,
            COALESCE(derivedtable1.TITLE, 'None'::text),
            COALESCE(derivedtable1.ACTOR, 'None'::text),
            COALESCE(PRODUCTS_1.TITLE, 'None'::text)
        FROM (
            SELECT
                PRODUCTS$k.TITLE,
                PRODUCTS$k.ACTOR,
                PRODUCTS$k.PROD_ID,
                PRODUCTS$k.COMMON_PROD_ID
            FROM CUST_HIST$k
            INNER JOIN PRODUCTS$k ON CUST_HIST$k.PROD_ID = PRODUCTS$k.PROD_ID
            WHERE CUST_HIST$k.CUSTOMERID = customerid_out
            ORDER BY ORDERID DESC, TITLE ASC
            LIMIT 10
        ) AS derivedtable1
        LEFT JOIN PRODUCTS$k AS PRODUCTS_1 ON derivedtable1.COMMON_PROD_ID = PRODUCTS_1.PROD_ID

        UNION ALL

        -- If no purchase history exists, return one row with 'None' values
        SELECT customerid_out, 'None'::text, 'None'::text, 'None'::text
        WHERE NOT EXISTS (
            SELECT 1 FROM CUST_HIST$k WHERE CUSTOMERID = customerid_out
        )
        LIMIT 10;
    ELSE
        -- Login failed - return customerid 0
        RETURN QUERY SELECT 0, 'None'::text, 'None'::text, 'None'::text;
    END IF;

    RETURN;
END;
\$\$;


CREATE OR REPLACE FUNCTION BROWSE_BY_CATEGORY$k (
    IN batch_size_in INTEGER,
    IN category_in INTEGER,
    IN special_in INTEGER
)
RETURNS SETOF PRODUCTS$k
LANGUAGE plpgsql
AS \$\$
BEGIN
    RETURN QUERY SELECT * FROM PRODUCTS$k WHERE CATEGORY=category_in AND SPECIAL=special_in LIMIT batch_size_in;
    RETURN;
END;
\$\$;


CREATE OR REPLACE FUNCTION BROWSE_BY_ACTOR$k(
    IN batch_size_in INTEGER,
    IN actor_in TEXT
)
RETURNS SETOF PRODUCTS$k
LANGUAGE plpgsql
AS \$\$
DECLARE
  vector_in TEXT;
BEGIN
    vector_in := replace(trim(both from actor_in), ' ','&');
    RETURN QUERY SELECT * FROM PRODUCTS$k WHERE to_tsvector('simple',ACTOR) \@\@ to_tsquery(vector_in) LIMIT batch_size_in;
    RETURN;
END;
\$\$;


CREATE OR REPLACE FUNCTION BROWSE_BY_TITLE$k (
    IN batch_size_in INTEGER,
    IN title_in TEXT
)
RETURNS SETOF PRODUCTS$k
LANGUAGE plpgsql
AS \$\$
DECLARE
  vector_in TEXT;
BEGIN
    vector_in := replace(trim(both from title_in), ' ','&');
    RETURN QUERY SELECT * FROM PRODUCTS$k WHERE to_tsvector('simple',TITLE) \@\@ to_tsquery(vector_in) LIMIT batch_size_in;
    RETURN;
END;
\$\$;


CREATE OR REPLACE FUNCTION BROWSE_BY_MEMBERSHIP$k (
    IN batch_size_in INTEGER,
    IN membershiptype_in INTEGER
)
RETURNS SETOF PRODUCTS$k
LANGUAGE plpgsql
AS \$\$
BEGIN
    RETURN QUERY SELECT * FROM PRODUCTS$k WHERE MEMBERSHIP_ITEM=membershiptype_in LIMIT batch_size_in;
    RETURN;
END;
\$\$;


CREATE OR REPLACE FUNCTION PURCHASE$k (
    IN customerid_in INTEGER,
    IN number_items INTEGER,
    IN netamount_in NUMERIC,
    IN taxamount_in NUMERIC,
    IN totalamount_in NUMERIC,
    IN prod_id_in0 INTEGER DEFAULT 0, IN qty_in0 INTEGER DEFAULT 0,
    IN prod_id_in1 INTEGER DEFAULT 0, IN qty_in1 INTEGER DEFAULT 0,
    IN prod_id_in2 INTEGER DEFAULT 0, IN qty_in2 INTEGER DEFAULT 0,
    IN prod_id_in3 INTEGER DEFAULT 0, IN qty_in3 INTEGER DEFAULT 0,
    IN prod_id_in4 INTEGER DEFAULT 0, IN qty_in4 INTEGER DEFAULT 0,
    IN prod_id_in5 INTEGER DEFAULT 0, IN qty_in5 INTEGER DEFAULT 0,
    IN prod_id_in6 INTEGER DEFAULT 0, IN qty_in6 INTEGER DEFAULT 0,
    IN prod_id_in7 INTEGER DEFAULT 0, IN qty_in7 INTEGER DEFAULT 0,
    IN prod_id_in8 INTEGER DEFAULT 0, IN qty_in8 INTEGER DEFAULT 0,
    IN prod_id_in9 INTEGER DEFAULT 0, IN qty_in9 INTEGER DEFAULT 0
)
RETURNS INTEGER
LANGUAGE plpgsql
AS \$\$
DECLARE
  date_in TIMESTAMP;
  neworderid INTEGER;
  item_id    INTEGER;
  prodid    INTEGER;
  qty        INTEGER;
  cur_quan   INTEGER;
  new_quan   INTEGER;
  cur_sales  INTEGER;
  new_sales  INTEGER;
BEGIN
 date_in := current_timestamp;
 BEGIN
   INSERT INTO ORDERS$k
    (
    ORDERDATE, CUSTOMERID, NETAMOUNT, TAX, TOTALAMOUNT
    )
  VALUES
  (
    date_in, customerid_in, netamount_in, taxamount_in, totalamount_in
    )
    RETURNING orderid INTO neworderid;


  -- neworderid := CURRVAL('orders_orderid_seq');


  -- ADD LINE ITEMS TO ORDERLINES

  item_id := 0;

  WHILE (item_id < number_items) LOOP
    prodid := CASE item_id WHEN 0 THEN prod_id_in0
                                  WHEN 1 THEN prod_id_in1
                                  WHEN 2 THEN prod_id_in2
                                  WHEN 3 THEN prod_id_in3
                                  WHEN 4 THEN prod_id_in4
                                  WHEN 5 THEN prod_id_in5
                                  WHEN 6 THEN prod_id_in6
                                  WHEN 7 THEN prod_id_in7
                                  WHEN 8 THEN prod_id_in8
                                  WHEN 9 THEN prod_id_in9
                      END;

    qty := CASE item_id WHEN 0 THEN qty_in0
                                    WHEN 1 THEN qty_in1
                                    WHEN 2 THEN qty_in2
                                    WHEN 3 THEN qty_in3
                                    WHEN 4 THEN qty_in4
                                    WHEN 5 THEN qty_in5
                                    WHEN 6 THEN qty_in6
                                    WHEN 7 THEN qty_in7
                                    WHEN 8 THEN qty_in8
                                    WHEN 9 THEN qty_in9
                        END;

    SELECT QUAN_IN_STOCK, SALES  INTO cur_quan, cur_sales FROM INVENTORY$k WHERE PROD_ID=prodid;
    new_quan := cur_quan - qty;
    new_sales := cur_Sales + qty;

    IF (new_quan < 0) THEN
        -- RAISE EXCEPTION 'Insufficient Quantity for prodid:%' , prodid;
        RETURN 0;
    ELSE
        UPDATE INVENTORY$k SET QUAN_IN_STOCK=new_quan, SALES=new_sales WHERE PROD_ID=prodid;
        INSERT INTO ORDERLINES$k
          (
          ORDERLINEID, ORDERID, PROD_ID, QUANTITY, ORDERDATE
          )
        VALUES
          (
          item_id + 1, neworderid, prodid, qty, date_in
          );

        INSERT INTO CUST_HIST$k
          (
          CUSTOMERID, ORDERID, PROD_ID
          )
        VALUES
          (
          customerid_in, neworderid, prodid
          );

        item_id := item_id + 1;
     END IF;
  END LOOP;
  RETURN neworderid;
 END;
END;
\$\$;

CREATE OR REPLACE FUNCTION new_member$k (
  IN customerid_in INT,
  IN membershiplevel_in INT

  )
  RETURNS INTEGER
  LANGUAGE plpgsql
  AS \$\$
  DECLARE
    customerid_out INTEGER;
  BEGIN
    BEGIN
      INSERT INTO MEMBERSHIP$k
        (CUSTOMERID,
         MEMBERSHIPTYPE,
         EXPIREDATE
         )
       VALUES
         (
         customerid_in,
         membershiplevel_in,
         current_date + INTERVAL '1 year'
         )
       RETURNING customerid INTO customerid_out;
           RETURN customerid_out;
           EXCEPTION
             WHEN unique_violation THEN
                RETURN 0;
       END;
 END;
 \$\$;

CREATE OR REPLACE FUNCTION get_membership_status$k (
  IN customerid_in INT
  )
  RETURNS TABLE (membership_level INT, is_expired INT)
  LANGUAGE plpgsql
  AS \$\$
  DECLARE
    v_membershiptype INT;
    v_expiredate DATE;
  BEGIN
    SELECT MEMBERSHIPTYPE, EXPIREDATE
    INTO v_membershiptype, v_expiredate
    FROM MEMBERSHIP$k
    WHERE CUSTOMERID = customerid_in;

    IF NOT FOUND THEN
      RETURN QUERY SELECT 0, 0;
      RETURN;
    END IF;

    IF v_expiredate < CURRENT_DATE THEN
      RETURN QUERY SELECT v_membershiptype, 1;
    ELSE
      RETURN QUERY SELECT v_membershiptype, 0;
    END IF;
    RETURN;
  END;
  \$\$;

CREATE OR REPLACE FUNCTION renew_membership$k (
  IN customerid_in INT
  )
  RETURNS INTEGER
  LANGUAGE plpgsql
  AS \$\$
  DECLARE
    rows_affected INT;
  BEGIN
    UPDATE MEMBERSHIP$k
    SET EXPIREDATE = CURRENT_DATE + INTERVAL '1 year'
    WHERE CUSTOMERID = customerid_in;

    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    RETURN rows_affected;
  END;
  \$\$;

CREATE OR REPLACE FUNCTION new_prod_review$k
  (
  IN prod_id_in INT,
  IN stars_in INT,
  IN customerid_in INT,
  IN review_summary_in TEXT,
  IN review_text_in TEXT
  )
  RETURNS INTEGER
  LANGUAGE plpgsql
  AS \$\$
  DECLARE
    review_id_out INTEGER;
  BEGIN
      INSERT INTO REVIEWS$k
        (
        PROD_ID,
        REVIEW_DATE,
        STARS,
        CUSTOMERID,
        REVIEW_SUMMARY,
        REVIEW_TEXT
        )
        VALUES
        (
        prod_id_in,
            current_date,
        stars_in,
        customerid_in,
        review_summary_in,
        review_text_in
        )
                RETURNING review_id INTO review_id_out;
        RETURN review_id_out;
      COMMIT;
END;
\$\$;

CREATE OR REPLACE FUNCTION new_review_helpfulness$k
  (
  IN review_id_in INT,
  IN customerid_in INT,
  IN review_helpfulness_in INT
  )
  RETURNS INTEGER
  LANGUAGE plpgsql
  AS \$\$
  DECLARE
    review_helpfulness_id_out INT;
  BEGIN
    INSERT INTO REVIEWS_HELPFULNESS$k
        (
        REVIEW_ID,
        CUSTOMERID,
        HELPFULNESS
        )
        VALUES
        (
        review_id_in,
        customerid_in,
        review_helpfulness_in
        )
        ON CONFLICT (REVIEW_ID, CUSTOMERID) DO UPDATE
          SET HELPFULNESS = review_helpfulness_in
                RETURNING REVIEW_HELPFULNESS_ID INTO review_helpfulness_id_out;
      RETURN review_helpfulness_id_out;
          COMMIT;
END;
\$\$;

CREATE OR REPLACE FUNCTION get_prod_reviews$k(
    batch_size_in INT,
    prod_in INT
)
RETURNS TABLE (
    r_review_id int,
    r_prod_id int,
    r_review_date date,
    r_stars smallint,
    r_customerid int,
    r_review_summary text,
    r_review_text text,
    r_totalhelp int
)
LANGUAGE plpgsql
AS \$\$
BEGIN
    RETURN QUERY
    SELECT
        REVIEW_ID,
        PROD_ID,
        REVIEW_DATE,
        STARS,
        CUSTOMERID,
        REVIEW_SUMMARY,
        REVIEW_TEXT,
        total_helpfulness
    FROM REVIEWS$k
    WHERE PROD_ID = prod_in
    ORDER BY total_helpfulness DESC
    LIMIT batch_size_in;
END;
\$\$;

CREATE OR REPLACE FUNCTION get_prod_reviews_by_stars$k(
    batch_size_in INT,
    prod_in INT,
    stars_in INT
)
RETURNS TABLE (
    r_review_id int, 
    r_prod_id int, 
    r_review_date date, 
    r_stars smallint,
    r_customerid int, 
    r_review_summary text, 
    r_review_text text, 
    r_totalhelp int
)
LANGUAGE plpgsql
AS \$\$
BEGIN
    RETURN QUERY
    SELECT 
        REVIEW_ID, 
        PROD_ID, 
        REVIEW_DATE, 
        STARS, 
        CUSTOMERID,
        REVIEW_SUMMARY, 
        REVIEW_TEXT, 
        total_helpfulness
    FROM REVIEWS$k
    WHERE PROD_ID = prod_in 
      AND STARS = stars_in::smallint
    ORDER BY total_helpfulness DESC 
    LIMIT batch_size_in;
END;
\$\$;

CREATE OR REPLACE FUNCTION get_prod_reviews_by_date$k(
    batch_size_in INT,
    prod_in INT
)
RETURNS TABLE (
    r_review_id int,
    r_prod_id int,
    r_review_date date,
    r_stars smallint,
    r_customerid int,
    r_review_summary text,
    r_review_text text,
    r_totalhelp int
)
LANGUAGE plpgsql
AS \$\$
BEGIN
    RETURN QUERY
    SELECT
        REVIEW_ID,
        PROD_ID,
        REVIEW_DATE,
        STARS,
        CUSTOMERID,
        REVIEW_SUMMARY,
        REVIEW_TEXT,
        total_helpfulness
    FROM REVIEWS$k
    WHERE PROD_ID = prod_in
    ORDER BY REVIEW_DATE DESC
    LIMIT batch_size_in;
END;
\$\$;

CREATE OR REPLACE FUNCTION get_prod_reviews_by_actor$k(
    batch_size_in INT,
    search_depth_in INT,
    actor_in TEXT
)
RETURNS TABLE (
    r_prod_id int,
    r_title text,
    r_actor text,
    r_review_id int,
    r_review_date date,
    r_stars smallint,
    r_customerid int,
    r_review_summary text,
    r_review_text text,
    r_totalhelp int
)
LANGUAGE plpgsql
AS \$\$
DECLARE
    vector_in tsquery;
BEGIN
    vector_in := to_tsquery('simple', replace(trim(actor_in), ' ', ' & '));

    -- Two-tier limiting: search_depth limits products, batch_size limits final reviews
    RETURN QUERY
    SELECT
        p.PROD_ID,
        p.TITLE,
        p.ACTOR,
        r.REVIEW_ID,
        r.REVIEW_DATE,
        r.STARS,
        r.CUSTOMERID,
        r.REVIEW_SUMMARY,
        r.REVIEW_TEXT,
        r.total_helpfulness
    FROM (
        SELECT PROD_ID, TITLE, ACTOR
        FROM PRODUCTS$k
        WHERE to_tsvector('simple', ACTOR) @@ vector_in
        LIMIT search_depth_in
    ) p
    INNER JOIN REVIEWS$k r ON p.PROD_ID = r.PROD_ID
    ORDER BY r.total_helpfulness DESC
    LIMIT batch_size_in;
END;
\$\$;

CREATE OR REPLACE FUNCTION get_prod_reviews_by_title$k(
    batch_size_in INT,
    search_depth_in INT,
    title_in TEXT
)
RETURNS TABLE (
    r_prod_id int,
    r_title text,
    r_actor text,
    r_review_id int,
    r_review_date date,
    r_stars smallint,
    r_customerid int,
    r_review_summary text,
    r_review_text text,
    r_totalhelp int
)
LANGUAGE plpgsql
AS \$\$
DECLARE
    vector_in tsquery;
BEGIN
    vector_in := to_tsquery('simple', replace(trim(title_in), ' ', ' & '));

    -- Two-tier limiting: search_depth limits products, batch_size limits final reviews
    RETURN QUERY
    SELECT
        p.PROD_ID,
        p.TITLE,
        p.ACTOR,
        r.REVIEW_ID,
        r.REVIEW_DATE,
        r.STARS,
        r.CUSTOMERID,
        r.REVIEW_SUMMARY,
        r.REVIEW_TEXT,
        r.total_helpfulness
    FROM (
        SELECT PROD_ID, TITLE, ACTOR
        FROM PRODUCTS$k
        WHERE to_tsvector('simple', TITLE) @@ vector_in
        LIMIT search_depth_in
    ) p
    INNER JOIN REVIEWS$k r ON p.PROD_ID = r.PROD_ID
    ORDER BY r.total_helpfulness DESC
    LIMIT batch_size_in;
END;
\$\$;

CREATE OR REPLACE FUNCTION addnewinventoryproduct$k(
    p_cat smallint,
    p_title varchar(50),
    p_actor varchar(50),
    p_price numeric(12,2),
    p_stock int,
    OUT v_new_id int
)
LANGUAGE plpgsql
AS \$\$
DECLARE
    v_max_id int;
    v_common_id int;
    v_membership smallint;
BEGIN
    SELECT COUNT(*) INTO v_max_id FROM products$k;

    IF v_max_id = 0 THEN
        v_common_id := 1;
    ELSE
        v_common_id := floor(1 + (random() * v_max_id))::int;
    END IF;

    v_membership := floor(random() * 4)::int;

    INSERT INTO products$k (category, title, actor, price, special, common_prod_id, membership_item)
    VALUES (p_cat, p_title, p_actor, p_price, 0, v_common_id, v_membership)
    RETURNING prod_id INTO v_new_id;

    INSERT INTO inventory$k (prod_id, quan_in_stock, sales)
    VALUES (v_new_id, p_stock, 0);

END;
\$\$;

CREATE OR REPLACE FUNCTION removereviewbyproduct$k(
    p_prod_id int,
    OUT deleted_review_id int
)
LANGUAGE plpgsql
AS \$\$
BEGIN
    deleted_review_id := 0;

    -- Find one random review for this specific product
    -- (simulates product-specific spam moderation)
    SELECT review_id INTO deleted_review_id
    FROM reviews$k
    WHERE prod_id = p_prod_id
    ORDER BY random()
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

    -- Delete it if found
    IF deleted_review_id > 0 THEN
        DELETE FROM reviews$k WHERE review_id = deleted_review_id;
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        deleted_review_id := 0;
END;
\$\$;

CREATE OR REPLACE FUNCTION removeunhelpfulreviews$k(
    p_batch_size int,
    OUT rows_deleted int
)
LANGUAGE plpgsql
AS \$\$
BEGIN
    -- Delete N least helpful reviews across all products
    -- (simulates global cleanup of low-quality reviews)
    DELETE FROM reviews$k
    WHERE review_id IN (
        SELECT review_id
        FROM reviews$k
        ORDER BY total_helpfulness ASC, review_id ASC
        LIMIT p_batch_size
        FOR UPDATE SKIP LOCKED
    );

    GET DIAGNOSTICS rows_deleted = ROW_COUNT;
END;
\$\$;

CREATE OR REPLACE FUNCTION removereviewsbydate$k(
    p_batch_size int,
    OUT rows_deleted int
)
LANGUAGE plpgsql
AS \$\$
BEGIN
    -- Delete N oldest reviews by REVIEW_DATE
    DELETE FROM reviews$k
    WHERE review_id IN (
        SELECT review_id
        FROM reviews$k
        ORDER BY review_date ASC
        LIMIT p_batch_size
        FOR UPDATE SKIP LOCKED
    );

    GET DIAGNOSTICS rows_deleted = ROW_COUNT;
END;
\$\$;

CREATE OR REPLACE FUNCTION adjustprices$k(
    p_prod_id int,
    OUT rows_updated int
)
LANGUAGE plpgsql
AS \$\$
DECLARE
    v_adjustment_factor numeric(4,3);
BEGIN
    -- Randomly adjust price by -10% to +10%
    v_adjustment_factor := 0.90 + (random() * 0.20);

    UPDATE products$k
    SET price = price * v_adjustment_factor
    WHERE prod_id = p_prod_id;

    GET DIAGNOSTICS rows_updated = ROW_COUNT;
END;
\$\$;

CREATE OR REPLACE FUNCTION bulkpriceadjustment$k(
    p_batch_size int,
    p_category int,
    OUT rows_updated int
)
LANGUAGE plpgsql
AS \$\$
DECLARE
    v_adjustment_factor numeric(5,4);
BEGIN
    -- Category-wide price adjustment (±25%)
    -- Simulates market events like 'Holiday DVDs 15% off'
    v_adjustment_factor := 0.75 + (random() * 0.50);

    WITH random_products AS (
        SELECT prod_id
        FROM products$k
        WHERE category = p_category
        ORDER BY random()
        LIMIT p_batch_size
    )
    UPDATE products$k
    SET price = FLOOR(price * v_adjustment_factor) + 0.77
    WHERE prod_id IN (SELECT prod_id FROM random_products);

    GET DIAGNOSTICS rows_updated = ROW_COUNT;
END;
\$\$;

CREATE OR REPLACE FUNCTION markspecials$k(
    p_prod_id int,
    OUT rows_updated int
)
LANGUAGE plpgsql
AS \$\$
BEGIN
    -- Toggle SPECIAL flag (0→1 or 1→0)
    -- Simulates rotating promotions/featured items
    UPDATE products$k
    SET special = CASE WHEN special = 1 THEN 0 ELSE 1 END
    WHERE prod_id = p_prod_id;

    GET DIAGNOSTICS rows_updated = ROW_COUNT;
END;
\$\$;

CREATE OR REPLACE FUNCTION expirememberships$k(
    p_batch_size int,
    OUT rows_deleted int
)
LANGUAGE plpgsql
AS \$\$
BEGIN
    -- Delete expired memberships (oldest first)
    -- Simulates cleanup of lapsed subscriptions
    DELETE FROM membership$k
    WHERE customerid IN (
        SELECT customerid
        FROM membership$k
        WHERE expiredate < CURRENT_TIMESTAMP
        ORDER BY expiredate ASC
        LIMIT p_batch_size
    );

    GET DIAGNOSTICS rows_deleted = ROW_COUNT;
END;
\$\$;

CREATE OR REPLACE FUNCTION purge_old_orders$k (
    IN p_batch_size int,
    OUT rows_deleted int
)
LANGUAGE plpgsql
AS \$\$
BEGIN
    -- Delete oldest orders (data retention policy, GDPR compliance)
    -- ORDERLINES cascade delete via foreign key ON DELETE CASCADE
    DELETE FROM orders$k
    WHERE orderid IN (
        SELECT orderid
        FROM orders$k
        ORDER BY orderdate ASC
        LIMIT p_batch_size
    );

    GET DIAGNOSTICS rows_deleted = ROW_COUNT;
END;
\$\$;

CREATE OR REPLACE FUNCTION upgrade_membership$k (
    IN p_batch_size int,
    OUT rows_upgraded int,
    OUT gold_threshold numeric,
    OUT silver_threshold numeric
)
LANGUAGE plpgsql
AS \$\$
DECLARE
    v_current_slice int;
BEGIN
    -- Time-based slicing: process 1% of customer base per minute
    -- Full coverage every 100 minutes, then repeats (stateless partitioning)
    v_current_slice := EXTRACT(MINUTE FROM CURRENT_TIMESTAMP)::int % 100;

    -- Calculate percentile thresholds for purchase counts in current slice
    -- Gold (3): >= 90th percentile, Silver (2): >= 75th percentile
    WITH slice_purchase_counts AS (
        SELECT COUNT(*) AS purchase_count
        FROM membership$k m
        INNER JOIN cust_hist$k ch ON m.customerid = ch.customerid
        WHERE m.customerid % 100 = v_current_slice
        GROUP BY m.customerid
    )
    SELECT
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY purchase_count),
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY purchase_count)
    INTO gold_threshold, silver_threshold
    FROM slice_purchase_counts;

    -- Fallback to hardcoded thresholds if no data in slice
    IF gold_threshold IS NULL THEN
        gold_threshold := 20;
        silver_threshold := 10;
    END IF;

    -- Count total purchases per customer, upgrade membership if thresholds met
    -- UPGRADE ONLY - never downgrade
    -- Reward: extend expiration by 180 days when upgrading
    WITH customer_purchases AS (
        SELECT
            ch.customerid,
            CASE
                WHEN COUNT(*) >= gold_threshold THEN 3  -- Gold (90th percentile)
                WHEN COUNT(*) >= silver_threshold THEN 2  -- Silver (75th percentile)
                ELSE m.membershiptype
            END AS new_level
        FROM cust_hist$k ch
        INNER JOIN membership$k m ON ch.customerid = m.customerid
        WHERE ch.customerid % 100 = v_current_slice
        GROUP BY ch.customerid, m.membershiptype
        HAVING CASE
            WHEN COUNT(*) >= gold_threshold THEN 3  -- Gold (90th percentile)
            WHEN COUNT(*) >= silver_threshold THEN 2  -- Silver (75th percentile)
            ELSE m.membershiptype
        END > m.membershiptype
        LIMIT p_batch_size
    )
    UPDATE membership$k m
    SET
        membershiptype = cp.new_level,
        expiredate = m.expiredate + INTERVAL '180 days'
    FROM customer_purchases cp
    WHERE m.customerid = cp.customerid;

    GET DIAGNOSTICS rows_upgraded = ROW_COUNT;
END;
\$\$;

CREATE OR REPLACE FUNCTION promotionalmembership$k(p_batch_size INT)
RETURNS INT AS \$\$
DECLARE
    v_customerid INT;
    v_old_tier INT;
    v_new_tier INT;
    v_old_expiredate DATE;
    v_new_expiredate DATE;
    v_operation_type VARCHAR(10);
    rows_affected INT := 0;
BEGIN
    -- Process random batch of customers
    FOR v_customerid IN
        SELECT customerid
        FROM customers$k
        ORDER BY RANDOM()
        LIMIT p_batch_size
    LOOP
        -- Check if customer has membership
        SELECT membershiptype, expiredate INTO v_old_tier, v_old_expiredate
        FROM membership$k
        WHERE customerid = v_customerid;

        IF NOT FOUND THEN
            -- INSERT: New tier 1 membership with 90-day expiration
            v_new_tier := 1;
            v_new_expiredate := CURRENT_DATE + INTERVAL '90 days';
            v_operation_type := 'INSERT';

            INSERT INTO membership$k (customerid, membershiptype, expiredate)
            VALUES (v_customerid, v_new_tier, v_new_expiredate);

            -- Audit trail
            INSERT INTO membership_promo_audit$k (
                customerid, old_tier, new_tier, old_expiredate, new_expiredate, operation_type
            ) VALUES (
                v_customerid, NULL, v_new_tier, NULL, v_new_expiredate, v_operation_type
            );

            rows_affected := rows_affected + 1;
        ELSE
            -- UPDATE: Sequential upgrade or tier 3 extension
            v_operation_type := 'UPDATE';

            IF v_old_tier = 1 THEN
                v_new_tier := 2;
                v_new_expiredate := v_old_expiredate;  -- Keep existing for upgrade
            ELSIF v_old_tier = 2 THEN
                v_new_tier := 3;
                v_new_expiredate := v_old_expiredate;  -- Keep existing for upgrade
            ELSE  -- tier 3
                v_new_tier := 3;
                v_new_expiredate := v_old_expiredate + INTERVAL '90 days';  -- Extend
            END IF;

            UPDATE membership$k
            SET membershiptype = v_new_tier,
                expiredate = v_new_expiredate
            WHERE customerid = v_customerid;

            -- Audit trail
            INSERT INTO membership_promo_audit$k (
                customerid, old_tier, new_tier, old_expiredate, new_expiredate, operation_type
            ) VALUES (
                v_customerid, v_old_tier, v_new_tier, v_old_expiredate, v_new_expiredate, v_operation_type
            );

            rows_affected := rows_affected + 1;
        END IF;
    END LOOP;

    RETURN rows_affected;
END;
\$\$
LANGUAGE plpgsql;

\n";
	close $OUT;
	sleep(1);
	print("psql -h $pgsql_target -U $SYSDBA -d $DBNAME < $pgsql_targetdir${pathsep}pgsql_ds_createsp.sql\n");
        system("psql -h $pgsql_target -U $SYSDBA -d $DBNAME < $pgsql_targetdir${pathsep}pgsql_ds_createsp.sql");
}
