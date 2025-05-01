#!/bin/sh

# Simplified installer for Mainsail and Fluidd on Creality K1/K1-Max
# This script uses the native curl command and existing Nginx/Moonraker

# --- Configuration ---
USR_DATA="/usr/data"
FLUIDD_FOLDER="$USR_DATA/fluidd"
MAINSAIL_FOLDER="$USR_DATA/mainsail"
MOONRAKER_CFG="$USR_DATA/printer_data/config/moonraker.conf"
NGINX_CONF_FILE="/opt/etc/nginx/nginx.conf"

# --- Helper Functions ---
function check_ipaddress() {
  ip route get 1 | awk '{print $7;exit}'
}

function print_banner() {
  echo "================================================="
  echo "   Creality K1/K1-Max Mainsail/Fluidd Installer"
  echo "================================================="
  echo ""
}

function install_mainsail() {
  echo "Installing Mainsail..."
  
  # Create directory
  if [ -d "$MAINSAIL_FOLDER" ]; then
    echo "Removing existing Mainsail directory..."
    rm -rf "$MAINSAIL_FOLDER"
  fi
  mkdir -p "$MAINSAIL_FOLDER"
  
  # Download and extract Mainsail
  echo "Downloading Mainsail..."
  curl --insecure -L "https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip" -o "$USR_DATA/mainsail.zip"
  if [ $? -ne 0 ]; then
    echo "Failed to download Mainsail. Trying with wget..."
    wget --no-check-certificate -O "$USR_DATA/mainsail.zip" "https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip"
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to download Mainsail!"
      return 1
    fi
  fi
  
  echo "Extracting Mainsail..."
  unzip -o "$USR_DATA/mainsail.zip" -d "$MAINSAIL_FOLDER"
  rm -f "$USR_DATA/mainsail.zip"
  
  echo "Mainsail installed successfully!"
  return 0
}

function install_fluidd() {
  echo "Installing Fluidd..."
  
  # Create directory
  if [ -d "$FLUIDD_FOLDER" ]; then
    echo "Removing existing Fluidd directory..."
    rm -rf "$FLUIDD_FOLDER"
  fi
  mkdir -p "$FLUIDD_FOLDER"
  
  # Download and extract Fluidd
  echo "Downloading Fluidd..."
  curl --insecure -L "https://github.com/fluidd-core/fluidd/releases/latest/download/fluidd.zip" -o "$USR_DATA/fluidd.zip"
  if [ $? -ne 0 ]; then
    echo "Failed to download Fluidd. Trying with wget..."
    wget --no-check-certificate -O "$USR_DATA/fluidd.zip" "https://github.com/fluidd-core/fluidd/releases/latest/download/fluidd.zip"
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to download Fluidd!"
      return 1
    fi
  fi
  
  echo "Extracting Fluidd..."
  unzip -o "$USR_DATA/fluidd.zip" -d "$FLUIDD_FOLDER"
  rm -f "$USR_DATA/fluidd.zip"
  
  echo "Fluidd installed successfully!"
  return 0
}

function configure_nginx() {
  echo "Configuring Nginx..."
  
  # Create nginx.conf with proper syntax
  mkdir -p /opt/etc/nginx
  cat > "$NGINX_CONF_FILE" << 'EOF'
worker_processes 1;
pid /opt/var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /opt/etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    gzip on;

    server {
        listen 80;
        server_name _;
        
        # Fluidd
        location /fluidd {
            alias /usr/data/fluidd;
            index index.html;
            try_files $uri $uri/ /fluidd/index.html;
        }

        # Mainsail
        location /mainsail {
            alias /usr/data/mainsail;
            index index.html;
            try_files $uri $uri/ /mainsail/index.html;
        }

        # Moonraker
        location /moonraker {
            proxy_pass http://127.0.0.1:7125;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
        }
    }
}
EOF

  echo "Nginx configured successfully!"
  return 0
}

function configure_moonraker() {
  echo "Configuring Moonraker..."
  
  # Create moonraker.conf if it doesn't exist
  mkdir -p "$USR_DATA/printer_data/config"
  
  if [ ! -f "$MOONRAKER_CFG" ]; then
    cat > "$MOONRAKER_CFG" << 'EOF'
[server]
host: 0.0.0.0
port: 7125
klippy_uds_address: /tmp/klippy_uds

[authorization]
trusted_clients:
    10.0.0.0/8
    127.0.0.0/8
    169.254.0.0/16
    172.16.0.0/12
    192.168.0.0/16
    FE80::/10
    ::1/128
cors_domains:
    http://*.lan
    http://*.local
    https://my.mainsail.xyz
    http://my.mainsail.xyz
    https://app.fluidd.xyz
    http://app.fluidd.xyz

[octoprint_compat]

[history]

[update_manager]
channel: dev
refresh_interval: 168

[update_manager mainsail]
type: web
channel: stable
repo: mainsail-crew/mainsail
path: ~/mainsail

[update_manager fluidd]
type: web
channel: stable
repo: fluidd-core/fluidd
path: ~/fluidd
EOF
  else
    # Update existing moonraker.conf with Mainsail and Fluidd entries if needed
    if ! grep -q "\[update_manager mainsail\]" "$MOONRAKER_CFG"; then
      cat >> "$MOONRAKER_CFG" << 'EOF'

[update_manager mainsail]
type: web
channel: stable
repo: mainsail-crew/mainsail
path: ~/mainsail
EOF
    fi
    
    if ! grep -q "\[update_manager fluidd\]" "$MOONRAKER_CFG"; then
      cat >> "$MOONRAKER_CFG" << 'EOF'

[update_manager fluidd]
type: web
channel: stable
repo: fluidd-core/fluidd
path: ~/fluidd
EOF
    fi
  fi

  echo "Moonraker configured successfully!"
  return 0
}

function restart_services() {
  echo "Restarting services..."
  
  # Restart Nginx
  if [ -f /opt/etc/init.d/S80nginx ]; then
    /opt/etc/init.d/S80nginx restart
  else
    killall nginx 2>/dev/null || true
    /opt/sbin/nginx
  fi
  
  echo "Services restarted successfully!"
  return 0
}

# --- Main Script ---
print_banner

# Install and configure everything
install_mainsail
install_fluidd
configure_nginx
configure_moonraker
restart_services

# Final message
echo ""
echo "================================================="
echo " Installation Complete!"
echo "================================================="
echo ""
echo "Your interfaces are available at:"
echo "- Mainsail: http://$(check_ipaddress)/mainsail"
echo "- Fluidd: http://$(check_ipaddress)/fluidd"
echo ""
echo "If Moonraker is not running, you can start it with:"
echo "- Use existing Creality startup script"
echo "- Or manually run: python3 /usr/data/moonraker/moonraker/moonraker.py -d /usr/data/printer_data"
echo ""
echo "Enjoy!"