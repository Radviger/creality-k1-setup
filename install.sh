#!/bin/sh

# MJ: This script performs the initial setup by checking the internet connection,
# checking if Moonraker is already running, setting up working directories,
# backing up, and ensuring the printer.cfg file. It also triggers the verification
# and service start scripts as necessary.

# Function to print a warning
warn() {
    echo "WARNING: $1"
}

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

# Check if Moonraker is already running
if ps aux | grep '[m]oonraker' > /dev/null; then
    echo "Moonraker is already running. Configuring Fluidd and Mainsail with the existing Moonraker service."

    # Set the working directory
    WORKING_DIR="/usr/data"
    
    # Install Fluidd and Mainsail
    cd $WORKING_DIR
    [ ! -d "fluidd" ] && git clone https://github.com/fluidd-core/fluidd.git fluidd
    [ ! -d "mainsail" ] && git clone https://github.com/mainsail-crew/mainsail.git mainsail

    # Configure Nginx
    cat <<EOF > /opt/etc/nginx/nginx.conf
server {
    listen 80;
    server_name _;

    location /fluidd {
        alias /usr/data/fluidd;
        try_files \$uri \$uri/ /index.html;
    }

    location /mainsail {
        alias /usr/data/mainsail;
        try_files \$uri \$uri/ /index.html;
    }

    location /moonraker {
        proxy_pass http://localhost:7125;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

    # Restart Nginx to apply changes
    /opt/etc/init.d/S80nginx restart || exit_on_error "Failed to restart Nginx"

    echo "Configuration complete! Fluidd and Mainsail are set up with the existing Moonraker service."
    exit 0
fi

echo "Moonraker is not running. Proceeding with full installation."

# Set the working directory
WORKING_DIR="/usr/data"
PACKAGES_DIR="$WORKING_DIR/packages"
CONFIG_DIR="$WORKING_DIR/config"

# Verify that the 'packages' directory exists
if [ ! -d "$PACKAGES_DIR" ]; then
    exit_on_error "The directory $PACKAGES_DIR does not exist. Please ensure the repository is cloned correctly."
fi

# Verify that the 'python' and 'ipk' directories exist under 'packages'
if [ ! -d "$PACKAGES_DIR/python" ]; then
    exit_on_error "The directory $PACKAGES_DIR/python does not exist. Please create it and add the required .whl files."
fi

if [ ! -d "$PACKAGES_DIR/ipk" ]; then
    exit_on_error "The directory $PACKAGES_DIR/ipk does not exist. Please create it and add the required .ipk files."
fi

# Function to check if a Python package is installed
is_python_package_installed() {
    pip3 show "$1" > /dev/null 2>&1
    return $?
}

# Function to check if an IPK package is installed
is_ipk_package_installed() {
    opkg list-installed | grep -q "$1"
    return $?
}

# Verify that the required .whl files exist in the 'python' directory and try to install them if they don't
verify_and_install_whl_files() {
    for file in "$@"; do
        package_name=$(echo "$file" | sed 's/-[0-9].*//')
        if [ ! -f "$PACKAGES_DIR/python/$file" ]; then
            if is_python_package_installed "$package_name"; then
                echo "$package_name is already installed."
            else
                warn "Required file $file not found in $PACKAGES_DIR/python and $package_name is not installed. Attempting to download and install..."
                pip3 install "$package_name" || exit_on_error "Failed to install $package_name from PyPI"
            fi
        else
            pip3 install "$PACKAGES_DIR/python/$file" || exit_on_error "Failed to install $file from local file"
        fi
    done
}

verify_and_install_whl_files \
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
    "watchdog-2.1.9-py3-none-any.whl"

# List of required Python packages to be installed via pip
required_python_packages="python3-virtualenv python3-dev liblmdb-dev libopenjp2-7 libsodium-dev zlib1g-dev libjpeg-dev packagekit wireless-tools curl"

# Install the required Python packages
for package in $required_python_packages; do
    if ! is_python_package_installed "$package"; then
        echo "Installing $package via pip..."
        pip3 install "$package" || exit_on_error "Failed to install $package from PyPI"
    fi
done

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

# Ensure virtualenv is installed and create a symlink if necessary
pip3 show virtualenv > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "virtualenv is not installed. Installing virtualenv from PyPI..."
    pip3 install virtualenv || exit_on_error "Failed to install virtualenv from PyPI"
fi

VIRTUALENV_PATH=$(which virtualenv)
if [ -z "$VIRTUALENV_PATH" ]; then
    VIRTUALENV_PATH=$(pip show virtualenv | grep Location | awk '{print $2}')/bin/virtualenv
fi

# Ensure virtualenv is available at /usr/bin/virtualenv
if [ ! -f /usr/bin/virtualenv ]; then
    ln -s "$VIRTUALENV_PATH" /usr/bin/virtualenv || exit_on_error "Failed to create symlink for virtualenv"
fi

# Modify the install-moonraker.sh script
echo "Modifying install-moonraker.sh to work without sudo and apt-get..."
sed -i 's/sudo //g' ./scripts/install-moonraker.sh
sed -i '/apt-get/d' ./scripts/install-moonraker.sh

# Run install-moonraker.sh with bash as moonrakeruser
echo "Running install-moonraker.sh with bash as moonrakeruser..."
su - moonrakeruser -c "PATH=$PATH:/usr/bin bash ./scripts/install-moonraker.sh" || exit_on_error "Failed to run Moonraker install script as moonrakeruser"

# Trigger the service start script
echo "Running service start script..."
sh scripts/start_services.sh || exit_on_error "Failed to run service start script"

echo "Installation complete!"
