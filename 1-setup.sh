#!/bin/bash
######################################################################################################################
# Guacamole appliance setup script
# For Ubuntu / Debian / Raspian
# David Harrop
# April 2023
#######################################################################################################################

# To install latest snapshot:
# wget https://raw.githubusercontent.com/itiligent/Guacamole-Setup/main/1-setup.sh && chmod +x 1-setup.sh && ./1-setup.sh

# If something isn't working? # tail -f /var/log/syslog /var/log/tomcat*/*.out /var/log/mysql/*.log

# This whole install routine could be collated into one huge script, but it is far easer to manage and maintan by
# breaking up the different stages of the install into at least 4 separate scripts as follows...
# 1-setup.sh is a central script that manages all inputs, options and sequences other included 'install' scripts.
# 2-install-guacamole is the main guts of the whole build. This script downloads and builds Guacamole from source.
# 3-install-nginx.sh automatically installs and configues Nginx to work as an http port 80 front end to Gaucamole
# 4a-install-self-signed-nginx.sh sets up the new Nginx/Guacamole front end with self signed SSL certificates.
# 4b-install-ssl-letsencrypt-nginx.sh sets up Nginx with public SSL certificates from LetsEncrypt.

clear

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

# Check to see if previous build/install files exist, stop and check to be safe.
if [ "$( find . -maxdepth 1 \( -name 'guacamole-*' -o -name 'mysql-connector-java-*' \) )" != "" ]; then
# Script branding header
echo
	echo -e "${GREYB}Itiligent Jump Server Appliance Setup."
	echo -e "                    ${LGREEN}Powered by Guacamole"
	echo
	echo
	echo -e "${RED}Possible previous temp files detected in current build path. Please review and remove old 'guacamole-*' & 'mysql-connector-java-*' files before proceeding.${GREY}" 1>&2
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
GUAC_VERSION="1.5.1"

# Set preferred Apache CDN download link
GUAC_SOURCE_LINK="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VERSION}"

# MySQL Connector/J version
MYSQLJCON="8.0.30"

# Apache Tomcat version. You will need to check the correct version for your particular distro.
TOMCAT_VERSION="tomcat9"

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

# We need to try and grab a default value for the local FQDN. Domain search suffix is used in this case because
# this is the simplest common default resolv.conf value available between recent Debian and Ubuntu flavours. YMMV.
DOMAIN_SEARCH_SUFFIX=$(grep search /etc/resolv.conf | grep -v "#" | sed  's/'search[[:space:]]'//')
DEFAULT_FQDN=$HOSTNAME.$DOMAIN_SEARCH_SUFFIX

#######################################################################################################################
# Silent setup options - adding true/false or specific values below prevents prompt at install ########################
#######################################################################################################################
SERVER_NAME=""						# Preferred server hostname
INSTALL_MYSQL=""					# Install locally true/false
SECURE_MYSQL=""						# Apply mysql secure configurarion tool
MYSQL_HOST=""						# leave blank for localhost default, only specify for remote servers
MYSQL_PORT=""						# If blank default is 3306
GUAC_DB=""							# If blank default is guacamole_db
GUAC_USER=""						# if blank default is guacamole_user
GUAC_PWD=""							# Should not be blank as this may break some aspects of install
MYSQL_ROOT_PWD=""					# Should not be blank as this may break some aspects of install
INSTALL_TOTP=""						# TOTP MFA extension
INSTALL_DUO=""						# DUO MFA extension (cant be installed simultaneously with TOTP)
INSTALL_LDAP=""						# Active Directory extension
INSTALL_NGINX=""					# Install and configure Guacamole behind Nginx reverse proxy (http port 80 only)
PROXY_SITE=""						# Local DNS name for reverse proxy and self signed ssl certificates
SELF_SIGN=""						# Add self signed SSL support to Nginx (Let's Encrypt not available)
CERT_COUNTRY="AU"					# 2 coutry charater code only, must not be blank
CERT_STATE="Victoria"				# Optional to change, must not be blank
CERT_LOCATION="Melbourne"			# Optional to change, must not be blank
CERT_ORG="Itiligent"				# Optional to change, must not be blank
CERT_OU="I.T."						# Optional to change, must not be blank
CERT_DAYS="3650"					# Number of days until self signed certificate expiry
LETS_ENCRYPT=""						# Add Lets Encrypt public SSL support for Nginx (self signed SSL certs not available)
LE_DNS_NAME="public.yourdomain.com"	# Public DNS name to bind with Lets Encrypt certificates
LE_EMAIL="webmaster@yourdomain.com"	# Webmaster/admin email for Lets Encrypt
EMAIL_DOMAIN="yourdomain.com"		# Email relay domain for backup notifications
ALERT_EMAIL="alerts@domain.com"		# Email address for backup notifications
BACKUP_RETENTION="30"				# How many days to keep backups for

