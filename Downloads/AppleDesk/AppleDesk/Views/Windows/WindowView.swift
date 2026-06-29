import SwiftUI
import WebKit

// MARK: - Window View
// NOTE: The core WindowView struct is in WindowViewCore.swift
// Everything below are content views and title bar


// MARK: - Title Bar
struct WindowTitleBar: View {
    let title: String; let icon: String; let iconAsset: String?; let isActive: Bool; let isMaximized: Bool
    let onClose: () -> Void; let onMinimize: () -> Void; let onMaximize: () -> Void
    @State private var isHoveringButtons = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    CircleButton(color: Color(red:1.0,green:0.23,blue:0.19), icon:"xmark", showIcon: isHoveringButtons, action: onClose)
                    CircleButton(color: Color(red:1.0,green:0.72,blue:0.0), icon:"minus", showIcon: isHoveringButtons, action: onMinimize)
                    CircleButton(color: Color(red:0.16,green:0.80,blue:0.25),
                                 icon: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                                 showIcon: isHoveringButtons,
                                 action: onMaximize)
                }
                .frame(width: 80, alignment: .leading)
                .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHoveringButtons = h } }

                Spacer()

                HStack(spacing: 6) {
                    if let asset = iconAsset {
                        Image(asset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size:13,weight:.medium))
                            .foregroundStyle(isActive ? .white.opacity(0.9) : .white.opacity(0.5))
                    }
                    Text(title)
                        .font(.system(size:13,weight:.bold,design:.rounded))
                        .foregroundStyle(isActive ? .white : .white.opacity(0.55))
                }

                Spacer()
                Color.clear.frame(width: 80)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(LinearGradient(
                colors: [Color(red:0.18,green:0.18,blue:0.20).opacity(0.95),
                         Color(red:0.13,green:0.13,blue:0.15).opacity(0.95)],
                startPoint:.top, endPoint:.bottom))

            Rectangle().fill(.white.opacity(isActive ? 0.12 : 0.05)).frame(height: 1)
        }
    }
}

