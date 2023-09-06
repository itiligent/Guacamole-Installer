#!/bin/bash
#######################################################################################################################
# Guacamole main build script
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

# Pre-seed MySQL install values
if [ "${INSTALL_MYSQL}" = true ]; then
    debconf-set-selections <<<"mysql-server mysql-server/root_password password ${MYSQL_ROOT_PWD}"
    debconf-set-selections <<<"mysql-server mysql-server/root_password_again password ${MYSQL_ROOT_PWD}"
fi

# Checking if (any kind of) mysql-client or compatible command installed. This is useful for existing mariadb server
if [ "${INSTALL_MYSQL}" = true ]; then
    MYSQL="${MYSQLSRV}"
elif [ -x "$(command -v mysql)" ]; then
    MYSQL=""
else
    MYSQL="${MYSQLCLIENT}"
fi

# Don't do annoying prompts during apt installs
echo -e "${GREY}Updating base Linux OS..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq &>>${LOG_LOCATION}
apt-get upgrade -qq -y &>>${LOG_LOCATION}
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Install Guacamole build dependencies.
echo -e "${GREY}Installing dependencies required for building Guacamole, this might take a few minutes..."

if [ -n "${MYSQL_VERSION}" ]; then
    # Add the Official MariaDB repo.
    apt-get -qq -y install curl gnupg2 &>>${LOG_LOCATION}
    curl -LsS -O https://downloads.mariadb.com/MariaDB/mariadb_repo_setup &>>${LOG_LOCATION}
    bash mariadb_repo_setup --mariadb-server-version=$MYSQL_VERSION &>>${LOG_LOCATION}
fi

apt-get -qq -y install ${JPEGTURBO} ${LIBPNG} ufw htop pwgen wget crudini expect build-essential libcairo2-dev libtool-bin uuid-dev libavcodec-dev libavformat-dev libavutil-dev \
    libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libwebsockets-dev libpulse-dev libssl-dev \
    libvorbis-dev libwebp-dev ghostscript ${MYSQL} ${TOMCAT_VERSION} &>>${LOG_LOCATION}
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
fi

# Install Postfix with default settings for smtp email relay
echo
echo -e "${GREY}Installing Postfix MTA for backup email notifications and alerts, see separate SMTP relay configuration script..."
DEBIAN_FRONTEND="noninteractive" apt-get install postfix mailutils -qq -y &>>${LOG_LOCATION}
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
fi
systemctl restart postfix

