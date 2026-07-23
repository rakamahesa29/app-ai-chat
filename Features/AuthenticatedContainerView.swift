import SwiftUI

// MARK: - Navigation Bar (shown above content on mac/iPad)
struct AuthenticatedNavigationBar: View {
    @EnvironmentObject var appState: AppState
    var onSettingsTap: (() -> Void)? = nil
    var onProfileTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: HermesSpacing.lg) {
            // Logo
            HStack(spacing: HermesSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: HermesRadius.sm)
                        .fill(Color.hermes.accent)
                        .frame(width: 32, height: 32)
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.white)
                }
                Text("Omoikane AI")
                    .font(.hermes.h3)
                    .foregroundColor(.hermes.text)
            }

            Spacer()

            // Right controls
            HStack(spacing: HermesSpacing.md) {
                // Theme Toggle
                Button(action: { appState.isDarkMode.toggle() }) {
                    Image(systemName: appState.isDarkMode ? "sun.max" : "moon")
                        .font(.system(size: 16))
                        .foregroundColor(.hermes.muted)
                        .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())

                // Settings gear
                Button(action: { onSettingsTap?() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundColor(.hermes.muted)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(PlainButtonStyle())

                // Profile Button
                Button(action: { onProfileTap?() }) {
                    HStack(spacing: HermesSpacing.sm) {
                        Circle()
                            .fill(Color.hermes.accent.opacity(0.15))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(appState.currentUserName.prefix(1)).uppercased())
                                    .font(.hermes.caption)
                                    .foregroundColor(.hermes.accent)
                            )
                        
                        Text(appState.currentUserName)
                            .font(.hermes.bodyMedium)
                            .foregroundColor(.hermes.text)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.hermes.muted)
                    }
                    .padding(.horizontal, HermesSpacing.sm)
                    .padding(.vertical, 6)
//                    .background(Color.hermes.hover)
                    .cornerRadius(HermesRadius.sm)
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    Button(action: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onProfileTap?()
                        }
                    }) {
                        Label("Profile", systemImage: "person")
                    }
                    Divider()
                    Button(role: .destructive, action: { appState.logout() }) {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
        .padding(.horizontal, HermesSpacing.xl)
        .padding(.vertical, HermesSpacing.md)
        .background(Color.hermes.surface)
        .overlay(alignment: .bottom) {
            Divider().foregroundColor(.hermes.border)
        }
    }
}

// MARK: - Authenticated Container View
struct AuthenticatedContainerView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AppTab = .dashboard
    @State private var activeSheet: ActiveSheet? = nil

    enum ActiveSheet: Identifiable {
        case settings
        case profile
        var id: Self { self }
    }

    enum AppTab: String, CaseIterable {
        case dashboard = "Dashboard"
        case chat = "Chat"
        case brain = "Brain"
        case files = "Files"

        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .chat: return "message"
            case .brain: return "brain"
            case .files: return "folder"
            }
        }
    }

    var body: some View {
        Group {
            #if os(macOS)
            macLayout
            #else
            if UIDevice.current.userInterfaceIdiom == .pad {
                macLayout
            } else {
                phoneLayout
            }
            #endif
        }
        .sheet(item: $activeSheet) { sheet in
            Group {
                switch sheet {
                case .settings:
                    SettingsView()
                        .environmentObject(appState)
                        .frame(minWidth: 580, idealWidth: 600, minHeight: 680, idealHeight: 720)
                case .profile:
                    ProfileView()
                        .environmentObject(appState)
                        .frame(minWidth: 480, idealWidth: 520, minHeight: 500, idealHeight: 560)
                }
            }
        }
    }

    // MARK: - Mac / iPad Layout
    private var macLayout: some View {
        NavigationSplitView {
            // --- Sidebar ---
            VStack(spacing: 0) {
                // App logo
                HStack(spacing: HermesSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: HermesRadius.sm)
                            .fill(Color.hermes.accent)
                            .frame(width: 32, height: 32)
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.white)
                    }
                    Text("Omoikane AI")
                        .font(.hermes.h3)
                        .foregroundColor(.hermes.text)
                    Spacer()
                }
                .padding(.horizontal, HermesSpacing.lg)
                .padding(.vertical, HermesSpacing.md)

                Divider().foregroundColor(.hermes.border)

                // Tabs
                VStack(spacing: HermesSpacing.xs) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        sidebarButton(for: tab)
                    }
                }
                .padding(.horizontal, HermesSpacing.md)
                .padding(.top, HermesSpacing.md)

                Spacer()

                // Footer
                VStack(spacing: 0) {
                    Divider().foregroundColor(.hermes.border)

                    Button(action: { activeSheet = .settings }) {
                        HStack(spacing: HermesSpacing.md) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 15))
                            Text("Settings")
                                .font(.hermes.bodyMedium)
                            Spacer()
                        }
                        .padding(.horizontal, HermesSpacing.lg)
                        .padding(.vertical, HermesSpacing.md)
                        .foregroundColor(.hermes.muted)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Divider().foregroundColor(.hermes.border)

                    // User info
                    HStack(spacing: HermesSpacing.md) {
                        Circle()
                            .fill(Color.hermes.accent.opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(String(appState.currentUserName.prefix(1)).uppercased())
                                    .font(.hermes.bodyMedium)
                                    .foregroundColor(.hermes.accent)
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(appState.currentUserName)
                                .font(.hermes.bodyMedium)
                                .foregroundColor(.hermes.text)
                                .lineLimit(1)
                            Text(appState.currentUserEmail)
                                .font(.hermes.caption)
                                .foregroundColor(.hermes.muted)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button(action: { appState.logout() }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14))
                                .foregroundColor(.hermes.muted)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(HermesSpacing.lg)
                }
            }
            .background(Color.hermes.surface)
            #if os(macOS)
            .frame(minWidth: 220, maxWidth: 240)
            #endif
        } detail: {
            VStack(spacing: 0) {
                AuthenticatedNavigationBar(
                    onSettingsTap: { activeSheet = .settings },
                    onProfileTap: { activeSheet = .profile }
                )
                .environmentObject(appState)
                selectedContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.hermes.bg)
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - iPhone Layout
    private var phoneLayout: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                .tag(AppTab.dashboard)

            MainContainerView()
                .tabItem { Label("Chat", systemImage: "message") }
                .tag(AppTab.chat)

            NavigationStack {
                BrainManagerView()
            }
            .tabItem { Label("Brain", systemImage: "brain") }
            .tag(AppTab.brain)
            
            NavigationStack {
                FileBrowserView()
            }
            .tabItem { Label("Files", systemImage: "folder") }
            .tag(AppTab.files)
        }
        .tint(Color.hermes.accent)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView()
        case .chat:
            MainContainerView()
        case .brain:
            NavigationStack {
                BrainManagerView()
            }
        case .files:
            NavigationStack {
                FileBrowserView()
            }
        }
    }

    private func sidebarButton(for tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        return Button(action: { selectedTab = tab }) {
            HStack(spacing: HermesSpacing.md) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15))
                    .frame(width: 20)
                Text(tab.rawValue)
                    .font(.hermes.bodyMedium)
                Spacer()
            }
            .padding(.horizontal, HermesSpacing.md)
            .padding(.vertical, HermesSpacing.sm + 2)
            .background(isSelected ? Color.hermes.accent.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? .hermes.accent : .hermes.muted)
            .cornerRadius(HermesRadius.sm)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AuthenticatedContainerView()
        .environmentObject({
            let state = AppState()
            state.currentUserName = "Raka"
            state.currentUserEmail = "raka@example.com"
            state.authStatus = .authenticated
            return state
        }())
}
