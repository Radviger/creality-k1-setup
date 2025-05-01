# Creality K1 and K1-Max Setup for Mainsail and Fluidd

This repository provides a step-by-step guide to setting up Mainsail and Fluidd on Creality K1 and K1-Max 3D printers. These steps include installing Entware, necessary dependencies, and configuring the environment.

## Table of Contents
- [Introduction and Purpose](#introduction-and-purpose)
- [Prerequisites](#prerequisites)
- [Installing Entware](#installing-entware)
- [Setting Up the Environment](#setting-up-the-environment)
- [Installing Necessary Packages](#installing-necessary-packages)
- [Configuring Moonraker, Mainsail, and Fluidd](#configuring-moonraker-mainsail-and-fluidd)
- [Running the Setup Script](#running-the-setup-script)
- [Troubleshooting Common Issues](#troubleshooting-common-issues)
- [Using PuTTY to SSH into Your Printer](#using-putty-to-ssh-into-your-printer)
- [Cloning the Repository and Running the Setup](#cloning-the-repository-and-running-the-setup)

## Introduction and Purpose

The Creality K1 and K1-Max 3D printers run on a restricted environment. This guide will help you unlock their potential by setting up Mainsail and Fluidd, which are web interfaces for controlling your 3D printer via Moonraker.

## Prerequisites

- Creality K1 or K1-Max 3D printer with default root access via SSH.
  - **Username:** `root`
  - **Password:** `creality_2023`
- A computer with SSH access to the printer.
- Basic knowledge of using the command line.

## Installing Entware

1. **Download and Install Entware:**
   - SSH into your Creality K1 or K1-Max printer (see below how to do it with PuTTY).
   - Run the following commands to install Entware:

     ```sh
     cd /tmp
     ```
     ```sh
     rm -f generic.sh  # Remove existing file if it exists
     ```
     ```sh
     wget http://bin.entware.net/mipselsf-k3.4/installer/generic.sh
     ```
     ```sh
     sh generic.sh
     ```

## Setting Up the Environment

1. **Create Required Directories:**
   ```sh
   mkdir -p /usr/data/packages/python /usr/data/packages/ipk
   ```

2. **Ensure Proper Directory Structure:**
   Before running the installation scripts, make sure you have the following directory structure:
   ```
   /usr/data/
   ├── creality-k1-setup/
   │   ├── scripts/
   │   │   ├── install_moonraker.sh
   │   │   ├── setup_nginx.sh
   │   │   └── verify_packages.sh
   │   ├── config.sh
   │   └── install.sh
   ├── packages/
   │   ├── python/
   │   └── ipk/
   ```

## Installing Necessary Packages

You'll install all the necessary packages using the provided scripts and package lists:

1. **Install sudo and fix permissions:**
   ```sh
   opkg install sudo
   chown root:root /opt/bin/sudo
   chmod 4755 /opt/bin/sudo
   chown root:root /opt/lib/sudo/sudoers.so
   chmod 644 /opt/lib/sudo/sudoers.so
   ```

2. **Create sudo configuration:**
   ```sh
   mkdir -p /opt/etc
   cat > /opt/etc/sudoers << 'EOF'
   # /etc/sudoers
   #
   # This file MUST be edited with the 'visudo' command as root.
   #
   # See the man page for details on how to write a sudoers file.
   #

   Defaults        env_reset

   # Host alias specification

   # User alias specification

   # Cmnd alias specification

   # User privilege specification
   root    ALL=(ALL) ALL
   moonrakeruser ALL=(ALL) NOPASSWD: ALL

   # Allow members of group sudo to execute any command
   %sudo   ALL=(ALL) ALL
   EOF
   ```

3. **Set proper permissions for sudoers file:**
   ```sh
   chown root:root /opt/etc/sudoers
   chmod 440 /opt/etc/sudoers
   ```

## Configuring Moonraker, Mainsail, and Fluidd

Configuration files and further instructions will be handled by the setup scripts.

## Running the Setup Script

After setting up the prerequisites and installing Entware, proceed with the steps below.

1. **Create and Check User:**
   ```sh
   adduser -h /usr/data/home/moonrakeruser -D moonrakeruser
   chown -R moonrakeruser:moonrakeruser /usr/data
   ```

2. **Make Scripts Executable:**
   ```sh
   chmod +x /usr/data/creality-k1-setup/install.sh
   chmod +x /usr/data/creality-k1-setup/scripts/install_moonraker.sh
   chmod +x /usr/data/creality-k1-setup/scripts/setup_nginx.sh
   chmod +x /usr/data/creality-k1-setup/scripts/verify_packages.sh
   ```

3. **Run the Install Script:**
   ```sh
   cd /usr/data/creality-k1-setup
   ./install.sh
   ```

## Troubleshooting Common Issues

### Sudo Permissions Issues
If you encounter errors like:
```
sudo: error in /opt/etc/sudo.conf, line 0 while loading plugin "sudoers_policy"
sudo: /opt/lib/sudo/sudoers.so must be owned by uid 0
sudo: fatal error, unable to load plugins
```

Fix with:
```sh
chown root:root /opt/lib/sudo/sudoers.so
chmod 644 /opt/lib/sudo/sudoers.so
```

### Missing Script Files
If you see errors about missing script files:
```
chmod: /usr/data/creality-k1-setup/scripts/install_moonraker.sh: No such file or directory
chmod: /usr/data/creality-k1-setup/scripts/setup_nginx.sh: No such file or directory
```

Ensure the scripts directory exists and files are present:
```sh
mkdir -p /usr/data/creality-k1-setup/scripts
# Copy the script files to this directory as shown in the repository
chmod +x /usr/data/creality-k1-setup/scripts/*.sh
```

### Wget Issues
If wget has problems with existing files:
```
wget: can't open 'generic.sh': File exists
```

Remove the existing file first:
```sh
rm -f generic.sh
```

## Using PuTTY to SSH into Your Printer

### Download and Install PuTTY:

1. Go to the [PuTTY download page](https://www.putty.org/).
2. Download the appropriate version for your operating system.
3. Install PuTTY on your computer.

### Using PuTTY to SSH:

1. Open PuTTY.
2. In the "Host Name (or IP address)" field, enter `root@<ip address>` (replace `<ip address>` with the IP address of your printer).
3. Click "Open."
4. A terminal window will open asking for a password. Type `creality_2023` (note that the password will not be displayed as you type).
5. Press Enter.

## Cloning the Repository and Running the Setup

### Clone the Repository:

1. SSH into your printer as described above.
2. Navigate to the `/usr/data` directory:

    ```sh
    cd /usr/data
    ```

3. Clone the repository:

    ```sh
    git clone https://github.com/Mariusjuvet1/creality-k1-setup.git
    ```

By following these instructions, you will set up a fully functional environment with Mainsail and Fluidd on your Creality K1 or K1-Max 3D printer.
