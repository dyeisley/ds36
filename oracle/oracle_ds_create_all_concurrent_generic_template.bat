REM oracle_ds_create_all_concurrent.bat
REM start in ./ds36/oracle
REM syntax is: oracle_ds_create_all_concurrent.bat <oracledbtarget> <number of stores>
cd build
sqlplus "sys/oracle@%1 as sysdba" @oracle_ds_prep_create_db.sql
sqlplus "sys/oracle@%1 as sysdba" @oracle_ds_drop_tablespaces.sql
sqlplus "sys/oracle@%1 as sysdba" @{TBLSPACE_SQLFNAME}
perl oracle_ds_perl_create_db_tables_multi.pl %1 %2
REM perl {CREATEDB_SQLFNAME} %1 %2
sqlplus "sys/oracle@%1 as sysdba" @oracle_ds_create_datatypes.sql
cd ..\load
perl ds_create_oracle_multistore_ctl_files.pl %1 %2
perl ds_execute_oracle_multistore_sqlldr.pl %1 %2
REM sleep 60
cd ..\build
perl oracle_ds_perl_create_seq_multi.pl %1 %2
perl oracle_ds_perl_create_indexes_multi.pl %1 %2
perl oracle_ds_perl_create_fulltextindex_multi.pl %1 %2
perl oracle_ds_perl_create_sp_multi.pl %1 %2
perl oracle_ds_perl_analyze_all_multi.pl %1 %2
cd ..

