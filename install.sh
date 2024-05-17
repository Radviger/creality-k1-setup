#!/bin/sh

# MJ: This script performs the initial setup by checking the internet connection,
# setting up working directories, backing up, and ensuring the printer.cfg file.
# It also triggers the verification and service start scripts.

# Function to print and exit on error
exit_on_error() {
    echo "$1"
    exit 1
}

# Check if connected to the internet
ping -c 1 google.com > /dev/null 2>&1
if [ $? -ne 0 ]; then
    exit_on_error "No internet connection. Please download the necessary packages manually. See the text files (requirements/requirements.txt, requirements/requirements_pypi.txt, requirements/ipk-packages.txt) for the list of packages."
else
    echo "Internet connection verified."
fi

# Set the working directory
WORKING_DIR="/usr/data"
PACKAGES_DIR="$WORKING_DIR/packages"
CONFIG_DIR="$WORKING_DIR/config"

# Create necessary directories if they don't exist
mkdir -p "$PACKAGES_DIR/python" || exit_on_error "Failed to create directory $PACKAGES_DIR/python"
mkdir -p "$PACKAGES_DIR/ipk" || exit_on_error "Failed to create directory $PACKAGES_DIR/ipk"

# Verify that the required .whl files exist
verify_whl_files() {
    for file in "$@"; do
        if [ ! -f "$PACKAGES_DIR/python/$file" ]; then
            exit_on_error "Required file $file not found in $PACKAGES_DIR/python"
        fi
    done
}

verify_whl_files \
    "zipp-3.18.1-py3-none-any.whl" \
    "typing_extensions-4.11.0-py3-none-any.whl" \
    "tomli-2.0.1-py3-none-any.whl" \
    "setuptools_scm-8.1.0-py3-none-any.whl" \
    "importlib_metadata-7.1.0-py3-none-any.whl" \
    "Markdown-3.6-py3-none-any.whl" \
    "mkdocs-1.6.0-py3-none-any.whl" \
    "mergedeep-1.3.4-py3-none-any.whl" \
    "packaging-24.0-py3-none-any.whl" \
    "jinja2-3.1.4-py3-none-any.whl" \
    "watchdog-4.0.0-py3-none-manylinux2014_armv7l.whl"

# Verify that the required .ipk files exist (assuming these files are listed in ipk-packages.txt)
if [ -f "requirements/ipk-packages.txt" ]; then
    while IFS= read -r ipk_file; do
        if [ ! -f "$PACKAGES_DIR/ipk/$ipk_file" ]; then
            exit_on_error "Required file $ipk_file not found in $PACKAGES_DIR/ipk"
        fi
    done < requirements/ipk-packages.txt
else
    exit_on_error "File requirements/ipk-packages.txt not found"
fi

# Backup existing printer.cfg
PRINTER_CFG="/usr/data/printer_data/config/printer.cfg"
BACKUP_PRINTER_CFG="/usr/data/printer_data/config/printer.cfg.backup"

if [ -f "$PRINTER_CFG" ]; then
    echo "Backing up existing printer.cfg to $BACKUP_PRINTER_CFG"
    cp "$PRINTER_CFG" "$BACKUP_PRINTER_CFG" || exit_on_error "Failed to backup printer.cfg"
else
    echo "No existing printer.cfg found to backup."
fi

# Ensure printer.cfg is accessible
FLUIDD_KLIPPER_CFG_DIR="/etc/fluidd_klipper/config"

if [ ! -d "$FLUIDD_KLIPPER_CFG_DIR" ]; then
    echo "Creating directory $FLUIDD_KLIPPER_CFG_DIR"
    mkdir -p "$FLUIDD_KLIPPER_CFG_DIR" || exit_on_error "Failed to create directory $FLUIDD_KLIPPER_CFG_DIR"
fi

# Copy or create a symlink for the printer.cfg file
if [ -f "$PRINTER_CFG" ]; then
    echo "Copying printer.cfg to $FLUIDD_KLIPPER_CFG_DIR"
    cp "$PRINTER_CFG" "$FLUIDD_KLIPPER_CFG_DIR/printer.cfg" || exit_on_error "Failed to copy printer.cfg"
else
    exit_on_error "No printer.cfg found to copy."
fi

# Trigger the verification script
echo "Running verification script..."
sh scripts/verify_packages.sh || exit_on_error "Failed to run verification script"

# Ensure virtualenv is installed
pip3 show virtualenv > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "virtualenv is not installed. Installing virtualenv from PyPI..."
    pip3 install virtualenv || exit_on_error "Failed to install virtualenv from PyPI"
fi

# Trigger the service start script
echo "Running service start script..."
sh scripts/start_services.sh || exit_on_error "Failed to run service start script"

echo "Installation complete!"
