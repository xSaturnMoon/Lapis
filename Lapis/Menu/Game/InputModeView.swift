import SwiftUI

enum InputMode {
    case touch
    case keyboard
}

struct InputModeView: View {
    let onSelect: (InputMode) -> Void
    
    var body: some View {
        ZStack {
            // Blurred background
            LapisTheme.Colors.background.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture { /* block taps on background */ }
            
            VStack(spacing: LapisTheme.Spacing.xxl) {
                Spacer()
                
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(LapisTheme.Colors.accent.opacity(0.4))
                
                // Two cards side by side
                HStack(spacing: LapisTheme.Spacing.xxl) {
                    // Touch
                    Button {
                        onSelect(.touch)
                    } label: {
                        VStack(spacing: LapisTheme.Spacing.xl) {
                            ZStack {
                                Circle()
                                    .fill(LapisTheme.Colors.accent.opacity(0.08))
                                    .frame(width: 90, height: 90)
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 38, weight: .light))
                                    .foregroundColor(LapisTheme.Colors.accent)
                            }
                            Image(systemName: "ipad.landscape")
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(LapisTheme.Colors.textMuted.opacity(0.5))
                        }
                        .frame(width: 200, height: 200)
                        .background(
                            RoundedRectangle(cornerRadius: LapisTheme.Radius.xl)
                                .fill(LapisTheme.Colors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: LapisTheme.Radius.xl)
                                        .stroke(LapisTheme.Colors.glassBorder, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Keyboard
                    Button {
                        onSelect(.keyboard)
                    } label: {
                        VStack(spacing: LapisTheme.Spacing.xl) {
                            ZStack {
                                Circle()
                                    .fill(LapisTheme.Colors.accent.opacity(0.08))
                                    .frame(width: 90, height: 90)
                                Image(systemName: "keyboard.fill")
                                    .font(.system(size: 38, weight: .light))
                                    .foregroundColor(LapisTheme.Colors.accent)
                            }
                            Image(systemName: "computermouse.fill")
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(LapisTheme.Colors.textMuted.opacity(0.5))
                        }
                        .frame(width: 200, height: 200)
                        .background(
                            RoundedRectangle(cornerRadius: LapisTheme.Radius.xl)
                                .fill(LapisTheme.Colors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: LapisTheme.Radius.xl)
                                        .stroke(LapisTheme.Colors.glassBorder, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 520)
                
                Spacer()
                
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
