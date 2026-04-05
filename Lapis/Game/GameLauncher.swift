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
        guard FileManager.default.fileExists(atPath: clientJarURL.path) else {
            completion("Errore: JAR di gioco non trovato in \(clientJarURL.lastPathComponent)")
            return
        }
        
        // 2. Costruisci il Classpath completo (Librerie + Client Jar)
        let librariesURL = gameURL.appendingPathComponent("libraries")
        let classpath = buildClasspath(librariesURL: librariesURL, clientJarURL: clientJarURL)
        
        // 3. Prepara gli argomenti di lancio per l'engine Pojav
        var args: [String] = [
            "java",
            "-Xmx\(config.memoryAllocation)M",
            "-Djava.home=\(jreURL.path)",
            "-Djava.library.path=\(versionURL.appendingPathComponent("natives").path)",
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
            "--assetIndex", config.versionId,
            "--uuid", config.playerUUID,
            "--accessToken", config.accessToken,
            "--userType", "msa",
            "--versionType", "release"
        ])
        
        NSLog("[GameLauncher] Classpath costruito con \(classpath.components(separatedBy: ":").count) elementi.")
        
        // 4. Esegui il lancio tramite il ponte nativo
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
    
    private func buildClasspath(librariesURL: URL, clientJarURL: URL) -> String {
        var items = [String]()
        
        // Aggiungi ricorsivamente tutti i jar dalle librerie
        if let enumerator = FileManager.default.enumerator(at: librariesURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "jar" {
                    items.append(fileURL.path)
                }
            }
        }
        
        // Aggiungi il jar principale di Minecraft
        items.append(clientJarURL.path)
        
        return items.joined(separator: ":")
    }
    
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
        
        // Fallback to bundle JRE if exists
        return Bundle.main.bundleURL.appendingPathComponent("jre")
    }
}
