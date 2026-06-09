# DVD Store Multi-Database Orchestrator

Launches multiple database drivers simultaneously for side-by-side performance comparison.

## Overview

Instead of combining all database types into one executable (complex), the orchestrator:
- Keeps the 4 separate executables simple and focused
- Launches them in parallel with identical workload parameters
- Monitors progress in real-time
- Collects output for comparison

## Usage

**Step 1: Build database driver binaries**
```bash
# MySQL
cd mysql && dotnet publish -c Release -o .

# SQL Server
cd ../sqlserver && dotnet publish -c Release -o .

# PostgreSQL
cd ../pgsql && dotnet publish -c Release -o .

# Oracle
cd ../oracle && dotnet publish -c Release -o .
```

This creates standalone executables:
- Linux: `mysql/mysql_ds`, `sqlserver/sqlserver_ds`, etc.
- Windows: `mysql/mysql_ds.exe`, `sqlserver/sqlserver_ds.exe`, etc.

**Step 2: Run orchestrator**
```bash
cd orchestrator
dotnet run example_config.txt
```

## Config File Format

See `example_config.txt` for a complete example.

**Common parameters** (applied to all databases):
```ini
run_time=10
n_threads=16
analytics_interval=2
enable_managers=Y
...
```

**Database targets** (one or more):
```ini
target_1=mysql/ds36mysqldriverlinux:10.31.46.50
target_2=sqlserver/ds36sqlserverdriverlinux:10.31.46.51
target_3=pgsql/ds36pgsqllinuxdriver:10.31.46.52
target_4=oracle/ds36oraclelinuxdriver:10.31.46.53
```

Format: `path/to/executable:hostname`

Database type is auto-detected from the directory name in the path (e.g., `mysql/` → type is "mysql").

## How It Works

1. **Parse config** - Read common parameters and database targets
2. **Create temp configs** - Generate individual config file for each database driver
3. **Launch in parallel** - Start all drivers simultaneously using `Task.WhenAll`
4. **Monitor output** - Prefix each driver's output with `[dbtype]` label
5. **Collect results** - Each driver writes validation output to separate files
6. **Report summary** - Show which drivers completed successfully

## Output Files

Each database driver creates its own output files:

**In orchestrator directory:**
- `mysql_hostname_output.log` - Full stdout/stderr from MySQL driver
- `sqlserver_hostname_output.log` - Full stdout/stderr from SQL Server driver
- `pgsql_hostname_output.log` - Full stdout/stderr from PostgreSQL driver

Note: Filenames include hostname to support running against multiple instances of the same database type.

**In database directories (if validation enabled):**
- `mysql/validation_mysql_store1of1_timestamp.txt` - MySQL validation results
- `sqlserver/validation_sqlserver_store1of1_timestamp.txt` - SQL Server validation results
- `pgsql/validation_pgsql_store1of1_timestamp.txt` - PostgreSQL validation results
- `oracle/validation_oracle_store1of1_timestamp.txt` - Oracle validation results

## Validation

By default, `validate_post_test=N` to avoid requiring database CLI tools.

**To enable validation (`validate_post_test=Y`):**

1. **Generate validation SQL** for each database:
   ```bash
   cd mysql/validate
   perl mysql_ds_perl_validate_multi.pl 10.31.46.50 1 post_test generate
   
   cd ../../sqlserver/validate
   perl sqlserver_ds_perl_validate_multi.pl 10.31.46.51 1 post_test generate
   
   cd ../../pgsql/validate
   perl pgsql_ds_perl_validate_multi.pl 10.31.46.52 1 post_test generate
   
   cd ../../oracle/validate
   perl oracle_ds_perl_validate_multi.pl 10.31.46.53 1 post_test generate
   ```

2. **Install required CLI tools** (orchestrator machine only):
   - MySQL: Uses ADO.NET connection (no local tool needed)
   - SQL Server: Uses ADO.NET connection (no local tool needed)
   - PostgreSQL: Uses ADO.NET connection (no local tool needed)
   - **Oracle: Requires `sqlplus` installed and in PATH**

**Note:** MySQL, SQL Server, and PostgreSQL validation execute SQL remotely via network connections. Oracle validation calls `sqlplus` as an external process, so it must be installed locally on the orchestrator machine.

## Comparison

After all drivers complete, the orchestrator automatically parses output logs and displays a comprehensive comparison table showing:
- **Database Performance** - OPM, average response time, rollback %, total orders
- **Analytics Performance** - Response times for all enabled analytics operations
- **Manager Operations Performance** - Response times for all 11 manager operations

Individual log files are also available for detailed analysis:
```bash
grep "Orders Per Minute:" mysql_hostname_output.log
grep "GetMembershipAnalytics:" sqlserver_hostname_output.log
```
