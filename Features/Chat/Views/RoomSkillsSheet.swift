import SwiftUI
import UniformTypeIdentifiers

/// Full-featured skills manager sheet, mirrors the web `openSkillsPanel()` flow:
/// list existing skills, toggle active/inactive, delete, add manual, upload .md/.txt.
struct RoomSkillsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let roomId: String

    @State private var skills: [RoomSkillResponse] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Add flows
    @State private var showAddManual = false
    @State private var showFileImporter = false

    // Toggle debounce state
    @State private var togglingIds: Set<Int> = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().foregroundColor(.hermes.border)

            if let err = errorMessage {
                errorBanner(err)
            }

            if isLoading && skills.isEmpty {
                Spacer()
                ProgressView("Loading skills…").font(.hermes.caption)
                Spacer()
            } else if skills.isEmpty {
                emptyState
            } else {
                skillsList
            }

            Divider().foregroundColor(.hermes.border)
            actionBar
        }
        .frame(minWidth: 480, minHeight: 500)
        .background(Color.hermes.bg)
        .task { await load() }
        .sheet(isPresented: $showAddManual) {
            AddSkillManualSheet { title, content in
                await addManual(title: title, content: content)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: skillFileTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFilePicked(result)
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Room Skills")
                    .font(.hermes.h3)
                    .foregroundColor(.hermes.text)
                Text("Active skills are injected into the AI's system prompt for this room.")
                    .font(.hermes.caption)
                    .foregroundColor(.hermes.muted)
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.hermes.accent)
        }
        .padding(HermesSpacing.lg)
        .background(Color.hermes.surface)
    }

    private func errorBanner(_ err: String) -> some View {
        HStack(spacing: HermesSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11))
                .foregroundColor(.hermes.danger)
            Text(err).font(.hermes.caption).foregroundColor(.hermes.danger)
            Spacer()
            Button {
                errorMessage = nil
            } label: {
                Image(systemName: "xmark").font(.system(size: 9)).foregroundColor(.hermes.muted)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, HermesSpacing.lg)
        .padding(.vertical, HermesSpacing.sm)
        .background(Color.hermes.danger.opacity(0.08))
    }

    // MARK: - Empty / List
    private var emptyState: some View {
        VStack(spacing: HermesSpacing.md) {
            Spacer()
            Image(systemName: "book.closed")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.hermes.muted.opacity(0.5))
            Text("No skills yet")
                .font(.hermes.bodyMedium)
                .foregroundColor(.hermes.text)
            Text("Add a skill (manual text or upload a .md/.txt file) so the AI follows extra rules in this room.")
                .font(.hermes.caption)
                .foregroundColor(.hermes.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HermesSpacing.xl)
            Spacer()
        }
    }

    private var skillsList: some View {
        ScrollView {
            LazyVStack(spacing: HermesSpacing.sm) {
                ForEach(skills) { skill in
                    skillRow(skill)
                }
            }
            .padding(HermesSpacing.lg)
        }
    }

    private func skillRow(_ skill: RoomSkillResponse) -> some View {
        HStack(alignment: .top, spacing: HermesSpacing.md) {
            Image(systemName: skill.isManual ? "square.and.pencil" : "doc.text")
                .font(.system(size: 14))
                .foregroundColor(skill.isManual ? .hermes.accent : .orange)
                .frame(width: 28, height: 28)
                .background((skill.isManual ? Color.hermes.accent : .orange).opacity(0.1))
                .cornerRadius(HermesRadius.sm)

            VStack(alignment: .leading, spacing: 2) {
                Text(skill.title)
                    .font(.hermes.bodyMedium)
                    .foregroundColor(.hermes.text)
                    .lineLimit(1)
                Text(skill.isManual ? "Manual input" : "File · \(skill.originalFilename ?? "uploaded")")
                    .font(.hermes.caption)
                    .foregroundColor(.hermes.muted)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { skill.isActive ?? false },
                set: { _ in Task { await toggle(skill) } }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .hermes.success))
            .labelsHidden()
            .disabled(togglingIds.contains(skill.id))

            Button {
                Task { await delete(skill) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.hermes.muted)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(HermesSpacing.md)
        .background(Color.hermes.surface)
        .cornerRadius(HermesRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: HermesRadius.md)
                .strokeBorder(Color.hermes.border, lineWidth: 1)
        )
    }

    // MARK: - Action Bar
    private var actionBar: some View {
        HStack(spacing: HermesSpacing.md) {
            Button {
                showAddManual = true
            } label: {
                Label("Add Manual", systemImage: "square.and.pencil")
                    .font(.hermes.bodyMedium)
                    .foregroundColor(.white)
                    .padding(.horizontal, HermesSpacing.md)
                    .padding(.vertical, HermesSpacing.sm)
                    .background(Color.hermes.accent)
                    .cornerRadius(HermesRadius.sm)
            }
            .buttonStyle(PlainButtonStyle())

            Button {
                showFileImporter = true
            } label: {
                Label("Upload .md / .txt", systemImage: "arrow.up.doc")
                    .font(.hermes.bodyMedium)
                    .foregroundColor(.hermes.text)
                    .padding(.horizontal, HermesSpacing.md)
                    .padding(.vertical, HermesSpacing.sm)
                    .background(Color.hermes.surface)
                    .cornerRadius(HermesRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: HermesRadius.sm)
                            .strokeBorder(Color.hermes.border, lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            if isLoading { ProgressView().scaleEffect(0.6) }
        }
        .padding(HermesSpacing.lg)
        .background(Color.hermes.surface)
    }

    // MARK: - Data
    private var skillFileTypes: [UTType] {
        [
            .plainText,
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "txt") ?? .plainText,
        ].compactMap { $0 }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            skills = try await APIClient.shared.fetchSkills(roomId: roomId)
        } catch {
            errorMessage = "Failed to load skills: \(error.localizedDescription)"
        }
    }

    private func addManual(title: String, content: String) async {
        do {
            let created = try await APIClient.shared.createSkillManual(roomId: roomId, title: title, content: content)
            withAnimation { skills.insert(created, at: 0) }
        } catch {
            errorMessage = "Add failed: \(error.localizedDescription)"
        }
    }

    private func toggle(_ skill: RoomSkillResponse) async {
        togglingIds.insert(skill.id)
        defer { togglingIds.remove(skill.id) }
        do {
            let newState = try await APIClient.shared.toggleSkill(roomId: roomId, skillId: skill.id)
            if let i = skills.firstIndex(where: { $0.id == skill.id }) {
                let s = skills[i]
                skills[i] = RoomSkillResponse(
                    id: s.id, roomId: s.roomId, title: s.title, content: s.content,
                    sourceType: s.sourceType, originalFilename: s.originalFilename,
                    isActive: newState, createdAt: s.createdAt, updatedAt: s.updatedAt
                )
            }
        } catch {
            errorMessage = "Toggle failed: \(error.localizedDescription)"
        }
    }

    private func delete(_ skill: RoomSkillResponse) async {
        do {
            try await APIClient.shared.deleteSkill(roomId: roomId, skillId: skill.id)
            withAnimation { skills.removeAll { $0.id == skill.id } }
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    private func handleFilePicked(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await uploadFile(url: url) }
        case .failure(let e):
            errorMessage = "Pick failed: \(e.localizedDescription)"
        }
    }

    private func uploadFile(url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()
        guard ext == "md" || ext == "txt" else {
            errorMessage = "Only .md and .txt files are allowed."
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let mime = ext == "md" ? "text/markdown" : "text/plain"
            let title = url.deletingPathExtension().lastPathComponent
            let created = try await APIClient.shared.createSkillFile(
                roomId: roomId, title: title,
                fileData: data, fileName: url.lastPathComponent, mimeType: mime
            )
            withAnimation { skills.insert(created, at: 0) }
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Add Manual Skill Sheet
struct AddSkillManualSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, String) async -> Void

    @State private var title = ""
    @State private var content = ""
    @State private var isSaving = false

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Skill")
                    .font(.hermes.h3)
                    .foregroundColor(.hermes.text)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.hermes.muted)
                Button {
                    Task {
                        isSaving = true
                        await onSave(
                            title.trimmingCharacters(in: .whitespacesAndNewlines),
                            content.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        isSaving = false
                        dismiss()
                    }
                } label: {
                    Text(isSaving ? "Saving…" : "Add Skill")
                        .font(.hermes.bodyMedium).foregroundColor(.white)
                        .padding(.horizontal, HermesSpacing.md).padding(.vertical, HermesSpacing.sm)
                        .background(Color.hermes.accent).cornerRadius(HermesRadius.sm)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canSave || isSaving)
                .opacity((!canSave || isSaving) ? 0.5 : 1)
            }
            .padding(HermesSpacing.lg)
            .background(Color.hermes.surface)

            Divider().foregroundColor(.hermes.border)

            VStack(alignment: .leading, spacing: HermesSpacing.md) {
                HermesTextField("e.g. Always respond in Bahasa Indonesia", text: $title, label: "Skill Title")

                Text("CONTENT")
                    .font(.hermes.badge)
                    .foregroundColor(.hermes.muted)
                    .kerning(0.5)

                TextEditor(text: $content)
                    .font(.hermes.mono)
                    .foregroundColor(.hermes.text)
                    .scrollContentBackground(.hidden)
                    .padding(HermesSpacing.md)
                    .background(Color.hermes.surface)
                    .cornerRadius(HermesRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: HermesRadius.md)
                            .strokeBorder(Color.hermes.border, lineWidth: 1)
                    )
            }
            .padding(HermesSpacing.lg)
        }
        .frame(minWidth: 480, minHeight: 420)
        .background(Color.hermes.bg)
    }
}
