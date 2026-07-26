import SwiftUI

struct BrainCreateView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var selectedTags: Set<String> = ["general"]
    @State private var inputType: BrainDocumentType = .text
    @State private var content = ""
    
    // Custom tags
    @State private var customTags: [String] = []
    @State private var newTagText = ""
    
    // Validation errors
    @State private var errors: [String] = []
    
    var onSave: (BrainDocument) -> Void
    
    let availableTags = ["general", "architect", "bestie", "sage", "executive", "education"]
    
    let tagLabels: [String: String] = [
        "general": "General (All Personas)",
        "architect": "The Architect (Tech & Code)",
        "bestie": "The Bestie (Casual)",
        "sage": "The Sage (Empathetic)",
        "executive": "The Executive (Business)",
        "education": "The Educator (Academic)"
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: HermesSpacing.xxl) {
                    // Header with back button
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
                            Text("Add Knowledge")
                                .font(.hermes.h1)
                                .foregroundColor(.hermes.text)
                            Text("Inject new information into the AI Brain.")
                                .font(.hermes.caption)
                                .foregroundColor(.hermes.muted)
                        }
                        
                        Spacer()
                    }
                    
                    // Errors
                    if !errors.isEmpty {
                        VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                            ForEach(errors, id: \.self) { error in
                                HStack(spacing: HermesSpacing.sm) {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.system(size: 13))
                                    Text(error)
                                        .font(.hermes.caption)
                                }
                            }
                        }
                        .padding(HermesSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.hermes.danger.opacity(0.1))
                        .foregroundColor(.hermes.danger)
                        .cornerRadius(HermesRadius.lg)
                        .overlay(
                            RoundedRectangle(cornerRadius: HermesRadius.lg)
                                .strokeBorder(Color.hermes.danger.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Form Card
                    HermesCard(padding: HermesSpacing.xxl) {
                        VStack(alignment: .leading, spacing: HermesSpacing.xl) {
                            // Title
                            HermesTextField("e.g. Laravel 12 Updates", text: $title, label: "Knowledge Title")
                            
                            // Persona Tags
                            VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                                Text("TARGET PERSONA (TAGS)")
                                    .font(.hermes.badge)
                                    .foregroundColor(.hermes.muted)
                                    .kerning(0.5)
                                
                                FlowLayout(spacing: HermesSpacing.sm) {
                                    ForEach(availableTags, id: \.self) { tag in
                                        TagCheckbox(
                                            label: tagLabels[tag] ?? tag.capitalized,
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
                                
                                Text("Select one or more personas. Knowledge will be injected when user selects these.")
                                    .font(.hermes.caption)
                                    .foregroundColor(.hermes.muted)
                            }
                            
                            // Custom Tags
                            VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                                Text("CUSTOM TAGS (OPTIONAL)")
                                    .font(.hermes.badge)
                                    .foregroundColor(.hermes.muted)
                                    .kerning(0.5)
                                
                                VStack(spacing: HermesSpacing.sm) {
                                    // Tag chips
                                    if !customTags.isEmpty {
                                        FlowLayout(spacing: HermesSpacing.xs) {
                                            ForEach(Array(customTags.enumerated()), id: \.offset) { index, tag in
                                                HStack(spacing: HermesSpacing.xs) {
                                                    Text(tag)
                                                        .font(.hermes.badge)
                                                    Button(action: { customTags.remove(at: index) }) {
                                                        Image(systemName: "xmark")
                                                            .font(.system(size: 8, weight: .bold))
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                }
                                                .padding(.horizontal, HermesSpacing.sm)
                                                .padding(.vertical, HermesSpacing.xs)
                                                .background(Color.hermes.accent.opacity(0.1))
                                                .foregroundColor(.hermes.accent)
                                                .cornerRadius(HermesRadius.sm)
                                            }
                                        }
                                    }
                                    
                                    // Input
                                    TextField("Type tags separated by commas...", text: $newTagText)
                                        .font(.hermes.body)
                                        .foregroundColor(.hermes.text)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .padding(HermesSpacing.md)
                                        .background(Color.hermes.surface)
                                        .cornerRadius(HermesRadius.md)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: HermesRadius.md)
                                                .strokeBorder(Color.hermes.border, lineWidth: 1)
                                        )
                                        .onSubmit { commitTags() }
                                }
                                
                                Text("Add custom tags for better RAG retrieval.")
                                    .font(.hermes.caption)
                                    .foregroundColor(.hermes.muted)
                            }
                            
                            // Input Type
                            VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                                Text("INPUT TYPE")
                                    .font(.hermes.badge)
                                    .foregroundColor(.hermes.muted)
                                    .kerning(0.5)
                                
                                HStack(spacing: HermesSpacing.md) {
                                    TypeButton(
                                        icon: "text.alignleft",
                                        label: "Raw Text",
                                        isSelected: inputType == .text,
                                        action: { inputType = .text }
                                    )
                                    TypeButton(
                                        icon: "doc",
                                        label: "Upload PDF",
                                        isSelected: inputType == .pdf,
                                        action: { inputType = .pdf }
                                    )
                                }
                            }
                            
                            // Content
                            if inputType == .text {
                                VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                                    Text("CONTENT (KNOWLEDGE)")
                                        .font(.hermes.badge)
                                        .foregroundColor(.hermes.muted)
                                        .kerning(0.5)
                                    
                                    TextEditor(text: $content)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.hermes.text)
                                        .scrollContentBackground(.hidden)
                                        .padding(HermesSpacing.md)
                                        .frame(minHeight: 200)
                                        .background(Color.hermes.surface)
                                        .cornerRadius(HermesRadius.md)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: HermesRadius.md)
                                                .strokeBorder(Color.hermes.border, lineWidth: 1)
                                        )
                                }
                            } else {
                                // PDF Dropzone
                                VStack(spacing: HermesSpacing.md) {
                                    Image(systemName: "arrow.up.doc")
                                        .font(.system(size: 32, weight: .light))
                                        .foregroundColor(.hermes.muted)
                                    Text("Click to upload")
                                        .font(.hermes.bodyMedium)
                                        .foregroundColor(.hermes.text)
                                    Text("or drag and drop")
                                        .font(.hermes.body)
                                        .foregroundColor(.hermes.muted)
                                    Text("PDF (MAX. 10MB)")
                                        .font(.hermes.caption)
                                        .foregroundColor(.hermes.muted)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 150)
                                .background(Color.hermes.surface)
                                .cornerRadius(HermesRadius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HermesRadius.md)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                                        .foregroundColor(.hermes.border)
                                )
                            }
                            
                            // Submit
                            HermesButton(
                                title: "Save to Brain",
                                icon: "square.and.arrow.down",
                                isDisabled: title.isEmpty || (inputType == .text && content.isEmpty),
                                action: saveDocument
                            )
                        }
                    }
                    .frame(maxWidth: 600)
                }
                .padding(.horizontal, HermesSpacing.xl)
                .padding(.vertical, HermesSpacing.xxl)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color.hermes.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }
    
    // MARK: - Actions
    
    private func commitTags() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        // Split by commas
        let newTags = trimmed
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty && !customTags.contains($0) }
        
        customTags.append(contentsOf: newTags)
        newTagText = ""
    }
    
    private func saveDocument() {
        errors = []
        
        // Validate
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Knowledge title is required.")
            return
        }
        if selectedTags.isEmpty && customTags.isEmpty {
            errors.append("Select at least one persona tag or add a custom tag.")
            return
        }
        if inputType == .text && content.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Content cannot be empty.")
            return
        }
        
        // Merge persona tags + custom tags
        var allTags = Array(selectedTags)
        allTags.append(contentsOf: customTags)
        
        let doc = BrainDocument(
            id: UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespaces),
            type: inputType,
            content: content,
            tags: allTags,
            createdAt: Date()
        )
        onSave(doc)
        dismiss()
    }
}

