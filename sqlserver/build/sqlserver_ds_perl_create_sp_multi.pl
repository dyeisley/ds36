# sqlserver_ds_perl_create_sp_multi.pl
# Script to create a ds3 stored procedures in sql server with a provided number of copies - supporting multiple stores
# Syntax to run - perl sqlserver_ds_perl_create_sp_multi.pl <sqlserver_target> <number_of_stores> <password> <use_vectors>

use strict;
use warnings;

my $sqlservertarget = $ARGV [0];
my $numberofstores = $ARGV[1];
my $password = $ARGV[2] || 'password';
my $use_vectors = $ARGV[3] || 0;

my $sqlservertargetdir;

$sqlservertargetdir = $sqlservertarget;

# remove any backslashes from string to be used for directory name
$sqlservertargetdir =~ s/\\//;

system ("mkdir -p $sqlservertargetdir");

my $pathsep;
my $startcmd;

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
	open (my $OUT, ">$sqlservertargetdir${pathsep}sqlserver_ds_createsp$k.sql") || die("Can't open sqlserver_ds_createsp$k.sql");
	print $OUT "-- NEW_CUSTOMER

USE DS3
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'NEW_CUSTOMER$k' AND type = 'P')
  DROP PROCEDURE NEW_CUSTOMER$k
GO

CREATE PROCEDURE NEW_CUSTOMER$k
  (
  \@firstname_in             VARCHAR(50),
  \@lastname_in              VARCHAR(50),
  \@address1_in              VARCHAR(50),
  \@address2_in              VARCHAR(50),
  \@city_in                  VARCHAR(50),
  \@state_in                 VARCHAR(50),
  \@zip_in                   INT,
  \@country_in               VARCHAR(50),
  \@region_in                TINYINT,
  \@email_in                 VARCHAR(50),
  \@phone_in                 VARCHAR(50),
  \@creditcardtype_in        TINYINT,
  \@creditcard_in            VARCHAR(50),
  \@creditcardexpiration_in  VARCHAR(50),
  \@username_out             VARCHAR(50) OUTPUT,
  \@password_in              VARCHAR(50),
  \@age_in                   TINYINT,
  \@income_in                INT,
  \@gender_in                VARCHAR(1)
  )

  AS

  DECLARE \@customerid_new INT
  DECLARE \@temp_username VARCHAR(50)
  SET \@temp_username = 'temp-' + CAST(\@\@SPID AS VARCHAR) + '-' + CAST(GETDATE() AS VARCHAR)

  INSERT INTO CUSTOMERS$k
    (
    FIRSTNAME,
    LASTNAME,
    ADDRESS1,
    ADDRESS2,
    CITY,
    STATE,
    ZIP,
    COUNTRY,
    REGION,
    EMAIL,
    PHONE,
    CREDITCARDTYPE,
    CREDITCARD,
    CREDITCARDEXPIRATION,
    USERNAME,
    PASSWORD,
    AGE,
    INCOME,
    GENDER
    )
  VALUES
    (
    \@firstname_in,
    \@lastname_in,
    \@address1_in,
    \@address2_in,
    \@city_in,
    \@state_in,
    \@zip_in,
    \@country_in,
    \@region_in,
    \@email_in,
    \@phone_in,
    \@creditcardtype_in,
    \@creditcard_in,
    \@creditcardexpiration_in,
    \@temp_username,
    \@password_in,
    \@age_in,
    \@income_in,
    \@gender_in
    )

  SET \@customerid_new = SCOPE_IDENTITY()
  SET \@username_out = 'user' + CAST(\@customerid_new AS VARCHAR)

  UPDATE CUSTOMERS$k SET USERNAME = \@username_out WHERE CUSTOMERID = \@customerid_new

  SELECT \@customerid_new
GO

-- NEW_MEMBER

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'NEW_MEMBER$k' AND type = 'P')
  DROP PROCEDURE NEW_MEMBER$k
GO

CREATE PROCEDURE NEW_MEMBER$k
  (
  \@customerid_in            INT,
  \@membershiplevel_in       INT
  )

  AS

  DECLARE
  \@date_in                  DATETIME

  SET DATEFORMAT ymd

  SET \@date_in = DATEADD(year, 1, GETDATE())

  IF (SELECT COUNT(*) FROM MEMBERSHIP$k WHERE CUSTOMERID=\@customerid_in) = 0
  BEGIN
    INSERT INTO MEMBERSHIP$k
      (
      CUSTOMERID,
      MEMBERSHIPTYPE,
      EXPIREDATE
      )
    VALUES
      (
      \@customerid_in,
      \@membershiplevel_in,
      \@date_in
      )
    SELECT \@customerid_in
  END
  ELSE
    SELECT 0
GO

-- NEW_PROD_REVIEW

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'NEW_PROD_REVIEW$k' AND type = 'P')
  DROP PROCEDURE NEW_PROD_REVIEW$k
GO

CREATE PROCEDURE NEW_PROD_REVIEW$k
  (
  \@prod_id_in            INT,
  \@stars_in			     INT,
  \@customerid_in		 INT,
  \@review_summary_in	 VARCHAR(50),
  \@review_text_in		 VARCHAR(1000)
  )

  AS

  DECLARE
  \@date_in                  DATETIME

  SET DATEFORMAT ymd

  SET \@date_in = GETDATE()

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
      \@prod_id_in,
      \@date_in,
      \@stars_in,
      \@customerid_in,
      \@review_summary_in,
      \@review_text_in
      )
    SELECT SCOPE_IDENTITY()
 GO


-- New review helpfulness rating

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'NEW_REVIEW_HELPFULNESS$k' AND type = 'P')
  DROP PROCEDURE NEW_REVIEW_HELPFULNESS$k
GO

