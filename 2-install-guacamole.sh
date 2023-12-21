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


# Update everything but don't do the annoying prompts during apt installs
echo -e "${GREY}Updating base Linux OS..."
export DEBIAN_FRONTEND=noninteractive
spinner() {
  local pid=$1
  local delay=0.15
  local spinstr='|/-\'
  tput civis
  while ps -p $pid > /dev/null; do
    for i in $(seq 0 3); do
      tput sc
      printf "[%c]" "${spinstr:$i:1}"
      tput rc
      sleep $delay
    done
  done
  tput cnorm
  printf "       "
  tput rc
}
apt-get upgrade -qq -y &>>${INSTALL_LOG} &
command_pid=$!
spinner $command_pid
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Pre-seed MySQL root password values for Linux Distro default packages only
if [[ "${INSTALL_MYSQL}" = true ]] && [[ -z "${MYSQL_VERSION}" ]]; then
    debconf-set-selections <<<"mysql-server mysql-server/root_password password ${MYSQL_ROOT_PWD}"
    debconf-set-selections <<<"mysql-server mysql-server/root_password_again password ${MYSQL_ROOT_PWD}"
fi

# Install official MariaDB repo and MariaDB version if a specific version number was provided.
if [[ -n "${MYSQL_VERSION}" ]]; then
    echo -e "${GREY}Adding the official MariaDB repository and installing version ${MYSQL_VERSION}..."
    # Add the Official MariaDB repo.
    apt-get -qq -y install curl gnupg2 &>>${INSTALL_LOG}
    curl -LsS -O ${MARIADB_LINK} &>>${INSTALL_LOG}
    bash mariadb_repo_setup --mariadb-server-version=$MYSQL_VERSION &>>${INSTALL_LOG}
    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

# Select the appropriate MySQL client or server packages, and don't clobber any pre-existing database installation accidentally
if [[ "${INSTALL_MYSQL}" = true ]]; then
    MYSQLPKG="${MYSQLSRV}"
elif [ -x "$(command -v ${DB_CMD})" ]; then
     MYSQLPKG=""
else
    MYSQLPKG="${MYSQLCLIENT}"
fi

# Install Guacamole build dependencies (pwgen needed for duo config only, expect is auto removed after install)
echo -e "${GREY}Installing dependencies required for building Guacamole, this might take a few minutes..."
spinner() {
  local pid=$1
  local delay=0.15
  local spinstr='|/-\'
  tput civis
  while ps -p $pid > /dev/null; do
    for i in $(seq 0 3); do
      tput sc
      printf "[%c]" "${spinstr:$i:1}"
      tput rc
      sleep $delay
    done
  done
  tput cnorm
  printf "       "
  tput rc
}
apt-get -qq -y install ${MYSQLPKG} ${TOMCAT_VERSION} ${JPEGTURBO} ${LIBPNG} ufw pwgen expect \
    build-essential libcairo2-dev libtool-bin uuid-dev libavcodec-dev libavformat-dev libavutil-dev \
    libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libwebsockets-dev \
    libpulse-dev libssl-dev libvorbis-dev libwebp-dev ghostscript &>>${INSTALL_LOG} &
command_pid=$!
spinner $command_pid
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Install Postfix with default settings for smtp email relay
echo -e "${GREY}Installing Postfix MTA for backup email notifications and alerts, see separate SMTP relay configuration script..."
spinner() {
  local pid=$1
  local delay=0.15
  local spinstr='|/-\'
  tput civis
  while ps -p $pid > /dev/null; do
    for i in $(seq 0 3); do
      tput sc
      printf "[%c]" "${spinstr:$i:1}"
      tput rc
      sleep $delay
    done
  done
  tput cnorm
  printf "       "
  tput rc
}
DEBIAN_FRONTEND="noninteractive" apt-get install postfix mailutils -qq -y &>>${INSTALL_LOG} &
command_pid=$!
spinner $command_pid
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    systemctl restart postfix
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Download Guacamole Server
echo -e "${GREY}Downloading Guacamole source files..."
wget -q --show-progress -O guacamole-server-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/source/guacamole-server-${GUAC_VERSION}.tar.gz
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed to download guacamole-server-${GUAC_VERSION}.tar.gz" 1>&2
    echo -e "${GUAC_SOURCE_LINK}/source/guacamole-server-${GUAC_VERSION}.tar.gz${GREY}"
    exit 1
