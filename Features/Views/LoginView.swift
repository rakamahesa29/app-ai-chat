import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var showRegister = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: HermesSpacing.xxl) {
                    VStack(spacing: HermesSpacing.sm) {
                        Text("Welcome back")
                            .font(.hermes.h1)
                            .foregroundColor(.hermes.text)
                        Text("Sign in to continue to Omoikane AI")
                            .font(.hermes.body)
                            .foregroundColor(.hermes.muted)
                    }
                    
                    HermesCard(padding: HermesSpacing.xxl) {
                        VStack(spacing: HermesSpacing.lg) {
                            if let error = appState.errorMessage {
                                HStack(spacing: HermesSpacing.sm) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                    Text(error)
                                }
                                .font(.hermes.caption)
                                .foregroundColor(.hermes.danger)
                                .padding(HermesSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.hermes.danger.opacity(0.1))
                                .cornerRadius(HermesRadius.sm)
                            }
                            
                            HermesTextField("you@example.com", text: $email, label: "Email", icon: "envelope")
                            HermesTextField("Enter your password", text: $password, label: "Password", isSecure: true, icon: "lock")
                            
                            HStack {
                                Toggle(isOn: $rememberMe) {
                                    Text("Remember me").font(.hermes.caption).foregroundColor(.hermes.muted)
                                }
                                #if os(macOS)
                                .toggleStyle(CheckboxToggleStyle())
                                #endif
                                Spacer()
                                Button("Forgot password?") {}
                                    .font(.hermes.captionMedium).foregroundColor(.hermes.accent).buttonStyle(PlainButtonStyle())
                            }
                            
                            HermesButton(
                                title: "Sign in", icon: "arrow.right",
                                isLoading: appState.isLoading,
                                isDisabled: email.isEmpty || password.isEmpty,
                                action: { appState.login(email: email, password: password) }
                            )
                        }
                    }
                    .frame(maxWidth: 400)
                    
                    HStack(spacing: HermesSpacing.xs) {
                        Text("Don't have an account?").font(.hermes.body).foregroundColor(.hermes.muted)
                        Button("Sign up") { showRegister = true }
                            .font(.hermes.bodyMedium).foregroundColor(.hermes.accent).buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, HermesSpacing.xl)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color.hermes.bg.ignoresSafeArea())
        .navigationDestination(isPresented: $showRegister) { RegisterView() }
    }
}