# Script branding header
echo
echo -e "${GREYB}Itiligent Jump Server Appliance Setup."
echo -e "                    ${LGREEN}Powered by Guacamole"
echo

# Setup directory locations
mkdir -p $DOWNLOAD_DIR
mkdir -p $DB_BACKUP_DIR
mkdir -p $TMP_DIR

#######################################################################################################################
# Download github setup scripts. To prevent overwrite, comment out lines of any scripts you have edited. ##############
#######################################################################################################################

# Download config scripts and setup items from github
cd $DOWNLOAD_DIR
echo
echo -e "${GREY}Downloading setup files...${DGREY}"
wget -q --show-progress ${GITHUB}2-install-guacamole.sh -O 2-install-guacamole.sh
wget -q --show-progress ${GITHUB}3-install-nginx.sh -O 3-install-nginx.sh
wget -q --show-progress ${GITHUB}4a-install-ssl-self-signed-nginx.sh -O 4a-install-ssl-self-signed-nginx.sh
wget -q --show-progress ${GITHUB}4b-install-ssl-letsencrypt-nginx.sh -O 4b-install-ssl-letsencrypt-nginx.sh

# Grab Guacamole auth extension config scripts
wget -q --show-progress ${GITHUB}add-auth-duo.sh -O add-auth-duo.sh
wget -q --show-progress ${GITHUB}add-auth-ldap.sh -O add-auth-ldap.sh
wget -q --show-progress ${GITHUB}add-auth-totp.sh -O add-auth-totp.sh


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
echo -e "${GREYB}Itiligent Jump Server Appliance Setup."
echo -e "                    ${LGREEN}Powered by Guacamole"
echo
echo

# For convenience & sanity check, diplay status of preset script options at start of install
echo -e "${GREY}Enabled non-interactive presets are listed below, blank entries will prompt."
echo -e "${DGREY}Server host name\t= ${GREY}${SERVER_NAME}"
echo -e "${DGREY}Install MYSQL locally\t= ${GREY}${INSTALL_MYSQL}"
echo -e "${DGREY}MySQL secure install\t= ${GREY}${SECURE_MYSQL}"
echo -e "${DGREY}MySQL remote IP\t\t= ${GREY}${MYSQL_HOST}"
echo -e "${DGREY}MySQL port\t\t= ${GREY}${MYSQL_PORT}"
echo -e "${DGREY}Guacamole db name\t= ${GREY}${GUAC_DB}"
echo -e "${DGREY}Guacamole db user name\t= ${GREY}${GUAC_USER}"
echo -e "${DGREY}Guacamole user pwd\t= ${GREY}${GUAC_PWD}"
echo -e "${DGREY}MySQL root pwd\t\t= ${GREY}${MYSQL_ROOT_PWD}"
echo -e "${DGREY}Add TOTP\t\t= ${GREY}${INSTALL_TOTP}"
echo -e "${DGREY}Add DUO\t\t\t= ${GREY}${INSTALL_DUO}"
echo -e "${DGREY}Add LDAP\t\t= ${GREY}${INSTALL_LDAP}${GREY}"
echo -e "${DGREY}Install Nginx rev proxy\t= ${GREY}${INSTALL_NGINX}${GREY}"
echo -e "${DGREY}Proxy local DNS name\t= ${GREY}${PROXY_SITE}"
echo -e "${DGREY}Add self signed SSL\t= ${GREY}${SELF_SIGN}${GREY}"
echo -e "${DGREY}Self sign cert days\t= ${GREY}${CERT_DAYS}${GREY}"
echo -e "${DGREY}Self sign country\t= ${GREY}${CERT_COUNTRY}${GREY}"
echo -e "${DGREY}Self sign state\t\t= ${GREY}${CERT_STATE}${GREY}"
echo -e "${DGREY}Self sign location\t= ${GREY}${CERT_LOCATION}${GREY}"
echo -e "${DGREY}Self sign ORG\t\t= ${GREY}${CERT_ORG}${GREY}"
echo -e "${DGREY}Self sign OU\t\t= ${GREY}${CERT_OU}${GREY}"
echo -e "${DGREY}Add Let's Encrypt SSL\t= ${GREY}${LETS_ENCRYPT}${GREY}"
echo -e	"${DGREY}Let's Encrypt FQDN\t= ${GREY}${LE_DNS_NAME}${GREY}"
echo -e "${DGREY}Let's Encrypt email\t= ${GREY}${LE_EMAIL}${GREY}"
echo -e "${DGREY}SMTP relay domain\t= ${GREY}${EMAIL_DOMAIN}${GREY}"
echo -e "${DGREY}Alerts email address\t= ${GREY}${ALERT_EMAIL}${GREY}"
echo -e "${DGREY}Days to keep backups\t= ${GREY}${BACKUP_RETENTION}${GREY}"

