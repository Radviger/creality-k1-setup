#!/bin/sh

# MJ: This script installs Moonraker and sets up the Python virtual environment.

# Function to print and exit on error
exit_on_error() {
    echo "$1"
    exit 1
}

# Set the working directory
WORKING_DIR="/usr/data"
MOONRAKER_DIR="$WORKING_DIR/moonraker"
VENV_DIR="$WORKING_DIR/moonraker-env"
TMPDIR="$WORKING_DIR/tmp"

# Ensure TMPDIR exists
mkdir -p "$TMPDIR"

# Export TMPDIR to use during pip installations
export TMPDIR="$TMPDIR"

# Ensure PATH includes Entware
export PATH=$PATH:/opt/bin:/opt/sbin

# Check if bash is installed
BASH_PATH=$(which bash)
if [ -z "$BASH_PATH" ]; then
    echo "Bash is not installed. Installing bash..."
    /opt/bin/opkg install bash || exit_on_error "Failed to install bash"
fi

# Install Moonraker
echo "Installing Moonraker..."
if [ -d "$MOONRAKER_DIR" ]; then
    echo "Moonraker directory already exists. Deleting..."
    rm -rf $MOONRAKER_DIR || exit_on_error "Failed to delete directory $MOONRAKER_DIR"
fi
mkdir -p $MOONRAKER_DIR || exit_on_error "Failed to create directory $MOONRAKER_DIR"
cd $WORKING_DIR || exit_on_error "Failed to change directory to $WORKING_DIR"
git clone https://github.com/Arksine/moonraker.git $MOONRAKER_DIR || exit_on_error "Failed to clone Moonraker"
cd $MOONRAKER_DIR || exit_on_error "Failed to change directory to $MOONRAKER_DIR"
echo "Checking if install-moonraker.sh exists..."
ls -l ./scripts/
if [ ! -f "./scripts/install-moonraker.sh" ]; then
    exit_on_error "install-moonraker.sh not found"
fi

# Modify the install-moonraker.sh script
echo "Modifying install-moonraker.sh to work without sudo and apt-get..."
sed -i 's/sudo //g' ./scripts/install-moonraker.sh
sed -i '/apt-get/d' ./scripts/install-moonraker.sh

# Install virtualenv if not available
echo "Checking for virtualenv..."
if ! command -v virtualenv >/dev/null 2>&1; then
    echo "virtualenv is not installed. Installing virtualenv..."
    pip3 install virtualenv || {
        echo "Failed to install virtualenv with pip3, trying with opkg..."
        /opt/bin/opkg update
        /opt/bin/opkg install python3-virtualenv || exit_on_error "Failed to install virtualenv"
    }
fi

# Verify virtualenv is installed
if ! command -v virtualenv >/dev/null 2>&1; then
    # If virtualenv is still not in PATH, try to find it
    VIRTUALENV_PATH=$(find /usr -name virtualenv -type f 2>/dev/null | head -n 1)
    if [ -z "$VIRTUALENV_PATH" ]; then
        VIRTUALENV_PATH=$(find /opt -name virtualenv -type f 2>/dev/null | head -n 1)
    fi
    
    if [ -z "$VIRTUALENV_PATH" ]; then
        # If we still can't find it, try installing it again with pip
        echo "Trying alternative virtualenv installation..."
        python3 -m pip install virtualenv || exit_on_error "Failed to install virtualenv with pip"
        VIRTUALENV_PATH="python3 -m virtualenv"
    else
        echo "Found virtualenv at $VIRTUALENV_PATH"
    fi
else
    VIRTUALENV_PATH=$(which virtualenv)
    echo "virtualenv found in PATH: $VIRTUALENV_PATH"
fi

# Create virtual environment
echo "Creating virtual environment..."
if [ "$VIRTUALENV_PATH" = "python3 -m virtualenv" ]; then
    python3 -m virtualenv $VENV_DIR || exit_on_error "Failed to create virtual environment"
else
    $VIRTUALENV_PATH -p $(which python3) $VENV_DIR || exit_on_error "Failed to create virtual environment"
fi

# Activate virtual environment
echo "Activating virtual environment..."
. $VENV_DIR/bin/activate || exit_on_error "Failed to activate virtual environment"

# Upgrade pip within the virtual environment
pip install --upgrade pip || echo "Warning: Failed to upgrade pip, continuing anyway..."

# Install Moonraker requirements
echo "Installing Moonraker requirements..."
pip install --trusted-host pypi.python.org --trusted-host pypi.org --trusted-host files.pythonhosted.org -r $MOONRAKER_DIR/scripts/moonraker-requirements.txt || exit_on_error "Failed to install Moonraker requirements"

# Set environment variable to use system lmdb
export LMDB_FORCE_SYSTEM=1

# Run install-moonraker.sh with bash
echo "Running install-moonraker.sh with bash..."
cd $MOONRAKER_DIR
bash $MOONRAKER_DIR/scripts/install-moonraker.sh || exit_on_error "Failed to run Moonraker install script"

echo "Moonraker installation complete."