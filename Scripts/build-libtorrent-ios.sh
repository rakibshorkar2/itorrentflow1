#!/bin/bash
# Build LibTorrent C++ library for iOS (arm64)
# Run this on macOS with Xcode installed

set -e

BUILD_DIR="$(dirname "$0")/../LibTorrentBuild"
mkdir -p "$BUILD_DIR"

# Minimum iOS version
IOS_MIN="16.0"

# Check for dependencies
if ! command -v cmake &> /dev/null; then
    echo "Error: cmake is required. Install with: brew install cmake"
    exit 1
fi

# Install Boost (required by LibTorrent)
if ! brew list boost &> /dev/null; then
    echo "Installing Boost..."
    brew install boost
fi

# Install OpenSSL
if ! brew list openssl &> /dev/null; then
    echo "Installing OpenSSL..."
    brew install openssl@3
fi

# Clone LibTorrent if not present
LIBTORRENT_DIR="$BUILD_DIR/libtorrent"
if [ ! -d "$LIBTORRENT_DIR" ]; then
    echo "Cloning LibTorrent..."
    git clone --depth 1 --branch v2.0.11 https://github.com/arvidn/libtorrent.git "$LIBTORRENT_DIR"
fi

# iOS toolchain file
TOOLCHAIN_FILE="$BUILD_DIR/ios-toolchain.cmake"
cat > "$TOOLCHAIN_FILE" << 'EOF'
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_OSX_SYSROOT iphoneos)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED NO)
set(CMAKE_Swift_LANGUAGE_VERSION 5)
EOF

BUILD_IOS_DIR="$BUILD_DIR/build-ios"
mkdir -p "$BUILD_IOS_DIR"
cd "$BUILD_IOS_DIR"

echo "Configuring LibTorrent for iOS..."
cmake "$LIBTORRENT_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/ios" \
    -DCMAKE_CXX_FLAGS="-stdlib=libc++ -miphoneos-version-min=$IOS_MIN" \
    -DCMAKE_C_FLAGS="-miphoneos-version-min=$IOS_MIN" \
    -DBUILD_SHARED_LIBS=OFF \
    -Dbuild_tests=OFF \
    -Dbuild_examples=OFF \
    -Dbuild_tools=OFF \
    -Ddeprecated_functions=OFF \
    -Dlogging=OFF

echo "Building LibTorrent for iOS..."
cmake --build . --config Release -j$(sysctl -n hw.ncpu)

echo "Installing LibTorrent for iOS..."
cmake --install .

echo ""
echo "LibTorrent iOS build complete!"
echo "Headers: $BUILD_DIR/ios/include"
echo "Library: $BUILD_DIR/ios/lib"
echo ""
echo "To use in Xcode:"
echo "1. Add $BUILD_DIR/ios/include to HEADER_SEARCH_PATHS"
echo "2. Add $BUILD_DIR/ios/lib/libtorrent-rasterbar.a to LIBRARY_SEARCH_PATHS"
echo "3. Set OTHER_LDFLAGS to -ltorrent-rasterbar"
echo "4. Add libc++.tbd, libssl.tbd, libcrypto.tbd to Link Binary With Libraries"
