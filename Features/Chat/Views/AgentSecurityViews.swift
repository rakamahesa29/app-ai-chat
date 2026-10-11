import SwiftUI

// MARK: - Agent Security Setup Sheet
struct AgentSecuritySetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var securityManager = AgentSecurityManager.shared
    
    @State private var selectedExecutionMode: AgentExecutionMode = .allowPerTask
    @State private var selectedAccessScope: AgentAccessScope = .workspace
    
    var onConfirm: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: HermesSpacing.sm) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 18))
                        .foregroundColor(.hermes.accent)
                    Text("Konfigurasi Otorisasi Agentic")
                        .font(.hermes.h3)
                        .foregroundColor(.hermes.text)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.hermes.muted)
                        .padding(HermesSpacing.xs)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(HermesSpacing.lg)
            .background(Color.hermes.surface)
            
            Divider().foregroundColor(.hermes.border)
            
            ScrollView {
                VStack(alignment: .leading, spacing: HermesSpacing.xl) {
                    // Penjelasan Singkat
                    Text("Omoikane Agent memiliki kemampuan mengeksekusi aksi berkas lokal di MacBook Anda. Tentukan tingkat izin eksekusi dan jangkauan akses berkas di bawah ini.")
                        .font(.hermes.body)
                        .foregroundColor(.hermes.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // 1. Mode Otorisasi
                    VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                        Text("1. MODE OTORISASI EKSEKUSI")
                            .font(.hermes.badge)
                            .foregroundColor(.hermes.muted)
                        
                        ForEach(AgentExecutionMode.allCases) { mode in
                            Button(action: { selectedExecutionMode = mode }) {
                                HStack(alignment: .top, spacing: HermesSpacing.md) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(selectedExecutionMode == mode ? .hermes.accent : .hermes.muted)
                                        .frame(width: 24, height: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mode.title)
                                            .font(.hermes.bodyMedium)
                                            .foregroundColor(.hermes.text)
                                        Text(mode.description)
                                            .font(.hermes.caption)
                                            .foregroundColor(.hermes.muted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                    if selectedExecutionMode == mode {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.hermes.accent)
                                            .font(.system(size: 16))
                                    }
                                }
                                .padding(HermesSpacing.md)
                                .background(selectedExecutionMode == mode ? Color.hermes.accent.opacity(0.08) : Color.hermes.surface)
                                .cornerRadius(HermesRadius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HermesRadius.md)
                                        .strokeBorder(selectedExecutionMode == mode ? Color.hermes.accent : Color.hermes.border, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // 2. Cakupan Akses File
                    VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                        Text("2. CAKUPAN AKSES FILE (FILESYSTEM)")
                            .font(.hermes.badge)
                            .foregroundColor(.hermes.muted)
                        
                        ForEach(AgentAccessScope.allCases) { scope in
                            Button(action: { selectedAccessScope = scope }) {
                                HStack(alignment: .top, spacing: HermesSpacing.md) {
                                    Image(systemName: scope.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(selectedAccessScope == scope ? (scope == .fullSystem ? .orange : .hermes.accent) : .hermes.muted)
                                        .frame(width: 24, height: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(scope.title)
                                                .font(.hermes.bodyMedium)
                                                .foregroundColor(.hermes.text)
                                            if scope == .fullSystem {
                                                Text("ROOT")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.orange)
                                                    .cornerRadius(3)
                                            }
                                        }
                                        Text(scope.description)
                                            .font(.hermes.caption)
                                            .foregroundColor(.hermes.muted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                    if selectedAccessScope == scope {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(scope == .fullSystem ? .orange : .hermes.accent)
                                            .font(.system(size: 16))
                                    }
                                }
                                .padding(HermesSpacing.md)
                                .background(selectedAccessScope == scope ? (scope == .fullSystem ? Color.orange.opacity(0.08) : Color.hermes.accent.opacity(0.08)) : Color.hermes.surface)
                                .cornerRadius(HermesRadius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HermesRadius.md)
                                        .strokeBorder(selectedAccessScope == scope ? (scope == .fullSystem ? Color.orange : Color.hermes.accent) : Color.hermes.border, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // 3. Double Verification Notice
                    HStack(alignment: .top, spacing: HermesSpacing.md) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.hermes.success)
                            .font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Double Verifikasi macOS Aktif")
                                .font(.hermes.bodyMedium)
                                .foregroundColor(.hermes.text)
                            Text("Setiap kali agen mengakses atau memodifikasi file di Mac Anda, sistem akan secara otomatis memunculkan Notifikasi Asli macOS sebagai verifikasi ganda dan riwayat audit.")
                                .font(.hermes.caption)
                                .foregroundColor(.hermes.muted)
                        }
                    }
                    .padding(HermesSpacing.md)
                    .background(Color.hermes.success.opacity(0.08))
                    .cornerRadius(HermesRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: HermesRadius.md)
                            .strokeBorder(Color.hermes.success.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(HermesSpacing.xl)
            }
            
            Divider().foregroundColor(.hermes.border)
            
            // Footer Action
            HStack {
                Button("Batal") {
                    dismiss()
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.hermes.muted)
                
                Spacer()
                
                Button(action: {
                    securityManager.executionMode = selectedExecutionMode
                    securityManager.accessScope = selectedAccessScope
                    securityManager.hasConfiguredSecurity = true
                    securityManager.postNotification(
                        title: "🤖 Omoikane Agent Siap",
                        subtitle: "Mode: \(selectedExecutionMode.title) | \(selectedAccessScope.title)",
                        body: "Pengaturan otorisasi agen berhasil disimpan."
                    )
                    dismiss()
                    onConfirm?()
                }) {
                    Text("Terapkan Pengaturan Agent")
                        .font(.hermes.bodyMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, HermesSpacing.lg)
                        .padding(.vertical, HermesSpacing.sm + 2)
                        .background(Color.hermes.accent)
                        .cornerRadius(HermesRadius.sm)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(HermesSpacing.lg)
            .background(Color.hermes.surface)
        }
        .frame(minWidth: 520, maxWidth: 600, minHeight: 520, maxHeight: 600)
        .background(Color.hermes.bg)
        .onAppear {
            selectedExecutionMode = securityManager.executionMode
            selectedAccessScope = securityManager.accessScope
        }
    }
}

// MARK: - Inline Agent Confirmation Card (for Allow Per Task Mode)
struct AgentConfirmationCard: View {
    let confirmation: AgentToolConfirmation
    let onApprove: () -> Void
    let onDeny: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: HermesSpacing.sm) {
            HStack(spacing: HermesSpacing.sm) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                Text("Konfirmasi Eksekusi Tool Agent")
                    .font(.hermes.bodyMedium)
                    .foregroundColor(.hermes.text)
                
                if confirmation.isRoot {
                    Text("ROOT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red)
                        .cornerRadius(3)
                }
                
                Spacer()
                
                Text(confirmation.tool)
                    .font(.hermes.mono)
                    .foregroundColor(.hermes.muted)
                    .padding(.horizontal, HermesSpacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.hermes.hover)
                    .cornerRadius(4)
            }
            
            HStack(alignment: .top, spacing: HermesSpacing.xs) {
                Text("Target:")
                    .font(.hermes.captionMedium)
                    .foregroundColor(.hermes.muted)
                Text(confirmation.path)
                    .font(.hermes.mono)
                    .foregroundColor(.hermes.text)
                    .lineLimit(2)
            }
            
            if let preview = confirmation.contentPreview, !preview.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pratinjau Konten:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.hermes.muted)
                    Text(preview)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.hermes.textSecondary)
                        .padding(HermesSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.hermes.bg)
                        .cornerRadius(HermesRadius.sm)
                }
            }
            
            HStack(spacing: HermesSpacing.md) {
                Spacer()
                Button(action: onDeny) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Tolak (Deny)")
                    }
                    .font(.hermes.captionMedium)
                    .foregroundColor(.hermes.danger)
                    .padding(.horizontal, HermesSpacing.md)
                    .padding(.vertical, HermesSpacing.xs + 2)
                    .background(Color.hermes.danger.opacity(0.1))
                    .cornerRadius(HermesRadius.sm)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onApprove) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Izinkan (Allow)")
                    }
                    .font(.hermes.captionMedium)
                    .foregroundColor(.white)
                    .padding(.horizontal, HermesSpacing.md)
                    .padding(.vertical, HermesSpacing.xs + 2)
                    .background(Color.hermes.accent)
                    .cornerRadius(HermesRadius.sm)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, HermesSpacing.xs)
        }
        .padding(HermesSpacing.md)
        .background(Color.hermes.card)
        .cornerRadius(HermesRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: HermesRadius.md)
                .strokeBorder(Color.orange.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
    }
}
