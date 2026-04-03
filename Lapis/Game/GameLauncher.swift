import Foundation

// MARK: - Game Launcher (Bridge to PojavLauncher native code)
class GameLauncher: ObservableObject {
    @Published var isLaunching = false
    @Published var launchError: String? = nil
    
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    /// Launch Minecraft with the correct arguments
    func launchGame(versionId: String, loader: ModLoader, inputMode: InputMode) {
        isLaunching = true
        launchError = nil
        
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let lapisRoot = docs.appendingPathComponent("Lapis")
        let versionDir = lapisRoot.appendingPathComponent("versions/\(versionId)")
        let libDir = lapisRoot.appendingPathComponent("libraries")
        let gameDir = lapisRoot.appendingPathComponent("game")
        let modsFolderName = "mods-\(versionId)-\(loader.rawValue.lowercased())"
        let modsDir = lapisRoot.appendingPathComponent("mods/\(modsFolderName)")
        
        // Create game directory
        try? fm.createDirectory(at: gameDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: modsDir, withIntermediateDirectories: true)
        
        // Build classpath from downloaded libraries
        let classpath = buildClasspath(versionDir: versionDir, libDir: libDir, versionId: versionId)
        
        // Build JVM arguments
        let jvmArgs = buildJVMArguments(
            versionId: versionId,
            gameDir: gameDir.path,
            modsDir: modsDir.path,
            assetsDir: lapisRoot.appendingPathComponent("assets").path,
            loader: loader,
            classpath: classpath
        )
        
        // Build game arguments
        let gameArgs = buildGameArguments(
            versionId: versionId,
            gameDir: gameDir.path,
            assetsDir: lapisRoot.appendingPathComponent("assets").path,
            accessToken: appState.accessToken,
            playerName: appState.playerName,
            playerUUID: appState.playerUUID
        )
        
        // Store input mode preference
        UserDefaults.standard.set(inputMode == .touch ? "touch" : "keyboard", forKey: "lapis_input_mode")
        
        // Call PojavLauncher's native JVM launch function
        launchJVM(jvmArgs: jvmArgs, gameArgs: gameArgs)
    }
    
    // MARK: - Build Classpath
    private func buildClasspath(versionDir: URL, libDir: URL, versionId: String) -> String {
        var paths: [String] = []
        
        // Add client.jar
        let clientJar = versionDir.appendingPathComponent("\(versionId).jar")
        if FileManager.default.fileExists(atPath: clientJar.path) {
            paths.append(clientJar.path)
        }
        
        // Add all library .jars recursively
        if let enumerator = FileManager.default.enumerator(at: libDir, includingPropertiesForKeys: nil) {
            while let file = enumerator.nextObject() as? URL {
                if file.pathExtension == "jar" {
                    paths.append(file.path)
                }
            }
        }
        
        return paths.joined(separator: ":")
    }
    
    // MARK: - JVM Arguments
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
        
        // Mod loader specific args
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
    
    // MARK: - Game Arguments
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
    
    // MARK: - Native JVM Launch (calls PojavLauncher C code)
    private func launchJVM(jvmArgs: [String], gameArgs: [String]) {
        // Convert Swift arrays to C-compatible format
        let allArgs = jvmArgs + ["net.minecraft.client.main.Main"] + gameArgs
        
        // Call the native PojavLauncher function to start the JVM
        // This is bridged via the C header (Lapis-Bridging-Header.h)
        let result = PojavBridge.launchJVM(withArgs: allArgs)
        
        if result != 0 {
            DispatchQueue.main.async {
                self.launchError = "JVM exited with code \(result)"
                self.isLaunching = false
            }
        }
    }
}
