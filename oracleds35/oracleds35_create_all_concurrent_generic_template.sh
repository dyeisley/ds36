#!/bin/sh

# oracleds35_create_all_<DB_SIZE>GB.sh
# Syntax to run - sh oracleds35_create_all_<DB_SIZE>GB.sh <oracle_target> <number_of_stores>
# start in ./ds35/oracleds35

TARGET=${1:-`hostname`}
STORES=${2:-1}

cd build
sqlplus "sys/oracle@$TARGET as sysdba" @oracleds35_drop_tablespaces.sql
sqlplus "sys/oracle@$TARGET as sysdba" @{TBLSPACE_SQLFNAME}
perl {CREATEDB_SQLFNAME} $TARGET $STORES
sqlplus "sys/oracle@$TARGET as sysdba" @oracleds35_create_datatypes.sql
cd ../load
perl linux_ds35_create_oracle_multistore_ctl_files.pl $TARGET $STORES
perl linux_ds35_execute_oracle_multistore_sqlldr.pl $TARGET $STORES
sleep 60
cd ../build
perl oracleds35_perl_create_seq_multi.pl $TARGET $STORES
perl oracleds35_perl_create_indexes_multi.pl $TARGET $STORES
perl oracleds35_perl_create_fulltextindex_multi.pl $TARGET $STORES
perl oracleds35_perl_create_sp_multi.pl $TARGET $STORES
perl oracleds35_perl_analyze_all_multi.pl $TARGET $STORES
cd ..

