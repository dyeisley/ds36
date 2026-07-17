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
- SQL Server: `sqlcmd`
- MySQL: `mariadb` or `mysql`
- PostgreSQL: `psql`
- Oracle: `sqlplus`

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
Databases requiring missing client tools will be hidden from Step 2 (Database Loading). Install the required client tool to enable that database.

## Documentation

For more information about the DVD Store 3.6 benchmark, see the main README.md in the ds36 root directory.
