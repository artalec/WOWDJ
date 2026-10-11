import SwiftUI

struct PlaylistSidebar: View {
    @Binding var playlists: [Playlist]
    @Binding var selectedPlaylist: Playlist?
    
    @State private var isAddingPlaylist = false
    @State private var newPlaylistName = ""
    @State private var editingPlaylist: Playlist?
    @State private var showColorPicker = false
    @State private var colorPickerPlaylist: Playlist?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Плейлисты")
                    .font(.headline)
                    .padding(.leading, 8)
                
                Spacer()
                
                Button(action: { isAddingPlaylist = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .padding(.trailing, 8)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Playlist list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(playlists.sorted(by: { $0.order < $1.order })) { playlist in
                        PlaylistRow(
                            playlist: playlist,
                            isSelected: selectedPlaylist?.id == playlist.id,
                            onSelect: { selectedPlaylist = playlist },
                            onRename: { editingPlaylist = playlist },
                            onColorChange: {
                                colorPickerPlaylist = playlist
                                showColorPicker = true
                            },
                            onDelete: { deletePlaylist(playlist) }
                        )
                    }
                    .onMove { from, to in
                        movePlaylist(from: from, to: to)
                    }
                }
                .padding(4)
            }
        }
        .frame(minWidth: 200, idealWidth: 250)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $isAddingPlaylist) {
            AddPlaylistSheet(
                playlistName: $newPlaylistName,
                onAdd: { addNewPlaylist() },
                onCancel: { isAddingPlaylist = false }
            )
        }
        .sheet(item: $editingPlaylist) { playlist in
            RenamePlaylistSheet(
                playlist: playlist,
                onRename: { newName in renamePlaylist(playlist, to: newName) },
                onCancel: { editingPlaylist = nil }
            )
        }
        .sheet(isPresented: $showColorPicker) {
            if let playlist = colorPickerPlaylist {
                ColorPickerSheet(
                    playlist: playlist,
                    onColorChange: { color in updatePlaylistColor(playlist, to: color) },
                    onCancel: { showColorPicker = false }
                )
            }
        }
    }
    
    private func addNewPlaylist() {
        let name = newPlaylistName.isEmpty ? "Новый плейлист" : newPlaylistName
        let newOrder = (playlists.map { $0.order }.max() ?? -1) + 1
        let newPlaylist = Playlist(name: name, order: newOrder)
        playlists.append(newPlaylist)
        selectedPlaylist = newPlaylist
        newPlaylistName = ""
        isAddingPlaylist = false
    }
    
    private func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        if selectedPlaylist?.id == playlist.id {
            selectedPlaylist = playlists.first
        }
    }
    
    private func renamePlaylist(_ playlist: Playlist, to newName: String) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[index].name = newName
        }
        editingPlaylist = nil
    }
    
    private func updatePlaylistColor(_ playlist: Playlist, to color: CodableColor) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[index].color = color
        }
        showColorPicker = false
        colorPickerPlaylist = nil
    }
    
    private func movePlaylist(from source: IndexSet, to destination: Int) {
        var sortedPlaylists = playlists.sorted(by: { $0.order < $1.order })
        sortedPlaylists.move(fromOffsets: source, toOffset: destination)
        
        for (index, playlist) in sortedPlaylists.enumerated() {
            if let playlistIndex = playlists.firstIndex(where: { $0.id == playlist.id }) {
                playlists[playlistIndex].order = index
            }
        }
    }
}

// MARK: - Playlist Row

struct PlaylistRow: View {
    let playlist: Playlist
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onColorChange: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(playlist.color.color)
                .frame(width: 12, height: 12)
            
            Text(playlist.name)
                .font(.body)
                .lineLimit(1)
            
            Spacer()
            
            if isHovering {
                Menu {
                    Button("Переименовать") { onRename() }
                    Button("Изменить цвет") { onColorChange() }
                    Divider()
                    Button("Удалить", role: .destructive) { onDelete() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Add Playlist Sheet

struct AddPlaylistSheet: View {
    @Binding var playlistName: String
    let onAdd: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Новый плейлист")
                .font(.headline)
            
            TextField("Название плейлиста", text: $playlistName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            HStack {
                Button("Отмена") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Добавить") { onAdd() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 350, height: 150)
    }
}

// MARK: - Rename Playlist Sheet

struct RenamePlaylistSheet: View {
    let playlist: Playlist
    let onRename: (String) -> Void
    let onCancel: () -> Void
    
    @State private var newName: String
    
    init(playlist: Playlist, onRename: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.playlist = playlist
        self.onRename = onRename
        self.onCancel = onCancel
        _newName = State(initialValue: playlist.name)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Переименовать плейлист")
                .font(.headline)
            
            TextField("Название", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            HStack {
                Button("Отмена") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Сохранить") { onRename(newName) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newName.isEmpty)
            }
        }
        .padding()
        .frame(width: 350, height: 150)
    }
}

// MARK: - Color Picker Sheet

struct ColorPickerSheet: View {
    let playlist: Playlist
    let onColorChange: (CodableColor) -> Void
    let onCancel: () -> Void
    
    @State private var selectedColor: Color
    
    init(playlist: Playlist, onColorChange: @escaping (CodableColor) -> Void, onCancel: @escaping () -> Void) {
        self.playlist = playlist
        self.onColorChange = onColorChange
        self.onCancel = onCancel
        _selectedColor = State(initialValue: playlist.color.color)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Выберите цвет")
                .font(.headline)
            
            ColorPicker("Цвет плейлиста", selection: $selectedColor)
                .labelsHidden()
                .frame(width: 300)
            
            HStack {
                Button("Отмена") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Сохранить") {
                    onColorChange(CodableColor(selectedColor))
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 350, height: 200)
    }
}
