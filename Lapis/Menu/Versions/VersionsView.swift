import SwiftUI

struct VersionsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var mojangService = MojangService()
    @AppStorage("lapis_last_played_v2") private var lastPlayedId: String = ""
    @State private var selectedMajor: String? = nil
    @State private var selectedSubVersion: String? = nil
    
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
                                        appState.selectedLoader = loader
                                    }
                                } label: {
                                    HStack {
                                        LapisImage(loader.iconName).resizable().aspectRatio(contentMode: .fit).frame(width: 14, height: 14)
                                        Text(loader.rawValue)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: LapisTheme.Spacing.sm) {
                                LapisImage(appState.selectedLoader.iconName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 12, height: 12)
                                Text(appState.selectedLoader.rawValue)
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
                    
                    // Content
                    if mojangService.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(LapisTheme.Colors.accent)
                        Text("Loading versions from Mojang...")
                            .font(.system(size: 13))
                            .foregroundColor(LapisTheme.Colors.textMuted)
                            .padding(.top, LapisTheme.Spacing.sm)
                        Spacer()
                    } else if let error = mojangService.error {
                        Spacer()
                        VStack(spacing: LapisTheme.Spacing.md) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundColor(LapisTheme.Colors.danger)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(LapisTheme.Colors.textSecondary)
                            Button("Retry") {
                                Task { await mojangService.fetchVersions() }
                            }
                            .buttonStyle(LapisButtonStyle(isAccent: true))
                        }
                        Spacer()
                    } else {
                        // Grid of major version cards (1.21, 1.20, 1.19...)
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVGrid(columns: columns, spacing: LapisTheme.Spacing.md) {
                                ForEach(mojangService.majorVersions, id: \.self) { major in
                                    MajorVersionCard(
                                        majorVersion: major,
                                        loader: appState.selectedLoader,
                                        subVersionCount: mojangService.subVersions(for: major).count,
                                        isSelected: selectedMajor == major
                                    ) {
                                        withAnimation(LapisTheme.Animation.smooth) {
                                            selectedMajor = major
                                            selectedSubVersion = nil
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, LapisTheme.Spacing.xxl)
                            .padding(.bottom, LapisTheme.Spacing.xxl)
                        }
                    }
                }
                
                // MARK: Right: Selection Panel (≈30%)
                VersionSelectionPanel(
                    selectedMajor: selectedMajor,
                    selectedSubVersion: $selectedSubVersion,
                    loader: appState.selectedLoader,
                    subVersions: selectedMajor != nil ? mojangService.subVersions(for: selectedMajor!) : [],
                    onSelect: { subVersion in
                        // Find the actual GameVersion object
                        if let version = mojangService.allVersions.first(where: { $0.id == subVersion }) {
                            withAnimation(LapisTheme.Animation.smooth) {
                                appState.selectedVersion = version
                                appState.selectedSubVersion = subVersion
                                lastPlayedId = "\(version.id)-\(appState.selectedLoader.rawValue)"
                                appState.currentTab = .home
                            }
                        }
                    }
                )
                .frame(width: 280)
            }
        }
        .task {
            if mojangService.allVersions.isEmpty {
                await mojangService.fetchVersions()
            }
        }
    }
}

// MARK: - Major Version Card (e.g. "1.21")
struct MajorVersionCard: View {
    let majorVersion: String
    let loader: ModLoader
    let subVersionCount: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
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
                
                // Loader icon watermark
                VStack {
                    LapisImage(loader.iconName)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(LapisTheme.Colors.textMuted.opacity(0.2))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Version info
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(loader.rawValue.uppercased()) \(majorVersion)")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(LapisTheme.Colors.textPrimary)
                    
                    Text("\(subVersionCount) versions")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                }
                .padding(LapisTheme.Spacing.lg)
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

// MARK: - Version Selection Panel (right side)
struct VersionSelectionPanel: View {
    let selectedMajor: String?
    @Binding var selectedSubVersion: String?
    let loader: ModLoader
    let subVersions: [GameVersion]
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if let major = selectedMajor {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("SELECTED VERSION")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                        .tracking(1.5)
                        .padding(.horizontal, LapisTheme.Spacing.xl)
                        .padding(.top, LapisTheme.Spacing.xl)
                        .padding(.bottom, LapisTheme.Spacing.lg)
                    
                    // Preview
                    ZStack {
                        RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                            .fill(LapisTheme.Colors.surfaceLight)
                            .frame(height: 100)
                        
                        VStack(spacing: LapisTheme.Spacing.sm) {
                            LapisImage(loader.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                            Text("\(loader.rawValue) \(major)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(LapisTheme.Colors.textPrimary)
                        }
                    }
                    .padding(.horizontal, LapisTheme.Spacing.xl)
                    
                    Spacer().frame(height: LapisTheme.Spacing.xl)
                    
                    // Sub-version dropdown
                    VStack(alignment: .leading, spacing: LapisTheme.Spacing.sm) {
                        Text("Version")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(LapisTheme.Colors.textSecondary)
                        
                        Menu {
                            ForEach(subVersions) { version in
                                Button(version.id) {
                                    selectedSubVersion = version.id
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedSubVersion ?? "Select version...")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(selectedSubVersion != nil ? LapisTheme.Colors.textPrimary : LapisTheme.Colors.textMuted)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(LapisTheme.Colors.textMuted)
                            }
                            .padding(LapisTheme.Spacing.md)
                            .glassBackground(cornerRadius: LapisTheme.Radius.small)
                        }
                        
                        // Loader badge
                        HStack(spacing: LapisTheme.Spacing.xs) {
                            Text(loader.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(LapisTheme.Colors.accent)
                                .padding(.horizontal, LapisTheme.Spacing.sm)
                                .padding(.vertical, LapisTheme.Spacing.xs)
                                .background(
                                    Capsule()
                                        .fill(LapisTheme.Colors.accent.opacity(0.12))
                                )
                        }
                    }
                    .padding(.horizontal, LapisTheme.Spacing.xl)
                    
                    Spacer()
                    
                    // SELECT button
                    Button {
                        if let sub = selectedSubVersion {
                            onSelect(sub)
                        }
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
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedSubVersion == nil)
                    .opacity(selectedSubVersion == nil ? 0.4 : 1.0)
                    .padding(.horizontal, LapisTheme.Spacing.xl)
                    .padding(.bottom, LapisTheme.Spacing.xl)
                }
            } else {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
        .background(LapisTheme.Colors.surface.opacity(0.5).ignoresSafeArea())
        .overlay(
            Rectangle().fill(LapisTheme.Colors.divider).frame(width: 1),
            alignment: .leading
        )
    }
}
