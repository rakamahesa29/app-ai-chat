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
    
    let categories = ["General", "Software Dev", "Copywriting", "Education", "Business", "Daily Life"]
    
    let personas: [String: String] = [
        "general": "General Assistant (Balanced)",
        "architect": "The Architect (Tech & Code Focused)",
        "bestie": "The Bestie (Casual & Fun Lifestyle)",
        "sage": "The Sage (Empathetic & Meaningful)",
        "executive": "The Executive (Formal & Business)",
        "education": "The Educator (Academic & Structured)",
        "swift-developer": "Swift Architect (SwiftUI & Laravel)"
    ]
    
    let models: [String: String] = [
        "ollama": "Ollama (Gemma4 12B)",
        "ollama_cloud": "Ollama (Gemma4 31B Cloud)",
        "deepseek": "DeepSeek API"
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
                            
                            HermesPicker(
                                label: "AI Model",
                                selection: $selectedModel,
                                options: ["ollama", "ollama_cloud", "deepseek"],
                                displayLabels: models
                            )
                            
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
