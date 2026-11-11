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
                    ChoicePicker(title: "Round to", options: [8, 16, 32],
                                 label: { "1/\($0)\"" }, selection: $denominator, style: .menu)
                    Toggle("Show feet and inches", isOn: $useFeet)
                    ChoicePicker(title: "Offset multipliers", options: MultiplierMode.allCases.map(\.rawValue),
                                 label: { MultiplierMode(rawValue: $0)?.displayName ?? $0 },
                                 selection: $multiplierModeRaw, style: .menu)
                } header: {
                    Text("Measurements")
                } footer: {
                    Text("Exact uses trig (60° = 1.15). Bender chart uses the rounded numbers printed on many benders (60° = 1.2), so the app matches your chart.")
                }

                Section("Level") {
                    Toggle("Beep on target", isOn: $levelBeep)
                    ChoicePicker(title: "On-target window", options: [0.5, 1.0, 2.0],
                                 label: { $0 == 0.5 ? "±½°" : "±\(Int($0))°" },
                                 selection: $levelTolerance, style: .menu)
                }

                Section {
                    if store.isPro {
                        Label {
                            Text("Pro is unlocked")
                        } icon: {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                    } else {
                        Button("Unlock Pro") { showPaywall = true }
                    }
                    Button("Restore purchases") {
                        Task { await store.restore() }
                    }
                    if ProStore.offersTestUnlock {
                        Toggle("Unlock Pro for testing", isOn: $store.debugUnlock)
                    }
                } header: {
                    Text("BendCoach Pro")
                } footer: {
                    if ProStore.offersTestUnlock {
                        Text("Test builds can't buy from the App Store. The testing switch only exists in test builds.")
                    }
                }

                Section("About") {
                    NavigationLink("How the math works") {
                        AboutMathView()
                    }
                    LabeledContent("Version", value: appVersion)
                }
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
