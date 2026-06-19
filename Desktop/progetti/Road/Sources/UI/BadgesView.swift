import SwiftUI

struct BadgesView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "star.circle")
                        .font(.system(size: 52, weight: .thin))
                        .foregroundStyle(.secondary)
                    Text("Badges")
                        .font(.title3.bold())
                    Text("Prossimamente")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Badges")
        }
    }
}
