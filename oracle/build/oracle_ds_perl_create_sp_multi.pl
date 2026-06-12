# oracleds3_perl_create_sp_multi.pl
# Script to create a ds3 stored procedures in oracle with a provided number of copies - supporting multiple stores
# Syntax to run - perl oracleds3_perl_create_sp_multi.pl <oracle_target> <number_of_stores>

use strict;
use warnings;

my $oracletarget = $ARGV [0];
my $numberofstores = $ARGV[1];

my $pathsep;
my $startcmd;

#Need seperate target directory so that mulitple DB Targets can be loaded at the same time
my $oracletargetdir;

$oracletargetdir = $oracletarget;

# remove any backslashes from string to be used for directory name
$oracletargetdir =~ s/\\//;

system ("mkdir -p $oracletargetdir");

# This section enables support for Linux and Windows - detecting the type of OS, and then using the proper commands
if ("$^O" eq "linux")
        {
        $pathsep = "/";
	$startcmd = "";
        }
else
        {
        $pathsep = "\\\\";
	$startcmd = "start";
        };

foreach my $k (1 .. $numberofstores){
	open (my $OUT, ">$oracletargetdir${pathsep}oracle_ds_createsp$k.sql") || die("Can't open oracle_ds_createsp$k.sql");
	print $OUT "CREATE OR REPLACE  PROCEDURE \"DS3\".\"NEW_CUSTOMER$k\"
  (
  firstname_in DS3.CUSTOMERS$k.FIRSTNAME%TYPE,
  lastname_in DS3.CUSTOMERS$k.LASTNAME%TYPE,
  address1_in DS3.CUSTOMERS$k.ADDRESS1%TYPE,
  address2_in DS3.CUSTOMERS$k.ADDRESS2%TYPE,
  city_in DS3.CUSTOMERS$k.CITY%TYPE,
  state_in DS3.CUSTOMERS$k.STATE%TYPE,
  zip_in DS3.CUSTOMERS$k.ZIP%TYPE,
  country_in DS3.CUSTOMERS$k.COUNTRY%TYPE,
  region_in DS3.CUSTOMERS$k.REGION%TYPE,
  email_in DS3.CUSTOMERS$k.EMAIL%TYPE,
  phone_in DS3.CUSTOMERS$k.PHONE%TYPE,
  creditcardtype_in DS3.CUSTOMERS$k.CREDITCARDTYPE%TYPE,
  creditcard_in DS3.CUSTOMERS$k.CREDITCARD%TYPE,
  creditcardexpiration_in DS3.CUSTOMERS$k.CREDITCARDEXPIRATION%TYPE,
  username_out OUT DS3.CUSTOMERS$k.USERNAME%TYPE,
  password_in DS3.CUSTOMERS$k.PASSWORD%TYPE,
  age_in DS3.CUSTOMERS$k.AGE%TYPE,
  income_in DS3.CUSTOMERS$k.INCOME%TYPE,
  gender_in DS3.CUSTOMERS$k.GENDER%TYPE,
  customerid_out OUT INTEGER
  )
  IS
  BEGIN
      SELECT CUSTOMERID_SEQ$k.NEXTVAL INTO customerid_out FROM DUAL;
      username_out := 'user' || customerid_out;

      INSERT INTO CUSTOMERS$k
        (
        CUSTOMERID,
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
        customerid_out,
        firstname_in,
        lastname_in,
        email_in,
        phone_in,
        username_out,
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
      COMMIT;

    END NEW_CUSTOMER$k;
/

CREATE OR REPLACE  PROCEDURE \"DS3\".\"NEW_MEMBER$k\"
  (
  customerid_in INTEGER,
  membershiplevel_in INTEGER,
  customerid_out OUT INTEGER
  )
  IS
  rows_returned INTEGER;
  BEGIN

    SELECT COUNT(*) INTO rows_returned FROM MEMBERSHIP$k WHERE CUSTOMERID = customerid_in;

    IF rows_returned = 0
    THEN
      INSERT INTO MEMBERSHIP$k
        (CUSTOMERID,
         MEMBERSHIPTYPE,
         EXPIREDATE
         )
      VALUES
        (
        customerid_in,
        membershiplevel_in,
        ADD_MONTHS(SYSDATE, 12)
        );
      customerid_out := customerid_in;
    ELSE
      customerid_out := 0;
    END IF;
    COMMIT;
    END NEW_MEMBER$k;
/




CREATE OR REPLACE PROCEDURE \"DS3\".\"NEW_PROD_REVIEW$k\"
  (
  prod_id_in 		IN DS3.REVIEWS$k.PROD_ID%TYPE,
  stars_in 		IN DS3.REVIEWS$k.STARS%TYPE,
  customerid_in 	IN DS3.REVIEWS$k.CUSTOMERID%TYPE,
  review_summary_in 	IN DS3.REVIEWS$k.REVIEW_SUMMARY%TYPE,
  review_text_in 	IN DS3.REVIEWS$k.REVIEW_TEXT%TYPE,
  review_id_out 	OUT INTEGER
 )
  IS
  rows_returned INTEGER;
  BEGIN

      SELECT REVIEWID_SEQ$k.NEXTVAL INTO review_id_out FROM DUAL;
      INSERT INTO REVIEWS$k
        (
        REVIEW_ID,
        PROD_ID,
        REVIEW_DATE,
        STARS,
        CUSTOMERID,
        REVIEW_SUMMARY,
        REVIEW_TEXT
        )
        VALUES
        (
        review_id_out,
        prod_id_in,
	SYSDATE,
        stars_in,
        customerid_in,
        review_summary_in,
        review_text_in
        )
        ;
      COMMIT;
END NEW_PROD_REVIEW$k; 
/

CREATE OR REPLACE PROCEDURE \"DS3\".\"NEW_REVIEW_HELPFULNESS$k\"
  (
  review_id_in          	IN DS3.REVIEWS_HELPFULNESS$k.REVIEW_ID%TYPE,
  customerid_in         	IN DS3.REVIEWS_HELPFULNESS$k.CUSTOMERID%TYPE,
  review_helpfulness_in 	IN DS3.REVIEWS_HELPFULNESS$k.HELPFULNESS%TYPE,
  review_helpfulness_id_out     OUT INTEGER
 )
  IS
  rows_returned INTEGER;
  v_new_id INTEGER;
  BEGIN
      -- Try MERGE (insert or update if exists)
      SELECT REVIEWHELPFULNESSID_SEQ$k.NEXTVAL INTO v_new_id FROM DUAL;

      MERGE INTO REVIEWS_HELPFULNESS$k target
      USING (SELECT review_id_in AS review_id,
                    customerid_in AS customerid,
                    review_helpfulness_in AS helpfulness,
                    v_new_id AS new_id
             FROM DUAL) source
      ON (target.REVIEW_ID = source.review_id AND target.CUSTOMERID = source.customerid)
      WHEN MATCHED THEN
        UPDATE SET target.HELPFULNESS = source.helpfulness
      WHEN NOT MATCHED THEN
        INSERT (REVIEW_HELPFULNESS_ID, REVIEW_ID, CUSTOMERID, HELPFULNESS)
        VALUES (source.new_id, source.review_id, source.customerid, source.helpfulness);

      -- Get the ID (either new or existing)
      SELECT REVIEW_HELPFULNESS_ID INTO review_helpfulness_id_out
      FROM REVIEWS_HELPFULNESS$k
      WHERE REVIEW_ID = review_id_in AND CUSTOMERID = customerid_in;

      COMMIT;
END NEW_REVIEW_HELPFULNESS$k;
/

CREATE OR REPLACE PROCEDURE \"DS3\".\"LOGIN$k\"
  (
  p_username_in  IN  VARCHAR2,
  p_password_in  IN  VARCHAR2,
  p_customerid   OUT INTEGER
  )
AS
  v_history_rc SYS_REFCURSOR;
BEGIN
  BEGIN
    SELECT CUSTOMERID INTO p_customerid
    FROM CUSTOMERS$k
    WHERE USERNAME = p_username_in AND PASSWORD = p_password_in;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_customerid := 0;
      RETURN;
  END;

  OPEN v_history_rc FOR
    SELECT p1.TITLE, p1.ACTOR, p2.TITLE AS RelatedTitle
    FROM cust_hist$k ch
    JOIN products$k p1 ON ch.prod_id = p1.prod_id
    LEFT JOIN products$k p2 ON p1.common_prod_id = p2.prod_id
    WHERE ch.customerid = p_customerid
    ORDER BY ch.orderid DESC
    FETCH FIRST 10 ROWS ONLY;

  DBMS_SQL.RETURN_RESULT(v_history_rc);

  END LOGIN$k;
/

CREATE OR REPLACE PROCEDURE \"DS3\".\"GET_MEMBERSHIP_STATUS$k\"
  (
  p_customerid_in     IN  INTEGER,
  p_membership_level  OUT INTEGER,
  p_is_expired        OUT INTEGER
  )
AS
  v_membershiptype INTEGER;
  v_expiredate DATE;
BEGIN
  -- Get membership info
  BEGIN
    SELECT MEMBERSHIPTYPE, EXPIREDATE
    INTO v_membershiptype, v_expiredate
    FROM MEMBERSHIP$k
    WHERE CUSTOMERID = p_customerid_in;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_membership_level := 0;
      p_is_expired := 0;
      RETURN;
  END;

  -- Check if expired
  p_membership_level := v_membershiptype;
  IF v_expiredate < SYSDATE THEN
    p_is_expired := 1;
  ELSE
    p_is_expired := 0;
  END IF;

END GET_MEMBERSHIP_STATUS$k;
/

CREATE OR REPLACE PROCEDURE \"DS3\".\"RENEW_MEMBERSHIP$k\"
  (
  p_customerid_in  IN  INTEGER,
  p_rows_affected  OUT INTEGER
  )
AS
BEGIN
  UPDATE MEMBERSHIP$k
  SET EXPIREDATE = ADD_MONTHS(SYSDATE, 12)
  WHERE CUSTOMERID = p_customerid_in;

  p_rows_affected := SQL%ROWCOUNT;
  COMMIT;

END RENEW_MEMBERSHIP$k;
/

CREATE OR REPLACE PROCEDURE \"DS3\".\"BROWSE_BY_CATEGORY$k\"
  (
  p_category_in  IN  INTEGER,
  p_batch_size   IN  INTEGER,
  p_special_in   IN  INTEGER
  )
AS
  v_cursor SYS_REFCURSOR;
BEGIN
  OPEN v_cursor FOR
    SELECT
        PROD_ID,
        CATEGORY,
        TITLE,
        ACTOR,
        PRICE,
        SPECIAL,
        COMMON_PROD_ID,
        MEMBERSHIP_ITEM
    FROM PRODUCTS$k
    WHERE CATEGORY = p_category_in
      AND SPECIAL = p_special_in
    FETCH NEXT p_batch_size ROWS ONLY;

  DBMS_SQL.RETURN_RESULT(v_cursor);
END;
/

CREATE OR REPLACE PROCEDURE \"DS3\".\"BROWSE_BY_CAT_FOR_MEMBERTY$k\"
  (
  batch_size   		IN INTEGER,
  found       		OUT INTEGER,
  category_in  		IN INTEGER,
  membershiptype_in 	IN INTEGER,
  prod_id_out  		OUT DS3_TYPES.N_TYPE,
  category_out 		OUT DS3_TYPES.N_TYPE,
  title_out    		OUT DS3_TYPES.ARRAY_TYPE,
  actor_out    		OUT DS3_TYPES.ARRAY_TYPE,
  price_out    		OUT DS3_TYPES.N_TYPE,
  special_out  		OUT DS3_TYPES.N_TYPE,
  common_prod_id_out  	OUT DS3_TYPES.N_TYPE,
  membership_item_out   OUT DS3_TYPES.N_TYPE
  )
  AS
  result_cv DS3_TYPES.DS3_CURSOR;
  i INTEGER;

  BEGIN

    IF NOT result_cv%ISOPEN THEN
      OPEN result_cv FOR
      SELECT * FROM PRODUCTS$k WHERE CATEGORY = category_in AND SPECIAL = 1 AND MEMBERSHIP_ITEM <= membershiptype_in;
    END IF;

    found := 0;
    FOR i IN 1..batch_size LOOP
      FETCH result_cv INTO prod_id_out(i), category_out(i), title_out(i), actor_out(i), price_out(i), special_out(i), common_prod_id_out(i), membership_item_out(i);
      IF result_cv%NOTFOUND THEN
        CLOSE result_cv;
        EXIT;
      ELSE
        found := found + 1;
      END IF;
    END LOOP;
  END BROWSE_BY_CAT_FOR_MEMBERTY$k;
/

CREATE OR REPLACE PROCEDURE \"DS3\".\"BROWSE_BY_MEMBERSHIP$k\"
  (
  p_batch_size        IN  INTEGER,
  p_membershiptype_in IN  INTEGER
  )
AS
  v_cursor SYS_REFCURSOR;
  v_random_category INTEGER;
BEGIN
  -- Select random category (1-16)
  v_random_category := FLOOR(DBMS_RANDOM.VALUE(1, 17));

  -- Pseudo-random distribution for variety across different browse operations
  -- Category filter reduces sort cost, time-based ordering provides variety
  OPEN v_cursor FOR
    SELECT
        PROD_ID,
        CATEGORY,
        TITLE,
        ACTOR,
        PRICE,
        SPECIAL,
        COMMON_PROD_ID,
        MEMBERSHIP_ITEM
    FROM PRODUCTS$k
    WHERE MEMBERSHIP_ITEM = p_membershiptype_in
      AND CATEGORY = v_random_category
    ORDER BY MOD(PROD_ID + p_batch_size + p_membershiptype_in + TO_NUMBER(TO_CHAR(SYSDATE, 'SS')), 997)
    FETCH NEXT p_batch_size ROWS ONLY;

  DBMS_SQL.RETURN_RESULT(v_cursor);
END;
/


CREATE OR REPLACE PROCEDURE \"DS3\".\"GET_PROD_REVIEWS$k\"
(
   p_prod_in      IN  INTEGER,
   p_batch_size   IN  INTEGER
)
AS
  v_cursor SYS_REFCURSOR;
BEGIN
  OPEN v_cursor FOR
    SELECT
        REVIEW_ID,
        PROD_ID,
        REVIEW_DATE,
        STARS,
        CUSTOMERID,
        REVIEW_SUMMARY,
        REVIEW_TEXT,
        NVL(TOTAL_HELPFULNESS, 0)
    FROM REVIEWS$k
    WHERE PROD_ID = p_prod_in
    ORDER BY TOTAL_HELPFULNESS DESC
    FETCH NEXT p_batch_size ROWS ONLY;

  DBMS_SQL.RETURN_RESULT(v_cursor);
END;
/
  
CREATE OR REPLACE PROCEDURE \"DS3\".\"GET_PROD_REVIEWS_BY_STARS$k\"
  (
   p_prod_in    IN  INTEGER,
   p_stars_in   IN  INTEGER,
   p_batch_size IN  INTEGER
  )
AS
  v_cursor SYS_REFCURSOR;
BEGIN
  OPEN v_cursor FOR
    SELECT
        REVIEW_ID,
        PROD_ID,
        REVIEW_DATE,
        STARS,
        CUSTOMERID,
        REVIEW_SUMMARY,
        REVIEW_TEXT,
        NVL(TOTAL_HELPFULNESS, 0) AS TOTAL_HELPFULNESS
    FROM REVIEWS$k
    WHERE PROD_ID = p_prod_in
      AND STARS = p_stars_in
    ORDER BY TOTAL_HELPFULNESS DESC
    FETCH NEXT p_batch_size ROWS ONLY;

  DBMS_SQL.RETURN_RESULT(v_cursor);

END GET_PROD_REVIEWS_BY_STARS$k;
/


CREATE OR REPLACE PROCEDURE \"DS3\".\"GET_PROD_REVIEWS_BY_DATE$k\"
  (
   p_prod_in    IN  INTEGER,
   p_batch_size IN  INTEGER
  )
AS
  v_cursor SYS_REFCURSOR;
BEGIN
  OPEN v_cursor FOR
    SELECT
        REVIEW_ID,
        PROD_ID,
        REVIEW_DATE,
        STARS,
        CUSTOMERID,
        REVIEW_SUMMARY,
        REVIEW_TEXT,
        NVL(TOTAL_HELPFULNESS, 0) AS TOTAL_HELPFULNESS
    FROM REVIEWS$k
    WHERE PROD_ID = p_prod_in
    ORDER BY REVIEW_DATE DESC
    FETCH NEXT p_batch_size ROWS ONLY;

  DBMS_SQL.RETURN_RESULT(v_cursor);

END GET_PROD_REVIEWS_BY_DATE$k;
/

CREATE OR REPLACE PROCEDURE \"DS3\".\"GET_PROD_REVIEWS_BY_ACTOR$k\"
  (
   p_actor_in     IN  VARCHAR2,
   p_batch_size   IN  INTEGER,
   p_search_depth IN  INTEGER DEFAULT 10
  )
AS
  v_cursor SYS_REFCURSOR;
BEGIN
  OPEN v_cursor FOR
    WITH Search_Filtered AS (
      SELECT
          P.TITLE,
          P.ACTOR,
          R.REVIEW_ID,
          R.PROD_ID,
          R.REVIEW_DATE,
          R.STARS,
          R.CUSTOMERID,
          R.REVIEW_SUMMARY,
          R.REVIEW_TEXT,
          NVL(R.TOTAL_HELPFULNESS, 0) AS HELPFULNESS_TOTAL
      FROM PRODUCTS$k P
      INNER JOIN REVIEWS$k R ON P.PROD_ID = R.PROD_ID
      WHERE CONTAINS(P.ACTOR, p_actor_in) > 0
      FETCH NEXT p_search_depth ROWS ONLY -- Respect search_depth
    )
    SELECT * FROM Search_Filtered
    ORDER BY HELPFULNESS_TOTAL DESC
    FETCH NEXT p_batch_size ROWS ONLY; -- Respect batch_size

  DBMS_SQL.RETURN_RESULT(v_cursor);
END GET_PROD_REVIEWS_BY_ACTOR$k;
/

CREATE OR REPLACE PROCEDURE \"DS3\".\"GET_PROD_REVIEWS_BY_TITLE$k\"
  (
   p_title_in     IN  VARCHAR2,
   p_batch_size   IN  INTEGER,
   p_search_depth IN  INTEGER DEFAULT 10
  )
AS
  v_cursor SYS_REFCURSOR;
BEGIN
  OPEN v_cursor FOR
    WITH Title_Search AS (
      SELECT
          P.TITLE,
          P.ACTOR,
          R.REVIEW_ID,
          R.PROD_ID,
          R.REVIEW_DATE,
          R.STARS,
          R.CUSTOMERID,
          R.REVIEW_SUMMARY,
          R.REVIEW_TEXT,
          NVL(R.TOTAL_HELPFULNESS, 0) AS HELPFULNESS_TOTAL
      FROM PRODUCTS$k P
      INNER JOIN REVIEWS$k R ON P.PROD_ID = R.PROD_ID
      WHERE CONTAINS(P.TITLE, p_title_in) > 0
      FETCH NEXT p_search_depth ROWS ONLY
    )
    SELECT * FROM Title_Search
    ORDER BY HELPFULNESS_TOTAL DESC
    FETCH NEXT p_batch_size ROWS ONLY;

  DBMS_SQL.RETURN_RESULT(v_cursor);
END GET_PROD_REVIEWS_BY_TITLE$k;
/

CREATE OR REPLACE PROCEDURE \"DS3\".\"BROWSE_BY_ACTOR$k\"
  (
  p_actor_in   IN  VARCHAR2,
  p_batch_size IN  INTEGER
  )
AS
  v_cursor SYS_REFCURSOR;
BEGIN
  OPEN v_cursor FOR
    SELECT
        PROD_ID,
        CATEGORY,
        TITLE,
        ACTOR,
        PRICE,
        SPECIAL,
        COMMON_PROD_ID,
        MEMBERSHIP_ITEM
    FROM PRODUCTS$k
    WHERE CONTAINS(ACTOR, p_actor_in) > 0
    ORDER BY TITLE
    FETCH NEXT p_batch_size ROWS ONLY;

  DBMS_SQL.RETURN_RESULT(v_cursor);
END;
/

CREATE OR REPLACE  PROCEDURE \"DS3\".\"BROWSE_BY_ACTOR_FOR_MEMBERTY$k\"
  (
  batch_size   		IN INTEGER,
  found        		OUT INTEGER,
  actor_in     		IN  VARCHAR2,
  membershiptype_in  	IN INTEGER,
  prod_id_out  		OUT DS3_TYPES.N_TYPE,
  category_out 		OUT DS3_TYPES.N_TYPE,
  title_out    		OUT DS3_TYPES.ARRAY_TYPE,
  actor_out    		OUT DS3_TYPES.ARRAY_TYPE,
  price_out    		OUT DS3_TYPES.N_TYPE,
  special_out  		OUT DS3_TYPES.N_TYPE,
  common_prod_id_out  	OUT DS3_TYPES.N_TYPE,
  membership_item_out   OUT DS3_TYPES.N_TYPE
  )
  AS
  result_cv DS3_TYPES.DS3_CURSOR;
  i INTEGER;

  BEGIN
    IF NOT result_cv%ISOPEN THEN
      OPEN result_cv FOR
      SELECT * FROM PRODUCTS$k WHERE CONTAINS(ACTOR, actor_in) > 0 AND MEMBERSHIP_ITEM <= membershiptype_in;
    END IF;

    found := 0;
    FOR i IN 1..batch_size LOOP
      FETCH result_cv INTO prod_id_out(i), category_out(i), title_out(i), actor_out(i), price_out(i), special_out(i), common_prod_id_out(i), membership_item_out(i);
      IF result_cv%NOTFOUND THEN
        CLOSE result_cv;
        EXIT;
      ELSE
        found := found + 1;
      END IF;
    END LOOP;
  END BROWSE_BY_ACTOR_FOR_MEMBERTY$k;
/

CREATE OR REPLACE PROCEDURE \"DS3\".\"BROWSE_BY_TITLE$k\"
  (
  p_title_in   IN  VARCHAR2,
  p_batch_size IN  INTEGER
  )
AS
  v_cursor SYS_REFCURSOR;
BEGIN
  OPEN v_cursor FOR
    SELECT
        PROD_ID,
        CATEGORY,
        TITLE,
        ACTOR,
        PRICE,
        SPECIAL,
        COMMON_PROD_ID,
        MEMBERSHIP_ITEM
    FROM PRODUCTS$k
    WHERE CONTAINS(TITLE, p_title_in) > 0
    ORDER BY TITLE
    FETCH NEXT p_batch_size ROWS ONLY;

  DBMS_SQL.RETURN_RESULT(v_cursor);
END;
/

CREATE OR REPLACE  PROCEDURE \"DS3\".\"BROWSE_BY_TITLE_FOR_MEMBERTY$k\"
  (
  batch_size            IN INTEGER,
  found                 OUT INTEGER,
  title_in              IN VARCHAR2,
  membershiptype_in     IN INTEGER,
  prod_id_out           OUT DS3_TYPES.N_TYPE,
  category_out          OUT DS3_TYPES.N_TYPE,
  title_out             OUT DS3_TYPES.ARRAY_TYPE,
  actor_out             OUT DS3_TYPES.ARRAY_TYPE,
  price_out             OUT DS3_TYPES.N_TYPE,
  special_out           OUT DS3_TYPES.N_TYPE,
  common_prod_id_out    OUT DS3_TYPES.N_TYPE,
  membership_item_out   OUT DS3_TYPES.N_TYPE
  )
  AS
  result_cv DS3_TYPES.DS3_CURSOR;
  i INTEGER;

  BEGIN
    IF NOT result_cv%ISOPEN THEN
      OPEN result_cv FOR
      SELECT * FROM PRODUCTS$k WHERE CONTAINS(TITLE, title_in) > 0 AND MEMBERSHIP_ITEM <= membershiptype_in;
    END IF;

    found := 0;
    FOR i IN 1..batch_size LOOP
      FETCH result_cv INTO prod_id_out(i), category_out(i), title_out(i), actor_out(i), price_out(i), special_out(i), common_prod_id_out(i), membership_item_out(i);
      IF result_cv%NOTFOUND THEN
        CLOSE result_cv;
        EXIT;
      ELSE
        found := found + 1;
      END IF;
    END LOOP;
  END BROWSE_BY_TITLE_FOR_MEMBERTY$k;
/


CREATE OR REPLACE  PROCEDURE \"DS3\".\"PURCHASE$k\"
  (
  customerid_in   IN INTEGER,
  number_items    IN INTEGER,
  netamount_in    IN NUMBER,
  taxamount_in    IN NUMBER,
  totalamount_in  IN NUMBER,
  neworderid_out  OUT INTEGER,
  prod_id_in      IN DS3_TYPES.N_TYPE,
  qty_in          IN DS3_TYPES.N_TYPE
  )
  AS
  date_in        DATE;
  item_id        INTEGER;
  price          NUMBER;
  cur_quan       NUMBER;
  new_quan       NUMBER;
  cur_sales      NUMBER;
  new_sales      NUMBER;
  prod_id_temp   DS3_TYPES.N_TYPE;

  BEGIN

    SELECT ORDERID_SEQ$k.NEXTVAL INTO neworderid_out FROM DUAL;

    date_in := SYSDATE;

    COMMIT;

  -- Start Transaction
    SET TRANSACTION NAME 'FillOrder';


  -- CREATE NEW ENTRY IN ORDERS TABLE
    INSERT INTO ORDERS$k
      (
      ORDERID,
      ORDERDATE,
      CUSTOMERID,
      NETAMOUNT,
      TAX,
      TOTALAMOUNT
      )
    VALUES
      (
      neworderid_out,
      date_in,
      customerid_in,
      netamount_in,
      taxamount_in,
      totalamount_in
      )
      ;

    -- ADD LINE ITEMS TO ORDERLINES

    FOR item_id IN 1..number_items LOOP
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
        prod_id_in(item_id),
        qty_in(item_id),
        date_in
        )
        ;
   -- Check and update quantity in stock
      SELECT QUAN_IN_STOCK, SALES into cur_quan, cur_sales FROM INVENTORY$k WHERE PROD_ID=prod_id_in(item_id);
      new_quan := cur_quan - qty_in(item_id);
      new_sales := cur_sales + qty_in(item_id);
      IF new_quan < 0 THEN
        ROLLBACK;
        neworderid_out := 0;
        RETURN;
      ELSE
        UPDATE INVENTORY$k SET QUAN_IN_STOCK = new_quan, SALES= new_sales WHERE PROD_ID=prod_id_in(item_id);

        INSERT INTO CUST_HIST$k
          (
          CUSTOMERID,
          ORDERID,
          PROD_ID
          )
        VALUES
          (
          customerid_in,
          neworderid_out,
          prod_id_in(item_id)
          );
      END IF;
    END LOOP;

    COMMIT;

  END PURCHASE$k;
/

CREATE OR REPLACE PROCEDURE DS3.AddNewInventoryProduct$k (
    p_cat    IN  NUMBER,
    p_title  IN  VARCHAR2,
    p_actor  IN  VARCHAR2,
    p_price  IN  NUMBER,
    p_stock  IN  NUMBER,
    p_gen_id OUT NUMBER
) AS
    v_new_id    NUMBER;
    v_max_id    NUMBER;
    v_common_id NUMBER;
    v_membership NUMBER;
BEGIN
    SELECT PROD_SEQ$k.NEXTVAL INTO v_new_id FROM dual;

    SELECT COUNT(*) INTO v_max_id FROM PRODUCTS$k;

    IF v_max_id = 0 THEN
        v_common_id := 1;
    ELSE
        v_common_id := TRUNC(DBMS_RANDOM.VALUE(1, v_max_id + 1));
    END IF;

    v_membership := TRUNC(DBMS_RANDOM.VALUE(0, 4));

    INSERT INTO PRODUCTS$k (
        PROD_ID, CATEGORY, TITLE, ACTOR, PRICE, SPECIAL, COMMON_PROD_ID, MEMBERSHIP_ITEM
    ) VALUES (
        v_new_id, p_cat, p_title, p_actor, p_price, 0, v_common_id, v_membership
    );

    INSERT INTO INVENTORY$k (PROD_ID, QUAN_IN_STOCK, SALES)
    VALUES (v_new_id, p_stock, 0);

    p_gen_id := v_new_id;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

CREATE OR REPLACE TRIGGER \"DS3\".\"RESTOCK$k\"
BEFORE UPDATE OF \"QUAN_IN_STOCK\" ON \"DS3\".\"INVENTORY$k\"
FOR EACH ROW WHEN (NEW.QUAN_IN_STOCK < 3)

DECLARE
  quan_reordered NUMBER;
  date_reordered DATE;
BEGIN
    -- Random quantity between 3 and 22
    quan_reordered := TRUNC(DBMS_RANDOM.VALUE(3, 23));

    -- Special products (every 10000th) get 20x the quantity
    IF (MOD(:NEW.PROD_ID, 10000) = 0) THEN
        quan_reordered := quan_reordered * 20;
    END IF;

    -- Calculate reorder date (NOW + quan_reordered MINUTES, not DAYS)
    date_reordered := SYSDATE + (quan_reordered / 1440);

    INSERT INTO DS3.REORDER$k(PROD_ID, DATE_LOW, QUAN_LOW, DATE_REORDERED, QUAN_REORDERED)
    VALUES(:NEW.PROD_ID, SYSDATE, :NEW.QUAN_IN_STOCK, date_reordered, quan_reordered);

    :NEW.QUAN_IN_STOCK := :NEW.QUAN_IN_STOCK + quan_reordered;
END RESTOCK$k;
/

CREATE OR REPLACE PROCEDURE DS3.RemoveReviewByProduct$k (
    p_prod_id    IN  NUMBER,
    p_review_id  OUT NUMBER
) AS
    -- Cursor to select one random review with locking
    CURSOR c_review IS
        SELECT REVIEW_ID
        FROM DS3.REVIEWS$k
        WHERE PROD_ID = p_prod_id
        ORDER BY DBMS_RANDOM.VALUE
        FOR UPDATE SKIP LOCKED;
BEGIN
    p_review_id := 0;

    -- Find one random review for this specific product
    -- (simulates product-specific spam moderation)
    BEGIN
        OPEN c_review;
        FETCH c_review INTO p_review_id;
        CLOSE c_review;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_review_id := 0;
    END;

    -- Delete it if found
    IF p_review_id > 0 THEN
        -- Disable trigger to avoid mutating table error
        EXECUTE IMMEDIATE 'ALTER TRIGGER DS3.TRG_HELPFULNESS_SYNC$k DISABLE';

        DELETE FROM DS3.REVIEWS$k WHERE REVIEW_ID = p_review_id;

        -- Re-enable trigger
        EXECUTE IMMEDIATE 'ALTER TRIGGER DS3.TRG_HELPFULNESS_SYNC$k ENABLE';
    END IF;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        -- Re-enable trigger even on error
        BEGIN
            EXECUTE IMMEDIATE 'ALTER TRIGGER DS3.TRG_HELPFULNESS_SYNC$k ENABLE';
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        ROLLBACK;
        RAISE;
END;
/

CREATE OR REPLACE PROCEDURE DS3.RemoveUnhelpfulReviews$k (
    p_batch_size     IN  NUMBER,
    p_rows_affected  OUT NUMBER
) AS
    TYPE reviewid_array IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v_review_ids reviewid_array;

    -- Cursor to select reviews with locking
    CURSOR c_reviews IS
        SELECT REVIEW_ID
        FROM DS3.REVIEWS$k
        ORDER BY TOTAL_HELPFULNESS ASC, REVIEW_ID ASC
        FOR UPDATE SKIP LOCKED;
BEGIN
    -- Delete N least helpful reviews across all products
    -- (simulates global cleanup of low-quality reviews)

    -- Open cursor and fetch up to batch_size rows
    OPEN c_reviews;
    FETCH c_reviews BULK COLLECT INTO v_review_ids LIMIT p_batch_size;
    CLOSE c_reviews;

    -- Then delete them
    IF v_review_ids.COUNT > 0 THEN
        -- Disable trigger to avoid mutating table error
        EXECUTE IMMEDIATE 'ALTER TRIGGER DS3.TRG_HELPFULNESS_SYNC$k DISABLE';

        FORALL i IN 1..v_review_ids.COUNT
            DELETE FROM DS3.REVIEWS$k
            WHERE REVIEW_ID = v_review_ids(i);

        -- Re-enable trigger
        EXECUTE IMMEDIATE 'ALTER TRIGGER DS3.TRG_HELPFULNESS_SYNC$k ENABLE';

        p_rows_affected := v_review_ids.COUNT;
    ELSE
        p_rows_affected := 0;
    END IF;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        -- Re-enable trigger even on error
        BEGIN
            EXECUTE IMMEDIATE 'ALTER TRIGGER DS3.TRG_HELPFULNESS_SYNC$k ENABLE';
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        ROLLBACK;
        RAISE;
END;
/

CREATE OR REPLACE PROCEDURE DS3.RemoveReviewsByDate$k (
    p_batch_size     IN  NUMBER,
    p_rows_affected  OUT NUMBER
) AS
    TYPE reviewid_array IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v_review_ids reviewid_array;

    -- Cursor to select oldest reviews with locking
    CURSOR c_reviews IS
        SELECT REVIEW_ID
        FROM DS3.REVIEWS$k
        ORDER BY REVIEW_DATE ASC
        FOR UPDATE SKIP LOCKED;
BEGIN
    -- Delete N oldest reviews by REVIEW_DATE

    -- Open cursor and fetch up to batch_size rows
    OPEN c_reviews;
    FETCH c_reviews BULK COLLECT INTO v_review_ids LIMIT p_batch_size;
    CLOSE c_reviews;

    -- Then delete them
    IF v_review_ids.COUNT > 0 THEN
        -- Disable trigger to avoid mutating table error
        EXECUTE IMMEDIATE 'ALTER TRIGGER DS3.TRG_HELPFULNESS_SYNC$k DISABLE';

        FORALL i IN 1..v_review_ids.COUNT
            DELETE FROM DS3.REVIEWS$k
            WHERE REVIEW_ID = v_review_ids(i);

        -- Re-enable trigger
        EXECUTE IMMEDIATE 'ALTER TRIGGER DS3.TRG_HELPFULNESS_SYNC$k ENABLE';

        p_rows_affected := v_review_ids.COUNT;
    ELSE
        p_rows_affected := 0;
    END IF;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        -- Re-enable trigger even on error
        BEGIN
            EXECUTE IMMEDIATE 'ALTER TRIGGER DS3.TRG_HELPFULNESS_SYNC$k ENABLE';
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        ROLLBACK;
        RAISE;
END;
/

CREATE OR REPLACE PROCEDURE DS3.AdjustPrices$k (
    p_prod_id        IN  NUMBER,
    p_rows_affected  OUT NUMBER
) AS
    v_adjustment_factor NUMBER;
BEGIN
    -- Randomly adjust price by -10% to +10%
    v_adjustment_factor := 0.90 + (DBMS_RANDOM.VALUE * 0.20);

    UPDATE DS3.PRODUCTS$k
    SET PRICE = PRICE * v_adjustment_factor
    WHERE PROD_ID = p_prod_id;

    p_rows_affected := SQL%ROWCOUNT;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

CREATE OR REPLACE PROCEDURE DS3.BulkPriceAdjustment$k (
    p_batch_size     IN  NUMBER,
    p_category       IN  NUMBER,
    p_rows_affected  OUT NUMBER
) AS
    v_adjustment_factor NUMBER;
BEGIN
    -- Category-wide price adjustment (±25%)
    -- Simulates market events like 'Holiday DVDs 15% off'
    v_adjustment_factor := 0.75 + (DBMS_RANDOM.VALUE * 0.50);

    UPDATE DS3.PRODUCTS$k
    SET PRICE = FLOOR(PRICE * v_adjustment_factor) + 0.77
    WHERE PROD_ID IN (
        SELECT PROD_ID
        FROM (
            SELECT PROD_ID
            FROM DS3.PRODUCTS$k
            WHERE CATEGORY = p_category
            ORDER BY DBMS_RANDOM.VALUE
        )
        WHERE ROWNUM <= p_batch_size
    );

    p_rows_affected := SQL%ROWCOUNT;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

CREATE OR REPLACE PROCEDURE DS3.MarkSpecials$k (
    p_prod_id        IN  NUMBER,
    p_rows_affected  OUT NUMBER
) AS
BEGIN
    -- Toggle SPECIAL flag (0→1 or 1→0)
    -- Simulates rotating promotions/featured items
    UPDATE DS3.PRODUCTS$k
    SET SPECIAL = CASE WHEN SPECIAL = 1 THEN 0 ELSE 1 END
    WHERE PROD_ID = p_prod_id;

    p_rows_affected := SQL%ROWCOUNT;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

CREATE OR REPLACE PROCEDURE DS3.ExpireMemberships$k (
    p_batch_size     IN  NUMBER,
    p_rows_affected  OUT NUMBER
) AS
    TYPE customer_ids IS TABLE OF NUMBER;
    v_customer_ids customer_ids;
BEGIN
    -- Delete expired memberships (oldest first)
    -- Simulates cleanup of lapsed subscriptions
    SELECT CUSTOMERID
    BULK COLLECT INTO v_customer_ids
    FROM (
        SELECT CUSTOMERID
        FROM DS3.MEMBERSHIP$k
        WHERE EXPIREDATE < SYSDATE
        ORDER BY EXPIREDATE ASC
    )
    WHERE ROWNUM <= p_batch_size;

    FORALL i IN 1 .. v_customer_ids.COUNT
        DELETE FROM DS3.MEMBERSHIP$k
        WHERE CUSTOMERID = v_customer_ids(i);

    p_rows_affected := SQL%ROWCOUNT;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

CREATE OR REPLACE PROCEDURE DS3.PurgeOldOrders$k (
    p_batch_size     IN  NUMBER,
    p_rows_affected  OUT NUMBER
) AS
    TYPE order_ids IS TABLE OF NUMBER;
    v_order_ids order_ids;
BEGIN
    -- Delete oldest orders (data retention policy, GDPR compliance)
    -- ORDERLINES cascade delete via foreign key ON DELETE CASCADE
    SELECT ORDERID
    BULK COLLECT INTO v_order_ids
    FROM (
        SELECT ORDERID
        FROM DS3.ORDERS$k
        ORDER BY ORDERDATE ASC
    )
    WHERE ROWNUM <= p_batch_size;

    FORALL i IN 1 .. v_order_ids.COUNT
        DELETE FROM DS3.ORDERS$k
        WHERE ORDERID = v_order_ids(i);

    p_rows_affected := SQL%ROWCOUNT;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

CREATE OR REPLACE PROCEDURE DS3.UpgradeMembership$k (
    p_batch_size       IN  NUMBER,
    p_rows_upgraded    OUT NUMBER,
    p_gold_threshold   OUT NUMBER,
    p_silver_threshold OUT NUMBER
) AS
    v_current_slice NUMBER;
BEGIN
    -- Time-based slicing: process 1% of customer base per minute
    -- Full coverage every 100 minutes, then repeats (stateless partitioning)
    v_current_slice := MOD(EXTRACT(MINUTE FROM SYSTIMESTAMP), 100);

    -- Calculate percentile thresholds for purchase counts in current slice
    -- Gold (3): >= 90th percentile, Silver (2): >= 75th percentile
    SELECT
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY purchase_count),
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY purchase_count)
    INTO p_gold_threshold, p_silver_threshold
    FROM (
        SELECT COUNT(*) AS purchase_count
        FROM DS3.MEMBERSHIP$k m
        INNER JOIN DS3.CUST_HIST$k ch ON m.CUSTOMERID = ch.CUSTOMERID
        WHERE MOD(m.CUSTOMERID, 100) = v_current_slice
        GROUP BY m.CUSTOMERID
    );

    -- Fallback to hardcoded thresholds if no data in slice
    IF p_gold_threshold IS NULL THEN
        p_gold_threshold := 20;
        p_silver_threshold := 10;
    END IF;

    -- Count total purchases per customer, upgrade membership if thresholds met
    -- UPGRADE ONLY - never downgrade
    -- Reward: extend expiration by 180 days when upgrading
    MERGE INTO DS3.MEMBERSHIP$k m
    USING (
        SELECT CUSTOMERID, new_level FROM (
            SELECT
                ch.CUSTOMERID,
                CASE
                    WHEN COUNT(*) >= p_gold_threshold THEN 3  -- Gold (90th percentile)
                    WHEN COUNT(*) >= p_silver_threshold THEN 2  -- Silver (75th percentile)
                END AS new_level,
                m2.MEMBERSHIPTYPE AS current_level
            FROM DS3.CUST_HIST$k ch
            INNER JOIN DS3.MEMBERSHIP$k m2 ON ch.CUSTOMERID = m2.CUSTOMERID
            WHERE MOD(ch.CUSTOMERID, 100) = v_current_slice
            GROUP BY ch.CUSTOMERID, m2.MEMBERSHIPTYPE
            HAVING COUNT(*) >= p_silver_threshold
                AND (
                    CASE
                        WHEN COUNT(*) >= p_gold_threshold THEN 3  -- Gold (90th percentile)
                        WHEN COUNT(*) >= p_silver_threshold THEN 2  -- Silver (75th percentile)
                    END
                ) > m2.MEMBERSHIPTYPE
        )
        WHERE ROWNUM <= p_batch_size
    ) upgrades
    ON (m.CUSTOMERID = upgrades.CUSTOMERID)
    WHEN MATCHED THEN
        UPDATE SET
            m.MEMBERSHIPTYPE = upgrades.new_level,
            m.EXPIREDATE = CASE
                WHEN m.EXPIREDATE > TRUNC(SYSDATE) THEN m.EXPIREDATE + 180  -- Active: extend from current
                ELSE TRUNC(SYSDATE) + 180  -- Expired: reactivate from today
            END;

    p_rows_upgraded := SQL%ROWCOUNT;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

