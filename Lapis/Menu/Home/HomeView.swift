import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("lapis_last_played_v2") private var lastPlayedId: String = ""
    @StateObject private var downloader = GameDownloader()
    @State private var pulseAnimation = false
    @State private var showInputMode = false
    @State private var showDownloadProgress = false
    @State private var selectedInputMode: InputMode? = nil
    @State private var showLaunchError = false
    @State private var launchErrorText = ""
    @State private var isLaunching = false
    
    var body: some View {
        ZStack {
            mainContent
            
            if showInputMode {
                InputModeView { mode in
                    selectedInputMode = mode
                    withAnimation(LapisTheme.Animation.smooth) {
                        showInputMode = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        startGameFlow(mode: mode)
                    }
                }
                .transition(.opacity)
            }
            
            if showDownloadProgress {
                DownloadProgressView(downloader: downloader)
                    .transition(.opacity)
                    .onChange(of: downloader.isComplete) { complete in
                        if complete {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation { showDownloadProgress = false }
                                if let mode = selectedInputMode {
                                    doLaunch(mode: mode)
                                }
                            }
                        }
                    }
            }
            
            // Launching overlay
            if isLaunching {
                ZStack {
                    LapisTheme.Colors.background.opacity(0.9)
                        .ignoresSafeArea()
                    VStack(spacing: LapisTheme.Spacing.xl) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(LapisTheme.Colors.accent)
                        Text("Launching Minecraft...")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(LapisTheme.Colors.textPrimary)
                        Text("This may take a moment")
                            .font(.system(size: 13))
                            .foregroundColor(LapisTheme.Colors.textMuted)
                    }
                }
                .transition(.opacity)
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
                    
                    if let version = appState.selectedVersion {
                        versionCard(version: version)
                    } else {
                        noVersionCard
                    }
                    
                    playButton
                    
                    if !appState.isLoggedIn && appState.selectedVersion != nil {
                        Text("Sign in with Microsoft to play")
                            .font(.system(size: 12))
                            .foregroundColor(LapisTheme.Colors.warning)
                    }
                }
                
                Spacer()
                
                HStack {
                    // Engine status
                    HStack(spacing: LapisTheme.Spacing.md) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(true ? LapisTheme.Colors.success : LapisTheme.Colors.danger)
                                .frame(width: 6, height: 6)
                            Text(true ? "Engine Ready" : "Engine Not Loaded")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(LapisTheme.Colors.textMuted)
                        }
                        
                        let isJIT = LapisEngine_isJITEnabled()
                        HStack(spacing: 4) {
                            Image(systemName: isJIT ? "bolt.circle.fill" : "bolt.slash.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(isJIT ? LapisTheme.Colors.success : LapisTheme.Colors.danger)
                            Text(isJIT ? "JIT Enabled" : "JIT Inactive")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(isJIT ? LapisTheme.Colors.success : LapisTheme.Colors.danger)
                        }
                    }
                    Spacer()
                    Text("v1.0.0")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                }
                .padding(.horizontal, LapisTheme.Spacing.xxl)
                .padding(.bottom, LapisTheme.Spacing.lg)
            }
        }
    }
    
    // MARK: - Version Card
    private func versionCard(version: GameVersion) -> some View {
        Menu {
            ForEach(appState.installedVersions) { iv in
                Button {
                    appState.selectedVersion = GameVersion(id: iv.versionNumber, type: "release", url: "", releaseTime: "")
                    appState.selectedLoader = iv.loader
                    lastPlayedId = iv.folderName
                } label: {
                    Text(iv.displayName)
                }
            }
        } label: {
        HStack(spacing: LapisTheme.Spacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                    .fill(LapisTheme.Colors.accent.opacity(0.1))
                    .frame(width: 56, height: 56)
                LapisImage(appState.selectedLoader.iconName)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(LapisTheme.Colors.accent)
            }
            VStack(alignment: .leading, spacing: LapisTheme.Spacing.xs) {
                HStack(spacing: 4) {
                    Text("\(appState.selectedLoader.rawValue) \(version.id)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                }
                Text("Installed Version (Tap to change)")
                    .font(.system(size: 11))
                    .foregroundColor(LapisTheme.Colors.textSecondary)
            }
        }
        .padding(LapisTheme.Spacing.xl)
        .frame(maxWidth: 420)
        .glassBackground()
        }
    }
    
    private var noVersionCard: some View {
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
    
    private var playButton: some View {
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
        .disabled(appState.selectedVersion == nil || !appState.isLoggedIn || isLaunching)
        .opacity(appState.selectedVersion == nil || !appState.isLoggedIn ? 0.4 : 1.0)
        .onAppear {
            appState.loadInstalledVersions()
            if let last = appState.installedVersions.first(where: { "\($0.versionNumber)-\($0.loader.rawValue)" == lastPlayedId || $0.folderName == lastPlayedId }) {
                appState.selectedVersion = GameVersion(id: last.versionNumber, type: "release", url: "", releaseTime: "")
                appState.selectedLoader = last.loader
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
    
    // MARK: - Game Flow
    private func startGameFlow(mode: InputMode) {
        guard let version = appState.selectedVersion else { return }
        
        if downloader.isVersionDownloaded(version.id) {
            doLaunch(mode: mode)
        } else {
            withAnimation { showDownloadProgress = true }
            Task {
                await downloader.downloadVersion(version.id)
            }
        }
    }
    
    private func doLaunch(mode: InputMode) {
        guard let version = appState.selectedVersion else { return }
        
        lastPlayedId = "\(version.id)-\(appState.selectedLoader.rawValue)"
        
        withAnimation { isLaunching = true }
        
        let config = GameLauncher.LaunchConfig(
            versionId: version.id,
            loader: appState.selectedLoader,
            inputMode: mode,
            playerName: appState.playerName,
            playerUUID: appState.playerUUID,
            accessToken: appState.accessToken
        )
        
        // Launch on background thread to keep UI responsive
        DispatchQueue.global(qos: .userInitiated).async {
            let error = GameLauncher.shared.launch(config: config)
            
            DispatchQueue.main.async {
                withAnimation { isLaunching = false }
                if let error = error {
                    launchErrorText = error
                    showLaunchError = true
                }
            }
        }
    }
}
