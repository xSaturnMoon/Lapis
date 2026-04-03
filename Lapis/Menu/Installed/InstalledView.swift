import SwiftUI

struct InstalledView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedInstalledVersion: InstalledVersion? = nil
    
    var body: some View {
        ZStack {
            LapisTheme.Colors.background.ignoresSafeArea()
            
            if let version = selectedInstalledVersion {
                InstalledDetailView(version: version) {
                    withAnimation(LapisTheme.Animation.smooth) {
                        selectedInstalledVersion = nil
                        appState.loadInstalledVersions()
                    }
                }
            } else {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("INSTALLED")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(LapisTheme.Colors.textSecondary)
                            .tracking(2)
                        
                        Spacer()
                        
                        Text("\(appState.installedVersions.count) versions")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(LapisTheme.Colors.textMuted)
                    }
                    .padding(.horizontal, LapisTheme.Spacing.xxl)
                    .padding(.top, LapisTheme.Spacing.xl)
                    .padding(.bottom, LapisTheme.Spacing.lg)
                    
                    if appState.installedVersions.isEmpty {
                        Spacer()
                        VStack(spacing: LapisTheme.Spacing.md) {
                            Image(systemName: "tray")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(LapisTheme.Colors.textMuted)
                            Text("No versions installed yet")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(LapisTheme.Colors.textSecondary)
                            Text("Go to Versions to download one")
                                .font(.system(size: 12))
                                .foregroundColor(LapisTheme.Colors.textMuted)
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
                                ForEach(appState.installedVersions) { version in
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
        .onAppear {
            appState.loadInstalledVersions()
        }
    }
}

// MARK: - Installed Version Row
struct InstalledVersionRow: View {
    let version: InstalledVersion
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: LapisTheme.Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                        .fill(LapisTheme.Colors.accent.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: version.loader.iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(LapisTheme.Colors.accent)
                }
                
                VStack(alignment: .leading, spacing: LapisTheme.Spacing.xs) {
                    Text(version.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textPrimary)
                    
                    Text("\(version.modCount) mods")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(LapisTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Text(version.folderName)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(LapisTheme.Colors.textMuted)
                    .padding(.horizontal, LapisTheme.Spacing.sm)
                    .padding(.vertical, LapisTheme.Spacing.xs)
                    .background(Capsule().fill(LapisTheme.Colors.glassBackground))
                
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
