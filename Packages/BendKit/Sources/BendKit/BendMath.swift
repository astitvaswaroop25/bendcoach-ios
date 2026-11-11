import Foundation

/// How the distance between offset marks is figured.
public enum MultiplierMode: String, Codable, CaseIterable, Sendable, Identifiable {
    /// 1 / sin(angle): 10° = 5.76, 22½° = 2.61, 30° = 2, 45° = 1.41, 60° = 1.15.
    case exact
    /// The rounded numbers printed on many bender charts: 6, 3.9, 2.6, 2, 1.4, 1.2.
    case benderChart

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .exact: return "Exact (trig)"
        case .benderChart: return "Bender chart (rounded)"
        }
    }
}

public enum BendMath {
    /// Angles cast on standard hand benders.
    public static let standardOffsetAngles: [Double] = [10, 15, 22.5, 30, 45, 60]

    static let chartMultipliers: [(angle: Double, multiplier: Double)] = [
        (10, 6.0), (15, 3.9), (22.5, 2.6), (30, 2.0), (45, 1.4), (60, 1.2)
    ]

    /// Shrink per inch of offset depth as printed on Klein, Ideal and Greenlee charts.
    static let shrinkTable: [(angle: Double, perInch: Double)] = [
        (0, 0), (10, 1.0 / 16), (15, 1.0 / 8), (22.5, 3.0 / 16), (30, 1.0 / 4), (45, 3.0 / 8), (60, 1.0 / 2)
    ]

    public static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    public static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }

    /// Distance between offset marks per inch of offset depth.
    public static func multiplier(_ angle: Double, mode: MultiplierMode = .exact) -> Double {
        if mode == .benderChart, let chart = chartMultiplier(angle) {
            return chart
        }
        return 1 / sin(radians(angle))
    }

    static func chartMultiplier(_ angle: Double) -> Double? {
        chartMultipliers.first { abs($0.angle - angle) < 1e-6 }?.multiplier
    }

    /// How much the run shortens per inch of offset depth. Uses the printed chart at the
    /// standard angles, interpolates between them, and follows tan(θ/2) past 60°.
    public static func shrinkPerInch(_ angle: Double) -> Double {
        guard angle > 0 else { return 0 }
        let table = shrinkTable
        let last = table[table.count - 1]
        if angle > last.angle {
            return last.perInch * tan(radians(angle) / 2) / tan(radians(last.angle) / 2)
        }
        for index in 1..<table.count {
            let low = table[index - 1]
            let high = table[index]
            if angle <= high.angle + 1e-9 {
                let t = (angle - low.angle) / (high.angle - low.angle)
                return low.perInch + t * (high.perInch - low.perInch)
            }
        }
        return last.perInch
    }

    /// Conduit saved by a 90° on radius `centerlineRadius` compared with a sharp corner,
    /// both legs measured to the back (outside) of the bend.
    public static func gain90(centerlineRadius: Double, outsideDiameter: Double) -> Double {
        2 * (centerlineRadius + outsideDiameter / 2) - .pi / 2 * centerlineRadius
    }
}

public enum Calibration {
    /// Take-up from a test bend: mark the conduit `markDistance` from the end, put the mark
    /// on the arrow, bend a 90° and measure the stub to the back of the bend.
    public static func takeUp(markDistance: Double, measuredStub: Double) -> Double? {
        guard markDistance >= 0, measuredStub > markDistance else { return nil }
        return measuredStub - markDistance
    }
}
