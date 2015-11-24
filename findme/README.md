## FindMe
Keyboard expander for user names.  Helpful for little ones.

## Build Instructions
1. Make a tab-delimited text file that has a current list of your domain's user names.

2. Enter configuration information in AppConfig.plist.  There are three keys:
    * userDomainSuffix:  like "@example.com" (append this to user names)
    * updateURL:         "http://example.com/users"
    * updateApiKey:      "apikey" (sent to updateURL in Authorization header)

3. In order for "Update User List" action to work, you will need to host a live webserver 
    that will respond with a "text/plain", UTF-8-encoded, tab-delimited data that represents 
    the valid user names for your domain.

## Xcode Notes
Targeted for OS X 10.6, built on Xcode 6.3 on OS X 10.10.

### 10.6 Compatiblity Notes
1. "Illegal Configuration. Auto Layout on OS X prior to 10.7"
    Edit Main.storyboard. Open the file inspector by choosing View > Utilities > Show File Inspector.
    Uncheck "Use Auto Layout" checkbox.

2. "Attribute Unavailable. Use Current Width For Max Layout on Mac OS X versions prior to 10.8"
    Uncheck "Use First Layout as Width as Max", in all text fields. This didn't remove the warning...