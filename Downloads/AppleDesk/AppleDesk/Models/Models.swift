import SwiftUI

// MARK: - App Item
struct AppItem: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    var iconAsset: String? = nil
    let color: Color
    var isPinned: Bool = true  // se true, sempre in taskbar

    // App pinnate (sempre in taskbar)
    static let defaults: [AppItem] = [
        AppItem(id: "chrome", name: "Chrome",  icon: "globe",       iconAsset: "chrome_icon", color: .clear),
        AppItem(id: "finder", name: "Finder",  icon: "folder.fill", iconAsset: "finder_icon", color: .clear),
    ]

    // Tutte le app disponibili (per la ricerca nel menu Start)
    static let allApps: [AppItem] = defaults + [
        AppItem(id: "spotify", name: "Spotify", icon: "music.note", iconAsset: "spotify_icon", color: .green, isPinned: false),
    ]
}

// MARK: - Desktop Window
struct DesktopWindow: Identifiable, Codable {
    var id: UUID = UUID()
    let appID: String
    var title: String
    var icon: String
    var iconAsset: String? = nil
    var position: CGPoint = CGPoint(x: 300, y: 200)
    var size: CGSize = CGSize(width: 680, height: 460)
    var isMinimized: Bool = false
    var isMaximized: Bool = false
}

// MARK: - Weather
struct WeatherData {
    var temperature: Double = 0
    var condition: String = "—"
    var symbolName: String = "cloud"
    var city: String = "—"
}