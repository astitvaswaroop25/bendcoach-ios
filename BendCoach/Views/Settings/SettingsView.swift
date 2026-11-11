import SwiftUI
import BendKit

struct SettingsView: View {
    @EnvironmentObject private var store: ProStore
    @AppStorage(PrefKey.denominator) private var denominator = 16
    @AppStorage(PrefKey.useFeet) private var useFeet = false
    @AppStorage(PrefKey.multiplierMode) private var multiplierModeRaw = MultiplierMode.exact.rawValue
    @AppStorage(PrefKey.levelBeep) private var levelBeep = true
    @AppStorage(PrefKey.levelTolerance) private var levelTolerance = 0.5
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Round to", selection: $denominator) {
                        Text("1/8\"").tag(8)
                        Text("1/16\"").tag(16)
                        Text("1/32\"").tag(32)
                    }
                    Toggle("Show feet and inches", isOn: $useFeet)
                    Picker("Offset multipliers", selection: $multiplierModeRaw) {
                        ForEach(MultiplierMode.allCases) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                } header: {
                    Text("Measurements")
                } footer: {
                    Text("Exact uses trig (60° = 1.15). Bender chart uses the rounded numbers printed on many benders (60° = 1.2), so the app matches your chart.")
                }

                Section("Level") {
                    Toggle("Beep on target", isOn: $levelBeep)
                    Picker("On-target window", selection: $levelTolerance) {
                        Text("±½°").tag(0.5)
                        Text("±1°").tag(1.0)
                        Text("±2°").tag(2.0)
                    }
                }

                Section("BendCoach Pro") {
                    if store.isPro {
                        Label("Pro is unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Unlock Pro") { showPaywall = true }
                    }
                    Button("Restore purchases") {
                        Task { await store.restore() }
                    }
                }

                Section("About") {
                    NavigationLink("How the math works") {
                        AboutMathView()
                    }
                    LabeledContent("Version", value: appVersion)
                }

                #if DEBUG
                Section("Developer") {
                    Toggle("Unlock Pro (debug builds only)", isOn: $store.debugUnlock)
                }
                #endif
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}

struct AboutMathView: View {
    var body: some View {
        List {
            Section("Offsets") {
                Text("Distance between marks = offset depth × multiplier. The exact multiplier is 1 ÷ sin(angle): 10° = 5.76, 22½° = 2.61, 30° = 2, 45° = 1.41, 60° = 1.15.")
                Text("Shrink per inch of depth follows the bender charts: 10° = 1/16\", 22½° = 3/16\", 30° = 1/4\", 45° = 3/8\", 60° = 1/2\". Shrink is added only when you measure to an obstruction.")
            }
            Section("Stub-ups and back-to-backs") {
                Text("Mark = stub height − take-up, lined up with the arrow. Typical take-ups: 1/2\" EMT 5\", 3/4\" EMT 6\", 1\" EMT 8\", 1-1/4\" EMT 11\". Calibrate yours for the best results.")
                Text("For a back-to-back, measure from the back of the first 90° and line that mark up with the star.")
            }
            Section("Saddles") {
                Text("3-point, 45°/22½°: outer marks 2½ × height from the center; the center mark moves ahead 3/16\" per inch of height. For 60°/30°: 2 × height and 1/4\" per inch.")
                Text("4-point: two offsets with the obstruction width between them. Shrink from the first offset is added before the first mark.")
            }
            Section("Rolling offsets") {
                Text("True offset = √(rise² + roll²). Bend that as a normal offset, then turn the conduit toward the roll before fastening.")
            }
            Section {
                Text("These are the standard trade methods printed by Klein, Ideal, Greenlee and Gardner Bender. Benders and conduit vary, so check your first bend on scrap before you cut good pipe.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("How the math works")
        .navigationBarTitleDisplayMode(.inline)
    }
}
