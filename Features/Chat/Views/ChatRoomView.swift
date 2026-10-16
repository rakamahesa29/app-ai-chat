import SwiftUI
import MarkdownUI
struct ChatRoomView: View {
    let room: ChatRoom
    var isMobile: Bool
    @Binding var isSidebarOpen: Bool
    var onDeleteRoom: (() -> Void)? = nil
    var onModelChange: ((String) -> Void)? = nil
    
    @State private var messages: [ChatMessage] = []
    @State private var isStreaming = false
    @State private var streamingText = ""
    @State private var isLoadingMessages = false
    @AppStorage("deepseek_pro_enabled") private var isDeepSeekPro = false
    @AppStorage("skripsi_mode_enabled") private var isSkripsiMode = false
    @State private var isWebSearchEnabled = false
    @State private var memoryUsed = 0
    @State private var memoryMax = 10
    @State private var isRateLimited = false
    @State private var rateLimitMessage: String?
    @State private var selectedModel: String = "ollama"
    @State private var streamingTask: Task<Void, Never>? = nil
    @AppStorage("active_chat_mode") private var chatModeRaw: String = "ask"
    private var chatMode: ChatMode {
        get { ChatMode(rawValue: chatModeRaw) ?? .ask }
        nonmutating set { chatModeRaw = newValue.rawValue }
    }
    @State private var agentWorkspaceURL: URL? = nil
    @State private var showWorkspacePicker = false
    @State private var showWorkspaceTrustAlert = false
    @ObservedObject private var securityManager = AgentSecurityManager.shared
    @State private var showAgentSecuritySheet = false
    @State private var scrollProxy: ScrollViewProxy?
    @StateObject private var speechSynth = SpeechSynthesizer()
    @State private var isAutoSpeakEnabled = false
    @State private var agentProcessingText = ""
    @State private var agentTurnCount = 0
    // Antigravity-style sequential checkpoints for current agent turn.
    @State private var currentTurnCheckpoints: [AgentCheckpoint] = []
    // Cursor-CLI style running activity log for the current agent turn.
    @State private var agentLog: [AgentLogEvent] = []
    @State private var isAgentLogExpanded: Bool = true
    @State private var agentThinkingText = ""
    @State private var isAgentThinkingExpanded = false
    
    enum ChatMode: String, CaseIterable {
        case ask = "Ask", agent = "Agent"
        var icon: String { self == .ask ? "bubble.left.and.bubble.right" : "hammer" }
    }

    // MARK: - Agent Log
    struct AgentLogEvent: Identifiable, Equatable {
        let id = UUID()
        let time: Date
        let level: Level
        let icon: String
        let text: String
        enum Level { case info, thinking, tool, success, warn, error }
    }
    
    var isEducationRoom: Bool { room.persona == "education" }
    
