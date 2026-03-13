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
	print $OUT "CREATE GLOBAL TEMPORARY TABLE derivedtable1$k
  ON COMMIT PRESERVE ROWS
  AS SELECT PRODUCTS$k.TITLE, PRODUCTS$k.ACTOR, PRODUCTS$k.PROD_ID, PRODUCTS$k.COMMON_PROD_ID
  FROM DS3.CUST_HIST$k INNER JOIN
    DS3.PRODUCTS$k ON CUST_HIST$k.PROD_ID = PRODUCTS$k.PROD_ID;

CREATE OR REPLACE  PROCEDURE \"DS3\".\"NEW_CUSTOMER$k\"
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
  username_in DS3.CUSTOMERS$k.USERNAME%TYPE,
  password_in DS3.CUSTOMERS$k.PASSWORD%TYPE,
  age_in DS3.CUSTOMERS$k.AGE%TYPE,
  income_in DS3.CUSTOMERS$k.INCOME%TYPE,
  gender_in DS3.CUSTOMERS$k.GENDER%TYPE,
  customerid_out OUT INTEGER
  )
  IS
  rows_returned INTEGER;
  BEGIN

    SELECT COUNT(*) INTO rows_returned FROM CUSTOMERS$k WHERE USERNAME = username_in;

    IF rows_returned = 0
    THEN
      SELECT CUSTOMERID_SEQ$k.NEXTVAL INTO customerid_out FROM DUAL;
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
        ;
      COMMIT;

    ELSE customerid_out := 0;

    END IF;

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
        SYSDATE
        );
      customerid_out := customerid_in;
    ELSE
      customerid_out := 0;
    END IF;
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
  BEGIN

      SELECT REVIEWHELPFULNESSID_SEQ$k.NEXTVAL INTO review_helpfulness_id_out FROM DUAL;
      INSERT INTO REVIEWS_HELPFULNESS$k
        (
        REVIEW_HELPFULNESS_ID,
        REVIEW_ID,
        CUSTOMERID,
        HELPFULNESS
        )
        VALUES
        (
        review_helpfulness_id_out,
        review_id_in,
        customerid_in,
        review_helpfulness_in
        )
        ;
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
    FROM cust_hist1 ch
    JOIN products1 p1 ON ch.prod_id = p1.prod_id
    LEFT JOIN products1 p2 ON p1.common_prod_id = p2.prod_id
    WHERE ch.customerid = p_customerid;

  DBMS_SQL.RETURN_RESULT(v_history_rc);

  END LOGIN$k;
/

