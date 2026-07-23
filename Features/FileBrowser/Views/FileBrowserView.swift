import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Browser View
struct FileBrowserView: View {
    @State private var rootURL: URL? = nil
    @State private var items: [FileItem] = []
    @State private var selectedFile: FileItem? = nil
    @State private var expandedFolders: Set<URL> = []
    @State private var showFolderPicker = false
    @State private var showDeleteConfirm = false
    @State private var itemToDelete: FileItem? = nil
    @State private var errorMessage: String? = nil
    @State private var showEditor = false
    @State private var fileContent: String = ""
    @State private var editingFile: FileItem? = nil
    @State private var isContentLoading = false
    
    // Default to home directory
    private let defaultRoot = FileManager.default.homeDirectoryForCurrentUser
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar
            
            Divider().foregroundColor(.hermes.border)
            
            // Breadcrumb
            if let root = rootURL {
                breadcrumbBar(root: root)
                Divider().foregroundColor(.hermes.border)
            }
            
            if rootURL == nil {
                emptyState
            } else if items.isEmpty {
                emptyFolder
            } else {
                fileList
            }
            
            // Status bar
            if let root = rootURL {
                statusBar(root: root)
            }
        }
        .background(Color.hermes.bg)
        .sheet(isPresented: $showEditor) {
            if let file = editingFile {
                FileEditorView(
                    file: file,
                    content: fileContent,
                    onSave: { newContent in
                        saveFile(file: file, content: newContent)
                    }
                )
                .frame(minWidth: 600, minHeight: 500)
            }
        }
        #if os(iOS)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    let secured = url.startAccessingSecurityScopedResource()
                    rootURL = url
                    expandedFolders.removeAll()
                    refreshFolder()
                    if secured {
                        // Keep access while browsing; release on folder change
                    }
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        #endif
        .alert("Delete Item", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    deleteItem(item)
                }
            }
        } message: {
            if let item = itemToDelete {
                Text("Are you sure you want to delete \"\(item.name)\"? This cannot be undone.")
            }
        }
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: HermesSpacing.md) {
            Image(systemName: "folder.fill")
                .foregroundColor(.hermes.accent)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: HermesSpacing.xs) {
                Text("File Explorer")
                    .font(.hermes.h3)
                    .foregroundColor(.hermes.text)
                Text("Browse, edit, and manage your project files.")
                    .font(.hermes.caption)
                    .foregroundColor(.hermes.muted)
            }
            
            Spacer()
            
            // Folder picker button
            Button(action: { openFolderPicker() }) {
                HStack(spacing: HermesSpacing.xs) {
                    Image(systemName: "folder.badge.plus")
                    Text(rootURL == nil ? "Open Folder" : "Change Folder")
                }
                .font(.hermes.captionMedium)
                .padding(.horizontal, HermesSpacing.md)
                .padding(.vertical, HermesSpacing.sm)
                .background(Color.hermes.accent)
                .foregroundColor(.white)
                .cornerRadius(HermesRadius.md)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Refresh
            if rootURL != nil {
                Button(action: refreshFolder) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundColor(.hermes.muted)
                        .padding(HermesSpacing.sm)
                        .background(Color.hermes.surface)
                        .cornerRadius(HermesRadius.sm)
                        .overlay(RoundedRectangle(cornerRadius: HermesRadius.sm).strokeBorder(Color.hermes.border, lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, HermesSpacing.xl)
        .padding(.vertical, HermesSpacing.md)
        .background(Color.hermes.surface)
    }
    
    // MARK: - Breadcrumb
    private func breadcrumbBar(root: URL) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HermesSpacing.xs) {
                Image(systemName: "house.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.hermes.muted)
                
                ForEach(breadcrumbComponents(root: root), id: \.url) { component in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.hermes.border)
                    
                    Text(component.name)
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.muted)
                }
            }
            .padding(.horizontal, HermesSpacing.xl)
            .padding(.vertical, HermesSpacing.sm)
        }
        .background(Color.hermes.bg)
    }
    
    private func breadcrumbComponents(root: URL) -> [(name: String, url: URL)] {
        var components: [(String, URL)] = []
        var current = root
        #if os(macOS)
        let home = FileManager.default.homeDirectoryForCurrentUser
        #else
        let home = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? root
        #endif
        
        while current.path != "/" {
            components.insert((current.lastPathComponent, current), at: 0)
            current = current.deletingLastPathComponent()
            if current == home { break }
        }
        return components
    }
    
    // MARK: - Empty States
    private var emptyState: some View {
        VStack(spacing: HermesSpacing.lg) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.hermes.muted.opacity(0.4))
            Text("No Folder Opened")
                .font(.hermes.h3)
                .foregroundColor(.hermes.text)
            Text("Open a project folder to browse, edit, and inject files into the AI Brain.")
                .font(.hermes.caption)
                .foregroundColor(.hermes.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            HermesButton(title: "Open Folder", icon: "folder.badge.plus", action: {
                openFolderPicker()
            })
            .fixedSize()
            Spacer()
        }
    }
    
    private var emptyFolder: some View {
        VStack(spacing: HermesSpacing.md) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.hermes.muted.opacity(0.4))
            Text("Empty Folder")
                .font(.hermes.bodyMedium)
                .foregroundColor(.hermes.muted)
            Spacer()
        }
    }
    
    // MARK: - File List
    private var fileList: some View {
        List {
            ForEach(items) { item in
                if item.isDirectory {
                    FolderRowView(
                        item: item,
                        expandedFolders: $expandedFolders,
                        onOpenFile: openFile,
                        fileContextMenu: fileContextMenu,
                        injectAction: injectToBrain
                    )
                } else {
                    fileRow(item)
                        .contextMenu { fileContextMenu(item) }
                }
            }
        }
        .listStyle(.plain)
        #if os(macOS)
        .listStyle(.inset(alternatesRowBackgrounds: true))
        #endif
    }
    
    private func fileRow(_ item: FileItem) -> some View {
        Button(action: { openFile(item) }) {
            HStack(spacing: HermesSpacing.sm) {
                Image(systemName: fileIcon(for: item))
                    .foregroundColor(fileColor(for: item))
                    .font(.system(size: 13))
                    .frame(width: 18)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.hermes.body)
                        .foregroundColor(.hermes.text)
                        .lineLimit(1)
                    
                    HStack(spacing: HermesSpacing.sm) {
                        Text(item.fileSizeFormatted)
                        Text("•")
                        Text(item.modificationDateFormatted)
                    }
                    .font(.hermes.badge)
                    .foregroundColor(.hermes.muted)
                }
                
                Spacer()
                
                // Inject to Brain button
                Button(action: { injectToBrain(item) }) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 11))
                        .foregroundColor(.hermes.accent)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Inject this file into the AI Brain")
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Context Menu
    private func fileContextMenu(_ item: FileItem) -> AnyView {
        AnyView(Group {
        Button(action: { openFile(item) }) {
            Label("Open", systemImage: "doc.text")
        }
        
        Button(action: { injectToBrain(item) }) {
            Label("Inject to Brain", systemImage: "brain.head.profile")
        }
        
        Divider()
        
        Button(action: { copyFilePath(item) }) {
            Label("Copy Path", systemImage: "doc.on.clipboard")
        }
        
        #if os(macOS)
        Button(action: { revealInFinder(item) }) {
            Label("Reveal in Finder", systemImage: "folder")
        }
        #endif
        
        Divider()
        
        Button(role: .destructive, action: {
            itemToDelete = item
            showDeleteConfirm = true
        }) {
            Label("Delete", systemImage: "trash")
        }
        })
    }
    
    // MARK: - Status Bar
    private func statusBar(root: URL) -> some View {
        HStack(spacing: HermesSpacing.md) {
            Text("\(items.count) items")
                .font(.hermes.badge)
                .foregroundColor(.hermes.muted)
            
            Spacer()
            
            if let error = errorMessage {
                Text(error)
                    .font(.hermes.badge)
                    .foregroundColor(.hermes.danger)
            }
            
            Text(root.path)
                .font(.hermes.badge)
                .foregroundColor(.hermes.muted)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .padding(.horizontal, HermesSpacing.lg)
        .padding(.vertical, HermesSpacing.sm)
        .background(Color.hermes.surface)
        .overlay(alignment: .top) {
            Divider().foregroundColor(.hermes.border)
        }
    }
    
    // MARK: - Helpers
    private func fileIcon(for item: FileItem) -> String {
        if item.isTextFile { return "doc.text.fill" }
        if item.isImageFile { return "photo.fill" }
        switch item.url.pathExtension.lowercased() {
        case "pdf": return "doc.fill"
        case "zip", "tar", "gz": return "archivebox.fill"
        case "mp3", "wav", "aac": return "music.note"
        case "mp4", "mov": return "film.fill"
        default: return "doc"
        }
    }
    
    private func fileColor(for item: FileItem) -> Color {
        if item.isTextFile { return .blue }
        if item.isImageFile { return .purple }
        switch item.url.pathExtension.lowercased() {
        case "pdf": return .red
        case "zip", "tar", "gz": return .orange
        case "swift": return .orange
        case "py": return .green
        case "js", "ts": return .yellow
        case "html", "css": return .indigo
        default: return .hermes.muted
        }
    }
    
    // MARK: - Actions
    private func openFile(_ item: FileItem) {
        if item.isTextFile {
            isContentLoading = true
            DispatchQueue.global(qos: .userInitiated).async {
                if let content = try? String(contentsOf: item.url, encoding: .utf8) {
                    DispatchQueue.main.async {
                        fileContent = content
                        editingFile = item
                        isContentLoading = false
                        showEditor = true
                    }
                } else {
                    DispatchQueue.main.async {
                        errorMessage = "Cannot read file: \(item.name)"
                        isContentLoading = false
                    }
                }
            }
        } else {
            // Open with default app
            #if os(macOS)
            NSWorkspace.shared.open(item.url)
            #else
            UIApplication.shared.open(item.url)
            #endif
        }
    }
    
    private func saveFile(file: FileItem, content: String) {
        do {
            try content.write(to: file.url, atomically: true, encoding: .utf8)
            refreshFolder()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    private func deleteItem(_ item: FileItem) {
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            refreshFolder()
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }
    
    private func copyFilePath(_ item: FileItem) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.url.path, forType: .string)
        #else
        UIPasteboard.general.string = item.url.path
        #endif
    }
    
    #if os(macOS)
    private func revealInFinder(_ item: FileItem) {
        NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: "")
    }
    #endif
    
    private func injectToBrain(_ item: FileItem) {
        // Read file and create a Brain document
        DispatchQueue.global(qos: .userInitiated).async {
            guard let content = try? String(contentsOf: item.url, encoding: .utf8) else {
                DispatchQueue.main.async {
                    errorMessage = "Cannot read: \(item.name)"
                }
                return
            }
            
            // Truncate content for preview if too large
            let maxChars = 5000
            let truncated = content.count > maxChars ? String(content.prefix(maxChars)) + "\n\n... (truncated)" : content
            
            DispatchQueue.main.async {
                // Create BrainDocument and switch to Brain tab
                let doc = BrainDocument(
                    id: UUID().uuidString,
                    title: item.name,
                    type: .text,
                    content: truncated,
                    tags: ["general"],
                    createdAt: Date()
                )
                // Post notification to add to knowledge base
                NotificationCenter.default.post(
                    name: .injectFileToBrain,
                    object: doc
                )
            }
        }
    }
    
    private func refreshFolder() {
        guard let root = rootURL else { return }
        items = FileItem.loadDirectory(url: root)
        errorMessage = nil
    }
    
    private func openFolderPicker() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a project folder to browse"
        panel.directoryURL = rootURL ?? defaultRoot
        
        if panel.runModal() == .OK, let url = panel.url {
            rootURL = url
            expandedFolders.removeAll()
            refreshFolder()
        }
        #else
        showFolderPicker = true
        #endif
    }
}