else
    tar -xzf guacamole-server-${GUAC_VERSION}.tar.gz
    echo -e "${LGREEN}Downloaded guacamole-server-${GUAC_VERSION}.tar.gz${GREY}"
fi

# Download Guacamole Client
wget -q --show-progress -O guacamole-${GUAC_VERSION}.war ${GUAC_SOURCE_LINK}/binary/guacamole-${GUAC_VERSION}.war
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed to download guacamole-${GUAC_VERSION}.war" 1>&2
    echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-${GUAC_VERSION}.war${GREY}"
    exit 1
else
    echo -e "${LGREEN}Downloaded guacamole-${GUAC_VERSION}.war${GREY}"
fi

# Download MySQL connector/j
wget -q --show-progress -O mysql-connector-j-${MYSQLJCON}.tar.gz ${MYSQLJCON_LINK}
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed to download mysql-connector-j-${MYSQLJCON}.tar.gz" 1>&2
    echo -e "${MYSQLJCON_LINK}${GREY}"
    exit 1
else
    tar -xzf mysql-connector-j-${MYSQLJCON}.tar.gz
    echo -e "${LGREEN}Downloaded mysql-connector-j-${MYSQLJCON}.tar.gz${GREY}"
fi

# Download Guacamole database auth extension
wget -q --show-progress -O guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed to download guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz" 1>&2
    echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz"
    exit 1
else
    tar -xzf guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz
    echo -e "${LGREEN}Downloaded guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz${GREY}"
fi

# Download TOTP auth extension
if [[ "${INSTALL_TOTP}" = true ]]; then
    wget -q --show-progress -O guacamole-auth-totp-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-totp-${GUAC_VERSION}.tar.gz
    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed to download guacamole-auth-totp-${GUAC_VERSION}.tar.gz" 1>&2
        echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-totp-${GUAC_VERSION}.tar.gz"
        exit 1
    else
        tar -xzf guacamole-auth-totp-${GUAC_VERSION}.tar.gz
        echo -e "${LGREEN}Downloaded guacamole-auth-totp-${GUAC_VERSION}.tar.gz${GREY}"
    fi
fi

# Download DUO auth extension
if [[ "${INSTALL_DUO}" = true ]]; then
    wget -q --show-progress -O guacamole-auth-duo-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-duo-${GUAC_VERSION}.tar.gz
    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed to download guacamole-auth-duo-${GUAC_VERSION}.tar.gz" 1>&2
        echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-duo-${GUAC_VERSION}.tar.gz"
        exit 1
    else
        tar -xzf guacamole-auth-duo-${GUAC_VERSION}.tar.gz
        echo -e "${LGREEN}Downloaded guacamole-auth-duo-${GUAC_VERSION}.tar.gz${GREY}"
    fi
fi

# Download LDAP auth extension
if [[ "${INSTALL_LDAP}" = true ]]; then
    wget -q --show-progress -O guacamole-auth-ldap-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-ldap-${GUAC_VERSION}.tar.gz
    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed to download guacamole-auth-ldap-${GUAC_VERSION}.tar.gz" 1>&2
        echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-ldap-${GUAC_VERSION}.tar.gz"
        exit 1
    else
        tar -xzf guacamole-auth-ldap-${GUAC_VERSION}.tar.gz
        echo -e "${LGREEN}Downloaded guacamole-auth-ldap-${GUAC_VERSION}.tar.gz${GREY}"
    fi
fi

# Download Guacamole quick-connect extension
if [[ "${INSTALL_QCONNECT}" = true ]]; then
    wget -q --show-progress -O guacamole-auth-quickconnect-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-auth-quickconnect-${GUAC_VERSION}.tar.gz
    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed to download guacamole-auth-quickconnect-${GUAC_VERSION}.tar.gz" 1>&2
        echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-auth-quickconnect-${GUAC_VERSION}.tar.gz"
        exit 1
    else
        tar -xzf guacamole-auth-quickconnect-${GUAC_VERSION}.tar.gz
        echo -e "${LGREEN}Downloaded guacamole-auth-quickconnect-${GUAC_VERSION}.tar.gz${GREY}"
    fi
fi

# Download Guacamole history recording storage extension
if [[ "${INSTALL_HISTREC}" = true ]]; then
    wget -q --show-progress -O guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz ${GUAC_SOURCE_LINK}/binary/guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz

    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed to download guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz" 1>&2
        echo -e "${GUAC_SOURCE_LINK}/binary/guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz"
        exit 1
    else
        tar -xzf guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz
        echo -e "${LGREEN}Downloaded guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz${GREY}"
    fi
