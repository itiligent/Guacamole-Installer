#!/bin/bash
######################################################################################################################
# Guacamole appliance upgrade script
# For Ubuntu / Debian / Raspbian
# David Harrop
# April 2023
#######################################################################################################################

#######################################################################################################################
# Initial enviromment setup ###########################################################################################
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
if ! [ $(id -u) = 0 ]; then
    echo
    echo -e "${LGREEN}Please run this script as sudo or root${NC}" 1>&2
    exit 1
fi

#Setup download and temp directory paths
USER_HOME_DIR=$(eval echo ~${SUDO_USER})
DOWNLOAD_DIR=$USER_HOME_DIR/guac-setup/upgrade

# Script branding header
echo
echo -e "${GREYB}Itiligent Virtual Desktop Appliance UPGRADE"
echo -e "                    ${LGREEN}Powered by Guacamole"
echo

# Setup directory locations
mkdir -p $DOWNLOAD_DIR

# Version of Guacamole to upgrade to
NEW_GUAC_VERSION="1.5.3"

# Get the currently installed Tomcat version.
TOMCAT_VERSION=$(ls /etc/ | grep tomcat)

# Get the currently installed Guacamole version
OLD_GUAC_VERSION=$(grep -oP 'Guacamole.API_VERSION = "\K[0-9\.]+' /var/lib/${TOMCAT_VERSION}/webapps/guacamole/guacamole-common-js/modules/Version.js)

# Set preferred Apache CDN download link
GUAC_SOURCE_LINK="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${NEW_GUAC_VERSION}"
# Set preferred Apache CDN download link

# Install log Location
LOG_LOCATION="${DOWNLOAD_DIR}/guacamole_${NEW_GUAC_VERSION}_upgrade.log"

# Non interactive silent setup options - add true/false or specific values
MYSQL_HOST=""     # leave blank for localhost default, only specify for remote servers
MYSQL_PORT=""     # If blank default is 3306
GUAC_DB=""        # If blank default is guacamole_db
GUAC_USER=""      # if blank default is guacamole_user
GUAC_PWD=""       # Should not be blank as this may break some aspects of install
MYSQL_ROOT_PWD="" # Should not be blank as this may break some aspects of install

echo
# For convenience & sanity check, display status of preset script options at start of install
echo -e "${GREY}Enabled non-interactive presets listed below, blank entries will prompt. Ctrl+x to stop/edit"
echo -e "${DGREY}Current Guacamole version\t= ${GREY}${OLD_GUAC_VERSION}"
echo -e "${DGREY}Guacamole upgrade version\t= ${GREY}${NEW_GUAC_VERSION}"
echo -e "${DGREY}MySQL hostname/IP\t\t= ${GREY}${MYSQL_HOST}"
echo -e "${DGREY}MySQL port\t\t\t= ${GREY}${MYSQL_PORT}"
echo -e "${DGREY}Guacamole db name\t\t= ${GREY}${GUAC_DB}"
echo -e "${DGREY}Guacamole db user name\t\t= ${GREY}${GUAC_USER}"
echo -e "${DGREY}Guacamole user pwd\t\t= ${GREY}${GUAC_PWD}"
echo -e "${DGREY}MySQL root pwd\t\t\t= ${GREY}${MYSQL_ROOT_PWD}${GREY}"
echo

#######################################################################################################################
# Prompt inputs #######################################################################################################
#######################################################################################################################

# Get MySQL Hostname or IP
if [ -z "${MYSQL_HOST}" ]; then
    read -s -p "Enter MySQL server hostname or IP [localhost]: " MYSQL_HOST
    echo
fi

# Get MySQL Port
if [ -z "${MYSQL_PORT}" ]; then
    read -s -p "Enter MySQL server port [3306]: " MYSQL_PORT
    echo
fi

# Get MySQL database name
if [ -z "${GUAC_DB}" ]; then
    read -s -p "Enter Guacamole database name [guacamole_db]: " GUAC_DB
    echo
fi

# Get MySQL user name
if [ -z "${GUAC_USER}" ]; then
    read -s -p "Enter Guacamole user name [guacamole_user]: " GUAC_USER
    echo
fi

# Get Guacamole User password, confirm correct password entry and prevent blank passwords
if [ -z "${GUAC_PWD}" ]; then
    read -s -p "Enter MySQL guacamole_user password: " GUAC_PWD
    echo
fi

# Get MySQL root password
if [ -z "${MYSQL_ROOT_PWD}" ]; then
    read -s -p "Enter MySQL root password: " MYSQL_ROOT_PWD
    echo
fi

# Set prompt input defaults if values not given

# Checking if a mysql host given, if not set a default
if [ -z "${MYSQL_HOST}" ]; then
    MYSQL_HOST="localhost"
fi

# Checking if a mysql port given, if not set a default
if [ -z "${MYSQL_PORT}" ]; then
    MYSQL_PORT="3306"
fi

# Checking if a database name given, if not set a default
if [ -z "${GUAC_DB}" ]; then
    GUAC_DB="guacamole_db"
fi

