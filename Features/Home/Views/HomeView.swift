import SwiftUI

struct HomeView: View {
    @State private var showLogin = false
    @State private var showRegister = false
    
    var body: some View {
        VStack(spacing: 0) {
            HomeNavigationBar(showLogin: $showLogin, showRegister: $showRegister)
            
            ScrollView {
                VStack(spacing: HermesSpacing.xxl) {
                    
                    // MARK: - Hero Section
                    VStack(spacing: HermesSpacing.xl) {
                        VStack(spacing: HermesSpacing.xl) {
                            Text("Experience the Future")
                                .font(.hermes.h1)
                            Text("of Local AI.")
                                .font(.hermes.h1)
                                .foregroundColor(.hermes.accent)
                        }
                        .multilineTextAlignment(.center)
                        .foregroundColor(.hermes.text)
                        
                        Text("Interact with powerful models locally using Ollama, or connect directly to global giants like DeepSeek. One interface, infinite possibilities.")
                            .font(.hermes.body)
                            .foregroundColor(.hermes.muted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: 500)
                        
                        // CTA Buttons
                        HStack(spacing: HermesSpacing.md) {
                            HermesButton(title: "Get Started", icon: "bolt", action: { showRegister = true })
                                .fixedSize()
                            
                            HermesButton(title: "Learn More", icon: "info.circle", style: .secondary, action: {})
                                .fixedSize()
                        }
                    }
                    .padding(.top, HermesSpacing.xxxxl)
                    
                    // MARK: - Features Grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: HermesSpacing.lg)], spacing: HermesSpacing.lg) {
                        FeatureCard(
                            icon: "hare",
                            iconColor: .blue,
                            title: "Fast Performance",
                            description: "Optimized to run smoothly on local machines with minimal latency."
                        )
                        FeatureCard(
                            icon: "checkmark.shield",
                            iconColor: .purple,
                            title: "Data Privacy",
                            description: "Your local data stays on your machine when using Ollama integration."
                        )
                        FeatureCard(
                            icon: "cloud",
                            iconColor: .green,
                            title: "Cloud Ready",
                            description: "Seamless switching between local models and premium Cloud APIs."
                        )
                    }
                    
                    // MARK: - Stats Grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: HermesSpacing.md)], spacing: HermesSpacing.md) {
                        StatCard(stat: "100%", label: "Private & Secure")
                        StatCard(stat: "Fast", label: "Local Processing")
                        StatCard(stat: "Multi", label: "AI Models")
                        StatCard(stat: "Free", label: "Open Source")
                    }
                }
                .padding(.horizontal, HermesSpacing.xl)
                .padding(.bottom, HermesSpacing.xl)
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.hermes.bg.ignoresSafeArea())
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
        .navigationDestination(isPresented: $showLogin) {
            LoginView()
        }
        .navigationDestination(isPresented: $showRegister) {
            RegisterView()
        }
    }
}

// MARK: - Feature Card
struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HermesCard {
            HStack(alignment: .top, spacing: HermesSpacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: HermesRadius.md)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: HermesSpacing.xs) {
                    Text(title)
                        .font(.hermes.h3)
                        .foregroundColor(.hermes.text)
                    Text(description)
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.muted)
                        .lineSpacing(2)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let stat: String
    let label: String
    
    var body: some View {
        HermesCard {
            VStack(spacing: HermesSpacing.xs) {
                Text(stat)
                    .font(.hermes.h1)
                    .foregroundColor(.hermes.accent)
                Text(label)
                    .font(.hermes.caption)
                    .foregroundColor(.hermes.muted)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AppState())
    }
}
