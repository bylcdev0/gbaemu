//
//  GbaEmuApp.swift
//  GbaEmu
//
//  Main app entry point
//

import SwiftUI
import GbaEmuCore

@main
struct GbaEmuApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var currentGame: GameItem?
    @Published var isEmulating = false
    @Published var emulatorCore: GbaCore?
    @Published var settings = AppSettings()

    func startGame(_ game: GameItem) {
        currentGame = game
        isEmulating = true
    }

    func stopGame() {
        currentGame = nil
        isEmulating = false
    }
}

struct AppSettings: Codable {
    var videoFilter: VideoFilter = .bilinear
    var videoScale: Double = 1.0
    var frameskip: Int = 0
    var vsync: Bool = true
    var audioEnabled: Bool = true
    var audioVolume: Double = 1.0
    var audioSampleRate: Int = 44100
    var saveType: SaveType = .autoDetect
    var rtcEnabled: Bool = true
    var showFPS: Bool = false
    var controllerVibration: Bool = true
    var keepScreenOn: Bool = true
    var autoSaveState: Bool = true
    var autoSaveInterval: Int = 300
    var fastForwardSpeed: Double = 2.0
    var biosPath: String = ""
    var cheatsPath: String = ""
    var gamepadOpacity: Double = 0.8
    var gamepadSize: Double = 1.0
    var gamepadLayout: GamepadLayout = .classic
    var gamepadHapticFeedback: Bool = true
    var autoConnectController: Bool = true
    var controllerLayout: ControllerLayout = .auto
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isEmulating, let game = appState.currentGame {
                EmulationView(game: game)
                    .environmentObject(appState)
            } else {
                GameListView()
                    .environmentObject(appState)
            }
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }

    private func handleIncomingURL(_ url: URL) {
        // Handle opening ROM files from other apps
        if url.pathExtension.lowercased() == "gba" {
            let game = GameItem.fromFile(url)
            appState.startGame(game)
        }
    }
}

// MARK: - Game Item (Shared)

struct GameItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let title: String
    let gameCode: String
    let region: String
    let fileSize: Int64
    let lastPlayed: Date
    var isFavorite: Bool = false

    var lastPlayedFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastPlayed, relativeTo: Date())
    }

    static func fromFile(_ url: URL) -> GameItem {
        let name = url.deletingPathExtension().lastPathComponent
        return GameItem(
            url: url,
            title: name,
            gameCode: "UNKN",
            region: "?",
            fileSize: (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0,
            lastPlayed: (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
        )
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
}