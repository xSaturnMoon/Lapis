import SwiftUI

enum AppPhase {
    case boot
    case auth
    case desktop
}

struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var phase: AppPhase = .boot

    var body: some View {
        ZStack {
            switch phase {
            case .boot:
                BootView()
                    .transition(.opacity)
            case .auth:
                AuthView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.04)),
                        removal: .opacity
                    ))
            case .desktop:
                DesktopView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.97)),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(duration: 0.6, bounce: 0.1), value: phase)
        .onReceive(authVM.$phase) { newPhase in
            withAnimation(.spring(duration: 0.6, bounce: 0.1)) {
                phase = newPhase
            }
        }
        .statusBarHidden(true)
    }
}
