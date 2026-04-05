import Foundation
import WebKit
import SwiftUI

// MARK: - Microsoft Auth Service (REAL OAuth via WKWebView)
class MicrosoftAuthService: ObservableObject {
    @Published var isAuthenticating = false
    @Published var showWebView = false
    @Published var error: String? = nil
    
    let clientId = "00000000402b5328"
    let redirectUri = "https://login.live.com/oauth20_desktop.srf"
    
    private let tokenURL = "https://login.live.com/oauth20_token.srf"
    private let xboxAuthURL = "https://user.auth.xboxlive.com/user/authenticate"
    private let xstsURL = "https://xsts.auth.xboxlive.com/xsts/authorize"
    private let mcAuthURL = "https://api.minecraftservices.com/authentication/login_with_xbox"
    private let mcProfileURL = "https://api.minecraftservices.com/minecraft/profile"
    
    var authURL: URL {
        let scope = "XboxLive.signin offline_access"
        let urlString = "https://login.live.com/oauth20_authorize.srf?client_id=\(clientId)&response_type=code&redirect_uri=\(redirectUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&scope=\(scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
        return URL(string: urlString)!
    }
    
    /// Called when WKWebView detects the redirect with the auth code
    func handleAuthCode(_ code: String, appState: AppState) {
        showWebView = false
        isAuthenticating = true
        error = nil
        
        Task {
            do {
                let msToken = try await exchangeCodeForToken(code: code)
                let (xblToken, userHash) = try await authenticateXboxLive(msToken: msToken)
                let xstsToken = try await getXSTSToken(xblToken: xblToken)
                let mcToken = try await authenticateMinecraft(xstsToken: xstsToken, userHash: userHash)
                let (name, uuid) = try await getMinecraftProfile(accessToken: mcToken)
                
                await MainActor.run {
                    appState.isLoggedIn = true
                    appState.playerName = name
                    appState.playerUUID = uuid
                    appState.accessToken = mcToken
                    self.isAuthenticating = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isAuthenticating = false
                }
            }
        }
    }
    
    // MARK: - Token Exchange
    private func exchangeCodeForToken(code: String) async throws -> String {
        guard let url = URL(string: tokenURL) else { throw AuthError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "client_id=\(clientId)&code=\(code)&grant_type=authorization_code&redirect_uri=\(redirectUri)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw AuthError.tokenParseFailed
        }
        return accessToken
    }
    
    // MARK: - Xbox Live
    private func authenticateXboxLive(msToken: String) async throws -> (String, String) {
        guard let url = URL(string: xboxAuthURL) else { throw AuthError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = [
            "Properties": [
                "AuthMethod": "RPS",
                "SiteName": "user.auth.xboxlive.com",
                "RpsTicket": "d=\(msToken)"
            ],
            "RelyingParty": "http://auth.xboxlive.com",
            "TokenType": "JWT"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["Token"] as? String,
              let claims = json["DisplayClaims"] as? [String: Any],
              let xui = (claims["xui"] as? [[String: String]])?.first,
              let userHash = xui["uhs"] else {
            throw AuthError.xboxFailed
        }
        return (token, userHash)
    }
    
    // MARK: - XSTS
    private func getXSTSToken(xblToken: String) async throws -> String {
        guard let url = URL(string: xstsURL) else { throw AuthError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = [
            "Properties": [
                "SandboxId": "RETAIL",
                "UserTokens": [xblToken]
            ],
            "RelyingParty": "rp://api.minecraftservices.com/",
            "TokenType": "JWT"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["Token"] as? String else {
            throw AuthError.xstsFailed
        }
        return token
    }
    
    // MARK: - Minecraft Auth
    private func authenticateMinecraft(xstsToken: String, userHash: String) async throws -> String {
        guard let url = URL(string: mcAuthURL) else { throw AuthError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["identityToken": "XBL3.0 x=\(userHash);\(xstsToken)"]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw AuthError.mcAuthFailed
        }
        return accessToken
    }
    
    // MARK: - Minecraft Profile
    private func getMinecraftProfile(accessToken: String) async throws -> (String, String) {
        guard let url = URL(string: mcProfileURL) else { throw AuthError.invalidURL }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String,
              let uuid = json["id"] as? String else {
            throw AuthError.profileFailed
        }
        return (name, uuid)
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case invalidURL, noCode, tokenParseFailed, xboxFailed, xstsFailed, mcAuthFailed, profileFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noCode: return "No authorization code received"
        case .tokenParseFailed: return "Failed to parse Microsoft token"
        case .xboxFailed: return "Xbox Live authentication failed"
        case .xstsFailed: return "XSTS token failed"
        case .mcAuthFailed: return "Minecraft authentication failed"
        case .profileFailed: return "Failed to get Minecraft profile"
        }
    }
}

// MARK: - WKWebView for Microsoft Login
struct MicrosoftLoginWebView: UIViewRepresentable {
    let authService: MicrosoftAuthService
    @EnvironmentObject var appState: AppState
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.load(URLRequest(url: authService.authURL))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(authService: authService, appState: appState)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let authService: MicrosoftAuthService
        let appState: AppState
        
        init(authService: MicrosoftAuthService, appState: AppState) {
            self.authService = authService
            self.appState = appState
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               url.absoluteString.starts(with: authService.redirectUri) {
                // Extract the auth code from the redirect URL
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                    authService.handleAuthCode(code, appState: appState)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
