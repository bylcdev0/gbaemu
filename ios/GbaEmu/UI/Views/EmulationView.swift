//
//  EmulationView.swift
//  GbaEmuUI
//
//  Main emulation screen with virtual gamepad
//

import SwiftUI
import CoreGraphics
import GbaEmuCore

struct EmulationView: View {
    let game: GameItem
    @Environment(\.dismiss) private var dismiss

    @StateObject private var emulator = EmulationViewModel()
    @State private var showingMenu = false
    @State private var showingSaveStates = false
    @State private var showingCheats = false
    @State private var fastForward = false

    var body: some View {
        ZStack {
            // Game screen
            GameScreenView(
                frameBuffer: emulator.frameBuffer,
                width: 240,
                height: 160,
                scale: emulator.videoScale
            )
            .ignoresSafeArea()
            .onTapGesture(count: 2) {
                fastForward.toggle()
                emulator.setFastForward(fastForward)
            }

            // Virtual gamepad
            VStack {
                Spacer()
                VirtualGamepadView(
                    buttonStates: $emulator.buttonStates,
                    onDPadPress: { direction, pressed in
                        emulator.setDPad(direction, pressed: pressed)
                    },
                    onButtonPress: { button, pressed in
                        emulator.setButton(button, pressed: pressed)
                    },
                    onShoulderPress: { shoulder, pressed in
                        emulator.setShoulder(shoulder, pressed: pressed)
                    }
                )
                .padding(.bottom, 20)
            }

            // Top toolbar
            VStack {
                HStack {
                    // FPS counter
                    if emulator.showFPS {
                        Text("FPS: \(emulator.fps)")
                            .font(.caption.monospaced())
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }

                    Spacer()

                    // Menu button
                    Button(action: { showingMenu = true }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title2)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding()
                Spacer()
            }

            // Pause menu overlay
            if showingMenu {
                PauseMenuView(
                    onResume: { showingMenu = false },
                    onSaveState: { showingSaveStates = true },
                    onLoadState: { showingSaveStates = true },
                    onCheats: { showingCheats = true; showingMenu = false },
                    onReset: { emulator.reset() },
                    onQuit: { dismiss() }
                )
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            emulator.startEmulation(game: game)
        }
        .onDisappear {
            emulator.stopEmulation()
        }
        .sheet(isPresented: $showingSaveStates) {
            SaveStateView(emulator: emulator)
        }
        .sheet(isPresented: $showingCheats) {
            CheatListView(emulator: emulator)
        }
    }
}

// MARK: - Game Screen

struct GameScreenView: View {
    let frameBuffer: [UInt32]
    let width: Int
    let height: Int
    let scale: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let aspectRatio = CGFloat(width) / CGFloat(height)
            let containerWidth = geometry.size.width
            let containerHeight = geometry.size.height
            let fittedWidth = min(containerWidth, containerHeight * aspectRatio) * scale
            let fittedHeight = fittedWidth / aspectRatio

            // Convert buffer to image
            if let image = bufferToImage() {
                Image(decorative: image, scale: 1.0)
                    .interpolation(.none)
                    .frame(width: fittedWidth, height: fittedHeight)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            } else {
                // Placeholder
                Rectangle()
                    .fill(Color.black)
                    .frame(width: fittedWidth, height: fittedHeight)
                    .overlay(
                        Text("Carregando...")
                            .foregroundColor(.white)
                    )
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }

    private func bufferToImage() -> CGImage? {
        guard !frameBuffer.isEmpty else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)

        let data = frameBuffer.withUnsafeBufferPointer { ptr in
            return Data(buffer: ptr)
        }

        return data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return nil }
            let context = CGContext(
                data: UnsafeMutableRawPointer(mutating: baseAddress),
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            )
            return context?.makeImage()
        }
    }
}

// MARK: - Virtual Gamepad

struct VirtualGamepadView: View {
    @Binding var buttonStates: [GamepadButton: Bool]

    let onDPadPress: (DPadDirection, Bool) -> Void
    let onButtonPress: (ActionButton, Bool) -> Void
    let onShoulderPress: (ShoulderButton, Bool) -> Void

