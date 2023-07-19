#!/bin/bash
######################################################################################################################
# Guacamole appliance setup script
# For Ubuntu / Debian / Raspbian
# David Harrop
# April 2023
#######################################################################################################################

# To install latest snapshot:
# wget https://raw.githubusercontent.com/itiligent/Guacamole-Setup/main/1-setup.sh && chmod +x 1-setup.sh && ./1-setup.sh

# If something isn't working?
# tail -f /var/log/syslog /var/log/tomcat*/*.out /var/log/mysql/*.log guac-setup/guacamole_${GUAC_VERSION}_setup.log

# This whole install routine could be collated into one huge script, but it is far easier to manage and maintain by
# breaking up the different stages of the install into at least 4 separate scripts as follows...
# 1-setup.sh is a central script that manages all inputs, options and sequences other included 'install' scripts.
# 2-install-guacamole is the main guts of the whole build. This script downloads and builds Guacamole from source.
# 3-install-nginx.sh automatically installs and configures Nginx to work as an http port 80 front end to Guacamole
# 4a-install-self-signed-nginx.sh sets up the new Nginx/Guacamole front end with self signed SSL certificates.
# 4b-install-ssl-letsencrypt-nginx.sh sets up Nginx with public SSL certificates from LetsEncrypt.
# Scripts with "add" in their name can be run post guacamole setup to add optional features not included in the main install

clear

# Prepare text output colours
GREY='\033[0;37m'
DGREY='\033[0;90m'
GREYB='\033[1;37m'
LRED='\033[0;91m'
LGREEN='\033[0;92m'
LYELLOW='\033[0;93m'
NC='\033[0m' #No Colour

if [[ $EUID -eq 0 ]]; then
    echo
    echo -e "${LRED}This script must NOT be run as root" 1>&2
    echo -e ${NC}
    exit 1
fi

# Check to see if previous build/install files exist, stop and check to be safe.
if [ "$(find . -maxdepth 1 \( -name 'guacamole-*' -o -name 'mysql-connector-j-*' \))" != "" ]; then
    # Script branding header
    echo
    echo -e "${GREYB}Itiligent Virtual Desktop Appliance Setup."
    echo -e "                    ${LGREEN}Powered by Guacamole"
    echo
    echo

    echo -e "${LRED}Possible previous temp files detected in current build path. Please review and remove old 'guacamole-*' & 'mysql-connector-j-*' files before proceeding.${GREY}" 1>&2
    echo
    exit 1
fi

#######################################################################################################################
# Core setup ##########################################################################################################
#######################################################################################################################

#Setup download and temp directory paths
USER_HOME_DIR=$(eval echo ~${SUDO_USER})
DOWNLOAD_DIR=$USER_HOME_DIR/guac-setup
DB_BACKUP_DIR=$USER_HOME_DIR/mysqlbackups/
TMP_DIR=$DOWNLOAD_DIR/tmp

# Github download branch
GITHUB="https://raw.githubusercontent.com/itiligent/Guacamole-Setup/main/"

#Version of Guacamole to install
GUAC_VERSION="1.5.2"

# Set preferred Apache CDN download link
GUAC_SOURCE_LINK="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VERSION}"

# MySQL Connector/J version
MYSQLJCON="8.0.33"

# Check for the latest version of Tomcat currently supported by the Linux distro
if [[ $(apt-cache show tomcat10 2>/dev/null | egrep "Version: 10" | wc -l) -gt 0 ]]; then
    TOMCAT_VERSION="tomcat10"
elif [[ $(apt-cache show tomcat9 2>/dev/null | egrep "Version: 9" | wc -l) -gt 0 ]]; then
    TOMCAT_VERSION="tomcat9"
elif [[ $(apt-cache show tomcat8 2>/dev/null | egrep "Version: 8.[5-9]" | wc -l) -gt 0 ]]; then
    TOMCAT_VERSION="tomcat8"
elif [[ $(apt-cache show tomcat7 2>/dev/null | egrep "Version: 8" | wc -l) -gt 0 ]]; then
    TOMCAT_VERSION="tomcat7"
else
    # Default to current version
    TOMCAT_VERSION="tomcat9"
fi
# Override Apache Tomcat version here.
# TOMCAT_VERSION="tomcat9"

# Install log Location
LOG_LOCATION="${DOWNLOAD_DIR}/guacamole_${GUAC_VERSION}_setup.log"

