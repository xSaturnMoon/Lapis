import Foundation

// MARK: - Modrinth API Service (REAL API)
class ModrinthService: ObservableObject {
    @Published var searchResults: [ModrinthMod] = []
    @Published var isLoading = false
    @Published var error: String? = nil
    
    private let baseURL = "https://api.modrinth.com/v2"
    
    /// Search mods on Modrinth (REAL API call)
    func searchMods(query: String, gameVersion: String, loader: ModLoader) async {
        await MainActor.run { isLoading = true; error = nil }
        
        var urlString = "\(baseURL)/search?limit=20"
        
        if !query.isEmpty {
            urlString += "&query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        }
        
        // Build facets for version and loader filtering
        var facets: [[String]] = [["project_type:mod"]]
        facets.append(["versions:\(gameVersion)"])
        if loader != .vanilla {
            facets.append(["categories:\(loader.rawValue.lowercased())"])
        }
        
        if let facetsJSON = try? JSONEncoder().encode(facets),
           let facetsString = String(data: facetsJSON, encoding: .utf8) {
            urlString += "&facets=\(facetsString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("xSaturnMoon/Lapis/1.0.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(ModrinthSearchResponse.self, from: data)
            
            await MainActor.run {
                self.searchResults = response.hits
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = "Search failed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Get download URL for a specific mod version
    func getModVersions(projectId: String, gameVersion: String, loader: ModLoader) async -> [ModrinthVersion] {
        let loaderParam = loader == .vanilla ? "" : "&loaders=[\"\(loader.rawValue.lowercased())\"]"
        let urlString = "\(baseURL)/project/\(projectId)/version?game_versions=[\"\(gameVersion)\"]\(loaderParam)"
        
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString) else { return [] }
        
        var request = URLRequest(url: url)
        request.setValue("xSaturnMoon/Lapis/1.0.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode([ModrinthVersion].self, from: data)
        } catch {
            return []
        }
    }
    
    /// Download a mod file to the correct version-specific folder
    func downloadMod(fileURL: String, fileName: String, gameVersion: String, loader: ModLoader) async -> Bool {
        guard let url = URL(string: fileURL) else { return false }
        
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modsFolderName = "mods-\(gameVersion)-\(loader.rawValue.lowercased())"
        let modsDir = docs.appendingPathComponent("Lapis/mods/\(modsFolderName)")
        
        // Create directory if needed
        try? fm.createDirectory(at: modsDir, withIntermediateDirectories: true)
        
        let destination = modsDir.appendingPathComponent(fileName)
        
        // Don't re-download if already exists
        if fm.fileExists(atPath: destination.path) { return true }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            try data.write(to: destination)
            return true
        } catch {
            return false
        }
    }
}
