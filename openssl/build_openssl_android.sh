# Path for copying builded files
# We are choosing current directory($PWD)
OUT_DIR="$PWD/generated_binaries"
mkdir -p $OUT_DIR

# Working directory
WORKDIR="/tmp"
cd $WORKDIR

# Where to place SDK
ANDROID_SDK_ROOT="/usr/lib/android-sdk"
mkdir -p $ANDROID_SDK_ROOT

# Download cmdline-tools
if [ ! -d "$ANDROID_SDK_ROOT/cmdline-tools/tools/" ]; then
    echo "Downloading Android SDK"
    cmdline_tools_url="https://dl.google.com/android/repository/commandlinetools-linux-6858069_latest.zip"
    cmdline_tools_zip="/tmp/commandlinetools-linux-6858069_latest.zip"

    wget -O $cmdline_tools_zip -q $cmdline_tools_url
    python3 -m zipfile -e $cmdline_tools_zip ./
    rm -rf $cmdline_tools_zip

    # Move cmdline-tools to $ANDROID_SDK_ROOT
    mkdir $ANDROID_SDK_ROOT/cmdline-tools
    mv cmdline-tools $ANDROID_SDK_ROOT/cmdline-tools/tools/

    # browse to sdkmanager make it executable and accept licences
    cd $ANDROID_SDK_ROOT/cmdline-tools/tools/bin &&\
    chmod +x sdkmanager &&\
    yes | ./sdkmanager --licenses
fi

# Set SDK's path in environment
export ANDROID_HOME=$ANDROID_SDK_ROOT

# Download NDK
if [ ! -d "$ANDROID_SDK_ROOT/ndk-bundle" ]; then
    echo "Downloading Android NDK"
    $ANDROID_HOME/cmdline-tools/tools/bin/sdkmanager "ndk-bundle"
fi
export ANDROID_NDK_HOME=$ANDROID_SDK_ROOT/ndk-bundle

# Add NDK to PATH
export PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"

# Download openssl source code
cd $WORKDIR
openssl_source_path="$WORKDIR/openssl-1.1.1w"
if [ ! -d "$openssl_source_path" ]; then
    echo "Downloading openssl"
    openssl_url="https://www.openssl.org/source/openssl-1.1.1w.tar.gz"
    openssl_tar="openssl-1.1.1w.tar.gz"

    wget -O $openssl_tar $openssl_url
    tar -xf $openssl_tar
    rm -rf $openssl_tar
fi

# Prepare for build
cd $openssl_source_path

# Android min api
export ANDROID_API=23

build_so() {
    echo "----------------------------\n\n"
    # Variables
    SSL_TARGET=$1
    ANDROID_ABI=$2

    # Clean build
    make clean
    # Build
    ./Configure $SSL_TARGET -fPIC -D__ANDROID_API__=$ANDROID_API &&\
    make SHLIB_VERSION_NUMBER="" SHLIB_EXT=.so
    # make SHLIB_VERSION_NUMBER="" SHLIB_EXT=.so install_sw DESTDIR="$BUILD_DIR/$ANDROID_ABI"

    # Copy generated ".so" files to output directory
    echo "Copying generated .so files of $ANDROID_ABI to output directory"
    mkdir -p $OUT_DIR/$ANDROID_ABI
    cp -r $openssl_source_path/*.so $OUT_DIR/$ANDROID_ABI
}

build_armeabiv7a() {
    # arm-linux-androideabi
    ANDROID_ABI="armeabi-v7a"
    SSL_TARGET="android-arm"
    build_so $SSL_TARGET $ANDROID_ABI
}

build_arm64() {
    # aarch64-linux-android
    echo "----------------------------\n\n"
    ANDROID_ABI="arm64-v8a"
    SSL_TARGET="android-arm64"
    build_so $SSL_TARGET $ANDROID_ABI
}

build_x86() {
    # i686-linux-android
    echo "----------------------------\n\n"
    ANDROID_ABI="x86"
    SSL_TARGET="android-x86"
    build_so $SSL_TARGET $ANDROID_ABI
}

build_x86_64() {
    # x86_64-linux-android
    echo "----------------------------\n\n"
    ANDROID_ABI="x86_64"
    SSL_TARGET="android-x86_64"
    build_so $SSL_TARGET $ANDROID_ABI
}

build_all() {
    echo "Build all"
    build_armeabiv7a
    build_arm64
    build_x86
    build_x86_64
    echo "All builds finished"
}

build_all

echo "You can find your generated files in: $OUT_DIR"