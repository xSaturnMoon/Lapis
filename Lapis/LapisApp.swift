import SwiftUI

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    let appState = AppState()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // CRITICAL: Initialize dyld bypass on the main thread at app launch
        // before dyld resolves other symbols
        GameLauncher.shared.initEngine()
        
        // Create app directories on first launch
        createDirectories()
        // Load installed versions from disk
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
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let lapisRoot = docs.appendingPathComponent("Lapis")
        let modsRoot = lapisRoot.appendingPathComponent("mods")
        let versionsRoot = lapisRoot.appendingPathComponent("versions")
        
        try? fm.createDirectory(at: modsRoot, withIntermediateDirectories: true)
        try? fm.createDirectory(at: versionsRoot, withIntermediateDirectories: true)
    }
}
