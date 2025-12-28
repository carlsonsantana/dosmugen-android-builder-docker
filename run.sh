#!/bin/sh

set -e

# Remove previous files build
rm -f /tmp/mugen-unsigned.apk /tmp/mugen-aligned.apk /tmp/mugen-unsigned.aab
rm -fr /tmp/apk /tmp/res.zip /tmp/_base.zip /tmp/base /tmp/base.zip /tmp/mugen-android-res-aab
rm -f /output/mugen-aligned.apk /output/mugen-signed.apk /output/mugen-unsigned.aab /output/mugen-signed.aab

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

resize_icon() {
  magick /icon.png -resize $1 $2 && oxipng -o 6 --strip safe $2
}

get_sigalg() {
  RAW_INFO=$(keytool -list -v -keystore /game_certificate.key -alias "$GAME_KEYSTORE_KEY_ALIAS" -storepass "$GAME_KEYSTORE_PASSWORD" | grep "Signature algorithm name")

  case "$RAW_INFO" in
    *RSA*) echo "SHA256withRSA" ;;
    *ECDSA*) echo "SHA256withECDSA" ;;
    *EC*) echo "SHA256withECDSA" ;;
    *DSA*) echo "SHA256withDSA" ;;
    *) echo "Unknown or unsupported key type."; exit 1 ;;
  esac
}

# Convert icons
resize_icon "36x36" "/mugen-android/res/drawable-ldpi/icon.png"
resize_icon "48x48" "/mugen-android/res/drawable-mdpi/icon.png"
resize_icon "72x72" "/mugen-android/res/drawable-hdpi/icon.png"
resize_icon "96x96" "/mugen-android/res/drawable-xhdpi/icon.png"
resize_icon "144x144" "/mugen-android/res/drawable-xxhdpi/icon.png"
resize_icon "192x192" "/mugen-android/res/drawable-xxxhdpi/icon.png"

# Rename APK name and application ID
sed -i "s|FreeBox|$GAME_NAME|g" /mugen-android/res/values/strings.xml
sed -i "s|\"aaaaa\.bbbbb\.ccccc\"|\"$GAME_APK_NAME\"|g" /mugen-android/AndroidManifest.xml
printf "version: 2.12.1\napkFileName: app-release-unsigned.apk\nusesFramework:\n  ids:\n  - 1\nsdkInfo:\n  minSdkVersion: 21\n  targetSdkVersion: 36\npackageInfo:\n  forcedPackageId: 127\n  renameManifestPackage: "$GAME_APK_NAME"\nversionInfo:\n  versionCode: "$GAME_VERSION_CODE"\n  versionName: "$GAME_VERSION_NAME"\ndoNotCompress:\n- arsc\n- png\n- assets/mugen/CWSDPMI.EXE\n- assets/mugen/mugen.exe" > /mugen-android/apktool.yml

# Copy DOS Mugen
cp -r /mugen /mugen-android/assets

# Build an aligned version of the Android app
java -jar /apktool/apktool.jar b /mugen-android -o /tmp/mugen-unsigned.apk
zipalign -v -p 4 /tmp/mugen-unsigned.apk /tmp/mugen-aligned.apk

# Build the Android App Bundle (.aab)
cp -r /mugen-android/res/ /tmp/mugen-android-res-aab
cd /tmp/mugen-android-res-aab
find . -type f -name '$*' | while read -r file; do
    # Get the directory name and the base filename
    dir=$(dirname "$file")
    base=$(basename "$file")

    # Remove the $ (first char) and add the prefix
    new_name="dosmugen_${base#\$}"

    # Perform the move
    mv -v "$file" "$dir/$new_name"

    find . -type f -name '*.xml' -exec sed -i "s/"${base%.*}"/"${new_name%.*}"/g" {} +
done
cd /
unzip /tmp/mugen-unsigned.apk -d /tmp/apk
aapt2 compile --dir /tmp/mugen-android-res-aab -o /tmp/res.zip
aapt2 link --proto-format -o /tmp/_base.zip -I /opt/android.jar --manifest /mugen-android/AndroidManifest.xml --min-sdk-version 21 --target-sdk-version 36 --version-code "$GAME_VERSION_CODE" --version-name "$GAME_VERSION_NAME" -R /tmp/res.zip --auto-add-overlay
unzip /tmp/_base.zip -d /tmp/base
cp -r /mugen-android/assets/ /mugen-android/lib/ /mugen-android/unknown/ /tmp/base
mkdir /tmp/base/manifest /tmp/base/dex
mv /tmp/base/AndroidManifest.xml /tmp/base/manifest/AndroidManifest.xml
mv /tmp/base/unknown /tmp/base/root
mv /tmp/apk/*.dex /tmp/base/dex
cd /tmp/base
jar cMf /tmp/base.zip manifest dex res root lib assets resources.pb
cd /
java -jar /opt/bundletool.jar build-bundle --modules=/tmp/base.zip --output=/tmp/mugen-unsigned.aab
chmod 644 /tmp/mugen-unsigned.aab

# Sign the APK and AAB
if [ -f "/game_certificate.key" ]; then
  java -jar /opt/signmyapp.jar -ks /game_certificate.key -ks-pass "$GAME_KEYSTORE_PASSWORD" -ks-key-alias "$GAME_KEYSTORE_KEY_ALIAS" -key-pass "$GAME_KEYSTORE_KEY_PASSWORD" -in /tmp/mugen-aligned.apk -out /output/mugen-signed.apk

  SIGALG=$(get_sigalg)
  jarsigner -verbose -sigalg $SIGALG -digestalg SHA-256 -signedjar /output/mugen-signed.aab -keystore /game_certificate.key -storepass "$GAME_KEYSTORE_PASSWORD" /tmp/mugen-unsigned.aab "$GAME_KEYSTORE_KEY_ALIAS"

  rm /tmp/mugen-aligned.apk /tmp/mugen-unsigned.aab
else
  mv /tmp/mugen-aligned.apk /output/mugen-aligned.apk
  mv /tmp/mugen-unsigned.aab /output/mugen-unsigned.aab
fi

rm -f /tmp/mugen-unsigned.apk
rm -fr /tmp/apk /tmp/res.zip /tmp/_base.zip /tmp/base /tmp/base.zip /tmp/mugen-android-res-aab
