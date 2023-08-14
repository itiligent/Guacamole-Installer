#!/bin/bash
#######################################################################################################################
# Add Active Directory integration with Guacamole
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

# Check if user is root or sudo

if ! [ $(id -u) = 0 ]; then
    echo
    echo -e "${LGREEN}Please run this script as sudo or root${NC}" 1>&2
    exit 1
fi

TOMCAT_VERSION=$(ls /etc/ | grep tomcat)
GUAC_VERSION=$(grep -oP 'Guacamole.API_VERSION = "\K[0-9\.]+' /var/lib/${TOMCAT_VERSION}/webapps/guacamole/guacamole-common-js/modules/Version.js)
GUAC_SOURCE_LINK="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VERSION}"

echo
echo -e "${LYELLOW}Have you updated this script to reflect your Active Directory settings?${NC}"

read -p "Do you want to proceed? (yes/no) " yn
echo
case $yn in
y) echo Beginning LDAP auth config... ;;
n)
    echo exiting...
    exit
    ;;
*)
    echo invalid response
    exit 1
    ;;
esac

echo
wget -q --show-progress -O guacamole-auth-ldap-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-ldap-${GUAC_VERSION}.tar.gz
tar -xzf guacamole-auth-ldap-${GUAC_VERSION}.tar.gz
echo
echo Adding the below config to /etc/guacamole/guacamole.properties
cat <<EOF | sudo tee -a /etc/guacamole/guacamole.properties
ldap-hostname: dc1.yourdomain.com dc2.yourdomain.com
ldap-port: 389
ldap-username-attribute: sAMAccountName
ldap-encryption-method: none
ldap-search-bind-dn: ad-account@yourdomain.com
ldap-search-bind-password: ad-account-password
ldap-config-base-dn: dc=domain,dc=com
ldap-user-base-dn: OU=SomeOU,DC=domain,DC=com
ldap-user-search-filter:(objectClass=user)(!(objectCategory=computer))
ldap-max-search-results:200
EOF

mv -f guacamole-auth-ldap-${GUAC_VERSION}/guacamole-auth-ldap-${GUAC_VERSION}.jar /etc/guacamole/extensions/
sudo chmod 664 /etc/guacamole/extensions/guacamole-auth-ldap-${GUAC_VERSION}.jar
sudo systemctl restart ${TOMCAT_VERSION}
sudo systemctl restart guacd

rm -rf guacamole-*

echo
echo "Done!"
echo -e ${NC}
