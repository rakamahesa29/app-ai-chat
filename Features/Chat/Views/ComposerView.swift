import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct ComposerView: View {
    var roomId: String? = nil
    var onSend: ((String) -> Void)?
    var isStreaming: Bool = false
    var isRateLimited: Bool = false
    var rateLimitMessage: String? = nil
    var chatMode: ChatRoomView.ChatMode = .ask
    var hasWorkspace: Bool = false
    @Binding var isAutoSpeakEnabled: Bool
    
    @State private var messageText = ""
    @State private var isWebSearchEnabled = false
    @State private var attachedFiles: [AttachedFile] = []
    @State private var pastedCode: String? = nil
    @State private var showFilePicker = false
    @State private var showPasteCodeSheet = false
    @State private var showSkillsSheet = false
    @FocusState private var isFocused: Bool

    #if os(macOS)
    // Height reported by ChatTextView; clamped between one line and ~six lines.
    @State private var textViewHeight: CGFloat = 22
    private let composerMinHeight: CGFloat = 22
    private let composerMaxHeight: CGFloat = 132
    #endif
    
    // Voice-to-text
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isListening = false
    
    private var placeholder: String {
        switch chatMode {
        case .agent:
            return hasWorkspace
                ? "Tell the agent what to do..."
                : "Select a workspace folder first..."
        case .ask:
            return "Message AI..."
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider().foregroundColor(.hermes.border)
            
            // Attached files / pasted code chips
            if !attachedFiles.isEmpty || pastedCode != nil {
                attachedFilesBar
            }
            
            // Rate limit warning
            if isRateLimited {
                rateLimitInline
            }
            
            // Main composer
            HStack(alignment: .bottom, spacing: HermesSpacing.md) {
                // Action Buttons
                HStack(spacing: HermesSpacing.sm) {
                    plusMenu
                    
                    // Voice-to-text mic button
                    Button(action: { toggleListening() }) {
                        Image(systemName: "mic")
                            .font(.system(size: 16))
                            .foregroundColor(isListening ? .red : .hermes.muted)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isStreaming || isRateLimited)
                    
                    // Auto-speak toggle
                    Button(action: { isAutoSpeakEnabled.toggle() }) {
                        Image(systemName: isAutoSpeakEnabled ? "speaker.wave.2" : "speaker.wave.1")
                            .font(.system(size: 16))
                            .foregroundColor(isAutoSpeakEnabled ? .hermes.accent : .hermes.muted)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isStreaming)
                    
                    // Web Search toggle
                    Button(action: { isWebSearchEnabled.toggle() }) {
                        Image(systemName: "globe")
                            .font(.system(size: 16))
                            .foregroundColor(isWebSearchEnabled ? .hermes.success : .hermes.muted)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isStreaming)
                }
                
                // Text Input
                ZStack(alignment: .leading) {
                    if isListening {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                                .scaleEffect(isListening ? 1.3 : 0.7)
                                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isListening)
                            Text(speechRecognizer.recognizedText.isEmpty ? "Listening…" : speechRecognizer.recognizedText)
                                .font(.hermes.body)
                                .foregroundColor(speechRecognizer.recognizedText.isEmpty ? .hermes.muted : .hermes.text)
                                .lineLimit(3)
                            Spacer()
                        }
                        .padding(.horizontal, HermesSpacing.xs)
                    } else {
                        if messageText.isEmpty {
                            Text(placeholder)
                                .font(.hermes.body)
                                .foregroundColor(.hermes.muted)
                                .padding(.horizontal, HermesSpacing.xs)
                                .allowsHitTesting(false)
                        }
                        
                        #if os(macOS)
                        // AppKit-backed input: Return sends, Shift+Return inserts newline,
                        // right-click shows the standard text services menu.
                        ChatTextView(
                            text: $messageText,
                            contentHeight: $textViewHeight,
                            font: NSFont.preferredFont(forTextStyle: .body),
                            textColor: hermesNSTextColor,
                            onSubmit: submitFromKeyboard
                        )
                        .frame(height: min(composerMaxHeight,
                                           max(composerMinHeight, textViewHeight)))
                        #else
                        TextField("", text: $messageText, axis: .vertical)
                            .font(.hermes.body)
                            .foregroundColor(.hermes.text)
                            .lineLimit(1...6)
                            .focused($isFocused)
                            .textInputAutocapitalization(.sentences)
                        #endif
                    }
                }
                .padding(.horizontal, HermesSpacing.md)
                .padding(.vertical, HermesSpacing.sm + 2)
                .background(Color.hermes.bg)
                .cornerRadius(HermesRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: HermesRadius.md)
                        .strokeBorder(Color.hermes.border, lineWidth: 1)
                        .allowsHitTesting(false) // don't swallow right-clicks / drag-select on the TextField
                )
                
                // Send / Stop Button
                Button(action: {
                    if isStreaming {
                        // Stop generation
                    } else {
                        handleSend()
                    }
                }) {
                    // Icon stays consistent between Ask and Agent — background color signals the mode.
                    Image(systemName: isStreaming ? "stop.circle" : "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(sendButtonColor)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!isStreaming && ((messageText.isEmpty && attachedFiles.isEmpty && pastedCode == nil) || (chatMode == .agent && !hasWorkspace)))
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal, HermesSpacing.lg)
            .padding(.vertical, HermesSpacing.md)
            .background(Color.hermes.surface)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: allowedFileTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showPasteCodeSheet) {
            PasteCodeSheet(initialCode: pastedCode ?? "") { code in
                pastedCode = code.isEmpty ? nil : code
            }
        }
        .sheet(isPresented: $showSkillsSheet) {
            if let rid = roomId {
                RoomSkillsSheet(roomId: rid)
            }
        }
        .onChange(of: speechRecognizer.isRecording) {
            if !speechRecognizer.isRecording {
                isListening = false
                let text = speechRecognizer.recognizedText.trimmingCharacters(in: .whitespaces)
                speechRecognizer.recognizedText = ""
                if !text.isEmpty { onSend?(text) }
            }
        }
    }

    // MARK: - Plus Menu (Paste Code / Upload File / Add Skill)
    private var plusMenu: some View {
        Menu {
            Button {
                showPasteCodeSheet = true
            } label: {
                Label("Paste Code", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Button {
                showFilePicker = true
            } label: {
                Label("Upload File", systemImage: "arrow.up.doc")
            }
            if roomId != nil {
                Button {
                    showSkillsSheet = true
                } label: {
                    Label("Room Skills", systemImage: "book.closed")
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.hermes.muted)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(isStreaming || isRateLimited)
    }
    
    // MARK: - Attached Files Bar
    private var attachedFilesBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HermesSpacing.sm) {
                if let code = pastedCode {
                    pastedCodeChip(preview: code)
                }
                ForEach(attachedFiles) { file in
                    fileChip(file)
                }
            }
            .padding(.horizontal, HermesSpacing.lg)
            .padding(.vertical, HermesSpacing.sm)
        }
        .background(Color.hermes.bg)
    }
    
    private func fileChip(_ file: AttachedFile) -> some View {
        HStack(spacing: HermesSpacing.xs) {
            Image(systemName: file.type.icon)
                .font(.system(size: 11))
                .foregroundColor(file.type.color)
            
            Text(file.name)
                .font(.hermes.caption)
                .foregroundColor(.hermes.text)
                .lineLimit(1)
                .frame(maxWidth: 120)
            
            Button(action: { attachedFiles.removeAll { $0.id == file.id } }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.hermes.muted)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, HermesSpacing.sm)
        .padding(.vertical, HermesSpacing.xs)
        .background(Color.hermes.surface)
        .cornerRadius(HermesRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: HermesRadius.sm)
                .strokeBorder(Color.hermes.border, lineWidth: 1)
        )
    }

    private func pastedCodeChip(preview: String) -> some View {
        HStack(spacing: HermesSpacing.xs) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 11))
                .foregroundColor(.purple)
            Text("Code snippet (\(preview.count) chars)")
                .font(.hermes.caption)
                .foregroundColor(.hermes.text)
                .lineLimit(1)
            Button(action: { showPasteCodeSheet = true }) {
                Image(systemName: "pencil")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.hermes.muted)
            }
            .buttonStyle(PlainButtonStyle())
            Button(action: { pastedCode = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.hermes.muted)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, HermesSpacing.sm)
        .padding(.vertical, HermesSpacing.xs)
        .background(Color.purple.opacity(0.08))
        .cornerRadius(HermesRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: HermesRadius.sm)
                .strokeBorder(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Rate Limit Inline
    private var rateLimitInline: some View {
        HStack(spacing: HermesSpacing.sm) {
            Image(systemName: "clock")
                .font(.system(size: 10))
                .foregroundColor(.hermes.warning)
            Text(rateLimitMessage ?? "Rate limited — please wait")
                .font(.hermes.caption)
                .foregroundColor(.hermes.warning)
            Spacer()
        }
        .padding(.horizontal, HermesSpacing.lg)
        .padding(.vertical, HermesSpacing.xs)
        .background(Color.hermes.warning.opacity(0.1))
    }
    
    // MARK: - Computed
    private var sendButtonColor: Color {
        if isStreaming { return .hermes.danger }
        if isRateLimited || (chatMode == .agent && !hasWorkspace) { return .hermes.muted.opacity(0.4) }
        if messageText.isEmpty && attachedFiles.isEmpty && pastedCode == nil { return .hermes.muted.opacity(0.4) }
        return chatMode == .agent ? .orange : .hermes.accent
    }
    
    private var allowedFileTypes: [UTType] {
        [
            .pdf, .plainText, .utf8PlainText,
            .sourceCode, .json, .xml, .commaSeparatedText,
            .html, .css, .javaScript,
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "php") ?? .sourceCode,
            UTType(filenameExtension: "docx") ?? .data
        ].compactMap { $0 }
    }
    
    #if os(macOS)
    // Adaptive NSColor mirroring Color.hermes.text so the AppKit text view
    // matches the rest of the design system in both light and dark modes.
    // Cached as a static so we do not mint a new NSColor on every SwiftUI
    // body evaluation (which would otherwise churn updateNSView).
    private var hermesNSTextColor: NSColor { Self.cachedTextColor }

    private static let cachedTextColor: NSColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(hex: "#F9FAFB")
            : NSColor(hex: "#111827")
    }

    // Called by ChatTextView when the user presses plain Return.
    // Guards mirror the Send button's disabled logic so the keyboard path
    // cannot bypass rate limiting, streaming, or the agent-without-workspace state.
    private func submitFromKeyboard() {
        let canSend = !messageText.trimmingCharacters(in: .whitespaces).isEmpty
            || !attachedFiles.isEmpty
            || pastedCode != nil
        let allowedForMode = !(chatMode == .agent && !hasWorkspace)
        guard canSend, !isStreaming, !isRateLimited, allowedForMode else { return }
        handleSend()
    }
    #endif

    // MARK: - Actions
    private func toggleListening() {
        if isListening {
            speechRecognizer.stopRecording()
            isListening = false
        } else {
            Task { @MainActor in
                if !speechRecognizer.isAuthorized {
                    await speechRecognizer.requestAuthorization()
                }
                guard speechRecognizer.isAuthorized else { return }
                isListening = true
                speechRecognizer.startRecording()
            }
        }
    }
    
    private func handleSend() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty || !attachedFiles.isEmpty || pastedCode != nil else { return }
        
        var fullMessage = text.isEmpty ? "Please analyze the attached content." : text

        // Append pasted code as a fenced block so the backend/model treats it as code context.
        if let code = pastedCode, !code.isEmpty {
            fullMessage += "\n\n```\n\(code)\n```"
        }

        // Append file references
        if !attachedFiles.isEmpty {
            let fileList = attachedFiles.map { "📎 \($0.name)" }.joined(separator: "\n")
            fullMessage += "\n\nAttached:\n\(fileList)"
        }

        onSend?(fullMessage)
        messageText = ""
        attachedFiles.removeAll()
        pastedCode = nil
        isFocused = true
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                let name = url.lastPathComponent
                let ext = url.pathExtension.lowercased()
                let type = AttachedFileType.from(extension: ext)
                
                let file = AttachedFile(
                    name: name,
                    url: url,
                    type: type
                )
                attachedFiles.append(file)
            }
        case .failure(let error):
            print("File import failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Attached File Model
struct AttachedFile: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let type: AttachedFileType
}

