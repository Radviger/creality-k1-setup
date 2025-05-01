#!/bin/sh

# Creality K1 Fix for Coexisting with Stock Services
# This script configures Fluidd/Mainsail to work with the existing Moonraker

# Function to print messages
print_message() {
  echo "===================================================================="
  echo "$1"
  echo "===================================================================="
  echo ""
}

# Check for running services
check_services() {
  print_message "Checking for running services"
  
  echo "Checking for Moonraker process..."
  if pgrep -f "moonraker.py" > /dev/null; then
    echo "✓ Moonraker is running!"
    echo "Process details:"
    ps aux | grep -v grep | grep "moonraker.py"
  else
    echo "✗ Moonraker is not running."
  fi
  
  echo ""
  echo "Checking for Nginx process..."
  if pgrep nginx > /dev/null; then
    echo "✓ Nginx is running!"
    echo "Process details:"
    ps aux | grep -v grep | grep nginx
    
    echo ""
    echo "Checking listening ports..."
    netstat -tulpn 2>/dev/null | grep nginx
  else
    echo "✗ Nginx is not running."
  fi
  
  echo ""
  echo "Checking listening ports..."
  echo "Port 7125 (Moonraker API):"
  netstat -tulpn 2>/dev/null | grep -E ":7125 "
  
  echo ""
  echo "Ports 4408 (Fluidd) and 4409 (Mainsail):"
  netstat -tulpn 2>/dev/null | grep -E ":(4408|4409) "
  
  echo ""
  echo "Port 80 (HTTP):"
  netstat -tulpn 2>/dev/null | grep -E ":80 "
}

# Test Moonraker API
test_moonraker_api() {
  print_message "Testing Moonraker API"
  
  # Use curl to check if Moonraker API is responsive
  echo "Checking Moonraker API (this may take a few seconds)..."
  curl -s http://localhost:7125/api/server/info > /tmp/moonraker_response.json
  
  if [ $? -eq 0 ] && [ -s /tmp/moonraker_response.json ]; then
    echo "✓ Moonraker API is responding!"
    echo ""
    echo "API response (first 10 lines):"
    head -n 10 /tmp/moonraker_response.json
  else
    echo "✗ Moonraker API is not responding."
    echo ""
    echo "Let's check if it's still installing dependencies..."
    if [ -f "/usr/data/printer_data/logs/moonraker.log" ]; then
      tail -n 20 /usr/data/printer_data/logs/moonraker.log
    else
      echo "No Moonraker log file found at /usr/data/printer_data/logs/moonraker.log"
    fi
  fi
  
  # Clean up
  rm -f /tmp/moonraker_response.json
}

# Create improved Nginx configuration
create_nginx_config() {
  print_message "Creating improved Nginx configuration"
  
  # Create directory if it doesn't exist
  mkdir -p /opt/etc/nginx
  
  # Create minimal Nginx configuration
  cat > /opt/etc/nginx/nginx.conf << 'EOF'
# Global settings
worker_processes 1;
error_log /var/log/nginx_error.log;
pid /opt/var/run/nginx.pid;

# Events configuration
events {
    worker_connections 1024;
}

# HTTP configuration
http {
    include mime.types;
    default_type application/octet-stream;
    
    # Basic settings
    sendfile on;
    keepalive_timeout 65;
    
    # Logging settings
    access_log /var/log/nginx_access.log;
    
    # Fluidd server on port 4408
    server {
        listen 4408;
        
        root /usr/data/fluidd;
        index index.html;
        
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        location /websocket {
            proxy_pass http://127.0.0.1:7125/websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $http_host;
            proxy_read_timeout 86400;
        }
        
        location ~ ^/(printer|api|access|machine|server)/ {
            proxy_pass http://127.0.0.1:7125;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Scheme $scheme;
        }
    }

    # Mainsail server on port 4409
    server {
        listen 4409;
        
        root /usr/data/mainsail;
        index index.html;
        
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        location /websocket {
            proxy_pass http://127.0.0.1:7125/websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $http_host;
            proxy_read_timeout 86400;
        }
        
        location ~ ^/(printer|api|access|machine|server)/ {
            proxy_pass http://127.0.0.1:7125;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Scheme $scheme;
        }
    }
}
EOF

  echo "Nginx configuration created."
  
  # Check if ports 4408 and 4409 are already in use
  if netstat -tulpn 2>/dev/null | grep -q ":4408 "; then
    echo "WARNING: Port 4408 is already in use. Fluidd may not be accessible."
  fi
  
  if netstat -tulpn 2>/dev/null | grep -q ":4409 "; then
    echo "WARNING: Port 4409 is already in use. Mainsail may not be accessible."
  fi
}