fi
echo -e "Source download complete.${GREY}"

# Place a pause in script here if you wish to make final tweaks to source code before compiling
#read -p $'Script paused for editing source before building. Enter to begin the build...\n'

# Add customised RDP share names and printer labels, remove Guacamole default labelling
sed -i -e 's/IDX_CLIENT_NAME, "Guacamole RDP"/IDX_CLIENT_NAME, "'"${RDP_SHARE_HOST}"'"/' ${DOWNLOAD_DIR}/guacamole-server-${GUAC_VERSION}/src/protocols/rdp/settings.c
sed -i -e 's/IDX_DRIVE_NAME, "Guacamole Filesystem"/IDX_CLIENT_NAME, "'"${RDP_SHARE_LABEL}"'"/' ${DOWNLOAD_DIR}/guacamole-server-${GUAC_VERSION}/src/protocols/rdp/settings.c
sed -i -e 's/IDX_PRINTER_NAME, "Guacamole Printer"/IDX_PRINTER_NAME, "'"${RDP_PRINTER_LABEL}"'"/' ${DOWNLOAD_DIR}/guacamole-server-${GUAC_VERSION}/src/protocols/rdp/settings.c

# Make Guacamole directories
rm -rf /etc/guacamole/lib/
rm -rf /etc/guacamole/extensions/
mkdir -p /etc/guacamole/lib/
mkdir -p /etc/guacamole/extensions/

# Setup freerdp profile permissions for storing certificates
mkdir -p /usr/sbin/.config/freerdp
chown daemon:daemon /usr/sbin/.config/freerdp

# Setup correct permissions for history recorded storage feature
mkdir -p /var/guacamole
chown daemon:daemon /var/guacamole

# Make and install guacd (Guacamole-Server)
cd guacamole-server-${GUAC_VERSION}/
echo
echo -e "${GREY}Compiling Guacamole-Server from source with with GCC $(gcc --version | head -n1 | grep -oP '\)\K.*' | awk '{print $1}'), this might take a few minutes...${GREY}"

# Skip any deprecated software warnings various distros may throw during build
export CFLAGS="-Wno-error"

# Configure Guacamole Server source
spinner() {
  local pid=$1
  local delay=0.15
  local spinstr='|/-\'
  tput civis
  while ps -p $pid > /dev/null; do
    for i in $(seq 0 3); do
      tput sc
      printf "[%c]" "${spinstr:$i:1}"
      tput rc
      sleep $delay
    done
  done
  tput cnorm
  printf "       "
  tput rc
}
./configure --with-systemd-dir=/etc/systemd/system &>>${INSTALL_LOG} &
command_pid=$!
spinner $command_pid
if [[ $? -ne 0 ]]; then
    echo "Failed to configure guacamole-server"
    echo "Trying again with --enable-allow-freerdp-snapshots"
    ./configure --with-systemd-dir=/etc/systemd/system --enable-allow-freerdp-snapshots
    if [[ $? -ne 0 ]]; then
        echo "Failed to configure guacamole-server - again"
        exit
    fi
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

echo -e "${GREY}Running make and building the Guacamole-Server application..."
spinner() {
  local pid=$1
  local delay=0.15
  local spinstr='|/-\'
  tput civis
  while ps -p $pid > /dev/null; do
    for i in $(seq 0 3); do
      tput sc
      printf "[%c]" "${spinstr:$i:1}"
      tput rc
      sleep $delay
    done
  done
  tput cnorm
  printf "       "
  tput rc
}
make &>>${INSTALL_LOG} &
command_pid=$!
spinner $command_pid
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

echo -e "${GREY}Installing Guacamole-Server..."
make install &>>${INSTALL_LOG}
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Update the shared library cache
ldconfig

# Move Guacamole client and authentication extensions to their correct install locations
cd ..
echo -e "${GREY}Moving guacamole-${GUAC_VERSION}.war (/etc/guacamole/extensions/)..."
mv -f guacamole-${GUAC_VERSION}.war /etc/guacamole/guacamole.war
chmod 664 /etc/guacamole/guacamole.war
# Create a symbolic link for Tomcat
ln -sf /etc/guacamole/guacamole.war /var/lib/${TOMCAT_VERSION}/webapps/ &>>${INSTALL_LOG}
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

