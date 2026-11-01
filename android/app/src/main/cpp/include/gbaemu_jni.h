#ifndef GBAEMU_JNI_H
#define GBAEMU_JNI_H

#include <jni.h>
#include <cstdint>
#include <cstddef>

// Forward declarations for mGBA types
struct mCore;
struct mGBACoreConfig;
struct mGBAAudioBuffer;
struct mGBAVideoBuffer;
struct mGBASaveData;
struct mGBACheat;

// Emulator state
enum class EmulatorState : int32_t {
    UNINITIALIZED = 0,
    READY = 1,
    RUNNING = 2,
    PAUSED = 3,
    ERROR = -1
};

// Save types (matching mGBA)
enum class SaveType : int32_t {
    NONE = 0,
    SRAM = 1,
    EEPROM = 2,
    FLASH_64K = 3,
    FLASH_128K = 4,
    FLASH_512K = 5,
    FLASH_1M = 6
};

// Sensor types
enum class SensorType : int32_t {
    NONE = 0,
    GYRO = 1,
    SOLAR = 2,
    TILT = 3,
    RUMBLE = 4
};

// Video filter types
enum class VideoFilter : int32_t {
    NEAREST = 0,
    BILINEAR = 1,
    SCALE2X = 2,
    HQ2X = 3,
    XBR = 4
};

// Audio config
struct AudioConfig {
    int sample_rate = 44100;
    int buffer_size = 2048;
    bool enabled = true;
    float volume = 1.0f;
};

// Video config
struct VideoConfig {
    int width = 240;
    int height = 160;
    VideoFilter filter = VideoFilter::BILINEAR;
    bool vsync = true;
    int frameskip = 0;
};

// Emulator config
struct EmulatorConfig {
    AudioConfig audio;
    VideoConfig video;
    SaveType save_type = SaveType::AUTO_DETECT;
    bool rtc_enabled = true;
    bool mirroring = false;
    int cpu_cycles_per_frame = 0; // 0 = auto
    const char* bios_path = nullptr;
    const char* cheats_path = nullptr;
};

// Frame data returned to Java/Kotlin
struct FrameData {
    void* pixels;        // RGBA8888 or RGB565
    int width;
    int height;
    int stride;          // bytes per row
    int64_t timestamp_ns;
    bool frame_ready;
};

// Audio data returned to Java/Kotlin
struct AudioData {
    int16_t* samples;    // Stereo interleaved
    int sample_count;
    int sample_rate;
    int64_t timestamp_ns;
};

// Cheat code structure
struct CheatCode {
    uint32_t address;
    uint16_t value;
    uint16_t mask;       // For comparison cheats
    bool enabled;
    const char* description;
    int type;            // 0=Action Replay, 1=GameShark, 2=CodeBreaker
};

// RTC time structure
struct RTCTime {
    int year;
    int month;
    int day;
    int hour;
    int minute;
    int second;
    int day_of_week;
};

// Game info structure
struct GameInfo {
    char title[12];
    char game_code[4];
    char maker_code[2];
    uint8_t save_type;
    bool has_rtc;
    bool has_gyro;
    bool has_solar;
    bool has_rumble;
    uint32_t rom_size;
    uint32_t crc32;
};

// Callback function pointers for Java/Kotlin integration
typedef void (*FrameCallback)(JNIEnv*, jobject, const FrameData*);
typedef void (*AudioCallback)(JNIEnv*, jobject, const AudioData*);
typedef void (*SaveCallback)(JNIEnv*, jobject, const uint8_t*, size_t);
typedef void (*LogCallback)(JNIEnv*, jobject, int level, const char* message);
typedef void (*StateCallback)(JNIEnv*, jobject, int state, const char* message);