struct CircleButton: View {
    let color: Color; let icon: String; let showIcon: Bool; let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(.black.opacity(0.1), lineWidth: 0.5))
                if showIcon {
                    Image(systemName: icon)
                        .font(.system(size: 6.5, weight: .black))
                        .foregroundStyle(.black.opacity(0.65))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Content Router
struct WindowContent: View {
    let app: AppItem?
    var body: some View {
        Group {
            switch app?.id {
            case "chrome":  ChromeWindowContent()
            case "spotify": SpotifyWindowContent()
            default:
                switch app?.name {
                case "Terminale": TerminalWindowContent()
                case "Note":      NotesWindowContent()
                case "Codice":    CodeWindowContent()
                default:          GenericWindowContent(app: app)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Spotify Service (singleton per controllare il webView da ControlCenter)
@MainActor
class SpotifyService: ObservableObject {
    static let shared = SpotifyService()
    weak var webView: WKWebView?

    func playPause() {
        webView?.evaluateJavaScript("""
            (function(){
                var btn = document.querySelector('[data-testid="control-button-playpause"]');
                if(btn) { btn.click(); return true; }
                return false;
            })()
        """)
    }
    func nextTrack() {
        webView?.evaluateJavaScript("""
            var b = document.querySelector('[data-testid="control-button-skip-forward"]');
            if(b) b.click();
        """)
    }
    func previousTrack() {
        webView?.evaluateJavaScript("""
            var b = document.querySelector('[data-testid="control-button-skip-back"]');
            if(b) b.click();
        """)
    }
    func setRepeat(_ on: Bool) {
        webView?.evaluateJavaScript("""
            var b = document.querySelector('[data-testid="control-button-repeat"]');
            if(b) { var curr = b.getAttribute('aria-label') || '';
                var active = curr.toLowerCase().includes('on');
                if(active !== \(on ? "true" : "false")) b.click(); }
        """)
    }
}

// MARK: - Spotify Window
struct SpotifyWindowContent: View {
    @StateObject private var tab = SpotifyTab()

    var body: some View {
        ZStack {
            SpotifyWebView(tab: tab)
            if tab.isLoading {
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.green)
                        .symbolEffect(.pulse)
                    Text("Caricamento Spotify…")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.07))
    }
}

@MainActor
class SpotifyTab: ObservableObject {
    @Published var isLoading = true
    let webView: WKWebView

    init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // Disabilita AirPlay per evitare conflitti audio multipli
        config.allowsAirPlayForMediaPlayback = false
        let prefs = WKWebpagePreferences()
        prefs.preferredContentMode = .desktop
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        self.webView = WKWebView(frame: .zero, configuration: config)
        // User agent desktop Mac — evita il redirect a Spotify native
        self.webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        self.webView.allowsLinkPreview = false
    }
}

struct SpotifyWebView: UIViewRepresentable {
    @ObservedObject var tab: SpotifyTab

    func makeUIView(context: Context) -> WKWebView {
        tab.webView.navigationDelegate = context.coordinator
        SpotifyService.shared.webView = tab.webView
        var req = URLRequest(url: URL(string: "https://open.spotify.com")!)
        req.setValue("https://open.spotify.com", forHTTPHeaderField: "Referer")
        tab.webView.load(req)
        return tab.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: SpotifyWebView
        init(_ p: SpotifyWebView) { parent = p }

        func webView(_ wv: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let url = action.request.url
            // Blocca qualsiasi redirect verso l'app Spotify nativa o App Store
            if let scheme = url?.scheme,
               scheme == "spotify" || scheme == "itms-apps" || scheme == "itms" {
                decisionHandler(.cancel)
                return
            }
            // Blocca i redirect all'App Store o a links.spotify.com che aprono l'app
            if let host = url?.host,
               host.contains("apps.apple.com") || host == "links.spotify.com" {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ wv: WKWebView, didFinish navigation: WKNavigation!) {
            // Rimuove il banner "Open in app" di Spotify se presente
            wv.evaluateJavaScript("""
                var banner = document.querySelector('[data-testid="web-player-app-banner"]');
                if (banner) banner.remove();
                var smartBanner = document.querySelector('.smart-banner');
                if (smartBanner) smartBanner.remove();
            """)
            DispatchQueue.main.async { self.parent.tab.isLoading = false }
        }
        func webView(_ wv: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            DispatchQueue.main.async { self.parent.tab.isLoading = true }
        }
        func webView(_ wv: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            DispatchQueue.main.async { self.parent.tab.isLoading = false }
        }
    }
}

// MARK: - Chrome Models
enum ChromeTheme: String, CaseIterable, Identifiable, Codable {
    case spaceGray="Titanio Spazio"; case silver="Argento Lucido"; case royalBlue="Blu Zaffiro"
    case emerald="Verde Smeraldo"; case obsidian="Nero Ossidiana"; case roseGold="Oro Rosa"
    var id: String { rawValue }
    var colors: [Color] {
        switch self {
        case .spaceGray: return [Color(red:0.16,green:0.16,blue:0.18), Color(red:0.11,green:0.11,blue:0.13)]
        case .silver: return [Color(red:0.32,green:0.32,blue:0.34), Color(red:0.22,green:0.22,blue:0.24)]
        case .royalBlue: return [Color(red:0.12,green:0.16,blue:0.24), Color(red:0.07,green:0.09,blue:0.15)]
        case .emerald: return [Color(red:0.08,green:0.18,blue:0.13), Color(red:0.04,green:0.10,blue:0.07)]
        case .obsidian: return [Color(red:0.08,green:0.08,blue:0.09), Color(red:0.04,green:0.04,blue:0.05)]
        case .roseGold: return [Color(red:0.26,green:0.18,blue:0.18), Color(red:0.18,green:0.12,blue:0.12)]
        }
    }
}

struct ChromeShortcut: Identifiable, Codable, Equatable {
    let id: UUID; let name: String; let url: String
}

struct ChromeExtensionItem: Identifiable {
    let id = UUID(); let name: String; let icon: String; var enabled: Bool
}

@MainActor
class ChromeTabModel: ObservableObject, Identifiable, Equatable {
    let id = UUID()
    @Published var title: String = "Nuova scheda"
    @Published var urlText: String = ""
    @Published var loadedURL: URL? = nil
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false

    let webView: WKWebView

    init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        
        let prefs = WKWebpagePreferences()
        prefs.preferredContentMode = .desktop
        config.defaultWebpagePreferences = prefs
        
        if #available(iOS 15.4, *) {
            config.preferences.isElementFullscreenEnabled = true
        }

        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    }

    nonisolated static func == (lhs: ChromeTabModel, rhs: ChromeTabModel) -> Bool { lhs.id == rhs.id }
}

@MainActor
class ChromeSession: ObservableObject {
    @Published var tabs: [ChromeTabModel] = []
    @Published var activeTabID: UUID? = nil
    @Published var shortcuts: [ChromeShortcut] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(shortcuts) {
                UserDefaults.standard.set(data, forKey: "chrome_shortcuts")
            }
        }
    }
    @Published var history: [String] = []
    @Published var searchEngine: String = "Google"
    @Published var isIncognito: Bool = false
    @Published var activeTheme: ChromeTheme = .spaceGray
    @Published var googleAccount: GoogleAccount? = nil {
        didSet {
            if let acc = googleAccount, let data = try? JSONEncoder().encode(acc) {
                UserDefaults.standard.set(data, forKey: "chrome_account")
            } else {
                UserDefaults.standard.removeObject(forKey: "chrome_account")
            }
        }
    }
    @Published var zoomLevel: Double = UserDefaults.standard.double(forKey: "chrome_zoom") == 0 ? 1.0 : UserDefaults.standard.double(forKey: "chrome_zoom")
    @Published var extensions: [ChromeExtensionItem] = [
        ChromeExtensionItem(name:"AdBlock Premium", icon:"shield.fill", enabled:true),
        ChromeExtensionItem(name:"Dark Reader", icon:"moon.fill", enabled:false),
        ChromeExtensionItem(name:"1Password", icon:"key.fill", enabled:true),
        ChromeExtensionItem(name:"Grammarly", icon:"text.badge.checkmark", enabled:false),
        ChromeExtensionItem(name:"uBlock Origin", icon:"eye.slash.fill", enabled:true),
        ChromeExtensionItem(name:"JSON Viewer", icon:"curlybraces", enabled:true),
    ]

    init() {
        if let data = UserDefaults.standard.data(forKey: "chrome_shortcuts"),
           let saved = try? JSONDecoder().decode([ChromeShortcut].self, from: data) {
            self.shortcuts = saved
        } else {
            self.shortcuts = [
                ChromeShortcut(id:UUID(), name:"Google", url:"https://www.google.com"),
                ChromeShortcut(id:UUID(), name:"YouTube", url:"https://www.youtube.com"),
                ChromeShortcut(id:UUID(), name:"GitHub", url:"https://github.com"),
                ChromeShortcut(id:UUID(), name:"Wikipedia", url:"https://www.wikipedia.org"),
                ChromeShortcut(id:UUID(), name:"Reddit", url:"https://www.reddit.com"),
            ]
        }
        
        if let data = UserDefaults.standard.data(forKey: "chrome_account"),
           let acc = try? JSONDecoder().decode(GoogleAccount.self, from: data) {
            self.googleAccount = acc
        }
        addTab()
    }

    func setZoom(_ value: Double) {
        zoomLevel = value
        UserDefaults.standard.set(value, forKey: "chrome_zoom")
    }

    func addTab() { let t = ChromeTabModel(); tabs.append(t); activeTabID = t.id }

    func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return }
        if let idx = tabs.firstIndex(where: { $0.id == id }) {
            tabs.remove(at: idx)
            if activeTabID == id { activeTabID = tabs[max(0, idx - 1)].id }
        }
    }

    var activeTab: ChromeTabModel? { tabs.first { $0.id == activeTabID } }

    func toggleBookmark(urlStr: String, name: String) {
        var u = urlStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !u.hasPrefix("http") { u = "https://" + u }
        let norm: (String) -> String = { $0.replacingOccurrences(of:"https://",with:"").replacingOccurrences(of:"http://",with:"").trimmingCharacters(in:.init(charactersIn:"/")).lowercased() }
        if let i = shortcuts.firstIndex(where: { norm($0.url) == norm(u) }) { shortcuts.remove(at: i) }
        else { shortcuts.append(ChromeShortcut(id:UUID(), name: name.isEmpty ? (URL(string:u)?.host ?? "Sito") : name, url: u)) }
    }

    func isBookmarked(urlStr: String) -> Bool {
        var u = urlStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !u.hasPrefix("http") { u = "https://" + u }
        let norm: (String) -> String = { $0.replacingOccurrences(of:"https://",with:"").replacingOccurrences(of:"http://",with:"").trimmingCharacters(in:.init(charactersIn:"/")).lowercased() }
        return shortcuts.contains(where: { norm($0.url) == norm(u) })
    }
}