# Download Guacamole Server
echo
echo -e "${GREY}Downloading Guacamole source files..."
wget -q --show-progress -O guacamole-server-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/source/guacamole-server-${GUAC_VERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed to download guacamole-server-${GUAC_VERSION}.tar.gz" 1>&2
    echo -e "${GUAC_SOURCE_LINK}/source/guacamole-server-${GUAC_VERSION}.tar.gz${GREY}"
    exit 1
else
    tar -xzf guacamole-server-${GUAC_VERSION}.tar.gz
fi
echo -e "${LGREEN}Downloaded guacamole-server-${GUAC_VERSION}.tar.gz${GREY}"

# Download Guacamole Client
wget -q --show-progress -O guacamole-${GUAC_VERSION}.war ${GUAC_SOURCE_LINK}/binary/guacamole-${GUAC_VERSION}.war
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed to download guacamole-${GUAC_VERSION}.war" 1>&2
    echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-${GUAC_VERSION}.war${GREY}"
    exit 1
fi
echo -e "${LGREEN}Downloaded guacamole-${GUAC_VERSION}.war (Guacamole client)${GREY}"

# Download MySQL connector/j
wget -q --show-progress -O mysql-connector-j-${MYSQLJCON}.tar.gz https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-${MYSQLJCON}.tar.gz
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed to download mysql-connector-j-${MYSQLJCON}.tar.gz" 1>&2
    echo -e "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-${MYSQLJCON}}.tar.gz${GREY}"
    exit 1
else
    tar -xzf mysql-connector-j-${MYSQLJCON}.tar.gz
fi
echo -e "${LGREEN}Downloaded mysql-connector-j-${MYSQLJCON}.tar.gz${GREY}"

# Download Guacamole authentication extensions
wget -q --show-progress -O guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed to download guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz" 1>&2
    echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz"
    exit 1
else
    tar -xzf guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz
fi
echo -e "${LGREEN}Downloaded guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz${GREY}"

# Download TOTP extension
if [ "${INSTALL_TOTP}" = true ]; then
    wget -q --show-progress -O guacamole-auth-totp-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-totp-${GUAC_VERSION}.tar.gz
    rm -f add-auth-totp.sh 
    if [ $? -ne 0 ]; then
        echo -e "${LRED}Failed to download guacamole-auth-totp-${GUAC_VERSION}.tar.gz" 1>&2
        echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-totp-${GUAC_VERSION}.tar.gz"
        exit 1
    else
        tar -xzf guacamole-auth-totp-${GUAC_VERSION}.tar.gz
    fi
    echo -e "${LGREEN}Downloaded guacamole-auth-totp-${GUAC_VERSION}.tar.gz${GREY}"
fi

# Download DUO extension
if [ "${INSTALL_DUO}" = true ]; then
    wget -q --show-progress -O guacamole-auth-duo-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-duo-${GUAC_VERSION}.tar.gz
    rm -f add-auth-duo.sh
    if [ $? -ne 0 ]; then
        echo -e "${LRED}Failed to download guacamole-auth-duo-${GUAC_VERSION}.tar.gz" 1>&2
        echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-duo-${GUAC_VERSION}.tar.gz"
        exit 1
    else
        tar -xzf guacamole-auth-duo-${GUAC_VERSION}.tar.gz
    fi
    echo -e "${LGREEN}Downloaded guacamole-auth-duo-${GUAC_VERSION}.tar.gz${GREY}"
fi

# Download LDAP extension
if [ "${INSTALL_LDAP}" = true ]; then
    wget -q --show-progress -O guacamole-auth-ldap-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-ldap-${GUAC_VERSION}.tar.gz
    rm -f add-auth-ldap.sh  
    if [ $? -ne 0 ]; then
        echo -e "${LRED}Failed to download guacamole-auth-ldap-${GUAC_VERSION}.tar.gz" 1>&2
        echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-ldap-${GUAC_VERSION}.tar.gz"
        exit 1
    else
        tar -xzf guacamole-auth-ldap-${GUAC_VERSION}.tar.gz
    fi
    echo -e "${LGREEN}Downloaded guacamole-auth-ldap-${GUAC_VERSION}.tar.gz${GREY}"
fi

# Download Guacamole quick-connect extension
if [ "${INSTALL_QCONNECT}" = true ]; then
    wget -q --show-progress -O guacamole-auth-quickconnect-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-quickconnect-${GUAC_VERSION}.tar.gz
    rm -f add-xtra-quickconnect.sh 
    if [ $? -ne 0 ]; then
        echo -e "${LRED}Failed to download guacamole-auth-quickconnect-${GUAC_VERSION}.tar.gz" 1>&2
        echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-quickconnect-${GUAC_VERSION}.tar.gz"
        exit 1
    else
        tar -xzf guacamole-auth-quickconnect-${GUAC_VERSION}.tar.gz
    fi
echo -e "${LGREEN}Downloaded guacamole-auth-quickconnect-${GUAC_VERSION}.tar.gz${GREY}"
fi

# Download Guacamole history recording storage extension
if [ "${INSTALL_HISTREC}" = true ]; then
    wget -q --show-progress -O guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz
    rm -f add-xtra-histrecstor.sh 
    if [ $? -ne 0 ]; then
        echo -e "${LRED}Failed to download guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz" 1>&2
        echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz"
        exit 1
    else
        tar -xzf guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz
    fi
    echo -e "${LGREEN}Downloaded guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz${GREY}"
fi
echo -e "Source download complete.${GREY}"

# Option to pause script here as we might want to make final tweaks to source code just before compiling
#echo -e "${LYELLOW}"
#read -p $'Script paused for (optional) tweaking of source before building. Enter to Continue...\n'
#echo -e "${GREY}"

# Add customised RDP share names and printer labels, remove Guacamole default labelling
sed -i -e 's/IDX_CLIENT_NAME, "Guacamole RDP"/IDX_CLIENT_NAME, "'"${RDP_SHARE_HOST}"'"/' ${DOWNLOAD_DIR}/guacamole-server-${GUAC_VERSION}/src/protocols/rdp/settings.c
sed -i -e 's/IDX_DRIVE_NAME, "Guacamole Filesystem"/IDX_CLIENT_NAME, "'"${RDP_SHARE_LABEL}"'"/' ${DOWNLOAD_DIR}/guacamole-server-${GUAC_VERSION}/src/protocols/rdp/settings.c
sed -i -e 's/IDX_PRINTER_NAME, "Guacamole Printer"/IDX_PRINTER_NAME, "'"${RDP_PRINTER_LABEL}"'"/' ${DOWNLOAD_DIR}/guacamole-server-${GUAC_VERSION}/src/protocols/rdp/settings.c

# Make Guacamole directories
rm -rf /etc/guacamole/lib/
rm -rf /etc/guacamole/extensions/
mkdir -p /etc/guacamole/lib/
mkdir -p /etc/guacamole/extensions/

# Fix for #196 see https://github.com/MysticRyuujin/guac-install/issues/196
mkdir -p /usr/sbin/.config/freerdp
chown daemon:daemon /usr/sbin/.config/freerdp

# Fix for #197 see https://github.com/MysticRyuujin/guac-install/issues/197
mkdir -p /var/guacamole
chown daemon:daemon /var/guacamole

# Make and install guacd (Guacamole-Server)
cd guacamole-server-${GUAC_VERSION}/
echo
echo -e "${GREY}Compiling Guacamole-Server from source with with GCC $(gcc --version | head -n1 | grep -oP '\)\K.*' | awk '{print $1}'), this might take a few minutes...${GREY}"

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

echo -e "${GREY}Running make and building the Guacamole-Server application..."
make &>>${LOG_LOCATION}
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

echo -e "${GREY}Installing Guacamole-Server..."
make install &>>${LOG_LOCATION}
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi
ldconfig

# Move files to correct install locations (guacamole-client & Guacamole authentication extensions)
cd ..
mv -f guacamole-${GUAC_VERSION}.war /etc/guacamole/guacamole.war
chmod 664 /etc/guacamole/guacamole.war
mv -f guacamole-auth-jdbc-${GUAC_VERSION}/mysql/guacamole-auth-jdbc-mysql-${GUAC_VERSION}.jar /etc/guacamole/extensions/
chmod 664 /etc/guacamole/extensions/guacamole-auth-jdbc-mysql-${GUAC_VERSION}.jar

# Create a symbolic link for Tomcat
ln -sf /etc/guacamole/guacamole.war /var/lib/${TOMCAT_VERSION}/webapps/

# Move MySQL connector/j files
echo -e "${GREY}Moving mysql-connector-j-${MYSQLJCON}.jar (/etc/guacamole/lib/mysql-connector-java.jar)..."
mv -f mysql-connector-j-${MYSQLJCON}/mysql-connector-j-${MYSQLJCON}.jar /etc/guacamole/lib/mysql-connector-java.jar
chmod 664 /etc/guacamole/lib/mysql-connector-java.jar
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Configure guacamole.properties file
rm -f /etc/guacamole/guacamole.properties
touch /etc/guacamole/guacamole.properties
echo "mysql-hostname: ${MYSQL_HOST}" >>/etc/guacamole/guacamole.properties
echo "mysql-port: ${MYSQL_PORT}" >>/etc/guacamole/guacamole.properties
echo "mysql-database: ${GUAC_DB}" >>/etc/guacamole/guacamole.properties
echo "mysql-username: ${GUAC_USER}" >>/etc/guacamole/guacamole.properties
echo "mysql-password: ${GUAC_PWD}" >>/etc/guacamole/guacamole.properties

# Move TOTP files
if [ "${INSTALL_TOTP}" = true ]; then
    echo -e "${GREY}Moving guacamole-auth-totp-${GUAC_VERSION}.jar (/etc/guacamole/extensions/)..."
    mv -f guacamole-auth-totp-${GUAC_VERSION}/guacamole-auth-totp-${GUAC_VERSION}.jar /etc/guacamole/extensions/
    chmod 664 /etc/guacamole/extensions/guacamole-auth-totp-${GUAC_VERSION}.jar
    if [ $? -ne 0 ]; then
        echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

# Move Duo files
if [ "${INSTALL_DUO}" = true ]; then
    echo -e "${GREY}Moving guacamole-auth-duo-${GUAC_VERSION}.jar (/etc/guacamole/extensions/)..."
    mv -f guacamole-auth-duo-${GUAC_VERSION}/guacamole-auth-duo-${GUAC_VERSION}.jar /etc/guacamole/extensions/
    chmod 664 /etc/guacamole/extensions/guacamole-auth-duo-${GUAC_VERSION}.jar
    echo "#duo-api-hostname: " >>/etc/guacamole/guacamole.properties
    echo "#duo-integration-key: " >>/etc/guacamole/guacamole.properties
    echo "#duo-secret-key: " >>/etc/guacamole/guacamole.properties
    echo "#duo-application-key: " >>/etc/guacamole/guacamole.properties
    echo -e "Duo auth is installed, it will need to be configured via guacamole.properties"
    if [ $? -ne 0 ]; then
        echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

# Move LDAP files
if [ "${INSTALL_LDAP}" = true ]; then
    echo -e "${GREY}Moving guacamole-auth-ldap-${GUAC_VERSION}.jar (/etc/guacamole/extensions/)..."
    mv -f guacamole-auth-ldap-${GUAC_VERSION}/guacamole-auth-ldap-${GUAC_VERSION}.jar /etc/guacamole/extensions/
    chmod 664 /etc/guacamole/extensions/guacamole-auth-ldap-${GUAC_VERSION}.jar
    echo "#If you have issues with LDAP, check the formatting is exactly as below or you will despair!" >>/etc/guacamole/guacamole.properties
    echo "#Be extra careful with spaces at line ends or with windows line feeds." >>/etc/guacamole/guacamole.properties
    echo "#ldap-hostname: dc1.yourdomain.com dc2.yourdomain.com" >>/etc/guacamole/guacamole.properties
    echo "#ldap-port: 389" >>/etc/guacamole/guacamole.properties
    echo "#ldap-username-attribute: sAMAccountName" >>/etc/guacamole/guacamole.properties
    echo "#ldap-encryption-method: none" >>/etc/guacamole/guacamole.properties
    echo "#ldap-search-bind-dn: ad-account@yourdomain.com" >>/etc/guacamole/guacamole.properties
    echo "#ldap-search-bind-password: ad-account-password" >>/etc/guacamole/guacamole.properties
    echo "#ldap-config-base-dn: dc=domain,dc=com" >>/etc/guacamole/guacamole.properties
    echo "#ldap-user-base-dn: OU=SomeOU,DC=domain,DC=com" >>/etc/guacamole/guacamole.properties
    echo "#ldap-user-search-filter:(objectClass=user)(!(objectCategory=computer))" >>/etc/guacamole/guacamole.properties
    echo "#ldap-max-search-results:200" >>/etc/guacamole/guacamole.properties
    if [ $? -ne 0 ]; then
        echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

# Move quick-connect extension files
if [ "${INSTALL_QCONNECT}" = true ]; then
    echo -e "${GREY}Moving guacamole-auth-quickconnect-${GUAC_VERSION}.jar (/etc/guacamole/extensions/)..."
    mv -f guacamole-auth-quickconnect-${GUAC_VERSION}/guacamole-auth-quickconnect-${GUAC_VERSION}.jar /etc/guacamole/extensions/
    chmod 664 /etc/guacamole/extensions/guacamole-auth-quickconnect-${GUAC_VERSION}.jar
    if [ $? -ne 0 ]; then
        echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

# Move history recording storage extension files
if [ "${INSTALL_HISTREC}" = true ]; then
    echo -e "${GREY}Moving guacamole-history-recording-storage-${GUAC_VERSION}.jar (/etc/guacamole/extensions/)..."
    mv -f guacamole-history-recording-storage-${GUAC_VERSION}/guacamole-history-recording-storage-${GUAC_VERSION}.jar /etc/guacamole/extensions/
    chmod 664 /etc/guacamole/extensions/guacamole-history-recording-storage-${GUAC_VERSION}.jar
    #Setup the default recording path
    mkdir -p ${HISTREC_PATH}
    chown daemon:tomcat ${HISTREC_PATH}
    chmod 2750 ${HISTREC_PATH}
    echo "recording-search-path: ${HISTREC_PATH}" >>/etc/guacamole/guacamole.properties
    if [ $? -ne 0 ]; then
        echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

# Apply a branded interface and dark theme. You may delete this file and restart guacd & tomcat for the default console
echo -e "${GREY}Setting the Guacamole console to a (customisable) dark mode themed template..."
mv branding.jar /etc/guacamole/extensions
chmod 664 /etc/guacamole/extensions/branding.jar
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Restart Tomcat
echo -e "${GREY}Restarting Tomcat service & enable at boot..."
systemctl restart ${TOMCAT_VERSION}
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
fi
# Set Tomcat to start at boot
systemctl enable ${TOMCAT_VERSION}
echo

# Set MySQL password
export MYSQL_PWD=${MYSQL_ROOT_PWD}

# Default locations of MySQL config files
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
    # Is there already a value?
    if grep -q "^default_time_zone[[:space:]]?=" "${mysqlconfig}"; then
        echo -e "MySQL database timezone already defined in ${mysqlconfig}"
    else
        timezone="$(cat /etc/timezone)"
        if [ -z "${timezone}" ]; then
            echo -e "Couldn't find system timezone, using UTC$"
            timezone="UTC"
        fi
        echo -e "Setting MySQL database timezone as ${timezone}${GREY}"
        # Fix for https://issues.apache.org/jira/browse/GUACAMOLE-760
        mysql_tzinfo_to_sql /usr/share/zoneinfo 2>/dev/null | mysql -u root -D mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT}
        crudini --set ${mysqlconfig} mysqld default_time_zone "${timezone}"
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
if [ "${INSTALL_MYSQL}" = true ]; then
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
fi

