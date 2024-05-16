#!/bin/sh

# Check if connected to the internet
ping -c 1 google.com > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "No internet connection. Please download the necessary packages manually."
  exit 1
fi

# Install IPK packages using Entware
echo "Installing IPK packages..."
while read -r package; do
  opkg install "$package"
done < ipk-packages.txt

# Install Python packages
echo "Installing Python packages..."
pip3 install --no-index --find-links=/usr/data/packages -r requirements.txt

# Install Nginx
echo "Installing Nginx..."
opkg install nginx

# Install Mainsail
echo "Installing Mainsail..."
mkdir -p /opt/mainsail
cd /opt/mainsail
wget https://github.com/meteyou/mainsail/releases/latest/download/mainsail.zip
unzip mainsail.zip
rm mainsail.zip

# Install Moonraker
echo "Installing Moonraker..."
cd /opt
git clone https://github.com/Arksine/moonraker.git
cd moonraker
./scripts/install-moonraker.sh

# Install Fluidd
echo "Installing Fluidd..."
mkdir -p /opt/fluidd
cd /opt/fluidd
wget https://github.com/cadriel/fluidd/releases/latest/download/fluidd.zip
unzip fluidd.zip
rm fluidd.zip

# Configure Nginx for Mainsail and Fluidd
echo "Configuring Nginx..."
cat <<EOF > /etc/nginx/nginx.conf
server {
    listen 80;
    server_name _;

    location / {
        root /opt/mainsail;
        try_files \$uri \$uri/ /index.html;
    }
}

server {
    listen 8888;
    server_name _;

    location / {
        root /opt/fluidd;
        try_files \$uri \$uri/ /index.html;
    }

    location /moonraker {
        proxy_pass http://localhost:7125;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

# Restart Nginx
echo "Restarting Nginx..."
/etc/init.d/nginx restart

# Start Moonraker
echo "Starting Moonraker..."
systemctl start moonraker
systemctl enable moonraker

echo "Installation complete! Mainsail is running on port 80 and Fluidd on port 8888."