CREATE PROCEDURE NEW_REVIEW_HELPFULNESS$k
  (
  \@review_id_in            INT,
  \@customerid_in           INT,
  \@review_helpfulness_in   INT
  )

  AS

  DECLARE \@OutputTable TABLE (review_helpfulness_id INT);

  MERGE INTO REVIEWS_HELPFULNESS$k AS target
  USING (VALUES (\@review_id_in, \@customerid_in, \@review_helpfulness_in))
    AS source (review_id, customerid, helpfulness)
  ON target.REVIEW_ID = source.review_id AND target.CUSTOMERID = source.customerid
  WHEN MATCHED THEN
    UPDATE SET HELPFULNESS = source.helpfulness
  WHEN NOT MATCHED THEN
    INSERT (REVIEW_ID, CUSTOMERID, HELPFULNESS)
    VALUES (source.review_id, source.customerid, source.helpfulness)
  OUTPUT INSERTED.REVIEW_HELPFULNESS_ID INTO \@OutputTable;

  SELECT review_helpfulness_id FROM \@OutputTable;
 GO

-- LOGIN

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'LOGIN$k' AND type = 'P')
  DROP PROCEDURE LOGIN$k
GO

CREATE PROCEDURE LOGIN$k
  (
  \@username_in              VARCHAR(50),
  \@password_in              VARCHAR(50)
  )

  AS
DECLARE \@customerid_out INT
  
  SELECT \@customerid_out=CUSTOMERID FROM CUSTOMERS$k WHERE USERNAME=\@username_in AND PASSWORD=\@password_in

  IF (\@\@ROWCOUNT > 0)
    BEGIN
      SELECT \@customerid_out
      SELECT derivedtable1$k.TITLE, derivedtable1$k.ACTOR, PRODUCTS_1$k.TITLE AS RelatedPurchase
        FROM (SELECT TOP 10 PRODUCTS$k.TITLE, PRODUCTS$k.ACTOR, PRODUCTS$k.PROD_ID, PRODUCTS$k.COMMON_PROD_ID
          FROM CUST_HIST$k INNER JOIN
             PRODUCTS$k ON CUST_HIST$k.PROD_ID = PRODUCTS$k.PROD_ID
          WHERE (CUST_HIST$k.CUSTOMERID = \@customerid_out)
          ORDER BY CUST_HIST$k.ORDERID DESC) AS derivedtable1$k INNER JOIN
             PRODUCTS$k AS PRODUCTS_1$k ON derivedtable1$k.COMMON_PROD_ID = PRODUCTS_1$k.PROD_ID
    END
  ELSE
    SELECT 0
GO

-- GetMembershipStatus - returns membership level and expiration status
IF EXISTS (SELECT name FROM sysobjects WHERE name = 'GET_MEMBERSHIP_STATUS$k' AND type = 'P')
  DROP PROCEDURE GET_MEMBERSHIP_STATUS$k
GO

CREATE PROCEDURE GET_MEMBERSHIP_STATUS$k
  (
  \@customerid_in            INT
  )

  AS
DECLARE \@membership_level INT
DECLARE \@is_expired INT

  -- Get membership info
  SELECT \@membership_level = MEMBERSHIPTYPE
  FROM MEMBERSHIP$k
  WHERE CUSTOMERID = \@customerid_in

  -- If no membership found, return 0
  IF (\@\@ROWCOUNT = 0)
    BEGIN
      SELECT 0 AS membership_level, 0 AS is_expired
      RETURN
    END

  -- Check if expired
  IF EXISTS (SELECT 1 FROM MEMBERSHIP$k
             WHERE CUSTOMERID = \@customerid_in
             AND EXPIREDATE < GETDATE())
    SET \@is_expired = 1
  ELSE
    SET \@is_expired = 0

  SELECT \@membership_level AS membership_level, \@is_expired AS is_expired
GO

-- RenewMembership - extend expiration by 1 year
IF EXISTS (SELECT name FROM sysobjects WHERE name = 'RENEW_MEMBERSHIP$k' AND type = 'P')
  DROP PROCEDURE RENEW_MEMBERSHIP$k
GO

CREATE PROCEDURE RENEW_MEMBERSHIP$k
  (
  \@customerid_in            INT
  )

  AS
  UPDATE MEMBERSHIP$k
  SET EXPIREDATE = DATEADD(year, 1, GETDATE())
  WHERE CUSTOMERID = \@customerid_in

  SELECT \@\@ROWCOUNT AS rows_affected
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'BROWSE_BY_CATEGORY$k' AND type = 'P')
  DROP PROCEDURE BROWSE_BY_CATEGORY$k
GO

CREATE PROCEDURE BROWSE_BY_CATEGORY$k
  (
  \@batch_size_in            INT,
  \@category_in              INT,
  \@special_in               INT
  )

  AS
  SELECT TOP (\@batch_size_in) * FROM PRODUCTS$k WHERE CATEGORY=\@category_in and SPECIAL=\@special_in
GO

-- Browse by category for membertype

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'BROWSE_BY_CATEGORY_FOR_MEMBERTYPE$k' AND type = 'P')
  DROP PROCEDURE BROWSE_BY_CATEGORY_FOR_MEMBERTYPE$k
GO

CREATE PROCEDURE BROWSE_BY_CATEGORY_FOR_MEMBERTYPE$k
  (
  \@batch_size_in            INT,
  \@category_in              INT,
  \@membershiptype_in	     INT
  )

  AS
  SELECT TOP (\@batch_size_in) * FROM PRODUCTS$k WHERE CATEGORY=\@category_in and SPECIAL=1 and MEMBERSHIP_ITEM<=\@membershiptype_in
GO

-- Browse by membership

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'BROWSE_BY_MEMBERSHIP$k' AND type = 'P')
  DROP PROCEDURE BROWSE_BY_MEMBERSHIP$k
GO

CREATE PROCEDURE BROWSE_BY_MEMBERSHIP$k
  (
  \@batch_size_in            INT,
  \@membershiptype_in        INT
  )
