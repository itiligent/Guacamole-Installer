#!/bin/bash
#######################################################################################################################
# Add fail2ban restrictions to Guacamole
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

# Check if user is root or sudo
if ! [ $(id -u) = 0 ]; then
    echo
    echo -e "${LGREEN}Please run this script as sudo or root${NC}" 1>&2
    exit 1
fi

# Initialise variables
FAIL2BAN_BASE=""
FAIL2BAN_GUAC=""
FAIL2BAN_NGINX=""
FAIL2BAN_SSH=""
TOMCAT_VERSION=$(ls /etc/ | grep tomcat)

#Clean up from any previous runs
rm -f /tmp/fail2ban.conf
rm -f /tmp/ip_list.txt
rm -f /tmp/netaddr.txt
rm -f /tmp/fail2ban.update

#######################################################################################################################
# Start setup prompts #################################################################################################
#######################################################################################################################

# Prompt to install fail2ban base package with no policy as yet, default of yes
if [[ -z ${FAIL2BAN_BASE} ]]; then
    echo
    echo -e -n "${LGREEN}Install Fail2ban? (base package with no policy as yet) [default y]: ${GREY}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Nn]$ ]]; then
        FAIL2BAN_BASE=false
    else
        FAIL2BAN_BASE=true
    fi
fi

# Prompt to install Guacamole fail2ban config defaults, default of no
if [[ -z ${FAIL2BAN_GUAC} ]] && [[ "${FAIL2BAN_BASE}" = true ]]; then
    echo -e -n "${GREY}POLICY: Apply Guacamole fail2ban security policy? (y/n) [default n]:${GREY}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        FAIL2BAN_GUAC=true
    else
        FAIL2BAN_GUAC=false
    fi
fi

# Prompt to install Nginx fail2ban config defaults , default of no - NOT IMPLEMENTED YET
#if [[ -z ${FAIL2BAN_NGINX} ]] && [[ "${FAIL2BAN_BASE}" = true ]]; then
#    echo -e -n "${GREY}POLICY: Apply Nginx fail2ban security policy? (y/n) [default n]:${GREY}"
#    read PROMPT
#    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
#        FAIL2BAN_NGINX=true
#    else
#        FAIL2BAN_NGINX=false
#    fi
#fi

# Prompt to install SSH fail2ban config defaults , default of no - NOT IMPLEMENTED YET
#if [[ -z ${FAIL2BAN_SSH} ]] && [[ "${FAIL2BAN_BASE}" = true ]]; then
#    echo -e -n "${GREY}POLICY: Apply SSH fail2ban security policy? (y/n) [default n]:${GREY}"
#    read PROMPT
#    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
#        FAIL2BAN_SSH=true
#    else
#        FAIL2BAN_SSH=false
#    fi
#fi

#######################################################################################################################
# Fail2ban base setup #################################################################################################
#######################################################################################################################

# Install base fail2ban base application, and whitelist the local subnet as the starting baseline (no policy defined yet)
if [ "${FAIL2BAN_BASE}" = true ]; then

    #Update and install fail2ban (and john for management of config file updates, and not overwrite any existing settings)
    sudo apt-get update -qq >/dev/null 2>&1
    sudo apt-get install fail2ban john -qq -y >/dev/null 2>&1

    # Create the basic jail.local template and local subnet whitelist
    cat >/tmp/fail2ban.conf <<EOF
[DEFAULT]
destemail = yourname@example.com
sender = yourname@example.com
action = %(action_mwl)s
ignoreip =
EOF

    # We need to discover all interfaces to ascertain what network ranges to add to fail2ban "ignoreip" policy override defaults
    ip -o addr show up primary scope global | while read -r num dev fam addr rest; do echo ${addr%*}; done | cat >/tmp/ip_list.txt

    # Loop the list of discovered ips and extract the subnet ID addresses for each interface
    FILE=/tmp/ip_list.txt
    LINES=$(cat $FILE)
    for LINE in $LINES; do

        tonum() {
            if [[ $LINE =~ ([[:digit:]]+)\.([[:digit:]]+)\.([[:digit:]]+)\.([[:digit:]]+) ]]; then
                addr=$(((${BASH_REMATCH[1]} << 24) + (${BASH_REMATCH[2]} << 16) + (${BASH_REMATCH[3]} << 8) + ${BASH_REMATCH[4]}))
                eval "$2=\$addr"
            fi
        }
        toaddr() {
            b1=$((($1 & 0xFF000000) >> 24))
            b2=$((($1 & 0xFF0000) >> 16))
            b3=$((($1 & 0xFF00) >> 8))
            b4=$(($1 & 0xFF))
            eval "$2=\$b1.\$b2.\$b3.\$b4"
        }

        if [[ $LINE =~ ^([0-9\.]+)/([0-9]+)$ ]]; then
            # CIDR notation
            IPADDR=${BASH_REMATCH[1]}
            NETMASKLEN=${BASH_REMATCH[2]}
            PREFIX=$NETMASKLEN
            zeros=$((32 - NETMASKLEN))
            NETMASKNUM=0
            for ((i = 0; i < $zeros; i++)); do
                NETMASKNUM=$(((NETMASKNUM << 1) ^ 1))
            done
            NETMASKNUM=$((NETMASKNUM ^ 0xFFFFFFFF))
            toaddr $NETMASKNUM NETMASK
        else
            IPADDR=${1:-192.168.1.1}
            NETMASK=${2:-255.255.255.0}
        fi

        tonum $IPADDR IPADDRNUM
        tonum $NETMASK NETMASKNUM

        # The logic to calculate network and broadcast
        INVNETMASKNUM=$((0xFFFFFFFF ^ NETMASKNUM))
        NETWORKNUM=$((IPADDRNUM & NETMASKNUM))
        BROADCASTNUM=$((INVNETMASKNUM | NETWORKNUM))

        toaddr $NETWORKNUM NETWORK
        toaddr $BROADCASTNUM BROADCAST

        # Reverse engineer the subnet ID from the calcualted IP address and subnet prefix
        IFS=. read -r i1 i2 i3 i4 <<<"$IPADDR"
        IFS=. read -r m1 m2 m3 m4 <<<"$NETMASK"

        # Lay out the subnet ID address as a variable
        printf -v NETADDR "%d.%d.%d.%d" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))"

        #Dump out the calcualted subnet IDs to a file
        echo $NETADDR"/"$NETMASKLEN | tr '\n' ' ' | cat >>/tmp/netaddr.txt

    done

