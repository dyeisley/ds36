# oracleds3_perl_create_indexes_multi.pl
# Script to create a ds3 indexes in oracle with a provided number of copies - supporting multiple stores
# Syntax to run - perl oracleds3_perl_create_indexes_multi.pl <oracle_target> <number_of_stores> 

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
	open (my $OUT, ">$oracletargetdir${pathsep}oracle_ds_createindexes$k.sql") || die("Can't open oracle_ds_indexes$k.sql");
	print $OUT "CREATE UNIQUE INDEX \"DS3\".\"PK_CUSTOMERS$k\" 
  ON \"DS3\".\"CUSTOMERS$k\"  (\"CUSTOMERID\")
  PARALLEL ( DEGREE DEFAULT )
  TABLESPACE \"INDXTBS\" 
  ;

ALTER TABLE \"DS3\".\"CUSTOMERS$k\"
  ADD (CONSTRAINT \"PK_CUSTOMERS$k\" PRIMARY KEY(\"CUSTOMERID\"))
  ;

-- CHANGED: Composite index for LOGIN query (USERNAME + PASSWORD)
CREATE UNIQUE INDEX \"DS3\".\"IX_CUST_UN_PW$k\"
  ON \"DS3\".\"CUSTOMERS$k\"  (\"USERNAME\", \"PASSWORD\")
  PARALLEL ( DEGREE DEFAULT )
  TABLESPACE \"INDXTBS\"
  ;

CREATE INDEX \"DS3\".\"PK_CUST_HIST$k\"
  ON \"DS3\".\"CUST_HIST$k\" (\"CUSTOMERID\")
  PARALLEL ( DEGREE DEFAULT )
  TABLESPACE \"INDXTBS\"
  ;

ALTER TABLE \"DS3\".\"CUST_HIST$k\"
  ADD (CONSTRAINT \"FK_CUST_HIST_CUSTOMERID$k\" FOREIGN KEY (\"CUSTOMERID\")
  REFERENCES \"DS3\".\"CUSTOMERS$k\" (\"CUSTOMERID\")
  ON DELETE CASCADE)
  ;

CREATE UNIQUE INDEX \"DS3\".\"PK_ORDERS$k\"
  ON \"DS3\".\"ORDERS$k\"  (\"ORDERID\")
  GLOBAL PARTITION BY HASH (\"ORDERID\")
  PARTITIONS 8 STORE IN (\"INDXTBS\")
  PARALLEL ( DEGREE DEFAULT )
  TABLESPACE \"INDXTBS\"
  ;

ALTER TABLE \"DS3\".\"ORDERS$k\"
  ADD (CONSTRAINT \"PK_ORDERS$k\" PRIMARY KEY(\"ORDERID\"))
  ;

ALTER TABLE \"DS3\".\"ORDERS$k\"
  ADD (CONSTRAINT \"FK_CUSTOMERID$k\" FOREIGN KEY(\"CUSTOMERID\")
    REFERENCES \"DS3\".\"CUSTOMERS$k\"(\"CUSTOMERID\")
    ON DELETE SET NULL)
  ;

CREATE UNIQUE INDEX \"DS3\".\"PK_ORDERLINES$k\"
  ON \"DS3\".\"ORDERLINES$k\"  (\"ORDERID\", \"ORDERLINEID\")
  GLOBAL PARTITION BY HASH (\"ORDERID\",\"ORDERLINEID\")
  PARTITIONS 8 STORE IN (\"INDXTBS\")
  PARALLEL ( DEGREE DEFAULT )
  TABLESPACE \"INDXTBS\"
  ;
ALTER TABLE \"DS3\".\"ORDERLINES$k\"
  ADD (CONSTRAINT \"PK_ORDERLINES$k\" PRIMARY KEY(\"ORDERID\", \"ORDERLINEID\"))
  ;

ALTER TABLE \"DS3\".\"ORDERLINES$k\"
  ADD (CONSTRAINT \"FK_ORDERID$k\" FOREIGN KEY(\"ORDERID\")
    REFERENCES \"DS3\".\"ORDERS$k\"(\"ORDERID\")
    ON DELETE CASCADE)
  ;

CREATE UNIQUE INDEX \"DS3\".\"PK_PROD_ID$k\" 
  ON \"DS3\".\"PRODUCTS$k\"  (\"PROD_ID\")
  PARALLEL ( DEGREE DEFAULT )
  TABLESPACE \"INDXTBS\" 
  ;

ALTER TABLE \"DS3\".\"PRODUCTS$k\"
  ADD (CONSTRAINT \"PK_PROD_ID$k\" PRIMARY KEY(\"PROD_ID\"))
  ;

-- CHANGED: Composite index for BROWSE_BY_CATEGORY query
CREATE INDEX \"DS3\".\"IX_PROD_CAT_SPECIAL$k\"
  ON \"DS3\".\"PRODUCTS$k\"  (\"CATEGORY\", \"SPECIAL\")
  TABLESPACE \"INDXTBS\"
  ;

ALTER TABLE DS3.INVENTORY$k
  ADD CONSTRAINT fk_inventory_product$k
  FOREIGN KEY (PROD_ID) 
  REFERENCES PRODUCTS$k(PROD_ID)
ON DELETE CASCADE
  ;

CREATE INDEX \"DS3\".\"IX_PROD_MEMBERSHIP$k\"
  ON \"DS3\".\"PRODUCTS$k\"  (\"MEMBERSHIP_ITEM\")
  TABLESPACE \"INDXTBS\"
  ;

CREATE INDEX \"DS3\".\"IX_INV_PROD_ID$k\" 
  ON \"DS3\".\"INVENTORY$k\"  (\"PROD_ID\") 
  TABLESPACE \"INDXTBS\"
  ;

CREATE UNIQUE INDEX \"DS3\".\"PK_MEMBERSHIP$k\"
  ON \"DS3\".\"MEMBERSHIP$k\"  (\"CUSTOMERID\")
  PARALLEL ( DEGREE DEFAULT )
  TABLESPACE \"INDXTBS\"
  ;

ALTER TABLE \"DS3\".\"MEMBERSHIP$k\"
  ADD (CONSTRAINT \"PK_MEMBERSHIP$k\" PRIMARY KEY(\"CUSTOMERID\"))
  ;

ALTER TABLE \"DS3\".\"MEMBERSHIP$k\"
  ADD (CONSTRAINT \"FK_MEMBERSHIP_CUSTID$k\" FOREIGN KEY(\"CUSTOMERID\")
    REFERENCES \"DS3\".\"CUSTOMERS$k\"(\"CUSTOMERID\")
    ON DELETE CASCADE)
  ;

CREATE UNIQUE INDEX \"DS3\".\"PK_REVIEWS$k\"
  ON \"DS3\".\"REVIEWS$k\"  (\"REVIEW_ID\")
  PARALLEL ( DEGREE DEFAULT )
  TABLESPACE \"INDXTBS\"
  ;

ALTER TABLE \"DS3\".\"REVIEWS$k\"
  ADD (CONSTRAINT \"PK_REVIEWS$k\" PRIMARY KEY(\"REVIEW_ID\"))
  ;

ALTER TABLE \"DS3\".\"REVIEWS$k\"
  ADD (CONSTRAINT \"FK_PROD_ID$k\" FOREIGN KEY(\"PROD_ID\")
    REFERENCES \"DS3\".\"PRODUCTS$k\"(\"PROD_ID\")
    ON DELETE CASCADE)
  ;

ALTER TABLE \"DS3\".\"REVIEWS$k\"
  ADD (CONSTRAINT \"FK_REVIEW_CUSTOMERID$k\" FOREIGN KEY(\"CUSTOMERID\")
    REFERENCES \"DS3\".\"CUSTOMERS$k\"(\"CUSTOMERID\")
    ON DELETE CASCADE)
  ;

-- CHANGED: Composite index for GET_PROD_REVIEWS query (PROD_ID + TOTAL_HELPFULNESS)
CREATE INDEX \"DS3\".\"IX_REVIEWS_PROD_HELP$k\"
  ON \"DS3\".\"REVIEWS$k\"  (\"PROD_ID\", \"TOTAL_HELPFULNESS\" DESC)
  TABLESPACE \"INDXTBS\"
  ;

-- CHANGED: Composite index for GET_PROD_REVIEWS_BY_STARS query
CREATE INDEX \"DS3\".\"IX_REVIEWS_PRODSTARS_HELP$k\"
  ON \"DS3\".\"REVIEWS$k\" (\"PROD_ID\", \"STARS\", \"TOTAL_HELPFULNESS\" DESC)
  TABLESPACE \"INDXTBS\"
  ;

-- CHANGED: Composite index for GET_PROD_REVIEWS_BY_DATE query
CREATE INDEX \"DS3\".\"IX_REVIEWS_PROD_DATE$k\"
  ON \"DS3\".\"REVIEWS$k\" (\"PROD_ID\", \"REVIEW_DATE\" DESC)
  TABLESPACE \"INDXTBS\"
  ;

-- Kept for backward compatibility / other queries
CREATE INDEX \"DS3\".\"IX_REVIEWS_TOTALHELPFULNESS$k\"
  ON \"DS3\".\"REVIEWS$k\" (\"TOTAL_HELPFULNESS\" DESC)
  TABLESPACE \"INDXTBS\"
  ;

CREATE UNIQUE INDEX \"DS3\".\"PK_REVIEWS_HELPFULNESS$k\"
  ON \"DS3\".\"REVIEWS_HELPFULNESS$k\"  (\"REVIEW_HELPFULNESS_ID\")
  PARALLEL ( DEGREE DEFAULT )
  TABLESPACE \"INDXTBS\"
  ;

ALTER TABLE \"DS3\".\"REVIEWS_HELPFULNESS$k\"
  ADD (CONSTRAINT \"PK_REVIEWS_HELPFULNESS$k\" PRIMARY KEY(\"REVIEW_HELPFULNESS_ID\"))
  ;

ALTER TABLE \"DS3\".\"REVIEWS_HELPFULNESS$k\"
  ADD (CONSTRAINT \"FK_REVIEW_ID$k\" FOREIGN KEY(\"REVIEW_ID\")
    REFERENCES \"DS3\".\"REVIEWS$k\"(\"REVIEW_ID\")
    ON DELETE CASCADE)
  ;

CREATE INDEX \"DS3\".\"IX_REVIEWS_HELP_REVID$k\"
  ON \"DS3\".\"REVIEWS_HELPFULNESS$k\"  (\"REVIEW_ID\")
  TABLESPACE \"INDXTBS\"
  ;

CREATE INDEX \"DS3\".\"IX_REVIEWS_HELP_CUSTID$k\"
  ON \"DS3\".\"REVIEWS_HELPFULNESS$k\"  (\"CUSTOMERID\")
  TABLESPACE \"INDXTBS\"
  ;

CREATE INDEX \"DS3\".\"IX_REORDER_PRODID$k\"
  ON \"DS3\".\"REORDER$k\" (\"PROD_ID\")
  TABLESPACE \"INDXTBS\"
  ;


EXIT;
  \n";
  close $OUT;
  }
  
sleep(1);
  
foreach my $k (1 .. ($numberofstores-1)){
  system ("$startcmd sqlplus -S \"ds3/ds3\@$oracletarget \" \@$oracletargetdir${pathsep}oracle_ds_createindexes$k.sql");
  }
  system ("sqlplus -S \"ds3/ds3\@$oracletarget \" \@$oracletargetdir${pathsep}oracle_ds_createindexes$numberofstores.sql");
