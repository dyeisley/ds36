#!/bin/sh

# oracle_ds_create_all_<DB_SIZE>GB.sh
# Syntax to run - sh oracle_ds_create_all_<DB_SIZE>GB.sh <oracle_target> <number_of_stores> <use_vectors>
# start in ./ds36/oracle

TARGET=${1:-`hostname`}
STORES=${2:-1}
VECTORS=${3:-0}

if [ $STORES -gt 16 ]
then
   echo "Number of STORES limited to 16."
   STORES=16
fi

cd build
sqlplus "sys/oracle@$TARGET as sysdba" @oracle_ds_drop_tablespaces.sql
sqlplus -S "sys/oracle@$TARGET as sysdba" @oracle_ds_create_tablespaces.sql
perl oracle_ds_perl_create_db_tables_multi.pl $TARGET $STORES $VECTORS
sqlplus -S "sys/oracle@$TARGET as sysdba" @oracle_ds_create_datatypes.sql
cd ../load
perl linux_ds_create_oracle_multistore_ctl_files.pl $TARGET $STORES $VECTORS
perl linux_ds_execute_oracle_multistore_sqlldr.pl $TARGET $STORES
sleep 5
cd ../build
perl oracle_ds_perl_create_seq_multi.pl $TARGET $STORES
perl oracle_ds_perl_create_indexes_multi.pl $TARGET $STORES $VECTORS
perl oracle_ds_perl_create_fulltextindex_multi.pl $TARGET $STORES
perl oracle_ds_perl_create_sp_multi.pl $TARGET $STORES $VECTORS
perl oracle_ds_perl_analyze_all_multi.pl $TARGET $STORES
cd ../validate
perl oracle_ds_perl_validate_multi.pl $HOSTNAME $STORES post_test generate > generate_post_test.txt
perl oracle_ds_perl_validate_multi.pl $HOSTNAME $STORES pre_test both > pre_test.txt
cd ..

