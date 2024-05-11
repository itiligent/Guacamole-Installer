#!/bin/bash
#######################################################################################################################
# Guacamole MySQL backend install script. (For split DB and guacamole application layers.
# For Ubuntu / Debian / Raspbian
# David Harrop
# September 2023
#######################################################################################################################

# This script is for separating the Guacamole architecture into a scaled out three tiered system.
# Layer 1 = DATABASE - This script
# Layer 2 = GUAC SERVER & APPLICATION - use the main setup script, and select remote MYSQL DB option.
# Layer 3 = FRONT END REV PROXY (Potentially load balanced & HA) - Up to you!

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

# Version of Guacamole auth jdbc database schema to use
GUAC_VERSION="1.5.5"

# Set preferred Apache CDN download link)
GUAC_SOURCE_LINK="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VERSION}"

# Install log Location
INSTALL_LOG="${DOWNLOAD_DIR}/mysql_install.log"

clear

# Script branding header
echo
echo -e "${GREYB}Guacamole Backend MySQL Setup."
echo -e "             ${LGREEN}Powered by Itiligent"
echo
echo

#######################################################################################################################
# Setup options. ######################################################################################################
#######################################################################################################################

BACKEND_MYSQL="true"       # True: For separated MySQL layer. False/blank: Add MySQL to existing guac server (replace XML user map)
FRONTEND_NET=""            # IPs guac server can login from. Blank = any IP or wildcard 192.168.1.% (ignored if BACKEND_SQL="false")
MYSQL_BIND_ADDR="0.0.0.0"  # Binds MySQL instance to this IP. (127.0.0.1, a specific IP or 0.0.0.0) (ignored if BACKEND_SQL="false")
SECURE_MYSQL="true"        # Apply the mysql secure configuration tool (true/false)
MYSQL_PORT="3306"          # Default is 3306
GUAC_DB="guacamole_db"     # Default is guacamole_db
GUAC_USER="guacamole_user" # Default is guacamole_user
GUAC_PWD="test"            # Requires an entry
MYSQL_ROOT_PWD="test"      # Requires an entry.
DB_TZ=$(cat /etc/timezone) # Typically system default (cat /etc/timezone) or change to "UTC" if required.
MYSQL_VERSION=""           # Blank "" will use distro default MySQL packages. Enter a specific MySQL version for official Maria repo eg. 11.1.2. See https://mariadb.org/mariadb/all-releases/ for available versions.

# For a remotely accessed back end DB instance, keep this script set to BACKEND_MYSQL="true".
# Other options are fairly straight forward. For a typical back end server only the $FRONTEND_NET and $MYSQL_BIND_ADDR
# values may need closer attention.

# This script can also accommodate DR or migration scenarios: E.g Migration away from XML user mappings, PostGres to MySQL etc).
# To install a new MySQL database on the same server as the Guacamole application, set BACKEND_MYSQL="false" &
# MYSQL_BIND_ADDR="127.0.0.1". See bottom of this script for some remaining DB migration actions.

#######################################################################################################################
# Start install actions  ##############################################################################################
#######################################################################################################################

# Standardise on a lexicon for the different MySQL package options
if [[ -z "${MYSQL_VERSION}" ]]; then
    # Use Linux distro default version.
    MYSQLPKG="default-mysql-server default-mysql-client mysql-common"
    DB_CMD="mysql" # mysql command is depricated
else
    # Use official mariadb.org repo
    MYSQLPKG="mariadb-server mariadb-client mariadb-common"
    DB_CMD="mariadb" # mysql command is depricated on newer versions
fi

# Update everything but don't do the annoying prompts during apt installs
echo -e "${GREY}Updating base Linux OS..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq &>>${INSTALL_LOG}
apt-get upgrade -qq -y &>>${INSTALL_LOG}
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

cd $DOWNLOAD_DIR

# Add the official MariaDB repo
if [[ -n "${MYSQL_VERSION}" ]]; then
    apt-get -qq -y install curl gnupg2 &>>${INSTALL_LOG}
    curl -LsS -O https://downloads.mariadb.com/MariaDB/mariadb_repo_setup &>>${INSTALL_LOG}
    bash mariadb_repo_setup --mariadb-server-version=$MYSQL_VERSION &>>${INSTALL_LOG}
