import Foundation

public enum BendKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case stub90
    case offset
    case threePointSaddle
    case fourPointSaddle
    case backToBack
    case rollingOffset

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .stub90: return "90° Stub-Up"
        case .offset: return "Offset"
        case .threePointSaddle: return "3-Point Saddle"
        case .fourPointSaddle: return "4-Point Saddle"
        case .backToBack: return "Back-to-Back 90s"
        case .rollingOffset: return "Rolling Offset"
        }
    }

    public var subtitle: String {
        switch self {
        case .stub90: return "Stub up to a box or panel"
        case .offset: return "Jog around something in the way"
        case .threePointSaddle: return "Hop over a pipe"
        case .fourPointSaddle: return "Clear something wide"
        case .backToBack: return "U-shape, two 90s on one stick"
        case .rollingOffset: return "Rise and roll at the same time"
        }
    }

    /// Stub-ups and offsets are free; the rest is part of Pro.
    public var requiresPro: Bool {
        switch self {
        case .stub90, .offset: return false
        case .threePointSaddle, .fourPointSaddle, .backToBack, .rollingOffset: return true
        }
    }
}

/// Where a mark's distance is measured from.
public enum MarkReference: String, Codable, Sendable {
    /// From the end of the conduit you're laying out from.
    case conduitEnd
    /// From mark A, when no starting distance was given.
    case firstMark
    /// From the back (outside) of the first 90°.
    case backOfFirstBend
}

/// The marks cast into a hand bender that a conduit mark is lined up with.
public enum BenderMark: String, Codable, Sendable {
    case arrow
    case star
    case centerNotch

    public var displayName: String {
        switch self {
        case .arrow: return "Arrow"
        case .star: return "Star (back of 90)"
        case .centerNotch: return "Rim notch / teardrop"
        }
    }
}

/// What to do with the conduit before a step.
public enum StepPrep: String, Codable, Sendable {
    case noChange
    case rotate180
    case turnEndForEnd
}

public struct BendMark: Codable, Hashable, Sendable, Identifiable {
    public var label: String
    /// Inches from `reference`.
    public var distance: Double
    public var reference: MarkReference
    public var benderMark: BenderMark
    /// Angle of the bend made at this mark.
    public var angle: Double

    public var id: String { label }

    public init(label: String, distance: Double, reference: MarkReference, benderMark: BenderMark, angle: Double) {
        self.label = label
        self.distance = distance
        self.reference = reference
        self.benderMark = benderMark
        self.angle = angle
    }
}

public struct BendStep: Codable, Hashable, Sendable, Identifiable {
    public var number: Int
    /// The mark this step bends at, if it's a bend.
    public var markLabel: String?
    public var benderMark: BenderMark?
    /// Target angle for bend steps; nil for measuring and checking steps.
    public var angle: Double?
    public var prep: StepPrep
    public var instruction: String

    public var id: Int { number }
    public var isBend: Bool { angle != nil }

    public init(number: Int, markLabel: String? = nil, benderMark: BenderMark? = nil, angle: Double? = nil,
                prep: StepPrep = .noChange, instruction: String) {
        self.number = number
        self.markLabel = markLabel
        self.benderMark = benderMark
        self.angle = angle
        self.prep = prep
        self.instruction = instruction
    }
}

public enum FactUnit: String, Codable, Sendable {
    case length
    case angle
    case multiplier
    case text
}

/// One labeled number (or short text) shown with a plan.
public struct PlanFact: Codable, Hashable, Sendable, Identifiable {
    public var label: String
    public var value: Double
    public var unit: FactUnit
    public var text: String?

    public var id: String { label }

    public init(_ label: String, _ value: Double, _ unit: FactUnit) {
        self.label = label
        self.value = value
        self.unit = unit
        self.text = nil
    }

    public init(_ label: String, text: String) {
        self.label = label
        self.value = 0
        self.unit = .text
        self.text = text
    }

    public func formatted(_ format: LengthFormat) -> String {
        switch unit {
        case .length: return format.string(value)
        case .angle: return AngleFormat.string(value)
        case .multiplier:
            let hundredths = (value * 100).rounded() / 100
            return "× \(hundredths)"
        case .text: return text ?? ""
        }
    }
}

public struct Point2D: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

/// Everything the app shows for one bend: marks, numbered steps, key numbers and the finished shape.
public struct BendPlan: Codable, Hashable, Sendable {
    public var kind: BendKind
    public var inputs: [PlanFact]
    public var marks: [BendMark]
    public var steps: [BendStep]
    public var facts: [PlanFact]
    public var warnings: [String]
    /// Corner points of the finished conduit (sharp corners, inches, y up).
    public var shape: [Point2D]
    public var benderName: String?

    public init(kind: BendKind, inputs: [PlanFact], marks: [BendMark], steps: [BendStep], facts: [PlanFact],
                warnings: [String] = [], shape: [Point2D], benderName: String? = nil) {
        self.kind = kind
        self.inputs = inputs
        self.marks = marks
        self.steps = steps
        self.facts = facts
        self.warnings = warnings
        self.shape = shape
        self.benderName = benderName
    }

    public func mark(_ label: String) -> BendMark? {
        marks.first { $0.label == label }
    }

    public var bendSteps: [BendStep] { steps.filter { $0.isBend } }
}

public enum BendInputError: Error, Equatable, LocalizedError {
    case notPositive(String)
    case negative(String)
    case angleOutOfRange(Double)

    public var errorDescription: String? {
        switch self {
        case .notPositive(let field): return "\(field) must be more than zero."
        case .negative(let field): return "\(field) can't be negative."
        case .angleOutOfRange(let angle): return "\(AngleFormat.string(angle)) won't work here. Pick an angle between 5° and 75°."
        }
    }
}
