import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var isLogin: Bool = false
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var selectedColor: Color = .blue
    @State private var appear: Bool = false

    let avatarColors: [Color] = [.blue, .purple, .pink, .orange, .green, .cyan, .red, .yellow]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red:0.05,green:0.05,blue:0.18), Color(red:0.10,green:0.05,blue:0.22), Color(red:0.02,green:0.08,blue:0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle().fill(selectedColor.opacity(0.18)).frame(width:400,height:400).blur(radius:80).offset(x:-150,y:-100)
                .animation(.easeInOut(duration:3).repeatForever(autoreverses:true), value:selectedColor)
            Circle().fill(Color.purple.opacity(0.12)).frame(width:350,height:350).blur(radius:70).offset(x:200,y:150)

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(selectedColor.opacity(0.25)).frame(width:72,height:72)
                            Text(username.prefix(1).uppercased().isEmpty ? "?" : String(username.prefix(1).uppercased()))
                                .font(.system(size:30,weight:.semibold,design:.rounded)).foregroundStyle(.white)
                        }
                        .animation(.spring(duration:0.4,bounce:0.3), value:username)
                        Text(isLogin ? "Bentornato" : "Crea account")
                            .font(.system(size:22,weight:.semibold,design:.rounded)).foregroundStyle(.white)
                        Text("AppleDesk").font(.system(size:13)).foregroundStyle(.white.opacity(0.45))
                    }

                    Divider().background(.white.opacity(0.1))

                    VStack(spacing: 14) {
                        GlassTextField(placeholder:"Username", text:$username, icon:"person")
                        GlassTextField(placeholder:"Password", text:$password, icon:"lock", isSecure:true)
                    }

                    if !isLogin {
                        VStack(alignment:.leading, spacing:8) {
                            Text("Colore avatar").font(.system(size:12,weight:.medium)).foregroundStyle(.white.opacity(0.5))
                            HStack(spacing:10) {
                                ForEach(avatarColors, id:\.self) { color in
                                    Circle().fill(color).frame(width:26,height:26)
                                        .overlay(Circle().stroke(.white, lineWidth: selectedColor==color ? 2 : 0).padding(-2))
                                        .scaleEffect(selectedColor==color ? 1.15 : 1)
                                        .animation(.spring(duration:0.3,bounce:0.4), value:selectedColor)
                                        .onTapGesture { selectedColor = color }
                                }
                            }
                        }
                        .transition(.opacity.combined(with:.move(edge:.top)))
                    }

                    if let err = authVM.error {
                        Text(err).font(.system(size:12,weight:.medium)).foregroundStyle(.red.opacity(0.9)).transition(.opacity)
                    }

                    Button {
                        withAnimation(.spring(duration:0.4,bounce:0.2)) {
                            if isLogin { authVM.login(username:username, password:password) }
                            else { authVM.register(username:username, password:password, color:selectedColor) }
                        }
                    } label: {
                        Text(isLogin ? "Accedi" : "Registrati")
                            .font(.system(size:16,weight:.semibold,design:.rounded)).foregroundStyle(.white)
                            .frame(maxWidth:.infinity).padding(.vertical,14)
                            .background(selectedColor.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius:14,style:.continuous))
                    }

                    Button {
                        withAnimation(.spring(duration:0.4,bounce:0.2)) { isLogin.toggle(); authVM.error = nil }
                    } label: {
                        Text(isLogin ? "Nessun account? Registrati" : "Hai già un account? Accedi")
                            .font(.system(size:13)).foregroundStyle(.white.opacity(0.45))
                    }
                }
                .padding(40).frame(width:360)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 30, y: 15)
                .scaleEffect(appear ? 1 : 0.94).opacity(appear ? 1 : 0)
                Spacer()
            }
            .animation(.spring(duration:0.5,bounce:0.15), value:isLogin)
        }
        .onAppear {
            withAnimation(.spring(duration:0.6,bounce:0.2).delay(0.1)) { appear = true }
        }
    }
}

struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing:10) {
            Image(systemName:icon).font(.system(size:14,weight:.medium)).foregroundStyle(.white.opacity(0.4)).frame(width:20)
            if isSecure {
                SecureField(placeholder, text:$text).font(.system(size:15)).foregroundStyle(.white).tint(.white)
            } else {
                TextField(placeholder, text:$text).font(.system(size:15)).foregroundStyle(.white).tint(.white)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
        }
        .padding(.horizontal,14).padding(.vertical,14)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius:14,style:.continuous))
        .overlay(RoundedRectangle(cornerRadius:14,style:.continuous).stroke(.white.opacity(0.08),lineWidth:0.5))
    }
}