    var body: some View {
        VStack(spacing: 16) {
            // D-Pad
            DPadView(
                upPressed: buttonStates[.up] ?? false,
                downPressed: buttonStates[.down] ?? false,
                leftPressed: buttonStates[.left] ?? false,
                rightPressed: buttonStates[.right] ?? false,
                onPress: onDPadPress
            )

            HStack(spacing: 20) {
                // Select/Start
                HStack(spacing: 40) {
                    ShoulderButtonView(
                        label: "SELECT",
                        pressed: buttonStates[.select] ?? false,
                        action: { onButtonPress(.select, $0) }
                    )
                    ShoulderButtonView(
                        label: "START",
                        pressed: buttonStates[.start] ?? false,
                        action: { onButtonPress(.start, $0) }
                    )
                }

                Spacer()

                // A/B Buttons
                HStack(spacing: 20) {
                    ActionButtonView(
                        label: "B",
                        pressed: buttonStates[.b] ?? false,
                        color: .red,
                        action: { onButtonPress(.b, $0) }
                    )
                    ActionButtonView(
                        label: "A",
                        pressed: buttonStates[.a] ?? false,
                        color: .green,
                        action: { onButtonPress(.a, $0) }
                    )
                }
            }
            .padding(.horizontal, 40)

            // L/R Shoulders
            HStack {
                ShoulderButtonView(
                    label: "L",
                    pressed: buttonStates[.l] ?? false,
                    isShoulder: true,
                    action: { onShoulderPress(.l, $0) }
                )
                Spacer()
                ShoulderButtonView(
                    label: "R",
                    pressed: buttonStates[.r] ?? false,
                    isShoulder: true,
                    action: { onShoulderPress(.r, $0) }
                )
            }
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - D-Pad

struct DPadView: View {
    let upPressed: Bool
    let downPressed: Bool
    let leftPressed: Bool
    let rightPressed: Bool
    let onPress: (DPadDirection, Bool) -> Void

    var body: some View {
        ZStack {
            // Up
            DPadButton(
                direction: .up,
                pressed: upPressed,
                icon: "chevron.up",
                onPress: onPress
            )
            .offset(y: -50)

            // Down
            DPadButton(
                direction: .down,
                pressed: downPressed,
                icon: "chevron.down",
                onPress: onPress
            )
            .offset(y: 50)

            // Left
            DPadButton(
                direction: .left,
                pressed: leftPressed,
                icon: "chevron.left",
                onPress: onPress
            )
            .offset(x: -50)

            // Right
            DPadButton(
                direction: .right,
                pressed: rightPressed,
                icon: "chevron.right",
                onPress: onPress
            )
            .offset(x: 50)

            // Center
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
        }
        .frame(width: 160, height: 160)
    }
}

struct DPadButton: View {
    let direction: DPadDirection
    let pressed: Bool
    let icon: String
    let onPress: (DPadDirection, Bool) -> Void

    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(pressed ? .white : .primary)
                .frame(width: 50, height: 50)
                .background(pressed ? Color.blue : Color.gray.opacity(0.3))
                .cornerRadius(12)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress(direction, true) }
                .onEnded { _ in onPress(direction, false) }
        )
    }
}

// MARK: - Action Buttons

struct ActionButtonView: View {
    let label: String
    let pressed: Bool
    let color: Color
    let action: (Bool) -> Void

    var body: some View {
        Button(action: {}) {
            Text(label)
                .font(.title.bold())
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(pressed ? color : color.opacity(0.7))
                .clipShape(Circle())
                .shadow(color: color.opacity(0.5), radius: pressed ? 2 : 8, y: pressed ? 1 : 4)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in action(true) }
                .onEnded { _ in action(false) }
        )
        .scaleEffect(pressed ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.05), value: pressed)
    }
}

// MARK: - Shoulder Buttons

struct ShoulderButtonView: View {
    let label: String
    let pressed: Bool
    let isShoulder: Bool
    let action: (Bool) -> Void

    var body: some View {
        Button(action: {}) {
            Text(label)
                .font(.headline.bold())
                .foregroundColor(pressed ? .white : .primary)
                .frame(width: isShoulder ? 80 : 60, height: isShoulder ? 40 : 60)
                .background(pressed ? Color.blue : Color.gray.opacity(0.3))
                .cornerRadius(isShoulder ? 8 : 30)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in action(true) }
                .onEnded { _ in action(false) }
        )
    }
}