AS
BEGIN
  DECLARE \@random_category INT;

  -- Select random category (1-16)
  SET \@random_category = FLOOR(RAND() * 16) + 1;

  -- Pseudo-random distribution for variety across different browse operations
  -- Category filter reduces sort cost, time-based ordering provides variety
  SELECT TOP (\@batch_size_in) *
  FROM PRODUCTS$k
  WHERE MEMBERSHIP_ITEM = \@membershiptype_in
    AND CATEGORY = \@random_category
  ORDER BY (PROD_ID + \@batch_size_in + \@membershiptype_in + DATEPART(SECOND, GETDATE())) % 997
END
GO

-- get prod reviews

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'GET_PROD_REVIEWS$k' AND type = 'P')
  DROP PROCEDURE GET_PROD_REVIEWS$k
GO

CREATE PROCEDURE GET_PROD_REVIEWS$k
(
    \@batch_size_in INT,
    \@prod_in       INT
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        REVIEW_ID, PROD_ID, REVIEW_DATE, STARS,
        CUSTOMERID, REVIEW_SUMMARY, REVIEW_TEXT,
        TOTAL_HELPFULNESS
    FROM REVIEWS$k
    WHERE PROD_ID = \@prod_in
    ORDER BY TOTAL_HELPFULNESS DESC
    OFFSET 0 ROWS FETCH NEXT \@batch_size_in ROWS ONLY;
END
GO

-- get prod reviews by stars

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'GET_PROD_REVIEWS_BY_STARS$k' AND type = 'P')
  DROP PROCEDURE GET_PROD_REVIEWS_BY_STARS$k
GO

CREATE PROCEDURE GET_PROD_REVIEWS_BY_STARS$k
(
    \@batch_size_in INT,
    \@prod_in       INT,
    \@stars_in      INT
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        REVIEW_ID,
        PROD_ID,
        REVIEW_DATE,
        STARS,
        CUSTOMERID,
        REVIEW_SUMMARY,
        REVIEW_TEXT,
        TOTAL_HELPFULNESS
    FROM REVIEWS$k
    WHERE PROD_ID = \@prod_in
      AND STARS = \@stars_in
    ORDER BY TOTAL_HELPFULNESS DESC
    OFFSET 0 ROWS FETCH NEXT \@batch_size_in ROWS ONLY;
END
GO

-- get prod reviews by date

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'GET_PROD_REVIEWS_BY_DATE$k' AND type = 'P')
  DROP PROCEDURE GET_PROD_REVIEWS_BY_DATE$k
GO

CREATE PROCEDURE GET_PROD_REVIEWS_BY_DATE$k
(
    \@batch_size_in INT,
    \@prod_in       INT
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        REVIEW_ID,
        PROD_ID,
        REVIEW_DATE,
        STARS,
        CUSTOMERID,
        REVIEW_SUMMARY,
        REVIEW_TEXT,
        TOTAL_HELPFULNESS
    FROM REVIEWS$k
    WHERE PROD_ID = \@prod_in
    ORDER BY REVIEW_DATE DESC
    OFFSET 0 ROWS FETCH NEXT \@batch_size_in ROWS ONLY;
END
GO

-- get prod reviews by actor

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'GET_PROD_REVIEWS_BY_ACTOR$k' AND type = 'P')
  DROP PROCEDURE GET_PROD_REVIEWS_BY_ACTOR$k
GO

CREATE PROCEDURE GET_PROD_REVIEWS_BY_ACTOR$k
(
    \@batch_size_in   INT,
    \@actor_in        VARCHAR(50),
    \@search_depth_in INT = 500
)
AS
BEGIN
    SET NOCOUNT ON;

    WITH T1 AS (
        SELECT TOP (\@search_depth_in) 
            P.TITLE, 
            P.ACTOR, 
            P.PROD_ID, 
            R.REVIEW_ID,
            R.REVIEW_DATE, 
            R.STARS, 
            R.CUSTOMERID, 
            R.REVIEW_SUMMARY, 
            R.REVIEW_TEXT,
            R.TOTAL_HELPFULNESS
        FROM PRODUCTS$k AS P
        INNER JOIN REVIEWS$k AS R ON P.PROD_ID = R.PROD_ID
        WHERE CONTAINS(P.ACTOR, \@actor_in)
    )
    SELECT 
        PROD_ID, 
        TITLE, 
        ACTOR, 
        REVIEW_ID, 
        REVIEW_DATE, 
        STARS, 
        CUSTOMERID, 
        REVIEW_SUMMARY, 
        REVIEW_TEXT, 
        TOTAL_HELPFULNESS AS totalhelp
    FROM T1
    ORDER BY totalhelp DESC
    OFFSET 0 ROWS FETCH NEXT \@batch_size_in ROWS ONLY;
END
GO

-- get prod reviews by title

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'GET_PROD_REVIEWS_BY_TITLE$k' AND type = 'P')
  DROP PROCEDURE GET_PROD_REVIEWS_BY_TITLE$k
GO

CREATE PROCEDURE GET_PROD_REVIEWS_BY_TITLE$k
(
    \@batch_size_in   INT,
    \@title_in        VARCHAR(50),
    \@search_depth_in INT = 500
)
AS
BEGIN
    SET NOCOUNT ON;

    WITH T1 AS (
        SELECT TOP (\@search_depth_in)
            P.TITLE,
            P.ACTOR,
            P.PROD_ID,
            R.REVIEW_ID,
            R.REVIEW_DATE,
            R.STARS,
            R.CUSTOMERID,
            R.REVIEW_SUMMARY,
            R.REVIEW_TEXT,
            R.TOTAL_HELPFULNESS
        FROM PRODUCTS$k AS P
        INNER JOIN REVIEWS$k AS R ON P.PROD_ID = R.PROD_ID
        WHERE CONTAINS(P.TITLE, \@title_in)
    )
    SELECT
        PROD_ID,
        TITLE,
        ACTOR,
        REVIEW_ID,
        REVIEW_DATE,
        STARS,
        CUSTOMERID,
        REVIEW_SUMMARY,
        REVIEW_TEXT,
        TOTAL_HELPFULNESS AS totalhelp
    FROM T1
    ORDER BY totalhelp DESC
    OFFSET 0 ROWS FETCH NEXT \@batch_size_in ROWS ONLY;
