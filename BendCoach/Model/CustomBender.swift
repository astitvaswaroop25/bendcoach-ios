import Foundation
import SwiftData
import BendKit

/// A bender the user set up or calibrated themselves.
@Model
final class CustomBender {
    var benderID: UUID = UUID()
    var name: String = ""
    var conduitTypeRaw: String = ConduitType.emt.rawValue
    var tradeSizeRaw: String = TradeSize.half.rawValue
    var takeUp: Double = 5
    var centerlineRadius: Double = 4.1875
    var createdAt: Date = Date.now

    init(profile: BenderProfile) {
        self.benderID = profile.id
        self.name = profile.name
        self.conduitTypeRaw = profile.conduitType.rawValue
        self.tradeSizeRaw = profile.tradeSize.rawValue
        self.takeUp = profile.takeUp
        self.centerlineRadius = profile.centerlineRadius
        self.createdAt = Date.now
    }

    var profile: BenderProfile {
        BenderProfile(
            id: benderID,
            name: name,
            conduitType: ConduitType(rawValue: conduitTypeRaw) ?? .emt,
            tradeSize: TradeSize(rawValue: tradeSizeRaw) ?? .half,
            takeUp: takeUp,
            centerlineRadius: centerlineRadius,
            isPreset: false
        )
    }

    func update(from profile: BenderProfile) {
        name = profile.name
        conduitTypeRaw = profile.conduitType.rawValue
        tradeSizeRaw = profile.tradeSize.rawValue
        takeUp = profile.takeUp
        centerlineRadius = profile.centerlineRadius
    }
}
