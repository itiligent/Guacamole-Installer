# Integrating Guacamole with Active Directory

## **1. Ensure two way LDAP traffic is available to the Guacamole application server**

- If Guacamole is operating in a separate network to that of your Active Directory Servers, allow TCP 389 between all Guacamole application servers and all Active Directory Domain Controllers nominated in the config script settings below.

## **2. Establish the required accounts to bind with Active Directory**

- An account with only **Domain Users** rights is sufficient for Guacamole to read and bind with Active Directory. 

   - a. In the Guacamole application, create a new Guacamole account with full admin rights to the Guacamole application e.g. `guacbind-ad` and assign it an appropriately strong password. (Then login with this new account and disable the default guacadmin account)
   - b. Create a new Active Directory domain account of EXACTLY THE SAME NAME as the new full admin account named above, only this time assign a DIFFERENT strong password to that which was used above. 

## **3. Edit the provided configuration script to reflect your specific Active Directory environment**

  Below is the EXACT format to follow in editing the `$USER_HOME_DIR/guac-setup/add-ldap-auth-guacamole.sh` script. Be careful not to introduce new lines, spaces at ends of lines or carriage returns as anything outside of this format will cause the LDAP auth extension to fail. You have been warned! 

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

  **Edit only the following values from the above example to suit your environment, then save the script**
```
ldap-hostname:
ldap-search-bind-dn:
ldap-search-bind-password:
ldap-config-base-dn:
ldap-user-base-dn:
mysql-auto-create-accounts: true
ldap-max-search-results:200
```
  - **_Important note on `ldap-user-base-dn:`_** _This value sets a position in the directory as a relative root to search within. All Guacamole users to be authenticated by Active Directory must be placed in a lower position within the directory tree to this value. This line can be added multiple times to more efficiently search across multiple branches of a directory tree._

  - **_Important note on `ldap-max-search-results:`_** _Yes, there is no space before the :200 value. In larger environments managing the directory efficiently requires we don't query every object in the tree for every user lookup. You may need to adjust this number depending on the number of objects in you tree._ 

  - **_Important note on `mysql-auto-create-accounts:`_** _This line is optional and can be deleted. This line ensures that all Active Directory user accounts will have a matching user account created in the Guacamole db at first logon. Local Guacamole accounts are NOT necessarily needed for access to Guacamole connections - these are only necessary when deploying MFA or you want to assign other settings specific to individual users. Domain users can be provisioned access to connections without creating local users in the Guacamole db. For many use cases, manually creating a small number of Guacamole user accounts to their matching domain accounts may be more preferable than all users inheriting access to establish a local account in the Guacamole db. See below for manual account setup._

## **4. Run the (now customised) LDAP configuration script**

`sudo $USER_HOME_DIR/guac-setup/add-ldap-auth-guacamole.sh` 

## **5. Logging on to Guacamole with the new guacbind-ad account**

- When logging in to Guacamole as the new Active Directory account and password created above, that domain user now passes through to Guacamole as both a Guacamole admin and a Domain User. If all is working correctly, all the users located below the directory tree position set in **ldap-user-base-dn** will be listed under **Settings | Users** of the Guacamole management console.

## **6. Manually creating and configuring new Guacamole users for Active Directory authentication**

- If not using the **mysql-auto-create-accounts** directive, manually re-create the exact user account names in Guacamole as those in the directory you wish to give Guacamole access. **DO NOT configure a Guacamole password for any users that will be exclusively authenticating via Active directory**. Guacamole local user accounts without a password are first given an MFA challenge by the local Guacamole application (only if MFA is configured for that user) and then will be brokered to Active Directory for their authentication challenge. Guacamole local user accounts that are given passwords in Guacamole will always refer to the local db for authentication, never Active Directory. This design allows for a matrix of local, domain, MFA & non MFA access use cases to be deployed.

## **7. Logging on using either the local vs the domain guacbind-ad account**

- As described above, logging on with the Guacamole admin user password will authenticate with the local Guacamole admin account, conversely if the Guacamole admin domain account password is given, the domain account is authenticated via Active Directory and then passed through as authorised to administer Guacamole. It may sometimes be necessary to log on with the local Guacamole admin account to manage some admin functions, but be aware that when doing so you will not be able to view and search the user list from Active Directory. Only when logged on with the domain version of the Guacamole admin account can domain user permissions to various Guacamole sessions and objects be delegated and managed.

## **8. Creating a quasi Single Sign On user experience for Windows RDP access**

- Create a Global Security domain group (e.g. Guac_Users) and populate it with selected domain users as required. 
- Now add this new security group to the built-in “Remote Desktop Users” domain group.
- Next, for each connection profile you wish to create the SSO behaviour, _parameter_ _tokens_ must be used in place of hard coded usernames and password values as follows... 
  - Add the parameter token `${GUAC_USERNAME}` to the Username field for each connection profile
  - Add the parameter token `${GUAC_PASSWORD}` to the Password field for each connection profile
- If the user has been given directory rights to the Guacamole session object, Guacamole will first authenticate the user to the Guacamole application (via a brokered Active Directory challenge) and then seamlessly pass the user's same domain credentials through to the Guacamole remote desktop session, thus avoiding any further remote desktop authentication prompts.
- For more info on other dynamic connection settings see https://guacamole.apache.org/doc/gug/configuring-guacamole.html#parameter-tokens
- For full SSO, the SAML authentication must be used. As the SAML extension requires a very bespoke approach to configuring login providers and login behaviours, the SAML authentication feature is beyond the scope of this project. 