END
GO
\n";

if ( $use_vectors == 1 )
{
print $OUT "

CREATE OR ALTER PROCEDURE BROWSE_BY_VECTOR$k
  (
    \@batch_size_in      INT,
    \@vector_in    VECTOR(384)
  )
  AS
  BEGIN
    SET NOCOUNT ON;

    SELECT TOP (\@batch_size_in)
        PROD_ID,
        CATEGORY,
        TITLE,
        ACTOR,
        PRICE,
        SPECIAL,
        COMMON_PROD_ID,
        v.distance  -- Keep v. because distance is generated by the function
    FROM VECTOR_SEARCH(
        TABLE = dbo.PRODUCTS$k,
        COLUMN = ProductEmbedding,
        SIMILAR_TO = \@vector_in,
        METRIC = 'COSINE',
        TOP_N = \@batch_size_in
    ) AS v
    ORDER BY v.distance ASC;
  END;
GO
\n";
}

print $OUT "
-- Browse by Actor

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'BROWSE_BY_ACTOR$k' AND type = 'P')
  DROP PROCEDURE BROWSE_BY_ACTOR$k
GO

CREATE PROCEDURE BROWSE_BY_ACTOR$k
  (
  \@batch_size_in            INT,
  \@actor_in                 VARCHAR(50)
  )

  AS

  SELECT TOP (\@batch_size_in) * FROM PRODUCTS$k WHERE CONTAINS(ACTOR, \@actor_in)
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'BROWSE_BY_TITLE$k' AND type = 'P')
  DROP PROCEDURE BROWSE_BY_TITLE$k
GO

CREATE PROCEDURE BROWSE_BY_TITLE$k
  (
  \@batch_size_in            INT,
  \@title_in                 VARCHAR(50)
  )

  AS

  SELECT TOP (\@batch_size_in) * FROM PRODUCTS$k WHERE CONTAINS(TITLE, \@title_in)
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'PURCHASE$k' AND type = 'P')
  DROP PROCEDURE PURCHASE$k
GO

CREATE PROCEDURE PURCHASE$k
  (
  \@customerid_in            INT,
  \@number_items             INT,
  \@netamount_in             MONEY,
  \@taxamount_in             MONEY,
  \@totalamount_in           MONEY,
  \@prod_id_in0              INT = 0,     \@qty_in0     INT = 0,
  \@prod_id_in1              INT = 0,     \@qty_in1     INT = 0,
  \@prod_id_in2              INT = 0,     \@qty_in2     INT = 0,
  \@prod_id_in3              INT = 0,     \@qty_in3     INT = 0,
  \@prod_id_in4              INT = 0,     \@qty_in4     INT = 0,
  \@prod_id_in5              INT = 0,     \@qty_in5     INT = 0,
  \@prod_id_in6              INT = 0,     \@qty_in6     INT = 0,
  \@prod_id_in7              INT = 0,     \@qty_in7     INT = 0,
  \@prod_id_in8              INT = 0,     \@qty_in8     INT = 0,
  \@prod_id_in9              INT = 0,     \@qty_in9     INT = 0
  )

  AS 

  DECLARE
  \@date_in                  DATETIME,
  \@neworderid               INT,
  \@item_id                  INT,
  \@prod_id                  INT,
  \@qty                      INT,
  \@cur_quan		     INT,
  \@new_quan		     INT,
  \@cur_sales                INT,
  \@new_sales                INT
  

  SET DATEFORMAT ymd

  SET \@date_in = GETDATE()
--SET \@date_in = '2005/10/31'

  BEGIN TRANSACTION
  -- CREATE NEW ENTRY IN ORDERS TABLE
  INSERT INTO ORDERS$k
    (
    ORDERDATE,
    CUSTOMERID,
    NETAMOUNT,
    TAX,
    TOTALAMOUNT
    )
  VALUES
    (
    \@date_in,
    \@customerid_in,
    \@netamount_in,
    \@taxamount_in,
    \@totalamount_in
    )

  SET \@neworderid = SCOPE_IDENTITY()


  -- ADD LINE ITEMS TO ORDERLINES

  SET \@item_id = 0

  WHILE (\@item_id < \@number_items)
  BEGIN
    SELECT \@prod_id = CASE \@item_id WHEN 0 THEN \@prod_id_in0
	                                WHEN 1 THEN \@prod_id_in1
	                                WHEN 2 THEN \@prod_id_in2
	                                WHEN 3 THEN \@prod_id_in3
	                                WHEN 4 THEN \@prod_id_in4
	                                WHEN 5 THEN \@prod_id_in5
	                                WHEN 6 THEN \@prod_id_in6
	                                WHEN 7 THEN \@prod_id_in7
	                                WHEN 8 THEN \@prod_id_in8
	                                WHEN 9 THEN \@prod_id_in9
    END

    SELECT \@qty = CASE \@item_id WHEN 0 THEN \@qty_in0
	                            WHEN 1 THEN \@qty_in1
	                            WHEN 2 THEN \@qty_in2
	                            WHEN 3 THEN \@qty_in3
	                            WHEN 4 THEN \@qty_in4
	                            WHEN 5 THEN \@qty_in5
	                            WHEN 6 THEN \@qty_in6
	                            WHEN 7 THEN \@qty_in7
	                            WHEN 8 THEN \@qty_in8
	                            WHEN 9 THEN \@qty_in9
    END

    SELECT \@cur_quan=QUAN_IN_STOCK, \@cur_sales=SALES FROM INVENTORY$k WHERE PROD_ID=\@prod_id

    SET \@new_quan = \@cur_quan - \@qty
    SET \@new_sales = \@cur_Sales + \@qty

    IF (\@new_quan < 0)
      BEGIN
        ROLLBACK TRANSACTION
        SELECT 0
        RETURN
      END
    ELSE
      BEGIN
        UPDATE INVENTORY$k SET QUAN_IN_STOCK=\@new_quan, SALES=\@new_sales WHERE PROD_ID=\@prod_id
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
          \@item_id + 1,
          \@neworderid,
          \@prod_id,
          \@qty,
          \@date_in
          )
        
        INSERT INTO CUST_HIST$k
          (
          CUSTOMERID,
          ORDERID,
          PROD_ID
          )
        VALUES
          (
          \@customerid_in,
          \@neworderid,
          \@prod_id
          )
      
        SET \@item_id = \@item_id + 1
      END    
  END

  COMMIT

  SELECT \@neworderid
