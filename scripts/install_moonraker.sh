#!/bin/sh

# This script addresses SSL issues and other problems with the Creality K1/K1-Max setup

# Function to print and exit on error
exit_on_error() {
    echo "ERROR: $1"
    exit 1
}

# Function to print warning but continue
warn() {
    echo "WARNING: $1"
}

# Function to print step information
step() {
    echo ""
    echo "====================================================================="
    echo "STEP: $1"
    echo "====================================================================="
}

step "Installing necessary system packages"
/opt/bin/opkg update
/opt/bin/opkg install zlib python3-pillow gcc make

step "Setting up required directories for Mainsail/Fluidd"
mkdir -p /usr/data/fluidd
mkdir -p /usr/data/mainsail

step "Downloading Fluidd without SSL verification"
cd /usr/data
rm -rf /usr/data/fluidd
# Using --no-check-certificate to bypass SSL verification issues
wget --no-check-certificate -O fluidd.zip https://github.com/fluidd-core/fluidd/releases/latest/download/fluidd.zip || exit_on_error "Failed to download Fluidd"
unzip fluidd.zip -d fluidd || exit_on_error "Failed to extract Fluidd"
rm fluidd.zip

step "Downloading Mainsail without SSL verification"
cd /usr/data
rm -rf /usr/data/mainsail
wget --no-check-certificate -O mainsail.zip https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip || exit_on_error "Failed to download Mainsail"
unzip mainsail.zip -d mainsail || exit_on_error "Failed to extract Mainsail"
rm mainsail.zip

step "Creating Moonraker config directory"
mkdir -p /usr/data/printer_data/config
mkdir -p /usr/data/printer_data/logs

step "Creating Moonraker configuration"
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
    http://*.lan
    http://*.local
    https://my.mainsail.xyz
    http://my.mainsail.xyz
    https://app.fluidd.xyz
    http://app.fluidd.xyz

[octoprint_compat]

[history]
EOF

step "Creating Nginx configuration"
mkdir -p /opt/etc/nginx
# Make sure we remove any previous nginx.conf
rm -f /opt/etc/nginx/nginx.conf
cat > /opt/etc/nginx/nginx.conf << 'EOF'
# Nginx configuration for Fluidd and Mainsail
worker_processes 1;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    gzip on;

    server {
        listen 80;
        server_name _;
        
        access_log /var/log/nginx_access.log;
        error_log /var/log/nginx_error.log;

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

        # Moonraker API
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

# Create a simple script to manually launch Moonraker
step "Creating Moonraker launcher script"
cat > /usr/data/launch_moonraker.sh << 'EOF'
#!/bin/sh

# Kill any existing Moonraker processes
pkill -f moonraker/moonraker.py || true

# Change to the moonraker directory
cd /usr/data/moonraker

# Launch Moonraker with the correct path and output to a log file
PYTHONPATH=/usr/data/moonraker python3 /usr/data/moonraker/moonraker/moonraker.py -d /usr/data/printer_data > /usr/data/printer_data/logs/moonraker.log 2>&1 &

echo "Moonraker launched in background. Check logs at /usr/data/printer_data/logs/moonraker.log"
EOF
chmod +x /usr/data/launch_moonraker.sh

step "Ensuring Moonraker directory exists"
cd /usr/data
if [ ! -d "moonraker" ]; then
    echo "Cloning Moonraker repository..."
    git clone --depth=1 --single-branch https://github.com/Arksine/moonraker.git || exit_on_error "Failed to clone Moonraker"
fi

# Modify pip.conf to disable SSL verification for pip
step "Configuring pip to ignore SSL verification"
mkdir -p ~/.pip
cat > ~/.pip/pip.conf << 'EOF'
[global]
trusted-host = pypi.python.org
               pypi.org
               files.pythonhosted.org
EOF

# Install only essential Moonraker dependencies directly to system Python
step "Installing minimal Moonraker dependencies"
pip3 install --no-cache-dir tornado pyserial jinja2 || warn "Some dependencies failed to install"

step "Starting services"
# Restart Nginx with new configuration
killall -q nginx || true
sleep 1
/opt/sbin/nginx || warn "Failed to start Nginx directly"

echo ""
echo "==============================================================="
echo "INSTALLATION COMPLETED"
echo "==============================================================="
echo ""
echo "To start Moonraker, run:"
echo "  /usr/data/launch_moonraker.sh"
echo ""
echo "Once running, you can access:"
echo "- Fluidd: http://$(ip route get 1 | awk '{print $7;exit}')/fluidd"
echo "- Mainsail: http://$(ip route get 1 | awk '{print $7;exit}')/mainsail"
echo ""
echo "If you encounter any issues, check the log files at:"
echo "- Moonraker log: /usr/data/printer_data/logs/moonraker.log"
echo "- Nginx access log: /var/log/nginx_access.log"
echo "- Nginx error log: /var/log/nginx_error.log"