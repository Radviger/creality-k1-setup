#!/bin/sh

# Clone the repository
git clone https://github.com/Mariusjuvet1/creality-k1-setup.git

# Navigate into the cloned repository
cd creality-k1-setup

# Give execute permissions to install.sh
chmod +x install.sh

# Install bash
opkg install bash

# Make sure bash_install.sh is executable
chmod +x bash_install.sh

# Run the bash_install.sh script with bash
bash bash_install.sh