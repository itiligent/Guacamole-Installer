## Integrating Guacamole With Active Directory

### :arrows_clockwise: **Step 1: Ensure two-way LDAP traffic is available to the Guacamole application server**

- If Guacamole is operating in a separate network from your Active Directory Servers, allow TCP 389 between all Guacamole application servers and all Active Directory Domain Controllers nominated in the config script settings below.

### :key: **Step 2: Establish the required accounts to bind with Active Directory**

- An account with only **Domain Users** rights is sufficient for Guacamole to read and bind with Active Directory. 

   - a. In the Guacamole application, create a new Guacamole account with full admin rights to the Guacamole application, e.g. `guacbind-ad`, and assign it an appropriately strong password. (Then log in with this new account and disable the default guacadmin account)
   - b. Create a new Active Directory domain account with EXACTLY THE SAME NAME as the new full admin account named above, only this time assign a DIFFERENT strong password than what was used above. 

### :pencil: **Step 3: Edit the provided configuration script to reflect your specific Active Directory environment**

Below is the EXACT format to follow in editing the `$USER_HOME_DIR/guac-setup/add-ldap-auth-guacamole.sh` script. Be careful not to introduce new lines, spaces at the ends of lines or carriage returns. Anything outside of this format will cause the LDAP auth extension to fail. You have been warned! 

```
ldap-hostname: dc1.yourdomain.com dc2.yourdomain.com dc3.yourdomain.com
ldap-port: 389
ldap-username-attribute: sAMAccountName
ldap-encryption-method: none
ldap-search-bind-dn: guacbind-ad@yourdomain.com
ldap-search-bind-password: guacbind-ad-password
ldap-config-base-dn: dc=yourdomain,dc=com
ldap-user-base-dn: OU=SomeOU,DC=yourdomain,DC=com
ldap-user-search-filter:(objectClass=user)(!(objectCategory=computer))
ldap-max-search-results:200
mysql-auto-create-accounts: true
```

**Edit only the following values from the above example to suit your environment, then save the add-ldap-auth-guacamole.sh script:**

```
ldap-hostname:
ldap-search-bind-dn:
ldap-search-bind-password:
ldap-config-base-dn:
ldap-user-base-dn:
mysql-auto-create-accounts: true
ldap-max-search-results:200
```

- **Important note on `ldap-user-base-dn:`** This value sets a position in the directory as a relative root to search within. All Guacamole users to be authenticated by Active Directory must be placed in a lower position within the directory tree than this value. This line can be added multiple times to more efficiently search across multiple branches of a directory tree.

- **Important note on `ldap-max-search-results:`** Yes, there is no space before the default `:200` value. In larger environments managing the directory efficiently requires that we don't query every object in the tree for every user lookup. You may need to adjust this number depending on the number of objects in the above relative root search path.

