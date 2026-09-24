packages="com.miui.packageinstaller com.google.android.packageinstaller"

mods_center() {
    ui_print "
             __  ___        __  
            /  |/  /__  ___/ /__
           / /|_/ / _ \/ _  (_-
          /_/  /_/\___/\_,_/___/
            _____         __         
           / ___/__ ___  / /____ ____
          / /__/ -_) _ \/ __/ -_) __/
          \___/\__/_//_/\__/\__/_/   
"
}

check_support() {
    android_ver=$(getprop ro.build.version.release)
    hos_version=$(getprop ro.product.build.version.incremental)
    mod_device=$(getprop ro.product.mod_device)
    ui_print "- Checking support..."
    if [ "$android_ver" -lt 15 ]; then
        abort "- Your Android version is not supported"
    fi

    if [[ "$hos_version" != *OS* ]]; then
        abort "- This package installer is supported for HyperOS only"
    fi

    if [[ "$mod_device" == *_global* ]]; then
        ui_print "! Global ROM detected"
        ui_print "! There might be chances of bootloop"
    fi
}

uninstall_updates() {
    ui_print "- Uninstalling installer updates..."
    for pkg in $packages; do
        pm uninstall-system-updates $pkg >/dev/null 2>&1
    done
}

get_package_info() {
    pkg=$1
    installed=$(pm list packages | grep -q "^package:$pkg$" && echo true || echo false)
    path=$(pm path $pkg | sed 's/package://')
    folder=$(dirname "$path")
}

find_replace_folder() {
    local search_dir="/data/adb/modules/$MODID"
    local replace_file=$(find "$search_dir" -name ".replace" -type f)
    if [ -n "$replace_file" ]; then
        local replace_folder=$(dirname "$replace_file")
        replace_folder=${replace_folder#$search_dir}
        if [ -z "$replace_folder" ]; then
            echo "$1"
        else
            echo "$replace_folder"
        fi
    else
        echo "$1"
    fi
}

install_package() {
    installer=$1
    partition=$2
    replace_folder=$3
    app_name=$(basename "$replace_folder")
    ui_print "- Replacing $app_name"
    mkdir -p "$MODPATH$replace_folder"
    cp -rf "$MODPATH/files/${installer}.apk" \
        "$MODPATH$replace_folder/$app_name.apk"
        if [ -d "$MODPATH/files/lib" ]; then
        mkdir -p "$MODPATH$replace_folder/lib"
        cp -rf "$MODPATH/files/lib/." \
            "$MODPATH$replace_folder/lib/"
    fi
    replace_folder=$(find_replace_folder "$replace_folder")
    REPLACE="
    $replace_folder
    "
}

add_installer() {
    ui_print "- Installing files for Android $android_ver"
    
    uninstall_updates
    
    for pkg in $packages; do
        get_package_info "$pkg"
        if [ "$installed" = "true" ]; then
            if [[ "$path" == *product* ]]; then
                partition=/system/product
                replace_folder="/system$folder"
            elif [[ "$path" == *system* ]]; then
                partition=/system
                replace_folder="$folder"            
            fi
            
            case $pkg in
                com.miui.packageinstaller) install_package "MiuiPackageInstaller" "$partition" "$replace_folder" ;;
                com.google.android.packageinstaller) install_package "GooglePackageInstaller" "$partition" "$replace_folder" ;;
            esac
            return
        fi
    done
    
    abort "- No supported package installer found"
}

delete_cache_files() {
    for file in "$1"/*; do
        if [ -f "$file" ]; then
            echo "$file" | grep -qi "installer" && rm -f "$file"
        elif [ -d "$file" ]; then
            delete_cache_files "$file"
        fi
    done
}

clean_files() {
    rm -rf "$MODPATH/addon" "$MODPATH/files" 2>/dev/null
    rm -f "$MODPATH/install.sh" 2>/dev/null
    base_dir="/data/system/package_cache"
    delete_cache_files "$base_dir"
    touch "$MODPATH/miui_pkg_installer/remove"
}

run_install() {
    mods_center
    check_support
    add_installer
    clean_files
}

run_install