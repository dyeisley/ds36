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

        # Two-column layout: Steps on left, Console on right
        main_frame.columnconfigure(0, weight=2, minsize=600)  # Left column (steps) - wider for long fields
        main_frame.columnconfigure(1, weight=3)  # Right column (console)
        main_frame.rowconfigure(1, weight=1)     # Row 1 expands vertically

        # Title spans both columns
        title = ttk.Label(main_frame, text="DVD Store 3.6 Benchmark",
                         font=('TkDefaultFont', 16, 'bold'))
        title.grid(row=0, column=0, columnspan=2, pady=10)

        # Left column: Steps 1, 2, 3
        left_frame = ttk.Frame(main_frame)
        left_frame.grid(row=1, column=0, sticky=(tk.W, tk.E, tk.N, tk.S), padx=(0, 5))
        left_frame.columnconfigure(0, weight=1)

        self.create_step1_widgets(left_frame)
        self.create_step2_widgets(left_frame)
        self.create_step3_widgets(left_frame)

        # Right column: Output console
        self.create_output_console(main_frame)

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

        # Generate button
        self.generate_button = ttk.Button(step1_frame, text="Generate Data Files",
                                         command=self.run_install_dvdstore)
        self.generate_button.grid(row=row, column=0, columnspan=3, pady=10)

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
            self.master.after_idle(lambda: self.log_output(f"\n✗ Error: {e}\n", "error"))
            self.master.after_idle(lambda: self.load_button.config(state='normal', text='Load Database'))

    def add_loaded_database(self, db_type, host, stores, vectors):
        """Add successfully loaded database to the list"""
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
        """Update Step 3 target database dropdown from loaded databases"""
        if self.loaded_databases:
            # Build list of "DatabaseType @ Host" strings
            targets = [f"{db['type']} @ {db['host']}" for db in self.loaded_databases]
            self.target_db_combo['values'] = targets
            self.target_db_combo.config(state='readonly')

            # Auto-select the first one if nothing selected
            if not self.target_db_var.get() and targets:
                self.target_db_combo.current(0)

            # Enable Step 3
            self.run_driver_button.config(state='normal')
        else:
            self.target_db_combo['values'] = []
            self.target_db_combo.config(state='disabled')
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

        # Target Database Selection (from loaded databases)
        ttk.Label(step3_frame, text="Target Database:").grid(row=row, column=0, sticky=tk.W, pady=2)
        self.target_db_var = tk.StringVar()
        self.target_db_combo = ttk.Combobox(step3_frame, textvariable=self.target_db_var, state='readonly')
        self.target_db_combo.grid(row=row, column=1, sticky=(tk.W, tk.E), pady=2, padx=5)
        self.target_db_combo.bind('<<ComboboxSelected>>', self.on_target_db_changed)
        ToolTip(self.target_db_combo, "Select which loaded database to run the benchmark against.\n"
                                       "You must load at least one database in Step 2 first.")
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

        # Configure/Run buttons
        button_frame = ttk.Frame(step3_frame)
        button_frame.grid(row=row, column=0, columnspan=2, pady=10)

        ttk.Button(button_frame, text="Advanced Configuration...",
                  command=self.open_advanced_config).pack(side=tk.LEFT, padx=5)

        self.run_driver_button = ttk.Button(button_frame, text="Run Driver",
                                            command=self.run_driver)
        self.run_driver_button.pack(side=tk.LEFT, padx=5)

        # Initially disable until Step 2 completes
        self.run_driver_button.config(state='disabled')
        self.target_db_combo.config(state='disabled')

    def on_target_db_changed(self, event):
        """Handle target database selection change"""
        # Future: auto-populate target host, stores, etc.
        pass

    def open_advanced_config(self):
        """Open advanced configuration dialog"""
        # TODO: Create a dialog window with tabbed interface for all parameters
        messagebox.showinfo("Advanced Configuration",
                          "Advanced configuration dialog will be implemented next.\n\n"
                          "Will include tabs for:\n"
                          "- Workload Mix\n"
                          "- Manager Operations\n"
                          "- Analytics\n"
                          "- Advanced Options")

    def run_driver(self):
        """Generate config and run driver"""
        self.log_output("\n=== Running Driver ===\n")

        # Validation: ensure database was loaded
        if not self.loaded_databases:
            messagebox.showerror("Error", "Please load a database first (Step 2)")
            return

        target_db = self.target_db_var.get()
        if not target_db:
            messagebox.showerror("Error", "Please select a target database")
            return

        self.log_output(f"Target: {target_db}\n")
        self.log_output(f"Threads: {self.threads_spinbox.get()}\n")
        self.log_output(f"Run Time: {self.runtime_spinbox.get()} minutes\n")

        # TODO: Generate DriverConfig.txt and execute driver
        self.log_output("Driver execution not yet implemented...\n", "error")

    def create_output_console(self, parent):
        """Create output console widget"""
        console_frame = ttk.LabelFrame(parent, text="Output Console", padding="10")
        console_frame.grid(row=1, column=1, sticky=(tk.W, tk.E, tk.N, tk.S), pady=5)
        console_frame.columnconfigure(0, weight=1)
        console_frame.rowconfigure(0, weight=1)

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
                # Enable Step 2 and update display fields
                self.master.after_idle(self.enable_step2)
            else:
                self.master.after_idle(lambda: self.log_output(f"\n✗ Data generation failed (exit code {return_code})\n", "error"))
                self.master.after_idle(lambda: self.generate_button.config(state='normal', text='Generate Data Files'))

        except Exception as e:
            self.master.after_idle(lambda: self.log_output(f"\n✗ Error: {e}\n", "error"))
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
