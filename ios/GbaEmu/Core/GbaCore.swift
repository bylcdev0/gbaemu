//
//  GbaCore.swift
//  GbaEmuCore
//
//  Main GBA emulator core wrapper for iOS/macOS using mGBA
//

import Foundation
import CoreGraphics
import Metal
import AVFoundation

// MARK: - Enums

public enum EmulatorState: Int32, CaseIterable {
    case uninitialized = 0
    case ready = 1
    case running = 2
    case paused = 3
    case error = -1
}

public enum SensorType: Int32, CaseIterable {
    case none = 0
    case gyro = 1
    case solar = 2
    case tilt = 3
    case rumble = 4
}

public enum VideoFilter: Int32, CaseIterable {
    case nearest = 0
    case bilinear = 1
    case scale2x = 2
    case hq2x = 3
    case xbr = 4
}

public enum SaveType: Int32, CaseIterable {
    case autoDetect = -1
    case none = 0
    case sram = 1
    case eeprom = 2
    case flash64k = 3
    case flash128k = 4
    case flash512k = 5
    case flash1m = 6
}

// MARK: - Configuration

public struct AudioConfig: Codable, Equatable {
    public var sampleRate: Int = 44100
    public var bufferSize: Int = 2048
    public var enabled: Bool = true
    public var volume: Float = 1.0

    public init() {}
}

public struct VideoConfig: Codable, Equatable {
    public var width: Int = 240
    public var height: Int = 160
    public var filter: VideoFilter = .bilinear
    public var vsync: Bool = true
    public var frameskip: Int = 0

    public init() {}
}

public struct EmulatorConfig: Codable, Equatable {
    public var audio: AudioConfig = AudioConfig()
    public var video: VideoConfig = VideoConfig()
    public var saveType: SaveType = .autoDetect
    public var rtcEnabled: Bool = true
    public var mirroring: Bool = false
    public var cpuCyclesPerFrame: Int = 0
    public var biosPath: String?
    public var cheatsPath: String?

    public init() {}
}

// MARK: - Data Structures

public struct FrameData {
    public let pixels: UnsafeMutableRawPointer
    public let width: Int
    public let height: Int
    public let stride: Int
    public let timestamp: UInt64
    public let ready: Bool

    public init(pixels: UnsafeMutableRawPointer, width: Int, height: Int, stride: Int, timestamp: UInt64, ready: Bool) {
        self.pixels = pixels
        self.width = width
        self.height = height
        self.stride = stride
        self.timestamp = timestamp
        self.ready = ready
    }
}

public struct AudioData {
    public let samples: UnsafeMutablePointer<Int16>
    public let sampleCount: Int
    public let sampleRate: Int
    public let timestamp: UInt64

    public init(samples: UnsafeMutablePointer<Int16>, sampleCount: Int, sampleRate: Int, timestamp: UInt64) {
        self.samples = samples
        self.sampleCount = sampleCount
        self.sampleRate = sampleRate
        self.timestamp = timestamp
    }
}

public struct CheatCode: Codable, Equatable, Identifiable {
    public let id = UUID()
    public var address: UInt32
    public var value: UInt16
    public var mask: UInt16
    public var enabled: Bool
    public var description: String
    public var type: Int // 0=Action Replay, 1=GameShark, 2=CodeBreaker

    public init(address: UInt32, value: UInt16, mask: UInt16, enabled: Bool, description: String, type: Int) {
        self.address = address
        self.value = value
        self.mask = mask
        self.enabled = enabled
        self.description = description
        self.type = type
    }
}

public struct GameInfo: Codable, Equatable {
    public var title: String
    public var gameCode: String
    public var makerCode: String
    public var saveType: UInt8
    public var hasRTC: Bool
    public var hasGyro: Bool
    public var hasSolar: Bool
    public var hasRumble: Bool
    public var romSize: UInt32
    public var crc32: UInt32

    public init() {
        self.title = ""
        self.gameCode = ""
        self.makerCode = ""
        self.saveType = 0
        self.hasRTC = false
        self.hasGyro = false
        self.hasSolar = false
        self.hasRumble = false
        self.romSize = 0
        self.crc32 = 0
    }
}

