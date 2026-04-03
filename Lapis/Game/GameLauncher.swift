import Foundation

// MARK: - Game Launcher
class GameLauncher: ObservableObject {
    @Published var isLaunching = false
    @Published var launchStatus: String = ""
    @Published var launchError: String? = nil
    @Published var needsJRE = false
    
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    /// Check if JRE is installed (checks bundle and Documents)
    var isJREInstalled: Bool {
        let fm = FileManager.default
        // Check bundle first
        let bundleJRE = Bundle.main.bundleURL.appendingPathComponent("jre").path
        if fm.fileExists(atPath: bundleJRE) { return true }
        // Check Documents
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docsJRE = docs.appendingPathComponent("Lapis/jre").path
        return fm.fileExists(atPath: docsJRE)
    }
    
    /// Launch Minecraft
    func launchGame(versionId: String, loader: ModLoader, inputMode: InputMode) {
        isLaunching = true
        launchError = nil
        
        // Check JRE
        if !isJREInstalled {
            launchError = "Java Runtime (JRE) not found.\n\nYou need to install a JRE for iOS to run Minecraft.\n\nPlace the JRE folder in:\nFiles → Lapis → jre/"
            needsJRE = true
            isLaunching = false
            return
        }
        
        launchStatus = "Preparing game..."
        
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let lapisRoot = docs.appendingPathComponent("Lapis")
        let versionDir = lapisRoot.appendingPathComponent("versions/\(versionId)")
        let libDir = lapisRoot.appendingPathComponent("libraries")
        let gameDir = lapisRoot.appendingPathComponent("game")
        let modsFolderName = "mods-\(versionId)-\(loader.rawValue.lowercased())"
        let modsDir = lapisRoot.appendingPathComponent("mods/\(modsFolderName)")
        
        try? fm.createDirectory(at: gameDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: modsDir, withIntermediateDirectories: true)
        
        // Check client.jar exists
        let clientJar = versionDir.appendingPathComponent("\(versionId).jar")
        if !fm.fileExists(atPath: clientJar.path) {
            launchError = "Game files not downloaded.\nClient jar not found at:\n\(clientJar.path)"
            isLaunching = false
            return
        }
        
        launchStatus = "Building classpath..."
        let classpath = buildClasspath(versionDir: versionDir, libDir: libDir, versionId: versionId)
        
        launchStatus = "Preparing JVM arguments..."
        let jvmArgs = buildJVMArguments(
            versionId: versionId,
            gameDir: gameDir.path,
            modsDir: modsDir.path,
            assetsDir: lapisRoot.appendingPathComponent("assets").path,
            loader: loader,
            classpath: classpath
        )
        
        let gameArgs = buildGameArguments(
            versionId: versionId,
            gameDir: gameDir.path,
            assetsDir: lapisRoot.appendingPathComponent("assets").path,
            accessToken: appState.accessToken,
            playerName: appState.playerName,
            playerUUID: appState.playerUUID
        )
        
        UserDefaults.standard.set(inputMode == .touch ? "touch" : "keyboard", forKey: "lapis_input_mode")
        
        launchStatus = "Starting Minecraft..."
        
        // Launch on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let allArgs = jvmArgs + ["net.minecraft.client.main.Main"] + gameArgs
            let result = PojavBridge.launchJVM(withArgs: allArgs)
            
            DispatchQueue.main.async {
                if result != 0 {
                    self?.launchError = "Minecraft exited with code \(result)\n\nPossible causes:\n• JRE incompatible with iOS\n• Missing libraries\n• JIT not enabled"
                }
                self?.isLaunching = false
            }
        }
    }
    
    private func buildClasspath(versionDir: URL, libDir: URL, versionId: String) -> String {
        var paths: [String] = []
        
        let clientJar = versionDir.appendingPathComponent("\(versionId).jar")
        if FileManager.default.fileExists(atPath: clientJar.path) {
            paths.append(clientJar.path)
        }
        
        if let enumerator = FileManager.default.enumerator(at: libDir, includingPropertiesForKeys: nil) {
            while let file = enumerator.nextObject() as? URL {
                if file.pathExtension == "jar" {
                    paths.append(file.path)
                }
            }
        }
        
        return paths.joined(separator: ":")
    }
    
    private func buildJVMArguments(versionId: String, gameDir: String, modsDir: String, assetsDir: String, loader: ModLoader, classpath: String) -> [String] {
        let ramMB = UserDefaults.standard.integer(forKey: "lapis_ram") > 0
            ? UserDefaults.standard.integer(forKey: "lapis_ram")
            : 1024
        
        var args: [String] = [
            "-Xmx\(ramMB)M",
            "-Xms\(ramMB / 2)M",
            "-XX:+UseG1GC",
            "-XX:+ParallelRefProcEnabled",
            "-XX:MaxGCPauseMillis=200",
            "-Dfile.encoding=UTF-8",
            "-Djava.io.tmpdir=\(NSTemporaryDirectory())",
            "-Dos.name=iOS",
            "-cp", classpath,
        ]
        
        switch loader {
        case .fabric:
            args.append("-Dfabric.modsDir=\(modsDir)")
            args.append("-Dfabric.gameDir=\(gameDir)")
        case .forge, .neoforge:
            args.append("-Dfml.modsDir=\(modsDir)")
        case .quilt:
            args.append("-Dloader.modsDir=\(modsDir)")
        case .vanilla:
            break
        }
        
        return args
    }
    
    private func buildGameArguments(versionId: String, gameDir: String, assetsDir: String, accessToken: String, playerName: String, playerUUID: String) -> [String] {
        return [
            "--username", playerName,
            "--version", versionId,
            "--gameDir", gameDir,
            "--assetsDir", assetsDir,
            "--assetIndex", versionId,
            "--uuid", playerUUID,
            "--accessToken", accessToken,
            "--userType", "msa",
            "--versionType", "Lapis"
        ]
    }
}
