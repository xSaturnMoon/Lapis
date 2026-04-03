import SwiftUI

struct VersionsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedLoader: ModLoader = .vanilla
    @State private var selectedVersionDetail: GameVersion? = nil
    @State private var searchText: String = ""
    
    // Sample data — will be replaced with real Mojang API data
    private var sampleVersions: [GameVersion] {
        let versions = [
            ("1.21.4", "The Garden Awakens"),
            ("1.21.1", "Tricky Trials"),
            ("1.21", "Tricky Trials"),
            ("1.20.4", "Trails & Tales"),
            ("1.20.1", "Trails & Tales"),
            ("1.19.4", "The Wild Update"),
            ("1.18.2", "Caves & Cliffs Part II"),
            ("1.17.1", "Caves & Cliffs Part I"),
            ("1.16.5", "Nether Update"),
            ("1.12.2", "World of Color"),
            ("1.8.9", "Bountiful Update"),
            ("1.7.10", "The Update that Changed the World"),
        ]
        return versions.map { v in
            GameVersion(
                id: "\(selectedLoader.rawValue.lowercased())-\(v.0)",
                versionNumber: v.0,
                loader: selectedLoader,
                releaseDate: "2024",
                description: v.1,
                isInstalled: appState.installedVersions.contains(where: {
                    $0.versionNumber == v.0 && $0.loader == selectedLoader
                })
            )
        }
    }
    
    private var filteredVersions: [GameVersion] {
        if searchText.isEmpty { return sampleVersions }
        return sampleVersions.filter { $0.versionNumber.contains(searchText) }
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 280), spacing: LapisTheme.Spacing.md)
    ]
    
    var body: some View {
        ZStack {
            LapisTheme.Colors.background.ignoresSafeArea()
            
            HStack(spacing: 0) {
                // MARK: Left: Version Grid (≈70%)
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: LapisTheme.Spacing.lg) {
                        Text("VERSIONS")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(LapisTheme.Colors.textSecondary)
                            .tracking(2)
                        
                        Spacer()
                        
                        // Loader Dropdown
                        Menu {
                            ForEach(ModLoader.allCases) { loader in
                                Button {
                                    withAnimation(LapisTheme.Animation.normal) {
                                        selectedLoader = loader
                                        selectedVersionDetail = nil
                                    }
                                } label: {
                                    Label(loader.rawValue, systemImage: loader.iconName)
                                }
                            }
                        } label: {
                            HStack(spacing: LapisTheme.Spacing.sm) {
                                Image(systemName: selectedLoader.iconName)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(selectedLoader.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(LapisTheme.Colors.accent)
                            .padding(.horizontal, LapisTheme.Spacing.lg)
                            .padding(.vertical, LapisTheme.Spacing.sm)
                            .glassBackground(cornerRadius: LapisTheme.Radius.small)
                        }
                    }
                    .padding(.horizontal, LapisTheme.Spacing.xxl)
                    .padding(.top, LapisTheme.Spacing.xl)
                    .padding(.bottom, LapisTheme.Spacing.lg)
                    
                    // Grid of version cards
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: LapisTheme.Spacing.md) {
                            ForEach(filteredVersions) { version in
                                VersionCardView(
                                    version: version,
                                    isSelected: selectedVersionDetail?.id == version.id
                                ) {
                                    withAnimation(LapisTheme.Animation.smooth) {
                                        selectedVersionDetail = version
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, LapisTheme.Spacing.xxl)
                        .padding(.bottom, LapisTheme.Spacing.xxl)
                    }
                }
                
                // MARK: Right: Selected Version Panel (≈30%)
                VersionDetailPanel(
                    version: selectedVersionDetail,
                    onSelect: { version in
                        withAnimation(LapisTheme.Animation.smooth) {
                            appState.selectedVersion = version
                            appState.currentTab = .home
                        }
                    }
                )
                .frame(width: 280)
            }
        }
    }
}

