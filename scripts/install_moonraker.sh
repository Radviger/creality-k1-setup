#!/bin/sh

# Updated script for installing Moonraker on Creality K1/K1-Max
# This script addresses disk space issues and disables problematic components

# Function to print and exit on error
exit_on_error() {
    echo "$1"
    exit 1
}

# Set the working directory and temp directory
# Use /usr/data for temporary files to avoid filling the root filesystem
WORKING_DIR="/usr/data"
MOONRAKER_DIR="$WORKING_DIR/moonraker"
VENV_DIR="$WORKING_DIR/moonraker-env"
TMPDIR="$WORKING_DIR/tmp"
CONFIG_DIR="$WORKING_DIR/printer_data/config"
LOGS_DIR="$WORKING_DIR/printer_data/logs"

# Ensure directories exist
mkdir -p "$TMPDIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOGS_DIR"

# Export TMPDIR to use during pip installations
export TMPDIR="$TMPDIR"

# Add Entware to PATH
export PATH=$PATH:/opt/bin:/opt/sbin

# Clean up any previous remnants to ensure a fresh start
cleanup_previous() {
    echo "Cleaning up previous installation files..."
    rm -rf "$TMPDIR"/*
    rm -rf /root/.cache/pip
    mkdir -p "$TMPDIR"
}

# Check if bash is installed
check_bash() {
    BASH_PATH=$(which bash)
    if [ -z "$BASH_PATH" ]; then
        echo "Bash is not installed. Installing bash..."
        /opt/bin/opkg install bash || exit_on_error "Failed to install bash"
    fi
}

# Install Moonraker
install_moonraker() {
    echo "Installing Moonraker..."
    
    # Check if directory exists and remove if necessary
    if [ -d "$MOONRAKER_DIR" ]; then
        echo "Moonraker directory already exists. Deleting..."
        rm -rf $MOONRAKER_DIR || exit_on_error "Failed to delete directory $MOONRAKER_DIR"
    fi
    
    # Create directory and clone repository
    mkdir -p $MOONRAKER_DIR || exit_on_error "Failed to create directory $MOONRAKER_DIR"
    cd $WORKING_DIR || exit_on_error "Failed to change directory to $WORKING_DIR"
    
    # Clone with --depth=1 to minimize disk usage
    git clone --depth=1 https://github.com/Arksine/moonraker.git $MOONRAKER_DIR || exit_on_error "Failed to clone Moonraker"
    
    cd $MOONRAKER_DIR || exit_on_error "Failed to change directory to $MOONRAKER_DIR"
    echo "Checking if install-moonraker.sh exists..."
    ls -l ./scripts/
    if [ ! -f "./scripts/install-moonraker.sh" ]; then
        exit_on_error "install-moonraker.sh not found"
    fi
    
    # Modify the install script to work without sudo and apt-get
    echo "Modifying install-moonraker.sh to work without sudo and apt-get..."
    sed -i 's/sudo //g' ./scripts/install-moonraker.sh
    sed -i '/apt-get/d' ./scripts/install-moonraker.sh
}

# Set up the virtual environment
setup_venv() {
    echo "Setting up Python virtual environment..."
    
    # Remove existing virtual environment if it exists
    if [ -d "$VENV_DIR" ]; then
        echo "Removing existing virtual environment..."
        rm -rf "$VENV_DIR"
    fi
    
    # Install virtualenv if needed
    echo "Checking for virtualenv..."
    pip3 install virtualenv || {
        echo "Failed to install virtualenv with pip3, trying with opkg..."
        /opt/bin/opkg update
        /opt/bin/opkg install python3-virtualenv || true
    }
    
    # Create virtual environment using system packages to save space
    echo "Creating virtual environment with system packages..."
    python3 -m venv --system-site-packages "$VENV_DIR" || {
        echo "Failed to create virtual environment with venv module."
        echo "Creating minimal virtual environment..."
        
        # Create directory structure
        mkdir -p "$VENV_DIR/bin"
        mkdir -p "$VENV_DIR/lib/python3.8/site-packages"
        
        # Create activate script
        cat > "$VENV_DIR/bin/activate" << 'EOF'
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
        ln -sf $(which python3) "$VENV_DIR/bin/python"
        ln -sf $(which python3) "$VENV_DIR/bin/python3"
        ln -sf $(which pip3) "$VENV_DIR/bin/pip"
        ln -sf $(which pip3) "$VENV_DIR/bin/pip3"
    }
    
    # Activate virtual environment
    echo "Activating virtual environment..."
    . "$VENV_DIR/bin/activate" || exit_on_error "Failed to activate virtual environment"
}

# Create Moonraker configuration
create_moonraker_config() {
    echo "Creating Moonraker configuration..."
    
    cat > "$CONFIG_DIR/moonraker.conf" << 'EOF'
[server]
host: 0.0.0.0
port: 7125
klippy_uds_address: /tmp/klippy_uds
# Disable dbus_manager to avoid dependency issues
disabled_components: ["dbus_manager"]

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
}

# Create Nginx configuration
create_nginx_config() {
    echo "Creating Nginx configuration..."
    
    mkdir -p /opt/etc/nginx
    
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
    
    server {
        listen 4408;
        root /usr/data/fluidd;
        
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        location /websocket {
            proxy_pass http://127.0.0.1:7125/websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
        
        location ~ ^/(printer|api|access|machine|server)/ {
            proxy_pass http://127.0.0.1:7125;
        }
    }
    
    server {
        listen 4409;
        root /usr/data/mainsail;
        
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        location /websocket {
            proxy_pass http://127.0.0.1:7125/websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
        
        location ~ ^/(printer|api|access|machine|server)/ {
            proxy_pass http://127.0.0.1:7125;
        }
    }
}
EOF

    echo "Nginx configuration created."
}

# Set up minimal dependencies directly
install_minimal_dependencies() {
    echo "Installing minimal Python dependencies..."
    
    # Use system pip to install basics
    pip3 install tornado==6.1 --no-cache-dir || echo "Failed to install tornado, continuing anyway"
    pip3 install pyserial --no-cache-dir || echo "Failed to install pyserial, continuing anyway"
    pip3 install pillow --no-cache-dir || echo "Failed to install pillow, continuing anyway"
    
    echo "Basic dependencies installed."
}

# Create start script for Moonraker
create_start_script() {
    echo "Creating Moonraker start script..."
    
    cat > "$WORKING_DIR/start_moonraker.sh" << 'EOF'
#!/bin/sh

# Kill any existing Moonraker process
pkill -f "moonraker.py" || true

# Start Moonraker
cd /usr/data/moonraker
python3 /usr/data/moonraker/moonraker/moonraker.py -d /usr/data/printer_data > /usr/data/printer_data/logs/moonraker.log 2>&1 &

echo "Moonraker started!"
EOF

    chmod +x "$WORKING_DIR/start_moonraker.sh"
    
    echo "Start script created at $WORKING_DIR/start_moonraker.sh"
}

# Start Moonraker
start_moonraker() {
    echo "Starting Moonraker..."
    "$WORKING_DIR/start_moonraker.sh"
    
    # Wait a moment for startup
    sleep 2
    
    # Check if it's running
    if pgrep -f "moonraker.py" > /dev/null; then
        echo "Moonraker is running!"
    else
        echo "Moonraker failed to start. Check logs at $LOGS_DIR/moonraker.log"
    fi
}

# Start Nginx
start_nginx() {
    echo "Starting Nginx..."
    
    # Kill any existing Nginx process
    killall nginx 2>/dev/null || true
    
    # Start Nginx
    if [ -f "/opt/sbin/nginx" ]; then
        /opt/sbin/nginx -c /opt/etc/nginx/nginx.conf
    elif [ -f "/opt/bin/nginx" ]; then
        /opt/bin/nginx -c /opt/etc/nginx/nginx.conf
    else
        echo "Nginx executable not found."
        return 1
    fi
    
    # Check if it started
    if pgrep nginx > /dev/null; then
        echo "Nginx started successfully!"
    else
        echo "Nginx failed to start."
        return 1
    fi
}

# Create directories for UIs
create_ui_dirs() {
    echo "Creating UI directories..."
    mkdir -p /usr/data/fluidd
    mkdir -p /usr/data/mainsail
    
    # Create minimal placeholder files
    echo '<html><body><h1>Fluidd Placeholder</h1><p>UI not yet installed</p></body></html>' > /usr/data/fluidd/index.html
    echo '<html><body><h1>Mainsail Placeholder</h1><p>UI not yet installed</p></body></html>' > /usr/data/mainsail/index.html
}

# Create download script for UIs
create_download_script() {
    echo "Creating UI download script..."
    
    cat > "$WORKING_DIR/download_ui.sh" << 'EOF'
#!/bin/sh

# Download Fluidd and Mainsail UIs

# Download Fluidd
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

# Download Mainsail
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

# Main execution
echo "Which UI would you like to download?"
echo "1) Fluidd"
echo "2) Mainsail"
echo "3) Both"
echo "4) Quit"

read -p "Enter your choice (1-4): " choice

case "$choice" in
    1) download_fluidd ;;
    2) download_mainsail ;;
    3) download_fluidd && download_mainsail ;;
    4) echo "Exiting without downloading." ;;
    *) echo "Invalid choice." ;;
esac

echo "Done!"
EOF

    chmod +x "$WORKING_DIR/download_ui.sh"
    
    echo "Download script created at $WORKING_DIR/download_ui.sh"
}

# Main execution
main() {
    # Run all the functions in sequence
    cleanup_previous
    check_bash
    install_moonraker
    setup_venv
    install_minimal_dependencies
    create_moonraker_config
    create_nginx_config
    create_start_script
    create_ui_dirs
    create_download_script
    start_moonraker
    start_nginx
    
    # Print completion message
    echo "==========================================="
    echo " Moonraker installation complete!"
    echo "==========================================="
    echo ""
    echo "You can now download the UI files with:"
    echo "  /usr/data/download_ui.sh"
    echo ""
    echo "Then access the interfaces at:"
    echo "  Fluidd: http://$(ip route get 1 | awk '{print $7;exit}'):4408"
    echo "  Mainsail: http://$(ip route get 1 | awk '{print $7;exit}'):4409"
    echo ""
    echo "If you need to restart Moonraker, use:"
    echo "  /usr/data/start_moonraker.sh"
    echo ""
    echo "Enjoy!"
}

# Execute main function
main