import SwiftUI
import BendKit

struct StubUpView: View {
    @Environment(\.currentBender) private var bender
    @State private var stubHeight: Double?

    private var result: Result<BendPlan, Error>? {
        guard let stubHeight else { return nil }
        return Result { try BendCalculator.stub90(stubHeight: stubHeight, bender: bender) }
    }

    var body: some View {
        CalculatorScreen(kind: .stub90, result: result) {
            BenderSummaryRow()
            MeasurementField(title: "Stub height", hint: "From the end to the back of the bend", value: $stubHeight)
        }
    }
}

struct OffsetView: View {
    @Environment(\.multiplierMode) private var mode
    @State private var depth: Double?
    @State private var angle: Double = 30
    @State private var distance: Double?
    @State private var measuredTo: OffsetMeasure = .toObstruction

    private var result: Result<BendPlan, Error>? {
        guard let depth else { return nil }
        return Result {
            try BendCalculator.offset(depth: depth, angle: angle, distance: distance,
                                      measuredTo: measuredTo, mode: mode)
        }
    }

    var body: some View {
        CalculatorScreen(kind: .offset, result: result) {
            MeasurementField(title: "Offset depth", hint: "How far the conduit has to move over", value: $depth)
            AnglePicker(title: "Bend angle", angles: BendMath.standardOffsetAngles, selection: $angle)
            MeasurementField(title: "Distance from the end", hint: "Optional: places the marks on the stick", value: $distance)
            if distance != nil {
                MeasurePicker(selection: $measuredTo)
            }
        }
    }
}

struct ThreePointSaddleView: View {
    @State private var height: Double?
    @State private var style: SaddleStyle = .fortyFive
    @State private var distance: Double?

    private var result: Result<BendPlan, Error>? {
        guard let height else { return nil }
        return Result {
            try BendCalculator.threePointSaddle(obstructionHeight: height, distanceToCenter: distance, style: style)
        }
    }

    var body: some View {
        CalculatorScreen(kind: .threePointSaddle, result: result) {
            MeasurementField(title: "Obstruction height", hint: "Usually the pipe's outside diameter", value: $height)
            VStack(alignment: .leading, spacing: 8) {
                Text("Saddle")
                Picker("Saddle", selection: $style) {
                    ForEach(SaddleStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 4)
            MeasurementField(title: "End to center of obstruction", hint: "Optional: places the marks on the stick", value: $distance)
        }
    }
}

struct FourPointSaddleView: View {
    @Environment(\.multiplierMode) private var mode
    @State private var height: Double?
    @State private var width: Double?
    @State private var angle: Double = 30
    @State private var distance: Double?

    private var result: Result<BendPlan, Error>? {
        guard let height, let width else { return nil }
        return Result {
            try BendCalculator.fourPointSaddle(height: height, width: width, distanceToObstruction: distance,
                                               angle: angle, mode: mode)
        }
    }

    var body: some View {
        CalculatorScreen(kind: .fourPointSaddle, result: result) {
            MeasurementField(title: "Obstruction height", value: $height)
            MeasurementField(title: "Width to clear", hint: "Add a little room on each side", value: $width)
            AnglePicker(title: "Bend angle", angles: [22.5, 30, 45], selection: $angle)
            MeasurementField(title: "End to obstruction", hint: "Optional: to the near edge", value: $distance)
        }
    }
}

struct BackToBackView: View {
    @Environment(\.currentBender) private var bender
    @State private var stubHeight: Double?
    @State private var backToBack: Double?

    private var result: Result<BendPlan, Error>? {
        guard let stubHeight, let backToBack else { return nil }
        return Result {
            try BendCalculator.backToBack(firstStubHeight: stubHeight, backToBack: backToBack, bender: bender)
        }
    }

    var body: some View {
        CalculatorScreen(kind: .backToBack, result: result) {
            BenderSummaryRow()
            MeasurementField(title: "First stub height", hint: "From the end to the back of the bend", value: $stubHeight)
            MeasurementField(title: "Back-to-back", hint: "Outside of one stub to outside of the other", value: $backToBack)
        }
    }
}

struct RollingOffsetView: View {
    @Environment(\.multiplierMode) private var mode
    @State private var rise: Double?
    @State private var roll: Double?
    @State private var angle: Double = 30
    @State private var distance: Double?
    @State private var measuredTo: OffsetMeasure = .toObstruction

    private var result: Result<BendPlan, Error>? {
        guard let rise, let roll else { return nil }
        return Result {
            try BendCalculator.rollingOffset(rise: rise, roll: roll, angle: angle, distance: distance,
                                             measuredTo: measuredTo, mode: mode)
        }
    }

    var body: some View {
        CalculatorScreen(kind: .rollingOffset, result: result) {
            MeasurementField(title: "Rise", hint: "Up or down", value: $rise)
            MeasurementField(title: "Roll", hint: "Sideways", value: $roll)
            AnglePicker(title: "Bend angle", angles: BendMath.standardOffsetAngles, selection: $angle)
            MeasurementField(title: "Distance from the end", hint: "Optional: places the marks on the stick", value: $distance)
            if distance != nil {
                MeasurePicker(selection: $measuredTo)
            }
        }
    }
}

/// "Distance runs to the obstruction / the first bend".
struct MeasurePicker: View {
    @Binding var selection: OffsetMeasure

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("That distance runs to")
            Picker("That distance runs to", selection: $selection) {
                ForEach(OffsetMeasure.allCases) { measure in
                    Text(measure.displayName).tag(measure)
                }
            }
            .pickerStyle(.segmented)
            Text(selection == .toObstruction
                 ? "The offset finishes at the obstruction, so shrink is added."
                 : "The first bend starts here. Shrink doesn't change the marks.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
