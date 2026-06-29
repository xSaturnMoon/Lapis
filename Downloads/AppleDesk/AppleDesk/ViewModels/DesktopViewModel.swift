import SwiftUI
import Combine
import AVFoundation

// MARK: - Snap Zone (tutti e 7 i tipi, come Windows 11)
enum SnapZone: Equatable {
    case fullscreen
    case leftHalf, rightHalf
    case topLeft, topRight
    case bottomLeft, bottomRight

    func previewFrame(for screen: CGSize) -> CGRect {
        let hw = screen.width / 2; let hh = screen.height / 2
        switch self {
        case .fullscreen:  return CGRect(origin: .zero, size: screen)
        case .leftHalf:    return CGRect(x: 0,  y: 0,  width: hw, height: screen.height)
        case .rightHalf:   return CGRect(x: hw, y: 0,  width: hw, height: screen.height)
        case .topLeft:     return CGRect(x: 0,  y: 0,  width: hw, height: hh)
        case .topRight:    return CGRect(x: hw, y: 0,  width: hw, height: hh)
        case .bottomLeft:  return CGRect(x: 0,  y: hh, width: hw, height: hh)
        case .bottomRight: return CGRect(x: hw, y: hh, width: hw, height: hh)
        }
    }

    // La taskbar si nasconde per questi snap
    var hidesTaskbar: Bool {
        switch self {
        case .fullscreen, .leftHalf, .rightHalf, .bottomLeft, .bottomRight: return true
        case .topLeft, .topRight: return false
        }
    }

    var cornerRadius: CGFloat { self == .fullscreen ? 0 : 16 }
}

@MainActor
class DesktopViewModel: ObservableObject {
    @Published var openWindows: [DesktopWindow] = [] { didSet { saveState() } }
    @Published var appStates: [String: DesktopWindow] = [:] { didSet { saveState() } }
    // taskbarApps è dinamico: pinned sempre presenti, non-pinned aggiunti all'apertura
    @Published var taskbarApps: [AppItem] = AppItem.defaults
    @Published var activeWindowID: UUID? = nil { didSet { saveState() } }
    @Published var showStartMenu: Bool = false
    @Published var taskbarVisible: Bool = true
    @Published var taskbarPinned: Bool = false
    @Published var snapPreview: SnapZone? = nil
    // Tiene traccia delle finestre snappate e la loro zona
    @Published var snappedWindowZones: [UUID: SnapZone] = [:]

    // Tutte le app cercabili nel menu Start
    let allApps: [AppItem] = AppItem.allApps

    func toggleStartMenu() {
        withAnimation(.spring(duration: 0.4, bounce: 0.1)) {
            showStartMenu.toggle()
            taskbarPinned = showStartMenu
            if showStartMenu { taskbarVisible = true }
        }
    }

