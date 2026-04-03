import SwiftUI

struct AccountView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            // Account Card
            VStack(spacing: 0) {
                if appState.isLoggedIn {
                    LoggedInView()
                } else {
                    LoginPromptView()
                }
            }
            .frame(width: 360, height: 420)
            .glassBackground(cornerRadius: LapisTheme.Radius.xl)
            .shadow(color: .black.opacity(0.4), radius: 30, y: 10)
        }
    }
}

// MARK: - Login Prompt
struct LoginPromptView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: LapisTheme.Spacing.xxl) {
            Spacer()
            
            // Xbox / Microsoft icon
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
                
                Text("Sign in with your Microsoft account\nto play on premium servers.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(LapisTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                // Microsoft OAuth flow — will be implemented
                // For now, simulate login
                appState.isLoggedIn = true
                appState.playerName = "xSaturnMoon"
                appState.playerUUID = "069a79f444e94726a5befca90e38aaf5"
            } label: {
                HStack(spacing: LapisTheme.Spacing.sm) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Sign In")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .buttonStyle(LapisButtonStyle(isAccent: true))
            
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
            
            // Player avatar
            AsyncImage(url: URL(string: "https://mc-heads.net/body/\(appState.playerUUID)/100")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 120)
                case .failure(_):
                    Image(systemName: "person.fill")
                        .font(.system(size: 48))
                        .foregroundColor(LapisTheme.Colors.accent)
                default:
                    ProgressView()
                        .tint(LapisTheme.Colors.accent)
                }
            }
            .frame(height: 120)
            
            // Player name
            VStack(spacing: LapisTheme.Spacing.xs) {
                Text(appState.playerName)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(LapisTheme.Colors.textPrimary)
                
                Text("Premium Account")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LapisTheme.Colors.accent)
            }
            
            // Stats
            HStack(spacing: LapisTheme.Spacing.xxl) {
                StatItem(label: "Play Time", value: formatPlayTime(appState.totalPlayTimeMinutes))
                
                Rectangle()
                    .fill(LapisTheme.Colors.divider)
                    .frame(width: 1, height: 32)
                
                StatItem(label: "Status", value: "Online")
            }
            .padding(LapisTheme.Spacing.lg)
            .glassBackground(cornerRadius: LapisTheme.Radius.medium)
            
            Spacer()
            
            // Logout
            Button {
                appState.isLoggedIn = false
                appState.playerName = ""
                appState.playerUUID = ""
                appState.totalPlayTimeMinutes = 0
            } label: {
                HStack(spacing: LapisTheme.Spacing.sm) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(LapisTheme.Colors.danger)
            }
            .buttonStyle(.plain)
            .padding(.bottom, LapisTheme.Spacing.lg)
        }
        .padding(LapisTheme.Spacing.xxl)
    }
    
    private func formatPlayTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: LapisTheme.Spacing.xs) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(LapisTheme.Colors.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(LapisTheme.Colors.textMuted)
        }
    }
}
