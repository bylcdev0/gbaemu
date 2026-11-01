#!/bin/bash
# Build script for mGBA core for Android and iOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MGBA_DIR="$PROJECT_ROOT/mgba"
BUILD_DIR="$PROJECT_ROOT/build"

# Android NDK path (adjust as needed)
ANDROID_NDK="${ANDROID_NDK_HOME:-$HOME/Library/Android/sdk/ndk/26.1.10909125}"

# iOS SDK
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || echo "")

# Build configurations
ANDROID_ABIS=("arm64-v8a" "armeabi-v7a")
IOS_ARCHS=("arm64" "x86_64")  # arm64 for device, x86_64 for simulator

echo "========================================="
echo "mGBA Build Script for GbaEmu"
echo "========================================="
echo "Project root: $PROJECT_ROOT"
echo "mGBA source: $MGBA_DIR"
echo "Build dir: $BUILD_DIR"
echo "Android NDK: $ANDROID_NDK"
echo "iOS SDK: $IOS_SDK"
echo ""

# Clone mGBA if not present
if [ ! -d "$MGBA_DIR" ]; then
    echo "Cloning mGBA repository..."
    git clone --depth 1 --branch master https://github.com/mgba-emu/mgba.git "$MGBA_DIR"
fi

cd "$MGBA_DIR"

# Initialize submodules
echo "Initializing submodules..."
git submodule update --init --recursive

# Function to build for Android
build_android() {
    local abi=$1
    local api_level=24

    echo "Building for Android $abi (API $api_level)..."

    local build_dir="$BUILD_DIR/android/$abi"
    mkdir -p "$build_dir"
    cd "$build_dir"

    cmake "$MGBA_DIR" \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI="$abi" \
        -DANDROID_PLATFORM="android-$api_level" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DENABLE_FFMPEG=OFF \
        -DENABLE_QT=OFF \
        -DENABLE_SDL=OFF \
        -DENABLE_OPENGL=OFF \
        -DENABLE_LINK=ON \
        -DENABLE_DEBUGGER=OFF \
        -DENABLE_TESTS=OFF

    cmake --build . --config Release -- -j$(nproc)

    # Copy static library
    local lib_name="libmgba.a"
    if [ -f "$lib_name" ]; then
        cp "$lib_name" "$PROJECT_ROOT/GbaEmu/android/app/src/main/jniLibs/$abi/"
        echo "Copied $lib_name to Android jniLibs/$abi/"
    fi
}

# Function to build for iOS
build_ios() {
    local arch=$1
    local sdk=$2
    local min_version="13.0"

    echo "Building for iOS $arch (SDK: $sdk)..."

    local build_dir="$BUILD_DIR/ios/$arch"
    mkdir -p "$build_dir"
    cd "$build_dir"

    local cmake_args=(
        -DCMAKE_TOOLCHAIN_FILE="$MGBA_DIR/cmake/ios.toolchain.cmake"
        -DIOS_PLATFORM=OS
        -DIOS_ARCH="$arch"
        -DCMAKE_IOS_DEPLOYMENT_TARGET="$min_version"
        -DCMAKE_BUILD_TYPE=Release
        -DBUILD_SHARED_LIBS=OFF
        -DENABLE_FFMPEG=OFF
        -DENABLE_QT=OFF
        -DENABLE_SDL=OFF
        -DENABLE_OPENGL=OFF
        -DENABLE_LINK=ON
        -DENABLE_DEBUGGER=OFF
        -DENABLE_TESTS=OFF
    )

    if [ "$arch" = "x86_64" ]; then
        cmake_args+=(-DIOS_PLATFORM=SIMULATOR)
    fi

    cmake "$MGBA_DIR" "${cmake_args[@]}"
    cmake --build . --config Release -- -j$(sysctl -n hw.ncpu)

    # Copy static library
    local lib_name="libmgba.a"
    if [ -f "$lib_name" ]; then
        cp "$lib_name" "$PROJECT_ROOT/GbaEmu/ios/libs/$arch/"
        echo "Copied $lib_name to iOS libs/$arch/"
    fi
}

# Function to create universal iOS library
create_universal_ios() {
    echo "Creating universal iOS library..."

    local lib_dir="$PROJECT_ROOT/GbaEmu/ios/libs"
    mkdir -p "$lib_dir/universal"

    lipo -create \
        "$lib_dir/arm64/libmgba.a" \
        "$lib_dir/x86_64/libmgba.a" \
        -output "$lib_dir/universal/libmgba.a"

    echo "Created universal library at $lib_dir/universal/libmgba.a"
}

# Main build
mkdir -p "$BUILD_DIR"
mkdir -p "$PROJECT_ROOT/GbaEmu/android/app/src/main/jniLibs/arm64-v8a"
mkdir -p "$PROJECT_ROOT/GbaEmu/android/app/src/main/jniLibs/armeabi-v7a"
mkdir -p "$PROJECT_ROOT/GbaEmu/ios/libs/arm64"
mkdir -p "$PROJECT_ROOT/GbaEmu/ios/libs/x86_64"
mkdir -p "$PROJECT_ROOT/GbaEmu/ios/libs/universal"

# Build Android
echo ""
echo "=== Building Android ==="
for abi in "${ANDROID_ABIS[@]}"; do
    build_android "$abi"
done

# Build iOS (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]] && [ -n "$IOS_SDK" ]; then
    echo ""
    echo "=== Building iOS ==="
    for arch in "${IOS_ARCHS[@]}"; do
        build_ios "$arch" "$IOS_SDK"
    done
    create_universal_ios
else
    echo ""
    echo "Skipping iOS build (not on macOS or Xcode not found)"
fi

echo ""
echo "========================================="
echo "Build complete!"
echo "========================================="
echo "Android libs: $PROJECT_ROOT/GbaEmu/android/app/src/main/jniLibs/"
echo "iOS libs: $PROJECT_ROOT/GbaEmu/ios/libs/"