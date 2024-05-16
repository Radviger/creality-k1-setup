#!/bin/sh

# Function to print and exit on error
exit_on_error() {
    echo "$1"
    exit 1
}

# Check if connected to the internet
ping -c 1 google.com > /dev/null 2>&1
if [ $? -ne 0 ]; then
    exit_on_error "No internet connection. Please download the necessary packages manually. See the text files (ipk-packages.txt and requirements.txt) for the list of packages."
else
    echo "Internet connection verified."
fi

# Check for sufficient disk space (1GB in this example)
if [ $(df --output=avail "$PWD" | tail -n1) -lt 1000000 ]; then
    exit_on_error "Not enough disk space. Please free up some space and try again."
fi

# Set the working directory
WORKING_DIR="/usr/data"
PACKAGES_DIR="$WORKING_DIR/packages"
CONFIG_DIR="$WORKING_DIR/config"

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

# List of packages and their versions
packages_versions="python3-lib2to3-3.11.7-1 libzstd-1.5.5-1 python3-dev-3.11.7-1 make-4.4.1-1 gcc-8.4.0-5c binutils-2.41-1 ar-2.41-1 objdump-2.41-1 libbfd-2.41-1 libopcodes-2.41-1 libintl-full-0.21.1-2 wget-1.21.1-1 curl-8.6.0-1"

# Install IPK packages using Entware
echo "Installing IPK packages..."
for package_version in $packages_versions
do
    package=$(echo $package_version | cut -d'-' -f1)
    version=$(echo $package_version | cut -d'-' -f2-)
    if opkg list-installed | grep -q "$package"; then
        echo "$package is already installed."
    else
        if [ -f "$PACKAGES_DIR/${package}_${version}_mipsel-3.4.ipk" ]; then
            echo "Installing specific version of $package from local file."
            opkg install "$PACKAGES_DIR/${package}_${version}_mipsel-3.4.ipk" || exit_on_error "Failed to install $package from local file"
        else
            echo "Specific version of $package not found locally. Checking Entware repository..."
            if opkg install "${package}=${version}"; then
                echo "Installed specific version of $package from Entware repository."
            else
                echo "Specific version of $package not found in Entware repository. Installing latest version..."
                opkg install $package || exit_on_error "Failed to install $package"
            fi
        fi
    fi
done

# Install Python packages
echo "Installing Python packages..."
pip3 install --no-index --find-links=$PACKAGES_DIR -r requirements.txt || echo "Failed to install Python packages from $PACKAGES_DIR. Attempting to install from PyPI..."
pip3 install --no-cache-dir -r requirements_pypi.txt || echo "Failed to install Python packages from PyPI"

# Check for Python version compatibility
python_version=$(python3 -c 'import sys; print(sys.version_info.major, sys.version_info.minor)')
major_version=$(echo $python_version | cut -d' ' -f1)
minor_version=$(echo $python_version | cut -d' ' -f2)

if [ $major_version -lt 3 ] || [ $major_version -eq 3 -a $minor_version -lt 6 ]; then
    exit_on_error "Python version is not compatible. Please upgrade to Python 3.6 or later."
fi

# Install Nginx
echo "Installing Nginx..."
opkg install nginx || exit_on_error "Failed to install Nginx"

# Install Mainsail
echo "Installing Mainsail..."
MAINSAIL_DIR="$WORKING_DIR/mainsail"
if [ ! -d "$MAINSAIL_DIR" ]; then
    mkdir -p $MAINSAIL_DIR || exit_on_error "Failed to create directory $MAINSAIL_DIR"
fi
cd $MAINSAIL_DIR || exit_on_error "Failed to change directory to $MAINSAIL_DIR"
git clone https://github.com/mainsail-crew/mainsail.git || exit_on_error "Failed to download Mainsail"


# Install Moonraker
echo "Installing Moonraker..."
MOONRAKER_DIR="$WORKING_DIR/moonraker"
if [ -d "$MOONRAKER_DIR" ]; then
    echo "Moonraker directory already exists. Deleting..."
    rm -rf $MOONRAKER_DIR || exit_on_error "Failed to delete directory $MOONRAKER_DIR"
fi
mkdir -p $MOONRAKER_DIR || exit_on_error "Failed to create directory $MOONRAKER_DIR"
cd $MOONRAKER_DIR || exit_on_error "Failed to change directory to $MOONRAKER_DIR"
git clone https://github.com/Arksine/moonraker.git $MOONRAKER_DIR || exit_on_error "Failed to clone Moonraker"
cd $MOONRAKER_DIR || exit_on_error "Failed to change directory to $MOONRAKER_DIR"
./scripts/install-moonraker.sh || exit_on_error "Failed to run Moonraker install script"

# Install Fluidd
echo "Installing Fluidd..."
FLUIDD_DIR="$WORKING_DIR/fluidd"
if [ ! -d "$FLUIDD_DIR" ]; then
    mkdir -p $FLUIDD_DIR || exit_on_error "Failed to create directory $FLUIDD_DIR"
fi
cd $FLUIDD_DIR || exit_on_error "Failed to change directory to $FLUIDD_DIR"
git clone https://github.com/fluidd-core/fluidd.git || exit_on_error "Failed to download Fluidd"


# Configure Nginx for Mainsail and Fluidd
echo "Configuring Nginx..."
cat <<EOF > /opt/etc/nginx/nginx.conf
server {
    listen 8081;
    server_name _;

    location / {
        root $MAINSAIL_DIR;
        try_files \$uri \$uri/ /index.html;
    }
}

server {
    listen 8082;
    server_name _;

    location / {
        root $FLUIDD_DIR;
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

if [ $? -ne 0 ]; then
    exit_on_error "Failed to write Nginx configuration"
fi

# Restart Nginx
echo "Restarting Nginx..."
/opt/etc/init.d/S80nginx restart || exit_on_error "Failed to restart Nginx"

# Start Moonraker
echo "Starting Moonraker..."
/opt/etc/init.d/S80moonraker start || exit_on_error "Failed to start Moonraker"
/opt/etc/init.d/S80moonraker enable || exit_on_error "Failed to enable Moonraker"

echo "Installation complete! Mainsail is running on port 8081 and Fluidd on port 8082."
