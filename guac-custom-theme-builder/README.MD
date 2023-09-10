
## Custom branding & theme instructions ##

1. Install the Java JDK: `sudo apt update && sudo apt -y install default-jdk`
3. Modify `custom-theme.css` ,`guac-manifest.json`, `en.json` & `META-INF` as desired & add your logo .png files to the images directory.
4. To commit your changes, run the below commands from within the custom-theme-builder directory, then refresh your browser to re-login to Guacamole:
```
# Run within the custom-theme-builder directory 
jar cfmv branding.jar META-INF/MANIFEST.MF guac-manifest.json css images translations META-INF
sudo mv branding.jar /etc/guacamole/extensions 
sudo chmod 664 /etc/guacamole/extensions/branding.jar 
TOMCAT=$(ls /etc/ | grep tomcat)
sudo systemctl restart guacd && sudo systemctl restart ${TOMCAT}
```

## Theme customisation hints: ##
  - Do not change any of the theme's directory structure or file names. File contents can be carefully edited according to the following constraints:
      - `MANIFEST.MF`: All values in here can be updated. Be aware that the "Name:" value MUST use same value in front of the the .jar creation command shown above in the 1st line e.g. `Name: branding` expects branding.jar
      - `guac-manifest.json`: The "name:" value in here can be changed to anything. The "namespace:" value MUST match the namespace image path line found in `custom-theme.css`, eg.`background-image: url('app/ext/custom-namespace/images/logo.png');`
  - It is preferable to give css a range of logo sizes as shown in the template. The "smallIcon" value in `guac-manifest.json` is used for browser tab favicons. As such this file can be kept to < 80x80 pixels. The example used is 64x64 pixels.
  - Within `custom-theme.css`, you may need to experiment with the the height and width values under `.login-ui .login-dialog .logo` to scale your particular logo neatly within the dialog box. Another option is to make the login dialog box larger. Under `.login-ui .login-dialog`, experiment with adding a `max-width: 4in;` or similar. There's a ton of css options available and this template is just starting point, Google is your friend!
  - An easy way to debug and preview potential style changes is to tweak various values by setting your browser to developer mode. 
  - Your changes may occasionally appear not to update, if so clear your browser cache before doing any further debugging.
