#!/bin/sh

# MJ: This script uninstalls the Mainsail and Fluidd setup for the Creality K1 and K1-Max printers.
# It removes installed directories and restores the original configuration.

# Function to print and exit on error
exit_on_error() {
    echo "$1"
    exit 1
}

# Stop services
echo "Stopping Moonraker..."
/opt/etc/init.d/S80moonraker stop || echo "Failed to stop Moonraker"

echo "Stopping Nginx..."
/opt/etc/init.d/S80nginx stop || echo "Failed to stop Nginx"

# Remove installed directories
echo "Removing Moonraker directory..."
rm -rf /usr/data/moonraker || exit_on_error "Failed to remove Moonraker directory"

echo "Removing Mainsail directory..."
rm -rf /usr/data/mainsail || exit_on_error "Failed to remove Mainsail directory"

echo "Removing Fluidd directory..."
rm -rf /usr/data/fluidd || exit_on_error "Failed to remove Fluidd directory"

# Remove Nginx configuration
echo "Removing Nginx configuration..."
rm -f /opt/etc/nginx/nginx.conf || exit_on_error "Failed to remove Nginx configuration"

# Restore backup of printer.cfg if it exists
BACKUP_PRINTER_CFG="/usr/data/printer_data/config/printer.cfg.backup"
PRINTER_CFG="/usr/data/printer_data/config/printer.cfg"

if [ -f "$BACKUP_PRINTER_CFG" ]; then
    echo "Restoring original printer.cfg..."
    mv "$BACKUP_PRINTER_CFG" "$PRINTER_CFG" || exit_on_error "Failed to restore original printer.cfg"
fi

# Remove the setup directory
echo "Removing setup directory..."
cd /usr/data || exit_on_error "Failed to change directory to /usr/data"
rm -rf creality-k1-setup || exit_on_error "Failed to remove setup directory"

echo "Uninstallation complete!"
