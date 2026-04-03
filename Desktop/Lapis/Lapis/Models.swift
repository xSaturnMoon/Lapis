import SwiftUI

// MARK: - App State
class AppState: ObservableObject {
    @Published var currentTab: SidebarTab = .home
    @Published var selectedVersion: GameVersion? = nil
    @Published var installedVersions: [GameVersion] = []
    @Published var isLoggedIn: Bool = false
    @Published var playerName: String = ""
    @Published var playerUUID: String = ""
    @Published var totalPlayTimeMinutes: Int = 0
}

// MARK: - Sidebar Tabs
enum SidebarTab: String, CaseIterable, Identifiable {
    case home
    case settings
    case versions
    case installed
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .settings: return "gearshape.fill"
        case .versions: return "square.stack.3d.up.fill"
        case .installed: return "puzzlepiece.fill"
        }
    }
}

// MARK: - Game Version
struct GameVersion: Identifiable, Codable, Equatable {
    let id: String
    let versionNumber: String
    let loader: ModLoader
    let releaseDate: String
    let description: String
    var isInstalled: Bool = false
    
    var displayName: String {
        "\(loader.rawValue.uppercased()) \(versionNumber)"
    }
    
    /// The isolated mod folder name for this version
    var modsFolderName: String {
        "mods-\(versionNumber)-\(loader.rawValue.lowercased())"
    }
}

// MARK: - Mod Loader
enum ModLoader: String, CaseIterable, Codable, Identifiable {
    case vanilla = "Vanilla"
    case fabric = "Fabric"
    case forge = "Forge"
    case neoforge = "NeoForge"
    case quilt = "Quilt"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .vanilla: return "cube.fill"
        case .fabric: return "wind"
        case .forge: return "hammer.fill"
        case .neoforge: return "flame.fill"
        case .quilt: return "square.grid.3x3.fill"
        }
    }
}

// MARK: - Installed Mod
struct InstalledMod: Identifiable, Codable {
    let id: String
    let name: String
    let author: String
    let version: String
    let fileName: String
    let iconURL: String?
    var isEnabled: Bool
}

// MARK: - Modrinth Search Result
struct ModrinthMod: Identifiable, Codable {
    let id: String
    let slug: String
    let title: String
    let description: String
    let author: String
    let downloads: Int
    let iconUrl: String?
    let categories: [String]
    let loaders: [String]
    let dateModified: String
    var isInstalled: Bool = false
}