enum AttachedFileType: String {
    case pdf, text, code, document, data, unknown
    
    var icon: String {
        switch self {
        case .pdf: return "doc"
        case .text: return "doc.text"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .document: return "doc.richtext"
        case .data: return "tablecells"
        case .unknown: return "paperclip"
        }
    }
    
    var color: Color {
        switch self {
        case .pdf: return .red
        case .text: return .blue
        case .code: return .purple
        case .document: return .orange
        case .data: return .green
        case .unknown: return .hermes.muted
        }
    }
    
    static func from(extension ext: String) -> AttachedFileType {
        switch ext {
        case "pdf": return .pdf
        case "txt", "md", "log": return .text
        case "swift", "js", "ts", "py", "php", "rb", "go", "java", "c", "cpp", "h", "html", "css", "json", "xml", "yaml", "yml", "toml": return .code
        case "docx", "doc", "rtf": return .document
        case "csv", "xlsx", "xls": return .data
        default: return .unknown
        }
    }
}

// MARK: - Paste Code Sheet
struct PasteCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let initialCode: String
    let onSave: (String) -> Void
    @State private var code: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Paste Code")
                    .font(.hermes.h3)
                    .foregroundColor(.hermes.text)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.hermes.muted)
                Button {
                    onSave(code.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                } label: {
                    Text("Attach").font(.hermes.bodyMedium).foregroundColor(.white)
                        .padding(.horizontal, HermesSpacing.md).padding(.vertical, HermesSpacing.sm)
                        .background(Color.hermes.accent).cornerRadius(HermesRadius.sm)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            .padding(HermesSpacing.lg)
            .background(Color.hermes.surface)

            Divider().foregroundColor(.hermes.border)

            Text("Paste your code snippet. It will be attached to your message as a fenced code block.")
                .font(.hermes.caption)
                .foregroundColor(.hermes.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, HermesSpacing.lg)
                .padding(.top, HermesSpacing.md)

            TextEditor(text: $code)
                .font(.hermes.mono)
                .foregroundColor(.hermes.text)
                .scrollContentBackground(.hidden)
                .padding(HermesSpacing.md)
                .background(Color.hermes.bg)
                .cornerRadius(HermesRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: HermesRadius.md)
                        .strokeBorder(Color.hermes.border, lineWidth: 1)
                )
                .padding(HermesSpacing.lg)
        }
        .frame(minWidth: 480, minHeight: 400)
        .background(Color.hermes.bg)
        .onAppear { code = initialCode }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var autoSpeak = false
        var body: some View {
            VStack {
                Spacer()
                ComposerView(roomId: "1", isAutoSpeakEnabled: $autoSpeak)
            }
            .background(Color.hermes.bg)
        }
    }
    return PreviewWrapper()
}
