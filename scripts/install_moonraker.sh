#!/bin/sh

# Creality K1 Compatible Moonraker/Nginx Installation Script
# Based on official Creality K1 Series Annex repository files

# Exit on errors
set -e

# Directories
USR_DATA="/usr/data"
MOONRAKER_DIR="${USR_DATA}/moonraker"
VENV_DIR="${USR_DATA}/moonraker-env"
CONFIG_DIR="${USR_DATA}/printer_data/config"
LOGS_DIR="${USR_DATA}/printer_data/logs"
FLUIDD_DIR="${USR_DATA}/fluidd"
MAINSAIL_DIR="${USR_DATA}/mainsail"
TMPDIR="${USR_DATA}/tmp"

# Create directories
mkdir -p "${TMPDIR}"
mkdir -p "${CONFIG_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${FLUIDD_DIR}"
mkdir -p "${MAINSAIL_DIR}"

# Set TMPDIR for pip installations
export TMPDIR="${TMPDIR}"

# Path to Entware
export PATH=$PATH:/opt/bin:/opt/sbin

# Print status message
print_status() {
    echo "===================================================================="
    echo "$1"
    echo "===================================================================="
}

# Exit on error
exit_on_error() {
    echo "ERROR: $1"
    exit 1
}

# Clean up existing installations
cleanup() {
    print_status "Cleaning up any previous installation files"
    
    # Stop existing services
    pkill -f "moonraker.py" || true
    pkill -f "nginx" || true
    
    # Clean up temporary files
    rm -rf "${TMPDIR:?}"/*
    rm -rf /root/.cache/pip || true
    mkdir -p "${TMPDIR}"
}

# Install Moonraker
install_moonraker() {
    print_status "Installing Moonraker"
    
    # Check if Moonraker directory exists and remove if necessary
    if [ -d "${MOONRAKER_DIR}" ]; then
        echo "Moonraker directory already exists. Deleting..."
        rm -rf "${MOONRAKER_DIR}" || exit_on_error "Failed to delete ${MOONRAKER_DIR}"
    fi
    
    # Create directory and clone repository
    mkdir -p "${MOONRAKER_DIR}" || exit_on_error "Failed to create ${MOONRAKER_DIR}"
    cd "${USR_DATA}" || exit_on_error "Failed to change directory to ${USR_DATA}"
    
    # Clone with --depth=1 to minimize disk usage
    git clone --depth=1 https://github.com/Arksine/moonraker.git "${MOONRAKER_DIR}" || exit_on_error "Failed to clone Moonraker"
    
    echo "Moonraker installed successfully"
}

# Set up Python virtual environment
setup_venv() {
    print_status "Setting up Python virtual environment"
    
    # Remove existing virtual environment if it exists
    if [ -d "${VENV_DIR}" ]; then
        echo "Removing existing virtual environment..."
        rm -rf "${VENV_DIR}"
    fi
    
    # Create virtual environment using system packages to save space
    echo "Creating virtual environment with system packages..."
    python3 -m venv --system-site-packages "${VENV_DIR}" || {
        echo "Failed to create virtual environment with venv module."
        echo "Creating minimal virtual environment..."
        
        # Create directory structure
        mkdir -p "${VENV_DIR}/bin"
        mkdir -p "${VENV_DIR}/lib/python3.8/site-packages"
        
        # Copy activate script
        cat > "${VENV_DIR}/bin/activate" << 'EOF'
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
VIRTUAL_ENV="$VENV_DIR"
export VIRTUAL_ENV
_OLD_VIRTUAL_PATH="$PATH"
PATH="$VIRTUAL_ENV/bin:$PATH"
export PATH
EOF
        
        # Create symlinks to system Python
        ln -sf $(which python3) "${VENV_DIR}/bin/python"
        ln -sf $(which python3) "${VENV_DIR}/bin/python3"
        ln -sf $(which pip3) "${VENV_DIR}/bin/pip"
        ln -sf $(which pip3) "${VENV_DIR}/bin/pip3"
    }
    
    # Install minimal dependencies
    echo "Installing minimal Python dependencies..."
    pip3 install tornado==6.1 pyserial pillow --no-cache-dir || echo "Warning: Some dependencies failed to install, but we'll continue anyway"
    
    echo "Python virtual environment set up successfully"
}

# Create Moonraker configuration
create_moonraker_config() {
    print_status "Creating Moonraker configuration"
    
    cat > "${CONFIG_DIR}/moonraker.conf" << 'EOF'
[server]
host: 0.0.0.0
port: 7125
klippy_uds_address: /tmp/klippy_uds
# Disable dbus_manager to avoid dependency issues
disabled_components: ["dbus_manager"]
max_upload_size: 1024

[file_manager]
queue_gcode_uploads: False
enable_object_processing: False
enable_inotify_warnings: True

[database]
#enable_database_debug: False

[data_store]
temperature_store_size: 600
gcode_store_size: 1000

[machine]
provider: none
validate_service: False
validate_config: False

[authorization]
force_logins: False
cors_domains:
  *.local
  *.lan
  *://app.fluidd.xyz

trusted_clients:
  10.0.0.0/8
  127.0.0.0/8
  169.254.0.0/16
  172.16.0.0/12
  192.168.0.0/16
  FE80::/10
  ::1/128

# enables partial support of Octoprint API
[octoprint_compat]

# enables moonraker to track and store print history.
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

    echo "Moonraker configuration created"
}

# Create Nginx configuration
create_nginx_config() {
    print_status "Creating Nginx configuration"
    
    mkdir -p /opt/etc/nginx
    
    cat > /opt/etc/nginx/nginx.conf << 'EOF'
#user  nobody;
worker_processes  1;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;

    server {
        listen 4408 default_server;

        #access_log /var/log/nginx/fluidd-access.log;
        #error_log /var/log/nginx/fluidd-error.log;

        # disable this section on smaller hardware like a pi zero
        gzip on;
        gzip_vary on;
        gzip_proxied any;
        gzip_proxied expired no-cache no-store private auth;
        gzip_comp_level 4;
        gzip_buffers 16 8k;
        gzip_http_version 1.1;
        gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/json application/xml;

        # web_path from fluidd static files
        root /usr/data/fluidd;

        index index.html;
        server_name _;

        # disable max upload size checks
        client_max_body_size 0;

        # disable proxy request buffering
        proxy_request_buffering off;

        location / {
            try_files $uri $uri/ /index.html;
        }

        location = /index.html {
            add_header Cache-Control "no-store, no-cache, must-revalidate";
        }

        location /websocket {
            proxy_pass http://apiserver/websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_read_timeout 86400;
        }

        location ~ ^/(printer|api|access|machine|server)/ {
            proxy_pass http://apiserver$request_uri;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Scheme $scheme;
        }

        location /webcam/ {
            proxy_pass http://mjpgstreamer1/;
        }

        location /webcam2/ {
            proxy_pass http://mjpgstreamer2/;
        }

        location /webcam3/ {
            proxy_pass http://mjpgstreamer3/;
        }

        location /webcam4/ {
            proxy_pass http://mjpgstreamer4/;
        }
    }

    server {
        listen 4409 default_server;
        # uncomment the next line to activate IPv6
        # listen [::]:80 default_server;

        #access_log /var/log/nginx/mainsail-access.log;
        #error_log /var/log/nginx/mainsail-error.log;

        # disable this section on smaller hardware like a pi zero
        gzip on;
        gzip_vary on;
        gzip_proxied any;
        gzip_proxied expired no-cache no-store private auth;
        gzip_comp_level 4;
        gzip_buffers 16 8k;
        gzip_http_version 1.1;
        gzip_types text/plain text/css text/xml text/javascript application/javascript application/x-javascript application/json application/xml;

        # web_path from mainsail static files
        root /usr/data/mainsail;

        index index.html;
        server_name _;

        # disable max upload size checks
        client_max_body_size 0;

        # disable proxy request buffering
        proxy_request_buffering off;

        location / {
            try_files $uri $uri/ /index.html;
        }

        location = /index.html {
            add_header Cache-Control "no-store, no-cache, must-revalidate";
        }

        location /websocket {
            proxy_pass http://apiserver/websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_read_timeout 86400;
        }

        location ~ ^/(printer|api|access|machine|server)/ {
            proxy_pass http://apiserver$request_uri;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Scheme $scheme;
        }

        location /webcam/ {
            postpone_output 0;
            proxy_buffering off;
            proxy_ignore_headers X-Accel-Buffering;
            access_log off;
            error_log off;
            proxy_pass http://mjpgstreamer1/;
        }

        location /webcam2/ {
            postpone_output 0;
            proxy_buffering off;
            proxy_ignore_headers X-Accel-Buffering;
            access_log off;
            error_log off;
            proxy_pass http://mjpgstreamer2/;
        }

        location /webcam3/ {
            postpone_output 0;
            proxy_buffering off;
            proxy_ignore_headers X-Accel-Buffering;
            access_log off;
            error_log off;
            proxy_pass http://mjpgstreamer3/;
        }

        location /webcam4/ {
            postpone_output 0;
            proxy_buffering off;
            proxy_ignore_headers X-Accel-Buffering;
            access_log off;
            error_log off;
            proxy_pass http://mjpgstreamer4/;
        }
    }

    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }
    upstream apiserver {
        ip_hash;
        server 127.0.0.1:7125;
    }

    upstream mjpgstreamer1 {
        ip_hash;
        server 127.0.0.1:8080;
    }

    upstream mjpgstreamer2 {
        ip_hash;
        server 127.0.0.1:8081;
    }

    upstream mjpgstreamer3 {
        ip_hash;
        server 127.0.0.1:8082;
    }

    upstream mjpgstreamer4 {
        ip_hash;
        server 127.0.0.1:8083;
    }
}
EOF

    echo "Nginx configuration created"
}

# Create Moonraker service startup script
create_moonraker_service() {
    print_status "Creating Moonraker service script"
    
    cat > "${USR_DATA}/start_moonraker.sh" << 'EOF'
#!/bin/sh

# Kill any existing Moonraker process
pkill -f "moonraker.py" || true

# Start Moonraker
cd /usr/data/moonraker
python3 /usr/data/moonraker/moonraker/moonraker.py -d /usr/data/printer_data > /usr/data/printer_data/logs/moonraker.log 2>&1 &

echo "Moonraker started!"
EOF

    chmod +x "${USR_DATA}/start_moonraker.sh"
    
    echo "Moonraker service script created at ${USR_DATA}/start_moonraker.sh"
}

# Create placeholders for the UIs
create_ui_placeholders() {
    print_status "Creating UI placeholders"
    
    # Create placeholder for Fluidd
    echo '<html><body><h1>Fluidd Placeholder</h1><p>The actual UI has not been downloaded yet.</p><p>Please use /usr/data/download_ui.sh to download it.</p></body></html>' > "${FLUIDD_DIR}/index.html"
    
    # Create placeholder for Mainsail
    echo '<html><body><h1>Mainsail Placeholder</h1><p>The actual UI has not been downloaded yet.</p><p>Please use /usr/data/download_ui.sh to download it.</p></body></html>' > "${MAINSAIL_DIR}/index.html"
    
    echo "UI placeholders created"
}

# Create script to download the UI files
create_download_script() {
    print_status "Creating UI download script"
    
    cat > "${USR_DATA}/download_ui.sh" << 'EOF'
#!/bin/sh

# Download Fluidd and Mainsail UIs for Creality K1

download_fluidd() {
    echo "Downloading Fluidd..."
    cd /usr/data
    wget --no-check-certificate -O fluidd.zip https://github.com/fluidd-core/fluidd/releases/latest/download/fluidd.zip
    if [ $? -eq 0 ]; then
        echo "Extracting Fluidd..."
        rm -rf /usr/data/fluidd/*
        unzip -o fluidd.zip -d /usr/data/fluidd
        rm fluidd.zip
        echo "Fluidd installed successfully!"
    else
        echo "Failed to download Fluidd."
    fi
}

download_mainsail() {
    echo "Downloading Mainsail..."
    cd /usr/data
    wget --no-check-certificate -O mainsail.zip https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip
    if [ $? -eq 0 ]; then
        echo "Extracting Mainsail..."
        rm -rf /usr/data/mainsail/*
        unzip -o mainsail.zip -d /usr/data/mainsail
        rm mainsail.zip
        echo "Mainsail installed successfully!"
    else
        echo "Failed to download Mainsail."
    fi
}

# Main menu
echo "===================================================================="
echo "                   UI Download for Creality K1                      "
echo "===================================================================="
echo ""
echo "Which UI would you like to download?"
echo "1) Fluidd (port 4408)"
echo "2) Mainsail (port 4409)"
echo "3) Both UIs"
echo "4) Quit"
echo ""
read -p "Enter your choice (1-4): " choice

case "$choice" in
    1) download_fluidd ;;
    2) download_mainsail ;;
    3) download_fluidd && download_mainsail ;;
    4) echo "Exiting without downloading." ;;
    *) echo "Invalid choice." ;;
esac

# Restart Nginx to apply changes
echo "Restarting Nginx..."
killall nginx 2>/dev/null || true
/opt/sbin/nginx

echo "Done!"
EOF

    chmod +x "${USR_DATA}/download_ui.sh"
    
    echo "Download script created at ${USR_DATA}/download_ui.sh"
}

# Start Moonraker
start_moonraker() {
    print_status "Starting Moonraker"
    
    "${USR_DATA}/start_moonraker.sh"
    
    # Check if Moonraker started
    sleep 2
    if pgrep -f "moonraker.py" > /dev/null; then
        echo "Moonraker started successfully!"
    else
        echo "Warning: Moonraker may not have started properly. Check logs at ${LOGS_DIR}/moonraker.log"
    fi
}

# Start Nginx
start_nginx() {
    print_status "Starting Nginx"
    
    # Kill any existing Nginx process
    killall nginx 2>/dev/null || true
    
    # Start Nginx
    /opt/sbin/nginx
    
    # Check if Nginx started
    if pgrep nginx > /dev/null; then
        echo "Nginx started successfully!"
    else
        echo "Warning: Nginx may not have started properly."
        return 1
    fi
}

# Main execution
main() {
    print_status "Starting installation of Moonraker and Nginx for Creality K1"
    
    # Run all installation steps
    cleanup
    install_moonraker
    setup_venv
    create_moonraker_config
    create_nginx_config
    create_moonraker_service
    create_ui_placeholders
    create_download_script
    start_moonraker
    start_nginx
    
    # Print completion message
    print_status "Installation complete!"
    echo ""
    echo "Moonraker should now be running on port 7125"
    echo "You can download the UI files with: /usr/data/download_ui.sh"
    echo ""
    echo "After downloading, you can access the UIs at:"
    echo "  Fluidd: http://$(ip route get 1 | awk '{print $7;exit}'):4408"
    echo "  Mainsail: http://$(ip route get 1 | awk '{print $7;exit}'):4409"
    echo ""
    echo "If you need to restart Moonraker, use: /usr/data/start_moonraker.sh"
    echo ""
    echo "Note: The official Creality warning states that running Moonraker"
    echo "for extended periods may cause memory issues on the K1 series."
    echo ""
    echo "Enjoy!"
}

# Execute main function
main