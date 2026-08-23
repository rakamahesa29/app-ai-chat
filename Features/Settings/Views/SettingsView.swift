import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    // AI Providers
    @State private var isOllamaEnabled = true
    @State private var isOllamaCloudEnabled = false
    @State private var isDeepSeekEnabled = true
    @State private var isRAGEnabled = true
    @State private var isKnowledgeGraphEnabled = true
    @State private var isWebSearchEnabled = true
    
    // DeepSeek Pro
    @State private var deepSeekProReasoning = "high"
    
    // RAG Settings
    @State private var ragChunkSize = "1000"
    @State private var ragTopK = "6"
    
    // Ollama endpoints
    @State private var ollamaLocalURL = "http://127.0.0.1:11434"
    @State private var ollamaCloudURL = ""
    @State private var ollamaLocalModel = "ornith"
    @State private var ollamaCloudModel = "gemma4:31b-cloud"
    @State private var embeddingModel = "bge-m3:567m"
    
    // DeepSeek API
    @State private var deepSeekAPIKey = ""
    @State private var deepSeekFlashModel = "deepseek-v4-flash"
    @State private var deepSeekProModel = "deepseek-v4-pro"
    
    // Tavily
    @State private var tavilyAPIKey = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: HermesSpacing.xxl) {
                    // Header
                    HStack(spacing: HermesSpacing.md) {
                        Button(action: { dismiss() }) {
                            HStack(spacing: HermesSpacing.xs) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(HermesSpacing.sm)
                            .background(Color.hermes.surface)
                            .cornerRadius(HermesRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: HermesRadius.md)
                                    .strokeBorder(Color.hermes.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        VStack(alignment: .leading, spacing: HermesSpacing.xs) {
                            Text("Settings")
                                .font(.hermes.h1)
                                .foregroundColor(.hermes.text)
                            Text("Configure AI providers and preferences.")
                                .font(.hermes.caption)
                                .foregroundColor(.hermes.muted)
                        }
                        
                        Spacer()
                    }
                    
                    // Profile Section
                    settingsSection("Profile") {
                        profileCard
                    }
                    
                    // AI Providers
                    settingsSection("AI Providers") {
                        VStack(spacing: HermesSpacing.md) {
                            HermesToggleRow(
                                title: "Ollama (Local)",
                                subtitle: "Ornith — Private & offline",
                                icon: "cpu",
                                iconColor: .blue,
                                isOn: $isOllamaEnabled
                            )
                            
                            if isOllamaEnabled {
                                HermesTextField("http://127.0.0.1:11434", text: $ollamaLocalURL, label: "Ollama URL")
                                HermesTextField("ornith", text: $ollamaLocalModel, label: "Local Model")
                            }
                            
                            HermesToggleRow(
                                title: "Ollama (Cloud)",
                                subtitle: "Gemma4 31B — Faster for complex tasks",
                                icon: "server.rack",
                                iconColor: .cyan,
                                isOn: $isOllamaCloudEnabled
                            )
                            
                            if isOllamaCloudEnabled {
                                HermesTextField("http://cloud-ip:11434", text: $ollamaCloudURL, label: "Cloud URL")
                                HermesTextField("gemma4:31b-cloud", text: $ollamaCloudModel, label: "Cloud Model")
                            }
                            
                            HermesToggleRow(
                                title: "DeepSeek API",
                                subtitle: "DeepSeek V4 — Flash + Pro with reasoning",
                                icon: "cloud",
                                iconColor: .purple,
                                isOn: $isDeepSeekEnabled
                            )
                            
                            if isDeepSeekEnabled {
                                HermesTextField("sk-...", text: $deepSeekAPIKey, label: "API Key", isSecure: true)
                                HermesTextField("deepseek-v4-flash", text: $deepSeekFlashModel, label: "Flash Model")
                                HermesTextField("deepseek-v4-pro", text: $deepSeekProModel, label: "Pro Model")
                                
                                HermesPicker(
                                    label: "Reasoning Effort",
                                    selection: $deepSeekProReasoning,
                                    options: ["low", "medium", "high"],
                                    displayLabels: [
                                        "low": "Low (Faster)",
                                        "medium": "Medium (Balanced)",
                                        "high": "High (Deeper reasoning)"
                                    ]
                                )
                            }
                        }
                    }
                    
                    // Embeddings
                    settingsSection("Embeddings & RAG") {
                        VStack(spacing: HermesSpacing.md) {
                            HermesTextField("bge-m3:567m", text: $embeddingModel, label: "Embedding Model")
                            
                            HermesToggleRow(
                                title: "RAG (Retrieval-Augmented Generation)",
                                subtitle: "Search knowledge base for context-aware answers",
                                icon: "magnifyingglass.circle",
                                iconColor: .hermes.accent,
                                isOn: $isRAGEnabled
                            )
                            
                            if isRAGEnabled {
                                HStack(spacing: HermesSpacing.md) {
                                    HermesTextField("1000", text: $ragChunkSize, label: "Chunk Size")
                                    HermesTextField("6", text: $ragTopK, label: "Top K")
                                }
                            }
                        }
                    }
                    
                    // Knowledge Graph
                    settingsSection("Knowledge Graph") {
                        VStack(spacing: HermesSpacing.md) {
                            HermesToggleRow(
                                title: "Knowledge Graph",
                                subtitle: "Extract entities and relationships from conversations",
                                icon: "network",
                                iconColor: .indigo,
                                isOn: $isKnowledgeGraphEnabled
                            )
                        }
                    }
                    
                    // Web Search
                    settingsSection("Web Search") {
                        VStack(spacing: HermesSpacing.md) {
                            HermesToggleRow(
                                title: "Web Search (Tavily)",
                                subtitle: "Search the web for real-time information",
                                icon: "globe",
                                iconColor: .hermes.success,
                                isOn: $isWebSearchEnabled
                            )
                            
                            if isWebSearchEnabled {
                                HermesTextField("tvly-...", text: $tavilyAPIKey, label: "Tavily API Key", isSecure: true)
                            }
                        }
                    }
                    
                    // Appearance
                    settingsSection("Appearance") {
                        VStack(spacing: HermesSpacing.md) {
                            HermesToggleRow(
                                title: "Dark Mode",
                                subtitle: "Toggle between light and dark themes",
                                icon: appState.isDarkMode ? "moon" : "sun.max",
                                iconColor: appState.isDarkMode ? .indigo : .orange,
                                isOn: $appState.isDarkMode
                            )
                        }
                    }
                    
                    // Account
                    settingsSection("Account") {
                        VStack(spacing: HermesSpacing.md) {
                            Button(action: { appState.logout() }) {
                                HStack(spacing: HermesSpacing.sm) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 14))
                                    Text("Log Out")
                                        .font(.hermes.bodyMedium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, HermesSpacing.md)
                                .foregroundColor(.hermes.danger)
                                .background(Color.hermes.danger.opacity(0.1))
                                .cornerRadius(HermesRadius.md)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Save Button
                    HermesButton(
                        title: "Save Settings",
                        icon: "checkmark.circle",
                        action: {
                            Task {
                                await saveSettings()
                                dismiss()
                            }
                        }
                    )
                    .padding(.bottom, HermesSpacing.xxxxl)
                }
                .padding(.horizontal, HermesSpacing.xl)
                .padding(.vertical, HermesSpacing.xxl)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
        .background(Color.hermes.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
        .task { await loadSettings() }
    }
    
    // MARK: - API
    
    private func loadSettings() async {
        do {
            let s = try await APIClient.shared.fetchSettings()
            isOllamaEnabled = s.ollamaEnabled ?? true
            isOllamaCloudEnabled = s.ollamaCloudEnabled ?? false
            isDeepSeekEnabled = s.deepseekEnabled ?? false
            isRAGEnabled = s.ragEnabled ?? true
            isKnowledgeGraphEnabled = s.knowledgeGraphEnabled ?? true
            isWebSearchEnabled = s.webSearchEnabled ?? true
            ollamaLocalURL = s.ollamaLocalUrl ?? "http://127.0.0.1:11434"
            ollamaLocalModel = s.ollamaLocalModel ?? "ornith"
            ollamaCloudURL = s.ollamaCloudUrl ?? ""
            ollamaCloudModel = s.ollamaCloudModel ?? "gemma4:31b-cloud"
            deepSeekAPIKey = s.deepseekApiKey ?? ""
            deepSeekFlashModel = s.deepseekFlashModel ?? "deepseek-v4-flash"
            deepSeekProModel = s.deepseekProModel ?? "deepseek-v4-pro"
            deepSeekProReasoning = s.deepseekReasoning ?? "high"
            embeddingModel = s.embeddingModel ?? "bge-m3:567m"
            ragChunkSize = String(s.ragChunkSize ?? 1500)
            ragTopK = String(s.ragTopK ?? 6)
            tavilyAPIKey = s.tavilyApiKey ?? ""
        } catch {
            print("Settings load error: \(error)")
        }
    }
    
    private func saveSettings() async {
        var dict: [String: String] = [:]
        dict["ollama_enabled"] = isOllamaEnabled ? "1" : "0"
        dict["ollama_cloud_enabled"] = isOllamaCloudEnabled ? "1" : "0"
        dict["deepseek_enabled"] = isDeepSeekEnabled ? "1" : "0"
        dict["rag_enabled"] = isRAGEnabled ? "1" : "0"
        dict["knowledge_graph_enabled"] = isKnowledgeGraphEnabled ? "1" : "0"
        dict["web_search_enabled"] = isWebSearchEnabled ? "1" : "0"
        dict["ollama_local_url"] = ollamaLocalURL
        dict["ollama_local_model"] = ollamaLocalModel
        dict["ollama_cloud_url"] = ollamaCloudURL
        dict["ollama_cloud_model"] = ollamaCloudModel
        dict["deepseek_api_key"] = deepSeekAPIKey
        dict["deepseek_flash_model"] = deepSeekFlashModel
        dict["deepseek_pro_model"] = deepSeekProModel
        dict["deepseek_reasoning"] = deepSeekProReasoning
        dict["embedding_model"] = embeddingModel
        dict["rag_chunk_size"] = ragChunkSize
        dict["rag_top_k"] = ragTopK
        dict["tavily_api_key"] = tavilyAPIKey
        dict["dark_mode"] = appState.isDarkMode ? "1" : "0"
        
        do {
            try await APIClient.shared.updateSettings(dict)
        } catch {
            print("Settings save error: \(error)")
        }
    }
    
    // MARK: - Profile Card
    private var profileCard: some View {
        HStack(spacing: HermesSpacing.lg) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.hermes.accent.opacity(0.15))
                    .frame(width: 56, height: 56)
                Text(String(appState.currentUserName.prefix(1)).uppercased())
                    .font(.hermes.h2)
                    .foregroundColor(.hermes.accent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.currentUserName)
                    .font(.hermes.h3)
                    .foregroundColor(.hermes.text)
                Text(appState.currentUserEmail)
                    .font(.hermes.caption)
                    .foregroundColor(.hermes.muted)
            }
            
            Spacer()
            
            HermesButton(title: "Edit", style: .secondary, size: .small, action: {
                // TODO: Navigate to profile edit
            })
            .fixedSize()
        }
    }
    
    // MARK: - Section Helper
    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        HermesCard(padding: HermesSpacing.xl) {
            VStack(alignment: .leading, spacing: HermesSpacing.lg) {
                Text(title.uppercased())
                    .font(.hermes.badge)
                    .foregroundColor(.hermes.muted)
                    .kerning(0.5)
                
                content()
            }
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var bio: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: HermesSpacing.xxl) {
                    // Header
                    HStack(spacing: HermesSpacing.md) {
                        Button(action: { dismiss() }) {
                            HStack(spacing: HermesSpacing.xs) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(HermesSpacing.sm)
                            .background(Color.hermes.surface)
                            .cornerRadius(HermesRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: HermesRadius.md)
                                    .strokeBorder(Color.hermes.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        VStack(alignment: .leading, spacing: HermesSpacing.xs) {
                            Text("Profile")
                                .font(.hermes.h1)
                                .foregroundColor(.hermes.text)
                            Text("Manage your account details.")
                                .font(.hermes.caption)
                                .foregroundColor(.hermes.muted)
                        }
                        
                        Spacer()
                    }
                    
                    // Avatar Section
                    VStack(spacing: HermesSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.hermes.accent.opacity(0.15))
                                .frame(width: 96, height: 96)
                            Text(String(appState.currentUserName.prefix(1)).uppercased())
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.hermes.accent)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Circle()
                                .fill(Color.hermes.accent)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "camera")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 4, y: 4)
                        }
                        
                        Text("Change Photo")
                            .font(.hermes.captionMedium)
                            .foregroundColor(.hermes.accent)
                    }
                    .padding(.top, HermesSpacing.lg)
                    
                    // Form
                    HermesCard(padding: HermesSpacing.xl) {
                        VStack(spacing: HermesSpacing.lg) {
                            HermesTextField("Your Name", text: $name, label: "Name", icon: "person")
                            HermesTextField("you@example.com", text: $email, label: "Email", icon: "envelope")
                            
                            VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                                Text("BIO")
                                    .font(.hermes.badge)
                                    .foregroundColor(.hermes.muted)
                                    .kerning(0.5)
                                TextEditor(text: $bio)
                                    .font(.hermes.body)
                                    .foregroundColor(.hermes.text)
                                    .scrollContentBackground(.hidden)
                                    .padding(HermesSpacing.md)
                                    .frame(minHeight: 100)
                                    .background(Color.hermes.surface)
                                    .cornerRadius(HermesRadius.md)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HermesRadius.md)
                                            .strokeBorder(Color.hermes.border, lineWidth: 1)
                                    )
                            }
                            
                            HermesButton(
                                title: "Save Profile",
                                icon: "checkmark.circle",
                                action: {
                                    appState.currentUserName = name
                                    appState.currentUserEmail = email
                                    dismiss()
                                }
                            )
                        }
                    }
                    .frame(maxWidth: 500)
                }
                .padding(.horizontal, HermesSpacing.xl)
                .padding(.vertical, HermesSpacing.xxl)
                .frame(maxWidth: .infinity)
            }
        .background(Color.hermes.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
        .onAppear {
            name = appState.currentUserName
            email = appState.currentUserEmail
        }
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState())
    }
}

#Preview("Profile") {
    NavigationStack {
        ProfileView()
            .environmentObject({
                let state = AppState()
                state.currentUserName = "Raka Mahesa"
                state.currentUserEmail = "raka@example.com"
                return state
            }())
    }
}