# Pause to optionally customise downloaded scripts before any install actions
echo
echo -e "${LYELLOW}Ctrl+Z now to exit if you wish to set any above options for an unattended install."
echo -e "${LYELLOW}After editing the setup script, you must always run it locally (not as sudo) i.e ./1-setup.sh (not from the web link)."

# Now prompt for sudo to get ready for a hostname change or so both sudo and non sudo functions can access tmp setup files
echo -e "${LGREEN}"
sudo chmod -R 770 $TMP_DIR
sudo chown -R $SUDO_USER:root $TMP_DIR


#######################################################################################################################
# Begin install menu prompts ##########################################################################################
#######################################################################################################################

# We need a default hostname avaiable to apply even if we do not want to change the hostname. This approach allows the
# user to simply hit enter at the prompt without this creating a blank entry into the /etc/hosts file.
# Hostnames and matching DNS entries are essential for implementing SSL succesfully.
echo
if [[ -z ${SERVER_NAME} ]]; then
	echo -e "${LYELLOW}Update Linux system HOSTNAME [Enter to keep: ${HOSTNAME}]${LGREEN}"
	read -p "                        Enter new HOSTNAME : " SERVER_NAME
	if [[ "${SERVER_NAME}" = "" ]]; then
		SERVER_NAME=$HOSTNAME
		echo
		sudo hostnamectl set-hostname $SERVER_NAME &>> ${LOG_LOCATION}
		sudo sed -i '/127.0.1.1/d' /etc/hosts &>> ${LOG_LOCATION}
		echo '127.0.1.1       '${SERVER_NAME}'' | sudo tee -a /etc/hosts &>> ${LOG_LOCATION}
		sudo systemctl restart systemd-hostnamed &>> ${LOG_LOCATION}
		else
		echo
		sudo hostnamectl set-hostname $SERVER_NAME &>> ${LOG_LOCATION}
		sudo sed -i '/127.0.1.1/d' /etc/hosts &>> ${LOG_LOCATION}
		echo '127.0.1.1       '${SERVER_NAME}'' | sudo tee -a /etc/hosts &>> ${LOG_LOCATION}
		sudo systemctl restart systemd-hostnamed &>> ${LOG_LOCATION}
	fi
fi

clear

# Script branding header
echo
echo -e "${GREYB}Itiligent Jump Server Appliance Setup."
echo -e "                    ${LGREEN}Powered by Guacamole"
echo
echo

# Prompt the user to install MySQL, default of yes
if [[ -z ${INSTALL_MYSQL} ]]; then
	echo -e -n "${LGREEN}SQL: Install MySQL? (for a remote MySQL Server select 'n') (y/n) [default y]: ${GREY}"
	read PROMPT
	if [[ ${PROMPT} =~ ^[Nn]$ ]]; then
	INSTALL_MYSQL=false
	else
	INSTALL_MYSQL=true
	fi
fi

# Prompt the user to apply the Mysql secure installation locally
if [ -z ${SECURE_MYSQL} ] && [ "${INSTALL_MYSQL}" = true ]; then
	echo -e -n "${GREY}SQL: Apply MySQL secure installation settings to LOCAL db? (y/n) [default y]: ${GREY}"
	read PROMPT
	if [[ ${PROMPT} =~ ^[Nn]$ ]]; then
	SECURE_MYSQL=false
	else
	SECURE_MYSQL=true
	fi
