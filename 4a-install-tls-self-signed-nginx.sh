#!/bin/bash
#######################################################################################################################
# Add self-signed TLS certificates to Guacamole with Nginx reverse proxy
# For Ubuntu / Debian / Raspbian
# 4a of 4
# David Harrop
# April 2023
#######################################################################################################################

# This script can be run multiple times to either install or update TLS settings and certificates.

# Change the name of the site or add/renew TLS certs by specifying command line arguments [dns.name] [cert-lifetime] [IP]
# e.g. sudo -E ./4a-install-tls-self-signed-nginx.sh proxy.domain.local 365 192.168.1.50

# Alternatively, run the script without any command arguments and the default variables below will apply
# e.g. sudo -E ./4a-install-tls-self-signed-nginx.sh

# Prepare text output colours
GREY='\033[0;37m'
DGREY='\033[0;90m'
GREYB='\033[1;37m'
LRED='\033[0;91m'
LGREEN='\033[0;92m'
LYELLOW='\033[0;93m'
NC='\033[0m' #No Colour

# Check if user is root or sudo
if ! [[ $(id -u) = 0 ]]; then
    echo
    echo -e "${LRED}Please run this script as sudo or root${NC}" 1>&2
    exit 1
fi

# Set default certificate file destinations.
DIR_SSL_CERT="/etc/nginx/ssl/cert"
DIR_SSL_KEY="/etc/nginx/ssl/private"

TOMCAT_VERSION=$(ls /etc/ | grep tomcat)
# Below variables are automatically updated by the 1-setup.sh script with the respective values given at install (manually update if blank)
DOWNLOAD_DIR=
CERT_COUNTRY=
CERT_STATE=
CERT_LOCATION=
CERT_ORG=
CERT_OU=
GUAC_URL=
INSTALL_LOG=
PROXY_SITE=
CERT_DAYS=
DEFAULT_IP=
RSA_KEYLENGTH=

# Create a place to save the certs so we don't overwrite any earlier versions
CERT_DIR_NAME=tls-certs-$(date +%y.%m.%d)
CERT_DIR=$DOWNLOAD_DIR/$CERT_DIR_NAME
mkdir -p $CERT_DIR
cd $CERT_DIR

# Setup script cmd line arguments for proxy site and certificate days
TLSNAME=$1
TLSDAYS=$2
TLSIP=$3

# Assume the values set by the main installer if the script is run without any command line options
if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ -z "$3" ]]; then
    TLSNAME=$PROXY_SITE
    TLSDAYS=$CERT_DAYS
    TLSIP=$DEFAULT_IP
fi

echo
echo
echo -e "${LGREEN}Setting up self-signed TLS certificates for Nginx...${GREY}"
echo

# Make directories to place TLS Certificate if they don't exist
if [[ ! -d $DIR_SSL_KEY ]]; then
    mkdir -p $DIR_SSL_KEY
fi

if [[ ! -d $DIR_SSL_CERT ]]; then
    mkdir -p $DIR_SSL_CERT
fi

echo -e "${GREY}New self-signed TLS certificate attributes are shown below...${DGREY}"
# Display the new TLS cert parameters.
cat <<EOF | tee cert_attributes.txt
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
CN                  = *.$(echo $TLSNAME | cut -d. -f2-)

[v3_req]
keyUsage            = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage    = serverAuth, clientAuth, codeSigning, emailProtection
subjectAltName      = @alt_names

[alt_names]
DNS.1               = $TLSNAME
DNS.2               = *.$(echo $TLSNAME | cut -d. -f2-)
IP.1                = $TLSIP
EOF

echo
echo -e "${GREY}Creating a new Nginx TLS Certificate..."
openssl req -x509 -nodes -newkey rsa:$RSA_KEYLENGTH -keyout $TLSNAME.key -out $TLSNAME.crt -days $TLSDAYS -config cert_attributes.txt
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Place TLS Certificate into the defined application path
cp $TLSNAME.key $DIR_SSL_KEY/$TLSNAME.key
cp $TLSNAME.crt $DIR_SSL_CERT/$TLSNAME.crt

# Create a PFX formatted key for easier import to Windows hosts
echo -e "${GREY}Converting client certificate to Windows pfx format...${GREY}"
openssl pkcs12 -export -out $TLSNAME.pfx -inkey $TLSNAME.key -in $TLSNAME.crt -password pass:1234
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Change of permissions so certs can be copied via WinSCP.
chown $SUDO_USER:root $TLSNAME.pfx
chown $SUDO_USER:root $TLSNAME.crt
chown $SUDO_USER:root $TLSNAME.key

