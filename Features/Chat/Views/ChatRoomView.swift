import SwiftUI

struct ChatRoomView: View {
    let room: ChatRoom
    var isMobile: Bool
    @Binding var isSidebarOpen: Bool
    var onDeleteRoom: (() -> Void)? = nil
    
    @State private var messages: [ChatMessage] = []
    @State private var isStreaming = false
    @State private var streamingText = ""
    @State private var isLoadingMessages = false
    @State private var isDeepSeekPro = false
    @State private var isSkripsiMode = false
    @State private var isWebSearchEnabled = false
    @State private var memoryUsed = 4
    @State private var memoryMax = 10
    @State private var isRateLimited = false
    @State private var rateLimitMessage: String?
    @State private var selectedModel: String = "ollama"
    @State private var streamingTask: Task<Void, Never>? = nil
    @State private var chatMode: ChatMode = .ask
    @State private var agentWorkspaceURL: URL? = nil
    @State private var showWorkspacePicker = false
    @State private var showWorkspaceTrustAlert = false
    @State private var scrollProxy: ScrollViewProxy?
    @StateObject private var speechSynth = SpeechSynthesizer()
    @State private var isAutoSpeakEnabled = false
    @State private var agentProcessingText = ""
    @State private var agentTurnCount = 0
    
    enum ChatMode: String, CaseIterable {
        case ask = "Ask", agent = "Agent"
        var icon: String { self == .ask ? "bubble.left.and.bubble.right" : "hammer" }
    }
    
    var isEducationRoom: Bool { room.persona == "education" }
    