struct GoogleAccount: Codable { let email: String; let name: String }

// MARK: - Chrome Window
struct ChromeWindowContent: View {
    @StateObject private var session = ChromeSession()
    @State private var mockDownloads: [String] = []

    var body: some View {
        let themeColors = session.isIncognito ?
            [Color(red:0.10,green:0.10,blue:0.11), Color(red:0.05,green:0.05,blue:0.06)] :
            session.activeTheme.colors

        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(session.tabs) { tab in
                            let isActive = tab.id == session.activeTabID
                            HStack(spacing: 6) {
                                Image(systemName: session.isIncognito ? "eye.slash.fill" : "globe")
                                    .font(.system(size:10))
                                    .foregroundStyle(isActive ? .blue : .white.opacity(0.4))
                                Text(tab.title)
                                    .font(.system(size:11,weight:.semibold,design:.rounded))
                                    .foregroundStyle(isActive ? .white : .white.opacity(0.55))
                                    .frame(maxWidth: 100, alignment: .leading).lineLimit(1)
                                if session.tabs.count > 1 {
                                    Button { withAnimation { session.closeTab(tab.id) } } label: {
                                        Image(systemName:"xmark").font(.system(size:7,weight:.black))
                                            .foregroundStyle(.white.opacity(0.5))
                                            .padding(3).background(Color.white.opacity(0.08)).clipShape(Circle())
                                    }.buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 10).frame(height: 32)
                            .background(isActive ?
                                LinearGradient(colors:[.white.opacity(0.14),.white.opacity(0.07)],startPoint:.top,endPoint:.bottom) :
                                LinearGradient(colors:[.white.opacity(0.03),.clear],startPoint:.top,endPoint:.bottom))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius:8).stroke(.white.opacity(isActive ? 0.1 : 0.02),lineWidth:0.8))
                            .onTapGesture { withAnimation(.spring(duration:0.2)) { session.activeTabID = tab.id } }
                        }
                    }.padding(.horizontal, 8)
                }
                Button { withAnimation { session.addTab() } } label: {
                    Image(systemName:"plus").font(.system(size:11,weight:.bold)).foregroundStyle(.white.opacity(0.8))
                        .frame(width:26,height:26).background(Color.white.opacity(0.08)).clipShape(Circle())
                }.buttonStyle(.plain)

                if session.isIncognito {
                    Label("Incognito", systemImage:"eye.slash.fill")
                        .font(.system(size:10,weight:.bold)).foregroundStyle(.purple)
                        .padding(.horizontal,8).padding(.vertical,4)
                        .background(Color.purple.opacity(0.12)).clipShape(Capsule())
                        .padding(.trailing, 6)
                }
            }
            .padding(.vertical, 5)
            .background(LinearGradient(colors:themeColors,startPoint:.top,endPoint:.bottom))
            .overlay(VStack { Spacer(); Rectangle().fill(.black.opacity(0.25)).frame(height:1) })

            if let tab = session.activeTab {
                ChromeTabContentView(tab:tab, session:session, mockDownloads:$mockDownloads)
            }
        }
    }
}

// MARK: - Chrome Tab
struct ChromeTabContentView: View {
    @ObservedObject var tab: ChromeTabModel
    @ObservedObject var session: ChromeSession
    @Binding var mockDownloads: [String]

    @State private var showExtensions = false
    @State private var showTheme = false
    @State private var showHistory = false
    @State private var showDownloads = false
    @State private var showSecurity = false
    @State private var showSettings = false
    @State private var showAccount = false
    @State private var showAddShortcut = false
    @State private var newShortcutName = ""
    @State private var newShortcutURL = ""
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    var isYouTube: Bool { tab.loadedURL?.host?.contains("youtube.com") == true }

