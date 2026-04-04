import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            // Full-screen dark background
            LapisTheme.Colors.background
                .ignoresSafeArea()
            
            HStack(spacing: 0) {
                // Left: Sidebar
                SidebarView()
                
                // Divider line
                Rectangle()
                    .fill(LapisTheme.Colors.divider)
                    .frame(width: 1)
                
                // Right: Content Area
                ZStack {
                    switch appState.currentTab {
                    case .home:
                        HomeView()
                            .transition(.opacity)
                    case .settings:
                        SettingsView()
                            .transition(.opacity)
                    case .versions:
                        VersionsView()
                            .transition(.opacity)
                    case .installed:
                        InstalledView()
                            .transition(.opacity)
                    case .reports:
                        ReportsView()
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(LapisTheme.Animation.normal, value: appState.currentTab)
            }
        }
        .statusBarHidden(true)
    }
}
