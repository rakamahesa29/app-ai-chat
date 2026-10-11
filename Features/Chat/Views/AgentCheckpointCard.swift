import SwiftUI
import AppKit

// MARK: - Antigravity Checkpoint Card Component
struct AgentCheckpointCard: View {
    let checkpoint: AgentCheckpoint
    
    @State private var isCopied = false
    
    private var actionColor: Color {
        switch checkpoint.action.lowercased() {
        case "explored": return Color.cyan
        case "created":  return Color.green
        case "edited":   return Color.orange
        case "deleted":  return Color.red
        default:         return Color.hermes.accent
        }
    }
    
    private var actionIcon: String {
        switch checkpoint.action.lowercased() {
        case "explored": return "magnifyingglass"
        case "created":  return "doc.badge.plus"
        case "edited":   return "pencil.line"
        case "deleted":  return "trash"
        default:         return "hammer.fill"
        }
    }
    
    private var actionLabel: String {
        switch checkpoint.action.lowercased() {
        case "explored": return "Explored"
        case "created":  return "Created"
        case "edited":   return "Edited"
        case "deleted":  return "Deleted"
        default:         return "Executed"
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: HermesSpacing.md) {
            // Checkpoint sequence indicator
            ZStack {
                Circle()
                    .fill(actionColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: actionIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(actionColor)
            }
            
            // File & Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: HermesSpacing.xs) {
                    Text(actionLabel.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(actionColor.opacity(0.18))
                        .foregroundColor(actionColor)
                        .cornerRadius(4)
                    
                    Text(checkpoint.file)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.hermes.text)
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.hermes.success)
                }
                
                HStack(spacing: HermesSpacing.sm) {
                    Text(checkpoint.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.hermes.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    if !checkpoint.message.isEmpty {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.hermes.muted.opacity(0.5))
                        
                        Text(checkpoint.message)
                            .font(.system(size: 10))
                            .foregroundColor(.hermes.muted)
                            .lineLimit(1)
                    }
                }
            }
            
            // Action Buttons
            HStack(spacing: HermesSpacing.xs) {
                Button(action: openInFinder) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundColor(.hermes.muted)
                        .padding(5)
                        .background(Color.hermes.card.opacity(0.8))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Buka di Finder")
                
                Button(action: copyPath) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(isCopied ? .hermes.success : .hermes.muted)
                        .padding(5)
                        .background(Color.hermes.card.opacity(0.8))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Salin Path")
            }
        }
        .padding(HermesSpacing.sm + 2)
        .background(Color.hermes.card.opacity(0.45))
        .cornerRadius(HermesRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: HermesRadius.md)
                .strokeBorder(actionColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func copyPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(checkpoint.path, forType: .string)
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCopied = false
        }
    }
    
    private func openInFinder() {
        let cleanPath = (checkpoint.path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: cleanPath)
        if FileManager.default.fileExists(atPath: cleanPath) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            let parent = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: parent.path) {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: parent.path)
            }
        }
    }
}

// MARK: - Checkpoints Sequence Container
struct AgentCheckpointsSequenceView: View {
    let checkpoints: [AgentCheckpoint]
    @State private var isExpanded: Bool = true
    
    var body: some View {
        if !checkpoints.isEmpty {
            VStack(alignment: .leading, spacing: HermesSpacing.xs) {
                // Header
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                    HStack(spacing: HermesSpacing.xs) {
                        Image(systemName: "checklist")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.hermes.accent)
                        
                        Text("Checkpoints (\(checkpoints.count))")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.hermes.text)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                            .foregroundColor(.hermes.muted)
                    }
                    .padding(.horizontal, HermesSpacing.sm)
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
                
                if isExpanded {
                    VStack(spacing: 6) {
                        ForEach(checkpoints) { cp in
                            AgentCheckpointCard(checkpoint: cp)
                        }
                    }
                }
            }
            .padding(HermesSpacing.sm)
            .background(Color.hermes.surface.opacity(0.7))
            .cornerRadius(HermesRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: HermesRadius.lg)
                    .strokeBorder(Color.hermes.border.opacity(0.6), lineWidth: 1)
            )
        }
    }
}
