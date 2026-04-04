import Foundation

/// GameLauncher — Swift bridge to the native Lapis game engine.
/// Handles JRE setup, classpath building, and JVM launch via LapisLauncher (ObjC).
class GameLauncher {
    
    static let shared = GameLauncher()
    
    private init() {}
    
    // MARK: - Engine Initialization
    
    /// Initialize the native engine (dyld bypass). Call once at app start.
    func initEngine() {
        LapisEngine_init()
        NSLog("[Lapis:GameLauncher] Engine initialized, bypass ready: \(LapisEngine_isBypassReady())")
    }
    
    // MARK: - JRE Management
    
    /// Find and set up the JRE. Returns the path if found, nil otherwise.
    func setupJRE() -> String? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let lapisRoot = docs.appendingPathComponent("Lapis")
        let docsJRE = lapisRoot.appendingPathComponent("jre")
        
        // Check Documents/Lapis/jre first
        if fm.fileExists(atPath: docsJRE.path) {
            NSLog("[Lapis:GameLauncher] JRE found in Documents: \(docsJRE.path)")
            return docsJRE.path
        }
        
        // Check app bundle
        let bundleJRE = Bundle.main.bundleURL.appendingPathComponent("jre")
        if fm.fileExists(atPath: bundleJRE.path) {
            NSLog("[Lapis:GameLauncher] JRE found in bundle, copying to Documents...")
            try? fm.createDirectory(at: lapisRoot, withIntermediateDirectories: true)
            do {
                try fm.copyItem(at: bundleJRE, to: docsJRE)
                NSLog("[Lapis:GameLauncher] JRE copied successfully")
                return docsJRE.path
            } catch {
                NSLog("[Lapis:GameLauncher] Failed to copy JRE: \(error)")
            }
        }
        