fi

# Prompt the user to apply the Mysql secure installation to remote db
if [ -z ${SECURE_MYSQL} ] && [ "${INSTALL_MYSQL}" = false ]; then
	echo -e -n "${GREY}SQL: Apply MySQL secure installation settings to REMOTE db? (y/n) [default n]: ${GREY}"
	read PROMPT
	if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
	SECURE_MYSQL=true
	else
	SECURE_MYSQL=false
	fi
fi

# We need to get some additional MYSQL values
if [ "${INSTALL_MYSQL}" = false ]; then
	[ -z "${MYSQL_HOST}" ] \
	&& read -p "SQL: Enter MySQL server hostname or IP: " MYSQL_HOST
	[ -z "${MYSQL_PORT}" ] \
	&& read -p "SQL: Enter MySQL server port [3306]: " MYSQL_PORT
	[ -z "${GUAC_DB}" ] \
	&& read -p "SQL: Enter Guacamole database name [guacamole_db]: " GUAC_DB
	[ -z "${GUAC_USER}" ] \
	&& read -p "SQL: Enter Guacamole user name [guacamole_user]: " GUAC_USER
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
	echo -e "${RED}Passwords don't match or can't be null. Please try again.${GREY}" 1>&2
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
	echo -e "${RED}Passwords don't match or can't be null. Please try again.${GREY}" 1>&2
	done
fi

# Prompt the user if they would like to install TOTP MFA, default of no
if [[ -z "${INSTALL_TOTP}" ]] && [[ "${INSTALL_DUO}" != true ]]; then
	echo -e -n "${GREY}GUAC MFA: Install TOTP? (choose 'n' if you want Duo) (y/n)? [default n]: "
	read PROMPT
	if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
	INSTALL_TOTP=true
	INSTALL_DUO=false
	else
	INSTALL_TOTP=false
	fi
fi

# Prompt the user if they would like to install Duo MFA, default of no
if [[ -z "${INSTALL_DUO}" ]] && [[ "${INSTALL_TOTP}" != true ]]; then
	echo -e -n "${GREY}GUAC MFA: Install Duo? (y/n) [default n]: "
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
	echo -e "${RED}GUAC MFA: TOTP and Duo cannot be installed at the same time.${GREY}" 1>&2
	exit 1
fi

# Prompt the user if they would like to install Duo MFA, default of no
if [[ -z "${INSTALL_LDAP}" ]]; then
	echo -e -n "${GREY}GUAC AUTH: Install LDAP? (y/n) [default n]: "
	read PROMPT
	if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
	INSTALL_LDAP=true
	else
	INSTALL_LDAP=false
	fi
fi

# Prompt for Guacamole front end reverse proxy option
if [[ -z ${INSTALL_NGINX} ]]; then
	echo -e -n "${LGREEN}ADD REVERSE PROXY?: Protect Gucamole behind Nginx reverse proxy (y/n)? [default y]: ${GREY}"
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
	read -p "REVERSE PROXY NAME?: Enter proxy local DNS name? [Enter to use ${DEFAULT_FQDN}]: " PROXY_SITE
	[ "${PROXY_SITE}" = "" ] || [ "${PROXY_SITE}" != "" ] && break
	# rather than allow any default, alternately force user to enter an explicit name instead
	# [ "${PROXY_SITE}" != "" ] && break
	# echo -e "${RED}You must enter a proxy site DNS name. Please try again.${GREY}" 1>&2
	done
fi

# If no proxy site dns name is given, lets assume a default FQDN
if [ -z "${PROXY_SITE}" ]; then
PROXY_SITE="${DEFAULT_FQDN}"
fi

# Prompt for self signed SSL reverse proxy option
if [[ -z ${SELF_SIGN} ]] && [[ "${INSTALL_NGINX}" = true ]]; then
	# Prompt the user to see if they would like to install self signed SSL support for Nginx, default of no
	echo -e -n "${GREY}PROXY SSL?: Add self signed SSL support to Nginx? (y/n)? (choose 'n' for Let's Encrypt)[default n]: "
	read PROMPT
	if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
	SELF_SIGN=true
	else
	SELF_SIGN=false
	fi
fi

# Optional prompt to assign the self sign SSL certficate a custom expiry date, uncomment to force a manual entry
#if [ "${SELF_SIGN}" = true ]; then
#	read - p "PROXY: Enter number of days till SSL certificate expires [default 3650]: " CERT_DAYS
#fi

