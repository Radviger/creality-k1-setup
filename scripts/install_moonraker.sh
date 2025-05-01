#!/bin/sh

# This script fixes all the identified issues with the Creality K1/K1-Max Mainsail/Fluidd setup

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
/opt/bin/opkg install zlib zlib-dev libjpeg libjpeg-dev python3-pip gcc make

step "Creating virtual environment"
cd /usr/data
rm -rf moonraker-env
python3 -m pip install virtualenv
python3 -m virtualenv moonraker-env || {
    echo "Failed to create virtual environment with virtualenv"
    echo "Creating alternative minimal virtual environment..."
    
    mkdir -p /usr/data/moonraker-env
    mkdir -p /usr/data/moonraker-env/bin
    mkdir -p /usr/data/moonraker-env/lib/python3.8/site-packages
    
    # Create activate script
    cat > /usr/data/moonraker-env/bin/activate << 'EOF'
# This file must be used with "source bin/activate" *from bash*
# You cannot run it directly
deactivate () {
    unset -f pydoc >/dev/null 2>&1
    unset -f deactivate
    unset VIRTUAL_ENV
    if [ ! "${1:-}" = "nondestructive" ] ; then
    # Self destruct!
        unset -f deactivate
    fi
}
VIRTUAL_ENV="/usr/data/moonraker-env"
export VIRTUAL_ENV
_OLD_VIRTUAL_PATH="$PATH"
PATH="$VIRTUAL_ENV/bin:$PATH"
export PATH
EOF

    # Create symlinks to system Python
    ln -sf $(which python3) /usr/data/moonraker-env/bin/python
    ln -sf $(which python3) /usr/data/moonraker-env/bin/python3
    ln -sf $(which pip3) /usr/data/moonraker-env/bin/pip
    ln -sf $(which pip3) /usr/data/moonraker-env/bin/pip3
}

step "Activating virtual environment"
. /usr/data/moonraker-env/bin/activate

step "Installing binary/wheel versions of problematic packages"
pip install --upgrade pip
pip install pillow --no-build-isolation || {
    echo "Failed to install Pillow with pip"
    /opt/bin/opkg install python3-pillow || warn "Failed to install python3-pillow"
}

step "Setting up required directories for Mainsail/Fluidd"
mkdir -p /usr/data/fluidd
mkdir -p /usr/data/mainsail

step "Downloading Fluidd"
cd /usr/data
rm -rf /usr/data/fluidd
wget -O fluidd.zip https://github.com/fluidd-core/fluidd/releases/latest/download/fluidd.zip || exit_on_error "Failed to download Fluidd"
unzip fluidd.zip -d fluidd || exit_on_error "Failed to extract Fluidd"
rm fluidd.zip

step "Downloading Mainsail"
cd /usr/data
rm -rf /usr/data/mainsail
wget -O mainsail.zip https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip || exit_on_error "Failed to download Mainsail"
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

[update_manager]
channel: dev
refresh_interval: 168
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

# Create a simple entware init script for Moonraker
step "Creating Moonraker startup script"
cat > /opt/etc/init.d/S99moonraker << 'EOF'
#!/bin/sh

MOONRAKER_DIR="/usr/data/moonraker"
MOONRAKER_ENV="/usr/data/moonraker-env"
CONFIG_DIR="/usr/data/printer_data/config"
LOG_PATH="/usr/data/printer_data/logs/moonraker.log"

start() {
    echo "Starting Moonraker..."
    cd $MOONRAKER_DIR
    $MOONRAKER_ENV/bin/python $MOONRAKER_DIR/moonraker/moonraker.py -d /usr/data/printer_data > $LOG_PATH 2>&1 &
    echo $! > /var/run/moonraker.pid
}

stop() {
    echo "Stopping Moonraker..."
    if [ -f /var/run/moonraker.pid ]; then
        kill $(cat /var/run/moonraker.pid)
        rm /var/run/moonraker.pid
    else
        killall -q python
    fi
}

restart() {
    stop
    sleep 2
    start
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart|reload)
        restart
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
esac

exit $?
EOF
chmod +x /opt/etc/init.d/S99moonraker

step "Ensuring Moonraker directory exists"
cd /usr/data
if [ ! -d "moonraker" ]; then
    echo "Cloning Moonraker repository..."
    git clone https://github.com/Arksine/moonraker.git
fi

step "Starting services"
# Stop any existing instances first
killall -q python python3 || true
if [ -f /opt/etc/init.d/S80nginx ]; then
    /opt/etc/init.d/S80nginx stop
fi

# Start the services
/opt/etc/init.d/S99moonraker restart
/opt/etc/init.d/S80nginx restart || {
    echo "Failed to restart Nginx with the init script, trying direct command..."
    killall -q nginx || true
    /opt/sbin/nginx || exit_on_error "Failed to start Nginx directly"
}

step "Installation completed successfully!"
echo ""
echo "You can now access:"
echo "- Fluidd: http://$(ip route get 1 | awk '{print $7;exit}')/fluidd"
echo "- Mainsail: http://$(ip route get 1 | awk '{print $7;exit}')/mainsail"
echo ""
echo "If you encounter any issues, check the log files at:"
echo "- Moonraker log: /usr/data/printer_data/logs/moonraker.log"
echo "- Nginx access log: /var/log/nginx_access.log"
echo "- Nginx error log: /var/log/nginx_error.log"