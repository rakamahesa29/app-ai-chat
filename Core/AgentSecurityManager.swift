import Foundation
import SwiftUI
import UserNotifications
#if os(macOS)
import AppKit
#endif

// MARK: - Enums

public enum AgentExecutionMode: String, CaseIterable, Identifiable {
    case allowPerTask = "allow_per_task"
    case autoAllow = "auto_allow"
    
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .allowPerTask: return "Allow Per Task"
        case .autoAllow: return "Auto-Allow"
        }
    }
    public var description: String {
        switch self {
        case .allowPerTask: return "Minta konfirmasi manual sebelum setiap operasi berkas/root dijalankan."
        case .autoAllow: return "Jalankan operasi secara otonom (autonomous loop) tanpa konfirmasi per task."
        }
    }
    public var icon: String {
        switch self {
        case .allowPerTask: return "shield.lefthalf.filled"
        case .autoAllow: return "bolt.shield"
        }
    }
}

public enum AgentAccessScope: String, CaseIterable, Identifiable {
    case workspace = "workspace"
    case fullSystem = "full_system"
    
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .workspace: return "Workspace Saja"
        case .fullSystem: return "Full Mac (Root Access)"
        }
    }
    public var description: String {
        switch self {
        case .workspace: return "Mengizinkan agen mengakses folder Home (~/) atau folder proyek spesifik yang Anda pilih."
        case .fullSystem: return "Mengizinkan agen mengakses seluruh disk MacBook hingga direktori root (/)."
        }
    }
    public var icon: String {
        switch self {
        case .workspace: return "folder"
        case .fullSystem: return "lock.open.trianglebadge.exclamationmark"
        }
    }
}

// MARK: - Confirmation Request Struct

public struct AgentToolConfirmation: Identifiable, Equatable {
    public let id: UUID
    public let tool: String
    public let path: String
    public let contentPreview: String?
    public let isRoot: Bool
    public let timestamp: Date
    
    public init(id: UUID = UUID(), tool: String, path: String, contentPreview: String? = nil, isRoot: Bool = false) {
        self.id = id
        self.tool = tool
        self.path = path
        self.contentPreview = contentPreview
        self.isRoot = isRoot
        self.timestamp = Date()
    }
}

// MARK: - AgentSecurityManager

@MainActor
public final class AgentSecurityManager: ObservableObject {
    public static let shared = AgentSecurityManager()
    
    @AppStorage("agent_execution_mode") public var executionModeRaw: String = AgentExecutionMode.allowPerTask.rawValue
    @AppStorage("agent_access_scope") public var accessScopeRaw: String = AgentAccessScope.workspace.rawValue
    @AppStorage("has_configured_agent_security") public var hasConfiguredSecurity: Bool = false
    
    @Published public var pendingConfirmation: AgentToolConfirmation? = nil
    
    private var confirmationContinuation: CheckedContinuation<Bool, Never>? = nil
    
    public var executionMode: AgentExecutionMode {
        get { AgentExecutionMode(rawValue: executionModeRaw) ?? .allowPerTask }
        set { executionModeRaw = newValue.rawValue }
    }
    
    public var accessScope: AgentAccessScope {
        get { AgentAccessScope(rawValue: accessScopeRaw) ?? .workspace }
        set { accessScopeRaw = newValue.rawValue }
    }
    
    private init() {
        requestNotificationPermission()
    }
    
    // MARK: - macOS UserNotifications
    
    public func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("⚠️ [AgentSecurity] Gagal meminta izin notifikasi: \(error.localizedDescription)")
            } else {
                print("🔔 [AgentSecurity] Status izin notifikasi macOS: \(granted)")
            }
        }
    }
    
    public func postNotification(title: String, subtitle: String, body: String, sound: Bool = true) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        if sound {
            content.sound = UNNotificationSound.default
        }
        
        let request = UNNotificationRequest(
            identifier: "omoikane_agent_\(UUID().uuidString)",
            content: content,
            trigger: nil // Langsung tampilkan
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ [AgentSecurity] Gagal mengirim notifikasi macOS: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Interactive Approval Handling
    
    public func requestApproval(tool: String, path: String, content: String?, isRoot: Bool) async -> Bool {
        // Double verification notification di macOS
        let toolName = humanReadableToolName(tool)
        let modeName = executionMode.title
        let scopeName = accessScope.title
        
        if executionMode == .autoAllow {
            // Auto-allow mode: otomatis diizinkan, tetapi tetap kirimkan notifikasi audit trail
            postNotification(
                title: "🤖 Omoikane Agent (Auto-Allow)",
                subtitle: "\(toolName) \(isRoot ? "[Root Access]" : "[\(scopeName)]")",
                body: "Target: \(path)\nOperasi dijalankan otomatis secara otonom."
            )
            return true
        }
        
        // Allow per task mode: kirim notifikasi macOS dan tunggu persetujuan interaktif dari UI
        postNotification(
            title: "🛡️ Omoikane Agent Memerlukan Izin",
            subtitle: "\(toolName) \(isRoot ? "[Root Mode]" : "")",
            body: "Meminta persetujuan Anda untuk mengakses:\n\(path)"
        )
        
        let preview = content.map { str -> String in
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.count > 300 ? String(trimmed.prefix(300)) + "…" : trimmed
        }
        
        let confirmation = AgentToolConfirmation(
            tool: tool,
            path: path,
            contentPreview: preview,
            isRoot: isRoot
        )
        
        if let existing = self.confirmationContinuation {
            self.confirmationContinuation = nil
            existing.resume(returning: false)
        }
        
        self.pendingConfirmation = confirmation
        
        return await withCheckedContinuation { continuation in
            self.confirmationContinuation = continuation
        }
    }
    
    public func resolvePendingConfirmation(approved: Bool) {
        self.pendingConfirmation = nil
        let continuation = self.confirmationContinuation
        self.confirmationContinuation = nil
        continuation?.resume(returning: approved)
    }
    
    public func cancelPendingConfirmation() {
        resolvePendingConfirmation(approved: false)
    }
    
    private func humanReadableToolName(_ tool: String) -> String {
        switch tool {
        case "write_file": return "✏️ Menulis Berkas"
        case "read_file": return "📖 Membaca Berkas"
        case "delete_file": return "🗑️ Menghapus Berkas"
        case "list_files": return "📂 Membaca Direktori"
        default: return "🔧 Menjalankan Tool (\(tool))"
        }
    }
    
    // MARK: - Root Shell Execution
    
    #if os(macOS)
    public func executeRootCommand(_ command: String) throws -> String {
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escapedCommand)\" with administrator privileges"
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let output = appleScript.executeAndReturnError(&error)
            if let error = error {
                let msg = error[NSAppleScript.errorMessage] as? String ?? "AppleScript error"
                throw NSError(domain: "RootExecution", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            return output.stringValue ?? ""
        }
        throw NSError(domain: "RootExecution", code: 2, userInfo: [NSLocalizedDescriptionKey: "Gagal menginisialisasi AppleScript"])
    }
    #endif
}