fi

# Download and extract the Guacamole SQL authentication extension containing the database schema
echo -e "${GREY}Downloading Guacamole database source files..."
wget -q --show-progress -O guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed to download guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz" 1>&2
    echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz"
    exit 1
else
    tar -xzf guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz
fi
echo -e "${LGREEN}Downloaded guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz${GREY}"

echo
echo -e "${GREY}Installing MySQL packages..."
apt-get -qq -y install ${MYSQLPKG} &>>${INSTALL_LOG}
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Set the MySQL root password without a reliance on debconf (may not be present in all distros).
echo -e "${GREY}Setting MySQL root password..."
SQLCODE="
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PWD';"
echo ${SQLCODE} | $DB_CMD -u root
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# A simple method to find the correct file containing the default MySQL timezone setting from a potential list of candidates.
# and then update that timzone value. Add to this array if your distro uses a different path to the .cnf contaiing the default_time_zone value.
for x in /etc/mysql/mariadb.conf.d/50-server.cnf \
    /etc/mysql/mysql.conf.d/mysqld.cnf \
    /etc/mysql/my.cnf; do
    # Check inside each candidate to see if a [mysqld] or [mariadbd] section exists, assign $x the correct filename.
    if [[ -e "${x}" ]]; then
        if grep -qE '^\[(mysqld|mariadbd)\]$' "${x}"; then
            mysqlconfig="${x}"
            # Reduce any duplicated section names, then sanitise the [ ] special characters for sed below)
            config_section=$(grep -m 1 -E '^\[(mysqld|mariadbd)\]$' "${x}" | sed 's/\[\(.*\)\]/\1/')
            break
        fi
    fi
done

# Set the MySQL Timezone
if [[ -z "${mysqlconfig}" ]]; then
    echo -e "${GREY}Couldn't detect MySQL config file - you will need to manually configure database timezone settings"
else
    # Is there already a timzeone value configured?
    if grep -q "^default_time_zone[[:space:]]=" "${mysqlconfig}"; then
        echo -e "MySQL database timezone defined in ${mysqlconfig}"
    else
        timezone=${DB_TZ}
        if [[ -z "${DB_TZ}" ]]; then
            echo -e "Couldn't find system timezone, using UTC$"
            timezone="UTC"
        fi
        echo -e "Setting MySQL database timezone as ${timezone}${GREY}"
        mysql_tzinfo_to_sql /usr/share/zoneinfo 2>/dev/null | ${DB_CMD} -u root -D mysql -p${MYSQL_ROOT_PWD}
        # Add the timzone value to the sanitsed server file section name.
        sed -i -e "/^\[${config_section}\]/a default_time_zone = ${timezone}" "${mysqlconfig}"
    fi
fi
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Establish the appropriate form of Guacamole user account access (remote or localhost login permissions)
echo -e "${GREY}Setting up database access parameters for the Guacamole user ..."
if [[ "${BACKEND_MYSQL}" = true ]] && [[ -z "${FRONTEND_NET}" ]]; then
    echo -e "${LYELLOW}${GUAC_USER} is set to accept db logins from any host, you may wish to limit this to specific IPs.${GREY}"
    GUAC_USERHost="%" # Allow guacamole access from all IPs where $FRONTEND_NET is left blank
elif [[ "${BACKEND_MYSQL}" = true ]] && [[ -n "${FRONTEND_NET}" ]]; then
    echo -e "${LYELLOW}${GUAC_USER} is set to accept db logins from ${FRONTEND_NET}.${GREY}"
    GUAC_USERHost="${FRONTEND_NET}" # Allow guacamole access from the given value in $FRONTEND_NET
elif [[ "${BACKEND_MYSQL}" = false ]] || [[ -z "${BACKEND_MYSQL}" ]]; then
    echo -e "${LYELLOW}${GUAC_USER} is set to accept db logins from localhost only.${GREY}"
    GUAC_USERHost=localhost # Assume a localhost only install
    MYSQL_BIND_ADDR="127.0.0.1"
else
    echo -e "${LYELLOW}${GUAC_USER} is set to accept db logins from localhost only.${GREY}"
    GUAC_USERHost=localhost # Assume a localhost only install
