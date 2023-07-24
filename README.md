# Guacamole 1.5.2 VDI & Jump Server Appliance Builder

A menu based build & install script for Guacamole 1.5.2 with support for SSL reverse proxy, AD integration, multi-factor authentication and further security hardening.

## Automatic build, install & config script

To install Guacamole, copy and paste the following command into your terminal:

```
wget https://raw.githubusercontent.com/itiligent/Guacamole-Install/main/1-setup.sh && chmod +x 1-setup.sh && ./1-setup.sh
```

## Prerequisites

- Ubuntu 18.04 - 22.x / Debian 10 & 11 / Raspbian Buster or Bullseye
 ### PLEASE NOTE: LASTEST DEBIAN 12 HAS SEVERAL PENDING ISSUES - SEE ISSUE #8
- Minimum 8GB RAM and 40GB HDD
- Public or private DNS entries that match the default physical interface IP address (required for self SSL)
- Incoming access on TCP ports 22, 80, and 443

## Setup Menu Flow

### 1. Setup MySQL

- Install Guacamole with a new local MySQL, or use an existing/remote MySQL instance. 
- Sub option: Add MySQL `mysql_secure_installation` settings to the local or remote MySQL instance

### 2. Select authentication extension

- Choose an authentication extension [DUO, TOTP, LDAP or None]  - *Simultaneous TOTP and DUO not possible, but LDAP with TOTP is ok.*

### 3. Choose a Guacamole front end 

- Install Nginx Reverse Proxy?: y/n ( n = default Guacamole frontend `http://hostname:8080/guacamole`)
- Install Nginx with no SSL?: y/n ( y = `http://hostname.local`)
- Install Nginx with self-signed SSL certificates?: y/n ( y = `https://hostname.local`) -  *Configures Nginx with a new self signed TLS certificate and generates corresponding Windows/Linux client certificates in the `$DOWNLOAD_DIR/guac-setup` directory*
- Install Nginx with Let's Encrypt certificates?: y/n ( y =`https://public.site.com`) - *Configures Nginx with a new LetsEncrypt certificate and sets up auto renewals.)*

### Optional post install hardening

The installer downloads additional scripts for:
- Adding a fail2ban lockdown policy for Guacamole `add-fail2ban.sh`
- Encrypting internal traffic between the Guacamole client and Guacd daemon with SSL `add-ssl-guac-gaucd.sh`
- Integrating with Active Directory (See ACTIVE-DIRECTORY-HOW-TO.md) `add-auth-ldap.sh`
- Adding email alerts via Microsoft365 (uses SMTP auth, requires BYO MS app password) `add-smtp-relay-o365.sh`

## Installation notes

To create a custom or unattended setup, follow these steps:
1. From a terminal session, change to your home directory then paste and run above wget link.
2. Exit `1-setup.sh` script at the first prompt. (At this point, only the scripts are downloaded).
3. Edit the "Silent setup options" section of `1-setup.sh`. 
    - *Note that script variables with an actual setting (e.g., `VARIABLE="value"`) will NOT prompt during the interactive setup. This means that with the right combination of variable inputs, it is possible to mass deploy a full Guacamole appliance with Nginx & SSL with zero touch.*
4. After setting your custom variable values in `1-setup.sh`, you must run the modified script saved locally with `./1-setup.sh` Beware: If you run the wget link again you will overwrite all your changes!
      - *For adaptations made to any other downloaded script, you must comment out the relevant wget lines in the "Download GitHub Setup" section at the top of `1-setup.sh` to prevent these from being re-downloaded and overwritten as well.* 
      - *There should be no need to customise any scripts other than `1-setup.sh` as all install options are managed in the first parent script.* 
      - *Be aware that all optional (manually run) `add-xxxx.sh` scripts are dynamically updated during the installation with the exact variables you selected at install. Editing anything other than `1-setup.sh` may break this functionality, so make changes only if you understand the impacts.*

### Manifest of items downloaded by the setup script

The setup command mentioned above downloads the following items into the `$DOWNLOAD_DIR/guac-setup` directory:

- `1-setup.sh`: The parent install script itself
- `2-install-guacamole.sh`: Guacamole installation script (inspired by [MysticRyuujin/guac-install](https://github.com/MysticRyuujin/guac-install))
- `3-install-nginx.sh`: Installs Nginx & auto-configures a front-end reverse proxy for Guacamole (optional)
- `4a-install-ssl-self-signed-nginx.sh`: Configures self-signed SSL certificates for Nginx proxy (optional)
- `4b-install-ssl-letsencrypt-nginx.sh`: Installs & configures Let's Encrypt with Guacamole & Nginx proxy (optional)
- `add-auth-duo.sh`: Adds the Duo MFA extensions if not selected during install (optional)
- `add-auth-ldap.sh`: Adds the Active Directory extension and setup template if not selected at install (optional)
- `add-auth-totp.sh`: Adds the TOTP MFA extension if not selected at install (optional)
- `add-ssl-guac-gaucd.sh`: A hardening script to wrap traffic between the guacd server & the Guacamole client application in TLS (optional)
- `add-fail2ban.sh`: Adds a fail2ban policy (with local subnet override) to secure Guacamole against external brute force attacks
- `add-smtp-relay-o365.sh`: Sets up a TLS/SMTP auth relay with O365 for monitoring & alerts (BYO app password)
- `backup-guacamole.sh`: A simple Guacamole backup script
- `branding.jar`: An example customised Guacamole login screen to brand Guacamole to your own requirements (or delete to keep the default interface.) This is a modified version of https://github.com/Zer0CoolX/guacamole-customize-loginscreen-extension but with with additional support for browser favicons.

Special acknowledgement to [MysticRyuujin](https://github.com/MysticRyuujin/guac-install) whose repository provided many helpful ideas in assembling this project.
