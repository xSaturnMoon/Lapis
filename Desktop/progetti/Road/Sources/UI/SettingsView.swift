import SwiftUI

struct SettingsView: View {
    @StateObject var auth = AuthManager.shared
    @State private var showingAuthModal = false
    @State private var showLogoutAlert = false
    @AppStorage("theme") private var theme: String = "Sistema"
    let themes = ["Sistema", "Chiaro", "Scuro"]

    var appVersion: String {
        if let url = Bundle.main.url(forResource: "version", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let v = json["version"] as? String { return v }
        return "1.0.0"
    }

    var body: some View {
        NavigationStack {
            Form {
                if let user = auth.currentUser {
                    Section {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 50, height: 50)
                                Text(String(user.email.prefix(1)).uppercased())
                                    .font(.title2.bold())
                                    .foregroundStyle(.blue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Account") {
                        Button(role: .destructive) {
                            showLogoutAlert = true
                        } label: {
                            Text("Esci")
                        }
                    }
                } else {
                    Section {
                        Button {
                            showingAuthModal = true
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.title2)
                                Text("Accedi o Registrati")
                            }
                        }
                    }
                }

                Section("Aspetto") {
                    Picker("Tema", selection: $theme) {
                        ForEach(themes, id: \.self) { Text($0) }
                    }
                }

                Section("App") {
                    HStack {
                        Text("Versione")
                        Spacer()
                        Text(appVersion).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Esci dall'account?", isPresented: $showLogoutAlert) {
                Button("Esci", role: .destructive) { auth.logout() }
                Button("Annulla", role: .cancel) {}
            }
            .sheet(isPresented: $showingAuthModal) {
                AuthView(isPresented: $showingAuthModal)
            }
        }
    }
}