# Test and start Nginx
test_and_start_nginx() {
  print_message "Testing and starting Nginx"
  
  # Check if Nginx is installed
  if [ ! -f "/opt/bin/nginx" ] && [ ! -f "/opt/sbin/nginx" ]; then
    echo "Nginx not found. Installing..."
    export PATH=$PATH:/opt/bin:/opt/sbin
    /opt/bin/opkg update
    /opt/bin/opkg install nginx
  fi
  
  # Determine the Nginx path
  NGINX_PATH=""
  if [ -f "/opt/bin/nginx" ]; then
    NGINX_PATH="/opt/bin/nginx"
  elif [ -f "/opt/sbin/nginx" ]; then
    NGINX_PATH="/opt/sbin/nginx"
  else
    echo "ERROR: Nginx executable not found after installation."
    return 1
  fi
  
  # Stop any running Nginx instance
  if pgrep nginx > /dev/null; then
    echo "Stopping existing Nginx process..."
    killall nginx
    sleep 2
  fi
  
  # Test Nginx configuration
  echo "Testing Nginx configuration..."
  $NGINX_PATH -t -c /opt/etc/nginx/nginx.conf
  
  if [ $? -eq 0 ]; then
    echo "Nginx configuration is valid."
    echo "Starting Nginx..."
    $NGINX_PATH -c /opt/etc/nginx/nginx.conf
    
    if [ $? -eq 0 ]; then
      echo "Nginx started successfully!"
    else
      echo "Failed to start Nginx. Please check the error logs."
    fi
  else
    echo "Nginx configuration is invalid. Please check the errors above."
  fi
}

