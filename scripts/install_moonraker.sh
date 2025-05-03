#!/bin/sh

# Automated Moonraker/Nginx Installation Script for Creality K1
# Compatible with BusyBox sh shell

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

# Create log file
echo "Starting installation script at $(date)" > "${SCRIPT_LOG}"
echo "--------------------------------------------------------------------------" >> "${SCRIPT_LOG}"

# Function to log and print
log() {
    echo "$@" | tee -a "${SCRIPT_LOG}"
}

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
    log "==========================================================================="
    log "$(date +%H:%M:%S) - $1"
    log "==========================================================================="
}

# Exit on error
exit_on_error() {
    log "ERROR: $1"
    log "Check log at ${SCRIPT_LOG} for details"
    exit 1
}

# Process status check - BusyBox compatible
check_process() {
    local process_name="$1"
    # Use ps and grep instead of pgrep for BusyBox compatibility
    local count=$(ps | grep -v grep | grep -c "$process_name" || echo 0)
    if [ "$count" -gt 0 ]; then
        return 0  # Process is running
    else
        return 1  # Process is not running
    fi
}

# Kill process if running
kill_process() {
    local process_name="$1"
    log "Attempting to kill process: $process_name"
    
    if check_process "$process_name"; then
        log "Process $process_name is running, stopping it now"
        killall -q "$process_name" 2>/dev/null || true
        sleep 1
        if check_process "$process_name"; then
            log "Process $process_name is still running, force killing"
            killall -9 -q "$process_name" 2>/dev/null || true
            sleep 1
        fi
    else
        log "Process $process_name is not running"
    fi
    
    # Double check
    if check_process "$process_name"; then
        log "WARNING: Process $process_name could not be stopped"
        return 1
    else
        log "Process $process_name is confirmed stopped"
        return 0
    fi
}

