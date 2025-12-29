#!/bin/sh

set -e

APP_BASENAME="mugen"
APKTOOL_DECODED_PATH="/mugen-android"
RESOURCE_PREFIX="dosmugen"
ICON_BASENAME="icon"

source "/script/common.sh"

remove_previous_files_build
validate_environment_variables_filled
replace_icons

# Rename app name and application ID
sed -i "s|FreeBox|$GAME_NAME|g" $APKTOOL_DECODED_PATH/res/values/strings.xml
sed -i "s|\"aaaaa\.bbbbb\.ccccc\"|\"$GAME_APK_NAME\"|g" $APKTOOL_DECODED_PATH/AndroidManifest.xml
printf "version: 2.12.1\napkFileName: app-release-unsigned.apk\nusesFramework:\n  ids:\n  - 1\nsdkInfo:\n  minSdkVersion: 21\n  targetSdkVersion: 36\npackageInfo:\n  forcedPackageId: 127\n  renameManifestPackage: "$GAME_APK_NAME"\nversionInfo:\n  versionCode: "$GAME_VERSION_CODE"\n  versionName: "$GAME_VERSION_NAME"\ndoNotCompress:\n- arsc\n- png\n- assets/mugen/CWSDPMI.EXE\n- assets/mugen/mugen.exe" > $APKTOOL_DECODED_PATH/apktool.yml

# Copy DOS Mugen
cp -r /mugen $APKTOOL_DECODED_PATH/assets
rm -rf $APKTOOL_DECODED_PATH/assets/mugen/docs $APKTOOL_DECODED_PATH/assets/mugen/chars/readme.txt $APKTOOL_DECODED_PATH/assets/mugen/sound/readme.txt

# Remove comments
if [ "$GAME_OPTIMIZATION_REMOVE_COMMENTS" == "true" ]; then
  find $APKTOOL_DECODED_PATH/assets/mugen -type f -name '*.def' -exec sed -i -e 's/[ \t]*;.*//g' {} \;
  find $APKTOOL_DECODED_PATH/assets/mugen -type f -name '*.air' -exec sed -i -e 's/[ \t]*;.*//g' {} \;
  find $APKTOOL_DECODED_PATH/assets/mugen -type f -name '*.cmd' -exec sed -i -e 's/[ \t]*;.*//g' {} \;
  find $APKTOOL_DECODED_PATH/assets/mugen -type f -name '*.cns' -exec sed -i -e 's/[ \t]*;.*//g' {} \;
fi

build_aligned_apk
build_unsigned_aab
sign_apk_aab
remove_temp_files
