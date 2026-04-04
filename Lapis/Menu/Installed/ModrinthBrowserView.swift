import SwiftUI

struct ModrinthBrowserView: View {
    let version: InstalledVersion
    @StateObject private var modrinthService = ModrinthService()
    @State private var searchText: String = ""
    @State private var sortBy: String = "Popularity"
    @State private var selectedCategory: String? = nil
    @State private var downloadingMods: Set<String> = []
    
    private let categories = ["Adventure", "Decoration", "Equipment", "Optimization", "Library", "Utility", "Cursed", "Economy", "Food"]
    
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
                            .onSubmit {
                                performSearch()
                            }
                    }
                    .padding(LapisTheme.Spacing.md)
                    .glassBackground(cornerRadius: LapisTheme.Radius.small)
                    
                    Button("Search") {
                        performSearch()
                    }
                    .buttonStyle(LapisButtonStyle(isAccent: true))
                    
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
                    .background(Capsule().fill(LapisTheme.Colors.success.opacity(0.12)))
                }
                .padding(.horizontal, LapisTheme.Spacing.xl)
                .padding(.vertical, LapisTheme.Spacing.md)
                
                // Results
                if modrinthService.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(LapisTheme.Colors.accent)
                    Text("Searching Modrinth...")
                        .font(.system(size: 12))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                        .padding(.top, LapisTheme.Spacing.sm)
                    Spacer()
                } else if let error = modrinthService.error {
                    Spacer()
                    VStack(spacing: LapisTheme.Spacing.md) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 28))
                            .foregroundColor(LapisTheme.Colors.danger)
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(LapisTheme.Colors.textSecondary)
                    }
                    Spacer()
                } else if modrinthService.searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: LapisTheme.Spacing.md) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(LapisTheme.Colors.textMuted)
                        Text("Search for mods on Modrinth")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LapisTheme.Colors.textSecondary)
                        Text("Results will appear here")
                            .font(.system(size: 12))
                            .foregroundColor(LapisTheme.Colors.textMuted)
                    }
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: LapisTheme.Spacing.sm) {
                            ForEach(modrinthService.searchResults) { mod in
                                ModrinthResultRow(
                                    mod: mod,
                                    version: version,
                                    isDownloading: downloadingMods.contains(mod.id),
                                    onInstall: { modVer in
                                        installMod(mod, modVersion: modVer)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, LapisTheme.Spacing.xl)
                        .padding(.bottom, LapisTheme.Spacing.xxl)
                    }
                }
            }
            
            // MARK: Right: Filters
            VStack(alignment: .leading, spacing: LapisTheme.Spacing.xl) {
                VStack(alignment: .leading, spacing: LapisTheme.Spacing.sm) {
                    Text("INSTALL TO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                        .tracking(1)
                    
                    HStack(spacing: LapisTheme.Spacing.sm) {
                        LapisImage(version.loader.iconName)
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                            .foregroundColor(LapisTheme.Colors.accent)
                        Text(version.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(LapisTheme.Colors.textPrimary)
                    }
                    .padding(LapisTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassBackground(cornerRadius: LapisTheme.Radius.small)
                }
                
                VStack(alignment: .leading, spacing: LapisTheme.Spacing.sm) {
                    Text("CATEGORIES")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                        .tracking(1)
                    
                    FlowLayout(spacing: LapisTheme.Spacing.xs) {
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            } label: {
                                Text(cat)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(selectedCategory == cat ? LapisTheme.Colors.accent : LapisTheme.Colors.textSecondary)
                                    .padding(.horizontal, LapisTheme.Spacing.md)
                                    .padding(.vertical, LapisTheme.Spacing.xs)
                                    .background(
                                        Capsule().fill(selectedCategory == cat ? LapisTheme.Colors.accent.opacity(0.12) : LapisTheme.Colors.glassBackground)
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
            .background(LapisTheme.Colors.surface.opacity(0.3).ignoresSafeArea())
            .overlay(Rectangle().fill(LapisTheme.Colors.divider).frame(width: 1), alignment: .leading)
        }
        .onAppear {
            // Auto-search popular mods on appear
            performSearch()
        }
    }
    
    private func performSearch() {
        Task {
            await modrinthService.searchMods(
                query: searchText,
                gameVersion: version.versionNumber,
                loader: version.loader
            )
        }
    }
    
    private func installMod(_ mod: ModrinthMod, modVersion: ModrinthVersion) {
        downloadingMods.insert(mod.id)
        
        Task {
            if let file = modVersion.files.first {
                let success = await modrinthService.downloadMod(
                    fileURL: file.url,
                    fileName: file.filename,
                    gameVersion: version.versionNumber,
                    loader: version.loader
                )
                
                await MainActor.run {
                    downloadingMods.remove(mod.id)
                }
            } else {
                await MainActor.run {
                    downloadingMods.remove(mod.id)
                }
            }
        }
    }
}

// MARK: - Modrinth Result Row
struct ModrinthResultRow: View {
    let mod: ModrinthMod
    let version: InstalledVersion
    let isDownloading: Bool
    let onInstall: (ModrinthVersion) -> Void
    
    @StateObject private var service = ModrinthService()
    @State private var fetchedVersions: [ModrinthVersion]? = nil
    @State private var isFetchingVersions = false
    
    var body: some View {
        HStack(spacing: LapisTheme.Spacing.lg) {
            // Icon
            if let iconUrl = mod.icon_url, let url = URL(string: iconUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: LapisTheme.Radius.small)
                        .fill(LapisTheme.Colors.surfaceLight)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: LapisTheme.Radius.small))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: LapisTheme.Radius.small)
                        .fill(LapisTheme.Colors.surfaceLight)
                        .frame(width: 48, height: 48)
                    Text(String(mod.title.prefix(2)))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.accent)
                }
            }
            
            VStack(alignment: .leading, spacing: LapisTheme.Spacing.xs) {
                Text(mod.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(LapisTheme.Colors.textPrimary)
                
                Text(mod.description)
                    .font(.system(size: 11))
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
            
            VStack(alignment: .trailing, spacing: LapisTheme.Spacing.xs) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 10))
                    Text(mod.downloadString)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(LapisTheme.Colors.textMuted)
            }
            
            // Install button
            if isDownloading {
                ProgressView()
                    .tint(LapisTheme.Colors.accent)
                    .frame(width: 70)
            } else if isFetchingVersions {
                ProgressView()
                    .tint(LapisTheme.Colors.accent)
                    .frame(width: 70)
            } else if let versions = fetchedVersions {
                Menu {
                    ForEach(versions, id: \.id) { modVer in
                        Button(action: {
                            onInstall(modVer)
                            fetchedVersions = nil
                        }) {
                            Text(modVer.version_number ?? "Unknown Version")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Select")
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(LapisTheme.Colors.accent)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
            } else {
                Button {
                    fetchVersions()
                } label: {
                    Text("Install")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(LapisButtonStyle(isAccent: true))
            }
        }
        .padding(LapisTheme.Spacing.lg)
        .glassBackground()
    }
    
    private func fetchVersions() {
        isFetchingVersions = true
        Task {
            let vers = await service.getModVersions(
                projectId: mod.project_id,
                gameVersion: version.versionNumber,
                loader: version.loader
            )
            await MainActor.run {
                if vers.isEmpty {
                    // Fallback to error or empty
                }
                self.fetchedVersions = vers
                self.isFetchingVersions = false
            }
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangeSubviews(proposal: proposal, subviews: subviews).size
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
        var x: CGFloat = 0; var y: CGFloat = 0; var rowHeight: CGFloat = 0; var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height); x += size.width + spacing; maxX = max(maxX, x)
        }
        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
