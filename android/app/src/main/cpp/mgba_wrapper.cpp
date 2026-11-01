#include "gbaemu_jni.h"
#include <memory>
#include <vector>
#include <string>

// This file provides a C++ wrapper around mGBA's C API
// In a real build, this would link against the actual mGBA library

namespace gbaemu {

class MGBAWrapper {
public:
    MGBAWrapper() : core_(nullptr) {}
    ~MGBAWrapper() { destroy(); }

    bool init() {
        core_ = mCoreCreate();
        return core_ != nullptr;
    }

    void destroy() {
        if (core_) {
            mCoreDestroy(core_);
            core_ = nullptr;
        }
    }

    bool loadROM(const uint8_t* data, size_t size) {
        return core_ && mCoreLoadROM(core_, data, size);
    }

    bool loadBIOS(const uint8_t* data, size_t size) {
        return core_ && mCoreLoadBIOS(core_, data, size);
    }

    void unloadROM() {
        if (core_) mCoreUnloadROM(core_);
    }

    void reset() {
        if (core_) mCoreReset(core_);
    }

    void runFrame() {
        if (core_) mCoreRunFrame(core_);
    }

    void setInput(uint32_t keys) {
        if (core_) mCoreSetInput(core_, keys);
    }

    void setSensor(int type, float x, float y, float z) {
        if (core_) mCoreSetSensor(core_, type, x, y, z);
    }

    const void* getVideoBuffer(int* width, int* height, int* pitch) {
        if (!core_) return nullptr;
        const mGBAVideoBuffer* vb = mCoreGetVideoBuffer(core_);
        if (vb) {
            if (width) *width = vb->width;
            if (height) *height = vb->height;
            if (pitch) *pitch = vb->pitch;
            return vb->data;
        }
        return nullptr;
    }

    const void* getAudioBuffer(int* sample_count, int* sample_rate) {
        if (!core_) return nullptr;
        const mGBAAudioBuffer* ab = mCoreGetAudioBuffer(core_);
        if (ab) {
            if (sample_count) *sample_count = ab->size / 2; // stereo 16-bit
            if (sample_rate) *sample_rate = ab->sample_rate;
            return ab->data;
        }
        return nullptr;
    }

    size_t saveStateSize() {
        return core_ ? mCoreSaveStateSize(core_) : 0;
    }

    bool saveState(uint8_t* data, size_t size) {
        return core_ && mCoreSaveState(core_, data, size);
    }

    bool loadState(const uint8_t* data, size_t size) {
        return core_ && mCoreLoadState(core_, data, size);
    }

    size_t saveBatterySize() {
        return core_ ? mCoreSaveBatterySize(core_) : 0;
    }

    bool saveBattery(uint8_t* data, size_t size) {
        return core_ && mCoreSaveBattery(core_, data, size);
    }

    bool loadBattery(const uint8_t* data, size_t size) {
        return core_ && mCoreLoadBattery(core_, data, size);
    }

    void addCheat(uint32_t addr, uint16_t val, uint16_t mask, bool enable, const char* desc, int type) {
        if (core_) mCoreAddCheat(core_, addr, val, mask, enable, desc, type);
    }

    void enableCheat(int index, bool enable) {
        if (core_) mCoreEnableCheat(core_, index, enable);
    }

    void clearCheats() {
        if (core_) mCoreClearCheats(core_);
    }

    int getCheatCount() {
        return core_ ? mCoreGetCheatCount(core_) : 0;
    }

    void getCheatInfo(int index, uint32_t* addr, uint16_t* val, uint16_t* mask, bool* enable, char* desc, int* type) {
        if (core_) mCoreGetCheatInfo(core_, index, addr, val, mask, enable, desc, type);
    }

    bool getGameInfo(char* title, char* game_code, char* maker_code,
                     uint8_t* save_type, bool* has_rtc, bool* has_gyro, bool* has_solar, bool* has_rumble,
                     uint32_t* rom_size, uint32_t* crc32) {
        return core_ && mCoreGetGameInfo(core_, title, game_code, maker_code,
                                         save_type, has_rtc, has_gyro, has_solar, has_rumble,
                                         rom_size, crc32);
    }

    void getRTC(int* year, int* month, int* day, int* hour, int* minute, int* second, int* dow) {
        if (core_) mCoreGetRTC(core_, year, month, day, hour, minute, second, dow);
    }

    void setRTC(int year, int month, int day, int hour, int minute, int second, int dow) {
        if (core_) mCoreSetRTC(core_, year, month, day, hour, minute, second, dow);
    }

    int getState() {
        return core_ ? mCoreGetState(core_) : -1;
    }

    int getFPS() {
        return core_ ? mCoreGetFPS(core_) : 0;
    }

    uint64_t getFrameCount() {
        return core_ ? mCoreGetFrameCount(core_) : 0;
    }

    const char* getError() {
        return core_ ? mCoreGetError(core_) : "Not initialized";
    }

    void clearError() {
        if (core_) mCoreClearError(core_);
    }

    mCore* getCore() { return core_; }

private:
    mCore* core_;
};

} // namespace gbaemu