GO

USE DS3
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'AddNewInventoryProduct$k' AND type = 'P')
  DROP PROCEDURE AddNewInventoryProduct$k
GO

CREATE PROCEDURE AddNewInventoryProduct$k
(
    \@p_cat TINYINT,
    \@p_title VARCHAR(50),
    \@p_actor VARCHAR(50),
    \@p_price NUMERIC(12,2),
    \@p_stock INT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE \@v_new_id INT;
    DECLARE \@v_max_id INT;
    DECLARE \@v_common_id INT;
    DECLARE \@v_membership TINYINT;

    SELECT \@v_max_id = COUNT(*) FROM PRODUCTS$k;

    IF \@v_max_id = 0
    BEGIN
        SET \@v_common_id = 1;
    END
    ELSE
    BEGIN
        SET \@v_common_id = FLOOR(1 + (RAND() * \@v_max_id));
    END

    SET \@v_membership = FLOOR(RAND() * 4);

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO PRODUCTS$k (CATEGORY, TITLE, ACTOR, PRICE, SPECIAL, COMMON_PROD_ID, MEMBERSHIP_ITEM)
        VALUES (\@p_cat, \@p_title, \@p_actor, \@p_price, 0, \@v_common_id, \@v_membership);

        SET \@v_new_id = SCOPE_IDENTITY();

        INSERT INTO INVENTORY$k (PROD_ID, QUAN_IN_STOCK, SALES)
        VALUES (\@v_new_id, \@p_stock, 0);

        COMMIT TRANSACTION;

        SELECT \@v_new_id AS generated_id;
    END TRY
    BEGIN CATCH
        IF \@\@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END
GO

PRINT 'Update TOTAL_HELPFULNESS in REVIEWS$k.';

UPDATE R
SET R.TOTAL_HELPFULNESS = H.CalculatedTotal
FROM REVIEWS$k R
INNER JOIN (
    -- Calculate current sum for every review
    SELECT REVIEW_ID, SUM(HELPFULNESS) AS CalculatedTotal
    FROM REVIEWS_HELPFULNESS$k
    GROUP BY REVIEW_ID
) AS H ON R.REVIEW_ID = H.REVIEW_ID;

-- Manager Thread Stored Procedures

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'RemoveReviewByProduct$k' AND type = 'P')
  DROP PROCEDURE RemoveReviewByProduct$k
GO

CREATE PROCEDURE RemoveReviewByProduct$k
  (
  \@prod_id             INT
  )
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE \@review_id INT = 0;

    -- Find one random review for this specific product
    -- (simulates product-specific spam moderation)
    SELECT TOP 1 \@review_id = REVIEW_ID
    FROM REVIEWS$k WITH (READPAST)
    WHERE PROD_ID = \@prod_id
    ORDER BY NEWID();

    -- Delete it if found
    IF \@review_id > 0
        DELETE FROM REVIEWS$k WHERE REVIEW_ID = \@review_id;

    SELECT \@review_id AS review_id;
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'RemoveUnhelpfulReviews$k' AND type = 'P')
  DROP PROCEDURE RemoveUnhelpfulReviews$k
GO

CREATE PROCEDURE RemoveUnhelpfulReviews$k
  (
  \@batch_size_in       INT
  )
AS
BEGIN
    SET NOCOUNT ON;

    -- Delete N least helpful reviews across all products
    -- (simulates global cleanup of low-quality reviews)
    DELETE FROM REVIEWS$k
    WHERE REVIEW_ID IN (
        SELECT TOP (\@batch_size_in) REVIEW_ID
        FROM REVIEWS$k WITH (READPAST)
        ORDER BY TOTAL_HELPFULNESS ASC, REVIEW_ID ASC
    );

    SELECT \@\@ROWCOUNT;
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'RemoveReviewsByDate$k' AND type = 'P')
  DROP PROCEDURE RemoveReviewsByDate$k
GO

CREATE PROCEDURE RemoveReviewsByDate$k
  (
  \@batch_size_in       INT
  )
AS
BEGIN
    SET NOCOUNT ON;

    -- Delete N oldest reviews by REVIEW_DATE
    DELETE FROM REVIEWS$k
    WHERE REVIEW_ID IN (
        SELECT TOP (\@batch_size_in) REVIEW_ID
        FROM REVIEWS$k WITH (READPAST)
        ORDER BY REVIEW_DATE ASC
    );

    SELECT \@\@ROWCOUNT;
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'AdjustPrices$k' AND type = 'P')
  DROP PROCEDURE AdjustPrices$k
GO

CREATE PROCEDURE AdjustPrices$k
  (
  \@prod_id             INT
  )
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE \@adjustment_factor DECIMAL(4,3);
    SET \@adjustment_factor = 0.90 + (RAND() * 0.20);  -- Range: 0.90 to 1.10 (±10%)

    UPDATE PRODUCTS$k WITH (READPAST)
    SET PRICE = PRICE * \@adjustment_factor
    WHERE PROD_ID = \@prod_id;

    SELECT \@\@ROWCOUNT;
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'BulkPriceAdjustment$k' AND type = 'P')
  DROP PROCEDURE BulkPriceAdjustment$k
