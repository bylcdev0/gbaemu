package com.gbaemu.core

import android.content.Context
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleObserver
import androidx.lifecycle.OnLifecycleEvent
import kotlinx.coroutines.*
import java.nio.ByteBuffer

/**
 * Main GBA Emulator Core - Kotlin wrapper around native mGBA core
 */
class GbaCore private constructor(private val nativeHandle: Long) : LifecycleObserver {

    companion object {
        @Volatile private var INSTANCE: GbaCore? = null
        private val lock = Any()

        fun getInstance(context: Context): GbaCore {
            synchronized(lock) {
                if (INSTANCE == null) {
                    val handle = nativeCreate()
                    if (handle == 0L) {
                        throw IllegalStateException("Failed to create GBA core")
                    }
                    INSTANCE = GbaCore(handle)
                }
                return INSTANCE!!
            }
        }

        fun destroyInstance() {
            synchronized(lock) {
                INSTANCE?.nativeDestroy()
                INSTANCE = null
            }
        }
    }

    // Native methods
    private external fun nativeCreate(): Long
    private external fun nativeDestroy()
    external fun nativeLoadRom(romData: ByteArray): Boolean
    external fun nativeLoadBios(biosData: ByteArray): Boolean
    external fun nativeUnloadRom()
    external fun nativeReset()
    external fun nativePause()
    external fun nativeResume()
    external fun nativeRunFrame(): Boolean
    external fun nativeRunFrameAsync(): Boolean
    external fun nativeSetKeys(keys: Int)
    external fun nativeSetSensorValue(sensorType: Int, x: Float, y: Float, z: Float)
    external fun nativeSaveState(): ByteArray?
    external fun nativeLoadState(stateData: ByteArray): Boolean
    external fun nativeSaveBattery(): ByteArray?
    external fun nativeLoadBattery(batteryData: ByteArray): Boolean
    external fun nativeAddCheat(address: Int, value: Short, mask: Short, enabled: Boolean, description: String, type: Int)
    external fun nativeEnableCheat(index: Int, enabled: Boolean)
    external fun nativeClearCheats()
    external fun nativeGetCheats(): Array<CheatCode>
    external fun nativeSetConfig(config: EmulatorConfig)
    external fun nativeGetConfig(): EmulatorConfig
    external fun nativeGetGameInfo(): GameInfo?
    external fun nativeGetRTC(): RTCTime?
    external fun nativeSetRTC(rtc: RTCTime)
    external fun nativeGetState(): EmulatorState
    external fun nativeGetFPS(): Int
    external fun nativeGetFrameCount(): Long
    external fun nativeSetCallbacks(
        frameCallback: FrameCallback?,
        audioCallback: AudioCallback?,
        saveCallback: SaveCallback?,
        logCallback: LogCallback?,
        stateCallback: StateCallback?
    )
    external fun nativeGetError(): String
    external fun nativeClearError()

    // Callbacks
    private var frameCallback: FrameCallback? = null
    private var audioCallback: AudioCallback? = null
    private var saveCallback: SaveCallback? = null
    private var logCallback: LogCallback? = null
    private var stateCallback: StateCallback? = null

    // Coroutine scope for async operations
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    init {
        System.loadLibrary("gbaemu-jni")
    }

    /**
     * Load a ROM file
     */
    suspend fun loadRom(romPath: String): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            val bytes = java.io.File(romPath).readBytes()
            nativeLoadRom(bytes)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun loadRom(romBytes: ByteArray): Boolean = withContext(Dispatchers.IO) {
        nativeLoadRom(romBytes)
    }

