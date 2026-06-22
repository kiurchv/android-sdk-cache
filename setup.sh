#!/usr/bin/env bash
set -euo pipefail

REPO="kiurchv/android-sdk-cache"
BASE_URL="https://codeload.github.com/${REPO}/tar.gz/refs/heads/main"
ANDROID_SDK_DIR="${ANDROID_SDK_DIR:-$HOME/android-sdk}"
GRADLE_HOME="${GRADLE_HOME:-$HOME/.gradle}"
GRADLE_VERSION="8.14.5"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[setup]${NC} $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $*"; }
section() { echo -e "\n${GREEN}=== $* ===${NC}"; }

section "Downloading all assets (~750MB)"
ARCHIVE=/tmp/android-sdk-cache-$$.tar.gz
curl -L --progress-bar "$BASE_URL" -o "$ARCHIVE"
EXTRACT_DIR=/tmp/sdk-cache-$$
mkdir -p "$EXTRACT_DIR"
tar -xzf "$ARCHIVE" -C "$EXTRACT_DIR"
CACHE_PATH="$EXTRACT_DIR/$(ls $EXTRACT_DIR)"
info "Downloaded: $(ls $CACHE_PATH)"

section "Android SDK"
mkdir -p "$ANDROID_SDK_DIR/build-tools" "$ANDROID_SDK_DIR/platforms"

BT=$(ls "$CACHE_PATH"/build-tools-*.tar.gz 2>/dev/null | head -1)
if [ -n "$BT" ]; then
  BT_VER=$(basename "$BT" | sed 's/build-tools-\(.*\)\.tar\.gz/\1/')
  [ -d "$ANDROID_SDK_DIR/build-tools/$BT_VER" ] && warn "build-tools $BT_VER already installed" || \
    { info "Installing build-tools $BT_VER"; tar -xzf "$BT" -C "$ANDROID_SDK_DIR/build-tools/"; }
fi

PLAT=$(ls "$CACHE_PATH"/platform-android-*.tar.gz 2>/dev/null | head -1)
if [ -n "$PLAT" ]; then
  PLAT_NAME=$(basename "$PLAT" | sed 's/platform-\(.*\)\.tar\.gz/\1/')
  [ -d "$ANDROID_SDK_DIR/platforms/$PLAT_NAME" ] && warn "platform $PLAT_NAME already installed" || \
    { info "Installing platform $PLAT_NAME"; tar -xzf "$PLAT" -C "$ANDROID_SDK_DIR/platforms/"; }
fi

mkdir -p "$ANDROID_SDK_DIR/licenses"
printf "24333f8a63b6825ea9c5514f83c2829b004d1fee\n84831b9409646a918e30573bab4c9c91346d8abd" \
  > "$ANDROID_SDK_DIR/licenses/android-sdk-license"

# Cull requires build-tools 35.0.0 — patch 37.0.0 metadata
if [ -d "$ANDROID_SDK_DIR/build-tools/37.0.0" ] && [ ! -d "$ANDROID_SDK_DIR/build-tools/35.0.0" ]; then
  info "Patching build-tools 37.0.0 \u2192 35.0.0"
  cp -r "$ANDROID_SDK_DIR/build-tools/37.0.0" "$ANDROID_SDK_DIR/build-tools/35.0.0"
  sed -i "s/Pkg.Revision=.*/Pkg.Revision=35.0.0/" "$ANDROID_SDK_DIR/build-tools/35.0.0/source.properties"
  sed -i "s|<major>37</major>|<major>35</major>|g" "$ANDROID_SDK_DIR/build-tools/35.0.0/package.xml"
  sed -i 's|path="build-tools;37.0.0"|path="build-tools;35.0.0"|g' "$ANDROID_SDK_DIR/build-tools/35.0.0/package.xml"
  sed -i "s|Build-Tools 37|Build-Tools 35|g" "$ANDROID_SDK_DIR/build-tools/35.0.0/package.xml"
fi

section "Gradle $GRADLE_VERSION"
KNOWN_HASH="91wvqqe4qmsefb2bitamjj9bp"
GRADLE_INSTALL="$GRADLE_HOME/wrapper/dists/gradle-${GRADLE_VERSION}-bin/$KNOWN_HASH"
if [ -f "$GRADLE_INSTALL/gradle-${GRADLE_VERSION}/bin/gradle" ]; then
  warn "Gradle $GRADLE_VERSION already in wrapper cache"
else
  PARTS=$(ls "$CACHE_PATH"/gradle-${GRADLE_VERSION}-bin.zip.part* 2>/dev/null | sort)
  if [ -n "$PARTS" ]; then
    GRADLE_ZIP=/tmp/gradle-${GRADLE_VERSION}-bin.zip
    info "Reassembling Gradle zip"
    cat $PARTS > "$GRADLE_ZIP"
    mkdir -p "$GRADLE_INSTALL"
    cp "$GRADLE_ZIP" "$GRADLE_INSTALL/"
    unzip -q "$GRADLE_ZIP" -d "$GRADLE_INSTALL/"
    touch "$GRADLE_INSTALL/gradle-${GRADLE_VERSION}-bin.zip.lck"
    info "Gradle OK"
  else
    warn "No Gradle parts found"
  fi
fi

section "Maven dependency cache"
DEPS_PARTS=$(ls "$CACHE_PATH"/deps-cache.tar.gz.part* 2>/dev/null | sort)
if [ -z "$DEPS_PARTS" ]; then
  warn "No dependency cache found — first build will download from internet"
else
  if [ -d "$GRADLE_HOME/caches/modules-2/files-2.1/com.google.dagger" ]; then
    warn "Dependency cache already installed"
  else
    DEPS_TAR=/tmp/deps-cache-$$.tar.gz
    info "Reassembling deps cache ($(ls $CACHE_PATH/deps-cache.tar.gz.part* | wc -l) parts)"
    cat $DEPS_PARTS > "$DEPS_TAR"
    mkdir -p "$GRADLE_HOME/caches"
    info "Extracting $(du -sh $DEPS_TAR | cut -f1) to ~/.gradle/caches/"
    tar -xzf "$DEPS_TAR" -C "$GRADLE_HOME/caches/"
    info "Dependency cache installed"
    rm "$DEPS_TAR"
  fi
fi

section "Writing local.properties"
for candidate in "$(pwd)" "$HOME/cull" "/home/claude/cull" "$(dirname $0)/../Cull"; do
  if [ -f "$candidate/app/build.gradle.kts" ]; then
    echo "sdk.dir=$ANDROID_SDK_DIR" > "$candidate/local.properties"
    info "Written $candidate/local.properties"
    break
  fi
done

section "Done!"
echo ""
echo "  export ANDROID_SDK_ROOT=$ANDROID_SDK_DIR"
echo "  export JAVA_HOME=\$(dirname \$(dirname \$(readlink -f \$(which java))))"
echo ""
echo "  cd /path/to/Cull && ./build-local.sh"
echo ""
rm -rf "$EXTRACT_DIR" "$ARCHIVE"
