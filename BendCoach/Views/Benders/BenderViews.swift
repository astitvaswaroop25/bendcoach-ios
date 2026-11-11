import SwiftUI
import SwiftData
import BendKit

/// Pick the bender the numbers are based on, or set up your own.
struct BenderListView: View {
    enum EditorTarget: Identifiable {
        case new
        case existing(CustomBender)

        var id: String {
            switch self {
            case .new: return "new"
            case .existing(let bender): return bender.benderID.uuidString
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var store: ProStore
    @AppStorage(PrefKey.selectedBenderID) private var selectedBenderID = BenderPresets.standard.id.uuidString
    @Query(sort: \CustomBender.createdAt) private var customBenders: [CustomBender]
    @State private var editing: EditorTarget?
    @State private var showPaywall = false

    var body: some View {
        List {
            Section {
                if customBenders.isEmpty {
                    Text("Calibrate your own bender so stubs come out exactly right with your tool.")
                        .foregroundStyle(.secondary)
                }
                ForEach(customBenders) { bender in
                    row(bender.profile)
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(bender)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editing = .existing(bender)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
                Button {
                    addTapped()
                } label: {
                    Label("Add a bender", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("My benders")
            } footer: {
                Text("Swipe left on a bender to edit or delete it.")
            }

            Section {
                ForEach(BenderPresets.all) { preset in
                    row(preset)
                }
            } header: {
                Text("Starting points")
            } footer: {
                Text("Typical take-ups from Klein, Ideal and Gardner Bender charts. Benders vary, so check yours with a test bend.")
            }
        }
        .navigationTitle("Benders")
        .sheet(item: $editing) { target in
            NavigationStack {
                BenderEditorView(target: target)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func row(_ profile: BenderProfile) -> some View {
        Button {
            selectedBenderID = profile.id.uuidString
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .foregroundStyle(.primary)
                    Text("Take-up \(LengthFormat.standard.string(profile.takeUp)) · \(profile.conduitDescription)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if profile.id.uuidString == selectedBenderID {
                    Image(systemName: "checkmark")
                        .font(.body.bold())
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Selected")
                }
            }
            .contentShape(Rectangle())
        }
    }

    private func addTapped() {
        if !store.isPro && customBenders.count >= FreeLimits.customBenders {
            showPaywall = true
        } else {
            editing = .new
        }
    }

    private func delete(_ bender: CustomBender) {
        if bender.benderID.uuidString == selectedBenderID {
            selectedBenderID = BenderPresets.standard.id.uuidString
        }
        modelContext.delete(bender)
    }
}

struct BenderEditorView: View {
    let target: BenderListView.EditorTarget

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PrefKey.selectedBenderID) private var selectedBenderID = BenderPresets.standard.id.uuidString
    @State private var name: String
    @State private var conduitType: ConduitType
    @State private var tradeSize: TradeSize
    @State private var takeUp: Double?
    @State private var radius: Double?
    @State private var showCalibration = false

    init(target: BenderListView.EditorTarget) {
        self.target = target
        let start: BenderProfile
        switch target {
        case .new:
            start = BenderPresets.standard
        case .existing(let bender):
            start = bender.profile
        }
        _name = State(initialValue: Self.isNew(target) ? "My \(start.conduitDescription) bender" : start.name)
        _conduitType = State(initialValue: start.conduitType)
        _tradeSize = State(initialValue: start.tradeSize)
        _takeUp = State(initialValue: start.takeUp)
        _radius = State(initialValue: start.centerlineRadius)
    }

    private static func isNew(_ target: BenderListView.EditorTarget) -> Bool {
        if case .new = target { return true }
        return false
    }

    private var canSave: Bool {
        guard let takeUp, let radius else { return false }
        return !name.trimmingCharacters(in: .whitespaces).isEmpty && takeUp > 0 && radius > 0
    }

    var body: some View {
        Form {
            Section("Bender") {
                TextField("Name", text: $name)
                Picker("Conduit", selection: $conduitType) {
                    ForEach(ConduitType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                Picker("Size", selection: $tradeSize) {
                    ForEach(TradeSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
            }

            Section {
                MeasurementField(title: "Take-up", hint: "Arrow to the back of a 90°", value: $takeUp)
                Button {
                    showCalibration = true
                } label: {
                    Label("Measure it with a test bend", systemImage: "ruler")
                }
            } footer: {
                Text("It's printed on most benders, but check it: a 1/8\" error shows up on every stub.")
            }

            Section {
                MeasurementField(title: "Centerline radius", hint: "Only used for the drawings", value: $radius)
            } footer: {
                Text("Leave the default if you don't know it.")
            }
        }
        .navigationTitle(Self.isNew(target) ? "New bender" : "Edit bender")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .onChange(of: conduitType) { _, _ in applyPresetDefaults() }
        .onChange(of: tradeSize) { _, _ in applyPresetDefaults() }
        .sheet(isPresented: $showCalibration) {
            NavigationStack {
                CalibrateTakeUpView { measured in
                    takeUp = measured
                }
            }
        }
    }

    /// A different conduit or size means a different shoe, so start from that size's typical numbers.
    private func applyPresetDefaults() {
        let preset = BenderPresets.closest(to: conduitType, tradeSize)
        takeUp = preset.takeUp
        radius = preset.centerlineRadius
    }

    private func save() {
        guard let takeUp, let radius else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        switch target {
        case .new:
            let profile = BenderProfile(name: trimmedName, conduitType: conduitType, tradeSize: tradeSize,
                                        takeUp: takeUp, centerlineRadius: radius)
            modelContext.insert(CustomBender(profile: profile))
            selectedBenderID = profile.id.uuidString
        case .existing(let bender):
            var profile = bender.profile
            profile.name = trimmedName
            profile.conduitType = conduitType
            profile.tradeSize = tradeSize
            profile.takeUp = takeUp
            profile.centerlineRadius = radius
            bender.update(from: profile)
        }
        dismiss()
    }
}

/// Works out take-up from one test bend on scrap.
struct CalibrateTakeUpView: View {
    let onUse: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.lengthFormat) private var format
    @State private var markDistance: Double? = 10
    @State private var measuredStub: Double?

    private var takeUp: Double? {
        guard let markDistance, let measuredStub else { return nil }
        return Calibration.takeUp(markDistance: markDistance, measuredStub: measuredStub)
    }

    var body: some View {
        Form {
            Section("Test bend") {
                Label("Mark a scrap piece 10\" from the end (any distance works).", systemImage: "1.circle")
                Label("Line the mark up with the arrow and bend a true 90°. Check it with the level.", systemImage: "2.circle")
                Label("Measure from the end to the back of the bend.", systemImage: "3.circle")
            }
            Section("Your numbers") {
                MeasurementField(title: "Mark from the end", value: $markDistance)
                MeasurementField(title: "Measured stub", hint: "End to the back of the bend", value: $measuredStub)
            }
            Section {
                if let takeUp {
                    LabeledContent("Your take-up", value: format.string(takeUp))
                        .font(.headline)
                } else if measuredStub != nil {
                    Text("The stub has to measure longer than the mark distance.")
                        .foregroundStyle(.red)
                } else {
                    Text("Enter the measured stub to see your take-up.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Calibrate take-up")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Use") {
                    if let takeUp { onUse(takeUp) }
                    dismiss()
                }
                .disabled(takeUp == nil)
            }
        }
    }
}
