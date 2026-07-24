# DVD Store 3.6 GUI

A desktop GUI application for the DVD Store 3.6 database benchmark.

## Features

- **Step 1: Data Generation** - Generate benchmark CSV data files
- **Step 2: Database Loading** - Load data to multiple databases (repeatable)
- **Step 3: Driver Configuration & Execution** - Configure and run benchmark tests

## Requirements

### All Platforms
- Python 3.6+ (with tkinter)
- perl
- dotnet SDK

### Linux/Mac Only
- gcc (for data generation)

### Database Client Tools (for Step 2)

These tools must be installed and available in your PATH:

- SQL Server: `sqlcmd`
- MySQL: `mariadb` or `mysql`
- PostgreSQL: `psql`
- Oracle: `sqlplus`

The GUI will only show databases in Step 2 (Database Loading) if their corresponding client tool is found in your PATH.

## Usage

### Linux/Mac
```bash
# From ds36 root directory
./run-gui.sh

# Or run directly
cd gui/
python3 dvdstore-gui.py
```

### Windows
```cmd
REM From ds36 root directory
run-gui.bat

REM Or run directly
cd gui
python dvdstore-gui.py
```

## Remote Display (Linux)

To run the GUI on a remote server and display on your local machine:

```bash
# Connect with X11 forwarding
ssh -YC username@remote-host

# Run the GUI
cd /path/to/ds36
./run-gui.sh
```

## Workflow

### Data Generation and Loading

**Step 1: Generate Data (CSV files + database-specific SQL files)**
- Generates CSV files in `data_files/` directory
- CSV files are overwritten each time you generate
- **Oracle and SQL Server:** Also create database-specific SQL files
  - SQL files persist when you generate for MySQL/PostgreSQL
  - SQL files are regenerated if you generate for Oracle/SQL Server again
  - You can change the database file path and regenerate to update the SQL files
  - **"SQL files only" checkbox:** Available for Oracle/SQL Server only
    - When checked, regenerates SQL files WITHOUT regenerating CSV data
    - Use this to update database file paths or create SQL files for a second database
    - At least one generation must create CSV files (checkbox unchecked) before loading
- **MySQL and PostgreSQL:** Only use CSV files (no additional SQL files needed)

**Step 2: Load Database (repeatable)**
- Loads data from the CSV files (most recently generated)
- Can be run multiple times to load the same CSV data into different databases
- **MySQL and PostgreSQL:** Available in Step 2 after ANY generation
- **Oracle and SQL Server:** Available in Step 2 after you generate with them selected at least once
  - Their SQL files persist when you generate for MySQL/PostgreSQL
  - If you regenerate for Oracle/SQL Server, their SQL files get updated
- **The GUI tracks which databases have been generated** to show only compatible databases in Step 2 dropdown

**Common Workflows:**

1. **Single Database:**
   ```
   Generate (MySQL, 4GB) → Load to MySQL
   ```

2. **MySQL + PostgreSQL (same data):**
   ```
   Generate (MySQL, 4GB) → Load to MySQL → Load to PostgreSQL
   ```
   Both databases contain identical data for fair comparison.

3. **All Four Databases (using --skip-csv checkbox):**
   ```
   Generate (SQL Server, 4GB, /var/opt/mssql/data)                → Creates SQL Server SQL files + CSV
   Generate (Oracle, 4GB, /home/oracle, ✓ SQL files only checkbox) → Creates Oracle SQL files only, keeps CSV
   Load to Oracle → Load to SQL Server → Load to MySQL → Load to PostgreSQL
   ```
   - SQL Server generation creates CSV + SQL files
   - Oracle generation with checkbox checked creates only SQL files (CSV unchanged)
   - All four databases now available in Step 2
   - All four load identical CSV data (from SQL Server generation)
   
   **Alternate order:**
   ```
   Generate (Oracle, 4GB, /home/oracle, ✓ SQL files only checkbox)  → Creates Oracle SQL files only (no CSV yet)
   Generate (SQL Server, 4GB, /var/opt/mssql/data)                  → Creates SQL Server SQL files + CSV
   Load to Oracle → Load to SQL Server → Load to MySQL → Load to PostgreSQL
   ```
   Order doesn't matter - both must complete before Step 2.