#ifdef __cplusplus
extern "C" {
#endif

// Core emulator functions
JNIEXPORT jlong JNICALL Java_com_gbaemu_core_GbaCore_nativeCreate(JNIEnv* env, jobject thiz);
JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeDestroy(JNIEnv* env, jobject thiz, jlong handle);

JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeLoadRom(JNIEnv* env, jobject thiz, jlong handle, jbyteArray rom_data, jint rom_size);
JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeLoadBios(JNIEnv* env, jobject thiz, jlong handle, jbyteArray bios_data, jint bios_size);
JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeUnloadRom(JNIEnv* env, jobject thiz, jlong handle);

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeReset(JNIEnv* env, jobject thiz, jlong handle);
JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativePause(JNIEnv* env, jobject thiz, jlong handle);
JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeResume(JNIEnv* env, jobject thiz, jlong handle);

JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeRunFrame(JNIEnv* env, jobject thiz, jlong handle);
JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeRunFrameAsync(JNIEnv* env, jobject thiz, jlong handle);

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeSetKeys(JNIEnv* env, jobject thiz, jlong handle, jint keys);
JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeSetSensorValue(JNIEnv* env, jobject thiz, jlong handle, jint sensor_type, jfloat x, jfloat y, jfloat z);

JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeSaveState(JNIEnv* env, jobject thiz, jlong handle, jbyteArray out_data);
JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeLoadState(JNIEnv* env, jobject thiz, jlong handle, jbyteArray state_data, jint size);
JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeSaveBattery(JNIEnv* env, jobject thiz, jlong handle, jbyteArray out_data);
JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeLoadBattery(JNIEnv* env, jobject thiz, jlong handle, jbyteArray battery_data, jint size);

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeAddCheat(JNIEnv* env, jobject thiz, jlong handle, jint address, jshort value, jshort mask, jboolean enabled, jstring desc, jint type);
JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeEnableCheat(JNIEnv* env, jobject thiz, jlong handle, jint index, jboolean enabled);
JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeClearCheats(JNIEnv* env, jobject thiz, jlong handle);
JNIEXPORT jobjectArray JNICALL Java_com_gbaemu_core_GbaCore_nativeGetCheats(JNIEnv* env, jobject thiz, jlong handle);

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeSetConfig(JNIEnv* env, jobject thiz, jlong handle, jobject config);
JNIEXPORT jobject JNICALL Java_com_gbaemu_core_GbaCore_nativeGetConfig(JNIEnv* env, jobject thiz, jlong handle);
JNIEXPORT jobject JNICALL Java_com_gbaemu_core_GbaCore_nativeGetGameInfo(JNIEnv* env, jobject thiz, jlong handle);
JNIEXPORT jobject JNICALL Java_com_gbaemu_core_GbaCore_nativeGetRTC(JNIEnv* env, jobject thiz, jlong handle);
JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeSetRTC(JNIEnv* env, jobject thiz, jlong handle, jobject rtc);

JNIEXPORT jint JNICALL Java_com_gbaemu_core_GbaCore_nativeGetState(JNIEnv* env, jobject thiz, jlong handle);
JNIEXPORT jint JNICALL Java_com_gbaemu_core_GbaCore_nativeGetFPS(JNIEnv* env, jobject thiz, jlong handle);
JNIEXPORT jlong JNICALL Java_com_gbaemu_core_GbaCore_nativeGetFrameCount(JNIEnv* env, jobject thiz, jlong handle);

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeSetCallbacks(JNIEnv* env, jobject thiz, jlong handle,
    jobject frame_callback, jobject audio_callback, jobject save_callback, jobject log_callback, jobject state_callback);

JNIEXPORT jstring JNICALL Java_com_gbaemu_core_GbaCore_nativeGetError(JNIEnv* env, jobject thiz, jlong handle);
JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeClearError(JNIEnv* env, jobject thiz, jlong handle);

// Link cable / multiplayer support
JNIEXPORT jlong JNICALL Java_com_gbaemu_core_GbaLink_nativeCreate(JNIEnv* env, jobject thiz);
JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaLink_nativeDestroy(JNIEnv* env, jobject thiz, jlong handle);
JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaLink_nativeConnect(JNIEnv* env, jobject thiz, jlong handle, jlong core_handle);
JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaLink_nativeDisconnect(JNIEnv* env, jobject thiz, jlong handle);
JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaLink_nativeSendData(JNIEnv* env, jobject thiz, jlong handle, jbyteArray data, jint size);
JNIEXPORT jint JNICALL Java_com_gbaemu_core_GbaLink_nativeReceiveData(JNIEnv* env, jobject thiz, jlong handle, jbyteArray out_data, jint max_size);
JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaLink_nativeIsConnected(JNIEnv* env, jobject thiz, jlong handle);

#ifdef __cplusplus
}
#endif

#endif // GBAEMU_JNI_H