//
//  GbaCoreBridge.c
//  GbaEmuCore
//
//  C implementation bridging Swift to mGBA core
//

#include "GbaCoreBridge.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// mGBA C API includes
// In a real build, these would come from mGBA source tree
// #include <mgba/core/core.h>
// #include <mgba/core/config.h>
// #include <mgba/core/cheats.h>
// #include <mgba/gba/gba.h>

// For now, we provide stub implementations that would be replaced
// with actual mGBA calls when linked against the library

// Forward declarations for mGBA functions (these would be from mGBA library)
extern struct mCore* mCoreCreate(void);
extern void mCoreDestroy(struct mCore* core);
extern bool mCoreLoadROM(struct mCore* core, const uint8_t* data, size_t size);
extern bool mCoreLoadBIOS(struct mCore* core, const uint8_t* data, size_t size);
extern void mCoreUnloadROM(struct mCore* core);
extern void mCoreReset(struct mCore* core);
extern void mCoreRunFrame(struct mCore* core);
extern void mCoreSetInput(struct mCore* core, uint32_t keys);
extern void mCoreSetSensor(struct mCore* core, int type, float x, float y, float z);
extern const struct mGBAVideoBuffer* mCoreGetVideoBuffer(struct mCore* core);
extern const struct mGBAAudioBuffer* mCoreGetAudioBuffer(struct mCore* core);
extern size_t mCoreSaveStateSize(struct mCore* core);
extern bool mCoreSaveState(struct mCore* core, uint8_t* data, size_t size);
extern bool mCoreLoadState(struct mCore* core, const uint8_t* data, size_t size);
extern size_t mCoreSaveBatterySize(struct mCore* core);
extern bool mCoreSaveBattery(struct mCore* core, uint8_t* data, size_t size);
extern bool mCoreLoadBattery(struct mCore* core, const uint8_t* data, size_t size);
extern void mCoreAddCheat(struct mCore* core, uint32_t addr, uint16_t val, uint16_t mask, bool enabled, const char* desc, int type);
extern void mCoreEnableCheat(struct mCore* core, int index, bool enabled);
extern void mCoreClearCheats(struct mCore* core);
extern int mCoreGetCheatCount(struct mCore* core);
extern void mCoreGetCheatInfo(struct mCore* core, int index,
                              uint32_t* addr, uint16_t* val, uint16_t* mask,
                              bool* enabled, char* desc, int* type);
extern bool mCoreGetGameInfo(struct mCore* core,
                             char* title, char* gameCode, char* makerCode,
                             uint8_t* saveType, bool* hasRTC, bool* hasGyro,
                             bool* hasSolar, bool* hasRumble,
                             uint32_t* romSize, uint32_t* crc32);
extern void mCoreGetRTC(struct mCore* core,
                        int* year, int* month, int* day,
                        int* hour, int* minute, int* second, int* dow);
extern void mCoreSetRTC(struct mCore* core,
                        int year, int month, int day,
                        int hour, int minute, int second, int dow);
extern const char* mCoreGetError(struct mCore* core);
extern void mCoreClearError(struct mCore* core);
extern void mCoreSetConfig(struct mCore* core, const struct mGBACoreConfig* config);
extern const struct mGBACoreConfig* mCoreGetConfig(struct mCore* core);

// Thread-local error buffer
static __thread char errorBuffer[1024] = {0};

// Core lifecycle
mCore* gbaCoreCreate(void) {
    mCore* core = mCoreCreate();
    if (!core) {
        snprintf(errorBuffer, sizeof(errorBuffer), "Failed to create mGBA core");
    }
    return core;
}

void gbaCoreDestroy(mCore* core) {
    if (core) {
        mCoreDestroy(core);
    }
}

// ROM/BIOS loading
bool gbaCoreLoadROM(mCore* core, const uint8_t* data, size_t size) {
    if (!core || !data || size == 0) {
        snprintf(errorBuffer, sizeof(errorBuffer), "Invalid parameters");
        return false;
    }
    return mCoreLoadROM(core, data, size);
}

bool gbaCoreLoadBIOS(mCore* core, const uint8_t* data, size_t size) {
    if (!core || !data || size == 0) {
        snprintf(errorBuffer, sizeof(errorBuffer), "Invalid parameters");
        return false;
    }
    return mCoreLoadBIOS(core, data, size);
}

void gbaCoreUnloadROM(mCore* core) {
    if (core) {
        mCoreUnloadROM(core);
    }
}

// Execution control
void gbaCoreReset(mCore* core) {
    if (core) {
        mCoreReset(core);
    }
}

void gbaCoreRunFrame(mCore* core) {
    if (core) {
        mCoreRunFrame(core);
    }
}

// Input
void gbaCoreSetKeys(mCore* core, uint32_t keys) {
    if (core) {
        mCoreSetInput(core, keys);
    }
}

