#!/bin/bash
#######################################################################################################################
# Add self signed SSL certificates to Guacamole with Nginx reverse proxy
# For Ubuntu / Debian / Raspian
# 4a of 4
# David Harrop
# April 2023
#######################################################################################################################

# Prepare text output colours
GREY='\033[0;37m'
DGREY='\033[0;90m'
GREYB='\033[1;37m'
LRED='\033[0;91m'
LGREEN='\033[0;92m'
LYELLOW='\033[0;93m'
NC='\033[0m' #No Colour

echo
echo
echo -e "${LGREEN}Setting up self signed SSL certificates for Nginx...${GREY}"
echo

# Setup script cmd line arguments for proxy site and certificate days
SSLNAME=$1
SSLDAYS=$2

#######################################################################################################################
# If you wish to add/regenerate self signed SSL to a pre-existing Nginx install, this script can be adapted to be run 
# standalone. To run as standalone, simply un-comment this entire section and provide the desired variable 
# values to complete the reconfiguration of Nginx.

# Variable inputs
#TOMCAT_VERSION="tomcat9" # Not needed for general SSL install(if Guacamole not present, also comment the tomcat restart)
#DOWNLOAD_DIR=$(eval echo ~${SUDO_USER})
#LOG_LOCATION="${DOWNLOAD_DIR}/ssl_install.log"
#TMP_DIR=/tmp
#GUAC_URL=http://localhost:8080/guacamole/ # substitute for whatever url that nginx is proxying
#CERT_COUNTRY="AU" # must be two letter code!
#CERT_STATE="Victoria"
#CERT_LOCATION="Melbourne"
#CERT_ORG="Itiligent"
#CERT_OU="I.T. dept"
#PROXY_SITE=$SSLNAME

# To run manually or to regenerate SSL certificates, this script must be run in the current user enviroment [-E switch]
# Be aware that runing this script just as sudo will save certs to sudo's home path with incorrect permissions, 
# plus the custom certifcate install instructions shown after running will be invalid. 

# e.g. sudo -E ./4a-install-ssl-self-signed-nginx.sh proxy-site-name 3650

#######################################################################################################################

# Discover IPv4 interface
echo -e "${GREY}Discovering the default route interface and Proxy DNS name to bind with the new SSL certificate..."
DEFAULT_IP=$(ip addr show $(ip route | awk '/default/ { print $5 }') | grep "inet" | head -n 1 | awk '/inet/ {print $2}' | cut -d'/' -f1)
if [ $? -ne 0 ]; then
	echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
	else
	echo -e "${LGREEN}OK${GREY}"
	echo
fi

echo -e "${GREY}New self signed SSL certificate attributes are shown below...${DGREY}"
# Display the new SSL cert parameters. Prompt for change if required
cat <<EOF | tee -a $TMP_DIR/cert_attributes.txt
[req]
distinguished_name  = req_distinguished_name
x509_extensions     = v3_req
prompt              = no
string_mask         = utf8only

[req_distinguished_name]
C                   = $CERT_COUNTRY
ST                  = $CERT_STATE
L                   = $CERT_LOCATION
O                   = $CERT_ORG
OU                  = $CERT_OU
CN                  = $PROXY_SITE

[v3_req]
keyUsage            = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage    = serverAuth, clientAuth, codeSigning, emailProtection
subjectAltName      = @alt_names

[alt_names]
DNS.1               = $PROXY_SITE
IP.1                = $DEFAULT_IP
EOF
# Add IP.2 & IP.3 into the above cat <<EOF as needed.
#IP.2                = $IP3
#IP.3                = $IP3
# Additional DNS names can also be manually added into the above cat <<EOF as needed.
#DNS.2               =
#DNS.3               =

# Set default certificate file destinations. These can be adapted for any other SSL application.
DIR_SSL_CERT="/etc/nginx/ssl/cert"
DIR_SSL_KEY="/etc/nginx/ssl/private"

# Make directories to place SSL Certificate if they don't exist
if [[ ! -d $DIR_SSL_KEY ]]; then
	sudo mkdir -p $DIR_SSL_KEY
fi

if [[ ! -d $DIR_SSL_CERT ]]; then
	sudo mkdir -p $DIR_SSL_CERT
fi

if [[ $SSLDAYS == "" ]]; then
$SSLDAYS = 3650
fi

echo
echo "{$GREY}Creating a new Nginx SSL Certificate ..."
openssl req -x509 -nodes -newkey rsa:2048 -keyout $SSLNAME.key -out $SSLNAME.crt -days $SSLDAYS -config $TMP_DIR/cert_attributes.txt
if [ $? -ne 0 ]; then
	echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
	else
	echo -e "${LGREEN}OK${GREY}"
	echo
