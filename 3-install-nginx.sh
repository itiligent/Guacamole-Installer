#!/bin/bash
#######################################################################################################################
# Add Nginx reverse proxy front end to default Guacamole install
# For Ubuntu / Debian / Raspbian
# 3 of 4
# David Harrop
# August 2023
#######################################################################################################################

# If run as standalone and not from the main installer script, check the below variables are correct.
# To run standalone: sudo -E ./3-install-nginx.sh

# Prepare text output colours
GREY='\033[0;37m'
DGREY='\033[0;90m'
GREYB='\033[1;37m'
LRED='\033[0;91m'
LGREEN='\033[0;92m'
LYELLOW='\033[0;93m'
NC='\033[0m' #No Colour

if ! [[ $(id -u) = 0 ]]; then
    echo
    echo -e "${LRED}Please run this script as sudo or root${NC}" 1>&2
    exit 1
fi

echo
echo
echo -e "${GREY}Installing Nginx..."
TOMCAT_VERSION=$(ls /etc/ | grep tomcat)
# Below variables are automatically updated by the 1-setup.sh script with the respective values given at install (manually update if blank)
PROXY_SITE=
INSTALL_LOG=
GUAC_URL=

# Install Nginx
spinner() {
  local pid=$1
  local delay=0.15
  local spinstr='|/-\'
  tput civis
  while ps -p $pid > /dev/null; do
    for i in $(seq 0 3); do
      tput sc
      printf "[%c]" "${spinstr:$i:1}"
      tput rc
      sleep $delay
    done
  done
  tput cnorm
  printf "       "
  tput rc
}
apt-get update -qq &> /dev/null && apt-get install nginx -qq -y &>>${INSTALL_LOG} &
command_pid=$!
spinner $command_pid
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

echo -e "${GREY}Configuring Nginx as a reverse proxy for Guacamole's Apache Tomcat front end...${DGREY}"
# Configure /etc/nginx/sites-available/(local dns site name)
cat <<EOF | tee /etc/nginx/sites-available/$PROXY_SITE
server {
    listen 80 default_server;
    server_name $GUAC_URL;
    location / {
        proxy_pass $GUAC_URL;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$http_connection;
        access_log off;
    }
}
EOF
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Force nginx to require tls1.2 and above
sed -i -e '/ssl_protocols/s/^/#/' /etc/nginx/nginx.conf
sed -i "/SSL Settings/a \        ssl_protocols TLSv1.2 TLSv1.3;" /etc/nginx/nginx.conf

# Symlink new reverse proxy site config from sites-available to sites-enabled
ln -s /etc/nginx/sites-available/$PROXY_SITE /etc/nginx/sites-enabled/

# Make sure the default Nginx site is unlinked
unlink /etc/nginx/sites-enabled/default

# Do mandatory Nginx tweaks for logging actual client IPs through a proxy IP of 127.0.0.1 - DO NOT CHANGE COMMAND FORMATTING!
echo -e "${GREY}Configuring Apache Tomcat valve for pass through of client IPs to Guacamole logs...${GREY}"
sed -i '/pattern="%h %l %u %t &quot;%r&quot; %s %b"/a        \        <!-- Allow host IP to pass through to guacamole.-->\n        <Valve className="org.apache.catalina.valves.RemoteIpValve"\n               internalProxies="127\.0\.0\.1|0:0:0:0:0:0:0:1"\n               remoteIpHeader="x-forwarded-for"\n               remoteIpProxiesHeader="x-forwarded-by"\n               protocolHeader="x-forwarded-proto" />' /etc/$TOMCAT_VERSION/server.xml
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Allow large file transfers through Nginx
sed -i '/client_max_body_size/d' /etc/nginx/nginx.conf  # remove this line if it already exists to prevent duplicates
sed -i "/Basic Settings/a \        client_max_body_size 1000000000M;" /etc/nginx/nginx.conf # Add larger file transfer size, should be enough!
echo -e "${GREY}Boosting Nginx's 'maximum body size' parameter to allow large file transfers...${GREY}"
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Update general ufw rules so force traffic via reverse proxy. Only Nginx and SSH will be available over the network.
echo -e "${GREY}Updating firewall rules to allow only SSH and tcp 80/443..."
ufw default allow outgoing >/dev/null 2>&1
ufw default deny incoming >/dev/null 2>&1
ufw allow OpenSSH >/dev/null 2>&1
ufw allow 80/tcp >/dev/null 2>&1
ufw delete allow 8080/tcp >/dev/null 2>&1
echo "y" | sudo ufw enable >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Reload everything
echo -e "${GREY}Restaring Guacamole & Ngnix..."
systemctl restart $TOMCAT_VERSION
systemctl restart guacd
systemctl restart nginx
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
fi

# Done
echo -e ${NC}