// MARK: - Pause Menu

struct PauseMenuView: View {
    let onResume: () -> Void
    let onSaveState: () -> Void
    let onLoadState: () -> Void
    let onCheats: () -> Void
    let onReset: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onResume() }

            VStack(spacing: 20) {
                Text("PAUSADO")
                    .font(.largeTitle.bold())

                MenuButton(title: "Continuar", icon: "play.fill", action: onResume)
                MenuButton(title: "Salvar Estado", icon: "square.and.arrow.down.fill", action: onSaveState)
                MenuButton(title: "Carregar Estado", icon: "square.and.arrow.up.fill", action: onLoadState)
                MenuButton(title: "Cheats", icon: "wand.and.stars", action: onCheats)
                MenuButton(title: "Reiniciar Jogo", icon: "arrow.clockwise", action: onReset, destructive: true)
                MenuButton(title: "Sair", icon: "xmark.circle.fill", action: onQuit, destructive: true)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding()
        }
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var destructive: Bool = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(destructive ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
            .foregroundColor(destructive ? .red : .primary)
            .cornerRadius(12)
        }
    }
}

// MARK: - Save State View

struct SaveStateView: View {
    @ObservedObject var emulator: EmulationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Salvar Estado") {
                    ForEach(0..<10) { slot in
                        HStack {
                            Text("Slot \(slot)")
                            Spacer()
                            Button("Salvar") {
                                emulator.saveState(slot: slot)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                Section("Estados Salvos") {
                    ForEach(emulator.savedStates) { state in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Slot \(state.slot)")
                                Text(state.date, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Carregar") {
                                emulator.loadState(slot: state.slot)
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle("Estados de Jogo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Cheat List View

struct CheatListView: View {
    @ObservedObject var emulator: EmulationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddCheat = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(emulator.cheats) { cheat in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(cheat.description.isEmpty ? "Cheat \(cheat.address, format: .hex)" : cheat.description)
                                .font(.headline)
                            Text("0x\(cheat.address, format: .hex) = 0x\(cheat.value, format: .hex)")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { cheat.enabled },
                            set: { emulator.enableCheat(cheat, enabled: $0) }
                        ))
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        emulator.removeCheat(at: index)
                    }
                }
            }
            .navigationTitle("Cheats")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddCheat = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddCheat) {
                AddCheatView(emulator: emulator)
            }
        }
    }
}

struct AddCheatView: View {
    @ObservedObject var emulator: EmulationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var value = ""
    @State private var description = ""
    @State private var type = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Código") {
                    TextField("Endereço (hex)", text: $address)
                        .textInputAutocapitalization(.characters)
                    TextField("Valor (hex)", text: $value)
                        .textInputAutocapitalization(.characters)
                }

                Section("Descrição") {
                    TextField("Nome do cheat", text: $description)
                }

                Section("Tipo") {
                    Picker("Tipo", selection: $type) {
                        Text("Action Replay").tag(0)
                        Text("GameShark").tag(1)
                        Text("CodeBreaker").tag(2)
                    }
                }
            }
            .navigationTitle("Adicionar Cheat")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Adicionar") {
                        if let addr = UInt32(address, radix: 16),
                           let val = UInt16(value, radix: 16) {
                            let cheat = CheatCode(
                                address: addr,
                                value: val,
                                mask: 0xFFFF,
                                enabled: true,
                                description: description,
                                type: type
                            )
                            emulator.addCheat(cheat)
                            dismiss()
                        }
                    }
                    .disabled(address.isEmpty || value.isEmpty)
                }
            }
        }
    }
}

// MARK: - Gamepad Types

enum DPadDirection: CaseIterable {
    case up, down, left, right
}

enum ActionButton: CaseIterable {
    case a, b, start, select
}

enum ShoulderButton: CaseIterable {
    case l, r
}

enum GamepadButton: Hashable {
    case up, down, left, right
    case a, b, start, select
    case l, r
}

// MARK: - Emulation ViewModel

