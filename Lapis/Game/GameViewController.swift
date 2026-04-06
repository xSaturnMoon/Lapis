import UIKit
import SwiftUI

/**
 * GameViewController: Il "contenitore" grafico ufficiale di Minecraft.
 * Riceve un LaunchConfig, lancia il gioco tramite GameLauncher,
 * e notifica HomeView al termine tramite onGameEnd.
 */
class GameViewController: UIViewController {

    let inputMode: InputMode
    let config: GameLauncher.LaunchConfig
    var onGameEnd: ((String?) -> Void)?   // callback verso HomeView per resettare stato

    init(inputMode: InputMode, config: GameLauncher.LaunchConfig, onGameEnd: ((String?) -> Void)? = nil) {
        self.inputMode = inputMode
        self.config = config
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
            requestPointerLock()
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
        NSLog("[GameView] Avvio tramite GameLauncher per versione: \(config.versionId)")

        GameLauncher.shared.launch(config: config) { [weak self] error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // Prima di chiudere la view, notifica HomeView.
                // HomeView usa questo per: resettare isLaunching, mostrare errore.
                // PRIMA questo callback non esisteva: HomeView settava isLaunching=true
                // e non lo resettava mai → overlay "Launching Minecraft..." bloccato in eterno.
                self.onGameEnd?(error)
                self.dismiss(animated: true)
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
