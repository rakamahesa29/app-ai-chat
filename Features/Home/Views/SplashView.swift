import SwiftUI

struct SplashView: View {
    @EnvironmentObject var appState: AppState
    @State private var opacity = 0.0
    @State private var scale = 0.85
    
    var body: some View {
        ZStack {
            Color.hermes.bg.ignoresSafeArea()
            
            VStack(spacing: HermesSpacing.xl) {
                ZStack {
                    RoundedRectangle(cornerRadius: HermesRadius.xl)
                        .fill(Color.hermes.accent)
                        .frame(width: 80, height: 80)
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundColor(.white)
                }
                .scaleEffect(scale)
                
                VStack(spacing: HermesSpacing.sm) {
                    Text("Omoikane AI")
                        .font(.hermes.h1)
                        .foregroundColor(.hermes.text)
                    Text("v0.0.1 beta")
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.muted)
                    Text("Experience the Future of Local AI")
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.muted)
                }
                .opacity(opacity)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .hermes.accent))
                    .scaleEffect(0.9)
                    .padding(.top, HermesSpacing.lg)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                appState.completeSplash()
            }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(AppState())
}
