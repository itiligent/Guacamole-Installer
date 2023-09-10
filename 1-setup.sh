#!/bin/bash
######################################################################################################################
# Guacamole appliance setup script
# For Ubuntu / Debian / Raspbian
# David Harrop
# April 2023
#######################################################################################################################

# To install latest code snapshot:
# wget https://raw.githubusercontent.com/itiligent/Guacamole-Install/main/1-setup.sh && chmod +x 1-setup.sh && ./1-setup.sh

# 1-setup.sh is a central script that manages all inputs, options and sequences other included 'install' scripts.
# 2-install-guacamole is the main guts of the whole build. This script downloads and builds Guacamole from source.
# 3-install-nginx.sh automatically installs and configures Nginx to work as an http port 80 front end to Guacamole
# 4a-install-tls-self-signed-nginx.sh sets up the new Nginx/Guacamole front end with self signed TLS certificates.
# 4b-install-tls-letsencrypt-nginx.sh sets up Nginx with public TLS certificates from LetsEncrypt.
# Scripts with "add" in their name can be run post install to add optional features not included in the main install

# If something isn't working:
#     tail -f /var/log/syslog /var/log/tomcat*/*.out guac-setup/guacamole_${GUAC_VERSION}_setup.log
# Or for Guacamole debug mode & verbose logs in the console:
#     sudo systemctl stop guacd && sudo /usr/local/sbin/guacd -L debug -f

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
LMAGENTA='\033[0;95m'
LCYAN='\033[0;96m'
NC='\033[0m' #No Colour

# Make sure the user is NOT running this script as root
if [[ $EUID -eq 0 ]]; then
    echo
    echo -e "${LRED}This script must NOT be run as root, exiting..." 1>&2
    echo -e ${NC}
    exit 1
fi

# Make sure the user is a member of the sudo group
if ! [[ $(id -nG "$USER" 2>/dev/null | egrep "sudo" | wc -l) -gt 0 ]]; then
    echo
    echo -e "${LRED}The current user (${USER}) must be a member of the 'sudo' group, exiting..." 1>&2
    echo -e ${NC}
    exit 1
fi

# Check to see if any previous version of build/install files exist, if so stop and check to be safe.
if [[ "$(find . -maxdepth 1 \( -name 'guacamole-*' -o -name 'mysql-connector-j-*' \))" != "" ]]; then
    echo
    echo -e "${LRED}Possible previous install files detected in current build path. Please review and remove old guacamole install files before proceeding.${GREY}" 1>&2
    echo
    exit 1
fi

#######################################################################################################################
# Core setup variables and mandatory inputs - EDIT VARIABLE VALUES TO SUIT ############################################
#######################################################################################################################

#  Setup download and temp directory paths
USER_HOME_DIR=$(eval echo ~${SUDO_USER})
DOWNLOAD_DIR=$USER_HOME_DIR/guac-setup
DB_BACKUP_DIR=$USER_HOME_DIR/mysqlbackups
TMP_DIR=$DOWNLOAD_DIR/tmp

# GitHub download branch
GITHUB="https://raw.githubusercontent.com/itiligent/Guacamole-Install/main"

# Version of Guacamole to install
GUAC_VERSION="1.5.3"

# MySQL Connector/J version to install
MYSQLJCON="8.1.0"

# Set preferred Apache CDN download link)
GUAC_SOURCE_LINK="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VERSION}"

# See https://mariadb.org/mariadb/all-releases/ for available versions.
# Provide a specific MySQL version e.g. 11.1.2 or leave blank to use distro default MySQL packages.
MYSQL_VERSION=""
if [[ -z "${MYSQL_VERSION}" ]]; then
    # Use Linux distro default version.
    MYSQLSRV="default-mysql-server default-mysql-client mysql-common" # Server
    MYSQLCLIENT="default-mysql-client" # Client
    DB_CMD="mysql" # mysql command is depricated
else
    # Use official mariadb.org repo
    MYSQLSRV="mariadb-server mariadb-client mariadb-common" # Server
    MYSQLCLIENT="mariadb-client" # Client
    DB_CMD="mariadb" # mysql command is depricated on newer versions
fi

# Install log Location
INSTALL_LOG="${DOWNLOAD_DIR}/guacamole_${GUAC_VERSION}_setup.log"

# Guacamole default install URL
GUAC_URL=http://localhost:8080/guacamole/

# Standardised language used for distro versions and dependencies allows a more maintainable approach should distros diverge.
# Here the variables for OS variant and library dependency names are initialised.
source /etc/os-release
OS_FLAVOUR=$ID
OS_VERSION=$VERSION_ID
OS_CODENAME=$VERSION_CODENAME
JPEGTURBO=""
LIBPNG=""