public struct RTCTime: Codable, Equatable {
    public var year: Int
    public var month: Int
    public var day: Int
    public var hour: Int
    public var minute: Int
    public var second: Int
    public var dayOfWeek: Int

    public init() {
        let date = Date()
        let calendar = Calendar.current
        self.year = calendar.component(.year, from: date)
        self.month = calendar.component(.month, from: date)
        self.day = calendar.component(.day, from: date)
        self.hour = calendar.component(.hour, from: date)
        self.minute = calendar.component(.minute, from: date)
        self.second = calendar.component(.second, from: date)
        self.dayOfWeek = calendar.component(.weekday, from: date) - 1
    }

    public init(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, dayOfWeek: Int) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.dayOfWeek = dayOfWeek
    }
}

// MARK: - Callbacks

public typealias FrameCallback = @Sendable (FrameData) -> Void
public typealias AudioCallback = @Sendable (AudioData) -> Void
public typealias SaveCallback = @Sendable (Data) -> Void
public typealias LogCallback = @Sendable (Int32, String) -> Void
public typealias StateCallback = @Sendable (Int32, String) -> Void

// MARK: - GBA Core Protocol

public protocol GbaCoreProtocol: AnyObject, Sendable {
    var state: EmulatorState { get }
    var fps: Int { get }
    var frameCount: UInt64 { get }
    var lastError: String? { get }

    func loadROM(_ data: Data) throws
    func loadBIOS(_ data: Data) throws
    func unloadROM()

    func reset()
    func pause()
    func resume()

    func runFrame() -> Bool
    func setKeys(_ keys: UInt32)
    func setSensor(_ type: SensorType, x: Float, y: Float, z: Float)

    func saveState() -> Data?
    func loadState(_ data: Data) -> Bool
    func saveBattery() -> Data?
    func loadBattery(_ data: Data) -> Bool

    func addCheat(_ cheat: CheatCode)
    func enableCheat(at index: Int, enabled: Bool)
    func clearCheats()
    func getCheats() -> [CheatCode]

    func setConfig(_ config: EmulatorConfig)
    func getConfig() -> EmulatorConfig
    func getGameInfo() -> GameInfo?
    func getRTC() -> RTCTime?
    func setRTC(_ rtc: RTCTime)

    func setCallbacks(
        frame: FrameCallback?,
        audio: AudioCallback?,
        save: SaveCallback?,
        log: LogCallback?,
        state: StateCallback?
    )

    func clearError()
}

// MARK: - GBA Core Implementation (Wrapper around mGBA C API)

public final class GbaCore: GbaCoreProtocol, @unchecked Sendable {

    // Native handle (opaque pointer to mGBA core)
    private var nativeHandle: OpaquePointer?

    // Callbacks
    private var frameCallback: FrameCallback?
    private var audioCallback: AudioCallback?
    private var saveCallback: SaveCallback?
    private var logCallback: LogCallback?
    private var stateCallback: StateCallback?

    // Frame/audio buffers
    private var frameBuffer: [UInt32] = Array(repeating: 0, count: 240 * 160)
    private var audioBuffer: [Int16] = Array(repeating: 0, count: 4096)

    // Emulation loop
    private var emulationTask: Task<Void, Never>?
    private let emulationQueue = DispatchQueue(label: "com.gbaemu.emulation", qos: .userInitiated)

    public private(set) var state: EmulatorState = .uninitialized
    public private(set) var fps: Int = 0
    public private(set) var frameCount: UInt64 = 0
    public private(set) var lastError: String?

    public init() {
        // Load native library
        loadNativeLibrary()
        nativeHandle = gbaCoreCreate()
        if nativeHandle == nil {
            lastError = "Failed to create GBA core"
            state = .error
        } else {
            state = .ready
        }
    }

    deinit {
        stop()
        if let handle = nativeHandle {
            gbaCoreDestroy(handle)
            nativeHandle = nil
        }
    }

    private func loadNativeLibrary() {
        // In real implementation, this would load the mGBA dylib
        // For now, we use stub functions
    }

    // MARK: - ROM Loading

