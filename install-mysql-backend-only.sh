#!/bin/bash
#######################################################################################################################
# Guacamole db build script
# For Ubuntu / Debian / Raspbian
# David Harrop
# September 2023
#######################################################################################################################

# This script is for separating the Guacamole architecture into a scaled out three tiered system.
# Layer 1 = DATABASE - This script
# Layer 2 = GUAC SERVER & APPLICATION - use the main setup script, and select remote MYSQL DB option.
# Layer 3 = FRONT END REV PROXY (Potentially load balanced & HA) - approach TBA

# Prepare text output colours
GREY='\033[0;37m'
DGREY='\033[0;90m'
GREYB='\033[1;37m'
LRED='\033[0;91m'
LGREEN='\033[0;92m'
LYELLOW='\033[0;93m'
NC='\033[0m' #No Colour

#  Setup download and temp directory paths
USER_HOME_DIR=$(eval echo ~${SUDO_USER})
DOWNLOAD_DIR=$USER_HOME_DIR/guac-setup
mkdir -p $DOWNLOAD_DIR

# Install log Location
INSTALL_LOG="${DOWNLOAD_DIR}/mysql_install.log"

# Version of Guacamole auth jdbc database schema to use
GUAC_VERSION="1.5.3"

# Set preferred Apache CDN download link)
GUAC_SOURCE_LINK="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VERSION}"

clear

# Script branding header
echo
echo -e "${GREYB}Guacamole Backend MySQL Setup."
echo -e "             ${LGREEN}Powered by Itiligent"
echo
echo

#######################################################################################################################
# Silent setup options - adding true/false or specific values below prevents prompt at install ########################
#######################################################################################################################
MYSQL_HOST="localhost"              # leave blank for localhost default, only specify for remote servers
SECURE_MYSQL="true"                 # Apply mysql secure configuration tool (true/false)
MYSQL_PORT="3306"                   # If blank default is 3306
GUAC_DB="guacamole_db"              # If blank default is guacamole_db
GUAC_USER="guacamole_user"          # If blank default is guacamole_user
GUAC_PWD="test"                     # Requires an entry here or at at script prompt.
MYSQL_ROOT_PWD="test"               # Requires an entry here or at at script prompt.
DB_TZ=$(cat /etc/timezone)          # Database timezone to apply. Defaults to system TZ. Change to "UTC" if appropriate

# Force a specific MySQL version e.g. 11.1.2 See https://mariadb.org/mariadb/all-releases/ for available versions.
# If MYSQL_VERSION is left blank, script will default to the distro default MYSQL packages.
MYSQL_VERSION=""
if [ -z "${MYSQL_VERSION}" ]; then
    # Use Linux distro default version.
    MYSQLV="default-mysql-server default-mysql-client mysql-common"
  else
    # Use official mariadb.org repo
    MYSQLV="mariadb-server mariadb-client mariadb-common"
fi

if [ -n "${MYSQL_VERSION}" ]; then
    # Add the Official MariaDB repo.
    apt-get -qq -y install curl gnupg2 &>>${INSTALL_LOG}
    curl -LsS -O https://downloads.mariadb.com/MariaDB/mariadb_repo_setup &>>${INSTALL_LOG}
    bash mariadb_repo_setup --mariadb-server-version=$MYSQL_VERSION &>>${INSTALL_LOG}
fi

# Pre-seed MySQL root password values for Linux Distro default packages only
if [ -z "${MYSQL_VERSION}" ]; then
    debconf-set-selections <<<"mysql-server mysql-server/root_password password ${MYSQL_ROOT_PWD}"
    debconf-set-selections <<<"mysql-server mysql-server/root_password_again password ${MYSQL_ROOT_PWD}"
fi

# Update everything but don't do the annoying prompts during apt installs
echo -e "${GREY}Updating base Linux OS..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq &>>${INSTALL_LOG}
apt-get upgrade -qq -y &>>${INSTALL_LOG}
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Download Guacamole mysql specific components
echo -e "${GREY}Downloading Guacamole database source files..."
wget -q --show-progress -O guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed to download guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz" 1>&2
    echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz"
    exit 1
else
    tar -xzf guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz
fi
echo -e "${LGREEN}Downloaded guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz${GREY}"

echo
echo -e "${GREY}Installing MySQL packages and dependencies..."
apt-get -qq -y install expect ${MYSQLV} &>>${INSTALL_LOG}
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Find the location of the MySQL config files
for x in /etc/mysql/mariadb.conf.d/50-server.cnf \
    /etc/mysql/mysql.conf.d/mysqld.cnf \
    /etc/mysql/my.cnf; do
    # Check the path exists
    if [ -e "${x}" ]; then
        # Does it have the necessary section?
        if grep -q '^\[mysqld\]$' "${x}"; then
            mysqlconfig="${x}"
            break
        fi
    fi
