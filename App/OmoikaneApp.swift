import SwiftUI

@main
struct OmoikaneApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 650)
                #endif
        }
        #if os(macOS)
        .windowStyle(HiddenTitleBarWindowStyle())
        #endif
    }
}

/// Root coordinator that switches between Splash, Auth, and Authenticated states
struct RootView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            switch appState.authStatus {
            case .splash:
                SplashView()
            case .unauthenticated:
                NavigationStack {
                    HomeView()
                }
            case .authenticated:
                AuthenticatedContainerView()
            }
        }
        .preferredColorScheme(appState.isDarkMode ? .dark : .light)
    }
}
