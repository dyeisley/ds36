# Quick Start

## Prerequisites

- A supported database installed and running (MySQL, PostgreSQL, SQL Server, or Oracle)
- Perl
- .NET SDK (check `dotnet --version`)
- `gcc` (Linux only, for compiling data generation programs)
- Database client tools in PATH (`mariadb`/`mysql`, `psql`, `sqlcmd`, or `sqlplus`)

## Step 1: Generate Data

From the `ds36/` directory:

```
perl Install_DVDStore.pl
```

The script prompts for database type, size (e.g., `4 GB`), and platform. It compiles the C data generation programs, creates CSV data files, and generates database-specific SQL scripts.

## Step 2: Load the Database

Change to your database directory and run the build script, passing the target hostname and number of stores:

```
cd mysql && bash mysql_ds_create_all.sh localhost 1
cd pgsql && bash pgsql_ds_create_all.sh localhost 1
cd sqlserver && bash sqlserver_ds_create_all.sh localhost 1 <password>
cd oracle && bash oracle_ds_create_all.sh localhost 1
```

This creates the database, tables, indexes, stored procedures, and loads the CSV data.

## Step 3: Create a Configuration File

```
perl CreateConfigFile.pl
```

The script prompts for target hostname, vector search, DS2 compatibility mode, validation, analytics, and manager operations. It writes `DriverConfig.txt` with sensible defaults for everything else (1 thread, infinite run time, etc.).

Edit `DriverConfig.txt` afterward to adjust threads, run time, warmup time, think time, and other workload parameters. Alternatively, skip the script and edit `DriverConfig.txt` directly.

## Step 4: Run the Benchmark

```
cd mysql    # or pgsql, sqlserver, oracle
dotnet run -- --config_file=../DriverConfig.txt
```

The driver connects to the database, spawns worker threads, and reports Orders Per Minute (OPM) every 10 seconds.

To see all available parameters and their defaults:

```
dotnet run
```

## Desktop GUI

For a graphical interface that combines all of the above steps:

```
./run-gui.sh
```

See `gui/README.md` for details.
