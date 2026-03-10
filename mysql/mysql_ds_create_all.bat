REM mysql_ds_create_all.bat
REM Syntax to run - mysql_ds_create_all.bat <mysql_target> <number_of_stores>
REM start in ./ds36/mysql
cd build
perl mysql_ds_perl_create_db_tables_multi.pl %1 %2
perl mysql_ds_perl_create_indexes_multi.pl %1 %2
perl mysql_ds_perl_create_sp_multi.pl %1 %2
cd ../load/
perl ds_create_mysql_multistore_load_files.pl %1 %2
perl ds_execute_mysql_multistore_load.pl %1 %2
cd ..
