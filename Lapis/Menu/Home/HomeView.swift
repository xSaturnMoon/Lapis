import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var downloader = GameDownloader()
    @State private var pulseAnimation = false
    @State private var showInputMode = false
    @State private var showDownloadProgress = false
    @State private var selectedInputMode: InputMode? = nil
    @State private var showLaunchError = false
    @State private var launchErrorText = ""
    
    var body: some View {
        ZStack {
            // Main Home content
            mainContent
            
            // Input mode overlay
            if showInputMode {
                InputModeView { mode in
                    selectedInputMode = mode
                    withAnimation(LapisTheme.Animation.smooth) {
                        showInputMode = false
                    }
                    startGameFlow(mode: mode)
                }
                .transition(.opacity)
            }
            
            // Download overlay
            if showDownloadProgress {
                DownloadProgressView(downloader: downloader)
                    .transition(.opacity)
                    .onChange(of: downloader.isComplete) { complete in
                        if complete {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation { showDownloadProgress = false }
                                launchGame()
                            }
                        }
                    }
            }
        }
        .alert("Launch Error", isPresented: $showLaunchError) {
            Button("OK") {}
        } message: {
            Text(launchErrorText)
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        ZStack {
            LinearGradient(
                colors: [LapisTheme.Colors.background, LapisTheme.Colors.surface.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Text("HOME")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textSecondary)
                        .tracking(2)
                    Spacer()
                    HStack(spacing: LapisTheme.Spacing.xs) {
                        Circle()
                            .fill(appState.isLoggedIn ? LapisTheme.Colors.success : LapisTheme.Colors.danger)
                            .frame(width: 8, height: 8)
                        Text(appState.isLoggedIn ? appState.playerName : "Not signed in")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(LapisTheme.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, LapisTheme.Spacing.xxl)
                .padding(.top, LapisTheme.Spacing.xl)
                
                Spacer()
                
                VStack(spacing: LapisTheme.Spacing.xxl) {
                    // Title
                    VStack(spacing: LapisTheme.Spacing.sm) {
                        Text("LAPIS")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [LapisTheme.Colors.accent, LapisTheme.Colors.accentLight],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                        Text("Minecraft Java Launcher")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LapisTheme.Colors.textSecondary)
                    }
                    
                    // Selected version card
                    if let version = appState.selectedVersion {
                        HStack(spacing: LapisTheme.Spacing.lg) {
                            ZStack {
                                RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                                    .fill(LapisTheme.Colors.accent.opacity(0.1))
                                    .frame(width: 56, height: 56)
                                Image(systemName: appState.selectedLoader.iconName)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(LapisTheme.Colors.accent)
                            }
                            VStack(alignment: .leading, spacing: LapisTheme.Spacing.xs) {
                                Text("\(appState.selectedLoader.rawValue) \(version.id)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(LapisTheme.Colors.textPrimary)
                                Text(version.type.capitalized)
                                    .font(.system(size: 13))
                                    .foregroundColor(LapisTheme.Colors.textSecondary)
                            }
                            Spacer()
                            
                            // JIT status
                            let jitAvailable = PojavBridge.isJITAvailable()
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(jitAvailable ? LapisTheme.Colors.success : LapisTheme.Colors.warning)
                                    .frame(width: 6, height: 6)
                                Text(jitAvailable ? "JIT" : "No JIT")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(LapisTheme.Colors.textMuted)
                            }
                        }
                        .padding(LapisTheme.Spacing.xl)
                        .frame(maxWidth: 420)
                        .glassBackground()
                    } else {
                        VStack(spacing: LapisTheme.Spacing.md) {
                            Image(systemName: "square.stack.3d.up.slash")
                                .font(.system(size: 32, weight: .light))
                                .foregroundColor(LapisTheme.Colors.textMuted)
                            Text("No version selected")
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
                        .padding(LapisTheme.Spacing.xxl)
                        .frame(maxWidth: 420)
                        .glassBackground()
                    }
                    
                    // PLAY button
                    Button {
                        withAnimation(LapisTheme.Animation.smooth) {
                            showInputMode = true
                        }
                    } label: {
                        HStack(spacing: LapisTheme.Spacing.md) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("PLAY")
                                .font(.system(size: 16, weight: .bold))
                                .tracking(2)
                        }
                        .foregroundColor(LapisTheme.Colors.background)
                        .frame(width: 220, height: 52)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                                    .fill(LinearGradient(
                                        colors: [LapisTheme.Colors.accent, LapisTheme.Colors.accentDark],
                                        startPoint: .top, endPoint: .bottom
                                    ))
                                if pulseAnimation {
                                    RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                                        .fill(LapisTheme.Colors.accentGlow)
                                        .blur(radius: 12)
                                        .scaleEffect(1.1)
                                }
                            }
                        )
                        .shadow(color: LapisTheme.Colors.accent.opacity(0.3), radius: 16, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.selectedVersion == nil || !appState.isLoggedIn)
                    .opacity(appState.selectedVersion == nil || !appState.isLoggedIn ? 0.4 : 1.0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            pulseAnimation = true
                        }
                    }
                    
                    if !appState.isLoggedIn && appState.selectedVersion != nil {
                        Text("Sign in with Microsoft to play")
                            .font(.system(size: 12))
                            .foregroundColor(LapisTheme.Colors.warning)
                    }
                }
                
                Spacer()
                
                HStack {
                    Text("v1.0.0")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                    Spacer()
                }
                .padding(.horizontal, LapisTheme.Spacing.xxl)
                .padding(.bottom, LapisTheme.Spacing.lg)
            }
        }
    }
    
    // MARK: - Game Flow
    private func startGameFlow(mode: InputMode) {
        guard let version = appState.selectedVersion else { return }
        
        // Step 1: Ensure JRE is available
        let jrePath = setupJRE()
        if jrePath == nil {
            launchErrorText = "Java Runtime (JRE) not found.\n\nThe JRE should be bundled with the app. Try reinstalling Lapis."
            showLaunchError = true
            return
        }
        
        // Step 2: Check game files
        if downloader.isVersionDownloaded(version.id) {
            launchGame()
        } else {
            withAnimation { showDownloadProgress = true }
            Task {
                await downloader.downloadVersion(version.id)
            }
        }
    }
    
    /// Find JRE: check Documents first, then app bundle. Copy from bundle if needed.
    private func setupJRE() -> String? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docsJRE = docs.appendingPathComponent("Lapis/jre")
        
        // Check Documents/Lapis/jre first
        if fm.fileExists(atPath: docsJRE.path) {
            return docsJRE.path
        }
        
        // Check app bundle
        let bundlePath = Bundle.main.bundlePath
        let bundleJRE = URL(fileURLWithPath: bundlePath).appendingPathComponent("jre")
        
        if fm.fileExists(atPath: bundleJRE.path) {
            // Copy from bundle to Documents (writable)
            try? fm.createDirectory(at: docsJRE.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.copyItem(at: bundleJRE, to: docsJRE)
            return docsJRE.path
        }
        
        return nil
    }
    
    private func launchGame() {
        guard let version = appState.selectedVersion,
              let mode = selectedInputMode else { return }
        
        // Set JRE path
        if let jrePath = setupJRE() {
            PojavBridge.setJavaHome(jrePath)
        }
        
        let launcher = GameLauncher(appState: appState)
        launcher.launchGame(
            versionId: version.id,
            loader: appState.selectedLoader,
            inputMode: mode
        )
        
        if let error = launcher.launchError {
            launchErrorText = error
            showLaunchError = true
        }
    }
}

