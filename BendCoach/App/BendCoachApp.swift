import SwiftUI
import SwiftData

@main
struct BendCoachApp: App {
    @StateObject private var store = ProStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
        .modelContainer(for: [SavedBend.self, CustomBender.self])
    }
}
