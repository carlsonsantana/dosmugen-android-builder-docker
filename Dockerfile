FROM debian:bullseye-20251117-slim as android-sdk-builder

# Environment variables
ENV SDK_VERSION "9477386_latest"
ENV ANDROID_SDK_ROOT /android-sdk
ENV NDK_VERSION "16.1.4479499"
ENV NDK_HOST_AWK /usr/bin/gawk
ENV KEYSTORE_NAME keystore_name
ENV KEYSTORE_PASSWORD keystore_password
ENV GAME_APK_NAME ""
ENV GAME_NAME ""

# Install operational system dependencies
RUN apt update && apt upgrade -y && \
  apt install -y curl unzip openjdk-11-jdk openjdk-17-jdk make && \
  apt-get clean -y && \
  apt-get autoremove -y && \
  apt-get autoclean -y && \
  rm -rf /tmp/* && \
  rm -rf /var/lib/apt/lists/*

# Install Android Command-line tools
RUN curl https://dl.google.com/android/repository/commandlinetools-linux-${SDK_VERSION}.zip --output cmdline-tools.zip
RUN unzip cmdline-tools.zip
RUN mkdir -p /android-sdk/cmdline-tools
RUN mv cmdline-tools /android-sdk/cmdline-tools/latest
RUN rm cmdline-tools.zip

# Install Android SDK
WORKDIR /android-sdk/cmdline-tools/latest/bin
RUN update-alternatives --set java $(update-alternatives --list java | grep java-17)
RUN echo "y" | ./sdkmanager "build-tools;29.0.3" "platform-tools" "platforms;android-29" "tools" "ndk;16.1.4479499"

# Prepare for build
RUN update-alternatives --set java $(update-alternatives --list java | grep java-11)

# Reduce build time in futher builds
COPY android-mugen /android-mugen
WORKDIR /android-mugen
RUN mkdir ./app/src/main/assets/mugen/
RUN touch ./app/src/main/assets/mugen/mugen.exe
RUN touch ./app/src/main/assets/mugen/CWSDPMI.EXE
RUN ./gradlew build
RUN rm -R app/src/main/assets/mugen/
RUN rm app/build/outputs/apk/debug/app-debug.apk
RUN rm app/build/outputs/apk/release/app-release-unsigned.apk

# Remove icons
RUN rm /android-mugen/app/src/main/res/drawable-hdpi/icon.png
RUN rm /android-mugen/app/src/main/res/drawable-ldpi/icon.png
RUN rm /android-mugen/app/src/main/res/drawable-mdpi/icon.png
RUN rm /android-mugen/app/src/main/res/drawable-xhdpi/icon.png

# Volumes
RUN mkdir /android-mugen/app/src/main/assets/mugen/
RUN mkdir /output
VOLUME /android-mugen/app/src/main/assets/mugen/
VOLUME /game_certificate.key
VOLUME /icon.png
VOLUME /output

# Run build
WORKDIR /android-mugen
COPY run.sh /
CMD ["bash", "/run.sh"]