    /**
     * Load BIOS (optional but recommended for accuracy)
     */
    suspend fun loadBios(biosPath: String): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            val bytes = java.io.File(biosPath).readBytes()
            nativeLoadBios(bytes)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Start emulation loop
     */
    fun start(frameCallback: FrameCallback, audioCallback: AudioCallback? = null,
              saveCallback: SaveCallback? = null, logCallback: LogCallback? = null,
              stateCallback: StateCallback? = null) {
        this.frameCallback = frameCallback
        this.audioCallback = audioCallback
        this.saveCallback = saveCallback
        this.logCallback = logCallback
        this.stateCallback = stateCallback

        nativeSetCallbacks(frameCallback, audioCallback, saveCallback, logCallback, stateCallback)

        scope.launch {
            while (isActive && nativeGetState() != EmulatorState.ERROR.ordinal) {
                val startTime = System.nanoTime()
                nativeRunFrame()
                val elapsed = System.nanoTime() - startTime
                
                // Frame pacing - target ~16.67ms (60 FPS)
                val targetFrameTime = 16_666_667L
                val sleepTime = targetFrameTime - elapsed
                if (sleepTime > 0) {
                    delay(sleepTime / 1_000_000)
                }
            }
        }
    }

    /**
     * Stop emulation
     */
    fun stop() {
        scope.cancel()
        nativePause()
    }

    /**
     * Pause emulation
     */
    fun pause() {
        nativePause()
    }

    /**
     * Resume emulation
     */
    fun resume() {
        nativeResume()
    }

    /**
     * Reset emulator (soft reset)
     */
    fun reset() {
        nativeReset()
    }

    /**
     * Set input keys
     * Key mapping: A=0, B=1, SELECT=2, START=3, RIGHT=4, LEFT=5, UP=6, DOWN=7, R=8, L=9
     */
    fun setKeys(keys: Int) {
        nativeSetKeys(keys)
    }

    /**
     * Set sensor values (gyro, solar, tilt)
     */
    fun setSensor(sensorType: SensorType, x: Float, y: Float, z: Float) {
        nativeSetSensorValue(sensorType.ordinal, x, y, z)
    }

