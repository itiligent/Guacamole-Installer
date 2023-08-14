# **Guacamole 1.5.3 VDI / Jump Server Appliance Build Script**

A menu based build & install script for Guacamole 1.5.3 with support for TLS reverse proxy, AD integration, multi-factor authentication and further security hardening.

### **Automatic build, install & config script**

To install Guacamole, paste the following command into your terminal **(do not run as sudo)**:

```
wget https://raw.githubusercontent.com/itiligent/Guacamole-Install/main/1-setup.sh && chmod +x 1-setup.sh && ./1-setup.sh
```

## **Prerequisites**
 ### PLEASE NOTE: DEBIAN 12 & Tomcat 10 NOT COMPATIBLE - SEE ISSUE #10

- **Ubuntu 18.04 - 22.x / Debian 11 & 10 / Raspbian Buster or Bullseye**
  - *(if using OS vendor cloud images - you must use **stable releases of the above OS variants.**  Daily cloud image builds are akin to rolling releases and may contain as yet unsupported updates that break Guacamole!)*
- Minimum 8GB RAM and 40GB HDD
- Public or private DNS entries that match the default route interface IP address (required for TLS)
- Incoming access on TCP ports 22, 80, and 443
- The user executing the wget installer script **must be a member of the sudo group**

## **Setup Menu Flow**

### **1. Confim the system hostname & local domain suffix**
- Change or keep the current hostname and local DNS suffix

### **2. Select a MySQL instance type and security baseline**

- Install a new local MySQL instance, or choose an existing/remote MySQL instance. 
  - *Optionally add MySQL **mysql_secure_installation** settings to the selected MySQL instance*
  - *Optionally provide an email address for backup messages and alerts*

### **3. Pick an authentication extension**

- **DUO, TOTP, LDAP or None**  
  - *Simultaneous TOTP and DUO not possible, but LDAP with TOTP is ok.*

### **4. Choose the Guacamole front end**

- **Install Nginx reverse Proxy?** [y/n]
     - No:  Keep the Guacamole native front end & url http://server.local:8080/guacamole
       - *Sub option: Change Guacamole's default url to http root? Yes = http://server.local:8080*
     - Yes: Prompts for a reverse proxy local dns name (this can be different to the hostname)
   
- **Install Nginx reverse proxy with a self-signed SSL certificate?** [y/n]
  - No: Installs Nginx as **http** reverse proxy with the given local dns name e.g. http://server.local
  - Yes: Installs Nginx as **https** reverse proxy with the given local dns name e.g  https://server.local 
     - *Auto configures Nginx with a self signed TLS certificate and http redirect*
     - *Auto generates Windows & Linux client browser certificates*

 - **Install Nginx reverse proxy with a Let's Encrypt certificate?** [y/n] 
    - Yes: = Prompts for a webmaster email & public reverse proxy dns name e.g https://your-public-site.com
      - *Installs Nginx with the given public dns name*
      - *Auto configures Nginx with a new LetsEncrypt certificate and http redirect*
      - *Auto configures certificate notifications to the webmaster email*
      - *Auto schedules recurring certificate renewals* 

## **Optional post install hardening**

The installer downloads additional scripts to manually run:
- `add-fail2ban.sh` - Adds a conservative fail2ban lockdown policy to Guacamole & whitelists local LAN
- `add-ssl-guac-gaucd.sh` - Encrypts internal traffic between Guacamole application and Guacd daemon with TLS
- `add-auth-ldap.sh` - Template script for integrating with Active Directory (See ACTIVE-DIRECTORY-HOW-TO.md)
- `add-smtp-relay-o365.sh` - Template script for email alerts via MSO65 (SMTP auth, requires BYO app password)

## **Active Directory integration**

See Active Directory authentication instructions [here](https://github.com/itiligent/Guacamole-Install/blob/main/ACTIVE-DIRECTORY-HOW-TO.md)


## **Installation notes**

To create a custom or unattended setup, follow these steps:
1. From a terminal session, change to your home directory then paste and run the above wget setup link.
2. Exit the `1-setup.sh` script at the first prompt. (At this point only the scripts have downloaded).
3. Customise the installation variables in the "Silent setup options" section of `1-setup.sh` as appropriate. 
    - *Note that script variables with an actual value (e.g. `VARIABLE="value"`) will not prompt during the interactive setup. This means that with the right combination of script variable inputs, it is possible to mass deploy full Guacamole appliances with zero touch.*
4. **After setting your custom variable values in `1-setup.sh`, you must now run the modified script saved locally with `./1-setup.sh` Beware: If you run the setup script once again via the wget link you will overwrite all your changes!**
      - *There should be no need to customise any scripts other than `1-setup.sh` as all install options are managed in this parent script.*
      - *If you must make changes to any other downloaded scripts, you must also comment out their corresponding wget lines in the "Download GitHub Setup" section at the top of `1-setup.sh` to prevent a re-download and overwrite when re-running the setup.* 
      - *Be aware that all optional (manually run) `add-xxxx.sh` scripts are dynamically updated during the installation with variables selected at install. Editing anything other than `1-setup.sh` may break this functionality.*
6. If the self signed SSL option is selected, client TLS certificates are saved to `$DOWNLOAD_DIR/guac-setup`.
7. If any TLS option is selected, Nginx is configured to only support connections using TLS 1.2 or above.

## **Setup download manifest**

The setup command mentioned above downloads the following items into the `$DOWNLOAD_DIR/guac-setup` directory:

- `1-setup.sh`: The parent install script itself
- `2-install-guacamole.sh`: Guacamole installation script (inspired by [MysticRyuujin/guac-install](https://github.com/MysticRyuujin/guac-install))
- `3-install-nginx.sh`: Installs Nginx & auto-configures a front-end reverse proxy for Guacamole (optional)
- `4a-install-ssl-self-signed-nginx.sh`: Configures self-signed TLS certificate for Nginx proxy (optional)
- `4b-install-ssl-letsencrypt-nginx.sh`: Installs & configures Let's Encrypt for Nginx proxy (optional)
- `add-auth-duo.sh`: Adds the Duo MFA extension if not selected during install (optional)
- `add-auth-ldap.sh`: Adds the Active Directory extension and setup template if not selected at install (optional)
- `add-auth-totp.sh`: Adds the TOTP MFA extension if not selected at install (optional)
- `add-ssl-guac-gaucd.sh`: A hardening script to add a TLS wrapper between the guacd daemon and Guacamole client application traffic (optional, consider extra performance impact mitigations)
- `add-fail2ban.sh`: Adds a fail2ban policy (with local subnet override) to secure Guacamole against external brute force attacks
- `add-smtp-relay-o365.sh`: Sets up a TLS/SMTP auth relay with O365 for monitoring & alerts (BYO app password)
- `backup-guacamole.sh`: A simple MySQL Guacamole backup script
- `branding.jar`: An example template for a customised Guacamole login screen. The extension allows some measure of branding the user interface (or delete to keep the default interface). This is a version of https://github.com/Zer0CoolX/guacamole-customize-loginscreen-extension but with further tweaks to additionally support custom browser tab favicons. Much more extensive branding is possible via CSS inside this extension.
