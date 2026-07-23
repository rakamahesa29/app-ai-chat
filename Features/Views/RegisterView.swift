import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && password.count >= 8 && password == confirmPassword
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: HermesSpacing.xxl) {
                    VStack(spacing: HermesSpacing.sm) {
                        Text("Create an account")
                            .font(.hermes.h1).foregroundColor(.hermes.text)
                        Text("Join Omoikane AI to start exploring")
                            .font(.hermes.body).foregroundColor(.hermes.muted)
                    }
                    
                    HermesCard(padding: HermesSpacing.xxl) {
                        VStack(spacing: HermesSpacing.lg) {
                            if let error = appState.errorMessage {
                                HStack(spacing: HermesSpacing.sm) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                    Text(error)
                                }
                                .font(.hermes.caption).foregroundColor(.hermes.danger)
                                .padding(HermesSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.hermes.danger.opacity(0.1)).cornerRadius(HermesRadius.sm)
                            }
                            
                            HermesTextField("John Doe", text: $name, label: "Full Name", icon: "person")
                            HermesTextField("you@example.com", text: $email, label: "Email", icon: "envelope")
                            HermesTextField("Min 8 characters", text: $password, label: "Password", isSecure: true, icon: "lock")
                            HermesTextField("Confirm your password", text: $confirmPassword, label: "Confirm Password", isSecure: true, icon: "lock")
                            
                            Text("By creating an account, you agree to our Terms of Service and Privacy Policy.")
                                .font(.hermes.caption).foregroundColor(.hermes.muted).multilineTextAlignment(.center)
                            
                            HermesButton(
                                title: "Create Account", icon: "person.badge.plus",
                                isLoading: appState.isLoading,
                                isDisabled: !isFormValid,
                                action: { appState.register(name: name, email: email, password: password) }
                            )
                        }
                    }
                    .frame(maxWidth: 400)
                    
                    HStack(spacing: HermesSpacing.xs) {
                        Text("Already have an account?").font(.hermes.body).foregroundColor(.hermes.muted)
                        Button("Sign in") { dismiss() }
                            .font(.hermes.bodyMedium).foregroundColor(.hermes.accent).buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, HermesSpacing.xl).padding(.vertical, HermesSpacing.xxl)
                .frame(maxWidth: .infinity).frame(minHeight: geometry.size.height)
            }
        }
        .background(Color.hermes.bg.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { dismiss() }) {
                    HStack(spacing: HermesSpacing.xs) {
                        Image(systemName: "chevron.left"); Text("Back")
                    }
                    .font(.hermes.body).foregroundColor(.hermes.accent)
                }
            }
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        #endif
    }
}
