import Foundation
import SwiftData
import BendKit

/// A plan the user saved so the marks are there for the next pull.
@Model
final class SavedBend {
    var createdAt: Date = Date.now
    var kindRaw: String = BendKind.offset.rawValue
    var title: String = ""
    var planData: Data = Data()

    init(plan: BendPlan, title: String) {
        self.createdAt = Date.now
        self.kindRaw = plan.kind.rawValue
        self.title = title
        self.planData = (try? JSONEncoder().encode(plan)) ?? Data()
    }

    var kind: BendKind { BendKind(rawValue: kindRaw) ?? .offset }

    var plan: BendPlan? { try? JSONDecoder().decode(BendPlan.self, from: planData) }
}
