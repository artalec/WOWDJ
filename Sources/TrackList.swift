import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct TrackList: View {
    @Binding var playlist: Playlist
    let onPlayTrack: (Track) -> Void
    
    @State private var selectedTrack: Track?
    @State private var isImporting = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with track count
            HStack {
                Text("\(playlist.tracks.count) треков")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { isImporting = true }) {
                    Label("Добавить треки", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Track list
            if playlist.tracks.isEmpty {
                EmptyTrackListView()
            } else {
                List(selection: $selectedTrack) {
                    ForEach(playlist.tracks) { track in
                        TrackRowView(track: track)
                            .tag(track)
                            .contextMenu {
                                Button("Удалить") {
                                    removeTrack(track)
                                }
                            }
                            .onTapGesture(count: 2) {
                                onPlayTrack(track)
                            }
                    }
                    .onMove { from, to in
                        playlist.tracks.move(fromOffsets: from, toOffset: to)
                    }
                    .onDelete { indexSet in
                        playlist.tracks.remove(atOffsets: indexSet)
                    }
                }
                .listStyle(.inset)
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }
    
    private func removeTrack(_ track: Track) {
        playlist.tracks.removeAll { $0.id == track.id }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                // Get security-scoped access
                _ = url.startAccessingSecurityScopedResource()
                
                // Get track info
                let asset = AVAsset(url: url)
                let duration = asset.duration.seconds
                let name = url.deletingPathExtension().lastPathComponent
                
                let track = Track(
                    name: name,
                    url: url,
                    duration: duration
                )
                
                playlist.tracks.append(track)
                
                // Release security-scoped access
                url.stopAccessingSecurityScopedResource()
            }
        case .failure(let error):
            print("Failed to import files: \(error)")
        }
    }
}

// MARK: - Track Row View

struct TrackRowView: View {
    let track: Track
    
    var body: some View {
        HStack {
            Image(systemName: "music.note")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.body)
                    .lineLimit(1)
                
                if track.duration > 0 {
                    Text(formatDuration(track.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Empty State View

struct EmptyTrackListView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Нет треков")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Нажмите \"+\" чтобы добавить треки")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
