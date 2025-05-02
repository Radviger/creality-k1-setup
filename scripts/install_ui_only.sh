#!/bin/sh

# Standalone UI installer script for Fluidd and Mainsail
# This script can be called independently or as part of the main installation

# Directories
MAINSAIL_DIR="/usr/data/mainsail"
FLUIDD_DIR="/usr/data/fluidd"
TEMP_CLONE="/usr/data/tmp"
LOG_FILE="/usr/data/ui_install.log"

# Debug function
debug() {
    echo "[DEBUG $(date +%H:%M:%S)] $1" | tee -a "$LOG_FILE"
}

# Create necessary directories
mkdir -p "${TEMP_CLONE}"
mkdir -p "${MAINSAIL_DIR}"
mkdir -p "${FLUIDD_DIR}"

# Install Mainsail using git clone
debug "Installing Mainsail UI..."
rm -rf "${MAINSAIL_DIR}"/*
cd "${TEMP_CLONE}"

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
        echo "✓ Mainsail UI installed successfully"
    fi
else
    debug "Failed to clone Mainsail repository"
    echo "✗ Failed to install Mainsail UI"
fi

# Install Fluidd using git clone  
debug "Installing Fluidd UI..."
rm -rf "${FLUIDD_DIR}"/*
cd "${TEMP_CLONE}"

if git clone --depth=1 https://github.com/fluidd-core/fluidd.git; then
    if [ -d "${TEMP_CLONE}/fluidd" ]; then
        cp -r "${TEMP_CLONE}/fluidd/"* "${FLUIDD_DIR}/"
        rm -rf "${TEMP_CLONE}/fluidd"
        debug "Fluidd UI files installed successfully"
        echo "✓ Fluidd UI installed successfully"
    fi
else
    debug "Failed to clone Fluidd repository"
    echo "✗ Failed to install Fluidd UI"
fi

# Clean up temp directory
rm -rf "${TEMP_CLONE}"

# Verify installation
if [ -f "${MAINSAIL_DIR}/index.html" ] && ! grep -q "Mainsail - Please Download UI" "${MAINSAIL_DIR}/index.html" 2>/dev/null; then
    echo "✓ Mainsail UI is properly installed"
else
    echo "✗ Mainsail UI installation failed"
fi

if [ -f "${FLUIDD_DIR}/index.html" ] && ! grep -q "Fluidd - Please Download UI" "${FLUIDD_DIR}/index.html" 2>/dev/null; then
    echo "✓ Fluidd UI is properly installed"
else
    echo "✗ Fluidd UI installation failed"
fi

echo "UI installation complete. Restart Nginx if needed: killall nginx && /opt/sbin/nginx"