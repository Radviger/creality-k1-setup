#!/bin/sh

# MJ: This script uninstalls the setup by removing installed directories and services.
# It does not remove the default vendor (Creality) Moonraker installation if it exists.

# Function to print and exit on error
exit_on_error() {
    echo "$1"
    exit 1
}

# Locate existing Moonraker installation
EXISTING_MOONRAKER_DIR=$(find / -name "moonraker" -type d 2>/dev/null | grep -v "/usr/data/moonraker")

# Check if existing Moonraker directory is found
if [ -z "$EXISTING_MOONRAKER_DIR" ]; then
    echo "No existing Moonraker installation found."
else
    echo "Found existing Moonraker installation at: $EXISTING_MOONRAKER_DIR"
fi

# Uninstall Fluidd and Mainsail
WORKING_DIR="/usr/data"
FLUIDD_DIR="$WORKING_DIR/fluidd"
MAINSAIL_DIR="$WORKING_DIR/mainsail"

if [ -d "$FLUIDD_DIR" ]; then
    echo "Removing Fluidd directory..."
    rm -rf "$FLUIDD_DIR" || exit_on_error "Failed to remove Fluidd directory"
fi

if [ -d "$MAINSAIL_DIR" ]; then
    echo "Removing Mainsail directory..."
    rm -rf "$MAINSAIL_DIR" || exit_on_error "Failed to remove Mainsail directory"
fi

# Uninstall Moonraker only if it is not the existing installation
MOONRAKER_DIR="$WORKING_DIR/moonraker"
if [ -d "$MOONRAKER_DIR" ] && [ "$MOONRAKER_DIR" != "$EXISTING_MOONRAKER_DIR" ]; then
    echo "Removing Moonraker directory..."
    rm -rf "$MOONRAKER_DIR" || exit_on_error "Failed to remove Moonraker directory"
fi

# Remove Moonraker user
if id "moonrakeruser" >/dev/null 2>&1; then
    echo "Removing moonrakeruser..."
    deluser moonrakeruser || exit_on_error "Failed to remove moonrakeruser"
fi

# Restart Nginx to apply changes
echo "Restarting Nginx..."
/opt/etc/init.d/S80nginx restart || exit_on_error "Failed to restart Nginx"

echo "Uninstallation complete!"
