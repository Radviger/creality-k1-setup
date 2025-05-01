#!/bin/sh

# Function to print messages
print_message() {
  echo "===================================================================="
  echo "$1"
  echo "===================================================================="
  echo ""
}

# Check if Entware is properly installed
check_entware() {
  print_message "Checking Entware installation"
  
  if [ ! -d "/opt" ] || [ ! -f "/opt/bin/opkg" ]; then
    echo "Entware not found or not properly installed."
    echo "Installing Entware..."
    
    # Navigate to /tmp directory
    cd /tmp
    
    # Remove any existing generic.sh file
    rm -f generic.sh
    
    # Download the Entware installer without SSL verification
    echo "Downloading Entware installer..."
    wget http://bin.entware.net/mipselsf-k3.4/installer/generic.sh
    
    if [ $? -ne 0 ]; then
      echo "Failed to download Entware installer. Aborting."
      exit 1
    fi
    
    # Run the Entware installer
    echo "Running Entware installer..."
    sh generic.sh
    
    if [ $? -ne 0 ]; then
      echo "Failed to install Entware. Aborting."
      exit 1
    fi
    
    echo "Entware installed successfully."
  else
    echo "Entware is already installed."
  fi
  
  # Add Entware to PATH
  export PATH=$PATH:/opt/bin:/opt/sbin
  
  # Update and install wget-ssl
  echo "Updating package lists..."
  /opt/bin/opkg update
  
  echo "Installing wget-ssl..."
  /opt/bin/opkg install wget-ssl
  
  if [ $? -ne 0 ]; then
    echo "Failed to install wget-ssl. Will try to use curl instead."
    /opt/bin/opkg install curl
  fi
  
  # Verify wget-ssl or curl is installed
  if [ ! -f "/opt/bin/wget-ssl" ] && [ ! -f "/opt/bin/curl" ]; then
    echo "Neither wget-ssl nor curl could be installed. Cannot continue."
    exit 1
  fi
  
  echo "SSL-capable downloader installed successfully."
}

# Function to safely download a file
download_file() {
  url="$1"
  output="$2"
  
  # Try wget-ssl first
  if [ -f "/opt/bin/wget-ssl" ]; then
    echo "Downloading with wget-ssl: $url"
    /opt/bin/wget-ssl --no-check-certificate -O "$output" "$url"
    return $?
  fi
  
  # Try curl as backup
  if [ -f "/opt/bin/curl" ]; then
    echo "Downloading with curl: $url"
    /opt/bin/curl --insecure -L -o "$output" "$url"
    return $?
  fi
  
  # If we get here, neither tool worked
  echo "No download tool available. Cannot download $url"
  return 1
}

# Create necessary directories
create_directories() {
  print_message "Creating necessary directories"
  mkdir -p /usr/data/fluidd
  mkdir -p /usr/data/mainsail
  mkdir -p /usr/data/printer_data/config
  mkdir -p /usr/data/printer_data/logs
  echo "Directories created."
}

