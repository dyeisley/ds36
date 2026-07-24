#!/bin/bash
# DVD Store 3.6 GUI Launcher
# Convenience script to launch the GUI from the ds36 root directory

cd "$(dirname "$0")/gui"
python3 dvdstore-gui.py
