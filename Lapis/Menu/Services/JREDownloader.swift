import Foundation

// MARK: - JRE Downloader
class JREDownloader: ObservableObject {
    @Published var isDownloading = false
    @Published var progress: Double = 0
    @Published var statusMessage = ""
    @Published var isComplete = false
    @Published var error: String? = nil
    
    var isJREInstalled: Bool {
        let fm = FileManager.default
        
        // Check Documents/Lapis/jre
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docsJRE = docs.appendingPathComponent("Lapis/jre")
        if fm.fileExists(atPath: docsJRE.path) { return true }
        
        // Check app bundle
        let bundleJRE = Bundle.main.bundleURL.appendingPathComponent("jre")
        if fm.fileExists(atPath: bundleJRE.path) { return true }
        
        return false
    }
}