# Create directories and placeholder files for Fluidd/Mainsail
create_ui_directories() {
  print_message "Creating UI directories"
  
  # Create directories if they don't exist
  mkdir -p /usr/data/fluidd
  mkdir -p /usr/data/mainsail
  
  # Check if the directories are empty
  if [ ! "$(ls -A /usr/data/fluidd 2>/dev/null)" ]; then
    echo "Creating placeholder index.html for Fluidd..."
    cat > /usr/data/fluidd/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>Fluidd - Placeholder</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
    h1 { color: #044b8a; }
    .container { max-width: 800px; margin: 0 auto; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Fluidd Placeholder</h1>
    <p>This is a placeholder page for Fluidd. You need to download and install Fluidd to use it.</p>
    <p>To install Fluidd:</p>
    <ol>
      <li>Download Fluidd from <a href="https://github.com/fluidd-core/fluidd/releases/latest">GitHub</a></li>
      <li>Extract the zip file</li>
      <li>Upload the contents to /usr/data/fluidd on your printer</li>
    </ol>
  </div>
</body>
</html>
EOF
  else
    echo "Fluidd directory is not empty. Skipping placeholder creation."
  fi
  
  if [ ! "$(ls -A /usr/data/mainsail 2>/dev/null)" ]; then
    echo "Creating placeholder index.html for Mainsail..."
    cat > /usr/data/mainsail/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>Mainsail - Placeholder</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
    h1 { color: #044b8a; }
    .container { max-width: 800px; margin: 0 auto; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Mainsail Placeholder</h1>
    <p>This is a placeholder page for Mainsail. You need to download and install Mainsail to use it.</p>
    <p>To install Mainsail:</p>
    <ol>
      <li>Download Mainsail from <a href="https://github.com/mainsail-crew/mainsail/releases/latest">GitHub</a></li>
      <li>Extract the zip file</li>
      <li>Upload the contents to /usr/data/mainsail on your printer</li>
    </ol>
  </div>
</body>
</html>
EOF
  else
    echo "Mainsail directory is not empty. Skipping placeholder creation."
  fi
}

# Fix Moonraker configuration paths
fix_moonraker_paths() {
  print_message "Fixing Moonraker configuration paths"
  
  if [ -f "/usr/data/printer_data/config/moonraker.conf" ]; then
    echo "Updating Mainsail and Fluidd paths in Moonraker config..."
    
    # Use sed to replace ~ with /usr/data
    sed -i 's|path = ~/mainsail|path = /usr/data/mainsail|g' /usr/data/printer_data/config/moonraker.conf
    sed -i 's|path = ~/fluidd|path = /usr/data/fluidd|g' /usr/data/printer_data/config/moonraker.conf
    
    echo "Paths updated in Moonraker configuration."
  else
    echo "Moonraker configuration not found."
  fi
}

# Create download helper script
create_download_helper() {
  print_message "Creating download helper script"
  
  cat > /usr/data/download_uis.sh << 'EOF'
#!/bin/sh

# Download helper for Fluidd and Mainsail
# This script downloads the latest releases and extracts them

# Function to print messages
print_message() {
  echo "===================================================================="
  echo "$1"
  echo "===================================================================="
  echo ""
}

# Ensure Entware PATH is set
export PATH=$PATH:/opt/bin:/opt/sbin

# Download Fluidd
download_fluidd() {
  print_message "Downloading Fluidd"
  
  cd /usr/data
  rm -rf /usr/data/fluidd.zip
  
  echo "Downloading latest Fluidd release..."
  wget --no-check-certificate -O fluidd.zip https://github.com/fluidd-core/fluidd/releases/latest/download/fluidd.zip
  
  if [ $? -eq 0 ]; then
    echo "Download successful. Extracting..."
    rm -rf /usr/data/fluidd/*
    unzip -o fluidd.zip -d fluidd
    rm fluidd.zip
    echo "Fluidd installed successfully!"
  else
    echo "Failed to download Fluidd."
  fi
}

# Download Mainsail
download_mainsail() {
  print_message "Downloading Mainsail"
  
  cd /usr/data
  rm -rf /usr/data/mainsail.zip
  
  echo "Downloading latest Mainsail release..."
  wget --no-check-certificate -O mainsail.zip https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip
  
  if [ $? -eq 0 ]; then
    echo "Download successful. Extracting..."
    rm -rf /usr/data/mainsail/*
    unzip -o mainsail.zip -d mainsail
    rm mainsail.zip
    echo "Mainsail installed successfully!"
  else
    echo "Failed to download Mainsail."
  fi
}

# Main function
main() {
  print_message "UI Download Helper"
  
  # Ask what to download
  echo "What would you like to download?"
  echo "1) Fluidd"
  echo "2) Mainsail"
  echo "3) Both"
  echo "4) Cancel"
  
  read -p "Enter your choice (1-4): " choice
  
  case "$choice" in
    1)
      download_fluidd
      ;;
    2)
      download_mainsail
      ;;
    3)
      download_fluidd
      download_mainsail
      ;;
    4)
      echo "Download canceled."
      ;;
    *)
      echo "Invalid choice. Please run the script again."
      ;;
  esac
  
  print_message "Download process complete!"
  echo "You can now access:"
  echo "- Fluidd at: http://$(ip route get 1 | awk '{print $7;exit}'):4408"
  echo "- Mainsail at: http://$(ip route get 1 | awk '{print $7;exit}'):4409"
}

# Run the main function
main
EOF
  
  chmod +x /usr/data/download_uis.sh
  
  echo "Download helper script created at /usr/data/download_uis.sh"
}

# Main function
main() {
  print_message "Starting Creality K1 Fix for Coexisting with Stock Services"
  
  check_services
  test_moonraker_api
  create_ui_directories
  fix_moonraker_paths
  create_nginx_config
  test_and_start_nginx
  create_download_helper
  
  # Final message
  print_message "Fix process complete!"
  echo "System status:"
  echo "- Moonraker: Using existing stock installation"
  echo "- Nginx: Configured for ports 4408 (Fluidd) and 4409 (Mainsail)"
  echo ""
  echo "You can now download the UIs with: /usr/data/download_uis.sh"
  echo ""
  echo "After downloading, you can access:"
  echo "- Fluidd at: http://$(ip route get 1 | awk '{print $7;exit}'):4408"
  echo "- Mainsail at: http://$(ip route get 1 | awk '{print $7;exit}'):4409"
  echo ""
  echo "If the UIs don't connect to Moonraker, check if it's running with:"
  echo "ps aux | grep moonraker"
}

# Run the main function
main