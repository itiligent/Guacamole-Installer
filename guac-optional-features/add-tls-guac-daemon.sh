#!/bin/bash
#######################################################################################################################
# Harden Guacd <-> Guac client traffic in TLS wrapper
# For Ubuntu / Debian / Raspbian
# David Harrop
# April 2023
#######################################################################################################################

# To delete and reissue a new cert
# sudo keytool -delete -alias guacd -noprompt -cacerts -storepass changeit -file guacd.crt

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

TOMCAT_VERSION=$(ls /etc/ | grep tomcat)
RSA_KEY_LENGTH=2048
# Below variables are automatically updated by the 1-setup.sh script with the respective values given at install (manually update if blank)
CERT_COUNTRY=
CERT_STATE=
CERT_LOCATION=
CERT_ORG=
CERT_OU=
CERT_DAYS=

clear

# Create the special directory for guacd tls certificate and key.
mkdir -p /etc/guacamole/ssl
echo
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
CN                  = localhost

[v3_req]
keyUsage            = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage    = serverAuth, clientAuth, codeSigning, emailProtection
subjectAltName      = @alt_names

[alt_names]
DNS.1               = localhost
IP.1                = 127.0.0.1
EOF

# Create the self signing request, certificate & key. 
# If splitting guacd (backend) and guacamole (front end) across separate systems, run this command on guacd and then copy certs to the same location on guacamole server.
# Also consider omitting the setting -config cert_attributes.txt or IP.1 = 0.0.0.0 for future ip address changes if splitting.
openssl req -x509 -nodes -days $CERT_DAYS -newkey rsa:$RSA_KEY_LENGTH -keyout /etc/guacamole/ssl/guacd.key -out /etc/guacamole/ssl/guacd.crt -config cert_attributes.txt
rm -f cert_attributes.txt

# Point Guacamole config file to certificate and key. (If splitting, run this on guacd after changing bind_ host to 0.0.0.0 ).
cp /etc/guacamole/guacd.conf /etc/guacamole/guacd.conf.bak
cat <<EOF | sudo tee /etc/guacamole/guacd.conf
[server]
bind_host = 127.0.0.1
bind_port = 4822
[ssl]
server_certificate = /etc/guacamole/ssl/guacd.crt
server_key = /etc/guacamole/ssl/guacd.key
EOF

# Enable TLS backend (Add this to guacamole server front end if splitting)
cat <<EOF | sudo tee -a /etc/guacamole/guacamole.properties
guacd-ssl: true
EOF

# Fix required permissions as guacd only runs as daemon (Run on both systems if splitting)
chown daemon:daemon /etc/guacamole/ssl
chown daemon:daemon /etc/guacamole/ssl/guacd.key
chown daemon:daemon /etc/guacamole/ssl/guacd.crt
chmod 644 /etc/guacamole/ssl/guacd.crt
chmod 644 /etc/guacamole/ssl/guacd.key

# Add the new certificate into the Java Runtime certificate store and set JRE to trust it. (Run on guacamole server front end if splitting)
cd /etc/guacamole/ssl
keytool -importcert -alias guacd -noprompt -cacerts -storepass changeit -file guacd.crt

systemctl restart guacd
systemctl restart ${TOMCAT_VERSION}

echo
echo "Done!"
echo -e ${NC}