# Guacamole default install URL
GUAC_URL=http://localhost:8080/guacamole/

# Depending on the Linux distro, required libraries have varied names. Standardising with names makes adapting
# to other distros easier.
source /etc/os-release
OS_FLAVOUR=$ID
OS_VERSION=$VERSION
JPEGTURBO=""
LIBPNG=""

# Get the default route interface IP
DEFAULT_IP=$(ip addr show $(ip route | awk '/default/ { print $5 }') | grep "inet" | head -n 1 | awk '/inet/ {print $2}' | cut -d'/' -f1)

# Get an initial dns search suffix for use as a starting default for a local dns domain prompt value, we prompt to update this later
get_domain_suffix() {
    echo "$1" | awk '{print $2}'
}
# Search for "search" and "domain" entries in /etc/resolv.conf
search_line=$(grep -E '^search[[:space:]]+' /etc/resolv.conf)
domain_line=$(grep -E '^domain[[:space:]]+' /etc/resolv.conf)
# Check if both "search" and "domain" lines exist
if [ -n "$search_line" ] && [ -n "$domain_line" ]; then
    # Both "search" and "domain" lines exist, extract the domain suffix from both
    search_suffix=$(get_domain_suffix "$search_line")
    domain_suffix=$(get_domain_suffix "$domain_line")
    # Print the domain suffix that appears first
    if [ ${#search_suffix} -lt ${#domain_suffix} ]; then
        DOMAIN_SUFFIX=$search_suffix
    else
        DOMAIN_SUFFIX=$domain_suffix
    fi
elif [ -n "$search_line" ]; then
    # If only "search" line exists
    DOMAIN_SUFFIX=$(get_domain_suffix "$search_line")
elif [ -n "$domain_line" ]; then
    # If only "domain" line exists
    DOMAIN_SUFFIX=$(get_domain_suffix "$domain_line")
else
    # If no "search" or "domain" lines found
    DOMAIN_SUFFIX="local"
fi

#######################################################################################################################
# Silent setup options - adding true/false or specific values below prevents prompt at install ########################
#######################################################################################################################
SERVER_NAME=""                  # Preferred server hostname
LOCAL_DOMAIN=""                 # Local DNS space in use
INSTALL_MYSQL=""                # Install locally (true/false)
SECURE_MYSQL=""                 # Apply mysql secure configuration tool (true/false)
MYSQL_HOST=""                   # leave blank for localhost default, only specify for remote servers
MYSQL_PORT=""                   # If blank default is 3306
GUAC_DB=""                      # If blank default is guacamole_db
GUAC_USER=""                    # if blank default is guacamole_user
GUAC_PWD=""                     # Should not be blank as this may break some aspects of install
MYSQL_ROOT_PWD=""               # Should not be blank as this may break some aspects of install
INSTALL_TOTP=""                 # TOTP MFA extension (true/false)
INSTALL_DUO=""                  # DUO MFA extension (cant be installed simultaneously with TOTP, true/false)
INSTALL_LDAP=""                 # Active Directory extension (true/false)
INSTALL_NGINX=""                # Install and configure Guacamole behind Nginx reverse proxy (http port 80 only, true/false)
PROXY_SITE=""                   # Local DNS name for reverse proxy and self signed ssl certificates
SELF_SIGN=""                    # Add self signed SSL support to Nginx (Let's Encrypt not available with this, true/false)
CERT_COUNTRY="AU"               # 2 country character code only, must not be blank
CERT_STATE="Victoria"           # Optional to change, must not be blank
CERT_LOCATION="Melbourne"       # Optional to change, must not be blank
CERT_ORG="Itiligent"            # Optional to change, must not be blank
CERT_OU="I.T."                  # Optional to change, must not be blank
CERT_DAYS="3650"                # Number of days until self signed certificate expiry
LETS_ENCRYPT=""                 # Add Lets Encrypt public SSL support for Nginx (self signed SSL certs not available with this, true/false)
LE_DNS_NAME=""                  # Public DNS name to bind with Lets Encrypt certificates
LE_EMAIL=""                     # Webmaster/admin email for Lets Encrypt
BACKUP_EMAIL=""                 # Email address for backup notifications
BACKUP_RETENTION="30"           # How many days to keep backups for
RDP_SHARE_LABEL=""              # Custom system name to show in windows explorer. (eg RDPshare on "ServerName")
RDP_DRIVE_LABEL="RDP Share"     # Custom drive file system label (eg "RDPshare" on ServerName)
RDP_PRINTER_LABEL="RDP Printer" # Custom RDP printer name

# Script branding header
echo
echo -e "${GREYB}Itiligent Virtual Desktop Appliance Setup."
echo -e "                    ${LGREEN}Powered by Guacamole"
echo
echo

# Setup directory locations
mkdir -p $DOWNLOAD_DIR
mkdir -p $DB_BACKUP_DIR
mkdir -p $TMP_DIR

#######################################################################################################################
# Download GitHub setup scripts. To prevent overwrite, comment out lines of any scripts you have edited. ##############
#######################################################################################################################

# Download config scripts and setup items from GitHub
cd $DOWNLOAD_DIR
echo -e "${GREY}Downloading setup files...${DGREY}"
wget -q --show-progress ${GITHUB}2-install-guacamole.sh -O 2-install-guacamole.sh
wget -q --show-progress ${GITHUB}3-install-nginx.sh -O 3-install-nginx.sh
wget -q --show-progress ${GITHUB}4a-install-ssl-self-signed-nginx.sh -O 4a-install-ssl-self-signed-nginx.sh
wget -q --show-progress ${GITHUB}4b-install-ssl-letsencrypt-nginx.sh -O 4b-install-ssl-letsencrypt-nginx.sh
# Grab Guacamole manual add on/upgrade scripts
wget -q --show-progress ${GITHUB}add-auth-duo.sh -O add-auth-duo.sh
wget -q --show-progress ${GITHUB}add-auth-ldap.sh -O add-auth-ldap.sh
wget -q --show-progress ${GITHUB}add-auth-totp.sh -O add-auth-totp.sh
wget -q --show-progress ${GITHUB}add-smtp-relay-o365.sh -O add-smtp-relay-o365.sh
wget -q --show-progress ${GITHUB}upgrade-guac.sh -O upgrade-guac.sh
# Grab backup and security hardening scripts
wget -q --show-progress ${GITHUB}backup-guac.sh -O backup-guac.sh
wget -q --show-progress ${GITHUB}add-ssl-guac-gaucd.sh -O add-ssl-guac-gaucd.sh
wget -q --show-progress ${GITHUB}add-fail2ban.sh -O add-fail2ban.sh
# Grab a (customisable) branding extension
wget -q --show-progress ${GITHUB}branding.jar -O branding.jar
chmod +x *.sh
sleep 2
clear

# Script branding header
echo
echo -e "${GREYB}Itiligent Virtual Desktop Appliance Setup."
echo -e "                    ${LGREEN}Powered by Guacamole"
echo
echo

# Pause to optionally customise downloaded scripts before any actual install actions
echo -e "${LYELLOW}Ctrl+Z now to exit if you wish to edit any 1-setup.sh options for an unattended install."

# Now prompt for sudo to get ready for a hostname change, then while we are here also set perms for sudo and non sudo access to tmp setup files
echo -e "${LGREEN}"
sudo chmod -R 770 $TMP_DIR
sudo chown -R $SUDO_USER:root $TMP_DIR

#######################################################################################################################
# Begin install menu prompts ##########################################################################################
#######################################################################################################################

# We need a default hostname value available to apply even if we do not want to change the hostname. This approach allows the
# user to simply hit enter at the prompt without this creating a blank entry into the /etc/hosts file.
# hostnames and matching DNS entries are essential for implementing SSL successfully.
if [[ -z ${SERVER_NAME} ]]; then
    echo -e "${LYELLOW}Update Linux system HOSTNAME [Enter to keep: ${HOSTNAME}]${LGREEN}"
    read -p "                        Enter new HOSTNAME : " SERVER_NAME
    if [[ "${SERVER_NAME}" = "" ]]; then
        SERVER_NAME=$HOSTNAME
    fi
    echo
    sudo hostnamectl set-hostname $SERVER_NAME &>>${LOG_LOCATION}
    sudo sed -i '/127.0.1.1/d' /etc/hosts &>>${LOG_LOCATION}
    echo '127.0.1.1       '${SERVER_NAME}'' | sudo tee -a /etc/hosts &>>${LOG_LOCATION}
    sudo systemctl restart systemd-hostnamed &>>${LOG_LOCATION}
else
    echo
    sudo hostnamectl set-hostname $SERVER_NAME &>>${LOG_LOCATION}
    sudo sed -i '/127.0.1.1/d' /etc/hosts &>>${LOG_LOCATION}
    echo '127.0.1.1       '${SERVER_NAME}'' | sudo tee -a /etc/hosts &>>${LOG_LOCATION}
    sudo systemctl restart systemd-hostnamed &>>${LOG_LOCATION}
fi

if [[ -z ${LOCAL_DOMAIN} ]]; then
    echo -e "${LYELLOW}Update Linux LOCAL DNS DOMAIN [Enter to keep: ${DOMAIN_SUFFIX}]${LGREEN}"
    read -p "                        Enter FULL LOCAL DOMAIN NAME: " LOCAL_DOMAIN
    if [[ "${LOCAL_DOMAIN}" = "" ]]; then
        LOCAL_DOMAIN=$DOMAIN_SUFFIX
    fi
    echo
    sudo sed -i "/${DEFAULT_IP}/d" /etc/hosts
    sudo sed -i '/domain/d' /etc/resolv.conf
    sudo sed -i '/search/d' /etc/resolv.conf
    # Update the /etc/hosts file with the new domain values
    echo ''${DEFAULT_IP}'	'${SERVER_NAME}.${LOCAL_DOMAIN} ${SERVER_NAME}'' | sudo tee -a /etc/hosts &>>${LOG_LOCATION}
    #Update resolv.conf with new domain and search suffix values
    echo 'domain	'${LOCAL_DOMAIN}'' | sudo tee -a /etc/resolv.conf &>>${LOG_LOCATION}
    echo 'search	'${LOCAL_DOMAIN}'' | sudo tee -a /etc/resolv.conf &>>${LOG_LOCATION}
    sudo systemctl restart systemd-hostnamed &>>${LOG_LOCATION}
else
    echo
    sudo sed -i "/${DEFAULT_IP}/d" /etc/hosts
    sudo sed -i '/domain/d' /etc/resolv.conf
    sudo sed -i '/search/d' /etc/resolv.conf
    # Update the /etc/hosts file with the new domain values
    echo ''${DEFAULT_IP}'	'${SERVER_NAME}.${LOCAL_DOMAIN} ${SERVER_NAME}'' | sudo tee -a /etc/hosts &>>${LOG_LOCATION}
    #Update resolv.conf with new domain and search suffix values
    echo 'domain	'${LOCAL_DOMAIN}'' | sudo tee -a /etc/resolv.conf &>>${LOG_LOCATION}
    echo 'search	'${LOCAL_DOMAIN}'' | sudo tee -a /etc/resolv.conf &>>${LOG_LOCATION}
    sudo systemctl restart systemd-hostnamed &>>${LOG_LOCATION}
fi

# After updating the hostname and domain names, we can now use a refreshed starting value for the local FQDN and Guacamole share label names.
DEFAULT_FQDN=$SERVER_NAME.$LOCAL_DOMAIN
if [[ -z ${RDP_SHARE_LABEL} ]]; then
    RDP_SHARE_LABEL=$SERVER_NAME
fi

clear

# Script branding header
echo
echo -e "${GREYB}Itiligent Virtual Desktop Appliance Setup."
echo -e "                    ${LGREEN}Powered by Guacamole"
echo
echo

# Prompt the user to install MySQL
echo -e "${LGREEN}MySQL setup options:${GREY}"
if [[ -z ${INSTALL_MYSQL} ]]; then
    echo -e -n "SQL: Install MySQL? (for a remote MySQL Server select 'n') [Y/n] [default y]: ${GREY}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Nn]$ ]]; then
        INSTALL_MYSQL=false
    else
        INSTALL_MYSQL=true
    fi
fi

# Prompt the user to apply the Mysql secure installation locally
if [ -z ${SECURE_MYSQL} ] && [ "${INSTALL_MYSQL}" = true ]; then
    echo -e -n "${GREY}SQL: Apply MySQL secure installation settings to LOCAL db? [Y/n] [default y]: ${GREY}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Nn]$ ]]; then
        SECURE_MYSQL=false
    else
        SECURE_MYSQL=true
    fi
fi

# Prompt the user to apply the Mysql secure installation to remote db
if [ -z ${SECURE_MYSQL} ] && [ "${INSTALL_MYSQL}" = false ]; then
    echo -e -n "${GREY}SQL: Apply MySQL secure installation settings to REMOTE db? [y/N] [default n]: ${GREY}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        SECURE_MYSQL=true
    else
        SECURE_MYSQL=false
    fi
fi

# Get additional MYSQL values
if [ "${INSTALL_MYSQL}" = false ]; then
    [ -z "${MYSQL_HOST}" ] &&
        read -p "SQL: Enter MySQL server hostname or IP: " MYSQL_HOST
    [ -z "${MYSQL_PORT}" ] &&
        read -p "SQL: Enter MySQL server port [3306]: " MYSQL_PORT
    [ -z "${GUAC_DB}" ] &&
        read -p "SQL: Enter Guacamole database name [guacamole_db]: " GUAC_DB
    [ -z "${GUAC_USER}" ] &&
        read -p "SQL: Enter Guacamole user name [guacamole_user]: " GUAC_USER
fi

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

# Get Guacamole User password, confirm correct password entry and prevent blank passwords
if [ -z "${GUAC_PWD}" ]; then
    while true; do
        read -s -p "SQL: Enter ${MYSQL_HOST}'s MySQL ${GUAC_USER} password: " GUAC_PWD
        echo
        read -s -p "SQL: Confirm ${MYSQL_HOST}'s MySQL ${GUAC_USER} password: " PROMPT2
        echo
        [ "${GUAC_PWD}" = "${PROMPT2}" ] && [ "${GUAC_PWD}" != "" ] && [ "${PROMPT2}" != "" ] && break
        echo -e "${LRED}Passwords don't match or can't be null. Please try again.${GREY}" 1>&2
    done
fi

# Get MySQL root password, confirm correct password entry and prevent blank passwords
if [ -z "${MYSQL_ROOT_PWD}" ]; then
    while true; do
        read -s -p "SQL: Enter ${MYSQL_HOST}'s MySQL root password: " MYSQL_ROOT_PWD
        echo
        read -s -p "SQL: Confirm ${MYSQL_HOST}'s MySQL root password: " PROMPT2
        echo
        [ "${MYSQL_ROOT_PWD}" = "${PROMPT2}" ] && [ "${MYSQL_ROOT_PWD}" != "" ] && [ "${PROMPT2}" != "" ] && break
        echo -e "${LRED}Passwords don't match or can't be null. Please try again.${GREY}" 1>&2
    done
fi

# Prompt for preferred backup notification email address
if [[ -z ${BACKUP_EMAIL} ]]; then
    while true; do
        read -p "SQL: Enter email address for SQL backup messages [Enter to skip]: " BACKUP_EMAIL
        [ "${BACKUP_EMAIL}" = "" ] || [ "${BACKUP_EMAIL}" != "" ] && break
        # Rather than allow a blank value, un-comment to alternately force user to enter an explicit value instead
        # [ "${BACKUP_EMAIL}" != "" ] && break
        # echo -e "${LRED}You must enter an email address. Please try again.${GREY}" 1>&2
    done
fi

# If no backup notification email address is given, enter a default value
if [ -z ${BACKUP_EMAIL} ]; then
    BACKUP_EMAIL="backup-email@yourdomain.com"
fi

echo
# Prompt the user if they would like to install TOTP MFA
echo -e "${LGREEN}Guacamole authentication extension options:${GREY}"
if [[ -z "${INSTALL_TOTP}" ]] && [[ "${INSTALL_DUO}" != true ]]; then
    echo -e -n "AUTH: Install TOTP? (choose 'n' if you want Duo) [y/N]? [default n]: "
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        INSTALL_TOTP=true
        INSTALL_DUO=false
    else
        INSTALL_TOTP=false
    fi
fi

# Prompt the user if they would like to install Duo MFA
if [[ -z "${INSTALL_DUO}" ]] && [[ "${INSTALL_TOTP}" != true ]]; then
    echo -e -n "${GREY}AUTH: Install Duo? [y/N] [default n]: "
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        INSTALL_DUO=true
        INSTALL_TOTP=false
    else
        INSTALL_DUO=false
    fi
fi

# We can't install TOTP and Duo at the same time (option not supported by Guacamole)
if [[ "${INSTALL_TOTP}" = true ]] && [[ "${INSTALL_DUO}" = true ]]; then
    echo -e "${LRED}GUAC MFA: TOTP and Duo cannot be installed at the same time.${GREY}" 1>&2
    exit 1
fi

# Prompt the user if they would like to install Duo MFA
if [[ -z "${INSTALL_LDAP}" ]]; then
    echo -e -n "${GREY}AUTH: Install LDAP? [y/N] [default n]: "
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        INSTALL_LDAP=true
    else
        INSTALL_LDAP=false
    fi
fi

echo
# Prompt for Guacamole front end reverse proxy option
echo -e "${LGREEN}Nginx reverse proxy options:${GREY}"
if [[ -z ${INSTALL_NGINX} ]]; then
    echo -e -n "REV PROXY: Protect Guacamole behind Nginx reverse proxy [Y/n]? [default y]: "
    read PROMPT
    if [[ ${PROMPT} =~ ^[Nn]$ ]]; then
        INSTALL_NGINX=false
    else
        INSTALL_NGINX=true
    fi
fi

# We must assign a DNS name for the new proxy site
if [[ -z ${PROXY_SITE} ]] && [[ "${INSTALL_NGINX}" = true ]]; then
    while true; do
        read -p "REV PROXY: Enter proxy local DNS name? [Enter to use ${DEFAULT_FQDN}]: " PROXY_SITE
        [ "${PROXY_SITE}" = "" ] || [ "${PROXY_SITE}" != "" ] && break
        # Rather than allow the default value below, un-comment to alternately force user to enter an explicit name instead
        # [ "${PROXY_SITE}" != "" ] && break
        # echo -e "${LRED}You must enter a proxy site DNS name. Please try again.${GREY}" 1>&2
    done
fi

# If no proxy site dns name is given, lets assume the default FQDN is the proxy site name
if [ -z "${PROXY_SITE}" ]; then
    PROXY_SITE="${DEFAULT_FQDN}"
fi

# Prompt for self signed SSL reverse proxy option
if [[ -z ${SELF_SIGN} ]] && [[ "${INSTALL_NGINX}" = true ]]; then
    # Prompt the user to see if they would like to install self signed SSL support for Nginx, default of no
    echo -e -n "REV PROXY: Add self signed SSL support to Nginx? [y/N]? (choose 'n' for Let's Encrypt)[default n]: "
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        SELF_SIGN=true
    else
        SELF_SIGN=false
    fi
fi

# Optional prompt to assign the self sign SSL certificate a custom expiry date, un-comment to force a manual entry
#if [ "${SELF_SIGN}" = true ]; then
#	read - p "PROXY: Enter number of days till SSL certificate expires [default 3650]: " CERT_DAYS
#fi

# If no self sign SSL certificate expiry given, lets assume a generous 10 year default certificate expiry
if [ -z "${CERT_DAYS}" ]; then
    CERT_DAYS="3650"
fi

# Prompt for Let's Encrypt SSL reverse proxy configuration option
if [[ -z ${LETS_ENCRYPT} ]] && [[ "${INSTALL_NGINX}" = true ]] && [[ "${SELF_SIGN}" = "false" ]]; then
    echo -e -n "REV PROXY: Add Let's Encrypt SSL support to Nginx reverse proxy [y/N] [default n]: ${GREY}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        LETS_ENCRYPT=true
    else
        LETS_ENCRYPT=false
    fi
fi

# Prompt for Let's Encrypt public dns name
if [[ -z ${LE_DNS_NAME} ]] && [[ "${LETS_ENCRYPT}" = true ]]; then
    while true; do
        read -p "REV PROXY: Enter the FQDN for your public proxy site : " LE_DNS_NAME
        [ "${LE_DNS_NAME}" != "" ] && break
        echo -e "${LRED}You must enter a public DNS name. Please try again.${GREY}" 1>&2
    done
fi

# Prompt for Let's Encrypt admin email
if [[ -z ${LE_EMAIL} ]] && [[ "${LETS_ENCRYPT}" = true ]]; then
    while true; do
        read -p "REV PROXY: Enter the email address for Let's Encrypt notifications : " LE_EMAIL
        [ "${LE_EMAIL}" != "" ] && break
        echo -e "${LRED}You must enter an email address. Please try again.${GREY}" 1>&2
    done
fi

#######################################################################################################################
# Start global setup actions  #########################################################################################
#######################################################################################################################

# Ubuntu and Debian each require different dependency packages.
# To adapt this script to other distros, research the correct library package names and reference these with their variable
# names shown here: https://guacamole.apache.org/doc/gug/installing-guacamole.html
clear
echo
echo -e "${GREYB}Itiligent Virtual Desktop Appliance Setup."
echo -e "                    ${LGREEN}Powered by Guacamole"
echo
echo
echo -e "${LGREEN}Beginning Guacamole setup...${GREY}"
echo
echo -e "${GREY}Checking Linux distro specific dependencies..."
if [[ $OS_FLAVOUR == "ubuntu" ]] || [[ $OS_FLAVOUR == "ubuntu"* ]]; then # potentially expand out distro choices here
    JPEGTURBO="libjpeg-turbo8-dev"
    LIBPNG="libpng-dev"
    # Just in case this repo is not added by default in the distro
    sudo add-apt-repository -y universe &>>${LOG_LOCATION}
elif [[ $OS_FLAVOUR == "debian" ]] || [[ $OS_FLAVOUR == "raspbian" ]]; then # expand distro choices here if required
    JPEGTURBO="libjpeg62-turbo-dev"
    LIBPNG="libpng-dev"
fi
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Because the below scripts may be run manually after install, we need to sync them
# with our global variables or any setup prompt choices we made. This way we can run them
# later and they will all work as a set without any manual changes.
sed -i "s|MYSQL_HOST=|MYSQL_HOST='${MYSQL_HOST}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|MYSQL_PORT=|MYSQL_PORT='${MYSQL_PORT}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|GUAC_USER=|GUAC_USER='${GUAC_USER}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|GUAC_PWD=|GUAC_PWD='${GUAC_PWD}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|GUAC_DB=|GUAC_DB='${GUAC_DB}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|DB_BACKUP_DIR=|DB_BACKUP_DIR='${DB_BACKUP_DIR}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|BACKUP_EMAIL=|BACKUP_EMAIL='${BACKUP_EMAIL}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|BACKUP_RETENTION=|BACKUP_RETENTION='${BACKUP_RETENTION}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|CERT_COUNTRY=|CERT_COUNTRY='${CERT_COUNTRY}'|g" $DOWNLOAD_DIR/add-ssl-guac-gaucd.sh
sed -i "s|CERT_STATE=|CERT_STATE='${CERT_STATE}'|g" $DOWNLOAD_DIR/add-ssl-guac-gaucd.sh
sed -i "s|CERT_LOCATION=|CERT_LOCATION='${CERT_LOCATION=}'|g" $DOWNLOAD_DIR/add-ssl-guac-gaucd.sh
sed -i "s|CERT_ORG=|CERT_ORG='${CERT_ORG}'|g" $DOWNLOAD_DIR/add-ssl-guac-gaucd.sh
sed -i "s|CERT_OU=|CERT_OU='${CERT_OU}'|g" $DOWNLOAD_DIR/add-ssl-guac-gaucd.sh

# Export the relevant variable selections to child install scripts
export BACKUP_EMAIL=$BACKUP_EMAIL
export CERT_COUNTRY=$CERT_COUNTRY
export CERT_LOCATION="${CERT_LOCATION}"
export CERT_ORG="${CERT_ORG}"
export CERT_OU="${CERT_OU}"
export CERT_STATE="${CERT_STATE}"
export DOWNLOAD_DIR="${DOWNLOAD_DIR}"
export GUAC_DB=$GUAC_DB
export GUAC_PWD="${GUAC_PWD}"
export GUAC_SOURCE_LINK=$GUAC_SOURCE_LINK
export GUAC_URL=$GUAC_URL
export GUAC_USER=$GUAC_USER
export GUAC_VERSION=$GUAC_VERSION
export INSTALL_DUO=$INSTALL_DUO
export INSTALL_LDAP=$INSTALL_LDAP
export INSTALL_MYSQL=$INSTALL_MYSQL
export INSTALL_TOTP=$INSTALL_TOTP
export JPEGTURBO=$JPEGTURBO
export LE_DNS_NAME=$LE_DNS_NAME
export LE_EMAIL=$LE_EMAIL
export LIBPNG=$LIBPNG
export LOG_LOCATION=$LOG_LOCATION
export MYSQL_HOST=$MYSQL_HOST
export MYSQL_PORT=$MYSQL_PORT
export MYSQL_ROOT_PWD="${MYSQL_ROOT_PWD}"
export MYSQLJCON=$MYSQLJCON
export PROXY_SITE=$PROXY_SITE
export SECURE_MYSQL=$SECURE_MYSQL
export TMP_DIR=$TMP_DIR
export TOMCAT_VERSION=$TOMCAT_VERSION
export RDP_SHARE_LABEL="${RDP_SHARE_LABEL}"
export RDP_DRIVE_LABEL="${RDP_DRIVE_LABEL}"
export RDP_PRINTER_LABEL="${RDP_PRINTER_LABEL}"

# Run the Guacamole install script
sudo -E ./2-install-guacamole.sh
if [ $? -ne 0 ]; then
    echo -e "${LRED}2-install-guacamole.sh FAILED. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}Guacamole install complete\nhttp://${PROXY_SITE}:8080/guacamole - login user/pass: guacadmin/guacadmin\n${LYELLOW}***Be sure to change the password***${GREY}"
fi

# Add a Guacamole database backup (mon-fri 12:00am) into cron
crontab -l >cron_1
# Remove existing entry to allow multiple runs
sed -i '/# backup guacamole/d' cron_1
# Create the job
echo "0 0 * * 1-5 ${DOWNLOAD_DIR}/backup-guac.sh # backup guacamole" >>cron_1
# Overwrite the cron settings and cleanup
crontab cron_1
rm cron_1

#######################################################################################################################
# Start optional setup actions   ######################################################################################
#######################################################################################################################

# Install Nginx reverse proxy front end to Guacamole if option is selected
if [ "${INSTALL_NGINX}" = true ]; then
    sudo -E ./3-install-nginx.sh
    echo -e "${LGREEN}Nginx install complete\nhttp://${PROXY_SITE} - login user/pass: guacadmin/guacadmin\n${LYELLOW}***Be sure to change the password***${GREY}"
fi

# Apply self signed SSL certificates to Nginx reverse proxy if option is selected
if [[ "${INSTALL_NGINX}" = true ]] && [[ "${SELF_SIGN}" = true ]]; then
    sudo -E ./4a-install-ssl-self-signed-nginx.sh ${PROXY_SITE} ${CERT_DAYS}
    echo -e "${LGREEN}Self signed certificate configured for Nginx \n${LYELLOW}https:${LGREEN}//${PROXY_SITE} - login user/pass: guacadmin/guacadmin\n${LYELLOW}***Be sure to change the password***${GREY}"
fi

# Apply Let's Encrypt SSL certificates to Nginx reverse proxy if option is selected
if [[ "${INSTALL_NGINX}" = true ]] && [[ "${LETS_ENCRYPT}" = true ]]; then
    sudo -E ./4b-install-ssl-letsencrypt-nginx.sh
    echo -e "${LGREEN}Let's Encrypt SSL configured for Nginx \n${LYELLOW}https:${LGREEN}//${LE_DNS_NAME} - login user/pass: guacadmin/guacadmin\n${LYELLOW}***Be sure to change the password***${GREY}"
fi

# Duo Settings reminder - If Duo is selected you can't login to Guacamole at all until this extension is fully configured
if [ $INSTALL_DUO == "true" ]; then
    echo
    echo -e "${LYELLOW}Reminder: Duo requires extra account specific info configured in the\n/etc/guacamole/guacamole.properties file before you can log in to Guacamole."
    echo -e "See https://guacamole.apache.org/doc/gug/duo-auth.html"
fi

# LDAP Settings reminder, LDAP auth is not active functional until the config is complete
if [ $INSTALL_LDAP == "true" ]; then
    echo
    echo -e "${LYELLOW}Reminder: LDAP requires that your LDAP directory configuration match the exact format\nadded to the /etc/guacamole/guacamole.properties file before LDAP auth will be active."
    echo -e "See https://guacamole.apache.org/doc/gug/ldap-auth.html"
fi

# Final tidy up
mv $USER_HOME_DIR/1-setup.sh $DOWNLOAD_DIR
sudo rm -R $TMP_DIR

# Done
echo
printf "${LGREEN}Guacamole ${GUAC_VERSION} install complete! \n${NC}"
echo -e ${NC}
