# Guacamole 1.5.3 VDI/Jump Server Appliance Build Script

<img src="https://github.githubassets.com/images/icons/emoji/sparkles.png" width="35"> This repo makes setting up Guacamole 1.5.3 a breeze, with added features like TLS reverse proxy, Active Directory integration, multi-factor authentication, Quick Connect, History Recording Storage, dark mode and custom UI templates, auto database backup, O365 email alerts, and enhanced security options. See below for enterprise and high availability deployments too.

## Automatic Installation

<img src="https://github.githubassets.com/images/icons/emoji/rocket.png" width="35"> To start building your Guacamole appliance, paste the below link into a terminal and follow the prompts **(no need for sudo, but the user must be a member of the sudo group)**:

```shell
wget https://raw.githubusercontent.com/itiligent/Guacamole-Install/main/1-setup.sh && chmod +x 1-setup.sh && ./1-setup.sh
```

## Prerequisites

<img src="https://github.githubassets.com/images/icons/emoji/lock.png" width="35"> **Before diving in, make sure you have:**

- A compatible OS: Ubuntu 18.04 - 22.x, Debian 10 or 11, or Raspbian Buster/Bullseye (If using vendor cloud images stick to stable releases).
- Minimum 8GB RAM and 40GB HDD.
- DNS entries matching your default appliance network interface IP (essential for TLS).
- Open TCP ports: 22, 80, and 443.

## Installation Menu

<img src="https://github.githubassets.com/images/icons/emoji/wrench.png" width="35"> **This script guides you through the installation process in the following steps:**

1. Confirm your system hostname and local DNS domain suffix. (Must be consistent for TLS proxy)
2. Choose a locally installed or remote MySQL instance, set database security preferences.
3. Pick an authentication extension: DUO, TOTP, LDAP, or none.
4. Select optional console features: Quick Connect & History Recorded Storage UI integrations.
5. Decide on the Guacamole front end: Nginx reverse proxy (http or https) or keep the native Guacamole interface

**For the more security minded, there's several post-install hardening script options available:**

- `add-fail2ban.sh`: Adds a lockdown policy for Guacamole to guard against brute force attacks.
- `add-tls-guac-daemon.sh`: Wraps internal server daemon <--> guac application traffic in TLS.
- `add-auth-ldap.sh`: A template script for Active Directory integration.
- `add-smtp-relay-o365.sh`: A template script for email alerts integrated with MSO65 (BYO app password).

## Active Directory Integration

<img src="https://github.githubassets.com/images/icons/emoji/key.png" width="35"> **Need help with Active Directory authentication?** Check [here](https://github.com/itiligent/Guacamole-Install/blob/main/ACTIVE-DIRECTORY-HOW-TO.md).

## Customise and Brand Your Guacamole Theme

<img src="https://github.githubassets.com/images/icons/emoji/art.png" width="35"> **Want to give Guacamole your personal touch? Follow the theme and branding instructions** [here](https://github.com/itiligent/Guacamole-Install/tree/main/custom-theme-builder).

## Custom Installation Notes

<img src="https://github.githubassets.com/images/icons/emoji/unicode/2699.png" width="35"> 

1. Paste and run the wget autorun link in your home directory.
2. Exit `1-setup.sh` at the first prompt. (At this point the scripts are downloaded only.)
3. Customise the huge number of installation variables available in `1-setup.sh` as required. (Certain combinations of edits will produce a fully unattended install.)
4. **Caution: If editing `1-setup.sh`, be aware that running the autorun link again re-downloads and overwrites all changes. You must run setup locally after editing.** (Also be sure to comment out the download links in the setup script for any other edited scripts. (There should be little need to edit outside of the setup script's options.)
5. The **upgrade-guac.sh, add-tls-guac-daemon.sh, refresh-tls-self-signed.sh & backup-guac.sh** scripts are automatically adjusted at installation to match your chosen installation settings. These can be run after install without any modification.
6. If the self-signed TLS proxy option is selected, browser client TLS certificates will be automatically created and saved to `$HOME/guac-setup`.
7. Note that Nginx is automatically configured to use TLS 1.2 or above (so really old browser versions may not work.)
8. A daily MySQL backup job will be automatically configured under the script owner's crontab.
9. **Security info:** The Quick Connect and History Recorded Storage options bring a few security implications; so be aware of potential risks in your particular environment.
   
## Upgrading Guacamole

<img src="https://github.githubassets.com/images/icons/emoji/globe_with_meridians.png" width="35"> To upgrade Guacamole, edit `upgrade-guac.sh` to relfect the latest versions of Guacamole and MySQL connector/J before running it. This script will also automatically update the DUO, LDAP, TOTP, Quick Connect & History Recorded Storage extension if they are found to be present.

## Enterprise Scale Out & High Availability 

<img src="https://github.githubassets.com/images/icons/emoji/unicode/1f454.png" width="35"> For Enterprise deployments, did you know that Guacamole can be run in a load balanced farm? To achieve this, the database, application and front end components are usually **split into 2 or 3 layers.** (VLANs & firewalls between the layers helps with security too.) See [here](https://github.com/itiligent/Guacamole-Install/tree/main/guac-enterprise-build) for useful related materials.
- **For the DATABASE layer:** Find the included `install-mysql-backend-only.sh` to install just a standalone backend instance of the Guacamole MySQL database. 
- **For the APPLICATION layer:** Simply use the main setup script to build as many application servers as you like. For a true 3 layer load balanced system, make sure to **say no to both the "Install MySQL locally" option and all Nginx front end options.** 
- **For the Front end**: There are may choices here. You can slightly modify the Nginx scripts for a front end TLS layer, however **HA Proxy** provides far superior session affinity under load balanced conditions when compared to Open Source Nginx (The paid for Nginx Plus gives you all the good stuff!) There's so many possible ways to achieve this in hardware and software. For this target audience there's plenty of config detail here help you begin to roll your own HA solution.

## Auto Download Manifest

<img src="https://github.githubassets.com/images/icons/emoji/package.png" width="35"> The autorun link downloads these repo files into `$HOME/guac-setup`:

- `1-setup.sh`: The installation script.
- `2-install-guacamole.sh`: Guacamole main source build installation script.
- `3-install-nginx.sh`: Installs Nginx for reverse proxy (optional).
- `4a-install-tls-self-signed-nginx.sh`: Configures self-signed TLS for Nginx (optional).
- `4b-install-tls-letsencrypt-nginx.sh`: Installs Let's Encrypt for Nginx (optional).
- `add-auth-duo.sh`: Adds Duo MFA extension (optional).
- `add-auth-ldap.sh`: Adds Active Directory extension (optional).
- `add-auth-totp.sh`: Adds TOTP MFA extension (optional).
- `add-xtra-quickconnect.sh`: Adds Quick Connect console feature (optional).
- `add-xtra-histrecstore.sh`: Adds History Recorded Storage feature (optional).
- `add-smtp-relay-o365.sh`: Sets up SMTP auth relay with O365 for backup messages, monitoring & alerts (BYO app password).
- `add-tls-guac-daemon.sh`: Adds TLS wrapper for guacd server daemon (optional).
- `add-fail2ban.sh`: Adds a fail2ban policy for brute force protection.
- `backup-guacamole.sh`: A MySQL Guacamole backup script.
- `upgrade-guac.sh`: Upgrades Guacamole and MySQL connector.
- `refresh-tls-self-signed`: Generates and installs updated TLS certificates for Nginx.
- `branding.jar`: An example template for customising Guacamole's theme. Delete to keep the default UI.

Happy Guacamole-ing! 😄🥑
