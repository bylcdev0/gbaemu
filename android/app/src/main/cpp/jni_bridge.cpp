#include "gbaemu_jni.h"
#include <jni.h>
#include <string>
#include <vector>
#include <mutex>
#include <memory>
#include <cstring>
#include <cstdio>

// mGBA C API includes (these would come from mGBA source)
// For now, we define the minimal interface we need
extern "C" {
    // mGBA core types (opaque pointers)
    typedef struct mCore mCore;
    typedef struct mGBACoreConfig mGBACoreConfig;
    typedef struct mGBAAudioBuffer mGBAAudioBuffer;
    typedef struct mGBAVideoBuffer mGBAVideoBuffer;
    
    // Core lifecycle
    mCore* mCoreCreate(void);
    void mCoreDestroy(mCore* core);
    
    // ROM loading
    bool mCoreLoadROM(mCore* core, const uint8_t* data, size_t size);
    bool mCoreLoadBIOS(mCore* core, const uint8_t* data, size_t size);
    void mCoreUnloadROM(mCore* core);
    
    // Execution
    void mCoreReset(mCore* core);
    void mCoreRunFrame(mCore* core);
    
    // Input
    void mCoreSetInput(mCore* core, uint32_t keys);
    void mCoreSetSensor(mCore* core, int type, float x, float y, float z);
    
    // Audio/Video
    const mGBAVideoBuffer* mCoreGetVideoBuffer(mCore* core);
    const mGBAAudioBuffer* mCoreGetAudioBuffer(mCore* core);
    void mCoreSetAudioConfig(mCore* core, int sample_rate, int buffer_size);
    void mCoreSetVideoConfig(mCore* core, int width, int height, int filter);
    
    // Save states
    size_t mCoreSaveStateSize(mCore* core);
    bool mCoreSaveState(mCore* core, uint8_t* data, size_t size);
    bool mCoreLoadState(mCore* core, const uint8_t* data, size_t size);
    
    // Battery saves
    size_t mCoreSaveBatterySize(mCore* core);
    bool mCoreSaveBattery(mCore* core, uint8_t* data, size_t size);
    bool mCoreLoadBattery(mCore* core, const uint8_t* data, size_t size);
    
    // Cheats
    void mCoreAddCheat(mCore* core, uint32_t addr, uint16_t val, uint16_t mask, bool enable, const char* desc, int type);
    void mCoreEnableCheat(mCore* core, int index, bool enable);
    void mCoreClearCheats(mCore* core);
    int mCoreGetCheatCount(mCore* core);
    void mCoreGetCheatInfo(mCore* core, int index, uint32_t* addr, uint16_t* val, uint16_t* mask, bool* enable, char* desc, int* type);
    
    // Config
    void mCoreSetConfig(mCore* core, const mGBACoreConfig* config);
    const mGBACoreConfig* mCoreGetConfig(mCore* core);
    
    // Game info
    bool mCoreGetGameInfo(mCore* core, char* title, char* game_code, char* maker_code, 
                          uint8_t* save_type, bool* has_rtc, bool* has_gyro, bool* has_solar, bool* has_rumble,
                          uint32_t* rom_size, uint32_t* crc32);
    
    // RTC
    void mCoreGetRTC(mCore* core, int* year, int* month, int* day, int* hour, int* minute, int* second, int* dow);
    void mCoreSetRTC(mCore* core, int year, int month, int day, int hour, int minute, int second, int dow);
    
    // Status
    int mCoreGetState(mCore* core);
    int mCoreGetFPS(mCore* core);
    uint64_t mCoreGetFrameCount(mCore* core);
    const char* mCoreGetError(mCore* core);
    void mCoreClearError(mCore* core);
}

// Global JVM reference for callbacks
static JavaVM* g_jvm = nullptr;
static std::mutex g_jvm_mutex;

// Callback storage
struct CallbackData {
    jobject frame_callback = nullptr;
    jobject audio_callback = nullptr;
    jobject save_callback = nullptr;
    jobject log_callback = nullptr;
    jobject state_callback = nullptr;
    jmethodID frame_method = nullptr;
    jmethodID audio_method = nullptr;
    jmethodID save_method = nullptr;
    jmethodID log_method = nullptr;
    jmethodID state_method = nullptr;
};

