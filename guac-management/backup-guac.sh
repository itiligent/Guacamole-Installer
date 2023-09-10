#!/bin/bash
#######################################################################################################################
# Guacamole MySQL Database Backup
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

export PATH=/bin:/usr/bin:/usr/local/bin
TODAY=$(date +%Y-%m-%d)
# Below variables are automatically updated by the 1-setup.sh script with the respective values given at install
MYSQL_HOST=
MYSQL_PORT=
GUAC_USER=
GUAC_PWD=
GUAC_DB=
DB_BACKUP_DIR=
BACKUP_EMAIL=
BACKUP_RETENTION=

# Protect disk space and remove backups older than {BACKUP_RETENTION} days
find ${DB_BACKUP_DIR} -mtime +${BACKUP_RETENTION} -delete

# Backup code
mkdir -p ${DB_BACKUP_DIR}
echo
echo -e "${LGREEN}Backup started for database - ${GUAC_DB}"
echo

mysqldump -h ${MYSQL_HOST} \
    -P ${MYSQL_PORT} \
    -u ${GUAC_USER} \
    -p"${GUAC_PWD}" \
    ${GUAC_DB} \
    --single-transaction --quick --lock-tables=false >${DB_BACKUP_DIR}${GUAC_DB}-${TODAY}.sql
SQLFILE=${DB_BACKUP_DIR}${GUAC_DB}-${TODAY}.sql
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Backup failed.${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}Backup completed ok.${GREY}"
    echo
fi
gzip -f ${SQLFILE}
# Error check and email alerts
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Backup failed.${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}${GUAC_DB} backup was successfully copied to ${DB_BACKUP_DIR}"
    #mailx -s "Guacamomle Database Backup Success" ${BACKUP_EMAIL}
    echo "${GUAC_DB} backup was successfully copied to $DB_BACKUP_DIR" | mailx -s "Guacamole backup " ${BACKUP_EMAIL}
fi

echo -e ${NC}
