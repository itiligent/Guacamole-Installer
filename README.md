# Guacamole 1.5.1 Virtual Desktop/Jump Server appliance with MFA, Active Directory integration & Nginx SSL reverse proxy

## Automatic build, install & config script:

    wget https://raw.githubusercontent.com/itiligent/Guacamole-Setup/main/1-setup.sh && chmod +x 1-setup.sh && ./1-setup.sh

## Prerequisites:

	Recent flavours of Ubuntu / Debian / Raspian 
 	Min 8GB RAM, 40GB HDD
	Public or private DNS entries matching the default physical interface IP address. (needed for SSL) 
	Incoming access on tcp 22, 80 & 443

### Setup menu options are:
	
### 1. Install default Guacamole with either a local MySQL database or with a remote MySQL instance 
	sub-options:
	a. Add MySQL mysql_secure_installation settings (to a local or remote MySQL instance)
	b. Add Guacamole MFA and Auth extensions - DUO, TOTP, LDAP. (Simultaneous TOTP & DUO not possible)
	
	
### 2. Optionally add a reverse proxy front end to Guacamole of either:
	a) None: Skip Nginx and keep the default Guacamole front end e.g. http://hostname:8080/guacamole
	b) Install Nginx with NO SSL: e.g. http://hostname.local
	c) Install Nginx with SELF SIGNED SSL certificates: e.g. https://hostname.local
		- Newly created Windows & Linux browser certs $site.crt, $site.key & $site.pfx are saved to $DOWNLOAD_DIR/guac-setup
		- Exact custom commands for the import of client certificates is generated on screen and is logged for later reference.
	d) Install Nginx with LET'S ENCRYPT certificates: e.g. https://public.site.com
	
### 3. After installation, optional hardening scripts can be manually run for :
	a. Adding a fail2ban lockdown policy for Guacamole
	b. Encryption of internal traffic between the Gaucamole client and Guacd daemon with SSL 
	To do list: (Hardening scripts for Nginx & MFA for shell access)

## Install notes:

To create an unattended setup, run the link above first, then EXIT the 1-setup.sh script when prompted.
At this point only a download of all scripts has occurred and from there you may edit the "Silent setup options" 
section at the start of 1-setup.sh as needed. 

In 1-setup-sh, any variables with an actual setting i.e. Variable="value" will not prompt during interactive setup, 
so with the right combination of saved ="variable" inputs it is fully possible to deploy Guacamole, Nginx and SSL with zero touch!

Note: If you have edited 1-setup.sh, you must setup script you saved LOCALLY with ./1-setup.sh (Important: DO NOT RUN AS SUDO, it will prompt for sudo as needed). 
Be aware that if you start setup again from the above link this will re-download and overwrite any of your previous customisations. 

There should be no need to customise any other scripts before installation. All optional (manually run) scripts are 
dynamically updated with their specific and relevant variables during setup. Essentially, this means that all scripts are built 
to work as a set specific to your particular install. Editing anything but 1-setup.sh (before a full install 
is first completed once) is not recommended.

To keep any adaptations you do make to any of the scripts, simply comment out the relevant wget lines in the "Download github setup" 
section at the top of script 1-setup.sh. This willl prevent any subsequent setup re-runs from overwriting your own edited versions.
 
This approach of pre-saving of options in the setup script itself has been taken as a more flexible route because there are far too 
many potential inputs and combinations of command line arguments that would need to be passed to the setup script at the command line for 
a full build, and this would require an impractically long string of setup arguments to type run correctly.

	# Items downloaded with the setup command above are placed in the $DOWNLOAD_DIR/guac-setup directory...
	1. 1-setup.sh				- the parent install script itself
	2. 2-install-guacamole.sh 		- Guacamole install script (inspired by https://github.com/MysticRyuujin/guac-install)
	3. 3-install-nginx.sh 			- Installs Nginx and auto configures as a front end for Guacamole (optional)
	4. 4a-install-ssl-self-signed-nginx.sh 	- Configures self signed ssl certs for Nginx (optional)
	5. 4b-install-ssl-letsencrypt-nginx.sh 	- Installs and configures Let's Encrypt with Guacamole and Nginx (optional)
	6. add-auth-duo.sh 			- Adds the Duo MFA extensions if not selected at install (optional)
	7. add-auth-ldap.sh 			- Adds the LDAP Active Directory extension and guides the specific LDAP setup requirements (optional)
	8. add-auth-totp.sh 			- Adds the TOTP MFA extension if not selected at install (optional)
	9. add-ssl-guac-gaucd.sh 		- A hardening script to wrap an extra ssl layer between the guacd server and the Guacamole client (optional)
	10. add-fail2ban.sh			- Adds and configures fail2ban to secure Guacamole against brute force attacks
	11. add-smtp-relay-o365.sh		- Sets up TLS SMTP authenticated relay with O365 (BYO app password)  
	12. backup-guacamole.sh			- A simple Guacamole backup script 
	13. branding.jar			- An extension to customise the Guacomole login screen (optional) 
	  					 see: https://github.com/Zer0CoolX/guacamole-customize-loginscreen-extension
 
Special acknowledgement to MysticRyuujin @ https://github.com/MysticRyuujin/guac-install and 
Zer0CoolX @ https://github.com/Zer0CoolX/guacamole-customize-loginscreen-extension whos repos were a helpful source of ideas in assembling this project. 
