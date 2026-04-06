import SwiftUI
import UIKit

// ─────────────────────────────────────────────
// Crash handler globale — scrive il motivo del
// crash in Documents/Lapis/crash.log PRIMA che
// il processo venga terminato dal sistema.
// ─────────────────────────────────────────────
private func crashLogPath() -> String {
    let docs = NSSearchPathForDirectoriesInDomains(
        .documentDirectory, .userDomainMask, true).first!
    return (docs as NSString).appendingPathComponent("Lapis/crash.log")
}

private func writeCrashLog(_ text: String) {
    let path = crashLogPath()
    // Assicura che la cartella esista
    try? FileManager.default.createDirectory(
        atPath: (path as NSString).deletingLastPathComponent,
        withIntermediateDirectories: true)
    let line = "[\(Date())] \(text)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: path),
           let fh = FileHandle(forWritingAtPath: path) {
            fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

private func installCrashHandlers() {
    // 1. Eccezioni Objective-C non gestite
    NSSetUncaughtExceptionHandler { exception in
        let msg = """
        ══ UNCAUGHT EXCEPTION ══
        Name   : \(exception.name.rawValue)
        Reason : \(exception.reason ?? "nil")
        Stack  :
        \(exception.callStackSymbols.joined(separator: "\n"))
        """
        writeCrashLog(msg)
        // Dai tempo al filesystem di flushare
        Thread.sleep(forTimeInterval: 0.5)
    }

    // 2. Segnali UNIX (SIGSEGV, SIGBUS, SIGABRT ecc.)
    for sig in [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE, SIGTRAP] {
        signal(sig) { signum in
            let names: [Int32: String] = [
                SIGABRT: "SIGABRT", SIGILL: "SIGILL", SIGSEGV: "SIGSEGV",
                SIGFPE:  "SIGFPE",  SIGBUS: "SIGBUS", SIGPIPE: "SIGPIPE",
                SIGTRAP: "SIGTRAP"
            ]
            let name = names[signum] ?? "SIG\(signum)"
            writeCrashLog("══ SIGNAL CRASH: \(name) ══\nControlla launch.log per il contesto.")
            Thread.sleep(forTimeInterval: 0.5)
            // Re-raise per far generare il crash report di sistema
            signal(signum, SIG_DFL)
            raise(signum)
        }
    }
}

// ─────────────────────────────────────────────
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    let appState = AppState()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // DISATTIVATO: I crash handler personalizzati vanno in conflitto con la JVM di Java 17.
        // Lasciamo che la JVM gestisca i propri segnali (SIGSEGV, SIGBUS) per il JIT.
        // installCrashHandlers()
        
        createDirectories()
        appState.loadInstalledVersions()

        let contentView = ContentView()
            .environmentObject(appState)
            .preferredColorScheme(.dark)

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()

        return true
    }

    private func createDirectories() {
        let fm   = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let root = docs.appendingPathComponent("Lapis")
        try? fm.createDirectory(at: root.appendingPathComponent("mods"),     withIntermediateDirectories: true)
        try? fm.createDirectory(at: root.appendingPathComponent("versions"), withIntermediateDirectories: true)
    }
}
