#!/bin/bash
#######################################################################################################################
# Create or refresh self signed TLS certificates for Nginx (or others)
# For Ubuntu / Debian / Rasbpian
# David Harrop
# September 2023
#######################################################################################################################

# If run with with no command arguments, the ${PROXY_SITE} ${CERT_DAYS} & ${Default_IP) values from original install are applied.
#      e.g. sudo ./refresh-tls-self-signed-nginx.sh
#
# SCript can also be run with custom command line arguments for use with any TLS application:
#      Command arguments are formatted as: [command] [FQDN] [cert-lifetime] [IP]
#      e.g. sudo ./refresh-tls-self-signed-nginx.sh webserver.domain.local 365 192.168.1.1

# Prepare text output colours
GREY='\033[0;37m'
DGREY='\033[0;90m'
GREYB='\033[1;37m'
LRED='\033[0;91m'
LGREEN='\033[0;92m'
LYELLOW='\033[0;93m'
NC='\033[0m' #No Colour

# Check if user is root or sudo
if ! [ $(id -u) = 0 ]; then
	echo
	echo -e "${LRED}Please run this script as sudo or root${NC}" 1>&2
	echo
	exit 1
fi

echo
echo
echo -e "${LGREEN}Cresting self signed TLS certificates for Nginx...${GREY}"
echo

USER_HOME_DIR=$(eval echo ~${SUDO_USER})
CERT_DIR=tls-certs-$(date +%y.%m.%d-%H_%M)
WORKING_DIR=$USER_HOME_DIR/guac-setup/$CERT_DIR
mkdir -p $WORKING_DIR
cd $WORKING_DIR

# Set default certificate file destinations. Change these for other TLS applications.
DIR_SSL_KEY="/etc/nginx/ssl/private"
DIR_SSL_CERT="/etc/nginx/ssl/cert"

# Cmd line arguments for dns name, certificate days and IP address
TLSNAME=$1
TLSDAYS=$2
TLSIP=$3

# Auto updated values from main installer (manually update if blank)
CERT_COUNTRY=
CERT_STATE=
CERT_LOCATION=
CERT_ORG=
CERT_OU=
PROXY_SITE=
CERT_DAYS=
DEFAULT_IP=

# Assume the values used by the guacamole installer if the script is run without any command line options
if [ -z "$1" ] | [ -z "$2" ] | [ -z "$3" ]; then
	TLSNAME=$PROXY_SITE
	TLSDAYS=$CERT_DAYS
	TLSIP=$DEFAULT_IP
fi

# Make directories to place TLS Certificate if they don't exist
if [[ ! -d $DIR_SSL_KEY ]]; then
	sudo mkdir -p $DIR_SSL_KEY
fi

if [[ ! -d $DIR_SSL_CERT ]]; then
	sudo mkdir -p $DIR_SSL_CERT
fi

echo -e "${GREY}New self signed TLS certificate attributes are shown below...${DGREY}"
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
CN                  = $TLSNAME

[v3_req]
keyUsage            = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage    = serverAuth, clientAuth, codeSigning, emailProtection
subjectAltName      = @alt_names

[alt_names]
DNS.1               = $TLSNAME
IP.1                = $TLSIP
EOF

echo
# Create the new certificates
echo "{$GREY}Creating a new TLS Certificate..."
openssl req -x509 -nodes -newkey rsa:2048 -keyout $TLSNAME.key -out $TLSNAME.crt -days $TLSDAYS -config cert_attributes.txt
if [ $? -ne 0 ]; then
	echo -e "${LRED}Failed.${GREY}" 1>&2
	exit 1
else
	echo -e "${LGREEN}OK${GREY}"
	echo
fi

# Place TLS Certificate into the defined application path
cp $TLSNAME.key $DIR_SSL_KEY/$TLSNAME.key
cp $TLSNAME.crt $DIR_SSL_CERT/$TLSNAME.crt

# Create a PFX formatted key for easier import to Windows hosts and change permissions to enable copying elsewhere
echo -e "${GREY}Converting client certificates for Windows & Linux...${GREY}"
openssl pkcs12 -export -out $TLSNAME.pfx -inkey $TLSNAME.key -in $TLSNAME.crt -password pass:1234
if [ $? -ne 0 ]; then
	echo -e "${LRED}Failed.${GREY}" 1>&2
	exit 1
else
	echo -e "${LGREEN}OK${GREY}"
	echo
fi

# Change of permissions so certs can be copied via WinSCP.
chown -R $SUDO_USER:root $WORKING_DIR

# Reload everything
echo -e "${GREY}New certificate created, restating Guacamole & Ngnix..."
TOMCAT=$(ls /etc/ | grep tomcat)
systemctl restart $TOMCAT
systemctl restart guacd
systemctl restart nginx
if [ $? -ne 0 ]; then
	echo -e "${LRED}Failed.${GREY}" 1>&2
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
+ 1. In ${WORKING_DIR} is a Windows version of the new certificate ${LYELLOW}$TLSNAME.pfx${GREY}
+ 2. Import this PFX file into your Windows client with the below Powershell commands (as Administrator):
\n"
echo -e "${SHOWASTEXT1} = ConvertTo-SecureString -String "1234" -Force -AsPlainText"
echo -e "Import-pfxCertificate -FilePath $TLSNAME.pfx -Password "${SHOWASTEXT1}" -CertStoreLocation "${SHOWASTEXT2}""
printf "${GREY}+-------------------------------------------------------------------------------------------------------------
${LGREEN}+ LINUX CLIENT SELF SIGNED TLS BROWSER CONFIG - SAVE THIS BEFORE CONTINUING!${GREY}
+
+ 1. In ${WORKING_DIR} is a new Linux native OpenSSL certificate ${LYELLOW}$TLSNAME.crt${GREY}
+ 2. Import the CRT file into your Linux client certificate store with the below command:
\n"
echo -e "(If certutil is not installed, run apt-get install libnss3-tools)"
echo -e "mkdir -p $HOME/.pki/nssdb && certutil -d $HOME/.pki/nssdb -N"
echo -e "certutil -d sql:$HOME/.pki/nssdb -A -t "CT,C,c" -n $TLSNAME -i $TLSNAME.crt"
printf "+-------------------------------------------------------------------------------------------------------------\n"

rm -f cert_attributes.txt

# Done
echo -e ${NC}
