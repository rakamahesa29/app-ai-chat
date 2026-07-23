import SwiftUI

struct BrainManagerView: View {
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @State private var documents: [BrainDocument] = []
    @State private var showCreateView = false
    @State private var editingDocument: BrainDocument? = nil
    @State private var isLoading = false
    @State private var apiError: String? = nil
    
    let filters = ["All", "General", "Architect", "Bestie", "Sage", "Executive", "Education"]
    
    var filteredDocuments: [BrainDocument] {
        var result = documents
        if selectedFilter != "All" {
            let filterTag = selectedFilter.lowercased()
            result = result.filter { $0.tags.contains(filterTag) }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: HermesSpacing.xs) {
                    Text("Knowledge Base")
                        .font(.hermes.h1)
                        .foregroundColor(.hermes.text)
                    Text("Manage documents and internal memory for RAG.")
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.muted)
                }
                
                Spacer()
                
                HermesButton(title: "Add Knowledge", icon: "plus.circle.fill", size: .small, action: {
                    showCreateView = true
                })
                .fixedSize()
            }
            .padding(HermesSpacing.xl)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
            
            Divider().foregroundColor(.hermes.border)
            
            // Toolbar
            VStack(spacing: HermesSpacing.md) {
                // Search
                HStack(spacing: HermesSpacing.md) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.hermes.muted)
                    TextField("Search documents...", text: $searchText)
                        .font(.hermes.body)
                        .foregroundColor(.hermes.text)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(HermesSpacing.md)
                .background(Color.hermes.surface)
                .cornerRadius(HermesRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: HermesRadius.md)
                        .strokeBorder(Color.hermes.border, lineWidth: 1)
                )
                
                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HermesSpacing.sm) {
                        ForEach(filters, id: \.self) { filter in
                            FilterChip(
                                label: filter,
                                isSelected: selectedFilter == filter,
                                action: { selectedFilter = filter }
                            )
                        }
                    }
                }
            }
            .padding(HermesSpacing.xl)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
            
            // Document List
            ScrollView {
                if filteredDocuments.isEmpty {
                    HermesEmptyState(
                        icon: "brain",
                        title: "No knowledge added yet",
                        message: "Add text or PDF documents to make your AI smarter.",
                        actionLabel: "Add Knowledge",
                        action: { showCreateView = true }
                    )
                } else {
                    LazyVStack(spacing: HermesSpacing.md) {
                        ForEach(filteredDocuments) { doc in
                            DocumentRow(
                                document: doc,
                                onEdit: { editingDocument = doc },
                                onDelete: {
                                    documents.removeAll { $0.id == doc.id }
                                    Task { await deleteBrainAPI(id: doc.id) }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, HermesSpacing.xl)
                    .padding(.bottom, HermesSpacing.xxl)
                    .frame(maxWidth: 1000)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Color.hermes.bg.ignoresSafeArea())
        .task { await fetchBrains() }
        .navigationDestination(isPresented: $showCreateView) {
            BrainCreateView { newDoc in
                documents.insert(newDoc, at: 0)
                Task { await saveBrain(newDoc) }
            }
        }
        .navigationDestination(item: $editingDocument) { doc in
            BrainEditView(document: doc) { updated in
                if let idx = documents.firstIndex(where: { $0.id == updated.id }) {
                    documents[idx] = updated
                }
                Task { await updateBrain(updated) }
            }
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }
    
    // MARK: - API
    
    private func fetchBrains() async {
        isLoading = true
        do {
            let brains = try await APIClient.shared.fetchBrains()
            documents = brains.map { $0.toDocument() }
        } catch {
            apiError = error.localizedDescription
        }
        isLoading = false
    }
    
    private func saveBrain(_ doc: BrainDocument) async {
        do {
            _ = try await APIClient.shared.createBrain(
                title: doc.title, tags: doc.tags, customTags: [],
                content: doc.content
            )
        } catch {
            apiError = error.localizedDescription
        }
    }
    
    private func updateBrain(_ doc: BrainDocument) async {
        do {
            _ = try await APIClient.shared.updateBrain(
                id: doc.id, title: doc.title, tags: doc.tags,
                customTags: [], content: doc.content
            )
        } catch {
            apiError = error.localizedDescription
        }
    }
    
    private func deleteBrainAPI(id: String) async {
        do {
            try await APIClient.shared.deleteBrain(id: id)
        } catch {
            apiError = error.localizedDescription
        }
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.hermes.bodyMedium)
                .padding(.horizontal, HermesSpacing.lg)
                .padding(.vertical, HermesSpacing.sm)
                .background(isSelected ? Color.hermes.accent : Color.hermes.surface)
                .foregroundColor(isSelected ? .white : .hermes.text)
                .cornerRadius(HermesRadius.full)
                .overlay(
                    RoundedRectangle(cornerRadius: HermesRadius.full)
                        .strokeBorder(isSelected ? Color.clear : Color.hermes.border, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DocumentRow: View {
    let document: BrainDocument
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        HermesCard {
            HStack(spacing: HermesSpacing.lg) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: HermesRadius.md)
                        .fill(document.type == .pdf ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: document.type.icon)
                        .font(.system(size: 20))
                        .foregroundColor(document.type == .pdf ? .red : .blue)
                }
                
                // Info
                VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                    Text(document.title)
                        .font(.hermes.h3)
                        .foregroundColor(.hermes.text)
                        .lineLimit(1)
                    
                    HStack(spacing: HermesSpacing.sm) {
                        HermesBadge(
                            text: document.type.rawValue.uppercased(),
                            color: document.type == .pdf ? .red : .blue,
                            style: .subtle
                        )
                        Text(document.createdAt, style: .date)
                            .font(.hermes.caption)
                            .foregroundColor(.hermes.muted)
                    }
                    
                    HStack(spacing: HermesSpacing.xs) {
                        ForEach(document.tags, id: \.self) { tag in
                            Text(tag.capitalized)
                                .font(.hermes.badge)
                                .padding(.horizontal, HermesSpacing.sm)
                                .padding(.vertical, HermesSpacing.xs)
                                .background(Color.hermes.hover)
                                .foregroundColor(.hermes.muted)
                                .cornerRadius(HermesRadius.sm)
                        }
                    }
                }
                
                Spacer()
                
                // Actions
                HStack(spacing: HermesSpacing.xs) {
                    HermesIconButton(icon: "pencil", size: 32, action: onEdit)
                    HermesIconButton(icon: "trash", size: 32, color: .hermes.danger, action: onDelete)
                }
            }
        }
    }
}

extension BrainDocument: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    NavigationStack {
        BrainManagerView()
            .environmentObject(AppState())
    }
}
