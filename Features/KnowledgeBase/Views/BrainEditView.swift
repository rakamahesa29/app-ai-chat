import SwiftUI

struct BrainEditView: View {
    @Environment(\.dismiss) var dismiss
    
    let document: BrainDocument
    var onSave: (BrainDocument) -> Void
    
    @State private var title: String
    @State private var selectedTags: Set<String>
    @State private var inputType: BrainDocumentType
    @State private var content: String
    
    let availableTags = ["general", "architect", "bestie", "sage", "executive", "education"]
    
    init(document: BrainDocument, onSave: @escaping (BrainDocument) -> Void) {
        self.document = document
        self.onSave = onSave
        _title = State(initialValue: document.title)
        _selectedTags = State(initialValue: Set(document.tags))
        _inputType = State(initialValue: document.type)
        _content = State(initialValue: document.content)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: HermesSpacing.xxl) {
                    // Header
                    VStack(spacing: HermesSpacing.sm) {
                        Text("Edit Knowledge")
                            .font(.hermes.h1)
                            .foregroundColor(.hermes.text)
                        Text("Modify existing knowledge document.")
                            .font(.hermes.body)
                            .foregroundColor(.hermes.muted)
                    }
                    
                    // Form Card
                    HermesCard(padding: HermesSpacing.xxl) {
                        VStack(alignment: .leading, spacing: HermesSpacing.xl) {
                            HermesTextField("e.g. Product Guidelines", text: $title, label: "Document Title")
                            
                            // Persona Tags
                            VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                                Text("PERSONA TAGS")
                                    .font(.hermes.badge)
                                    .foregroundColor(.hermes.muted)
                                    .kerning(0.5)
                                
                                Text("Select which personas should have access to this knowledge.")
                                    .font(.hermes.caption)
                                    .foregroundColor(.hermes.muted)
                                
                                FlowLayout(spacing: HermesSpacing.sm) {
                                    ForEach(availableTags, id: \.self) { tag in
                                        TagCheckbox(
                                            label: tag.capitalized,
                                            isSelected: selectedTags.contains(tag),
                                            action: {
                                                if selectedTags.contains(tag) {
                                                    selectedTags.remove(tag)
                                                } else {
                                                    selectedTags.insert(tag)
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                            
                            // Input Type
                            VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                                Text("INPUT TYPE")
                                    .font(.hermes.badge)
                                    .foregroundColor(.hermes.muted)
                                    .kerning(0.5)
                                
                                HStack(spacing: HermesSpacing.md) {
                                    TypeButton(
                                        icon: "doc.text",
                                        label: "Text Input",
                                        isSelected: inputType == .text,
                                        action: { inputType = .text }
                                    )
                                    TypeButton(
                                        icon: "doc",
                                        label: "PDF Upload",
                                        isSelected: inputType == .pdf,
                                        action: { inputType = .pdf }
                                    )
                                }
                            }
                            
                            // Content
                            if inputType == .text {
                                VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                                    Text("CONTENT")
                                        .font(.hermes.badge)
                                        .foregroundColor(.hermes.muted)
                                        .kerning(0.5)
                                    
                                    TextEditor(text: $content)
                                        .font(.hermes.body)
                                        .foregroundColor(.hermes.text)
                                        .scrollContentBackground(.hidden)
                                        .padding(HermesSpacing.md)
                                        .frame(minHeight: 180)
                                        .background(Color.hermes.surface)
                                        .cornerRadius(HermesRadius.md)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: HermesRadius.md)
                                                .strokeBorder(Color.hermes.border, lineWidth: 1)
                                        )
                                }
                            } else {
                                // PDF Info
                                HStack(spacing: HermesSpacing.md) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: HermesRadius.md)
                                            .fill(Color.red.opacity(0.1))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "doc")
                                            .foregroundColor(.red)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(document.title).pdf")
                                            .font(.hermes.bodyMedium)
                                            .foregroundColor(.hermes.text)
                                        Text("Uploaded document")
                                            .font(.hermes.caption)
                                            .foregroundColor(.hermes.muted)
                                    }
                                    
                                    Spacer()
                                    
                                    HermesButton(title: "Replace", style: .secondary, size: .small) {}
                                }
                                .padding(HermesSpacing.md)
                                .background(Color.hermes.surface)
                                .cornerRadius(HermesRadius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HermesRadius.md)
                                        .strokeBorder(Color.hermes.border, lineWidth: 1)
                                )
                            }
                            
                            HermesButton(
                                title: "Save Changes",
                                icon: "checkmark.circle",
                                isDisabled: title.isEmpty || (inputType == .text && content.isEmpty),
                                action: saveDocument
                            )
                        }
                    }
                    .frame(maxWidth: 550)
                }
                .padding(.horizontal, HermesSpacing.xl)
                .padding(.vertical, HermesSpacing.xxl)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color.hermes.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { dismiss() }) {
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
    
    private func saveDocument() {
        let updated = BrainDocument(
            id: document.id,
            title: title,
            type: inputType,
            content: content,
            tags: Array(selectedTags),
            createdAt: document.createdAt
        )
        onSave(updated)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        BrainEditView(document: BrainDocument.samples[0]) { _ in }
            .environmentObject(AppState())
    }
}
