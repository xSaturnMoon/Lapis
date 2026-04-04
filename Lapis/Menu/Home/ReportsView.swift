import SwiftUI

struct ReportsView: View {
    @State private var logContent: String = "No logs found."
    @State private var autoScroll: Bool = true
    
    // Timer to poll for new log entries every 500ms
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: LapisTheme.Spacing.md) {
            // Header
            HStack {
                Text("JVM Engine Log")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(LapisTheme.Colors.textPrimary)
                
                Spacer()
                
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(SwitchToggleStyle(tint: LapisTheme.Colors.accent))
                    .frame(width: 140)
                
                Button(action: readLog) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.accent)
                }
                .buttonStyle(.plain)
                
                Button(action: copyLog) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(LapisTheme.Colors.accent)
                }
                .buttonStyle(.plain)
                .padding(.leading, LapisTheme.Spacing.sm)
            }
            
            // Console Area
            ScrollViewReader { proxy in
                ScrollView {
                    Text(logContent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id("bottom")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.8))
                .cornerRadius(LapisTheme.Radius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                        .stroke(LapisTheme.Colors.divider, lineWidth: 1)
                )
                .onChange(of: logContent) { _ in
                    if autoScroll {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(LapisTheme.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: readLog)
        .onReceive(timer) { _ in readLog() }
    }
    
    private func readLog() {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let logPath = docs.appendingPathComponent("Lapis/latestlog.txt")
        
        if let content = try? String(contentsOf: logPath, encoding: .utf8), !content.isEmpty {
            if content != logContent {
                logContent = content
            }
        } else {
            // Also check root Lapis if GameLauncher creates it differently
            let alternatePath = docs.appendingPathComponent("latestlog.txt")
            if let content = try? String(contentsOf: alternatePath, encoding: .utf8), !content.isEmpty {
                if content != logContent {
                    logContent = content
                }
            }
        }
    }
    
    private func copyLog() {
        UIPasteboard.general.string = logContent
    }
}