// MARK: - File Editor View
struct FileEditorView: View {
    @Environment(\.dismiss) var dismiss
    let file: FileItem
    @State var content: String
    @State private var hasChanges = false
    var onSave: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: HermesSpacing.md) {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.hermes.bodyMedium)
                        .foregroundColor(.hermes.text)
                    Text(file.url.path)
                        .font(.hermes.badge)
                        .foregroundColor(.hermes.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                if hasChanges {
                    Text("Unsaved changes")
                        .font(.hermes.badge)
                        .foregroundColor(.hermes.warning)
                        .padding(.horizontal, HermesSpacing.sm)
                        .padding(.vertical, HermesSpacing.xs)
                        .background(Color.hermes.warning.opacity(0.1))
                        .cornerRadius(HermesRadius.sm)
                }
                
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.hermes.bodyMedium)
                        .foregroundColor(.hermes.muted)
                }
                .buttonStyle(PlainButtonStyle())
                
                HermesButton(title: "Save", icon: "checkmark", size: .small, isDisabled: !hasChanges, action: {
                    onSave(content)
                    hasChanges = false
                    dismiss()
                })
                .fixedSize()
            }
            .padding(.horizontal, HermesSpacing.xl)
            .padding(.vertical, HermesSpacing.md)
            .background(Color.hermes.surface)
            
            Divider().foregroundColor(.hermes.border)
            
            // Editor
            TextEditor(text: Binding(
                get: { content },
                set: { newValue in
                    content = newValue
                    hasChanges = true
                }
            ))
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.hermes.text)
            .scrollContentBackground(.hidden)
            .padding(HermesSpacing.md)
            .background(Color.hermes.bg)
            
            // Status bar
            HStack {
                Text("\(content.count) characters • \(content.split(separator: "\n").count) lines")
                    .font(.hermes.badge)
                    .foregroundColor(.hermes.muted)
                
                Spacer()
                
                if let lang = detectLanguage(file.url.pathExtension) {
                    Text(lang)
                        .font(.hermes.badge)
                        .foregroundColor(.hermes.accent)
                        .padding(.horizontal, HermesSpacing.sm)
                        .padding(.vertical, HermesSpacing.xs)
                        .background(Color.hermes.accent.opacity(0.1))
                        .cornerRadius(HermesRadius.sm)
                }
            }
            .padding(.horizontal, HermesSpacing.lg)
            .padding(.vertical, HermesSpacing.sm)
            .background(Color.hermes.surface)
            .overlay(alignment: .top) {
                Divider().foregroundColor(.hermes.border)
            }
        }
        .background(Color.hermes.bg)
        .onDisappear {
            if hasChanges {
                // Auto-save on dismiss
                onSave(content)
            }
        }
    }
    
    private func detectLanguage(_ ext: String) -> String? {
        switch ext.lowercased() {
        case "swift": return "Swift"
        case "py": return "Python"
        case "js": return "JavaScript"
        case "ts": return "TypeScript"
        case "php": return "PHP"
        case "rb": return "Ruby"
        case "go": return "Go"
        case "java": return "Java"
        case "c": return "C"
        case "cpp": return "C++"
        case "html": return "HTML"
        case "css": return "CSS"
        case "json": return "JSON"
        case "xml": return "XML"
        case "yaml", "yml": return "YAML"
        case "md": return "Markdown"
        case "sql": return "SQL"
        case "sh", "bash": return "Shell"
        case "rs": return "Rust"
        case "kt": return "Kotlin"
        default: return nil
        }
    }
}

