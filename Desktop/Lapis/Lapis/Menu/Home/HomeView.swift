import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var isPlayHovered = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Background with subtle gradient
            LinearGradient(
                colors: [
                    LapisTheme.Colors.background,
                    LapisTheme.Colors.surface.opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Text("HOME")
                        .font(.system(size: 13, weight: .bold, design: .default))
                        .foregroundColor(LapisTheme.Colors.textSecondary)
                        .tracking(2)
                    
                    Spacer()
                    
                    // Status indicator
                    HStack(spacing: LapisTheme.Spacing.xs) {
                        Circle()
                            .fill(appState.isLoggedIn ? LapisTheme.Colors.success : LapisTheme.Colors.danger)
                            .frame(width: 8, height: 8)
                        Text(appState.isLoggedIn ? "Online" : "Offline")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(LapisTheme.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, LapisTheme.Spacing.xxl)
                .padding(.top, LapisTheme.Spacing.xl)
                
                Spacer()
                
                // MARK: - Center Content
                VStack(spacing: LapisTheme.Spacing.xxl) {
                    // App Logo / Title
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
                    
                    // Selected Version Card
                    if let version = appState.selectedVersion {
                        SelectedVersionCard(version: version)
                    } else {
                        NoVersionSelectedCard()
                    }
                    
                    // MARK: - PLAY Button
                    Button {
                        // Launch game — will be implemented in Game phase
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
                                    .fill(
                                        LinearGradient(
                                            colors: [LapisTheme.Colors.accent, LapisTheme.Colors.accentDark],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                
                                // Glow effect
                                if pulseAnimation {
                                    RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                                        .fill(LapisTheme.Colors.accentGlow)
                                        .blur(radius: 12)
                                        .scaleEffect(1.1)
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                                .stroke(LapisTheme.Colors.accentLight.opacity(0.4), lineWidth: 1)
                        )
                        .shadow(color: LapisTheme.Colors.accent.opacity(0.3), radius: 16, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.selectedVersion == nil)
                    .opacity(appState.selectedVersion == nil ? 0.4 : 1.0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            pulseAnimation = true
                        }
                    }
                }
                
                Spacer()
                
                // MARK: - Bottom Info
                HStack {
                    Text("v1.0.0")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                    
                    Spacer()
                    
                    if let version = appState.selectedVersion {
                        Text("\(version.displayName)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(LapisTheme.Colors.textMuted)
                    }
                }
                .padding(.horizontal, LapisTheme.Spacing.xxl)
                .padding(.bottom, LapisTheme.Spacing.lg)
            }
        }
    }
}

// MARK: - Selected Version Card
struct SelectedVersionCard: View {
    let version: GameVersion
    
    var body: some View {
        HStack(spacing: LapisTheme.Spacing.lg) {
            // Version icon
            ZStack {
                RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                    .fill(LapisTheme.Colors.accent.opacity(0.1))
                    .frame(width: 56, height: 56)
                
                Image(systemName: version.loader.iconName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(LapisTheme.Colors.accent)
            }
            
            VStack(alignment: .leading, spacing: LapisTheme.Spacing.xs) {
                Text(version.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(LapisTheme.Colors.textPrimary)
                
                Text(version.description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(LapisTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Ready indicator
            VStack(spacing: LapisTheme.Spacing.xs) {
                Circle()
                    .fill(version.isInstalled ? LapisTheme.Colors.success : LapisTheme.Colors.warning)
                    .frame(width: 10, height: 10)
                Text(version.isInstalled ? "Ready" : "Download")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(LapisTheme.Colors.textMuted)
            }
        }
        .padding(LapisTheme.Spacing.xl)
        .frame(maxWidth: 420)
        .glassBackground()
    }
}

// MARK: - No Version Card
struct NoVersionSelectedCard: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
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
}
