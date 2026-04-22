# mysql_ds_perl_create_indexes_multi.pl
# Script to create a ds3 indexes in MySQL with a provided number of copies - supporting multiple stores
# Syntax to run - perl mysqlds3_perl_create_indexes_multi.pl <mysql_target> <number_of_stores> <use_vectors>

use strict;
use warnings;

my $mysqltarget = $ARGV[0];
my $numberofstores = $ARGV[1];
my $use_vectors = $ARGV[2];

my $pathsep;
my $mybackground;
my $indexfile;

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
   $mybackground = "&";
   if ($use_vectors == 1)
   {
      $mybackground = "";
   } 
}
else
{
   $pathsep = "\\\\";
   $mybackground = "";
};

foreach my $k (1 .. $numberofstores){
        $indexfile="mysql_ds_create_customer_indexes$k.sql";
	open (my $OUT, ">$mysql_targetdir${pathsep}$indexfile") || die("Can't open $mysql_targetdir${pathsep}$indexfile");
	print $OUT  "-- Tables
USE DS3;

CREATE UNIQUE INDEX IX_CUST_USERNAME$k ON CUSTOMERS$k
  (
  USERNAME
  );

CREATE UNIQUE INDEX IX_CUST_UN_PW$k ON CUSTOMERS$k
  (
  USERNAME,
  PASSWORD
  );

CREATE INDEX IX_CUST_HIST_CUSTOMERID_PRODID$k ON CUST_HIST$k
   (
   CUSTOMERID,
   PROD_ID
   );

SET FOREIGN_KEY_CHECKS=0;

ALTER TABLE CUST_HIST$k
  ADD CONSTRAINT FK_CUST_HIST_CUSTOMERID$k FOREIGN KEY (CUSTOMERID)
  REFERENCES CUSTOMERS$k (CUSTOMERID)
  ON DELETE CASCADE
  ;

SET FOREIGN_KEY_CHECKS=1;
\n";
  close $OUT;
  sleep(1);
  print ("mariadb -h $mysqltarget -u web --password=web < $mysql_targetdir${pathsep}$indexfile\n");
  system ("mariadb -h $mysqltarget -u web --password=web < $mysql_targetdir${pathsep}$indexfile $mybackground");
  }

foreach my $k (1 .. $numberofstores){
        $indexfile="mysql_ds_create_orders_indexes$k.sql";
	open (my $OUT, ">$mysql_targetdir${pathsep}$indexfile") || die("Can't open $mysql_targetdir${pathsep}$indexfile");
	print $OUT  "-- Tables
USE DS3;
CREATE INDEX IX_ORDER_CUSTID$k ON ORDERS$k
  (
  CUSTOMERID
  );

SET FOREIGN_KEY_CHECKS=0;

ALTER TABLE ORDERS$k
  ADD CONSTRAINT FK_CUSTOMERID$k FOREIGN KEY (CUSTOMERID)
  REFERENCES CUSTOMERS$k (CUSTOMERID)
  ON DELETE SET NULL
  ;

SET FOREIGN_KEY_CHECKS=1;

CREATE UNIQUE INDEX IX_ORDERLINES_ORDERID$k ON ORDERLINES$k
  (
  ORDERID, ORDERLINEID
  );

SET FOREIGN_KEY_CHECKS=0;

ALTER TABLE ORDERLINES$k
  ADD CONSTRAINT FK_ORDERID$k FOREIGN KEY (ORDERID)
  REFERENCES ORDERS$k (ORDERID)
  ON DELETE CASCADE
  ;

SET FOREIGN_KEY_CHECKS=1;
\n";
  close $OUT;
  sleep(1);
  print ("mariadb -h $mysqltarget -u web --password=web < $mysql_targetdir${pathsep}$indexfile\n");
  system ("mariadb -h $mysqltarget -u web --password=web < $mysql_targetdir${pathsep}$indexfile $mybackground");
  }

foreach my $k (1 .. $numberofstores){
        $indexfile="mysql_ds_create_products_indexes$k.sql";
	open (my $OUT, ">$mysql_targetdir${pathsep}$indexfile") || die("Can't open $mysql_targetdir${pathsep}$indexfile");
	print $OUT  "-- Tables
USE DS3;
CREATE FULLTEXT INDEX IX_PROD_ACTOR$k ON PRODUCTS$k
  (
  ACTOR
  );

CREATE INDEX IX_PROD_CATEGORY$k ON PRODUCTS$k
  (
  CATEGORY
  );

CREATE INDEX IX_PROD_CAT_SPECIAL$k ON PRODUCTS$k
  (
  CATEGORY,
  SPECIAL
  );

CREATE FULLTEXT INDEX IX_PROD_TITLE$k ON PRODUCTS$k
  (
  TITLE
  );

CREATE INDEX IX_PROD_SPECIAL$k ON PRODUCTS$k
  (
  SPECIAL
  );

CREATE INDEX IX_INV_PROD_ID$k ON INVENTORY$k
  (
  PROD_ID
  );

ALTER TABLE INVENTORY$k
ADD CONSTRAINT fk_inventory_product$k
FOREIGN KEY (PROD_ID)
REFERENCES PRODUCTS$k(PROD_ID)
ON DELETE CASCADE;

\n";

if ($use_vectors == 1)
{
print $OUT
"\nCREATE VECTOR INDEX idx_v_prod ON PRODUCTS$k(v_embedding) M=16 DISTANCE=cosine;\n"
}

  close $OUT;
  sleep(1);
  print ("mariadb -h $mysqltarget -u web --password=web < $mysql_targetdir${pathsep}$indexfile\n");
  system ("mariadb -h $mysqltarget -u web --password=web < $mysql_targetdir${pathsep}$indexfile $mybackground");
  }