    /**
     * Save state to byte array
     */
    suspend fun saveState(): Result<ByteArray> = withContext(Dispatchers.IO) {
        try {
            val data = nativeSaveState()
            Result.success(data ?: byteArrayOf())
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Load state from byte array
     */
    suspend fun loadState(stateData: ByteArray): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            Result.success(nativeLoadState(stateData))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Save battery (SRAM/EEPROM/Flash)
     */
    suspend fun saveBattery(): Result<ByteArray> = withContext(Dispatchers.IO) {
        try {
            val data = nativeSaveBattery()
            Result.success(data ?: byteArrayOf())
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Load battery
     */
    suspend fun loadBattery(batteryData: ByteArray): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            Result.success(nativeLoadBattery(batteryData))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Cheat management
     */
    fun addCheat(cheat: CheatCode) {
        nativeAddCheat(cheat.address, cheat.value, cheat.mask, cheat.enabled, cheat.description, cheat.type)
    }

    fun enableCheat(index: Int, enabled: Boolean) {
        nativeEnableCheat(index, enabled)
    }

    fun clearCheats() {
        nativeClearCheats()
    }

    fun getCheats(): List<CheatCode> = nativeGetCheats().toList()

    /**
     * Configuration
     */
    fun setConfig(config: EmulatorConfig) {
        nativeSetConfig(config)
    }

    fun getConfig(): EmulatorConfig = nativeGetConfig()

    /**
     * Game information
     */
    fun getGameInfo(): GameInfo? = nativeGetGameInfo()

    /**
     * Real-time clock
     */
    fun getRTC(): RTCTime? = nativeGetRTC()

    fun setRTC(rtc: RTCTime) {
        nativeSetRTC(rtc)
    }

    /**
     * Status
     */
    fun getState(): EmulatorState = nativeGetState()
    fun getFPS(): Int = nativeGetFPS()
    fun getFrameCount(): Long = nativeGetFrameCount()
    fun getError(): String = nativeGetError()
    fun clearError() { nativeClearError() }

    @OnLifecycleEvent(Lifecycle.Event.ON_DESTROY)
    fun onDestroy() {
        stop()
        nativeDestroy()
    }
}

/**
 * Emulator state enum
 */
enum class EmulatorState(val ordinal: Int) {
    UNINITIALIZED(0),
    READY(1),
    RUNNING(2),
    PAUSED(3),
    ERROR(-1)
}

/**
 * Sensor types
 */
enum class SensorType(val ordinal: Int) {
    NONE(0),
    GYRO(1),
    SOLAR(2),
    TILT(3),
    RUMBLE(4)
}

/**
 * Video filter types
 */
enum class VideoFilter(val ordinal: Int) {
    NEAREST(0),
    BILINEAR(1),
    SCALE2X(2),
    HQ2X(3),
    XBR(4)
}

/**
 * Save types
 */
enum class SaveType(val ordinal: Int) {
    AUTO_DETECT(-1),
    NONE(0),
    SRAM(1),
    EEPROM(2),
    FLASH_64K(3),
    FLASH_128K(4),
    FLASH_512K(5),
    FLASH_1M(6)
}

/**
 * Emulator configuration data class
 */
@kotlinx.serialization.Serializable
data class EmulatorConfig(
    val audio: AudioConfig = AudioConfig(),
    val video: VideoConfig = VideoConfig(),
    val saveType: SaveType = SaveType.AUTO_DETECT,
    val rtcEnabled: Boolean = true,
    val mirroring: Boolean = false,
    val cpuCyclesPerFrame: Int = 0,
    val biosPath: String? = null,
    val cheatsPath: String? = null
)

@kotlinx.serialization.Serializable
data class AudioConfig(
    val sampleRate: Int = 44100,
    val bufferSize: Int = 2048,
    val enabled: Boolean = true,
    val volume: Float = 1.0f
)

@kotlinx.serialization.Serializable
data class VideoConfig(
    val width: Int = 240,
    val height: Int = 160,
    val filter: VideoFilter = VideoFilter.BILINEAR,
    val vsync: Boolean = true,
    val frameskip: Int = 0
)

/**
 * Frame callback interface
 */
interface FrameCallback {
    fun onFrame(buffer: ByteBuffer, width: Int, height: Int, stride: Int, timestampNs: Long)
}

/**
 * Audio callback interface
 */
interface AudioCallback {
    fun onAudio(samples: ShortArray, sampleRate: Int, timestampNs: Long)
}

/**
 * Save callback interface
 */
interface SaveCallback {
    fun onSave(data: ByteArray)
}

/**
 * Log callback interface
 */
interface LogCallback {
    fun onLog(level: Int, message: String)
}

/**
 * State callback interface
 */
interface StateCallback {
    fun onStateChange(state: Int, message: String)
}

/**
 * Cheat code data class
 */
@kotlinx.serialization.Serializable
data class CheatCode(
    val address: Int,
    val value: Short,
    val mask: Short,
    val enabled: Boolean,
    val description: String,
    val type: Int // 0=AR, 1=GS, 2=CB
)

/**
 * Game info data class
 */
@kotlinx.serialization.Serializable
data class GameInfo(
    val title: String,
    val gameCode: String,
    val makerCode: String,
    val saveType: Byte,
    val hasRTC: Boolean,
    val hasGyro: Boolean,
    val hasSolar: Boolean,
    val hasRumble: Boolean,
    val romSize: Int,
    val crc32: Int
)

/**
 * RTC time data class
 */
@kotlinx.serialization.Serializable
data class RTCTime(
    val year: Int,
    val month: Int,
    val day: Int,
    val hour: Int,
    val minute: Int,
    val second: Int,
    val dayOfWeek: Int
)

/**
 * Key constants for input mapping
 */
object GbaKeys {
    const val A = 1 shl 0
    const val B = 1 shl 1
    const val SELECT = 1 shl 2
    const val START = 1 shl 3
    const val RIGHT = 1 shl 4
    const val LEFT = 1 shl 5
    const val UP = 1 shl 6
    const val DOWN = 1 shl 7
    const val R = 1 shl 8
    const val L = 1 shl 9
    
    fun fromDirections(up: Boolean, down: Boolean, left: Boolean, right: Boolean,
                       a: Boolean, b: Boolean, start: Boolean, select: Boolean,
                       l: Boolean, r: Boolean): Int {
        var keys = 0
        if (up) keys |= UP
        if (down) keys |= DOWN
        if (left) keys |= LEFT
        if (right) keys |= RIGHT
        if (a) keys |= A
        if (b) keys |= B
        if (start) keys |= START
        if (select) keys |= SELECT
        if (l) keys |= L
        if (r) keys |= R
        return keys
    }
}