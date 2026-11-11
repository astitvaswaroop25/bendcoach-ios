import SwiftUI
import UIKit
import AudioToolbox
import BendKit

/// Live angle readout that turns green, buzzes and beeps when the bend hits its target.
struct LevelGauge: View {
    let target: Double

    @StateObject private var level = MotionLevel()
    @AppStorage(PrefKey.levelBeep) private var beep = true
    @AppStorage(PrefKey.levelTolerance) private var tolerance = 0.5
    @State private var hits = 0

    private var difference: Double { level.angle - target }
    private var isOnTarget: Bool { abs(difference) <= tolerance }

    private var statusColor: Color {
        if isOnTarget { return .green }
        if difference > tolerance { return .red }
        return difference > -3 ? .orange : .secondary
    }

    private var statusText: String {
        if isOnTarget { return "On target" }
        if difference > 0 { return String(format: "Over by %.1f°", difference) }
        return String(format: "%.1f° to go", -difference)
    }

    var body: some View {
        VStack(spacing: 14) {
            if level.isAvailable {
                readout
                LevelBar(value: level.angle, target: target, tolerance: tolerance, color: statusColor)
                    .frame(height: 30)
                controls
                Text("Zero the level on the straight part first. Then lay the phone's long edge on the bent section, pointing the same way.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                ContentUnavailableView("Level needs a real iPhone",
                                       systemImage: "level",
                                       description: Text("The motion sensor isn't available here, so the level can't run."))
            }
        }
        .onAppear {
            level.start()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            level.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: isOnTarget) { _, onTarget in
            guard onTarget else { return }
            hits += 1
            if beep { AudioServicesPlaySystemSound(1057) }
        }
        .sensoryFeedback(.success, trigger: hits)
    }

    private var readout: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1f°", level.angle))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(statusColor)
                .contentTransition(.numericText())
                .accessibilityLabel(String(format: "%.1f degrees", level.angle))
            Text("Target \(AngleFormat.string(target)) · \(statusText)")
                .font(.headline)
                .foregroundStyle(statusColor)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                level.zero()
            } label: {
                Label("Zero here", systemImage: "scope")
            }
            .buttonStyle(.borderedProminent)
            if level.zeroOffset != 0 {
                Button("Clear zero") {
                    level.clearZero()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

/// Horizontal bar with the target window marked.
struct LevelBar: View {
    let value: Double
    let target: Double
    let tolerance: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let maxValue = max(target * 1.4, target + 10)
            let width = proxy.size.width
            let position = { (degrees: Double) -> CGFloat in
                CGFloat(min(max(degrees / maxValue, 0), 1)) * width
            }
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(uiColor: .tertiarySystemFill))
                Rectangle()
                    .fill(Color.green.opacity(0.35))
                    .frame(width: max(position(target + tolerance) - position(target - tolerance), 3))
                    .offset(x: position(target - tolerance))
                Capsule()
                    .fill(color)
                    .frame(width: max(position(value), 6))
            }
            .clipShape(Capsule())
        }
        .accessibilityHidden(true)
    }
}

/// Standalone level tab for checking any bend.
struct LevelView: View {
    @State private var target: Double = 30
    private let targets: [Double] = [10, 22.5, 30, 45, 60, 90]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Picker("Target angle", selection: $target) {
                    ForEach(targets, id: \.self) { angle in
                        Text(AngleFormat.string(angle)).tag(angle)
                    }
                }
                .pickerStyle(.segmented)
                LevelGauge(target: target)
                Spacer()
            }
            .padding()
            .navigationTitle("Level")
        }
    }
}

/// Walks through a plan one step at a time, with the level on every bend.
struct GuidedBendView: View {
    let plan: BendPlan

    @Environment(\.lengthFormat) private var format
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    var body: some View {
        let steps = plan.steps
        let step = steps[min(index, steps.count - 1)]
        VStack(spacing: 16) {
            ProgressView(value: Double(index + 1), total: Double(max(steps.count, 1)))
            Text("Step \(step.number) of \(steps.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 16) {
                    if let label = step.markLabel, let mark = plan.mark(label) {
                        markCallout(mark)
                    }
                    if let prep = step.prep.label {
                        Label(prep, systemImage: step.prep.symbolName)
                            .font(.headline)
                            .foregroundStyle(.orange)
                    }
                    Text(step.instruction)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    if let angle = step.angle {
                        LevelGauge(target: angle)
                            .id(step.number)
                    }
                }
            }

            HStack {
                Button {
                    index -= 1
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .disabled(index == 0)
                Spacer()
                Button {
                    if index >= steps.count - 1 {
                        dismiss()
                    } else {
                        index += 1
                    }
                } label: {
                    Text(index >= steps.count - 1 ? "Done" : "Next step")
                        .bold()
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .navigationTitle(plan.kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func markCallout(_ mark: BendMark) -> some View {
        HStack(spacing: 16) {
            MarkBadge(label: mark.label, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(mark.distanceText(format))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(mark.referenceText)
                    .foregroundStyle(.secondary)
                Label(mark.benderMark.displayName, systemImage: mark.benderMark.symbolName)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