# If no self sign SSL certificate expiry given, lets assume a generous 10 year default certificate expiry
if [ -z "${CERT_DAYS}" ]; then
	CERT_DAYS="3650"
fi

# Prompt for Let's Encrypt SSL reverse proxy configuration option
if [[ -z ${LETS_ENCRYPT} ]] && [[ "${INSTALL_NGINX}" = true ]] && [[ "${SELF_SIGN}" = "false" ]]; then
	echo -e -n "${GREY}SSL PROXY: Add Let's Encrypt SSL support to Nginx reverse proxy (y/n) [default n]: ${GREY}"
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
	read -p "Enter the FQDN for your public proxy site : " LE_DNS_NAME
	[ "${LE_DNS_NAME}" != "" ] && break
	echo -e "${RED}You must enter a public DNS name. Please try again.${GREY}" 1>&2
	done
fi

# Prompt for Let's Encrypt admin email
if [[ -z ${LE_EMAIL} ]] && [[ "${LETS_ENCRYPT}" = true ]]; then
	while true; do
	read -p "Enter the email address for Let's Encrypt notifications : " LE_EMAIL
	[ "${LE_EMAIL}" != "" ] && break
	echo -e "${RED}You must enter an email address. Please try again.${GREY}" 1>&2
	done
fi


#######################################################################################################################
# Start global setup actions  #########################################################################################
#######################################################################################################################

# Ubuntu and Debian each require different dependency packages. Below works ok from Ubuntu 18.04 / Debian 10 and above.
# To adapt this script to other distros, research the correct library package names and reference these with the varible 
# names assigned here. See https://guacamole.apache.org/doc/gug/installing-guacamole.html for dependecy info.
echo -e "${GREY}Checking linux distro specific dependencies..."
if [[ $OS_FLAVOUR == "ubuntu" ]] || [[ $OS_FLAVOUR == "ubuntu"* ]]; then # potentially expand out distro choices here
	JPEGTURBO="libjpeg-turbo8-dev"
	LIBPNG="libpng-dev"
	sudo add-apt-repository -y universe &>> ${LOG_LOCATION}
	elif [[ $OS_FLAVOUR == "debian" ]] || [[ $OS_FLAVOUR == "raspbian" ]] ; then # expand distro choices here if req
	JPEGTURBO="libjpeg62-turbo-dev"
	LIBPNG="libpng-dev"
fi
if [ $? -ne 0 ]; then
	echo -e "${RED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
else
	echo -e "${LGREEN}OK${GREY}"
fi

