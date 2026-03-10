# pgsql_ds_create_all.sh
# must set PGPASSWORD environment variable to ds3
export PGPASSWORD=ds3

# Syntax to run - sh pgsql_ds_create_all.sh <psql_target> <number_of_stores>
# start in ./ds36/pgsql

TARGET=${1:-`hostname`}
STORES=${2:-1}

cd build/
perl pgsql_ds_perl_logout_all.pl $TARGET
perl pgsql_ds_perl_create_db_tables_multi.pl $TARGET $STORES
perl pgsql_ds_perl_create_sp_multi.pl $TARGET $STORES
cd ../load/
perl ds_create_pgsql_multistore_load_files.pl $TARGET $STORES
perl ds_execute_pgsql_multistore_load.pl $TARGET $STORES
cd ../build/
perl pgsql_ds_perl_create_indexes_multi.pl $TARGET $STORES
perl pgsql_ds_perl_create_triggers.pl $TARGET $STORES
perl pgsql_ds_perl_reset_sequences.pl $TARGET $STORES
cd ../
