#!/bin/sh

# Function to check if a file exists, download if not
download_if_not_exists() {
  local url=$1
  local file=$2

  if [ ! -f "$file" ]; then
    echo "Downloading $file from $url"
    wget -q --show-progress $url -O $file
    if [ $? -ne 0 ]; then
      echo "Failed to download $file"
      exit 1
    fi
  else
    echo "$file already exists, skipping download"
  fi
}

# Set the working directory
WORKING_DIR="/usr/data"
PACKAGES_DIR="$WORKING_DIR/packages"
CONFIG_DIR="$WORKING_DIR/config"
IPK_PACKAGES_FILE="ipk-packages.txt"
REQUIREMENTS_FILE="requirements.txt"

# Check if connected to the internet
ping -c 1 google.com > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "No internet connection. Please download the necessary packages manually. See the text files ($IPK_PACKAGES_FILE and $REQUIREMENTS_FILE) for the list of packages."
  exit 1
fi

# Backup existing printer.cfg
PRINTER_CFG="/usr/data/printer_data/config/printer.cfg"
BACKUP_PRINTER_CFG="/usr/data/printer_data/config/printer.cfg.backup"

if [ -f "$PRINTER_CFG" ]; then
    echo "Backing up existing printer.cfg to $BACKUP_PRINTER_CFG"
    cp "$PRINTER_CFG" "$BACKUP_PRINTER_CFG"
else
    echo "No existing printer.cfg found to backup."
fi

# Ensure printer.cfg is accessible
FLUIDD_KLIPPER_CFG_DIR="/etc/fluidd_klipper/config"

if [ ! -d "$FLUIDD_KLIPPER_CFG_DIR" ]; then
    echo "Creating directory $FLUIDD_KLIPPER_CFG_DIR"
    mkdir -p "$FLUIDD_KLIPPER_CFG_DIR"
fi

# Copy or create a symlink for the printer.cfg file
if [ -f "$PRINTER_CFG" ]; then
    echo "Copying printer.cfg to $FLUIDD_KLIPPER_CFG_DIR"
    cp "$PRINTER_CFG" "$FLUIDD_KLIPPER_CFG_DIR/printer.cfg"
else
    echo "No printer.cfg found to copy."
fi

# Install IPK packages using Entware
echo "Installing IPK packages..."
while read -r package; do
  if [ -f "$PACKAGES_DIR/$package" ]; then
    opkg install "$PACKAGES_DIR/$package"
  else
    echo "Package $package not found in $PACKAGES_DIR, attempting to download..."
    download_if_not_exists "http://bin.entware.net/mipselsf-k3.4/$package" "$PACKAGES_DIR/$package"
    opkg install "$PACKAGES_DIR/$package"
  fi
done < $IPK_PACKAGES_FILE

# Install Python packages
echo "Installing Python packages..."
pip3 install --no-index --find-links=$PACKAGES_DIR -r $REQUIREMENTS_FILE || { echo "Failed to install some Python packages"; exit 1; }

# Install Nginx
echo "Installing Nginx..."
opkg install nginx || { echo "Failed to install Nginx"; exit 1; }

# Install Mainsail
echo "Installing Mainsail..."
MAINSIAL_DIR="$WORKING_DIR/mainsail"
mkdir -p $MAINSIAL_DIR
cd $MAINSIAL_DIR
if ! wget https://github.com/meteyou/mainsail/releases/latest/download/mainsail.zip; then
  echo "Failed to download Mainsail. Please ensure you have an internet connection or download the file manually."
  exit 1
fi
unzip mainsail.zip || { echo "Failed to unzip Mainsail"; exit 1; }
rm mainsail.zip

# Install Moonraker
echo "Installing Moonraker..."
MOONRAKER_DIR="$WORKING_DIR/moonraker"
cd $WORKING_DIR
if ! git clone https://github.com/Arksine/moonraker.git $MOONRAKER_DIR; then
  echo "Failed to clone Moonraker. Please ensure you have an internet connection."
  exit 1
fi
cd $MOONRAKER_DIR
./scripts/install-moonraker.sh || { echo "Failed to install Moonraker"; exit 1; }

# Install Fluidd
echo "Installing Fluidd..."
FLUIDD_DIR="$WORKING_DIR/fluidd"
mkdir -p $FLUIDD_DIR
cd $FLUIDD_DIR
if ! wget https://github.com/cadriel/fluidd/releases/latest/download/fluidd.zip; then
  echo "Failed to download Fluidd. Please ensure you have an internet connection or download the file manually."
  exit 1
fi
unzip fluidd.zip || { echo "Failed to unzip Fluidd"; exit 1; }
rm fluidd.zip

# Configure Nginx for Mainsail and Fluidd
echo "Configuring Nginx..."
if [ ! -d /opt/etc/nginx ]; then
    mkdir -p /opt/etc/nginx
fi
cat <<EOF > /opt/etc/nginx/nginx.conf
server {
    listen 8081;
    server_name _;

    location / {
        root $MAINSIAL_DIR;
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

# Restart Nginx
echo "Restarting Nginx..."
/opt/etc/init.d/S80nginx restart || { echo "Failed to restart Nginx"; exit 1; }

# Start Moonraker
echo "Starting Moonraker..."
if command -v systemctl > /dev/null; then
    systemctl start moonraker || { echo "Failed to start Moonraker"; exit 1; }
    systemctl enable moonraker || { echo "Failed to enable Moonraker"; exit 1; }
else
    echo "Systemctl not found. Please start Moonraker manually."
fi

echo "Installation complete! Mainsail is running on port 8081 and Fluidd on port 8082."
