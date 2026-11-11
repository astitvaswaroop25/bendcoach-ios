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
            Section("Measurements") {
                inputs
            }
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
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
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
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }

        Section {
            ForEach(plan.marks) { mark in
                MarkRow(mark: mark)
            }
            StickLayoutView(plan: plan)
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
                LabeledContent(fact.label, value: fact.formatted(format))
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
    var size: CGFloat = 36

    var body: some View {
        Text(label)
            .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.accentColor))
            .accessibilityLabel("Mark \(label)")
    }
}

struct MarkRow: View {
    let mark: BendMark
    @Environment(\.lengthFormat) private var format

    var body: some View {
        HStack(spacing: 14) {
            MarkBadge(label: mark.label)
            VStack(alignment: .leading, spacing: 2) {
                Text(mark.distanceText(format))
                    .font(.title2.monospacedDigit().weight(.bold))
                Text(mark.referenceText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Label(mark.benderMark.displayName, systemImage: mark.benderMark.symbolName)
                    .font(.subheadline)
                    .multilineTextAlignment(.trailing)
                Text("Bend \(AngleFormat.string(mark.angle))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct StepRow: View {
    let step: BendStep

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(step.number)")
                .font(.headline)
                .foregroundStyle(step.isBend ? Color.white : Color.primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(step.isBend ? Color.accentColor : Color.secondary.opacity(0.25)))
            VStack(alignment: .leading, spacing: 4) {
                if let prep = step.prep.label {
                    Label(prep, systemImage: step.prep.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                Text(step.instruction)
            }
        }
        .padding(.vertical, 2)
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
