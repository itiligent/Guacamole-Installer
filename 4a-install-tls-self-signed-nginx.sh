#!/bin/bash
#######################################################################################################################
# Add self signed TLS certificates to Guacamole with Nginx reverse proxy
# For Ubuntu / Debian / Raspbian
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
echo -e "${LGREEN}Setting up self signed TLS certificates for Nginx...${GREY}"
echo

# Setup script cmd line arguments for proxy site and certificate days
TLSNAME=$1
TLSDAYS=$2

# Set default certificate file destinations.
DIR_SSL_CERT="/etc/nginx/ssl/cert"
DIR_SSL_KEY="/etc/nginx/ssl/private"

# Make directories to place TLS Certificate if they don't exist
if [[ ! -d $DIR_SSL_KEY ]]; then
    sudo mkdir -p $DIR_SSL_KEY
fi

if [[ ! -d $DIR_SSL_CERT ]]; then
    sudo mkdir -p $DIR_SSL_CERT
fi

# Discover IPv4 interface
DEFAULT_IP=$(ip addr show $(ip route | awk '/default/ { print $5 }') | grep "inet" | head -n 1 | awk '/inet/ {print $2}' | cut -d'/' -f1)

echo -e "${GREY}New self signed TLS certificate attributes are shown below...${DGREY}"
# Display the new TLS cert parameters.
cat <<EOF | tee $TMP_DIR/cert_attributes.txt
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
CN                  = $TLSNAME

[v3_req]
keyUsage            = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage    = serverAuth, clientAuth, codeSigning, emailProtection
subjectAltName      = @alt_names

[alt_names]
DNS.1               = $TLSNAME
IP.1                = $DEFAULT_IP
EOF

echo
echo "{$GREY}Creating a new Nginx TLS Certificate..."
openssl req -x509 -nodes -newkey rsa:2048 -keyout $TLSNAME.key -out $TLSNAME.crt -days $TLSDAYS -config $TMP_DIR/cert_attributes.txt
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Place TLS Certificate into the defined application path
sudo cp $TLSNAME.key $DIR_SSL_KEY/$TLSNAME.key
sudo cp $TLSNAME.crt $DIR_SSL_CERT/$TLSNAME.crt

# Create a PFX formatted key for easier import to Windows hosts and change permissions to enable copying elsewhere
echo -e "${GREY}Converting client certificates for Windows & Linux...${GREY}"
sudo openssl pkcs12 -export -out $TLSNAME.pfx -inkey $TLSNAME.key -in $TLSNAME.crt -password pass:1234
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Change of permissions so certs can be copied via WinSCP.
sudo chown $SUDO_USER:root $TLSNAME.pfx 
sudo chown $SUDO_USER:root $TLSNAME.crt
sudo chown $SUDO_USER:root $TLSNAME.key

# Backup the current Nginx config before update
echo -e "${GREY}Backing up previous Nginx proxy to $DOWNLOAD_DIR/$TLSNAME-nginx.bak"
cp /etc/nginx/sites-enabled/${TLSNAME} $DOWNLOAD_DIR/${TLSNAME}-nginx.bak
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Update Nginx config to accept the new certificates
echo -e "${GREY}Configuring Nginx proxy to use the self signed TLS certificate and setting up HTTP redirect...${DGREY}"
cat <<EOF | tee /etc/nginx/sites-available/$TLSNAME
server {
    #listen 80 default_server;
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    server_name $TLSNAME;
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
    ssl_certificate      /etc/nginx/ssl/cert/$TLSNAME.crt;
    ssl_certificate_key  /etc/nginx/ssl/private/$TLSNAME.key;
    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout  5m;
}
server {
    return 301 https://\$host\$request_uri;
    listen 80 default_server;
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    server_name $TLSNAME;
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

# Update general ufw rules so force traffic via reverse proxy. Only Nginx and SSH will be available over the network.
echo -e "${GREY}Updating firewall rules to allow only SSH and tcp 80/443..."
sudo ufw default allow outgoing >/dev/null 2>&1
sudo ufw default deny incoming >/dev/null 2>&1
sudo ufw allow OpenSSH >/dev/null 2>&1
sudo ufw allow 80/tcp >/dev/null 2>&1
sudo ufw allow 443/tcp >/dev/null 2>&1
echo "y" | sudo ufw enable >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

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
    echo
fi

# Hack to assist with displaying "$" symbols and " ' quotes in a (cut/paste-able) bash screen output format
SHOWASTEXT1='$mypwd'
SHOWASTEXT2='"Cert:\LocalMachine\Root"'

printf "${GREY}+-------------------------------------------------------------------------------------------------------------
${LGREEN}+ WINDOWS CLIENT SELF SIGNED TLS BROWSER CONFIG - SAVE THIS BEFORE CONTINUING!${GREY}
+
+ 1. In ${DOWNLOAD_DIR} is a Windows version of the new certificate ${LYELLOW}$TLSNAME.pfx${GREY}
+ 2. Import this PFX file into your Windows client with the below Powershell commands (as Administrator):
\n"
echo -e "${SHOWASTEXT1} = ConvertTo-SecureString -String "1234" -Force -AsPlainText"
echo -e "Import-pfxCertificate -FilePath $TLSNAME.pfx -Password "${SHOWASTEXT1}" -CertStoreLocation "${SHOWASTEXT2}""
printf "${GREY}+-------------------------------------------------------------------------------------------------------------
${LGREEN}+ LINUX CLIENT SELF SIGNED TLS BROWSER CONFIG - SAVE THIS BEFORE CONTINUING!${GREY}
+
+ 1. In ${DOWNLOAD_DIR} is a new Linux native OpenSSL certificate ${LYELLOW}$TLSNAME.crt${GREY}
+ 2. Import the CRT file into your Linux client certificate store with the below command:
\n"
echo -e "(If certutil is not installed, run apt-get install libnss3-tools)"
echo -e "mkdir -p $HOME/.pki/nssdb && certutil -d $HOME/.pki/nssdb -N"
echo -e "certutil -d sql:$HOME/.pki/nssdb -A -t "CT,C,c" -n $TLSNAME -i $TLSNAME.crt"
printf "+-------------------------------------------------------------------------------------------------------------\n"
echo -e "${LYELLOW}The above TLS browser config instructions are saved in ${LGREEN}$LOG_LOCATION${GREY}"

# Done
echo -e ${NC}
