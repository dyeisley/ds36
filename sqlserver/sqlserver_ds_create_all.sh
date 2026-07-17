# start in ./ds36/sqlserver
# Syntax is: remote_sqlserver_ds_create_all_concurrent.sh <sqlserverdbtarget> <number of stores> <password> <use_vectors>
# Assumes sqlcmd is in PATH.

TARGET=${1:-`hostname`}
STORES=${2:-1}
PASSWORD=${3:-password}
USEVECTORS=${4:-0}

if [ $STORES -gt 16 ]
then
   echo "Number of STORES limited to 16."
   STORES=16
fi

# Remove the double quotes from the vector data.
perl -i -pe 's/"//g' ../data_files/prod/prod.csv

cd build
echo sqlcmd -C -S $TARGET -U sa -P $PASSWORD -i sqlserver_ds_create_all_init.sql
sqlcmd -C -S $TARGET -U sa -P $PASSWORD -i sqlserver_ds_create_all_init.sql

echo perl sqlserver_ds_perl_create_db_tables_multi.pl $TARGET $STORES $PASSWORD
perl sqlserver_ds_perl_create_db_tables_multi.pl $TARGET $STORES $PASSWORD $USEVECTORS

cd ../load
echo perl linux_ds_create_sqlserver_multistore_load_files.pl $TARGET $STORES $PASSWORD
perl linux_ds_create_sqlserver_multistore_load_files.pl $TARGET $STORES $PASSWORD

echo perl linux_ds_execute_sqlserver_multistore_load.pl $TARGET $STORES $PASSWORD
perl linux_ds_execute_sqlserver_multistore_load.pl $TARGET $STORES $PASSWORD

cd ../build
echo sqlcmd -C -S $TARGET -U sa -P $PASSWORD -i sqlserver_ds_shrinklog.sql
sqlcmd -C -S $TARGET -U sa -P $PASSWORD -i sqlserver_ds_shrinklog.sql

echo perl sqlserver_ds_perl_create_indexes_multi.pl $TARGET $STORES $PASSWORD
perl sqlserver_ds_perl_create_indexes_multi.pl $TARGET $STORES $PASSWORD $USEVECTORS

echo perl sqlserver_ds_perl_create_sp_multi.pl $TARGET $STORES $PASSWORD
perl sqlserver_ds_perl_create_sp_multi.pl $TARGET $STORES $PASSWORD $USEVECTORS

echo sqlcmd -C -S $TARGET -U sa -P $PASSWORD -i sqlserver_ds_create_user.sql
sqlcmd -C -S $TARGET -U sa -P $PASSWORD -i sqlserver_ds_create_user.sql

cd ../validate
echo perl sqlserver_ds_perl_validate_multi.pl $TARGET $STORES $PASSWORD pre_test
perl sqlserver_ds_perl_validate_multi.pl $TARGET $STORES $PASSWORD pre_test both > pre_test.txt
perl sqlserver_ds_perl_validate_multi.pl $TARGET $STORES $PASSWORD post_test generate > generate_post_test.txt

cd ../
