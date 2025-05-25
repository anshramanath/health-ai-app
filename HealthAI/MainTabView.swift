import SwiftUI

// tab routing like pages in Next.js and react router
struct MainTabView: View {
    var body: some View {
        TabView {
            AIChatView()
                .tabItem {
                    Label("Chat", systemImage: "message")
                }

            HealthChartsView()
                .tabItem {
                    Label("Charts", systemImage: "chart.xyaxis.line")
                }
        }
    }
}

#Preview {
    MainTabView()
}
