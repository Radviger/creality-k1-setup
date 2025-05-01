#!/bin/sh

# Complete Fix for Creality K1 Nginx and Moonraker
# This script fixes both Nginx configuration and speeds up Moonraker dependency installation

# Function to print messages
print_message() {
  echo "===================================================================="
  echo "$1"
  echo "===================================================================="
  echo ""
}

# Fix Nginx configuration
fix_nginx() {
  print_message "Fixing Nginx configuration"
  
  # Stop any running nginx
  if pidof nginx > /dev/null; then
    echo "Stopping existing Nginx process..."
    killall nginx
    sleep 1
  fi
  
  # Check if Nginx is installed
  if [ ! -f "/opt/bin/nginx" ]; then
    echo "Nginx not found, installing..."
    export PATH=$PATH:/opt/bin:/opt/sbin
    /opt/bin/opkg update
    /opt/bin/opkg install nginx
  fi
  
  # Create a properly formatted nginx.conf file
  echo "Creating proper Nginx configuration..."
  mkdir -p /opt/etc/nginx
  cat > /opt/etc/nginx/nginx.conf << 'EOF'
# Nginx configuration for Fluidd and Mainsail

# Set user to run worker processes
user nobody;

# Set number of worker processes
worker_processes 1;

# Set location of error logs
error_log /var/log/nginx_error.log;

# Set process ID file
pid /opt/var/run/nginx.pid;

# Events block
events {
    worker_connections 1024;
}

# HTTP block
http {
    # Include MIME types
    include mime.types;
    default_type application/octet-stream;

    # Basic settings
    sendfile on;
    keepalive_timeout 65;
    gzip on;

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

  # Test Nginx configuration
  echo "Testing Nginx configuration..."
  /opt/bin/nginx -t -c /opt/etc/nginx/nginx.conf
  
  if [ $? -eq 0 ]; then
    echo "Nginx configuration is valid."
    echo "Starting Nginx..."
    /opt/bin/nginx -c /opt/etc/nginx/nginx.conf
    
    if [ $? -eq 0 ]; then
      echo "Nginx started successfully!"
    else
      echo "Failed to start Nginx. Please check the error logs."
    fi
  else
    echo "Nginx configuration is invalid. Please check the errors above."
  fi
}

# Check Moonraker status and handle dependencies
check_moonraker() {
  print_message "Checking Moonraker status"
  
  # Check if Moonraker is running
  if pgrep -f "moonraker.py" > /dev/null; then
    echo "Moonraker is running! Let's check if it's still installing dependencies..."
    
    # Check if it's still installing dependencies
    tail -n 50 /usr/data/printer_data/logs/moonraker.log | grep -q "Installing build dependencies"
    
    if [ $? -eq 0 ]; then
      echo "Moonraker is still installing dependencies. This might take a while."
      echo "Let it continue running until it completes."
      echo "You can check the progress with: tail -f /usr/data/printer_data/logs/moonraker.log"
    else
      echo "Moonraker seems to be running normally."
    fi
  else
    echo "Moonraker is not running. Let's check if there were any errors..."
    
    # Check log for errors
    if [ -f "/usr/data/printer_data/logs/moonraker.log" ]; then
      echo "Recent log entries:"
      tail -n 20 /usr/data/printer_data/logs/moonraker.log
      
      echo ""
      echo "If Moonraker was installing dependencies but failed, let's try to resume..."
      echo "Starting Moonraker..."
      
      # Check if moonraker folder exists
      if [ ! -d "/usr/data/moonraker" ]; then
        echo "Moonraker directory not found. Cloning repository..."
        cd /usr/data
        git clone https://github.com/Arksine/moonraker.git
      fi
      
      # Start Moonraker
      python3 /usr/data/moonraker/moonraker/moonraker.py -d /usr/data/printer_data > /usr/data/printer_data/logs/moonraker.log 2>&1 &
      
      echo "Moonraker started in the background. It will continue installing dependencies."
      echo "Check the progress with: tail -f /usr/data/printer_data/logs/moonraker.log"
    else
      echo "No Moonraker log file found. Please make sure Moonraker has been set up correctly."
    fi
  fi
}

# Create a launcher script for Moonraker
create_launcher() {
  print_message "Creating Moonraker launcher script"
  
  cat > /usr/data/start_moonraker.sh << 'EOF'
#!/bin/sh

# Kill any existing Moonraker process
pkill -f "moonraker.py" || true

# Start Moonraker
cd /usr/data/moonraker
python3 /usr/data/moonraker/moonraker/moonraker.py -d /usr/data/printer_data > /usr/data/printer_data/logs/moonraker.log 2>&1 &

echo "Moonraker started!"
EOF

  chmod +x /usr/data/start_moonraker.sh
  
  echo "Launcher script created at /usr/data/start_moonraker.sh"
}

# Fix Fluidd and Mainsail paths in Moonraker config
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

# Main function
main() {
  print_message "Starting Complete Fix for Creality K1"
  
  fix_nginx
  fix_moonraker_paths
  check_moonraker
  create_launcher
  
  # Final message
  print_message "Fix process complete!"
  echo "Nginx has been configured to serve:"
  echo "- Fluidd at: http://$(ip route get 1 | awk '{print $7;exit}'):4408"
  echo "- Mainsail at: http://$(ip route get 1 | awk '{print $7;exit}'):4409"
  echo ""
  echo "Moonraker is either running or continuing to install dependencies."
  echo "You can check its status with: ps aux | grep moonraker"
  echo "And view the logs with: tail -f /usr/data/printer_data/logs/moonraker.log"
  echo ""
  echo "If you need to restart Moonraker, use: /usr/data/start_moonraker.sh"
  echo ""
  echo "Note: The first Moonraker start can take a long time as it builds Python dependencies."
  echo "      This is normal - just wait for it to complete."
}

# Run the main function
main