// MARK: - Version Card
struct VersionCardView: View {
    let version: GameVersion
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // Card background with gradient
                RoundedRectangle(cornerRadius: LapisTheme.Radius.large)
                    .fill(
                        LinearGradient(
                            colors: [
                                LapisTheme.Colors.surfaceLight,
                                LapisTheme.Colors.surface
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Overlay gradient for text readability
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)
                }
                .clipShape(RoundedRectangle(cornerRadius: LapisTheme.Radius.large))
                
                // Version icon in center
                VStack {
                    Image(systemName: version.loader.iconName)
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(LapisTheme.Colors.textMuted.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Version name
                VStack(alignment: .leading, spacing: 2) {
                    Text(version.displayName)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(LapisTheme.Colors.textPrimary)
                }
                .padding(LapisTheme.Spacing.lg)
                
                // Installed indicator
                if version.isInstalled {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(LapisTheme.Colors.success)
                                .frame(width: 10, height: 10)
                                .padding(LapisTheme.Spacing.md)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 110)
            .overlay(
                RoundedRectangle(cornerRadius: LapisTheme.Radius.large)
                    .stroke(
                        isSelected ? LapisTheme.Colors.accent : LapisTheme.Colors.glassBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Version Detail Side Panel
struct VersionDetailPanel: View {
    let version: GameVersion?
    let onSelect: (GameVersion) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if let version = version {
                VStack(alignment: .leading, spacing: 0) {
                    // Panel header
                    Text("SELECTED VERSION")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                        .tracking(1.5)
                        .padding(.horizontal, LapisTheme.Spacing.xl)
                        .padding(.top, LapisTheme.Spacing.xl)
                        .padding(.bottom, LapisTheme.Spacing.lg)
                    
                    // Version preview card
                    ZStack {
                        RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                            .fill(LapisTheme.Colors.surfaceLight)
                            .frame(height: 140)
                        
                        VStack(spacing: LapisTheme.Spacing.sm) {
                            Image(systemName: version.loader.iconName)
                                .font(.system(size: 32, weight: .light))
                                .foregroundColor(LapisTheme.Colors.accent.opacity(0.5))
                            
                            Text(version.displayName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(LapisTheme.Colors.textPrimary)
                        }
                    }
                    .padding(.horizontal, LapisTheme.Spacing.xl)
                    
                    Spacer().frame(height: LapisTheme.Spacing.xl)
                    
                    // Version info
                    VStack(alignment: .leading, spacing: LapisTheme.Spacing.md) {
                        HStack(spacing: LapisTheme.Spacing.sm) {
                            Image(systemName: version.loader.iconName)
                                .font(.system(size: 14))
                                .foregroundColor(LapisTheme.Colors.accent)
                            Text("Minecraft \(version.versionNumber)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(LapisTheme.Colors.textPrimary)
                        }
                        
                        Text(version.description)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(LapisTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Loader badge
                        HStack(spacing: LapisTheme.Spacing.xs) {
                            Text(version.loader.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(LapisTheme.Colors.accent)
                                .padding(.horizontal, LapisTheme.Spacing.sm)
                                .padding(.vertical, LapisTheme.Spacing.xs)
                                .background(
                                    Capsule()
                                        .fill(LapisTheme.Colors.accent.opacity(0.12))
                                )
                        }
                        
                        // Status
                        HStack(spacing: LapisTheme.Spacing.sm) {
                            Circle()
                                .fill(version.isInstalled ? LapisTheme.Colors.success : LapisTheme.Colors.textMuted)
                                .frame(width: 8, height: 8)
                            Text(version.isInstalled ? "Installed" : "Not installed")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(LapisTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, LapisTheme.Spacing.xl)
                    
                    Spacer()
                    
                    // SELECT button
                    Button {
                        onSelect(version)
                    } label: {
                        HStack(spacing: LapisTheme.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("SELECT")
                                .font(.system(size: 14, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundColor(LapisTheme.Colors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LapisTheme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                                .fill(LapisTheme.Colors.accent)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                                .stroke(LapisTheme.Colors.accentLight.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, LapisTheme.Spacing.xl)
                    .padding(.bottom, LapisTheme.Spacing.xl)
                    
                }
            } else {
                // No version selected
                VStack(spacing: LapisTheme.Spacing.lg) {
                    Spacer()
                    Image(systemName: "hand.tap")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                    Text("Select a version")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                    Spacer()
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(
            LapisTheme.Colors.surface.opacity(0.5)
                .ignoresSafeArea()
        )
        .overlay(
            Rectangle()
                .fill(LapisTheme.Colors.divider)
                .frame(width: 1),
            alignment: .leading
        )
    }
}