GO

CREATE PROCEDURE BulkPriceAdjustment$k
  (
  \@batch_size           INT,
  \@category             INT
  )
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE \@adjustment_factor DECIMAL(5,4);

    -- Generate random adjustment factor (0.75 to 1.25, ±25%)
    SET \@adjustment_factor = 0.75 + (RAND() * 0.50);

    -- Update batch_size random products in selected category
    WITH RandomProducts AS (
        SELECT TOP (\@batch_size) PROD_ID
        FROM PRODUCTS$k WITH (READPAST)
        WHERE CATEGORY = \@category
        ORDER BY NEWID()
    )
    UPDATE PRODUCTS$k WITH (READPAST)
    SET PRICE = FLOOR(PRICE * \@adjustment_factor) + 0.77
    WHERE PROD_ID IN (SELECT PROD_ID FROM RandomProducts);

    SELECT \@\@ROWCOUNT;
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'MarkSpecials$k' AND type = 'P')
  DROP PROCEDURE MarkSpecials$k
GO

CREATE PROCEDURE MarkSpecials$k
  (
  \@prod_id             INT
  )
AS
BEGIN
    SET NOCOUNT ON;

    -- Toggle SPECIAL flag (0→1 or 1→0)
    -- Simulates rotating promotions/featured items
    UPDATE PRODUCTS$k WITH (READPAST)
    SET SPECIAL = CASE WHEN SPECIAL = 1 THEN 0 ELSE 1 END
    WHERE PROD_ID = \@prod_id;

    SELECT \@\@ROWCOUNT;
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'ExpireMemberships$k' AND type = 'P')
  DROP PROCEDURE ExpireMemberships$k
GO

CREATE PROCEDURE ExpireMemberships$k
  (
  \@batch_size          INT
  )
AS
BEGIN
    SET NOCOUNT ON;

    -- Delete expired memberships (oldest first)
    -- Simulates cleanup of lapsed subscriptions
    DELETE FROM MEMBERSHIP$k
    WHERE CUSTOMERID IN (
        SELECT TOP (\@batch_size) CUSTOMERID
        FROM MEMBERSHIP$k WITH (READPAST)
        WHERE EXPIREDATE < GETDATE()
        ORDER BY EXPIREDATE ASC
    );

    SELECT \@\@ROWCOUNT;
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'PurgeOldOrders$k' AND type = 'P')
  DROP PROCEDURE PurgeOldOrders$k
GO

CREATE PROCEDURE PurgeOldOrders$k
  (
  \@batch_size          INT
  )
AS
BEGIN
    SET NOCOUNT ON;

    -- Delete oldest orders (data retention policy, GDPR compliance)
    -- ORDERLINES cascade delete via foreign key ON DELETE CASCADE
    DELETE FROM ORDERS$k
    WHERE ORDERID IN (
        SELECT TOP (\@batch_size) ORDERID
        FROM ORDERS$k WITH (READPAST)
        ORDER BY ORDERDATE ASC
    );

    SELECT \@\@ROWCOUNT;
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'UpgradeMembership$k' AND type = 'P')
  DROP PROCEDURE UpgradeMembership$k
GO
CREATE PROCEDURE UpgradeMembership$k
    (
    \@batch_size          INT
    )
AS
BEGIN
    SET NOCOUNT ON;

    -- Time-based slicing: process 1% of customer base per minute
    -- Full coverage every 100 minutes, then repeats (stateless partitioning)
    DECLARE \@current_slice INT = DATEPART(MINUTE, GETDATE()) % 100;

    -- Calculate percentile thresholds for purchase counts in current slice
    DECLARE \@gold_threshold DECIMAL(10,2);
    DECLARE \@silver_threshold DECIMAL(10,2);

    WITH SlicePurchaseCounts AS (
        SELECT COUNT(*) AS purchase_count
        FROM MEMBERSHIP$k m
        INNER JOIN CUST_HIST$k ch ON m.CUSTOMERID = ch.CUSTOMERID
        WHERE m.CUSTOMERID % 100 = \@current_slice
        GROUP BY m.CUSTOMERID
    )
    SELECT TOP 1
        \@gold_threshold = PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY purchase_count) OVER(),
        \@silver_threshold = PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY purchase_count) OVER()
    FROM SlicePurchaseCounts;

    -- Fallback to hardcoded thresholds if no data in slice
    IF \@gold_threshold IS NULL
    BEGIN
        SET \@gold_threshold = 20;
        SET \@silver_threshold = 10;
    END;

    -- Count total purchases per customer, upgrade membership if thresholds met
    -- Gold (3): >= 90th percentile, Silver (2): >= 75th percentile
    -- UPGRADE ONLY - never downgrade
    -- Reward: extend expiration by 180 days when upgrading
    WITH CustomerPurchases AS (
        SELECT TOP (\@batch_size)
            m.CUSTOMERID,
            m.MEMBERSHIPTYPE,
            m.EXPIREDATE,
            COUNT(*) AS products_purchased,
            CASE
                WHEN COUNT(*) >= \@gold_threshold THEN 3  -- Gold (90th percentile)
                WHEN COUNT(*) >= \@silver_threshold THEN 2  -- Silver (75th percentile)
                ELSE m.MEMBERSHIPTYPE
            END AS new_level
        FROM MEMBERSHIP$k m WITH (READPAST)
        INNER JOIN CUST_HIST$k ch ON m.CUSTOMERID = ch.CUSTOMERID
        WHERE m.CUSTOMERID % 100 = \@current_slice
        GROUP BY m.CUSTOMERID, m.MEMBERSHIPTYPE, m.EXPIREDATE
        HAVING CASE
            WHEN COUNT(*) >= \@gold_threshold THEN 3  -- Gold (90th percentile)
            WHEN COUNT(*) >= \@silver_threshold THEN 2  -- Silver (75th percentile)
            ELSE m.MEMBERSHIPTYPE
        END > m.MEMBERSHIPTYPE
    )
    UPDATE m
    SET
        MEMBERSHIPTYPE = cp.new_level,
        EXPIREDATE = CASE
            WHEN m.EXPIREDATE > GETDATE() THEN DATEADD(DAY, 180, m.EXPIREDATE)  -- Active: extend from current
            ELSE DATEADD(DAY, 180, GETDATE())  -- Expired: reactivate from today
        END
    FROM MEMBERSHIP$k m
    INNER JOIN CustomerPurchases cp ON m.CUSTOMERID = cp.CUSTOMERID;

    SELECT \@\@ROWCOUNT AS rows_updated, \@gold_threshold AS gold_threshold, \@silver_threshold AS silver_threshold;
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'PromotionalMembership$k' AND type = 'P')
  DROP PROCEDURE PromotionalMembership$k
