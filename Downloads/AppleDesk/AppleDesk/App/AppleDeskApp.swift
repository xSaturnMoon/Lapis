import SwiftUI

@main
struct AppleDeskApp: App {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var desktopVM = DesktopViewModel()
    @StateObject private var weatherService = WeatherService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authVM)
                .environmentObject(desktopVM)
                .environmentObject(weatherService)
                .preferredColorScheme(.dark)
        }
    }
}
