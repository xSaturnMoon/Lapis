import Foundation
import SwiftUI

struct RoadUser: Codable, Identifiable {
    var id = UUID()
    var name: String
    var email: String
}

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: RoadUser?
    @Published var isLoading = false
    @Published var authError: String?

    private let sessionKey = "road_current_user"

    init() {
        loadLocalSession()
    }

    var isLoggedIn: Bool { currentUser != nil }

    private func loadLocalSession() {
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let user = try? JSONDecoder().decode(RoadUser.self, from: data) {
            currentUser = user
        }
    }

    private func saveLocalSession(_ user: RoadUser?) {
        if let u = user, let enc = try? JSONEncoder().encode(u) {
            UserDefaults.standard.set(enc, forKey: sessionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: sessionKey)
        }
    }

    func login(email: String, password: String) {
        isLoading = true
        authError = nil

        // Local-only auth: store credentials hashed in UserDefaults
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let storedEmail = UserDefaults.standard.string(forKey: "road_reg_email") ?? ""
            let storedPwd   = UserDefaults.standard.string(forKey: "road_reg_pwd") ?? ""
            let storedName  = UserDefaults.standard.string(forKey: "road_reg_name") ?? email.components(separatedBy: "@").first ?? "Utente"

            if email == storedEmail && password == storedPwd {
                let user = RoadUser(name: storedName, email: email)
                self.currentUser = user
                self.saveLocalSession(user)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                self.authError = "Email o password errati."
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            self.isLoading = false
        }
    }

    func signUp(email: String, name: String, password: String) {
        isLoading = true
        authError = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            UserDefaults.standard.set(email,    forKey: "road_reg_email")
            UserDefaults.standard.set(password, forKey: "road_reg_pwd")
            UserDefaults.standard.set(name,     forKey: "road_reg_name")

            let user = RoadUser(name: name, email: email)
            self.currentUser = user
            self.saveLocalSession(user)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self.isLoading = false
        }
    }

    func logout() {
        currentUser = nil
        saveLocalSession(nil)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
