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
        let bundleJRE = Bundle.main.bundleURL.appendingPathComponent("jre").path
        if fm.fileExists(atPath: bundleJRE) { return true }
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docsJRE = docs.appendingPathComponent("Lapis/jre").path
        return fm.fileExists(atPath: docsJRE)
    }
    
    /// Get the JRE path that actually exists
    private var resolvedJREPath: String? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docsJRE = docs.appendingPathComponent("Lapis/jre")
        if fm.fileExists(atPath: docsJRE.path) { return docsJRE.path }
        let bundleJRE = Bundle.main.bundleURL.appendingPathComponent("jre")
        if fm.fileExists(atPath: bundleJRE.path) { return bundleJRE.path }
        return nil
    }
    
    /// Launch Minecraft
    func launchGame(versionId: String, loader: ModLoader, inputMode: InputMode) {
        isLaunching = true
        launchError = nil
        
        // Check JRE
        guard let jrePath = resolvedJREPath else {
            launchError = "Java Runtime (JRE) not found.\n\nPlace the JRE in:\nFiles → Lapis → jre/"
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
        
        // Check client.jar
        let clientJar = versionDir.appendingPathComponent("\(versionId).jar")
        if !fm.fileExists(atPath: clientJar.path) {
            launchError = "Game files not downloaded yet.\nPlease wait for the download to complete."
            isLaunching = false
            return
        }
        
        // Check libjli.dylib exists before trying dlopen
        let jliPath = (jrePath as NSString).appendingPathComponent("lib/libjli.dylib")
        if !fm.fileExists(atPath: jliPath) {
            // Try alternative paths
            let altJli = (jrePath as NSString).appendingPathComponent("lib/jli/libjli.dylib")
            if !fm.fileExists(atPath: altJli) {
                launchError = "JRE is incomplete.\n\nlibjli.dylib not found in:\n\(jrePath)/lib/\n\nPlease re-install the JRE."
                isLaunching = false
                return
            }
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
        
        // Set JAVA_HOME before launching
        PojavBridge.setJavaHome(jrePath)
        
        launchStatus = "Starting Minecraft..."
        
        // Launch on background thread with crash protection
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let allArgs = jvmArgs + ["net.minecraft.client.main.Main"] + gameArgs
            
            // Log what we're about to do
            NSLog("[Lapis] JAVA_HOME: %@", jrePath)
            NSLog("[Lapis] JLI path: %@", jliPath)
            NSLog("[Lapis] Classpath entries: %d", classpath.split(separator: ":").count)
            NSLog("[Lapis] Total args: %d", allArgs.count)
            for (i, arg) in allArgs.enumerated() {
                NSLog("[Lapis]   arg[%d]: %@", i, arg)
            }
            
            // Try to load the JRE library first (safe check)
            let handle = dlopen(jliPath, RTLD_LAZY)
            if handle == nil {
                let err = String(cString: dlerror())
                NSLog("[Lapis] ERROR: Cannot load JRE: %@", err)
                DispatchQueue.main.async {
                    self?.launchError = "Cannot load Java Runtime.\n\nError: \(err)\n\nThis usually means:\n• JIT is not enabled (use StikDebug/TrollStore)\n• The JRE is not properly signed\n• The app needs to be installed via TrollStore"
                    self?.isLaunching = false
                }
                return
            }
            dlclose(handle)
            
            // Actually launch (if dlopen worked, this should too)
            let result = PojavBridge.launchJVM(withArgs: allArgs)
            
            DispatchQueue.main.async {
                if result != 0 {
                    self?.launchError = "Minecraft exited with code \(result)\n\nPossible causes:\n• JRE incompatible\n• Missing libraries\n• JIT not enabled"
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
