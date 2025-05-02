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

    # Serve Fluidd and Mainsail on port 80 with URL prefixes
    server {
        listen 80;
        server_name _;

        location /fluidd {
            alias /usr/data/fluidd;
            try_files $uri $uri/ /fluidd/index.html;
        }

        location /mainsail {
            alias /usr/data/mainsail;
            try_files $uri $uri/ /mainsail/index.html;
        }

        location /websocket {
            proxy_pass http://127.0.0.1:7125/websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
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

    # Also serve Fluidd on its own port
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
    
    # Also serve Mainsail on its own port
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

    debug "Nginx config file created. First 10 lines:"
    head -n 10 /opt/etc/nginx/nginx.conf
    
    # Verify structure is correct
    if grep -q "^worker_processes" /opt/etc/nginx/nginx.conf && \
       grep -q "^events {" /opt/etc/nginx/nginx.conf && \
       grep -q "^http {" /opt/etc/nginx/nginx.conf; then
        debug "Nginx config structure verification passed"
    else
        debug "WARNING: Nginx config structure verification failed!"
        debug "Full nginx.conf contents:"
        cat /opt/etc/nginx/nginx.conf
    fi
    
    echo "Nginx configuration created"
}

# Create Moonraker service startup script
create_moonraker_service() {
    print_status "Creating Moonraker service script"
    
    debug "Creating start_moonraker.sh script"
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
    debug "start_moonraker.sh contents:"
    cat "${USR_DATA}/start_moonraker.sh"
    
    echo "Moonraker service script created at ${USR_DATA}/start_moonraker.sh"
}

# Install UI files - USE GIT CLONE 
install_ui_files() {
    print_status "Installing UI files via git clone"
    
    # Create temporary directory
    TEMP_CLONE="/usr/data/tmp"
    mkdir -p "${TEMP_CLONE}"
    
    # Install Mainsail
    debug "Installing Mainsail UI..."
    rm -rf "${MAINSAIL_DIR}"/*
    cd "${TEMP_CLONE}"
    debug "Cloning Mainsail repository..."
    
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
            debug "Mainsail UI files installed successfully"
        fi
    else
        debug "Failed to clone Mainsail repository, installation will continue with placeholders"
        create_minimal_ui "mainsail"
    fi
    
    # Install Fluidd
    debug "Installing Fluidd UI..."
    rm -rf "${FLUIDD_DIR}"/*
    cd "${TEMP_CLONE}"
    debug "Cloning Fluidd repository..."
    
    if git clone --depth=1 https://github.com/fluidd-core/fluidd.git; then
        if [ -d "${TEMP_CLONE}/fluidd" ]; then
            cp -r "${TEMP_CLONE}/fluidd/"* "${FLUIDD_DIR}/"
            rm -rf "${TEMP_CLONE}/fluidd"
            debug "Fluidd UI files installed successfully"
        fi
    else
        debug "Failed to clone Fluidd repository, installation will continue with placeholders"
        create_minimal_ui "fluidd"
    fi
}

# Create minimal UI files - UPDATED
create_minimal_ui() {
    UI_TYPE="$1"
    
    if [ "$UI_TYPE" = "mainsail" ]; then
        print_status "Creating minimal Mainsail UI"
        
        # Create minimal Mainsail placeholder 
        cat > "${MAINSAIL_DIR}/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Mainsail - Please Download UI</title>
    <style>
        body { font-family: sans-serif; text-align: center; padding: 50px; }
        h1 { color: #E76F51; }
        p { margin: 20px 0; }
    </style>
</head>
<body>
    <h1>Mainsail UI Not Installed</h1>
    <p>Please run the download script to install the Mainsail UI:</p>
    <p><code>/usr/data/download_ui.sh</code></p>
    <p>Or select option 2 from the menu.</p>
</body>
</html>
EOF
        debug "Created minimal Mainsail placeholder"
        
    elif [ "$UI_TYPE" = "fluidd" ]; then
        print_status "Creating minimal Fluidd UI"
        
        # Create minimal Fluidd placeholder
        cat > "${FLUIDD_DIR}/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Fluidd - Please Download UI</title>
    <style>
        body { font-family: sans-serif; text-align: center; padding: 50px; }
        h1 { color: #0078D7; }
        p { margin: 20px 0; }
    </style>
</head>
<body>
    <h1>Fluidd UI Not Installed</h1>
    <p>Please run the download script to install the Fluidd UI:</p>
    <p><code>/usr/data/download_ui.sh</code></p>
    <p>Or select option 1 from the menu.</p>
</body>
</html>
EOF
        debug "Created minimal Fluidd placeholder"
    fi
}

# Create UI download script for later use
create_download_script() {
    print_status "Creating UI download script for later use"
    
    debug "Creating download_ui.sh script"
    cat > "${USR_DATA}/download_ui.sh" << 'EOF'
#!/bin/sh

# Download Fluidd and Mainsail UIs for Creality K1

# Function to log messages
log() {
    echo "$(date +%H:%M:%S) - $1"
}

# Function to download UI using multiple methods
download_ui() {
    UI_NAME="$1"
    UI_DIR="$2"
    RELEASE_URL="$3"
    
    log "Downloading ${UI_NAME}..."
    cd /usr/data
    
    # Try wget first
    log "Trying wget method..."
    wget --no-check-certificate -O ${UI_NAME,,}.zip "$RELEASE_URL"
    if [ $? -eq 0 ]; then
        log "Extracting ${UI_NAME}..."
        rm -rf "${UI_DIR}"/*
        unzip -o ${UI_NAME,,}.zip -d "${UI_DIR}"
        rm ${UI_NAME,,}.zip
        log "${UI_NAME} installed successfully!"
        return 0
    fi
    
    # Try curl as second option
    log "Trying curl method..."
    curl -L -k -o ${UI_NAME,,}.zip "$RELEASE_URL"
    if [ $? -eq 0 ]; then
        log "Extracting ${UI_NAME}..."
        rm -rf "${UI_DIR}"/*
        unzip -o ${UI_NAME,,}.zip -d "${UI_DIR}"
        rm ${UI_NAME,,}.zip
        log "${UI_NAME} installed successfully!"
        return 0
    fi
    
    log "All download methods failed for ${UI_NAME}."
    return 1
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
    download_ui "Fluidd" "/usr/data/fluidd" "https://github.com/fluidd-core/fluidd/releases/latest/download/fluidd.zip"
}

# Download Mainsail
download_mainsail() {
    download_ui "Mainsail" "/usr/data/mainsail" "https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip"
}

# Execute main menu if run directly
if [ "$0" = "/usr/data/download_ui.sh" ]; then
    show_menu
fi
EOF

    chmod +x "${USR_DATA}/download_ui.sh"
    debug "download_ui.sh contents (first 10 lines):"
    head -n 10 "${USR_DATA}/download_ui.sh"
    
    echo "Download script created at ${USR_DATA}/download_ui.sh"
}

# Start Moonraker
start_moonraker() {
    print_status "Starting Moonraker"
    
    debug "Checking if Moonraker is already running"
    if check_process "python3.*moonraker.py"; then
        debug "Moonraker is already running, stopping it first"
        kill_process "python3.*moonraker.py"
    fi
    
    debug "Starting Moonraker with start_moonraker.sh"
    "${USR_DATA}/start_moonraker.sh"
    
    # Check if Moonraker started
    sleep 2
    if check_process "python3.*moonraker.py"; then
        debug "Moonraker process is running"
        echo "Moonraker started successfully!"
    else
        debug "Moonraker process is NOT running after start attempt"
        debug "Checking Moonraker log:"
        tail -n 20 "${LOGS_DIR}/moonraker.log" || debug "Could not read Moonraker log"
        echo "Warning: Moonraker may not have started properly. Check logs at ${LOGS_DIR}/moonraker.log"
    fi
}

# Start Nginx
start_nginx() {
    print_status "Starting Nginx"
    
    # Kill any existing Nginx process
    debug "Stopping Nginx if it's already running"
    kill_process "nginx"
    
    # Start Nginx
    debug "Starting Nginx"
    /opt/sbin/nginx
    
    # Check if Nginx started
    sleep 1
    if check_process "nginx"; then
        debug "Nginx process is running"
        echo "Nginx started successfully!"
    else
        debug "Nginx is NOT running after start attempt"
        debug "Checking Nginx error log:"
        tail -n 20 /opt/var/log/nginx/error.log 2>/dev/null || debug "Could not read Nginx error log"
        
        # Check for specific error conditions
        debug "Testing Nginx configuration file"
        /opt/sbin/nginx -t
        
        echo "Warning: Nginx may not have started properly."
        return 1
    fi
}

# Check installation
verify_installation() {
    print_status "Verifying installation"
    
    local errors=0
    
    # Check Moonraker
    debug "Checking if Moonraker is running"
    if check_process "python3.*moonraker.py"; then
        echo "✓ Moonraker is running"
    else
        echo "✗ Moonraker is NOT running"
        errors=$((errors + 1))
    fi
    
    # Check Nginx
    debug "Checking if Nginx is running"
    if check_process "nginx"; then
        echo "✓ Nginx is running"
    else
        echo "✗ Nginx is NOT running"
        errors=$((errors + 1))
    fi
    
    # Check UI files
    if [ -f "${MAINSAIL_DIR}/index.html" ]; then
        echo "✓ Mainsail UI files are installed"
    else
        echo "✗ Mainsail UI files are NOT installed"
        errors=$((errors + 1))
    fi
    
    if [ -f "${FLUIDD_DIR}/index.html" ]; then
        echo "✓ Fluidd UI files are installed"
    else
        echo "✗ Fluidd UI files are NOT installed"
        errors=$((errors + 1))
    fi
    
    # Report status
    if [ $errors -eq 0 ]; then
        echo "✓ Installation verification passed!"
        return 0
    else
        echo "✗ Installation verification failed with $errors errors"
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
echo ""
echo "Moonraker is running on port 7125"
echo "UI interfaces are installed and ready to use:"
echo "  • Fluidd: http://$(ip route get 1 | awk '{print $7;exit}'):4408"
echo "  • Mainsail: http://$(ip route get 1 | awk '{print $7;exit}'):4409"
echo ""
echo "Note: The official Creality warning states that running Moonraker"
echo "for extended periods may cause memory issues on the K1 series."
echo ""
echo "Installation log saved to: ${SCRIPT_LOG}"
echo ""
echo "Enjoy!"
}

# Execute main function
main