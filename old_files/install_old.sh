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

# Essential packages list
packages="python3 libzstd make gcc binutils ar objdump libbfd libopcodes libintl-full wget curl sudo bash"

# Install IPK packages using Entware
echo "Installing IPK packages..."
for package in $packages; do
    if opkg list-installed | grep -q "$package"; then
        echo "$package is already installed."
    else
        if [ -f "$PACKAGES_DIR/${package}_*.ipk" ]; then
            echo "Installing $package from local file."
            opkg install "$PACKAGES_DIR/${package}_*.ipk" || exit_on_error "Failed to install $package from local file"
        else
            echo "Installing $package from Entware repository..."
            opkg install $package || exit_on_error "Failed to install $package"
        fi
    fi
done

# Install Python packages
echo "Installing Python packages..."
pip3 install --no-index --find-links=$PACKAGES_DIR -r requirements.txt || echo "Failed to install Python packages from $PACKAGES_DIR. Attempting to install from PyPI..."
pip3 install --no-cache-dir -r requirements_pypi.txt || exit_on_error "Failed to install Python packages from PyPI"

# Check for Python version compatibility
python_version=$(python3 -c 'import sys; print(sys.version_info.major, sys.version_info.minor)')
major_version=$(echo $python_version | cut -d' ' -f1)
minor_version=$(echo $python_version | cut -d' ' -f2)

if [ $major_version -lt 3 ] || { [ $major_version -eq 3 ] && [ $minor_version -lt 6 ]; }; then
    exit_on_error "Python version is not compatible. Please upgrade to Python 3.6 or later."
fi

# Install Nginx
echo "Installing Nginx..."
opkg install nginx || exit_on_error "Failed to install Nginx"

# Create moonrakeruser and home directory
echo "Creating user moonrakeruser..."
if ! id "moonrakeruser" >/dev/null 2>&1; then
    adduser -h /usr/data/home/moonrakeruser -D moonrakeruser || exit_on_error "Failed to create user moonrakeruser"
else
    echo "User moonrakeruser already exists."
fi

# Install Moonraker
echo "Installing Moonraker..."
MOONRAKER_DIR="$WORKING_DIR/moonraker"
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

# Ensure bash is installed
BASH_PATH=$(which bash)
if [ -z "$BASH_PATH" ]; then
    echo "Bash is not installed. Installing bash..."
    opkg install bash || exit_on_error "Failed to install bash"
fi

# Install virtualenv if not available
pip3 show virtualenv > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "virtualenv is not installed. Installing virtualenv from PyPI..."
    pip3 install virtualenv || exit_on_error "Failed to install virtualenv from PyPI"
fi

# Run install-moonraker.sh with bash as moonrakeruser
echo "Running install-moonraker.sh with bash as moonrakeruser..."
su moonrakeruser -c "bash ./scripts/install-moonraker.sh" || exit_on_error "Failed to run Moonraker install script as moonrakeruser"

# Install Mainsail
echo "Installing Mainsail..."
MAINSAIL_DIR="$WORKING_DIR/mainsail"
if [ -d "$MAINSAIL_DIR" ]; then
    echo "Mainsail directory already exists. Deleting..."
    rm -rf $MAINSAIL_DIR || exit_on_error "Failed to delete directory $MAINSAIL_DIR"
fi
mkdir -p $MAINSAIL_DIR || exit_on_error "Failed to create directory $MAINSAIL_DIR"
cd $MAINSAIL_DIR || exit_on_error "Failed to change directory to $MAINSAIL_DIR"
git clone https://github.com/mainsail-crew/mainsail.git . || exit_on_error "Failed to download Mainsail"

# Install Fluidd
echo "Installing Fluidd..."
FLUIDD_DIR="$WORKING_DIR/fluidd"
if [ -d "$FLUIDD_DIR" ]; then
    echo "Fluidd directory already exists. Deleting..."
    rm -rf $FLUIDD_DIR || exit_on_error "Failed to delete directory $FLUIDD_DIR"
fi
mkdir -p $FLUIDD_DIR || exit_on_error "Failed to create directory $FLUIDD_DIR"
cd $FLUIDD_DIR || exit_on_error "Failed to change directory to $FLUIDD_DIR"
git clone https://github.com/fluidd-core/fluidd.git . || exit_on_error "Failed to download Fluidd"

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
