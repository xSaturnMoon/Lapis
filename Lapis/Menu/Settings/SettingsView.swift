import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    // Settings state
    @State private var allocatedRAM: Double = 2048
    @State private var enableJIT: Bool = true
    @State private var renderScale: Double = 100
    @State private var fullscreen: Bool = true
    @State private var customJVMArgs: String = ""
    @State private var selectedLanguage: String = "English"
    
    let maxRAM: Double = 6144 // 6GB — sensible max for iOS
    let languages = ["English", "Italiano", "Español", "Français", "Deutsch", "日本語"]
    
    var body: some View {
        ZStack {
            LapisTheme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: Header
                HStack {
                    Text("SETTINGS")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textSecondary)
                        .tracking(2)
                    Spacer()
                }
                .padding(.horizontal, LapisTheme.Spacing.xxl)
                .padding(.top, LapisTheme.Spacing.xl)
                .padding(.bottom, LapisTheme.Spacing.lg)
                
                // MARK: Scrollable Sections
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: LapisTheme.Spacing.lg) {
                        
                        // ── Performance ──
                        SettingsSection(title: "Performance", icon: "bolt.fill") {
                            // RAM slider
                            VStack(alignment: .leading, spacing: LapisTheme.Spacing.sm) {
                                HStack {
                                    Text("Allocated RAM")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(LapisTheme.Colors.textPrimary)
                                    Spacer()
                                    Text("\(Int(allocatedRAM)) MB")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(LapisTheme.Colors.accent)
                                }
                                
                                Slider(value: $allocatedRAM, in: 512...maxRAM, step: 256)
                                    .tint(LapisTheme.Colors.accent)
                                
                                Text("Higher values improve performance but use more device memory.")
                                    .font(.system(size: 11))
                                    .foregroundColor(LapisTheme.Colors.textMuted)
                            }
                            
                            Divider().overlay(LapisTheme.Colors.divider)
                            
                            // JIT toggle
                            SettingsToggle(
                                title: "Enable JIT Compilation",
                                subtitle: "Required for Java performance on iOS. Needs JIT entitlement.",
                                isOn: $enableJIT
                            )
                        }
                        
                        // ── Video ──
                        SettingsSection(title: "Video", icon: "display") {
                            VStack(alignment: .leading, spacing: LapisTheme.Spacing.sm) {
                                HStack {
                                    Text("Render Scale")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(LapisTheme.Colors.textPrimary)
                                    Spacer()
                                    Text("\(Int(renderScale))%")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(LapisTheme.Colors.accent)
                                }
                                
                                Slider(value: $renderScale, in: 50...200, step: 25)
                                    .tint(LapisTheme.Colors.accent)
                                
                                Text("Lower values improve FPS at the cost of visual quality.")
                                    .font(.system(size: 11))
                                    .foregroundColor(LapisTheme.Colors.textMuted)
                            }
                            
                            Divider().overlay(LapisTheme.Colors.divider)
                            
                            SettingsToggle(
                                title: "Fullscreen",
                                subtitle: "Use the entire screen for gameplay.",
                                isOn: $fullscreen
                            )
                        }
                        
                        // ── Java ──
                        SettingsSection(title: "Java", icon: "chevron.left.forwardslash.chevron.right") {
                            VStack(alignment: .leading, spacing: LapisTheme.Spacing.sm) {
                                Text("Custom JVM Arguments")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(LapisTheme.Colors.textPrimary)
                                
                                TextField("e.g. -XX:+UseG1GC", text: $customJVMArgs)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(LapisTheme.Colors.textPrimary)
                                    .padding(LapisTheme.Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: LapisTheme.Radius.small)
                                            .fill(LapisTheme.Colors.background)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: LapisTheme.Radius.small)
                                            .stroke(LapisTheme.Colors.glassBorder, lineWidth: 1)
                                    )
                                
                                Text("Advanced: Add custom arguments passed to the JVM on launch.")
                                    .font(.system(size: 11))
                                    .foregroundColor(LapisTheme.Colors.textMuted)
                            }
                        }
                        
                        // ── Launcher ──
                        SettingsSection(title: "Launcher", icon: "wrench.and.screwdriver.fill") {
                            // Language picker
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Language")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(LapisTheme.Colors.textPrimary)
                                    Text("Interface display language.")
                                        .font(.system(size: 11))
                                        .foregroundColor(LapisTheme.Colors.textMuted)
                                }
                                
                                Spacer()
                                
                                Picker("", selection: $selectedLanguage) {
                                    ForEach(languages, id: \.self) { lang in
                                        Text(lang).tag(lang)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(LapisTheme.Colors.accent)
                            }
                        }
                        
                        // ── About ──
                        SettingsSection(title: "About", icon: "info.circle.fill") {
                            VStack(spacing: LapisTheme.Spacing.md) {
                                SettingsInfoRow(label: "Version", value: "1.0.0")
                                SettingsInfoRow(label: "Build", value: "1")
                                SettingsInfoRow(label: "Engine", value: "PojavLauncher Core")
                                SettingsInfoRow(label: "Developer", value: "xSaturnMoon")
                            }
                        }
                        
                        Spacer().frame(height: LapisTheme.Spacing.xxl)
                    }
                    .padding(.horizontal, LapisTheme.Spacing.xxl)
                }
            }
        }
    }
}

// MARK: - Settings Section Container
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: LapisTheme.Spacing.lg) {
            // Section header
            HStack(spacing: LapisTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(LapisTheme.Colors.accent)
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(LapisTheme.Colors.accent)
                    .tracking(1.5)
            }
            
            // Content
            VStack(alignment: .leading, spacing: LapisTheme.Spacing.md) {
                content
            }
            .padding(LapisTheme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassBackground()
        }
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LapisTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(LapisTheme.Colors.textMuted)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(LapisTheme.Colors.accent)
        }
    }
}

// MARK: - Settings Info Row
struct SettingsInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(LapisTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(LapisTheme.Colors.textPrimary)
        }
    }
}