# Download and install Fluidd
install_fluidd() {
  print_message "Installing Fluidd"
  cd /usr/data
  
  # Remove any existing installation
  rm -rf /usr/data/fluidd/*
  
  # Download Fluidd
  download_file "https://github.com/fluidd-core/fluidd/releases/latest/download/fluidd.zip" "fluidd.zip"
  
  if [ $? -eq 0 ]; then
    echo "Successfully downloaded Fluidd."
    unzip -o fluidd.zip -d fluidd
    rm fluidd.zip
    echo "Fluidd installed successfully!"
  else
    echo "Failed to download Fluidd."
    # Create placeholder file
    mkdir -p /usr/data/fluidd
    echo "<html><body><h1>Fluidd Download Failed</h1><p>Please download and install manually.</p></body></html>" > /usr/data/fluidd/index.html
    return 1
  fi
}

# Download and install Mainsail
install_mainsail() {
  print_message "Installing Mainsail"
  cd /usr/data
  
  # Remove any existing installation
  rm -rf /usr/data/mainsail/*
  
  # Download Mainsail
  download_file "https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip" "mainsail.zip"
  
  if [ $? -eq 0 ]; then
    echo "Successfully downloaded Mainsail."
    unzip -o mainsail.zip -d mainsail
    rm mainsail.zip
    echo "Mainsail installed successfully!"
  else
    echo "Failed to download Mainsail."
    # Create placeholder file
    mkdir -p /usr/data/mainsail
    echo "<html><body><h1>Mainsail Download Failed</h1><p>Please download and install manually.</p></body></html>" > /usr/data/mainsail/index.html
    return 1
  fi
}

# Configure Nginx on alternative ports
configure_nginx() {
  print_message "Configuring Nginx on alternative ports"
  
  # Ensure Nginx is installed
  export PATH=$PATH:/opt/bin:/opt/sbin
  /opt/bin/opkg install nginx
  
  # Create proper Nginx configuration using alternative ports
  mkdir -p /opt/etc/nginx
  
  # Create a proper nginx.conf file with alternative ports (8080)
  cat > /opt/etc/nginx/nginx.conf << 'EOF'
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

    # Main server on port 8080 to avoid conflicts
    server {
        listen 8080;
        server_name _;
        
        # Fluidd
        location /fluidd/ {
            alias /usr/data/fluidd/;
            index index.html;
            try_files $uri $uri/ /fluidd/index.html;
        }

        # Mainsail
        location /mainsail/ {
            alias /usr/data/mainsail/;
            index index.html;
            try_files $uri $uri/ /mainsail/index.html;
        }

        # Moonraker
        location /moonraker/ {
            proxy_pass http://127.0.0.1:7125/;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Scheme $scheme;
        }

        # Moonraker websocket
        location /moonraker/websocket {
            proxy_pass http://127.0.0.1:7125/websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_read_timeout 86400;
        }
    }
}
EOF

  echo "Nginx configuration created."
}

# Configure Moonraker
configure_moonraker() {
  print_message "Configuring Moonraker"
  
  # Create moonraker.conf if it doesn't exist
  if [ ! -f "/usr/data/printer_data/config/moonraker.conf" ]; then
    cat > /usr/data/printer_data/config/moonraker.conf << 'EOF'
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
    *.local
    *.lan
    *://my.mainsail.xyz
    *://app.fluidd.xyz

[octoprint_compat]

[history]

[update_manager]
channel: dev
refresh_interval: 168

[update_manager mainsail]
type: web
channel: stable
repo: mainsail-crew/mainsail
path: /usr/data/mainsail

[update_manager fluidd]
type: web
channel: stable
repo: fluidd-core/fluidd
path: /usr/data/fluidd
EOF
    echo "Moonraker configuration created."
  else
    echo "Moonraker configuration already exists."
  fi
}

# Find and detect existing web services
detect_web_services() {
  print_message "Detecting existing web services"
  
  echo "Checking for processes using port 80..."
  netstat -tulpn 2>/dev/null | grep ":80 "
  
  echo ""
  echo "Checking for running web servers..."
  ps aux | grep -E 'nginx|httpd|lighttpd' | grep -v grep
  
  echo ""
  echo "Existing Moonraker processes:"
  ps aux | grep moonraker | grep -v grep
}

# Restart Nginx on the alternative port
restart_nginx() {
  print_message "Starting Nginx on alternative port"
  
  # Kill any existing Nginx processes managed by our installation
  if [ -f "/opt/var/run/nginx.pid" ]; then
    echo "Stopping existing Nginx instance..."
    kill -TERM $(cat /opt/var/run/nginx.pid) 2>/dev/null
    sleep 2
  fi
  
  # Start Nginx
  echo "Starting Nginx..."
  /opt/sbin/nginx -c /opt/etc/nginx/nginx.conf
  
  if [ $? -eq 0 ]; then
    echo "Nginx started successfully on port 8080."
  else
    echo "Failed to start Nginx. Please check the logs."
    echo "You can try starting it manually with: /opt/sbin/nginx -c /opt/etc/nginx/nginx.conf"
  fi
}

# Main function
main() {
  print_message "Starting Creality K1/K1-Max Mainsail/Fluidd Installer (Alternative Port Version)"
  
  # Check Entware and install SSL-capable downloader
  check_entware
  
  # Create directories
  create_directories
  
  # Install Fluidd and Mainsail
  install_fluidd
  install_mainsail
  
  # Detect existing web services
  detect_web_services
  
  # Configure services
  configure_nginx
  configure_moonraker
  
  # Restart Nginx
  restart_nginx
  
  # Final message
  print_message "Installation complete!"
  echo "You can now access:"
  echo "- Fluidd at: http://$(ip route get 1 | awk '{print $7;exit}'):8080/fluidd"
  echo "- Mainsail at: http://$(ip route get 1 | awk '{print $7;exit}'):8080/mainsail"
  echo ""
  echo "NOTE: We're using port 8080 to avoid conflicts with the existing web server."
  echo ""
  echo "If you encounter any issues:"
  echo "1. Check that Moonraker is running:"
  echo "   ps aux | grep moonraker"
  echo "2. If not, start it manually:"
  echo "   python3 /usr/data/moonraker/moonraker/moonraker.py -d /usr/data/printer_data"
  echo ""
  echo "Enjoy!"
}

# Run the main function
main