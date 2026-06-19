import SwiftUI

@main
struct RoadApp: App {
    @AppStorage("theme") private var theme: String = "Sistema"

    var colorScheme: ColorScheme? {
        switch theme {
        case "Chiaro": return .light
        case "Scuro": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
        }
    }
}
