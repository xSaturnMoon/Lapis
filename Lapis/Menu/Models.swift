import SwiftUI

// MARK: - App State
class AppState: ObservableObject {
    @Published var currentTab: SidebarTab = .home
    @Published var selectedVersion: GameVersion? = nil
    @Published var selectedSubVersion: String? = nil
    @Published var selectedLoader: ModLoader = .vanilla
    @Published var installedVersions: [InstalledVersion] = []
    @Published var isLoggedIn: Bool = false {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: "lapis_logged_in") }
    }
    @Published var playerName: String = "" {
        didSet { UserDefaults.standard.set(playerName, forKey: "lapis_player_name") }
    }
    @Published var playerUUID: String = "" {
        didSet { UserDefaults.standard.set(playerUUID, forKey: "lapis_player_uuid") }
    }
    @Published var accessToken: String = "" {
        didSet { UserDefaults.standard.set(accessToken, forKey: "lapis_access_token") }
    }
    @Published var totalPlayTimeMinutes: Int = 0 {
        didSet { UserDefaults.standard.set(totalPlayTimeMinutes, forKey: "lapis_play_time") }
    }
    @Published var memoryAllocation: Int = 2048 {
        didSet { UserDefaults.standard.set(memoryAllocation, forKey: "lapis_memory") }
    }
    
    init() {
        // Restore saved account
        let defaults = UserDefaults.standard
        isLoggedIn = defaults.bool(forKey: "lapis_logged_in")
        playerName = defaults.string(forKey: "lapis_player_name") ?? ""
        playerUUID = defaults.string(forKey: "lapis_player_uuid") ?? ""
        accessToken = defaults.string(forKey: "lapis_access_token") ?? ""
        totalPlayTimeMinutes = defaults.integer(forKey: "lapis_play_time")
        
        let savedMemory = defaults.integer(forKey: "lapis_memory")
        memoryAllocation = savedMemory > 0 ? savedMemory : 2048
    }
    
    /// Load installed versions from disk on startup
    func loadInstalledVersions() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modsRoot = docs.appendingPathComponent("Lapis/mods")
        
        guard let contents = try? fm.contentsOfDirectory(at: modsRoot, includingPropertiesForKeys: nil) else { return }
        
        installedVersions = contents
            .filter { $0.hasDirectoryPath }
            .compactMap { dir -> InstalledVersion? in
                let name = dir.lastPathComponent
                let parts = name.replacingOccurrences(of: "mods-", with: "").split(separator: "-")
                guard parts.count >= 2 else { return nil }
                let ver = String(parts[0])
                let loaderStr = String(parts[1])
                let loader = ModLoader(rawValue: loaderStr.capitalized) ?? .vanilla
                let jars = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?.filter { $0.pathExtension == "jar" } ?? []
                
                return InstalledVersion(
                    versionNumber: ver,
                    loader: loader,
                    modCount: jars.count,
                    folderName: name
                )
            }
    }
}

// MARK: - Lapis Image Helper
func LapisImage(_ name: String) -> Image {
    if let uiImage = UIImage(named: name + ".png") ?? UIImage(named: name) {
        return Image(uiImage: uiImage)
    } else {
        // Fallback
        return Image(systemName: "questionmark.square.dashed")
    }
}

// MARK: - Sidebar Tabs
enum SidebarTab: String, CaseIterable, Identifiable {
    case home
    case settings
    case versions
    case installed
    case reports
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .settings: return "gearshape.fill"
        case .versions: return "square.stack.3d.up.fill"
        case .installed: return "puzzlepiece.fill"
        case .reports: return "scroll.fill"
        }
    }
}

// MARK: - Game Version (from Mojang API)
struct GameVersion: Identifiable, Codable, Equatable {
    let id: String
    let type: String // "release" or "snapshot"
    let url: String
    let releaseTime: String
    
    /// Major version like "1.21"
    var majorVersion: String {
        let parts = id.split(separator: ".")
        if parts.count >= 2 {
            return "\(parts[0]).\(parts[1])"
        }
        return id
    }
    
    var isRelease: Bool {
        type == "release"
    }
}

// MARK: - Mojang Version Manifest
struct MojangVersionManifest: Codable {
    let latest: MojangLatest
    let versions: [GameVersion]
}

struct MojangLatest: Codable {
    let release: String
    let snapshot: String
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
        return rawValue.lowercased()
    }
}

// MARK: - Installed Version (from disk)
struct InstalledVersion: Identifiable, Equatable {
    var id: String { folderName }
    let versionNumber: String
    let loader: ModLoader
    let modCount: Int
    let folderName: String
    
    var displayName: String {
        "\(loader.rawValue) \(versionNumber)"
    }
}

// MARK: - Installed Mod (from disk)
struct InstalledMod: Identifiable {
    let id: String
    let name: String
    let fileName: String
    let fileSize: Int64
    var isEnabled: Bool
}

// MARK: - Modrinth API Models
struct ModrinthSearchResponse: Codable {
    let hits: [ModrinthMod]
    let total_hits: Int
}

struct ModrinthMod: Identifiable, Codable {
    let project_id: String
    let slug: String
    let title: String
    let description: String
    let author: String
    let downloads: Int
    let icon_url: String?
    let categories: [String]
    let date_modified: String
    let latest_version: String?
    
    var id: String { project_id }
    
    var downloadString: String {
        if downloads >= 1_000_000 {
            return String(format: "%.1fM", Double(downloads) / 1_000_000)
        } else if downloads >= 1_000 {
            return String(format: "%.0fK", Double(downloads) / 1_000)
        }
        return "\(downloads)"
    }
}

struct ModrinthVersionFile: Codable {
    let url: String
    let filename: String
    let size: Int
}

struct ModrinthVersion: Codable {
    let id: String
    let version_number: String?
    let files: [ModrinthVersionFile]
    let game_versions: [String]
    let loaders: [String]
}
