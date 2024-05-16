#!/bin/bash

# This script sets up Mainsail and Fluidd on Creality K1 and K1-Max printers.

echo "Starting setup for Creality K1/K1-Max..."

# Step 1: Install Entware
echo "Installing Entware..."
cd /tmp
wget http://bin.entware.net/mipselsf-k3.4/installer/generic.sh
sh generic.sh

# Initialize and update Entware
/opt/bin/opkg update
/opt/bin/opkg upgrade

# Step 2: Install necessary packages
echo "Installing necessary packages..."
/opt/bin/opkg install make gcc python3-dev python3-pip git

# Step 3: Install Python packages
/opt/bin/pip3 install wheel setuptools
/opt/bin/pip3 install watchdog PyYAML Markdown Jinja2 packaging mergedeep importlib-metadata zipp tomli typing-extensions

# Create directories for configuration and assets
mkdir -p /usr/data/config /usr/data/assets/img/home

# Download logo and favicon
wget -O /usr/data/assets/img/home/logo.png [URL-to-logo]
wget -O /usr.data/assets/img/home/favicon.png [URL-to-favicon]

# Download extra assets
wget -O /usr/data/assets/stylesheets/extra.css [URL-to-extra-css]
wget -O /usr/data/assets/stylesheets/glightbox.min.css [URL-to-glightbox-css]
wget -O /usr/data/assets/javascripts/glightbox.min.js [URL-to-glightbox-js]
wget -O /usr/data/assets/javascripts/external_links.js [URL-to-external-js]

# Step 4: Configure the server
echo "Configuring server..."
# Additional server configuration goes here

echo "Setup complete! Access the web interface via the printer's IP address."

# Reminder to configure Moonraker, Mainsail, and Fluidd as per their documentation.
echo "Please configure Moonraker, Mainsail, and Fluidd as per their documentation."