echo -e "${GREY}Moving guacamole-auth-jdbc-mysql-${GUAC_VERSION}.jar (/etc/guacamole/extensions/)..."
mv -f guacamole-auth-jdbc-${GUAC_VERSION}/mysql/guacamole-auth-jdbc-mysql-${GUAC_VERSION}.jar /etc/guacamole/extensions/
chmod 664 /etc/guacamole/extensions/guacamole-auth-jdbc-mysql-${GUAC_VERSION}.jar
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Move MySQL connector/j files
echo -e "${GREY}Moving mysql-connector-j-${MYSQLJCON}.jar (/etc/guacamole/lib/mysql-connector-java.jar)..."
mv -f mysql-connector-j-${MYSQLJCON}/mysql-connector-j-${MYSQLJCON}.jar /etc/guacamole/lib/mysql-connector-java.jar
chmod 664 /etc/guacamole/lib/mysql-connector-java.jar
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
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
if [[ "${INSTALL_TOTP}" = true ]]; then
    echo -e "${GREY}Moving guacamole-auth-totp-${GUAC_VERSION}.jar (/etc/guacamole/extensions/)..."
    mv -f guacamole-auth-totp-${GUAC_VERSION}/guacamole-auth-totp-${GUAC_VERSION}.jar /etc/guacamole/extensions/
    chmod 664 /etc/guacamole/extensions/guacamole-auth-totp-${GUAC_VERSION}.jar
    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

# Move Duo files
if [[ "${INSTALL_DUO}" = true ]]; then
    echo -e "${GREY}Moving guacamole-auth-duo-${GUAC_VERSION}.jar (/etc/guacamole/extensions/)..."
    mv -f guacamole-auth-duo-${GUAC_VERSION}/guacamole-auth-duo-${GUAC_VERSION}.jar /etc/guacamole/extensions/
    chmod 664 /etc/guacamole/extensions/guacamole-auth-duo-${GUAC_VERSION}.jar
    echo "#duo-api-hostname: " >>/etc/guacamole/guacamole.properties
    echo "#duo-integration-key: " >>/etc/guacamole/guacamole.properties
    echo "#duo-secret-key: " >>/etc/guacamole/guacamole.properties
    echo "#duo-application-key: " >>/etc/guacamole/guacamole.properties
    echo -e "Duo auth is installed, it will need to be configured via guacamole.properties"
    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

# Move LDAP files
if [[ "${INSTALL_LDAP}" = true ]]; then
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
    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

# Move quick-connect extension files
if [[ "${INSTALL_QCONNECT}" = true ]]; then
    echo -e "${GREY}Moving guacamole-auth-quickconnect-${GUAC_VERSION}.jar (/etc/guacamole/extensions/)..."
    mv -f guacamole-auth-quickconnect-${GUAC_VERSION}/guacamole-auth-quickconnect-${GUAC_VERSION}.jar /etc/guacamole/extensions/
    chmod 664 /etc/guacamole/extensions/guacamole-auth-quickconnect-${GUAC_VERSION}.jar
    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

# Move history recording storage extension files
if [[ "${INSTALL_HISTREC}" = true ]]; then
    echo -e "${GREY}Moving guacamole-history-recording-storage-${GUAC_VERSION}.jar (/etc/guacamole/extensions/)..."
    mv -f guacamole-history-recording-storage-${GUAC_VERSION}/guacamole-history-recording-storage-${GUAC_VERSION}.jar /etc/guacamole/extensions/
    chmod 664 /etc/guacamole/extensions/guacamole-history-recording-storage-${GUAC_VERSION}.jar
    #Setup the default recording path
    mkdir -p ${HISTREC_PATH}
    chown daemon:tomcat ${HISTREC_PATH}
    chmod 2750 ${HISTREC_PATH}
    echo "recording-search-path: ${HISTREC_PATH}" >>/etc/guacamole/guacamole.properties
    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
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
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Restart Tomcat
echo -e "${GREY}Restarting Tomcat service & enable at boot..."
systemctl restart ${TOMCAT_VERSION}
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Set Tomcat to start at boot
systemctl enable ${TOMCAT_VERSION}

