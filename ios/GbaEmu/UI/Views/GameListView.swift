//
//  GameListView.swift
//  GbaEmuUI
//
//  Game library browser with grid/list view
//

import SwiftUI
import UniformTypeIdentifiers
import GbaEmuCore

struct GameListView: View {
    @StateObject private var viewModel = GameListViewModel()
    @State private var showingImporter = false
    @State private var selectedGame: GameItem?
    @State private var showingSettings = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.games.isEmpty {
                    EmptyStateView(onImport: { showingImporter = true })
                } else {
                    GameGridView(
                        games: filteredGames,
                        onGameTap: { game in
                            selectedGame = game
                        }
                    )
                }
            }
            .navigationTitle("GBA Emu")
            .searchable(text: $searchText, prompt: "Buscar jogos...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingImporter = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingImporter) {
                DocumentPickerView(onPick: { url in
                    viewModel.importROM(from: url)
                })
            }
            .sheet(item: $selectedGame) { game in
                EmulationView(game: game)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onAppear {
                viewModel.refresh()
            }
        }
    }

    private var filteredGames: [GameItem] {
        if searchText.isEmpty {
            return viewModel.games
        }
        return viewModel.games.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - Game Grid

struct GameGridView: View {
    let games: [GameItem]
    let onGameTap: (GameItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(games) { game in
                    GameCardView(game: game)
                        .onTapGesture {
                            onGameTap(game)
                        }
                        .contextMenu {
                            Button(action: { /* Save state */ }) {
                                Label("Salvar Estado", systemImage: "square.and.arrow.down")
                            }
                            Button(action: { /* Load state */ }) {
                                Label("Carregar Estado", systemImage: "square.and.arrow.up")
                            }
                            Button(action: { /* Cheats */ }) {
                                Label("Cheats", systemImage: "wand.and.stars")
                            }
                            Divider()
                            Button(role: .destructive, action: { /* Delete */ }) {
                                Label("Remover", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
        .refreshable {
            // Pull to refresh handled by viewModel
        }
    }
}

// MARK: - Game Card

struct GameCardView: View {
    let game: GameItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(3/2, contentMode: .fit)
                    .overlay(
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.5))
                    )

                if game.isFavorite {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack {
                    Text(game.gameCode)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)

                    Text(game.region)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if game.lastPlayed > 0 {
                    Text("Jogado \(game.lastPlayedFormatted)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text("Nenhum jogo encontrado")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Adicione ROMs GBA para começar a jogar")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onImport) {
                Label("Importar ROM", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType(filenameExtension: "gba")!,
            UTType(filenameExtension: "zip")!,
            UTType(filenameExtension: "7z")!
        ], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                // Start accessing security-scoped resource
                if url.startAccessingSecurityScopedResource() {
                    onPick(url)
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class GameListViewModel: ObservableObject {
    @Published var games: [GameItem] = []
    @Published var isLoading = false

    private let fileManager = FileManager.default
    private let romDirectories: [URL] = [
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!,
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!,
        URL(fileURLWithPath: "/var/mobile/Containers/Data/Application"),
    ]

    func refresh() {
        isLoading = true
        Task {
            let found = await scanForROMs()
            await MainActor.run {
                self.games = found.sorted { $0.title < $1.title }
                self.isLoading = false
            }
        }
    }

    private func scanForROMs() async -> [GameItem] {
        var found: [GameItem] = []

        // Scan app documents directory
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        if let files = try? fileManager.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) {
            for file in files where isROMExtension(file.pathExtension) {
                found.append(GameItem.fromFile(file))
            }
        }

        return found
    }

    func importROM(from url: URL) {
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destURL = docsURL.appendingPathComponent(url.lastPathComponent)

        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: url, to: destURL)
            refresh()
        } catch {
            print("Failed to import ROM: \(error)")
        }
    }

    private func isROMExtension(_ ext: String) -> Bool {
        ["gba", "zip", "7z"].contains(ext.lowercased())
    }
}

// MARK: - Game Item Model

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
        // In real implementation, parse ROM header
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
    GameListView()
}