    var body: some View {
        let themeColors = session.isIncognito ?
            [Color(red:0.10,green:0.10,blue:0.11), Color(red:0.05,green:0.05,blue:0.06)] :
            session.activeTheme.colors

        VStack(spacing: 0) {
            // Address bar row
            HStack(spacing: 6) {
                // Nav buttons
                HStack(spacing: 10) {
                    Button { tab.webView.goBack() } label: {
                        Image(systemName:"chevron.left").font(.system(size:13,weight:.bold))
                            .foregroundStyle(tab.canGoBack ? .white : .white.opacity(0.2))
                    }.disabled(!tab.canGoBack).buttonStyle(.plain)
                    Button { tab.webView.goForward() } label: {
                        Image(systemName:"chevron.right").font(.system(size:13,weight:.bold))
                            .foregroundStyle(tab.canGoForward ? .white : .white.opacity(0.2))
                    }.disabled(!tab.canGoForward).buttonStyle(.plain)
                    Button { tab.isLoading ? tab.webView.stopLoading() : reloadPage() } label: {
                        Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise").font(.system(size:12,weight:.bold)).foregroundStyle(.white.opacity(0.8))
                    }.buttonStyle(.plain)
                    Button { goHome() } label: {
                        Image(systemName:"house.fill").font(.system(size:12)).foregroundStyle(.white.opacity(0.8))
                    }.buttonStyle(.plain)
                }.padding(.leading, 8)

                // URL bar
                HStack(spacing: 8) {
                    // Lock / security
                    Button { showSecurity = true } label: {
                        Image(systemName: tab.loadedURL == nil ? "magnifyingglass" : "lock.fill")
                            .font(.system(size:11,weight:.bold))
                            .foregroundStyle(tab.loadedURL == nil ? .white.opacity(0.35) : .green)
                    }.buttonStyle(.plain)
                    .popover(isPresented:$showSecurity) {
                        popoverContent(width: 260) {
                            VStack(alignment:.leading, spacing:8) {
                                HStack(spacing:6) {
                                    Image(systemName: tab.loadedURL == nil ? "globe" : "lock.fill")
                                        .foregroundStyle(tab.loadedURL == nil ? .yellow : .green)
                                    Text(tab.loadedURL == nil ? "Pagina locale" : "Connessione sicura")
                                        .font(.system(size:13,weight:.bold)).foregroundStyle(.white)
                                }
                                Text(tab.loadedURL == nil ? "Pagina protetta AppleDesk." :
                                     "SSL 256-bit — \(tab.loadedURL?.host ?? "sito") è crittografato.")
                                    .font(.system(size:11)).foregroundStyle(.white.opacity(0.65))
                            }
                        }
                    }

                    TextField("Cerca o inserisci URL", text:$tab.urlText)
                        .font(.system(size:12,weight:.medium,design:.rounded)).foregroundStyle(.white).tint(.blue)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                        .onSubmit { submitURL() }

                    if tab.loadedURL != nil {
                        Button { session.toggleBookmark(urlStr:tab.urlText, name:tab.title) } label: {
                            Image(systemName: session.isBookmarked(urlStr:tab.urlText) ? "star.fill" : "star")
                                .font(.system(size:12))
                                .foregroundStyle(session.isBookmarked(urlStr:tab.urlText) ? .yellow : .white.opacity(0.45))
                        }.buttonStyle(.plain)
                    }
                    if isYouTube {
                        Button {
                            tab.webView.evaluateJavaScript("document.querySelector('video')?.requestPictureInPicture()")
                        } label: {
                            Image(systemName:"pip.fill").font(.system(size:11)).foregroundStyle(.red)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal,10).padding(.vertical,6)
                .background(Color.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius:18, style:.continuous))
                .overlay(RoundedRectangle(cornerRadius:18).stroke(.white.opacity(0.1),lineWidth:0.8))

                // Right toolbar — ARROWEDGE .bottom così apre verso il basso
                HStack(spacing: 8) {
                    // Extensions
                    toolbarButton(icon:"puzzlepiece.extension.fill", action:{ showExtensions = true })
                        .popover(isPresented:$showExtensions) {
                            popoverContent(width: 260) {
                                VStack(alignment:.leading, spacing:4) {
                                    Text("Estensioni").font(.system(size:14,weight:.bold)).foregroundStyle(.white).padding(.bottom,4)
                                    ForEach($session.extensions) { $ext in
                                        HStack(spacing:10) {
                                            Image(systemName:ext.icon).font(.system(size:14)).foregroundStyle(ext.enabled ? .blue : .white.opacity(0.3)).frame(width:22)
                                            Text(ext.name).font(.system(size:13,weight:.medium)).foregroundStyle(.white)
                                            Spacer()
                                            Toggle("", isOn:$ext.enabled).labelsHidden()
                                        }
                                        .padding(.vertical,6).padding(.horizontal,4)
                                        .background(Color.white.opacity(ext.enabled ? 0.05 : 0)).clipShape(RoundedRectangle(cornerRadius:8))
                                    }
                                }
                            }
                        }

                    // Themes
                    toolbarButton(icon:"paintpalette.fill", action:{ showTheme = true })
                        .disabled(session.isIncognito)
                        .popover(isPresented:$showTheme) {
                            popoverContent(width: 200) {
                                VStack(alignment:.leading, spacing:4) {
                                    Text("Temi").font(.system(size:14,weight:.bold)).foregroundStyle(.white).padding(.bottom,4)
                                    ForEach(ChromeTheme.allCases) { theme in
                                        Button { withAnimation { session.activeTheme=theme; showTheme=false } } label: {
                                            HStack(spacing:10) {
                                                Circle().fill(theme.colors[0]).frame(width:16,height:16).overlay(Circle().stroke(.white.opacity(0.2),lineWidth:0.8))
                                                Text(theme.rawValue).font(.system(size:13,weight: session.activeTheme==theme ? .bold : .medium)).foregroundStyle(.white)
                                                Spacer()
                                                if session.activeTheme==theme { Image(systemName:"checkmark").font(.system(size:11,weight:.bold)).foregroundStyle(.blue) }
                                            }
                                            .padding(.vertical,7).padding(.horizontal,4)
                                            .background(Color.white.opacity(session.activeTheme==theme ? 0.07 : 0)).clipShape(RoundedRectangle(cornerRadius:8))
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                    // History
                    toolbarButton(icon:"clock.arrow.circlepath", action:{ showHistory = true })
                        .popover(isPresented:$showHistory) {
                            popoverContent(width: 280) {
                                VStack(alignment:.leading, spacing:8) {
                                    HStack {
                                        Text("Cronologia").font(.system(size:14,weight:.bold)).foregroundStyle(.white)
                                        Spacer()
                                        if !session.history.isEmpty {
                                            Button("Cancella") { session.history.removeAll() }
                                                .font(.system(size:12,weight:.bold)).foregroundStyle(.red).buttonStyle(.plain)
                                        }
                                    }
                                    if session.isIncognito {
                                        Text("Incognito: nessuna cronologia.").font(.system(size:12)).foregroundStyle(.purple)
                                    } else if session.history.isEmpty {
                                        Text("Nessun sito visitato.").font(.system(size:12)).foregroundStyle(.white.opacity(0.5))
                                    } else {
                                        ScrollView {
                                            VStack(alignment:.leading, spacing:6) {
                                                ForEach(session.history.prefix(50), id:\.self) { u in
                                                    Button { loadURL(u); showHistory=false } label: {
                                                        Text(u).font(.system(size:12)).foregroundStyle(.blue).lineLimit(1).frame(maxWidth:.infinity,alignment:.leading)
                                                    }.buttonStyle(.plain)
                                                    Divider().background(.white.opacity(0.08))
                                                }
                                            }
                                        }
                                        .frame(maxHeight: 300)
                                    }
                                }
                            }
                        }

                    // Downloads
                    toolbarButton(icon:"arrow.down.circle", action:{ showDownloads = true })
                        .popover(isPresented:$showDownloads) {
                            popoverContent(width: 240) {
                                VStack(alignment:.leading, spacing:8) {
                                    Text("Download").font(.system(size:14,weight:.bold)).foregroundStyle(.white)
                                    if mockDownloads.isEmpty {
                                        Text("Nessun file scaricato.").font(.system(size:12)).foregroundStyle(.white.opacity(0.5))
                                    } else {
                                        ForEach(mockDownloads, id:\.self) { d in
                                            HStack(spacing:8) {
                                                Image(systemName:"doc.fill").foregroundStyle(.blue)
                                                Text(d).font(.system(size:12)).lineLimit(1).foregroundStyle(.white)
                                            }.padding(.vertical,4)
                                        }
                                    }
                                }
                            }
                        }

                    // Account Google
                    Button { 
                        if session.googleAccount != nil {
                            showAccount = true
                        } else {
                            loadURL("https://accounts.google.com/ServiceLogin")
                        }
                    } label: {
                        if let acc = session.googleAccount {
                            ZStack {
                                Circle().fill(Color.blue.opacity(0.4)).frame(width:26,height:26)
                                Text(acc.name.prefix(1).uppercased()).font(.system(size:12,weight:.bold,design:.rounded)).foregroundStyle(.white)
                            }
                        } else {
                            Image(systemName:"person.crop.circle").font(.system(size:16)).foregroundStyle(.white.opacity(0.7))
                        }
                    }.buttonStyle(.plain)
                    .popover(isPresented:$showAccount) {
                        popoverContent(width: 280) {
                            if let acc = session.googleAccount {
                                VStack(spacing:12) {
                                    ZStack {
                                        Circle().fill(Color.blue.opacity(0.3)).frame(width:56,height:56)
                                        Text(acc.name.prefix(1).uppercased()).font(.system(size:24,weight:.bold,design:.rounded)).foregroundStyle(.white)
                                    }
                                    Text(acc.name).font(.system(size:15,weight:.bold)).foregroundStyle(.white)
                                    Text(acc.email).font(.system(size:12)).foregroundStyle(.white.opacity(0.6))
                                    Divider().background(.white.opacity(0.1))
                                    Button(role:.destructive) { 
                                        session.googleAccount = nil
                                        showAccount = false
                                        // Clear cookies to actually log out
                                        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date(timeIntervalSince1970: 0), completionHandler: {})
                                    } label: {
                                        Label("Disconnetti",systemImage:"rectangle.portrait.and.arrow.right")
                                            .font(.system(size:13)).foregroundStyle(.red)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Settings ⋮
                    toolbarButton(icon:"ellipsis", action:{ showSettings = true }, rotate: true)
                        .popover(isPresented:$showSettings) {
                            popoverContent(width: 260) {
                                VStack(alignment:.leading, spacing:6) {
                                    Text("Opzioni").font(.system(size:14,weight:.bold)).foregroundStyle(.white).padding(.bottom,4)
                                    Button { withAnimation { session.isIncognito.toggle(); showSettings=false } } label: {
                                        HStack {
                                            Image(systemName:session.isIncognito ? "eye.fill" : "eye.slash.fill")
                                            Text(session.isIncognito ? "Disattiva Incognito" : "Attiva Incognito").font(.system(size:13,weight:.medium))
                                            Spacer()
                                        }.foregroundStyle(session.isIncognito ? .blue : .purple).padding(.vertical,6)
                                    }.buttonStyle(.plain)
                                    Divider().background(.white.opacity(0.1))
                                    Text("Motore di ricerca").font(.system(size:11,weight:.bold)).foregroundStyle(.white.opacity(0.5)).padding(.top,4)
                                    HStack(spacing:6) {
                                        ForEach(["Google","DuckDuckGo","Bing"], id:\.self) { e in
                                            Button { session.searchEngine=e } label: {
                                                Text(e).font(.system(size:11,weight: session.searchEngine==e ? .bold : .regular))
                                                    .padding(.horizontal,8).padding(.vertical,4)
                                                    .background(session.searchEngine==e ? Color.blue : Color.white.opacity(0.1))
                                                    .clipShape(Capsule())
                                            }.buttonStyle(.plain)
                                        }
                                    }
                                    Divider().background(.white.opacity(0.1)).padding(.top,4)
                                    Text("Zoom pagina").font(.system(size:11,weight:.bold)).foregroundStyle(.white.opacity(0.5)).padding(.top,4)
                                    HStack(spacing:0) {
                                        Button { session.setZoom(max(0.5, session.zoomLevel - 0.1)) } label: {
                                            Image(systemName:"minus").font(.system(size:13,weight:.bold)).foregroundStyle(.white)
                                                .frame(width:36,height:32).background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius:8))
                                        }.buttonStyle(.plain)
                                        Spacer()
                                        Text("\(Int(session.zoomLevel * 100))%")
                                            .font(.system(size:14,weight:.bold,design:.rounded)).foregroundStyle(.white)
                                        Spacer()
                                        Button { session.setZoom(min(3.0, session.zoomLevel + 0.1)) } label: {
                                            Image(systemName:"plus").font(.system(size:13,weight:.bold)).foregroundStyle(.white)
                                                .frame(width:36,height:32).background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius:8))
                                        }.buttonStyle(.plain)
                                    }
                                    Button { session.setZoom(1.0) } label: {
                                        Text("Ripristina 100%").font(.system(size:11)).foregroundStyle(.white.opacity(0.4))
                                            .frame(maxWidth:.infinity)
                                    }.buttonStyle(.plain).padding(.top,2)
                                    Divider().background(.white.opacity(0.1)).padding(.top,4)
                                    Button { session.history.removeAll(); mockDownloads.removeAll(); showSettings=false } label: {
                                        HStack {
                                            Image(systemName:"trash.fill")
                                            Text("Pulisci dati locali").font(.system(size:13))
                                            Spacer()
                                        }.foregroundStyle(.red).padding(.vertical,6)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                }.padding(.trailing, 8)
            }
            .padding(.horizontal, 6).padding(.vertical, 6)
            .background(LinearGradient(colors:themeColors,startPoint:.top,endPoint:.bottom))

            // Bookmarks bar
            if !session.shortcuts.isEmpty {
                ScrollView(.horizontal, showsIndicators:false) {
                    HStack(spacing:10) {
                        Image(systemName:"star.fill").font(.system(size:10)).foregroundStyle(.yellow.opacity(0.7)).padding(.leading,12)
                        ForEach(session.shortcuts) { s in
                            Button { loadURL(s.url) } label: {
                                HStack(spacing:4) {
                                    Image(systemName:"globe").font(.system(size:10)).foregroundStyle(.blue.opacity(0.8))
                                    Text(s.name).font(.system(size:11,weight:.semibold,design:.rounded)).foregroundStyle(.white.opacity(0.85))
                                }
                                .padding(.horizontal,8).padding(.vertical,3)
                                .background(Color.white.opacity(0.07)).clipShape(Capsule())
                                .overlay(Capsule().stroke(.white.opacity(0.05),lineWidth:0.5))
                            }.buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation { session.shortcuts.removeAll { $0.id == s.id } }
                                } label: { Label("Rimuovi", systemImage: "trash") }
                            }
                        }
                        // Add shortcut
                        Button { showAddShortcut=true } label: {
                            Image(systemName:"plus").font(.system(size:10,weight:.bold)).foregroundStyle(.white.opacity(0.4))
                                .padding(.horizontal,8).padding(.vertical,3).background(Color.white.opacity(0.04)).clipShape(Capsule())
                        }.buttonStyle(.plain)
                        .popover(isPresented:$showAddShortcut) {
                            popoverContent(width:240) {
                                VStack(spacing:10) {
                                    Text("Aggiungi Scorciatoia").font(.system(size:14,weight:.bold)).foregroundStyle(.white)
                                    TextField("Nome", text:$newShortcutName).font(.system(size:13)).padding(8).background(Color.white.opacity(0.09)).clipShape(RoundedRectangle(cornerRadius:9))
                                    TextField("URL", text:$newShortcutURL).font(.system(size:13)).padding(8).background(Color.white.opacity(0.09)).clipShape(RoundedRectangle(cornerRadius:9)).autocorrectionDisabled().textInputAutocapitalization(.never)
                                    HStack {
                                        Button("Annulla") { showAddShortcut=false; newShortcutName=""; newShortcutURL="" }.font(.system(size:12)).foregroundStyle(.white.opacity(0.5))
                                        Spacer()
                                        Button("Aggiungi") {
                                            var u = newShortcutURL.trimmingCharacters(in:.whitespacesAndNewlines)
                                            if !u.hasPrefix("http") { u = "https://"+u }
                                            session.shortcuts.append(ChromeShortcut(id:UUID(), name:newShortcutName, url:u))
                                            newShortcutName=""; newShortcutURL=""; showAddShortcut=false
                                        }.font(.system(size:12,weight:.bold)).foregroundStyle(.blue).disabled(newShortcutName.isEmpty||newShortcutURL.isEmpty)
                                    }
                                }
                            }
                        }
                    }.padding(.vertical,5)
                }
                .background(themeColors.last ?? Color.black.opacity(0.18))
                .overlay(VStack { Spacer(); Rectangle().fill(.white.opacity(0.05)).frame(height:0.8) })
            }

            // Content area
            if tab.loadedURL != nil {
                ZStack {
                    WebViewRepresentable(tab:tab, session:session)
                    if tab.isLoading {
                        VStack {
                            ProgressView().tint(.blue).padding(14)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius:14))
                        }
                    }
                }
            } else {
                ChromeHomePage(session:session, onLoad:{ url in loadURL(url) },
                               onSubmit:{ submitURL() }, urlText:$tab.urlText,
                               showAddShortcut:$showAddShortcut,
                               newShortcutName:$newShortcutName, newShortcutURL:$newShortcutURL)
            }
        }
    }

    // Helper per popover con stile uniforme e dimensioni generose
    @ViewBuilder
    func popoverContent<Content: View>(width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(16)
        }
        .frame(width: width, alignment: .leading)
        .frame(minHeight: 100, maxHeight: 500)
        .background(Color(red:0.13,green:0.13,blue:0.16))
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    func toolbarButton(icon: String, action: @escaping () -> Void, rotate: Bool = false) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size:13,weight:.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .rotationEffect(rotate ? .degrees(90) : .zero)
        }.buttonStyle(.plain)
    }

    private func goHome() { tab.loadedURL=nil; tab.urlText=""; tab.title="Nuova scheda" }

    private func loadURL(_ urlStr: String) {
        var s = urlStr.trimmingCharacters(in:.whitespacesAndNewlines)
        if !s.hasPrefix("http") { s = "https://"+s }
        if let url = URL(string:s) { tab.loadedURL=url; tab.urlText=s; tab.title=url.host ?? "Sito web" }
    }

    private func reloadPage() {
        if let url = tab.loadedURL { tab.loadedURL=nil; DispatchQueue.main.asyncAfter(deadline:.now()+0.05) { tab.loadedURL=url } }
    }

    private func submitURL() {
        let text = tab.urlText.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let resolved: URL
        if text.hasPrefix("http://") || text.hasPrefix("https://") { resolved = URL(string:text) ?? URL(string:"https://www.google.com")! }
        else if text.contains(".") && !text.contains(" ") { resolved = URL(string:"https://"+text) ?? URL(string:"https://www.google.com")! }
        else {
            let enc = text.addingPercentEncoding(withAllowedCharacters:.urlQueryAllowed) ?? ""
            switch session.searchEngine {
            case "DuckDuckGo": resolved = URL(string:"https://duckduckgo.com/?q=\(enc)")!
            case "Bing": resolved = URL(string:"https://www.bing.com/search?q=\(enc)")!
            default: resolved = URL(string:"https://www.google.com/search?q=\(enc)")!
            }
        }
        tab.loadedURL=resolved; tab.urlText=resolved.absoluteString; tab.title=resolved.host ?? "Sito web"
    }
}

// MARK: - Chrome Home
struct ChromeHomePage: View {
    @ObservedObject var session: ChromeSession
    let onLoad: (String)->Void; let onSubmit: ()->Void
    @Binding var urlText: String
    @Binding var showAddShortcut: Bool
    @Binding var newShortcutName: String
    @Binding var newShortcutURL: String

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                let hour = Calendar.current.component(.hour, from:Date())
                let greeting = hour<13 ? "Buongiorno" : (hour<18 ? "Buon pomeriggio" : "Buonasera")
                let name = session.googleAccount?.name ?? "Miro"

                VStack(spacing:12) {
                    Text("\(greeting), \(name)")
                        .font(.system(size:22,weight:.bold,design:.rounded)).foregroundStyle(.white)
                    HStack(spacing:0) {
                        let googleLetters: [(String, Color)] = [("G",.blue),("o",.red),("o",.yellow),("g",.blue),("l",.green),("e",.red)]
                        ForEach(googleLetters.indices, id:\.self) { i in
                            Text(googleLetters[i].0).foregroundStyle(googleLetters[i].1)
                        }
                    }.font(.system(size:48,weight:.black,design:.rounded))
                    Text(session.isIncognito ? "INCOGNITO" : "CHROME PREMIUM")
                        .font(.system(size:9,weight:.bold,design:.rounded)).kerning(2)
                        .foregroundStyle(session.isIncognito ? .purple : .white.opacity(0.4))
                        .padding(.horizontal,10).padding(.vertical,4).background(Color.white.opacity(0.06)).clipShape(Capsule())
                }.padding(.top, 36)

                HStack(spacing:10) {
                    Image(systemName:"magnifyingglass").font(.system(size:14,weight:.bold)).foregroundStyle(.white.opacity(0.4))
                    TextField("Cerca con \(session.searchEngine)", text:$urlText).font(.system(size:14,weight:.medium,design:.rounded)).foregroundStyle(.white).onSubmit { onSubmit() }
                    Button { onSubmit() } label: { Image(systemName:"arrow.right.circle.fill").font(.system(size:18)).foregroundStyle(.blue) }.buttonStyle(.plain)
                }
                .padding(.horizontal,16).padding(.vertical,10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius:22,style:.continuous))
                .frame(maxWidth:400)

                // Shortcuts grid
                LazyVGrid(columns:[GridItem(.adaptive(minimum:75,maximum:90))], spacing:16) {
                    ForEach(session.shortcuts) { s in
                        Button { onLoad(s.url) } label: {
                            VStack(spacing:8) {
                                ZStack {
                                    Circle().fill(LinearGradient(colors:[.white.opacity(0.12),.white.opacity(0.04)],startPoint:.topLeading,endPoint:.bottomTrailing))
                                        .frame(width:48,height:48).overlay(Circle().stroke(.white.opacity(0.08),lineWidth:1))
                                    Image(systemName:"globe").font(.system(size:20,weight:.light)).foregroundStyle(.white.opacity(0.8))
                                }
                                Text(s.name).font(.system(size:11,weight:.semibold,design:.rounded)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                            }
                        }.buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation { session.shortcuts.removeAll { $0.id == s.id } }
                            } label: { Label("Rimuovi", systemImage: "trash") }
                        }
                    }
                }.frame(maxWidth:360).padding(.bottom,40)
            }
        }
        .frame(maxWidth:.infinity, maxHeight:.infinity)
        .background(LinearGradient(colors:session.isIncognito ? [Color(red:0.10,green:0.10,blue:0.11), Color(red:0.05,green:0.05,blue:0.06)] : session.activeTheme.colors, startPoint:.top, endPoint:.bottom))
    }
}

