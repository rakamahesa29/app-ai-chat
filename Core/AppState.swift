import SwiftUI
import Combine

/// Manages the global app authentication state and user session.
@MainActor
class AppState: ObservableObject {
    enum AuthStatus {
        case splash
        case unauthenticated
        case authenticated
    }
    
    @Published var authStatus: AuthStatus = .splash
    @Published var currentUserEmail: String = ""
    @Published var currentUserName: String = ""
    @Published var isDarkMode: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    func completeSplash() {
        // Check if we have a stored token
        if APIConfig.isAuthenticated {
            Task { await restoreSession() }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                authStatus = .unauthenticated
            }
        }
    }
    
    func login(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let data = try await APIClient.shared.login(email: email, password: password)
                currentUserEmail = data.user.email
                currentUserName = data.user.name
                withAnimation(.easeInOut(duration: 0.3)) {
                    authStatus = .authenticated
                    isLoading = false
                }
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func register(name: String, email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let data = try await APIClient.shared.register(name: name, email: email, password: password)
                currentUserEmail = data.user.email
                currentUserName = data.user.name
                withAnimation(.easeInOut(duration: 0.3)) {
                    authStatus = .authenticated
                    isLoading = false
                }
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func logout() {
        Task {
            try? await APIClient.shared.logout()
        }
        currentUserEmail = ""
        currentUserName = ""
        withAnimation(.easeInOut(duration: 0.3)) {
            authStatus = .unauthenticated
        }
    }
    
    private func restoreSession() async {
        do {
            let user = try await APIClient.shared.fetchUser()
            currentUserEmail = user.email
            currentUserName = user.name
            withAnimation(.easeInOut(duration: 0.3)) {
                authStatus = .authenticated
            }
        } catch {
            APIConfig.token = nil
            withAnimation(.easeInOut(duration: 0.3)) {
                authStatus = .unauthenticated
            }
        }
    }
}
