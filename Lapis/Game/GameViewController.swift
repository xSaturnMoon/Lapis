import UIKit
import SwiftUI

/**
 * GameViewController: Il "contenitore" grafico ufficiale di Minecraft.
 * Gestisce il rendering dell'engine e gli input esterni.
 */
class GameViewController: UIViewController {
    
    let inputMode: InputMode
    private var engineLayer: CALayer?
    
    init(inputMode: InputMode) {
        self.inputMode = inputMode
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
            // Su iPadOS 26, abilitiamo il supporto ai puntatori fisici
            self.requestPointerLock()
        } else {
            // Su touch mode, potremmo caricare dei tasti virtuali in sovrimpressione
            print("[GameView] Caricamento tasti virtuali...")
        }
    }
    
    private func requestPointerLock() {
        if #available(iOS 14.0, *) {
            // Logica per bloccare il cursore nel gioco
            self.setNeedsUpdateOfPrefersPointerLocked()
        }
    }
    
    override var prefersPointerLocked: Bool {
        return inputMode == .keyboard
    }
    
    private func launchMinecraft() {
        // Qui chiameremo il LauncherBridge con i parametri reali
        NSLog("[GameView] Chiamata a LauncherBridge per avvio engine...")
        
        let args = ["minecraft", "--version", "1.20"] // Esempio semplificato
        
        LauncherBridge.launch(withArgs: args) { exitCode in
            NSLog("[GameView] Engine terminato con codice: \(exitCode)")
            self.dismiss(animated: true)
        }
    }
}

// MARK: - SwiftUI Representable
struct GameViewContainer: UIViewControllerRepresentable {
    let inputMode: InputMode
    
    func makeUIViewController(context: Context) -> GameViewController {
        return GameViewController(inputMode: inputMode)
    }
    
    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {}
}
