#!/bin/sh

# Common directories
WORKING_DIR="/usr/data"
PACKAGES_DIR="$WORKING_DIR/packages"
CONFIG_DIR="$WORKING_DIR/config"
SCRIPTS_DIR="$WORKING_DIR/creality-k1-setup/scripts"
FLUIDD_KLIPPER_CFG_DIR="/etc/fluidd_klipper/config"
PRINTER_CFG="/usr/data/printer_data/config/printer.cfg"
BACKUP_PRINTER_CFG="/usr/data/printer_data/config/printer.cfg.backup"
TMPDIR="$WORKING_DIR/tmp"

# Ensure TMPDIR exists
mkdir -p "$TMPDIR"

# Export TMPDIR to use during pip installations
export TMPDIR="$TMPDIR"

# Function to print and exit on error
exit_on_error() {
    echo "$1"
    exit 1
}