// Emulator context
struct EmulatorContext {
    mCore* core = nullptr;
    EmulatorConfig config;
    CallbackData callbacks;
    std::mutex mutex;
    std::string last_error;
    bool initialized = false;
    
    // Frame buffer for video output
    std::vector<uint32_t> frame_buffer;
    std::vector<int16_t> audio_buffer;
    
    EmulatorContext() {
        frame_buffer.resize(240 * 160);
        audio_buffer.resize(4096); // stereo
    }
    
    ~EmulatorContext() {
        if (core) {
            mCoreDestroy(core);
            core = nullptr;
        }
    }
};

// Link cable context
struct LinkContext {
    mCore* core = nullptr;
    bool connected = false;
    std::mutex mutex;
    std::vector<uint8_t> tx_buffer;
    std::vector<uint8_t> rx_buffer;
};

// JNI helper functions
static JNIEnv* getJNIEnv() {
    JNIEnv* env = nullptr;
    if (g_jvm) {
        jint res = g_jvm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
        if (res == JNI_EDETACHED) {
            res = g_jvm->AttachCurrentThread(&env, nullptr);
        }
        if (res != JNI_OK) return nullptr;
    }
    return env;
}

static void releaseJNIEnv() {
    if (g_jvm) {
        g_jvm->DetachCurrentThread();
    }
}

static void throwJavaException(JNIEnv* env, const char* class_name, const char* message) {
    jclass cls = env->FindClass(class_name);
    if (cls) {
        env->ThrowNew(cls, message);
    }
}

static void setError(EmulatorContext* ctx, const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    char buffer[1024];
    vsnprintf(buffer, sizeof(buffer), fmt, args);
    va_end(args);
    ctx->last_error = buffer;
    
    // Call log callback if set
    JNIEnv* env = getJNIEnv();
    if (env && ctx->callbacks.log_callback && ctx->callbacks.log_method) {
        jstring msg = env->NewStringUTF(buffer);
        env->CallVoidMethod(ctx->callbacks.log_callback, ctx->callbacks.log_method, 1, msg);
        env->DeleteLocalRef(msg);
    }
    releaseJNIEnv();
}

// Callback invocation helpers
static void invokeFrameCallback(EmulatorContext* ctx, const FrameData* frame) {
    JNIEnv* env = getJNIEnv();
    if (env && ctx->callbacks.frame_callback && ctx->callbacks.frame_method) {
        // Create direct byte buffer for pixels
        jobject buffer = env->NewDirectByteBuffer(frame->pixels, frame->width * frame->height * 4);
        env->CallVoidMethod(ctx->callbacks.frame_callback, ctx->callbacks.frame_method, 
                           buffer, frame->width, frame->height, frame->stride, frame->timestamp_ns);
        env->DeleteLocalRef(buffer);
    }
    releaseJNIEnv();
}

static void invokeAudioCallback(EmulatorContext* ctx, const AudioData* audio) {
    JNIEnv* env = getJNIEnv();
    if (env && ctx->callbacks.audio_callback && ctx->callbacks.audio_method) {
        jshortArray array = env->NewShortArray(audio->sample_count);
        env->SetShortArrayRegion(array, 0, audio->sample_count, reinterpret_cast<const jshort*>(audio->samples));
        env->CallVoidMethod(ctx->callbacks.audio_callback, ctx->callbacks.audio_method,
                           array, audio->sample_rate, audio->timestamp_ns);
        env->DeleteLocalRef(array);
    }
    releaseJNIEnv();
}

static void invokeSaveCallback(EmulatorContext* ctx, const uint8_t* data, size_t size) {
    JNIEnv* env = getJNIEnv();
    if (env && ctx->callbacks.save_callback && ctx->callbacks.save_method) {
        jbyteArray array = env->NewByteArray(size);
        env->SetByteArrayRegion(array, 0, size, reinterpret_cast<const jbyte*>(data));
        env->CallVoidMethod(ctx->callbacks.save_callback, ctx->callbacks.save_method, array);
        env->DeleteLocalRef(array);
    }
    releaseJNIEnv();
}

