use strict;
use warnings;

my $pgsql_target = $ARGV[0];
my $numStores = $ARGV[1];
my $DBNAME = "ds3";
my $SYSDBA = "ds3";
my $PGPASSWORD = "ds3";

my $pathsep;

#Need seperate target directory so that mulitple DB Targets can be loaded at the same time
my $pgsql_targetdir;  

$pgsql_targetdir = $pgsql_target;

# remove any backslashes from string to be used for directory name
$pgsql_targetdir =~ s/\\//;

system ("mkdir -p $pgsql_targetdir");

if ("$^O" eq "linux")
        {
        $pathsep = "/";
        }
else
        {
        $pathsep = "\\\\";
        };

foreach my $k (1 .. $numStores){
        open(my $OUT, ">$pgsql_targetdir${pathsep}pgsql_ds_createtriggers.sql") || die("Can't open pgsql_ds_createtriggers.sql");
        print $OUT "-- Triggers

\\c ds3;

CREATE OR REPLACE FUNCTION RESTOCK_ORDER$k()
RETURNS TRIGGER
LANGUAGE plpgsql
AS \$RESTOCK_ORDER\$
DECLARE
  restockto INTEGER;
BEGIN
  IF ( NEW.QUAN_IN_STOCK < 3) THEN
    restockto = 250;
    IF ( (NEW.PROD_ID +1) % 10000 = 0 ) THEN
      restockto = 2500;
    END IF;
    INSERT INTO REORDER$k ( PROD_ID, DATE_LOW, QUAN_LOW, quan_reordered)
    VALUES ( NEW.PROD_ID, current_timestamp , NEW.QUAN_IN_STOCK, restockto - NEW.QUAN_IN_STOCK);
    NEW.QUAN_IN_STOCK = restockto;
    -- UPDATE INVENTORY$k SET QUAN_IN_STOCK = OLD.QUAN_IN_STOCK WHERE PROD_ID = NEW.PROD_ID;
  END IF;
RETURN NEW;
END;
\$RESTOCK_ORDER\$;

CREATE TRIGGER RESTOCK$k BEFORE UPDATE ON INVENTORY$k
FOR EACH ROW
WHEN (OLD.QUAN_IN_STOCK IS DISTINCT FROM NEW.QUAN_IN_STOCK )
EXECUTE PROCEDURE  RESTOCK_ORDER$k();

CREATE OR REPLACE FUNCTION fn_update_review_helpfulness$k()
RETURNS TRIGGER
LANGUAGE plpgsql
AS \$UPDATEREVIEWHELPFULNESS\$
BEGIN
    UPDATE reviews$k
    SET total_helpfulness = total_helpfulness + NEW.helpfulness
    WHERE review_id = NEW.review_id;

    RETURN NEW;
END;
\$UPDATEREVIEWHELPFULNESS\$;

CREATE TRIGGER after_helpfulness_insert$k
AFTER INSERT ON reviews_helpfulness$k
FOR EACH ROW
EXECUTE FUNCTION fn_update_review_helpfulness$k();

UPDATE reviews$k r
SET total_helpfulness = (
    SELECT COALESCE(SUM(h.helpfulness), 0)
    FROM reviews_helpfulness$k h
    WHERE h.review_id = r.review_id
)
WHERE EXISTS (
    SELECT 1
    FROM reviews_helpfulness$k h
    WHERE h.review_id = r.review_id
);

\n";

close $OUT;
        sleep(1);
        print("psql -h $pgsql_target -U $SYSDBA -d $DBNAME < $pgsql_targetdir${pathsep}pgsql_ds_createtriggers.sql\n");
        system("psql -h $pgsql_target -U $SYSDBA -d $DBNAME < $pgsql_targetdir${pathsep}pgsql_ds_createtriggers.sql");
}



