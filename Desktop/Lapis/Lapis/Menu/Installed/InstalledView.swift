import SwiftUI

struct InstalledView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedInstalledVersion: GameVersion? = nil
    
    // Sample installed versions for UI preview
    private var installedVersions: [GameVersion] {
        if appState.installedVersions.isEmpty {
            // Show sample data for UI development
            return [
                GameVersion(id: "v1", versionNumber: "1.21.1", loader: .vanilla, releaseDate: "2024", description: "Tricky Trials", isInstalled: true),
                GameVersion(id: "f1", versionNumber: "1.20.1", loader: .fabric, releaseDate: "2023", description: "Trails & Tales", isInstalled: true),
                GameVersion(id: "fo1", versionNumber: "1.8.9", loader: .forge, releaseDate: "2015", description: "Bountiful Update", isInstalled: true),
            ]
        }
        return appState.installedVersions
    }
    
    var body: some View {
        ZStack {
            LapisTheme.Colors.background.ignoresSafeArea()
            
            if let version = selectedInstalledVersion {
                // Show mod management for selected version
                InstalledDetailView(version: version) {
                    withAnimation(LapisTheme.Animation.smooth) {
                        selectedInstalledVersion = nil
                    }
                }
            } else {
                // Show list of installed versions
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("INSTALLED")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(LapisTheme.Colors.textSecondary)
                            .tracking(2)
                        
                        Spacer()
                        
                        Text("\(installedVersions.count) versions")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(LapisTheme.Colors.textMuted)
                    }
                    .padding(.horizontal, LapisTheme.Spacing.xxl)
                    .padding(.top, LapisTheme.Spacing.xl)
                    .padding(.bottom, LapisTheme.Spacing.lg)
                    
                    if installedVersions.isEmpty {
                        // Empty state
                        Spacer()
                        VStack(spacing: LapisTheme.Spacing.md) {
                            Image(systemName: "tray")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(LapisTheme.Colors.textMuted)
                            Text("No versions installed")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(LapisTheme.Colors.textSecondary)
                            Button {
                                appState.currentTab = .versions
                            } label: {
                                Text("Browse Versions")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(LapisTheme.Colors.accent)
                            }
                        }
                        Spacer()
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: LapisTheme.Spacing.sm) {
                                ForEach(installedVersions) { version in
                                    InstalledVersionRow(version: version) {
                                        withAnimation(LapisTheme.Animation.smooth) {
                                            selectedInstalledVersion = version
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, LapisTheme.Spacing.xxl)
                            .padding(.bottom, LapisTheme.Spacing.xxl)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Installed Version Row
struct InstalledVersionRow: View {
    let version: GameVersion
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: LapisTheme.Spacing.lg) {
                // Loader icon
                ZStack {
                    RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                        .fill(LapisTheme.Colors.accent.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: version.loader.iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(LapisTheme.Colors.accent)
                }
                
                // Version info
                VStack(alignment: .leading, spacing: LapisTheme.Spacing.xs) {
                    Text(version.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textPrimary)
                    
                    Text(version.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(LapisTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Mod folder name badge
                Text(version.modsFolderName)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(LapisTheme.Colors.textMuted)
                    .padding(.horizontal, LapisTheme.Spacing.sm)
                    .padding(.vertical, LapisTheme.Spacing.xs)
                    .background(
                        Capsule().fill(LapisTheme.Colors.glassBackground)
                    )
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(LapisTheme.Colors.textMuted)
            }
            .padding(LapisTheme.Spacing.lg)
            .glassBackground()
        }
        .buttonStyle(.plain)
    }
}
