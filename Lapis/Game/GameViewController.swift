import UIKit
import SwiftUI

class GameViewController: UIViewController {

    let inputMode: InputMode
    let config: GameLauncher.LaunchConfig
    var onGameEnd: ((String?) -> Void)?

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

    private func launchMinecraft() {
        NSLog("[GameView] Avvio GameLauncher per versione: \(config.versionId)")

        GameLauncher.shared.launch(config: config) { [weak self] error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // Prima chiudi la schermata nera, poi (dopo la fine dell'animazione)
                // notifica HomeView. Se onGameEnd fosse chiamato prima del dismiss,
                // SwiftUI scarta l'alert perché il fullScreenCover è ancora in dismissing.
                self.dismiss(animated: true) {
                    // Questo blocco viene eseguito DOPO che l'animazione di dismiss è completata.
                    // A questo punto HomeView è tornata visibile e può presentare l'alert.
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
