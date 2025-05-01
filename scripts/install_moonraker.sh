#!/bin/sh

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

# Install pip if not already available
if ! command -v pip3 >/dev/null 2>&1; then
    echo "pip3 is not installed. Installing python3-pip..."
    /opt/bin/opkg update
    /opt/bin/opkg install python3-pip || exit_on_error "Failed to install python3-pip"
fi

# Install virtualenv using pip directly
echo "Installing virtualenv..."
pip3 install virtualenv || exit_on_error "Failed to install virtualenv with pip3"

# Create virtual environment using Python module approach
echo "Creating virtual environment using Python module..."
python3 -m virtualenv $VENV_DIR || {
    echo "Failed to create virtual environment with python3 -m virtualenv."
    echo "Attempting alternative method with direct Python commands..."
    
    # Create directory
    mkdir -p $VENV_DIR || exit_on_error "Failed to create virtual environment directory"
    
    # Create venv structure manually using Python's built-in venv
    python3 -m venv $VENV_DIR || {
        echo "Python's venv module failed too. Attempting minimal venv creation..."
        
        # If both methods fail, try to create a minimal virtual environment
        mkdir -p $VENV_DIR/bin
        mkdir -p $VENV_DIR/lib/python$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')/site-packages
        
        # Create activate script
        cat > $VENV_DIR/bin/activate << EOF
# This file must be used with "source bin/activate" *from bash*
# You cannot run it directly
deactivate () {
    unset -f pydoc >/dev/null 2>&1
    unset -f deactivate
    unset VIRTUAL_ENV
    if [ ! "\${1:-}" = "nondestructive" ] ; then
    # Self destruct!
        unset -f deactivate
    fi
}
VIRTUAL_ENV="$VENV_DIR"
export VIRTUAL_ENV
_OLD_VIRTUAL_PATH="\$PATH"
PATH="\$VIRTUAL_ENV/bin:\$PATH"
export PATH
EOF
        
        # Create symlink to python
        ln -sf $(which python3) $VENV_DIR/bin/python
        ln -sf $(which python3) $VENV_DIR/bin/python3
        ln -sf $(which pip3) $VENV_DIR/bin/pip
        ln -sf $(which pip3) $VENV_DIR/bin/pip3
    }
}

# Activate virtual environment
echo "Activating virtual environment..."
. $VENV_DIR/bin/activate || exit_on_error "Failed to activate virtual environment"

# Upgrade pip within the virtual environment
pip install --upgrade pip || echo "Warning: Failed to upgrade pip, continuing anyway..."

# Install Moonraker requirements directly to the system Python
echo "Installing Moonraker requirements..."
pip install --trusted-host pypi.python.org --trusted-host pypi.org --trusted-host files.pythonhosted.org -r $MOONRAKER_DIR/scripts/moonraker-requirements.txt || {
    echo "Failed to install via requirements file. Installing packages individually..."
    
    # Install key packages one by one
    pip install tornado>=6.1.0,<7.0.0
    pip install pyserial>=3.4
    pip install pillow>=8.0.1
    pip install lmdb>=1.2.0
    pip install streaming-form-data>=1.8.0
    pip install distro>=1.5.0
    pip install inotify-simple>=1.3.5
    pip install libnacl>=1.7.2
    pip install paho-mqtt>=1.5.1
    pip install zeroconf>=0.32.1
    pip install preprocess-cancellation>=0.2.0
    pip install jinja2>=3.0.0
    pip install dbus-next>=0.2.3
    pip install apprise>=1.1.0
    pip install ldap3>=2.9.1
}

# Set environment variable to use system lmdb
export LMDB_FORCE_SYSTEM=1

# Run install-moonraker.sh with bash
echo "Running install-moonraker.sh with bash..."
cd $MOONRAKER_DIR
bash $MOONRAKER_DIR/scripts/install-moonraker.sh || {
    echo "Warning: Moonraker install script failed but we'll continue setup."
    
    # Create manual moonraker service file
    cat > /etc/init.d/moonraker << 'EOF'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/data/moonraker-env/bin/python /usr/data/moonraker/moonraker/moonraker.py -d /usr/data/printer_data
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}
EOF
    chmod +x /etc/init.d/moonraker
    
    # Try to start the service
    /etc/init.d/moonraker start
}

echo "Moonraker installation complete."