# Backup the previous configuration
if [ -f "/etc/nginx/sites-enabled/${TLSNAME}" ]; then
    echo -e "${GREY}Backing up previous Nginx proxy config to $DOWNLOAD_DIR/${PROXY_SITE}-nginx.bak"
    cp -f /etc/nginx/sites-enabled/${TLSNAME} $DOWNLOAD_DIR/${TLSNAME}-nginx.bak
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Warning: Failed to copy the Nginx site config.${GREY}" 1>&2
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi
fi

# Update Nginx config to accept the new certificates
echo -e "${GREY}Configuring Nginx proxy to use the self-signed TLS certificate and setting up HTTP redirect...${DGREY}"
cat <<EOF | tee /etc/nginx/sites-available/$TLSNAME
server {
    # HTTPS site
    listen 443 ssl;
    server_name _;
    location / {
        proxy_pass $GUAC_URL;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$http_connection;
        access_log off;
    }
    ssl_certificate      /etc/nginx/ssl/cert/$TLSNAME.crt;
    ssl_certificate_key  /etc/nginx/ssl/private/$TLSNAME.key;
    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout  5m;
}

server {
    # Redirect all other traffic to the HTTPS site
    listen 80 default_server;
    location / {
        return 301 https://\$host\$request_uri;
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

# Find all enabled sites containing the $GUAC_URL and remove them to avoid conflicts
for x in /etc/nginx/sites-enabled/*; do
    # Check inside each enabled site to see if the $GUAC_URL exists.
    if [[ -f "${x}" ]]; then
        if grep -qE "${GUAC_URL}" "${x}"; then
            found_sites+=("${x}")
        fi
    fi
done

# Unlink all previous sites pointed to $GUAC_URL
if [ "${#found_sites[@]}" -gt 0 ]; then
    for guacUrl in "${found_sites[@]}"; do
        unlink "${guacUrl}"
    done
fi

# Link to enable the new site configuration
ln -s /etc/nginx/sites-available/$TLSNAME /etc/nginx/sites-enabled/ >/dev/null 2>&1

# Update general ufw rules so force traffic via reverse proxy. Only Nginx and SSH will be available over the network.
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

# Reload everything and tidy up
echo -e "${GREY}Restaring Guacamole & Ngnix..."
systemctl restart $TOMCAT_VERSION
systemctl restart guacd
systemctl restart nginx
rm -f cert_attributes.txt
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# A simple hack to display special characters in a cut & paste-able format directly to stdout.
SHOWASTEXT1='$mypwd'
SHOWASTEXT2='"Cert:\LocalMachine\Root"'

printf "${GREY}+-------------------------------------------------------------------------------------------------------------
${LGREEN}+ WINDOWS CLIENT SELF SIGNED TLS BROWSER CONFIG - SAVE THIS BEFORE CONTINUING!${GREY}
+
+ 1. In $CERT_DIR is a Windows version of the new certificate ${LYELLOW}$TLSNAME.pfx${GREY}
+ 2. Import this PFX file into your Windows client with the below PowerShell commands (as Administrator):
\n"
echo -e "${SHOWASTEXT1} = ConvertTo-SecureString -String "1234" -Force -AsPlainText"
echo -e "Import-pfxCertificate -FilePath $TLSNAME.pfx -Password "${SHOWASTEXT1}" -CertStoreLocation "${SHOWASTEXT2}""
printf "${GREY}+-------------------------------------------------------------------------------------------------------------
${LGREEN}+ LINUX CLIENT SELF SIGNED TLS BROWSER CONFIG - SAVE THIS BEFORE CONTINUING!${GREY}
+
+ 1. In $CERT_DIR is a new Linux native OpenSSL certificate ${LYELLOW}$TLSNAME.crt${GREY}
+ 2. Import the CRT file into your Linux client certificate store with the below command:
\n"
echo -e "(If certutil is not installed, run apt-get install libnss3-tools)"
echo -e "mkdir -p \$HOME/.pki/nssdb && certutil -d \$HOME/.pki/nssdb -N"
echo -e "certutil -d sql:\$HOME/.pki/nssdb -A -t "CT,C,c" -n $TLSNAME -i $TLSNAME.crt"
printf "+-------------------------------------------------------------------------------------------------------------\n"
echo -e "${LYELLOW}The above TLS browser config instructions are saved in ${LGREEN}$INSTALL_LOG${GREY}"

# Done
echo -e ${NC}
