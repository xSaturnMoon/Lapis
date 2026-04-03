import SwiftUI

@main
struct LapisApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Create app directories on first launch
                    createDirectories()
                    // Load installed versions from disk
                    appState.loadInstalledVersions()
                }
        }
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
