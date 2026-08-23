import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isOllamaEnabled = true
    @State private var isOllamaCloudEnabled = false
    @State private var isDeepSeekEnabled = false
    @State private var isAnalyzing = false
    @State private var stats: DashboardStats? = nil
    @State private var activityData: [ActivityItem] = []
    @State private var isLoadingStats = false
    
    private var statsColumns: [GridItem] {
        let count = horizontalSizeClass == .compact ? 2 : 4
        return Array(repeating: GridItem(.flexible(), spacing: HermesSpacing.lg), count: count)
    }
    
    private var chartsColumns: [GridItem] {
        let count = horizontalSizeClass == .compact ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: HermesSpacing.lg), count: count)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HermesSpacing.xxl) {
                
                // Header
                HermesSectionHeader(
                    title: "Dashboard",
                    subtitle: "Manage your AI providers and monitor analytics."
                )
                .padding(.top, HermesSpacing.xxl)
                
                // AI Providers
                HermesCard(padding: HermesSpacing.xl) {
                    VStack(alignment: .leading, spacing: HermesSpacing.lg) {
                        VStack(alignment: .leading, spacing: HermesSpacing.xs) {
                            Text("AI Providers")
                                .font(.hermes.h3)
                                .foregroundColor(.hermes.text)
                            Text("Toggle the provider you want to use for chat sessions.")
                                .font(.hermes.caption)
                                .foregroundColor(.hermes.muted)
                        }
                        
                        VStack(spacing: HermesSpacing.md) {
                            HermesToggleRow(title: "Ollama (Ornith)", subtitle: "Local", icon: "cpu", iconColor: .blue, isOn: $isOllamaEnabled)
                                .onChange(of: isOllamaEnabled) { toggleProvider("ollama", enabled: isOllamaEnabled) }
                            HermesToggleRow(title: "Ollama (Gemma4 31B Cloud)", subtitle: "Cloud", icon: "server.rack", iconColor: .cyan, isOn: $isOllamaCloudEnabled)
                                .onChange(of: isOllamaCloudEnabled) { toggleProvider("ollama_cloud", enabled: isOllamaCloudEnabled) }
                            HermesToggleRow(title: "DeepSeek API", subtitle: "Premium", icon: "cloud", iconColor: .purple, isOn: $isDeepSeekEnabled)
                                .onChange(of: isDeepSeekEnabled) { toggleProvider("deepseek", enabled: isDeepSeekEnabled) }
                        }
                    }
                }
                
                // Stats Grid
                LazyVGrid(columns: statsColumns, spacing: HermesSpacing.lg) {
                    DashboardStatCard(title: "Avg. Memory", value: String(format: "%.0f", stats?.avgMemoryKb ?? 32450), unit: "KB", icon: "internaldrive", iconColor: .hermes.accent)
                    DashboardStatCard(title: "Bot Tokens/Msg", value: "\(stats?.avgBotTokens ?? 452)", unit: "tk", icon: "cpu", iconColor: .blue)
                    DashboardStatCard(title: "User Tokens/Msg", value: "\(stats?.avgUserTokens ?? 128)", unit: "tk", icon: "person", iconColor: .hermes.accent)
                    DashboardStatCard(title: "Success Rate", value: "\(stats?.successRate ?? 98)", unit: "%", icon: "checkmark.circle", iconColor: .hermes.success)
                }
                
                // Charts Row
                LazyVGrid(columns: chartsColumns, spacing: HermesSpacing.lg) {
                    ChartCard(title: "Satisfaction") {
                        Chart {
                            SectorMark(angle: .value("Count", 85), innerRadius: .ratio(0.65), angularInset: 2)
                                .foregroundStyle(Color.hermes.success)
                            SectorMark(angle: .value("Count", 10), innerRadius: .ratio(0.65), angularInset: 2)
                                .foregroundStyle(Color.hermes.warning)
                            SectorMark(angle: .value("Count", 5), innerRadius: .ratio(0.65), angularInset: 2)
                                .foregroundStyle(Color.hermes.danger)
                        }
                        .frame(height: 140)
                    }
                    
                    ChartCard(title: "Content Dynamics") {
                        Chart {
                            BarMark(x: .value("Topic", "Code"), y: .value("Score", 80))
                            BarMark(x: .value("Topic", "Logic"), y: .value("Score", 65))
                            BarMark(x: .value("Topic", "General"), y: .value("Score", 90))
                        }
                        .foregroundStyle(Color.hermes.accent.gradient)
                        .frame(height: 140)
                    }
                }
                
                // Activity Chart
                ChartCard(title: "Chat Activity (Last 7 Days)") {
                    Chart(activityData) { item in
                        BarMark(
                            x: .value("Day", item.day),
                            y: .value("Messages", item.count)
                        )
                        .foregroundStyle(Color.hermes.accent)
                        .cornerRadius(HermesRadius.sm)
                    }
                    .frame(height: 180)
                }
                
                // Knowledge Graph (real data)
                KnowledgeGraphView()
                
                // User Behavior Analysis
                HermesCard(padding: HermesSpacing.xl) {
                    VStack(alignment: .leading, spacing: HermesSpacing.lg) {
                        HStack(spacing: HermesSpacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: HermesRadius.md)
                                    .fill(Color.orange.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "wand.and.sparkles")
                                    .foregroundColor(.orange)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("User Behavior Analysis")
                                    .font(.hermes.h3)
                                    .foregroundColor(.hermes.text)
                                Text("AI-powered profiling based on history.")
                                    .font(.hermes.caption)
                                    .foregroundColor(.hermes.muted)
                            }
                        }
                        
                        HermesButton(
                            title: isAnalyzing ? "Processing..." : "Analyze User Data",
                            icon: isAnalyzing ? "arrow.triangle.2.circlepath" : "sparkles",
                            isLoading: isAnalyzing,
                            action: {
                                withAnimation { isAnalyzing.toggle() }
                                if isAnalyzing {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation { isAnalyzing = false }
                                    }
                                }
                            }
                        )
                        
                        // Insight Card
                        HStack(alignment: .top, spacing: HermesSpacing.md) {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.hermes.accent)
                                .padding(HermesSpacing.sm)
                                .background(Color.hermes.accent.opacity(0.1))
                                .cornerRadius(HermesRadius.sm)
                            
                            VStack(alignment: .leading, spacing: HermesSpacing.xs) {
                                Text("Optimization Insight")
                                    .font(.hermes.bodyMedium)
                                    .foregroundColor(.hermes.text)
                                Text("Consider updating your system prompt to optimize for your most used topics.")
                                    .font(.hermes.caption)
                                    .foregroundColor(.hermes.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(HermesSpacing.md)
                        .background(Color.hermes.accent.opacity(0.05))
                        .cornerRadius(HermesRadius.md)
                    }
                }
                .padding(.bottom, HermesSpacing.xxxxl)
            }
            .padding(.horizontal, HermesSpacing.xl)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(Color.hermes.bg.ignoresSafeArea())
        .task { await fetchDashboardData() }
    }
    
    private func fetchDashboardData() async {
        isLoadingStats = true
        do {
            stats = try await APIClient.shared.fetchDashboardStats()
            let points = try await APIClient.shared.fetchActivity()
            activityData = points.map { ActivityItem(day: $0.day, count: $0.count) }
            // Sync provider toggles
            if let p = stats?.providers {
                isOllamaEnabled = p.ollamaEnabled ?? true
                isOllamaCloudEnabled = p.ollamaCloudEnabled ?? false
                isDeepSeekEnabled = p.deepseekEnabled ?? false
            }
        } catch {
            // Keep mock data on failure
        }
        isLoadingStats = false
    }
    
    private func toggleProvider(_ provider: String, enabled: Bool) {
        Task {
            try? await APIClient.shared.updateProviderMode(provider: provider, enabled: enabled)
        }
    }
}

