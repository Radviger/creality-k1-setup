# Creality K1 and K1-Max Setup for Mainsail and Fluidd

This guide will help you install Mainsail and Fluidd on your Creality K1 or K1-Max 3D printer. These are powerful web interfaces that will give you more control over your printer.

## Quick Start Guide

### Step 1: SSH into your printer
Use PuTTY on Windows, or Terminal on Mac/Linux to connect to your printer:
- **Address**: Your printer's IP address
- **Username**: `root`
- **Password**: `creality_2023`

### Step 2: Install Entware
Copy and paste these commands one by one:

```
cd /tmp
rm -f generic.sh
wget http://bin.entware.net/mipselsf-k3.4/installer/generic.sh
sh generic.sh
```

### Step 3: Clone the setup repository

```
cd /usr/data
git clone https://github.com/Mariusjuvet1/creality-k1-setup.git
chmod +x /usr/data/creality-k1-setup/install.sh
chmod +x /usr/data/creality-k1-setup/scripts/*.sh
```

### Step 4: Run the installation script

```
cd /usr/data/creality-k1-setup
./install.sh
```

Wait for the installation to complete - this might take several minutes.

### Step 5: Access your new interfaces

After installation is complete, you can access:
- Mainsail: `http://your_printer_ip/mainsail`
- Fluidd: `http://your_printer_ip/fluidd`

## Troubleshooting

If you encounter issues, try these solutions:

### "File exists" errors:
When you see: `wget: can't open 'generic.sh': File exists`
```
rm -f generic.sh
```

### Missing script files:
Try running:
```
mkdir -p /usr/data/creality-k1-setup/scripts
chmod +x /usr/data/creality-k1-setup/scripts/*.sh
```

### Sudo permission errors:
If you see errors about sudo permissions, run:
```
chown root:root /opt/bin/sudo
chmod 4755 /opt/bin/sudo
chown root:root /opt/lib/sudo/sudoers.so
chmod 644 /opt/lib/sudo/sudoers.so
```

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

If you encounter issues not covered here, please open an issue on the GitHub repository with a description of your problem.
