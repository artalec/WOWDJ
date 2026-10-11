import Foundation

class StorageManager {
    static let shared = StorageManager()
    
    private let appStateKey = "DJPlayer.AppState"
    private let fileManager = FileManager.default
    
    private var appSupportDirectory: URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }
    
    private var storageURL: URL? {
        guard let appSupport = appSupportDirectory else { return nil }
        let appDir = appSupport.appendingPathComponent("DJPlayer", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        
        return appDir.appendingPathComponent("appstate.json")
    }
    
    private init() {}
    
    // MARK: - Save & Load
    
    func save(appState: AppState) {
        guard let url = storageURL else {
            print("Failed to get storage URL")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(appState)
            try data.write(to: url, options: .atomic)
            print("App state saved successfully to: \(url.path)")
        } catch {
            print("Failed to save app state: \(error)")
        }
    }
    
    func load() -> AppState {
        guard let url = storageURL else {
            print("Failed to get storage URL, returning default state")
            return .default
        }
        
        guard fileManager.fileExists(atPath: url.path) else {
            print("No saved state found, returning default")
            return .default
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let appState = try decoder.decode(AppState.self, from: data)
            print("App state loaded successfully from: \(url.path)")
            return appState
        } catch {
            print("Failed to load app state: \(error), returning default")
            return .default
        }
    }
    
    // MARK: - Export & Import Playlists
    
    func exportPlaylist(_ playlist: Playlist, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(playlist)
        try data.write(to: url, options: .atomic)
    }
    
    func importPlaylist(from url: URL) throws -> Playlist {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(Playlist.self, from: data)
    }
    
    // MARK: - Clear Storage
    
    func clearAllData() {
        guard let url = storageURL else { return }
        try? fileManager.removeItem(at: url)
        print("All data cleared")
    }
}
