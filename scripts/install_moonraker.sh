#!/bin/sh

# Function to print messages
print_message() {
  echo "===================================================================="
  echo "$1"
  echo "===================================================================="
  echo ""
}

# Install Entware and wget-ssl to fix TLS issues
fix_ssl_issues() {
  print_message "Installing Entware to fix SSL/TLS issues"
  
  # Check if Entware is already installed
  if [ ! -d "/opt" ] || [ ! -f "/opt/bin/opkg" ]; then
    echo "Entware not found. Installing Entware..."
    
    # Create a temporary directory for Entware installation
    mkdir -p /tmp/entware
    cd /tmp/entware
    
    # Download and run the Entware installer
    wget http://bin.entware.net/mipselsf-k3.4/installer/generic.sh
    sh generic.sh
    
    # Clean up
    cd /
    rm -rf /tmp/entware
    
    print_message "Entware installed. Now installing wget-ssl..."
    
    # Need to reload the shell to get Entware in the path
    export PATH=$PATH:/opt/bin:/opt/sbin
    
    # Install wget-ssl
    /opt/bin/opkg update
    /opt/bin/opkg install wget-ssl
    
    print_message "SSL support installed!"
  else
    echo "Entware is already installed."
    
    # Ensure wget-ssl is installed
    export PATH=$PATH:/opt/bin:/opt/sbin
    /opt/bin/opkg update
    /opt/bin/opkg install wget-ssl
  fi
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
  
  # Download using wget-ssl which has proper SSL support
  /opt/bin/wget-ssl --no-check-certificate -O fluidd.zip https://github.com/fluidd-core/fluidd/releases/latest/download/fluidd.zip
  
  if [ $? -eq 0 ]; then
    echo "Successfully downloaded Fluidd."
    unzip -o fluidd.zip -d fluidd
    rm fluidd.zip
    echo "Fluidd installed successfully!"
  else
    echo "Failed to download Fluidd. Please check your internet connection."
    return 1
  fi
}

# Download and install Mainsail
install_mainsail() {
  print_message "Installing Mainsail"
  cd /usr/data
  
  # Remove any existing installation
  rm -rf /usr/data/mainsail/*
  
  # Download using wget-ssl which has proper SSL support
  /opt/bin/wget-ssl --no-check-certificate -O mainsail.zip https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip
  
  if [ $? -eq 0 ]; then
    echo "Successfully downloaded Mainsail."
    unzip -o mainsail.zip -d mainsail
    rm mainsail.zip
    echo "Mainsail installed successfully!"
  else
    echo "Failed to download Mainsail. Please check your internet connection."
    return 1
  fi
}

# Configure Nginx
configure_nginx() {
  print_message "Configuring Nginx"
  
  # Ensure Nginx is installed
  export PATH=$PATH:/opt/bin:/opt/sbin
  /opt/bin/opkg install nginx
  
  # Create proper Nginx configuration
  mkdir -p /opt/etc/nginx
  
  # Create a proper nginx.conf file
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

    server {
        listen 80;
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

# Restart services
restart_services() {
  print_message "Restarting services"
  
  # Kill any existing Nginx processes
  killall -q nginx || true
  
  # Start Nginx
  /opt/sbin/nginx
  
  echo "Services restarted. If Moonraker is not running, you may need to start it manually."
}

# Main function
main() {
  print_message "Starting Creality K1/K1-Max Mainsail/Fluidd Installer"
  
  # Fix SSL issues first
  fix_ssl_issues
  
  # Create directories
  create_directories
  
  # Install Fluidd and Mainsail
  install_fluidd
  install_mainsail
  
  # Configure services
  configure_nginx
  configure_moonraker
  
  # Restart services
  restart_services
  
  # Final message
  print_message "Installation complete!"
  echo "You can now access:"
  echo "- Fluidd at: http://$(ip route get 1 | awk '{print $7;exit}')/fluidd"
  echo "- Mainsail at: http://$(ip route get 1 | awk '{print $7;exit}')/mainsail"
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