    var body: some View {
        VStack(spacing: 0) {
            chatHeader; Divider().foregroundColor(.hermes.border)
            if chatMode == .agent { agentCompactBar }
            if !agentProcessingText.isEmpty { agentProcessingBar }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: HermesSpacing.lg) {
                        ForEach(messages) { msg in messageRow(for: msg).id(msg.id) }
                        // Antigravity-style sequential checkpoints for currently running agent task
                        if chatMode == .agent && !currentTurnCheckpoints.isEmpty {
                            AgentCheckpointsSequenceView(checkpoints: currentTurnCheckpoints)
                                .id("agent_checkpoints")
                        }
                        // Inline Cursor-CLI-style agent activity log — appears above the streaming reply
                        if chatMode == .agent && !agentLog.isEmpty {
                            agentActivityBlock.id("agent_log")
                        }
                        // Inline Agent Confirmation Card (for Allow Per Task mode)
                        if let confirmation = securityManager.pendingConfirmation {
                            AgentConfirmationCard(confirmation: confirmation, onApprove: {
                                securityManager.resolvePendingConfirmation(approved: true)
                            }, onDeny: {
                                securityManager.resolvePendingConfirmation(approved: false)
                            })
                            .id("agent_confirmation")
                        }
                        if !agentThinkingText.isEmpty { thinkingBubble.id("thinking") }
                        if isStreaming { streamingBubble.id("streaming") }
                        if isRateLimited { rateLimitBanner.id("rate_limit") }
                        if isStreaming {
                            Button(action: stopStreaming) {
                                HStack(spacing: 5) {
                                    Image(systemName: "stop.circle.fill")
                                    Text("Stop Generating")
                                }
                                .font(.hermes.captionMedium)
                                .foregroundColor(.white)
                                .padding(.horizontal, HermesSpacing.md)
                                .padding(.vertical, HermesSpacing.xs + 2)
                                .background(Color.hermes.danger)
                                .cornerRadius(HermesRadius.sm)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            .id("stop_btn")
                        }
                    }.padding(.horizontal, HermesSpacing.lg).padding(.vertical, HermesSpacing.lg)
                }
                .onAppear { scrollProxy = proxy }
                .onChange(of: messages.count) { scrollToBottom() }
                // Only follow streaming text while the reply is actually being
                // built up. Ignoring the trailing "" reset avoids a redundant
                // animated scroll at completion time (part of the flicker fix).
                .onChange(of: streamingText) { _, new in
                    if isStreaming && !new.isEmpty { scrollToBottom() }
                }
                .onChange(of: agentLog.count) { scrollToBottom() }
            }
            ComposerView(
                roomId: room.id,
                onSend: { text, images in
                    sendMessage(text, images: images)
                },
                onStop: {
                    stopStreaming()
                },
                isStreaming: isStreaming,
                isRateLimited: isRateLimited,
                rateLimitMessage: rateLimitMessage,
                chatMode: chatMode,
                hasWorkspace: agentWorkspaceURL != nil || securityManager.accessScope == .fullSystem,
                isAutoSpeakEnabled: $isAutoSpeakEnabled,
                isWebSearchEnabled: $isWebSearchEnabled
            )
            statusBar
        }
        .background(Color.hermes.bg)
        .task(id: room.id) { await fetchMessages() }
        .onAppear { selectedModel = room.model }
        .onChange(of: room.id) { selectedModel = room.model }
        .onChange(of: selectedModel) { _, new in onModelChange?(new) }
        .onChange(of: isAutoSpeakEnabled) { if !isAutoSpeakEnabled { speechSynth.stop() } }
        .onDisappear {
            streamingTask?.cancel()
            securityManager.cancelPendingConfirmation()
        }
        .sheet(isPresented: $showAgentSecuritySheet) {
            AgentSecuritySetupSheet()
        }
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
            
            // Mode Switcher (Ask vs Agent)
            HStack(spacing: 2) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        chatMode = .ask
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 11))
                        Text("Ask")
                            .font(.hermes.captionMedium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(chatMode == .ask ? Color.hermes.accent : Color.clear)
                    .foregroundColor(chatMode == .ask ? .white : .hermes.muted)
                    .cornerRadius(HermesRadius.sm)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        chatMode = .agent
                        if !securityManager.hasConfiguredSecurity {
                            showAgentSecuritySheet = true
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 11))
                        Text("Agent")
                            .font(.hermes.captionMedium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(chatMode == .agent ? Color.orange : Color.clear)
                    .foregroundColor(chatMode == .agent ? .white : .hermes.muted)
                    .cornerRadius(HermesRadius.sm)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(2)
            .background(Color.hermes.bg)
            .cornerRadius(HermesRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: HermesRadius.md)
                    .strokeBorder(Color.hermes.border, lineWidth: 1)
            )

            if isEducationRoom { ToggleButton(label: "Skripsi", icon: "graduationcap", isOn: $isSkripsiMode, color: .orange) }
            DeepSeekProToggle(isOn: $isDeepSeekPro, visible: selectedModel == "deepseek")
            Menu {
                Section("Standard Models") {
                    Button(action: { selectedModel = "ollama" }) {
                        if selectedModel == "ollama" { Label("Ornith (Local)", systemImage: "checkmark") } else { Text("Ornith (Local)") }
                    }
                    Button(action: { selectedModel = "ollama_cloud" }) {
                        if selectedModel == "ollama_cloud" { Label("Gemma4 31B Cloud", systemImage: "checkmark") } else { Text("Gemma4 31B Cloud") }
                    }
                    Button(action: { selectedModel = "deepseek" }) {
                        if selectedModel == "deepseek" { Label("DeepSeek API", systemImage: "checkmark") } else { Text("DeepSeek API") }
                    }
                }
                Menu("Gemini 3.8 Flash") {
                    Button(action: { selectedModel = "gemini-3.8-flash-low" }) {
                        if selectedModel == "gemini-3.8-flash-low" || selectedModel == "gemini_pro" || selectedModel == "gemini" { Label("Low Thinking", systemImage: "checkmark") } else { Text("Low Thinking") }
                    }
                    Button(action: { selectedModel = "gemini-3.8-flash-medium" }) {
                        if selectedModel == "gemini-3.8-flash-medium" { Label("Medium Thinking", systemImage: "checkmark") } else { Text("Medium Thinking") }
                    }
                    Button(action: { selectedModel = "gemini-3.8-flash-high" }) {
                        if selectedModel == "gemini-3.8-flash-high" { Label("High Thinking", systemImage: "checkmark") } else { Text("High Thinking") }
                    }
                }
                Menu("Claude Sonnet 5.5") {
                    Button(action: { selectedModel = "claude-sonnet-5-5-low" }) {
                        if selectedModel == "claude-sonnet-5-5-low" { Label("Low Thinking", systemImage: "checkmark") } else { Text("Low Thinking") }
                    }
                    Button(action: { selectedModel = "claude-sonnet-5-5-medium" }) {
                        if selectedModel == "claude-sonnet-5-5-medium" { Label("Medium Thinking", systemImage: "checkmark") } else { Text("Medium Thinking") }
                    }
                    Button(action: { selectedModel = "claude-sonnet-5-5-high" }) {
                        if selectedModel == "claude-sonnet-5-5-high" { Label("High Thinking", systemImage: "checkmark") } else { Text("High Thinking") }
                    }
                }
                Menu("Claude Opus 5.5") {
                    Button(action: { selectedModel = "claude-opus-5-5-low" }) {
                        if selectedModel == "claude-opus-5-5-low" { Label("Low Thinking", systemImage: "checkmark") } else { Text("Low Thinking") }
                    }
                    Button(action: { selectedModel = "claude-opus-5-5-medium" }) {
                        if selectedModel == "claude-opus-5-5-medium" { Label("Medium Thinking", systemImage: "checkmark") } else { Text("Medium Thinking") }
                    }
                    Button(action: { selectedModel = "claude-opus-5-5-high" }) {
                        if selectedModel == "claude-opus-5-5-high" { Label("High Thinking", systemImage: "checkmark") } else { Text("High Thinking") }
                    }
                }
                Section("GPT-OSS") {
                    Button(action: { selectedModel = "gpt-oss-120b-medium" }) {
                        if selectedModel == "gpt-oss-120b-medium" { Label("GPT-OSS 120B (Medium)", systemImage: "checkmark") } else { Text("GPT-OSS 120B (Medium)") }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(modelLabel)
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.text)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(.hermes.muted)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.hermes.surface)
                .cornerRadius(HermesRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: HermesRadius.sm)
                        .strokeBorder(Color.hermes.border, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }.padding(.horizontal, HermesSpacing.lg).padding(.vertical, HermesSpacing.md).background(Color.hermes.surface)
    }
    
    private var agentCompactBar: some View {
        HStack(spacing: HermesSpacing.sm) {
            Image(systemName: "hammer").font(.system(size: 11)).foregroundColor(.hermes.accent)
            
            if securityManager.accessScope == .fullSystem {
                HStack(spacing: 4) {
                    Text("Akses:")
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.muted)
                    Text("Full Mac (Root)")
                        .font(.hermes.captionMedium)
                        .foregroundColor(.orange)
                    Text("•")
                        .foregroundColor(.hermes.muted)
                    Text(securityManager.executionMode.title)
                        .font(.hermes.captionMedium)
                        .foregroundColor(.hermes.accent)
                }
            } else if let ws = agentWorkspaceURL {
                HStack(spacing: 4) {
                    Text("Workspace:")
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.muted)
                    Text(ws.lastPathComponent)
                        .font(.hermes.captionMedium)
                        .foregroundColor(.hermes.text)
                    Button(action: {
                        agentWorkspaceURL = nil
                        UserDefaults.standard.removeObject(forKey: "agent_workspace_bookmark")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.hermes.muted)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Text("•")
                        .foregroundColor(.hermes.muted)
                    Text(securityManager.executionMode.title)
                        .font(.hermes.captionMedium)
                        .foregroundColor(.hermes.accent)
                }
            } else {
                HStack(spacing: 4) {
                    Text("Target:")
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.muted)
                    Text("Mac Global (~/)")
                        .font(.hermes.captionMedium)
                        .foregroundColor(.hermes.text)
                    Text("•")
                        .foregroundColor(.hermes.muted)
                    Text(securityManager.executionMode.title)
                        .font(.hermes.captionMedium)
                        .foregroundColor(.hermes.accent)
                }
            }
            
            Spacer()
            
            // Tombol Konfigurasi Otorisasi & Keamanan
            Button(action: { showAgentSecuritySheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: securityManager.executionMode.icon)
                        .font(.system(size: 10))
                    Text(securityManager.executionMode == .autoAllow ? "Auto-Allow" : "Per Task")
                        .font(.hermes.captionMedium)
                }
                .foregroundColor(.hermes.accent)
                .padding(.horizontal, HermesSpacing.sm)
                .padding(.vertical, 3)
                .background(Color.hermes.accent.opacity(0.12))
                .cornerRadius(HermesRadius.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Tombol Pilih Folder (Opsional)
            Button(action: { openWorkspacePicker() }) {
                HStack(spacing: 4) {
                    Image(systemName: agentWorkspaceURL != nil ? "folder.fill" : "folder.badge.plus")
                        .font(.system(size: 10))
                    Text(agentWorkspaceURL != nil ? "Ubah Folder" : "Fokus Folder (Opsional)")
                        .font(.hermes.captionMedium)
                }
                .foregroundColor(.hermes.textSecondary)
                .padding(.horizontal, HermesSpacing.sm)
                .padding(.vertical, 3)
                .background(Color.hermes.hover)
                .cornerRadius(HermesRadius.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, HermesSpacing.lg).padding(.vertical, HermesSpacing.sm)
        .background(Color.hermes.surface)
        .overlay(alignment: .top) { Divider().foregroundColor(.hermes.border) }
    }

    // MARK: - Inline Agent Activity Log (Cursor CLI style)
    private var agentActivityBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isAgentLogExpanded.toggle() }
            } label: {
                HStack(spacing: HermesSpacing.sm) {
                    Image(systemName: isStreaming ? "circle.dotted" : "checkmark.circle")
                        .font(.system(size: 11))
                        .foregroundColor(isStreaming ? .hermes.accent : .hermes.success)
                        .rotationEffect(.degrees(isStreaming ? 360 : 0))
                        .animation(isStreaming ? .linear(duration: 1.4).repeatForever(autoreverses: false) : .default, value: isStreaming)
                    Text("Agent Activity")
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.text)
                    Text("· \(agentLog.count) event\(agentLog.count == 1 ? "" : "s")")
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.muted)
                    Spacer()
                    Image(systemName: isAgentLogExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(.hermes.muted)
                }
                .padding(.horizontal, HermesSpacing.md)
                .padding(.vertical, HermesSpacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isAgentLogExpanded {
                Divider().foregroundColor(.hermes.border)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(agentLog) { event in
                        agentLogRow(event)
                    }
                }
                .padding(.horizontal, HermesSpacing.md)
                .padding(.vertical, HermesSpacing.sm)
            }
        }
        .background(Color.hermes.card.opacity(0.6))
        .cornerRadius(HermesRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: HermesRadius.md)
                .strokeBorder(Color.hermes.border.opacity(0.6), lineWidth: 1)
        )
        .opacity(0.9)
    }

    private func agentLogRow(_ event: AgentLogEvent) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(Self.logTimeFormatter.string(from: event.time))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.hermes.muted.opacity(0.7))
                .frame(width: 52, alignment: .leading)
            Image(systemName: event.icon)
                .font(.system(size: 9))
                .foregroundColor(agentLogColor(event.level))
                .frame(width: 12, alignment: .center)
            Text(event.text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.hermes.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func agentLogColor(_ level: AgentLogEvent.Level) -> Color {
        switch level {
        case .info:     return .hermes.muted
        case .thinking: return .hermes.accent
        case .tool:     return .orange
        case .success:  return .hermes.success
        case .warn:     return .hermes.warning
        case .error:    return .hermes.danger
        }
    }

    private static let logTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    @MainActor
    private func logAgent(_ text: String, level: AgentLogEvent.Level = .info, icon: String? = nil) {
        let defaultIcon: String = {
            switch level {
            case .info:     return "info.circle"
            case .thinking: return "brain"
            case .tool:     return "hammer"
            case .success:  return "checkmark.circle"
            case .warn:     return "exclamationmark.triangle"
            case .error:    return "xmark.octagon"
            }
        }()
        agentLog.append(AgentLogEvent(time: Date(), level: level, icon: icon ?? defaultIcon, text: text))
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
            Image(systemName: "clock").foregroundColor(.hermes.warning).font(.system(size: 12))
            Text(rateLimitMessage ?? "Please wait…").font(.hermes.caption).foregroundColor(.hermes.warning)
        }.padding(HermesSpacing.md).background(Color.hermes.warning.opacity(0.08)).cornerRadius(HermesRadius.md)
    }
    
    private var statusBar: some View {
        HStack(spacing: HermesSpacing.md) {
            statusItem(icon: "cpu", text: modelLabel)
            statusItem(icon: "person.circle", text: personaLabel(room.persona))
            if chatMode == .agent {
                let wsName = agentWorkspaceURL?.lastPathComponent ?? (securityManager.accessScope == .fullSystem ? "Full Mac (/)" : "Home (~)")
                statusItem(icon: "hammer", text: wsName, color: .hermes.accent)
            }
            Spacer()
            Button(action: {
                withAnimation {
                    chatMode = chatMode == .ask ? .agent : .ask
                    if chatMode == .agent && !securityManager.hasConfiguredSecurity {
                        showAgentSecuritySheet = true
                    }
                }
            }) {
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
                if !msg.checkpoints.isEmpty {
                    AgentCheckpointsSequenceView(checkpoints: msg.checkpoints)
                        .padding(.bottom, 2)
                }
                VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                    RichMessageContent(content: msg.content, isUser: msg.isUser)
                }
                .textSelection(.enabled)
                .padding(HermesSpacing.md)
                .background(msg.isUser ? Color.hermes.accent : Color.hermes.card.opacity(0.5))
                .cornerRadius(HermesRadius.lg)
                .overlay(RoundedRectangle(cornerRadius: HermesRadius.lg).strokeBorder(msg.isUser ? Color.clear : Color.hermes.border, lineWidth: 1))
                .contextMenu {
                    Button {
                        copy(msg)
                    } label: {
                        Label("Salin Pesan (Copy)", systemImage: "doc.on.doc")
                    }
                    if !msg.isUser {
                        Button {
                            if speechSynth.isSpeaking { speechSynth.stop() }
                            else { speechSynth.speak(speakableText(msg.content), messageId: msg.id) }
                        } label: {
                            Label(speechSynth.isSpeaking ? "Hentikan Suara" : "Bacakan (Read Aloud)", systemImage: speechSynth.isSpeaking ? "speaker.slash" : "speaker.wave.2")
                        }
                        if isSkripsiMode {
                            Divider()
                            Button { exportToDocx(msg) } label: { Label("Export Word (.docx)", systemImage: "doc.text") }
                            Button { exportToGoogleDocs(msg) } label: { Label("Export Google Docs", systemImage: "doc.text.image") }
                            Button { exportToGoogleSheets(msg) } label: { Label("Export Google Sheets", systemImage: "tablecells") }
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        deleteMsg(msg)
                    } label: {
                        Label("Hapus Pesan", systemImage: "trash")
                    }
                }
                // Action buttons
                HStack(spacing: HermesSpacing.sm) {
                    if !msg.isUser {
                        IconBtn("hand.thumbsup", active: msg.rating == .up, color: .hermes.success) { rate(msg, .up) }
                        IconBtn("hand.thumbsdown", active: msg.rating == .down, color: .hermes.danger) { rate(msg, .down) }
                        IconBtn("doc.on.doc") { copy(msg) }
                        let spk = speechSynth.isSpeaking
                        IconBtn(spk ? "speaker.wave.2" : "speaker.wave.1",
                                color: spk ? .hermes.accent : .hermes.muted) {
                            if speechSynth.isSpeaking { speechSynth.stop() }
                            else { speechSynth.speak(speakableText(msg.content), messageId: msg.id) }
                        }
                        if isSkripsiMode {
                            Menu {
                                Button(action: { exportToDocx(msg) }) { Label("Word (.docx)", systemImage: "doc.text") }
                                Button(action: { exportToGoogleDocs(msg) }) { Label("Google Docs", systemImage: "doc.text.image") }
                                Button(action: { exportToGoogleSheets(msg) }) { Label("Google Sheets", systemImage: "tablecells") }
                            } label: {
                                Image(systemName: "square.and.arrow.up").font(.system(size: 11)).foregroundColor(.hermes.muted)
                            }.buttonStyle(PlainButtonStyle())
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
        Button(action: action) { Image(systemName: icon).font(.system(size: 11)).foregroundColor(active ? color : .hermes.muted) }.buttonStyle(PlainButtonStyle())
    }
    
    private var thinkingBubble: some View {
        HStack {
            DisclosureGroup(isExpanded: $isAgentThinkingExpanded) {
                Text(agentThinkingText)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } label: {
                Label("DeepSeek is thinking...", systemImage: "brain")
                    .foregroundColor(.hermes.accent)
                    .font(.hermes.body)
            }
            .padding()
            .background(Color.hermes.surface)
            .cornerRadius(HermesSpacing.md)
            .textSelection(.enabled)
            
            Spacer()
        }
    }

    private var streamingBubble: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                if streamingText.isEmpty {
                    ProgressView().scaleEffect(0.8)
                } else {
                    RichMessageContent(content: streamingText, isUser: false)
                        .textSelection(.enabled)
                        .padding(HermesSpacing.md)
                        .background(Color.hermes.card.opacity(0.5))
                        .cornerRadius(HermesRadius.lg)
                        .overlay(RoundedRectangle(cornerRadius: HermesRadius.lg).strokeBorder(Color.hermes.border, lineWidth: 1))
                }
            }
            Spacer(minLength: 60)
        }
    }
    
    // Computed
    private var modelLabel: String {
        switch selectedModel {
        case "ollama": "Ornith"
        case "ollama_cloud": "Gemma4 31B"
        case "deepseek": isDeepSeekPro ? "DeepSeek Pro" : "DeepSeek Flash"
        case "gemini-3.8-flash-low", "gemini_pro", "gemini": "Gemini 3.8 Flash (Low)"
        case "gemini-3.8-flash-medium": "Gemini 3.8 Flash (Med)"
        case "gemini-3.8-flash-high": "Gemini 3.8 Flash (High)"
        case "claude-sonnet-5-5-low": "Claude Sonnet (Low)"
        case "claude-sonnet-5-5-medium": "Claude Sonnet (Med)"
        case "claude-sonnet-5-5-high": "Claude Sonnet (High)"
        case "claude-opus-5-5-low": "Claude Opus (Low)"
        case "claude-opus-5-5-medium": "Claude Opus (Med)"
        case "claude-opus-5-5-high": "Claude Opus (High)"
        case "gpt-oss-120b-medium": "GPT-OSS 120B"
        default: selectedModel
        }
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

    /// Sync memory cycle display using total message count (user + bot)
    /// with modulo arithmetic, matching the web frontend's logic.
    private func updateMemoryCycle() {
        let total = messages.count
        let mod = total % memoryMax
        memoryUsed = (mod == 0 && total > 0) ? memoryMax : mod
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
    
    private func exportToDocx(_ msg: ChatMessage) {
        Task {
            do {
                let url = try await APIClient.shared.exportDocx(messageId: msg.id)
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #else
                print("Exported to: \(url)")
                #endif
            } catch { print("Docx export error: \(error)") }
        }
    }
    
    private func exportToGoogleDocs(_ msg: ChatMessage) {
        Task {
            do {
                let url = try await APIClient.shared.exportGoogleDocs(messageId: msg.id)
                if let u = URL(string: url) {
                    #if os(macOS)
                    NSWorkspace.shared.open(u)
                    #else
                    UIApplication.shared.open(u)
                    #endif
                }
            } catch { print("Google Docs export error: \(error)") }
        }
    }
    
    private func exportToGoogleSheets(_ msg: ChatMessage) {
        Task {
            do {
                let url = try await APIClient.shared.exportGoogleSheets(messageId: msg.id)
                if let u = URL(string: url) {
                    #if os(macOS)
                    NSWorkspace.shared.open(u)
                    #else
                    UIApplication.shared.open(u)
                    #endif
                }
            } catch { print("Google Sheets export error: \(error)") }
        }
    }
    
    // API
    private func fetchMessages() async {
        isLoadingMessages = true
        do {
            messages = try await APIClient.shared.fetchMessages(roomId: room.id).map {
                ChatMessage(id: String($0.id), content: $0.content, isUser: $0.senderType == "user")
            }
            updateMemoryCycle()
        }
        catch { print("Fetch msgs: \(error)") }
        isLoadingMessages = false
    }
    
    // SSE Send
    private func sendMessage(_ text: String, images: [String] = []) {
        guard !isRateLimited else { return }
        agentTurnCount = 0
        streamingTask?.cancel()
        let um = ChatMessage(content: text, isUser: true, hasWebContext: isWebSearchEnabled)
        withAnimation { messages.append(um) }
        updateMemoryCycle()
        isStreaming = true; streamingText = ""
        // continueAgent handles its own completion (append + isStreaming=false).
        // We set this to true before delegating so sendMessage's outer
        // completion block skips re-doing the same work.
        var didHandOffToContinue = false
        // Reset agent activity log for this new turn (only shown in agent mode).
        if chatMode == .agent {
            agentLog.removeAll()
            currentTurnCheckpoints.removeAll()
            isAgentLogExpanded = true
            logAgent("Sending request to agent…", level: .info, icon: "paperplane")
        }
        let url = APIClient.shared.sendMessageStreamURL(roomId: room.id)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let t = APIConfig.token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let effectiveWorkspacePath = agentWorkspaceURL?.path ?? (securityManager.accessScope == .fullSystem ? "/" : FileManager.default.homeDirectoryForCurrentUser.path)
        req.httpBody = APIClient.shared.sendMessageBody(message: text, model: selectedModel, useWebSearch: isWebSearchEnabled, deepseekPro: isDeepSeekPro, skripsiMode: isSkripsiMode, workspacePath: effectiveWorkspacePath, chatMode: chatMode == .agent ? "agent" : "ask", images: images)
        var full = ""
        streamingTask = Task {
            defer { streamingTask = nil }
            do {
                print("📡 [SSE] Connecting to: \(url)"); print("📡 [SSE] Model: \(selectedModel)")
                let (bytes, response) = try await APIClient.streamingSession.bytes(for: req)
                print("📡 [SSE] Connected: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                
                var agentStateToken: String? = nil
                var agentRequests: [[String: Any]]? = nil
                
                for try await line in bytes.lines {
                    if Task.isCancelled { print("📡 [SSE] Cancelled"); break }
                    guard line.hasPrefix("data: "), let d = line.dropFirst(6).data(using: .utf8) else { if !line.isEmpty { print("📡 [SSE] non-data: \(line.prefix(80))") }; continue }
                    guard let o = try? JSONSerialization.jsonObject(with: d) as? [String:Any] else { continue }
                    if let e = o["error"] as? String { print("📡 [SSE] error: \(e)"); streamingText = "Error: \(e)"; break }
                    if let type = o["type"] as? String {
                        if type == "meta" {
                            if let s = o["status"] as? String {
                                print("📡 [SSE] meta: \(s)")
                                handleAgentMetaEvent(s, payload: o)
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
                        } else if type == "thinking_start" {
                            agentThinkingText = ""
                            isAgentThinkingExpanded = true
                            continue
                        } else if type == "thinking" {
                            if let c = o["content"] as? String { agentThinkingText += c }
                            continue
                        } else if type == "thinking_end" {
                            continue
                        } else if type == "chunk" {
                            if let c = o["content"] as? String { full += c; streamingText = full }
                            continue
                        }
                    }
                    if let c = o["content"] as? String { full += c; streamingText = full }
                    if o["done"] as? Bool == true {
                        // Agent awaiting tool execution
                        if o["awaiting_tools"] as? Bool == true, let token = agentStateToken, let requests = agentRequests {
                            guard agentTurnCount < 30 else {
                                streamingText = "⚠️ Agent reached max turns. Try a simpler request."
                                agentProcessingText = ""; break
                            }
                            agentTurnCount += 1
                            print("📡 [Agent] Executing \(requests.count) tools locally (turn \(agentTurnCount))...")
                            let results = await executeAgentToolsAsync(requests, workspace: agentWorkspaceURL)
                            print("📡 [Agent] Tools done, continuing with token: \(token.prefix(8))...")
                            didHandOffToContinue = true
                            await continueAgent(token: token, results: results)
                        }
                        print("📡 [SSE] done"); break
                    }
                }
            } catch {
                if !Task.isCancelled {
                    print("📡 [SSE] error: \(error)")
                    streamingText = "Error: \(error.localizedDescription)"
                    if chatMode == .agent { logAgent("stream error: \(error.localizedDescription)", level: .error) }
                }
            }
            if !Task.isCancelled && !didHandOffToContinue {
                print("📡 [SSE] Done. Response length: \(full.count)")
                finalizeReply(full: full)
                if chatMode == .agent && !agentLog.isEmpty {
                    logAgent("done (\(full.count) chars)", level: .success, icon: "flag.checkered")
                }
            }
        }
    }
    
    // MARK: - Agent Tool Execution
    
    private func executeAgentToolsAsync(_ requests: [[String: Any]], workspace: URL?) async -> [[String: Any]] {
        var base = workspace
        var bookmarkAccessing = false
        if let data = UserDefaults.standard.data(forKey: "agent_workspace_bookmark") {
            var stale = false
            if let resolved = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
                bookmarkAccessing = resolved.startAccessingSecurityScopedResource()
                base = resolved
                if stale {
                    if let fresh = try? resolved.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                        UserDefaults.standard.set(fresh, forKey: "agent_workspace_bookmark")
                    }
                }
            }
        }
        defer { if bookmarkAccessing { base?.stopAccessingSecurityScopedResource() } }
        
        let isFullSystem = securityManager.accessScope == .fullSystem
        if base == nil {
            base = isFullSystem ? URL(fileURLWithPath: "/") : FileManager.default.homeDirectoryForCurrentUser
        }
        
        guard let base = base else {
            print("❌ [Agent] No workspace URL!")
            await MainActor.run { agentProcessingText = "Error: No workspace selected" }
            return [["tool": "error", "path": "", "status": "error", "message": "No workspace selected"]]
        }
        
        print("📁 [Agent] Workspace base: \(base.path) (Full System: \(isFullSystem))")
        
        let finalBase = base
        var results: [[String: Any]] = []
        
        // Execute sequentially to handle sequential user approvals in Allow Per Task mode
        for req in requests {
            if Task.isCancelled {
                print("🛑 [Agent] Tool loop cancelled by user")
                break
            }
            let res = await self.executeSingleTool(req, base: finalBase, isFullSystem: isFullSystem)
            results.append(res)
        }
        
        await MainActor.run {
            self.agentProcessingText = "Sending results…"
            self.logAgent("Sending results back to AI…", level: .info, icon: "paperplane")
        }
        return results
    }
    
    private func executeSingleTool(_ req: [String: Any], base: URL, isFullSystem: Bool) async -> [String: Any] {
        let tool = req["tool"] as? String ?? ""
        var path = req["path"] as? String ?? ""
        let content = req["content"] as? String
        
        if Task.isCancelled {
            return ["tool": tool, "path": path, "status": "error", "message": "Dihentikan oleh pengguna"]
        }
        
        // Expand tilde (~) if present (e.g. ~/Desktop/test.txt -> /Users/administrator/Desktop/test.txt)
        if path.hasPrefix("~") {
            path = (path as NSString).expandingTildeInPath
        }
        
        let bp = base.path.hasSuffix("/") ? String(base.path.dropLast()) : base.path
        let fullPath: URL
        if path.hasPrefix("/") {
            // Absolute path
            fullPath = URL(fileURLWithPath: path)
        } else {
            // Relative path
            if path.hasPrefix(bp + "/") {
                path = String(path.dropFirst(bp.count + 1))
            }
            fullPath = base.appendingPathComponent(path)
        }
        
        // Check sandbox boundary only if user specifically pinned a workspace
        if !isFullSystem && agentWorkspaceURL != nil && !path.hasPrefix("/") {
            guard !path.contains(".."), fullPath.path.hasPrefix(bp) else {
                return ["tool": tool, "path": path, "status": "error", "message": "Security: path traversal outside workspace blocked"]
            }
        }
        
        let isRoot = fullPath.path.hasPrefix("/System") ||
                     fullPath.path.hasPrefix("/bin") ||
                     fullPath.path.hasPrefix("/sbin") ||
                     fullPath.path.hasPrefix("/usr") ||
                     fullPath.path.hasPrefix("/private") ||
                     fullPath.path.hasPrefix("/etc") ||
                     fullPath.path.hasPrefix("/var") ||
                     fullPath.path == "/"
        
        let label = toolLabel(tool, path: fullPath.path)
        await MainActor.run { agentProcessingText = label }
        
        // Request confirmation and trigger double verification macOS notification
        let approved = await securityManager.requestApproval(
            tool: tool,
            path: fullPath.path,
            content: content,
            isRoot: isRoot
        )
        
        if !approved {
            await MainActor.run {
                logAgent("Operation cancelled by user: \(fullPath.path)", level: .error, icon: "hand.raised.fill")
            }
            return ["tool": tool, "path": fullPath.path, "status": "error", "message": "Operation cancelled by user"]
        }
        
        var result: [String: Any] = [:]
        switch tool {
        case "write_file":
            do {
                let dir = fullPath.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try (content ?? "").write(to: fullPath, atomically: true, encoding: .utf8)
                let size = (try? fullPath.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                if FileManager.default.fileExists(atPath: fullPath.path) {
                    result = ["tool": "write_file", "path": fullPath.path, "status": "success", "message": "File created: \(fullPath.path) (\(size) bytes)"]
                    await MainActor.run { logAgent("wrote \(fullPath.lastPathComponent) (\(size) B)", level: .success) }
                } else {
                    try writeViaShell(fullPath: fullPath, content: content ?? "")
                    result = ["tool": "write_file", "path": fullPath.path, "status": "success", "message": "File created via shell: \(fullPath.path)"]
                    await MainActor.run { logAgent("wrote \(fullPath.lastPathComponent) (via shell)", level: .success) }
                }
            } catch {
                do {
                    try writeViaShell(fullPath: fullPath, content: content ?? "")
                    result = ["tool": "write_file", "path": fullPath.path, "status": "success", "message": "File created: \(fullPath.path)"]
                    await MainActor.run { logAgent("wrote \(fullPath.lastPathComponent) (via shell)", level: .success) }
                } catch {
                    if isFullSystem {
                        do {
                            try writeViaRoot(fullPath: fullPath, content: content ?? "")
                            result = ["tool": "write_file", "path": fullPath.path, "status": "success", "message": "File created with root privileges: \(fullPath.path)"]
                            await MainActor.run { logAgent("wrote \(fullPath.lastPathComponent) (root privileges)", level: .success, icon: "lock.open.fill") }
                        } catch let rootError {
                            result = ["tool": "write_file", "path": fullPath.path, "status": "error", "message": "Root write failed: \(rootError.localizedDescription)"]
                            await MainActor.run { logAgent("root write failed: \(fullPath.path) — \(rootError.localizedDescription)", level: .error) }
                        }
                    } else {
                        result = ["tool": "write_file", "path": fullPath.path, "status": "error", "message": "Write failed: \(error.localizedDescription)"]
                        await MainActor.run { logAgent("write failed: \(fullPath.path) — \(error.localizedDescription)", level: .error) }
                    }
                }
            }
        case "read_file":
            do {
                let data = try String(contentsOf: fullPath, encoding: .utf8)
                result = ["tool": "read_file", "path": fullPath.path, "status": "success", "message": "Read \(data.count) chars", "content": data]
                await MainActor.run { logAgent("read \(fullPath.lastPathComponent) (\(data.count) chars)", level: .success) }
            } catch {
                do {
                    let data = try readViaShell(fullPath: fullPath, isRoot: isRoot)
                    result = ["tool": "read_file", "path": fullPath.path, "status": "success", "message": "Read \(data.count) chars", "content": data]
                    await MainActor.run { logAgent("read \(fullPath.lastPathComponent) (via shell)", level: .success) }
                } catch {
                    result = ["tool": "read_file", "path": fullPath.path, "status": "error", "message": "Cannot read: \(fullPath.path)"]
                    await MainActor.run { logAgent("read failed: \(fullPath.path)", level: .error) }
                }
            }
        case "delete_file":
            do {
                try FileManager.default.removeItem(at: fullPath)
                result = ["tool": "delete_file", "path": fullPath.path, "status": "success", "message": "Deleted: \(fullPath.path)"]
                await MainActor.run { logAgent("deleted \(fullPath.lastPathComponent)", level: .success) }
            } catch {
                if isFullSystem {
                    do {
                        try deleteViaRoot(fullPath: fullPath)
                        result = ["tool": "delete_file", "path": fullPath.path, "status": "success", "message": "Deleted with root privileges: \(fullPath.path)"]
                        await MainActor.run { logAgent("deleted \(fullPath.lastPathComponent) (root privileges)", level: .success, icon: "lock.open.fill") }
                    } catch let rootError {
                        result = ["tool": "delete_file", "path": fullPath.path, "status": "error", "message": "Root delete failed: \(rootError.localizedDescription)"]
                        await MainActor.run { logAgent("delete failed: \(fullPath.path) — \(rootError.localizedDescription)", level: .error) }
                    }
                } else {
                    result = ["tool": "delete_file", "path": fullPath.path, "status": "error", "message": "Delete failed: \(error.localizedDescription)"]
                    await MainActor.run { logAgent("delete failed: \(fullPath.path)", level: .error) }
                }
            }
        case "list_files":
            if let items = try? FileManager.default.contentsOfDirectory(at: fullPath, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: .skipsHiddenFiles) {
                var files: [[String: Any]] = []
                for item in items {
                    let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    let size = (try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
                    files.append(["name": item.lastPathComponent, "type": isDir ? "dir" : "file", "size": size as Any])
                }
                result = ["tool": "list_files", "path": fullPath.path, "status": "success", "message": "\(files.count) items", "files": files]
                await MainActor.run { logAgent("listed \(fullPath.lastPathComponent) (\(files.count) items)", level: .success) }
            } else {
                result = ["tool": "list_files", "path": fullPath.path, "status": "error", "message": "Cannot list: \(fullPath.path)"]
                await MainActor.run { logAgent("list failed: \(fullPath.path)", level: .error) }
            }
        default:
            result = ["tool": tool, "path": fullPath.path, "status": "error", "message": "Unknown tool: \(tool)"]
            await MainActor.run { logAgent("unknown tool: \(tool)", level: .error) }
        }
        return result
    }
    
    private func toolLabel(_ tool: String, path: String) -> String {
        let icon = ["read_file":"📖 Reading","write_file":"✏️ Writing","delete_file":"🗑 Deleting","list_files":"📂 Listing"][tool] ?? "🔧 Running"
        return "\(icon) \(path)…"
    }

    /// Translate backend SSE meta events into human-readable log lines (Cursor CLI style).
    @MainActor
    private func handleAgentMetaEvent(_ status: String, payload: [String: Any]) {
        guard chatMode == .agent else { return }
        switch status {
        case "agent_start":
            let msg = (payload["message"] as? String) ?? "Agent started"
            logAgent(msg, level: .info, icon: "play")
        case "agent_thinking":
            let iter = payload["iteration"] as? Int
            logAgent(iter.map { "Thinking… (iteration \($0))" } ?? "Thinking…", level: .thinking)
        case "agent_reasoning":
            logAgent("Reasoning…", level: .thinking, icon: "brain.head.profile")
        case "agent_tool_requests":
            let n = (payload["requests"] as? [[String: Any]])?.count ?? 0
            logAgent("Planned \(n) tool call\(n == 1 ? "" : "s")", level: .tool, icon: "list.bullet.rectangle")
            if let reqs = payload["requests"] as? [[String: Any]] {
                for r in reqs {
                    let tool = r["tool"] as? String ?? "?"
                    let path = r["path"] as? String ?? ""
                    logAgent("→ \(tool)  \(path)", level: .tool, icon: iconFor(tool: tool))
                }
            }
        case "agent_waiting":
            logAgent("Awaiting client tool execution…", level: .info, icon: "hourglass")
        case "agent_resumed":
            let iter = payload["iteration"] as? Int
            logAgent(iter.map { "Resumed (iteration \($0))" } ?? "Resumed", level: .info, icon: "arrow.clockwise")
        case "agent_analyzing":
            let msg = (payload["message"] as? String) ?? "Analyzing tool results…"
            logAgent(msg, level: .thinking, icon: "sparkles")
        case "searching_internal":
            logAgent("Searching internal knowledge…", level: .info, icon: "magnifyingglass")
        case "using_model_knowledge":
            logAgent("Using model knowledge…", level: .info, icon: "brain")
        case "agent_checkpoint":
            let action = payload["action"] as? String ?? "executed"
            let path = payload["path"] as? String ?? ""
            let file = payload["file"] as? String ?? (path as NSString).lastPathComponent
            let step = payload["step"] as? Int ?? 1
            let statusCode = payload["status_code"] as? String ?? "success"
            let msg = payload["message"] as? String ?? ""
            let cp = AgentCheckpoint(action: action, path: path, file: file, step: step, statusCode: statusCode, message: msg)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentTurnCheckpoints.append(cp)
            }
            logAgent("\(action.capitalized): \(file)", level: .success, icon: "checkmark.circle")
        default:
            // Log any unrecognized backend status so nothing is silently dropped.
            let msg = (payload["message"] as? String) ?? status
            logAgent(msg, level: .info)
        }
    }

    private func iconFor(tool: String) -> String {
        switch tool {
        case "write_file":  return "square.and.pencil"
        case "read_file":   return "doc.text"
        case "delete_file": return "trash"
        case "list_files":  return "folder"
        default:            return "hammer"
        }
    }
    
    /// Fallback: write file via shell command (bypasses sandbox restrictions)
    private func writeViaShell(fullPath: URL, content: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
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
    
    private func readViaShell(fullPath: URL, isRoot: Bool) throws -> String {
        let escapedPath = fullPath.path.replacingOccurrences(of: "'", with: "'\\''")
        if isRoot {
            return try securityManager.executeRootCommand("cat '\(escapedPath)'")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "cat '\(escapedPath)'"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Agent", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode output"])
        }
        return str
    }
    
    private func writeViaRoot(fullPath: URL, content: String) throws {
        let b64 = Data(content.utf8).base64EncodedString()
        let escapedPath = fullPath.path.replacingOccurrences(of: "'", with: "'\\''")
        let dir = fullPath.deletingLastPathComponent().path.replacingOccurrences(of: "'", with: "'\\''")
        let cmd = "mkdir -p '\(dir)' && echo '\(b64)' | base64 -d > '\(escapedPath)'"
        _ = try securityManager.executeRootCommand(cmd)
    }
    
    private func deleteViaRoot(fullPath: URL) throws {
        let escapedPath = fullPath.path.replacingOccurrences(of: "'", with: "'\\''")
        let cmd = "rm -rf '\(escapedPath)'"
        _ = try securityManager.executeRootCommand(cmd)
    }
    
    private func continueAgent(token: String, results: [[String: Any]]) async {
        var currentToken = token
        var currentResults = results
        var finalFull = ""
        
        while !Task.isCancelled {
            let url = APIClient.shared.sendAgentContinueURL(roomId: room.id)
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 60
            if let t = APIConfig.token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
            req.httpBody = APIClient.shared.sendAgentContinueBody(stateToken: currentToken, results: currentResults)
            
            var turnFull = ""
            var nextStateToken: String? = nil
            var nextRequests: [[String: Any]]? = nil
            var awaitingTools = false
            
            do {
                await MainActor.run { agentProcessingText = "Sending results to AI…" }
                print("📡 [Agent:Continue] Sending \(currentResults.count) results...")
                let (bytes, response) = try await APIClient.streamingSession.bytes(for: req)
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("📡 [Agent:Continue] Connected: \(statusCode)")
                await MainActor.run { agentProcessingText = statusCode == 200 ? "Waiting for AI…" : "Server responded \(statusCode)" }
                
                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    guard line.hasPrefix("data: "), let d = line.dropFirst(6).data(using: .utf8) else { continue }
                    guard let o = try? JSONSerialization.jsonObject(with: d) as? [String:Any] else { continue }
                    
                    if o["content"] != nil && agentProcessingText == "Waiting for AI…" {
                        await MainActor.run { agentProcessingText = "" }
                    }
                    if let e = o["error"] as? String {
                        await MainActor.run {
                            streamingText = "Error: \(e)"
                            agentProcessingText = ""
                        }
                        break
                    }
                    if let type = o["type"] as? String {
                        if type == "meta" {
                            if let s = o["status"] as? String {
                                await MainActor.run {
                                    handleAgentMetaEvent(s, payload: o)
                                    if s == "agent_tool_requests" {
                                        nextStateToken = o["state_token"] as? String
                                        nextRequests = o["requests"] as? [[String: Any]]
                                        agentProcessingText = "Executing more tools..."
                                    } else if s == "agent_analyzing" || s == "agent_thinking" {
                                        agentProcessingText = "AI is thinking…"
                                    }
                                }
                            }
                            continue
                        } else if type == "thinking_start" {
                            await MainActor.run {
                                agentThinkingText = ""
                                isAgentThinkingExpanded = true
                            }
                            continue
                        } else if type == "thinking" {
                            if let c = o["content"] as? String {
                                await MainActor.run { agentThinkingText += c }
                            }
                            continue
                        } else if type == "thinking_end" {
                            continue
                        } else if type == "chunk" {
                            if let c = o["content"] as? String {
                                turnFull += c
                                await MainActor.run { streamingText = turnFull }
                            }
                            continue
                        }
                    }
                    if let c = o["content"] as? String {
                        turnFull += c
                        await MainActor.run { streamingText = turnFull }
                    }
                    if o["done"] as? Bool == true {
                        if o["awaiting_tools"] as? Bool == true, let t2 = nextStateToken, let r2 = nextRequests {
                            awaitingTools = true
                            nextStateToken = t2
                            nextRequests = r2
                        }
                        break
                    }
                }
            } catch {
                if !Task.isCancelled {
                    print("📡 [Agent:Continue] error: \(error)")
                    await MainActor.run {
                        streamingText = "Error: \(error.localizedDescription)"
                        agentProcessingText = ""
                        logAgent("continue error: \(error.localizedDescription)", level: .error)
                    }
                }
                break
            }
            
            if Task.isCancelled { break }
            
            finalFull = turnFull
            
            if awaitingTools, let t2 = nextStateToken, let r2 = nextRequests {
                guard agentTurnCount < 30 else {
                    await MainActor.run {
                        streamingText = "⚠️ Agent reached max turns. Try a simpler request."
                        agentProcessingText = ""
                    }
                    break
                }
                agentTurnCount += 1
                print("📡 [Agent] Executing \(r2.count) more tools (turn \(agentTurnCount))...")
                let nextResults = await executeAgentToolsAsync(r2, workspace: agentWorkspaceURL)
                if Task.isCancelled { break }
                
                currentToken = t2
                currentResults = nextResults
                // Continues loop to the next checkpoint!
            } else {
                // Done with all tool checkpoints!
                break
            }
        }
        
        if !Task.isCancelled {
            print("📡 [Agent:Continue] Done all checkpoints. Response: \(finalFull.count) chars")
            await MainActor.run {
                finalizeReply(full: finalFull)
                if !agentLog.isEmpty {
                    logAgent("done (\(finalFull.count) chars)", level: .success, icon: "flag.checkered")
                }
            }
        }
    }

    /// Atomically transition from "streaming" to "bot message present" so the
    /// streamingBubble and the freshly-mounted messageRow don't visually
    /// clobber each other. Order matters:
    ///   1. Append the bot message first (WebView starts loading with the
    ///      cached height, so it renders at the right size immediately).
    ///   2. Only then hide the streamingBubble and reset streamingText —
    ///      inside a single `withTransaction` block that disables animation
    ///      to avoid stacking scroll animations that used to look like flicker.
    @MainActor
    private func finalizeReply(full: String) {
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            if !full.isEmpty {
                let botMsg = ChatMessage(content: full, isUser: false, hasReasoning: isDeepSeekPro, checkpoints: currentTurnCheckpoints)
                messages.append(botMsg)
                currentTurnCheckpoints = []
                if isAutoSpeakEnabled { speechSynth.speak(speakableText(full), messageId: botMsg.id) }
            }
            isStreaming = false
            agentProcessingText = ""
            if !streamingText.hasPrefix("Error") && !streamingText.hasPrefix("⚠️") {
                streamingText = ""
            }
            updateMemoryCycle()
        }
    }
    
    private func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
        if !streamingText.isEmpty && !streamingText.hasPrefix("Error") && !streamingText.hasPrefix("⚠️") {
            let botMsg = ChatMessage(content: streamingText + "\n\n*(Dihentikan)*", isUser: false, checkpoints: currentTurnCheckpoints)
            messages.append(botMsg)
            currentTurnCheckpoints = []
        }
        streamingText = ""
        agentProcessingText = ""
        agentThinkingText = ""
        securityManager.cancelPendingConfirmation()
        if chatMode == .agent && !agentLog.isEmpty {
            logAgent("Dihentikan oleh pengguna", level: .warn, icon: "stop.circle")
        }
        Task { try? await APIClient.shared.clearLocks() }
    }
    
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
    var body: some View { Button(action: { withAnimation { isOn.toggle() } }) { HStack(spacing: 3) { Image(systemName: icon).font(.system(size: 10)); Text(label) }.font(.hermes.badge).padding(.horizontal, HermesSpacing.sm).padding(.vertical, 3).background(isOn ? color.opacity(0.15) : Color.hermes.hover).foregroundColor(isOn ? color : .hermes.muted).cornerRadius(HermesRadius.sm).overlay(RoundedRectangle(cornerRadius: HermesRadius.sm).strokeBorder(isOn ? color.opacity(0.3) : .clear, lineWidth: 1)) }.buttonStyle(PlainButtonStyle()) }
}
struct DeepSeekProToggle: View {
    @Binding var isOn: Bool; let visible: Bool
    var body: some View { if visible { ToggleButton(label: "Pro", icon: "brain.head.profile", isOn: $isOn, color: .purple) } }
}

