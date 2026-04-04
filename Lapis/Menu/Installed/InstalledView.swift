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
                                    InstalledVersionRow(
                                        version: version,
                                        action: {
                                            withAnimation(LapisTheme.Animation.smooth) {
                                                selectedInstalledVersion = version
                                            }
                                        },
                                        onDelete: {
                                            deleteVersion(version)
                                        }
                                    )
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
    
    private func deleteVersion(_ version: InstalledVersion) {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let versionDir = docs.appendingPathComponent("Lapis/mods/\(version.folderName)")
        let binDir = docs.appendingPathComponent("Lapis/versions/\(version.folderName)")
        
        try? fm.removeItem(at: versionDir)
        try? fm.removeItem(at: binDir)
        
        withAnimation {
            appState.loadInstalledVersions()
        }
    }
}

// MARK: - Installed Version Row
struct InstalledVersionRow: View {
    let version: InstalledVersion
    let action: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: LapisTheme.Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                        .fill(LapisTheme.Colors.accent.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(version.loader.iconName)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
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
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(LapisTheme.Colors.danger)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                
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