    var body: some View {
        VStack(spacing: 0) {
            chatHeader; Divider().foregroundColor(.hermes.border)
            if chatMode == .agent && agentWorkspaceURL == nil { agentCompactBar }
            if !agentProcessingText.isEmpty { agentProcessingBar }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: HermesSpacing.lg) {
                        ForEach(messages) { msg in messageRow(for: msg).id(msg.id) }
                        if isStreaming { streamingBubble.id("streaming") }
                        if isRateLimited { rateLimitBanner.id("rate_limit") }
                        if isStreaming {
                            Button(action: stopStreaming) {
                                Label("Stop", systemImage: "stop.circle.fill").font(.hermes.caption)
                            }.foregroundColor(.hermes.danger).padding(.horizontal).id("stop_btn")
                        }
                    }.padding(.horizontal, HermesSpacing.lg).padding(.vertical, HermesSpacing.lg)
                }
                .onAppear { scrollProxy = proxy }
                .onChange(of: messages.count) { scrollToBottom() }
                .onChange(of: streamingText) { scrollToBottom() }
            }
            ComposerView(onSend: sendMessage, isStreaming: isStreaming, isRateLimited: isRateLimited, rateLimitMessage: rateLimitMessage, chatMode: chatMode, hasWorkspace: agentWorkspaceURL != nil, isAutoSpeakEnabled: $isAutoSpeakEnabled)
            statusBar
        }
        .background(Color.hermes.bg)
        .task(id: room.id) { await fetchMessages() }
        .onAppear { selectedModel = room.model }
        .onChange(of: room.id) { selectedModel = room.model }
        .onChange(of: isAutoSpeakEnabled) { if !isAutoSpeakEnabled { speechSynth.stop() } }
        .alert("Workspace Trusted", isPresented: $showWorkspaceTrustAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Agent now has full read/write access to this folder and its contents.")
        }
        #if os(iOS)
        .fileImporter(isPresented: $showWorkspacePicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { r in
            if case .success(let urls) = r, let url = urls.first { _ = url.startAccessingSecurityScopedResource(); agentWorkspaceURL = url }
        }
        #endif
    }
    
    // Header
    private var chatHeader: some View {
        HStack(spacing: HermesSpacing.md) {
            if isMobile { HermesIconButton(icon: "sidebar.left", size: 36) { withAnimation(.easeInOut(duration: 0.25)) { isSidebarOpen.toggle() } } }
            VStack(alignment: .leading, spacing: 2) {
                Text(room.title).font(.hermes.h3).foregroundColor(.hermes.text).lineLimit(1)
                HStack(spacing: HermesSpacing.sm) {
                    HermesBadge(text: room.category, color: .hermes.accent, style: .subtle)
                    HStack(spacing: HermesSpacing.xs) { Image(systemName: memoryIcon).font(.system(size: 9)); Text("\(memoryUsed)/\(memoryMax)") }.font(.hermes.badge).foregroundColor(memoryColor)
                }
            }
            Spacer()
            if isEducationRoom { ToggleButton(label: "Skripsi", icon: "graduationcap", isOn: $isSkripsiMode, color: .orange) }
            DeepSeekProToggle(isOn: $isDeepSeekPro, visible: selectedModel == "deepseek")
            Picker("Model", selection: $selectedModel) {
                Text("Gemma4 12B").tag("ollama"); Text("Gemma4 31B").tag("ollama_cloud"); Text("DeepSeek").tag("deepseek")
            }.pickerStyle(.menu).font(.hermes.caption).foregroundColor(.hermes.muted)
        }.padding(.horizontal, HermesSpacing.lg).padding(.vertical, HermesSpacing.md).background(Color.hermes.surface)
    }
    
    private var agentCompactBar: some View {
        HStack(spacing: HermesSpacing.sm) {
            Image(systemName: "hammer.fill").font(.system(size: 11)).foregroundColor(.hermes.accent)
            Text("Select workspace folder for agent").font(.hermes.caption).foregroundColor(.hermes.muted)
            Spacer()
            Button("Choose…") { openWorkspacePicker() }
                .font(.hermes.captionMedium).foregroundColor(.hermes.accent)
                .padding(.horizontal, HermesSpacing.sm).padding(.vertical, 2)
                .background(Color.hermes.accent.opacity(0.1)).cornerRadius(HermesRadius.sm)
        }
        .padding(.horizontal, HermesSpacing.lg).padding(.vertical, HermesSpacing.sm)
        .background(Color.hermes.surface)
        .overlay(alignment: .top) { Divider().foregroundColor(.hermes.border) }
    }
    
    private var agentProcessingBar: some View {
        HStack(spacing: HermesSpacing.sm) {
            ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
            Text(agentProcessingText)
                .font(.hermes.caption)
                .foregroundColor(.hermes.accent.opacity(0.8))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, HermesSpacing.lg).padding(.vertical, HermesSpacing.xs)
        .background(Color.hermes.accent.opacity(0.06))
        .overlay(alignment: .top) { Divider().foregroundColor(.hermes.border) }
    }
    
    private var rateLimitBanner: some View {
        HStack(spacing: HermesSpacing.sm) {
            Image(systemName: "clock.fill").foregroundColor(.hermes.warning).font(.system(size: 12))
            Text(rateLimitMessage ?? "Please wait…").font(.hermes.caption).foregroundColor(.hermes.warning)
        }.padding(HermesSpacing.md).background(Color.hermes.warning.opacity(0.08)).cornerRadius(HermesRadius.md)
    }
    
    private var statusBar: some View {
        HStack(spacing: HermesSpacing.md) {
            statusItem(icon: "cpu", text: modelLabel)
            statusItem(icon: "person.circle", text: personaLabel(room.persona))
            if chatMode == .agent, let ws = agentWorkspaceURL { statusItem(icon: "hammer.fill", text: ws.lastPathComponent, color: .hermes.accent) }
            Spacer()
            Button(action: { withAnimation { chatMode = chatMode == .ask ? .agent : .ask } }) {
                HStack(spacing: 3) { Image(systemName: chatMode.icon).font(.system(size: 9)); Text(chatMode.rawValue) }
                    .font(.hermes.badge).padding(.horizontal, HermesSpacing.sm).padding(.vertical, 2)
                    .background(chatMode == .agent ? Color.orange.opacity(0.15) : Color.hermes.hover)
                    .foregroundColor(chatMode == .agent ? .orange : .hermes.muted).cornerRadius(HermesRadius.sm)
            }.buttonStyle(PlainButtonStyle())
            HStack(spacing: 4) {
                Circle().fill(isStreaming ? .orange : .hermes.success).frame(width: 6, height: 6)
                Text(isStreaming ? "Thinking…" : "Connected").font(.hermes.badge).foregroundColor(.hermes.muted)
            }
        }.padding(.horizontal, HermesSpacing.lg).padding(.vertical, HermesSpacing.sm).background(Color.hermes.surface).overlay(alignment: .top) { Divider().foregroundColor(.hermes.border) }
    }
    
    private func statusItem(icon: String, text: String, color: Color = .hermes.muted) -> some View {
        HStack(spacing: 4) { Image(systemName: icon).font(.system(size: 10)).foregroundColor(color); Text(text).font(.hermes.badge).foregroundColor(.hermes.muted) }
    }
    
    // Messages
    private func messageRow(for msg: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if msg.isUser { Spacer(minLength: 60) }
            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 4) {
                if msg.hasReasoning, let r = msg.reasoningContent, !r.isEmpty {
                    DisclosureGroup("Reasoning") { Text(r).font(.hermes.mono).foregroundColor(.hermes.muted).padding(.vertical, 4) }
                        .font(.hermes.caption).foregroundColor(.purple).padding(HermesSpacing.sm).background(Color.purple.opacity(0.06)).cornerRadius(HermesRadius.md)
                }
                VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                    RichMessageContent(content: msg.content, isUser: msg.isUser)
                }.padding(HermesSpacing.md).background(msg.isUser ? Color.hermes.accent : Color.hermes.card.opacity(0.5)).cornerRadius(HermesRadius.lg).overlay(RoundedRectangle(cornerRadius: HermesRadius.lg).strokeBorder(msg.isUser ? Color.clear : Color.hermes.border, lineWidth: 1))
                // Action buttons
                HStack(spacing: HermesSpacing.sm) {
                    if !msg.isUser {
                        IconBtn("hand.thumbsup", active: msg.rating == .up, color: .hermes.success) { rate(msg, .up) }
                        IconBtn("hand.thumbsdown", active: msg.rating == .down, color: .hermes.danger) { rate(msg, .down) }
                        IconBtn("doc.on.doc") { copy(msg) }
                        let spk = speechSynth.isSpeaking
                        IconBtn(spk ? "speaker.wave.2.fill" : "speaker.wave.1",
                                color: spk ? .hermes.accent : .hermes.muted) {
                            if speechSynth.isSpeaking { speechSynth.stop() }
                            else { speechSynth.speak(speakableText(msg.content), messageId: msg.id) }
                        }
                        if msg.id == messages.last?.id { IconBtn("arrow.triangle.2.circlepath", color: .hermes.accent) { continueGen(msg) } }
                    } else {
                        IconBtn("doc.on.doc") { copy(msg) }
                    }
                    IconBtn("trash") { deleteMsg(msg) }
                }.padding(.leading, 4)
            }
            if !msg.isUser { Spacer(minLength: 60) }
        }
    }
    
    private func IconBtn(_ icon: String, active: Bool = false, color: Color = .hermes.muted, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: active ? "\(icon).fill" : icon).font(.system(size: 11)).foregroundColor(active ? color : .hermes.muted) }.buttonStyle(PlainButtonStyle())
    }
    
    private var streamingBubble: some View {
        HStack(alignment: .top) {
            Spacer(minLength: 60)
            VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                if streamingText.isEmpty {
                    HStack(spacing: 4) { ProgressView().scaleEffect(0.6); Text("Thinking…").font(.hermes.caption).foregroundColor(.hermes.muted) }.padding(HermesSpacing.md)
                } else {
                    RichMessageContent(content: streamingText, isUser: false)
                }
            }
            Spacer(minLength: 60)
        }
    }
    
    // Computed
    private var modelLabel: String {
        switch selectedModel { case "ollama": "Gemma4 12B"; case "ollama_cloud": "Gemma4 31B"; case "deepseek": isDeepSeekPro ? "DeepSeek Pro" : "DeepSeek Flash"; default: "Gemma4 12B" }
    }
    private var memoryIcon: String { memoryUsed >= memoryMax ? "rectangle.compress.vertical" : memoryUsed >= 5 ? "square.stack.3d.up" : "square.stack.3d.down.forward" }
    private var memoryColor: Color { memoryUsed >= memoryMax ? .hermes.danger : memoryUsed >= 5 ? .hermes.warning : .hermes.muted }
    private func personaLabel(_ p: String) -> String { ["architect":"Architect","bestie":"Bestie","sage":"Sage","executive":"Executive","education":"Educator"][p] ?? p.capitalized }
    
    // Actions
    private func scrollToBottom() {
        guard let proxy = scrollProxy else { return }
        let id = isStreaming ? "streaming" : (isRateLimited ? "rate_limit" : messages.last?.id ?? "")
        if !id.isEmpty { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
    }
    private func rate(_ msg: ChatMessage, _ r: MessageRating) {
        guard let i = messages.firstIndex(where: { $0.id == msg.id }) else { return }
        messages[i].rating = messages[i].rating == r ? nil : r
        Task { try? await APIClient.shared.rateMessage(id: msg.id, rating: r == .up ? 1 : -1) }
    }
    private func copy(_ msg: ChatMessage) {
        #if os(macOS)
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(msg.content, forType: .string)
        #else
        UIPasteboard.general.string = msg.content
        #endif
    }
    private func deleteMsg(_ msg: ChatMessage) { withAnimation { messages.removeAll { $0.id == msg.id } }; Task { try? await APIClient.shared.deleteMessage(id: msg.id) } }
    private func continueGen(_ msg: ChatMessage) { isStreaming = true; streamingText = "\n\n*Continuing…*\n\n"; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isStreaming = false; streamingText = "" } }
    
    // API
    private func fetchMessages() async {
        isLoadingMessages = true
        do { messages = try await APIClient.shared.fetchMessages(roomId: room.id).map { ChatMessage(id: String($0.id), content: $0.content, isUser: $0.senderType == "user") } }
        catch { print("Fetch msgs: \(error)") }
        isLoadingMessages = false
    }
    
    // SSE Send
    private func sendMessage(_ text: String) {
        guard !isRateLimited else { return }
        agentTurnCount = 0
        if chatMode == .agent, agentWorkspaceURL == nil {
            rateLimitMessage = "Select workspace folder for Agent mode"; isRateLimited = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { isRateLimited = false; rateLimitMessage = nil }; return
        }
        streamingTask?.cancel()
        let um = ChatMessage(content: text, isUser: true, hasWebContext: isWebSearchEnabled)
        withAnimation { messages.append(um) }
        if memoryUsed < memoryMax { memoryUsed += 1 }
        isStreaming = true; streamingText = ""
        let url = APIClient.shared.sendMessageStreamURL(roomId: room.id)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let t = APIConfig.token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        req.httpBody = APIClient.shared.sendMessageBody(message: text, model: selectedModel, useWebSearch: isWebSearchEnabled, deepseekPro: isDeepSeekPro, skripsiMode: isSkripsiMode, workspacePath: agentWorkspaceURL?.path, chatMode: chatMode == .agent ? "agent" : "ask")
        var full = ""
        streamingTask = Task {
            defer { streamingTask = nil }
            do {
                print("📡 [SSE] Connecting to: \(url)"); print("📡 [SSE] Model: \(selectedModel)")
                let (bytes, response) = try await URLSession.shared.bytes(for: req)
                print("📡 [SSE] Connected: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                
                var agentStateToken: String? = nil
                var agentRequests: [[String: Any]]? = nil
                
                for try await line in bytes.lines {
                    if Task.isCancelled { print("📡 [SSE] Cancelled"); break }
                    guard line.hasPrefix("data: "), let d = line.dropFirst(6).data(using: .utf8) else { if !line.isEmpty { print("📡 [SSE] non-data: \(line.prefix(80))") }; continue }
                    guard let o = try? JSONSerialization.jsonObject(with: d) as? [String:Any] else { continue }
                    if let e = o["error"] as? String { print("📡 [SSE] error: \(e)"); streamingText = "Error: \(e)"; break }
                    if let type = o["type"] as? String, type == "meta" {
                        if let s = o["status"] as? String {
                            print("📡 [SSE] meta: \(s)")
                            if s == "searching_internal" { streamingText = "Searching..." }
                            else if s == "using_model_knowledge" { streamingText = "" }
                            else if s == "agent_tool_requests" {
                                agentStateToken = o["state_token"] as? String
                                agentRequests = o["requests"] as? [[String: Any]]
                                agentProcessingText = "Executing agent tools..."
                            }
                            else if s == "agent_start" || s == "agent_analyzing" {
                                agentProcessingText = "Agent is thinking…"
                            }
                        }
                        continue
                    }
                    if let c = o["content"] as? String { full += c; streamingText = full }
                    if o["done"] as? Bool == true {
                        // Agent awaiting tool execution
                        if o["awaiting_tools"] as? Bool == true, let token = agentStateToken, let requests = agentRequests {
                            guard agentTurnCount < 8 else {
                                streamingText = "⚠️ Agent reached max turns. Try a simpler request."
                                agentProcessingText = ""; break
                            }
                            agentTurnCount += 1
                            print("📡 [Agent] Executing \(requests.count) tools locally (turn \(agentTurnCount))...")
                            let results = executeAgentTools(requests, workspace: agentWorkspaceURL)
                            print("📡 [Agent] Tools done, continuing with token: \(token.prefix(8))...")
                            await continueAgent(token: token, results: results)
                        }
                        print("📡 [SSE] done"); break
                    }
                }
            } catch { if !Task.isCancelled { print("📡 [SSE] error: \(error)"); streamingText = "Error: \(error.localizedDescription)" } }
            if !Task.isCancelled {
                print("📡 [SSE] Done. Response length: \(full.count)")
                isStreaming = false; agentProcessingText = ""
                if !full.isEmpty {
                    let botMsg = ChatMessage(content: full, isUser: false, hasReasoning: isDeepSeekPro)
                    withAnimation { messages.append(botMsg) }
                    if isAutoSpeakEnabled { speechSynth.speak(speakableText(full), messageId: botMsg.id) }
                }
                if !streamingText.hasPrefix("Error") && !streamingText.hasPrefix("⚠️") { streamingText = "" }; if memoryUsed >= memoryMax { memoryUsed = 2 }
            }
        }
    }
    
    // MARK: - Agent Tool Execution
    
    private func executeAgentTools(_ requests: [[String: Any]], workspace: URL?) -> [[String: Any]] {
        var results: [[String: Any]] = []
        
        // Resolve security-scoped bookmark for persistent access
        var base = workspace
        var bookmarkAccessing = false
        if let data = UserDefaults.standard.data(forKey: "agent_workspace_bookmark") {
            var stale = false
            if let resolved = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
                bookmarkAccessing = resolved.startAccessingSecurityScopedResource()
                base = resolved
                if stale {
                    // Refresh bookmark for next time
                    if let fresh = try? resolved.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                        UserDefaults.standard.set(fresh, forKey: "agent_workspace_bookmark")
                    }
                }
            }
        }
        defer { if bookmarkAccessing { base?.stopAccessingSecurityScopedResource() } }
        
        guard let base = base else {
            print("❌ [Agent] No workspace URL!")
            agentProcessingText = "Error: No workspace selected"
            return [["tool": "error", "path": "", "status": "error", "message": "No workspace selected"]]
        }
        
        print("📁 [Agent] Workspace: \(base.path)")
        print("📁 [Agent] Workspace exists: \(FileManager.default.fileExists(atPath: base.path))")
        print("📁 [Agent] Workspace writable: \(FileManager.default.isWritableFile(atPath: base.path))")
        
        for req in requests {
            let tool = req["tool"] as? String ?? ""
            var path = req["path"] as? String ?? ""
            let content = req["content"] as? String
            
            // Normalize path: strip workspace prefix if LLM sent absolute path
            let bp = base.path.hasSuffix("/") ? String(base.path.dropLast()) : base.path
            if path.hasPrefix(bp + "/") {
                path = String(path.dropFirst(bp.count + 1))
                print("🔧 [Agent] Normalized absolute path → relative: \(path)")
            } else if path.hasPrefix("/") && path != "/" {
                // Absolute path not under workspace — treat as relative (strip leading /)
                path = String(path.dropFirst())
                print("🔧 [Agent] Stripped leading / from absolute path: \(path)")
            }
            let fullPath = base.appendingPathComponent(path)
            
            // Live status per tool
            let label = toolLabel(tool, path: path)
            agentProcessingText = label
            print("🔧 [Agent] Tool: \(tool) path: \(path) → \(fullPath.path)")
            
            // Security: prevent path traversal
            guard !path.contains(".."), fullPath.path.hasPrefix(bp) else {
                print("❌ [Agent] Security blocked: \(path)")
                results.append(["tool": tool, "path": path, "status": "error", "message": "Security: path traversal blocked"])
                continue
            }
            
            switch tool {
            case "write_file":
                do {
                    let dir = fullPath.deletingLastPathComponent()
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    try (content ?? "").write(to: fullPath, atomically: true, encoding: .utf8)
                    let size = (try? fullPath.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                    let exists = FileManager.default.fileExists(atPath: fullPath.path)
                    if exists {
                        print("✅ [Agent] Written: \(fullPath.path) (\(size) bytes)")
                        results.append(["tool": "write_file", "path": path, "status": "success", "message": "File created: \(path) (\(size) bytes)"])
                    } else {
                        // FileManager reported success but file doesn't exist — try shell
                        print("⚠️ [Agent] FileManager wrote but file missing, trying shell...")
                        try writeViaShell(fullPath: fullPath, content: content ?? "")
                        print("✅ [Agent] Shell wrote: \(fullPath.path)")
                        results.append(["tool": "write_file", "path": path, "status": "success", "message": "File created via shell: \(path)"])
                    }
                } catch {
                    // FileManager failed — try shell fallback
                    print("⚠️ [Agent] FileManager error: \(error.localizedDescription), trying shell...")
                    do {
                        try writeViaShell(fullPath: fullPath, content: content ?? "")
                        print("✅ [Agent] Shell fallback wrote: \(fullPath.path)")
                        results.append(["tool": "write_file", "path": path, "status": "success", "message": "File created: \(path)"])
                    } catch {
                        print("❌ [Agent] Shell also failed: \(error.localizedDescription)")
                        results.append(["tool": "write_file", "path": path, "status": "error", "message": "Write failed: \(error.localizedDescription)"])
                    }
                }
            case "read_file":
                do {
                    let data = try String(contentsOf: fullPath, encoding: .utf8)
                    print("📖 [Agent] Read: \(path) (\(data.count) chars)")
                    results.append(["tool": "read_file", "path": path, "status": "success", "message": "Read \(data.count) chars", "content": data])
                } catch {
                    print("❌ [Agent] Read failed: \(path) — \(error.localizedDescription)")
                    results.append(["tool": "read_file", "path": path, "status": "error", "message": "Cannot read: \(path)"])
                }
            case "delete_file":
                do {
                    try FileManager.default.removeItem(at: fullPath)
                    print("🗑 [Agent] Deleted: \(fullPath.path)")
                    results.append(["tool": "delete_file", "path": path, "status": "success", "message": "Deleted: \(path)"])
                } catch {
                    print("❌ [Agent] Delete failed: \(path) — \(error.localizedDescription)")
                    results.append(["tool": "delete_file", "path": path, "status": "error", "message": "Delete failed: \(error.localizedDescription)"])
                }
            case "list_files":
                if let items = try? FileManager.default.contentsOfDirectory(at: fullPath, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: .skipsHiddenFiles) {
                    var files: [[String: Any]] = []
                    for item in items {
                        let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                        let size = (try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
                        files.append(["name": item.lastPathComponent, "type": isDir ? "dir" : "file", "size": size as Any])
                    }
                    print("📂 [Agent] Listed \(path): \(files.count) items")
                    results.append(["tool": "list_files", "path": path, "status": "success", "message": "\(files.count) items", "files": files])
                } else {
                    print("❌ [Agent] List failed: \(path)")
                    results.append(["tool": "list_files", "path": path, "status": "error", "message": "Cannot list: \(path)"])
                }
            default:
                print("❌ [Agent] Unknown tool: \(tool)")
                results.append(["tool": tool, "path": path, "status": "error", "message": "Unknown tool: \(tool)"])
            }
        }
        // Restore generic label after batch completes
        agentProcessingText = "Sending results…"
        return results
    }
    
    private func toolLabel(_ tool: String, path: String) -> String {
        let icon = ["read_file":"📖 Reading","write_file":"✏️ Writing","delete_file":"🗑 Deleting","list_files":"📂 Listing"][tool] ?? "🔧 Running"
        return "\(icon) \(path)…"
    }
    
    /// Fallback: write file via shell command (bypasses sandbox restrictions)
    private func writeViaShell(fullPath: URL, content: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Use stdin redirection instead of positional params to avoid $1 Swift issue
        let escapedPath = fullPath.path.replacingOccurrences(of: "'", with: "'\\''")
        process.arguments = ["-c", "cat > '\(escapedPath)'"]
        
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        try process.run()
        if let data = content.data(using: .utf8) {
            try inputPipe.fileHandleForWriting.write(contentsOf: data)
        }
        inputPipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "Agent", code: Int(process.terminationStatus), 
                         userInfo: [NSLocalizedDescriptionKey: "Shell exit code \(process.terminationStatus)"])
        }
    }
    
    private func continueAgent(token: String, results: [[String: Any]]) async {
        let url = APIClient.shared.sendAgentContinueURL(roomId: room.id)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 30
        if let t = APIConfig.token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        req.httpBody = APIClient.shared.sendAgentContinueBody(stateToken: token, results: results)
        
        var full = ""
        do {
            agentProcessingText = "Sending results to AI…"
            print("📡 [Agent:Continue] Sending \(results.count) results...")
            let (bytes, response) = try await URLSession.shared.bytes(for: req)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("📡 [Agent:Continue] Connected: \(statusCode)")
            agentProcessingText = statusCode == 200 ? "Waiting for AI…" : "Server responded \(statusCode)"
            
            var agentStateToken: String? = nil
            var agentRequests: [[String: Any]]? = nil
            
            for try await line in bytes.lines {
                if Task.isCancelled { break }
                guard line.hasPrefix("data: "), let d = line.dropFirst(6).data(using: .utf8) else { continue }
                guard let o = try? JSONSerialization.jsonObject(with: d) as? [String:Any] else { continue }
                // First content clears the "Waiting" label
                if o["content"] != nil && agentProcessingText == "Waiting for AI…" { agentProcessingText = "" }
                if let e = o["error"] as? String {
                    streamingText = "Error: \(e)"; agentProcessingText = ""
                    break
                }
                if let type = o["type"] as? String, type == "meta" {
                    if let s = o["status"] as? String {
                        if s == "agent_tool_requests" {
                            agentStateToken = o["state_token"] as? String
                            agentRequests = o["requests"] as? [[String: Any]]
                            agentProcessingText = "Executing more tools..."
                        } else if s == "agent_analyzing" || s == "agent_thinking" {
                            agentProcessingText = "AI is thinking…"
                        }
                    }
                    continue
                }
                if let c = o["content"] as? String { full += c; streamingText = full }
                if o["done"] as? Bool == true {
                    // More tools? Loop
                    if o["awaiting_tools"] as? Bool == true, let t2 = agentStateToken, let r2 = agentRequests {
                        guard agentTurnCount < 8 else {
                            streamingText = "⚠️ Agent reached max turns. Try a simpler request."
                            agentProcessingText = ""; break
                        }
                        agentTurnCount += 1
                        print("📡 [Agent] Executing \(r2.count) more tools (turn \(agentTurnCount))...")
                        let results2 = executeAgentTools(r2, workspace: agentWorkspaceURL)
                        await continueAgent(token: t2, results: results2)
                    }
                    break
                }
            }
        } catch {
            if !Task.isCancelled {
                print("📡 [Agent:Continue] error: \(error)")
                streamingText = "Error: \(error.localizedDescription)"
                agentProcessingText = ""
            }
        }
        if !Task.isCancelled {
            print("📡 [Agent:Continue] Done. Response: \(full.count) chars")
            isStreaming = false; agentProcessingText = ""
            if !full.isEmpty {
                let botMsg = ChatMessage(content: full, isUser: false, hasReasoning: isDeepSeekPro)
                withAnimation { messages.append(botMsg) }
                if isAutoSpeakEnabled { speechSynth.speak(speakableText(full), messageId: botMsg.id) }
            }
            if !streamingText.hasPrefix("Error") && !streamingText.hasPrefix("⚠️") { streamingText = "" }; if memoryUsed >= memoryMax { memoryUsed = 2 }
        }
    }
    private func stopStreaming() { streamingTask?.cancel(); streamingTask = nil; isStreaming = false; streamingText = ""; agentProcessingText = ""; Task { try? await APIClient.shared.clearLocks() } }
    
    /// Strip HTML + DeepSeek thinking blocks for clean TTS output.
    private func speakableText(_ content: String) -> String {
        var text = content
        while let s = text.range(of: "<details class=\"ds-thinking\">"),
              let e = text.range(of: "</details>", range: s.upperBound..<text.endIndex) {
            text.removeSubrange(s.lowerBound..<e.upperBound)
        }
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespaces)
    }
    private func openWorkspacePicker() {
        #if os(macOS)
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.allowsMultipleSelection = false; p.message = "Select workspace for Agent"
        if p.runModal() == .OK, let u = p.url {
            // Security-scoped bookmark for persistent access
            _ = u.startAccessingSecurityScopedResource()
            do {
                let bookmark = try u.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmark, forKey: "agent_workspace_bookmark")
            } catch { print("⚠️ [Agent] Bookmark failed: \(error)") }
            agentWorkspaceURL = u
            showWorkspaceTrustAlert = true
            print("📁 [Agent] Workspace set: \(u.path)")
        }
        #else
        showWorkspacePicker = true
        #endif
    }
}