static void invokeStateCallback(EmulatorContext* ctx, int state, const char* message) {
    JNIEnv* env = getJNIEnv();
    if (env && ctx->callbacks.state_callback && ctx->callbacks.state_method) {
        jstring msg = env->NewStringUTF(message);
        env->CallVoidMethod(ctx->callbacks.state_callback, ctx->callbacks.state_method, state, msg);
        env->DeleteLocalRef(msg);
    }
    releaseJNIEnv();
}

// JNI_OnLoad - cache JVM
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
    g_jvm = vm;
    JNIEnv* env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
        return JNI_ERR;
    }
    return JNI_VERSION_1_6;
}

JNIEXPORT void JNICALL JNI_OnUnload(JavaVM* vm, void* reserved) {
    g_jvm = nullptr;
}

// JNI Implementation

JNIEXPORT jlong JNICALL Java_com_gbaemu_core_GbaCore_nativeCreate(JNIEnv* env, jobject thiz) {
    auto* ctx = new EmulatorContext();
    ctx->core = mCoreCreate();
    if (!ctx->core) {
        delete ctx;
        return 0;
    }
    ctx->initialized = true;
    return reinterpret_cast<jlong>(ctx);
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeDestroy(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (ctx) {
        // Clear global refs
        if (ctx->callbacks.frame_callback) env->DeleteGlobalRef(ctx->callbacks.frame_callback);
        if (ctx->callbacks.audio_callback) env->DeleteGlobalRef(ctx->callbacks.audio_callback);
        if (ctx->callbacks.save_callback) env->DeleteGlobalRef(ctx->callbacks.save_callback);
        if (ctx->callbacks.log_callback) env->DeleteGlobalRef(ctx->callbacks.log_callback);
        if (ctx->callbacks.state_callback) env->DeleteGlobalRef(ctx->callbacks.state_callback);
        delete ctx;
    }
}

JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeLoadRom(JNIEnv* env, jobject thiz, jlong handle, jbyteArray rom_data, jint rom_size) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core || !rom_data) return JNI_FALSE;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    
    jbyte* data = env->GetByteArrayElements(rom_data, nullptr);
    bool result = mCoreLoadROM(ctx->core, reinterpret_cast<const uint8_t*>(data), rom_size);
    env->ReleaseByteArrayElements(rom_data, data, JNI_ABORT);
    
    if (!result) {
        setError(ctx, "Failed to load ROM: %s", mCoreGetError(ctx->core));
    }
    return result ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeLoadBios(JNIEnv* env, jobject thiz, jlong handle, jbyteArray bios_data, jint bios_size) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core || !bios_data) return JNI_FALSE;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    
    jbyte* data = env->GetByteArrayElements(bios_data, nullptr);
    bool result = mCoreLoadBIOS(ctx->core, reinterpret_cast<const uint8_t*>(data), bios_size);
    env->ReleaseByteArrayElements(bios_data, data, JNI_ABORT);
    
    return result ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeUnloadRom(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    mCoreUnloadROM(ctx->core);
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeReset(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    mCoreReset(ctx->core);
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativePause(JNIEnv* env, jobject thiz, jlong handle) {
    // mGBA doesn't have explicit pause, but we can track state
    invokeStateCallback(reinterpret_cast<EmulatorContext*>(handle), 3, "Paused");
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeResume(JNIEnv* env, jobject thiz, jlong handle) {
    invokeStateCallback(reinterpret_cast<EmulatorContext*>(handle), 2, "Resumed");
}

JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeRunFrame(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return JNI_FALSE;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    mCoreRunFrame(ctx->core);
    
    // Get video frame
    const mGBAVideoBuffer* vb = mCoreGetVideoBuffer(ctx->core);
    if (vb && vb->data) {
        // Convert to RGBA8888
        const uint16_t* src = static_cast<const uint16_t*>(vb->data);
        uint32_t* dst = ctx->frame_buffer.data();
        for (int i = 0; i < 240 * 160; i++) {
            uint16_t pixel = src[i];
            uint8_t r = (pixel >> 0) & 0x1F;
            uint8_t g = (pixel >> 5) & 0x1F;
            uint8_t b = (pixel >> 10) & 0x1F;
            dst[i] = (0xFF << 24) | (r << 19) | (g << 11) | (b << 3);
        }
        
        FrameData frame = {
            ctx->frame_buffer.data(),
            240, 160,
            240 * 4,
            0, // timestamp
            true
        };
        invokeFrameCallback(ctx, &frame);
    }
    
    // Get audio
    const mGBAAudioBuffer* ab = mCoreGetAudioBuffer(ctx->core);
    if (ab && ab->data && ab->size > 0) {
        int samples = std::min(ab->size / 2, static_cast<size_t>(ctx->audio_buffer.size()));
        memcpy(ctx->audio_buffer.data(), ab->data, samples * 2);
        
        AudioData audio = {
            ctx->audio_buffer.data(),
            samples,
            ctx->config.audio.sample_rate,
            0
        };
        invokeAudioCallback(ctx, &audio);
    }
    
    return JNI_TRUE;
}

JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeRunFrameAsync(JNIEnv* env, jobject thiz, jlong handle) {
    // For async, we'd use a thread pool. For now, just call sync version.
    return Java_com_gbaemu_core_GbaCore_nativeRunFrame(env, thiz, handle);
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeSetKeys(JNIEnv* env, jobject thiz, jlong handle, jint keys) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    mCoreSetInput(ctx->core, static_cast<uint32_t>(keys));
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeSetSensorValue(JNIEnv* env, jobject thiz, jlong handle, jint sensor_type, jfloat x, jfloat y, jfloat z) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    mCoreSetSensor(ctx->core, static_cast<int>(sensor_type), x, y, z);
}

JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeSaveState(JNIEnv* env, jobject thiz, jlong handle, jbyteArray out_data) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core || !out_data) return JNI_FALSE;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    size_t size = mCoreSaveStateSize(ctx->core);
    
    jbyte* data = env->GetByteArrayElements(out_data, nullptr);
    bool result = mCoreSaveState(ctx->core, reinterpret_cast<uint8_t*>(data), size);
    env->ReleaseByteArrayElements(out_data, data, 0);
    
    return result ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeLoadState(JNIEnv* env, jobject thiz, jlong handle, jbyteArray state_data, jint size) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core || !state_data) return JNI_FALSE;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    
    jbyte* data = env->GetByteArrayElements(state_data, nullptr);
    bool result = mCoreLoadState(ctx->core, reinterpret_cast<const uint8_t*>(data), size);
    env->ReleaseByteArrayElements(state_data, data, JNI_ABORT);
    
    return result ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeSaveBattery(JNIEnv* env, jobject thiz, jlong handle, jbyteArray out_data) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core || !out_data) return JNI_FALSE;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    size_t size = mCoreSaveBatterySize(ctx->core);
    
    jbyte* data = env->GetByteArrayElements(out_data, nullptr);
    bool result = mCoreSaveBattery(ctx->core, reinterpret_cast<uint8_t*>(data), size);
    env->ReleaseByteArrayElements(out_data, data, 0);
    
    return result ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaCore_nativeLoadBattery(JNIEnv* env, jobject thiz, jlong handle, jbyteArray battery_data, jint size) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core || !battery_data) return JNI_FALSE;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    
    jbyte* data = env->GetByteArrayElements(battery_data, nullptr);
    bool result = mCoreLoadBattery(ctx->core, reinterpret_cast<const uint8_t*>(data), size);
    env->ReleaseByteArrayElements(battery_data, data, JNI_ABORT);
    
    return result ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeAddCheat(JNIEnv* env, jobject thiz, jlong handle, jint address, jshort value, jshort mask, jboolean enabled, jstring desc, jint type) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    
    const char* desc_str = desc ? env->GetStringUTFChars(desc, nullptr) : "";
    mCoreAddCheat(ctx->core, static_cast<uint32_t>(address), static_cast<uint16_t>(value),
                  static_cast<uint16_t>(mask), enabled, desc_str, static_cast<int>(type));
    if (desc) env->ReleaseStringUTFChars(desc, desc_str);
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeEnableCheat(JNIEnv* env, jobject thiz, jlong handle, jint index, jboolean enabled) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    mCoreEnableCheat(ctx->core, static_cast<int>(index), enabled);
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeClearCheats(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    mCoreClearCheats(ctx->core);
}