void gbaCoreSetSensor(mCore* core, int type, float x, float y, float z) {
    if (core) {
        mCoreSetSensor(core, type, x, y, z);
    }
}

// Video/Audio
const mGBAVideoBuffer* gbaCoreGetVideoBuffer(mCore* core) {
    if (core) {
        return mCoreGetVideoBuffer(core);
    }
    return NULL;
}

const mGBAAudioBuffer* gbaCoreGetAudioBuffer(mCore* core) {
    if (core) {
        return mCoreGetAudioBuffer(core);
    }
    return NULL;
}

// Save states
size_t gbaCoreSaveStateSize(mCore* core) {
    if (core) {
        return mCoreSaveStateSize(core);
    }
    return 0;
}

bool gbaCoreSaveState(mCore* core, uint8_t* data, size_t size) {
    if (!core || !data || size == 0) {
        snprintf(errorBuffer, sizeof(errorBuffer), "Invalid parameters");
        return false;
    }
    return mCoreSaveState(core, data, size);
}

bool gbaCoreLoadState(mCore* core, const uint8_t* data, size_t size) {
    if (!core || !data || size == 0) {
        snprintf(errorBuffer, sizeof(errorBuffer), "Invalid parameters");
        return false;
    }
    return mCoreLoadState(core, data, size);
}

// Battery saves
size_t gbaCoreSaveBatterySize(mCore* core) {
    if (core) {
        return mCoreSaveBatterySize(core);
    }
    return 0;
}

bool gbaCoreSaveBattery(mCore* core, uint8_t* data, size_t size) {
    if (!core || !data || size == 0) {
        snprintf(errorBuffer, sizeof(errorBuffer), "Invalid parameters");
        return false;
    }
    return mCoreSaveBattery(core, data, size);
}

bool gbaCoreLoadBattery(mCore* core, const uint8_t* data, size_t size) {
    if (!core || !data || size == 0) {
        snprintf(errorBuffer, sizeof(errorBuffer), "Invalid parameters");
        return false;
    }
    return mCoreLoadBattery(core, data, size);
}

// Cheats
void gbaCoreAddCheat(mCore* core, uint32_t addr, uint16_t val, uint16_t mask,
                     bool enabled, const char* desc, int type) {
    if (core) {
        mCoreAddCheat(core, addr, val, mask, enabled, desc ? desc : "", type);
    }
}

void gbaCoreEnableCheat(mCore* core, int index, bool enabled) {
    if (core) {
        mCoreEnableCheat(core, index, enabled);
    }
}

void gbaCoreClearCheats(mCore* core) {
    if (core) {
        mCoreClearCheats(core);
    }
}

int gbaCoreGetCheatCount(mCore* core) {
    if (core) {
        return mCoreGetCheatCount(core);
    }
    return 0;
}

void gbaCoreGetCheatInfo(mCore* core, int index,
                         uint32_t* addr, uint16_t* val, uint16_t* mask,
                         bool* enabled, char* desc, int* type) {
    if (core) {
        mCoreGetCheatInfo(core, index, addr, val, mask, enabled, desc, type);
    }
}

// Game info
bool gbaCoreGetGameInfo(mCore* core,
                        char* title, char* gameCode, char* makerCode,
                        uint8_t* saveType, bool* hasRTC, bool* hasGyro,
                        bool* hasSolar, bool* hasRumble,
                        uint32_t* romSize, uint32_t* crc32) {
    if (!core) {
        return false;
    }
    return mCoreGetGameInfo(core, title, gameCode, makerCode,
                            saveType, hasRTC, hasGyro, hasSolar, hasRumble,
                            romSize, crc32);
}

// RTC
void gbaCoreGetRTC(mCore* core,
                   int* year, int* month, int* day,
                   int* hour, int* minute, int* second, int* dow) {
    if (core) {
        mCoreGetRTC(core, year, month, day, hour, minute, second, dow);
    }
}

void gbaCoreSetRTC(mCore* core,
                   int year, int month, int day,
                   int hour, int minute, int second, int dow) {
    if (core) {
        mCoreSetRTC(core, year, month, day, hour, minute, second, dow);
    }
}

// Error handling
const char* gbaCoreGetError(mCore* core) {
    if (core) {
        const char* err = mCoreGetError(core);
        if (err) return err;
    }
    return errorBuffer[0] ? errorBuffer : "Unknown error";
}

void gbaCoreClearError(mCore* core) {
    if (core) {
        mCoreClearError(core);
    }
    errorBuffer[0] = '\0';
}

// Configuration
void gbaCoreSetConfig(mCore* core, const mGBACoreConfig* config) {
    if (core && config) {
        mCoreSetConfig(core, config);
    }
}

const mGBACoreConfig* gbaCoreGetConfig(mCore* core) {
    if (core) {
        return mCoreGetConfig(core);
    }
    return NULL;
}