    func showTaskbar() {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) { taskbarVisible = true }
    }

    func hideTaskbarIfNeeded() {
        guard !taskbarPinned else { return }
        let shouldHide = openWindows.contains { w in
            guard !w.isMinimized else { return false }
            if w.isMaximized { return true }
            if let z = snappedWindowZones[w.id], z.hidesTaskbar { return true }
            return false
        }
        if shouldHide {
            withAnimation(.spring(duration: 0.35, bounce: 0.05)) { taskbarVisible = false }
        }
    }

    func addSnappedWindow(_ id: UUID, zone: SnapZone) {
        snappedWindowZones[id] = zone
        syncTaskbarVisibility()
    }

    func removeSnappedWindow(_ id: UUID) {
        snappedWindowZones.removeValue(forKey: id)
    }

    init() { loadState() }

    private func saveState() {
        if let data = try? JSONEncoder().encode(openWindows) {
            UserDefaults.standard.set(data, forKey: "savedWindows")
        }
        if let data = try? JSONEncoder().encode(appStates) {
            UserDefaults.standard.set(data, forKey: "savedAppStates")
        }
        if let activeID = activeWindowID?.uuidString {
            UserDefaults.standard.set(activeID, forKey: "activeWindowID")
        }
    }

    private func loadState() {
        if let data = UserDefaults.standard.data(forKey: "savedWindows"),
           let saved = try? JSONDecoder().decode([DesktopWindow].self, from: data) {
            self.openWindows = saved
        }
        if let data = UserDefaults.standard.data(forKey: "savedAppStates"),
           let saved = try? JSONDecoder().decode([String: DesktopWindow].self, from: data) {
            self.appStates = saved
        }
        if let activeIDStr = UserDefaults.standard.string(forKey: "activeWindowID"),
           let activeID = UUID(uuidString: activeIDStr) {
            self.activeWindowID = activeID
        } else {
            self.activeWindowID = openWindows.last?.id
        }
        // Ripristina taskbarApps per app non-pinnate già aperte
        for window in openWindows {
            if let app = allApps.first(where: { $0.id == window.appID }),
               !app.isPinned,
               !taskbarApps.contains(where: { $0.id == app.id }) {
                taskbarApps.append(app)
            }
        }
    }

    func openApp(_ app: AppItem) {
        // Aggiunge alla taskbar se non pinnata e non già presente
        if !taskbarApps.contains(where: { $0.id == app.id }) {
            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                taskbarApps.append(app)
            }
        }

        if let idx = openWindows.firstIndex(where: { $0.appID == app.id }) {
            withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
                openWindows[idx].isMinimized = false
            }
            bringToFront(openWindows[idx].id)
        } else {
            var win = appStates[app.id] ?? DesktopWindow(
                appID: app.id, title: app.name, icon: app.icon, iconAsset: app.iconAsset,
                position: CGPoint(x: 520, y: 380)
            )
            win.id = UUID()
            win.isMinimized = false
            openWindows.append(win)
            activeWindowID = win.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.syncTaskbarVisibility() }
        }
    }

    func closeApp(_ appID: String) {
        if let window = openWindows.first(where: { $0.appID == appID }) {
            closeWindow(window.id)
        }
    }

    func minimizeWindow(_ id: UUID) {
        if let idx = openWindows.firstIndex(where: { $0.id == id }) {
            withAnimation(.spring(duration: 0.35, bounce: 0.1)) { openWindows[idx].isMinimized = true }
            activeWindowID = openWindows.last(where: { !$0.isMinimized })?.id
            syncTaskbarVisibility()
        }
    }

    func closeWindow(_ id: UUID) {
        // Se l'app non è pinnata, toglila dalla taskbar alla chiusura
        if let window = openWindows.first(where: { $0.id == id }),
           let app = allApps.first(where: { $0.id == window.appID }),
           !app.isPinned {
            withAnimation(.spring(duration: 0.3, bounce: 0.1)) {
                taskbarApps.removeAll { $0.id == app.id }
            }
        }
        snappedWindowZones.removeValue(forKey: id)
        withAnimation(.spring(duration: 0.35, bounce: 0.05)) { openWindows.removeAll { $0.id == id } }
        activeWindowID = openWindows.last?.id
        syncTaskbarVisibility()
    }

    func setMaximized(_ id: UUID, value: Bool) {
        if let idx = openWindows.firstIndex(where: { $0.id == id }) {
            openWindows[idx].isMaximized = value
            appStates[openWindows[idx].appID] = openWindows[idx]
            if !value { snappedWindowZones.removeValue(forKey: id) }
            syncTaskbarVisibility()
        }
    }

    func bringToFront(_ id: UUID) {
        guard let idx = openWindows.firstIndex(where: { $0.id == id }) else { return }
        let win = openWindows.remove(at: idx)
        openWindows.append(win)
        activeWindowID = id
    }

    func updateWindow(_ id: UUID, position: CGPoint, size: CGSize) {
        if let idx = openWindows.firstIndex(where: { $0.id == id }) {
            openWindows[idx].position = position
            openWindows[idx].size = size
            appStates[openWindows[idx].appID] = openWindows[idx]
        }
    }

    func syncTaskbarVisibility() {
        guard !taskbarPinned else { taskbarVisible = true; return }
        let shouldHide = openWindows.contains { w in
            guard !w.isMinimized else { return false }
            if w.isMaximized { return true }
            if let z = snappedWindowZones[w.id], z.hidesTaskbar { return true }
            return false
        }
        withAnimation(.spring(duration: 0.4, bounce: 0.08)) { taskbarVisible = !shouldHide }
    }

    func restart(authVM: AuthViewModel) {
        withAnimation(.spring(duration: 0.4, bounce: 0.05)) {
            openWindows.removeAll()
            snappedWindowZones.removeAll()
            taskbarApps = AppItem.defaults
            showStartMenu = false
            taskbarPinned = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { authVM.logout() }
    }

    func shutdown() { exit(0) }
}