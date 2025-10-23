#! /bin/bash

# exit on error
set -e

# clear screen
clear

# variables
GREEN="\e[32m"
CYAN="\e[36m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"
CUR_TIMEZONE=$(timedatectl show | grep zone | sed 's/Timezone=//g')
KOPIA_PASSWORD=$(tr </dev/urandom -dc A-Z-a-z-0-9 | head -c"${1:-10}")
ARCHITECTURE=$(dpkg --print-architecture)

# intro message
echo -e "${GREEN}Welcome! This script should be run as the root user on a new Debian or Ubuntu server.${ENDCOLOR}\n"

# change timezone (works on debian / ubuntu / fedora)
read -r -p "$(echo -e "The system time zone is ${YELLOW}$CUR_TIMEZONE${ENDCOLOR}. Do you want to change it (y/n)?${ENDCOLOR} ")" yn
if [[ $yn =~ ^[Yy]$ ]]; then
  if command -v dpkg-reconfigure &>/dev/null; then
    dpkg-reconfigure tzdata
  else
    read -r -p "Enter time zone: " new_timezone
    if timedatectl set-timezone "$new_timezone"; then
      echo -e "${GREEN}Time zone has changed to: $new_timezone ${ENDCOLOR}"
    else
      echo -e "Run ${CYAN}timedatectl list-timezones${ENDCOLOR} to view all time zones"
      exit
    fi
  fi
fi

# create user account (works on debian / ubuntu / fedora)
read -r -p "$(echo -e "\nEnter username for the user to be created: ")" username
while [[ ! $username =~ ^[a-z][-a-z0-9]*$ ]]; do
  read -r -p "Invalid format. Enter username for the user to be created: " username
done
useradd -m -s /bin/bash "$username"
passwd "$username"
usermod -aG sudo "$username" || usermod -aG wheel "$username"

echo ""

# SSH port prompt
read -r -p "Which port do you want to use for SSH (not 6900-6905 please)? " ssh_port
while ((ssh_port < 1000 || ssh_port > 65000)); do
  read -r -p "Please use a number between 1000 and 65000: " ssh_port
done

# add ssh key
mkdir -p "/home/$username/.ssh"
# check if root has authorized_keys already
if [ -s /root/.ssh/authorized_keys ]; then
  cp /root/.ssh/authorized_keys "/home/$username/.ssh/authorized_keys"
else
  # if no keys, ask for key instead
  read -r -p "Please paste your public SSH key: " sshkey
  echo "$sshkey" >>"/home/$username/.ssh/authorized_keys"
fi

# add / update packages
echo -e "${CYAN}Updating system & packages...${ENDCOLOR}"

# kopia
curl -s https://kopia.io/signing-key | gpg --dearmor -o /usr/share/keyrings/kopia-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kopia-keyring.gpg] http://packages.kopia.io/apt/ stable main" | tee /etc/apt/sources.list.d/kopia.list

apt update && apt upgrade -y
apt install kopia rsync unattended-upgrades zsh bat eza ncdu apache2-utils clang ufw jq htop tmux -y

curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh

# eza
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list

# download fzf binary
wget -O /tmp/fzf.tar.gz "https://github.com/junegunn/fzf/releases/download/v0.60.3/fzf-0.60.3-linux_amd64.tar.gz"
tar -xzf /tmp/fzf.tar.gz -C /usr/bin/

# neovim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz

# docker stuff
echo -e "${CYAN}Setting up docker containers...${ENDCOLOR}"

# copy files
mkdir -p "/home/$username/server"
cp /tmp/cs/docker-compose.yml "/home/$username/server/docker-compose.yml"
cp /tmp/cs/firewall.sh "/home/$username/firewall.sh"
sed -i "s/REPLACE_ME/$ssh_port/" "/home/$username/firewall.sh"

# replace docker compose file with user input, and start
sed -i "s/CHANGE_TO_USERNAME/$username/" "/home/$username/server/docker-compose.yml"
docker compose -f "/home/$username/server/docker-compose.yml" up -d

# add user to docker users
usermod -aG docker "$username"