done

if [ -z "${mysqlconfig}" ]; then
    echo -e "${GREY}Couldn't detect MySQL config file - you may need to manually enter timezone settings"
else
    # Is there already a timzeone value configured?
    if grep -q "^default_time_zone[[:space:]]=" "${mysqlconfig}"; then
        echo -e "MySQL database timezone defined in ${mysqlconfig}"
    else
        timezone=${DB_TZ}
        if [ -z "${DB_TZ}" ]; then
            echo -e "Couldn't find system timezone, using UTC$"
            timezone="UTC"
        fi
        echo -e "Setting MySQL database timezone as ${timezone}${GREY}"
        mysql_tzinfo_to_sql /usr/share/zoneinfo 2>/dev/null | mysql -u root -D mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT}
        sed -i -e "/^\[mysqld\]/a default_time_zone = ${timezone}" "${mysqlconfig}"
        # Restart to apply
        systemctl restart mysql
    fi
fi
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Restart MySQL service
    echo -e "${GREY}Restarting MySQL service & enable at boot..."
    # Set MySQl to start at boot
    systemctl enable mysql
    systemctl restart mysql
    if [ $? -ne 0 ]; then
        echo -e "${LRED}Failed${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi

# Create ${GUAC_DB} and grant ${GUAC_USER} permissions to it
GUAC_USERHost="localhost"
if [[ "${MYSQL_HOST}" != "localhost" ]]; then
    GUAC_USERHost="%"
    echo -e "${YELLOW}MySQL Guacamole user is set to accept login from any host, please change this for security reasons if possible.${GREY}"
fi

# Check if ${GUAC_DB} is already present
echo -e "${GREY}Checking MySQL for existing database (${GUAC_DB})"
SQLCODE="
SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${GUAC_DB}';"

# Execute SQL code
MYSQL_RESULT=$(echo ${SQLCODE} | mysql -u root -D information_schema -h ${MYSQL_HOST} -P ${MYSQL_PORT})
if [[ $MYSQL_RESULT != "" ]]; then
    echo -e "${LRED}It appears there is already a MySQL database (${GUAC_DB}) on ${MYSQL_HOST}${GREY}" 1>&2
    echo -e "${LRED}Try:    mysql -e 'DROP DATABASE ${GUAC_DB}'${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Check if ${GUAC_USER} is already present
echo -e "${GREY}Checking MySQL for existing user (${GUAC_USER})"
SQLCODE="
SELECT COUNT(*) FROM mysql.user WHERE user = '${GUAC_USER}';"

# Execute SQL code
MYSQL_RESULT=$(echo ${SQLCODE} | mysql -u root -D mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} | grep '0')
if [[ $MYSQL_RESULT == "" ]]; then
    echo -e "${LRED}It appears there is already a MySQL user (${GUAC_USER}) on ${MYSQL_HOST}${GREY}" 1>&2
    echo -e "${LRED}Try:    mysql -e \"DROP USER '${GUAC_USER}'@'${GUAC_USERHost}'; FLUSH PRIVILEGES;\"${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Create database & user, then set permissions
SQLCODE="
DROP DATABASE IF EXISTS ${GUAC_DB};
CREATE DATABASE IF NOT EXISTS ${GUAC_DB};
CREATE USER IF NOT EXISTS '${GUAC_USER}'@'${GUAC_USERHost}' IDENTIFIED BY \"${GUAC_PWD}\";
GRANT SELECT,INSERT,UPDATE,DELETE ON ${GUAC_DB}.* TO '${GUAC_USER}'@'${GUAC_USERHost}';
FLUSH PRIVILEGES;"

# Execute SQL code
echo ${SQLCODE} | mysql -u root -D mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT}

# Add Guacamole schema to newly created database
echo -e "${GREY}Adding database tables..."
cat guacamole-auth-jdbc-${GUAC_VERSION}/mysql/schema/*.sql | mysql -u root -D ${GUAC_DB} -h ${MYSQL_HOST} -P ${MYSQL_PORT}
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Apply Secure MySQL installation settings
if [ "${SECURE_MYSQL}" = true ]; then
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
    if [ $? -ne 0 ]; then
        echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

# Cleanup
echo -e "${GREY}Cleaning up install files...${GREY}"
sudo apt-get -y remove expect &>>${INSTALL_LOG}
sudo apt-get -y autoremove &>>${INSTALL_LOG}
rm -rf guacamole-*
if [ $? -ne 0 ]; then
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
