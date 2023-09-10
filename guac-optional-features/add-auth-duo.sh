#!/bin/bash
#######################################################################################################################
# Add Duo (MFA) support to Guacamole
# For Ubuntu / Debian / Raspbian
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

clear

if ! [ $(id -u) = 0 ]; then
	echo
	echo -e "${LGREEN}Please run this script as sudo or root${NC}" 1>&2
	exit 1
fi
TOMCAT_VERSION=$(ls /etc/ | grep tomcat)
GUAC_VERSION=$(grep -oP 'Guacamole.API_VERSION = "\K[0-9\.]+' /var/lib/${TOMCAT_VERSION}/webapps/guacamole/guacamole-common-js/modules/Version.js)
GUAC_SOURCE_LINK="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VERSION}"

echo
wget -q --show-progress -O guacamole-auth-duo-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-duo-${GUAC_VERSION}.tar.gz
tar -xzf guacamole-auth-duo-${GUAC_VERSION}.tar.gz
mv -f guacamole-auth-duo-${GUAC_VERSION}/guacamole-auth-duo-${GUAC_VERSION}.jar /etc/guacamole/extensions/
chmod 664 /etc/guacamole/extensions/guacamole-auth-duo-${GUAC_VERSION}.jar
echo -e "${LGREEN}Installed guacamole-auth-duo-${GUAC_VERSION}${GREY}"
echo "duo-integration-key: " >>/etc/guacamole/guacamole.properties
echo "duo-secret-key: " >>/etc/guacamole/guacamole.properties
echo "duo-api-hostname: " >>/etc/guacamole/guacamole.properties
echo "duo-application-key: " >>/etc/guacamole/guacamole.properties
echo
systemctl restart ${TOMCAT_VERSION}
sudo systemctl restart guacd

echo -e "${LYELLOW}You must now set up your online Duo account with a new 'Web SDK' application."
echo
echo "Next you must copy the API settings from your Duo account into /etc/guacamole/guacamole.properties in the EXACT below format."
echo -e "Be VERY careful to avoid extra trailing spaces or other line feed characters when pasting!${GREY}"
echo
echo "duo-integration-key: ??????????"
echo "duo-api-hostname: ??????????"
echo "duo-secret-key: ??????????"
echo "duo-application-key: (this is locally created - run 'pwgen 40 1' to manually generate this 40 char random value)"
echo
echo "Once this change is complete, restart Guacamole with sudo systemctl restart ${TOMCAT_VERSION}"

rm -rf guacamole-*

echo
echo -e ${NC}