# Check if port is in use
check_port() {
    local port=$1
    if $(netstat -an 2>/dev/null | grep -q ":$port "); then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Clean up existing installations
cleanup() {
    print_status "Cleaning up any previous installation files"
    
    # Stop existing services
    log "Stopping Moonraker if running"
    kill_process "moonraker"
    kill_process "python3.*moonraker.py"
    
    log "Stopping Nginx if running"
    kill_process "nginx"
    
    # Clean up temporary files
    log "Removing temporary files"
    rm -rf "${TMPDIR:?}"/*
    rm -rf /root/.cache/pip || true
    mkdir -p "${TMPDIR}"
    
    log "Cleanup completed"
}

# Install Moonraker
install_moonraker() {
    print_status "Installing Moonraker"
    
    # Check if Moonraker directory exists and remove if necessary
    if [ -d "${MOONRAKER_DIR}" ]; then
        log "Moonraker directory already exists. Deleting..."
        rm -rf "${MOONRAKER_DIR}" || exit_on_error "Failed to delete ${MOONRAKER_DIR}"
    fi
    
    # Create directory and clone repository
    log "Creating Moonraker directory and cloning repository"
    mkdir -p "${MOONRAKER_DIR}" || exit_on_error "Failed to create ${MOONRAKER_DIR}"
    cd "${USR_DATA}" || exit_on_error "Failed to change directory to ${USR_DATA}"
    
    # Clone with --depth=1 to minimize disk usage
    log "Cloning Moonraker repository"
    git clone --depth=1 https://github.com/Arksine/moonraker.git "${MOONRAKER_DIR}" || exit_on_error "Failed to clone Moonraker"
    
    log "Moonraker installed successfully"
    
    # Fix dbus_manager.py to avoid dependency issues
    print_status "Fixing dbus_manager.py to avoid dependency issues"
    cat > "${MOONRAKER_DIR}/moonraker/components/dbus_manager.py" << 'EOF'
# Modified dbus_manager.py for Creality K1
class DbusManager:
    def __init__(self, config):
        self.server = config.get_server()
        self.server.add_log_rollover_item("dbus_manager", None)

def load_component(config):
    return DbusManager(config)
EOF

    log "dbus_manager.py fixed successfully"
}

# Set up Python virtual environment
setup_venv() {
    print_status "Setting up Python virtual environment"
    
    # Remove existing virtual environment if it exists
    if [ -d "${VENV_DIR}" ]; then
        log "Removing existing virtual environment..."
        rm -rf "${VENV_DIR}"
    fi
    
    # Create virtual environment using system packages to save space
    log "Creating virtual environment with system packages..."
    python3 -m venv --system-site-packages "${VENV_DIR}" || {
        log "Failed to create virtual environment with venv module. Creating minimal environment..."
        
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
    log "Installing minimal Python dependencies..."
    pip3 install tornado==6.1 pyserial pillow --no-cache-dir || log "Warning: Some dependencies failed to install, but we'll continue anyway"
    
    log "Python virtual environment set up successfully"
}

# Create Moonraker configuration
create_moonraker_config() {
    print_status "Creating Moonraker configuration"
    
    log "Writing moonraker.conf to ${CONFIG_DIR}/moonraker.conf"
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

    log "Moonraker configuration created"
}

# Create Nginx configuration with proper structure
create_nginx_config() {
    print_status "Creating Nginx configuration"
    
    # Create Nginx directories
    mkdir -p /opt/etc/nginx
    
    # Remove any existing nginx.conf
    log "Removing any existing nginx.conf"
    rm -f /opt/etc/nginx/nginx.conf
    
    # Check which ports are available
    local fluidd_port=4408
    local mainsail_port=4409
    
    # Find available ports if default ones are in use
    if check_port $fluidd_port; then
        log "Port $fluidd_port is in use, trying alternative..."
        fluidd_port=4410
    fi
    
    if check_port $mainsail_port; then
        log "Port $mainsail_port is in use, trying alternative..."
        mainsail_port=4411
    fi
    
    log "Using ports: Fluidd=$fluidd_port, Mainsail=$mainsail_port"
    
    # Create new nginx.conf - WITHOUT port 80 to avoid conflicts
    log "Creating new nginx.conf"
    cat > /opt/etc/nginx/nginx.conf << EOF
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
        listen ${fluidd_port};
        root /usr/data/fluidd;
        
        location / {
            try_files \$uri \$uri/ /index.html;
        }
        
        location = /index.html {
            add_header Cache-Control "no-store, no-cache, must-revalidate";
        }
        
        location /websocket {
            proxy_pass http://127.0.0.1:7125/websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \$connection_upgrade;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
        
        location ~ ^/(printer|api|access|machine|server)/ {
            proxy_pass http://127.0.0.1:7125;
            proxy_http_version 1.1;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }
    
    # Serve Mainsail on its own port
    server {
        listen ${mainsail_port};
        root /usr/data/mainsail;
        
        location / {
            try_files \$uri \$uri/ /index.html;
        }
        
        location = /index.html {
            add_header Cache-Control "no-store, no-cache, must-revalidate";
        }
        
        location /websocket {
            proxy_pass http://127.0.0.1:7125/websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \$connection_upgrade;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
        
        location ~ ^/(printer|api|access|machine|server)/ {
            proxy_pass http://127.0.0.1:7125;
            proxy_http_version 1.1;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }
    
    map \$http_upgrade \$connection_upgrade {
        default upgrade;
        '' close;
    }
}
EOF

    log "Nginx configuration created"
}

# Create Moonraker service startup script
create_moonraker_service() {
    print_status "Creating Moonraker service script"
    
    log "Creating start_moonraker.sh script"
    cat > "${USR_DATA}/start_moonraker.sh" << 'EOF'
#!/bin/sh

# Kill any existing Moonraker process
killall -q moonraker 2>/dev/null || true
pkill -f "moonraker.py" 2>/dev/null || true
sleep 1

# Start Moonraker
cd /usr/data/moonraker
python3 /usr/data/moonraker/moonraker/moonraker.py -d /usr/data/printer_data > /usr/data/printer_data/logs/moonraker.log 2>&1 &

echo "Moonraker started!"
EOF

    chmod +x "${USR_DATA}/start_moonraker.sh"
    log "Moonraker service script created at ${USR_DATA}/start_moonraker.sh"
}

# Install UI files - USE GIT CLONE 
install_ui_files() {
    print_status "Installing UI files via git clone"
    
    # Create temporary directory
    TEMP_CLONE="/usr/data/tmp"
    mkdir -p "${TEMP_CLONE}"
    
    # Install Mainsail
    log "Installing Mainsail UI..."
    rm -rf "${MAINSAIL_DIR}"/*
    cd "${TEMP_CLONE}"
    log "Cloning Mainsail repository..."
    
    if git clone --depth=1 https://github.com/mainsail-crew/mainsail.git; then
        if [ -d "${TEMP_CLONE}/mainsail" ]; then
            # Check if dist directory exists (for production builds)
            if [ -d "${TEMP_CLONE}/mainsail/dist" ]; then
                cp -r "${TEMP_CLONE}/mainsail/dist/"* "${MAINSAIL_DIR}/"
            else
                # Copy all files if no dist directory
                cp -r "${TEMP_CLONE}/mainsail/"* "${MAINSAIL_DIR}/"
            fi
            rm -rf "${TEMP_CLONE}/mainsail"
            log "Mainsail UI files installed successfully"
        fi
    else
        log "Failed to clone Mainsail repository"
    fi
    
    # Install Fluidd
    log "Installing Fluidd UI..."
    rm -rf "${FLUIDD_DIR}"/*
    cd "${TEMP_CLONE}"
    log "Cloning Fluidd repository..."
    
    if git clone --depth=1 https://github.com/fluidd-core/fluidd.git; then
        if [ -d "${TEMP_CLONE}/fluidd" ]; then
            cp -r "${TEMP_CLONE}/fluidd/"* "${FLUIDD_DIR}/"
            rm -rf "${TEMP_CLONE}/fluidd"
            log "Fluidd UI files installed successfully"
        fi
    else
        log "Failed to clone Fluidd repository"
    fi
}

# Create UI download script for later use
create_download_script() {
    print_status "Creating UI download script for later use"
    
    log "Creating download_ui.sh script"
    cat > "${USR_DATA}/download_ui.sh" << 'EOF'
#!/bin/sh

# Download Fluidd and Mainsail UIs for Creality K1

# Function to log messages
log() {
    echo "$(date +%H:%M:%S) - $1"
}

# Main menu
show_menu() {
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
}

# Download Fluidd
download_fluidd() {
    log "Downloading Fluidd..."
    cd /usr/data
    rm -rf fluidd
    git clone --depth=1 https://github.com/fluidd-core/fluidd.git
    log "Fluidd installed successfully!"
}

# Download Mainsail
download_mainsail() {
    log "Downloading Mainsail..."
    cd /usr/data
    rm -rf mainsail
    git clone --depth=1 https://github.com/mainsail-crew/mainsail.git
    log "Mainsail installed successfully!"
}

# Execute main menu if run directly
if [ "$0" = "/usr/data/download_ui.sh" ]; then
    show_menu
fi
EOF

    chmod +x "${USR_DATA}/download_ui.sh"
    log "Download script created at ${USR_DATA}/download_ui.sh"
}

# Start Moonraker
start_moonraker() {
    print_status "Starting Moonraker"
    
    log "Checking if Moonraker is already running"
    if check_process "python3.*moonraker.py"; then
        log "Moonraker is already running, stopping it first"
        kill_process "python3.*moonraker.py"
    fi
    
    log "Starting Moonraker with start_moonraker.sh"
    "${USR_DATA}/start_moonraker.sh"
    
    # Check if Moonraker started
    sleep 2
    if check_process "python3.*moonraker.py"; then
        log "Moonraker process is running"
        log "Moonraker started successfully!"
    else
        log "Moonraker process is NOT running after start attempt"
        log "Checking Moonraker log:"
        tail -n 20 "${LOGS_DIR}/moonraker.log" || log "Could not read Moonraker log"
        log "Warning: Moonraker may not have started properly. Check logs at ${LOGS_DIR}/moonraker.log"
    fi
}

# Start Nginx
start_nginx() {
    print_status "Starting Nginx"
    
    # Kill any existing Nginx process
    log "Stopping Nginx if it's already running"
    kill_process "nginx"
    
    # Start Nginx
    log "Starting Nginx"
    /opt/sbin/nginx
    
    # Check if Nginx started
    sleep 1
    if check_process "nginx"; then
        log "Nginx process is running"
        log "Nginx started successfully!"
    else
        log "Nginx is NOT running after start attempt"
        log "Checking Nginx error log:"
        tail -n 20 /opt/var/log/nginx/error.log 2>/dev/null || log "Could not read Nginx error log"
        
        # Check for specific error conditions
        log "Testing Nginx configuration file"
        /opt/sbin/nginx -t
        
        log "Warning: Nginx may not have started properly."
        return 1
    fi
}

# Check installation
verify_installation() {
    print_status "Verifying installation"
    
    local errors=0
    
    # Check Moonraker
    log "Checking if Moonraker is running"
    if check_process "python3.*moonraker.py"; then
        log "✓ Moonraker is running"
    else
        log "✗ Moonraker is NOT running"
        errors=$((errors + 1))
    fi
    
    # Check Nginx
    log "Checking if Nginx is running"
    if check_process "nginx"; then
        log "✓ Nginx is running"
    else
        log "✗ Nginx is NOT running"
        errors=$((errors + 1))
    fi
    
    # Check UI files
    if [ -f "${MAINSAIL_DIR}/index.html" ]; then
        log "✓ Mainsail UI files are installed"
    else
        log "✗ Mainsail UI files are NOT installed"
        errors=$((errors + 1))
    fi
    
    if [ -f "${FLUIDD_DIR}/index.html" ]; then
        log "✓ Fluidd UI files are installed"
    else
        log "✗ Fluidd UI files are NOT installed"
        errors=$((errors + 1))
    fi
    
    # Report status
    if [ $errors -eq 0 ]; then
        log "✓ Installation verification passed!"
        return 0
    else
        log "✗ Installation verification failed with $errors errors"
        return 1
    fi
}

# Main execution
main() {
    print_status "Starting installation of Moonraker, Nginx, and UI files for Creality K1"
    
    # Run all installation steps
    cleanup
    install_moonraker
    setup_venv
    create_moonraker_config
    create_nginx_config
    create_moonraker_service
    install_ui_files
    create_download_script
    
    # Start services
    start_moonraker
    start_nginx
    
    # Verify installation
    verify_installation
    
    print_status "Installation complete!"
log ""
log "Moonraker is running on port 7125"
log "UI interfaces are installed and ready to use:"
log "  • Fluidd: http://$(ip route get 1 | awk '{print $7;exit}'):4408"
log "  • Mainsail: http://$(ip route get 1 | awk '{print $7;exit}'):4409"
log ""
log "Note: The official Creality warning states that running Moonraker"
log "for extended periods may cause memory issues on the K1 series."
log ""
log "Installation log saved to: ${SCRIPT_LOG}"
log ""
log "Enjoy!"
}

# Execute main function
main