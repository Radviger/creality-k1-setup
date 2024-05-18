#!/bin/sh

# MJ: This script installs Moonraker and sets up the Python virtual environment.

# Function to print and exit on error
exit_on_error() {
    echo "$1"
    exit 1
}

# Ensure bash is installed
BASH_PATH=$(which bash)
if [ -z "$BASH_PATH" ]; then
    echo "Bash is not installed. Installing bash..."
    opkg install bash || exit_on_error "Failed to install bash"
fi

# Set the working directory
WORKING_DIR="/usr/data"
MOONRAKER_DIR="$WORKING_DIR/moonraker"
VENV_DIR="$WORKING_DIR/moonraker-env"

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

# Upgrade pip
pip install --upgrade pip || exit_on_error "Failed to upgrade pip"

# Create virtual environment using virtualenv.py directly
echo "Creating virtual environment..."
python3 /usr/lib/python3.8/site-packages/virtualenv.py -p /usr/bin/python3 $VENV_DIR || exit_on_error "Failed to create virtual environment"

# Activate virtual environment and install requirements
echo "Activating virtual environment and installing requirements..."
source $VENV_DIR/bin/activate
pip install --trusted-host pypi.python.org --trusted-host pypi.org --trusted-host files.pythonhosted.org -r ./scripts/moonraker-requirements.txt || exit_on_error "Failed to install Moonraker requirements"

# Set environment variable to use system lmdb
export LMDB_FORCE_SYSTEM=1

# Run install-moonraker.sh with bash as moonrakeruser
echo "Running install-moonraker.sh with bash as moonrakeruser..."
su moonrakeruser -c "bash ./scripts/install-moonraker.sh" || exit_on_error "Failed to run Moonraker install script as moonrakeruser"

echo "Moonraker installation complete."