        NSLog("[Lapis:GameLauncher] No JRE found!")
        return nil
    }
    
    /// Check if JRE has libjli.dylib
    func isJREValid(_ jrePath: String) -> Bool {
        let fm = FileManager.default
        let jli11 = (jrePath as NSString).appendingPathComponent("lib/libjli.dylib")
        let jli8 = (jrePath as NSString).appendingPathComponent("lib/jli/libjli.dylib")
        return fm.fileExists(atPath: jli11) || fm.fileExists(atPath: jli8)
    }
    
    // MARK: - Game Launch
    
    struct LaunchConfig {
        let versionId: String
        let loader: ModLoader
        let inputMode: InputMode
        let playerName: String
        let playerUUID: String
        let accessToken: String
    }
    
    /// Launch Minecraft with the given configuration.
    /// Returns nil on success, or an error message on failure.
    func launch(config: LaunchConfig) -> String? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let lapisRoot = docs.appendingPathComponent("Lapis")
        
        // 1. Validate JRE
        guard let jrePath = setupJRE() else {
            return "Java Runtime (JRE) not found.\n\nPlace the JRE in: Files → Lapis → jre/"
        }
        
        guard isJREValid(jrePath) else {
            return "JRE is incomplete.\n\nlibjli.dylib not found.\nPlease re-install the JRE."
        }
        
        // 2. Validate game files
        let versionDir = lapisRoot.appendingPathComponent("versions/\(config.versionId)")
        let clientJar = versionDir.appendingPathComponent("\(config.versionId).jar")
        guard fm.fileExists(atPath: clientJar.path) else {
            return "Game files not downloaded.\nPlease download \(config.versionId) first."
        }
        
        // 3. Set up directories
        let gameDir = lapisRoot.appendingPathComponent("game")
        let modsDir = lapisRoot.appendingPathComponent("mods/mods-\(config.versionId)-\(config.loader.rawValue.lowercased())")
        let assetsDir = lapisRoot.appendingPathComponent("assets")
        let libDir = lapisRoot.appendingPathComponent("libraries")
        
        try? fm.createDirectory(at: gameDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: modsDir, withIntermediateDirectories: true)
        
        // 4. Configure engine
        initEngine()
        LapisEngine_setJavaHome(jrePath)
        LapisEngine_setGameHome(lapisRoot.path)
        
        // Save input mode
        UserDefaults.standard.set(config.inputMode == .touch ? "touch" : "keyboard", forKey: "lapis_input_mode")
        
        // 5. Build classpath
        var cpPaths = [clientJar.path]
        if let enumerator = fm.enumerator(at: libDir, includingPropertiesForKeys: nil) {
            while let file = enumerator.nextObject() as? URL {
                if file.pathExtension == "jar" { cpPaths.append(file.path) }
            }
        }
        // Add bundled libs
        let bundleLibs = Bundle.main.bundleURL.appendingPathComponent("libs")
        if fm.fileExists(atPath: bundleLibs.path),
           let enumerator = fm.enumerator(at: bundleLibs, includingPropertiesForKeys: nil) {
            while let file = enumerator.nextObject() as? URL {
                if file.pathExtension == "jar" { cpPaths.append(file.path) }
            }
        }
        let classpath = cpPaths.joined(separator: ":")
        
        // 6. Build JVM arguments
        let ramMB = max(UserDefaults.standard.integer(forKey: "lapis_ram"), 1024)
        let frameworksPath = Bundle.main.bundleURL.appendingPathComponent("Frameworks").path
        
        var args: [String] = [
            "java",              // argv[0] = java binary path
            "-Xms128M",
            "-Xmx\(ramMB)M",
            "-Djava.library.path=\(frameworksPath)",
            "-Duser.dir=\(gameDir.path)",
            "-Duser.home=\(lapisRoot.path)",
            "-Duser.timezone=\(TimeZone.current.identifier)",
            "-Dorg.lwjgl.glfw.checkThread0=false",
            "-Dorg.lwjgl.system.allocator=system",
            "-Dlog4j2.formatMsgNoLookups=true",
            "-Dfile.encoding=UTF-8",
            "-Djava.io.tmpdir=\(NSTemporaryDirectory())",
            "-Dos.name=iOS",
            "-XX:+UseSerialGC",
            "-XX:MaxGCPauseMillis=200",
            "-XX:+UnlockExperimentalVMOptions",
            "-XX:+DisablePrimordialThreadGuardPages",  // Workaround stack guard crash
            "-Dfml.earlyprogresswindow=false",         // Disable Forge loading window
        ]
        
        // Java 17 module system flags (needed for Caciocavallo and modern MC)
        args += [
            "--add-exports=java.desktop/java.awt=ALL-UNNAMED",
            "--add-exports=java.desktop/java.awt.peer=ALL-UNNAMED",
            "--add-exports=java.desktop/sun.awt.image=ALL-UNNAMED",
            "--add-exports=java.desktop/sun.java2d=ALL-UNNAMED",
            "--add-exports=java.desktop/java.awt.dnd.peer=ALL-UNNAMED",
            "--add-exports=java.desktop/sun.awt=ALL-UNNAMED",
            "--add-exports=java.desktop/sun.awt.event=ALL-UNNAMED",
            "--add-exports=java.desktop/sun.awt.datatransfer=ALL-UNNAMED",
            "--add-exports=java.desktop/sun.font=ALL-UNNAMED",
            "--add-exports=java.base/sun.security.action=ALL-UNNAMED",
            "--add-opens=java.base/java.util=ALL-UNNAMED",
            "--add-opens=java.desktop/java.awt=ALL-UNNAMED",
            "--add-opens=java.desktop/sun.font=ALL-UNNAMED",
            "--add-opens=java.desktop/sun.java2d=ALL-UNNAMED",
            "--add-opens=java.base/java.lang.reflect=ALL-UNNAMED",
            "--add-opens=java.base/java.net=ALL-UNNAMED",
        ]
        
        // Headless AWT (Caciocavallo)
        args += [
            "-Djava.awt.headless=false",
            "-Dawt.toolkit=com.github.caciocavallosilano.cacio.ctc.CTCToolkit",
            "-Djava.awt.graphicsenv=com.github.caciocavallosilano.cacio.ctc.CTCGraphicsEnvironment",
            "-Dcacio.font.fontmanager=sun.awt.X11FontManager",
            "-Dcacio.font.fontscaler=sun.font.FreetypeFontScaler",
            "-Dswing.defaultlaf=javax.swing.plaf.metal.MetalLookAndFeel",
        ]
        
        // Loader-specific flags
        switch config.loader {
        case .fabric:
            args.append("-Dfabric.modsDir=\(modsDir.path)")
            args.append("-Dfabric.gameDir=\(gameDir.path)")
        case .forge, .neoforge:
            args.append("-Dfml.modsDir=\(modsDir.path)")
        case .quilt:
            args.append("-Dloader.modsDir=\(modsDir.path)")
        case .vanilla:
            break
        }
        
        // Classpath and main class
        args += ["-cp", classpath]
        args.append("net.minecraft.client.main.Main")
        
        // Game arguments
        args += [
            "--username", config.playerName,
            "--version", config.versionId,
            "--gameDir", gameDir.path,
            "--assetsDir", assetsDir.path,
            "--assetIndex", config.versionId,
            "--uuid", config.playerUUID,
            "--accessToken", config.accessToken,
            "--userType", "msa",
            "--versionType", "Lapis"
        ]
        
        NSLog("[Lapis:GameLauncher] Launching with \(args.count) arguments")
        
        // 7. Launch on background thread
        let result = LapisEngine_launchJVM(args)
        
        if result != 0 {
            let engineError = LapisEngine_getLastError() ?? "Unknown error"
            return "Launch failed (code \(result)):\n\(engineError)"
        }
        
        return nil
    }
}
