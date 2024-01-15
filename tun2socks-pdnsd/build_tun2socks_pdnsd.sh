# Path for copying builded files
# We are choosing current directory($PWD)
OUT_DIR="$PWD/generated_binaries"
mkdir -p $OUT_DIR

# Working directory
WORKDIR="/tmp"

# Android.mk file
rm "$WORKDIR/Android.mk"
cp "$PWD/Android.mk" "$WORKDIR/Android.mk"

# Enter working directory
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

# Pull source code from github
cd $WORKDIR
libancillary_source_path="$WORKDIR/libancillary"
if [ ! -d "$libancillary_source_path" ]; then
    echo "Downloading libancillary"
    git clone --depth=1 https://github.com/shadowsocks/libancillary.git
fi

badvpn_source_path="$WORKDIR/badvpn"
if [ ! -d "$badvpn_source_path" ]; then
    echo "Downloading badvpn"
    git clone --depth=1 https://github.com/gokhantuffer/badvpn.git
fi

pdnsd_source_path="$WORKDIR/pdnsd"
if [ ! -d "$pdnsd_source_path" ]; then
    echo "Downloading pdnsd"
    git clone --depth=1 https://github.com/gokhantuffer/pdnsd.git
fi

# Prepare for build
# Create temporary directory
TMPDIR=$(mktemp -d)
echo "Temporary directory = $TMPDIR"

# Variables needed by ndk-bundle
ANDROID_MK="$WORKDIR/Android.mk"
ANDROID_ABI="all"
ANDROID_API="android-19"
NDK_LIBS_OUT="$TMPDIR/libs"
NDK_OUT="$TMPDIR/tmp"

# Start to build
echo "STARTING NDK BUILD..."
echo "------------------------------------------------"
cd $WORKDIR && $ANDROID_NDK_HOME/ndk-build \
    NDK_PROJECT_PATH=. \
    APP_BUILD_SCRIPT=$ANDROID_MK \
    APP_ABI=$ANDROID_ABI \
    APP_PLATFORM=$ANDROID_API \
    NDK_LIBS_OUT=$NDK_LIBS_OUT \
    NDK_OUT=$NDK_OUT \
    APP_SHORT_COMMANDS=false LOCAL_SHORT_COMMANDS=false -B -j4 >> $TMPDIR/ndk_tun2socks.log
echo "------------------------------------------------"
echo "NDK BUILD ENDED"

# See if we builded our files successfully
echo "------------------------------------------------"
# Folder size
du -sh $TMPDIR/libs
# You should see libtun2socks.so and pdsnd files
ls -sh $TMPDIR/libs/x86
echo "------------------------------------------------"

# Copy builded files to a permanent folder
cp -r $TMPDIR/libs $OUT_DIR

# Convert pdnsd to libpdnsd.so
cd $OUT_DIR/libs
for d in */ ; do
    # echo "$d"
    mv $d"pdnsd" $d"libpdnsd.so"
done

# Delete temp dir
rm -rf $TMPDIR

echo "You can find your generated files in: $OUT_DIR/libs"