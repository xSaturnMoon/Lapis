import Foundation

// MARK: - Mojang Version Service (REAL API)
class MojangService: ObservableObject {
    @Published var allVersions: [GameVersion] = []
    @Published var majorVersions: [String] = []  // ["1.21", "1.20", "1.19", ...]
    @Published var isLoading = false
    @Published var error: String? = nil
    
    private let manifestURL = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
    
    /// Fetch ALL versions from Mojang's real API
    func fetchVersions() async {
        await MainActor.run { isLoading = true; error = nil }
        
        guard let url = URL(string: manifestURL) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let manifest = try JSONDecoder().decode(MojangVersionManifest.self, from: data)
            
            // Only keep releases (not snapshots)
            let releases = manifest.versions.filter { $0.isRelease }
            
            // Extract unique major versions in order
            var seen = Set<String>()
            var majors: [String] = []
            for v in releases {
                if !seen.contains(v.majorVersion) {
                    seen.insert(v.majorVersion)
                    majors.append(v.majorVersion)
                }
            }
            
            await MainActor.run {
                self.allVersions = releases
                self.majorVersions = majors
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load versions: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Get all sub-versions for a major version (e.g. "1.21" -> ["1.21.4", "1.21.3", "1.21.2", "1.21.1", "1.21"])
    func subVersions(for major: String) -> [GameVersion] {
        allVersions.filter { $0.majorVersion == major }
    }
}
