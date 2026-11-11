import SwiftUI
import UIKit
import AudioToolbox
import BendKit

/// Live angle readout with a status pill that turns green, buzzes and beeps on target.
struct LevelGauge: View {
    let target: Double
    @ObservedObject var level: MotionLevel

    @AppStorage(PrefKey.levelBeep) private var beep = true
    @AppStorage(PrefKey.levelTolerance) private var tolerance = 0.5
    @ScaledMetric(relativeTo: .largeTitle) private var readoutSize: CGFloat = 76
    @State private var hits = 0

    private enum Status {
        case far, close, onTarget, over
    }

    private var difference: Double { level.angle - target }
    private var isOnTarget: Bool { abs(difference) <= tolerance }

    private var status: Status {
        if isOnTarget { return .onTarget }
        if difference > tolerance { return .over }
        return difference > -3 ? .close : .far
    }

    private var statusText: String {
        switch status {
        case .onTarget: return "On target"
        case .over: return String(format: "Over by %.1f°", difference)
        case .close, .far: return String(format: "%.1f° to go", -difference)
        }
    }

    private var statusSymbol: String {
        switch status {
        case .onTarget: return "checkmark.circle.fill"
        case .over: return "exclamationmark.triangle.fill"
        case .close, .far: return "arrow.up.circle"
        }
    }

    private var statusFill: Color {
        switch status {
        case .onTarget: return .green
        case .over: return .red
        case .close: return Theme.highVis
        case .far: return Color(uiColor: .tertiarySystemFill)
        }
    }

    private var statusForeground: Color {
        status == .far ? .primary : .black
    }

    private var barFill: Color {
        status == .far ? Color.accentColor : statusFill
    }

    var body: some View {
        VStack(spacing: 16) {
            if level.isAvailable {
                readout
                LevelBar(value: level.angle, target: target, tolerance: tolerance, fill: barFill)
                    .frame(height: 28)
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
        .onChange(of: isOnTarget) { _, onTarget in
            guard onTarget else { return }
            hits += 1
            if beep { AudioServicesPlaySystemSound(1057) }
        }
        .sensoryFeedback(.success, trigger: hits)
    }

    private var readout: some View {
        VStack(spacing: 10) {
            Text(String(format: "%.1f°", level.angle))
                .font(.system(size: readoutSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
            Text("Target \(AngleFormat.string(target))")
                .font(.headline)
                .foregroundStyle(.secondary)
            StatusPill(text: statusText, systemImage: statusSymbol, fill: statusFill, foreground: statusForeground)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: "%.1f degrees. Target %@. %@.", level.angle, AngleFormat.string(target), statusText))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                level.zero()
            } label: {
                Label("Zero here", systemImage: "scope")
            }
            .buttonStyle(.highVis)
            if level.zeroOffset != 0 {
                Button("Clear zero") {
                    level.clearZero()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }
}

/// Horizontal bar with the target window marked.
struct LevelBar: View {
    let value: Double
    let target: Double
    let tolerance: Double
    let fill: Color

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
                    .fill(fill)
                    .frame(width: max(position(value), 6))
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 2)
                    .offset(x: position(target) - 1)
            }
            .clipShape(Capsule())
        }
        .accessibilityHidden(true)
    }
}

/// Standalone level tab for checking any bend.
struct LevelView: View {
    @StateObject private var level = MotionLevel()
    @State private var target: Double = 30
    private let targets: [Double] = [10, 22.5, 30, 45, 60, 90]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    ChoicePicker(title: "Target angle", options: targets, label: { AngleFormat.string($0) },
                                 selection: $target, showsTitle: false)
                    LevelGauge(target: target, level: level)
                }
                .padding()
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Level")
        }
        .keepsLevelRunning(level)
    }
}

/// Walks through a plan one step at a time, with the level on every bend.
struct GuidedBendView: View {
    let plan: BendPlan

    @Environment(\.lengthFormat) private var format
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var calloutSize: CGFloat = 34
    @StateObject private var level = MotionLevel()
    @State private var index = 0

    var body: some View {
        let steps = plan.steps
        let step = steps[min(index, max(steps.count - 1, 0))]
        let isLast = index >= steps.count - 1
        VStack(spacing: 14) {
            ProgressView(value: Double(index + 1), total: Double(max(steps.count, 1)))
                .accessibilityLabel("Step \(step.number) of \(steps.count)")
            Text("Step \(step.number) of \(steps.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 20) {
                    if let label = step.markLabel, let mark = plan.mark(label) {
                        markCallout(mark)
                    }
                    if let prep = step.prep.label {
                        StatusPill(text: prep, systemImage: step.prep.symbolName,
                                   fill: Theme.highVis, foreground: Theme.onHighVis)
                    }
                    Text(step.instruction)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    if let angle = step.angle {
                        LevelGauge(target: angle, level: level)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollBounceBehavior(.basedOnSize)

            HStack {
                Button {
                    index -= 1
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .frame(minHeight: 44)
                }
                .disabled(index == 0)
                Spacer()
                Button {
                    if isLast {
                        dismiss()
                    } else {
                        index += 1
                    }
                } label: {
                    Text(isLast ? "Done" : "Next step")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.highVis)
            }
        }
        .padding()
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .navigationTitle(plan.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .keepsLevelRunning(level)
    }

    private func markCallout(_ mark: BendMark) -> some View {
        HStack(alignment: .top, spacing: 16) {
            MarkBadge(label: mark.label, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(mark.distanceText(format))
                    .font(.system(size: calloutSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(mark.referenceText)
                    .foregroundStyle(.secondary)
                Label(mark.benderMark.displayName, systemImage: mark.benderMark.symbolName)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct KeepsLevelRunning: ViewModifier {
    let level: MotionLevel

    func body(content: Content) -> some View {
        content
            .onAppear {
                level.start()
                UIApplication.shared.isIdleTimerDisabled = true
            }
            .onDisappear {
                level.stop()
                UIApplication.shared.isIdleTimerDisabled = false
            }
    }
}

extension View {
    /// Runs the motion sensor and keeps the screen on while this view is showing.
    func keepsLevelRunning(_ level: MotionLevel) -> some View {
        modifier(KeepsLevelRunning(level: level))
    }
}