JNIEXPORT jobjectArray JNICALL Java_com_gbaemu_core_GbaCore_nativeGetCheats(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return nullptr;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    int count = mCoreGetCheatCount(ctx->core);
    
    jclass cheat_class = env->FindClass("com/gbaemu/core/CheatCode");
    if (!cheat_class) return nullptr;
    
    jmethodID ctor = env->GetMethodID(cheat_class, "<init>", "(ISSZLjava/lang/String;I)V");
    if (!ctor) return nullptr;
    
    jobjectArray array = env->NewObjectArray(count, cheat_class, nullptr);
    
    for (int i = 0; i < count; i++) {
        uint32_t addr; uint16_t val, mask; bool enable; char desc[256]; int type;
        mCoreGetCheatInfo(ctx->core, i, &addr, &val, &mask, &enable, desc, &type);
        
        jstring desc_str = env->NewStringUTF(desc);
        jobject cheat = env->NewObject(cheat_class, ctor, static_cast<jint>(addr), 
                                       static_cast<jshort>(val), static_cast<jshort>(mask),
                                       enable, desc_str, type);
        env->SetObjectArrayElement(array, i, cheat);
        env->DeleteLocalRef(desc_str);
        env->DeleteLocalRef(cheat);
    }
    
    return array;
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeSetConfig(JNIEnv* env, jobject thiz, jlong handle, jobject config) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core || !config) return;
    
    // Parse config object and apply to mGBA
    std::lock_guard<std::mutex> lock(ctx->mutex);
    // Implementation would extract fields from config object
}