CREATE OR REPLACE PROCEDURE DS3.PromotionalMembership$k (
    p_batch_size    IN  NUMBER,
    p_rows_affected OUT NUMBER
) AS
    v_customerid INT;
    v_old_tier INT;
    v_new_tier INT;
    v_old_expiredate DATE;
    v_new_expiredate DATE;
    v_operation_type VARCHAR2(10);

    CURSOR customer_cursor IS
        SELECT CUSTOMERID
        FROM DS3.CUSTOMERS$k
        ORDER BY DBMS_RANDOM.VALUE
        FETCH FIRST p_batch_size ROWS ONLY;
BEGIN
    p_rows_affected := 0;

    FOR customer_rec IN customer_cursor LOOP
        v_customerid := customer_rec.CUSTOMERID;

        -- Check if customer has membership
        BEGIN
            SELECT MEMBERSHIPTYPE, EXPIREDATE INTO v_old_tier, v_old_expiredate
            FROM DS3.MEMBERSHIP$k
            WHERE CUSTOMERID = v_customerid;

            -- UPDATE: Sequential upgrade or tier 3 extension
            v_operation_type := 'UPDATE';

            IF v_old_tier = 1 THEN
                v_new_tier := 2;
                v_new_expiredate := SYSDATE + 90;  -- Reactivate for upgrade
            ELSIF v_old_tier = 2 THEN
                v_new_tier := 3;
                v_new_expiredate := SYSDATE + 90;  -- Reactivate for upgrade
            ELSE  -- tier 3
                v_new_tier := 3;
                v_new_expiredate := v_old_expiredate + 90;  -- Extend by 90 days
            END IF;

            UPDATE DS3.MEMBERSHIP$k
            SET MEMBERSHIPTYPE = v_new_tier,
                EXPIREDATE = v_new_expiredate
            WHERE CUSTOMERID = v_customerid;

            -- Audit trail
            INSERT INTO DS3.MEMBERSHIP_PROMO_AUDIT$k (
                CUSTOMERID, OLD_TIER, NEW_TIER, OLD_EXPIREDATE, NEW_EXPIREDATE, OPERATION_TYPE
            ) VALUES (
                v_customerid, v_old_tier, v_new_tier, v_old_expiredate, v_new_expiredate, v_operation_type
            );

            p_rows_affected := p_rows_affected + 1;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- INSERT: New tier 1 membership with 90-day expiration
                v_new_tier := 1;
                v_new_expiredate := SYSDATE + 90;
                v_operation_type := 'INSERT';

                INSERT INTO DS3.MEMBERSHIP$k (CUSTOMERID, MEMBERSHIPTYPE, EXPIREDATE)
                VALUES (v_customerid, v_new_tier, v_new_expiredate);

                -- Audit trail
                INSERT INTO DS3.MEMBERSHIP_PROMO_AUDIT$k (
                    CUSTOMERID, OLD_TIER, NEW_TIER, OLD_EXPIREDATE, NEW_EXPIREDATE, OPERATION_TYPE
                ) VALUES (
                    v_customerid, NULL, v_new_tier, NULL, v_new_expiredate, v_operation_type
                );

                p_rows_affected := p_rows_affected + 1;
        END;
    END LOOP;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

