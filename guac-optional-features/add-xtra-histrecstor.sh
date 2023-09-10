#!/bin/bash
#######################################################################################################################
# Add History Recorded Storage extension for Guacamole
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
if ! [ $(id -u) = 0 ]; then
	echo
	echo -e "${LGREEN}Please run this script as sudo or root${NC}" 1>&2
	exit 1
fi

TOMCAT_VERSION=$(ls /etc/ | grep tomcat)
GUAC_VERSION=$(grep -oP 'Guacamole.API_VERSION = "\K[0-9\.]+' /var/lib/${TOMCAT_VERSION}/webapps/guacamole/guacamole-common-js/modules/Version.js)
GUAC_SOURCE_LINK="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VERSION}"
HISTREC_PATH_DEFAULT=/var/lib/guacamole/recordings # Apache default

while true; do
	echo
	read -p "Enter recorded storage path [Enter for default ${HISTREC_PATH_DEFAULT}]: " HISTREC_PATH
	[ "${HISTREC_PATH}" = "" ] || [ "${HISTREC_PATH}" != "" ] && break
done
# If no custom path is given, lets assume the default path on hitting enter
if [ -z "${HISTREC_PATH}" ]; then
	HISTREC_PATH="${HISTREC_PATH_DEFAULT}"
fi
echo

# Download Guacamole history recording storage extension
wget -q --show-progress -O guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz
tar -xzf guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz

# Move history recording storage extension files
mv -f guacamole-history-recording-storage-${GUAC_VERSION}/guacamole-history-recording-storage-${GUAC_VERSION}.jar /etc/guacamole/extensions/
chmod 664 /etc/guacamole/extensions/guacamole-history-recording-storage-${GUAC_VERSION}.jar
#Setup the default recording path
mkdir -p ${HISTREC_PATH}
chown daemon:tomcat ${HISTREC_PATH}
chmod 2750 ${HISTREC_PATH}
echo "recording-search-path: ${HISTREC_PATH}" >>/etc/guacamole/guacamole.properties
echo -e "${LGREEN}Installed guacamole-history-recording-storage-${GUAC_VERSION}${GREY}"

systemctl restart ${TOMCAT_VERSION}
systemctl restart guacd

rm -rf guacamole-*

echo
echo "Done!"
echo -e ${NC}
