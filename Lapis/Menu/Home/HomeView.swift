import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [LapisTheme.Colors.background, LapisTheme.Colors.surface.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("HOME")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textSecondary)
                        .tracking(2)
                    
                    Spacer()
                    
                    HStack(spacing: LapisTheme.Spacing.xs) {
                        Circle()
                            .fill(appState.isLoggedIn ? LapisTheme.Colors.success : LapisTheme.Colors.danger)
                            .frame(width: 8, height: 8)
                        Text(appState.isLoggedIn ? appState.playerName : "Not signed in")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(LapisTheme.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, LapisTheme.Spacing.xxl)
                .padding(.top, LapisTheme.Spacing.xl)
                
                Spacer()
                
                VStack(spacing: LapisTheme.Spacing.xxl) {
                    // Title
                    VStack(spacing: LapisTheme.Spacing.sm) {
                        Text("LAPIS")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [LapisTheme.Colors.accent, LapisTheme.Colors.accentLight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Minecraft Java Launcher")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LapisTheme.Colors.textSecondary)
                    }
                    
                    // Selected version card or empty state
                    if let version = appState.selectedVersion {
                        HStack(spacing: LapisTheme.Spacing.lg) {
                            ZStack {
                                RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                                    .fill(LapisTheme.Colors.accent.opacity(0.1))
                                    .frame(width: 56, height: 56)
                                
                                Image(systemName: appState.selectedLoader.iconName)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(LapisTheme.Colors.accent)
                            }
                            
                            VStack(alignment: .leading, spacing: LapisTheme.Spacing.xs) {
                                Text("\(appState.selectedLoader.rawValue) \(version.id)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(LapisTheme.Colors.textPrimary)
                                
                                Text(version.type.capitalized)
                                    .font(.system(size: 13))
                                    .foregroundColor(LapisTheme.Colors.textSecondary)
                            }
                            
                            Spacer()
                        }
                        .padding(LapisTheme.Spacing.xl)
                        .frame(maxWidth: 420)
                        .glassBackground()
                    } else {
                        VStack(spacing: LapisTheme.Spacing.md) {
                            Image(systemName: "square.stack.3d.up.slash")
                                .font(.system(size: 32, weight: .light))
                                .foregroundColor(LapisTheme.Colors.textMuted)
                            
                            Text("No version selected")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(LapisTheme.Colors.textSecondary)
                            
                            Button {
                                withAnimation(LapisTheme.Animation.smooth) {
                                    appState.currentTab = .versions
                                }
                            } label: {
                                Text("Browse Versions")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(LapisTheme.Colors.accent)
                            }
                        }
                        .padding(LapisTheme.Spacing.xxl)
                        .frame(maxWidth: 420)
                        .glassBackground()
                    }
                    
                    // PLAY button
                    Button {
                        // Game launch — will be connected to PojavLauncher core
                    } label: {
                        HStack(spacing: LapisTheme.Spacing.md) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("PLAY")
                                .font(.system(size: 16, weight: .bold))
                                .tracking(2)
                        }
                        .foregroundColor(LapisTheme.Colors.background)
                        .frame(width: 220, height: 52)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                                    .fill(LinearGradient(
                                        colors: [LapisTheme.Colors.accent, LapisTheme.Colors.accentDark],
                                        startPoint: .top, endPoint: .bottom
                                    ))
                                if pulseAnimation {
                                    RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                                        .fill(LapisTheme.Colors.accentGlow)
                                        .blur(radius: 12)
                                        .scaleEffect(1.1)
                                }
                            }
                        )
                        .shadow(color: LapisTheme.Colors.accent.opacity(0.3), radius: 16, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.selectedVersion == nil || !appState.isLoggedIn)
                    .opacity(appState.selectedVersion == nil || !appState.isLoggedIn ? 0.4 : 1.0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            pulseAnimation = true
                        }
                    }
                    
                    // Warning if not logged in
                    if !appState.isLoggedIn && appState.selectedVersion != nil {
                        Text("Sign in with Microsoft to play")
                            .font(.system(size: 12))
                            .foregroundColor(LapisTheme.Colors.warning)
                    }
                }
                
                Spacer()
                
                HStack {
                    Text("v1.0.0")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                    Spacer()
                }
                .padding(.horizontal, LapisTheme.Spacing.xxl)
                .padding(.bottom, LapisTheme.Spacing.lg)
            }
        }
    }
}
