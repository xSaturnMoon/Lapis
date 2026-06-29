import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var phase: AppPhase = .boot
    @Published var username: String = ""
    @Published var avatarColor: Color = .blue
    @Published var error: String? = nil

    private let usernameKey = "appledesk_username"
    private let passwordKey = "appledesk_password"
    private let colorKey    = "appledesk_avatarColor"
    private let loggedInKey = "appledesk_loggedIn"

    // MARK: Boot → auth or desktop
    func finishBoot() {
        let isLoggedIn = UserDefaults.standard.bool(forKey: loggedInKey)
        let savedUser  = UserDefaults.standard.string(forKey: usernameKey) ?? ""
        if isLoggedIn && !savedUser.isEmpty {
            username = savedUser
            loadAvatarColor()
            withAnimation { phase = .desktop }
        } else {
            withAnimation { phase = .auth }
        }
    }

    // MARK: Register
    func register(username: String, password: String, color: Color) {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Inserisci un username"; return
        }
        guard password.count >= 4 else {
            error = "Password minimo 4 caratteri"; return
        }
        UserDefaults.standard.set(username, forKey: usernameKey)
        UserDefaults.standard.set(password, forKey: passwordKey)
        UserDefaults.standard.set(true,     forKey: loggedInKey)
        saveColor(color)
        self.username = username
        self.avatarColor = color
        error = nil
        withAnimation { phase = .desktop }
    }

    // MARK: Login
    func login(username: String, password: String) {
        let savedUser = UserDefaults.standard.string(forKey: usernameKey) ?? ""
        let savedPass = UserDefaults.standard.string(forKey: passwordKey) ?? ""
        guard username == savedUser && password == savedPass else {
            error = "Credenziali errate"; return
        }
        UserDefaults.standard.set(true, forKey: loggedInKey)
        self.username = username
        loadAvatarColor()
        error = nil
        withAnimation { phase = .desktop }
    }

    // MARK: Logout
    func logout() {
        UserDefaults.standard.set(false, forKey: loggedInKey)
        withAnimation { phase = .auth }
    }

    // MARK: Color persistence
    private func saveColor(_ color: Color) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: UIColor(color), requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: colorKey)
        }
    }

    private func loadAvatarColor() {
        if let data = UserDefaults.standard.data(forKey: colorKey),
           let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) {
            avatarColor = Color(uiColor)
        }
    }
}
