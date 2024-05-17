#!/bin/sh

# MJ: This script installs and sets up Moonraker, Mainsail, and Fluidd.
# It also configures and restarts Nginx, and starts the Moonraker service.

# Function to print and exit on error
exit_on_error() {
    echo "$1"
    exit 1
}

# Working directory
WORKING_DIR="/usr/data"
PACKAGES_DIR="$WORKING_DIR/packages"

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
