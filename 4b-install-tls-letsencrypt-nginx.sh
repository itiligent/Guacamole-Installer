#!/bin/bash
#######################################################################################################################
# Add Let's Encrypt TLS Certificates to Guacamole with Nginx reverse proxy
# For Ubuntu / Debian / Raspbian
# 4b of 4
# David Harrop
# April 2023
#######################################################################################################################

# If run as standalone and not from the main installer script, check the below variables are correct.
# To run standalone: sudo -E ./4b-install-tls-letsencrypt-nginx.sh

# Prepare text output colours
GREY='\033[0;37m'
DGREY='\033[0;90m'
GREYB='\033[1;37m'
LRED='\033[0;91m'
LGREEN='\033[0;92m'
LYELLOW='\033[0;93m'
NC='\033[0m' #No Colour

TOMCAT_VERSION=$(ls /etc/ | grep tomcat)
# Below variables are automatically updated by the 1-setup.sh script with the respective values given at install (manually update if blank)
DOWNLOAD_DIR=
PROXY_SITE=
GUAC_URL=
LE_DNS_NAME=
LE_EMAIL=
INSTALL_LOG=

echo
echo
echo -e "${GREY}Installing Nginx & Lets Encrypt Certbot..."
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
apt-get update -qq &> /dev/null && apt-get install nginx certbot python3-certbot-nginx -qq -y &>>${INSTALL_LOG} &
command_pid=$!
spinner $command_pid
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Backup the current Nginx config
echo
echo -e "${GREY}Backing up previous Nginx proxy to $DOWNLOAD_DIR/$PROXY_SITE-nginx.bak"
cp /etc/nginx/sites-enabled/${PROXY_SITE} $DOWNLOAD_DIR/${PROXY_SITE}-nginx.bak
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Configure Nginx to accept the new certificates
echo -e "${GREY}Configuring Nginx proxy for Let's Encrypt TLS and setting up automatic HTTP redirect...${GREY}"
cat >/etc/nginx/sites-available/$PROXY_SITE <<EOL
server {
    listen 80 default_server;
    #listen [::]:80 default_server;
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    server_name $PROXY_SITE;
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
EOL
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Update general ufw rules to force traffic via reverse proxy. Only Nginx and SSH will be available over the network.
echo -e "${GREY}Updating firewall rules to allow only SSH and tcp 80/443..."
ufw default allow outgoing >/dev/null 2>&1
ufw default deny incoming >/dev/null 2>&1
ufw allow OpenSSH >/dev/null 2>&1
ufw allow 80/tcp >/dev/null 2>&1
ufw allow 443/tcp >/dev/null 2>&1
echo "y" | sudo ufw enable >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Reload the new Nginx config so as certbot can read the new config and update it
systemctl restart nginx

# Run certbot to create and associate certificates with current public IP (must have tcp 80 and 443 open to work!)
certbot --nginx -n -d $LE_DNS_NAME --email $LE_EMAIL --agree-tos --redirect --hsts
echo -e
echo -e "${GREY}Let's Encrypt successfully installed, but check for any errors above (DNS & firewall are the usual culprits).${GREY}"
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Select a random daily time to schedule a daily check for a Let's Encrypt certificate due to expire in next 30 days.
# If due to expire within a 30 day window, certbot will attempt to renew automatically each day.
echo -e "${GREY}Scheduling automatic certificate renewals for certificates with < 30 days till expiry.)${GREY}"
#Dump out the current crontab
crontab -l >cron_1
# Remove any previosly added certbot renewal entries
sed -i '/# certbot renew/d' cron_1
# Randomly choose a daily update schedule and append this to the cron schedule
HOUR=$(shuf -i 0-23 -n 1)
MINUTE=$(shuf -i 0-59 -n 1)
echo "${MINUTE} ${HOUR} * * * /usr/bin/certbot renew --quiet --pre-hook 'systemctl stop nginx' --post-hook 'systemctl start nginx'" >>cron_1
# Overwrite old cron settings and cleanup
crontab cron_1
rm cron_1
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Reload everything once again
echo -e "${GREY}Restarting Guacamole & Ngnix..."
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