GO
CREATE PROCEDURE PromotionalMembership$k
  \@batch_size INT,
  \@rows_affected INT OUTPUT
AS
BEGIN
  SET NOCOUNT ON;

  -- Select random batch of customers using time-based slicing
  -- Cycles through all customers every 100 seconds (slice 0-99)
  DECLARE \@customer_batch TABLE (CUSTOMERID INT);
  DECLARE \@current_slice INT = DATEPART(SECOND, GETDATE()) % 100;

  INSERT INTO \@customer_batch
  SELECT TOP (\@batch_size) CUSTOMERID
  FROM CUSTOMERS$k
  WHERE CUSTOMERID % 100 = \@current_slice
  ORDER BY CUSTOMERID;

  -- MERGE with audit tracking
  MERGE INTO MEMBERSHIP$k AS target
  USING \@customer_batch AS source
    ON target.CUSTOMERID = source.CUSTOMERID

  -- Customer already has membership: upgrade tier or extend expiration
  WHEN MATCHED THEN
    UPDATE SET
      MEMBERSHIPTYPE = CASE
        WHEN target.MEMBERSHIPTYPE = 1 THEN 2
        WHEN target.MEMBERSHIPTYPE = 2 THEN 3
        ELSE 3  -- Already tier 3, stay at tier 3
      END,
      EXPIREDATE = CASE
        WHEN target.MEMBERSHIPTYPE = 3 THEN DATEADD(day, 90, target.EXPIREDATE)  -- Extend tier 3
        ELSE DATEADD(day, 90, GETDATE())  -- Reactivate for tier 1→2 and 2→3 upgrades
      END

  -- Customer doesn't have membership: insert tier 1 with 90-day expiration
  WHEN NOT MATCHED THEN
    INSERT (CUSTOMERID, MEMBERSHIPTYPE, EXPIREDATE)
    VALUES (source.CUSTOMERID, 1, DATEADD(day, 90, GETDATE()))

  -- Capture MERGE operations to audit table
  OUTPUT
    COALESCE(deleted.CUSTOMERID, inserted.CUSTOMERID),
    deleted.MEMBERSHIPTYPE,           -- NULL for INSERT
    inserted.MEMBERSHIPTYPE,
    deleted.EXPIREDATE,               -- NULL for INSERT
    inserted.EXPIREDATE,
    CASE WHEN deleted.CUSTOMERID IS NULL THEN 'INSERT' ELSE 'UPDATE' END,
    GETDATE()
  INTO MEMBERSHIP_PROMO_AUDIT$k (
    CUSTOMERID,
    OLD_TIER,
    NEW_TIER,
    OLD_EXPIREDATE,
    NEW_EXPIREDATE,
    OPERATION_TYPE,
    OPERATION_TIMESTAMP
  );

  SET \@rows_affected = \@\@ROWCOUNT;
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'GetMembershipAnalytics$k' AND type = 'P')
  DROP PROCEDURE GetMembershipAnalytics$k
GO
CREATE PROCEDURE GetMembershipAnalytics$k
AS
BEGIN
  SET NOCOUNT ON;

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
      WHEN m.EXPIREDATE >= GETDATE() THEN c.CUSTOMERID  -- active members only
      ELSE NULL  -- expired members, don't count
    END) AS BIGINT) AS active_member_count,
    CAST(COUNT(DISTINCT CASE
      WHEN m.MEMBERSHIPTYPE IS NOT NULL AND m.EXPIREDATE < GETDATE() THEN c.CUSTOMERID
      ELSE NULL
    END) AS BIGINT) AS expired_member_count,
    CAST(ISNULL(SUM(co.order_count), 0) AS BIGINT) AS total_orders,
    ROUND(ISNULL(SUM(co.total_revenue), 0), 2) AS total_revenue
  FROM CUSTOMERS$k c
  LEFT JOIN MEMBERSHIP$k m ON c.CUSTOMERID = m.CUSTOMERID
  LEFT JOIN CustomerOrders co ON c.CUSTOMERID = co.CUSTOMERID
  GROUP BY m.MEMBERSHIPTYPE
  ORDER BY CASE WHEN m.MEMBERSHIPTYPE IS NULL THEN -1 ELSE m.MEMBERSHIPTYPE END DESC;
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'GetNewCustomerAnalytics$k' AND type = 'P')
  DROP PROCEDURE GetNewCustomerAnalytics$k
GO
CREATE PROCEDURE GetNewCustomerAnalytics$k
  \@customers_baseline BIGINT
