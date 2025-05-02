#!/bin/sh

# Function to print and exit on error
exit_on_error() {
    echo "$1"
    exit 1
}

# Clean up any existing Nginx configuration and stop Nginx service
rm -f /opt/etc/nginx/nginx.conf
killall -q nginx 2>/dev/null || true
sleep 1

# Check if Nginx is installed
if [ ! -f "/opt/sbin/nginx" ]; then
    # Install Nginx via Entware
    echo "Installing Nginx via opkg..."
    opkg install nginx || exit_on_error "Failed to install Nginx"
fi

# Create Nginx directories
mkdir -p /opt/etc/nginx

# Check which ports are available
echo "Checking for available ports..."
# Check if port 80 is in use
nc -z localhost 80
PORT_80_IN_USE=$?
# Check if other ports are in use
nc -z localhost 4408
PORT_4408_IN_USE=$?
nc -z localhost 4409
PORT_4409_IN_USE=$?

# Set up Nginx configuration with proper structure
# Skip port 80 configuration if it's already in use
echo "Creating new nginx.conf with proper structure"
cat > /opt/etc/nginx/nginx.conf << 'EOF'
worker_processes 1;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;

    # Serve Fluidd on its own port
    server {
        listen 4408;
        root /usr/data/fluidd;
        
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        location = /index.html {
            add_header Cache-Control "no-store, no-cache, must-revalidate";
        }
        
        location /websocket {
            proxy_pass http://127.0.0.1:7125/websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        
        location ~ ^/(printer|api|access|machine|server)/ {
            proxy_pass http://127.0.0.1:7125;
            proxy_http_version 1.1;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
    
    # Serve Mainsail on its own port
    server {
        listen 4409;
        root /usr/data/mainsail;
        
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        location = /index.html {
            add_header Cache-Control "no-store, no-cache, must-revalidate";
        }
        
        location /websocket {
            proxy_pass http://127.0.0.1:7125/websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        
        location ~ ^/(printer|api|access|machine|server)/ {
            proxy_pass http://127.0.0.1:7125;
            proxy_http_version 1.1;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
    
    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }
}
EOF

# Verify structure is correct 
if grep -q "^worker_processes" /opt/etc/nginx/nginx.conf && grep -q "^events {" /opt/etc/nginx/nginx.conf && grep -q "^http {" /opt/etc/nginx/nginx.conf; then
    echo "Nginx config structure verification passed"
else
    echo "WARNING: Nginx config structure verification failed!"
    echo "Full nginx.conf contents:"
    cat /opt/etc/nginx/nginx.conf
    exit_on_error "Nginx configuration creation failed"
fi

# Start Nginx
echo "Starting Nginx"
/opt/sbin/nginx || {
    echo "Error starting Nginx. Testing configuration..."
    /opt/sbin/nginx -t
    exit_on_error "Failed to start Nginx"
}

# Check if Nginx is running (verification)
sleep 2
if pgrep -f nginx > /dev/null; then
    echo "Nginx setup complete and service is running!"
    
    # Provide information about how to access the interfaces
    IP=$(ip route get 1 | awk '{print $7;exit}')
    echo ""
    echo "UI interfaces are installed and ready to use:"
    echo "  • Fluidd: http://${IP}:4408"
    echo "  • Mainsail: http://${IP}:4409"
else
    echo "Nginx failed to start. Testing configuration again..."
    /opt/sbin/nginx -t
    exit_on_error "Failed to start Nginx after configuration"
fi