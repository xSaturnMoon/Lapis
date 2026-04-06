import UIKit
import SwiftUI

/**
 * GameViewController: Il "contenitore" grafico ufficiale di Minecraft.
 * Gestisce il rendering dell'engine e gli input esterni.
 * Riceve un LaunchConfig e delega il lancio reale a GameLauncher.
 */
class GameViewController: UIViewController {

    let inputMode: InputMode
    let config: GameLauncher.LaunchConfig   // ← AGGIUNTO: config reale passata da HomeView

    init(inputMode: InputMode, config: GameLauncher.LaunchConfig) {
        self.inputMode = inputMode
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupInputMode()
        launchMinecraft()   // ora usa config reale, non args finti
    }

    private func setupInputMode() {
        if inputMode == .keyboard {
            self.requestPointerLock()
        } else {
            print("[GameView] Caricamento tasti virtuali...")
        }
    }

    private func requestPointerLock() {
        if #available(iOS 14.0, *) {
            self.setNeedsUpdateOfPrefersPointerLocked()
        }
    }

    override var prefersPointerLocked: Bool {
        return inputMode == .keyboard
    }

    private func launchMinecraft() {
        NSLog("[GameView] Avvio tramite GameLauncher con config reale per versione: \(config.versionId)")

        // CORRETTO: usa GameLauncher.shared.launch con la config reale ricevuta da HomeView.
        // Prima era: LauncherBridge.launch(withArgs: ["minecraft", "--version", "1.20"]) ← CRASH
        GameLauncher.shared.launch(config: config) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    NSLog("[GameView] Errore lancio: \(error)")
                }
                // Chiude la game view quando il processo JVM termina
                self?.dismiss(animated: true)
            }
        }
    }
}

// MARK: - SwiftUI Representable
struct GameViewContainer: UIViewControllerRepresentable {
    let inputMode: InputMode
    let config: GameLauncher.LaunchConfig   // ← AGGIUNTO: ora riceve il config da HomeView

    func makeUIViewController(context: Context) -> GameViewController {
        return GameViewController(inputMode: inputMode, config: config)
    }

    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {}
}
