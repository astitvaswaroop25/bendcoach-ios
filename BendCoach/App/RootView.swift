import SwiftUI
import SwiftData
import BendKit

/// Tabs plus the app-wide settings every screen reads from the environment.
struct RootView: View {
    @AppStorage(PrefKey.denominator) private var denominator = 16
    @AppStorage(PrefKey.useFeet) private var useFeet = false
    @AppStorage(PrefKey.multiplierMode) private var multiplierModeRaw = MultiplierMode.exact.rawValue
    @AppStorage(PrefKey.selectedBenderID) private var selectedBenderID = BenderPresets.standard.id.uuidString
    @Query(sort: \CustomBender.createdAt) private var customBenders: [CustomBender]

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Bend", systemImage: "wrench.and.screwdriver") }
            LevelView()
                .tabItem { Label("Level", systemImage: "level") }
            HistoryView()
                .tabItem { Label("Saved", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .environment(\.lengthFormat, LengthFormat(denominator: denominator, useFeet: useFeet))
        .environment(\.multiplierMode, MultiplierMode(rawValue: multiplierModeRaw) ?? .exact)
        .environment(\.currentBender, currentBender)
    }

    private var currentBender: BenderProfile {
        BenderLibrary.profile(id: selectedBenderID, customs: customBenders.map { $0.profile })
    }
}