fi
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Set the MySQL binding IP address according to setup variables given.
echo -e "${GREY}Setting MySQL IP address binding to ${MYSQL_BIND_ADDR}..."
sed -i "s/^bind-address[[:space:]]*=[[:space:]]*.*/bind-address = ${MYSQL_BIND_ADDR}/g" ${mysqlconfig}
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Create the new Guacamole database
echo -e "${GREY}Creating the Guacamole database..."
SQLCODE="
DROP DATABASE IF EXISTS ${GUAC_DB};
CREATE DATABASE IF NOT EXISTS ${GUAC_DB};
CREATE USER IF NOT EXISTS '${GUAC_USER}'@'${GUAC_USERHost}' IDENTIFIED BY \"${GUAC_PWD}\";
GRANT SELECT,INSERT,UPDATE,DELETE ON ${GUAC_DB}.* TO '${GUAC_USER}'@'${GUAC_USERHost}';
FLUSH PRIVILEGES;"
# Execute SQL code
echo ${SQLCODE} | $DB_CMD -u root -D mysql -p${MYSQL_ROOT_PWD}
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Add Guacamole's schema code to newly created database
echo -e "${GREY}Adding the Guacamole database schema..."
cat guacamole-auth-jdbc-${GUAC_VERSION}/mysql/schema/*.sql | $DB_CMD -u root -D ${GUAC_DB} -p${MYSQL_ROOT_PWD}
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Apply Secure MySQL installation settings
if [[ "${SECURE_MYSQL}" = true ]]; then
    apt-get -qq -y install expect &>>${INSTALL_LOG}
    echo -e "${GREY}Applying mysql_secure_installation settings...${DGREY}"
    SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"$MYSQL_ROOT_PWD\r\"
expect \"Switch to unix_socket authentication\"
send \"n\r\"
expect \"Change the root password?\"
send \"n\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
    echo "$SECURE_MYSQL"
    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

# Restart & enable MySQL service at boot
echo -e "${GREY}Restarting MySQL service & enable at boot..."
systemctl enable mysql
systemctl restart mysql
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Cleanup
echo -e "${GREY}Cleaning up install files...${GREY}"
apt-get -y remove expect &>>${INSTALL_LOG}
apt-get -y autoremove &>>${INSTALL_LOG}
rm -rf guacamole-*
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Done
echo
printf "${LGREEN}Guacamole ${GUAC_VERSION} MySQL backend install complete! \n${NC}"
echo -e ${NC}

#######################################################################################################################
# Additional migration steps for adding MySQL to an existing Guacamole application server
#######################################################################################################################

# Download and upgrade Guacamole SQL authentication extension
#wget -q --show-progress -O guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz
#tar -xzf guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz
#rm /etc/guacamole/extensions/guacamole-auth-jdbc-*.jar
#mv -f guacamole-auth-jdbc-${GUAC_VERSION}/mysql/guacamole-auth-jdbc-mysql-${GUAC_VERSION}.jar /etc/guacamole/extensions/
#chmod 664 /etc/guacamole/extensions/guacamole-auth-jdbc-mysql-${GUAC_VERSION}.jar

# Download MySQL connector/j
# MYSQLJCON="8.1.0"
#wget -q --show-progress -O mysql-connector-j-${MYSQLJCON}.tar.gz https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-${MYSQLJCON}.tar.gz
#tar -xzf mysql-connector-j-${MYSQLJCON}.tar.gz
#rm /etc/guacamole/lib/mysql-connector-java.jar
#mv -f mysql-connector-j-${MYSQLJCON}/mysql-connector-j-${MYSQLJCON}.jar /etc/guacamole/lib/mysql-connector-java.jar

# Configure guacamole.properties file
#rm -f /etc/guacamole/guacamole.properties
#touch /etc/guacamole/guacamole.properties
#echo "mysql-hostname: ${MYSQL_HOST}" >>/etc/guacamole/guacamole.properties
#echo "mysql-port: ${MYSQL_PORT}" >>/etc/guacamole/guacamole.properties
#echo "mysql-database: ${GUAC_DB}" >>/etc/guacamole/guacamole.properties
#echo "mysql-username: ${GUAC_USER}" >>/etc/guacamole/guacamole.properties
#echo "mysql-password: ${GUAC_PWD}" >>/etc/guacamole/guacamole.properties
