#!/bin/bash
######################################################################################################################
# Guacamole appliance mysql upgrade script
# For Ubuntu / Debian / Raspbian
# David Harrop
# April 2023
#######################################################################################################################

### IMPORTANT ###
# Update you MySQL database packages separately first via your package manager first 
# You only need to run this script if the Guacamole schema have changed between versions (this has not been updated since late 2021 with 1.0, suggesting 
# that Guacamole is now quite mature and changes may be rare in future. 
# To acertain if there are schema changes required for an upgraded version, check inside the guacamole-auth-jdbc-GUAC_VERSION.tar.gz 
# file under /mysql/schema/upgrade/ to find any relevant updates. Only run this script if there are. 

#######################################################################################################################
# Script pre-flight checks and settings ###############################################################################
#######################################################################################################################

clear

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

# Check to see if any previous version of build/install files exist, if so stop and check to be safe.
if [[ "$(find . -maxdepth 1 \( -name 'guacamole-*' -o -name 'mysql-connector-j-*' \))" != "" ]]; then
    echo
    echo -e "${LRED}Possible previous install files detected. Please review and remove old guacamole install files before proceeding.${GREY}" 1>&2
    echo
    exit 1
fi

#######################################################################################################################
# Initial environment setup ###########################################################################################
#######################################################################################################################

#Setup download and temp directory paths
USER_HOME_DIR=$(eval echo ~${SUDO_USER})
DOWNLOAD_DIR=$USER_HOME_DIR/guac-setup

# Setup directory locations
mkdir -p $DOWNLOAD_DIR
chown -R $SUDO_USER:root $DOWNLOAD_DIR

# Version of Guacamole to upgrade to. See https://guacamole.apache.org/releases/ for latest version info.
NEW_GUAC_VERSION="1.5.5"

# The currently installed Guacamole schema version is needed to evaluate the required schema upgrades.
OLD_GUAC_VERSION="1.5.4"

# Set preferred Apache CDN download link)
GUAC_SOURCE_LINK="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${NEW_GUAC_VERSION}"

# Install log Location
INSTALL_LOG="${DOWNLOAD_DIR}/mysql_upgrade.log"

# Database details
GUAC_DB="guacamole_db"
MYSQL_ROOT_PWD="test"

clear

# Script branding header
echo
echo -e "${GREYB}Guacamole Backend MySQL Schema UPGRADE."
echo -e "                      ${LGREEN}Powered by Itiligent${GREY}"
echo
echo

#######################################################################################################################
# Start install actions  ##############################################################################################
#######################################################################################################################


# Download and extract the Guacamole SQL authentication extension containing the database schema
wget -q --show-progress -O guacamole-auth-jdbc-${NEW_GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-jdbc-${NEW_GUAC_VERSION}.tar.gz
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed to download guacamole-auth-jdbc-${NEW_GUAC_VERSION}.tar.gz" 1>&2
    echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-jdbc-${NEW_GUAC_VERSION}.tar.gz"
    exit 1
else
    tar -xzf guacamole-auth-jdbc-${NEW_GUAC_VERSION}.tar.gz
fi

echo
# Get list of SQL Upgrade Files
echo -e "${GREY}Upgrading MySQL Schema..."
UPGRADEFILES=($(ls -1 guacamole-auth-jdbc-${NEW_GUAC_VERSION}/mysql/schema/upgrade/ | sort -V))

# Compare SQL Upgrage Files against old version, apply upgrades as needed
for FILE in ${UPGRADEFILES[@]}; do
    FILEVERSION=$(echo ${FILE} | grep -oP 'upgrade-pre-\K[0-9\.]+(?=\.)')
    if [[ $(echo -e "${FILEVERSION}\n${OLD_GUAC_VERSION}" | sort -V | head -n1) == ${OLD_GUAC_VERSION} && ${FILEVERSION} != ${OLD_GUAC_VERSION} ]]; then
        echo "Patching ${GUAC_DB} with ${FILE}"
        mariadb -u root -D ${GUAC_DB} -p${MYSQL_ROOT_PWD} <guacamole-auth-jdbc-${NEW_GUAC_VERSION}/mysql/schema/upgrade/${FILE} &>>${INSTALL_LOG}
    fi
done
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}SQL upgrade failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Restart MySQL service
echo -e "${GREY}Restarting MySQL service..."
systemctl restart mysql
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Cleanup
echo -e "${GREY}Clean up install files...${GREY}"
rm -rf guacamole-*
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Done
printf "${LGREEN}Guacamole ${NEW_GUAC_VERSION} schema upgrade complete - check log for details! \n${NC}"
echo -e ${NC}
