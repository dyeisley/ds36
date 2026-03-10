# mysql_ds_create_all.sh
# Syntax to run - sh mysql_ds_create_all.sh <mysql_target> <number_of_stores> <use_vectors>
# start in ./ds36/mysql

TARGET=${1:-`hostname`}
STORES=${2:-1}
VECTORS=${3:-0}

cd build
perl mysql_ds_perl_create_db_tables_multi.pl $TARGET $STORES $VECTORS
perl mysql_ds_perl_create_sp_multi.pl $TARGET $STORES $VECTORS
cd ../load/
perl ds_create_mysql_multistore_load_files.pl $TARGET $STORES $VECTORS
perl ds_execute_mysql_multistore_load.pl $TARGET $STORES $VECTORS
cd ../build
perl mysql_ds_perl_create_indexes_multi.pl $TARGET $STORES $VECTORS
perl mysql_ds_perl_create_trigger_multi.pl $TARGET $STORES $VECTORS
cd ../

