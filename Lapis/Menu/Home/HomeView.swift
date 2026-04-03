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
            mainContent
            
            if showInputMode {
                InputModeView { mode in
                    selectedInputMode = mode
                    withAnimation(LapisTheme.Animation.smooth) {
                        showInputMode = false
                    }
                    // Delay to avoid state conflict during animation
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
                        versionCard(version: version)
                    } else {
                        noVersionCard
                    }
                    
                    // PLAY button
                    playButton
                    
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
    
    // MARK: - Version Card
    private func versionCard(version: GameVersion) -> some View {
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
            
            // Static JIT reminder (actual JIT enabled via StikDebug/TrollStore)
            HStack(spacing: 4) {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(LapisTheme.Colors.warning)
                Text("Enable JIT")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(LapisTheme.Colors.textMuted)
            }
        }
        .padding(LapisTheme.Spacing.xl)
        .frame(maxWidth: 420)
        .glassBackground()
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
        .disabled(appState.selectedVersion == nil || !appState.isLoggedIn)
        .opacity(appState.selectedVersion == nil || !appState.isLoggedIn ? 0.4 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
    
    // MARK: - Game Flow
    private func startGameFlow(mode: InputMode) {
        guard let version = appState.selectedVersion else { return }
        
        // Ensure JRE is available
        if let jrePath = setupJRE() {
            PojavBridge.setJavaHome(jrePath)
        }
        
        // Check game files
        if downloader.isVersionDownloaded(version.id) {
            // Files already downloaded — launch
            doLaunch(version: version, mode: mode)
        } else {
            // Need to download first
            withAnimation { showDownloadProgress = true }
            Task {
                await downloader.downloadVersion(version.id)
            }
        }
    }
    
    private func setupJRE() -> String? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docsJRE = docs.appendingPathComponent("Lapis/jre")
        
        if fm.fileExists(atPath: docsJRE.path) {
            return docsJRE.path
        }
        
        let bundleJRE = Bundle.main.bundleURL.appendingPathComponent("jre")
        if fm.fileExists(atPath: bundleJRE.path) {
            try? fm.createDirectory(at: docsJRE.deletingLastPathComponent(), withIntermediateDirectories: true)
            do {
                try fm.copyItem(at: bundleJRE, to: docsJRE)
            } catch {
                NSLog("[Lapis] Failed to copy JRE: %@", error.localizedDescription)
            }
            if fm.fileExists(atPath: docsJRE.path) {
                return docsJRE.path
            }
        }
        
        return nil
    }
    
    private func doLaunch(version: GameVersion, mode: InputMode) {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let lapisRoot = docs.appendingPathComponent("Lapis")
        
        // Validate JRE
        guard let jrePath = setupJRE() else {
            launchErrorText = "Java Runtime (JRE) not found.\n\nThe JRE should be bundled with the app. Try reinstalling Lapis."
            showLaunchError = true
            return
        }
        
        // Validate libjli.dylib before dlopen
        let jliPath = (jrePath as NSString).appendingPathComponent("lib/libjli.dylib")
        if !fm.fileExists(atPath: jliPath) {
            launchErrorText = "JRE is incomplete.\n\nlibjli.dylib not found at:\n\(jliPath)\n\nThe JRE may not have been bundled correctly."
            showLaunchError = true
            return
        }
        
        // Validate client.jar
        let versionDir = lapisRoot.appendingPathComponent("versions/\(version.id)")
        let clientJar = versionDir.appendingPathComponent("\(version.id).jar")
        if !fm.fileExists(atPath: clientJar.path) {
            launchErrorText = "Game files not found.\nPlease re-download."
            showLaunchError = true
            return
        }
        
        // Save input mode
        UserDefaults.standard.set(mode == .touch ? "touch" : "keyboard", forKey: "lapis_input_mode")
        PojavBridge.setJavaHome(jrePath)
        
        // Build args
        let libDir = lapisRoot.appendingPathComponent("libraries")
        let gameDir = lapisRoot.appendingPathComponent("game")
        let modsDir = lapisRoot.appendingPathComponent("mods/mods-\(version.id)-\(appState.selectedLoader.rawValue.lowercased())")
        let assetsDir = lapisRoot.appendingPathComponent("assets")
        
        try? fm.createDirectory(at: gameDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: modsDir, withIntermediateDirectories: true)
        
        // Build classpath
        var cpPaths = [clientJar.path]
        if let enumerator = fm.enumerator(at: libDir, includingPropertiesForKeys: nil) {
            while let file = enumerator.nextObject() as? URL {
                if file.pathExtension == "jar" { cpPaths.append(file.path) }
            }
        }
        let classpath = cpPaths.joined(separator: ":")
        
        let ramMB = max(UserDefaults.standard.integer(forKey: "lapis_ram"), 1024)
        
        var jvmArgs: [String] = [
            "-Xmx\(ramMB)M", "-Xms\(ramMB / 2)M",
            "-XX:+UseG1GC", "-XX:MaxGCPauseMillis=200",
            "-Dfile.encoding=UTF-8",
            "-Djava.io.tmpdir=\(NSTemporaryDirectory())",
            "-Dos.name=iOS",
            "-cp", classpath,
        ]
        
        let gameArgs: [String] = [
            "--username", appState.playerName,
            "--version", version.id,
            "--gameDir", gameDir.path,
            "--assetsDir", assetsDir.path,
            "--assetIndex", version.id,
            "--uuid", appState.playerUUID,
            "--accessToken", appState.accessToken,
            "--userType", "msa",
            "--versionType", "Lapis"
        ]
        
        let allArgs = jvmArgs + ["net.minecraft.client.main.Main"] + gameArgs
        
        NSLog("[Lapis] Ready to launch with %d args", allArgs.count)
        NSLog("[Lapis] JRE: %@", jrePath)
        NSLog("[Lapis] JLI: %@", jliPath)
        
        // Launch on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Safe dlopen check first (RTLD_LAZY won't execute constructors)
            let testHandle = dlopen(jliPath, RTLD_LAZY)
            if testHandle == nil {
                let errMsg = String(cString: dlerror())
                NSLog("[Lapis] dlopen FAILED: %@", errMsg)
                DispatchQueue.main.async { [self] in
                    self.launchErrorText = "Cannot load Java Runtime.\n\n\(errMsg)\n\nMake sure JIT is enabled via StikDebug or TrollStore before launching."
                    self.showLaunchError = true
                }
                return
            }
            dlclose(testHandle)
            
            NSLog("[Lapis] dlopen OK — launching JVM")
            let result = PojavBridge.launchJVM(withArgs: allArgs)
            
            DispatchQueue.main.async { [self] in
                if result != 0 {
                    self.launchErrorText = "Minecraft exited with code \(result)"
                    self.showLaunchError = true
                }
            }
        }
    }
    
    private func launchGame() {
        guard let version = appState.selectedVersion,
              let mode = selectedInputMode else { return }
        doLaunch(version: version, mode: mode)
    }
}

