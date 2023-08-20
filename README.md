# **Guacamole 1.5.3 VDI / Jump Server Appliance Build Script**

A menu based source build & install script for Guacamole 1.5.3 with support for TLS reverse proxy, AD integration, multi-factor authentication and further security hardening.

### **Automatic build, install & config script**

To build the Guacamole appliance, paste the below link into a terminal and follow prompts **(do not run as sudo)**:

```
wget https://raw.githubusercontent.com/itiligent/Guacamole-Install/main/1-setup.sh && chmod +x 1-setup.sh && ./1-setup.sh
```

## **Prerequisites**
 ### NOTE: DEBIAN 12 & TOMCAT 10 NOT CURRENTLY COMPATIBLE - SEE ISSUE #10

- **Ubuntu 18.04 - 22.x / Debian 11 & 10 / Raspbian Buster or Bullseye**
  - *(if using OS vendor cloud images - you must use **stable releases of the above OS variants.**  Daily cloud image builds are akin to rolling releases and may contain as yet unsupported updates that break Guacamole!)*
- Minimum 8GB RAM and 40GB HDD
- Public or private DNS entries that match the default route interface IP address (required for TLS)
- Incoming access on TCP ports 22, 80, and 443
- Do not run as root. The user executing the installer script must instead be a **member of the sudo group**

## **Installer Menu Flow**

### **1. Confirm the system hostname & local dns domain suffix**

### **2. Select a MySQL instance type and security baseline**

- Install a new local MySQL instance, or choose an existing/remote MySQL instance? 
  - *Optionally add MySQL **mysql_secure_installation** settings to the selected MySQL instance*
  - *Optionally provide an email address for backup messages and alerts*

### **3. Pick an authentication extension**

- DUO, TOTP, LDAP or none?  

### **4. Choose the Guacamole front end**

- **Install Nginx reverse Proxy?** [y/n]
     - No:  Keeps the Guacamole native front end & url http://server.local:8080/guacamole
     - Yes: Prompts for a reverse proxy local dns name (this can be different to the hostname)
   
- **Install Nginx reverse proxy with a self-signed TLS certificate?** [y/n]
  - No: Installs Nginx as **http** reverse proxy, Guacamole site set to http://server.local
  - Yes: Installs Nginx as **https** reverse proxy, Guacamole site set to https://server.local 
     - *Nginx is configured with a self signed TLS certificate and http redirect*
     - *Windows & Linux self signed client browser certificates generated*

 - **Install Nginx reverse proxy with a Let's Encrypt certificate?** [y/n] 
    - Yes: Prompts for a webmaster email & public reverse proxy dns name 
      - *Installs Nginx as **https** reverse proxy, Guacamole site set to* https://your-public-site.com
      - *Nginx configured with a new LetsEncrypt certificate and http redirect*
      - *Ongoing certbot certificate renewals scheduled* 

## **Post install hardening options**

The installer additionally downloads the following manual configuration scripts:
- `add-fail2ban.sh` - Adds a baseline fail2ban lockdown policy to Guacamole (& whitelists the local subnet)
- `add-tls-guac-daemon.sh` - Adds a TLS wrapper to internal traffic between the Guacamole application and guacd server daemon
- `add-auth-ldap.sh` - A template script for integrating Guacamole with Active Directory
- `add-smtp-relay-o365.sh` - A template script for email alerts via MSO65 (SMTP auth via BYO app password)

## **Active Directory integration**

See Active Directory authentication instructions [here](https://github.com/itiligent/Guacamole-Install/blob/main/ACTIVE-DIRECTORY-HOW-TO.md)


## **Installation notes**

The installer can be run interactively, or for a customised/unattended setup:
1. From a terminal session, change to your home directory then paste and run the above wget autorun link.
2. Exit the `1-setup.sh` script at the first prompt. (At this point only the scripts have downloaded).
3. Customise the many installation variables in the "Silent setup options" section of `1-setup.sh` as appropriate. 
    - *Script variables with a given value (e.g. `VARIABLE="value"`) will not prompt during the interactive setup. With the right combination of custom script variables, it is possible to deploy Guacamole appliance(s) with zero touch in only minutes.*
4. **Beware: If any settings in `1-setup.sh` are edited, you must run this modified script locally. If you run the wget autorun link again you will overwrite all your changes!**
      - *All install options are managed from within `1-setup.sh`. If you edit any of the other downloaded scripts, **you must also comment out each script's corresponding download link** within the "Download GitHub Setup" section of `1-setup.sh` to prevent re-download and overwrite when running setup.*
      - *Some manual scripts are automatically customised at installation to reflect various install settings and options.*
6. If the TLS self signed option is selected, client TLS certificates will be saved to `$DOWNLOAD_DIR/guac-setup`.
7. Nginx is configured to only support TLS 1.2 or above.

## **Download manifest**

The autorun link above downloads the following items into the `$DOWNLOAD_DIR/guac-setup` directory:

- `1-setup.sh`: The parent install script itself (saved to the current directory)
- `2-install-guacamole.sh`: Guacamole installation script (based on [MysticRyuujin/guac-install](https://github.com/MysticRyuujin/guac-install))
- `3-install-nginx.sh`: Installs Nginx & auto-configures a front-end reverse proxy for Guacamole (optional)
- `4a-install-tls-self-signed-nginx.sh`: Configures self-signed TLS certificate for Nginx proxy (optional)
- `4b-install-tls-letsencrypt-nginx.sh`: Installs & configures Let's Encrypt for Nginx proxy (optional)
- `add-auth-duo.sh`: Adds the Duo MFA extension if not selected during install (optional)
- `add-auth-ldap.sh`: Adds the Active Directory extension and setup template if not selected at install (optional)
- `add-auth-totp.sh`: Adds the TOTP MFA extension if not selected at install (optional)
- `add-tls-guac-daemon.sh`: A hardening script to add a TLS wrapper between the guacd server daemon and Guacamole application traffic (optional, consider extra performance impact mitigations)
- `add-fail2ban.sh`: Adds a fail2ban policy (with local subnet override) to secure Guacamole against external brute force attacks
- `add-smtp-relay-o365.sh`: Sets up an SMTP auth relay with O365 for monitoring & alerts (BYO app password)
- `backup-guacamole.sh`: A simple MySQL Guacamole backup script
- `branding.jar`: An example template for a customised Guacamole login screen. Much further UI customisation is possible inside this extension via additional CSS. Delete this file to keep the default Guacmole UI. 
