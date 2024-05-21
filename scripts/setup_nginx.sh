#!/bin/sh

# Function to print and exit on error
exit_on_error() {
    echo "$1"
    exit 1
}

# Check if Nginx is installed
NGINX_PATH="/opt/sbin/nginx"
if [ -z "$NGINX_PATH" ]; then
    # Install Nginx via Entware
    opkg install nginx || exit_on_error "Failed to install Nginx"
fi

# Set up Nginx configuration
cat <<EOF > /opt/etc/nginx/nginx.conf
server {
    listen 80;
    server_name _;

    location /fluidd {
        alias /usr/data/fluidd;
        try_files \$uri \$uri/ /index.html;
    }

    location /mainsail {
        alias /usr/data/mainsail;
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
/opt/etc/init.d/S80nginx restart || exit_on_error "Failed to restart Nginx"

echo "Nginx setup complete!"
