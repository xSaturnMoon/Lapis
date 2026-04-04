import SwiftUI

struct InstalledDetailView: View {
    let version: InstalledVersion
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
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(LapisTheme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .glassBackground(cornerRadius: LapisTheme.Radius.small)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("MINECRAFT \(version.versionNumber)")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(LapisTheme.Colors.textPrimary)
                    
                    Text(version.loader.rawValue + " • " + version.folderName)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                }
                
                Spacer()
                
                // Tab switcher
                if version.loader != .vanilla {
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
            }
            .padding(.horizontal, LapisTheme.Spacing.xxl)
            .padding(.top, LapisTheme.Spacing.xl)
            .padding(.bottom, LapisTheme.Spacing.lg)
            
            Rectangle()
                .fill(LapisTheme.Colors.divider)
                .frame(height: 1)
            
            if version.loader == .vanilla {
                Spacer()
                VStack(spacing: LapisTheme.Spacing.md) {
                    Image(systemName: "xmark.bin")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                    Text("Vanilla Minecraft does not support mods")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(LapisTheme.Colors.textSecondary)
                    Text("Install a mod loader like Fabric or Forge to use mods.")
                        .font(.system(size: 12))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                switch selectedTab {
                case .mods:
                    ModsListView(version: version)
                case .modrinth:
                    ModrinthBrowserView(version: version)
                }
            }
        }
    }
}

// MARK: - Mods List View (reads REAL .jar files from disk)
struct ModsListView: View {
    let version: InstalledVersion
    @State private var mods: [InstalledMod] = []
    @State private var searchText: String = ""
    
    private var filteredMods: [InstalledMod] {
        if searchText.isEmpty { return mods }
        return mods.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
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
                
                Text("\(mods.count) mods")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LapisTheme.Colors.textMuted)
            }
            .padding(.horizontal, LapisTheme.Spacing.xxl)
            .padding(.vertical, LapisTheme.Spacing.md)
            
            if mods.isEmpty {
                Spacer()
                VStack(spacing: LapisTheme.Spacing.md) {
                    Image(systemName: "puzzlepiece")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                    Text("No mods installed")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(LapisTheme.Colors.textSecondary)
                    Text("Use the Modrinth tab to find and install mods")
                        .font(.system(size: 12))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                }
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: LapisTheme.Spacing.sm) {
                        ForEach(filteredMods) { mod in
                            ModRow(mod: mod, version: version)
                        }
                    }
                    .padding(.horizontal, LapisTheme.Spacing.xxl)
                    .padding(.bottom, LapisTheme.Spacing.xxl)
                }
            }
        }
        .onAppear {
            loadModsFromDisk()
        }
    }
    
    /// Read real .jar files from the version's mod folder
    private func loadModsFromDisk() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modsDir = docs.appendingPathComponent("Lapis/mods/\(version.folderName)")
        
        guard let files = try? fm.contentsOfDirectory(at: modsDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            mods = []
            return
        }
        
        mods = files
            .filter { $0.pathExtension == "jar" }
            .map { file in
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                let name = file.deletingPathExtension().lastPathComponent
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " ")
                
                // Check if it's a .jar.disabled file
                let isEnabled = !file.lastPathComponent.hasSuffix(".disabled")
                
                return InstalledMod(
                    id: file.lastPathComponent,
                    name: name.capitalized,
                    fileName: file.lastPathComponent,
                    fileSize: Int64(size),
                    isEnabled: isEnabled
                )
            }
            .sorted { $0.name < $1.name }
    }
}

// MARK: - Single Mod Row
struct ModRow: View {
    let mod: InstalledMod
    let version: InstalledVersion
    @State private var isEnabled: Bool
    
    init(mod: InstalledMod, version: InstalledVersion) {
        self.mod = mod
        self.version = version
        _isEnabled = State(initialValue: mod.isEnabled)
    }
    
    private var fileSizeString: String {
        let kb = Double(mod.fileSize) / 1024
        if kb > 1024 {
            return String(format: "%.1f MB", kb / 1024)
        }
        return String(format: "%.0f KB", kb)
    }
    
    var body: some View {
        HStack(spacing: LapisTheme.Spacing.lg) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: LapisTheme.Radius.small)
                    .fill(LapisTheme.Colors.surfaceLight)
                    .frame(width: 44, height: 44)
                
                Text(String(mod.name.prefix(2)))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(LapisTheme.Colors.accent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(mod.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(LapisTheme.Colors.textPrimary)
                
                Text(mod.fileName)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(LapisTheme.Colors.textMuted)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(fileSizeString)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(LapisTheme.Colors.textSecondary)
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(LapisTheme.Colors.accent)
                .onChange(of: isEnabled) { newValue in
                    toggleMod(enabled: newValue)
                }
            
            Button {
                deleteMod()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(LapisTheme.Colors.danger)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(LapisTheme.Spacing.lg)
        .glassBackground()
        .opacity(isEnabled ? 1.0 : 0.6)
    }
    
    /// Rename .jar to .jar.disabled or vice versa
    private func toggleMod(enabled: Bool) {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modsDir = docs.appendingPathComponent("Lapis/mods/\(version.folderName)")
        
        let currentPath = modsDir.appendingPathComponent(mod.fileName)
        let newName = enabled ? mod.fileName.replacingOccurrences(of: ".disabled", with: "") : mod.fileName + ".disabled"
        let newPath = modsDir.appendingPathComponent(newName)
        
        try? fm.moveItem(at: currentPath, to: newPath)
    }
    
    /// Delete the mod file from disk
    private func deleteMod() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modPath = docs.appendingPathComponent("Lapis/mods/\(version.folderName)/\(mod.fileName)")
        try? fm.removeItem(at: modPath)
    }
}
