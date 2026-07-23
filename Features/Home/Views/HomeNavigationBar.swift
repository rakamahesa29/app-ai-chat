import SwiftUI

struct HomeNavigationBar: View {
    @Binding var showLogin: Bool
    @Binding var showRegister: Bool
    
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
                        .frame(width: 15, height: 15)
                        .foregroundColor(.white)
                }
                Text("Omoikane AI")
                    .font(.hermes.h3)
                    .foregroundColor(.hermes.text)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: HermesSpacing.md) {
                Button(action: { showLogin = true }) {
                    Text("Login")
                        .font(.hermes.bodyMedium)
                        .foregroundColor(.hermes.text)
                }
                .buttonStyle(PlainButtonStyle())
                
                HermesButton(title: "Join Now", style: .secondary, size: .small, action: { showRegister = true })
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
