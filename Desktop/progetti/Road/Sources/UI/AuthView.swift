import SwiftUI

struct AuthView: View {
    @Binding var isPresented: Bool
    @StateObject private var auth = AuthManager.shared

    @State private var isLogin = true
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @FocusState private var focused: Field?

    enum Field { case email, name, password, confirm }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "0A0A0F"), Color(hex: "101020")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle glow
            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: -60, y: -120)

            VStack(spacing: 0) {
                Spacer()

                // Logo / title
                VStack(spacing: 8) {
                    Image(systemName: "road.lanes")
                        .font(.system(size: 44, weight: .thin))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Road")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Il tuo navigatore per 125cc")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.bottom, 48)

                // Glass card
                VStack(spacing: 16) {
                    // Segment
                    HStack(spacing: 0) {
                        segBtn("Accedi", selected: isLogin) { withAnimation(.spring(response: 0.3)) { isLogin = true } }
                        segBtn("Registrati", selected: !isLogin) { withAnimation(.spring(response: 0.3)) { isLogin = false } }
                    }
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 4)

                    if !isLogin {
                        glassField("Nome", text: $name, icon: "person")
                            .focused($focused, equals: .name)
                    }

                    glassField("Email", text: $email, icon: "envelope", keyboard: .emailAddress)
                        .focused($focused, equals: .email)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    glassField("Password", text: $password, icon: "lock", secure: true)
                        .focused($focused, equals: .password)

                    if !isLogin {
                        glassField("Conferma Password", text: $confirmPassword, icon: "lock.fill", secure: true)
                            .focused($focused, equals: .confirm)
                    }

                    if let err = auth.authError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    // CTA
                    Button {
                        focused = nil
                        if isLogin {
                            auth.login(email: email, password: password)
                        } else {
                            guard password == confirmPassword else {
                                auth.authError = "Le password non coincidono."
                                return
                            }
                            auth.signUp(email: email, name: name, password: password)
                        }
                    } label: {
                        ZStack {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(isLogin ? "Entra" : "Crea account")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(colors: [Color(hex: "2563EB"), Color(hex: "1D4ED8")],
                                          startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(auth.isLoading)
                    .padding(.top, 4)
                }
                .padding(24)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.08), lineWidth: 1))
                .padding(.horizontal, 24)

                Spacer()
                Spacer()
            }
        }
    }

    @ViewBuilder
    func segBtn(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(selected ? .white : .white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected ? .white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .padding(2)
        }
    }

    @ViewBuilder
    func glassField(_ placeholder: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType = .default, secure: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 20)

            if secure {
                SecureField(placeholder, text: text)
                    .foregroundStyle(.white)
                    .tint(.blue)
            } else {
                TextField(placeholder, text: text)
                    .foregroundStyle(.white)
                    .tint(.blue)
                    .keyboardType(keyboard)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.07), lineWidth: 1))
    }
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)         / 255
        self.init(red: r, green: g, blue: b)
    }
}