    public func loadROM(_ data: Data) throws {
        guard let handle = nativeHandle else {
            throw EmulatorError.notInitialized
        }

        let result = data.withUnsafeBytes { bytes in
            gbaCoreLoadROM(handle, bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), data.count)
        }

        if !result {
            lastError = String(cString: gbaCoreGetError(handle))
            throw EmulatorError.loadFailed(lastError ?? "Unknown error")
        }

        state = .ready
        lastError = nil
    }

    public func loadBIOS(_ data: Data) throws {
        guard let handle = nativeHandle else {
            throw EmulatorError.notInitialized
        }

        let result = data.withUnsafeBytes { bytes in
            gbaCoreLoadBIOS(handle, bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), data.count)
        }

        if !result {
            lastError = String(cString: gbaCoreGetError(handle))
            throw EmulatorError.loadFailed(lastError ?? "Unknown error")
        }
    }

    public func unloadROM() {
        guard let handle = nativeHandle else { return }
        gbaCoreUnloadROM(handle)
        state = .ready
    }

    // MARK: - Control

    public func reset() {
        guard let handle = nativeHandle else { return }
        gbaCoreReset(handle)
    }

    public func pause() {
        state = .paused
        stateCallback?(EmulatorState.paused.rawValue, "Paused")
    }

    public func resume() {
        state = .running
        stateCallback?(EmulatorState.running.rawValue, "Resumed")
    }

    // MARK: - Emulation Loop

    public func runFrame() -> Bool {
        guard let handle = nativeHandle, state == .running else { return false }

        let startTime = DispatchTime.now().uptimeNanoseconds
        gbaCoreRunFrame(handle)
        frameCount += 1

        // Get video frame
        if let vb = gbaCoreGetVideoBuffer(handle) {
            convertVideoBuffer(vb)
            let frame = FrameData(
                pixels: &frameBuffer,
                width: 240,
                height: 160,
                stride: 240 * 4,
                timestamp: UInt64(startTime),
                ready: true
            )
            frameCallback?(frame)
        }

        // Get audio
        if let ab = gbaCoreGetAudioBuffer(handle) {
            convertAudioBuffer(ab)
            let audio = AudioData(
                samples: &audioBuffer,
                sampleCount: min(ab.size / 2, audioBuffer.count),
                sampleRate: ab.sampleRate,
                timestamp: UInt64(startTime)
            )
            audioCallback?(audio)
        }

        // Calculate FPS
        let elapsed = DispatchTime.now().uptimeNanoseconds - startTime
        fps = Int(1_000_000_000 / max(elapsed, 1))

        return true
    }

    public func setKeys(_ keys: UInt32) {
        guard let handle = nativeHandle else { return }
        gbaCoreSetKeys(handle, keys)
    }

    public func setSensor(_ type: SensorType, x: Float, y: Float, z: Float) {
        guard let handle = nativeHandle else { return }
        gbaCoreSetSensor(handle, type.rawValue, x, y, z)
    }

    // MARK: - Save States

    public func saveState() -> Data? {
        guard let handle = nativeHandle else { return nil }
        let size = gbaCoreSaveStateSize(handle)
        var data = Data(count: size)
        let result = data.withUnsafeMutableBytes { bytes in
            gbaCoreSaveState(handle, bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), size)
        }
        if result {
            saveCallback?(data)
            return data
        }
        return nil
    }

    public func loadState(_ data: Data) -> Bool {
        guard let handle = nativeHandle else { return false }
        return data.withUnsafeBytes { bytes in
            gbaCoreLoadState(handle, bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), data.count)
        }
    }

    public func saveBattery() -> Data? {
        guard let handle = nativeHandle else { return nil }
        let size = gbaCoreSaveBatterySize(handle)
        var data = Data(count: size)
        let result = data.withUnsafeMutableBytes { bytes in
            gbaCoreSaveBattery(handle, bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), size)
        }
        if result {
            saveCallback?(data)
            return data
        }
        return nil
    }

    public func loadBattery(_ data: Data) -> Bool {
        guard let handle = nativeHandle else { return false }
        return data.withUnsafeBytes { bytes in
            gbaCoreLoadBattery(handle, bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), data.count)
        }
    }

    // MARK: - Cheats

    public func addCheat(_ cheat: CheatCode) {
        guard let handle = nativeHandle else { return }
        gbaCoreAddCheat(
            handle,
            cheat.address,
            cheat.value,
            cheat.mask,
            cheat.enabled,
            cheat.description,
            Int32(cheat.type)
        )
    }

    public func enableCheat(at index: Int, enabled: Bool) {
        guard let handle = nativeHandle else { return }
        gbaCoreEnableCheat(handle, Int32(index), enabled)
    }

    public func clearCheats() {
        guard let handle = nativeHandle else { return }
        gbaCoreClearCheats(handle)
    }

    public func getCheats() -> [CheatCode] {
        guard let handle = nativeHandle else { return [] }
        let count = gbaCoreGetCheatCount(handle)
        var cheats: [CheatCode] = []

        for i in 0..<count {
            var addr: UInt32 = 0
            var val: UInt16 = 0
            var mask: UInt16 = 0
            var enabled: Bool = false
            var desc = [CChar](repeating: 0, count: 256)
            var type: Int32 = 0

            gbaCoreGetCheatInfo(handle, Int32(i), &addr, &val, &mask, &enabled, &desc, &type)
            let descStr = String(cString: desc)
            cheats.append(CheatCode(
                address: addr,
                value: val,
                mask: mask,
                enabled: enabled,
                description: descStr,
                type: Int(type)
            ))
        }
        return cheats
    }

    // MARK: - Configuration

    public func setConfig(_ config: EmulatorConfig) {
        guard let handle = nativeHandle else { return }
        // Apply config to mGBA core
        // This would call native config functions
    }

    public func getConfig() -> EmulatorConfig {
        return EmulatorConfig() // Return current config
    }

    public func getGameInfo() -> GameInfo? {
        guard let handle = nativeHandle else { return nil }

        var info = GameInfo()
        let result = withUnsafeMutableBytes(of: &info) { bytes in
            gbaCoreGetGameInfo(
                handle,
                bytes.bindMemory(to: CChar.self).baseAddress!,
                bytes.bindMemory(to: CChar.self).baseAddress!.advanced(by: 12),
                bytes.bindMemory(to: CChar.self).baseAddress!.advanced(by: 16),
                bytes.bindMemory(to: UInt8.self).baseAddress!.advanced(by: 18),
                bytes.bindMemory(to: Bool.self).baseAddress!,
                bytes.bindMemory(to: Bool.self).baseAddress!.advanced(by: 1),
                bytes.bindMemory(to: Bool.self).baseAddress!.advanced(by: 2),
                bytes.bindMemory(to: Bool.self).baseAddress!.advanced(by: 3),
                bytes.bindMemory(to: UInt32.self).baseAddress!.advanced(by: 1),
                bytes.bindMemory(to: UInt32.self).baseAddress!.advanced(by: 2)
            )
        }
        return result ? info : nil
    }

    public func getRTC() -> RTCTime? {
        guard let handle = nativeHandle else { return nil }
        var rtc = RTCTime()
        gbaCoreGetRTC(handle,
                      &rtc.year, &rtc.month, &rtc.day,
                      &rtc.hour, &rtc.minute, &rtc.second,
                      &rtc.dayOfWeek)
        return rtc
    }

    public func setRTC(_ rtc: RTCTime) {
        guard let handle = nativeHandle else { return }
        gbaCoreSetRTC(handle,
                      Int32(rtc.year), Int32(rtc.month), Int32(rtc.day),
                      Int32(rtc.hour), Int32(rtc.minute), Int32(rtc.second),
                      Int32(rtc.dayOfWeek))
    }

    // MARK: - Callbacks

    public func setCallbacks(
        frame: FrameCallback?,
        audio: AudioCallback?,
        save: SaveCallback?,
        log: LogCallback?,
        state: StateCallback?
    ) {
        self.frameCallback = frame
        self.audioCallback = audio
        self.saveCallback = save
        self.logCallback = log
        self.stateCallback = state
    }

    public func clearError() {
        guard let handle = nativeHandle else { return }
        gbaCoreClearError(handle)
        lastError = nil
    }

    // MARK: - Emulation Loop Management

    public func start() {
        guard state != .running else { return }
        state = .running
        stateCallback?(EmulatorState.running.rawValue, "Started")

        emulationTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.emulationLoop()
        }
    }

    public func stop() {
        emulationTask?.cancel()
        emulationTask = nil
        state = .paused
        stateCallback?(EmulatorState.paused.rawValue, "Stopped")
    }

    private func emulationLoop() async {
        while !Task.isCancelled && state == .running {
            let startTime = DispatchTime.now().uptimeNanoseconds
            _ = runFrame()
            let elapsed = DispatchTime.now().uptimeNanoseconds - startTime

            // Frame pacing - target 60 FPS (16.67ms)
            let targetFrameTime: UInt64 = 16_666_667
            if elapsed < targetFrameTime {
                let sleepTime = targetFrameTime - elapsed
                try? await Task.sleep(nanoseconds: sleepTime)
            }
        }
    }

    // MARK: - Buffer Conversion

    private func convertVideoBuffer(_ vb: UnsafeRawPointer) {
        // Convert mGBA's RGB565 to RGBA8888
        let src = vb.assumingMemoryBound(to: UInt16.self)
        for i in 0..<(240 * 160) {
            let pixel = src[i]
            let r = UInt32((pixel >> 0) & 0x1F) << 3
            let g = UInt32((pixel >> 5) & 0x1F) << 3
            let b = UInt32((pixel >> 10) & 0x1F) << 3
            frameBuffer[i] = 0xFF000000 | (r << 16) | (g << 8) | b
        }
    }

    private func convertAudioBuffer(_ ab: UnsafeRawPointer) {
        // Copy audio data
        let src = ab.assumingMemoryBound(to: Int16.self)
        let count = min(ab.load(as: Int32.self, atByteOffset: 8) / 2, audioBuffer.count) // size field
        audioBuffer.withUnsafeMutableBufferPointer { dest in
            dest.initialize(from: UnsafeBufferPointer(start: src, count: count))
        }
    }
}

