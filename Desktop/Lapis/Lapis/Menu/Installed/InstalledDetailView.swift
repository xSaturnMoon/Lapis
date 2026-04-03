import SwiftUI

struct InstalledDetailView: View {
    let version: GameVersion
    let onBack: () -> Void
    
    @State private var selectedTab: InstalledDetailTab = .mods
    
    enum InstalledDetailTab: String, CaseIterable {
        case mods = "Mods"
        case modrinth = "Modrinth"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack(spacing: LapisTheme.Spacing.lg) {
                // Back button
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(LapisTheme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .glassBackground(cornerRadius: LapisTheme.Radius.small)
                }
                .buttonStyle(.plain)
                
                // Version title
                VStack(alignment: .leading, spacing: 2) {
                    Text("MINECRAFT \(version.versionNumber)")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(LapisTheme.Colors.textPrimary)
                    
                    Text(version.loader.rawValue + " • " + version.modsFolderName)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                }
                
                Spacer()
                
                // Tab switcher
                HStack(spacing: 0) {
                    ForEach(InstalledDetailTab.allCases, id: \.rawValue) { tab in
                        Button {
                            withAnimation(LapisTheme.Animation.fast) {
                                selectedTab = tab
                            }
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(selectedTab == tab ? LapisTheme.Colors.accent : LapisTheme.Colors.textMuted)
                                .padding(.horizontal, LapisTheme.Spacing.lg)
                                .padding(.vertical, LapisTheme.Spacing.sm)
                                .background(
                                    Group {
                                        if selectedTab == tab {
                                            RoundedRectangle(cornerRadius: LapisTheme.Radius.small)
                                                .fill(LapisTheme.Colors.accent.opacity(0.1))
                                        }
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .glassBackground(cornerRadius: LapisTheme.Radius.medium)
            }
            .padding(.horizontal, LapisTheme.Spacing.xxl)
            .padding(.top, LapisTheme.Spacing.xl)
            .padding(.bottom, LapisTheme.Spacing.lg)
            
            Rectangle()
                .fill(LapisTheme.Colors.divider)
                .frame(height: 1)
            
            // MARK: Tab Content
            switch selectedTab {
            case .mods:
                ModsListView(version: version)
            case .modrinth:
                ModrinthBrowserView(version: version)
            }
        }
    }
}

// MARK: - Mods List View
struct ModsListView: View {
    let version: GameVersion
    @State private var searchText: String = ""
    
    // Sample mods for UI development
    private let sampleMods: [InstalledMod] = [
        InstalledMod(id: "1", name: "Fabric API", author: "modmuss50", version: "0.92.1+1.21.1", fileName: "fabric-api-0.92.1.jar", iconURL: nil, isEnabled: true),
        InstalledMod(id: "2", name: "Sodium", author: "CaffeineMC", version: "0.5.8+mc1.21.1", fileName: "sodium-0.5.8.jar", iconURL: nil, isEnabled: true),
        InstalledMod(id: "3", name: "Iris Shaders", author: "coderbot", version: "1.7.0+mc1.21.1", fileName: "iris-1.7.0.jar", iconURL: nil, isEnabled: true),
        InstalledMod(id: "4", name: "Lithium", author: "CaffeineMC", version: "0.12.1+mc1.21.1", fileName: "lithium-0.12.1.jar", iconURL: nil, isEnabled: false),
        InstalledMod(id: "5", name: "Entity Culling", author: "tr7zw", version: "1.6.2+mc1.21.1", fileName: "entity-culling-1.6.2.jar", iconURL: nil, isEnabled: true),
        InstalledMod(id: "6", name: "ModMenu", author: "Terraformers", version: "11.0.1", fileName: "modmenu-11.0.1.jar", iconURL: nil, isEnabled: true),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and counter
            HStack {
                HStack(spacing: LapisTheme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                    
                    TextField("Search mods...", text: $searchText)
                        .font(.system(size: 13))
                        .foregroundColor(LapisTheme.Colors.textPrimary)
                }
                .padding(LapisTheme.Spacing.md)
                .glassBackground(cornerRadius: LapisTheme.Radius.small)
                .frame(maxWidth: 300)
                
                Spacer()
                
                Text("\(sampleMods.count) mods")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LapisTheme.Colors.textMuted)
            }
            .padding(.horizontal, LapisTheme.Spacing.xxl)
            .padding(.vertical, LapisTheme.Spacing.md)
            
            // Mod list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: LapisTheme.Spacing.sm) {
                    ForEach(sampleMods) { mod in
                        ModRow(mod: mod)
                    }
                }
                .padding(.horizontal, LapisTheme.Spacing.xxl)
                .padding(.bottom, LapisTheme.Spacing.xxl)
            }
        }
    }
}

// MARK: - Single Mod Row
struct ModRow: View {
    let mod: InstalledMod
    @State private var isEnabled: Bool
    
    init(mod: InstalledMod) {
        self.mod = mod
        _isEnabled = State(initialValue: mod.isEnabled)
    }
    
    var body: some View {
        HStack(spacing: LapisTheme.Spacing.lg) {
            // Mod icon placeholder
            ZStack {
                RoundedRectangle(cornerRadius: LapisTheme.Radius.small)
                    .fill(LapisTheme.Colors.surfaceLight)
                    .frame(width: 44, height: 44)
                
                Text(String(mod.name.prefix(2)))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(LapisTheme.Colors.accent)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(mod.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(LapisTheme.Colors.textPrimary)
                
                Text("By \(mod.author)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(LapisTheme.Colors.textMuted)
            }
            
            Spacer()
            
            // Version badge
            Text(mod.version)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(LapisTheme.Colors.textSecondary)
                .padding(.horizontal, LapisTheme.Spacing.sm)
                .padding(.vertical, LapisTheme.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: LapisTheme.Radius.small)
                        .fill(LapisTheme.Colors.surface)
                )
            
            // Enable/Disable toggle
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(LapisTheme.Colors.accent)
            
            // More options
            Button {
                // Context menu: remove, update, etc.
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LapisTheme.Colors.textMuted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(LapisTheme.Spacing.lg)
        .glassBackground()
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}
