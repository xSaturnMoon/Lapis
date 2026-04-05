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
    }
    
    // Il JREManager può essere il GameDownloader o un servizio dedicato
    // Per ora usiamo GameDownloader per coerenza con il progetto
    
    func launch(config: LaunchConfig, completion: @escaping (String?) -> Void) {
        NSLog("[GameLauncher] Inizio sequenza di lancio per: \(config.versionId)")
        
        // 1. Prepara gli argomenti di sistema per JavaLauncher_main
        // NOTA: Questi verranno passati al ponte Objective-C
        let args: [String] = [
            "java", 
            "-Xmx2048M", 
            "-Djava.library.path=...", 
            "-cp", "...", 
            "net.minecraft.client.main.Main",
            "--username", config.playerName,
            "--version", config.versionId,
            "--uuid", config.playerUUID,
            "--accessToken", config.accessToken,
            "--userType", "msa"
        ]
        
        // 2. Esegui il lancio tramite il ponte
        LauncherBridge.launch(withArgs: args) { exitCode in
            if exitCode == 0 {
                completion(nil)
            } else {
                completion("Errore durante l'avvio (Code: \(exitCode))")
            }
        }
    }
    
    private func getGameDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("minecraft")
    }
}
