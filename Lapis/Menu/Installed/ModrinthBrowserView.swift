import SwiftUI

struct ModrinthBrowserView: View {
    let version: GameVersion
    @State private var searchText: String = ""
    @State private var sortBy: String = "Popularity"
    @State private var selectedCategory: String? = nil
    
    private let sortOptions = ["Popularity", "Downloads", "Updated", "Newest"]
    private let categories = ["Adventure", "Decoration", "Equipment", "Optimization", "Library", "Utility", "Cursed", "Economy", "Food"]
    
    // Sample Modrinth results for UI
    private let sampleResults: [ModrinthMod] = [
        ModrinthMod(id: "1", slug: "fabric-api", title: "Fabric API", description: "Lightweight and modular API providing common hooks and interoperability measures utilized by mods using the Fabric toolchain.", author: "modmuss50", downloads: 152_120_000, iconUrl: nil, categories: ["Library"], loaders: ["Fabric"], dateModified: "1 day ago", isInstalled: true),
        ModrinthMod(id: "2", slug: "sodium", title: "Sodium", description: "The fastest and most compatible rendering optimization mod. Now available for both NeoForge and Fabric!", author: "CaffeineMC", downloads: 138_330_000, iconUrl: nil, categories: ["Optimization"], loaders: ["Fabric", "NeoForge"], dateModified: "5 hours ago", isInstalled: true),
        ModrinthMod(id: "3", slug: "cloth-config", title: "Cloth Config API", description: "Configuration Library for Minecraft Mods.", author: "shedaniel", downloads: 109_330_000, iconUrl: nil, categories: ["Library"], loaders: ["Fabric"], dateModified: "8 days ago", isInstalled: false),
        ModrinthMod(id: "4", slug: "iris", title: "Iris Shaders", description: "A modern shader loader for Minecraft intended to be compatible with existing OptiFine shader packs.", author: "coderbot", downloads: 107_450_000, iconUrl: nil, categories: ["Decoration"], loaders: ["Fabric"], dateModified: "5 hours ago", isInstalled: true),
        ModrinthMod(id: "5", slug: "entity-culling", title: "Entity Culling", description: "Using async path-tracing to hide Block-/Entities that are not visible.", author: "tr7zw", downloads: 99_510_000, iconUrl: nil, categories: ["Optimization"], loaders: ["Fabric", "Forge"], dateModified: "9 days ago", isInstalled: false),
        ModrinthMod(id: "6", slug: "ferrite-core", title: "FerriteCore", description: "Memory usage optimizations.", author: "malte0811", downloads: 99_190_000, iconUrl: nil, categories: ["Optimization"], loaders: ["Fabric", "Forge"], dateModified: "10 days ago", isInstalled: false),
        ModrinthMod(id: "7", slug: "lithium", title: "Lithium", description: "No-compromise game logic optimization mod. Well suited for both clients and servers of all kinds.", author: "CaffeineMC", downloads: 83_670_000, iconUrl: nil, categories: ["Optimization"], loaders: ["Fabric", "NeoForge"], dateModified: "2 days ago", isInstalled: false),
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            // MARK: Left: Search Results
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: LapisTheme.Spacing.md) {
                    HStack(spacing: LapisTheme.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundColor(LapisTheme.Colors.textMuted)
                        
                        TextField("Search Modrinth...", text: $searchText)
                            .font(.system(size: 13))
                            .foregroundColor(LapisTheme.Colors.textPrimary)
                    }
                    .padding(LapisTheme.Spacing.md)
                    .glassBackground(cornerRadius: LapisTheme.Radius.small)
                    
                    // Sort dropdown
                    Menu {
                        ForEach(sortOptions, id: \.self) { option in
                            Button {
                                sortBy = option
                            } label: {
                                Label(option, systemImage: sortBy == option ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: LapisTheme.Spacing.xs) {
                            Text("Sort: \(sortBy)")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(LapisTheme.Colors.textSecondary)
                        .padding(.horizontal, LapisTheme.Spacing.md)
                        .padding(.vertical, LapisTheme.Spacing.sm)
                        .glassBackground(cornerRadius: LapisTheme.Radius.small)
                    }
                    
                    // Modrinth badge
                    HStack(spacing: LapisTheme.Spacing.xs) {
                        Image(systemName: "link")
                            .font(.system(size: 10, weight: .bold))
                        Text("Modrinth")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(LapisTheme.Colors.success)
                    .padding(.horizontal, LapisTheme.Spacing.md)
                    .padding(.vertical, LapisTheme.Spacing.sm)
                    .background(
                        Capsule().fill(LapisTheme.Colors.success.opacity(0.12))
                    )
                }
                .padding(.horizontal, LapisTheme.Spacing.xl)
                .padding(.vertical, LapisTheme.Spacing.md)
                
                // Results
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: LapisTheme.Spacing.sm) {
                        ForEach(sampleResults) { mod in
                            ModrinthResultRow(mod: mod, version: version)
                        }
                    }
                    .padding(.horizontal, LapisTheme.Spacing.xl)
                    .padding(.bottom, LapisTheme.Spacing.xxl)
                }
            }
            
            // MARK: Right: Filters Sidebar
            VStack(alignment: .leading, spacing: LapisTheme.Spacing.xl) {
                // Install target
                VStack(alignment: .leading, spacing: LapisTheme.Spacing.sm) {
                    Text("INSTALL TO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                        .tracking(1)
                    
                    HStack(spacing: LapisTheme.Spacing.sm) {
                        Image(systemName: version.loader.iconName)
                            .font(.system(size: 12))
                            .foregroundColor(LapisTheme.Colors.accent)
                        Text(version.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(LapisTheme.Colors.textPrimary)
                    }
                    .padding(LapisTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassBackground(cornerRadius: LapisTheme.Radius.small)
                }
                
                // Categories
                VStack(alignment: .leading, spacing: LapisTheme.Spacing.sm) {
                    Text("CATEGORIES")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                        .tracking(1)
                    
                    FlowLayout(spacing: LapisTheme.Spacing.xs) {
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                if selectedCategory == cat {
                                    selectedCategory = nil
                                } else {
                                    selectedCategory = cat
                                }
                            } label: {
                                Text(cat)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(selectedCategory == cat ? LapisTheme.Colors.accent : LapisTheme.Colors.textSecondary)
                                    .padding(.horizontal, LapisTheme.Spacing.md)
                                    .padding(.vertical, LapisTheme.Spacing.xs)
                                    .background(
                                        Capsule()
                                            .fill(selectedCategory == cat ? LapisTheme.Colors.accent.opacity(0.12) : LapisTheme.Colors.glassBackground)
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(selectedCategory == cat ? LapisTheme.Colors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(LapisTheme.Spacing.xl)
            .frame(width: 200)
            .background(
                LapisTheme.Colors.surface.opacity(0.3)
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
}

// MARK: - Modrinth Result Row
struct ModrinthResultRow: View {
    let mod: ModrinthMod
    let version: GameVersion
    
    private var downloadString: String {
        if mod.downloads >= 1_000_000 {
            return String(format: "%.1fM", Double(mod.downloads) / 1_000_000)
        } else if mod.downloads >= 1_000 {
            return String(format: "%.0fK", Double(mod.downloads) / 1_000)
        }
        return "\(mod.downloads)"
    }
    
    var body: some View {
        HStack(spacing: LapisTheme.Spacing.lg) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: LapisTheme.Radius.small)
                    .fill(LapisTheme.Colors.surfaceLight)
                    .frame(width: 48, height: 48)
                
                Text(String(mod.title.prefix(2)))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(LapisTheme.Colors.accent)
            }
            
            // Info
            VStack(alignment: .leading, spacing: LapisTheme.Spacing.xs) {
                HStack(spacing: LapisTheme.Spacing.sm) {
                    Text(mod.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textPrimary)
                    
                    if mod.isInstalled {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(LapisTheme.Colors.success)
                    }
                }
                
                Text(mod.description)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(LapisTheme.Colors.textSecondary)
                    .lineLimit(1)
                
                HStack(spacing: LapisTheme.Spacing.sm) {
                    Text(mod.author)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                    
                    ForEach(mod.categories.prefix(2), id: \.self) { cat in
                        Text(cat)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(LapisTheme.Colors.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(LapisTheme.Colors.glassBackground))
                    }
                }
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: LapisTheme.Spacing.xs) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 10))
                    Text(downloadString)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(LapisTheme.Colors.textMuted)
                
                Text(mod.dateModified)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(LapisTheme.Colors.textMuted)
            }
            
            // Action buttons
            HStack(spacing: LapisTheme.Spacing.sm) {
                Button {
                    // View mod details
                } label: {
                    Text("View")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(LapisButtonStyle())
                
                Button {
                    // Install / Already installed
                } label: {
                    Text(mod.isInstalled ? "Installed" : "Install")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(LapisButtonStyle(isAccent: !mod.isInstalled))
                .disabled(mod.isInstalled)
                .opacity(mod.isInstalled ? 0.7 : 1.0)
            }
        }
        .padding(LapisTheme.Spacing.lg)
        .glassBackground()
    }
}

// MARK: - Simple Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }
        
        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