JNIEXPORT jobject JNICALL Java_com_gbaemu_core_GbaCore_nativeGetConfig(JNIEnv* env, jobject thiz, jlong handle) {
    // Return config object
    return nullptr;
}

JNIEXPORT jobject JNICALL Java_com_gbaemu_core_GbaCore_nativeGetGameInfo(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return nullptr;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    
    GameInfo info{};
    if (!mCoreGetGameInfo(ctx->core, info.title, info.game_code, info.maker_code,
                          &info.save_type, &info.has_rtc, &info.has_gyro, &info.has_solar, &info.has_rumble,
                          &info.rom_size, &info.crc32)) {
        return nullptr;
    }
    
    jclass info_class = env->FindClass("com/gbaemu/core/GameInfo");
    if (!info_class) return nullptr;
    
    jmethodID ctor = env->GetMethodID(info_class, "<init>", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;BZZZZII)V");
    if (!ctor) return nullptr;
    
    jstring title = env->NewStringUTF(info.title);
    jstring game_code = env->NewStringUTF(info.game_code);
    jstring maker_code = env->NewStringUTF(info.maker_code);
    
    jobject obj = env->NewObject(info_class, ctor, title, game_code, maker_code,
                                 static_cast<jbyte>(info.save_type), info.has_rtc, info.has_gyro,
                                 info.has_solar, info.has_rumble, static_cast<jint>(info.rom_size),
                                 static_cast<jint>(info.crc32));
    
    env->DeleteLocalRef(title);
    env->DeleteLocalRef(game_code);
    env->DeleteLocalRef(maker_code);
    
    return obj;
}

