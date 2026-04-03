import SwiftUI

// MARK: - App State
class AppState: ObservableObject {
    @Published var currentTab: SidebarTab = .home
    @Published var selectedVersion: GameVersion? = nil
    @Published var selectedSubVersion: String? = nil
    @Published var selectedLoader: ModLoader = .vanilla
    @Published var installedVersions: [InstalledVersion] = []
    @Published var isLoggedIn: Bool = false
    @Published var playerName: String = ""
    @Published var playerUUID: String = ""
    @Published var accessToken: String = ""
    @Published var totalPlayTimeMinutes: Int = 0
    
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
                // Parse folder name like "mods-1.21.1-vanilla"
                let parts = name.replacingOccurrences(of: "mods-", with: "").split(separator: "-")
                guard parts.count >= 2 else { return nil }
                let ver = String(parts[0])
                let loaderStr = String(parts[1])
                let loader = ModLoader(rawValue: loaderStr.capitalized) ?? .vanilla
                
                // Count .jar files inside
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
        switch self {
        case .vanilla: return "cube.fill"
        case .fabric: return "wind"
        case .forge: return "hammer.fill"
        case .neoforge: return "flame.fill"
        case .quilt: return "square.grid.3x3.fill"
        }
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
    let files: [ModrinthVersionFile]
    let game_versions: [String]
    let loaders: [String]
}