# Create ${GUAC_DB} and grant ${GUAC_USER} permissions to it
# SQL code
GUAC_USERHost="localhost"
if [[ "${MYSQL_HOST}" != "localhost" ]]; then
    GUAC_USERHost="%"
    echo -e "${YELLOW}MySQL Guacamole user is set to accept login from any host, please change this for security reasons if possible.${GREY}"
fi

# Check for ${GUAC_DB} already being there
echo -e "${GREY}Checking MySQL for existing database (${GUAC_DB})"
SQLCODE="
SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${GUAC_DB}';"

# Execute SQL code
MYSQL_RESULT=$(echo ${SQLCODE} | mysql -u root -D information_schema -h ${MYSQL_HOST} -P ${MYSQL_PORT})
if [[ $MYSQL_RESULT != "" ]]; then
    echo -e "${LRED}It appears there is already a MySQL database (${GUAC_DB}) on ${MYSQL_HOST}${GREY}" 1>&2
    echo -e "${LRED}Try:    mysql -e 'DROP DATABASE ${GUAC_DB}'${GREY}" 1>&2
#exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Check for ${GUAC_USER} already being there
echo -e "${GREY}Checking MySQL for existing user (${GUAC_USER})"
SQLCODE="
SELECT COUNT(*) FROM mysql.user WHERE user = '${GUAC_USER}';"