foreach my $k (1 .. $numberofstores){
        $indexfile="mysql_ds_create_membership_indexes$k.sql";
	open (my $OUT, ">$mysql_targetdir${pathsep}$indexfile") || die("Can't open $mysql_targetdir${pathsep}$indexfile");
	print $OUT  "-- Tables
USE DS3;
SET FOREIGN_KEY_CHECKS=0;

ALTER TABLE MEMBERSHIP$k
  ADD CONSTRAINT FK_MEMBERSHIP_CUSTID$k FOREIGN KEY (CUSTOMERID)
  REFERENCES CUSTOMERS$k (CUSTOMERID)
  ON DELETE CASCADE
  ;

SET FOREIGN_KEY_CHECKS=1;
\n";
  close $OUT;
  sleep(1);
  print ("mariadb -h $mysqltarget -u web --password=web < $mysql_targetdir${pathsep}$indexfile\n");
  system ("mariadb -h $mysqltarget -u web --password=web < $mysql_targetdir${pathsep}$indexfile $mybackground");
  }

foreach my $k (1 .. $numberofstores){
        $indexfile="mysql_ds_create_review_indexes$k.sql";
	open (my $OUT, ">$mysql_targetdir${pathsep}$indexfile") || die("Can't open $mysql_targetdir${pathsep}$indexfile");
	print $OUT  "-- Tables
USE DS3;

CREATE INDEX IX_REVIEWS_PROD_HELP$k ON REVIEWS$k
  (
  PROD_ID,
  total_helpfulness DESC
  );

CREATE INDEX IX_REVIEWS_PRODSTARS_HELP$k on REVIEWS$k
  (
  PROD_ID,
  STARS,
  total_helpfulness DESC
  );

CREATE INDEX IX_REVIEWS_PROD_DATE$k ON REVIEWS$k
  (
  PROD_ID,
  REVIEW_DATE DESC
  );

CREATE INDEX idx_reviews_helpfulness$k ON REVIEWS$k
  (
  total_helpfulness
  );

SET FOREIGN_KEY_CHECKS=0;

ALTER TABLE REVIEWS$k
  ADD CONSTRAINT FK_REVIEW_CUSTOMERID$k FOREIGN KEY (CUSTOMERID)
  REFERENCES CUSTOMERS$k (CUSTOMERID)
  ON DELETE CASCADE
  ;

ALTER TABLE REVIEWS$k
  ADD CONSTRAINT FK_REVIEW_PRODID$k FOREIGN KEY (PROD_ID)
  REFERENCES PRODUCTS$k (PROD_ID)
  ON DELETE CASCADE
  ;

SET FOREIGN_KEY_CHECKS=1;
\n";
  close $OUT;
  sleep(1);
  print ("mariadb -h $mysqltarget -u web --password=web < $mysql_targetdir${pathsep}$indexfile\n");
  system ("mariadb -h $mysqltarget -u web --password=web < $mysql_targetdir${pathsep}$indexfile");
  }

foreach my $k (1 .. $numberofstores){
        $indexfile="mysql_ds_create_review_helpfulness_indexes$k.sql";
	open (my $OUT, ">$mysql_targetdir${pathsep}$indexfile") || die("Can't open $mysql_targetdir${pathsep}$indexfile");
	print $OUT  "-- Tables
USE DS3;

CREATE INDEX IX_REVIEWS_HELP_CUSTID$k on REVIEWS_HELPFULNESS$k
  (
  CUSTOMERID
  );

CREATE INDEX IX_REVIEW_HELP_ID_HELPID$k ON REVIEWS_HELPFULNESS$k
  (
  REVIEW_ID,
  REVIEWS_HELPFULNESS_ID
  );

SET FOREIGN_KEY_CHECKS=0;

ALTER TABLE REVIEWS_HELPFULNESS$k
  ADD CONSTRAINT FK_REVIEW_ID$k FOREIGN KEY (REVIEW_ID)
  REFERENCES REVIEWS$k (REVIEW_ID)
  ON DELETE CASCADE
  ;

SET FOREIGN_KEY_CHECKS=1;

CREATE INDEX IX_REORDER_PRODID$k on REORDER$k
  (
  PROD_ID
  );
\n";
  close $OUT;
  sleep(1);
  print ("mariadb -h $mysqltarget -u web --password=web < $mysql_targetdir${pathsep}$indexfile\n");
  system ("mariadb -h $mysqltarget -u web --password=web < $mysql_targetdir${pathsep}$indexfile");
}