// MARK: - WebView
struct WebViewRepresentable: UIViewRepresentable {
    @ObservedObject var tab: ChromeTabModel
    @ObservedObject var session: ChromeSession

    func makeUIView(context:Context) -> WKWebView {
        let wv = tab.webView
        wv.navigationDelegate = context.coordinator
        if let url = tab.loadedURL { wv.load(URLRequest(url:url)) }
        wv.evaluateJavaScript("document.body.style.zoom = '\(session.zoomLevel)'")
        return wv
    }

    func updateUIView(_ uiView:WKWebView, context:Context) {
        uiView.evaluateJavaScript("document.body.style.zoom = '\(session.zoomLevel)'")
        guard let target = tab.loadedURL else { return }
        let cur = uiView.url?.absoluteString ?? ""
        let tgt = target.absoluteString
        if cur != tgt && cur+"/" != tgt && tgt+"/" != cur {
            uiView.load(URLRequest(url:target))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable
        init(_ p: WebViewRepresentable) { parent = p }

        func webView(_ wv:WKWebView, didFinish navigation:WKNavigation!) {
            DispatchQueue.main.async {
                wv.evaluateJavaScript("document.body.style.zoom = '\(self.parent.session.zoomLevel)'")
                self.parent.tab.isLoading = false
                if let url = wv.url {
                    self.parent.tab.urlText = url.absoluteString
                    self.parent.tab.title = wv.title?.isEmpty == false ? wv.title! : (url.host ?? "Sito web")
                    if !self.parent.session.isIncognito {
                        let s = url.absoluteString
                        if self.parent.session.history.first != s {
                            self.parent.session.history.insert(s, at:0)
                            if self.parent.session.history.count > 100 { self.parent.session.history.removeLast() }
                        }
                    }
                }
                self.parent.tab.canGoBack = wv.canGoBack
                self.parent.tab.canGoForward = wv.canGoForward
                
                // Sync Google Account state based on cookies
                WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                    let hasGoogleAuth = cookies.contains(where: { $0.domain.contains("google.com") && ($0.name == "SID" || $0.name == "SAPISID") })
                    DispatchQueue.main.async {
                        if hasGoogleAuth && self.parent.session.googleAccount == nil {
                            self.parent.session.googleAccount = GoogleAccount(email: "Utente Google", name: "Utente")
                        } else if !hasGoogleAuth && self.parent.session.googleAccount != nil {
                            self.parent.session.googleAccount = nil
                        }
                    }
                }
            }
        }
        func webView(_ wv:WKWebView, didStartProvisionalNavigation navigation:WKNavigation!) {
            DispatchQueue.main.async { self.parent.tab.isLoading=true; self.parent.tab.canGoBack=wv.canGoBack; self.parent.tab.canGoForward=wv.canGoForward }
        }
        func webView(_ wv:WKWebView, didFail navigation:WKNavigation!, withError error:Error) {
            DispatchQueue.main.async { self.parent.tab.isLoading=false }
        }
    }
}

