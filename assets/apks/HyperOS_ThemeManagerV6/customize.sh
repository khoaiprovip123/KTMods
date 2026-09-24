#!/sbin/sh
#Require DI v4.8+

#-----------SPECIAL VARS-----------#
SKIPUNZIP=0
#----------------------------------#

#You can define which additional variables should be shared with the DI
SHARED_VARS="

MODPATH
SKIPUNZIP
SKIPMOUNT
PROPFILE
POSTFSDATA
LATESTARTSERVICE
KSU
KSU_VER
KSU_VER_CODE
KSU_KERNEL_VER_CODE

"

#Exporting the SPECIAL VARIABLES ensures that they are also shared with the DI
export SHARED_VARS $SHARED_VARS
#Get update-binary
binary="META-INF/com/google/android/update-binary"
binaryout="$TMPDIR/$binary"
unzip -qo "$ZIPFILE" "$binary" -d "$TMPDIR"
if [ -f "$binaryout" ]; then
   . "$binaryout"
else
    abort "SETUP: Can't get update-binary"
fi
