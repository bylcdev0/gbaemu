//
//  GbaCoreBridge.h
//  GbaEmuCore
//
//  C bridge header for mGBA core integration
//

#ifndef GbaCoreBridge_h
#define GbaCoreBridge_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer types
typedef struct mCore mCore;
typedef struct mGBACoreConfig mGBACoreConfig;
typedef struct mGBAVideoBuffer mGBAVideoBuffer;
typedef struct mGBAAudioBuffer mGBAAudioBuffer;

// Video buffer structure (matches mGBA)
struct mGBAVideoBuffer {
    void* data;
    int width;
    int height;
    int pitch;
    int format; // 0 = RGB565, 1 = RGBA8888
};

// Audio buffer structure
struct mGBAAudioBuffer {
    void* data;
    int size;         // bytes
    int sampleRate;   // Hz
    int channels;     // 2 for stereo
};

// Core lifecycle
mCore* gbaCoreCreate(void);
void gbaCoreDestroy(mCore* core);

// ROM/BIOS loading
bool gbaCoreLoadROM(mCore* core, const uint8_t* data, size_t size);
bool gbaCoreLoadBIOS(mCore* core, const uint8_t* data, size_t size);
void gbaCoreUnloadROM(mCore* core);

// Execution control
void gbaCoreReset(mCore* core);
void gbaCoreRunFrame(mCore* core);

// Input
void gbaCoreSetKeys(mCore* core, uint32_t keys);
void gbaCoreSetSensor(mCore* core, int type, float x, float y, float z);

// Video/Audio
const mGBAVideoBuffer* gbaCoreGetVideoBuffer(mCore* core);
const mGBAAudioBuffer* gbaCoreGetAudioBuffer(mCore* core);

// Save states
size_t gbaCoreSaveStateSize(mCore* core);
bool gbaCoreSaveState(mCore* core, uint8_t* data, size_t size);
bool gbaCoreLoadState(mCore* core, const uint8_t* data, size_t size);

// Battery saves
size_t gbaCoreSaveBatterySize(mCore* core);
bool gbaCoreSaveBattery(mCore* core, uint8_t* data, size_t size);
bool gbaCoreLoadBattery(mCore* core, const uint8_t* data, size_t size);

// Cheats
void gbaCoreAddCheat(mCore* core, uint32_t addr, uint16_t val, uint16_t mask, bool enabled, const char* desc, int type);
void gbaCoreEnableCheat(mCore* core, int index, bool enabled);
void gbaCoreClearCheats(mCore* core);
int gbaCoreGetCheatCount(mCore* core);
void gbaCoreGetCheatInfo(mCore* core, int index,
                         uint32_t* addr, uint16_t* val, uint16_t* mask,
                         bool* enabled, char* desc, int* type);

// Game info
bool gbaCoreGetGameInfo(mCore* core,
                        char* title, char* gameCode, char* makerCode,
                        uint8_t* saveType, bool* hasRTC, bool* hasGyro,
                        bool* hasSolar, bool* hasRumble,
                        uint32_t* romSize, uint32_t* crc32);

// RTC
void gbaCoreGetRTC(mCore* core,
                   int* year, int* month, int* day,
                   int* hour, int* minute, int* second, int* dow);
void gbaCoreSetRTC(mCore* core,
                   int year, int month, int day,
                   int hour, int minute, int second, int dow);

// Error handling
const char* gbaCoreGetError(mCore* core);
void gbaCoreClearError(mCore* core);

// Configuration
void gbaCoreSetConfig(mCore* core, const mGBACoreConfig* config);
const mGBACoreConfig* gbaCoreGetConfig(mCore* core);

#ifdef __cplusplus
}
#endif

#endif /* GbaCoreBridge_h */