// MARK: - Terminal
struct TerminalWindowContent: View {
    @State private var output:[String]=["AppleDesk Terminal v1.2","Digita 'help' per i comandi.",""]
    @State private var input=""
    var body: some View {
        VStack(spacing:0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment:.leading,spacing:4) {
                        ForEach(Array(output.enumerated()),id:\.offset) { _,line in
                            Text(line).font(.system(size:13,design:.monospaced))
                                .foregroundStyle(line.hasPrefix("→") ? .cyan : (line.hasPrefix("➜") ? .green : .white.opacity(0.85)))
                                .frame(maxWidth:.infinity,alignment:.leading)
                        }
                    }.padding(14).id("bottom")
                }.onChange(of:output.count) { _,_ in proxy.scrollTo("bottom",anchor:.bottom) }
            }
            HStack(spacing:8) {
                Text("➜").font(.system(size:13,design:.monospaced)).foregroundStyle(.green)
                TextField("",text:$input).font(.system(size:13,design:.monospaced)).foregroundStyle(.white).tint(.green)
                    .autocorrectionDisabled().textInputAutocapitalization(.never).onSubmit { runCommand() }
            }.padding(.horizontal,14).padding(.vertical,10).background(.black.opacity(0.4))
        }.background(.black.opacity(0.65))
    }
    private func runCommand() {
        let cmd=input.trimmingCharacters(in:.whitespaces); output.append("➜ "+cmd)
        switch cmd.lowercased() {
        case "help": output+=["  help — comandi disponibili","  clear — pulisci terminale","  whoami — utente","  date — data e ora","  system — info hardware"]
        case "clear": output=[""]
        case "whoami": output.append("→ appledesk_user")
        case "date": output.append("→ \(Date().formatted(date:.long,time:.standard))")
        case "system": output+=["→ CPU: Apple M4 Pro","→ RAM: 16 GB","→ OS: AppleDesk 1.0"]
        case "": break
        default: output.append("→ comando non trovato: \(cmd)")
        }
        input=""
    }
}

