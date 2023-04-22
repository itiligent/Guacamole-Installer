#!/bin/bash
#######################################################################################################################
# Harden Guacd <-> Guac client traffic in SSL wrapper
# For Ubuntu / Debian / Raspian
# David Harrop
# April 2023
#######################################################################################################################

# Prepare text output colours
GREY='\033[0;37m'
DGREY='\033[0;90m'
GREYB='\033[1;37m'
RED='\033[0;31m'
LRED='\033[0;91m'
GREEN='\033[0;32m'
LGREEN='\033[0;92m'
YELLOW='\033[0;33m'
LYELLOW='\033[0;93m'
BLUE='\033[0;34m'
LBLUE='\033[0;94m'
CYAN='\033[0;36m'
LCYAN='\033[0;96m'
MAGENTA='\033[0;35m'
LMAGENTA='\033[0;95m'
NC='\033[0m' #No Colour

CERT_COUNTRY=
CERT_STATE=
CERT_LOCATION=
CERT_ORG=
CERT_OU=

clear

if ! [ $( id -u ) = 0 ]; then
	echo
	echo -e "${LGREEN}Please run this script as sudo or root${NC}" 1>&2
	exit 1
fi

# Create the special directory for guacd ssl certfifacte and key.
sudo mkdir /etc/guacamole/ssl
echo
cat <<EOF | tee -a cert_attributes.txt
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
CN                  = localhost

[v3_req]
keyUsage            = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage    = serverAuth, clientAuth, codeSigning, emailProtection
subjectAltName      = @alt_names

[alt_names]
DNS.1               = localhost
IP.1                = 127.0.0.1
EOF

# Create the self signining request, certificate & key
sudo openssl req -x509 -nodes -days 36500 -newkey rsa:2048 -keyout /etc/guacamole/ssl/guacd.key -out /etc/guacamole/ssl/guacd.crt -config cert_attributes.txt
rm -f cert_attributes.txt

# Point Gaucamole config file to certificate any key
sudo cat <<EOF | sudo tee /etc/guacamole/guacd.conf
[server]
bind_host = 127.0.0.1
bind_port = 4822
[ssl]
server_certificate = /etc/guacamole/ssl/guacd.crt
server_key = /etc/guacamole/ssl/guacd.key
EOF

# Enable SSL backend
sudo cat <<EOF | sudo tee -a /etc/guacamole/guacamole.properties
guacd-ssl: true
EOF

# Fix required permissions as guacd only runs as daemon
sudo chown daemon:daemon /etc/guacamole/ssl
sudo chown daemon:daemon /etc/guacamole/ssl/guacd.key
sudo chown daemon:daemon /etc/guacamole/ssl/guacd.crt
sudo chmod 644 /etc/guacamole/ssl/guacd.crt
sudo chmod 644 /etc/guacamole/ssl/guacd.key

# Add the new certificate into the Java Runtime certificate store and set JRE to trust it.
cd /etc/guacamole/ssl
sudo keytool -importcert -alias guacd -noprompt -cacerts -storepass changeit -file guacd.crt
sudo systemctl restart guacd

echo
echo "Done!"
echo -e ${NC}