# Checking if a mysql user given, if not set a default
if [ -z "${GUAC_USER}" ]; then
    GUAC_USER="guacamole_user"
fi

#######################################################################################################################
# Start upgrade actions  ##############################################################################################
#######################################################################################################################

sudo apt-get upgrade -qq -y

# Stop tomcat and guacd
systemctl stop ${TOMCAT_VERSION}
systemctl stop guacd

cd $DOWNLOAD_DIR

echo
echo -e "${GREY}Beggining Guacamole ${OLD_GUAC_VERSION} to ${NEW_GUAC_VERSION} upgrade..."
wget -q --show-progress -O guacamole-${NEW_GUAC_VERSION}.war ${GUAC_SOURCE_LINK}/binary/guacamole-${NEW_GUAC_VERSION}.war
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed to download guacamole-${NEW_GUAC_VERSION}.war" 1>&2
    echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-${NEW_GUAC_VERSION}.war${GREY}"
    exit 1
else
    rm /etc/guacamole/guacamole.war
    mv -f guacamole-${NEW_GUAC_VERSION}.war /etc/guacamole/guacamole.war
fi
echo -e "${LGREEN}Upgraded Guacamole client to version ${NEW_GUAC_VERSION}${GREY}"

# Download and upgrade Guacamole SQL authentication extension
wget -q --show-progress -O guacamole-auth-jdbc-${NEW_GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-jdbc-${NEW_GUAC_VERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed to download guacamole-auth-jdbc-${NEW_GUAC_VERSION}.tar.gz" 1>&2
    echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-jdbc-${NEW_GUAC_VERSION}.tar.gz"
    exit 1
else
    tar -xzf guacamole-auth-jdbc-${NEW_GUAC_VERSION}.tar.gz
    rm /etc/guacamole/extensions/guacamole-auth-jdbc-*.jar
    mv -f guacamole-auth-jdbc-${NEW_GUAC_VERSION}/mysql/guacamole-auth-jdbc-mysql-${NEW_GUAC_VERSION}.jar /etc/guacamole/extensions/
fi
echo -e "${LGREEN}Upgraded Guacamole SQL jdbc to version ${NEW_GUAC_VERSION}${GREY}"

# Download Guacamole Server
wget -q --show-progress -O guacamole-server-${NEW_GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/source/guacamole-server-${NEW_GUAC_VERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed to download guacamole-server-${NEW_GUAC_VERSION}.tar.gz" 1>&2
    echo -e "${GUAC_SOURCE_LINK}/source/guacamole-server-${NEW_GUAC_VERSION}.tar.gz${GREY}"
    exit 1
else
    tar -xzf guacamole-server-${NEW_GUAC_VERSION}.tar.gz
fi
echo -e "${LGREEN}Downloaded guacamole-server-${NEW_GUAC_VERSION}.tar.gz${GREY}"

# Make and install guacd (Guacamole-Server)
cd guacamole-server-${NEW_GUAC_VERSION}/
echo
echo -e "${GREY}Compiling Guacamole-Server ${NEW_GUAC_VERSION} from source with with GCC $(gcc --version | head -n1 | grep -oP '\)\K.*' | awk '{print $1}'), this might take a few minutes...${GREY}"
# Fix for warnings see #222 https://github.com/MysticRyuujin/guac-install/issues/222
export CFLAGS="-Wno-error"
# Configure Guacamole Server source
./configure --with-systemd-dir=/etc/systemd/system &>>${LOG_LOCATION}
if [ $? -ne 0 ]; then
    echo "Failed to configure guacamole-server"
    echo "Trying again with --enable-allow-freerdp-snapshots"
    ./configure --with-systemd-dir=/etc/systemd/system --enable-allow-freerdp-snapshots
    if [ $? -ne 0 ]; then
        echo "Failed to configure guacamole-server - again"
        exit
    fi
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

echo -e "${GREY}Running Make and building the upgraded Guacamole-Server application..."
make &>>${LOG_LOCATION}
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

echo -e "${GREY}Installing the upgraded Guacamole-Server..."
make install &>>${LOG_LOCATION}
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi
ldconfig

cd ..

# Get list of SQL Upgrade Files
echo -e "${GREY}Upgrading MySQL Schema..."
UPGRADEFILES=($(ls -1 guacamole-auth-jdbc-${NEW_GUAC_VERSION}/mysql/schema/upgrade/ | sort -V))

# Compare SQL Upgrage Files against old version, apply upgrades as needed
for FILE in ${UPGRADEFILES[@]}; do
    FILEVERSION=$(echo ${FILE} | grep -oP 'upgrade-pre-\K[0-9\.]+(?=\.)')
    if [[ $(echo -e "${FILEVERSION}\n${OLD_GUAC_VERSION}" | sort -V | head -n1) == ${OLD_GUAC_VERSION} && ${FILEVERSION} != ${OLD_GUAC_VERSION} ]]; then
        echo "Patching ${GUAC_DB} with ${FILE}"
        mysql -u root -D ${GUAC_DB} -h ${MYSQL_HOST} -P ${MYSQL_PORT} <guacamole-auth-jdbc-${NEW_GUAC_VERSION}/mysql/schema/upgrade/${FILE} &>>${LOG_LOCATION}
    fi
done
if [ $? -ne 0 ]; then
    echo -e "${LRED}SQL upgrade failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Check for DUO extension and upgrade if found
for file in /etc/guacamole/extensions/guacamole-auth-duo*.jar; do
    if [[ -f $file ]]; then
        echo -e "${LGREEN}DUO authentication extension was found, upgrading...${GREY}"
        rm /etc/guacamole/extensions/guacamole-auth-duo*.jar &>>${LOG_LOCATION}
        wget -q --show-progress -O guacamole-auth-duo-${NEW_GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-duo-${NEW_GUAC_VERSION}.tar.gz
        if [ $? -ne 0 ]; then
            echo -e "${LRED}Failed to download guacamole-auth-duo-${NEW_GUAC_VERSION}.tar.gz" 1>&2
            echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-duo-${NEW_GUAC_VERSION}.tar.gz"
            exit 1
        fi
        tar -xzf guacamole-auth-duo-${NEW_GUAC_VERSION}.tar.gz &>>${LOG_LOCATION}
        mv -f guacamole-auth-duo-${NEW_GUAC_VERSION}/guacamole-auth-duo-${NEW_GUAC_VERSION}.jar /etc/guacamole/extensions/ &>>${LOG_LOCATION}
        echo -e "${LGREEN}Upgraded DUO extension to version ${NEW_GUAC_VERSION}${GREY}"
        echo
        break
    fi
done

# Check for LDAP extension and upgrade if found
for file in /etc/guacamole/extensions/guacamole-auth-ldap*.jar; do
    if [[ -f $file ]]; then
        echo -e "${LGREEN}LDAP authentication extension was found, upgrading...${GREY}"
        rm /etc/guacamole/extensions/guacamole-auth-ldap*.jar &>>${LOG_LOCATION}
        wget -q --show-progress -O guacamole-auth-ldap-${NEW_GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-ldap-${NEW_GUAC_VERSION}.tar.gz
        if [ $? -ne 0 ]; then
            echo -e "${LRED}Failed to download guacamole-auth-ldap-${NEW_GUAC_VERSION}.tar.gz" 1>&2
            echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-ldap-${NEW_GUAC_VERSION}.tar.gz"
            exit 1
        fi
        tar -xzf guacamole-auth-ldap-${NEW_GUAC_VERSION}.tar.gz &>>${LOG_LOCATION}
        mv -f guacamole-auth-ldap-${NEW_GUAC_VERSION}/guacamole-auth-ldap-${NEW_GUAC_VERSION}.jar /etc/guacamole/extensions/ &>>${LOG_LOCATION}
        echo -e "${LGREEN}Upgraded LDAP extension to version ${NEW_GUAC_VERSION}${GREY}"
        echo
        break
    fi
done

# Check for TOTP extension and upgrade if found
for file in /etc/guacamole/extensions/guacamole-auth-totp*.jar; do
    if [[ -f $file ]]; then
        echo -e "${LGREEN}TOTP authentication extension was found, upgrading...${GREY}"
        rm /etc/guacamole/extensions/guacamole-auth-totp*.jar &>>${LOG_LOCATION}
        wget -q --show-progress -O guacamole-auth-totp-${NEW_GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-totp-${NEW_GUAC_VERSION}.tar.gz
        if [ $? -ne 0 ]; then
            echo -e "${LRED}Failed to download guacamole-auth-totp-${NEW_GUAC_VERSION}.tar.gz" 1>&2
            echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-totp-${NEW_GUAC_VERSION}.tar.gz"
            exit 1
        fi
        tar -xzf guacamole-auth-totp-${NEW_GUAC_VERSION}.tar.gz &>>${LOG_LOCATION}
        mv -f guacamole-auth-totp-${NEW_GUAC_VERSION}/guacamole-auth-totp-${GUAC_VERSION}.jar /etc/guacamole/extensions/ &>>${LOG_LOCATION}
        echo -e "${LGREEN}Upgraded TOTP extension to version ${NEW_GUAC_VERSION}${GREY}"
        echo
        break
    fi
done

# Fix for #196 see https://github.com/MysticRyuujin/guac-install/issues/196
mkdir -p /usr/sbin/.config/freerdp
chown daemon:daemon /usr/sbin/.config/freerdp

# Fix for #197 see https://github.com/MysticRyuujin/guac-install/issues/197
mkdir -p /var/guacamole
chown daemon:daemon /var/guacamole

# Bring guacd and Tomcat back up
echo -e "${GREY}Starting guacd and Tomcat services..."
systemctl enable guacd
systemctl start guacd
systemctl start ${TOMCAT_VERSION}
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Cleanup
echo -e "${GREY}Cleanup install files...${GREY}"
rm -rf guacamole-*
unset MYSQL_PWD
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Done
printf "${LGREEN}Guacamole ${NEW_GUAC_VERSION} upgrade complete! \n${NC}"
echo -e ${NC}
