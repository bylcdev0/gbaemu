cmake_minimum_required(VERSION 3.22.1)
project("gbaemu-native" LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Android NDK toolchain handles this
if(ANDROID)
    set(CMAKE_ANDROID_NDK_TOOLCHAIN_VERSION "clang")
endif()

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/mgba/include
)

# mGBA core source files (we'll add these)
# For now, create a JNI wrapper that interfaces with mGBA

# JNI Wrapper
add_library(gbaemu-jni SHARED
    src/main/cpp/jni_bridge.cpp
    src/main/cpp/mgba_wrapper.cpp
)

# Find log library
find_library(log-lib log)
find_library(android-lib android)
find_library(z-lib z)

target_link_libraries(gbaemu-jni
    ${log-lib}
    ${android-lib}
    ${z-lib}
    mgba-core
)

# mGBA core as static library (to be built separately or included)
add_library(mgba-core STATIC IMPORTED)
set_target_properties(mgba-core PROPERTIES
    IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libmgba.a
)

# If building mGBA from source, add_subdirectory(mgba)
# add_subdirectory(mgba)