// MARK: - Rich Markdown Renderer
private struct RichMessageContent: View {
    let content: String; let isUser: Bool

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
                        Markdown(md)
                            .textSelection(.enabled)
                    }
                }
            }
            .textSelection(.enabled)
        }
    }
    
    private func thinkingBlock(summary: String, body: String) -> some View {
        DisclosureGroup {
            Text(.init(body))
                .font(.hermes.caption)
                .foregroundColor(.hermes.muted)
                .lineSpacing(4)
                .padding(.vertical, 4)
                .textSelection(.enabled)
        } label: {
            Label(summary, systemImage: "brain.head.profile")
                .font(.hermes.caption)
                .foregroundColor(.purple)
        }
        .padding(10)
        .background(Color.purple.opacity(0.06))
        .cornerRadius(HermesRadius.md)
        .textSelection(.enabled)
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
                    let thinkingSoFar = String(text[start.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !thinkingSoFar.isEmpty {
                        blocks.append(Block(type: .thinking(summary: "Thinking...", body: thinkingSoFar)))
                    }
                    text = ""
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
    
    // MARK: - Markdown Sanitization & Preprocessing
    private static let lucideIcons: [String: String] = [
        "activity": "🩺",
        "heart": "❤️",
        "heart-pulse": "💓",
        "zap": "⚡",
        "info": "ℹ️",
        "alert-triangle": "⚠️",
        "alert-circle": "⚠️",
        "check": "✓",
        "check-circle": "✅",
        "check-circle-2": "✅",
        "x-circle": "❌",
        "x": "✕",
        "brain": "🧠",
        "cpu": "💻",
        "hard-drive": "💾",
        "sparkles": "✨",
        "lightbulb": "💡",
        "shield": "🛡️",
        "shield-check": "🛡️",
        "shield-alert": "🛡️",
        "message-square": "💬",
        "file-text": "📄",
        "file": "📄",
        "folder": "📁",
        "code": "💻",
        "terminal": "🖥️",
        "database": "🗄️",
        "search": "🔍",
        "scan-search": "🔍",
        "user": "👤",
        "users": "👥",
        "refresh-cw": "🔄",
        "rocket": "🚀",
        "sun": "☀️",
        "moon": "🌙",
        "clock": "🕒",
        "calendar": "📅",
        "book": "📚",
        "book-open": "📖",
        "graduation-cap": "🎓",
        "flame": "🔥",
        "link": "🔗",
        "settings": "⚙️",
        "sliders": "⚙️",
        "lock": "🔒",
        "unlock": "🔓",
        "key": "🔑",
        "star": "⭐",
        "bell": "🔔",
        "mail": "✉️",
        "phone": "📞",
        "globe": "🌐",
        "trash": "🗑️",
        "trash-2": "🗑️",
        "edit": "✏️",
        "edit-3": "✏️",
        "external-link": "↗️",
        "arrow-right": "→",
        "arrow-left": "←",
        "arrow-up": "↑",
        "arrow-down": "↓",
        "target": "🎯",
        "award": "🏆",
        "tag": "🏷️",
        "filter": "🔎",
        "image": "🖼️",
        "video": "🎥",
        "music": "🎵",
        "wifi": "📶",
        "battery": "🔋",
        "cloud": "☁️",
        "bar-chart": "📊",
        "bar-chart-2": "📊",
        "trending-up": "📈",
        "trending-down": "📉",
        "layers": "🥞",
        "package": "📦",
        "map-pin": "📍",
        "compass": "🧭",
        "eye": "👁️",
        "eye-off": "🙈",
        "git-branch": "🌿",
        "git-commit": "⭕",
        "git-pull-request": "🔀",
        "hammer": "🔨",
        "wrench": "🔧",
        "bug": "🐛",
        "stethoscope": "🩺",
        "thermometer": "🌡️",
        "pill": "💊",
        "microscope": "🔬",
        "circle-dot": "🔘",
        "sun-moon": "🌗"
    ]

    private static let subscriptMap: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
        "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
        ".": ".", ",": ",",
        "a": "ₐ", "e": "ₑ", "o": "ₒ", "x": "ₓ", "h": "ₕ",
        "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ", "p": "ₚ",
        "s": "ₛ", "t": "ₜ", "i": "ᵢ", "j": "ⱼ"
    ]

    private static let superscriptMap: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
        "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
        "n": "ⁿ", "i": "ⁱ", "x": "ˣ"
    ]

    private static func toSubscript(_ text: String) -> String {
        String(text.map { subscriptMap[$0] ?? $0 })
    }

    private static func toSuperscript(_ text: String) -> String {
        String(text.map { superscriptMap[$0] ?? $0 })
    }

    private static func formatMathExpression(_ text: String) -> String {
        var str = text
        
        // Convert subscripts: _{...} and _[0-9a-zA-Z]
        if let subRegex = try? NSRegularExpression(pattern: "_\\{([^{}]+)\\}|_([0-9a-zA-Z])", options: []) {
            let ns = str as NSString
            let matches = subRegex.matches(in: str, range: NSRange(location: 0, length: ns.length))
            for m in matches.reversed() {
                let targetRange = m.range(at: 1).location != NSNotFound ? m.range(at: 1) : m.range(at: 2)
                let subContent = ns.substring(with: targetRange)
                let converted = toSubscript(subContent)
                str = (str as NSString).replacingCharacters(in: m.range, with: converted)
            }
        }
        
        // Convert superscripts: ^{...} and ^[0-9a-zA-Z]
        if let supRegex = try? NSRegularExpression(pattern: "\\^\\{([^{}]+)\\}|\\^([0-9a-zA-Z])", options: []) {
            let ns = str as NSString
            let matches = supRegex.matches(in: str, range: NSRange(location: 0, length: ns.length))
            for m in matches.reversed() {
                let targetRange = m.range(at: 1).location != NSNotFound ? m.range(at: 1) : m.range(at: 2)
                let supContent = ns.substring(with: targetRange)
                let converted = toSuperscript(supContent)
                str = (str as NSString).replacingCharacters(in: m.range, with: converted)
            }
        }
        
        // Convert LaTeX math symbols
        let symbolReplacements: [(String, String)] = [
            ("\\\\times", "×"),
            ("\\\\div", "÷"),
            ("\\\\pm", "±"),
            ("\\\\approx", "≈"),
            ("\\\\neq", "≠"),
            ("\\\\le(q)?", "≤"),
            ("\\\\ge(q)?", "≥"),
            ("\\\\infty", "∞"),
            ("\\\\cdot", "·"),
            ("\\\\degree", "°"),
            ("\\\\to|\\\\rightarrow", "→"),
            ("\\\\leftarrow", "←"),
            ("\\\\alpha", "α"),
            ("\\\\beta", "β"),
            ("\\\\gamma", "γ"),
            ("\\\\delta", "δ"),
            ("\\\\Delta", "Δ"),
            ("\\\\pi", "π"),
            ("\\\\sigma", "σ"),
            ("\\\\mu", "µ"),
            ("\\\\theta", "θ"),
            ("\\\\lambda", "λ"),
            ("\\\\text\\{([^{}]+)\\}", "$1"),
            ("\\\\mathrm\\{([^{}]+)\\}", "$1"),
            ("\\\\mathbf\\{([^{}]+)\\}", "**$1**"),
            ("\\\\mathit\\{([^{}]+)\\}", "*$1*"),
            ("\\\\sqrt\\{([^{}]+)\\}", "√($1)"),
            ("\\\\frac\\{([^{}]+)\\}\\{([^{}]+)\\}", "($1 / $2)")
        ]
        
        for (pattern, repl) in symbolReplacements {
            str = str.replacingOccurrences(of: pattern, with: repl, options: .regularExpression)
        }
        
        return str.trimmingCharacters(in: .whitespaces)
    }

    private static func formatCommonScientificNotation(_ text: String) -> String {
        var str = text
        if let sciRegex = try? NSRegularExpression(pattern: "\\b([A-Z][a-zA-Z]*)_\\{([0-9\\.]+)\\}|\\b([A-Z][a-zA-Z]*)_([0-9]+)", options: []) {
            let ns = str as NSString
            let matches = sciRegex.matches(in: str, range: NSRange(location: 0, length: ns.length))
            for m in matches.reversed() {
                let nameRange = m.range(at: 1).location != NSNotFound ? m.range(at: 1) : m.range(at: 3)
                let subRange = m.range(at: 2).location != NSNotFound ? m.range(at: 2) : m.range(at: 4)
                let name = ns.substring(with: nameRange)
                let subVal = ns.substring(with: subRange)
                let converted = name + toSubscript(subVal)
                str = (str as NSString).replacingCharacters(in: m.range, with: converted)
            }
        }
        return str
    }

    /// Preprocess and clean markdown text before feeding to MarkdownUI.
    /// Converts Lucide HTML icons to inline emojis and LaTeX math notation to readable Unicode.
    /// Preserves legitimate HTML and code inside code blocks untouched.
    private func sanitize(_ text: String) -> String {
        // 1. Protect code blocks so we don't modify code or examples
        var codeBlocks: [String] = []
        let codePattern = "(```[\\s\\S]*?```|`[^`\\n]+`)"
        guard let codeRegex = try? NSRegularExpression(pattern: codePattern) else {
            return text
        }
        
        var working = text
        let nsWorking = working as NSString
        let matches = codeRegex.matches(in: working, range: NSRange(location: 0, length: nsWorking.length))
        
        for match in matches.reversed() {
            let matchedCode = nsWorking.substring(with: match.range)
            codeBlocks.insert(matchedCode, at: 0)
        }
        
        var placeholderIndex = 0
        working = codeRegex.stringByReplacingMatches(in: working, options: [], range: NSRange(location: 0, length: (working as NSString).length), withTemplate: "%%HERMES_CODE_BLOCK_TAG%%")
        
        while let r = working.range(of: "%%HERMES_CODE_BLOCK_TAG%%") {
            working.replaceSubrange(r, with: "%%HERMES_CODE_\(placeholderIndex)%%")
            placeholderIndex += 1
        }
        
        // 2. Remove residual DeepSeek thinking tags
        working = working.replacingOccurrences(of: "</?details[^>]*>", with: "", options: .regularExpression)
        working = working.replacingOccurrences(of: "</?summary>", with: "", options: .regularExpression)
        
        // 3. Process Lucide icon tags: <i data-lucide="name"></i> or <i ... data-lucide="name" ...></i>
        if let lucideRegex = try? NSRegularExpression(pattern: "<i[^>]*data-lucide=[\"']([^\"']+)[\"'][^>]*>(?:<\\/i>)?", options: .caseInsensitive) {
            let nsStr = working as NSString
            let iconMatches = lucideRegex.matches(in: working, range: NSRange(location: 0, length: nsStr.length))
            for match in iconMatches.reversed() {
                let iconName = nsStr.substring(with: match.range(at: 1)).lowercased().trimmingCharacters(in: .whitespaces)
                let replacement = Self.lucideIcons[iconName] ?? ""
                let fullRange = match.range
                let endLoc = fullRange.location + fullRange.length
                let hasTrailingSpace = endLoc < nsStr.length && nsStr.character(at: endLoc) == 32
                let finalReplacement = replacement.isEmpty ? "" : (hasTrailingSpace ? replacement : "\(replacement) ")
                working = (working as NSString).replacingCharacters(in: fullRange, with: finalReplacement)
            }
        }
        working = working.replacingOccurrences(of: "<i[^>]*>\\s*<\\/i>", with: "", options: .regularExpression)
        
        // 4. Process LaTeX / Math notation:
        // A) Block math $$...$$ and inline math $...$
        if let mathRegex = try? NSRegularExpression(pattern: "\\$\\$([\\s\\S]*?)\\$\\$|\\$([^\\$\\n]+)\\$", options: []) {
            let nsStr = working as NSString
            let mathMatches = mathRegex.matches(in: working, range: NSRange(location: 0, length: nsStr.length))
            for match in mathMatches.reversed() {
                let range1 = match.range(at: 1)
                let range2 = match.range(at: 2)
                let exprRange = range1.location != NSNotFound ? range1 : range2
                var expr = nsStr.substring(with: exprRange)
                
                expr = Self.formatMathExpression(expr)
                working = (working as NSString).replacingCharacters(in: match.range, with: expr)
            }
        }
        
        // B) Standalone scientific terms outside math tags (e.g. PM_{2.5}, CO_2, H_2O)
        working = Self.formatCommonScientificNotation(working)
        
        // 5. Basic HTML tag cleanup
        working = working.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        working = working.replacingOccurrences(of: "</?p>", with: "\n", options: .regularExpression)
        working = working.replacingOccurrences(of: "<b>(.*?)</b>", with: "**$1**", options: .regularExpression)
        working = working.replacingOccurrences(of: "<strong>(.*?)</strong>", with: "**$1**", options: .regularExpression)
        
        // 6. Restore protected code blocks
        for (i, code) in codeBlocks.enumerated() {
            working = working.replacingOccurrences(of: "%%HERMES_CODE_\(i)%%", with: code)
        }
        
        // 7. Collapse multiple newlines
        working = working.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return working.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
