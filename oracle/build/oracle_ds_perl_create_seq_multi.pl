# oracleds3_perl_create_seq_multi.pl
# Script to create a DS3 sequences script that will create seqences for Reviews and Reviews Helpfulness tables - supporting multiple stores
# Syntax to run - perl oracleds3_perl_create_seq_multi.pl <oracle_target> <number_of_stores> 

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
	open (my $OUT, ">$oracletargetdir${pathsep}oracle_ds_createseq$k.sql") || die("Can't open oracle_ds_createseq$k.sql");
	print $OUT "DECLARE
  CUST_ROWS$k NUMBER;
  ORD_ROWS$k NUMBER;
  REVIEW_ROWS$k NUMBER;
  HELP_ROWS$k NUMBER;
  PROD_ROWS$k NUMBER;

BEGIN

  SELECT count(*) INTO CUST_ROWS$k  from \"DS3\".\"CUSTOMERS$k\";

CUST_ROWS$k := CUST_ROWS$k + 1;

EXECUTE IMMEDIATE '
CREATE SEQUENCE \"DS3\".\"CUSTOMERID_SEQ$k\"
  INCREMENT BY 1
  START WITH ' || CUST_ROWS$k || '
  MAXVALUE 1.0E28
  MINVALUE 1
  NOCYCLE
  CACHE 1000000
  NOORDER'
  ;

  SELECT count(*) INTO ORD_ROWS$k  from \"DS3\".\"ORDERS$k\";

ORD_ROWS$k := ORD_ROWS$k + 1;

EXECUTE IMMEDIATE '
CREATE SEQUENCE \"DS3\".\"ORDERID_SEQ$k\"
  INCREMENT BY 1
  START WITH ' || ORD_ROWS$k || '
  MAXVALUE 1.0E28
  MINVALUE 1
  NOCYCLE
  CACHE 1000000
  NOORDER'
  ;

  SELECT count(*) INTO REVIEW_ROWS$k  from \"DS3\".\"REVIEWS$k\";

REVIEW_ROWS$k := REVIEW_ROWS$k + 1;

EXECUTE IMMEDIATE '
CREATE SEQUENCE \"DS3\".\"REVIEWID_SEQ$k\"
  INCREMENT BY 1
  START WITH ' || REVIEW_ROWS$k || '
  MAXVALUE 1.0E28
  MINVALUE 1
  NOCYCLE
  CACHE 100000
  NOORDER'
  ;

  SELECT count(*) INTO HELP_ROWS$k  from \"DS3\".\"REVIEWS_HELPFULNESS$k\";

HELP_ROWS$k := HELP_ROWS$k + 1;

EXECUTE IMMEDIATE '
CREATE SEQUENCE \"DS3\".\"REVIEWHELPFULNESSID_SEQ$k\"
  INCREMENT BY 1
  START WITH ' || HELP_ROWS$k || '
  MAXVALUE 1.0E28
  MINVALUE 1
  NOCYCLE
  CACHE 100000
  NOORDER'
  ;

  SELECT count(*) INTO PROD_ROWS$k  from \"DS3\".\"PRODUCTS$k\";

PROD_ROWS$k := PROD_ROWS$k + 1;

EXECUTE IMMEDIATE '
CREATE SEQUENCE \"DS3\".\"PROD_SEQ$k\"
  INCREMENT BY 1
  START WITH ' || PROD_ROWS$k || '
  MAXVALUE 1.0E28
  MINVALUE 1
  NOCYCLE
  CACHE 100000
  NOORDER'
  ;

  EXECUTE IMMEDIATE 'CREATE SEQUENCE \"DS3\".\"MERGE_AUDIT_SEQ$k\" START WITH 1 INCREMENT BY 1';

  EXECUTE IMMEDIATE '
CREATE OR REPLACE TRIGGER \"DS3\".\"AUDIT_HELPFULNESS_MERGE$k\"
AFTER INSERT OR UPDATE ON \"DS3\".\"REVIEWS_HELPFULNESS$k\"
FOR EACH ROW
DECLARE
  v_operation VARCHAR2(10);
  v_old_helpfulness NUMBER;
BEGIN
  IF INSERTING THEN
    v_operation := ''INSERT'';
    v_old_helpfulness := NULL;
  ELSIF UPDATING THEN
    v_operation := ''UPDATE'';
    v_old_helpfulness := :OLD.HELPFULNESS;
  END IF;

  INSERT INTO \"DS3\".\"MERGE_AUDIT$k\"
    (AUDIT_ID, TABLE_NAME, OPERATION, REVIEW_HELPFULNESS_ID, REVIEW_ID, CUSTOMERID, OLD_HELPFULNESS, NEW_HELPFULNESS)
  VALUES
    (\"DS3\".\"MERGE_AUDIT_SEQ$k\".NEXTVAL, ''REVIEWS_HELPFULNESS'', v_operation, :NEW.REVIEW_HELPFULNESS_ID, :NEW.REVIEW_ID, :NEW.CUSTOMERID, v_old_helpfulness, :NEW.HELPFULNESS);
END;'
  ;

END;
/

EXIT;
\n";
close $OUT;
  
 }
  
sleep(1);

foreach my $k (1 .. ($numberofstores-1)){
  system ("$startcmd sqlplus -S \"sys/oracle\@$oracletarget as sysdba \" \@$oracletargetdir${pathsep}oracle_ds_createseq$k.sql");
  }
  system ("sqlplus -S \"sys/oracle\@$oracletarget as sysdba \" \@$oracletargetdir${pathsep}oracle_ds_createseq$numberofstores.sql");
