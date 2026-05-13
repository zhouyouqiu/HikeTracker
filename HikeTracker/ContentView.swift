import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                RecordingView()
                    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem {
                Label("记录", systemImage: "location.circle")
            }
            .tag(0)

            NavigationStack {
                HistoryListView()
            }
            .tabItem {
                Label("历史", systemImage: "clock.arrow.circlepath")
            }
            .tag(1)

            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("统计", systemImage: "chart.bar")
            }
            .tag(2)
        }
    }
}
