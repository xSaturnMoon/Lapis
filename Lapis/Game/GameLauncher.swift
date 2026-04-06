import Foundation
import UIKit

/**
 * GameLauncher: Il coordinatore finale dell'avvio di Minecraft.
 * Prepara l'ambiente di runtime (JRE) e invia i parametri al ponte nativo.
 */
class GameLauncher {
    static let shared = GameLauncher()

    struct LaunchConfig {
        let versionId: String
        let loader: ModLoader
        let inputMode: InputMode
        let playerName: String
        let playerUUID: String
        let accessToken: String
        let memoryAllocation: Int
    }

    func launch(config: LaunchConfig, completion: @escaping (String?) -> Void) {
        NSLog("[GameLauncher] Avvio sequenza di lancio per: \(config.versionId)")

        let gameURL    = getGameDirectory()
        let jreURL     = getJREDirectory()
        let versionURL = gameURL.appendingPathComponent("versions/\(config.versionId)")
        let clientJarURL = versionURL.appendingPathComponent("\(config.versionId).jar")

        // 1. Verifica esistenza file critici
        let fm = FileManager.default
        let assetsObjectsURL = gameURL.appendingPathComponent("assets/objects")
        guard fm.fileExists(atPath: clientJarURL.path) else {
            completion("Errore: JAR di gioco non trovato in \(clientJarURL.lastPathComponent)")
            return
        }

        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: assetsObjectsURL.path, isDirectory: &isDir) || !isDir.boolValue {
            completion("Errore: Assets (900MB) mancanti. Clicca DOWNLOAD prima di giocare.")
            return
        }

        // 2. Leggi assetIndex.id dal JSON di versione
        let versionJsonURL = versionURL.appendingPathComponent("\(config.versionId).json")
        let assetIndexId   = readAssetIndexId(from: versionJsonURL) ?? config.versionId
        NSLog("[GameLauncher] assetIndex risolto: \(assetIndexId)")

        // 3. Costruisci il Classpath completo
        let librariesURL = gameURL.appendingPathComponent("libraries")
        let classpath    = buildClasspath(librariesURL: librariesURL, clientJarURL: clientJarURL)

        // ──────────────────────────────────────────────────────────
        // FIX BUG #3: esporta JAVA_HOME *prima* di chiamare il bridge
        // in modo che LauncherBridge.m trovi sempre il valore corretto
        // senza doverlo calcolare autonomamente (source unica).
        // ──────────────────────────────────────────────────────────
        setenv("JAVA_HOME",       jreURL.path, 1)
        setenv("POJAV_HOME",      gameURL.path, 1)
        setenv("POJAV_GAME_DIR",  gameURL.path, 1)
        setenv("POJAV_RENDERER",  "mobileglues", 1)
        setenv("PRINT_ALL_EXCEPTIONS", "1", 1)
        NSLog("[GameLauncher] JAVA_HOME esportato: \(jreURL.path)")

        // 4. Prepara gli argomenti di lancio
        let frameworkPath = Bundle.main.bundleURL
            .appendingPathComponent("Frameworks").path
        let nativesPath   = versionURL.appendingPathComponent("natives").path

        var args: [String] = [
            "java",
            "-Xmx\(config.memoryAllocation)M",
            "-Djava.home=\(jreURL.path)",
            "-Djava.library.path=\(frameworkPath):\(nativesPath)",
            "-Dapple.laf.useScreenMenuBar=true",
            "-cp", classpath,
            "net.minecraft.client.main.Main"
        ]

        args.append(contentsOf: [
            "--username",   config.playerName,
            "--version",    config.versionId,
            "--gameDir",    gameURL.path,
            "--assetsDir",  gameURL.appendingPathComponent("assets").path,
            "--assetIndex", assetIndexId,
            "--uuid",       config.playerUUID,
            "--accessToken", config.accessToken,
            "--userType",   "msa",
            "--versionType", "release"
        ])

        NSLog("[GameLauncher] Classpath: \(classpath.components(separatedBy: ":").count) elementi")

        // 5. Esegui il lancio tramite il ponte nativo
        LauncherBridge.launch(withArgs: args) { exitCode in
            if exitCode == 0 {
                NSLog("[GameLauncher] Minecraft terminato normalmente.")
                completion(nil)
            } else {
                NSLog("[GameLauncher] Motore terminato con codice: \(exitCode)")
                completion("Launch Error (Code: \(exitCode)). Controlla Documents/Lapis/launch.log.")
            }
        }
    }

    // MARK: - Legge assetIndex.id dal version JSON di Mojang
    private func readAssetIndexId(from jsonURL: URL) -> String? {
        guard
            let data = try? Data(contentsOf: jsonURL),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let assetIndexObj = root["assetIndex"] as? [String: Any],
            let indexId = assetIndexObj["id"] as? String
        else {
            NSLog("[GameLauncher] Avviso: impossibile leggere assetIndex.id da \(jsonURL.lastPathComponent)")
            return nil
        }
        return indexId
    }

    // MARK: - Classpath Builder
    private func buildClasspath(librariesURL: URL, clientJarURL: URL) -> String {
        var items = [String]()
        if let enumerator = FileManager.default.enumerator(
            at: librariesURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator
                where fileURL.pathExtension == "jar" {
                items.append(fileURL.path)
            }
        }
        items.append(clientJarURL.path)
        return items.joined(separator: ":")
    }

    // MARK: - Directory Helpers

    /// Directory di gioco: Documents/Lapis/
    private func getGameDirectory() -> URL {
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lapis")
    }

    /// JRE da usare.
    /// Priorità:
    ///   1. Documents/Lapis/jre      ← scaricato da JREDownloader
    ///   2. Bundle.app/java_runtimes/java-17-openjdk  ← bundled (se presente)
    ///   3. Bundle.app/jre           ← path legacy
    private func getJREDirectory() -> URL {
        let fm   = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!

        // 1. JRE scaricato dall'utente
        let docsJRE = docs.appendingPathComponent("Lapis/jre")
        if fm.fileExists(atPath: docsJRE.path) { return docsJRE }

        // 2. JRE bundled (struttura Amethyst)
        let bundledJRE17 = Bundle.main.bundleURL
            .appendingPathComponent("java_runtimes/java-17-openjdk")
        if fm.fileExists(atPath: bundledJRE17.path) { return bundledJRE17 }

        // 3. Path legacy
        return Bundle.main.bundleURL.appendingPathComponent("jre")
    }
}
