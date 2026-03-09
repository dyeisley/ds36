#!/bin/sh

# oracle_ds_create_all_<DB_SIZE>GB.sh
# Syntax to run - sh oracle_ds_create_all_<DB_SIZE>GB.sh <oracle_target> <number_of_stores>
# start in ./ds36/oracle

TARGET=${1:-`hostname`}
STORES=${2:-1}

cd build
sqlplus "sys/oracle@$TARGET as sysdba" @oracle_ds_drop_tablespaces.sql
sqlplus "sys/oracle@$TARGET as sysdba" @{TBLSPACE_SQLFNAME}
perl {CREATEDB_SQLFNAME} $TARGET $STORES
sqlplus "sys/oracle@$TARGET as sysdba" @oracle_ds_create_datatypes.sql
cd ../load
perl linux_ds_create_oracle_multistore_ctl_files.pl $TARGET $STORES
perl linux_ds_execute_oracle_multistore_sqlldr.pl $TARGET $STORES
sleep 60
cd ../build
perl oracle_ds_perl_create_seq_multi.pl $TARGET $STORES
perl oracle_ds_perl_create_indexes_multi.pl $TARGET $STORES
perl oracle_ds_perl_create_fulltextindex_multi.pl $TARGET $STORES
perl oracle_ds_perl_create_sp_multi.pl $TARGET $STORES
perl oracle_ds_perl_analyze_all_multi.pl $TARGET $STORES
cd ..