// MARK: - Errors

public enum EmulatorError: LocalizedError {
    case notInitialized
    case loadFailed(String)
    case saveFailed(String)
    case invalidROM
    case biosRequired

    public var errorDescription: String? {
        switch self {
        case .notInitialized: return "Emulator not initialized"
        case .loadFailed(let msg): return "Failed to load: \(msg)"
        case .saveFailed(let msg): return "Failed to save: \(msg)"
        case .invalidROM: return "Invalid ROM file"
        case .biosRequired: return "BIOS required for this game"
        }
    }
}

// MARK: - Native Function Declarations (C Bridge)

@_silgen_name("gbaCoreCreate")
func gbaCoreCreate() -> OpaquePointer?

@_silgen_name("gbaCoreDestroy")
func gbaCoreDestroy(_ handle: OpaquePointer)

@_silgen_name("gbaCoreLoadROM")
func gbaCoreLoadROM(_ handle: OpaquePointer, _ data: UnsafePointer<UInt8>?, _ size: Int) -> Bool

@_silgen_name("gbaCoreLoadBIOS")
func gbaCoreLoadBIOS(_ handle: OpaquePointer, _ data: UnsafePointer<UInt8>?, _ size: Int) -> Bool

@_silgen_name("gbaCoreUnloadROM")
func gbaCoreUnloadROM(_ handle: OpaquePointer)

