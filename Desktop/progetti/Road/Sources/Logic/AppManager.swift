import Foundation
import SwiftUI

class AppManager: ObservableObject {
    static let shared = AppManager()
    @Published var selectedTab: Int = 0
    private init() {}
}
