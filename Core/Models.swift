import Foundation

struct ChatRoom: Identifiable, Equatable {
    var id: String
    var title: String
    var category: String
    var persona: String
    var model: String
    var createdAt: Date
    
    static let samples: [ChatRoom] = [
        ChatRoom(id: "room_1", title: "Penelitian Skripsi Bab 1", category: "Education", persona: "education", model: "ollama", createdAt: Date().addingTimeInterval(-86400)),
        ChatRoom(id: "room_2", title: "Brainstorming Fitur RAG", category: "Software Dev", persona: "architect", model: "ollama", createdAt: Date().addingTimeInterval(-3600)),
        ChatRoom(id: "room_3", title: "Diskusi Laravel 12", category: "Software Dev", persona: "architect", model: "deepseek", createdAt: Date().addingTimeInterval(-7200))
    ]
}

enum BrainDocumentType: String {
    case text, pdf
    
    var icon: String {
        switch self {
        case .text: return "doc.text.fill"
        case .pdf: return "doc.richtext.fill"
        }
    }
}

struct BrainDocument: Identifiable, Equatable {
    let id: String
    var title: String
    var type: BrainDocumentType
    var content: String
    var tags: [String]
    var createdAt: Date
    
    static let samples: [BrainDocument] = [
        BrainDocument(id: "1", title: "Turnitin Algorithm Deconstruction", type: .pdf, content: "", tags: ["education", "sage"], createdAt: Date().addingTimeInterval(-86400 * 3)),
        BrainDocument(id: "2", title: "Laravel 12 Architecture Guidelines", type: .text, content: "## Laravel 12...", tags: ["architect"], createdAt: Date().addingTimeInterval(-86400 * 2)),
        BrainDocument(id: "3", title: "Prompt Engineering Basics", type: .text, content: "# Prompt Engineering...", tags: ["general"], createdAt: Date().addingTimeInterval(-86400))
    ]
}

// MARK: - File Browser

struct FileItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let fileSize: Int64?
    let modificationDate: Date?
    var children: [FileItem]?
    
    var isTextFile: Bool {
        let textExtensions = ["txt", "md", "swift", "js", "ts", "py", "php", "rb", "go", "java", "c", "cpp", "h", "html", "css", "json", "xml", "yaml", "yml", "toml", "log", "csv", "sh", "bash", "zsh", "env", "gitignore", "sql", "r", "kt", "scala", "rs"]
        return textExtensions.contains(url.pathExtension.lowercased())
    }
    
    var isImageFile: Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "heic"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    var fileSizeFormatted: String {
        guard let size = fileSize else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var modificationDateFormatted: String {
        guard let date = modificationDate else { return "--" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    static func loadDirectory(url: URL) -> [FileItem] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        return contents.compactMap { fileURL in
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]),
                  let isDir = resourceValues.isDirectory else { return nil }
            
            return FileItem(
                url: fileURL,
                name: fileURL.lastPathComponent,
                isDirectory: isDir,
                fileSize: Int64(resourceValues.fileSize ?? 0),
                modificationDate: resourceValues.contentModificationDate,
                children: isDir ? nil : nil
            )
        }.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
}

// Shared types used across views
enum MessageRating { case up, down }
struct ChatMessage: Identifiable, Equatable {
    let id: String
    var content: String
    var isUser: Bool
    var hasWebContext: Bool = false
    var hasReasoning: Bool = false
    var reasoningContent: String? = nil
    var isEducationEval: Bool = false
    var evalData: ThesisEvalData? = nil
    var rating: MessageRating? = nil
    var timestamp: Date = Date()
    
    init(id: String = UUID().uuidString, content: String, isUser: Bool, hasWebContext: Bool = false, hasReasoning: Bool = false, reasoningContent: String? = nil, isEducationEval: Bool = false, evalData: ThesisEvalData? = nil) {
        self.id = id; self.content = content; self.isUser = isUser; self.hasWebContext = hasWebContext
        self.hasReasoning = hasReasoning; self.reasoningContent = reasoningContent
        self.isEducationEval = isEducationEval; self.evalData = evalData
    }
}
struct ThesisEvalData: Equatable {
    var bab1Score: Double?; var bab2Score: Double?; var bab3Score: Double?
    var bab4Score: Double?; var bab5Score: Double?; var coherenceScore: Double?
    var strengths: [String] = []; var weaknesses: [String] = []; var recommendations: [String] = []
}
