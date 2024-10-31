


### How to build all Guacamole client extensions:
Licensing prevents some extensions being supplied in binary form, therefore these must be built from source. To achieve this, follow the exact order below on a fresh Linux system **WITHOUT JVM INSTALLED**. 

#### 1. Obtain the specific JDK dependency
Download jdk-8u411-linux-x64.tar.gz from [Oracle](https://www.oracle.com/java/technologies/javase/javase8u211-later-archive-downloads.html) (needs an Oracle sign in, select the Linux x64 compressed archive and copy it to your Linux home dir) A backup of this file is achived [here]( https://1drv.ms/u/s!Asccp3ag4RnQj-dAGYyfqwf-Rf5mTg?e=uRy1DM).

### 2. Install the JDK
```
sudo mkdir -p /usr/lib/jvm
sudo tar zxvf jdk-8u411-linux-x64.tar.gz -C /usr/lib/jvm
sudo update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/jdk1.8.0_411/bin/java" 1
sudo update-alternatives --set java /usr/lib/jvm/jdk1.8.0_411/bin/java
```
### 3. Clone Guacamole client source
```sudo apt update && sudo apt -y install git
git clone https://github.com/apache/guacamole-client.git
cd guacamole-client
git checkout 1.5.5 # or whatever version
```
### 4. Install Maven and build all the client binaries (with Radius support)
```
sudo apt -y install maven
mvn clean package -Plgpl-extensions
```
Build output should show:
```
[INFO] Reactor Summary for guacamole-client 1.5.5:
[INFO] guacamole-client ................................... SUCCESS [ 18.363 s]
[INFO] guacamole-common ................................... SUCCESS [ 10.902 s]
[INFO] guacamole-ext ...................................... SUCCESS [  6.032 s]
[INFO] guacamole-common-js ................................ SUCCESS [ 14.552 s]
[INFO] guacamole .......................................... SUCCESS [01:04 min]
[INFO] extensions ......................................... SUCCESS [  0.132 s]
[INFO] guacamole-auth-duo ................................. SUCCESS [  5.207 s]
[INFO] guacamole-auth-header .............................. SUCCESS [  0.793 s]
[INFO] guacamole-auth-jdbc ................................ SUCCESS [  0.143 s]
[INFO] guacamole-auth-jdbc-base ........................... SUCCESS [  3.314 s]
[INFO] guacamole-auth-jdbc-mysql .......................... SUCCESS [  1.208 s]
[INFO] guacamole-auth-jdbc-postgresql ..................... SUCCESS [  1.008 s]
[INFO] guacamole-auth-jdbc-sqlserver ...................... SUCCESS [  1.004 s]
[INFO] guacamole-auth-jdbc-dist ........................... SUCCESS [  1.072 s]
[INFO] guacamole-auth-json ................................ SUCCESS [  2.648 s]
[INFO] guacamole-auth-ldap ................................ SUCCESS [  8.882 s]
[INFO] guacamole-auth-quickconnect ........................ SUCCESS [  1.704 s]
[INFO] guacamole-auth-sso ................................. SUCCESS [  0.132 s]
[INFO] guacamole-auth-sso-base ............................ SUCCESS [  0.667 s]
[INFO] guacamole-auth-sso-cas ............................. SUCCESS [  5.205 s]
[INFO] guacamole-auth-sso-openid .......................... SUCCESS [  1.237 s]
[INFO] guacamole-auth-sso-saml ............................ SUCCESS [  3.801 s]
[INFO] guacamole-auth-sso-dist ............................ SUCCESS [  1.312 s]
[INFO] guacamole-auth-totp ................................ SUCCESS [  2.780 s]
[INFO] guacamole-history-recording-storage ................ SUCCESS [  0.646 s]
[INFO] guacamole-vault .................................... SUCCESS [  0.117 s]
[INFO] guacamole-vault-base ............................... SUCCESS [  1.005 s]
[INFO] guacamole-vault-ksm ................................ SUCCESS [  5.242 s]
[INFO] guacamole-vault-dist ............................... SUCCESS [  1.050 s]
[INFO] guacamole-auth-radius .............................. SUCCESS [ 11.777 s] 
[INFO] guacamole-example .................................. SUCCESS [  2.080 s]
[INFO] guacamole-playback-example ......................... SUCCESS [  0.883 s]
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  02:59 min
[INFO] Finished at: 2024-10-29T11:38:19+11:00
[INFO] ------------------------------------------------------------------------
```

### 5 Move your new extension to the Guacamole server  
1. As sudo, copy the new `extension.jar` file (found in `guacamole-client/extensions/guacamole-auth-radius/target/`) to `/etc/guacamole/extensions` on your Guacamole server.
2. Adjust permissions on the new `extension.jar` file with `sudo chmod 664 /etc/guacamole/extensions/extension.jar`
3. Restart and continue configuring the new extension as per the Guacmole official documentation [here](https://guacamole.apache.org/doc/gug/).
