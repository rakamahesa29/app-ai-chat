import SwiftUI

struct ChatCreateView: View {
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var selectedCategory = "General"
    @State private var selectedPersona = "general"
    @State private var selectedModel = "ollama"

    /// Called when the user taps "Back". Defaults to the environment dismiss so
    /// this view still works when pushed via a NavigationStack (e.g. in Previews).
    var onDismiss: (() -> Void)? = nil
    var onCreateRoom: (ChatRoom) -> Void
    
    let categories = ["General", "Software Dev", "Copywriting", "Education", "Business", "Design & UI/UX", "Daily Life"]
    
    let personas: [String: String] = [
        "general": "General Assistant (Balanced)",
        "architect": "The Architect (Tech & Code Focused)",
        "bestie": "The Bestie (Casual & Fun Lifestyle)",
        "sage": "The Sage (Empathetic & Meaningful)",
        "executive": "The Executive (Formal & Business)",
        "education": "The Educator (Academic & Structured)",
        "swift-developer": "Swift Architect (SwiftUI & Laravel)",
        "lovable-engineer": "Lovable UI/UX Engineer (Frontend & Design)"
    ]
    
    let models: [String: String] = [
        "ollama": "Ollama (Ornith)",
        "ollama_cloud": "Ollama (Gemma4 31B Cloud)",
        "deepseek": "DeepSeek API",
        "gemini-3.8-flash-low": "Gemini 3.8 Flash (Low Thinking)",
        "gemini-3.8-flash-medium": "Gemini 3.8 Flash (Medium Thinking)",
        "gemini-3.8-flash-high": "Gemini 3.8 Flash (High Thinking)",
        "claude-sonnet-5-5-low": "Claude Sonnet 5.5 (Low Thinking)",
        "claude-sonnet-5-5-medium": "Claude Sonnet 5.5 (Medium Thinking)",
        "claude-sonnet-5-5-high": "Claude Sonnet 5.5 (High Thinking)",
        "claude-opus-5-5-low": "Claude Opus 5.5 (Low Thinking)",
        "claude-opus-5-5-medium": "Claude Opus 5.5 (Medium Thinking)",
        "claude-opus-5-5-high": "Claude Opus 5.5 (High Thinking)",
        "gpt-oss-120b-medium": "GPT-OSS 120B (Medium Thinking)",
        "gemini_pro": "Gemini Pro"
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: HermesSpacing.xxl) {
                    // Header
                    VStack(spacing: HermesSpacing.sm) {
                        Text("Prepare your Session")
                            .font(.hermes.h1)
                            .foregroundColor(.hermes.text)
                        Text("Set up the initial parameters for this conversation.")
                            .font(.hermes.body)
                            .foregroundColor(.hermes.muted)
                    }
                    
                    // Form Card
                    HermesCard(padding: HermesSpacing.xxl) {
                        VStack(spacing: HermesSpacing.lg) {
                            HermesTextField("e.g. Recipe for Padang Food", text: $title, label: "Chat Title")
                            
                            HermesPicker(
                                label: "Category",
                                selection: $selectedCategory,
                                options: categories
                            )
                            
                            HermesPicker(
                                label: "AI Persona (Tone)",
                                selection: $selectedPersona,
                                options: Array(personas.keys).sorted(),
                                displayLabels: personas
                            )
                            
                            VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                                Text("AI MODEL")
                                    .font(.hermes.badge)
                                    .foregroundColor(.hermes.muted)
                                    .kerning(0.5)
                                
                                Menu {
                                    Section("Standard Models") {
                                        Button(action: { selectedModel = "ollama" }) {
                                            if selectedModel == "ollama" { Label("Ollama (Ornith)", systemImage: "checkmark") } else { Text("Ollama (Ornith)") }
                                        }
                                        Button(action: { selectedModel = "ollama_cloud" }) {
                                            if selectedModel == "ollama_cloud" { Label("Ollama (Gemma4 31B Cloud)", systemImage: "checkmark") } else { Text("Ollama (Gemma4 31B Cloud)") }
                                        }
                                        Button(action: { selectedModel = "deepseek" }) {
                                            if selectedModel == "deepseek" { Label("DeepSeek API", systemImage: "checkmark") } else { Text("DeepSeek API") }
                                        }
                                    }
                                    
                                    Menu("Gemini 3.8 Flash") {
                                        Button(action: { selectedModel = "gemini-3.8-flash-low" }) {
                                            if selectedModel == "gemini-3.8-flash-low" || selectedModel == "gemini_pro" { Label("Low Thinking", systemImage: "checkmark") } else { Text("Low Thinking") }
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
                                    HStack {
                                        Text(models[selectedModel] ?? selectedModel)
                                            .font(.hermes.body)
                                            .foregroundColor(.hermes.text)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.hermes.muted)
                                    }
                                    .padding(HermesSpacing.md)
                                    .background(Color.hermes.surface)
                                    .cornerRadius(HermesRadius.md)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HermesRadius.md)
                                            .strokeBorder(Color.hermes.border, lineWidth: 1)
                                    )
                                }
                                .menuStyle(.borderlessButton)
                                .menuIndicator(.hidden)
                            }
                            
                            // Info
                            HStack(alignment: .top, spacing: HermesSpacing.md) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.hermes.accent)
                                    .padding(HermesSpacing.sm)
                                    .background(Color.hermes.accent.opacity(0.1))
                                    .cornerRadius(HermesRadius.sm)
                                
                                Text("Selecting a model determines speed and accuracy. \"Local\" is private & offline; \"Cloud\" models are faster for complex tasks.")
                                    .font(.hermes.caption)
                                    .foregroundColor(.hermes.muted)
                            }
                            .padding(HermesSpacing.md)
                            .background(Color.hermes.accent.opacity(0.05))
                            .cornerRadius(HermesRadius.md)
                            
                            HermesButton(
                                title: "Start Conversation",
                                icon: "arrow.right",
                                isDisabled: title.isEmpty,
                                action: createRoom
                            )
                        }
                    }
                    .frame(maxWidth: 500)
                }
                .padding(.horizontal, HermesSpacing.xl)
                .padding(.vertical, HermesSpacing.xxl)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color.hermes.bg.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: handleDismiss) {
                    HStack(spacing: HermesSpacing.xs) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.hermes.body)
                    .foregroundColor(.hermes.accent)
                }
            }
        }
    }

    private func handleDismiss() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    private func createRoom() {
        let room = ChatRoom(
            id: UUID().uuidString,
            title: title,
            category: selectedCategory,
            persona: selectedPersona,
            model: selectedModel,
            createdAt: Date()
        )
        onCreateRoom(room)
    }
}

#Preview {
    NavigationStack {
        ChatCreateView { _ in }
            .environmentObject(AppState())
    }
}
