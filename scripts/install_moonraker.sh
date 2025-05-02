#!/bin/sh

# Automated Moonraker/Nginx Installation Script for Creality K1
# Enhanced with debugging and process verification

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
SCRIPT_LOG="${USR_DATA}/moonraker_install.log"

# Start logging
exec > >(tee -a "${SCRIPT_LOG}") 2>&1
echo "Starting installation script at $(date)"
echo "--------------------------------------------------------------------------"

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
    echo "==========================================================================="
    echo "$(date +%H:%M:%S) - $1"
    echo "==========================================================================="
}

# Debug message
debug() {
    echo "[DEBUG $(date +%H:%M:%S)] $1"
}

# Exit on error
exit_on_error() {
    echo "ERROR: $1"
    echo "Check log at ${SCRIPT_LOG} for details"
    exit 1
}

# Process status check
check_process() {
    local process_name="$1"
    local count=$(pgrep -fc "$process_name" || echo 0)
    debug "Process '$process_name' count: $count"
    if [ "$count" -gt 0 ]; then
        return 0  # Process is running
    else
        return 1  # Process is not running
    fi
}

# Kill process if running
kill_process() {
    local process_name="$1"
    debug "Attempting to kill process: $process_name"
    
    if check_process "$process_name"; then
        debug "Process $process_name is running, stopping it now"
        killall -q "$process_name" 2>/dev/null || true
        sleep 1
        if check_process "$process_name"; then
            debug "Process $process_name is still running, force killing"
            killall -9 -q "$process_name" 2>/dev/null || true
            sleep 1
        fi
    else
        debug "Process $process_name is not running"
    fi
    
    # Double check
    if check_process "$process_name"; then
        debug "WARNING: Process $process_name could not be stopped"
        return 1
    else
        debug "Process $process_name is confirmed stopped"
        return 0
    fi
}

# Clean up existing installations
cleanup() {
    print_status "Cleaning up any previous installation files"
    
    # Stop existing services
    debug "Stopping Moonraker if running"
    kill_process "moonraker"
    kill_process "python3.*moonraker.py"
    
    debug "Stopping Nginx if running"
    kill_process "nginx"
    
    # Clean up temporary files
    debug "Removing temporary files"
    rm -rf "${TMPDIR:?}"/*
    rm -rf /root/.cache/pip || true
    mkdir -p "${TMPDIR}"
    
    debug "Cleanup completed"
}

# Install Moonraker
install_moonraker() {
    print_status "Installing Moonraker"
    
    # Check if Moonraker directory exists and remove if necessary
    if [ -d "${MOONRAKER_DIR}" ]; then
        debug "Moonraker directory already exists. Deleting..."
        rm -rf "${MOONRAKER_DIR}" || exit_on_error "Failed to delete ${MOONRAKER_DIR}"
    fi
    
    # Create directory and clone repository
    debug "Creating Moonraker directory and cloning repository"
    mkdir -p "${MOONRAKER_DIR}" || exit_on_error "Failed to create ${MOONRAKER_DIR}"
    cd "${USR_DATA}" || exit_on_error "Failed to change directory to ${USR_DATA}"
    
    # Clone with --depth=1 to minimize disk usage
    debug "Cloning Moonraker repository"
    git clone --depth=1 https://github.com/Arksine/moonraker.git "${MOONRAKER_DIR}" || exit_on_error "Failed to clone Moonraker"
    
    echo "Moonraker installed successfully"
    
    # Fix dbus_manager.py to avoid dependency issues
    print_status "Fixing dbus_manager.py to avoid dependency issues"
    debug "Original dbus_manager.py contents (first 10 lines):"
    head -n 10 "${MOONRAKER_DIR}/moonraker/components/dbus_manager.py" || debug "Could not read dbus_manager.py"
    
    debug "Writing new dbus_manager.py"
    cat > "${MOONRAKER_DIR}/moonraker/components/dbus_manager.py" << 'EOF'
# Modified dbus_manager.py for Creality K1
class DbusManager:
    def __init__(self, config):
        self.server = config.get_server()
        self.server.add_log_rollover_item("dbus_manager", None)

def load_component(config):
    return DbusManager(config)
EOF

    debug "New dbus_manager.py contents:"
    cat "${MOONRAKER_DIR}/moonraker/components/dbus_manager.py"
    echo "dbus_manager.py fixed successfully"
}

# Set up Python virtual environment
setup_venv() {
    print_status "Setting up Python virtual environment"
    
    # Remove existing virtual environment if it exists
    if [ -d "${VENV_DIR}" ]; then
        debug "Removing existing virtual environment..."
        rm -rf "${VENV_DIR}"
    fi
    
    # Create virtual environment using system packages to save space
    debug "Creating virtual environment with system packages..."
    python3 -m venv --system-site-packages "${VENV_DIR}" || {
        debug "Failed to create virtual environment with venv module. Creating minimal environment..."
        
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
    debug "Installing minimal Python dependencies..."
    pip3 install tornado==6.1 pyserial pillow --no-cache-dir || debug "Warning: Some dependencies failed to install, but we'll continue anyway"
    
    echo "Python virtual environment set up successfully"
}

# Create Moonraker configuration
create_moonraker_config() {
    print_status "Creating Moonraker configuration"
    
    debug "Writing moonraker.conf to ${CONFIG_DIR}/moonraker.conf"
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

    debug "Moonraker config file contents (first 10 lines):"
    head -n 10 "${CONFIG_DIR}/moonraker.conf"
    echo "Moonraker configuration created"
}

# Create Nginx configuration with proper structure
create_nginx_config() {
    print_status "Creating Nginx configuration"
    
    # Create Nginx directories
    mkdir -p /opt/etc/nginx
    
    # Remove any existing nginx.conf
    debug "Removing any existing nginx.conf"
    rm -f /opt/etc/nginx/nginx.conf
    
    # Create new nginx.conf
    debug "Creating new nginx.conf"
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
        default upgrade