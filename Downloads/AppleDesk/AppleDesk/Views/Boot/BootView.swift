import SwiftUI

struct BootView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var progressWidth: CGFloat = 0
    @State private var subtitleOpacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.04), Color(white: 0.08), Color(white: 0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()
                VStack(spacing: 16) {
                    ZStack {
                        Color.clear
                            .frame(width: 120, height: 120)
                            .background(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 0.5))
                        Image(systemName: "laptopcomputer")
                            .font(.system(size: 52, weight: .ultraLight))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    Text("AppleDesk")
                        .font(.system(size: 42, weight: .thin, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(logoOpacity)

                    Text("iPadOS 26")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .opacity(subtitleOpacity)
                }
                Spacer()
                VStack(spacing: 12) {
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08)).frame(width: 220, height: 3)
                        Capsule().fill(.white.opacity(0.6)).frame(width: progressWidth * 2.2, height: 3)
                    }
                    Text("Avvio in corso…")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear { runBoot() }
    }

    private func runBoot() {
        withAnimation(.spring(duration: 0.8, bounce: 0.3)) { logoScale = 1; logoOpacity = 1 }
        withAnimation(.easeIn(duration: 0.6).delay(0.4)) { subtitleOpacity = 1 }
        withAnimation(.easeInOut(duration: 1.6).delay(0.3)) { progressWidth = 100 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { authVM.finishBoot() }
    }
}
