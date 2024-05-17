#!/bin/sh

# MJ: This script downloads and sets up Mainsail from the Creality K1 Series Annex repository

# Function to print and exit on error
exit_on_error() {
    echo "$1"
    exit 1
}

# Set the working directory
WORKING_DIR="/usr/data"
MAINSAIL_DIR="$WORKING_DIR/mainsail"

# URL of the tar file in the GitHub repository
TAR_URL="https://github.com/CrealityOfficial/K1_Series_Annex/raw/main/mainsail/mainsail/mainsail.tar"

# Ensure the working directory exists
if [ ! -d "$WORKING_DIR" ]; then
    exit_on_error "The directory $WORKING_DIR does not exist. Please ensure the repository is cloned correctly."
fi

# Create a directory for Mainsail if it doesn't exist
if [ ! -d "$MAINSAIL_DIR" ]; then
    mkdir -p "$MAINSAIL_DIR" || exit_on_error "Failed to create directory $MAINSAIL_DIR"
fi

# Navigate to the Mainsail directory
cd "$MAINSAIL_DIR" || exit_on_error "Failed to navigate to $MAINSAIL_DIR"

# Download the tar file
echo "Downloading mainsail.tar from GitHub..."
curl -L -o mainsail.tar "$TAR_URL" || exit_on_error "Failed to download mainsail.tar"

# Extract the tar file
echo "Extracting mainsail.tar..."
tar -xvf mainsail.tar || exit_on_error "Failed to extract mainsail.tar"

# Clean up by removing the tar file
rm mainsail.tar

# Ensure necessary directories and files are in place
if [ ! -d "$MAINSAIL_DIR/mainsail" ]; then
    exit_on_error "Extraction failed or mainsail directory not found"
fi

echo "Mainsail setup complete!"
