import SwiftUI
import BendKit

enum Theme {
    /// Galvanized-steel greys for drawing conduit.
    static let conduit = Color(red: 0.70, green: 0.73, blue: 0.76)
    static let conduitEdge = Color(red: 0.42, green: 0.46, blue: 0.50)
}

extension BendKind {
    var symbolName: String {
        switch self {
        case .stub90: return "arrow.turn.right.up"
        case .offset: return "arrow.up.right"
        case .threePointSaddle: return "triangle"
        case .fourPointSaddle: return "rectangle"
        case .backToBack: return "arrow.uturn.up"
        case .rollingOffset: return "rotate.3d"
        }
    }
}

extension BenderMark {
    var symbolName: String {
        switch self {
        case .arrow: return "arrow.up"
        case .star: return "star.fill"
        case .centerNotch: return "chevron.down"
        }
    }

    /// Plain-text stand-in used inside Canvas drawings.
    var glyph: String {
        switch self {
        case .arrow: return "↑"
        case .star: return "★"
        case .centerNotch: return "▼"
        }
    }
}

extension StepPrep {
    var label: String? {
        switch self {
        case .noChange: return nil
        case .rotate180: return "Rotate 180° first"
        case .turnEndForEnd: return "Turn end for end first"
        }
    }

    var symbolName: String {
        switch self {
        case .noChange: return "circle"
        case .rotate180: return "arrow.triangle.2.circlepath"
        case .turnEndForEnd: return "arrow.left.arrow.right"
        }
    }
}

extension BendMark {
    /// "25-1/2"", "Start" or "+12"".
    func distanceText(_ format: LengthFormat) -> String {
        switch reference {
        case .firstMark:
            return distance == 0 ? "Start" : "+" + format.string(distance)
        case .conduitEnd, .backOfFirstBend:
            return format.string(distance)
        }
    }

    var referenceText: String {
        switch reference {
        case .conduitEnd: return "from the end"
        case .firstMark: return distance == 0 ? "wherever the first bend goes" : "from mark A"
        case .backOfFirstBend: return "from the back of the 1st 90°"
        }
    }
}

extension BendPlan {
    func input(_ label: String) -> PlanFact? {
        inputs.first { $0.label == label }
    }

    /// Short name for history, e.g. `6" offset at 30°`.
    func title(format: LengthFormat) -> String {
        func length(_ label: String) -> String {
            input(label).map { format.string($0.value) } ?? "?"
        }
        func angle(_ label: String) -> String {
            input(label).map { AngleFormat.string($0.value) } ?? ""
        }
        switch kind {
        case .stub90:
            return "\(length("Stub height")) stub-up"
        case .offset:
            return "\(length("Offset depth")) offset at \(angle("Angle"))"
        case .threePointSaddle:
            return "\(length("Obstruction height")) saddle, \(input("Saddle")?.text ?? "")"
        case .fourPointSaddle:
            return "\(length("Obstruction height")) × \(length("Width to clear")) 4-point saddle"
        case .backToBack:
            return "\(length("Back-to-back")) back-to-back"
        case .rollingOffset:
            return "\(length("Rise")) rise × \(length("Roll")) roll at \(angle("Angle"))"
        }
    }

    /// Plain text for sharing with a helper or pasting into notes.
    func shareText(format: LengthFormat) -> String {
        var lines = ["BendCoach: \(title(format: format))"]
        if let benderName { lines.append("Bender: \(benderName)") }
        lines.append("")
        lines.append("Marks")
        for mark in marks {
            lines.append("  \(mark.label): \(mark.distanceText(format)) \(mark.referenceText) · \(mark.benderMark.displayName) · bend \(AngleFormat.string(mark.angle))")
        }
        lines.append("")
        lines.append("Steps")
        for step in steps {
            lines.append("  \(step.number). \(step.instruction)")
        }
        if !warnings.isEmpty {
            lines.append("")
            lines.append(contentsOf: warnings.map { "Warning: \($0)" })
        }
        return lines.joined(separator: "\n")
    }
}
