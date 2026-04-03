import SwiftUI

enum InputMode {
    case touch
    case keyboard
}

struct InputModeView: View {
    let onSelect: (InputMode) -> Void
    @State private var hoveredMode: InputMode? = nil
    
    var body: some View {
        ZStack {
            // Blurred background
            LapisTheme.Colors.background.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: LapisTheme.Spacing.xxl) {
                Spacer()
                
                // Title icon
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(LapisTheme.Colors.accent.opacity(0.4))
                
                // Two big cards side by side
                HStack(spacing: LapisTheme.Spacing.xxl) {
                    // Touch card
                    InputModeCard(
                        iconName: "hand.tap.fill",
                        secondaryIcon: "ipad.landscape",
                        isHovered: hoveredMode == .touch
                    ) {
                        onSelect(.touch)
                    }
                    
                    // Keyboard card
                    InputModeCard(
                        iconName: "keyboard.fill",
                        secondaryIcon: "computermouse.fill",
                        isHovered: hoveredMode == .keyboard
                    ) {
                        onSelect(.keyboard)
                    }
                }
                .frame(maxWidth: 520)
                
                Spacer()
                
                // Subtle hint
                HStack(spacing: LapisTheme.Spacing.sm) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                    Text("You can change this later in Settings")
                        .font(.system(size: 11))
                }
                .foregroundColor(LapisTheme.Colors.textMuted)
                .padding(.bottom, LapisTheme.Spacing.xxl)
            }
        }
    }
}

// MARK: - Input Mode Card
struct InputModeCard: View {
    let iconName: String
    let secondaryIcon: String
    let isHovered: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: LapisTheme.Spacing.xl) {
                // Main icon
                ZStack {
                    Circle()
                        .fill(LapisTheme.Colors.accent.opacity(0.08))
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 38, weight: .light))
                        .foregroundColor(LapisTheme.Colors.accent)
                }
                
                // Secondary icon (device type)
                Image(systemName: secondaryIcon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(LapisTheme.Colors.textMuted.opacity(0.5))
            }
            .frame(width: 200, height: 200)
            .background(
                RoundedRectangle(cornerRadius: LapisTheme.Radius.xl)
                    .fill(LapisTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: LapisTheme.Radius.xl)
                            .stroke(
                                isPressed ? LapisTheme.Colors.accent : LapisTheme.Colors.glassBorder,
                                lineWidth: isPressed ? 2 : 1
                            )
                    )
                    .shadow(color: isPressed ? LapisTheme.Colors.accent.opacity(0.2) : .clear, radius: 20)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(LapisTheme.Animation.fast, value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
