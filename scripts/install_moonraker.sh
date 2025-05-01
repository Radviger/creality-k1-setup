#!/bin/sh

# Moonraker Dependencies Fixer for Creality K1/K1-Max
# This script fixes the missing Python dependencies for Moonraker

# Function to print messages
print_message() {
  echo "===================================================================="
  echo "$1"
  echo "===================================================================="
  echo ""
}

# Create directories
create_dirs() {
  print_message "Creating necessary directories"
  mkdir -p /usr/data/python_deps
  mkdir -p /usr/data/python_deps/wheels
  echo "Directories created."
}

# Install Entware and necessary packages
install_entware() {
  print_message "Checking Entware installation"
  
  if [ ! -d "/opt" ] || [ ! -f "/opt/bin/opkg" ]; then
    echo "Entware not found. Installing Entware..."
    
    # Navigate to /tmp directory
    cd /tmp
    
    # Remove any existing generic.sh file
    rm -f generic.sh
    
    # Download the Entware installer
    echo "Downloading Entware installer..."
    wget http://bin.entware.net/mipselsf-k3.4/installer/generic.sh
    
    if [ $? -ne 0 ]; then
      echo "Failed to download Entware installer. Aborting."
      exit 1
    fi
    
    # Run the Entware installer
    echo "Running Entware installer..."
    sh generic.sh
    
    if [ $? -ne 0 ]; then
      echo "Failed to install Entware. Aborting."
      exit 1
    fi
    
    echo "Entware installed successfully."
  else
    echo "Entware is already installed."
  fi
  
  # Add Entware to PATH
  export PATH=$PATH:/opt/bin:/opt/sbin
  
  # Install necessary packages
  echo "Installing necessary packages..."
  /opt/bin/opkg update
  /opt/bin/opkg install python3-pip
  /opt/bin/opkg install wget-ssl
  /opt/bin/opkg install python3-dev
  /opt/bin/opkg install gcc
  /opt/bin/opkg install make
  
  echo "Packages installed."
}

# Install Python dependencies using pip
install_python_deps() {
  print_message "Installing Python dependencies"
  
  # Use pip to install the required packages
  pip3 install --upgrade pip
  
  echo "Installing tornado..."
  pip3 install tornado==6.1
  
  echo "Installing other Moonraker dependencies..."
  pip3 install pyserial
  pip3 install jinja2
  pip3 install pillow
  pip3 install inotify-simple
  pip3 install libnacl
  pip3 install paho-mqtt
  pip3 install zeroconf
  pip3 install distro
  pip3 install lmdb
  pip3 install apprise
  pip3 install ldap3
  pip3 install dbus-next
  
  echo "Python dependencies installed."
}

# Manually create a virtual environment with system packages
setup_moonraker_env() {
  print_message "Setting up Moonraker environment"
  
  # Check if moonraker directory exists
  if [ ! -d "/usr/data/moonraker" ]; then
    echo "Moonraker directory not found at /usr/data/moonraker."
    echo "Cloning Moonraker repository..."
    cd /usr/data
    git clone https://github.com/Arksine/moonraker.git
  fi
  
  # Create a virtual environment
  echo "Creating virtual environment..."
  if [ -d "/usr/data/moonraker-env" ]; then
    echo "Removing existing moonraker-env..."
    rm -rf /usr/data/moonraker-env
  fi
  
  # Create virtual environment with system packages
  python3 -m venv --system-site-packages /usr/data/moonraker-env
  
  echo "Moonraker environment set up."
}

# Configure Moonraker
configure_moonraker() {
  print_message "Configuring Moonraker"
  
  # Create moonraker.conf if it doesn't exist
  mkdir -p /usr/data/printer_data/config
  
  if [ ! -f "/usr/data/printer_data/config/moonraker.conf" ]; then
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
    *.local
    *.lan
    *://my.mainsail.xyz
    *://app.fluidd.xyz

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
  else
    echo "Moonraker configuration already exists."
  fi
}

# Test Moonraker
test_moonraker() {
  print_message "Testing Moonraker installation"
  
  echo "Stopping any existing Moonraker processes..."
  pkill -f "moonraker.py" || true
  
  echo "Starting Moonraker..."
  cd /usr/data/moonraker
  /usr/data/moonraker-env/bin/python /usr/data/moonraker/moonraker/moonraker.py -d /usr/data/printer_data > /usr/data/printer_data/logs/moonraker.log 2>&1 &
  
  # Wait for Moonraker to start
  sleep 5
  
  # Check if Moonraker is running
  if pgrep -f "moonraker.py" > /dev/null; then
    echo "Moonraker is running successfully!"
  else
    echo "Moonraker failed to start. Checking logs..."
    tail -n 50 /usr/data/printer_data/logs/moonraker.log
  fi
}

# Create launcher script
create_launcher() {
  print_message "Creating Moonraker launcher script"
  
  cat > /usr/data/start_moonraker.sh << 'EOF'
#!/bin/sh

# Kill any existing Moonraker process
pkill -f "moonraker.py" || true

# Start Moonraker
cd /usr/data/moonraker
/usr/data/moonraker-env/bin/python /usr/data/moonraker/moonraker/moonraker.py -d /usr/data/printer_data > /usr/data/printer_data/logs/moonraker.log 2>&1 &

echo "Moonraker started!"
EOF

  chmod +x /usr/data/start_moonraker.sh
  
  echo "Launcher script created at /usr/data/start_moonraker.sh"
}

# Install Moonraker as a service
install_service() {
  print_message "Installing Moonraker service"
  
  # Create systemd service or init.d script
  cat > /etc/init.d/moonraker << 'EOF'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/data/moonraker-env/bin/python /usr/data/moonraker/moonraker/moonraker.py -d /usr/data/printer_data
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}
EOF

  chmod +x /etc/init.d/moonraker
  
  echo "Moonraker service installed."
  echo "You can start it with: /etc/init.d/moonraker start"
}

# Main function
main() {
  print_message "Starting Moonraker Dependencies Fixer"
  
  create_dirs
  install_entware
  install_python_deps
  setup_moonraker_env
  configure_moonraker
  create_launcher
  install_service
  test_moonraker
  
  # Final message
  print_message "Installation complete!"
  echo "If Moonraker is now running, you can connect using:"
  echo "- Fluidd at: http://$(ip route get 1 | awk '{print $7;exit}'):4408"
  echo "- Mainsail at: http://$(ip route get 1 | awk '{print $7;exit}'):4409"
  echo ""
  echo "If Moonraker is not running, you can start it with:"
  echo "/usr/data/start_moonraker.sh"
  echo ""
  echo "You can also try to start the service with:"
  echo "/etc/init.d/moonraker start"
  echo ""
  echo "Check logs at: /usr/data/printer_data/logs/moonraker.log"
}

# Run the main function
main