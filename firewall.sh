#! /bin/bash

set -e

# runs on first login to set up and save firewall rules

SSH_PORT=REPLACE_ME

# read -p "$(echo -e "\e[32mWelcome! The last thing we need to do is set up and save firewall rules. Do you want to do this now (y/n)?\e[0m ")" yn

# if [[ ! $yn =~ ^[Yy]$ ]]; then
#   echo "Goodbye. This script will run again next time you log in."
#   exit
# fi

# Install UFW if not already installed
# sudo apt update
# sudo apt install ufw -y

# Default deny incoming and allow outgoing
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow all traffic on localhost interface
# sudo ufw allow from 127.0.0.1 to 127.0.0.1 comment 'Allow all localhost traffic'

# Allow SSH, HTTP, and HTTPS
sudo ufw allow $SSH_PORT/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# Rate limiting for SSH to prevent brute force attacks
# sudo ufw limit $SSH_PORT/tcp comment 'Rate limit SSH'

# Protect against port scanning
sudo ufw deny out to any port 111 comment 'Block outgoing portmapper'
sudo ufw deny out to any port 135 comment 'Block outgoing RPC'

# Log all denied packets for troubleshooting
# sudo ufw logging on

# Enable UFW
sudo ufw enable

# Install ufw-docker
sudo wget -O /usr/local/bin/ufw-docker \
  https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker
sudo chmod +x /usr/local/bin/ufw-docker
sudo ufw-docker install -y
sudo ufw route allow proto tcp from any to any port 80
sudo ufw route allow proto tcp from any to any port 443
sudo ufw route allow proto tcp from any to any port "$SSH_PORT"
sudo systemctl restart ufw

echo -e "\n\e[32mFirewall configured with UFW 👍. Your allowed ports are: $SSH_PORT (SSH), 80 (HTTP), and 443 (HTTPS).\e[0m\n"

rm ~/firewall.sh
