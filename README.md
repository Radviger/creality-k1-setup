# Creality K1 and K1-Max Setup for Mainsail and Fluidd

A simple guide to install Mainsail and Fluidd on your Creality K1 or K1-Max 3D printer.

## Quick Installation (Recommended)

1. **Connect to your printer**

   Connect to your printer using SSH:
   - Username: `root`
   - Password: `creality_2023`

2. **Run this single command**

   ```
   wget -O - https://raw.githubusercontent.com/Mariusjuvet1/creality-k1-setup/main/easy_install.sh | sh
   ```

   That's it! The script will handle everything else.

3. **Access your new interfaces**

   When installation completes, open these in your browser:
   - Mainsail: `http://your_printer_ip/mainsail`
   - Fluidd: `http://your_printer_ip/fluidd`

## How to Connect to Your Printer

### Finding Your Printer's IP Address

Look on your printer's touchscreen:
1. Go to **Settings**
2. Tap **Network Settings**
3. Note the IP address shown

### Connecting with SSH

#### Windows Users
1. Download [PuTTY](https://www.putty.org/)
2. Open PuTTY
3. In "Host Name" field, enter: `root@YOUR_PRINTER_IP`
4. Click "Open"
5. Enter password: `creality_2023`

#### Mac/Linux Users
Open Terminal and type:
```
ssh root@YOUR_PRINTER_IP
```
Enter password: `creality_2023`

## Need Help?

If you have problems, check our [Troubleshooting Guide](https://github.com/Mariusjuvet1/creality-k1-setup/blob/main/Troubleshooting%20Guide%20for%20Creality%20K1%20and%20K1-Max%20Setup).