- **Important note on `mysql-auto-create-accounts:`** This line is optional and can be deleted if using Active Directory authentication without Guacamole's implementation of MFA. This line ensures that all Active Directory user accounts will have a matching user account created in the Guacamole database at thier first Guacmaole logon with thier AD accout. Only if Gucamole's MFA feature is to be provisioned is a local Guacamole account required, and automating this step can aid MFA deployment. If you want to provision Guacamole MFA access to just a limited selection of Active Diretory users, you may remove this line and manually create the passwordless Guacamole database local account pairings as needed. [See below for more.](https://github.com/itiligent/Guacamole-Install/blob/main/ACTIVE-DIRECTORY-HOW-TO.md#busts_in_silhouette-manually-creating-and-configuring-new-guacamole-users-for-active-directory-authentication-with-mfa) 

#### If your AD has TLS implemented via a self signed certificate you must also apply the extra TLS tasks A to E below, else skip to Step 4 ... For more info see [#18](https://github.com/itiligent/Guacamole-Install/issues/18)

TLS task A. Adjust this line in the above template for add-ldap-auth-guacamole.sh (Values can be none, ssl or stattls) 
```
ldap-encryption-method: starttls 
```
TLS task B. Next, you must obtain your AD TLS cert. 
```
openssl s_client -connect X.X.X.X:389 \
              -starttls ldap \
              -showcerts < /dev/null | \
              openssl x509 -text | \
              sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p'
```
TLS task C. Copy the certificate contents from -----BEGIN CERTIFICATE----- to -----END CERTIFICATE----- and paste this into a file (e.g. adcert.pem as per below)
```
sudo nano /etc/ssl/certs/adcert.pem  # then paste certificate output
```

TLS task D. Now import the AD cert file into the Java keystore
```
sudo keytool -importcert -alias adcert \
	-file /etc/ssl/certs/adcert.pem \
	-keystore /usr/lib/jvm/java-11-openjdk-amd64/lib/security/cacerts \
	-storepass changeit \
	-noprompt
```
TLS task E. Restart Apache Tomcat
````
TOMCAT=$(ls /etc/ | grep tomcat) && sudo systemctl restart ${TOMCAT}
````

### :computer: **Step 4: Run the (now customised) LDAP configuration script**

```shell
sudo $USER_HOME_DIR/guac-setup/add-ldap-auth-guacamole.sh
```



### :door: **Step 5: Log on to Guacamole with the new guacbind-ad account**

- When logging in to Guacamole as the new Active Directory account and password created above, that domain user is passed through to Guacamole as both a Guacamole admin and a Domain User. If all is working correctly, all the users located below the directory tree position set in **ldap-user-base-dn** will be listed under **Settings | Users** of the Guacamole management console.

### :busts_in_silhouette: **Manually creating and configuring new Guacamole users for Active Directory authentication with MFA.**

- If not using the **mysql-auto-create-accounts** directive, manually re-create the exact user account names in Guacamole as those in the directory that you wish to give specific local adminstrative permissions and/or provision Guacamole's MFA access. **DO NOT configure a Guacamole password for any users that will be exclusively authenticating via Active directory**. Guacamole database local user accounts without a password are first given an MFA challenge by the local Guacamole application (Only where the local passwordless Guacamole account is configured for MFA) and then will be brokered to Active Directory for their Kerberos authentication challenge. Guacamole database local user accounts that are given passwords in Guacamole will always refer to the local database account for authentication, never Active Directory. This design allows for a matrix of local, domain, MFA & non-MFA access use cases to be deployed.

### :key: **Logging in using Gucamole local vs. domain guacbind-ad account**

- As described above, logging on with the Guacamole admin user password will authenticate with the local Guacamole admin account, conversely if the Guacamole admin domain account password is given, the domain account is authenticated via Active Directory and then passed through as authorized to administer Guacamole. It may sometimes be necessary to log on with the local Guacamole admin account to manage some application functions, but be aware that when doing so you will not be able to view and search the user list from Active Directory. Only when logged on with the domain version of the Guacamole admin account can domain user permissions to various Guacamole sessions and objects be delegated and managed.

### :gear: **Creating a quasi Single Sign-On user experience for Windows RDP access**

- Create a Global Security domain group (e.g., Guac_Users) and populate it with selected domain users as required. 
- Now add this new security group to the built-in “Remote Desktop Users” domain group.
- Next, for each connection profile you wish to create the SSO experience and behavior, _parameter_ _tokens_ must be used in place of hard-coded usernames and password values as follows... 
  - Add the parameter token `${GUAC_USERNAME}` to the Username field for each connection profile
  - Add the parameter token `${GUAC_PASSWORD}` to the Password field for each connection profile
- If the user has been given directory rights to the Guacamole session object, Guacamole will first authenticate the user to the Guacamole application (via a brokered Active Directory challenge) and then seamlessly pass the user's same domain credentials through to the Guacamole remote desktop session, thus avoiding any further remote desktop authentication prompts.
- For more info on other dynamic connection settings see [Guacamole Documentation](https://guacamole.apache.org/doc/gug/configuring-guacamole.html#parameter-tokens)
- Additional extensions are required for full SSO, but because centralised authentication / authorisation extensions require a bespoke approach to service providers and login behaviors, the SSO features are currently beyond the scope of this project. Here's some links for info on configuring [SAML](https://guacamole.apache.org/doc/gug/saml-auth.html#) and [OpenID Connect](https://guacamole.apache.org/doc/gug/openid-auth.html)
