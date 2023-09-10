#!/bin/bash
#######################################################################################################################
# Add Quick Connect extension to Guacamole
# For Ubuntu / Debian / Raspbian
# David Harrop
# September 2023
#######################################################################################################################

# Prepare text output colours
GREY='\033[0;37m'
DGREY='\033[0;90m'
GREYB='\033[1;37m'
LRED='\033[0;91m'
LGREEN='\033[0;92m'
LYELLOW='\033[0;93m'
NC='\033[0m' #No Colour

clear

# Check if user is root or sudo
if ! [[ $(id -u) = 0 ]]; then
    echo
    echo -e "${LGREEN}Please run this script as sudo or root${NC}" 1>&2
    exit 1
fi

TOMCAT_VERSION=$(ls /etc/ | grep tomcat)
GUAC_VERSION=$(grep -oP 'Guacamole.API_VERSION = "\K[0-9\.]+' /var/lib/${TOMCAT_VERSION}/webapps/guacamole/guacamole-common-js/modules/Version.js)
GUAC_SOURCE_LINK="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VERSION}"

echo
wget -q --show-progress -O guacamole-auth-quickconnect-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-quickconnect-${GUAC_VERSION}.tar.gz
tar -xzf guacamole-auth-quickconnect-${GUAC_VERSION}.tar.gz
mv -f guacamole-auth-quickconnect-${GUAC_VERSION}/guacamole-auth-quickconnect-${GUAC_VERSION}.jar /etc/guacamole/extensions/
chmod 664 /etc/guacamole/extensions/guacamole-auth-quickconnect-${GUAC_VERSION}.jar
echo -e "${LGREEN}Installed guacamole-auth-quickconnect-${GUAC_VERSION}${GREY}"

systemctl restart ${TOMCAT_VERSION}
systemctl restart guacd

rm -rf guacamole-*

echo
echo "Done!"
echo -e ${NC}
