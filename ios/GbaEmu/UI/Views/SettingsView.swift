//
//  SettingsView.swift
//  GbaEmuUI
//
//  Settings screen with all emulator options
//

import SwiftUI
import GbaEmuCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("videoFilter") private var videoFilter: VideoFilter = .bilinear
    @AppStorage("videoScale") private var videoScale: Double = 1.0
    @AppStorage("frameskip") private var frameskip: Int = 0
    @AppStorage("vsync") private var vsync: Bool = true
    @AppStorage("audioEnabled") private var audioEnabled: Bool = true
    @AppStorage("audioVolume") private var audioVolume: Double = 1.0
    @AppStorage("audioSampleRate") private var audioSampleRate: Int = 44100
    @AppStorage("saveType") private var saveType: SaveType = .autoDetect
    @AppStorage("rtcEnabled") private var rtcEnabled: Bool = true
    @AppStorage("showFPS") private var showFPS: Bool = false
    @AppStorage("controllerVibration") private var controllerVibration: Bool = true
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = true
    @AppStorage("autoSaveState") private var autoSaveState: Bool = true
    @AppStorage("autoSaveInterval") private var autoSaveInterval: Int = 300 // seconds
    @AppStorage("fastForwardSpeed") private var fastForwardSpeed: Double = 2.0
    @AppStorage("biosPath") private var biosPath: String = ""
    @AppStorage("cheatsPath") private var cheatsPath: String = ""

    var body: some View {
        NavigationStack {
            Form {
                // Video Section
                Section("Vídeo") {
                    Picker("Filtro de Escala", selection: $videoFilter) {
                        ForEach(VideoFilter.allCases, id: \.self) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }

                    Slider(value: $videoScale, in: 0.5...3.0, step: 0.25) {
                        Text("Escala: \(videoScale, specifier: "%.2f")x")
                    }

                    Toggle("V-Sync", isOn: $vsync)

                    Stepper("Frameskip: \(frameskip)", value: $frameskip, in: 0...9)

                    Toggle("Mostrar FPS", isOn: $showFPS)
                }

                // Audio Section
                Section("Áudio") {
                    Toggle("Áudio Habilitado", isOn: $audioEnabled)

                    Slider(value: $audioVolume, in: 0.0...2.0, step: 0.1) {
                        Text("Volume: \(Int(audioVolume * 100))%")
                    }

                    Picker("Taxa de Amostragem", selection: $audioSampleRate) {
                        Text("22050 Hz").tag(22050)
                        Text("44100 Hz").tag(44100)
                        Text("48000 Hz").tag(48000)
                    }
                }

                // Save/Load Section
                Section("Salvamento") {
                    Picker("Tipo de Save", selection: $saveType) {
                        ForEach(SaveType.allCases.filter { $0 != .autoDetect }, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    Toggle("RTC (Relógio em Tempo Real)", isOn: $rtcEnabled)

                    Toggle("Auto-save State", isOn: $autoSaveState)

                    if autoSaveState {
                        Stepper("Intervalo: \(autoSaveInterval/60) min", value: $autoSaveInterval, in: 60...3600, step: 60)
                    }
                }

                // Input Section
                Section("Controles") {
                    Toggle("Vibração do Controle", isOn: $controllerVibration)

                    NavigationLink("Configurar Gamepad Virtual") {
                        VirtualGamepadSettingsView()
                    }

                    NavigationLink("Controles Externos (MFi/Bluetooth)") {
                        ExternalControllerSettingsView()
                    }
                }

                // Advanced Section
                Section("Avançado") {
                    Toggle("Manter Tela Ligada", isOn: $keepScreenOn)

                    Slider(value: $fastForwardSpeed, in: 1.0...10.0, step: 0.5) {
                        Text("Velocidade Avanço Rápido: \(fastForwardSpeed, specifier: "%.1f")x")
                    }

                    NavigationLink("BIOS") {
                        BiosSettingsView(biosPath: $biosPath)
                    }

                    NavigationLink("Cheats") {
                        CheatsSettingsView(cheatsPath: $cheatsPath)
                    }
                }

                // About Section
                Section("Sobre") {
                    HStack {
                        Text("Versão")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link("Código Fonte", destination: URL(string: "https://github.com/your-repo/gbaemu")!)
                    Link("mGBA Core", destination: URL(string: "https://mgba.io")!)
                    Link("Licenças", destination: URL(string: "https://github.com/your-repo/gbaemu/blob/main/LICENSES")!)
                }

                // Danger Zone
                Section {
                    Button("Limpar Cache", role: .destructive) {
                        // Clear cache
                    }
                    Button("Resetar Configurações", role: .destructive) {
                        // Reset all settings
                    }
                }
            }
            .navigationTitle("Configurações")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sub Settings Views

struct VirtualGamepadSettingsView: View {
    @AppStorage("gamepadOpacity") private var opacity: Double = 0.8
    @AppStorage("gamepadSize") private var size: Double = 1.0
    @AppStorage("gamepadLayout") private var layout: GamepadLayout = .classic
    @AppStorage("gamepadHapticFeedback") private var hapticFeedback: Bool = true

    var body: some View {
        Form {
            Section("Aparência") {
                Slider(value: $opacity, in: 0.3...1.0, step: 0.1) {
                    Text("Opacidade: \(Int(opacity * 100))%")
                }

                Slider(value: $size, in: 0.7...1.5, step: 0.1) {
                    Text("Tamanho: \(size, specifier: "%.1f")x")
                }

                Picker("Layout", selection: $layout) {
                    ForEach(GamepadLayout.allCases, id: \.self) { layout in
                        Text(layout.displayName).tag(layout)
                    }
                }
            }

            Section("Feedback") {
                Toggle("Feedback Tátil", isOn: $hapticFeedback)
            }

            Section("Personalização Avançada") {
                NavigationLink("Mapeamento de Botões") {
                    ButtonMappingView()
                }
                NavigationLink("Zonas Mortas") {
                    DeadzoneSettingsView()
                }
            }
        }
        .navigationTitle("Gamepad Virtual")
    }
}

enum GamepadLayout: String, CaseIterable {
    case classic = "classic"
    case modern = "modern"
    case compact = "compact"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .classic: return "Clássico (GBA)"
        case .modern: return "Moderno (Xbox/PS)"
        case .compact: return "Compacto"
        case .custom: return "Personalizado"
        }
    }
}

struct ButtonMappingView: View {
    var body: some View {
        Form {
            Section("Mapeamento") {
                Text("Personalize o mapeamento dos botões")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Mapeamento")
    }
}

struct DeadzoneSettingsView: View {
    var body: some View {
        Form {
            Section("Zonas Mortas") {
                Text("Configure zonas mortas para analógicos")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Zonas Mortas")
    }
}

struct ExternalControllerSettingsView: View {
    @AppStorage("autoConnectController") private var autoConnect: Bool = true
    @AppStorage("controllerLayout") private var controllerLayout: ControllerLayout = .auto

    var body: some View {
        Form {
            Section("Conexão") {
                Toggle("Conectar Automaticamente", isOn: $autoConnect)
            }

            Section("Layout") {
                Picker("Layout Padrão", selection: $controllerLayout) {
                    ForEach(ControllerLayout.allCases, id: \.self) { layout in
                        Text(layout.displayName).tag(layout)
                    }
                }
            }

            Section("Controles Conectados") {
                Text("Nenhum controle conectado")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Controles Externos")
    }
}

enum ControllerLayout: String, CaseIterable {
    case auto = "auto"
    case xbox = "xbox"
    case playstation = "playstation"
    case nintendo = "nintendo"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .auto: return "Automático"
        case .xbox: return "Xbox"
        case .playstation: return "PlayStation"
        case .nintendo: return "Nintendo"
        case .custom: return "Personalizado"
        }
    }
}

struct BiosSettingsView: View {
    @Binding var biosPath: String
    @State private var showingPicker = false

    var body: some View {
        Form {
            Section("Arquivo BIOS (Opcional)") {
                Text("O BIOS do GBA melhora a compatibilidade e precisão. Coloque 'gba_bios.bin' na pasta do app.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text(biosPath.isEmpty ? "Não configurado" : biosPath)
                        .foregroundColor(biosPath.isEmpty ? .secondary : .primary)
                    Spacer()
                    Button("Selecionar") {
                        showingPicker = true
                    }
                }
            }

            Section("Informações") {
                Text("SHA256 esperado: a860e8c0b6d573d191e4ec7db1b1e4f6")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("BIOS")
        .fileImporter(isPresented: $showingPicker, allowedContentTypes: [.data]) { result in
            if case .success(let url) = result {
                biosPath = url.path
            }
        }
    }
}

struct CheatsSettingsView: View {
    @Binding var cheatsPath: String
    @State private var showingPicker = false

    var body: some View {
        Form {
            Section("Arquivo de Cheats") {
                Text("Arquivo de cheats no formato .cht (compatível com mGBA/VBA)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text(cheatsPath.isEmpty ? "Não configurado" : cheatsPath)
                        .foregroundColor(cheatsPath.isEmpty ? .secondary : .primary)
                    Spacer()
                    Button("Selecionar") {
                        showingPicker = true
                    }
                }
            }

            Section("Formatos Suportados") {
                Label("Action Replay (.cht)", systemImage: "doc.text")
                Label("GameShark (.gsa)", systemImage: "doc.text")
                Label("CodeBreaker (.cbc)", systemImage: "doc.text")
            }
        }
        .navigationTitle("Cheats")
        .fileImporter(isPresented: $showingPicker, allowedContentTypes: [.data]) { result in
            if case .success(let url) = result {
                cheatsPath = url.path
            }
        }
    }
}

// MARK: - Extensions

extension VideoFilter {
    var displayName: String {
        switch self {
        case .nearest: return "Mais Próximo (Pixel Perfect)"
        case .bilinear: return "Bilinear (Suave)"
        case .scale2x: return "Scale2x"
        case .hq2x: return "HQ2x"
        case .xbr: return "xBR"
        }
    }
}

extension SaveType {
    var displayName: String {
        switch self {
        case .autoDetect: return "Auto Detectar"
        case .none: return "Nenhum"
        case .sram: return "SRAM"
        case .eeprom: return "EEPROM"
        case .flash64k: return "Flash 64K"
        case .flash128k: return "Flash 128K"
        case .flash512k: return "Flash 512K"
        case .flash1m: return "Flash 1M"
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}