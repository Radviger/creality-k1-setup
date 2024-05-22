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
- [Conclusion and Troubleshooting](#conclusion-and-troubleshooting)
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
     wget http://bin.entware.net/mipselsf-k3.4/installer/generic.sh
     sh generic.sh
     ```

## Setting Up the Environment

Follow the steps below to set up the environment for Mainsail and Fluidd.

## Installing Necessary Packages

You'll install all the necessary packages using the provided scripts and package lists.

## Configuring Moonraker, Mainsail, and Fluidd

Configuration files and further instructions will be handled by the setup scripts.

## Running the Setup Script

After setting up the prerequisites and installing Entware, proceed with the steps below.

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
    git clone https://github.com/your-repo/creality-k1-setup.git
    ```

### Set Permissions and Run the Install Script:

1. Navigate to the cloned repository:

    ```sh
    cd creality-k1-setup
    ```

2. Make the install script executable:

    ```sh
    chmod +x ./install.sh
    ```

3. Run the install script:

    ```sh
    ./install.sh
    ```

## Conclusion and Troubleshooting

Follow the above steps to set up Mainsail and Fluidd on your Creality K1 or K1-Max. If you encounter any issues, ensure all steps were followed correctly and refer to the repository for updates or additional troubleshooting steps. If you need to remove the setup directory, run the following commands:

1. Navigate to the `/usr/data` directory:

    ```sh
    cd /usr/data
    ```

2. Remove the setup directory:

    ```sh
    rm -rf creality-k1-setup/
    ```

By following these instructions, you will set up a fully functional environment with Mainsail and Fluidd on your Creality K1 or K1-Max 3D printer.