@_silgen_name("gbaCoreReset")
func gbaCoreReset(_ handle: OpaquePointer)

@_silgen_name("gbaCoreRunFrame")
func gbaCoreRunFrame(_ handle: OpaquePointer)

@_silgen_name("gbaCoreSetKeys")
func gbaCoreSetKeys(_ handle: OpaquePointer, _ keys: UInt32)

@_silgen_name("gbaCoreSetSensor")
func gbaCoreSetSensor(_ handle: OpaquePointer, _ type: Int32, _ x: Float, _ y: Float, _ z: Float)

@_silgen_name("gbaCoreGetVideoBuffer")
func gbaCoreGetVideoBuffer(_ handle: OpaquePointer) -> UnsafeRawPointer?

@_silgen_name("gbaCoreGetAudioBuffer")
func gbaCoreGetAudioBuffer(_ handle: OpaquePointer) -> UnsafeRawPointer?

@_silgen_name("gbaCoreSaveStateSize")
func gbaCoreSaveStateSize(_ handle: OpaquePointer) -> Int

@_silgen_name("gbaCoreSaveState")
func gbaCoreSaveState(_ handle: OpaquePointer, _ data: UnsafeMutablePointer<UInt8>?, _ size: Int) -> Bool

@_silgen_name("gbaCoreLoadState")
func gbaCoreLoadState(_ handle: OpaquePointer, _ data: UnsafePointer<UInt8>?, _ size: Int) -> Bool

