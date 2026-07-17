@echo off
REM DVD Store 3.6 GUI Launcher (Windows)
REM Convenience script to launch the GUI from the ds36 root directory

cd /d "%~dp0gui"
python dvdstore-gui.py
