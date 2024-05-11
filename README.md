# 
<h1 align="center">:avocado: Easy Guacamole Installer & Jump-Host Builder</h1> 
 <p align="center">
<a href="https://www.paypal.com/donate/?business=PSZ878JBJDMB8&amount=10&no_recurring=0&item_name=Thankyou+for+your+support+in+maintaining+this+project&currency_code=AUD">
  <img src="https://github.com/itiligent/Guacamole-Install/raw/main/.github/ISSUE_TEMPLATE/paypal-donate-button.png" width="125" />
</a>

This suite of build and management scripts makes setting up a secure Guacamole jump server a breeze. Its got installer support for TLS reverse proxy (self sign or LetsEncrypt), Active Directory integration, multi-factor authentication, Quick Connect & History Recording Storage UI enhancements, a custom UI theme creation template with dark mode as default, auto database backup, O365 email alerts, internal daemon security hardening options and even a fail2ban policy for defence against brute force attacks. There's also code in here to get you up and running with an enterprise deployment approach very similar to [Amazon's Guacmole Bastion Cluster](http://netcubed-ami.s3-website-us-east-1.amazonaws.com/guaws/v2.3.1/cluster/), if that's your thing!

## Automatic Installation

<img src="https://github.githubassets.com/images/icons/emoji/rocket.png" width="23"> To start building your Guacamole appliance, paste the below link into a terminal and just follow the option prompts **(no need for sudo, but you must be a member of the sudo group)**:

```shell
wget https://raw.githubusercontent.com/itiligent/Guacamole-Install/main/1-setup.sh && chmod +x 1-setup.sh && ./1-setup.sh
```

## Prerequisites 

<img src="https://github.githubassets.com/images/icons/emoji/lock.png" width="23"> **Before diving in, make sure you have:**

- **A compatible OS (with sudo & wget packages installed):**
    - **Debian 12, 11 or 10**
    - **Ubuntu 23.04, 22.04, 20.04**
    - **Raspbian Buster or Bullseye**
    - **Official vendor cloud images equivalent to the above versions.** 
      - (if your cloud image uses an IP of 127.0.1.1, [see here to use TLS with Nginx](https://github.com/itiligent/Guacamole-Install/issues/21))
- **1 CPU core + 2GB RAM for every 25 users (plus minimum RAM & disk space for your selected OS).**
- **Open TCP ports: 22, 80, and 443 (no other services using 80, 8080 & 443)**
- **If selecting either of the TLS reverse proxy options, you must create an internal DNS record for the internal proxy site, and an additional public DNS record if using the LetsEncypt option.**
- **The username running the 1-setup.sh script must have sudo permissions (script is not run as sudo, it will prompt for sudo)**

## Setup Script Menu

<img src="https://github.githubassets.com/images/icons/emoji/wrench.png" width="23"> **The main 1-setup.sh script guides you through the installation options in the following steps:**

1. Setup the system hostname and local DNS name. (Must be consistent with DNS records for TLS proxy)
2. Choose either a fresh local MySQL install or use a pre-existing local or remote MySQL instance.
3. Pick an authentication extension: DUO, TOTP, LDAP/Active Directory, or none.
4. Select optional console features: Quick Connect & History Recorded Storage UI integrations.
5. Decide on the Guacamole front end: Nginx reverse proxy (http or https) or keep the native Guacamole interface on port 8080
    - If you opt to install Nginx with self signed TLS:
      - New server and client browser certificates are saved to `$HOME/guac-setup/tls-certs/[date-time]`
      - Pay attention to on-screen instructions for client certificate import (no more pesky browser warnings). 

## Custom Installation Instructions

<img src="https://github.githubassets.com/images/icons/emoji/unicode/2699.png" width="23"> **If you want to make Guacamole your own and customise all the available options:**


  - Exit `1-setup.sh` at the first prompt. (the script suite is now downloaded under `$HOME/guac-setup`)
  - All the configurable options are clearly noted at the start of `1-setup.sh` under **Silent setup options**. Simply re-run the edited setup script when done making your changes.
  - Certain combinations of the silent setup options will allow a fully unattended install.

**Other useful custom install notes:**
- **Caution: Be aware that running the auto-installer link again re-downloads the suite of scripts and will overwrite all script edits. You must run setup locally after editing the setup script.** If any other scripts are edited, their corresponding download links in the setup script must also be commented out in the main setup script else these will be overwritten even when setup is run locally. There should be no reason to edit any script other than the main `1-setup.sh`

- Many of the scripts in the suite are **automatically adjusted with your chosen installation settings at 1st install** to form a matched set. This allows you to upgrade Guacamole or add extra features after the original installation without any configuration mismatches or errors. Editing any scripts other than the main setup may break this function.
- Nginx is automatically configured to default to at least TLS 1.2, therefore ancient browsers or API connections using TLS 1.1 will not work out of the box. To revert this see commented sections of the `/etc/nginx/nginx.conf` file.
- A daily MySQL backup job will be automatically configured under the script owner's crontab.
- **Security note:** The Quick Connect option brings a few extra security implications; so be aware of potential risks in your particular environment.

**For the more security minded, there's several post-install hardening script options available (manually applied):**

- `add-fail2ban.sh`: Adds a lockdown policy for Guacamole to guard against password brute force attacks.
- `add-tls-guac-daemon.sh`: Wraps internal traffic between the guac server daemon & guac application in TLS.
- `add-auth-ldap.sh`: A template script for Active Directory integration and authentication management.
- `add-smtp-relay-o365.sh`: A template script for email alerts integrated with MSO65 (BYO app password).

## Customise & Brand Your Guacamole Theme

<img src="https://github.githubassets.com/images/icons/emoji/art.png" width="23"> **Want to give Guacamole your personal touch? Follow the theme and branding instructions** [here](https://github.com/itiligent/Guacamole-Install/tree/main/guac-custom-theme-builder). To revert to the Guacamole default theme, simply delete the branding.jar file from /etc/guacamole/extensions, run `TOMCAT=$(ls /etc/ | grep tomcat) && sudo systemctl restart  ${TOMCAT} && sudo systemctl restart guacd && sudo systemctl restart nginx`, then clear your browser's cache. 

## Managing self signed TLS certs with Nginx (the easy way!)

   - **To renew self signed certificates or to change the reverse proxy local dns name/IP address:** 
     - Just re-run `4a-install-tls-self-signed-nginx.sh` as many times as you like to create a new certificate for Nginx (accompanying browser client certs will also be updated). Look to this script's comments for further command line argument options and remember to clear your browser cache after changing certificates.

## Active Directory SSO Integration

<img src="https://github.githubassets.com/images/icons/emoji/key.png" width="23"> **Need help with Active Directory authentication?** Check [here](https://github.com/itiligent/Guacamole-Install/blob/main/ACTIVE-DIRECTORY-HOW-TO.md).

## Upgrading Guacamole

<img src="https://github.githubassets.com/images/icons/emoji/globe_with_meridians.png" width="23"> To upgrade, edit `upgrade-guac.sh` to relfect the latest versions of Guacamole, MySQL connector/J before running. This script will also automatically update any optional pre-existing extensions if present (TOTP, DUO, LDAP, Quick Connect and History Recorded Storage.)

## High Availability Deployment 

<img src="https://github.githubassets.com/images/icons/emoji/unicode/1f454.png" width="23"> Did you know that Guacamole can run in a load balanced farm with layered physical / virtual separation between the web front end, application and database layers? To achieve this, the MySQL, Guacamole and Nginx front end components are typically split into 3 systems (or containers). VLANs & firewalls between these layers help greatly with defence in depth security concepts too.

 Separating the MySQL layer allows for more granular delegation of datasbase admin tasks (least priviledge) and staged upgrades or application scale out without taking Guacamole offline. (Simply by pointing the installer to your shared backend MySQL instance, all exisiting connection profiles and settings will be immediately available to the new Guacamole instance).

- **For the DATABASE layer:** Find the included  `install-mysql-backend-only.sh` [here](https://github.com/itiligent/Guacamole-Install/tree/main/guac-enterprise-build) to install a standalone instance of the Guacamole MySQL database for your backend.
- **For the APPLICATION layer:** You can use the main setup script to build as many application servers as you like.  Simply run the main installer to point new installations to a separate remote backend database, just make sure to say **no** to the "Install MySQL locally" option. Also consider saying **no** to any other local reverse proxy install options depending on your plan for load balancing the web front end.
- **For the Front end**: There are so many choices available that are already very well documented. You could even use the included Nginx scripts to build the basis of a separate TLS front end layer, and then add your preferred Nginx load balancing techniques to this config. Be aware that [HA Proxy](https://www.haproxy.org/) generally provides far superior session persistence / affinity under load balanced conditions [when compared to Open Source Nginx](https://www.nginx.com/products/nginx/compare-models/) as only Nginx Plus subscribers get all the proper load balancing stuff! How far you go with load balancing / session affinity will be determined by how seamless you wish to make the user experience when reconnecting to interrupted sessions.

### Installer script download manifest

<img src="https://github.githubassets.com/images/icons/emoji/package.png" width="23"> The autorun link downloads these repo files into `$HOME/guac-setup`:

- `1-setup.sh`: The parent installation script.
- `2-install-guacamole.sh`: Guacamole source build & installer script.
- `3-install-nginx.sh`: Nginx installation script.
- `4a-install-tls-self-signed-nginx.sh`: Install / refresh self-signed TLS certificates script.
- `4b-install-tls-letsencrypt-nginx.sh`: Let's Encrypt for Nginx installer script.
- `add-auth-duo.sh`: Duo MFA extension install script.
- `add-auth-ldap.sh`: Active Directory extension installer script.
- `add-auth-totp.sh`: TOTP MFA extension installer script.
- `add-xtra-quickconnect.sh`: Quick Connect console extension installer script.
- `add-xtra-histrecstore.sh`: History Recorded Storage extension installer script.
- `add-smtp-relay-o365.sh`: Script for O365 SMTP auth relay setup (BYO app password).
- `add-tls-guac-daemon.sh`: Script to wrap internal guacd daemon to Guacamole web app traffic in TLS.
- `add-fail2ban.sh`: Fail2ban (and Guacamole protection policy) installer script.
- `backup-guacamole.sh`: MySQL backup script.
- `upgrade-guac.sh`: Guacamole application, extension and MySQL connector upgrade script.
- `branding.jar`: Template for customising Guacamole's UI theme.

😄🥑
