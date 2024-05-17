#!/bin/sh

# MJ: This script sets up and configures Nginx for Fluidd and Mainsail.

# Function to print and exit on error
exit_on_error() {
    echo "$1"
    exit 1
}

# Set the working directory
WORKING_DIR="/usr/data"

# Install Fluidd and Mainsail
cd $WORKING_DIR
[ ! -d "fluidd" ] && git clone https://github.com/fluidd-core/fluidd.git fluidd
[ ! -d "mainsail" ] && git clone https://github.com/mainsail-crew/mainsail.git mainsail

# Configure Nginx
echo "Configuring Nginx..."
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

if [ $? -ne 0 ]; then
    exit_on_error "Failed to write Nginx configuration"
fi

# Restart Nginx
echo "Restarting Nginx..."
/opt/etc/init.d/S80nginx restart || exit_on_error "Failed to restart Nginx"

echo "Nginx setup complete! Mainsail is running on port 80, and Fluidd is running on port 80 under /fluidd."