CREATE OR REPLACE PROCEDURE \"DS3\".\"BROWSE_BY_CATEGORY$k\"
  (
  p_category_in  IN  INTEGER,
  p_batch_size   IN  INTEGER
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
      AND SPECIAL = 1
    ORDER BY TITLE
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

END GET_PROD_REVIEWS_BY_DATE1;
/

CREATE OR REPLACE  PROCEDURE \"DS3\".\"GET_PROD_REVIEWS_BY_ACTOR$k\"
  (
   batch_size                  IN INTEGER,
   search_depth				   IN INTEGER DEFAULT 10,
   found                       OUT INTEGER,
   actor_in                    IN  VARCHAR2,
   title_out		       OUT DS3_TYPES.ARRAY_TYPE,
   actor_out		       OUT DS3_TYPES.ARRAY_TYPE,
   review_id_out               OUT DS3_TYPES.N_TYPE,
   prod_id_out                 OUT DS3_TYPES.N_TYPE,
   review_date_out             OUT DS3_TYPES.ARRAY_TYPE,
   review_stars_out            OUT DS3_TYPES.N_TYPE,
   review_customerid_out       OUT DS3_TYPES.N_TYPE,
   review_summary_out          OUT DS3_TYPES.ARRAY_TYPE,
   review_text_out             OUT DS3_TYPES.LONG_ARRAY_TYPE,
   review_helpfulness_sum_out  OUT DS3_TYPES.N_TYPE
  )
  AS
  result_cv DS3_TYPES.DS3_CURSOR;
  i INTEGER;

  BEGIN

    IF NOT result_cv%ISOPEN THEN
      OPEN result_cv FOR
	WITH T1 AS 
          (SELECT PRODUCTS$k.TITLE, PRODUCTS$k.ACTOR, PRODUCTS$k.PROD_ID, REVIEWS$k.REVIEW_DATE, REVIEWS$k.STARS, REVIEWS$k.REVIEW_ID,
           REVIEWS$k.CUSTOMERID, REVIEWS$k.REVIEW_SUMMARY, REVIEWS$k.REVIEW_TEXT 
           FROM PRODUCTS$k INNER JOIN REVIEWS$k on PRODUCTS$k.PROD_ID = REVIEWS$k.PROD_ID where CONTAINS (ACTOR, actor_in) > 0 AND ROWNUM<= search_depth )
         select T1.title, T1.actor, T1.REVIEW_ID, T1.prod_id, T1.review_date, T1.stars, 
                T1.customerid, T1.review_summary, T1.review_text, SUM(helpfulness) AS totalhelp from REVIEWS_HELPFULNESS$k 
         inner join T1 on REVIEWS_HELPFULNESS$k.REVIEW_ID = T1.review_id
	 GROUP BY T1.REVIEW_ID, T1.prod_id, t1.title, t1.actor, t1.review_date, t1.stars, t1.customerid, t1.review_summary, t1.review_text
	 ORDER BY totalhelp DESC;       
    END IF;

    found := 0;
    FOR i IN 1..batch_size LOOP
      FETCH result_cv INTO title_out(i), actor_out(i),review_id_out(i), prod_id_out(i), review_date_out(i), review_stars_out(i), review_customerid_out(i), review_summary_out(i), review_text_out(i), review_helpfulness_sum_out(i);
      IF result_cv%NOTFOUND THEN
        CLOSE result_cv;
        EXIT;
      ELSE
	    IF review_helpfulness_sum_out(i) IS NULL THEN
          review_helpfulness_sum_out(i) := 0;
        END IF;
        found := found + 1;
      END IF;
    END LOOP;
  END GET_PROD_REVIEWS_BY_ACTOR$k;
/


CREATE OR REPLACE  PROCEDURE \"DS3\".\"GET_PROD_REVIEWS_BY_TITLE$k\"
  (
   batch_size                  IN INTEGER,
   search_depth				   IN INTEGER DEFAULT 10,
   found                       OUT INTEGER,
   title_in                    IN  VARCHAR2,
   title_out                   OUT DS3_TYPES.ARRAY_TYPE,
   actor_out                   OUT DS3_TYPES.ARRAY_TYPE,
   review_id_out               OUT DS3_TYPES.N_TYPE,
   prod_id_out                 OUT DS3_TYPES.N_TYPE,
   review_date_out             OUT DS3_TYPES.ARRAY_TYPE,
   review_stars_out            OUT DS3_TYPES.N_TYPE,
   review_customerid_out       OUT DS3_TYPES.N_TYPE,
   review_summary_out          OUT DS3_TYPES.ARRAY_TYPE,
   review_text_out             OUT DS3_TYPES.LONG_ARRAY_TYPE,
   review_helpfulness_sum_out  OUT DS3_TYPES.N_TYPE
  )
  AS
  result_cv DS3_TYPES.DS3_CURSOR;
  i INTEGER;

  BEGIN

    IF NOT result_cv%ISOPEN THEN
      OPEN result_cv FOR
	WITH T1 AS
          (SELECT PRODUCTS$k.TITLE, PRODUCTS$k.ACTOR, PRODUCTS$k.PROD_ID, REVIEWS$k.REVIEW_DATE, REVIEWS$k.STARS, REVIEWS$k.REVIEW_ID,
           REVIEWS$k.CUSTOMERID, REVIEWS$k.REVIEW_SUMMARY, REVIEWS$k.REVIEW_TEXT
           FROM PRODUCTS$k INNER JOIN REVIEWS$k on PRODUCTS$k.PROD_ID = REVIEWS$k.PROD_ID where CONTAINS (TITLE, title_in) > 0 AND ROWNUM<= search_depth )
         select T1.title, T1.actor, T1.REVIEW_ID, T1.prod_id, T1.review_date, T1.stars,
                T1.customerid, T1.review_summary, T1.review_text, SUM(helpfulness) AS totalhelp from REVIEWS_HELPFULNESS$k
         inner join T1 on REVIEWS_HELPFULNESS$k.REVIEW_ID = T1.review_id
         GROUP BY T1.REVIEW_ID, T1.prod_id, t1.title, t1.actor, t1.review_date, t1.stars, t1.customerid, t1.review_summary, t1.review_text
         ORDER BY totalhelp DESC;
    END IF;

    found := 0;
    FOR i IN 1..batch_size LOOP
      FETCH result_cv INTO title_out(i), actor_out(i),review_id_out(i), prod_id_out(i), review_date_out(i), review_stars_out(i), review_customerid_out(i), review_summary_out(i), review_text_out(i), review_helpfulness_sum_out(i);
      IF result_cv%NOTFOUND THEN
        CLOSE result_cv;
        EXIT;
      ELSE
	    IF review_helpfulness_sum_out(i) IS NULL THEN
          review_helpfulness_sum_out(i) := 0;
        END IF;
        found := found + 1;
      END IF;
    END LOOP;
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
--  date_in := TO_DATE('2005/1/1', 'YYYY/MM/DD');

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

CREATE OR REPLACE TRIGGER \"DS3\".\"RESTOCK$k\"
BEFORE UPDATE OF \"QUAN_IN_STOCK\" ON \"DS3\".\"INVENTORY$k\"
FOR EACH ROW WHEN (NEW.QUAN_IN_STOCK < 3)

DECLARE
  X INTEGER;
BEGIN
    X := DBMS_RANDOM.VALUE(3, 20);
    -- INSERT INTO DS3.REORDER$k(PROD_ID, DATE_LOW, QUAN_LOW) VALUES(:NEW.PROD_ID, SYSDATE, :NEW.QUAN_IN_STOCK);
    INSERT INTO DS3.REORDER$k(PROD_ID, DATE_LOW, QUAN_LOW, DATE_REORDERED, QUAN_REORDERED) VALUES(:NEW.PROD_ID, SYSDATE, :NEW.QUAN_IN_STOCK, SYSDATE + X, X);
    :NEW.QUAN_IN_STOCK := :NEW.QUAN_IN_STOCK + X;
END RESTOCK$k;
/

CREATE OR REPLACE TRIGGER \"DS3\".\"TRG_HELPFULNESS_SYNC$k\"
AFTER INSERT OR UPDATE OR DELETE ON \"DS3\".\"REVIEWS_HELPFULNESS$k\"
FOR EACH ROW
BEGIN
    IF INSERTING OR UPDATING THEN
        UPDATE DS3.REVIEWS$k
        SET TOTAL_HELPFULNESS = TOTAL_HELPFULNESS + :NEW.HELPFULNESS
        WHERE REVIEW_ID = :NEW.REVIEW_ID;
    ELSIF DELETING THEN
        UPDATE DS3.REVIEWS$k
        SET TOTAL_HELPFULNESS = TOTAL_HELPFULNESS - :OLD.HELPFULNESS
        WHERE REVIEW_ID = :OLD.REVIEW_ID;
    END IF;
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
  system ("$startcmd sqlplus \"ds3/ds3\@$oracletarget\" \@$oracletargetdir${pathsep}oracle_ds_createsp$k.sql");
  }
  system ("sqlplus \"ds3/ds3\@$oracletarget\" \@$oracletargetdir${pathsep}oracle_ds_createsp$numberofstores.sql");