JNIEXPORT jobject JNICALL Java_com_gbaemu_core_GbaCore_nativeGetRTC(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return nullptr;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    
    int year, month, day, hour, minute, second, dow;
    mCoreGetRTC(ctx->core, &year, &month, &day, &hour, &minute, &second, &dow);
    
    jclass rtc_class = env->FindClass("com/gbaemu/core/RTCTime");
    if (!rtc_class) return nullptr;
    
    jmethodID ctor = env->GetMethodID(rtc_class, "<init>", "(IIIIIII)V");
    if (!ctor) return nullptr;
    
    return env->NewObject(rtc_class, ctor, year, month, day, hour, minute, second, dow);
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeSetRTC(JNIEnv* env, jobject thiz, jlong handle, jobject rtc) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core || !rtc) return;
    
    jclass rtc_class = env->GetObjectClass(rtc);
    jfieldID f_year = env->GetFieldID(rtc_class, "year", "I");
    jfieldID f_month = env->GetFieldID(rtc_class, "month", "I");
    jfieldID f_day = env->GetFieldID(rtc_class, "day", "I");
    jfieldID f_hour = env->GetFieldID(rtc_class, "hour", "I");
    jfieldID f_minute = env->GetFieldID(rtc_class, "minute", "I");
    jfieldID f_second = env->GetFieldID(rtc_class, "second", "I");
    jfieldID f_dow = env->GetFieldID(rtc_class, "dayOfWeek", "I");
    
    int year = env->GetIntField(rtc, f_year);
    int month = env->GetIntField(rtc, f_month);
    int day = env->GetIntField(rtc, f_day);
    int hour = env->GetIntField(rtc, f_hour);
    int minute = env->GetIntField(rtc, f_minute);
    int second = env->GetIntField(rtc, f_second);
    int dow = env->GetIntField(rtc, f_dow);
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    mCoreSetRTC(ctx->core, year, month, day, hour, minute, second, dow);
}

JNIEXPORT jint JNICALL Java_com_gbaemu_core_GbaCore_nativeGetState(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return static_cast<jint>(EmulatorState::ERROR);
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    return static_cast<jint>(mCoreGetState(ctx->core));
}

JNIEXPORT jint JNICALL Java_com_gbaemu_core_GbaCore_nativeGetFPS(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return 0;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    return mCoreGetFPS(ctx->core);
}

JNIEXPORT jlong JNICALL Java_com_gbaemu_core_GbaCore_nativeGetFrameCount(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return 0;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    return static_cast<jlong>(mCoreGetFrameCount(ctx->core));
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeSetCallbacks(JNIEnv* env, jobject thiz, jlong handle,
    jobject frame_callback, jobject audio_callback, jobject save_callback, jobject log_callback, jobject state_callback) {
    
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx) return;
    
    // Clear old refs
    if (ctx->callbacks.frame_callback) env->DeleteGlobalRef(ctx->callbacks.frame_callback);
    if (ctx->callbacks.audio_callback) env->DeleteGlobalRef(ctx->callbacks.audio_callback);
    if (ctx->callbacks.save_callback) env->DeleteGlobalRef(ctx->callbacks.save_callback);
    if (ctx->callbacks.log_callback) env->DeleteGlobalRef(ctx->callbacks.log_callback);
    if (ctx->callbacks.state_callback) env->DeleteGlobalRef(ctx->callbacks.state_callback);
    
    // Store new refs
    ctx->callbacks.frame_callback = frame_callback ? env->NewGlobalRef(frame_callback) : nullptr;
    ctx->callbacks.audio_callback = audio_callback ? env->NewGlobalRef(audio_callback) : nullptr;
    ctx->callbacks.save_callback = save_callback ? env->NewGlobalRef(save_callback) : nullptr;
    ctx->callbacks.log_callback = log_callback ? env->NewGlobalRef(log_callback) : nullptr;
    ctx->callbacks.state_callback = state_callback ? env->NewGlobalRef(state_callback) : nullptr;
    
    // Cache method IDs
    if (ctx->callbacks.frame_callback) {
        jclass cls = env->GetObjectClass(ctx->callbacks.frame_callback);
        ctx->callbacks.frame_method = env->GetMethodID(cls, "onFrame", "(Ljava/nio/ByteBuffer;IIIIJ)V");
    }
    if (ctx->callbacks.audio_callback) {
        jclass cls = env->GetObjectClass(ctx->callbacks.audio_callback);
        ctx->callbacks.audio_method = env->GetMethodID(cls, "onAudio", "([SIIJ)V");
    }
    if (ctx->callbacks.save_callback) {
        jclass cls = env->GetObjectClass(ctx->callbacks.save_callback);
        ctx->callbacks.save_method = env->GetMethodID(cls, "onSave", "([B)V");
    }
    if (ctx->callbacks.log_callback) {
        jclass cls = env->GetObjectClass(ctx->callbacks.log_callback);
        ctx->callbacks.log_method = env->GetMethodID(cls, "onLog", "(ILjava/lang/String;)V");
    }
    if (ctx->callbacks.state_callback) {
        jclass cls = env->GetObjectClass(ctx->callbacks.state_callback);
        ctx->callbacks.state_method = env->GetMethodID(cls, "onStateChange", "(ILjava/lang/String;)V");
    }
}

