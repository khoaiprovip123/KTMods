ui_print "
             __  ___        __  
            /  |/  /__  ___/ /__
           / /|_/ / _ \/ _  (_-<
          /_/  /_/\___/\_,_/___/
            _____         __         
           / ___/__ ___  / /____ ____
          / /__/ -_) _ \/ __/ -_) __/
          \___/\__/_//_/\__/\__/_/   
"

# Check Android version
# Android 14+ users must disable signature verification
android_version=$(getprop ro.build.version.release)
if [ "$android_version" -lt 14 ]; then
    abort "
    Android version is not supported.
    "
elif [ "$android_version" -ge 14 ]; then
    ui_print "
    ------------------------------------------
                     READ!!!                  
     Signature verification must be disabled  
         mandatory for Android 14+ users;      
       otherwise, the module will not work.    
    ------------------------------------------
    "
fi

# Check if the module is installed in the correct directory
patch_vault() {
    PACKAGE_NAME="com.miui.personalassistant"
    ui_print "- Locating app vault package..."
    pm uninstall-system-updates "$PACKAGE_NAME" 2>/dev/null
    pm disable "com.mi.globalminusscreen" 2>/dev/null

    app_path=$(pm path "$PACKAGE_NAME" | sed 's/package://')
    if ! exist "$app_path"; then
        ui_print "- Package not found, adding to a new directory..."
        app_path="/product/priv-app/MIUIPersonalAssistantPhoneOS2NoBeta/MIUIPersonalAssistantPhoneOS2NoBeta.apk"
    fi

    # Ensure the directory for the new app_path exists
    mkdir -p "$(dirname "$MODPATH/system$app_path")"

    app_path="$MODPATH/system$app_path"
    pm install -r "$MODPATH/files/AppVault.apk" 2>/dev/null
    ui_print "- Copying AppVault.apk..."
    cp -f "$MODPATH/files/AppVault.apk" "$app_path"
    ui_print "- Validating AppVault.apk..."
    if ! is_valid "$app_path"; then
        abort "! Validation failed for App vault"
    fi
}

delete_cache_files() {
    for file in "$1"/*; do
        if [ -f "$file" ]; then
            echo "$file" | grep -Eqi "vault|assistant" && rm -f "$file"
        elif [ -d "$file" ]; then
            delete_cache_files "$file"
        fi
    done
}

clean_environment() {
    ui_print " - Cleaning package cache..."
    base_dir="/data/system/package_cache"
    delete_cache_files "$base_dir"
    ui_print " - Fixing contexts..."
    set_context /system "$MODPATH/system"
    rm -r "$MODPATH/files"
    rm "$MODPATH/customize.sh"
    ui_print "- Done"
}

# Extract the files from the module
package_extract_dir files "$MODPATH/files"
package_extract_dir system "$MODPATH/system"
# Main script starts here

patch_vault
ui_print " - Make sure to use launcher mod and theme app mod to make widgets work correctly"
ui_print " - Done, reboot your device."
clean_environment
