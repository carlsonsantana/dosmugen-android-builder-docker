FROM debian:bullseye-20251117-slim as android-sdk-builder

# Build arguments
ARG SDK_VERSION="9477386_latest"
ARG NDK_VERSION="16.1.4479499"
ARG APKTOOL_VERSION="2.12.1"

# Environment variables
ENV GAME_APK_NAME "Game Name"
ENV GAME_NAME "com.mycompany.gamename"

# Install operational system dependencies
RUN apt update && apt upgrade -y && \
  apt install -y curl unzip openjdk-11-jdk openjdk-17-jdk make imagemagick && \
  apt-get clean -y && \
  apt-get autoremove -y && \
  apt-get autoclean -y && \
  rm -rf /tmp/* && \
  rm -rf /var/lib/apt/lists/*
RUN mkdir /apktool && \
  curl -L "https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_""$APKTOOL_VERSION"".jar" --output /apktool/apktool.jar

# Copy Android Mugen repository
COPY android-mugen /android-mugen

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
  update-alternatives --set java $(update-alternatives --list java | grep java-17) && \
  echo "y" | ./sdkmanager "build-tools;29.0.3" "platform-tools" "platforms;android-29" "tools" "ndk;${NDK_VERSION}" && \
  cd /android-mugen && \
  mkdir /android-mugen/app/src/main/assets/mugen/ && \
  touch /android-mugen/app/src/main/assets/mugen/mugen.exe && \
  touch /android-mugen/app/src/main/assets/mugen/CWSDPMI.EXE && \
  update-alternatives --set java $(update-alternatives --list java | grep java-11) && \
  ./gradlew build --no-daemon --no-build-cache && \
  update-alternatives --set java $(update-alternatives --list java | grep java-17) && \
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

# Volumes
RUN mkdir /output && mkdir /mugen
VOLUME /mugen
VOLUME /icon.png
VOLUME /output

# Run build
WORKDIR /
COPY run.sh /
CMD ["bash", "/run.sh"]
