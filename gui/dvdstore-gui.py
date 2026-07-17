#!/usr/bin/env python3
"""
DVD Store 3.6 GUI - Desktop application for benchmark workflow
Provides form-based interface for data generation, database loading, and driver execution.
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, filedialog, messagebox
import platform
import os
import sys
import shutil
import subprocess
import re
import threading
from pathlib import Path
from datetime import datetime


class ToolTip:
    """Simple tooltip widget for mouse-over help"""

    def __init__(self, widget, text):
        self.widget = widget
        self.text = text
        self.tooltip_window = None
        self.widget.bind("<Enter>", self.show_tooltip)
        self.widget.bind("<Leave>", self.hide_tooltip)

    def show_tooltip(self, event=None):
        if self.tooltip_window or not self.text:
            return

        x, y, _, _ = self.widget.bbox("insert")
        x += self.widget.winfo_rootx() + 25
        y += self.widget.winfo_rooty() + 25

        self.tooltip_window = tw = tk.Toplevel(self.widget)
        tw.wm_overrideredirect(True)
        tw.wm_geometry(f"+{x}+{y}")

        label = tk.Label(tw, text=self.text, justify=tk.LEFT,
                        background="#ffffe0", relief=tk.SOLID, borderwidth=1,
                        font=("tahoma", "8", "normal"), wraplength=300)
        label.pack(ipadx=1)

    def hide_tooltip(self, event=None):
        if self.tooltip_window:
            self.tooltip_window.destroy()
            self.tooltip_window = None


class CrossPlatformSupport:
    """Handle platform-specific operations"""

    def __init__(self):
        self.platform = platform.system()  # 'Linux', 'Windows', 'Darwin'
        self.is_windows = (self.platform == 'Windows')
        self.is_linux = (self.platform == 'Linux')
        self.is_mac = (self.platform == 'Darwin')

        # Script extensions by platform
        self.script_ext = '.bat' if self.is_windows else '.sh'

        # Shell command prefix (bash on Unix, direct execution on Windows)
        self.shell_cmd = [] if self.is_windows else ['bash']

    def get_script_path(self, db_dir, base_path):
        """Get platform-appropriate script path

        Linux/Mac: mysql/mysql_ds_create_all.sh
        Windows:   mysql\\mysql_ds_create_all.bat
        """
        script_name = f'{db_dir}_ds_create_all{self.script_ext}'
        return os.path.join(base_path, db_dir, script_name)

    def check_tool_installed(self, tool_name):
        """Cross-platform tool detection using shutil.which (works everywhere)"""
        return shutil.which(tool_name) is not None

    def run_script(self, script_path, args, cwd, env=None):
        """Execute script with platform-appropriate method

        Windows: Run .bat directly
        Linux/Mac: Use bash for .sh
        """
        if self.is_windows:
            # Windows: run .bat directly
            cmd = [script_path] + args
        else:
            # Linux/Mac: use bash for .sh
            cmd = ['bash', script_path] + args

        return subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            cwd=cwd,
            env=env
        )


class DVDStoreGUI:
    """Main GUI application for DVD Store 3.6 benchmark"""

    def __init__(self, master):
        self.master = master
        self.master.title("DVD Store 3.6 Benchmark")
        self.master.geometry("1400x900")

        # Platform support
        self.platform_support = CrossPlatformSupport()

        # State management
        self.loaded_databases = []
        self.data_generated = False
        self.generated_for_database = None  # Track which DB type was used in Step 1
        self.db_params = {}  # Parsed script parameters
        self.running_process = None  # Track running subprocess for cancellation

        # Get ds36 directory
        self.ds36_path = self.get_ds36_directory()
        if not self.ds36_path:
            messagebox.showerror("Error", "DVD Store directory is required")
            sys.exit(1)

        # Check prerequisites
        self.check_prerequisites()

        # Build UI
        self.create_widgets()

    def get_ds36_directory(self):
        """Find or ask for ds36 directory location (cross-platform)"""
        # Try to find ds36 by going up from gui directory
        gui_dir = os.path.dirname(os.path.abspath(__file__))
        potential_ds36 = os.path.dirname(gui_dir)

        # Verify it's actually a ds36 directory
        if os.path.exists(os.path.join(potential_ds36, 'Install_DVDStore.pl')):
            return potential_ds36

        # Try common locations
        possible_paths = [
            os.path.join(os.path.expanduser('~'), 'claude', 'ds36'),
            os.path.join(os.path.expanduser('~'), 'Documents', 'ds36'),
            'C:\\ds36',
            '/opt/ds36',
        ]

        for path in possible_paths:
            if os.path.exists(path) and os.path.isdir(path):
                if os.path.exists(os.path.join(path, 'Install_DVDStore.pl')):
                    return path

        # Not found, ask user to browse
        messagebox.showinfo(
            "Locate DVD Store Directory",
            "Please select the DVD Store 3.6 directory (ds36)"
        )

        path = filedialog.askdirectory(title="Select ds36 Directory")

        # Verify selected path
        if path and os.path.exists(os.path.join(path, 'Install_DVDStore.pl')):
            return path
        elif path:
            messagebox.showerror("Invalid Directory",
                "Selected directory does not appear to be a valid ds36 directory.\n"
                "Looking for Install_DVDStore.pl")
            return None

        return None

    def check_prerequisites(self):
        """Check for required tools on startup and display warnings for missing tools"""
        missing = []

        # gcc ONLY required on Linux/Mac (not Windows - Install_DVDStore.pl handles differently)
        if not self.platform_support.is_windows:
            if not self.platform_support.check_tool_installed('gcc'):
                missing.append("gcc (required for compiling data generation C programs)")

        # perl (required on all platforms)
        if not self.platform_support.check_tool_installed('perl'):
            missing.append("perl (required for Install_DVDStore.pl)")

        # dotnet (required on all platforms for driver execution)
        dotnet_status = self.check_dotnet_compatibility()
        if dotnet_status == "dotnet not installed":
            missing.append("dotnet (required for driver execution)")
        elif isinstance(dotnet_status, dict) and dotnet_status.get('status') == 'incompatible':
            # Offer to fix .csproj files
            self.offer_csproj_update(
                dotnet_status['installed'],
                dotnet_status['required'],
                dotnet_status['csproj_files']
            )

        # Display warning if any tools are missing
        if missing:
            msg = "Missing required tools:\n\n" + "\n".join(f"  • {tool}" for tool in missing)
            msg += "\n\nInstall missing tools to enable all features."
            messagebox.showwarning("Missing Dependencies", msg)

    def check_dotnet_compatibility(self):
        """Check dotnet version and .csproj TargetFramework compatibility"""

        # 1. Get installed dotnet version
        try:
            result = subprocess.run(['dotnet', '--version'],
                                  capture_output=True, text=True)
            if result.returncode != 0:
                return "dotnet not installed"

            # Parse version (e.g., "8.0.100" -> major version 8)
            version_str = result.stdout.strip()
            major_version = int(version_str.split('.')[0])

        except Exception:
            return "dotnet not installed"

        # 2. Scan all database .csproj files for TargetFramework
        csproj_files = []
        target_frameworks = set()

        for db_dir in os.listdir(self.ds36_path):
            if not os.path.isdir(os.path.join(self.ds36_path, db_dir)):
                continue

            csproj_path = os.path.join(self.ds36_path, db_dir, f'{db_dir}_ds.csproj')
            if os.path.exists(csproj_path):
                csproj_files.append(csproj_path)
                framework = self._parse_target_framework(csproj_path)
                if framework:
                    target_frameworks.add(framework)

        # 3. Check compatibility
        for framework in target_frameworks:
            # Extract major version from framework
            # Handle: net10.0, netcoreapp3.1, net6.0, etc.
            match = re.search(r'(\d+)\.', framework)
            if match:
                required_version = int(match.group(1))

                if required_version > major_version:
                    return {
                        'status': 'incompatible',
                        'installed': major_version,
                        'required': required_version,
                        'csproj_files': csproj_files
                    }

        return {'status': 'compatible', 'version': major_version}

    def _parse_target_framework(self, csproj_path):
        """Extract TargetFramework from .csproj file"""
        try:
            with open(csproj_path, 'r') as f:
                for line in f:
                    if '<TargetFramework>' in line:
                        # Extract: <TargetFramework>net10.0</TargetFramework>
                        match = re.search(r'<TargetFramework>(.*?)</TargetFramework>', line)
                        if match:
                            return match.group(1)
        except Exception:
            pass
        return None

    def offer_csproj_update(self, installed_version, required_version, csproj_files):
        """Offer to update .csproj files to match installed dotnet version"""
        msg = f"Dotnet version mismatch detected:\n\n"
        msg += f"  Installed: dotnet {installed_version}.0\n"
        msg += f"  Required by projects: dotnet {required_version}.0\n\n"
        msg += f"Options:\n"
        msg += f"  1. Install dotnet {required_version}.0 SDK\n"
        msg += f"  2. Update all .csproj files to use net{installed_version}.0\n\n"
        msg += f"Update .csproj files now?"

        response = messagebox.askyesno("Dotnet Version Mismatch", msg)

        if response:
            self.update_csproj_target_framework(csproj_files, installed_version)
            messagebox.showinfo("Success",
                f"Updated {len(csproj_files)} .csproj files to target net{installed_version}.0")

    def update_csproj_target_framework(self, csproj_files, new_version):
        """Update TargetFramework in all .csproj files"""
        for csproj_path in csproj_files:
            try:
                with open(csproj_path, 'r') as f:
                    content = f.read()

                # Replace TargetFramework
                updated = re.sub(
                    r'<TargetFramework>net\d+\.\d+</TargetFramework>',
                    f'<TargetFramework>net{new_version}.0</TargetFramework>',
                    content
                )

                with open(csproj_path, 'w') as f:
                    f.write(updated)

            except Exception as e:
                messagebox.showerror("Error", f"Failed to update {csproj_path}: {e}")

    def create_widgets(self):
        """Create all GUI widgets"""
        # Main container
        main_frame = ttk.Frame(self.master, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

        self.master.columnconfigure(0, weight=1)
        self.master.rowconfigure(0, weight=1)
        main_frame.columnconfigure(0, weight=1)
        main_frame.rowconfigure(1, weight=1)

        # Title spans full width
        title = ttk.Label(main_frame, text="DVD Store 3.6 Benchmark",
                         font=('TkDefaultFont', 16, 'bold'))
        title.grid(row=0, column=0, pady=10, sticky=(tk.W, tk.E))

        # PanedWindow for resizable columns
        paned = ttk.PanedWindow(main_frame, orient=tk.HORIZONTAL)
        paned.grid(row=1, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

        # Left pane: Steps 1, 2, 3
        left_frame = ttk.Frame(paned)
        left_frame.columnconfigure(0, weight=1)

        self.create_step1_widgets(left_frame)
        self.create_step2_widgets(left_frame)
        self.create_step3_widgets(left_frame)

        # Right pane: Output console
        right_frame = ttk.Frame(paned)
        self.create_output_console(right_frame)

        # Add panes (left gets initial 400px, right gets the rest)
        paned.add(left_frame, weight=1)
        paned.add(right_frame, weight=3)

    def create_step1_widgets(self, parent):
        """Create Step 1: Data Generation widgets"""
        step1_frame = ttk.LabelFrame(parent, text="Step 1: Data Generation", padding="10")
        step1_frame.grid(row=0, column=0, sticky=(tk.W, tk.E), pady=5)
        step1_frame.columnconfigure(1, weight=1)

        row = 0

        # Database Type
        ttk.Label(step1_frame, text="Database Type:").grid(row=row, column=0, sticky=tk.W, pady=2)
        self.db_type_var = tk.StringVar()
        self.db_type_combo = ttk.Combobox(step1_frame, textvariable=self.db_type_var, state='readonly')
        self.db_type_combo.grid(row=row, column=1, sticky=(tk.W, tk.E), pady=2, padx=5)
        self.db_type_combo.bind('<<ComboboxSelected>>', self.on_db_type_changed)
        row += 1

        # Size
        ttk.Label(step1_frame, text="Database Size:").grid(row=row, column=0, sticky=tk.W, pady=2)
        size_frame = ttk.Frame(step1_frame)
        size_frame.grid(row=row, column=1, sticky=(tk.W, tk.E), pady=2, padx=5)
        self.db_size_entry = ttk.Entry(size_frame, width=10)
        self.db_size_entry.insert(0, "4")
        self.db_size_entry.pack(side=tk.LEFT, padx=(0, 5))
        self.db_unit_var = tk.StringVar(value="GB")
        self.db_unit_combo = ttk.Combobox(size_frame, textvariable=self.db_unit_var,
                                         values=["MB", "GB"], state='readonly', width=5)
        self.db_unit_combo.pack(side=tk.LEFT)
        row += 1

        # Number of Stores
        ttk.Label(step1_frame, text="Number of Stores:").grid(row=row, column=0, sticky=tk.W, pady=2)
        self.stores_var = tk.StringVar(value="1")
        self.stores_combo = ttk.Combobox(step1_frame, textvariable=self.stores_var,
                                        values=[str(i) for i in range(1, 17)],
                                        state='readonly', width=5)
        self.stores_combo.grid(row=row, column=1, sticky=tk.W, pady=2, padx=5)
        row += 1

        # Vector Search (conditional - Linux only + database-specific)
        # Don't grid it yet - update_step1_visibility() will decide
        self.vector_search_var = tk.BooleanVar(value=False)
        self.vector_search_check = ttk.Checkbutton(step1_frame, text="Enable Vector Search",
                                                   variable=self.vector_search_var)
        self.vector_search_row = row
        self.vector_search_frame = step1_frame

        # Add tooltip for vector search
        ToolTip(self.vector_search_check,
                "Enable vector similarity search functionality.\n\n"
                "Adds vector embeddings to product descriptions for semantic search.\n"
                "Uses pgvector extension (PostgreSQL) or AI Vector Search (Oracle).\n\n"
                "When enabled:\n"
                "• Generates vector embeddings during data creation\n"
                "• Adds BROWSE_BY_VECTOR stored procedure\n"
                "• Increases data generation time significantly\n\n"
                "Note: Only available on Linux and only for databases with vector support.")

        row += 1

        # Database Paths (conditional - Oracle/SQL Server only)
        ttk.Label(step1_frame, text="Database Paths:").grid(row=row, column=0, sticky=tk.W, pady=2)
        self.db_paths_entry = ttk.Entry(step1_frame)
        self.db_paths_entry.grid(row=row, column=1, sticky=(tk.W, tk.E), pady=2, padx=5)
        self.db_paths_label = ttk.Label(step1_frame, text="(Semicolon-separated paths)")
        self.db_paths_label.grid(row=row, column=2, sticky=tk.W, pady=2)

        # Add tooltip for database paths
        ToolTip(self.db_paths_entry,
                "Semicolon-separated file paths for database files.\n\n"
                "SQL Server: 9 paths needed for ds.mdf, ds_misc, cust, order, index, member, review, log, and full-text catalog.\n"
                "  Linux:   /var/opt/mssql/data/\n"
                "  Windows: C:\\SQLData\\\n\n"
                "Oracle: 6 paths needed for cust, index, member, reviews, ds_misc, and order dbfiles.\n"
                "  Linux:   /u01/app/oracle/oradata\n"
                "  Windows: C:\\oracledbfiles\\\n\n"
                "If only one path is specified, it will be used for all dbfiles.\n"
                "Multiple paths allow distribution across disks for better I/O performance.")

        row += 1

        # Generate button with timestamp
        button_frame = ttk.Frame(step1_frame)
        button_frame.grid(row=row, column=0, columnspan=3, pady=10)

        self.generate_button = ttk.Button(button_frame, text="Generate Data Files",
                                         command=self.run_install_dvdstore)
        self.generate_button.pack(side=tk.LEFT, padx=5)

        self.generate_timestamp_label = ttk.Label(button_frame, text="", foreground="gray")
        self.generate_timestamp_label.pack(side=tk.LEFT, padx=5)

        # Populate database types
        self.populate_database_types()

        # Hide vector search initially
        self.update_step1_visibility()

    def create_step2_widgets(self, parent):
        """Create Step 2: Database Loading widgets"""
        step2_frame = ttk.LabelFrame(parent, text="Step 2: Database Loading (Repeatable)", padding="10")
        step2_frame.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=5)
        step2_frame.columnconfigure(1, weight=1)

        row = 0

        # Database Type (for loading - requires client tools)
        ttk.Label(step2_frame, text="Database Type:").grid(row=row, column=0, sticky=tk.W, pady=2)
        self.db_type_load_var = tk.StringVar()
        self.db_type_load_combo = ttk.Combobox(step2_frame, textvariable=self.db_type_load_var, state='readonly')
        self.db_type_load_combo.grid(row=row, column=1, sticky=(tk.W, tk.E), pady=2, padx=5)
        self.db_type_load_combo.bind('<<ComboboxSelected>>', self.on_load_db_type_changed)
        row += 1

        # Host
        ttk.Label(step2_frame, text="Host:").grid(row=row, column=0, sticky=tk.W, pady=2)
        self.host_entry = ttk.Entry(step2_frame)
        self.host_entry.insert(0, "localhost")
        self.host_entry.grid(row=row, column=1, sticky=(tk.W, tk.E), pady=2, padx=5)
        ToolTip(self.host_entry, "Database server hostname or IP address.\nUse 'localhost' for local database.")
        row += 1

        # Password (conditional - only shown for databases that need it)
        ttk.Label(step2_frame, text="Password:").grid(row=row, column=0, sticky=tk.W, pady=2)
        self.password_entry = ttk.Entry(step2_frame, show="*")
        self.password_entry.grid(row=row, column=1, sticky=(tk.W, tk.E), pady=2, padx=5)
        self.password_label = ttk.Label(step2_frame, text="")
        self.password_label.grid(row=row, column=2, sticky=tk.W, pady=2)
        self.password_row = row
        row += 1

        # Stores (display only - from Step 1)
        ttk.Label(step2_frame, text="Stores:").grid(row=row, column=0, sticky=tk.W, pady=2)
        self.stores_display = ttk.Label(step2_frame, text="(complete Step 1 first)", foreground="gray")
        self.stores_display.grid(row=row, column=1, sticky=tk.W, pady=2, padx=5)
        row += 1

        # Vector Search (display only - from Step 1)
        ttk.Label(step2_frame, text="Vector Search:").grid(row=row, column=0, sticky=tk.W, pady=2)
        self.vectors_display = ttk.Label(step2_frame, text="(complete Step 1 first)", foreground="gray")
        self.vectors_display.grid(row=row, column=1, sticky=tk.W, pady=2, padx=5)
        row += 1

        # Buttons
        button_frame = ttk.Frame(step2_frame)
        button_frame.grid(row=row, column=0, columnspan=3, pady=10)
        self.load_button = ttk.Button(button_frame, text="Load Database",
                                      command=self.run_database_loader)
        self.load_button.pack(side=tk.LEFT, padx=5)
        ttk.Button(button_frame, text="Clear Loaded List",
                  command=self.clear_loaded_databases).pack(side=tk.LEFT, padx=5)
        row += 1

        # Loaded Databases List
        ttk.Label(step2_frame, text="Loaded Databases:").grid(row=row, column=0, sticky=(tk.W, tk.N), pady=2)
        self.loaded_db_listbox = tk.Listbox(step2_frame, height=4)
        self.loaded_db_listbox.grid(row=row, column=1, sticky=(tk.W, tk.E), pady=2, padx=5)
        scrollbar = ttk.Scrollbar(step2_frame, orient=tk.VERTICAL, command=self.loaded_db_listbox.yview)
        scrollbar.grid(row=row, column=2, sticky=(tk.N, tk.S), pady=2)
        self.loaded_db_listbox.config(yscrollcommand=scrollbar.set)

        # Populate database types for loading
        self.populate_database_types_for_loading()

        # Initially disable until Step 1 completes
        self.load_button.config(state='disabled')

    def populate_database_types_for_loading(self):
        """Populate database type dropdown with databases that have client tools installed"""
        databases = self.detect_available_databases_for_loading()

        # Filter based on what was generated in Step 1
        if self.generated_for_database:
            databases = self.filter_compatible_databases(databases)

        self.db_type_load_combo['values'] = databases

        if not databases:
            if self.generated_for_database:
                self.log_output(f"Warning: No compatible databases available for data generated with {self.generated_for_database}.\n", "error")
            else:
                self.log_output("Warning: No database client tools found. Install sqlcmd, psql, mariadb/mysql, or sqlplus.\n", "error")
        elif databases:
            self.db_type_load_combo.current(0)
            self.on_load_db_type_changed(None)

    def filter_compatible_databases(self, databases):
        """Filter databases based on compatibility with generated data

        Compatibility logic:
        - Databases that require paths during generation (Oracle, SQL Server) have incompatible path formats
        - Data generated WITH paths can load to: same database + any database that doesn't need paths
        - Data generated WITHOUT paths can only load to databases that don't need paths

        This is determined dynamically - no hardcoded database list.
        """
        if not self.generated_for_database:
            return databases

        gen_db = self.generated_for_database

        # Databases that require paths (detected at runtime, not hardcoded)
        path_requiring_dbs = ['Oracle', 'SQL Server']

        if gen_db in path_requiring_dbs:
            # Data was generated WITH paths
            # Can load to: same database + all databases that DON'T require paths
            # Cannot load to: the OTHER path-requiring database
            compatible = [db for db in databases if db == gen_db or db not in path_requiring_dbs]
        else:
            # Data was generated WITHOUT paths
            # Can only load to databases that don't require paths
            compatible = [db for db in databases if db not in path_requiring_dbs]

        return compatible

    def detect_available_databases_for_loading(self):
        """Auto-detect databases for Step 2 (loading - requires client tools installed)"""
        databases = []

        # Map directory names to friendly names and required client tools (only known databases)
        # Unknown databases will be detected but client tool requirements must be guessed
        db_info = {
            'sqlserver': {'name': 'SQL Server', 'client': 'sqlcmd'},
            'mysql': {'name': 'MySQL', 'client': 'mariadb'},  # or 'mysql'
            'pgsql': {'name': 'PostgreSQL', 'client': 'psql'},
            'oracle': {'name': 'Oracle', 'client': 'sqlplus'}
        }

        # Scan for platform-appropriate scripts AND check if client tool is installed
        try:
            for item in os.listdir(self.ds36_path):
                item_path = os.path.join(self.ds36_path, item)
                if os.path.isdir(item_path):
                    script_path = self.platform_support.get_script_path(item, self.ds36_path)
                    if os.path.exists(script_path):
                        # Check if client tool is installed
                        info = db_info.get(item)
                        if info and self._is_client_tool_installed(info['client']):
                            databases.append(info['name'])
                        elif not info:
                            # Unknown database, skip for now
                            pass
        except Exception as e:
            if hasattr(self, 'output_text'):
                self.log_output(f"Error detecting databases for loading: {e}\n", "error")

        return sorted(databases)

    def _is_client_tool_installed(self, tool_name):
        """Check if a database client tool is installed on the system"""
        # Special case: mysql client can be 'mysql' or 'mariadb'
        if tool_name == 'mariadb':
            # Try mariadb first, fall back to mysql
            if self.platform_support.check_tool_installed('mariadb'):
                return True
            return self.platform_support.check_tool_installed('mysql')

        # For all other tools, use cross-platform check
        return self.platform_support.check_tool_installed(tool_name)

    def on_load_db_type_changed(self, event):
        """Handle database type selection change for loading"""
        self.update_step2_visibility()

    def update_step2_visibility(self):
        """Show/hide Step 2 fields based on selected database"""
        db_type = self.db_type_load_var.get()
        if not db_type:
            return

        db_dir = self.get_db_dir(db_type)

        # Show password field only if database needs it
        if db_dir in self.db_params and self.db_params[db_dir].get('needs_password', False):
            self.password_entry.grid()
            self.password_label.grid()
        else:
            self.password_entry.grid_remove()
            self.password_label.grid_remove()

    def run_database_loader(self):
        """Execute database-specific loading script (can be called multiple times)"""
        self.log_output("\n=== Loading Database ===\n")

        # Validation: ensure data was generated first
        if not self.data_generated:
            messagebox.showerror("Error", "Please generate data first (Step 1)")
            return

        # Get form values
        db_type = self.db_type_load_var.get()
        host = self.host_entry.get() or 'localhost'

        if not db_type:
            messagebox.showerror("Error", "Please select a database type")
            return

        # These come from Step 1 and are immutable
        stores = self.stores_var.get()
        use_vectors = '1' if self.vector_search_var.get() else '0'

        # Get database directory
        db_dir = self.get_db_dir(db_type)
        db_meta = self.db_params.get(db_dir, {})

        # Build arguments list based on parsed script requirements
        args = [host, stores]

        # Add password if required (from parsed syntax)
        if db_meta.get('needs_password', False):
            password = self.password_entry.get()
            if not password:
                messagebox.showerror("Error", f"{db_type} requires a password")
                return
            args.append(password)

        # Add use_vectors if supported (from parsed syntax)
        if db_meta.get('supports_vectors', True):
            args.append(use_vectors)

        self.log_output(f"Database: {db_type}\n")
        self.log_output(f"Host: {host}\n")
        self.log_output(f"Stores: {stores}\n")
        self.log_output(f"Vectors: {'Yes' if use_vectors == '1' else 'No'}\n")
        self.log_output(f"\nRunning {db_dir}_ds_create_all{self.platform_support.script_ext}...\n")

        # Disable button during execution
        self.load_button.config(state='disabled', text='Loading...')

        # Run in background thread
        thread = threading.Thread(
            target=self._execute_database_loader,
            args=(db_type, db_dir, args, host, stores, use_vectors),
            daemon=True
        )
        thread.start()

    def _execute_database_loader(self, db_type, db_dir, args, host, stores, use_vectors):
        """Execute database loading script in background thread"""
        try:
            # Scripts must be run from their own directory
            script_dir = os.path.join(self.ds36_path, db_dir)
            script_name = f'{db_dir}_ds_create_all{self.platform_support.script_ext}'

            # Set environment variables if needed (may not apply to Windows .bat files)
            env = os.environ.copy()
            if db_type == 'PostgreSQL' and not self.platform_support.is_windows:
                env['PGPASSWORD'] = 'ds3'  # hardcoded in pgsql .sh script

            # Execute with platform-appropriate method (from the database directory)
            proc = self.platform_support.run_script(
                script_name,  # Just the script name, not full path
                args,
                cwd=script_dir,  # Run from sqlserver/, mysql/, etc.
                env=env
            )

            # Stream output line by line
            for line in iter(proc.stdout.readline, ''):
                if not line:
                    break
                # Update GUI from background thread (use after_idle for thread safety)
                self.master.after_idle(lambda msg=line: self.log_output(msg))

            # Wait for completion
            proc.wait()
            return_code = proc.returncode

            # Update GUI based on result
            if return_code == 0:
                self.master.after_idle(lambda: self.log_output(f"\n✓ Successfully loaded data to {db_type} @ {host}!\n", "success"))
                # Add to loaded databases list
                self.master.after_idle(lambda: self.add_loaded_database(db_type, host, stores, use_vectors == '1'))
                self.master.after_idle(lambda: self.load_button.config(state='normal', text='Load Database'))
            else:
                self.master.after_idle(lambda: self.log_output(f"\n✗ Failed to load database (exit code {return_code})\n", "error"))
                self.master.after_idle(lambda: self.load_button.config(state='normal', text='Load Database'))

        except Exception as e:
            self.master.after_idle(lambda err=e: self.log_output(f"\n✗ Error: {err}\n", "error"))
            self.master.after_idle(lambda: self.load_button.config(state='normal', text='Load Database'))

    def add_loaded_database(self, db_type, host, stores, vectors):
        """Add successfully loaded database to the list (avoiding duplicates)"""
        # Check if this database+host combination already exists
        for existing in self.loaded_databases:
            if existing['type'] == db_type and existing['host'] == host:
                # Update the existing entry instead of adding duplicate
                existing['stores'] = stores
                existing['vectors'] = vectors
                existing['loaded_at'] = datetime.now()
                self.update_loaded_databases_display()
                return

        # Not a duplicate, add new entry
        entry = {
            'type': db_type,
            'host': host,
            'stores': stores,
            'vectors': vectors,
            'loaded_at': datetime.now()
        }
        self.loaded_databases.append(entry)
        self.update_loaded_databases_display()

    def update_loaded_databases_display(self):
        """Refresh the loaded databases list widget"""
        self.loaded_db_listbox.delete(0, tk.END)
        for db in self.loaded_databases:
            vectors_str = "vectors enabled" if db['vectors'] else "no vectors"
            line = f"✓ {db['type']} @ {db['host']} ({db['stores']} store, {vectors_str})"
            self.loaded_db_listbox.insert(tk.END, line)

        # Update Step 3 target database dropdown
        self.update_target_database_dropdown()

    def update_target_database_dropdown(self):
        """Update Step 3 target database checkboxes from loaded databases"""
        # Clear existing checkboxes
        for widget in self.target_selection_frame.winfo_children():
            widget.destroy()
        self.target_checkboxes = []

        if self.loaded_databases:
            # Create checkbox for each loaded database
            for idx, db in enumerate(self.loaded_databases):
                var = tk.BooleanVar(value=False)
                vectors_str = "vectors" if db['vectors'] else "no vectors"
                label_text = f"{db['type']} @ {db['host']} ({db['stores']} store, {vectors_str})"

                cb = ttk.Checkbutton(self.target_selection_frame,
                                    text=label_text,
                                    variable=var)
                cb.grid(row=idx, column=0, sticky=tk.W, pady=1)

                self.target_checkboxes.append((db, var))

            # Enable Step 3
            self.run_driver_button.config(state='normal')
        else:
            # Recreate placeholder label (it was destroyed above)
            self.no_targets_label = ttk.Label(self.target_selection_frame,
                                              text="(Load databases in Step 2 first)",
                                              foreground='gray')
            self.no_targets_label.grid(row=0, column=0, sticky=tk.W)
            self.run_driver_button.config(state='disabled')

    def clear_loaded_databases(self):
        """Clear the loaded databases list"""
        self.loaded_databases = []
        self.loaded_db_listbox.delete(0, tk.END)
        self.log_output("Cleared loaded databases list\n")

    def enable_step2(self):
        """Enable Step 2 after successful data generation"""
        # Update display fields from Step 1
        stores = self.stores_var.get()
        vectors = "Yes" if self.vector_search_var.get() else "No"

        self.stores_display.config(text=stores, foreground="black")
        self.vectors_display.config(text=vectors, foreground="black")

        # Repopulate database types based on compatibility
        self.populate_database_types_for_loading()

        # Enable the Load Database button
        self.load_button.config(state='normal')

        # Show compatibility info
        if self.generated_for_database:
            self.log_output(f"\nData generated for {self.generated_for_database}.\n")
            compatible = self.filter_compatible_databases(['Oracle', 'SQL Server', 'MySQL', 'PostgreSQL'])
            if compatible:
                self.log_output(f"Compatible databases: {', '.join(compatible)}\n")

    def create_step3_widgets(self, parent):
        """Create Step 3: Driver Configuration widgets"""
        step3_frame = ttk.LabelFrame(parent, text="Step 3: Driver Configuration & Execution", padding="10")
        step3_frame.grid(row=2, column=0, sticky=(tk.W, tk.E), pady=5)
        step3_frame.columnconfigure(1, weight=1)

        row = 0

        # Target Database Selection (from loaded databases) - checkboxes for multi-select
        ttk.Label(step3_frame, text="Target Database(s):").grid(row=row, column=0, sticky=tk.W, pady=2)

        # Create a frame to hold target checkboxes (populated dynamically when databases are loaded)
        self.target_selection_frame = ttk.Frame(step3_frame)
        self.target_selection_frame.grid(row=row, column=1, sticky=(tk.W, tk.E), pady=2, padx=5)
        self.target_checkboxes = []  # List of (db_dict, checkbox_var) tuples

        # Placeholder label (shown when no databases loaded)
        self.no_targets_label = ttk.Label(self.target_selection_frame,
                                          text="(Load databases in Step 2 first)",
                                          foreground='gray')
        self.no_targets_label.grid(row=0, column=0, sticky=tk.W)

        row += 1

        # Basic parameters
        ttk.Label(step3_frame, text="Threads:").grid(row=row, column=0, sticky=tk.W, pady=2)
        self.threads_spinbox = ttk.Spinbox(step3_frame, from_=1, to=100, width=10)
        self.threads_spinbox.set(16)
        self.threads_spinbox.grid(row=row, column=1, sticky=tk.W, pady=2, padx=5)
        ToolTip(self.threads_spinbox, "Number of concurrent user threads.\nTypical: 16 (matches 16 CPUs)")
        row += 1

        ttk.Label(step3_frame, text="Run Time (min):").grid(row=row, column=0, sticky=tk.W, pady=2)
        self.runtime_spinbox = ttk.Spinbox(step3_frame, from_=0, to=1440, width=10)
        self.runtime_spinbox.set(10)
        self.runtime_spinbox.grid(row=row, column=1, sticky=tk.W, pady=2, padx=5)
        ToolTip(self.runtime_spinbox, "Benchmark duration in minutes.\n0 = run indefinitely (Ctrl+C to stop)")
        row += 1

        # Enable managers checkbox
        self.enable_managers_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(step3_frame, text="Enable Manager Operations",
                       variable=self.enable_managers_var).grid(row=row, column=1, sticky=tk.W, pady=2, padx=5)
        row += 1

        # Enable analytics checkbox
        self.enable_analytics_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(step3_frame, text="Enable Analytics",
                       variable=self.enable_analytics_var).grid(row=row, column=1, sticky=tk.W, pady=2, padx=5)
        row += 1

        # Validate after test checkbox
        self.validate_post_test_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(step3_frame, text="Run Validation SQL After Test",
                       variable=self.validate_post_test_var).grid(row=row, column=1, sticky=tk.W, pady=2, padx=5)
        ToolTip(step3_frame.winfo_children()[-1], "Execute validation queries after benchmark completes\nto verify database consistency")
        row += 1

        # Configure/Run buttons
        button_frame = ttk.Frame(step3_frame)
        button_frame.grid(row=row, column=0, columnspan=2, pady=10)

        ttk.Button(button_frame, text="Advanced Configuration...",
                  command=self.open_advanced_config).pack(side=tk.LEFT, padx=5)

        self.run_driver_button = ttk.Button(button_frame, text="Run Driver",
                                            command=self.run_driver)
        self.run_driver_button.pack(side=tk.LEFT, padx=5)

        self.stop_driver_button = ttk.Button(button_frame, text="Stop",
                                             command=self.stop_driver,
                                             state='disabled')
        self.stop_driver_button.pack(side=tk.LEFT, padx=5)

        # Initially disable until Step 2 completes
        self.run_driver_button.config(state='disabled')

    def on_target_db_changed(self, event):
        """Handle target database selection change"""
        # Future: auto-populate target host, stores, etc.
        pass

    def open_advanced_config(self):
        """Open advanced configuration dialog"""
        # Create dialog window
        dialog = tk.Toplevel(self.master)
        dialog.title("Advanced Driver Configuration")
        dialog.geometry("700x750")
        dialog.transient(self.master)
        dialog.grab_set()

        # Create notebook (tabbed interface)
        notebook = ttk.Notebook(dialog)
        notebook.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        # Customer/Membership tab
        self.create_customer_tab(notebook)

        # Workload Mix tab
        self.create_workload_tab(notebook)

        # Manager tab
        self.create_manager_tab(notebook)

        # Analytics tab
        self.create_analytics_tab(notebook)

        # OK/Cancel buttons
        button_frame = ttk.Frame(dialog)
        button_frame.pack(side=tk.BOTTOM, pady=10)

        ttk.Button(button_frame, text="OK", command=dialog.destroy).pack(side=tk.LEFT, padx=5)
        ttk.Button(button_frame, text="Cancel", command=dialog.destroy).pack(side=tk.LEFT, padx=5)

    def create_customer_tab(self, notebook):
        """Create the Customer/Membership configuration tab"""
        customer_frame = ttk.Frame(notebook, padding=10)
        notebook.add(customer_frame, text="Customer/Membership")

        row = 0

        # New Customer percentage
        ttk.Label(customer_frame, text="New Customer %:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.pct_newcustomers_var = tk.IntVar(value=20)
        ttk.Spinbox(customer_frame, from_=0, to=100, textvariable=self.pct_newcustomers_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(customer_frame.winfo_children()[-1], "Percentage of orders from new customers\n(vs existing customers logging in)\nDefault: 20%")
        row += 1

        # New Member percentage
        ttk.Label(customer_frame, text="New Member %:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.pct_newmember_var = tk.IntVar(value=1)
        ttk.Spinbox(customer_frame, from_=0, to=100, textvariable=self.pct_newmember_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(customer_frame.winfo_children()[-1], "Percentage of new customers who sign up for membership\nDefault: 1%")
        row += 1

        # Renew Member percentage
        ttk.Label(customer_frame, text="Renew Member %:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.pct_renewmember_var = tk.IntVar(value=50)
        ttk.Spinbox(customer_frame, from_=0, to=100, textvariable=self.pct_renewmember_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(customer_frame.winfo_children()[-1], "Percentage of expired members who renew during login\nDefault: 50%")
        row += 1

        ttk.Separator(customer_frame, orient=tk.HORIZONTAL).grid(row=row, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=10)
        row += 1

        # Review behavior
        ttk.Label(customer_frame, text="Review Behavior:", font=('TkDefaultFont', 10, 'bold')).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=5)
        row += 1

        ttk.Label(customer_frame, text="Reviews per Order:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.n_reviews_var = tk.IntVar(value=3)
        ttk.Spinbox(customer_frame, from_=0, to=100, textvariable=self.n_reviews_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(customer_frame.winfo_children()[-1], "Number of product reviews to read per order\nDefault: 3")
        row += 1

        ttk.Label(customer_frame, text="New Reviews %:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.pct_newreviews_var = tk.IntVar(value=5)
        ttk.Spinbox(customer_frame, from_=0, to=100, textvariable=self.pct_newreviews_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(customer_frame.winfo_children()[-1], "Percentage of customers who write a new review\nDefault: 5%")
        row += 1

        ttk.Label(customer_frame, text="New Helpfulness %:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.pct_newhelpfulness_var = tk.IntVar(value=10)
        ttk.Spinbox(customer_frame, from_=0, to=100, textvariable=self.pct_newhelpfulness_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(customer_frame.winfo_children()[-1], "Percentage of customers who rate a review as helpful/unhelpful\nDefault: 10%")
        row += 1

    def create_workload_tab(self, notebook):
        """Create the Workload Mix configuration tab"""
        workload_frame = ttk.Frame(notebook, padding=10)
        notebook.add(workload_frame, text="Workload Mix")

        # Create scrollable canvas for all the workload parameters
        canvas = tk.Canvas(workload_frame, highlightthickness=0)
        scrollbar = ttk.Scrollbar(workload_frame, orient="vertical", command=canvas.yview)
        scrollable_frame = ttk.Frame(canvas)

        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )

        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)

        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

        row = 0

        # Warmup time
        ttk.Label(scrollable_frame, text="Warmup Time (min):").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.warmup_time_var = tk.IntVar(value=1)
        ttk.Spinbox(scrollable_frame, from_=0, to=60, textvariable=self.warmup_time_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(scrollable_frame.winfo_children()[-1], "Minutes to run before collecting metrics\nDefault: 1 minute")
        row += 1

        # Think time
        ttk.Label(scrollable_frame, text="Think Time (sec):").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.think_time_var = tk.DoubleVar(value=0.0)
        ttk.Spinbox(scrollable_frame, from_=0.0, to=60.0, increment=0.1, textvariable=self.think_time_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(scrollable_frame.winfo_children()[-1], "Delay between operations (seconds)\n0 = maximum throughput\nDefault: 0")
        row += 1

        # Number of stores
        ttk.Label(scrollable_frame, text="Number of Stores:").grid(row=row, column=0, sticky=tk.W, pady=5)
        # Default to the number loaded from Step 1, allow reducing it
        default_stores = 1
        if hasattr(self, 'loaded_databases') and self.loaded_databases:
            default_stores = self.loaded_databases[0].get('stores', 1)
        self.n_stores_var = tk.IntVar(value=default_stores)
        ttk.Spinbox(scrollable_frame, from_=1, to=16, textvariable=self.n_stores_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(scrollable_frame.winfo_children()[-1], "Number of stores to use in the test\nMust be <= stores loaded in Step 2\nDefault: all loaded stores")
        row += 1

        ttk.Separator(scrollable_frame, orient=tk.HORIZONTAL).grid(row=row, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=10)
        row += 1

        # Search behavior
        ttk.Label(scrollable_frame, text="Search Behavior:", font=('TkDefaultFont', 10, 'bold')).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=5)
        row += 1

        ttk.Label(scrollable_frame, text="Searches per Order:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.n_searches_var = tk.IntVar(value=3)
        ttk.Spinbox(scrollable_frame, from_=0, to=100, textvariable=self.n_searches_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(scrollable_frame.winfo_children()[-1], "Number of searches per purchase\nDefault: 3")
        row += 1

        ttk.Label(scrollable_frame, text="Search Batch Size:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.search_batch_size_var = tk.IntVar(value=5)
        ttk.Spinbox(scrollable_frame, from_=1, to=1000, textvariable=self.search_batch_size_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(scrollable_frame.winfo_children()[-1], "Number of products per search result\nDefault: 5")
        row += 1

        ttk.Label(scrollable_frame, text="Search Depth:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.search_depth_var = tk.IntVar(value=500)
        ttk.Spinbox(scrollable_frame, from_=1, to=100000, textvariable=self.search_depth_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(scrollable_frame.winfo_children()[-1], "Number of rows to scan before applying batch size limit\nHigher = more thorough search, slower\nDefault: 500")
        row += 1

        ttk.Separator(scrollable_frame, orient=tk.HORIZONTAL).grid(row=row, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=10)
        row += 1

        # Purchase behavior
        ttk.Label(scrollable_frame, text="Purchase Behavior:", font=('TkDefaultFont', 10, 'bold')).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=5)
        row += 1

        ttk.Label(scrollable_frame, text="Line Items per Order:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.n_line_items_var = tk.IntVar(value=5)
        ttk.Spinbox(scrollable_frame, from_=1, to=1000, textvariable=self.n_line_items_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(scrollable_frame.winfo_children()[-1], "Products per shopping cart\nDefault: 5")
        row += 1

        ttk.Separator(scrollable_frame, orient=tk.HORIZONTAL).grid(row=row, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=10)
        row += 1

        # Logging
        ttk.Label(scrollable_frame, text="Logging:", font=('TkDefaultFont', 10, 'bold')).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=5)
        row += 1

        ttk.Label(scrollable_frame, text="Log Frequency (sec):").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.log_freq_var = tk.IntVar(value=10)
        ttk.Spinbox(scrollable_frame, from_=1, to=3600, textvariable=self.log_freq_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(scrollable_frame.winfo_children()[-1], "Seconds between OPM status updates\nDefault: 10 seconds")
        row += 1

        ttk.Label(scrollable_frame, text="Log Timestamp:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.log_timestamp_var = tk.StringVar(value="NONE")
        ttk.Combobox(scrollable_frame, textvariable=self.log_timestamp_var, values=["NONE", "UTC", "LOCAL"], state='readonly', width=10).grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(scrollable_frame.winfo_children()[-1], "Add timestamps to log output\nNONE = no timestamps (default)\nUTC = UTC timestamps\nLOCAL = local timezone")
        row += 1

        self.detailed_view_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(scrollable_frame, text="Detailed View (verbose statistics)",
                       variable=self.detailed_view_var).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=5)
        ToolTip(scrollable_frame.winfo_children()[-1], "Show detailed per-operation statistics")
        row += 1

        ttk.Separator(scrollable_frame, orient=tk.HORIZONTAL).grid(row=row, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=10)
        row += 1

        # Advanced options
        ttk.Label(scrollable_frame, text="Advanced:", font=('TkDefaultFont', 10, 'bold')).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=5)
        row += 1

        # Initialize based on whether any loaded database has vectors
        has_vectors = False
        if hasattr(self, 'loaded_databases') and self.loaded_databases:
            # Check if any loaded database has vectors enabled
            has_vectors = any(db.get('vectors', False) for db in self.loaded_databases)
        self.use_vectors_var = tk.BooleanVar(value=has_vectors)
        ttk.Checkbutton(scrollable_frame, text="Enable Vector Search",
                       variable=self.use_vectors_var).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=5, padx=20)
        ToolTip(scrollable_frame.winfo_children()[-1], "Enable vector similarity searches (PostgreSQL/Oracle)\nRequires vector data loaded in Step 2\nIncompatible with Manager Operations")
        row += 1

        self.ds2_mode_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(scrollable_frame, text="DS2 Compatibility Mode",
                       variable=self.ds2_mode_var).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=5, padx=20)
        ToolTip(scrollable_frame.winfo_children()[-1], "Disable DS3.6 features for DVD Store 2 comparison\n(Disables membership, manager, analytics)")
        row += 1

    def create_manager_tab(self, notebook):
        """Create the Manager Operations configuration tab"""
        manager_frame = ttk.Frame(notebook, padding=10)
        notebook.add(manager_frame, text="Manager Operations")

        # Create scrollable canvas for all the manager parameters
        canvas = tk.Canvas(manager_frame, highlightthickness=0)
        scrollbar = ttk.Scrollbar(manager_frame, orient="vertical", command=canvas.yview)
        scrollable_frame = ttk.Frame(canvas)

        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )

        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)

        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

        row = 0

        # Manager interval
        ttk.Label(scrollable_frame, text="Manager Interval (seconds):").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.manager_interval_var = tk.IntVar(value=30)
        interval_spin = ttk.Spinbox(scrollable_frame, from_=1, to=600, textvariable=self.manager_interval_var, width=10)
        interval_spin.grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(interval_spin, "Seconds between manager operations\nDefault: 30 seconds")
        row += 1

        # Batch sizes
        ttk.Label(scrollable_frame, text="Batch Size Min:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.manager_batch_min_var = tk.IntVar(value=1)
        batch_min_spin = ttk.Spinbox(scrollable_frame, from_=1, to=1000, textvariable=self.manager_batch_min_var, width=10)
        batch_min_spin.grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(batch_min_spin, "Minimum batch size for manager operations")
        row += 1

        ttk.Label(scrollable_frame, text="Batch Size Max:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.manager_batch_max_var = tk.IntVar(value=20)
        batch_max_spin = ttk.Spinbox(scrollable_frame, from_=1, to=1000, textvariable=self.manager_batch_max_var, width=10)
        batch_max_spin.grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(batch_max_spin, "Maximum batch size for manager operations")
        row += 1

        ttk.Separator(scrollable_frame, orient=tk.HORIZONTAL).grid(row=row, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=10)
        row += 1

        # Operation percentages header
        ttk.Label(scrollable_frame, text="Operation Percentages:", font=('TkDefaultFont', 10, 'bold')).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=5)
        row += 1

        ttk.Label(scrollable_frame, text="(Total should equal 100%)", font=('TkDefaultFont', 8)).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=2, padx=20)
        row += 1

        # AddProduct
        ttk.Label(scrollable_frame, text="Add Product %:").grid(row=row, column=0, sticky=tk.W, pady=2, padx=20)
        self.mgr_add_product_var = tk.IntVar(value=40)
        ttk.Spinbox(scrollable_frame, from_=0, to=100, textvariable=self.mgr_add_product_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=2)
        ToolTip(scrollable_frame.winfo_children()[-1], "Add new products to inventory (.01 price endings)")
        row += 1

        # DeleteReview
        ttk.Label(scrollable_frame, text="Delete Review %:").grid(row=row, column=0, sticky=tk.W, pady=2, padx=20)
        self.mgr_delete_review_var = tk.IntVar(value=20)
        ttk.Spinbox(scrollable_frame, from_=0, to=100, textvariable=self.mgr_delete_review_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=2)
        ToolTip(scrollable_frame.winfo_children()[-1], "Remove reviews (by product, unhelpful, or by date)")
        row += 1

        # AdjustPrices (includes BulkPriceAdjustment)
        ttk.Label(scrollable_frame, text="Adjust Prices %:").grid(row=row, column=0, sticky=tk.W, pady=2, padx=20)
        self.mgr_update_price_var = tk.IntVar(value=20)
        ttk.Spinbox(scrollable_frame, from_=0, to=100, textvariable=self.mgr_update_price_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=2)
        ToolTip(scrollable_frame.winfo_children()[-1], "Price adjustments (alternates individual .99 and bulk .77)")
        row += 1

        # MarkSpecials
        ttk.Label(scrollable_frame, text="Mark Specials %:").grid(row=row, column=0, sticky=tk.W, pady=2, padx=20)
        self.mgr_update_special_var = tk.IntVar(value=5)
        ttk.Spinbox(scrollable_frame, from_=0, to=100, textvariable=self.mgr_update_special_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=2)
        ToolTip(scrollable_frame.winfo_children()[-1], "Toggle product special flags")
        row += 1

        # ExpireMemberships
        ttk.Label(scrollable_frame, text="Expire Memberships %:").grid(row=row, column=0, sticky=tk.W, pady=2, padx=20)
        self.mgr_expire_memberships_var = tk.IntVar(value=5)
        ttk.Spinbox(scrollable_frame, from_=0, to=100, textvariable=self.mgr_expire_memberships_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=2)
        ToolTip(scrollable_frame.winfo_children()[-1], "Expire old memberships based on expiration date")
        row += 1

        # PurgeOldOrders
        ttk.Label(scrollable_frame, text="Purge Old Orders %:").grid(row=row, column=0, sticky=tk.W, pady=2, padx=20)
        self.mgr_purge_old_orders_var = tk.IntVar(value=5)
        ttk.Spinbox(scrollable_frame, from_=0, to=100, textvariable=self.mgr_purge_old_orders_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=2)
        ToolTip(scrollable_frame.winfo_children()[-1], "Delete oldest orders (GDPR/data retention compliance)")
        row += 1

        # UpgradeMembership
        ttk.Label(scrollable_frame, text="Upgrade Membership %:").grid(row=row, column=0, sticky=tk.W, pady=2, padx=20)
        self.mgr_upgrade_membership_var = tk.IntVar(value=5)
        ttk.Spinbox(scrollable_frame, from_=0, to=100, textvariable=self.mgr_upgrade_membership_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=2)
        ToolTip(scrollable_frame.winfo_children()[-1], "Upgrade membership tiers based on purchase history (percentile-based)")
        row += 1

        # PromotionalMembership
        ttk.Label(scrollable_frame, text="Promotional Membership %:").grid(row=row, column=0, sticky=tk.W, pady=2, padx=20)
        self.mgr_promo_membership_var = tk.IntVar(value=0)
        ttk.Spinbox(scrollable_frame, from_=0, to=100, textvariable=self.mgr_promo_membership_var, width=10).grid(row=row, column=1, sticky=tk.W, pady=2)
        ToolTip(scrollable_frame.winfo_children()[-1], "90-day promotional membership upgrades (MERGE-based)")
        row += 1

    def create_analytics_tab(self, notebook):
        """Create the Analytics configuration tab"""
        analytics_frame = ttk.Frame(notebook, padding=10)
        notebook.add(analytics_frame, text="Analytics")

        row = 0

        # Analytics interval
        ttk.Label(analytics_frame, text="Analytics Interval (minutes):").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.analytics_interval_var = tk.IntVar(value=5)
        analytics_spin = ttk.Spinbox(analytics_frame, from_=0, to=60, textvariable=self.analytics_interval_var, width=10)
        analytics_spin.grid(row=row, column=1, sticky=tk.W, pady=5, padx=5)
        ToolTip(analytics_spin, "Minutes between analytics queries.\n0 = disabled\nTypical: 5-15 minutes")
        row += 1

        ttk.Separator(analytics_frame, orient=tk.HORIZONTAL).grid(row=row, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=10)
        row += 1

        # Individual analytics toggles
        ttk.Label(analytics_frame, text="Enable Individual Analytics:", font=('TkDefaultFont', 10, 'bold')).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=5)
        row += 1

        self.enable_membership_analytics_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(analytics_frame, text="Membership Analytics",
                       variable=self.enable_membership_analytics_var).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=2, padx=20)
        ToolTip(analytics_frame.winfo_children()[-1], "Orders and revenue per tier (Gold/Silver/Bronze/Non-member)")
        row += 1

        self.enable_newcustomer_analytics_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(analytics_frame, text="New Customer Analytics",
                       variable=self.enable_newcustomer_analytics_var).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=2, padx=20)
        ToolTip(analytics_frame.winfo_children()[-1], "New customers created and retention metrics")
        row += 1

        self.enable_review_analytics_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(analytics_frame, text="Review Analytics",
                       variable=self.enable_review_analytics_var).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=2, padx=20)
        ToolTip(analytics_frame.winfo_children()[-1], "Review distribution by star rating and helpfulness scores")
        row += 1

        self.enable_pricepoint_analytics_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(analytics_frame, text="Price Point Analytics",
                       variable=self.enable_pricepoint_analytics_var).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=2, padx=20)
        ToolTip(analytics_frame.winfo_children()[-1], "Distribution of price endings (.99, .77, .01, other)")
        row += 1

        self.enable_inventory_analytics_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(analytics_frame, text="Inventory Analytics",
                       variable=self.enable_inventory_analytics_var).grid(row=row, column=0, columnspan=2, sticky=tk.W, pady=2, padx=20)
        ToolTip(analytics_frame.winfo_children()[-1], "Low/high stock counts, reorder events, sales velocity")

    def run_driver(self):
        """Generate config and run orchestrator (supports 1 or multiple targets)"""
        self.log_output("\n=== Running Driver ===\n")

        # Validation: ensure database was loaded
        if not self.loaded_databases:
            messagebox.showerror("Error", "Please load a database first (Step 2)")
            return

        # Get selected target databases from checkboxes
        selected_targets = self.get_selected_targets()
        if not selected_targets:
            messagebox.showerror("Error", "Please select at least one target database")
            return

        # Validation: cannot use both vectors and managers
        # Check if ANY selected target has vectors enabled
        vectors_enabled = False
        for target_db in selected_targets:
            if hasattr(self, 'use_vectors_var'):
                if self.use_vectors_var.get():
                    vectors_enabled = True
                    break
            else:
                if target_db['vectors']:
                    vectors_enabled = True
                    break

        if vectors_enabled and self.enable_managers_var.get():
            messagebox.showerror("Error",
                "Cannot enable both Vector Search and Manager Operations.\n\n"
                "Vector search requires specific database configuration that is\n"
                "incompatible with manager operations.\n\n"
                "Please either:\n"
                "  • Disable Manager Operations, or\n"
                "  • Uncheck 'Enable Vector Search' in Advanced Config")
            return

        # Validation: n_stores must be <= loaded stores
        if hasattr(self, 'n_stores_var'):
            requested_stores = self.n_stores_var.get()
            max_loaded_stores = max(int(db['stores']) for db in selected_targets)
            if requested_stores > max_loaded_stores:
                messagebox.showerror("Error",
                    f"Cannot use {requested_stores} stores.\n\n"
                    f"Maximum loaded stores: {max_loaded_stores}\n\n"
                    f"Please reduce Number of Stores in Advanced Config (Workload Mix tab)\n"
                    f"or load more stores in Step 2.")
                return

        threads = self.threads_spinbox.get()
        runtime = self.runtime_spinbox.get()

        # Log selected targets
        self.log_output(f"Selected Targets ({len(selected_targets)}):\n")
        for target_db in selected_targets:
            self.log_output(f"  • {target_db['type']} @ {target_db['host']}\n")

        self.log_output(f"Threads: {threads}\n")
        self.log_output(f"Run Time: {runtime} minutes\n")
        self.log_output(f"Managers: {'Yes' if self.enable_managers_var.get() else 'No'}\n")
        self.log_output(f"Analytics: {'Yes' if self.enable_analytics_var.get() else 'No'}\n\n")

        # Disable run button, enable stop button during execution
        self.run_driver_button.config(state='disabled', text='Running...')
        self.stop_driver_button.config(state='normal')

        # Run in background thread
        thread = threading.Thread(
            target=self._execute_orchestrator,
            args=(selected_targets,),
            daemon=True
        )
        thread.start()

    def stop_driver(self):
        """Stop the currently running driver process"""
        if self.running_process:
            self.log_output("\n⚠ Stopping driver...\n", "error")
            try:
                self.running_process.terminate()
                # Give it a moment to terminate gracefully
                try:
                    self.running_process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    # Force kill if it doesn't terminate
                    self.running_process.kill()
                    self.log_output("Driver process killed (forced)\n", "error")
            except Exception as e:
                self.log_output(f"Error stopping driver: {e}\n", "error")

    def get_selected_targets(self):
        """Get list of selected target databases from checkboxes"""
        selected = []
        for db, var in self.target_checkboxes:
            if var.get():
                selected.append(db)
        return selected

    def generate_orchestrator_config(self, selected_targets):
        """Generate orchestrator config from current settings (supports multiple targets)"""
        lines = []
        lines.append("# DVD Store Multi-Database Orchestrator Config")
        lines.append("# Generated by DVD Store 3.6 GUI")
        lines.append("")
        lines.append("# Common benchmark parameters (shared across all databases)")

        # Basic parameters (NO target= here - that goes in target_N= lines)
        lines.append(f"n_threads={self.threads_spinbox.get()}")
        lines.append(f"run_time={self.runtime_spinbox.get()}")
        lines.append(f"ramp_rate=10")   # Default

        # Workload parameters (use advanced config if available, otherwise defaults)
        if hasattr(self, 'warmup_time_var'):
            lines.append(f"warmup_time={self.warmup_time_var.get()}")
            lines.append(f"think_time={self.think_time_var.get()}")
            lines.append(f"n_searches={self.n_searches_var.get()}")
            lines.append(f"search_batch_size={self.search_batch_size_var.get()}")
            lines.append(f"search_depth={self.search_depth_var.get()}")
            lines.append(f"n_line_items={self.n_line_items_var.get()}")
            lines.append(f"log_freq={self.log_freq_var.get()}")
        else:
            lines.append(f"warmup_time=1")
            lines.append(f"think_time=0")
            lines.append(f"n_searches=3")
            lines.append(f"search_batch_size=5")
            lines.append(f"search_depth=500")
            lines.append(f"n_line_items=5")
            lines.append(f"log_freq=10")

        # Customer/Membership parameters (use advanced config if available, otherwise defaults)
        if hasattr(self, 'pct_newcustomers_var'):
            lines.append(f"pct_newcustomers={self.pct_newcustomers_var.get()}")
            lines.append(f"pct_newmember={self.pct_newmember_var.get()}")
            lines.append(f"pct_renewmember={self.pct_renewmember_var.get()}")
            lines.append(f"n_reviews={self.n_reviews_var.get()}")
            lines.append(f"pct_newreviews={self.pct_newreviews_var.get()}")
            lines.append(f"pct_newhelpfulness={self.pct_newhelpfulness_var.get()}")
        else:
            lines.append(f"pct_newcustomers=20")
            lines.append(f"pct_newmember=1")
            lines.append(f"pct_renewmember=50")
            lines.append(f"n_reviews=3")
            lines.append(f"pct_newreviews=5")
            lines.append(f"pct_newhelpfulness=10")

        # Vector search (from advanced config if available, otherwise from loaded database)
        if hasattr(self, 'use_vectors_var'):
            # Use the checkbox from Workload tab
            if self.use_vectors_var.get():
                lines.append(f"use_vectors=Y")
        elif selected_targets and any(db.get('vectors', False) for db in selected_targets):
            # Fallback: auto-detect if ANY selected database has vectors
            lines.append(f"use_vectors=Y")

        # Manager operations (use advanced config settings if available)
        if self.enable_managers_var.get():
            lines.append(f"enable_managers=Y")

            # Use advanced config values if dialog was opened, otherwise use defaults
            if hasattr(self, 'manager_interval_var'):
                lines.append(f"manager_interval={self.manager_interval_var.get()}")
                lines.append(f"manager_batch_size_min={self.manager_batch_min_var.get()}")
                lines.append(f"manager_batch_size_max={self.manager_batch_max_var.get()}")
                lines.append(f"manager_add_product_pct={self.mgr_add_product_var.get()}")
                lines.append(f"manager_delete_review_pct={self.mgr_delete_review_var.get()}")
                lines.append(f"manager_update_price_pct={self.mgr_update_price_var.get()}")
                lines.append(f"manager_update_special_pct={self.mgr_update_special_var.get()}")
                lines.append(f"manager_expire_memberships_pct={self.mgr_expire_memberships_var.get()}")
                lines.append(f"manager_purge_old_orders_pct={self.mgr_purge_old_orders_var.get()}")
                lines.append(f"manager_upgrade_membership_pct={self.mgr_upgrade_membership_var.get()}")
                lines.append(f"manager_promo_membership_pct={self.mgr_promo_membership_var.get()}")
            else:
                # Defaults if advanced config not used
                lines.append(f"manager_interval=30")
                lines.append(f"manager_batch_size_min=1")
                lines.append(f"manager_batch_size_max=20")
                lines.append(f"manager_add_product_pct=40")
                lines.append(f"manager_delete_review_pct=20")
                lines.append(f"manager_update_price_pct=20")
                lines.append(f"manager_update_special_pct=5")
                lines.append(f"manager_expire_memberships_pct=5")
                lines.append(f"manager_purge_old_orders_pct=5")
                lines.append(f"manager_upgrade_membership_pct=5")
                lines.append(f"manager_promo_membership_pct=0")

        # Analytics (use advanced config settings if available, but respect main checkbox)
        if hasattr(self, 'analytics_interval_var') and self.enable_analytics_var.get():
            analytics_interval = self.analytics_interval_var.get()
        elif self.enable_analytics_var.get():
            analytics_interval = 5  # Default if checkbox enabled but no advanced config
        else:
            analytics_interval = 0  # Checkbox unchecked = disabled

        if analytics_interval > 0:
            lines.append(f"analytics_interval={analytics_interval}")

            # Individual analytics toggles (only disable if explicitly unchecked)
            if hasattr(self, 'enable_membership_analytics_var') and not self.enable_membership_analytics_var.get():
                lines.append(f"enable_membership_analytics=N")
            if hasattr(self, 'enable_newcustomer_analytics_var') and not self.enable_newcustomer_analytics_var.get():
                lines.append(f"enable_newcustomer_analytics=N")
            if hasattr(self, 'enable_review_analytics_var') and not self.enable_review_analytics_var.get():
                lines.append(f"enable_review_analytics=N")
            if hasattr(self, 'enable_pricepoint_analytics_var') and not self.enable_pricepoint_analytics_var.get():
                lines.append(f"enable_pricepoint_analytics=N")
            if hasattr(self, 'enable_inventory_analytics_var') and not self.enable_inventory_analytics_var.get():
                lines.append(f"enable_inventory_analytics=N")

        # Validation (always available in Step 3)
        if self.validate_post_test_var.get():
            lines.append(f"validate_post_test=Y")

        # Additional workload options (from advanced config if available)
        if hasattr(self, 'log_timestamp_var'):
            if self.log_timestamp_var.get() != "NONE":
                lines.append(f"log_timestamp={self.log_timestamp_var.get()}")
            if self.detailed_view_var.get():
                lines.append(f"detailed_view=Y")
            if self.ds2_mode_var.get():
                lines.append(f"ds2_mode=Y")

        # Number of stores (use advanced config if available, otherwise use loaded value)
        if hasattr(self, 'n_stores_var'):
            n_stores = self.n_stores_var.get()
        elif selected_targets:
            n_stores = selected_targets[0]['stores']
        else:
            n_stores = 1  # Fallback default
        lines.append(f"n_stores={n_stores}")

        # Add target definitions
        lines.append("")
        lines.append("# Database targets")
        lines.append("# Format: target_N=path/to/executable:hostname")

        exe_ext = '.exe' if self.platform_support.is_windows else ''

        for idx, target_db in enumerate(selected_targets, start=1):
            db_dir = self.get_db_dir(target_db['type'])
            exe_name = f"{db_dir}_ds{exe_ext}"
            target_line = f"target_{idx}=../{db_dir}/{exe_name}:{target_db['host']}"
            lines.append(target_line)

        # Write orchestrator config file
        config_path = os.path.join(self.ds36_path, 'orchestrator', 'OrchestratorConfig.txt')
        os.makedirs(os.path.dirname(config_path), exist_ok=True)
        with open(config_path, 'w') as f:
            f.write('\n'.join(lines) + '\n')

        return config_path

    def _execute_driver(self, target_db, config_path):
        """Execute driver in background thread"""
        try:
            # Determine database directory
            db_dir = self.get_db_dir(target_db['type'])
            driver_cwd = os.path.join(self.ds36_path, db_dir)

            self.master.after_idle(lambda: self.log_output(f"\nStarting driver from {db_dir}/ directory...\n"))

            # Execute driver
            proc = subprocess.Popen(
                ['dotnet', 'run', '--', '--config_file=../DriverConfig.txt'],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=driver_cwd
            )

            # Store process for cancellation
            self.running_process = proc

            # Stream output line by line
            for line in iter(proc.stdout.readline, ''):
                if not line:
                    break
                # Update GUI from background thread
                self.master.after_idle(lambda msg=line: self.log_output(msg))

            # Wait for completion
            proc.wait()
            return_code = proc.returncode

            # Clear running process
            self.running_process = None

            # Update GUI based on result
            if return_code == 0:
                self.master.after_idle(lambda: self.log_output("\n✓ Driver completed successfully!\n", "success"))
            elif return_code == -15 or return_code == -9:  # SIGTERM or SIGKILL
                self.master.after_idle(lambda: self.log_output("\n⚠ Driver stopped by user\n", "error"))
            else:
                self.master.after_idle(lambda: self.log_output(f"\n✗ Driver failed (exit code {return_code})\n", "error"))

            # Re-enable run button, disable stop button
            self.master.after_idle(lambda: self.run_driver_button.config(state='normal', text='Run Driver'))
            self.master.after_idle(lambda: self.stop_driver_button.config(state='disabled'))

        except Exception as e:
            self.running_process = None
            self.master.after_idle(lambda err=e: self.log_output(f"\n✗ Error: {err}\n", "error"))
            self.master.after_idle(lambda: self.run_driver_button.config(state='normal', text='Run Driver'))
            self.master.after_idle(lambda: self.stop_driver_button.config(state='disabled'))

    def _execute_orchestrator(self, selected_targets):
        """Compile drivers and execute orchestrator in background thread"""
        try:
            # Step 1: Compile drivers for each selected target
            self.master.after_idle(lambda: self.log_output("\n=== Compiling Drivers ===\n"))

            for target_db in selected_targets:
                db_dir = self.get_db_dir(target_db['type'])
                db_path = os.path.join(self.ds36_path, db_dir)

                self.master.after_idle(lambda db=target_db['type']:
                    self.log_output(f"Compiling {db} driver...\n"))

                # Run dotnet publish to create standalone executable
                compile_proc = subprocess.Popen(
                    ['dotnet', 'publish', '-c', 'Release', '-o', '.'],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    cwd=db_path
                )

                # Stream compilation output
                for line in iter(compile_proc.stdout.readline, ''):
                    if not line:
                        break
                    # Only show important messages (errors, warnings, final success)
                    if 'error' in line.lower() or 'warning' in line.lower() or 'succeeded' in line.lower():
                        self.master.after_idle(lambda msg=line: self.log_output(f"  {msg}"))

                compile_proc.wait()
                if compile_proc.returncode != 0:
                    self.master.after_idle(lambda db=target_db['type']:
                        self.log_output(f"✗ Failed to compile {db} driver\n", "error"))
                    self.master.after_idle(lambda: self.run_driver_button.config(state='normal', text='Run Driver'))
                    self.master.after_idle(lambda: self.stop_driver_button.config(state='disabled'))
                    return

                self.master.after_idle(lambda db=target_db['type']:
                    self.log_output(f"✓ {db} driver compiled\n", "success"))

            # Step 2: Generate orchestrator config
            self.master.after_idle(lambda: self.log_output("\n=== Generating Orchestrator Config ===\n"))
            config_path = self.generate_orchestrator_config(selected_targets)
            self.master.after_idle(lambda path=config_path:
                self.log_output(f"Config written to {path}\n"))

            # Step 3: Run orchestrator
            self.master.after_idle(lambda: self.log_output("\n=== Running Orchestrator ===\n"))
            orchestrator_dir = os.path.join(self.ds36_path, 'orchestrator')

            proc = subprocess.Popen(
                ['dotnet', 'run', 'OrchestratorConfig.txt'],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=orchestrator_dir
            )

            # Store process for cancellation
            self.running_process = proc

            # Stream output line by line
            for line in iter(proc.stdout.readline, ''):
                if not line:
                    break
                # Update GUI from background thread
                self.master.after_idle(lambda msg=line: self.log_output(msg))

            # Wait for completion
            proc.wait()
            return_code = proc.returncode

            # Clear running process
            self.running_process = None

            # Update GUI based on result
            if return_code == 0:
                self.master.after_idle(lambda: self.log_output("\n✓ Orchestrator completed successfully!\n", "success"))
            elif return_code == -15 or return_code == -9:  # SIGTERM or SIGKILL
                self.master.after_idle(lambda: self.log_output("\n⚠ Orchestrator stopped by user\n", "error"))
            else:
                self.master.after_idle(lambda: self.log_output(f"\n✗ Orchestrator failed (exit code {return_code})\n", "error"))

            # Re-enable run button, disable stop button
            self.master.after_idle(lambda: self.run_driver_button.config(state='normal', text='Run Driver'))
            self.master.after_idle(lambda: self.stop_driver_button.config(state='disabled'))

        except Exception as e:
            self.running_process = None
            self.master.after_idle(lambda err=e: self.log_output(f"\n✗ Error: {err}\n", "error"))
            self.master.after_idle(lambda: self.run_driver_button.config(state='normal', text='Run Driver'))
            self.master.after_idle(lambda: self.stop_driver_button.config(state='disabled'))

    def create_output_console(self, parent):
        """Create output console widget"""
        console_frame = ttk.LabelFrame(parent, text="Output Console", padding="10")
        console_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        console_frame.columnconfigure(0, weight=1)
        console_frame.rowconfigure(0, weight=1)
        parent.columnconfigure(0, weight=1)
        parent.rowconfigure(0, weight=1)

        # Scrolled text widget - remove fixed height, let it expand
        self.output_text = scrolledtext.ScrolledText(console_frame, wrap=tk.WORD)
        self.output_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

        # Configure tags for colored output
        self.output_text.tag_config("success", foreground="green")
        self.output_text.tag_config("error", foreground="red")

    def populate_database_types(self):
        """Populate database type dropdown with dynamically detected databases"""
        databases = self.detect_available_databases_for_generation()
        self.db_type_combo['values'] = databases
        if databases:
            self.db_type_combo.current(0)
            self.on_db_type_changed(None)

    def detect_available_databases_for_generation(self):
        """Auto-detect databases for Step 1 (data generation - no client tools needed)"""
        databases = []

        # Map directory names to friendly names (only known databases)
        # Unknown databases will use uppercase directory name
        name_map = {
            'sqlserver': 'SQL Server',
            'mysql': 'MySQL',
            'pgsql': 'PostgreSQL',
            'oracle': 'Oracle'
        }

        # Scan for platform-appropriate scripts (.sh on Linux/Mac, .bat on Windows)
        try:
            for item in os.listdir(self.ds36_path):
                item_path = os.path.join(self.ds36_path, item)
                if os.path.isdir(item_path):
                    script_path = self.platform_support.get_script_path(item, self.ds36_path)
                    if os.path.exists(script_path):
                        db_name = name_map.get(item, item.upper())
                        databases.append(db_name)

                        # Parse script to determine parameter requirements
                        self._parse_script_syntax(item, script_path)
        except Exception as e:
            # Only log if output exists
            if hasattr(self, 'output_text'):
                self.log_output(f"Error detecting databases: {e}\n", "error")

        return sorted(databases)

    def _parse_script_syntax(self, db_dir, script_path):
        """Parse script header to determine parameter requirements

        Looks for lines like:
        # syntax is: script_name.sh <target> <stores> <password> [use_vectors]
        """
        try:
            with open(script_path, 'r') as f:
                line_count = 0
                for line in f:
                    line_count += 1
                    # Look for syntax/usage comment
                    if '# syntax' in line.lower() or '# usage' in line.lower():
                        # Extract parameter list
                        # Check if <password> is present
                        needs_password = '<password>' in line.lower()
                        # Check if use_vectors is present (optional with [] or required with <>)
                        supports_vectors = 'use_vectors' in line.lower() or 'use-vectors' in line.lower()

                        # Store in database metadata
                        self.db_params[db_dir] = {
                            'needs_password': needs_password,
                            'supports_vectors': supports_vectors
                        }

                        # Debug output (only if output_text exists)
                        if hasattr(self, 'output_text'):
                            self.log_output(f"Parsed {db_dir}: vectors={supports_vectors}, password={needs_password}\n")
                        break

                    # Stop scanning after first 20 lines (syntax should be at top)
                    if line_count > 20:
                        break
        except Exception as e:
            # Default to no password, supports vectors
            self.db_params[db_dir] = {
                'needs_password': False,
                'supports_vectors': True
            }
            # Only log if output exists
            if hasattr(self, 'output_text'):
                self.log_output(f"Parse error for {db_dir}: {e}\n", "error")

    def on_db_type_changed(self, event):
        """Handle database type selection change"""
        self.update_step1_visibility()

    def update_step1_visibility(self):
        """Show/hide Step 1 fields based on platform and selected database"""
        db_type = self.db_type_var.get()
        if not db_type:
            return

        db_dir = self.get_db_dir(db_type)

        # Vector search: only on Linux AND if database supports it
        show_vectors = False
        if self.platform_support.is_linux:
            if db_dir in self.db_params:
                show_vectors = self.db_params[db_dir].get('supports_vectors', False)

        if show_vectors:
            self.vector_search_check.grid(row=self.vector_search_row, column=1, sticky=tk.W, pady=2, padx=5)
        else:
            self.vector_search_check.grid_remove()

        # Database paths: only for Oracle/SQL Server
        if db_type in ['Oracle', 'SQL Server']:
            self.db_paths_entry.grid()
            self.db_paths_label.grid()
        else:
            self.db_paths_entry.grid_remove()
            self.db_paths_label.grid_remove()

    def get_db_dir(self, db_type):
        """Convert friendly database name to directory name"""
        name_to_dir = {
            'SQL Server': 'sqlserver',
            'MySQL': 'mysql',
            'PostgreSQL': 'pgsql',
            'Oracle': 'oracle'
        }
        return name_to_dir.get(db_type, db_type.lower().replace(' ', ''))

    def run_install_dvdstore(self):
        """Non-interactive execution of Install_DVDStore.pl"""
        self.log_output("\n=== Starting Data Generation ===\n")

        # Get form values
        db_type = self.db_type_var.get()
        db_size = self.db_size_entry.get()
        db_unit = self.db_unit_var.get()
        stores = self.stores_var.get()
        use_vectors = self.vector_search_var.get()
        db_paths = self.db_paths_entry.get().strip()

        # Validate inputs
        if not db_type:
            messagebox.showerror("Error", "Please select a database type")
            return

        try:
            size_int = int(db_size)
            if size_int <= 0:
                raise ValueError()
        except ValueError:
            messagebox.showerror("Error", "Database size must be a positive number")
            return

        # Build answers string for Install_DVDStore.pl
        # Install_DVDStore.pl only knows: MSSQL, MYSQL, PGSQL, ORACLE
        # Unknown databases default to MYSQL (compatible with most)
        db_type_map = {
            'SQL Server': 'MSSQL',
            'MySQL': 'MYSQL',
            'PostgreSQL': 'PGSQL',
            'Oracle': 'ORACLE'
        }
        db_type_code = db_type_map.get(db_type, 'MYSQL')  # Default to MYSQL for unknown DBs

        # Platform detection
        system_type = "WIN" if self.platform_support.is_windows else "LINUX"

        # Build answer string (one answer per line)
        answers = f"{db_size}\n"           # Size
        answers += f"{db_unit}\n"          # Unit (GB/MB)
        answers += f"{db_type_code}\n"     # Database type
        answers += f"{system_type}\n"      # System type

        # Database paths (only for Oracle/SQL Server)
        if db_type in ['Oracle', 'SQL Server']:
            if db_paths:
                answers += f"{db_paths}\n"
            else:
                # Use default path
                if self.platform_support.is_windows:
                    answers += "C:\\dbfiles\\\n"
                else:
                    answers += "/var/dbfiles/\n"

        # Vector search (Linux only)
        if self.platform_support.is_linux:
            answers += f"{'Y' if use_vectors else 'N'}\n"

        self.log_output(f"Database Type: {db_type}\n")
        self.log_output(f"Size: {db_size} {db_unit}\n")
        self.log_output(f"Stores: {stores}\n")
        self.log_output(f"Vector Search: {'Yes' if use_vectors else 'No'}\n")
        if db_paths:
            self.log_output(f"Database Paths: {db_paths}\n")
        self.log_output("\nRunning Install_DVDStore.pl...\n")

        # Disable button during execution
        self.generate_button.config(state='disabled', text='Generating...')

        # Run in background thread
        thread = threading.Thread(target=self._execute_install_dvdstore, args=(answers,), daemon=True)
        thread.start()

    def _execute_install_dvdstore(self, answers):
        """Execute Install_DVDStore.pl in background thread"""
        try:
            # Execute with piped input
            proc = subprocess.Popen(
                ['perl', 'Install_DVDStore.pl'],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=self.ds36_path
            )

            # Send answers and close stdin
            proc.stdin.write(answers)
            proc.stdin.close()

            # Stream output line by line
            for line in iter(proc.stdout.readline, ''):
                if not line:
                    break
                # Update GUI from background thread (use after_idle for thread safety)
                self.master.after_idle(lambda msg=line: self.log_output(msg))

            # Wait for completion
            proc.wait()
            return_code = proc.returncode

            # Update GUI based on result
            if return_code == 0:
                self.master.after_idle(lambda: self.log_output("\n✓ Data generation completed successfully!\n", "success"))
                self.master.after_idle(lambda: setattr(self, 'data_generated', True))
                # Remember which database type was used for generation
                gen_db_type = self.db_type_var.get()
                self.master.after_idle(lambda: setattr(self, 'generated_for_database', gen_db_type))
                self.master.after_idle(lambda: self.generate_button.config(state='normal', text='Generate Data Files'))
                # Update timestamp
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                self.master.after_idle(lambda: self.generate_timestamp_label.config(text=f"(last: {timestamp})"))
                # Enable Step 2 and update display fields
                self.master.after_idle(self.enable_step2)
            else:
                self.master.after_idle(lambda: self.log_output(f"\n✗ Data generation failed (exit code {return_code})\n", "error"))
                self.master.after_idle(lambda: self.generate_button.config(state='normal', text='Generate Data Files'))

        except Exception as e:
            self.master.after_idle(lambda err=e: self.log_output(f"\n✗ Error: {err}\n", "error"))
            self.master.after_idle(lambda: self.generate_button.config(state='normal', text='Generate Data Files'))

    def log_output(self, message, tag=None):
        """Append message to output console"""
        self.output_text.insert(tk.END, message, tag)
        self.output_text.see(tk.END)
        self.output_text.update()


def main():
    """Main entry point"""
    root = tk.Tk()
    app = DVDStoreGUI(root)
    root.mainloop()


if __name__ == '__main__':
    main()
