#!/bin/bash
#######################################################################################################################
# SMTP relay with Office 365 Setup
# For Ubuntu / Debian / Raspbian
# David Harrop
# April 2023
#######################################################################################################################

# Prerequisites:
# An office 365 account with a mailbox (NON ADMIN!!)
# An app password created for the above office 365 user at https://mysignins.microsoft.com/security-info
# SMTP Auth enabled for that user under "manage mail apps" in the Office365 admin centre.

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

clear

SENDER=$SUDO_USER
SERVER=$(uname -n)
# Below variables are automatically updated by the 1-setup.sh script with the respective values given at install (manually update if blank)
LOCAL_DOMAIN=

echo
echo -e "${LYELLOW}SMTP relay for Office365 setup...${LGREEN}"

# Install Posfix
echo
echo -e "${GREY}Installing Postfix with non-interactive defaults..."
apt-get update -qq
DEBIAN_FRONTEND="noninteractive" apt-get install postfix mailutils -qq -y >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Postfix install failed. ${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
fi

# Get the Office365 smtp authentication credentials
echo
echo -e "${LYELLOW}An Office365 account email account is needed for SMTP relay authentication...${LGREEN}"
echo
read -p "Enter O365 SMTP auth enabled email : " SMTP_EMAIL
read -s -p "Enter the SMTP auth account 'app password': " APP_PWD
echo
echo

# Remove some default Postifx config items that conflict with new entries
sed -i '/relayhost/d' /etc/postfix/main.cf
sed -i '/smtp_tls_security_level=may/d' /etc/postfix/main.cf

# For simple relay outbound only, limit Postfix to just loopback and IPv4
sed -i 's/inet_interfaces = all/inet_interfaces = loopback-only/g' /etc/postfix/main.cf
sed -i "s/inet_protocols = all/inet_protocols = ipv4/g" /etc/postfix/main.cf

echo -e "${GREY}Configuring Postfix for O365 SMTP relay and TLS auth..."
# Add the new Office365 SMTP auth with TLS settings
cat <<EOF | sudo tee -a /etc/postfix/main.cf >/dev/null 2>&1
relayhost = [smtp.office365.com]:587
smtp_use_tls = yes
smtp_always_send_ehlo = yes
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_sasl_tls_security_options = noanonymous
smtp_tls_security_level = encrypt
smtp_generic_maps = hash:/etc/postfix/generic
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
EOF
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Postfix restart failed. ${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
    echo
fi

# Setup the password file and postmap
touch /etc/postfix/sasl_passwd
cat <<EOF | sudo tee -a /etc/postfix/sasl_passwd >/dev/null 2>&1
[smtp.office365.com]:587 ${SMTP_EMAIL}:${APP_PWD}
EOF
chown root:root /etc/postfix/sasl_passwd
chmod 0600 /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd

# Setup the generic map file
touch /etc/postfix/generic
cat <<EOF | sudo tee -a /etc/postfix/generic >/dev/null 2>&1
root@${SERVER} ${SMTP_EMAIL}
${SENDER}@${SERVER} ${SMTP_EMAIL}
@${LOCAL_DOMAIN} ${SMTP_EMAIL}
EOF
chown root:root /etc/postfix/generic
chmod 0600 /etc/postfix/generic
postmap /etc/postfix/generic

# Restart and test
echo -e "${GREY}Restarting Postfix..."
systemctl restart postfix
if [[ $? -ne 0 ]]; then
    echo -e "${LRED}Postfix restart failed. ${GREY}" 1>&2
    exit 1
else
    echo -e "${LGREEN}OK${GREY}"
fi

echo
read -p "Enter an email address to test that email relay is working : " TEST_EMAIL
echo "This is a test email" | mail -s "SMTP Auth Relay Is Working is working" ${TEST_EMAIL} -a "FROM:${SMTP_EMAIL}"
echo -e "${LGREEN}Test message sent.."
echo -e ${NC}