CREATE OR REPLACE PROCEDURE DS3.GetMembershipAnalytics$k (
    p_cursor OUT SYS_REFCURSOR
)
AS
BEGIN
    OPEN p_cursor FOR
    WITH CustomerOrders AS (
        SELECT
            CUSTOMERID,
            COUNT(*) AS order_count,
            SUM(TOTALAMOUNT) AS total_revenue
        FROM DS3.ORDERS$k
        GROUP BY CUSTOMERID
    )
    SELECT
        m.MEMBERSHIPTYPE AS membership_tier,
        COUNT(DISTINCT CASE
            WHEN m.MEMBERSHIPTYPE IS NULL THEN c.CUSTOMERID
            WHEN m.EXPIREDATE >= TRUNC(SYSDATE) THEN c.CUSTOMERID
            ELSE NULL
        END) AS active_member_count,
        COUNT(DISTINCT CASE
            WHEN m.MEMBERSHIPTYPE IS NOT NULL AND m.EXPIREDATE < TRUNC(SYSDATE) THEN c.CUSTOMERID
            ELSE NULL
        END) AS expired_member_count,
        NVL(SUM(co.order_count), 0) AS total_orders,
        ROUND(NVL(SUM(co.total_revenue), 0), 2) AS total_revenue
    FROM DS3.CUSTOMERS$k c
    LEFT JOIN DS3.MEMBERSHIP$k m ON c.CUSTOMERID = m.CUSTOMERID
    LEFT JOIN CustomerOrders co ON c.CUSTOMERID = co.CUSTOMERID
    GROUP BY m.MEMBERSHIPTYPE
    ORDER BY CASE WHEN m.MEMBERSHIPTYPE IS NULL THEN -1 ELSE m.MEMBERSHIPTYPE END DESC;
