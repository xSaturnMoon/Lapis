import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAccountSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Logo
            VStack(spacing: LapisTheme.Spacing.xs) {
                LapisImage("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: LapisTheme.Radius.small))
            }
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(LapisTheme.Colors.divider)
                .frame(height: 1)
                .padding(.horizontal, LapisTheme.Spacing.md)
            
            Spacer().frame(height: LapisTheme.Spacing.lg)
            
            // MARK: - Navigation Tabs
            VStack(spacing: LapisTheme.Spacing.sm) {
                ForEach(SidebarTab.allCases) { tab in
                    SidebarButton(
                        tab: tab,
                        isSelected: appState.currentTab == tab
                    ) {
                        withAnimation(LapisTheme.Animation.smooth) {
                            appState.currentTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, LapisTheme.Spacing.sm)
            
            Spacer()
            
            // MARK: - Bottom: Account Button
            Rectangle()
                .fill(LapisTheme.Colors.divider)
                .frame(height: 1)
                .padding(.horizontal, LapisTheme.Spacing.md)
            
            Spacer().frame(height: LapisTheme.Spacing.md)
            
            AccountSidebarButton {
                showAccountSheet = true
            }
            .padding(.horizontal, LapisTheme.Spacing.sm)
            
            Spacer().frame(height: LapisTheme.Spacing.md)
        }
        .frame(width: LapisTheme.Sidebar.width)
        .background(
            ZStack {
                LapisTheme.Colors.sidebar
                LapisTheme.Colors.glassBackground
            }
            .ignoresSafeArea()
        )
        .fullScreenCover(isPresented: $showAccountSheet) {
            AccountView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Sidebar Icon Button
struct SidebarButton: View {
    let tab: SidebarTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Active indicator background
                if isSelected {
                    RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                        .fill(LapisTheme.Colors.accent.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                                .stroke(LapisTheme.Colors.accent.opacity(0.2), lineWidth: 1)
                        )
                }
                
                Image(systemName: tab.iconName)
                    .font(.system(size: LapisTheme.Sidebar.iconSize, weight: .medium))
                    .foregroundColor(isSelected ? LapisTheme.Colors.accent : LapisTheme.Colors.textMuted)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .animation(LapisTheme.Animation.fast, value: isSelected)
    }
}

// MARK: - Account Button (bottom of sidebar)
struct AccountSidebarButton: View {
    @EnvironmentObject var appState: AppState
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if appState.isLoggedIn {
                    // Show player head avatar
                    AsyncImage(url: URL(string: "https://mc-heads.net/avatar/\(appState.playerUUID)/32")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .foregroundColor(LapisTheme.Colors.accent)
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: LapisTheme.Radius.small))
                } else {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: LapisTheme.Sidebar.iconSize, weight: .medium))
                        .foregroundColor(LapisTheme.Colors.textMuted)
                }
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}
