# 
<h1 align="center">:avocado: Guacamole 1.5.3 Appliance Auto Installer Script</h1>
<p align="center">
  <img src="https://img.shields.io/badge/GitHub-GPL--3.0-informational.svg" alt="License">
</p>

This suite of build and management scripts makes setting and operating Guacamole a breeze. Its got installer support for TLS reverse proxy (self sign or LetsEncrypt), Active Directory integration, multi-factor authentication, Quick Connect & History Recording Storage UI enhancements, a custom UI theme creation template with dark mode as default, auto database backup, O365 email alerts, internal daemon security hardening options and even a fail2ban policy for defence against brute force attacks. There's also code in here to get you up and running with an enterprise deployment approach very similar to [Amazon's Guacmole Bastion Cluster](http://netcubed-ami.s3-website-us-east-1.amazonaws.com/guaws/v2.3.1/cluster/), if that's your thing!

## Automatic Installation

<img src="https://github.githubassets.com/images/icons/emoji/rocket.png" width="35"> To start building your Guacamole appliance, paste the below link into a terminal and just follow the option prompts **(no need for sudo, but you must be a member of the sudo group)**:

```shell
wget https://raw.githubusercontent.com/itiligent/Guacamole-Install/main/1-setup.sh && chmod +x 1-setup.sh && ./1-setup.sh
```
## Docker Image Creation
For customised & branded Docker builds, unattended installation options are available. Read on...

## Prerequisites (Yes! Debian 12 is now supported!)

<img src="https://github.githubassets.com/images/icons/emoji/lock.png" width="35"> **Before diving in, make sure you have:**

- **A compatible OS:**
    - **Debian 12, 11 or 10**
    - **Ubuntu 23.04, 22.04, 20.04 & 18.04**
    - **Raspbian Buster & Bullseye**
    - **Official vendor cloud images equivalent to the above.**
- **1 CPU core + 2GB RAM for every 25 users (plus minimum RAM & disk space for your selected OS).**
- **Open TCP ports: 22, 80, and 443**
- **If selecting the reverse proxy with TLS option, internal DNS entries for the internal proxy site (and an additional public DNS entry with the LetsEncypt option).**

## Installation Menu

<img src="https://github.githubassets.com/images/icons/emoji/wrench.png" width="35"> **The main script guides you through the installation process in the following steps:**

1. Confirm your system hostname and local DNS domain suffix. (Must be consistent for TLS proxy)
2. Choose a locally installed or remote MySQL instance, set database security preferences.
3. Pick an authentication extension: DUO, TOTP, LDAP, or none.
4. Select optional console features: Quick Connect & History Recorded Storage UI integrations.
5. Decide on the Guacamole front end: Nginx reverse proxy (http or https) or keep the native Guacamole interface
  - If you opt to install Nginx with self signed TLS:
    - New server and client browser certificates are backed up to `$HOME/guac-setup/tls-certs/[date-time]`
    - Pay attention to on-screen instructions for client certificate import (no more pesky browser warnings). 

## Managing self signed TLS certs with Nginx (the easy way!)

   - **To renew certificates, or to change the reverse proxy local dns name and/or IP address:** 
     - Just re-run `4a-install-tls-self-signed-nginx.sh` as many times as you like (accompanying server and browser client certs will also be updated). Look this script's comments for further command line argument options. 
     - Remember to clear your browser cache after changing certificates.

## Active Directory Integration

<img src="https://github.githubassets.com/images/icons/emoji/key.png" width="35"> **Need help with Active Directory authentication?** Check [here](https://github.com/itiligent/Guacamole-Install/blob/main/ACTIVE-DIRECTORY-HOW-TO.md).

## Customise & Brand Your Guacamole Theme

<img src="https://github.githubassets.com/images/icons/emoji/art.png" width="35"> **Want to give Guacamole your personal touch? Follow the theme and branding instructions** [here](https://github.com/itiligent/Guacamole-Install/tree/main/custom-theme-builder).
  - To revert to the Guacamole default theme, simply delete the branding.jar file from /etc/guacamole/extensions

## Installation Instructions

<img src="https://github.githubassets.com/images/icons/emoji/unicode/2699.png" width="35"> 

### **Paste and run the wget autorun link, thats it! *But if* you want to make Guacamole your own and customise...**
**Exit `1-setup.sh` at the first prompt**. All the configurable options are clearly noted at the start of `1-setup.sh`. Certain combinations of setup script edits will even produce an unattended install!

**Other useful install notes:**
- **Caution: Be aware that running the auto-run link again re-downloads the suite of scripts and will overwrite your changes. You must run setup locally after editing the setup script.** (Also be sure to comment out the download links in the setup script for any other scripts you edit, but there's really no need to touch these - see the next point...
  - Many of the scripts in the suite are **automatically adjusted with your chosen installation settings** to form a matched & transportable set. This allows you to add or update features after installation whilst avoiding mismatches with the original install. Editing any scripts other than the main setup may break this function.
- Nginx is automatically configured to use TLS 1.2 or above (so really old browser versions may not work.)
- A daily MySQL backup job will be automatically configured under the script owner's crontab.
- **Security info:** The Quick Connect option brings a few extra security implications; so be aware of potential risks in your particular environment.

**For the more security minded, there's several post-install hardening script options available:**

- `add-fail2ban.sh`: Adds a lockdown policy for Guacamole to guard against brute force attacks.
- `add-tls-guac-daemon.sh`: Wraps internal server daemon <--> guac application traffic in TLS.
- `add-auth-ldap.sh`: A template script for Active Directory integration.
- `add-smtp-relay-o365.sh`: A template script for email alerts integrated with MSO65 (BYO app password).

## Upgrading Guacamole

<img src="https://github.githubassets.com/images/icons/emoji/globe_with_meridians.png" width="35"> To upgrade Guacamole, edit `upgrade-guac.sh` to relfect the latest versions of Guacamole and MySQL connector/J before running it. This script will also automatically update the installed extensions too.

## High Availability (Or Docker Multi-Container) Deployments 

<img src="https://github.githubassets.com/images/icons/emoji/unicode/1f454.png" width="35"> For Enterprise (or custom Docker) deployments, did you know that Guacamole can be run in a load balanced farm with physical/logical separation between TLS, application and database layers? To achieve this, the MySQL, Guacamole and Nginx front end components are typically split into 3 systems or containers. (VLANs & firewalls between these layers helps greatly with security too.)

 A simple benefit of using a separate MySQL backend server or container means you can upgrade and test whilst keeping all your data and connection profiles intact. Just point this installer (or point a fresh Docker application container) to your MySQL instance and immediately all your connection profiles and settings are right there!

- **For the DATABASE layer:** Find the included  `install-mysql-backend-only.sh` [here](https://github.com/itiligent/Guacamole-Install/tree/main/guac-enterprise-build) to install a standalone instance of the Guacamole MySQL database for your backend.
- **For the APPLICATION layer:** Simply use the main setup script to build as many application servers as you like, just use the main installer to point new installations to the remote backend database, making sure to **say no to both the "Install MySQL locally" option and any proxy install options**.
- **For the Front end**: There are so many choices available that are already very well documented. You could even use the Nginx scripts to build a separate TLS front end layer. Be aware that [HA Proxy](https://www.haproxy.org/) generally provides far superior session persistence/affinity under load balanced conditions [when compared to Open Source Nginx](https://www.nginx.com/products/nginx/compare-models/) as only Nginx Plus subscribers get all the proper load balancing stuff!

### Installer script download manifest

<img src="https://github.githubassets.com/images/icons/emoji/package.png" width="35"> The autorun link downloads these repo files into `$HOME/guac-setup`:

Where noted, below scripts can be run to add extra features that were selected during the initial install.

- `1-setup.sh`: The installation script.
- `2-install-guacamole.sh`: Guacamole main source build installation script.
- `3-install-nginx.sh`: Installs Nginx for reverse proxy if not added at install.
- `4a-install-tls-self-signed-nginx.sh`: Configures or updates self-signed TLS for Nginx if not added at install.
- `4b-install-tls-letsencrypt-nginx.sh`: Installs Let's Encrypt for Nginx if not added at install
- `add-auth-duo.sh`: Installs Duo MFA extension if not added at install.
- `add-auth-ldap.sh`: Installs Active Directory extension if not added at install.
- `add-auth-totp.sh`: Adds TOTP MFA extension if not added at install.
- `add-xtra-quickconnect.sh`: Adds Quick Connect console extension if not added at install.
- `add-xtra-histrecstore.sh`: Adds History Recorded Storage extension if not added at install.
- `add-smtp-relay-o365.sh`: Sets up SMTP auth relay with O365 for backup messages, monitoring & alerts (BYO app password).
- `add-tls-guac-daemon.sh`: Adds TLS wrapper for guacd server daemon to Guacamole client app internal traffic.
- `add-fail2ban.sh`: Adds a fail2ban policy for brute force attack protection.
- `backup-guacamole.sh`: A MySQL Guacamole backup script.
- `upgrade-guac.sh`: Upgrades Guacamole, all installed extensions and the MySQL connector.
- `branding.jar`: An example template for customising Guacamole's UI theme. Delete to from /etc/guacamole/extensions to keep the default UI.

Happy Guacamole-ing! 😄🥑