fi

# Place SSL Certificate within defined path
	sudo cp $SSLNAME.key $DIR_SSL_KEY/$SSLNAME.key
	sudo cp $SSLNAME.crt $DIR_SSL_CERT/$SSLNAME.crt

# Create a PFX formatted key for easier import to Windows hosts and change permissions to enable copying elsewhere
	echo -e "${GREY}Creating client certificates for Windows & Linux...${GREY}"
	sudo openssl pkcs12 -export -out $SSLNAME.pfx -inkey $SSLNAME.key -in $SSLNAME.crt -password pass:1234
	sudo chmod 0774 $SSLNAME.pfx
if [ $? -ne 0 ]; then
	echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
	else
	echo -e "${LGREEN}OK${GREY}"
	echo
fi

# Backup the current Nginx config before update
echo -e "${GREY}Backing up previous Nginx proxy to $DOWNLOAD_DIR/$PROXY_SITE-nginx.bak"
cp /etc/nginx/sites-enabled/${PROXY_SITE} $DOWNLOAD_DIR/${PROXY_SITE}-nginx.bak
if [ $? -ne 0 ]; then
	echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
	else
	echo -e "${LGREEN}OK${GREY}"
	echo
fi

# Update Nginx config to accept the new certificates
echo -e "${GREY}Configuring Nginx proxy to use self signed SSL certificates and setting up automatic HTTP to HTTPS redirect...${DGREY}"
#cat > /etc/nginx/sites-available/$PROXY_SITE <<EOL | > /dev/null
cat <<EOF | tee /etc/nginx/sites-available/$PROXY_SITE
server {
    #listen 80 default_server;
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
    listen 443 ssl;
    ssl_certificate      /etc/nginx/ssl/cert/$SSLNAME.crt;
    ssl_certificate_key  /etc/nginx/ssl/private/$SSLNAME.key;
    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout  5m;
}
server {
    return 301 https://\$host\$request_uri;
    listen 80 default_server;
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
EOF
if [ $? -ne 0 ]; then
	echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
	else
	echo -e "${LGREEN}OK${GREY}"
	echo
fi

# Hack to assist with displaying "$" symbols and " ' quotes in a (cut/pasteable) bash screen output format for Nginx configs
SHOWASTEXT1='$mypwd'
SHOWASTEXT2='"Cert:\LocalMachine\Root"'

printf "${GREY}+-------------------------------------------------------------------------------------------------------------
${LGREEN}+ WINDOWS CLIENT SELF SIGNED SSL BROWSER CONFIG - SAVE THIS BEFORE CONTINUING!${GREY}
+
+ 1. In ${DOWNLOAD_DIR} is a new Windows friendly version of the new certificate ${LYELLOW}$SSLNAME.pfx${GREY}
+ 2. Copy this .pfx file to a location accessible by Windows.
+ 3. Import the PFX file into your Windows client with the below Powershell commands (as Administrator):
\n"
echo -e "${SHOWASTEXT1} = ConvertTo-SecureString -String "1234" -Force -AsPlainText"
echo -e "Import-pfxCertificate -FilePath $SSLNAME.pfx -Password "${SHOWASTEXT1}" -CertStoreLocation "${SHOWASTEXT2}""
echo -e "(Clear your browser cache and restart your browser to test.)"
printf "${GREY}+-------------------------------------------------------------------------------------------------------------
${LGREEN}+ LINUX CLIENT SELF SIGNED SSL BROWSER CONFIG - SAVE THIS BEFORE CONTINUING!${GREY}
+
+ 1. In ${DOWNLOAD_DIR} is a new Linux native OpenSSL certificate ${LYELLOW}$SSLNAME.crt${GREY}
+ 2. Copy this file to a location accessible by Linux.
+ 3. Import the CRT file into your Linux client certificate store with the below command (as sudo):
\n"
echo -e "certutil -d sql:$HOME/.pki/nssdb -A -t "CT,C,c" -n $SSLNAME -i $SSLNAME.crt"
echo -e "(If certutil is not installed, run apt-get install libnss3-tools)"
printf "+-------------------------------------------------------------------------------------------------------------\n"
echo
echo -e "${LYELLOW}The above SSL browser config instructions are saved in ${LGREEN}$LOG_LOCATION${GREY}"
echo

# Reload everything
echo -e "${GREY}Restaring Guacamole & Ngnix..."
sudo systemctl restart $TOMCAT_VERSION
sudo systemctl restart guacd
sudo systemctl restart nginx
if [ $? -ne 0 ]; then
	echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
else
	echo -e "${LGREEN}OK${GREY}"
fi

# Done
echo -e ${NC}
