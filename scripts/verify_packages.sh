#!/bin/sh

# MJ: This script verifies and installs essential IPK packages and Python packages.
# It also checks Python version compatibility and creates the moonrakeruser.

# Function to print and exit on error
exit_on_error() {
    echo "$1"
    exit 1
}

# Set the working directory
WORKING_DIR="/usr/data"
PACKAGES_DIR="$WORKING_DIR/packages"

# Ensure the directories exist
if [ ! -d "$PACKAGES_DIR/python" ]; then
    exit_on_error "The directory $PACKAGES_DIR/python does not exist. Please create it and add the required .whl files."
fi

# Essential packages list
packages="python3 libzstd make gcc binutils ar objdump libbfd libopcodes libintl-full wget curl sudo bash"

# Install IPK packages using Entware
echo "Installing IPK packages..."
for package in $packages; do
    if opkg list-installed | grep -q "$package"; then
        echo "$package is already installed."
    else
        if [ -f "$PACKAGES_DIR/ipk/${package}_*.ipk" ]; then
            echo "Installing $package from local file."
            opkg install "$PACKAGES_DIR/ipk/${package}_*.ipk" || exit_on_error "Failed to install $package from local file"
        else
            echo "Installing $package from Entware repository..."
            opkg install $package || exit_on_error "Failed to install $package"
        fi
    fi
done

# Install Python packages
echo "Installing Python packages..."
pip3 install --no-index --find-links=$PACKAGES_DIR/python -r requirements/requirements.txt || echo "Failed to install Python packages from $PACKAGES_DIR/python. Attempting to install from PyPI..."
pip3 install --no-cache-dir -r requirements/requirements_pypi.txt || exit_on_error "Failed to install Python packages from PyPI"

# Check for Python version compatibility
python_version=$(python3 -c 'import sys; print(sys.version_info.major, sys.version_info.minor)')
major_version=$(echo $python_version | cut -d' ' -f1)
minor_version=$(echo $python_version | cut -d' ' -f2)

if [ $major_version -lt 3 ] || { [ $major_version -eq 3 ] && [ $minor_version -lt 6 ]; }; then
    exit_on_error "Python version is not compatible. Please upgrade to Python 3.6 or later."
fi

# Create moonrakeruser and home directory
echo "Creating user moonrakeruser..."
if ! id "moonrakeruser" >/dev/null 2>&1; then
    adduser -h /usr/data/home/moonrakeruser -D moonrakeruser || exit_on_error "Failed to create user moonrakeruser"
else
    echo "User moonrakeruser already exists."
fi
