# Creality K1 and K1-Max Setup for Mainsail and Fluidd

This guide will help you install Mainsail and Fluidd on your Creality K1 or K1-Max 3D printer with a single installation script.

## One-Command Installation

SSH into your printer and run this single command:

```bash
wget -O - https://raw.githubusercontent.com/Mariusjuvet1/creality-k1-setup/main/easy_install.sh | sh
```

That's it! The script will handle everything else automatically.

## Manual Installation Steps

If you prefer to install manually, follow these steps:

### Step 1: SSH into your printer
Use PuTTY on Windows, or Terminal on Mac/Linux to connect to your printer:
- **Address**: Your printer's IP address
- **Username**: `root`
- **Password**: `creality_2023`

### Step 2: Clone and run the setup
Copy and paste these commands:

```bash
cd /usr/data
mkdir -p creality-k1-setup
cd creality-k1-setup
wget https://raw.githubusercontent.com/Mariusjuvet1/creality-k1-setup/main/install.sh
wget https://raw.githubusercontent.com/Mariusjuvet1/creality-k1-setup/main/config.sh
mkdir -p scripts
cd scripts
wget https://raw.githubusercontent.com/Mariusjuvet1/creality-k1-setup/main/scripts/install_moonraker.sh
wget https://raw.githubusercontent.com/Mariusjuvet1/creality-k1-setup/main/scripts/setup_nginx.sh
wget https://raw.githubusercontent.com/Mariusjuvet1/creality-k1-setup/main/scripts/verify_packages.sh
cd ..
chmod +x install.sh
chmod +x scripts/*.sh
./install.sh
```

Wait for the installation to complete - this might take several minutes.

### Step 3: Access your new interfaces

After installation is complete, you can access:
- Mainsail: `http://your_printer_ip/mainsail`
- Fluidd: `http://your_printer_ip/fluidd`

## Finding your printer's IP address

From your printer's touchscreen:
1. Go to **Settings**
2. Tap **Network Settings**
3. Your IP address will be shown on this screen

## Using PuTTY to SSH (Windows users)

1. Download PuTTY from [putty.org](https://www.putty.org/)
2. Open PuTTY
3. In "Host Name" field, enter `root@<your_printer_ip>` (replace with your printer's IP)
4. Click "Open"
5. Enter password: `creality_2023` when prompted

## Need help?

If you encounter issues, please check our [Troubleshooting Guide](https://github.com/Mariusjuvet1/creality-k1-setup/blob/main/Troubleshooting%20Guide%20for%20Creality%20K1%20and%20K1-Max%20Setup) or open an issue on the GitHub repository.