// MARK: - Supporting Views

struct TagCheckbox: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: HermesSpacing.sm) {
                Image(systemName: isSelected ? "checkmark.square" : "square")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .hermes.accent : .hermes.border)
                Text(label)
                    .font(.hermes.body)
                    .foregroundColor(.hermes.text)
            }
            .padding(.horizontal, HermesSpacing.md)
            .padding(.vertical, HermesSpacing.sm)
            .background(isSelected ? Color.hermes.accent.opacity(0.05) : Color.hermes.surface)
            .cornerRadius(HermesRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: HermesRadius.sm)
                    .strokeBorder(isSelected ? Color.hermes.accent.opacity(0.3) : Color.hermes.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TypeButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: HermesSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(label)
                    .font(.hermes.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HermesSpacing.lg)
            .foregroundColor(isSelected ? .hermes.accent : .hermes.muted)
            .background(isSelected ? Color.hermes.accent.opacity(0.1) : Color.hermes.surface)
            .cornerRadius(HermesRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: HermesRadius.md)
                    .strokeBorder(isSelected ? Color.hermes.accent : Color.hermes.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, containerWidth: proposal.width ?? .infinity).size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let positions = layout(sizes: sizes, containerWidth: bounds.width).positions
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + positions[index].x, y: bounds.minY + positions[index].y), proposal: .unspecified)
        }
    }
    
    private func layout(sizes: [CGSize], containerWidth: CGFloat) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for size in sizes {
            if x + size.width > containerWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        
        return (CGSize(width: containerWidth, height: y + rowHeight), positions)
    }
}

#Preview {
    NavigationStack {
        BrainCreateView { _ in }
            .environmentObject(AppState())
    }
}