fi

if [ "${FAIL2BAN_BASE}" = true ]; then
    # Now the above loop is done, append the single loopback address to all the discovered the subnet IDs in a single line
    sed -i 's/^/127.0.0.1\/24 /' /tmp/netaddr.txt

    # Finally assemble the entire syntax of the ignoreip whitelist for insertion into the base fail2ban config
    SED_IGNORE=$(echo "ignoreip = ")
    SED_NETADDR=$(cat /tmp/netaddr.txt)
    sed -i "s|ignoreip \=|${SED_IGNORE}${SED_NETADDR}|g" /tmp/fail2ban.conf

    # Move the new base fail2ban config to the jail.local file
    touch /etc/fail2ban/jail.local

    # Apply the base config, keeping any pre-existing settings
    sudo bash -c 'cat /tmp/fail2ban.conf /etc/fail2ban/jail.local | unique /tmp/fail2ban.update ; cat /tmp/fail2ban.update > /etc/fail2ban/jail.local'

    # Clean up
    rm -f /tmp/fail2ban.conf
    rm -f /tmp/ip_list.txt
    rm -f /tmp/netaddr.txt
    rm -f /tmp/fail2ban.update

    # bounce the service to reload the new config
    sudo systemctl restart fail2ban

    # Done
    echo
    echo -e "${LGREEN}Fail2ban installed...${GREY}"
    echo

else
    echo -e "${LGREEN}Fail2ban setup cancelled.${GREY}"

fi

#######################################################################################################################
# Fail2ban optional policy setup items ################################################################################
#######################################################################################################################

if [ "${FAIL2BAN_GUAC}" = true ]; then

# Create the Guacamole jail.local policy template
cat >/tmp/fail2ban.conf <<EOF
[guacamole]
enabled = true
port = http,https
logpath  = /var/log/$TOMCAT_VERSION/catalina.out
bantime = 15m
findtime  = 60m
maxretry = 5
EOF

# Apply the new Guacamole jail config keeping any pre-existing settings
sudo bash -c 'cat /tmp/fail2ban.conf /etc/fail2ban/jail.local | unique /tmp/fail2ban.update ; cat /tmp/fail2ban.update > /etc/fail2ban/jail.local'

# Backup the default Fail2ban Guacamole filter
cp /etc/fail2ban/filter.d/guacamole.conf /etc/fail2ban/filter.d/guacamole.conf.bak

# Remove the default log search regex
sudo bash -c 'sed -e "/Authentication attempt from/ s/^#*/#/" -i /etc/fail2ban/filter.d/guacamole.conf'

# Create a new log search regex specific for tomcat logs (as a variable due to complexity of characters for sed syntax)
REGEX='failregex = ^.*WARN  o\.a\.g\.r\.auth\.AuthenticationService - Authentication attempt from <HOST> for user "[^"]*" failed\.$'
#Insert the new regex
sed -i -e "/Authentication attempt from/a ${REGEX}" /etc/fail2ban/filter.d/guacamole.conf

# Done
echo -e "${LGREEN}Guacamole security policy applied${GREY}\n- ${SED_NETADDR}are whitelisted from all IP bans.\n- To alter this whitelist, edit /etc/fail2ban/jail.local & sudo systemctl restart fail2ban \n \n This script may take a while to complete..."

# Bounce the service to reload the new config
sudo systemctl restart fail2ban
echo
fi

# Clean up
rm -f /tmp/fail2ban.conf
rm -f /tmp/ip_list.txt
rm -f /tmp/netaddr.txt
rm -f /tmp/fail2ban.update

############## Start Fail2ban NGINX security policy option ###############
#if [ "${FAIL2BAN_NGINX}" = true ]; then
#    echo -e "${LGREEN}Nginx Fail2ban policy not implemented yet.${GREY}"
#    echo
#fi

############### Start Fail2ban SSH security policy option ################
#if [ "${FAIL2BAN_SSH}" = true ]; then
#    echo -e "${LGREEN}SSH Fail2ban policy not implemented yet..${GREY}"
#    echo
#fi

#Done
echo -e ${NC}
