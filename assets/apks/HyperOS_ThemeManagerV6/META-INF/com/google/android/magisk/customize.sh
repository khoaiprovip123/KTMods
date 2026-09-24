# HEADER PRINT
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
# MODING CHECKS METHODS
verify_and_start_flashing() {
    ui_print " "
    hos_version=$(getprop ro.mi.os.version.incremental)
    if [[ "$hos_version" == *OS3* ]]; then
    package_extract_dir files "$MODPATH/files"
    add_pkg
    
    else
    abort "
    HyperOS version is not supported.
    Current app mod is supported for HyperOS 3 Only
    "
    fi
}

add_pkg() {
    PACKAGE_NAME="com.android.thememanager"

    ui_print "- Locating Theme app package..."
    app_path=$(pm path "$PACKAGE_NAME" | sed 's/package://')
    if ! exist "$app_path"; then
        ui_print "- Package not found, adding to a new directory..."
        app_path="/product/app/MIUIThemeManager/MIUIThemeManager.apk"
    fi

    # Ensure the directory for the new app_path exists
    mkdir -p "$(dirname "$MODPATH/system$app_path")"
    pm install -r "$MODPATH/files/MIUIThemeManager.apk" 2>/dev/null

    app_path="$MODPATH/system$app_path"
    ui_print "- Copying ThemeApp.apk..."
    cp -f "$MODPATH/files/MIUIThemeManager.apk" "$app_path"
    mkdir -p "$(dirname "$app_path")/lib"
    cp -r "$MODPATH/files/lib" "$(dirname "$app_path")/"
    chmod 731 "/data/system/theme"
    ui_print "- Validating MIUIThemeManager.apk..."
    if ! is_valid "$app_path"; then
        abort "! Validation failed for Theme app"
    fi
}

delete_cache_files() {
    for file in "$1"/*; do
        if [ -f "$file" ]; then
            echo "$file" | grep -qi "theme" && rm -f "$file"
        elif [ -d "$file" ]; then
            delete_cache_files "$file"
        fi
    done
}

clean_environment() {
    rm -r "$MODPATH/files"
    ui_print " - Cleaning package cache..."
    base_dir="/data/system/package_cache"
    delete_cache_files "$base_dir"
    rm "$MODPATH/customize.sh"
}

# MODDING CHECKS CALLS
verify_and_start_flashing

ui_print "
"
# CLEAN THE ENV
clean_environment
ui_print "- Done, reboot your device."