# A default route IP and dns search suffix is needed for initial prompts & default starting values.
# Get the default route interface IP
DEFAULT_IP=$(ip addr show $(ip route | awk '/default/ { print $5 }') | grep "inet" | head -n 1 | awk '/inet/ {print $2}' | cut -d'/' -f1)
get_domain_suffix() {
    echo "$1" | awk '{print $2}'
}
# Search for "search" and "domain" entries in /etc/resolv.conf
search_line=$(grep -E '^search[[:space:]]+' /etc/resolv.conf)
domain_line=$(grep -E '^domain[[:space:]]+' /etc/resolv.conf)
# Check if both "search" and "domain" lines exist
if [[ -n "$search_line" ]] && [[ -n "$domain_line" ]]; then
    # Both "search" and "domain" lines exist, extract the domain suffix from both
    search_suffix=$(get_domain_suffix "$search_line")
    domain_suffix=$(get_domain_suffix "$domain_line")
    # Print the domain suffix that appears first
    if [[ ${#search_suffix} -lt ${#domain_suffix} ]]; then
        DOMAIN_SUFFIX=$search_suffix
    else
        DOMAIN_SUFFIX=$domain_suffix
    fi
elif [[ -n "$search_line" ]]; then
    # If only "search" line exists
    DOMAIN_SUFFIX=$(get_domain_suffix "$search_line")
elif [[ -n "$domain_line" ]]; then
    # If only "domain" line exists
    DOMAIN_SUFFIX=$(get_domain_suffix "$domain_line")
else
    # If no "search" or "domain" lines found
    DOMAIN_SUFFIX="local"
fi

# Setup directory locations
mkdir -p $DOWNLOAD_DIR
mkdir -p $DB_BACKUP_DIR
mkdir -p $TMP_DIR

# Script branding header
echo
echo -e "${GREYB}Guacamole VDI & Jump Server Appliance Setup."
echo -e "              ${LGREEN}Powered by Itiligent"
echo
echo

#######################################################################################################################
# Silent setup options - true/false or specific values below prevents prompt at install. EDIT TO SUIT #################
#######################################################################################################################
SERVER_NAME=""                  # Preferred server hostname
LOCAL_DOMAIN=""                 # Local DNS space in use
INSTALL_MYSQL=""                # Install locally (true/false)
SECURE_MYSQL=""                 # Apply mysql secure configuration tool (true/false)
MYSQL_HOST=""                   # Blank or localhost for a local MySQL install, a specific IP for remote MySQL option.
MYSQL_PORT=""                   # If blank default is 3306
GUAC_DB=""                      # If blank default is guacamole_db
GUAC_USER=""                    # If blank default is guacamole_user
MYSQL_ROOT_PWD=""               # Requires an entry here or at at script prompt.
GUAC_PWD=""                     # Requires an entry here or at at script prompt.
DB_TZ=$(cat /etc/timezone)      # MySQL timezone default=(cat /etc/timezone) or change to "UTC" if required.
INSTALL_TOTP=""                 # Add TOTP MFA extension (true/false)
INSTALL_DUO=""                  # Add DUO MFA extension (can't be installed simultaneously with TOTP, true/false)
INSTALL_LDAP=""                 # Add Active Directory extension (true/false)
INSTALL_QCONNECT=""             # Add Guacamole console quick connect feature
INSTALL_HISTREC=""              # Add Guacamole history recording storage feature
HISTREC_PATH=""                 # Path to save recorded sessions, default is /var/lib/guacamole/recordings
GUAC_URL_REDIR=""               # Redirect default Guacamole URL to http root (skip typing the extra "/guacamole" in the URL)
INSTALL_NGINX=""                # Install and configure Guacamole behind Nginx reverse proxy (http port 80 only, true/false)
PROXY_SITE=""                   # Local DNS name for reverse proxy and/or self signed TLS certificates
SELF_SIGN=""                    # Add self signed TLS support to Nginx (Let's Encrypt not available with this option, true/false)
CERT_COUNTRY="AU"               # Self signed cert setup: 2 country character code only, must not be blank
CERT_STATE="Victoria"           # Self signed cert setup: Optional to change, must not be blank
CERT_LOCATION="Melbourne"       # Self signed cert setup: Optional to change, must not be blank
CERT_ORG="Itiligent"            # Self signed cert setup: Optional to change, must not be blank
CERT_OU="I.T."                  # Self signed cert setup: Optional to change, must not be blank
CERT_DAYS="3650"                # Self signed cert setup: Number of days until self signed certificate expiry
LETS_ENCRYPT=""                 # Add Lets Encrypt public TLS cert for Nginx (self signed not available with this option, true/false)
LE_DNS_NAME=""                  # Public DNS name to bind with Lets Encrypt certificates
LE_EMAIL=""                     # Webmaster/admin email for Lets Encrypt notifications
BACKUP_EMAIL=""                 # Email address for backup notifications
BACKUP_RETENTION="30"           # How many days to keep SQL backups locally for
RDP_SHARE_HOST=""               # Custom Windows RDP share host name. (e.g. RDP_SHARE_LABEL on RDP_SHARE_HOST)
RDP_SHARE_LABEL="RDP Share"     # Custom Windows RDP share drive label (e.g. RDP_SHARE_LABEL on RDP_SHARE_HOST)
RDP_PRINTER_LABEL="RDP Printer" # Custom Windows RDP printer label

#######################################################################################################################
# Download GitHub setup scripts. To prevent overwrite, COMMENT OUT LINES OF ANY SCRIPTS YOU HAVE EDITED. ##############
#######################################################################################################################

# Download the set of config scripts from GitHub
cd $DOWNLOAD_DIR
echo -e "${GREY}Downloading setup files...${DGREY}"
wget -q --show-progress ${GITHUB}/2-install-guacamole.sh -O 2-install-guacamole.sh
wget -q --show-progress ${GITHUB}/3-install-nginx.sh -O 3-install-nginx.sh
wget -q --show-progress ${GITHUB}/4a-install-tls-self-signed-nginx.sh -O 4a-install-tls-self-signed-nginx.sh
wget -q --show-progress ${GITHUB}/4b-install-tls-letsencrypt-nginx.sh -O 4b-install-tls-letsencrypt-nginx.sh
# Download the Guacamole optional feature scripts
wget -q --show-progress ${GITHUB}/guac-optional-features/add-auth-duo.sh -O add-auth-duo.sh
wget -q --show-progress ${GITHUB}/guac-optional-features/add-auth-ldap.sh -O add-auth-ldap.sh
wget -q --show-progress ${GITHUB}/guac-optional-features/add-auth-totp.sh -O add-auth-totp.sh
wget -q --show-progress ${GITHUB}/guac-optional-features/add-xtra-quickconnect.sh -O add-xtra-quickconnect.sh
wget -q --show-progress ${GITHUB}/guac-optional-features/add-xtra-histrecstor.sh -O add-xtra-histrecstor.sh
wget -q --show-progress ${GITHUB}/guac-optional-features/add-smtp-relay-o365.sh -O add-smtp-relay-o365.sh
wget -q --show-progress ${GITHUB}/guac-optional-features/add-tls-guac-daemon.sh -O add-tls-guac-daemon.sh
wget -q --show-progress ${GITHUB}/guac-optional-features/add-fail2ban.sh -O add-fail2ban.sh
wget -q --show-progress ${GITHUB}/guac-management/backup-guac.sh -O backup-guac.sh
wget -q --show-progress ${GITHUB}/guac-management/upgrade-guac.sh -O upgrade-guac.sh
wget -q --show-progress ${GITHUB}/guac-management/refresh-tls-self-signed.sh -O refresh-tls-self-signed.sh
# Download the (customisable) dark theme & branding template
wget -q --show-progress ${GITHUB}/branding.jar -O branding.jar
chmod +x *.sh
sleep 3
clear

# Script branding header
echo
echo -e "${GREYB}Guacamole VDI & Jump Server Appliance Setup."
echo -e "              ${LGREEN}Powered by Itiligent"
echo
echo

# Pause here to optionally customise downloaded scripts before any actual install actions have began
echo -e "${LYELLOW}Ctrl+Z now to exit now if you wish to customise 1-setup.sh options or to setup an unattended install."
echo
echo

# Lets trigger a sudo prompt here for root credentials needed for the install - this keeps the install menu flow neat
# Set permissions for sudo and non sudo access to tmp setup files
sudo chmod -R 770 $TMP_DIR
sudo chown -R $SUDO_USER:root $TMP_DIR

#######################################################################################################################
# Determine the correct version of Tomcat use #########################################################################
#######################################################################################################################

# Check for the latest version of Tomcat currently supported by the distro
if [[ $(apt-cache show tomcat10 2>/dev/null | egrep "Version: 10" | wc -l) -gt 0 ]]; then
    TOMCAT_VERSION="tomcat10"
elif [[ $(apt-cache show tomcat9 2>/dev/null | egrep "Version: 9" | wc -l) -gt 0 ]]; then
    TOMCAT_VERSION="tomcat9"
elif [[ $(apt-cache show tomcat8 2>/dev/null | egrep "Version: 8.[5-9]" | wc -l) -gt 0 ]]; then
    TOMCAT_VERSION="tomcat8"
else
    # Default to version
    TOMCAT_VERSION="tomcat9"
fi

# Workaround for current Debian 12 & Tomcat 10 incompatibilities
if [[ ${OS_FLAVOUR,,} = "debian" ]] && [[ ${OS_CODENAME,,} = *"bookworm"* ]]; then #(checks for upper and lower case)
    # Add the oldstable repo and downgrade tomcat version install
    echo "deb http://deb.debian.org/debian/ bullseye main" | sudo tee /etc/apt/sources.list.d/bullseye.list >/dev/null
    TOMCAT_VERSION="tomcat9"
fi

# Workaround for Ubuntu 23.x & Tomcat 10 incompatibilities
if [[ ${OS_FLAVOUR,,} = "ubuntu" ]] && [[ ${OS_CODENAME,,} = *"lunar"* ]]; then  #(checks for upper and lower case)
    TOMCAT_VERSION="tomcat9"
fi

# Uncomment to force a specific Tomcat version here.
# TOMCAT_VERSION="tomcat9"

#######################################################################################################################
# DO NOT EDIT PAST THIS POINT #########################################################################################
#######################################################################################################################

#######################################################################################################################
# Begin install menu prompts ##########################################################################################
#######################################################################################################################

# We need to ensure consistent default hostname and domain suffix values for TLS implementation. The below approach
# allows the user to either hit enter at the prompt to keep current values, or to manually update values. Silent install
# pre-set values (if provided) will bypass all prompts.

# Ensure SERVER_NAME is consistent with local host entries
if [[ -z ${SERVER_NAME} ]]; then
    echo -e "${LYELLOW}Update Linux system HOSTNAME [Enter to keep: ${HOSTNAME}]${LGREEN}"
    read -p "              Enter new HOSTNAME : " SERVER_NAME
    # If hit enter making no SERVER_NAME change, assume the existing hostname as current
    if [[ "${SERVER_NAME}" = "" ]]; then
        SERVER_NAME=$HOSTNAME
    fi
    echo
    # A SERVER_NAME was derived via the prompt
    # Apply the SERVER_NAME value & remove and update any old 127.0.1.1 local host references
    sudo hostnamectl set-hostname $SERVER_NAME &>>${INSTALL_LOG}
    sudo sed -i '/127.0.1.1/d' /etc/hosts &>>${INSTALL_LOG}
    echo '127.0.1.1       '${SERVER_NAME}'' | sudo tee -a /etc/hosts &>>${INSTALL_LOG}
    sudo systemctl restart systemd-hostnamed &>>${INSTALL_LOG}
else
    echo
    # A SERVER_NAME value was derived from a pre-set silent install option.
    # Apply the SERVER_NAME value & remove and update any old 127.0.1.1 local host references
    sudo hostnamectl set-hostname $SERVER_NAME &>>${INSTALL_LOG}
    sudo sed -i '/127.0.1.1/d' /etc/hosts &>>${INSTALL_LOG}
    echo '127.0.1.1       '${SERVER_NAME}'' | sudo tee -a /etc/hosts &>>${INSTALL_LOG}
    sudo systemctl restart systemd-hostnamed &>>${INSTALL_LOG}
fi

# Ensure SERVER_NAME, LOCAL_DOMAIN suffix and host entries are all consistent
if [[ -z ${LOCAL_DOMAIN} ]]; then
    echo -e "${LYELLOW}Update Linux LOCAL DNS DOMAIN [Enter to keep: ${DOMAIN_SUFFIX}]${LGREEN}"
    read -p "              Enter FULL LOCAL DOMAIN NAME: " LOCAL_DOMAIN
    # If hit enter making no LOCAL_DOMAIN name change, assume the existing domain suffix as current
    if [[ "${LOCAL_DOMAIN}" = "" ]]; then
        LOCAL_DOMAIN=$DOMAIN_SUFFIX
    fi
    echo
    # A LOCAL_DOMAIN value was derived via the prompt
    # Remove any old hosts & resolv file values and update these with the new LOCAL_DOMAIN value
    sudo sed -i "/${DEFAULT_IP}/d" /etc/hosts
    sudo sed -i '/domain/d' /etc/resolv.conf
    sudo sed -i '/search/d' /etc/resolv.conf
    # Refresh the /etc/hosts file with the server name and new local domain value
    echo ''${DEFAULT_IP}'	'${SERVER_NAME}.${LOCAL_DOMAIN} ${SERVER_NAME}'' | sudo tee -a /etc/hosts &>>${INSTALL_LOG}
    # Refresh /etc/resolv.conf with new domain and search suffix values
    echo 'domain	'${LOCAL_DOMAIN}'' | sudo tee -a /etc/resolv.conf &>>${INSTALL_LOG}
    echo 'search	'${LOCAL_DOMAIN}'' | sudo tee -a /etc/resolv.conf &>>${INSTALL_LOG}
    sudo systemctl restart systemd-hostnamed &>>${INSTALL_LOG}
else
    echo
    # A LOCAL_DOMIN value was derived from a pre-set silent install option.
    # Remove any old hosts & resolv file values and update these with the new LOCAL_DOMAIN value
    sudo sed -i "/${DEFAULT_IP}/d" /etc/hosts
    sudo sed -i '/domain/d' /etc/resolv.conf
    sudo sed -i '/search/d' /etc/resolv.conf
    # Refresh the /etc/hosts file with the server name and new local domain value
    echo ''${DEFAULT_IP}'	'${SERVER_NAME}.${LOCAL_DOMAIN} ${SERVER_NAME}'' | sudo tee -a /etc/hosts &>>${INSTALL_LOG}
    # Refresh /etc/resolv.conf with new domain and search suffix values
    echo 'domain	'${LOCAL_DOMAIN}'' | sudo tee -a /etc/resolv.conf &>>${INSTALL_LOG}
    echo 'search	'${LOCAL_DOMAIN}'' | sudo tee -a /etc/resolv.conf &>>${INSTALL_LOG}
    sudo systemctl restart systemd-hostnamed &>>${INSTALL_LOG}
fi

# Now that $SERVER_NAME and $LOCAL_DOMAIN values are updated and refreshed:
# Values are merged to build a local FQDN value (used for the default reverse proxy site name.)
DEFAULT_FQDN=$SERVER_NAME.$LOCAL_DOMAIN
# The RDP share label default can now assume the updated $SERVER_NAME value (if not manually specified in silent setup options).
if [[ -z ${RDP_SHARE_HOST} ]]; then
    RDP_SHARE_HOST=$SERVER_NAME
fi

clear

# Script branding header
echo
echo -e "${GREYB}Guacamole VDI & Jump Server Appliance Setup."
echo -e "              ${LGREEN}Powered by Itiligent"
echo
echo

# Prompt the user to install MySQL
echo -e "${LGREEN}MySQL setup options:${GREY}"
if [[ -z ${INSTALL_MYSQL} ]]; then
    echo -e -n "SQL: Install MySQL locally? (to use a remote MySQL Server select 'n') [Y/n] [default y]: ${GREY}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Nn]$ ]]; then
        INSTALL_MYSQL=false
    else
        INSTALL_MYSQL=true
    fi
fi

# Prompt the user to apply the Mysql secure installation locally
if [[ -z ${SECURE_MYSQL} ]] && [[ "${INSTALL_MYSQL}" = true ]]; then
    echo -e -n "${GREY}SQL: Apply MySQL secure installation settings to LOCAL db? [Y/n] [default y]: ${GREY}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Nn]$ ]]; then
        SECURE_MYSQL=false
    else
        SECURE_MYSQL=true
    fi
fi

# Prompt the user to apply the Mysql secure installation to remote db
# This may be problematic on remote databases (for one-script upgrades) as this addition removes remote root login access - a good thing.
#if [[ -z ${SECURE_MYSQL} ]] && [[ "${INSTALL_MYSQL}" = false ]]; then
#    echo -e -n "${GREY}SQL: Apply MySQL secure installation settings to REMOTE db? [y/N] [default n]: ${GREY}"
#    read PROMPT
#    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
#        SECURE_MYSQL=true
#    else
#        SECURE_MYSQL=false
#    fi
#fi

# Get additional MYSQL values
if [[ "${INSTALL_MYSQL}" = false ]]; then
    [[ -z "${MYSQL_HOST}" ]] &&
        read -p "SQL: Enter remote MySQL server hostname or IP: " MYSQL_HOST
    [[ -z "${MYSQL_PORT}" ]] &&
        read -p "SQL: Enter remote MySQL server port [3306]: " MYSQL_PORT
    [[ -z "${GUAC_DB}" ]] &&
        read -p "SQL: Enter remote Guacamole database name [guacamole_db]: " GUAC_DB
    [[-z "${GUAC_USER}" ]] &&
        read -p "SQL: Enter remote Guacamole user name [guacamole_user]: " GUAC_USER
fi
# Checking if a mysql host given, if not set a default
if [[ -z "${MYSQL_HOST}" ]]; then
    MYSQL_HOST="localhost"
fi
# Checking if a mysql port given, if not set a default
if [[ -z "${MYSQL_PORT}" ]]; then
    MYSQL_PORT="3306"
fi
# Checking if a database name given, if not set a default
if [[ -z "${GUAC_DB}" ]]; then
    GUAC_DB="guacamole_db"
fi
# Checking if a mysql user given, if not set a default
if [[ -z "${GUAC_USER}" ]]; then
    GUAC_USER="guacamole_user"
fi

echo -e ${LMAGENTA}
# Get MySQL root password, confirm correct password entry and prevent blank passwords. No root pw needed for remote instances.
if [[ -z "${MYSQL_ROOT_PWD}" ]] && [[ "${INSTALL_MYSQL}" = true ]]; then
    while true; do
        read -s -p "SQL: Enter ${MYSQL_HOST}'s MySQL ROOT password: " MYSQL_ROOT_PWD
        echo
        read -s -p "SQL: Confirm ${MYSQL_HOST}'s MySQL ROOT password: " PROMPT2
        echo
        [[ "${MYSQL_ROOT_PWD}" = "${PROMPT2}" ]] && [[ "${MYSQL_ROOT_PWD}" != "" ]] && [[ "${PROMPT2}" != "" ]] && break
        echo -e "${LRED}Passwords don't match or can't be null. Please try again.${LMAGENTA}" 1>&2
    done
fi

echo -e ${LCYAN}
# Get Guacamole User password, confirm correct password entry and prevent blank passwords
if [[ -z "${GUAC_PWD}" ]]; then
    while true; do
        read -s -p "SQL: Enter ${MYSQL_HOST}'s MySQL ${GUAC_USER} password: " GUAC_PWD
        echo
        read -s -p "SQL: Confirm ${MYSQL_HOST}'s MySQL ${GUAC_USER} password: " PROMPT2
        echo
        [[ "${GUAC_PWD}" = "${PROMPT2}" ]] && [[ "${GUAC_PWD}" != "" ]] && [[ "${PROMPT2}" != "" ]] && break
        echo -e "${LRED}Passwords don't match or can't be null. Please try again.${LCYAN}" 1>&2
    done
fi

echo -e ${GREY}
# Prompt for preferred backup notification email address
if [[ -z ${BACKUP_EMAIL} ]]; then
    while true; do
        read -p "SQL: Enter email address for SQL backup messages [Enter to skip]: " BACKUP_EMAIL
        [[ "${BACKUP_EMAIL}" = "" ]] || [[ "${BACKUP_EMAIL}" != "" ]] && break
        # Rather than allow a blank value, un-comment to alternately force user to enter an explicit value instead
        # [[ "${BACKUP_EMAIL}" != "" ]] && break
        # echo -e "${LRED}You must enter an email address. Please try again.${GREY}" 1>&2
    done
fi
# If no backup notification email address is given, provide a default value
if [[ -z ${BACKUP_EMAIL} ]]; then
    BACKUP_EMAIL="backup-email@yourdomain.com"
fi

echo
# Prompt the user to install TOTP MFA
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

# Prompt the user to install Duo MFA
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

# Prompt the user to install Duo MFA
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
# Prompt the user to install the Quick Connect feature (some higher security use cases may not want this)
echo -e "${LGREEN}Guacamole console optional extras:${GREY}"
if [[ -z "${INSTALL_QCONNECT}" ]]; then
    echo -e -n "${GREY}EXTRAS: Install Quick Connect feature? [y/N] [default n]: "
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        INSTALL_QCONNECT=true
    else
        INSTALL_QCONNECT=false
    fi
fi

# Prompt the user to install the History Recorded Storage feature
if [[ -z "${INSTALL_HISTREC}" ]]; then
    echo -e -n "${GREY}EXTRAS: Install History Recorded Storage (session replay console integration) [y/N] [default n]: "
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        INSTALL_HISTREC=true
    else
        INSTALL_HISTREC=false
    fi
fi
HISTREC_PATH_DEFAULT=/var/lib/guacamole/recordings # Apache default
if [[ -z ${HISTREC_PATH} ]] && [[ "${INSTALL_HISTREC}" = true ]]; then
    while true; do
        read -p "EXTRAS: Enter recorded storage path [Enter for default ${HISTREC_PATH_DEFAULT}]: " HISTREC_PATH
        [[ "${HISTREC_PATH}" = "" ]] || [[ "${HISTREC_PATH}" != "" ]] && break
    done
fi
# If no custom path is given, lets assume the default path on hitting enter
if [[ -z "${HISTREC_PATH}" ]]; then
    HISTREC_PATH="${HISTREC_PATH_DEFAULT}"
fi

echo
# Prompt for Guacamole front end reverse proxy option
echo -e "${LGREEN}Reverse Proxy & front end options:${GREY}"
if [[ -z ${INSTALL_NGINX} ]]; then
    echo -e -n "FRONT END: Protect Guacamole behind Nginx reverse proxy [y/N]? [default n]: "
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        INSTALL_NGINX=true
        GUAC_URL_REDIR=false
    else
        INSTALL_NGINX=false
    fi
fi

# Prompt to remove the trailing /guacamole dir from the default front end url
if [[ "${INSTALL_NGINX}" = false ]]; then
    echo -e -n "FRONT END: Shorten Guacamole root url to *:8080 (& redirect to /guacamole ) [Y/n]? [default y]: "
    read PROMPT
    if [[ ${PROMPT} =~ ^[Nn]$ ]]; then
        GUAC_URL_REDIR=false
    else
        GUAC_URL_REDIR=true
    fi
fi

# We must assign a DNS name for the new proxy site
if [[ -z ${PROXY_SITE} ]] && [[ "${INSTALL_NGINX}" = true ]]; then
    while true; do
        read -p "FRONT END: Enter proxy local DNS name? [Enter to use ${DEFAULT_FQDN}]: " PROXY_SITE
        [[ "${PROXY_SITE}" = "" ]] || [[ "${PROXY_SITE}" != "" ]] && break
        # Rather than allow the default value below, un-comment to alternately force user to enter an explicit name instead
        # [[ "${PROXY_SITE}" != "" ]] && break
        # echo -e "${LRED}You must enter a proxy site DNS name. Please try again.${GREY}" 1>&2
    done
fi

# If no proxy site dns name is given, lets assume the default FQDN is the proxy site name
if [[ -z "${PROXY_SITE}" ]]; then
    PROXY_SITE="${DEFAULT_FQDN}"
fi

# Prompt for self signed TLS reverse proxy option
if [[ -z ${SELF_SIGN} ]] && [[ "${INSTALL_NGINX}" = true ]]; then
    # Prompt the user to see if they would like to install self signed TLS support for Nginx, default of no
    echo -e -n "FRONT END: Add self signed TLS support to Nginx? [y/N]? (choose 'n' for Let's Encrypt)[default n]: "
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        SELF_SIGN=true
    else
        SELF_SIGN=false
    fi
fi

# Optional prompt to assign the self sign TLS certificate a custom expiry date, un-comment to force a manual entry
#if [[ "${SELF_SIGN}" = true ]]; then
#	read - p "PROXY: Enter number of days till TLS certificate expires [default 3650]: " CERT_DAYS
#fi

# If no self sign TLS certificate expiry given, lets assume a generous 10 year default certificate expiry
if [[ -z "${CERT_DAYS}" ]]; then
    CERT_DAYS="3650"
fi

# Prompt for Let's Encrypt TLS reverse proxy configuration option
if [[ -z ${LETS_ENCRYPT} ]] && [[ "${INSTALL_NGINX}" = true ]] && [[ "${SELF_SIGN}" = "false" ]]; then
    echo -e -n "FRONT END: Add Let's Encrypt TLS support to Nginx reverse proxy [y/N] [default n]: ${GREY}"
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
        read -p "FRONT END: Enter the FQDN for your public proxy site : " LE_DNS_NAME
        [[ "${LE_DNS_NAME}" != "" ]] && break
        echo -e "${LRED}You must enter a public DNS name. Please try again.${GREY}" 1>&2
    done
fi

# Prompt for Let's Encrypt admin email
if [[ -z ${LE_EMAIL} ]] && [[ "${LETS_ENCRYPT}" = true ]]; then
    while true; do
        read -p "FRONT END: Enter the email address for Let's Encrypt notifications : " LE_EMAIL
        [[ "${LE_EMAIL}" != "" ]] && break
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
echo -e "${GREYB}Guacamole VDI & Jump Server Appliance Setup."
echo -e "              ${LGREEN}Powered by Itiligent"
echo
echo

echo -e "${LGREEN}Beginning Guacamole setup...${GREY}"
echo
echo -e "${GREY}Checking Linux distro specific dependencies..."
if [[ $OS_FLAVOUR == "ubuntu" ]] || [[ $OS_FLAVOUR == *"ubuntu"* ]]; then # potentially expand out distro choices here
    JPEGTURBO="libjpeg-turbo8-dev"
    LIBPNG="libpng-dev"
    # Just in case this repo is not added by default in the distro
    sudo add-apt-repository -y universe &>>${INSTALL_LOG}
elif [[ $OS_FLAVOUR == "debian" ]] || [[ $OS_FLAVOUR == "raspbian" ]]; then # expand distro choices here if required
    JPEGTURBO="libjpeg62-turbo-dev"
    LIBPNG="libpng-dev"
fi
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Sync the various manual config scripts with the relevant variables selected at install
sed -i "s|MYSQL_HOST=|MYSQL_HOST='${MYSQL_HOST}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|MYSQL_PORT=|MYSQL_PORT='${MYSQL_PORT}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|GUAC_USER=|GUAC_USER='${GUAC_USER}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|GUAC_PWD=|GUAC_PWD='${GUAC_PWD}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|GUAC_DB=|GUAC_DB='${GUAC_DB}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|DB_BACKUP_DIR=|DB_BACKUP_DIR='${DB_BACKUP_DIR}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|BACKUP_EMAIL=|BACKUP_EMAIL='${BACKUP_EMAIL}'|g" $DOWNLOAD_DIR/backup-guac.sh
sed -i "s|BACKUP_RETENTION=|BACKUP_RETENTION='${BACKUP_RETENTION}'|g" $DOWNLOAD_DIR/backup-guac.sh

sed -i "s|CERT_COUNTRY=|CERT_COUNTRY='${CERT_COUNTRY}'|g" $DOWNLOAD_DIR/add-tls-guac-daemon.sh
sed -i "s|CERT_STATE=|CERT_STATE='${CERT_STATE}'|g" $DOWNLOAD_DIR/add-tls-guac-daemon.sh
sed -i "s|CERT_LOCATION=|CERT_LOCATION='${CERT_LOCATION=}'|g" $DOWNLOAD_DIR/add-tls-guac-daemon.sh
sed -i "s|CERT_ORG=|CERT_ORG='${CERT_ORG}'|g" $DOWNLOAD_DIR/add-tls-guac-daemon.sh
sed -i "s|CERT_OU=|CERT_OU='${CERT_OU}'|g" $DOWNLOAD_DIR/add-tls-guac-daemon.sh
sed -i "s|CERT_DAYS=|CERT_DAYS='${CERT_DAYS}'|g" $DOWNLOAD_DIR/add-tls-guac-daemon.sh

sed -i "s|INSTALL_MYSQL=|INSTALL_MYSQL='${INSTALL_MYSQL}'|g" $DOWNLOAD_DIR/upgrade-guac.sh
sed -i "s|MYSQL_HOST=|MYSQL_HOST='${MYSQL_HOST}'|g" $DOWNLOAD_DIR/upgrade-guac.sh
sed -i "s|MYSQL_PORT=|MYSQL_PORT='${MYSQL_PORT}'|g" $DOWNLOAD_DIR/upgrade-guac.sh
sed -i "s|GUAC_DB=|GUAC_DB='${GUAC_DB}'|g" $DOWNLOAD_DIR/upgrade-guac.sh
sed -i "s|MYSQL_ROOT_PWD=|MYSQL_ROOT_PWD='${MYSQL_ROOT_PWD}'|g" $DOWNLOAD_DIR/upgrade-guac.sh
sed -i "s|GUAC_USER=|GUAC_USER='${GUAC_USER}'|g" $DOWNLOAD_DIR/upgrade-guac.sh
sed -i "s|GUAC_PWD=|GUAC_PWD='${GUAC_PWD}'|g" $DOWNLOAD_DIR/upgrade-guac.sh

sed -i "s|CERT_COUNTRY=|CERT_COUNTRY='${CERT_COUNTRY}'|g" $DOWNLOAD_DIR/refresh-tls-self-signed.sh
sed -i "s|CERT_STATE=|CERT_STATE='${CERT_STATE}'|g" $DOWNLOAD_DIR/refresh-tls-self-signed.sh
sed -i "s|CERT_LOCATION=|CERT_LOCATION='${CERT_LOCATION}'|g" $DOWNLOAD_DIR/refresh-tls-self-signed.sh
sed -i "s|CERT_ORG=|CERT_ORG='${CERT_ORG}'|g" $DOWNLOAD_DIR/refresh-tls-self-signed.sh
sed -i "s|CERT_OU=|CERT_OU='${CERT_OU}'|g" $DOWNLOAD_DIR/refresh-tls-self-signed.sh
sed -i "s|PROXY_SITE=|PROXY_SITE='${PROXY_SITE}'|g" $DOWNLOAD_DIR/refresh-tls-self-signed.sh
sed -i "s|DEFAULT_IP=|DEFAULT_IP='${DEFAULT_IP}'|g" $DOWNLOAD_DIR/refresh-tls-self-signed.sh
sed -i "s|CERT_DAYS=|CERT_DAYS='${CERT_DAYS}'|g" $DOWNLOAD_DIR/refresh-tls-self-signed.sh

# Export the relevant variable selections to child install scripts
export DOWNLOAD_DIR="${DOWNLOAD_DIR}"
export TMP_DIR=$TMP_DIR
export GUAC_VERSION=$GUAC_VERSION
export GUAC_SOURCE_LINK=$GUAC_SOURCE_LINK
export MYSQLJCON=$MYSQLJCON
export MYSQL_VERSION=$MYSQL_VERSION
export MYSQLSRV=$MYSQLSRV
export MYSQLCLIENT=$MYSQLCLIENT
export DB_CMD=$DB_CMD
export TOMCAT_VERSION=$TOMCAT_VERSION
export INSTALL_LOG=$INSTALL_LOG
export GUAC_URL=$GUAC_URL
export JPEGTURBO=$JPEGTURBO
export LIBPNG=$LIBPNG
export INSTALL_MYSQL=$INSTALL_MYSQL
export SECURE_MYSQL=$SECURE_MYSQL
export MYSQL_HOST=$MYSQL_HOST
export MYSQL_PORT=$MYSQL_PORT
export GUAC_DB=$GUAC_DB
export GUAC_USER=$GUAC_USER
export MYSQL_ROOT_PWD="${MYSQL_ROOT_PWD}"
export GUAC_PWD="${GUAC_PWD}"
export DB_TZ="${DB_TZ}"
export INSTALL_TOTP=$INSTALL_TOTP
export INSTALL_DUO=$INSTALL_DUO
export INSTALL_LDAP=$INSTALL_LDAP
export INSTALL_QCONNECT=$INSTALL_QCONNECT
export INSTALL_HISTREC=$INSTALL_HISTREC
export HISTREC_PATH="${HISTREC_PATH}"
export GUAC_URL_REDIR=$GUAC_URL_REDIR
export INSTALL_NGINX=$INSTALL_NGINX
export PROXY_SITE=$PROXY_SITE
export CERT_COUNTRY=$CERT_COUNTRY
export CERT_STATE="${CERT_STATE}"
export CERT_LOCATION="${CERT_LOCATION}"
export CERT_ORG="${CERT_ORG}"
export CERT_OU="${CERT_OU}"
export LE_DNS_NAME=$LE_DNS_NAME
export LE_EMAIL=$LE_EMAIL
export BACKUP_EMAIL=$BACKUP_EMAIL
export RDP_SHARE_HOST="${RDP_SHARE_HOST}"
export RDP_SHARE_LABEL="${RDP_SHARE_LABEL}"
export RDP_PRINTER_LABEL="${RDP_PRINTER_LABEL}"

# Run the Guacamole install script
sudo -E ./2-install-guacamole.sh
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}2-install-guacamole.sh FAILED. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
elif [[ "${GUAC_URL_REDIR}" = true ]]; then
    echo -e "${LGREEN}Guacamole install complete\nhttp://${PROXY_SITE}:8080 - login user/pass: guacadmin/guacadmin\n${LYELLOW}***Be sure to change the password***${GREY}"
else
    echo -e "${LGREEN}Guacamole install complete\nhttp://${PROXY_SITE}:8080/guacamole - login user/pass: guacadmin/guacadmin\n${LYELLOW}***Be sure to change the password***${GREY}"
fi

# Add a Guacamole database backup (mon-fri 12:00am) into cron
mv $DOWNLOAD_DIR/backup-guac.sh $DB_BACKUP_DIR
crontab -l >cron_1
# Remove any existing entry
sed -i '/# backup guacamole/d' cron_1
# Create the job
echo "0 0 * * 1-5 ${DB_BACKUP_DIR}/backup-guac.sh # backup guacamole" >>cron_1
# Overwrite the cron settings and cleanup
crontab cron_1
rm cron_1

#######################################################################################################################
# Start optional setup actions   ######################################################################################
#######################################################################################################################

# Install Nginx reverse proxy front end to Guacamole if option is selected
if [[ "${INSTALL_NGINX}" = true ]]; then
    sudo -E ./3-install-nginx.sh
    echo -e "${LGREEN}Nginx install complete\nhttp://${PROXY_SITE} - admin login: guacadmin pass: guacadmin\n${LYELLOW}***Be sure to change the password***${GREY}"
fi

# Apply self signed TLS certificates to Nginx reverse proxy if option is selected
if [[ "${INSTALL_NGINX}" = true ]] && [[ "${SELF_SIGN}" = true ]]; then
    sudo -E ./4a-install-tls-self-signed-nginx.sh ${PROXY_SITE} ${CERT_DAYS} | tee -a ${INSTALL_LOG}
    echo -e "${LGREEN}Self signed certificate configured for Nginx \n${LYELLOW}https:${LGREEN}//${PROXY_SITE} - admin login: guacadmin pass: guacadmin\n${LYELLOW}***Be sure to change the password***${GREY}"
fi

# Apply Let's Encrypt TLS certificates to Nginx reverse proxy if option is selected
if [[ "${INSTALL_NGINX}" = true ]] && [[ "${LETS_ENCRYPT}" = true ]]; then
    sudo -E ./4b-install-tls-letsencrypt-nginx.sh
    echo -e "${LGREEN}Let's Encrypt TLS configured for Nginx \n${LYELLOW}https:${LGREEN}//${LE_DNS_NAME} - admin login: guacadmin pass: guacadmin\n${LYELLOW}***Be sure to change the password***${GREY}"
fi

# Duo Settings reminder - If Duo is selected you can't login to Guacamole until this extension is fully configured
if [[ $INSTALL_DUO == "true" ]]; then
    echo
    echo -e "${LYELLOW}Reminder: Duo requires extra account specific info configured in the\n/etc/guacamole/guacamole.properties file before you can log in to Guacamole."
    echo -e "See https://guacamole.apache.org/doc/gug/duo-auth.html"
fi

# LDAP Settings reminder, LDAP auth is not functional until the config is complete
if [[ $INSTALL_LDAP == "true" ]]; then
    echo
    echo -e "${LYELLOW}Reminder: LDAP requires that your LDAP directory configuration match the exact format\nadded to the /etc/guacamole/guacamole.properties file before LDAP auth will be active."
    echo -e "See https://guacamole.apache.org/doc/gug/ldap-auth.html"
fi

# Tidy up. (Installer and Nginx scripts can't be run again or standalone without modification, so removing.)
rm -rf $USER_HOME_DIR/1-setup.sh
rm -f 2-install-guacamole.sh
rm -f 3-install-nginx.sh
rm -f 4a-install-tls-self-signed-nginx.sh
rm -f 4b-install-tls-letsencrypt-nginx.sh
sudo rm -rf $TMP_DIR
apt-get -y autoremove &>>${INSTALL_LOG}

# Done
echo
printf "${LGREEN}Guacamole ${GUAC_VERSION} install complete! \n${NC}"
echo -e ${NC}