# Because the below scripts may be run manually after install, we need to sync them
# with our global variables or any setup prompt choices we make. This way we can run them
# later and they will all work as a set without any manual changes.
sed -i "s|MYSQL_HOST=|MYSQL_HOST='${MYSQL_HOST}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|MYSQL_PORT=|MYSQL_PORT='${MYSQL_PORT}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|GUAC_USER=|GUAC_USER='${GUAC_USER}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|GUAC_PWD=|GUAC_PWD='${GUAC_PWD}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|GUAC_DB=|GUAC_DB='${GUAC_DB}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|DB_BACKUP_DIR=|DB_BACKUP_DIR='${DB_BACKUP_DIR}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|ALERT_EMAIL=|ALERT_EMAIL='${ALERT_EMAIL}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|BACKUP_RETENTION=|BACKUP_RETENTION='${BACKUP_RETENTION}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|GUAC_VERSION=|GUAC_VERSION='${GUAC_VERSION}'|g" $DOWNLOAD_DIR/add-auth-duo.sh
sed -i "s|GUAC_VERSION=|GUAC_VERSION='${GUAC_VERSION}'|g" $DOWNLOAD_DIR/add-auth-ldap.sh
sed -i "s|GUAC_VERSION=|GUAC_VERSION='${GUAC_VERSION}'|g" $DOWNLOAD_DIR/add-auth-totp.sh
sed -i "s|TOMCAT_VERSION=|TOMCAT_VERSION='${TOMCAT_VERSION}'|g" $DOWNLOAD_DIR/add-auth-duo.sh
sed -i "s|TOMCAT_VERSION=|TOMCAT_VERSION='${TOMCAT_VERSION}'|g" $DOWNLOAD_DIR/add-auth-ldap.sh
sed -i "s|TOMCAT_VERSION=|TOMCAT_VERSION='${TOMCAT_VERSION}'|g" $DOWNLOAD_DIR/add-auth-totp.sh
sed -i "s|TOMCAT_VERSION=|TOMCAT_VERSION='${TOMCAT_VERSION}'|g" $DOWNLOAD_DIR/add-fail2ban.sh
sed -i "s|CERT_COUNTRY=|CERT_COUNTRY='${CERT_COUNTRY}'|g" $DOWNLOAD_DIR/add-ssl-guac-gaucd.sh
sed -i "s|CERT_STATE=|CERT_STATE='${CERT_STATE}'|g" $DOWNLOAD_DIR/add-ssl-guac-gaucd.sh
sed -i "s|CERT_LOCATION=|CERT_LOCATION='${CERT_LOCATION=}'|g" $DOWNLOAD_DIR/add-ssl-guac-gaucd.sh
sed -i "s|CERT_ORG=|CERT_ORG='${CERT_ORG}'|g" $DOWNLOAD_DIR/add-ssl-guac-gaucd.sh
sed -i "s|CERT_OU=|CERT_OU='${CERT_OU}'|g" $DOWNLOAD_DIR/add-ssl-guac-gaucd.sh
# As dynamic web links may contain "&" characters, GUAC_SOURCE_LINK is fixed to parse "&" with sed correctly
FIXED_LINK=$(sed 's/\&/\\&/g' <<< $GUAC_SOURCE_LINK)
sed -i "s|GUAC_SOURCE_LINK=|GUAC_SOURCE_LINK='${FIXED_LINK}'|g" $DOWNLOAD_DIR/add-auth-duo.sh
sed -i "s|GUAC_SOURCE_LINK=|GUAC_SOURCE_LINK='${FIXED_LINK}'|g" $DOWNLOAD_DIR/add-auth-ldap.sh
sed -i "s|GUAC_SOURCE_LINK=|GUAC_SOURCE_LINK='${FIXED_LINK}'|g" $DOWNLOAD_DIR/add-auth-totp.sh

# Pass the relevant variable selections to child install scripts below
# (This is a more robust method than export, which is unreliable in this instance)
COLOUR_VAR="GREY=$GREY DGREY=$DGREY GREYB=$GREYB RED=$RED LRED=$LRED GREEN=$GREEN LGREEN=$LGREEN YELLOW=$YELLOW LYELLOW=$LYELLOW BLUE=$BLUE LBLUE=$LBLUECYAN=$CYAN LCYAN=$LCYAN MAGENTA=$MAGENTA LMAGENTA=$LMAGENTA NC=$NC"
GUAC_VAR="JPEGTURBO=$JPEGTURBO LIBPNG=$LIBPNG GUAC_VERSION=$GUAC_VERSION MYSQLJCON=$MYSQLJCON GUAC_SOURCE_LINK=$GUAC_SOURCE_LINK TOMCAT_VERSION=$TOMCAT_VERSION LOG_LOCATION=$LOG_LOCATION INSTALL_MYSQL=$INSTALL_MYSQL SECURE_MYSQL=$SECURE_MYSQL MYSQL_HOST=$MYSQL_HOST MYSQL_PORT=$MYSQL_PORT GUAC_DB=$GUAC_DB GUAC_USER=$GUAC_USER GUAC_PWD=$GUAC_PWD MYSQL_ROOT_PWD=$MYSQL_ROOT_PWD INSTALL_TOTP=$INSTALL_TOTP INSTALL_DUO=$INSTALL_DUO INSTALL_LDAP=$INSTALL_LDAP EMAIL_DOMAIN=$EMAIL_DOMAIN"
NGINX_VAR="TOMCAT_VERSION=$TOMCAT_VERSION LOG_LOCATION=$LOG_LOCATION GUAC_URL=$GUAC_URL PROXY_SITE=$PROXY_SITE"
SELF_SIGN_VAR="DOWNLOAD_DIR=$DOWNLOAD_DIR TMP_DIR=$TMP_DIR TOMCAT_VERSION=$TOMCAT_VERSION LOG_LOCATION=$LOG_LOCATION GUAC_URL=$GUAC_URL PROXY_SITE=$PROXY_SITE CERT_COUNTRY=$CERT_COUNTRY CERT_STATE=$CERT_STATE CERT_LOCATION=$CERT_LOCATION CERT_ORG=$CERT_ORG CERT_OU=$CERT_OU" 
LE_VAR="DOWNLOAD_DIR=$DOWNLOAD_DIR TOMCAT_VERSION=$TOMCAT_VERSION LOG_LOCATION=$LOG_LOCATION PROXY_SITE=$PROXY_SITE GUAC_URL=$GUAC_URL LE_DNS_NAME=$LE_DNS_NAME LE_EMAIL=$LE_EMAIL"

