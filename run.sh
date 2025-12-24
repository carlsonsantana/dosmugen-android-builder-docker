#!/bin/sh

set -e

rm -f /tmp/mugen-unsigned.apk /tmp/mugen-aligned.apk /output/mugen-aligned.apk /output/mugen-signed.apk

if [ -f "/game_certificate.key" ]; then
  if [ -z "$GAME_KEYSTORE_PASSWORD" ] || [ -z "$GAME_KEYSTORE_KEY_ALIAS" ] || [ -z "$GAME_KEYSTORE_KEY_PASSWORD" ]; then
    echo "ERROR: Partial keystore configuration detected."
    echo "You must provide ALL THREE variables, when pass '/game_certificate.key' VOLUME."
    echo "Missing values for: "
    [ -z "$GAME_KEYSTORE_PASSWORD" ] && echo "- GAME_KEYSTORE_PASSWORD"
    [ -z "$GAME_KEYSTORE_KEY_ALIAS" ] && echo "- GAME_KEYSTORE_KEY_ALIAS"
    [ -z "$GAME_KEYSTORE_KEY_PASSWORD" ] && echo "- GAME_KEYSTORE_KEY_PASSWORD"
    exit 1
  fi
fi

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
zipalign -v -p 4 /tmp/mugen-unsigned.apk /tmp/mugen-aligned.apk

if [ -f "/game_certificate.key" ]; then
  java -jar /opt/signmyapp.jar -ks /game_certificate.key -ks-pass "$GAME_KEYSTORE_PASSWORD" -ks-key-alias "$GAME_KEYSTORE_KEY_ALIAS" -key-pass "$GAME_KEYSTORE_KEY_PASSWORD" -in /tmp/mugen-aligned.apk -out /output/mugen-signed.apk
  rm /tmp/mugen-aligned.apk
else
  mv /tmp/mugen-aligned.apk /output/mugen-aligned.apk
fi

rm /tmp/mugen-unsigned.apk