END;
/

CREATE OR REPLACE PROCEDURE DS3.GetNewCustomerAnalytics$k (
    p_customers_baseline IN NUMBER,
    p_cursor OUT SYS_REFCURSOR
)
AS
BEGIN
    OPEN p_cursor FOR
    WITH NewCustomerStats AS (
        SELECT
            COUNT(DISTINCT c.CUSTOMERID) AS Created,
            COUNT(DISTINCT CASE WHEN o.OrderCount >= 2 THEN c.CUSTOMERID END) AS TwoPlus,
            COUNT(DISTINCT CASE WHEN o.OrderCount > 2 THEN c.CUSTOMERID END) AS ThreePlus,
            NVL(SUM(o.OrderCount), 0) AS TotalOrders
        FROM DS3.CUSTOMERS$k c
        LEFT JOIN (
            SELECT CUSTOMERID,
                   COUNT(*) AS OrderCount
            FROM DS3.ORDERS$k
            WHERE CUSTOMERID > p_customers_baseline
            GROUP BY CUSTOMERID
        ) o ON c.CUSTOMERID = o.CUSTOMERID
        WHERE c.CUSTOMERID > p_customers_baseline
    )
    SELECT Created, TwoPlus, ThreePlus, TotalOrders
    FROM NewCustomerStats;
