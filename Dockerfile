FROM --platform=$BUILDPLATFORM alpine:3.18.12 AS android-sdk-builder

# Build arguments
ARG SDK_VERSION="9477386_latest"
ARG NDK_VERSION="21.4.7075529"
ARG APKTOOL_VERSION="2.12.1"

# Install operational system dependencies
RUN apk --update --no-cache add curl openjdk17-jdk bash unzip make file libc6-compat gcompat gcc g++
RUN mkdir /apktool && \
  curl -L "https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_""$APKTOOL_VERSION"".jar" --output /apktool/apktool.jar

# Copy Android Mugen repository
COPY android-mugen /android-mugen
RUN sed -i "s|applicationId \"com\.fishstix\.dosboxfree\"|applicationId \"aaaaa.bbbbb.ccccc\"|g" /android-mugen/app/build.gradle

# Install Android Command-line tools
WORKDIR /
RUN export ANDROID_SDK_ROOT=/android-sdk && \
  export NDK_HOST_AWK=/usr/bin/gawk && \
  mkdir /android-sdk && \
  curl -L https://dl.google.com/android/repository/commandlinetools-linux-${SDK_VERSION}.zip --output /android-sdk/cmdline-tools.zip && \
  unzip /android-sdk/cmdline-tools.zip && \
  mkdir -p /android-sdk/cmdline-tools && \
  mv cmdline-tools /android-sdk/cmdline-tools/latest && \
  cd /android-sdk/cmdline-tools/latest/bin && \
  echo "y" | ./sdkmanager "build-tools;36.0.0" "platform-tools" "platforms;android-36" "tools" "ndk;${NDK_VERSION}" && \
  cd /android-mugen && \
  mkdir /android-mugen/app/src/main/assets/mugen/ && \
  touch /android-mugen/app/src/main/assets/mugen/mugen.exe && \
  touch /android-mugen/app/src/main/assets/mugen/CWSDPMI.EXE && \
  ./gradlew build --no-daemon --no-build-cache && \
  java -jar /apktool/apktool.jar d app/build/outputs/apk/release/app-release-unsigned.apk -o /mugen-android && \
  rm -R /android-mugen/app/src/main/assets/mugen/ && \
  rm /android-mugen/app/build/outputs/apk/debug/app-debug.apk && \
  rm /android-mugen/app/build/outputs/apk/release/app-release-unsigned.apk && \
  rm /android-mugen/app/src/main/res/drawable-hdpi/icon.png && \
  rm /android-mugen/app/src/main/res/drawable-ldpi/icon.png && \
  rm /android-mugen/app/src/main/res/drawable-mdpi/icon.png && \
  rm /android-mugen/app/src/main/res/drawable-xhdpi/icon.png && \
  rm -R /android-sdk ~/.gradle ~/.android && \
  unset ANDROID_SDK_ROOT

# Another image with only used resources
FROM alpine:3.23.3

# Install dependencies
RUN apk --update --no-cache add curl openjdk17-jdk imagemagick oxipng abseil-cpp-hash gtest libprotobuf fmt && \
  apk --update --no-cache add android-build-tools --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing/
RUN curl -L "https://github.com/carlsonsantana/signmyapp/releases/download/1.1.0/signmyapp.jar" --output /opt/signmyapp.jar && \
  curl -L "https://github.com/google/bundletool/releases/download/1.18.3/bundletool-all-1.18.3.jar" --output /opt/bundletool.jar && \
  curl -L "https://github.com/Sable/android-platforms/raw/f2ca864c44f277bbc09afda0ba36437ce22105f0/android-36/android.jar" --output /opt/android.jar

# Copy files from previous build
RUN mkdir /apktool
COPY --from=android-sdk-builder /apktool/apktool.jar /apktool/apktool.jar
COPY --from=android-sdk-builder /mugen-android /mugen-android

# Volumes
RUN mkdir /output && mkdir /mugen
VOLUME /mugen
VOLUME /icon.png
VOLUME /output
VOLUME /game_certificate.key
VOLUME /run/secrets/game_keystore_password
VOLUME /run/secrets/game_keystore_key_alias
VOLUME /run/secrets/game_keystore_key_password

# Environment variables
ENV GAME_APK_NAME="com.mycompany.gamename"
ENV GAME_NAME="Game Name"
ENV GAME_VERSION_CODE="100"
ENV GAME_VERSION_NAME="1.0.0"

# Run build
WORKDIR /
COPY script /script
CMD ["sh", "/script/run.sh"]