// MARK: - Folder Row (recursive, uses AnyView to break type recursion)
struct FolderRowView: View {
    let item: FileItem
    @Binding var expandedFolders: Set<URL>
    var onOpenFile: (FileItem) -> Void
    var fileContextMenu: (FileItem) -> AnyView
    var injectAction: (FileItem) -> Void
    
    var body: some View {
        let children = expandedFolders.contains(item.url)
            ? (item.children ?? FileItem.loadDirectory(url: item.url))
            : []
        
        DisclosureGroup(isExpanded: Binding(
            get: { expandedFolders.contains(item.url) },
            set: { isExpanded in
                if isExpanded {
                    expandedFolders.insert(item.url)
                } else {
                    expandedFolders.remove(item.url)
                }
            }
        )) {
            ForEach(children) { child in
                if child.isDirectory {
                    FolderRowView(
                        item: child,
                        expandedFolders: $expandedFolders,
                        onOpenFile: onOpenFile,
                        fileContextMenu: fileContextMenu,
                        injectAction: injectAction
                    )
                } else {
                    fileRowView(child)
                }
            }
        } label: {
            HStack(spacing: HermesSpacing.sm) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.hermes.accent)
                    .font(.system(size: 13))
                Text(item.name)
                    .font(.hermes.body)
                    .foregroundColor(.hermes.text)
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(children.count) items")
                    .font(.hermes.caption)
                    .foregroundColor(.hermes.muted)
            }
            .contentShape(Rectangle())
        }
    }
    
    private func fileRowView(_ item: FileItem) -> some View {
        Button(action: { onOpenFile(item) }) {
            HStack(spacing: HermesSpacing.sm) {
                Image(systemName: fileIcon(for: item))
                    .foregroundColor(fileColor(for: item))
                    .font(.system(size: 13))
                    .frame(width: 18)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.hermes.body)
                        .foregroundColor(.hermes.text)
                        .lineLimit(1)
                    
                    HStack(spacing: HermesSpacing.sm) {
                        Text(item.fileSizeFormatted)
                        Text("•")
                        Text(item.modificationDateFormatted)
                    }
                    .font(.hermes.badge)
                    .foregroundColor(.hermes.muted)
                }
                
                Spacer()
                
                Button(action: { injectAction(item) }) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 11))
                        .foregroundColor(.hermes.accent)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu { fileContextMenu(item) }
    }
    
    private func fileIcon(for item: FileItem) -> String {
        if item.isTextFile { return "doc.text.fill" }
        if item.isImageFile { return "photo.fill" }
        switch item.url.pathExtension.lowercased() {
        case "pdf": return "doc.fill"
        case "zip", "tar", "gz": return "archivebox.fill"
        default: return "doc"
        }
    }
    
    private func fileColor(for item: FileItem) -> Color {
        if item.isTextFile { return .blue }
        if item.isImageFile { return .purple }
        switch item.url.pathExtension.lowercased() {
        case "pdf": return .red
        case "swift": return .orange
        case "py": return .green
        case "js", "ts": return .yellow
        default: return .hermes.muted
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let injectFileToBrain = Notification.Name("injectFileToBrain")
}

#Preview {
    FileBrowserView()
}