END;
/

CREATE OR REPLACE PROCEDURE DS3.GetReviewAnalytics$k (
    p_reviewid_baseline IN NUMBER,
    p_cursor OUT SYS_REFCURSOR
)
AS
BEGIN
    OPEN p_cursor FOR
    WITH ReviewStats AS (
        SELECT
            STARS,
            COUNT(*) AS Reviews,
            SUM(CASE WHEN REVIEW_ID > p_reviewid_baseline THEN 1 ELSE 0 END) AS Added,
            NVL(AVG(TOTAL_HELPFULNESS), 0) AS AvgHelp,
            SUM(CASE WHEN TOTAL_HELPFULNESS >= 20 THEN 1 ELSE 0 END) AS HighHelp,
            SUM(CASE WHEN TOTAL_HELPFULNESS < 5 THEN 1 ELSE 0 END) AS LowHelp
        FROM DS3.REVIEWS$k
        GROUP BY STARS
    )
    SELECT
        STARS,
        Reviews,
        Added,
        CAST(AvgHelp AS NUMBER(10,1)) AS AvgHelp,
        HighHelp,
        LowHelp
    FROM ReviewStats
    ORDER BY STARS DESC;
END;
/

CREATE OR REPLACE PROCEDURE GET_PRICE_POINT_ANALYTICS$k(
    p_baseline_product_count IN NUMBER,
    p_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN p_cursor FOR
    -- Result Set 1: Price point distribution
    SELECT
        CASE
            WHEN MOD(CAST(PRICE * 100 AS INT), 100) = 99 THEN '.99'
            WHEN MOD(CAST(PRICE * 100 AS INT), 100) = 77 THEN '.77'
            WHEN MOD(CAST(PRICE * 100 AS INT), 100) = 1 THEN '.01'
            ELSE 'Other'
        END AS PriceEnding,
        COUNT(*) AS ProductCount
    FROM DS3.PRODUCTS$k
    GROUP BY
        CASE
            WHEN MOD(CAST(PRICE * 100 AS INT), 100) = 99 THEN '.99'
            WHEN MOD(CAST(PRICE * 100 AS INT), 100) = 77 THEN '.77'
            WHEN MOD(CAST(PRICE * 100 AS INT), 100) = 1 THEN '.01'
            ELSE 'Other'
        END
    ORDER BY
        CASE
            CASE
                WHEN MOD(CAST(PRICE * 100 AS INT), 100) = 99 THEN '.99'
                WHEN MOD(CAST(PRICE * 100 AS INT), 100) = 77 THEN '.77'
                WHEN MOD(CAST(PRICE * 100 AS INT), 100) = 1 THEN '.01'
                ELSE 'Other'
            END
            WHEN '.99' THEN 1
            WHEN '.77' THEN 2
            WHEN '.01' THEN 3
            ELSE 4
        END;

    -- Result Set 2: New products purchased count
    -- Oracle doesn't support multiple result sets, so we'll handle this in the C# code
    -- by making a second call or combining into a single query
END;
/

CREATE OR REPLACE PROCEDURE GET_NEW_PRODUCTS_PURCHASED$k(
    p_baseline_product_count IN NUMBER,
    p_count OUT NUMBER
)
IS
BEGIN
    SELECT COUNT(DISTINCT PROD_ID)
    INTO p_count
    FROM DS3.CUST_HIST$k
    WHERE PROD_ID > p_baseline_product_count;
END;
/

CREATE OR REPLACE PROCEDURE GET_INVENTORY_ANALYTICS$k(
    p_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN p_cursor FOR
    SELECT
        COUNT(CASE WHEN QUAN_IN_STOCK < 10 THEN 1 END) AS LowStockCount,
        COUNT(CASE WHEN QUAN_IN_STOCK > 100 THEN 1 END) AS HighStockCount,
        MAX(r.ReorderCount) AS ReorderCount,
        ROUND(NVL(AVG(QUAN_IN_STOCK), 0), 1) AS AvgInventory,
        COUNT(CASE WHEN SALES = 0 THEN 1 END) AS DeadStock,
        COUNT(CASE WHEN SALES BETWEEN 1 AND 999 THEN 1 END) AS LowSales,
        COUNT(CASE WHEN SALES BETWEEN 1000 AND 1499 THEN 1 END) AS MedSales,
        COUNT(CASE WHEN SALES >= 1500 THEN 1 END) AS HighSales,
        COUNT(*) AS TotalProducts
    FROM DS3.INVENTORY$k
    CROSS JOIN (SELECT COUNT(*) AS ReorderCount FROM DS3.REORDER$k) r;
END;
/

CREATE OR REPLACE TRIGGER \"DS3\".\"TRG_HELPFULNESS_SYNC$k\"
AFTER INSERT OR UPDATE OR DELETE ON \"DS3\".\"REVIEWS_HELPFULNESS$k\"
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        UPDATE DS3.REVIEWS$k
        SET TOTAL_HELPFULNESS = TOTAL_HELPFULNESS + :NEW.HELPFULNESS
        WHERE REVIEW_ID = :NEW.REVIEW_ID;
    ELSIF UPDATING THEN
        UPDATE DS3.REVIEWS$k
        SET TOTAL_HELPFULNESS = TOTAL_HELPFULNESS - :OLD.HELPFULNESS + :NEW.HELPFULNESS
        WHERE REVIEW_ID = :NEW.REVIEW_ID;
    ELSIF DELETING THEN
        UPDATE DS3.REVIEWS$k
        SET TOTAL_HELPFULNESS = TOTAL_HELPFULNESS - :OLD.HELPFULNESS
        WHERE REVIEW_ID = :OLD.REVIEW_ID;
    END IF;
END;
/

SET SERVEROUTPUT ON;

BEGIN
    DBMS_OUTPUT.PUT_LINE('Calculating total_helpfulness for reviews!');
END;
/

UPDATE DS3.REVIEWS$k R
SET TOTAL_HELPFULNESS = (
    SELECT NVL(SUM(H.HELPFULNESS), 0)
    FROM DS3.REVIEWS_HELPFULNESS$k H
    WHERE H.REVIEW_ID = R.REVIEW_ID
)
WHERE EXISTS (
    SELECT 1
    FROM DS3.REVIEWS_HELPFULNESS$k H
    WHERE H.REVIEW_ID = R.REVIEW_ID
);

exit;\n";
  close $OUT;
}

sleep (1);

foreach my $k (1 .. ($numberofstores-1)){
  system ("$startcmd sqlplus -S \"ds3/ds3\@$oracletarget\" \@$oracletargetdir${pathsep}oracle_ds_createsp$k.sql");
  }
  system ("sqlplus -S \"ds3/ds3\@$oracletarget\" \@$oracletargetdir${pathsep}oracle_ds_createsp$numberofstores.sql");

