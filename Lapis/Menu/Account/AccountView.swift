import SwiftUI

struct AccountView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authService = MicrosoftAuthService()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    if !authService.showWebView { dismiss() }
                }
            
            if authService.showWebView {
                // Full screen Microsoft Login WebView
                VStack(spacing: 0) {
                    HStack {
                        Text("Sign in with Microsoft")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(LapisTheme.Colors.textPrimary)
                        Spacer()
                        Button {
                            authService.showWebView = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(LapisTheme.Colors.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(LapisTheme.Spacing.lg)
                    .background(LapisTheme.Colors.surface)
                    
                    MicrosoftLoginWebView(authService: authService)
                        .environmentObject(appState)
                }
                .frame(maxWidth: 500, maxHeight: 600)
                .clipShape(RoundedRectangle(cornerRadius: LapisTheme.Radius.xl))
                .shadow(color: .black.opacity(0.5), radius: 30)
            } else {
                // Account card
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(LapisTheme.Colors.textMuted)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, LapisTheme.Spacing.lg)
                    .padding(.top, LapisTheme.Spacing.lg)
                    
                    if appState.isLoggedIn {
                        LoggedInView()
                    } else if authService.isAuthenticating {
                        Spacer()
                        ProgressView()
                            .tint(LapisTheme.Colors.accent)
                        Text("Authenticating with Xbox Live...")
                            .font(.system(size: 13))
                            .foregroundColor(LapisTheme.Colors.textMuted)
                            .padding(.top, LapisTheme.Spacing.sm)
                        Spacer()
                    } else {
                        LoginPromptView(authService: authService)
                    }
                }
                .frame(width: 360, height: 420)
                .glassBackground(cornerRadius: LapisTheme.Radius.xl)
                .shadow(color: .black.opacity(0.4), radius: 30, y: 10)
            }
        }
    }
}

// MARK: - Login Prompt
struct LoginPromptView: View {
    @ObservedObject var authService: MicrosoftAuthService
    
    var body: some View {
        VStack(spacing: LapisTheme.Spacing.xxl) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(LapisTheme.Colors.accent.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(LapisTheme.Colors.accent)
            }
            
            VStack(spacing: LapisTheme.Spacing.sm) {
                Text("Microsoft Account")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(LapisTheme.Colors.textPrimary)
                Text("Sign in with your Microsoft account\nto play Minecraft Java Edition.")
                    .font(.system(size: 13))
                    .foregroundColor(LapisTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                authService.showWebView = true
            } label: {
                HStack(spacing: LapisTheme.Spacing.sm) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Sign In with Microsoft")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .buttonStyle(LapisButtonStyle(isAccent: true))
            
            if let error = authService.error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(LapisTheme.Colors.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(LapisTheme.Spacing.xxl)
    }
}

// MARK: - Logged In
struct LoggedInView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: LapisTheme.Spacing.xl) {
            Spacer()
            
            AsyncImage(url: URL(string: "https://mc-heads.net/body/\(appState.playerUUID)/100")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fit).frame(height: 120)
                case .failure(_):
                    Image(systemName: "person.fill")
                        .font(.system(size: 48))
                        .foregroundColor(LapisTheme.Colors.accent)
                default:
                    ProgressView().tint(LapisTheme.Colors.accent)
                }
            }
            .frame(height: 120)
            
            VStack(spacing: LapisTheme.Spacing.xs) {
                Text(appState.playerName)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(LapisTheme.Colors.textPrimary)
                Text("Premium Account")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LapisTheme.Colors.accent)
            }
            
            HStack(spacing: LapisTheme.Spacing.xxl) {
                VStack(spacing: LapisTheme.Spacing.xs) {
                    Text(formatPlayTime(appState.totalPlayTimeMinutes))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textPrimary)
                    Text("Play Time")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                }
                Rectangle().fill(LapisTheme.Colors.divider).frame(width: 1, height: 32)
                VStack(spacing: LapisTheme.Spacing.xs) {
                    Text("Online")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textPrimary)
                    Text("Status")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                }
            }
            .padding(LapisTheme.Spacing.lg)
            .glassBackground(cornerRadius: LapisTheme.Radius.medium)
            
            Spacer()
            
            Button {
                appState.isLoggedIn = false
                appState.playerName = ""
                appState.playerUUID = ""
                appState.accessToken = ""
            } label: {
                HStack(spacing: LapisTheme.Spacing.sm) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out").font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(LapisTheme.Colors.danger)
            }
            .buttonStyle(.plain)
            .padding(.bottom, LapisTheme.Spacing.lg)
        }
        .padding(LapisTheme.Spacing.xxl)
    }
    
    private func formatPlayTime(_ m: Int) -> String {
        m / 60 > 0 ? "\(m/60)h \(m%60)m" : "\(m)m"
    }
}