# Run the Guacamole install script
sudo $GUAC_VAR $COLOUR_VAR ./2-install-guacamole.sh
if [ $? -ne 0 ]; then
	echo -e "${RED}2-install-guacamole.sh FAILED. See ${LOG_LOCATION}${GREY}" 1>&2
	exit 1
	else
	echo -e "${LGREEN}Guacamole installation complete\n- Visit: http://${PROXY_SITE}:8080/guacamole\n- Default login (user/pass): guacadmin/guacadmin\n${LYELLOW}***Be sure to change the password***.${GREY}"
fi

# Duo Settings reminder - If Duo is selected you can't login to Guacamole at all until this extension is fully configured
if [ $INSTALL_DUO == "true" ]; then
	echo -e "${YELLOW}Reminder: Duo requires extra account specific config before you can log in to Guacamole."
	echo -e "See https://guacamole.apache.org/doc/${GUAC_VERSION}/gug/duo-auth.html"
fi

# Add a Guacamole database backup (mon-fri 12:00am) into cron
crontab -l > cron_1 > /dev/null 2>&1
	# Remove existing entry to allow multiple runs
	sed -i '/# backup guacamole/d' cron_1
	# Create the job
	echo "0 0 * * 1-5 ${DOWNLOAD_DIR}/backup-guac.sh # backup guacamole" >> cron_1
# Overwrite the cron settings and cleanup
crontab cron_1 > /dev/null 2>&1
rm cron_1


#######################################################################################################################
# Start optional setup actions   ######################################################################################
#######################################################################################################################

### Install Nginx reverse proxy front end to Guacamole if option is selected
if [ "${INSTALL_NGINX}" = true ]; then
	sudo $NGINX_VAR $COLOUR_VAR ./3-install-nginx.sh 
	echo -e "${LGREEN}Nginx installation complete\n- Site changed to : http://${PROXY_SITE}\n- Default login (user/pass): guacadmin/guacadmin\n${LYELLOW}***Be sure to change the password***.${GREY}"
	fi


### Apply self signed SSL certificates to Nginx reverse proxy if option is selected
if [[ "${INSTALL_NGINX}" = true ]] && [[ "${SELF_SIGN}" = true ]]; then
	sudo -E $SELF_SIGN_VAR $COLOUR_VAR ./4a-install-ssl-self-signed-nginx.sh ${PROXY_SITE} ${CERT_DAYS} 
echo -e "${LGREEN}Self signed certificates successfully created and configured for Nginx \n- Site changed to : ${LYELLOW}https:${LGREEN}//${PROXY_SITE}\n- Default login (user/pass): guacadmin/guacadmin\n${LYELLOW}***Be sure to change the password***.${GREY}"
fi


### Apply Let's Encrypt SSL certificates to Nginx reverse proxy if option is selected
if [[ "${INSTALL_NGINX}" = true ]] && [[ "${LETS_ENCRYPT}" = true ]]; then
	sudo -E $LE_VAR $COLOUR_VAR ./4b-install-ssl-letsencrypt-nginx.sh 
echo -e "${LGREEN}Let's Encrypt SSL successfully configured for Nginx \n- Site changed to : ${LYELLOW}https:${LGREEN}//${LE_DNS_NAME}\n- Default login (user/pass): guacadmin/guacadmin\n${LYELLOW}***Be sure to change the password***.${GREY}"
fi


# Final tidy up
echo
echo -e "${LGREEN}1-setup.sh was moved to ${USER_HOME_DIR}/guac-setup."
mv $USER_HOME_DIR/1-setup.sh $DOWNLOAD_DIR
sudo rm -R $TMP_DIR

# Done
echo
printf "${LGREEN}Guacamole ${GUAC_VERSION} install complete! \n${NC}"
echo -e ${NC}