# Execute SQL code
MYSQL_RESULT=$(echo ${SQLCODE} | mysql -u root -D mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} | grep '0')
if [[ $MYSQL_RESULT == "" ]]; then
    echo -e "${LRED}It appears there is already a MySQL user (${GUAC_USER}) on ${MYSQL_HOST}${GREY}" 1>&2
    echo -e "${LRED}Try:    mysql -e \"DROP USER '${GUAC_USER}'@'${GUAC_USERHost}'; FLUSH PRIVILEGES;\"${GREY}" 1>&2
#exit 1
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

# Create guacd.conf and locahost IP binding.
echo -e "${GREY}Binding guacd to 127.0.0.1 port 4822..."
cat >/etc/guacamole/guacd.conf <<-"EOF"
[server]
bind_host = 127.0.0.1
bind_port = 4822
EOF
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Ensure guacd is started
echo -e "${GREY}Starting guacd service & enable at boot..."
systemctl enable guacd
systemctl stop guacd 2>/dev/null
systemctl start guacd
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
rm -rf mysql-connector-j-*
rm -rf mariadb_repo_setup
unset MYSQL_PWD
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Apply Secure MySQL installation settings
if [ "${SECURE_MYSQL}" = true ]; then
    echo -e "${GREY}Applying mysql_secure_installation settings...${DGREY}"
    MYSQLPW=${MYSQL_ROOT_PWD}
    SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"$MYSQLPW\r\"
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
        echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

if [ "${CHANGE_ROOT}" = true ]; then
    echo -e "${GREY}Shortening the Guacamole root url and setting up redirect...${DGREY}"
    systemctl stop ${TOMCAT_VERSION}
    mv /var/lib/${TOMCAT_VERSION}/webapps/ROOT/index.html index.html.old
    touch /var/lib/${TOMCAT_VERSION}/webapps/ROOT/index.jsp
    echo "<% response.sendRedirect(\"/guacamole\");%>" >>/var/lib/${TOMCAT_VERSION}/webapps/ROOT/index.jsp
    systemctl start ${TOMCAT_VERSION}
    if [ $? -ne 0 ]; then
        echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

echo -e "${GREY}Updating firewall rules to allow only SSH and tcp 8080..."
sudo ufw default allow outgoing >/dev/null 2>&1
sudo ufw default deny incoming >/dev/null 2>&1
sudo ufw allow OpenSSH >/dev/null 2>&1
sudo ufw allow 8080/tcp >/dev/null 2>&1
echo "y" | sudo ufw enable >/dev/null 2>&1
# Reduce firewall logging noise
sudo ufw logging off >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${LRED}Failed. See ${LOG_LOCATION}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
fi

# Done
echo -e ${NC}
