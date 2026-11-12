import Foundation
import BendKit

/// Debug-only launch arguments that open a screen with sample numbers filled in. CI uses this
/// to take simulator screenshots, e.g. `-demoScreen offset` or `-demoScreen offset:results`.
/// Release builds ignore it.
enum Demo {
    static var screen: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-demoScreen"), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
        #else
        return nil
        #endif
    }

    static var isActive: Bool { screen != nil }

    /// The screen name without a `:results` suffix.
    static var screenName: String? {
        screen.map { String($0.split(separator: ":").first ?? "") }
    }

    /// Calculators list their results above the inputs, so a screenshot shows the marks.
    static var showsResultsFirst: Bool { screen?.hasSuffix(":results") ?? false }

    static var kind: BendKind? { screenName.flatMap { BendKind(rawValue: $0) } }

    /// A steady level reading for the simulator, which has no motion sensor: on target in the
    /// Level tab, a little short of the bend in guided mode.
    static var levelAngle: Double? {
        guard isActive else { return nil }
        return screenName == "level" ? 29.8 : 43.6
    }

    /// Demo screenshots show Pro screens unlocked, except the paywall itself.
    static var unlocksPro: Bool { isActive && screenName != "paywall" }

    static var initialTab: AppTab {
        switch screenName {
        case "level": return .level
        case "saved": return .saved
        case "settings": return .settings
        default: return .bend
        }
    }

    /// A sample measurement while demoing, otherwise nothing.
    static func sample(_ inches: Double) -> Double? {
        isActive ? inches : nil
    }

    static func samplePlans() -> [BendPlan] {
        [
            try? BendCalculator.offset(depth: 6, angle: 30, distance: 24),
            try? BendCalculator.threePointSaddle(obstructionHeight: 3, distanceToCenter: 48),
            try? BendCalculator.stub90(stubHeight: 11, bender: BenderPresets.standard)
        ].compactMap { $0 }
    }
}
