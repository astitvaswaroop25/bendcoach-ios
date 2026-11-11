import SwiftUI
import SwiftData
import BendKit

enum AppTab: Hashable {
    case bend
    case level
    case saved
    case settings
}

/// Tabs plus the app-wide settings every screen reads from the environment.
struct RootView: View {
    @State private var tab: AppTab = Demo.initialTab
    @AppStorage(PrefKey.denominator) private var denominator = 16
    @AppStorage(PrefKey.useFeet) private var useFeet = false
    @AppStorage(PrefKey.multiplierMode) private var multiplierModeRaw = MultiplierMode.exact.rawValue
    @AppStorage(PrefKey.selectedBenderID) private var selectedBenderID = BenderPresets.standard.id.uuidString
    @Query(sort: \CustomBender.createdAt) private var customBenders: [CustomBender]

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Bend", systemImage: "wrench.and.screwdriver") }
                .tag(AppTab.bend)
            LevelView()
                .tabItem { Label("Level", systemImage: "level") }
                .tag(AppTab.level)
            HistoryView()
                .tabItem { Label("Saved", systemImage: "clock.arrow.circlepath") }
                .tag(AppTab.saved)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .environment(\.lengthFormat, LengthFormat(denominator: denominator, useFeet: useFeet))
        .environment(\.multiplierMode, MultiplierMode(rawValue: multiplierModeRaw) ?? .exact)
        .environment(\.currentBender, currentBender)
    }

    private var currentBender: BenderProfile {
        BenderLibrary.profile(id: selectedBenderID, customs: customBenders.map { $0.profile })
    }
}
