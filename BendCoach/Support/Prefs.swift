import SwiftUI
import BendKit

/// UserDefaults keys used with @AppStorage.
enum PrefKey {
    static let denominator = "lengthDenominator"
    static let useFeet = "useFeetAndInches"
    static let multiplierMode = "multiplierMode"
    static let selectedBenderID = "selectedBenderID"
    static let levelBeep = "levelBeep"
    static let levelTolerance = "levelTolerance"
    static let debugPro = "debugProUnlock"
}

/// What the free tier allows before asking for Pro.
enum FreeLimits {
    static let customBenders = 1
    static let savedBends = 5
}

enum BenderLibrary {
    /// Resolves a stored bender ID to a preset or one of the user's own benders.
    static func profile(id: String, customs: [BenderProfile]) -> BenderProfile {
        guard let uuid = UUID(uuidString: id) else { return BenderPresets.standard }
        if let preset = BenderPresets.preset(id: uuid) { return preset }
        return customs.first { $0.id == uuid } ?? BenderPresets.standard
    }
}

private struct LengthFormatKey: EnvironmentKey {
    static let defaultValue = LengthFormat.standard
}

private struct CurrentBenderKey: EnvironmentKey {
    static let defaultValue = BenderPresets.standard
}

private struct MultiplierModeKey: EnvironmentKey {
    static let defaultValue = MultiplierMode.exact
}

extension EnvironmentValues {
    var lengthFormat: LengthFormat {
        get { self[LengthFormatKey.self] }
        set { self[LengthFormatKey.self] = newValue }
    }

    var currentBender: BenderProfile {
        get { self[CurrentBenderKey.self] }
        set { self[CurrentBenderKey.self] = newValue }
    }

    var multiplierMode: MultiplierMode {
        get { self[MultiplierModeKey.self] }
        set { self[MultiplierModeKey.self] = newValue }
    }
}
