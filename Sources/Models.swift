import Foundation
import SwiftUI

// MARK: - Track Model
struct Track: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var url: URL
    var duration: TimeInterval
    
    init(id: UUID = UUID(), name: String, url: URL, duration: TimeInterval = 0) {
        self.id = id
        self.name = name
        self.url = url
        self.duration = duration
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, url, duration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        // Handle URL decoding with bookmark data for security-scoped resources
        if let urlString = try? container.decode(String.self, forKey: .url),
           let decodedURL = URL(string: urlString) {
            url = decodedURL
        } else {
            url = URL(fileURLWithPath: "/")
        }
        
        duration = try container.decode(TimeInterval.self, forKey: .duration)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(url.path, forKey: .url)
        try container.encode(duration, forKey: .duration)
    }
}

// MARK: - Playlist Model
struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var tracks: [Track]
    var color: CodableColor
    var order: Int
    
    init(id: UUID = UUID(), name: String, tracks: [Track] = [], color: CodableColor = CodableColor(.blue), order: Int = 0) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.color = color
        self.order = order
    }
}

// MARK: - Codable Color Wrapper
struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    
    init(_ color: Color) {
        // Convert SwiftUI Color to components
        #if os(macOS)
        let nsColor = NSColor(color)
        self.red = Double(nsColor.redComponent)
        self.green = Double(nsColor.greenComponent)
        self.blue = Double(nsColor.blueComponent)
        self.alpha = Double(nsColor.alphaComponent)
        #else
        self.red = 0.0
        self.green = 0.5
        self.blue = 1.0
        self.alpha = 1.0
        #endif
    }
    
    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

// MARK: - App Settings
struct AppSettings: Codable {
    var crossfadeEnabled: Bool
    var crossfadeDuration: Double // in seconds
    var highCutFilterEnabled: Bool
    var highCutFilterDuration: Double // in seconds
    
    static let `default` = AppSettings(
        crossfadeEnabled: false,
        crossfadeDuration: 3.0,
        highCutFilterEnabled: false,
        highCutFilterDuration: 2.0
    )
}

// MARK: - App State (persisted)
struct AppState: Codable {
    var playlists: [Playlist]
    var settings: AppSettings
    var selectedPlaylistID: UUID?
    
    static let `default` = AppState(
        playlists: [Playlist(name: "Default Playlist", order: 0)],
        settings: .default,
        selectedPlaylistID: nil
    )
}
