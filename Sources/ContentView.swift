import SwiftUI

class AppViewModel: ObservableObject {
    @Published var appState: AppState
    @Published var audioEngine: AudioEngine
    @Published var selectedPlaylist: Playlist?
    
    private let storage = StorageManager.shared
    
    init() {
        // Load saved state
        self.appState = storage.load()
        self.audioEngine = AudioEngine()
        
        // Set audio engine settings
        self.audioEngine.settings = appState.settings
        
        // Select saved playlist
        if let selectedID = appState.selectedPlaylistID {
            self.selectedPlaylist = appState.playlists.first { $0.id == selectedID }
        } else {
            self.selectedPlaylist = appState.playlists.first
        }
    }
    
    func save() {
        appState.selectedPlaylistID = selectedPlaylist?.id
        storage.save(appState: appState)
    }
    
    func updateSettings(_ settings: AppSettings) {
        appState.settings = settings
        audioEngine.settings = settings
        save()
    }
}

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    
    @State private var selectedTrackIndex: Int?
    
    var body: some View {
        HSplitView {
            // Left sidebar - Playlists
            PlaylistSidebar(
                playlists: $viewModel.appState.playlists,
                selectedPlaylist: $viewModel.selectedPlaylist
            )
            .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
            
            // Main content
            VStack(spacing: 0) {
                // Top controls and waveform
                VStack(spacing: 12) {
                    // Control buttons
                    HStack {
                        Spacer()
                        
                        // Crossfade controls
                        HStack(spacing: 12) {
                            Toggle(isOn: Binding(
                                get: { viewModel.appState.settings.crossfadeEnabled },
                                set: { enabled in
                                    var settings = viewModel.appState.settings
                                    settings.crossfadeEnabled = enabled
                                    viewModel.updateSettings(settings)
                                }
                            )) {
                                Text("Crossfade")
                            }
                            .toggleStyle(.switch)
                            
                            if viewModel.appState.settings.crossfadeEnabled {
                                Stepper(
                                    value: Binding(
                                        get: { viewModel.appState.settings.crossfadeDuration },
                                        set: { duration in
                                            var settings = viewModel.appState.settings
                                            settings.crossfadeDuration = duration
                                            viewModel.updateSettings(settings)
                                        }
                                    ),
                                    in: 1...10,
                                    step: 0.5
                                ) {
                                    Text("\(viewModel.appState.settings.crossfadeDuration, specifier: "%.1f")s")
                                        .frame(width: 40)
                                }
                            }
                        }
                        
                        Divider()
                            .frame(height: 20)
                        
                        // High-cut filter controls
                        HStack(spacing: 12) {
                            Toggle(isOn: Binding(
                                get: { viewModel.appState.settings.highCutFilterEnabled },
                                set: { enabled in
                                    var settings = viewModel.appState.settings
                                    settings.highCutFilterEnabled = enabled
                                    viewModel.updateSettings(settings)
                                }
                            )) {
                                Text("High-Cut Filter")
                            }
                            .toggleStyle(.switch)
                            
                            if viewModel.appState.settings.highCutFilterEnabled {
                                Stepper(
                                    value: Binding(
                                        get: { viewModel.appState.settings.highCutFilterDuration },
                                        set: { duration in
                                            var settings = viewModel.appState.settings
                                            settings.highCutFilterDuration = duration
                                            viewModel.updateSettings(settings)
                                        }
                                    ),
                                    in: 0.5...5,
                                    step: 0.5
                                ) {
                                    Text("\(viewModel.appState.settings.highCutFilterDuration, specifier: "%.1f")s")
                                        .frame(width: 40)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Waveform display
                    if viewModel.audioEngine.isPlaying {
                        VStack(spacing: 4) {
                            WaveformView(
                                data: viewModel.audioEngine.waveformData,
                                currentTime: viewModel.audioEngine.currentTime,
                                duration: viewModel.audioEngine.currentTrack?.duration ?? 0
                            )
                            .frame(height: 80)
                            
                            // Current track info
                            if let track = viewModel.audioEngine.currentTrack {
                                HStack {
                                    Text(track.name)
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Text(formatTime(viewModel.audioEngine.currentTime))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("/")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(formatTime(track.duration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    } else {
                        // Placeholder for waveform when nothing is playing
                        VStack {
                            Text("Нажмите пробел чтобы воспроизвести трек")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 100)
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Track list
                if let playlist = viewModel.selectedPlaylist,
                   let playlistIndex = viewModel.appState.playlists.firstIndex(where: { $0.id == playlist.id }) {
                    TrackList(
                        playlist: $viewModel.appState.playlists[playlistIndex],
                        onPlayTrack: { track in
                            playTrack(track)
                        }
                    )
                } else {
                    EmptyPlaylistView()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            setupKeyboardShortcuts()
        }
        .onDisappear {
            viewModel.save()
        }
    }
    
    private func playTrack(_ track: Track) {
        viewModel.audioEngine.play(track: track)
    }
    
    private func stopPlayback() {
        viewModel.audioEngine.stop()
    }
    
    private func setupKeyboardShortcuts() {
        // Keyboard shortcuts are handled via onKeyPress in SwiftUI
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 49 { // Space bar
                if let playlist = viewModel.selectedPlaylist,
                   !playlist.tracks.isEmpty {
                    if viewModel.audioEngine.isPlaying {
                        viewModel.audioEngine.pause()
                    } else if viewModel.audioEngine.currentTrack != nil {
                        viewModel.audioEngine.resume()
                    } else {
                        playTrack(playlist.tracks[0])
                    }
                }
                return nil // Consume event
            } else if event.keyCode == 53 { // Escape key
                stopPlayback()
                return nil // Consume event
            }
            return event
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Empty Playlist View

struct EmptyPlaylistView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("Выберите плейлист")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