// MARK: - Notes
struct NotesWindowContent: View {
    @State private var text=""
    var body: some View {
        TextEditor(text:$text).font(.system(size:15,design:.rounded)).foregroundStyle(.white)
            .scrollContentBackground(.hidden).background(.clear).padding(16).background(.black.opacity(0.25))
    }
}

// MARK: - Code Editor
struct CodeWindowContent: View {
    @State private var code="// AppleDesk Code Editor\nimport SwiftUI\n\nfunc hello() {\n    print(\"Ciao da AppleDesk!\")\n}\n"
    var body: some View {
        TextEditor(text:$code).font(.system(size:13,design:.monospaced)).foregroundStyle(.green.opacity(0.9))
            .scrollContentBackground(.hidden).background(.clear).padding(16).background(.black.opacity(0.5))
    }
}

// MARK: - Generic
struct GenericWindowContent: View {
    let app: AppItem?
    var body: some View {
        VStack(spacing:20) {
            Image(systemName:app?.icon ?? "app.fill").font(.system(size:54,weight:.light)).foregroundStyle(app?.color ?? .white)
            Text(app?.name ?? "App").font(.system(size:20,weight:.bold,design:.rounded)).foregroundStyle(.white)
            Text("In sviluppo…").font(.system(size:13)).foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal,14).padding(.vertical,6).background(Color.white.opacity(0.04)).clipShape(Capsule())
        }.frame(maxWidth:.infinity,maxHeight:.infinity).background(.black.opacity(0.3))
    }
}