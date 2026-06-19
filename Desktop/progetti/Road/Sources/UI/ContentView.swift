import SwiftUI

struct ContentView: View {
    @StateObject var appManager = AppManager.shared
    @StateObject var auth = AuthManager.shared
    @State private var showingAuth = false

    var body: some View {
        ZStack {
            TabView(selection: $appManager.selectedTab) {
                MapView()
                    .tabItem { Label("Map", systemImage: "map") }
                    .tag(0)

                BadgesView()
                    .tabItem { Label("Badges", systemImage: "star.circle") }
                    .tag(1)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
                    .tag(2)
            }
            .tint(.blue)
        }
        .fullScreenCover(isPresented: $showingAuth) {
            AuthView(isPresented: $showingAuth)
                .interactiveDismissDisabled()
        }
        .onAppear {
            if auth.currentUser == nil {
                showingAuth = true
            }
        }
        .onChange(of: auth.currentUser?.id) { _, newId in
            if newId == nil {
                showingAuth = true
            } else {
                showingAuth = false
            }
        }
    }
}
