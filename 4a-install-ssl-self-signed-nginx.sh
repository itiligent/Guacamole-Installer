#!/bin/bash
#######################################################################################################################
# Add self signed SSL certificates to Guacamole with Nginx reverse proxy
# For Ubuntu / Debian / Raspian
# 4a of 4
# David Harrop
# April 2023
#######################################################################################################################

# To run manually and regenerate certificates, this script must be run in the current user enviroment [-E switch]
# to provide certifacate outputs correctly. Runing just as sudo will save certs to sudo's home path
# sudo -E ./4a-install-ssl-self-signed-nginx.sh [your-dns-name.local] [3650]

# Hack to assist with displaying "$" symbols and " ' quotes in a (cut/pasteable) bash screen output format for Nginx configs
SHOWASTEXT1='$mypwd'
SHOWASTEXT2='"Cert:\LocalMachine\Root"'

# Discover all IPv4 interfaces addresses to bind to new SSL certficates
echo
	echo -e "${GREY}Discovering the default route interface and DNS names to bind with the new SSL certificate..."
	# Dump interface info and copy this output to a temp file
	DUMP_IPS=$(ip -o addr show up primary scope global | while read -r num dev fam addr rest; do echo ${addr%/*}; done)
	echo $DUMP_IPS > $TMP_DIR/dump_ips.txt

	# Filter out anything but numerical characters, then add output to a temporary list
	grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" $TMP_DIR/dump_ips.txt > $TMP_DIR/ip_list.txt

	# Separate each row in the temporary ip_list.txt file and further split each single row into a separate new temp file for each individual IP address found
	sed -n '1p' $TMP_DIR/ip_list.txt > $TMP_DIR/1st_ip.txt
	#sed -n '2p' $TMP_DIR/ip_list.txt > $TMP_DIR/2nd_ip.txt # uncomment for 2nd interface
	#sed -n '3p' $TMP_DIR/ip_list.txt > $TMP_DIR/3rd_ip.txt # uncomment for 3rd interface etc

	# Assign each individual IP address temp file a discreet variable for use in the certificate parameters setup
	IP1=$(cat $TMP_DIR/1st_ip.txt)
	#IP2=$(cat $TMP_DIR/2nd_ip.txt) # uncomment for 2nd interface
	#IP3=$(cat $TMP_DIR/3rd_ip.txt) # uncomment for 3rd interface etc
if [ $? -ne 0 ]; then
	echo -e "${RED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
	else
	echo -e "${GREEN}OK${GREY}"
	echo
fi

echo
echo -e "${GREY}New self signed SSL certificate attributes are shown below...${GREY}"
echo -e "${DGREY}"

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
IP.1                = $IP1
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

# Setup SSL certificate variables
SSLNAME=$1
SSLDAYS=$2

if [[ $SSLDAYS == "" ]]; then
$SSLDAYS = 3650
fi

echo "Creating a new Certificate ..."
openssl req -x509 -nodes -newkey rsa:2048 -keyout $SSLNAME.key -out $SSLNAME.crt -days $SSLDAYS -config $TMP_DIR/cert_attributes.txt

# Make directories to place SSL Certificate if they don't exist
if [[ ! -d $DIR_SSL_KEY ]]; then
	sudo mkdir -p $DIR_SSL_KEY
fi

if [[ ! -d $DIR_SSL_CERT ]]; then
	sudo mkdir -p $DIR_SSL_CERT
fi

# Place SSL Certificate within defined path
	sudo cp $SSLNAME.key $DIR_SSL_KEY/$SSLNAME.key
	sudo cp $SSLNAME.crt $DIR_SSL_CERT/$SSLNAME.crt

# Create a PFX formatted key for easier import to Windows hosts and change permissions to enable copying elsewhere
	sudo openssl pkcs12 -export -out $SSLNAME.pfx -inkey $SSLNAME.key -in $SSLNAME.crt -password pass:1234
	sudo chmod 0774 $SSLNAME.pfx
	echo -e "${GREY}Creating a selection of self signed certificates for Nginx and Windows/Linux browser clients...${GREY}"
if [ $? -ne 0 ]; then
	echo -e "${RED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
	else
	echo -e "${GREEN}OK${GREY}"
	echo
fi

# Backup the current Nginx config before update
cp /etc/nginx/sites-enabled/${PROXY_SITE} $DOWNLOAD_DIR/${PROXY_SITE}-nginx.bak
echo -e "${GREY}Backing up previous Nginx proxy to $DOWNLOAD_DIR/$PROXY_SITE-nginx.bak"
if [ $? -ne 0 ]; then
	echo -e "${RED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
	else
	echo -e "${GREEN}OK${GREY}"
	echo
fi

# Update Nginx config to accept the new certificates
cat > /etc/nginx/sites-available/$PROXY_SITE <<EOL | > /dev/null
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
EOL

echo -e "${GREY}Configuring Nginx proxy to use self signed SSL certificates and setting up automatic HTTP to HTTPS redirect...${GREY}"
if [ $? -ne 0 ]; then
	echo -e "${RED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
	else
	echo -e "${GREEN}OK${GREY}"
	echo
fi

printf "${GREY}+-------------------------------------------------------------------------------------------------------------
${GREEN}+ WINDOWS CLIENT SELF SIGNED SSL BROWSER CONFIG - SAVE THIS BEFORE CONTINUING!${GREY}
+
+ 1. In ${DOWNLOAD_DIR} is a Windows friendly version of the new certificate ${LYELLOW}$SSLNAME.pfx${GREY}
+ 2. Copy this .pfx file to a location accessible by Windows.
+ 3. Import the PFX file into your Windows client with the below Powershell commands (as administrator):
\n"
echo -e "${SHOWASTEXT1} = ConvertTo-SecureString -String "1234" -Force -AsPlainText"
echo -e "Import-pfxCertificate -FilePath $SSLNAME.pfx -Password "${SHOWASTEXT1}" -CertStoreLocation "${SHOWASTEXT2}""
echo -e "(Clear your browser cache and restart your browser to test.)"
printf "${GREY}+-------------------------------------------------------------------------------------------------------------
${GREEN}+ LINUX CLIENT SELF SIGNED SSL BROWSER CONFIG - SAVE THIS BEFORE CONTINUING!${GREY}
+
+ 1. In In ${DOWNLOAD_DIR} is also the Linux native OpenSSL certificate ${LYELLOW}$SSLNAME.crt${GREY}
+ 2. Copy this file to a location accessible by Linux.
+ 3. Import the CRT file into your Linux client certificate store with the below command (as sudo):
\n"
echo -e "certutil -d sql:$HOME/.pki/nssdb -A -t "CT,C,c" -n $SSLNAME -i $SSLNAME.crt"
echo -e "(If certutil is not installed, run apt-get install libnss3-tools)"
printf "+-------------------------------------------------------------------------------------------------------------\n"
echo
echo -e "${LYELLOW}The above SSL browser config instructions are also saved in ${LGREEN}$LOG_LOCATION${GREY}"
echo

# Reload everything
echo -e "${GREY}Restaring Guacamole & Ngnix..."
sudo systemctl restart $TOMCAT_VERSION
sudo systemctl restart guacd
sudo systemctl restart nginx
if [ $? -ne 0 ]; then
	echo -e "${RED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
else
	echo -e "${LGREEN}OK${GREY}"
	echo
fi

# Done
echo -e ${NC}