4. **All Four Databases (old method, requires TWO full generations):**
   ```
   Generate (Oracle, 4GB, /home/oracle)     → Creates Oracle SQL files + CSV
   Generate (SQL Server, 4GB, /var/opt/mssql/data) → Creates SQL Server SQL files + overwrites CSV
   Load to Oracle → Load to SQL Server → Load to MySQL → Load to PostgreSQL
   ```
   - Oracle SQL files created and persist
   - SQL Server SQL files created, CSV files overwritten
   - All four databases now available in Step 2
   - All four load the same CSV data (from SQL Server generation)
   - **Note:** This method regenerates CSV unnecessarily. Use the --skip-csv checkbox method above instead.

5. **Update Database File Paths (using --skip-csv checkbox):**
   ```
   Generate (Oracle, 4GB, /u01/oracle/data)                            → Creates Oracle SQL files + CSV
   (Oracle datafiles moved to /data/oracle)
   Generate (Oracle, 4GB, /data/oracle, ✓ SQL files only checkbox)     → Updates Oracle SQL files only, CSV unchanged
   Load to Oracle                                                      → Uses new path
   ```
   - First generation creates CSV + SQL files with `/u01/oracle/data` paths
   - Later, Oracle datafiles moved to `/data/oracle` directory
   - Second generation with checkbox updates SQL files with new path without regenerating CSV
   - **Use case:** Change database file locations without regenerating benchmark data

6. **Regenerating CSV after Oracle/SQL Server SQL files exist:**
   ```
   Generate (Oracle, 4GB, /home/oracle)     → Creates Oracle SQL files + CSV
   Generate (SQL Server, 4GB, /var/opt/mssql/data) → Creates SQL Server SQL files + CSV
   Generate (MySQL, 10GB)                    → Overwrites CSV only (no new SQL files)
   Load to Oracle → Load to SQL Server → Load to MySQL → Load to PostgreSQL
   ```
   - Oracle and SQL Server SQL files still exist (from earlier generations)
   - All four databases available in Step 2
   - All four load 10GB MySQL-generated CSV data

7. **Different Data Sizes:**
   ```
   Generate (Oracle, 4GB, /home/oracle)  → Load to Oracle
   Generate (MySQL, 50GB)                → Load to MySQL → Load to PostgreSQL
   ```
   - Oracle loads 4GB data
   - MySQL and PostgreSQL load 50GB data (CSV overwritten)

**Important:** 
- MySQL and PostgreSQL data is database-agnostic and can be shared
- Oracle and SQL Server require separate generation with database-specific file paths
- Only the most recently generated CSV files are loaded in Step 2

## How It Works

The GUI is a wrapper around the standard DVD Store 3.6 command-line tools:

**Step 1: Data Generation**
- Runs `Install_DVDStore.pl` with automated answers
- Same as running the Perl script manually, but without interactive prompts

**Step 2: Database Loading**
- Runs database-specific scripts:
  - MySQL: `mysql/mysql_ds_create_all.sh`
  - PostgreSQL: `pgsql/pgsql_ds_create_all.sh`
  - Oracle: `oracle/oracle_ds_create_all.sh`
  - SQL Server: `sqlserver/sqlserver_ds_create_all.sh`
- Same as running these scripts from the command line

**Step 3: Driver Execution**
- Generates `DriverConfig.txt` from GUI form values
- Runs the orchestrator or individual database driver
- Same as running `dotnet run` manually

**Advantages of the GUI:**
- No need to remember script locations or parameters
- Visual feedback with real-time output
- Repeatable workflows (save/load configurations)
- Form-based configuration instead of editing text files

**Command-line equivalent still works:**
Everything the GUI does can still be done manually from the command line. The GUI is just a convenience wrapper.

## Configuration Presets

Save and load complete benchmark configurations:
- Click "Save Config" to save current settings
- Click "Load Config" to restore saved settings
- Presets are stored in `gui/presets/`

## Troubleshooting

**Missing Prerequisites:**
The GUI will check for required tools on startup and show warnings for any missing dependencies.

**Dotnet Version Mismatch:**
If your installed dotnet version doesn't match the project requirements, the GUI will offer to automatically update the .csproj files.

**Client Tools Not Found:**
Databases requiring missing client tools will be hidden from Step 2 (Database Loading). Install the required client tool and ensure it's in your PATH to enable that database.

**Checking your PATH:**
```bash
# Linux/Mac
which sqlcmd    # Check if sqlcmd is in PATH
which psql      # Check if psql is in PATH
which mariadb   # Check if mariadb is in PATH

# Windows
where sqlcmd    # Check if sqlcmd is in PATH
where psql      # Check if psql is in PATH
```

## Documentation

For more information about the DVD Store 3.6 benchmark, see the main README.md in the ds36 root directory.
