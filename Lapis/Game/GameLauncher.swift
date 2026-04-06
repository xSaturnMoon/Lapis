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
        NSLog("[GameLauncher] Avvio sequenza di lancio professionale per: \(config.versionId)")

        let gameURL = getGameDirectory()
        let jreURL = getJREDirectory()
        let versionURL = gameURL.appendingPathComponent("versions/\(config.versionId)")
        let clientJarURL = versionURL.appendingPathComponent("\(config.versionId).jar")

        // 1. Verifica esistenza file critici
        let fm = FileManager.default
        let assetsObjectsURL = gameURL.appendingPathComponent("assets/objects")
        guard fm.fileExists(atPath: clientJarURL.path) else {
            completion("Errore: JAR di gioco non trovato in \(clientJarURL.lastPathComponent)")
            return
        }

        // Verifica Assets (per evitare schermata nera)
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: assetsObjectsURL.path, isDirectory: &isDir) || !isDir.boolValue {
            completion("Errore: Assets (900MB) mancanti. Clicca DOWNLOAD prima di giocare.")
            return
        }

        // 2. Leggi assetIndex.id dal JSON di versione scaricato da Mojang.
        //    CORRETTO: prima era "--assetIndex", config.versionId (es. "1.20.4")
        //    ma l'assetIndex corretto viene dal campo assetIndex.id nel JSON (es. "3").
        let versionJsonURL = versionURL.appendingPathComponent("\(config.versionId).json")
        let assetIndexId = readAssetIndexId(from: versionJsonURL) ?? config.versionId
        NSLog("[GameLauncher] assetIndex risolto: \(assetIndexId)")

        // 3. Costruisci il Classpath completo (Librerie + Client Jar)
        let librariesURL = gameURL.appendingPathComponent("libraries")
        let classpath = buildClasspath(librariesURL: librariesURL, clientJarURL: clientJarURL)

        // 4. Prepara gli argomenti di lancio per l'engine Amethyst
        let frameworkPath = Bundle.main.bundleURL.appendingPathComponent("Frameworks").path
        var args: [String] = [
            "java",
            "-Xmx\(config.memoryAllocation)M",
            "-Djava.home=\(jreURL.path)",
            "-Djava.library.path=\(frameworkPath):\(versionURL.appendingPathComponent("natives").path)",
            "-Dapple.laf.useScreenMenuBar=true",
            "-cp", classpath,
            "net.minecraft.client.main.Main"
        ]

        // Argomenti specifici di Minecraft
        args.append(contentsOf: [
            "--username", config.playerName,
            "--version", config.versionId,
            "--gameDir", gameURL.path,
            "--assetsDir", gameURL.appendingPathComponent("assets").path,
            "--assetIndex", assetIndexId,        // ← CORRETTO: usa assetIndexId letto dal JSON
            "--uuid", config.playerUUID,
            "--accessToken", config.accessToken,
            "--userType", "msa",
            "--versionType", "release"
        ])

        NSLog("[GameLauncher] Classpath costruito con \(classpath.components(separatedBy: ":").count) elementi.")

        // 5. Esegui il lancio tramite il ponte nativo
        LauncherBridge.launch(withArgs: args) { exitCode in
            if exitCode == 0 {
                NSLog("[GameLauncher] Minecraft terminato con successo.")
                completion(nil)
            } else {
                NSLog("[GameLauncher] Errore critico durante l'esecuzione del motore. Code: \(exitCode)")
                completion("Launch Error (Code: \(exitCode)). Controlla i log per i dettagli.")
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

        if let enumerator = FileManager.default.enumerator(at: librariesURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "jar" {
                    items.append(fileURL.path)
                }
            }
        }

        items.append(clientJarURL.path)
        return items.joined(separator: ":")
    }

    // MARK: - Directory Helpers
    private func getGameDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Lapis")
    }

    private func getJREDirectory() -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docsJRE = docs.appendingPathComponent("Lapis/jre")

        if fm.fileExists(atPath: docsJRE.path) {
            return docsJRE
        }

        return Bundle.main.bundleURL.appendingPathComponent("jre")
    }
}
