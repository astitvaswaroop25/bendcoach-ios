import Foundation

public enum ConduitType: String, Codable, CaseIterable, Sendable, Identifiable {
    case emt
    case imc
    case rigid

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .emt: return "EMT"
        case .imc: return "IMC"
        case .rigid: return "Rigid"
        }
    }
}

/// Trade sizes that are bent with hand benders.
public enum TradeSize: String, Codable, CaseIterable, Sendable, Identifiable {
    case half = "1/2"
    case threeQuarter = "3/4"
    case one = "1"
    case oneAndQuarter = "1-1/4"

    public var id: String { rawValue }
    public var displayName: String { rawValue + "\"" }
}

public enum ConduitSpecs {
    /// Nominal outside diameter in inches.
    /// EMT per ANSI C80.3, rigid (RMC) per ANSI C80.1, IMC per ANSI C80.6.
    public static func outsideDiameter(_ type: ConduitType, _ size: TradeSize) -> Double {
        switch type {
        case .emt:
            switch size {
            case .half: return 0.706
            case .threeQuarter: return 0.922
            case .one: return 1.163
            case .oneAndQuarter: return 1.510
            }
        case .imc:
            switch size {
            case .half: return 0.815
            case .threeQuarter: return 1.029
            case .one: return 1.290
            case .oneAndQuarter: return 1.638
            }
        case .rigid:
            switch size {
            case .half: return 0.840
            case .threeQuarter: return 1.050
            case .one: return 1.315
            case .oneAndQuarter: return 1.660
            }
        }
    }
}

/// What the app needs to know about one bender + conduit combination.
public struct BenderProfile: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var conduitType: ConduitType
    public var tradeSize: TradeSize
    /// Distance from the bender's arrow to the back of a finished 90° (also called the deduct).
    public var takeUp: Double
    /// Centerline radius of the bender shoe, in inches. Used for drawings and gain.
    public var centerlineRadius: Double
    /// True for the built-in starting points; false for benders the user saved.
    public var isPreset: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        conduitType: ConduitType,
        tradeSize: TradeSize,
        takeUp: Double,
        centerlineRadius: Double,
        isPreset: Bool = false
    ) {
        self.id = id
        self.name = name
        self.conduitType = conduitType
        self.tradeSize = tradeSize
        self.takeUp = takeUp
        self.centerlineRadius = centerlineRadius
        self.isPreset = isPreset
    }

    public var outsideDiameter: Double { ConduitSpecs.outsideDiameter(conduitType, tradeSize) }

    /// Conduit saved by bending a 90° on this radius instead of a sharp corner,
    /// with both legs measured to the back of the bend.
    public var gain: Double {
        BendMath.gain90(centerlineRadius: centerlineRadius, outsideDiameter: outsideDiameter)
    }

    /// "1/2" EMT"
    public var conduitDescription: String { "\(tradeSize.displayName) \(conduitType.displayName)" }
}

/// Starting points taken from the take-up tables printed on Klein, Ideal and Gardner Bender
/// hand benders, with centerline radii from Greenlee's SITE-RITE catalog. Real benders vary,
/// which is why the app lets people calibrate their own.
public enum BenderPresets {
    private static func presetID(_ n: Int) -> UUID {
        let digits = String(n)
        let padded = String(repeating: "0", count: max(0, 12 - digits.count)) + digits
        return UUID(uuidString: "00000000-0000-0000-0000-" + padded)!
    }

    public static let all: [BenderProfile] = [
        BenderProfile(id: presetID(1), name: "1/2\" EMT hand bender", conduitType: .emt, tradeSize: .half,
                      takeUp: 5, centerlineRadius: 4.1875, isPreset: true),
        BenderProfile(id: presetID(2), name: "3/4\" EMT hand bender", conduitType: .emt, tradeSize: .threeQuarter,
                      takeUp: 6, centerlineRadius: 5.125, isPreset: true),
        BenderProfile(id: presetID(3), name: "1\" EMT hand bender", conduitType: .emt, tradeSize: .one,
                      takeUp: 8, centerlineRadius: 6.5, isPreset: true),
        BenderProfile(id: presetID(4), name: "1-1/4\" EMT hand bender", conduitType: .emt, tradeSize: .oneAndQuarter,
                      takeUp: 11, centerlineRadius: 9.625, isPreset: true),
        BenderProfile(id: presetID(5), name: "1/2\" rigid in a 3/4\" EMT bender", conduitType: .rigid, tradeSize: .half,
                      takeUp: 6, centerlineRadius: 5.125, isPreset: true),
        BenderProfile(id: presetID(6), name: "3/4\" rigid in a 1\" EMT bender", conduitType: .rigid, tradeSize: .threeQuarter,
                      takeUp: 8, centerlineRadius: 6.5, isPreset: true),
        BenderProfile(id: presetID(7), name: "1\" rigid in a 1-1/4\" EMT bender", conduitType: .rigid, tradeSize: .one,
                      takeUp: 11, centerlineRadius: 9.625, isPreset: true)
    ]

    public static var standard: BenderProfile { all[0] }

    public static func preset(id: UUID) -> BenderProfile? {
        all.first { $0.id == id }
    }

    /// The preset that matches a conduit type and size, used as the starting point for a custom bender.
    public static func closest(to type: ConduitType, _ size: TradeSize) -> BenderProfile {
        let rigidLike: ConduitType = (type == .emt) ? .emt : .rigid
        return all.first { $0.conduitType == rigidLike && $0.tradeSize == size }
            ?? all.first { $0.tradeSize == size }
            ?? standard
    }
}
