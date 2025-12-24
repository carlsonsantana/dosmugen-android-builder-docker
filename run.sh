#!/bin/sh

set -e

rm -f /tmp/mugen-unsigned.apk /output/mugen-aligned.apk

# Convert icons
magick /icon.png -resize 72x72 /mugen-android/res/drawable-hdpi/icon.png
magick /icon.png -resize 36x36 /mugen-android/res/drawable-ldpi/icon.png
magick /icon.png -resize 48x48 /mugen-android/res/drawable-mdpi/icon.png
magick /icon.png -resize 96x96 /mugen-android/res/drawable-xhdpi/icon.png

# Rename APK name and application ID
sed -i "s|FreeBox|$GAME_NAME|g" /mugen-android/res/values/strings.xml
sed -i "s|\"aaaaa\.bbbbb\.ccccc\"|\"$GAME_APK_NAME\"|g" /mugen-android/AndroidManifest.xml
printf "version: 2.12.1\napkFileName: app-release-unsigned.apk\nusesFramework:\n  ids:\n  - 1\nsdkInfo:\n  minSdkVersion: 14\n  targetSdkVersion: 21\npackageInfo:\n  forcedPackageId: 127\n  renameManifestPackage: "$GAME_APK_NAME"\nversionInfo:\n  versionCode: "$GAME_VERSION_CODE"\n  versionName: "$GAME_VERSION_NAME"\ndoNotCompress:\n- arsc\n- png\n- assets/mugen/CWSDPMI.EXE\n- assets/mugen/mugen.exe" > /mugen-android/apktool.yml

# Copy DOS Mugen
cp -r /mugen /mugen-android/assets

# Build an aligned version of the Android app
java -jar /apktool/apktool.jar b /mugen-android -o /tmp/mugen-unsigned.apk
zipalign -v -p 4 /tmp/mugen-unsigned.apk /output/mugen-aligned.apk

rm /tmp/mugen-unsigned.apk
