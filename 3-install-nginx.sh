#!/bin/bash
#######################################################################################################################
# Add Nginx reverse proxy fromt end to default Guacamole install
# For Ubuntu / Debian / Raspian
# 3 of 4
# David Harrop
# August 2023
#######################################################################################################################

# Install Nginx
sudo apt-get install nginx -y &>> ${LOG_LOCATION}

# Configure /etc/nginx/sites-available/(local dns site name)
cat >/etc/nginx/sites-available/$PROXY_SITE <<EOL
server {
    listen 80 default_server;
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
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
EOL

echo
echo -e "${GREY}Configuring Nginx proxy to connect to Guacamole's Apache front end..."
if [ $? -ne 0 ]; then
	echo -e "${RED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
	else
	echo -e "${LGREEN}OK${GREY}"
	echo
fi

# Symlink from sites-available to sites-enabled
ln -s /etc/nginx/sites-available/$PROXY_SITE /etc/nginx/sites-enabled/

# Make sure default Nginx site is unlinked
unlink /etc/nginx/sites-enabled/default

# Do mandatory Nginx tweaks for logging actual client IPs through a proxy IP of 127.0.0.1 - DO NOT CHANGE COMMAND FORMATING!
sudo sed -i '/pattern="%h %l %u %t &quot;%r&quot; %s %b"/a        \        <!-- Allow host IP to pass through to guacamole.-->\n        <Valve className="org.apache.catalina.valves.RemoteIpValve"\n               internalProxies="127\.0\.0\.1|0:0:0:0:0:0:0:1"\n               remoteIpHeader="x-forwarded-for"\n               remoteIpProxiesHeader="x-forwarded-by"\n               protocolHeader="x-forwarded-proto" />' /etc/$TOMCAT_VERSION/server.xml
echo -e "${GREY}Configuring Apache Tomcat's internal proxy valve to support proxy client IP4 & IPv6 address passthough for correct logging and ACL support...${GREY}"
if [ $? -ne 0 ]; then
	echo -e "${RED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
	else
	echo -e "${LGREEN}OK${GREY}"
	echo
fi

# Allow large file transfers through Nginx
sudo sed -i '/client_max_body_size/d' /etc/nginx/nginx.conf # remove this line if it already exists to prevent duplicates
sudo sed -i "/Basic Settings/a \        client_max_body_size 100000000M;" /etc/nginx/nginx.conf # Add the larger file transfer size
echo -e "${GREY}Boosting Nginx's 'maximum body size' parameter to support file transfers > 100 TB through the proxy...${GREY}"
if [ $? -ne 0 ]; then
	echo -e "${RED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
	else
	echo -e "${LGREEN}OK${GREY}"
	echo
fi

# Bind guacd to localhost and force all Guacamole connections via reverse proxy
echo -e "${GREY}Binding guacd to 127.0.0.1 port 4822..."
cat > /etc/guacamole/guacd.conf <<- "EOF"
[server]
bind_host = 127.0.0.1
bind_port = 4822
EOF
if [ $? -ne 0 ]; then
	echo -e "${RED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
else
	echo -e "${LGREEN}OK${GREY}"
	echo
fi

# Update general ufw rules so force traffic via reverse proxy. Only Nginx and SSH will be available over the network.
echo -e "${GREY}Updating firewall rules to allow only SSH and tcp 80/443..."
sudo ufw default allow outgoing &>> ${LOG_LOCATION}
sudo ufw default deny incoming &>> ${LOG_LOCATION}
sudo ufw delete allow 8080/tcp &>> ${LOG_LOCATION}
sudo ufw allow OpenSSH &>> ${LOG_LOCATION}
sudo ufw allow 80/tcp &>> ${LOG_LOCATION}
sudo ufw allow 443/tcp &>> ${LOG_LOCATION}
echo "y" | sudo ufw enable &>> ${LOG_LOCATION}
if [ $? -ne 0 ]; then
	echo -e "${RED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
	else
	echo -e "${LGREEN}OK${GREY}"
	echo
fi

# Reload everything
echo -e "${GREY}Restaring Guacamole & Ngnix..."
sudo systemctl restart $TOMCAT_VERSION &>> ${LOG_LOCATION}
sudo systemctl restart guacd &>> ${LOG_LOCATION}
sudo systemctl restart nginx &>> ${LOG_LOCATION}
if [ $? -ne 0 ]; then
	echo -e "${RED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
	else
	echo -e "${LGREEN}OK${GREY}"
	echo
fi

# Done
echo -e ${NC}