# Begin the MySQL database config only if this is a local MYSQL install.
if [[ "${INSTALL_MYSQL}" = true ]]; then
    # Set MySQL password
    export MYSQL_PWD=${MYSQL_ROOT_PWD}

    # Set the root password without a reliance on debconf.
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

    # Find the location of the MySQL or MariaDB config files. (Add more potential config file candidates here.)
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
                echo -e "No timezone specified, using UTC"
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

    # This below block should stay as "localhost" for all local MySQL install situations and it is driven by the $MYSQL_HOST setting. 
    # $GUAC_USERHost determines from WHERE the new ${GUAC_USER} will be able to login to the database (either from specific remote IPs 
    # or from localhost only.) 
    if [[ "${MYSQL_HOST}" != "localhost" ]]; then
        GUAC_USERHost="%"
        echo -e "${LYELLOW}${GUAC_USER} is set to accept db logins from any host, you may wish to limit this to specific IPs.${GREY}"
    else
        GUAC_USERHost="localhost"
    fi

    # Execute SQL code to create the Guacamole database
    echo -e "${GREY}Creating the Guacamole database..."
    SQLCODE="
DROP DATABASE IF EXISTS ${GUAC_DB};
CREATE DATABASE IF NOT EXISTS ${GUAC_DB};
CREATE USER IF NOT EXISTS '${GUAC_USER}'@'${GUAC_USERHost}' IDENTIFIED BY \"${GUAC_PWD}\";
GRANT SELECT,INSERT,UPDATE,DELETE ON ${GUAC_DB}.* TO '${GUAC_USER}'@'${GUAC_USERHost}';
FLUSH PRIVILEGES;"
    echo ${SQLCODE} | $DB_CMD -u root -D mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT}
    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi

    # Add Guacamole schema to newly created database
    echo -e "${GREY}Adding database tables..."
    cat guacamole-auth-jdbc-${GUAC_VERSION}/mysql/schema/*.sql | $DB_CMD -u root -D ${GUAC_DB} -p${MYSQL_ROOT_PWD}
    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

# Apply Secure MySQL installation settings
if [[ "${SECURE_MYSQL}" = true ]] && [[ "${INSTALL_MYSQL}" = true ]]; then
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

# Restart MySQL service
if [[ "${INSTALL_MYSQL}" = true ]]; then
    echo -e "${GREY}Restarting MySQL service & enable at boot..."
    # Set MySQl to start at boot
    systemctl enable mysql
    systemctl restart mysql
    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

# Create guacd.conf and localhost IP binding.
echo -e "${GREY}Binding guacd to 127.0.0.1 port 4822..."
cat >/etc/guacamole/guacd.conf <<-"EOF"
[server]
bind_host = 127.0.0.1
bind_port = 4822
EOF
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
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
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Redirect the Tomcat URL to its root to avoid typing the extra /guacamole path (if not using a reverse proxy)
if [[ "${GUAC_URL_REDIR}" = true ]] && [[ "${INSTALL_NGINX}" = false ]]; then
    echo -e "${GREY}Redirecting the Tomcat http root url to /guacamole...${DGREY}"
    systemctl stop ${TOMCAT_VERSION}
    mv /var/lib/${TOMCAT_VERSION}/webapps/ROOT/index.html /var/lib/${TOMCAT_VERSION}/webapps/ROOT/index.html.old
    touch /var/lib/${TOMCAT_VERSION}/webapps/ROOT/index.jsp
    echo "<% response.sendRedirect(\"/guacamole\");%>" >>/var/lib/${TOMCAT_VERSION}/webapps/ROOT/index.jsp
    systemctl start ${TOMCAT_VERSION}
    if [[ $? -ne 0 ]]; then
        echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
        exit 1
    else
        echo -e "${LGREEN}OK${GREY}"
        echo
    fi
fi

# Update Linux firewall
echo -e "${GREY}Updating firewall rules to allow only SSH and tcp 8080..."
ufw default allow outgoing >/dev/null 2>&1
ufw default deny incoming >/dev/null 2>&1
ufw allow OpenSSH >/dev/null 2>&1
ufw allow 8080/tcp >/dev/null 2>&1
echo "y" | sudo ufw enable >/dev/null 2>&1
ufw logging off >/dev/null 2>&1 # Reduce firewall logging noise
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Cleanup
echo -e "${GREY}Cleaning up Guacamole source files...${GREY}"
rm -rf guacamole-*
rm -rf mysql-connector-j-*
rm -rf mariadb_repo_setup
unset MYSQL_PWD
apt-get -y remove expect &>>${INSTALL_LOG}
apt-get -y autoremove &>>${INSTALL_LOG}
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Failed. See ${INSTALL_LOG}${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
fi

# Done
echo -e ${NC}