// MARK: - Toggle Buttons
struct ToggleButton: View {
    let label: String; let icon: String; @Binding var isOn: Bool; let color: Color
    var body: some View { Button(action: { withAnimation { isOn.toggle() } }) { HStack(spacing: 3) { Image(systemName: isOn ? "\(icon).fill" : icon).font(.system(size: 10)); Text(label) }.font(.hermes.badge).padding(.horizontal, HermesSpacing.sm).padding(.vertical, 3).background(isOn ? color.opacity(0.15) : Color.hermes.hover).foregroundColor(isOn ? color : .hermes.muted).cornerRadius(HermesRadius.sm).overlay(RoundedRectangle(cornerRadius: HermesRadius.sm).strokeBorder(isOn ? color.opacity(0.3) : .clear, lineWidth: 1)) }.buttonStyle(PlainButtonStyle()) }
}
struct DeepSeekProToggle: View {
    @Binding var isOn: Bool; let visible: Bool
    var body: some View { if visible { ToggleButton(label: "Pro", icon: "brain.head.profile", isOn: $isOn, color: .purple) } }
}

// MARK: - Rich Markdown Renderer
private struct RichMessageContent: View {
    let content: String; let isUser: Bool
    @State private var webHeight: CGFloat = 40
    
    var body: some View {
        if isUser {
            Text(content).font(.hermes.body).foregroundColor(.white).lineSpacing(4).textSelection(.enabled)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(parsedBlocks) { block in
                    switch block.type {
                    case .thinking(let summary, let body):
                        thinkingBlock(summary: summary, body: body)
                    case .markdown(let md):
                        MarkdownWebView(html: MarkdownHTMLRenderer.render(md), contentHeight: $webHeight)
                            .frame(height: max(webHeight, 40))
                    }
                }
            }
        }
    }
    
    private func thinkingBlock(summary: String, body: String) -> some View {
        DisclosureGroup {
            Text(.init(body))
                .font(.hermes.caption)
                .foregroundColor(.hermes.muted)
                .lineSpacing(4)
                .padding(.vertical, 4)
        } label: {
            Label(summary, systemImage: "brain.head.profile")
                .font(.hermes.caption)
                .foregroundColor(.purple)
        }
        .padding(10)
        .background(Color.purple.opacity(0.06))
        .cornerRadius(HermesRadius.md)
    }
    
    struct Block: Identifiable {
        let id = UUID()
        let type: BlockType
        enum BlockType {
            case thinking(summary: String, body: String)
            case markdown(String)
        }
    }
    
    private var parsedBlocks: [Block] {
        var text = content
        var blocks: [Block] = []
        
        // Extract DeepSeek thinking blocks
        while let start = text.range(of: "<details class=\"ds-thinking\">") {
            // Text before thinking block
            let prefix = String(text[text.startIndex..<start.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !prefix.isEmpty {
                blocks.append(Block(type: .markdown(sanitize(prefix))))
            }
            
            guard let end = text.range(of: "</details>", range: start.upperBound..<text.endIndex) else {
                // Orphaned opening tag — strip it and continue
                text.removeSubrange(start.lowerBound..<text.endIndex)
                break
            }
            
            let inner = String(text[start.upperBound..<end.lowerBound])
            let summary: String
            let body: String
            if let ss = inner.range(of: "<summary>"), let se = inner.range(of: "</summary>") {
                summary = String(inner[ss.upperBound..<se.lowerBound])
                    .replacingOccurrences(of: "💭", with: "")
                    .trimmingCharacters(in: .whitespaces)
                body = String(inner[se.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                summary = "Thinking"
                body = inner.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            blocks.append(Block(type: .thinking(summary: summary, body: body)))
            
            text = String(text[end.upperBound...])
        }
        
        // Remaining text after all thinking blocks
        let remaining = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            blocks.append(Block(type: .markdown(sanitize(remaining))))
        }
        
        return blocks
    }
    
    /// Strip residual HTML tags (orphaned </details>, unclosed tags, etc.)
    private func sanitize(_ text: String) -> String {
        var cleaned = text
        // Remove all HTML tags
        cleaned = cleaned.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Collapse multiple newlines
        cleaned = cleaned.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