JNIEXPORT jstring JNICALL Java_com_gbaemu_core_GbaCore_nativeGetError(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return env->NewStringUTF("Invalid handle");
    
    const char* err = mCoreGetError(ctx->core);
    return env->NewStringUTF(err ? err : "Unknown error");
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaCore_nativeClearError(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<EmulatorContext*>(handle);
    if (!ctx || !ctx->core) return;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    mCoreClearError(ctx->core);
    ctx->last_error.clear();
}

// Link cable implementation

JNIEXPORT jlong JNICALL Java_com_gbaemu_core_GbaLink_nativeCreate(JNIEnv* env, jobject thiz) {
    auto* ctx = new LinkContext();
    return reinterpret_cast<jlong>(ctx);
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaLink_nativeDestroy(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<LinkContext*>(handle);
    if (ctx) delete ctx;
}

JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaLink_nativeConnect(JNIEnv* env, jobject thiz, jlong handle, jlong core_handle) {
    auto* ctx = reinterpret_cast<LinkContext*>(handle);
    auto* core_ctx = reinterpret_cast<EmulatorContext*>(core_handle);
    if (!ctx || !core_ctx || !core_ctx->core) return JNI_FALSE;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    ctx->core = core_ctx->core;
    ctx->connected = true;
    return JNI_TRUE;
}

JNIEXPORT void JNICALL Java_com_gbaemu_core_GbaLink_nativeDisconnect(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<LinkContext*>(handle);
    if (!ctx) return;
    
    std::lock_guard<std::mutex> lock(ctx->mutex);
    ctx->core = nullptr;
    ctx->connected = false;
}

JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaLink_nativeSendData(JNIEnv* env, jobject thiz, jlong handle, jbyteArray data, jint size) {
    auto* ctx = reinterpret_cast<LinkContext*>(handle);
    if (!ctx || !ctx->connected || !data) return JNI_FALSE;
    
    jbyte* bytes = env->GetByteArrayElements(data, nullptr);
    ctx->tx_buffer.assign(reinterpret_cast<uint8_t*>(bytes), reinterpret_cast<uint8_t*>(bytes) + size);
    env->ReleaseByteArrayElements(data, bytes, JNI_ABORT);
    
    // In real implementation, this would trigger link cable protocol
    return JNI_TRUE;
}

JNIEXPORT jint JNICALL Java_com_gbaemu_core_GbaLink_nativeReceiveData(JNIEnv* env, jobject thiz, jlong handle, jbyteArray out_data, jint max_size) {
    auto* ctx = reinterpret_cast<LinkContext*>(handle);
    if (!ctx || !ctx->connected || !out_data) return 0;
    
    int size = std::min(static_cast<int>(ctx->rx_buffer.size()), max_size);
    if (size > 0) {
        env->SetByteArrayRegion(out_data, 0, size, reinterpret_cast<const jbyte*>(ctx->rx_buffer.data()));
    }
    return size;
}

JNIEXPORT jboolean JNICALL Java_com_gbaemu_core_GbaLink_nativeIsConnected(JNIEnv* env, jobject thiz, jlong handle) {
    auto* ctx = reinterpret_cast<LinkContext*>(handle);
    return ctx && ctx->connected ? JNI_TRUE : JNI_FALSE;
}