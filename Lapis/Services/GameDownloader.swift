import Foundation

// MARK: - Game Downloader (REAL — downloads from Mojang servers)
class GameDownloader: ObservableObject {
    @Published var progress: Double = 0
    @Published var statusMessage: String = "Preparing..."
    @Published var currentFile: String = ""
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var isDownloading = false
    @Published var isComplete = false
    @Published var error: String? = nil
    
    private var versionId: String = ""
    private var retryVersion: String = ""
    
    var downloadedSizeString: String {
        let mb = Double(downloadedBytes) / 1_048_576
        let totalMB = Double(totalBytes) / 1_048_576
        return String(format: "%.1f / %.1f MB", mb, totalMB)
    }
    
    /// Check if a version is already downloaded
    func isVersionDownloaded(_ versionId: String) -> Bool {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let versionDir = docs.appendingPathComponent("Lapis/versions/\(versionId)")
        let clientJar = versionDir.appendingPathComponent("\(versionId).jar")
        return fm.fileExists(atPath: clientJar.path)
    }
    
    /// Download all game files for a specific version
    func downloadVersion(_ versionId: String) async {
        self.versionId = versionId
        self.retryVersion = versionId
        
        await MainActor.run {
            isDownloading = true
            isComplete = false
            error = nil
            progress = 0
            statusMessage = "Fetching version info..."
            currentFile = versionId
        }
        
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let versionDir = docs.appendingPathComponent("Lapis/versions/\(versionId)")
        let libDir = docs.appendingPathComponent("Lapis/libraries")
        
        try? fm.createDirectory(at: versionDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: libDir, withIntermediateDirectories: true)
        
        do {
            // Step 1: Get version manifest
            await updateStatus("Fetching version manifest...", file: "version_manifest_v2.json")
            
            let manifestURL = URL(string: "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")!
            let (manifestData, _) = try await URLSession.shared.data(from: manifestURL)
            let manifest = try JSONDecoder().decode(MojangVersionManifest.self, from: manifestData)
            
            guard let versionEntry = manifest.versions.first(where: { $0.id == versionId }) else {
                throw DownloadError.versionNotFound
            }
            
            // Step 2: Get version JSON (contains download URLs)
            await updateStatus("Downloading version metadata...", file: "\(versionId).json")
            await updateProgress(0.05)
            
            let versionURL = URL(string: versionEntry.url)!
            let (versionData, _) = try await URLSession.shared.data(from: versionURL)
            
            // Save version JSON
            try versionData.write(to: versionDir.appendingPathComponent("\(versionId).json"))
            
            guard let versionJSON = try JSONSerialization.jsonObject(with: versionData) as? [String: Any] else {
                throw DownloadError.invalidJSON
            }
            
            // Step 3: Download client.jar
            await updateStatus("Downloading Minecraft \(versionId)...", file: "\(versionId).jar")
            await updateProgress(0.1)
            
            if let downloads = versionJSON["downloads"] as? [String: Any],
               let client = downloads["client"] as? [String: Any],
               let clientURL = client["url"] as? String,
               let clientSize = client["size"] as? Int {
                
                await MainActor.run { totalBytes = Int64(clientSize) }
                
                let clientDest = versionDir.appendingPathComponent("\(versionId).jar")
                if !fm.fileExists(atPath: clientDest.path) {
                    try await downloadFile(from: clientURL, to: clientDest)
                }
            }
            
            await updateProgress(0.4)
            
            // Step 4: Download libraries
            if let libraries = versionJSON["libraries"] as? [[String: Any]] {
                let totalLibs = libraries.count
                
                for (index, lib) in libraries.enumerated() {
                    // Check OS rules — skip libraries not needed for iOS/macOS
                    if let rules = lib["rules"] as? [[String: Any]] {
                        let allowed = checkRules(rules)
                        if !allowed { continue }
                    }
                    
                    if let libDownloads = lib["downloads"] as? [String: Any],
                       let artifact = libDownloads["artifact"] as? [String: Any],
                       let pathStr = artifact["path"] as? String,
                       let urlStr = artifact["url"] as? String {
                        
                        let libPath = libDir.appendingPathComponent(pathStr)
                        let libName = URL(string: pathStr)?.lastPathComponent ?? pathStr
                        
                        await updateStatus("Downloading libraries...", file: libName)
                        
                        if !fm.fileExists(atPath: libPath.path) {
                            try? fm.createDirectory(at: libPath.deletingLastPathComponent(), withIntermediateDirectories: true)
                            try await downloadFile(from: urlStr, to: libPath)
                        }
                        
                        let libProgress = 0.4 + (0.5 * Double(index + 1) / Double(totalLibs))
                        await updateProgress(libProgress)
                    }
                }
            }
            
            // Step 5: Download asset index
            await updateStatus("Downloading assets index...", file: "assets")
            await updateProgress(0.9)
            
            if let assetIndex = versionJSON["assetIndex"] as? [String: Any],
               let assetURL = assetIndex["url"] as? String,
               let assetId = assetIndex["id"] as? String {
                
                let assetsDir = docs.appendingPathComponent("Lapis/assets/indexes")
                try? fm.createDirectory(at: assetsDir, withIntermediateDirectories: true)
                
                let assetDest = assetsDir.appendingPathComponent("\(assetId).json")
                if !fm.fileExists(atPath: assetDest.path) {
                    try await downloadFile(from: assetURL, to: assetDest)
                }
            }
            
            await updateProgress(1.0)
            await updateStatus("Download complete!", file: "")
            
            await MainActor.run {
                isComplete = true
                isDownloading = false
            }
            
        } catch {
            await MainActor.run {
                self.error = "Download failed: \(error.localizedDescription)"
                self.isDownloading = false
            }
        }
    }
    
    /// Download a single file
    private func downloadFile(from urlString: String, to destination: URL) async throws {
        guard let url = URL(string: urlString) else { throw DownloadError.invalidURL }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw DownloadError.httpError(httpResponse.statusCode)
        }
        
        try data.write(to: destination)
        
        await MainActor.run {
            downloadedBytes += Int64(data.count)
        }
    }
    
    /// Check library rules (for OS compatibility)
    private func checkRules(_ rules: [[String: Any]]) -> Bool {
        var allowed = false
        for rule in rules {
            let action = rule["action"] as? String ?? "allow"
            if let os = rule["os"] as? [String: Any], let osName = os["name"] as? String {
                if osName == "osx" || osName == "linux" {
                    allowed = action == "allow"
                }
            } else {
                allowed = action == "allow"
            }
        }
        return allowed
    }
    
    func retry() {
        Task {
            await downloadVersion(retryVersion)
        }
    }
    
    private func updateStatus(_ message: String, file: String) async {
        await MainActor.run {
            statusMessage = message
            currentFile = file
        }
    }
    
    private func updateProgress(_ value: Double) async {
        await MainActor.run { progress = value }
    }
}

enum DownloadError: LocalizedError {
    case versionNotFound, invalidJSON, invalidURL, httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .versionNotFound: return "Version not found in manifest"
        case .invalidJSON: return "Invalid version JSON"
        case .invalidURL: return "Invalid download URL"
        case .httpError(let code): return "HTTP error: \(code)"
        }
    }
}
