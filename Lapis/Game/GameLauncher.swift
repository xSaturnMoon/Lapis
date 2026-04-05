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
        NSLog("[Lapis:GameLauncher] Engine initialized")
    }
    
    // MARK: - JRE Management
    
    /// Find and set up the JRE. Returns the path if found, nil otherwise.
    func setupJRE() -> String? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let lapisRoot = docs.appendingPathComponent("Lapis")
        let docsJRE = lapisRoot.appendingPathComponent("jre")
        
        // 1. Check if user provided a custom JRE in Documents/Lapis/jre
        if fm.fileExists(atPath: docsJRE.path) {
            NSLog("[Lapis:GameLauncher] Using custom JRE in Documents: \(docsJRE.path)")
            return docsJRE.path
        }
        
        // 2. Otherwise, use the bundled JRE directly!
        let bundleJRE = Bundle.main.bundleURL.appendingPathComponent("jre")
        if fm.fileExists(atPath: bundleJRE.path) {
            NSLog("[Lapis:GameLauncher] Using bundled JRE directly: \(bundleJRE.path)")
            return bundleJRE.path
        }
        
        NSLog("[Lapis:GameLauncher] No JRE found in bundle or Documents!")
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
            return """
            JRE non valido o non compatibile.
            Scarica il JRE iOS da:
            github.com/PojavLauncherTeam/PojavLauncher_iOS/releases
            Poi copialo in: Files → On My iPad → Lapis → jre/
            """
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
        LapisEngine_setJavaHome(jrePath)
        LapisEngine_setGameHome(gameDir.path)
        
        let jliPath = jrePath + "/lib/libjli.dylib"
        setenv("INTERNAL_JLI_PATH", jliPath, 1)
        
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
            "java",
            "-Xms128M",
            "-Xmx\(ramMB)M",
            "-Djava.library.path=\(frameworksPath)",
            "-Duser.dir=\(gameDir.path)",
            "-Duser.home=\(lapisRoot.path)",
            "-Duser.timezone=\(TimeZone.current.identifier)",
            "-Dorg.lwjgl.glfw.checkThread0=false",
            "-Dorg.lwjgl.system.allocator=system",
            "-Dorg.lwjgl.util.NoChecks=true",
            "-Dlog4j2.formatMsgNoLookups=true",
            "-Dfile.encoding=UTF-8",
            "-Djava.io.tmpdir=\(NSTemporaryDirectory())",
            "-Dos.name=Mac OS X",
            "-Dos.version=10.16",
            "-Dos.arch=aarch64",
            "-XX:+UseSerialGC",
            "-XX:MaxGCPauseMillis=200",
            "-XX:+UnlockExperimentalVMOptions",
            "-XX:-UseCompressedOops",
            "-XX:-UseCompressedClassPointers",
            "-XX:+DisablePrimordialThreadGuardPages",
            "-Dfml.earlyprogresswindow=false",
            "-Djava.awt.headless=true",
            "-Dapple.awt.UIElement=true",
            "-Dorg.lwjgl.opengl.Display.noinput=true"
        ]
        
        // Java module system flags
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
        
        // 7. Launch via SurfaceViewController
        DispatchQueue.main.async {
            let surface = SurfaceViewController(args: args, username: config.playerName)
            surface.modalPresentationStyle = .fullScreen
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(surface, animated: true)
            }
        }
        
        return nil
    }
}
