# mysql_ds_perl_create_sp_multi.pl
# Script to create a ds3 stored procedures in MySQL with a provided number of copies - supporting multiple stores
# Syntax to run - perl mysqlds3_perl_create_sp_multi.pl <mysql_target> <number_of_stores>

use strict;
use warnings;

my $mysqltarget = $ARGV[0];
my $numberofstores = $ARGV[1];

my $pathsep;

#Need seperate target directory so that mulitple DB Targets can be loaded at the same time
my $mysql_targetdir;

$mysql_targetdir = $mysqltarget;

# remove any backslashes from string to be used for directory name
$mysql_targetdir =~ s/\\//;

system ("mkdir -p $mysql_targetdir");

# This section enables support for Linux and Windows - detecting the type of OS, and then using the proper commands
if ("$^O" eq "linux")
        {
        $pathsep = "/";
        }
else
        {
        $pathsep = "\\\\";
        };

foreach my $k (1 .. $numberofstores){
	open (my $OUT, ">$mysql_targetdir${pathsep}mysql_ds_createsp$k.sql") || die("Can't open $mysql_targetdir${pathsep}mysql_ds_createsp$k.sql");
	print $OUT  "USE DS3;

Delimiter $$
DROP PROCEDURE IF EXISTS DS3.NEW_CUSTOMER$k $$
CREATE PROCEDURE DS3.NEW_CUSTOMER$k ( IN firstname_in varchar(50), IN lastname_in varchar(50), IN address1_in varchar(50), IN address2_in varchar(50), IN city_in varchar(50), IN state_in varchar(50), IN zip_in int, IN country_in varchar(50), IN region_in int, IN email_in varchar(50), IN phone_in varchar(50), IN creditcardtype_in int, IN creditcard_in varchar(50), IN creditcardexpiration_in varchar(50), OUT username_out varchar(50), IN password_in varchar(50), IN age_in int, IN income_in int, IN gender_in varchar(1), OUT customerid_out INT)
  BEGIN
  DECLARE temp_username VARCHAR(50);
  SET temp_username = CONCAT('temp-', CONNECTION_ID(), '-', UNIX_TIMESTAMP(NOW(6)));

  INSERT INTO CUSTOMERS$k
    (
    FIRSTNAME,
    LASTNAME,
    EMAIL,
    PHONE,
    USERNAME,
    PASSWORD,
    ADDRESS1,
    ADDRESS2,
    CITY,
    STATE,
    ZIP,
    COUNTRY,
    REGION,
    CREDITCARDTYPE,
    CREDITCARD,
    CREDITCARDEXPIRATION,
    AGE,
    INCOME,
    GENDER
    )
  VALUES
    (
    firstname_in,
    lastname_in,
    email_in,
    phone_in,
    temp_username,
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
    ;
  select last_insert_id() into customerid_out;
  SET username_out = CONCAT('user', customerid_out);
  UPDATE CUSTOMERS$k SET USERNAME = username_out WHERE CUSTOMERID = customerid_out;
  END; $$


DROP PROCEDURE IF EXISTS DS3.NEW_MEMBER$k $$
CREATE PROCEDURE DS3.NEW_MEMBER$k ( IN customerid_in int, IN membershiplevel_in int, OUT customerid_out int)
BEGIN
  DECLARE rows_returned INT;
  SELECT COUNT(*) INTO rows_returned FROM MEMBERSHIP$k WHERE CUSTOMERID = customerid_in;
  IF rows_returned = 0
  THEN
    INSERT INTO MEMBERSHIP$k
      (
      CUSTOMERID,
      MEMBERSHIPTYPE,
      EXPIREDATE
      )
      VALUES
      (
      customerid_in,
      membershiplevel_in,
      DATE_ADD(NOW(), INTERVAL 1 YEAR)
      )
      ;
    SET customerid_out = customerid_in;
  ELSE
    SET customerid_out = 0;
  END IF;
  END; $$

DROP PROCEDURE IF EXISTS DS3.NEW_PROD_REVIEW$k $$
CREATE PROCEDURE DS3.NEW_PROD_REVIEW$k
  (
  IN  prod_id_in            int,
  IN  stars_in              int,
  IN  customerid_in         int,
  IN  review_summary_in     VARCHAR(50),
  IN  review_text_in        VARCHAR(1000),
  OUT review_id_out         int
 )
BEGIN
  DECLARE rows_retunred int;
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
      SYSDATE(),
      stars_in,
      customerid_in,
      review_summary_in,
      review_text_in
      )
      ;
    COMMIT;
    select last_insert_id() into review_id_out;
END; $$

DROP PROCEDURE IF EXISTS DS3.NEW_REVIEW_HELPFULNESS$k $$
CREATE PROCEDURE DS3.NEW_REVIEW_HELPFULNESS$k
  (
  IN  review_id_in         	int,
  IN  customerid_in         	int,
  IN  review_helpfulness_in 	int,
  OUT review_helpfulness_id_out int
 )
BEGIN
  DECLARE rows_retunred int;
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
      ON DUPLICATE KEY UPDATE
        HELPFULNESS = review_helpfulness_in;
    COMMIT;
    select last_insert_id() into review_helpfulness_id_out;
END; $$

DROP PROCEDURE IF EXISTS DS3.LOGIN$k $$
CREATE PROCEDURE DS3.LOGIN$k
  (
  IN username_in              VARCHAR(50),
  IN password_in              VARCHAR(50)
  )
BEGIN
  DECLARE login_customerid_out INT;

  SELECT CUSTOMERID into login_customerid_out FROM CUSTOMERS$k WHERE USERNAME=username_in AND PASSWORD=password_in;

  IF (FOUND_ROWS() > 0)
  THEN
      SELECT login_customerid_out;
      SELECT derivedtable1.TITLE, derivedtable1.ACTOR, PRODUCTS_1.TITLE AS RelatedPurchase
        FROM (SELECT PRODUCTS$k.TITLE, PRODUCTS$k.ACTOR, PRODUCTS$k.PROD_ID, PRODUCTS$k.COMMON_PROD_ID
          FROM DS3.CUST_HIST$k INNER JOIN
             PRODUCTS$k ON DS3.CUST_HIST$k.PROD_ID = PRODUCTS$k.PROD_ID
          WHERE (DS3.CUST_HIST$k.CUSTOMERID = login_customerid_out)
          ORDER BY DS3.CUST_HIST$k.ORDERID DESC
          LIMIT 10) AS derivedtable1 INNER JOIN
             PRODUCTS$k AS PRODUCTS_1 ON derivedtable1.COMMON_PROD_ID = PRODUCTS_1.PROD_ID;
  ELSE
        SELECT 0;
  END IF;

END; $$

DROP PROCEDURE IF EXISTS DS3.GET_MEMBERSHIP_STATUS$k $$
CREATE PROCEDURE DS3.GET_MEMBERSHIP_STATUS$k
  (
  IN customerid_in            INT
  )
BEGIN
  DECLARE membership_level_var INT;
  DECLARE is_expired_var INT;
  DECLARE rows_found INT;

  -- Get membership info
  SELECT MEMBERSHIPTYPE INTO membership_level_var FROM MEMBERSHIP$k WHERE CUSTOMERID = customerid_in;
  SET rows_found = FOUND_ROWS();

  -- If no membership found, return 0
  IF (rows_found = 0)
  THEN
    SELECT 0 AS membership_level, 0 AS is_expired;
  ELSE
    -- Check if expired
    IF EXISTS (SELECT 1 FROM MEMBERSHIP$k WHERE CUSTOMERID = customerid_in AND EXPIREDATE < NOW())
    THEN
      SET is_expired_var = 1;
    ELSE
      SET is_expired_var = 0;
    END IF;

    SELECT membership_level_var AS membership_level, is_expired_var AS is_expired;
  END IF;

END; $$

DROP PROCEDURE IF EXISTS DS3.RENEW_MEMBERSHIP$k $$
CREATE PROCEDURE DS3.RENEW_MEMBERSHIP$k
  (
  IN customerid_in            INT
  )
BEGIN
  UPDATE MEMBERSHIP$k
  SET EXPIREDATE = DATE_ADD(NOW(), INTERVAL 1 YEAR)
  WHERE CUSTOMERID = customerid_in;

  SELECT ROW_COUNT() AS rows_affected;

END; $$

DROP PROCEDURE IF EXISTS DS3.PURCHASE$k $$
CREATE PROCEDURE DS3.PURCHASE$k
  (
  IN customerid_in            INT,
  IN number_items             INT,
  IN netamount_in             DECIMAL(10,2),
  IN taxamount_in             DECIMAL(10,2),
  IN totalamount_in           DECIMAL(10,2),
  IN prod_id_in0              INT,    IN qty_in0     INT,
  IN prod_id_in1              INT,    IN qty_in1     INT,
  IN prod_id_in2              INT,    IN qty_in2     INT,
  IN prod_id_in3              INT,    IN qty_in3     INT,
  IN prod_id_in4              INT,    IN qty_in4     INT,
  IN prod_id_in5              INT,    IN qty_in5     INT,
  IN prod_id_in6              INT,    IN qty_in6     INT,
  IN prod_id_in7              INT,    IN qty_in7     INT,
  IN prod_id_in8              INT,    IN qty_in8     INT,
  IN prod_id_in9              INT,    IN qty_in9     INT,
  OUT neworderid_out          INT
  )
proc_label:BEGIN

   DECLARE date_in        DATE;
   DECLARE item_id        INTEGER;
   DECLARE cur_quan       INTEGER;
   DECLARE new_quan       INTEGER;
   DECLARE cur_sales      INTEGER;
   DECLARE new_sales      INTEGER;
   DECLARE prod_id_in     INTEGER;
   DECLARE qty_in         INTEGER;

   START TRANSACTION;

   SET date_in = NOW();

   -- CREATE NEW ENTRY IN ORDERS TABLE
    INSERT INTO DS3.ORDERS$k
      (
      ORDERDATE,
      CUSTOMERID,
      NETAMOUNT,
      TAX,
      TOTALAMOUNT
      )
    VALUES
      (
      date_in,
      customerid_in,
      netamount_in,
      taxamount_in,
      totalamount_in
      )
      ;

    SET neworderid_out = LAST_INSERT_ID();

    -- ADD LINE ITEMS TO ORDERLINES$k
    SET item_id = 0;
    WHILE item_id < number_items DO

        SET prod_id_in = CASE item_id
                WHEN 0 then prod_id_in0
                WHEN 1 then prod_id_in1
                WHEN 2 then prod_id_in2
                WHEN 3 then prod_id_in3
                WHEN 4 then prod_id_in4
                WHEN 5 then prod_id_in5
                WHEN 6 then prod_id_in6
                WHEN 7 then prod_id_in7
                WHEN 8 then prod_id_in8
                WHEN 9 then prod_id_in9
        END;

        SET qty_in = CASE item_id
                WHEN 0 then qty_in0
                WHEN 1 then qty_in1
                WHEN 2 then qty_in2
                WHEN 3 then qty_in3
                WHEN 4 then qty_in4
                WHEN 5 then qty_in5
                WHEN 6 then qty_in6
                WHEN 7 then qty_in7
                WHEN 8 then qty_in8
                WHEN 9 then qty_in9
        END;

        INSERT INTO ORDERLINES$k
        (
          ORDERLINEID,
          ORDERID,
          PROD_ID,
          QUANTITY,
          ORDERDATE
        )
        VALUES
        (
          item_id,
          neworderid_out,
          prod_id_in,
          qty_in,
          date_in
        )
        ;

      -- Check and update quantity in stock
      SELECT QUAN_IN_STOCK, SALES into cur_quan, cur_sales FROM DS3.INVENTORY$k WHERE PROD_ID=prod_id_in;

      SET new_quan = cur_quan - qty_in;
      SET new_sales = cur_sales + qty_in;

      IF new_quan < 0 THEN
        ROLLBACK;
        SET neworderid_out = 0;
        LEAVE proc_label;
      ELSE
        UPDATE DS3.INVENTORY$k SET QUAN_IN_STOCK = new_quan, SALES= new_sales WHERE PROD_ID=prod_id_in;

        INSERT INTO DS3.CUST_HIST$k
          (
          CUSTOMERID,
          ORDERID,
          PROD_ID
          )
        VALUES
          (
          customerid_in,
          neworderid_out,
          prod_id_in
          );
      END IF;

      SET item_id = item_id + 1;

    END WHILE;

    COMMIT;
END; $$

DROP PROCEDURE IF EXISTS DS3.BROWSE_BY_TITLE$k $$

CREATE PROCEDURE DS3.BROWSE_BY_TITLE$k
  (
  IN batch_size_in            INT,
  IN title_in                 VARCHAR(50)
  )
BEGIN
        select * from PRODUCTS$k where MATCH (TITLE) AGAINST (title_in IN BOOLEAN MODE) LIMIT batch_size_in;
END; $$

DROP PROCEDURE IF EXISTS DS3.BROWSE_BY_ACTOR$k $$

CREATE PROCEDURE DS3.BROWSE_BY_ACTOR$k
  (
  IN batch_size_in            INT,
  IN actor_in                 VARCHAR(50)
  )
BEGIN
        select * from PRODUCTS$k where MATCH (ACTOR) AGAINST (actor_in IN BOOLEAN MODE) LIMIT batch_size_in;
END; $$

DROP PROCEDURE IF EXISTS DS3.BROWSE_BY_CATEGORY$k $$
CREATE PROCEDURE DS3.BROWSE_BY_CATEGORY$k
  (
  IN batch_size_in            INT,
  IN category_in              INT,
  in special_in               INT
  )
BEGIN
        select * from PRODUCTS$k WHERE CATEGORY=category_in and SPECIAL=special_in limit batch_size_in;
END; $$

DROP PROCEDURE IF EXISTS DS3.BROWSE_BY_MEMBERSHIP$k $$
CREATE PROCEDURE DS3.BROWSE_BY_MEMBERSHIP$k
  (
  IN batch_size_in            INT,
  IN membershiptype_in        INT
  )
BEGIN
  DECLARE random_category INT;

  -- Select random category (1-16)
  SET random_category = FLOOR(RAND() * 16) + 1;

  -- Pseudo-random distribution for variety across different browse operations
  -- Category filter reduces sort cost, time-based ordering provides variety
  SELECT *
  FROM PRODUCTS$k
  WHERE MEMBERSHIP_ITEM = membershiptype_in
    AND CATEGORY = random_category
  ORDER BY (PROD_ID + batch_size_in + membershiptype_in + SECOND(NOW())) % 997
  LIMIT batch_size_in;
END; $$

CREATE OR REPLACE PROCEDURE DS3.BROWSE_BY_VECTOR$k (
    IN p_batch_size_in INT,
    IN p_vector_text TEXT -- Pass the vector as a JSON string
)
BEGIN
    SELECT
        PROD_ID,
        CATEGORY,
        TITLE,
        ACTOR,
        PRICE,
        SPECIAL,
        COMMON_PROD_ID,
        -- Calculate distance (automatically uses index if created)
        VEC_DISTANCE(v_embedding, VEC_FromText(p_vector_text)) AS distance
    FROM PRODUCTS$k
    ORDER BY distance ASC
    LIMIT p_batch_size_in;
END; $$

DROP PROCEDURE IF EXISTS DS3.GET_PROD_REVIEWS_BY_TITLE$k $$
CREATE PROCEDURE DS3.GET_PROD_REVIEWS_BY_TITLE$k
  (
  IN batch_size_in            INT,
  IN title_in                 VARCHAR(50),
  IN search_depth_in          INT
  )
BEGIN

  IF search_depth_in = '' || search_depth_in = 0
  THEN
    SET search_depth_in = 500;
  END IF;

    SELECT * FROM (
        SELECT
            P.prod_id,
            P.title,
            P.actor,
            R.review_id,
            R.review_date,
            R.stars,
            R.customerid,
            R.review_summary,
            R.review_text,
            R.total_helpfulness AS totalhelp
        FROM DS3.PRODUCTS$k P
        INNER JOIN DS3.REVIEWS$k R ON P.prod_id = R.prod_id
        WHERE MATCH (P.title) AGAINST (title_in IN BOOLEAN MODE)
        LIMIT search_depth_in
    ) AS T1
    ORDER BY totalhelp DESC
    LIMIT batch_size_in;

END; $$

DROP PROCEDURE IF EXISTS DS3.GET_PROD_REVIEWS_BY_ACTOR$k $$
CREATE PROCEDURE DS3.GET_PROD_REVIEWS_BY_ACTOR$k
  (
  IN batch_size_in            INT,
  IN actor_in                 VARCHAR(50),
  IN search_depth_in          INT
  )
BEGIN

  IF search_depth_in = '' || search_depth_in = 0
  THEN
    SET search_depth_in = 500;
  END IF;

    SELECT * FROM (
        SELECT
            P.prod_id,
            P.title,
            P.actor,
            R.review_id,
            R.review_date,
            R.stars,
            R.customerid,
            R.review_summary,
            R.review_text,
            R.total_helpfulness AS totalhelp
        FROM DS3.PRODUCTS$k P
        INNER JOIN DS3.REVIEWS$k R ON P.prod_id = R.prod_id
        WHERE MATCH(P.actor) AGAINST(actor_in IN BOOLEAN MODE)
        LIMIT search_depth_in
    ) AS T1
    ORDER BY totalhelp DESC
    LIMIT batch_size_in;

END; $$

DROP PROCEDURE IF EXISTS DS3.GET_PROD_REVIEWS$k $$
CREATE PROCEDURE DS3.GET_PROD_REVIEWS$k
  (
  IN batch_size_in        INT,
  IN prod_in              INT
  )
BEGIN

SELECT review_id, prod_id, review_date, stars, customerid, review_summary, review_text, total_helpfulness
FROM REVIEWS$k
WHERE prod_id = prod_in
ORDER BY total_helpfulness DESC
LIMIT batch_size_in;

END; $$

DROP PROCEDURE IF EXISTS DS3.GET_PROD_REVIEWS_BY_STARS$k $$
CREATE PROCEDURE DS3.GET_PROD_REVIEWS_BY_STARS$k
  (
  IN batch_size_in        INT,
  IN stars_in             INT,
  IN prod_in              INT
  )
BEGIN

SELECT review_id, prod_id, review_date, stars, customerid, review_summary, review_text, total_helpfulness
FROM REVIEWS$k
WHERE prod_id = prod_in AND STARS = stars_in
ORDER BY total_helpfulness DESC
LIMIT batch_size_in;

END; $$

DROP PROCEDURE IF EXISTS DS3.GET_PROD_REVIEWS_BY_DATE$k $$
CREATE PROCEDURE DS3.GET_PROD_REVIEWS_BY_DATE$k
  (
  IN batch_size_in        INT,
  IN prod_in              INT
  )
BEGIN

SELECT review_id, prod_id, review_date, stars, customerid, review_summary, review_text, total_helpfulness
FROM REVIEWS$k
WHERE prod_id = prod_in
ORDER BY REVIEW_DATE DESC
LIMIT batch_size_in;

END; $$

DELIMITER $$

DROP PROCEDURE IF EXISTS DS3.AddNewInventoryProduct$k $$
CREATE PROCEDURE DS3.AddNewInventoryProduct$k
(
    IN p_cat TINYINT,
    IN p_title VARCHAR(50),
    IN p_actor VARCHAR(50),
    IN p_price NUMERIC(12,2),
    IN p_stock INT
)
BEGIN
    DECLARE v_new_id INT;
    DECLARE v_max_id INT;
    DECLARE v_common_id INT;
    DECLARE v_membership TINYINT;

    SELECT COUNT(*) INTO v_max_id FROM PRODUCTS$k;

    IF v_max_id = 0 THEN
        SET v_common_id = 1;
    ELSE
        SET v_common_id = FLOOR(1 + (RAND() * v_max_id));
    END IF;

    SET v_membership = FLOOR(RAND() * 4);

    START TRANSACTION;

    INSERT INTO PRODUCTS$k (CATEGORY, TITLE, ACTOR, PRICE, SPECIAL, COMMON_PROD_ID, MEMBERSHIP_ITEM)
    VALUES (p_cat, p_title, p_actor, p_price, 0, v_common_id, v_membership);

    SET v_new_id = LAST_INSERT_ID();

    INSERT INTO INVENTORY$k (PROD_ID, QUAN_IN_STOCK, SALES)
    VALUES (v_new_id, p_stock, 0);

    COMMIT;

    SELECT v_new_id AS generated_id;
END $$

DROP PROCEDURE IF EXISTS DS3.RemoveReviewByProduct$k $$
CREATE PROCEDURE DS3.RemoveReviewByProduct$k
(
    IN p_prod_id INT
)
BEGIN
    DECLARE v_review_id INT DEFAULT 0;

    -- Find one random review for this specific product
    -- (simulates product-specific spam moderation)
    SELECT REVIEW_ID INTO v_review_id
    FROM REVIEWS$k
    WHERE PROD_ID = p_prod_id
    ORDER BY RAND()
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

    -- Delete it if found
    IF v_review_id > 0 THEN
        DELETE FROM REVIEWS$k WHERE REVIEW_ID = v_review_id;
    END IF;

    SELECT v_review_id AS deleted_review_id;
END $$

DROP PROCEDURE IF EXISTS DS3.RemoveUnhelpfulReviews$k $$
CREATE PROCEDURE DS3.RemoveUnhelpfulReviews$k
(
    IN p_batch_size INT
)
BEGIN
    -- Delete N least helpful reviews across all products
    -- (simulates global cleanup of low-quality reviews)
    DELETE r FROM REVIEWS$k r
    INNER JOIN (
        SELECT REVIEW_ID
        FROM REVIEWS$k
        ORDER BY TOTAL_HELPFULNESS ASC, REVIEW_ID ASC
        LIMIT p_batch_size
        FOR UPDATE SKIP LOCKED
    ) AS to_delete ON r.REVIEW_ID = to_delete.REVIEW_ID;
    SELECT ROW_COUNT() AS rows_affected;
END $$

DROP PROCEDURE IF EXISTS DS3.RemoveReviewsByDate$k $$
CREATE PROCEDURE DS3.RemoveReviewsByDate$k
(
    IN p_batch_size INT
)
BEGIN
    -- Delete N oldest reviews by REVIEW_DATE
    DELETE r FROM REVIEWS$k r
    INNER JOIN (
        SELECT REVIEW_ID
        FROM REVIEWS$k
        ORDER BY REVIEW_DATE ASC
        LIMIT p_batch_size
        FOR UPDATE SKIP LOCKED
    ) AS to_delete ON r.REVIEW_ID = to_delete.REVIEW_ID;
    SELECT ROW_COUNT() AS rows_affected;
END $$

DROP PROCEDURE IF EXISTS DS3.AdjustPrices$k $$
CREATE PROCEDURE DS3.AdjustPrices$k
(
    IN p_prod_id INT
)
BEGIN
    DECLARE v_adjustment_factor DECIMAL(4,3);

    -- Randomly adjust price by -10% to +10%
    SET v_adjustment_factor = 0.90 + (RAND() * 0.20);

    UPDATE PRODUCTS$k
    SET PRICE = PRICE * v_adjustment_factor
    WHERE PROD_ID = p_prod_id;
    SELECT ROW_COUNT() AS rows_affected;
END $$

DROP PROCEDURE IF EXISTS DS3.BulkPriceAdjustment$k $$
CREATE PROCEDURE DS3.BulkPriceAdjustment$k
(
    IN p_batch_size INT,
    IN p_category INT
)
BEGIN
    DECLARE v_adjustment_factor DECIMAL(5,4);

    -- Generate random adjustment factor (0.75 to 1.25, ±25%)
    SET v_adjustment_factor = 0.75 + (RAND() * 0.50);

    -- Update batch_size random products in selected category
    -- Use JOIN instead of IN to avoid MariaDB LIMIT restriction
    UPDATE PRODUCTS$k p
    INNER JOIN (
        SELECT PROD_ID
        FROM PRODUCTS$k
        WHERE CATEGORY = p_category
        ORDER BY RAND()
        LIMIT p_batch_size
    ) random_products ON p.PROD_ID = random_products.PROD_ID
    SET p.PRICE = FLOOR(p.PRICE * v_adjustment_factor) + 0.77;

    SELECT ROW_COUNT() AS rows_affected;
END $$

DROP PROCEDURE IF EXISTS DS3.MarkSpecials$k $$
CREATE PROCEDURE DS3.MarkSpecials$k
(
    IN p_prod_id INT
)
BEGIN
    -- Toggle SPECIAL flag (0→1 or 1→0)
    -- Simulates rotating promotions/featured items
    UPDATE PRODUCTS$k
    SET SPECIAL = CASE WHEN SPECIAL = 1 THEN 0 ELSE 1 END
    WHERE PROD_ID = p_prod_id;
    SELECT ROW_COUNT() AS rows_affected;
END $$

DROP PROCEDURE IF EXISTS DS3.ExpireMemberships$k $$
CREATE PROCEDURE DS3.ExpireMemberships$k
(
    IN p_batch_size INT
)
BEGIN
    -- Delete expired memberships (oldest first)
    -- Simulates cleanup of lapsed subscriptions
    -- Uses JOIN pattern for MariaDB LIMIT compatibility
    DELETE m FROM MEMBERSHIP$k m
    INNER JOIN (
        SELECT CUSTOMERID
        FROM MEMBERSHIP$k
        WHERE EXPIREDATE < NOW()
        ORDER BY EXPIREDATE ASC
        LIMIT p_batch_size
        FOR UPDATE SKIP LOCKED
    ) AS to_delete ON m.CUSTOMERID = to_delete.CUSTOMERID;
    SELECT ROW_COUNT() AS rows_affected;
END $$

DROP PROCEDURE IF EXISTS DS3.PurgeOldOrders$k $$
CREATE PROCEDURE DS3.PurgeOldOrders$k
(
    IN p_batch_size INT
)
BEGIN
    -- Delete oldest orders (data retention policy, GDPR compliance)
    -- ORDERLINES cascade delete via foreign key ON DELETE CASCADE
    -- Uses JOIN pattern for MariaDB LIMIT compatibility
    DELETE o FROM ORDERS$k o
    INNER JOIN (
        SELECT ORDERID
        FROM ORDERS$k
        ORDER BY ORDERDATE ASC
        LIMIT p_batch_size
        FOR UPDATE SKIP LOCKED
    ) AS to_delete ON o.ORDERID = to_delete.ORDERID;
    SELECT ROW_COUNT() AS rows_affected;
END $$

DROP PROCEDURE IF EXISTS DS3.UpgradeMembership$k $$
CREATE PROCEDURE DS3.UpgradeMembership$k
(
    IN p_batch_size INT
)
BEGIN
    -- Time-based slicing: process 1% of customer base per minute
    -- Full coverage every 100 minutes, then repeats (stateless partitioning)
    DECLARE v_current_slice INT DEFAULT MOD(MINUTE(NOW()), 100);
    DECLARE v_gold_threshold DECIMAL(10,2);
    DECLARE v_silver_threshold DECIMAL(10,2);

    -- Calculate percentile thresholds for purchase counts in current slice
    -- Gold (3): >= 90th percentile, Silver (2): >= 75th percentile
    WITH SlicePurchaseCounts AS (
        SELECT COUNT(*) AS purchase_count
        FROM MEMBERSHIP$k m
        INNER JOIN CUST_HIST$k ch ON m.CUSTOMERID = ch.CUSTOMERID
        WHERE MOD(m.CUSTOMERID, 100) = v_current_slice
        GROUP BY m.CUSTOMERID
    ),
    PercentileCalc AS (
        SELECT
            purchase_count,
            PERCENT_RANK() OVER (ORDER BY purchase_count) AS percentile
        FROM SlicePurchaseCounts
    )
    SELECT
        MIN(CASE WHEN percentile >= 0.90 THEN purchase_count END),
        MIN(CASE WHEN percentile >= 0.75 THEN purchase_count END)
    INTO v_gold_threshold, v_silver_threshold
    FROM PercentileCalc;

    -- Fallback to hardcoded thresholds if no data in slice
    IF v_gold_threshold IS NULL THEN
        SET v_gold_threshold = 20;
        SET v_silver_threshold = 10;
    END IF;

    -- Count total purchases per customer, upgrade membership if thresholds met
    -- UPGRADE ONLY - never downgrade
    -- Reward: extend expiration by 180 days when upgrading
    UPDATE MEMBERSHIP$k m
    INNER JOIN (
        SELECT
            ch.CUSTOMERID,
            CASE
                WHEN COUNT(*) >= v_gold_threshold THEN 3  -- Gold (90th percentile)
                WHEN COUNT(*) >= v_silver_threshold THEN 2  -- Silver (75th percentile)
                ELSE 1
            END AS new_level
        FROM CUST_HIST$k ch
        INNER JOIN MEMBERSHIP$k m2 ON ch.CUSTOMERID = m2.CUSTOMERID
        WHERE MOD(ch.CUSTOMERID, 100) = v_current_slice
        GROUP BY ch.CUSTOMERID, m2.MEMBERSHIPTYPE
        HAVING CASE
            WHEN COUNT(*) >= v_gold_threshold THEN 3  -- Gold (90th percentile)
            WHEN COUNT(*) >= v_silver_threshold THEN 2  -- Silver (75th percentile)
            ELSE 1
        END > m2.MEMBERSHIPTYPE
        LIMIT p_batch_size
    ) AS upgrades ON m.CUSTOMERID = upgrades.CUSTOMERID
    SET
        m.MEMBERSHIPTYPE = upgrades.new_level,
        m.EXPIREDATE = CASE
            WHEN m.EXPIREDATE > NOW() THEN DATE_ADD(m.EXPIREDATE, INTERVAL 180 DAY)  -- Active: extend from current
            ELSE DATE_ADD(NOW(), INTERVAL 180 DAY)  -- Expired: reactivate from today
        END;

    SELECT ROW_COUNT() AS rows_affected, v_gold_threshold AS gold_threshold, v_silver_threshold AS silver_threshold;
END $$

DROP PROCEDURE IF EXISTS DS3.PromotionalMembership$k $$
CREATE PROCEDURE DS3.PromotionalMembership$k
(
    IN p_batch_size INT,
    OUT p_rows_affected INT
)
BEGIN
    DECLARE v_insert_count INT DEFAULT 0;
    DECLARE v_update_count INT DEFAULT 0;
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_customerid INT;
    DECLARE v_old_tier INT;
    DECLARE v_new_tier INT;
    DECLARE v_old_expiredate DATE;
    DECLARE v_new_expiredate DATE;

    -- Cursor to select random batch of customers
    DECLARE customer_cursor CURSOR FOR
        SELECT CUSTOMERID
        FROM CUSTOMERS$k
        ORDER BY RAND()
        LIMIT p_batch_size;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- Create temporary table to track operations
    CREATE TEMPORARY TABLE IF NOT EXISTS temp_promo_ops (
        customerid INT,
        old_tier INT,
        new_tier INT,
        old_expiredate DATE,
        new_expiredate DATE,
        operation_type VARCHAR(10)
    );

    TRUNCATE TABLE temp_promo_ops;

    OPEN customer_cursor;

    read_loop: LOOP
        FETCH customer_cursor INTO v_customerid;
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- Reset variables
        SET v_old_tier = NULL;
        SET v_old_expiredate = NULL;

        -- Check if customer has membership (EXISTS avoids NOT FOUND)
        IF EXISTS (SELECT 1 FROM MEMBERSHIP$k WHERE CUSTOMERID = v_customerid) THEN
            SELECT MEMBERSHIPTYPE, EXPIREDATE
            INTO v_old_tier, v_old_expiredate
            FROM MEMBERSHIP$k
            WHERE CUSTOMERID = v_customerid;
        END IF;

        IF v_old_tier IS NULL THEN
            -- INSERT: New tier 1 membership with 90-day expiration
            INSERT INTO MEMBERSHIP$k (CUSTOMERID, MEMBERSHIPTYPE, EXPIREDATE)
            VALUES (v_customerid, 1, DATE_ADD(NOW(), INTERVAL 90 DAY));

            SET v_insert_count = v_insert_count + 1;

            INSERT INTO temp_promo_ops VALUES (
                v_customerid,
                NULL,
                1,
                NULL,
                DATE_ADD(NOW(), INTERVAL 90 DAY),
                'INSERT'
            );
        ELSE
            -- UPDATE: Sequential upgrade or tier 3 extension
            SET v_new_tier = CASE
                WHEN v_old_tier = 1 THEN 2
                WHEN v_old_tier = 2 THEN 3
                ELSE 3  -- Already tier 3
            END;

            SET v_new_expiredate = CASE
                WHEN v_old_tier = 3 THEN DATE_ADD(v_old_expiredate, INTERVAL 90 DAY)
                ELSE DATE_ADD(NOW(), INTERVAL 90 DAY)  -- Reactivate for tier upgrades
            END;

            UPDATE MEMBERSHIP$k
            SET MEMBERSHIPTYPE = v_new_tier,
                EXPIREDATE = v_new_expiredate
            WHERE CUSTOMERID = v_customerid;

            SET v_update_count = v_update_count + 1;

            INSERT INTO temp_promo_ops VALUES (
                v_customerid,
                v_old_tier,
                v_new_tier,
                v_old_expiredate,
                v_new_expiredate,
                'UPDATE'
            );
        END IF;

        -- Reset for next iteration
        SET v_old_tier = NULL;
        SET v_old_expiredate = NULL;
    END LOOP;

    CLOSE customer_cursor;

    -- Write audit trail
    INSERT INTO MEMBERSHIP_PROMO_AUDIT$k (
        CUSTOMERID,
        OLD_TIER,
        NEW_TIER,
        OLD_EXPIREDATE,
        NEW_EXPIREDATE,
        OPERATION_TYPE,
        OPERATION_TIMESTAMP
    )
    SELECT
        customerid,
        old_tier,
        new_tier,
        old_expiredate,
        new_expiredate,
        operation_type,
        NOW()
    FROM temp_promo_ops;

    DROP TEMPORARY TABLE temp_promo_ops;

    SET p_rows_affected = v_insert_count + v_update_count;
END $$

DROP PROCEDURE IF EXISTS DS3.GetMembershipAnalytics$k $$
CREATE PROCEDURE DS3.GetMembershipAnalytics$k()
BEGIN
  -- Use READ UNCOMMITTED to avoid locking MEMBERSHIP table (analytics is read-only, dirty reads acceptable)
  SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  WITH CustomerOrders AS (
    SELECT
      CUSTOMERID,
      COUNT(*) AS order_count,
      SUM(TOTALAMOUNT) AS total_revenue
    FROM ORDERS$k
    GROUP BY CUSTOMERID
  )
  SELECT
    m.MEMBERSHIPTYPE AS membership_tier,
    CAST(COUNT(DISTINCT CASE
      WHEN m.MEMBERSHIPTYPE IS NULL THEN c.CUSTOMERID  -- non-members, count all
      WHEN m.EXPIREDATE >= NOW() THEN c.CUSTOMERID  -- active members only
      ELSE NULL  -- expired members, don't count
    END) AS UNSIGNED) AS active_member_count,
    CAST(COUNT(DISTINCT CASE
      WHEN m.MEMBERSHIPTYPE IS NOT NULL AND m.EXPIREDATE < NOW() THEN c.CUSTOMERID
      ELSE NULL
    END) AS UNSIGNED) AS expired_member_count,
    CAST(IFNULL(SUM(co.order_count), 0) AS UNSIGNED) AS total_orders,
    ROUND(IFNULL(SUM(co.total_revenue), 0), 2) AS total_revenue
  FROM CUSTOMERS$k c
  LEFT JOIN MEMBERSHIP$k m ON c.CUSTOMERID = m.CUSTOMERID
  LEFT JOIN CustomerOrders co ON c.CUSTOMERID = co.CUSTOMERID
  GROUP BY m.MEMBERSHIPTYPE
  ORDER BY CASE WHEN m.MEMBERSHIPTYPE IS NULL THEN -1 ELSE m.MEMBERSHIPTYPE END DESC;
END $$

DROP PROCEDURE IF EXISTS DS3.GetNewCustomerAnalytics$k $$
CREATE PROCEDURE DS3.GetNewCustomerAnalytics$k(
  IN customers_baseline BIGINT UNSIGNED
)
BEGIN
  -- Use READ UNCOMMITTED to avoid locking CUSTOMERS table (analytics is read-only, dirty reads acceptable)
  SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  WITH NewCustomerStats AS (
    SELECT
      COUNT(DISTINCT c.CUSTOMERID) AS Created,
      COUNT(DISTINCT CASE WHEN o.OrderCount >= 2 THEN c.CUSTOMERID END) AS TwoPlus,
      COUNT(DISTINCT CASE WHEN o.OrderCount > 2 THEN c.CUSTOMERID END) AS ThreePlus,
      IFNULL(SUM(o.OrderCount), 0) AS TotalOrders
    FROM CUSTOMERS$k c
    LEFT JOIN (
      SELECT CUSTOMERID,
             COUNT(*) AS OrderCount
      FROM ORDERS$k
      WHERE CUSTOMERID > customers_baseline
      GROUP BY CUSTOMERID
    ) o ON c.CUSTOMERID = o.CUSTOMERID
    WHERE c.CUSTOMERID > customers_baseline
  )
  SELECT Created, TwoPlus, ThreePlus, TotalOrders
  FROM NewCustomerStats;
END $$

DELIMITER ;
DROP PROCEDURE IF EXISTS DS3.GetReviewAnalytics$k;
DELIMITER $$
CREATE PROCEDURE DS3.GetReviewAnalytics$k(
  IN reviewid_baseline BIGINT UNSIGNED
)
BEGIN
  SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  WITH ReviewStats AS (
    SELECT
      STARS,
      COUNT(*) AS Reviews,
      SUM(CASE WHEN REVIEW_ID > reviewid_baseline THEN 1 ELSE 0 END) AS Added,
      IFNULL(AVG(TOTAL_HELPFULNESS), 0) AS AvgHelp,
      SUM(CASE WHEN TOTAL_HELPFULNESS >= 20 THEN 1 ELSE 0 END) AS HighHelp,
      SUM(CASE WHEN TOTAL_HELPFULNESS < 5 THEN 1 ELSE 0 END) AS LowHelp
    FROM REVIEWS$k
    GROUP BY STARS
  )
  SELECT
    STARS,
    Reviews,
    Added,
    CAST(AvgHelp AS DECIMAL(10,1)) AS AvgHelp,
    HighHelp,
    LowHelp
  FROM ReviewStats
  ORDER BY STARS DESC;
END $$

DELIMITER ;
DROP PROCEDURE IF EXISTS DS3.GetPricePointAnalytics$k;
DELIMITER $$
CREATE PROCEDURE DS3.GetPricePointAnalytics$k(
  IN baseline_product_count BIGINT UNSIGNED
)
BEGIN
  -- Result Set 1: Price point distribution
  SELECT
    CASE
      WHEN (CAST(PRICE * 100 AS SIGNED) % 100) = 99 THEN '.99'
      WHEN (CAST(PRICE * 100 AS SIGNED) % 100) = 77 THEN '.77'
      WHEN (CAST(PRICE * 100 AS SIGNED) % 100) = 1 THEN '.01'
      ELSE 'Other'
    END AS PriceEnding,
    COUNT(*) AS ProductCount
  FROM PRODUCTS$k
  GROUP BY
    CASE
      WHEN (CAST(PRICE * 100 AS SIGNED) % 100) = 99 THEN '.99'
      WHEN (CAST(PRICE * 100 AS SIGNED) % 100) = 77 THEN '.77'
      WHEN (CAST(PRICE * 100 AS SIGNED) % 100) = 1 THEN '.01'
      ELSE 'Other'
    END
  ORDER BY
    CASE
      WHEN (CAST(PRICE * 100 AS SIGNED) % 100) = 99 THEN 1
      WHEN (CAST(PRICE * 100 AS SIGNED) % 100) = 77 THEN 2
      WHEN (CAST(PRICE * 100 AS SIGNED) % 100) = 1 THEN 3
      ELSE 4
    END;

  -- Result Set 2: New products purchased count
  SELECT COUNT(DISTINCT PROD_ID) AS NewProductsPurchased
  FROM CUST_HIST$k
  WHERE PROD_ID > baseline_product_count;
END $$

DELIMITER ;
DROP PROCEDURE IF EXISTS DS3.GetInventoryAnalytics$k;
DELIMITER $$
CREATE PROCEDURE DS3.GetInventoryAnalytics$k()
BEGIN
  SELECT
    COUNT(CASE WHEN QUAN_IN_STOCK < 10 THEN 1 END) AS LowStockCount,
    COUNT(CASE WHEN QUAN_IN_STOCK > 100 THEN 1 END) AS HighStockCount,
    (SELECT COUNT(*) FROM REORDER$k) AS ReorderCount,
    AVG(CAST(QUAN_IN_STOCK AS DECIMAL(10,1))) AS AvgInventory,
    COUNT(CASE WHEN SALES = 0 THEN 1 END) AS DeadStock,
    COUNT(CASE WHEN SALES BETWEEN 1 AND 999 THEN 1 END) AS LowSales,
    COUNT(CASE WHEN SALES BETWEEN 1000 AND 1499 THEN 1 END) AS MedSales,
    COUNT(CASE WHEN SALES >= 1500 THEN 1 END) AS HighSales,
    COUNT(*) AS TotalProducts
  FROM INVENTORY$k;
END $$

\n";
  close $OUT;
  sleep(1);
  print ("mariadb -h $mysqltarget -u web --password=web < $mysql_targetdir${pathsep}mysql_ds_createsp$k.sql\n");
  system ("mariadb -h $mysqltarget -u web --password=web < $mysql_targetdir${pathsep}mysql_ds_createsp$k.sql");
  }
