import SwiftUI
import UIKit

// MARK: - Option Key Handler
extension UIResponder {
    private static weak var _stored: UIResponder?
    static var currentFirstResponder: UIResponder? {
        _stored = nil
        UIApplication.shared.sendAction(#selector(storeFirstResponder(_:)), to: nil, from: nil, for: nil)
        return _stored
    }
    @objc private func storeFirstResponder(_ sender: Any) { UIResponder._stored = self }
}

class MenuKeyView: UIView {
    var onOptionKey: (() -> Void)?
    private var timer: Timer?

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        becomeFirstResponder()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, !self.isFirstResponder else { return }
                let cur = UIResponder.currentFirstResponder
                let cls = String(describing: type(of: cur as AnyObject))
                guard !(cur is UITextField), !(cur is UITextView),
                      !cls.contains("WKContent"), !cls.contains("WKWebView") else { return }
                self.becomeFirstResponder()
            }
        }
    }

    override func removeFromSuperview() {
        timer?.invalidate(); timer = nil
        super.removeFromSuperview()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if let key = press.key,
               key.keyCode == .keyboardLeftAlt || key.keyCode == .keyboardRightAlt {
                DispatchQueue.main.async { self.onOptionKey?() }
                handled = true
            }
        }
        if !handled { super.pressesBegan(presses, with: event) }
    }
}

struct MenuKeyHandler: UIViewRepresentable {
    let action: () -> Void
    func makeUIView(context: Context) -> MenuKeyView {
        let v = MenuKeyView()
        v.onOptionKey = action
        DispatchQueue.main.async { v.becomeFirstResponder() }
        return v
    }
    func updateUIView(_ v: MenuKeyView, context: Context) { v.onOptionKey = action }
}

// MARK: - Desktop View
struct DesktopView: View {
    @EnvironmentObject var desktopVM: DesktopViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var weatherService: WeatherService

    var body: some View {
        GeometryReader { geo in
            let screenSize = geo.size
            ZStack {
                // Sfondo grigio scuro
                LinearGradient(
                    colors: [
                        Color(red: 0.13, green: 0.13, blue: 0.14),
                        Color(red: 0.09, green: 0.09, blue: 0.10),
                        Color(red: 0.06, green: 0.06, blue: 0.07)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                // Finestre aperte
                ForEach(desktopVM.openWindows.filter { !$0.isMinimized }) { window in
                    WindowView(window: window, screenSize: screenSize)
                        .environmentObject(desktopVM)
                        .zIndex(Double(desktopVM.openWindows.firstIndex(where: { $0.id == window.id }) ?? 0) + 10)
                }

                // Option key handler
                MenuKeyHandler { desktopVM.toggleStartMenu() }
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)

                // Snap preview
                if let snap = desktopVM.snapPreview {
                    let frame = snap.previewFrame(for: screenSize)
                    RoundedRectangle(cornerRadius: snap.cornerRadius, style: .continuous)
                        .fill(.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: snap.cornerRadius, style: .continuous)
                                .stroke(.white.opacity(0.28), lineWidth: 1.5)
                        )
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .allowsHitTesting(false)
                        .animation(.spring(duration: 0.18, bounce: 0.05), value: snap)
                        .zIndex(150)
                }

                // Taskbar + Start Menu
                VStack {
                    Spacer()
                    if desktopVM.showStartMenu {
                        StartMenuView()
                            .environmentObject(desktopVM)
                            .environmentObject(authVM)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)),
                                removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .bottom))
                            ))
                            .padding(.bottom, 12)
                            .zIndex(300)
                    }
                    if desktopVM.taskbarVisible {
                        TaskbarView()
                            .environmentObject(desktopVM)
                            .environmentObject(authVM)
                            .environmentObject(weatherService)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 16)
                            .zIndex(200)
                    }
                }
                .animation(.spring(duration: 0.4, bounce: 0.08), value: desktopVM.showStartMenu)
                .animation(.spring(duration: 0.35, bounce: 0.05), value: desktopVM.taskbarVisible)
                .zIndex(100)
            }
            .onTapGesture {
                if desktopVM.showStartMenu {
                    withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
                        desktopVM.showStartMenu = false
                        desktopVM.taskbarPinned = false
                        desktopVM.hideTaskbarIfNeeded()
                    }
                }
            }
            // Hover in basso: UIHoverGestureRecognizer sulla UIWindow
            .onAppear {
                installWindowHoverDetector(screenHeight: screenSize.height)
            }
        }
        .ignoresSafeArea()
    }

    private func installWindowHoverDetector(screenHeight: CGFloat) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first else { return }

            // Rimuovi eventuali detector precedenti
            window.gestureRecognizers?
                .filter { $0 is UIHoverGestureRecognizer && ($0.name == "AppleDeskHover") }
                .forEach { window.removeGestureRecognizer($0) }

            let hover = UIHoverGestureRecognizer(
                target: HoverCoordinator.shared,
                action: #selector(HoverCoordinator.handleHover(_:))
            )
            hover.name = "AppleDeskHover"
            HoverCoordinator.shared.screenHeight = screenHeight
            HoverCoordinator.shared.onTrigger = { desktopVM.showTaskbar() }
            window.addGestureRecognizer(hover)
        }
    }
}

// Coordinator globale per l'hover — vive fuori dalla view
class HoverCoordinator: NSObject {
    static let shared = HoverCoordinator()
    var screenHeight: CGFloat = 0
    var onTrigger: (() -> Void)?
    private var hoverTimer: Timer?

    @objc func handleHover(_ g: UIHoverGestureRecognizer) {
        let y = g.location(in: nil).y
        if y > screenHeight - 44 {
            guard hoverTimer == nil else { return }
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                DispatchQueue.main.async { self?.onTrigger?() }
                self?.hoverTimer = nil
            }
        } else {
            hoverTimer?.invalidate()
            hoverTimer = nil
        }
    }
}

// MARK: - Start Menu
struct StartMenuView: View {
    @EnvironmentObject var desktopVM: DesktopViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var results: [AppItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return desktopVM.allApps.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "applelogo")
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.75))
                Text("Ciao, \(authVM.username)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                TextField("Cerca app...", text: $query)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($searchFocused)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12), lineWidth: 0.8))
            .padding(.horizontal, 24)
            .onAppear { searchFocused = true }

            if !results.isEmpty {
                VStack(spacing: 2) {
                    ForEach(results) { app in
                        Button {
                            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                                desktopVM.openApp(app)
                                desktopVM.toggleStartMenu()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 34, height: 34)
                                    if let asset = app.iconAsset {
                                        Image(asset)
                                            .resizable().scaledToFit()
                                            .frame(width: 26, height: 26)
                                    } else {
                                        Image(systemName: app.icon)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(app.color == .clear ? .white : app.color)
                                    }
                                }
                                Text(app.name)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 14)
            } else if !query.isEmpty {
                Text("Nessuna app trovata")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 20)
            }

            Spacer()

            Divider().background(.white.opacity(0.1)).padding(.horizontal, 24)

            HStack(spacing: 0) {
                Button {
                    desktopVM.toggleStartMenu()
                    desktopVM.restart(authVM: authVM)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 13))
                        Text("Riavvia").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                }.buttonStyle(.plain)

                Divider().frame(height: 20).background(.white.opacity(0.15))

                Button { desktopVM.shutdown() } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "power").font(.system(size: 13))
                        Text("Spegni").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.red.opacity(0.75))
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                }.buttonStyle(.plain)
            }
        }
        .frame(width: 380, height: 460)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 40, y: 20)
    }
}