@_silgen_name("gbaCoreSaveBatterySize")
func gbaCoreSaveBatterySize(_ handle: OpaquePointer) -> Int

@_silgen_name("gbaCoreSaveBattery")
func gbaCoreSaveBattery(_ handle: OpaquePointer, _ data: UnsafeMutablePointer<UInt8>?, _ size: Int) -> Bool

@_silgen_name("gbaCoreLoadBattery")
func gbaCoreLoadBattery(_ handle: OpaquePointer, _ data: UnsafePointer<UInt8>?, _ size: Int) -> Bool

@_silgen_name("gbaCoreAddCheat")
func gbaCoreAddCheat(_ handle: OpaquePointer, _ addr: UInt32, _ val: UInt16, _ mask: UInt16, _ enabled: Bool, _ desc: UnsafePointer<CChar>?, _ type: Int32)

@_silgen_name("gbaCoreEnableCheat")
func gbaCoreEnableCheat(_ handle: OpaquePointer, _ index: Int32, _ enabled: Bool)

@_silgen_name("gbaCoreClearCheats")
func gbaCoreClearCheats(_ handle: OpaquePointer)

@_silgen_name("gbaCoreGetCheatCount")
func gbaCoreGetCheatCount(_ handle: OpaquePointer) -> Int32

@_silgen_name("gbaCoreGetCheatInfo")
func gbaCoreGetCheatInfo(_ handle: OpaquePointer, _ index: Int32, _ addr: UnsafeMutablePointer<UInt32>, _ val: UnsafeMutablePointer<UInt16>, _ mask: UnsafeMutablePointer<UInt16>, _ enabled: UnsafeMutablePointer<Bool>, _ desc: UnsafeMutablePointer<CChar>, _ type: UnsafeMutablePointer<Int32>)

@_silgen_name("gbaCoreGetGameInfo")
func gbaCoreGetGameInfo(_ handle: OpaquePointer, _ title: UnsafeMutablePointer<CChar>, _ gameCode: UnsafeMutablePointer<CChar>, _ makerCode: UnsafeMutablePointer<CChar>, _ saveType: UnsafeMutablePointer<UInt8>, _ hasRTC: UnsafeMutablePointer<Bool>, _ hasGyro: UnsafeMutablePointer<Bool>, _ hasSolar: UnsafeMutablePointer<Bool>, _ hasRumble: UnsafeMutablePointer<Bool>, _ romSize: UnsafeMutablePointer<UInt32>, _ crc32: UnsafeMutablePointer<UInt32>) -> Bool

@_silgen_name("gbaCoreGetRTC")
func gbaCoreGetRTC(_ handle: OpaquePointer, _ year: UnsafeMutablePointer<Int32>, _ month: UnsafeMutablePointer<Int32>, _ day: UnsafeMutablePointer<Int32>, _ hour: UnsafeMutablePointer<Int32>, _ minute: UnsafeMutablePointer<Int32>, _ second: UnsafeMutablePointer<Int32>, _ dow: UnsafeMutablePointer<Int32>)

@_silgen_name("gbaCoreSetRTC")
func gbaCoreSetRTC(_ handle: OpaquePointer, _ year: Int32, _ month: Int32, _ day: Int32, _ hour: Int32, _ minute: Int32, _ second: Int32, _ dow: Int32)

@_silgen_name("gbaCoreGetError")
func gbaCoreGetError(_ handle: OpaquePointer) -> UnsafePointer<CChar>

@_silgen_name("gbaCoreClearError")
func gbaCoreClearError(_ handle: OpaquePointer)