struct ActivityItem: Identifiable {
    let id = UUID()
    let day: String
    let count: Int
}

// MARK: - Subcomponents

struct DashboardStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HermesCard {
            VStack(alignment: .leading, spacing: HermesSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: HermesRadius.sm)
                        .fill(iconColor.opacity(0.1))
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                }
                .frame(width: 32, height: 32) // Ikon tetap 32×32
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.hermes.badge)
                        .foregroundColor(.hermes.muted)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(value)
                            .font(.hermes.h2)
                            .foregroundColor(.hermes.text)
                        if !unit.isEmpty {
                            Text(unit)
                                .font(.hermes.caption)
                                .foregroundColor(.hermes.muted)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MiniStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: HermesSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: HermesRadius.sm)
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.hermes.bodyMedium)
                    .foregroundColor(.hermes.text)
                Text(title)
                    .font(.hermes.badge)
                    .foregroundColor(.hermes.muted)
            }
            Spacer()
        }
        .padding(HermesSpacing.md)
        .background(color.opacity(0.04))
        .cornerRadius(HermesRadius.md)
    }
}

struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HermesCard {
            VStack(alignment: .leading, spacing: HermesSpacing.lg) {
                Text(title)
                    .font(.hermes.h3)
                    .foregroundColor(.hermes.text)
                content()
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
}
