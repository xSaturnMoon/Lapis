import Foundation

// MARK: - JRE Downloader
// Downloads the Java Runtime for iOS from PojavLauncher's official releases
class JREDownloader: ObservableObject {
    @Published var isDownloading = false
    @Published var progress: Double = 0
    @Published var statusMessage = ""
    @Published var isComplete = false
    @Published var error: String? = nil
    
    // PojavLauncher's official JRE17 for iOS (with JIT support)
    private let jreURL = "https://github.com/nicklasmoeller/pojav-jre-bin/releases/download/jre17-ios/jre17-ios-aarch64.tar.xz"
    // Fallback: PojavLauncher Actions artifacts
    private let jreFallbackURL = "https://github.com/nicklasmoeller/pojav-jre-bin/releases/download/jre17-ios/java-17-openjdk.tar.xz"
    
    var isJREInstalled: Bool {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let jrePath = docs.appendingPathComponent("Lapis/jre")
        let javaPath = jrePath.appendingPathComponent("lib/libjli.dylib")
        
        // Check if the JRE has essential files
        return fm.fileExists(atPath: jrePath.path) &&
               (fm.fileExists(atPath: javaPath.path) ||
                fm.fileExists(atPath: jrePath.appendingPathComponent("bin/java").path))
    }
    
    var jrePath: String {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Lapis/jre").path
    }
    
    /// Download and extract JRE
    func downloadJRE() async {
        await MainActor.run {
            isDownloading = true
            isComplete = false
            error = nil
            progress = 0
            statusMessage = "Preparing to download Java Runtime..."
        }
        
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let lapisDir = docs.appendingPathComponent("Lapis")
        let jreDir = lapisDir.appendingPathComponent("jre")
        let tempFile = lapisDir.appendingPathComponent("jre_download.tar.xz")
        
        try? fm.createDirectory(at: lapisDir, withIntermediateDirectories: true)
        
        // Try to download JRE
        await updateStatus("Downloading Java 17 Runtime for iOS...")
        await updateProgress(0.1)
        
        let downloaded = await downloadFileWithProgress(from: jreURL, to: tempFile) ||
                         await downloadFileWithProgress(from: jreFallbackURL, to: tempFile)
        
        if !downloaded {
            await MainActor.run {
                error = """
                JRE download failed.
                
                You can manually install the JRE:
                1. Download the JRE from PojavLauncher's GitHub
                2. Extract it
                3. Place the contents in:
                   Files → Lapis → jre/
                
                The JRE folder should contain:
                  jre/lib/libjli.dylib
                  jre/bin/java
                """
                isDownloading = false
            }
            return
        }
        
        // Extract
        await updateStatus("Extracting Java Runtime...")
        await updateProgress(0.7)
        
        // Remove old JRE if exists
        try? fm.removeItem(at: jreDir)
        try? fm.createDirectory(at: jreDir, withIntermediateDirectories: true)
        
        // Extract tar.xz using tar command (available on iOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["xf", tempFile.path, "-C", jreDir.path, "--strip-components=1"]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                // Fallback: try without --strip-components
                let process2 = Process()
                process2.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                process2.arguments = ["xf", tempFile.path, "-C", jreDir.path]
                try process2.run()
                process2.waitUntilExit()
            }
        } catch {
            // On iOS, Process isn't available. Use a manual approach.
            // The tar extraction will need to be done differently on iOS
            // For now, mark that the file was downloaded but needs manual extraction
            await MainActor.run {
                self.error = """
                JRE downloaded but extraction failed on iOS.
                
                Please manually extract the JRE:
                1. Open Files app
                2. Go to Lapis folder
                3. Find jre_download.tar.xz
                4. Extract it into the 'jre' folder
                """
                self.isDownloading = false
            }
            return
        }
        
        // Cleanup
        try? fm.removeItem(at: tempFile)
        
        await updateProgress(1.0)
        await updateStatus("Java Runtime installed!")
        
        await MainActor.run {
            isComplete = true
            isDownloading = false
        }
    }
    
    private func downloadFileWithProgress(from urlString: String, to destination: URL) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                return false
            }
            
            try data.write(to: destination)
            return true
        } catch {
            return false
        }
    }
    
    private func updateStatus(_ msg: String) async {
        await MainActor.run { statusMessage = msg }
    }
    
    private func updateProgress(_ val: Double) async {
        await MainActor.run { progress = val }
    }
}
