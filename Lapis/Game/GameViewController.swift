import UIKit
import SwiftUI

class GameViewController: UIViewController {

    let inputMode: InputMode
    let config: GameLauncher.LaunchConfig
    var onGameEnd: ((String?) -> Void)?

    init(inputMode: InputMode, config: GameLauncher.LaunchConfig,
         onGameEnd: ((String?) -> Void)? = nil) {
        self.inputMode = inputMode
        self.config    = config
        self.onGameEnd = onGameEnd
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupInputMode()
        launchMinecraft()
    }

    private func setupInputMode() {
        if inputMode == .keyboard {
            if #available(iOS 14.0, *) {
                self.setNeedsUpdateOfPrefersPointerLocked()
            }
        } else {
            print("[GameView] Caricamento tasti virtuali...")
        }
    }

    override var prefersPointerLocked: Bool {
        return inputMode == .keyboard
    }

    // MARK: - Launch

    private func launchMinecraft() {
        NSLog("[GameView] Avvio GameLauncher per versione: \(config.versionId)")

        GameLauncher.shared.launch(config: config) { [weak self] error in
            guard let self = self else { return }

            // ──────────────────────────────────────────────
            // FIX BUG #4: la schermata nera (questa view)
            // non viene mai chiusa finché il gioco è in esecuzione.
            // LauncherBridge.launchWithArgs() ora è bloccante:
            // la completion arriva SOLO quando Minecraft termina
            // (o va in crash). Solo a quel punto facciamo dismiss.
            //
            // Prima: dismiss immediato su completion(0) → schermata
            //        nera spariva 1-2s dopo l'avvio, gioco invisibile.
            // Ora:   dismiss sempre e solo dopo la fine reale del gioco.
            // ──────────────────────────────────────────────
            DispatchQueue.main.async {
                self.dismiss(animated: true) {
                    // Eseguito DOPO l'animazione di dismiss: HomeView è
                    // già visibile e può mostrare alert senza race condition.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        self.onGameEnd?(error)
                    }
                }
            }
        }
    }
}

// MARK: - SwiftUI Representable

struct GameViewContainer: UIViewControllerRepresentable {
    let inputMode: InputMode
    let config: GameLauncher.LaunchConfig
    var onGameEnd: ((String?) -> Void)? = nil

    func makeUIViewController(context: Context) -> GameViewController {
        return GameViewController(inputMode: inputMode, config: config, onGameEnd: onGameEnd)
    }

    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {}
}
