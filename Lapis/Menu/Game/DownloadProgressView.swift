import SwiftUI

struct DownloadProgressView: View {
    @ObservedObject var downloader: GameDownloader
    
    var body: some View {
        ZStack {
            LapisTheme.Colors.background.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: LapisTheme.Spacing.xxl) {
                Spacer()
                
                // Animated icon
                ZStack {
                    Circle()
                        .stroke(LapisTheme.Colors.accent.opacity(0.1), lineWidth: 3)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: downloader.progress)
                        .stroke(LapisTheme.Colors.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: downloader.progress)
                    
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(LapisTheme.Colors.accent)
                }
                
                // Status
                VStack(spacing: LapisTheme.Spacing.sm) {
                    Text(downloader.statusMessage)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.textPrimary)
                    
                    Text(downloader.currentFile)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                        .lineLimit(1)
                }
                
                // Progress bar
                VStack(spacing: LapisTheme.Spacing.sm) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LapisTheme.Colors.surface)
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LapisTheme.Colors.accent)
                                .frame(width: geo.size.width * downloader.progress, height: 6)
                                .animation(.linear(duration: 0.3), value: downloader.progress)
                        }
                    }
                    .frame(height: 6)
                    
                    HStack {
                        Text("\(Int(downloader.progress * 100))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(LapisTheme.Colors.accent)
                        
                        Spacer()
                        
                        Text(downloader.downloadedSizeString)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(LapisTheme.Colors.textMuted)
                    }
                }
                .frame(maxWidth: 400)
                
                if let error = downloader.error {
                    VStack(spacing: LapisTheme.Spacing.md) {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(LapisTheme.Colors.danger)
                        
                        Button("Retry") {
                            downloader.retry()
                        }
                        .buttonStyle(LapisButtonStyle(isAccent: true))
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, LapisTheme.Spacing.xxl)
        }
    }
}
