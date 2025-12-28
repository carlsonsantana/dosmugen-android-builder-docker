#!/bin/sh

set -e

APP_BASENAME="mugen"
APKTOOL_DECODED_PATH="/mugen-android"
RESOURCE_PREFIX="dosmugen"

TEMP_UNSIGNED_APK_FILE="/tmp/$APP_BASENAME-unsigned.apk"
TEMP_ALIGNED_APK_FILE="/tmp/$APP_BASENAME-aligned.apk"
TEMP_UNSIGNED_AAB_FILE="/tmp/$APP_BASENAME-unsigned.aab"
OUTPUT_ALIGNED_APK_FILE="/output/$APP_BASENAME-aligned.apk"
OUTPUT_SIGNED_APK_FILE="/output/$APP_BASENAME-signed.apk"
OUTPUT_UNSIGNED_AAB_FILE="/output/$APP_BASENAME-unsigned.aab"
OUTPUT_SIGNED_AAB_FILE="/output/$APP_BASENAME-signed.aab"
TEMP_RESOURCES_AAB_PATH="/tmp/$APKTOOL_DECODED_PATH-res-aab"

# Remove previous files build
rm -f "$TEMP_UNSIGNED_APK_FILE" "$TEMP_ALIGNED_APK_FILE" "$TEMP_UNSIGNED_AAB_FILE"
rm -fr /tmp/apk /tmp/res.zip /tmp/_base.zip /tmp/base /tmp/base.zip "$TEMP_RESOURCES_AAB_PATH"
rm -f "$OUTPUT_ALIGNED_APK_FILE" "$OUTPUT_SIGNED_APK_FILE" "$OUTPUT_UNSIGNED_AAB_FILE" "$OUTPUT_SIGNED_AAB_FILE"

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
resize_icon "36x36" "$APKTOOL_DECODED_PATH/res/drawable-ldpi/icon.png"
resize_icon "48x48" "$APKTOOL_DECODED_PATH/res/drawable-mdpi/icon.png"
resize_icon "72x72" "$APKTOOL_DECODED_PATH/res/drawable-hdpi/icon.png"
resize_icon "96x96" "$APKTOOL_DECODED_PATH/res/drawable-xhdpi/icon.png"
resize_icon "144x144" "$APKTOOL_DECODED_PATH/res/drawable-xxhdpi/icon.png"
resize_icon "192x192" "$APKTOOL_DECODED_PATH/res/drawable-xxxhdpi/icon.png"

# Rename APK name and application ID
sed -i "s|FreeBox|$GAME_NAME|g" $APKTOOL_DECODED_PATH/res/values/strings.xml
sed -i "s|\"aaaaa\.bbbbb\.ccccc\"|\"$GAME_APK_NAME\"|g" $APKTOOL_DECODED_PATH/AndroidManifest.xml
printf "version: 2.12.1\napkFileName: app-release-unsigned.apk\nusesFramework:\n  ids:\n  - 1\nsdkInfo:\n  minSdkVersion: 21\n  targetSdkVersion: 36\npackageInfo:\n  forcedPackageId: 127\n  renameManifestPackage: "$GAME_APK_NAME"\nversionInfo:\n  versionCode: "$GAME_VERSION_CODE"\n  versionName: "$GAME_VERSION_NAME"\ndoNotCompress:\n- arsc\n- png\n- assets/mugen/CWSDPMI.EXE\n- assets/mugen/mugen.exe" > $APKTOOL_DECODED_PATH/apktool.yml

# Copy DOS Mugen
cp -r /mugen $APKTOOL_DECODED_PATH/assets

# Build an aligned version of the Android app
java -jar /apktool/apktool.jar b $APKTOOL_DECODED_PATH -o $TEMP_UNSIGNED_APK_FILE
zipalign -v -p 4 $TEMP_UNSIGNED_APK_FILE $TEMP_ALIGNED_APK_FILE

# Build the Android App Bundle (.aab)
cp -r $APKTOOL_DECODED_PATH/res/ $TEMP_RESOURCES_AAB_PATH
cd $TEMP_RESOURCES_AAB_PATH
find . -type f -name '$*' | while read -r file; do
    # Get the directory name and the base filename
    dir=$(dirname "$file")
    base=$(basename "$file")

    # Remove the $ (first char) and add the prefix
    new_name="$RESOURCE_PREFIX""_${base#\$}"

    # Perform the move
    mv -v "$file" "$dir/$new_name"

    find . -type f -name '*.xml' -exec sed -i "s/"${base%.*}"/"${new_name%.*}"/g" {} +
done
cd /
unzip $TEMP_UNSIGNED_APK_FILE -d /tmp/apk
aapt2 compile --dir $TEMP_RESOURCES_AAB_PATH -o /tmp/res.zip
aapt2 link --proto-format -o /tmp/_base.zip -I /opt/android.jar --manifest $APKTOOL_DECODED_PATH/AndroidManifest.xml --min-sdk-version 21 --target-sdk-version 36 --version-code "$GAME_VERSION_CODE" --version-name "$GAME_VERSION_NAME" -R /tmp/res.zip --auto-add-overlay
unzip /tmp/_base.zip -d /tmp/base
cp -r $APKTOOL_DECODED_PATH/assets/ $APKTOOL_DECODED_PATH/lib/ $APKTOOL_DECODED_PATH/unknown/ /tmp/base
mkdir /tmp/base/manifest /tmp/base/dex
mv /tmp/base/AndroidManifest.xml /tmp/base/manifest/AndroidManifest.xml
mv /tmp/base/unknown /tmp/base/root
mv /tmp/apk/*.dex /tmp/base/dex
cd /tmp/base
jar cMf /tmp/base.zip manifest dex res root lib assets resources.pb
cd /
java -jar /opt/bundletool.jar build-bundle --modules=/tmp/base.zip --output=$TEMP_UNSIGNED_AAB_FILE
chmod 644 $TEMP_UNSIGNED_AAB_FILE

# Sign the APK and AAB
if [ -f "/game_certificate.key" ]; then
  java -jar /opt/signmyapp.jar -ks /game_certificate.key -ks-pass "$GAME_KEYSTORE_PASSWORD" -ks-key-alias "$GAME_KEYSTORE_KEY_ALIAS" -key-pass "$GAME_KEYSTORE_KEY_PASSWORD" -in $TEMP_ALIGNED_APK_FILE -out $OUTPUT_SIGNED_APK_FILE

  SIGALG=$(get_sigalg)
  jarsigner -verbose -sigalg $SIGALG -digestalg SHA-256 -signedjar $OUTPUT_SIGNED_AAB_FILE -keystore /game_certificate.key -storepass "$GAME_KEYSTORE_PASSWORD" $TEMP_UNSIGNED_AAB_FILE "$GAME_KEYSTORE_KEY_ALIAS"

  rm $TEMP_ALIGNED_APK_FILE $TEMP_UNSIGNED_AAB_FILE
else
  mv $TEMP_ALIGNED_APK_FILE $OUTPUT_ALIGNED_APK_FILE
  mv $TEMP_UNSIGNED_AAB_FILE $OUTPUT_UNSIGNED_AAB_FILE
fi

rm -f $TEMP_UNSIGNED_APK_FILE
rm -fr /tmp/apk /tmp/res.zip /tmp/_base.zip /tmp/base /tmp/base.zip $TEMP_RESOURCES_AAB_PATH
