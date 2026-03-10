REM  pgsql_ds_create_all.bat
REM Must set PGPASSWORD environment variable to ds3
set PGPASSWORD=ds3
REM Syntax to run - sh pgsql_ds_create_all.bat <psql_target> <number_of_stores>
REM start in ./ds36/pgsql
cd build/
perl pgsql_ds_perl_logout_all.pl %1
perl pgsql_ds_perl_create_db_tables_multi.pl %1 %2
perl pgsql_ds_perl_create_sp_multi.pl %1 %2
cd ../load/
perl ds_create_pgsql_multistore_load_files.pl %1 %2
perl ds_execute_pgsql_multistore_load.pl %1 %2
cd ../build/
perl pgsql_ds_perl_create_indexes_multi.pl %1 %2
perl pgsql_ds_perl_create_triggers.pl %1 %2
perl pgsql_ds_perl_reset_sequences.pl %1 %2
cd ../
