# pgsqlds35_create_all.sh
# must set PGPASSWORD environment variable to ds3
export PGPASSWORD=ds3

# Syntax to run - sh pgsqlds35_create_all.sh <psql_target> <number_of_stores>
# start in ./ds35/pgsqlds35

TARGET=${1:-`hostname`}
STORES=${2:-1}

cd build/
perl pgsqlds35_perl_logout_all.pl $TARGET
perl pgsqlds35_perl_create_db_tables_multi.pl $TARGET $STORES
perl pgsqlds35_perl_create_sp_multi.pl $TARGET $STORES
cd ../load/
perl ds35_create_pgsql_multistore_load_files.pl $TARGET $STORES
perl ds35_execute_pgsql_multistore_load.pl $TARGET $STORES
cd ../build/
perl pgsqlds35_perl_create_indexes_multi.pl $TARGET $STORES
perl pgsqlds35_perl_create_triggers.pl $TARGET $STORES
perl pgsqlds35_perl_reset_sequences.pl $TARGET $STORES
cd ../