@MainActor
class EmulationViewModel: ObservableObject {
    @Published var frameBuffer: [UInt32] = Array(repeating: 0, count: 240 * 160)
    @Published var buttonStates: [GamepadButton: Bool] = [:]
    @Published var fps: Int = 0
    @Published var showFPS: Bool = false
    @Published var savedStates: [SaveStateInfo] = []
    @Published var cheats: [CheatCode] = []
    @Published var videoScale: CGFloat = 1.0

    private var core: GbaCore?
    private var emulationTask: Task<Void, Never>?
    private var currentKeys: UInt32 = 0

    struct SaveStateInfo: Identifiable {
        let id = UUID()
        let slot: Int
        let date: Date
    }

    func startEmulation(game: GameItem) {
        core = GbaCore()

        do {
            let data = try Data(contentsOf: game.url)
            try core?.loadROM(data)

            // Set up callbacks
            core?.setCallbacks(
                frame: { [weak self] frame in
                    Task { @MainActor in
                        self?.frameBuffer = Array(UnsafeBufferPointer(
                            start: frame.pixels.assumingMemoryBound(to: UInt32.self),
                            count: frame.width * frame.height
                        ))
                    }
                },
                audio: { [weak self] audio in
                    // Play audio via AVAudioEngine
                },
                save: { [weak self] data in
                    // Auto-save battery
                },
                log: { level, message in
                    print("[GBA] \(message)")
                },
                state: { [weak self] state, message in
                    Task { @MainActor in
                        // Handle state changes
                    }
                }
            )

            core?.start()
        } catch {
            print("Failed to start emulation: \(error)")
        }
    }

    func stopEmulation() {
        core?.stop()
        core = nil
        emulationTask?.cancel()
        emulationTask = nil
    }

    func setDPad(_ direction: DPadDirection, pressed: Bool) {
        updateKeyState(direction, pressed: pressed)
    }

    func setButton(_ button: ActionButton, pressed: Bool) {
        updateKeyState(button, pressed: pressed)
    }

    func setShoulder(_ shoulder: ShoulderButton, pressed: Bool) {
        updateKeyState(shoulder, pressed: pressed)
    }

    private func updateKeyState(_ input: Any, pressed: Bool) {
        var keyBit: UInt32 = 0

        if let dir = input as? DPadDirection {
            switch dir {
            case .up: keyBit = 1 << 6
            case .down: keyBit = 1 << 7
            case .left: keyBit = 1 << 5
            case .right: keyBit = 1 << 4
            }
        } else if let btn = input as? ActionButton {
            switch btn {
            case .a: keyBit = 1 << 0
            case .b: keyBit = 1 << 1
            case .start: keyBit = 1 << 3
            case .select: keyBit = 1 << 2
            }
        } else if let shoulder = input as? ShoulderButton {
            switch shoulder {
            case .l: keyBit = 1 << 9
            case .r: keyBit = 1 << 8
            }
        }

        if pressed {
            currentKeys |= keyBit
        } else {
            currentKeys &= ~keyBit
        }

        core?.setKeys(currentKeys)
    }

    func setFastForward(_ enabled: Bool) {
        // Implement fast forward by reducing frame delay
    }

    func reset() {
        core?.reset()
    }

    func saveState(slot: Int) {
        if let data = core?.saveState() {
            // Save to file
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("state_\(slot).sav")
            try? data.write(to: url)
            savedStates.append(SaveStateInfo(slot: slot, date: Date()))
        }
    }

    func loadState(slot: Int) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("state_\(slot).sav")
        if let data = try? Data(contentsOf: url) {
            _ = core?.loadState(data)
        }
    }

    func addCheat(_ cheat: CheatCode) {
        core?.addCheat(cheat)
        cheats.append(cheat)
    }

    func enableCheat(_ cheat: CheatCode, enabled: Bool) {
        if let index = cheats.firstIndex(where: { $0.id == cheat.id }) {
            cheats[index].enabled = enabled
            core?.enableCheat(at: index, enabled: enabled)
        }
    }

    func removeCheat(at index: Int) {
        core?.enableCheat(at: index, enabled: false)
        cheats.remove(at: index)
    }
}

// MARK: - Preview

#Preview {
    EmulationView(game: GameItem(
        url: URL(fileURLWithPath: "/test.gba"),
        title: "Pokémon FireRed",
        gameCode: "BPRE",
        region: "U",
        fileSize: 16777216,
        lastPlayed: Date()
    ))
}