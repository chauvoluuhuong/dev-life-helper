#!/bin/bash

# vpsSync.sh - Interactive VPS Sync and Copy Utility
# This is a global entrypoint wrapped around the python implementation.

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure Python 3 is installed
if ! command -v python3 &>/dev/null; then
    echo -e "\033[31mError: Python 3 is not installed or not in your PATH.\033[0m"
    echo "Please install Python 3 to run this script."
    exit 1
fi

# Run the python script and pass all command-line arguments to it
python3 "$SCRIPT_DIR/vpsSync.py" "$@"