AS
BEGIN
  SET NOCOUNT ON;

  WITH NewCustomerStats AS (
    SELECT
      CAST(COUNT(DISTINCT c.CUSTOMERID) AS BIGINT) AS Created,
      CAST(COUNT(DISTINCT CASE WHEN o.OrderCount >= 2 THEN c.CUSTOMERID END) AS BIGINT) AS TwoPlus,
      CAST(COUNT(DISTINCT CASE WHEN o.OrderCount > 2 THEN c.CUSTOMERID END) AS BIGINT) AS ThreePlus,
      CAST(ISNULL(SUM(o.OrderCount), 0) AS BIGINT) AS TotalOrders
    FROM CUSTOMERS$k c
    LEFT JOIN (
      SELECT CUSTOMERID,
             COUNT(*) AS OrderCount
      FROM ORDERS$k
      WHERE CUSTOMERID > \@customers_baseline
      GROUP BY CUSTOMERID
    ) o ON c.CUSTOMERID = o.CUSTOMERID
    WHERE c.CUSTOMERID > \@customers_baseline
  )
  SELECT Created, TwoPlus, ThreePlus, TotalOrders
  FROM NewCustomerStats;
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'GetReviewAnalytics$k' AND type = 'P')
  DROP PROCEDURE GetReviewAnalytics$k
GO
CREATE PROCEDURE GetReviewAnalytics$k
  \@reviewid_baseline BIGINT
AS
BEGIN
  SET NOCOUNT ON;

  WITH ReviewStats AS (
    SELECT
      STARS,
      COUNT(*) AS Reviews,
      SUM(CASE WHEN REVIEW_ID > \@reviewid_baseline THEN 1 ELSE 0 END) AS Added,
      ISNULL(AVG(CAST(TOTAL_HELPFULNESS AS DECIMAL(10,1))), 0) AS AvgHelp,
      SUM(CASE WHEN TOTAL_HELPFULNESS >= 20 THEN 1 ELSE 0 END) AS HighHelp,
      SUM(CASE WHEN TOTAL_HELPFULNESS < 5 THEN 1 ELSE 0 END) AS LowHelp
    FROM REVIEWS$k
    GROUP BY STARS
  )
  SELECT
    STARS,
    CAST(Reviews AS BIGINT) AS Reviews,
    CAST(Added AS BIGINT) AS Added,
    CAST(AvgHelp AS DECIMAL(10,1)) AS AvgHelp,
    CAST(HighHelp AS BIGINT) AS HighHelp,
    CAST(LowHelp AS BIGINT) AS LowHelp
  FROM ReviewStats
  ORDER BY STARS DESC;
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'GetPricePointAnalytics$k' AND type = 'P')
  DROP PROCEDURE GetPricePointAnalytics$k
GO
CREATE PROCEDURE GetPricePointAnalytics$k
  \@baseline_product_count BIGINT
AS
BEGIN
  SET NOCOUNT ON;

  -- Result Set 1: Price point distribution
  SELECT
    CASE
      WHEN (CAST(PRICE * 100 AS INT) % 100) = 99 THEN '.99'
      WHEN (CAST(PRICE * 100 AS INT) % 100) = 77 THEN '.77'
      WHEN (CAST(PRICE * 100 AS INT) % 100) = 1 THEN '.01'
      ELSE 'Other'
    END AS PriceEnding,
    CAST(COUNT(*) AS BIGINT) AS ProductCount
  FROM PRODUCTS$k
  GROUP BY
    CASE
      WHEN (CAST(PRICE * 100 AS INT) % 100) = 99 THEN '.99'
      WHEN (CAST(PRICE * 100 AS INT) % 100) = 77 THEN '.77'
      WHEN (CAST(PRICE * 100 AS INT) % 100) = 1 THEN '.01'
      ELSE 'Other'
    END
  ORDER BY
    CASE
      CASE
        WHEN (CAST(PRICE * 100 AS INT) % 100) = 99 THEN '.99'
        WHEN (CAST(PRICE * 100 AS INT) % 100) = 77 THEN '.77'
        WHEN (CAST(PRICE * 100 AS INT) % 100) = 1 THEN '.01'
        ELSE 'Other'
      END
      WHEN '.99' THEN 1
      WHEN '.77' THEN 2
      WHEN '.01' THEN 3
      ELSE 4
    END;

  -- Result Set 2: New products purchased count
  SELECT CAST(COUNT(DISTINCT PROD_ID) AS BIGINT) AS NewProductsPurchased
  FROM CUST_HIST$k
  WHERE PROD_ID > \@baseline_product_count;
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'GetInventoryAnalytics$k' AND type = 'P')
  DROP PROCEDURE GetInventoryAnalytics$k
GO
CREATE PROCEDURE GetInventoryAnalytics$k
AS
BEGIN
  SET NOCOUNT ON;

  SELECT
    CAST(COUNT(CASE WHEN QUAN_IN_STOCK < 10 THEN 1 END) AS BIGINT) AS LowStockCount,
    CAST(COUNT(CASE WHEN QUAN_IN_STOCK > 100 THEN 1 END) AS BIGINT) AS HighStockCount,
    CAST((SELECT COUNT(*) FROM REORDER$k) AS BIGINT) AS ReorderCount,
    AVG(CAST(QUAN_IN_STOCK AS DECIMAL(10,1))) AS AvgInventory,
    CAST(COUNT(CASE WHEN SALES = 0 THEN 1 END) AS BIGINT) AS DeadStock,
    CAST(COUNT(CASE WHEN SALES BETWEEN 1 AND 999 THEN 1 END) AS BIGINT) AS LowSales,
    CAST(COUNT(CASE WHEN SALES BETWEEN 1000 AND 1499 THEN 1 END) AS BIGINT) AS MedSales,
    CAST(COUNT(CASE WHEN SALES >= 1500 THEN 1 END) AS BIGINT) AS HighSales,
    CAST(COUNT(*) AS BIGINT) AS TotalProducts
  FROM INVENTORY$k;
END
GO

\n";
  close $OUT;
}

sleep (1);
  
  foreach my $k (1 .. ($numberofstores-1)){
  system ("$startcmd sqlcmd -C -S $sqlservertarget -U sa -P $password -i $sqlservertargetdir${pathsep}sqlserver_ds_createsp$k.sql");
  }
  system ("sqlcmd -C -S $sqlservertarget -U sa -P $password -i $sqlservertargetdir${pathsep}sqlserver_ds_createsp$numberofstores.sql");