# set up automated jobs with systemd
sed -i "s/USERNAME/$username/" /tmp/cs/systemd/*.service
cp /tmp/cs/systemd/* /etc/systemd/system

systemctl daemon-reload
# Enable and start specific timers
systemctl start optimize-images.timer
systemctl enable optimize-images.timer >/dev/null 2>&1
systemctl start crowdsec-prune.timer
systemctl enable crowdsec-prune.timer >/dev/null 2>&1
# Enable and start all direct services (not triggered by timers)
# systemctl start kopia-server.service
# systemctl enable kopia-server.service >/dev/null 2>&1

# disable userland-proxy
jq '. + { "userland-proxy": false }' /etc/docker/daemon.json >/etc/docker/daemon.json.new && mv /etc/docker/daemon.json.new /etc/docker/daemon.json
# update SSH config
echo -e "\n${CYAN}Updating SSH config...${ENDCOLOR}"
{
  echo "Port $ssh_port"
  echo "PermitRootLogin prohibit-password"
  echo "PubkeyAuthentication yes"
  echo "PasswordAuthentication no"
  echo "X11Forwarding no"
  echo "PubkeyAcceptedAlgorithms +ssh-ed25519"
  echo "HostKeyAlgorithms +ssh-ed25519"
} >>/etc/ssh/sshd_config

echo -e "${CYAN}Restarting SSH daemon...${ENDCOLOR}\n"
systemctl restart sshd

# add boost cli
mkdir -p "/home/$username/.local/bin"
wget -O "/home/$username/.local/bin/boost.tar.gz" "https://github.com/BOOST-Creative/boost-server-cli/releases/download/v0.0.5/boost-server-cli_0.0.5_linux_$ARCHITECTURE.tar.gz"
tar -zxvf "/home/$username/.local/bin/boost.tar.gz" -C "/home/$username/.local/bin" boost
rm "/home/$username/.local/bin/boost.tar.gz"
# chown -R "$username:" "/home/$username/.local/bin"

# install zoxide
sudo -u "$username" curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sudo -u "$username" bash
ln -s "/home/$username/.local/bin/zoxide" "/usr/local/bin/zoxide"

# clone wordpress repo and copy config
mkdir -p "/etc/server-setup/mariadb"
mkdir -p "/etc/server-setup/valkey"
git clone https://github.com/BOOST-Creative/coolify-wordpress-8 "/tmp/wp" --depth=1
cp "/tmp/wp/config/valkey.conf" "/etc/server-setup/valkey/valkey.conf"
cp "/tmp/wp/config/my.cnf" "/etc/server-setup/mariadb/my.cnf"
cp "/tmp/wp/config/db-entrypoint.sh" "/etc/server-setup/mariadb/db-entrypoint.sh"
chmod +x "/etc/server-setup/mariadb/db-entrypoint.sh"

# proxy config
mkdir -p "/etc/server-setup/crowdsec"
cp "/tmp/cs/crowdsec/acquis.yaml" "/etc/server-setup/crowdsec/acquis.yaml"
echo "CROWDSEC_API_KEY=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32)" >"/home/$username/server/.env"

# configure zsh
cp /tmp/cs/.zshrc "/home/$username/.zshrc"
cp /tmp/cs/.zshrc_root "/root/.zshrc"
chsh -s /bin/zsh root
chsh -s /bin/zsh "$username"

# install starship
curl -sS https://starship.rs/install.sh | sh -s -- -y

# lazyvim
# mv ~/.config/nvim{,.bak}
git clone https://github.com/LazyVim/starter "/home/$username/.config/nvim" --depth=1

# Add welcome message to zshrc
# {
#   echo 'echo -e "\nFile Browser: \e[34mhttp://localhost:6900\n\e[0mKopia: \e[34mhttp://localhost:6901\e[0m (kopia:'"$KOPIA_PASSWORD"')\n"'
# } >>"/home/$username/.zshrc"

# permissions
chown -R "$username": "/home/$username"
# filebrowser uses nobody user bc that's what the wp container uses
mkdir -p "/home/$username/server/filebrowser"
chown -R nobody:nogroup "/home/$username/server/filebrowser"

# unattended-upgrades
echo -e "${CYAN}Setting up unattended-upgrades...${ENDCOLOR}"
dpkg-reconfigure --priority=low unattended-upgrades

# verify ssh key is correct
cat "/home/$username/.ssh/authorized_keys"
read -r -p "$(echo -e "\nIs the above SSH key(s) correct (y/n)? ")" ssh_correct
while [[ ! $ssh_correct =~ ^[Yy]$ ]]; do
  read -r -p "Please paste your public SSH key: " sshkey
  echo "$sshkey" >>"/home/$username/.ssh/authorized_keys"
  cat "/home/$username/.ssh/authorized_keys"
  read -r -p "$(echo -e "\nIs the above SSH key(s) correct (y/n)? ")" ssh_correct
done

# Success Message
echo -e "\n${GREEN}Setup complete 👍. Please log back in as $username on port $ssh_port.${ENDCOLOR}"
echo -e "${GREEN}Firewall script will run on first login.${ENDCOLOR}"
echo -e "${GREEN}Update your SSH config file with the info below${ENDCOLOR}"

echo -e "\n\033[1m🚨\e[31m ENABLE CLOUD FIREWALL NOW 🚨${ENDCOLOR}\n"

echo "Host $(hostname)"
echo "    HostName $(curl -s -4 ifconfig.me)"
echo "    Port $ssh_port"
echo "    User $username"
echo "    LocalForward 6901 127.0.0.1:6901"
echo "    LocalForward 6902 127.0.0.1:6902"
echo "    LocalForward 6903 127.0.0.1:6903"
echo "    LocalForward 8000 127.0.0.1:8000"
echo "    ServerAliveInterval 60"
echo -e "    ServerAliveCountMax 10\n"

reboot