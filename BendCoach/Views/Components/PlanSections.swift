import SwiftUI
import SwiftData
import BendKit

/// Shared calculator scaffold: measurements on top, the plan underneath.
struct CalculatorScreen<Inputs: View>: View {
    let kind: BendKind
    let result: Result<BendPlan, Error>?
    @ViewBuilder var inputs: Inputs

    var body: some View {
        Form {
            if Demo.showsResultsFirst {
                resultSections
            }
            Section("Measurements") {
                inputs
            }
            if !Demo.showsResultsFirst {
                resultSections
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var resultSections: some View {
        switch result {
        case .none:
            Section {
                Text("Enter your measurements and the marks show up here.")
                    .foregroundStyle(.secondary)
            }
        case .some(.success(let plan)):
            PlanSections(plan: plan)
        case .some(.failure(let error)):
            Section {
                Label {
                    Text(error.localizedDescription)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

/// Marks, steps, drawings and numbers for one plan.
struct PlanSections: View {
    let plan: BendPlan
    var allowsSaving = true

    @Environment(\.lengthFormat) private var format
    @Environment(\.currentBender) private var bender

    var body: some View {
        if !plan.warnings.isEmpty {
            Section {
                ForEach(plan.warnings, id: \.self) { warning in
                    Label {
                        Text(warning)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }

        Section {
            ForEach(plan.marks) { mark in
                MarkRow(mark: mark)
            }
            // The rows above carry the same numbers at full size, so the diagram's labels stop
            // growing at the largest text sizes and stay where they belong.
            StickLayoutView(plan: plan)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
            if plan.marks.contains(where: { $0.reference == .backOfFirstBend }) {
                Text("Mark B goes on after the first bend. Measure it from the back of that 90°.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Marks")
        } footer: {
            if let benderName = plan.benderName {
                Text("Using \(benderName).")
            }
        }

        Section("Steps") {
            ForEach(plan.steps) { step in
                StepRow(step: step)
            }
            NavigationLink {
                GuidedBendView(plan: plan)
            } label: {
                Label("Bend it step by step with the level", systemImage: "level")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }
        }

        Section("Finished shape") {
            ShapePreviewView(plan: plan, radius: bender.centerlineRadius)
        }

        Section("Numbers") {
            ForEach(plan.facts) { fact in
                LabeledContent(fact.label) {
                    Text(fact.formatted(format))
                        .font(.measurement(.body, weight: .semibold))
                        .foregroundStyle(Color.primary)
                }
            }
        }

        if allowsSaving {
            Section {
                SaveBendButton(plan: plan)
                ShareLink(item: plan.shareText(format: format)) {
                    Label("Share marks", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

struct MarkBadge: View {
    let label: String
    var size: CGFloat = 40

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    private var diameter: CGFloat { size * min(scale, 1.8) }

    var body: some View {
        Text(label)
            .font(.system(size: diameter * 0.5, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.onHighVis)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(Theme.highVis))
            .overlay(Circle().strokeBorder(Theme.highVisEdge, lineWidth: 1))
            .accessibilityLabel("Mark \(label)")
    }
}

/// One mark, sized to be read at arm's length: where it goes, then the angle and the bender
/// mark to line it up with.
struct MarkRow: View {
    let mark: BendMark
    @Environment(\.lengthFormat) private var format
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var benderColumnWidth: CGFloat = 116

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    MarkBadge(label: mark.label)
                    distanceBlock
                    bendBlock(alignment: .leading)
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    MarkBadge(label: mark.label)
                    distanceBlock
                    Spacer(minLength: 8)
                    bendBlock(alignment: .trailing)
                        .frame(maxWidth: benderColumnWidth, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mark \(mark.label): \(mark.distanceText(format)) \(mark.referenceText). Bend \(AngleFormat.string(mark.angle)) on the \(mark.benderMark.displayName.lowercased()).")
    }

    private var distanceBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(mark.distanceText(format))
                .font(.measurement(.title))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(mark.referenceText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func bendBlock(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(AngleFormat.string(mark.angle))
                .font(.measurement(.title2))
            Label(mark.benderMark.displayName, systemImage: mark.benderMark.symbolName)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
        }
    }
}

struct StepRow: View {
    let step: BendStep
    @ScaledMetric(relativeTo: .headline) private var numberSize: CGFloat = 30

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(step.number)")
                .font(.measurement(.headline))
                .foregroundStyle(step.isBend ? Theme.onHighVis : Color.primary)
                .frame(width: numberSize, height: numberSize)
                .background(Circle().fill(step.isBend ? Theme.highVis : Color(uiColor: .tertiarySystemFill)))
            VStack(alignment: .leading, spacing: 6) {
                if let prep = step.prep.label {
                    StatusPill.prepCue(prep, systemImage: step.prep.symbolName, compact: true)
                }
                Text(InstructionText.emphasized(step.instruction))
            }
            .padding(.top, 3)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Saves a plan to history; free users get a handful before the paywall.
struct SaveBendButton: View {
    let plan: BendPlan

    @Environment(\.modelContext) private var modelContext
    @Environment(\.lengthFormat) private var format
    @EnvironmentObject private var store: ProStore
    @Query private var saved: [SavedBend]
    @State private var showPaywall = false
    @State private var didSave = false

    var body: some View {
        Button {
            if !store.isPro && saved.count >= FreeLimits.savedBends {
                showPaywall = true
                return
            }
            modelContext.insert(SavedBend(plan: plan, title: plan.title(format: format)))
            didSave = true
        } label: {
            Label(didSave ? "Saved" : "Save to history",
                  systemImage: didSave ? "checkmark.circle.fill" : "tray.and.arrow.down")
        }
        .disabled(didSave)
        .onChange(of: plan) { _, _ in
            didSave = false
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}
