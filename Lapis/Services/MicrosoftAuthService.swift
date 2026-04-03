import Foundation
import AuthenticationServices

// MARK: - Microsoft Auth Service (REAL OAuth)
class MicrosoftAuthService: ObservableObject {
    @Published var isAuthenticating = false
    @Published var error: String? = nil
    
    // Microsoft OAuth endpoints
    private let clientId = "00000000402b5328" // Standard Minecraft client ID
    private let redirectUri = "https://login.live.com/oauth20_desktop.srf"
    private let authURL = "https://login.live.com/oauth20_authorize.srf"
    private let tokenURL = "https://login.live.com/oauth20_token.srf"
    private let xboxAuthURL = "https://user.auth.xboxlive.com/user/authenticate"
    private let xstsURL = "https://xsts.auth.xboxlive.com/xsts/authorize"
    private let mcAuthURL = "https://api.minecraftservices.com/authentication/login_with_xbox"
    private let mcProfileURL = "https://api.minecraftservices.com/minecraft/profile"
    
    /// Start the full Microsoft → Xbox → Minecraft authentication flow
    func authenticate(appState: AppState) async {
        await MainActor.run { isAuthenticating = true; error = nil }
        
        do {
            // Step 1: Get Microsoft OAuth code via browser
            let code = try await getMicrosoftCode()
            
            // Step 2: Exchange code for Microsoft token
            let msToken = try await exchangeCodeForToken(code: code)
            
            // Step 3: Authenticate with Xbox Live
            let (xblToken, userHash) = try await authenticateXboxLive(msToken: msToken)
            
            // Step 4: Get XSTS token
            let xstsToken = try await getXSTSToken(xblToken: xblToken)
            
            // Step 5: Authenticate with Minecraft
            let mcToken = try await authenticateMinecraft(xstsToken: xstsToken, userHash: userHash)
            
            // Step 6: Get Minecraft profile
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
                self.error = "Authentication failed: \(error.localizedDescription)"
                self.isAuthenticating = false
            }
        }
    }
    
    // MARK: Step 1 - Microsoft OAuth via ASWebAuthenticationSession
    private func getMicrosoftCode() async throws -> String {
        let scope = "XboxLive.signin offline_access"
        let urlString = "\(authURL)?client_id=\(clientId)&response_type=code&redirect_uri=\(redirectUri)&scope=\(scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scope)"
        
        guard let url = URL(string: urlString) else {
            throw AuthError.invalidURL
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "https") { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.noCode)
                    return
                }
                
                continuation.resume(returning: code)
            }
            session.prefersEphemeralWebBrowserSession = false
            
            DispatchQueue.main.async {
                session.start()
            }
        }
    }
    
    // MARK: Step 2 - Exchange code for Microsoft token
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
    
    // MARK: Step 3 - Xbox Live authentication
    private func authenticateXboxLive(msToken: String) async throws -> (String, String) {
        guard let url = URL(string: xboxAuthURL) else { throw AuthError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
    
    // MARK: Step 4 - XSTS token
    private func getXSTSToken(xblToken: String) async throws -> String {
        guard let url = URL(string: xstsURL) else { throw AuthError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
    
    // MARK: Step 5 - Minecraft authentication
    private func authenticateMinecraft(xstsToken: String, userHash: String) async throws -> String {
        guard let url = URL(string: mcAuthURL) else { throw AuthError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "identityToken": "XBL3.0 x=\(userHash);\(xstsToken)"
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw AuthError.mcAuthFailed
        }
        
        return accessToken
    }
    
    // MARK: Step 6 - Get Minecraft profile
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
    case invalidURL
    case noCode
    case tokenParseFailed
    case xboxFailed
    case xstsFailed
    case mcAuthFailed
    case profileFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid authentication URL"
        case .noCode: return "No authorization code received"
        case .tokenParseFailed: return "Failed to parse Microsoft token"
        case .xboxFailed: return "Xbox Live authentication failed"
        case .xstsFailed: return "XSTS token retrieval failed"
        case .mcAuthFailed: return "Minecraft authentication failed"
        case .profileFailed: return "Failed to get Minecraft profile"
        }
    }
}
