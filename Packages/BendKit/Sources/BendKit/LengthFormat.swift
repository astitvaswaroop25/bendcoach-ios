import Foundation

/// Formats inch values the way they read on a tape: whole inches plus a reduced fraction,
/// for example `40-5/8"` or, with feet turned on, `3' 4-5/8"`.
public struct LengthFormat: Hashable, Sendable {
    /// Smallest fraction shown: 8 → 1/8", 16 → 1/16", 32 → 1/32".
    public var denominator: Int
    /// Show values of 12" or more as feet and inches.
    public var useFeet: Bool

    public init(denominator: Int = 16, useFeet: Bool = false) {
        self.denominator = max(1, denominator)
        self.useFeet = useFeet
    }

    public static let standard = LengthFormat()

    /// Rounds `inches` to the nearest 1/denominator.
    public func rounded(_ inches: Double) -> Double {
        (inches * Double(denominator)).rounded() / Double(denominator)
    }

    public func string(_ inches: Double) -> String {
        guard inches.isFinite else { return "—" }
        let units = Int((abs(inches) * Double(denominator)).rounded())
        let sign = (inches < 0 && units > 0) ? "-" : ""
        let whole = units / denominator
        var numerator = units % denominator
        var reducedDenominator = denominator
        if numerator > 0 {
            let divisor = Self.gcd(numerator, reducedDenominator)
            numerator /= divisor
            reducedDenominator /= divisor
        }
        if useFeet && whole >= 12 {
            let feet = whole / 12
            let rest = whole % 12
            return sign + "\(feet)' " + Self.inchText(whole: rest, numerator: numerator, denominator: reducedDenominator)
        }
        return sign + Self.inchText(whole: whole, numerator: numerator, denominator: reducedDenominator)
    }

    static func inchText(whole: Int, numerator: Int, denominator: Int) -> String {
        if numerator == 0 { return "\(whole)\"" }
        if whole == 0 { return "\(numerator)/\(denominator)\"" }
        return "\(whole)-\(numerator)/\(denominator)\""
    }

    static func gcd(_ a: Int, _ b: Int) -> Int {
        var x = abs(a)
        var y = abs(b)
        while y != 0 {
            (x, y) = (y, x % y)
        }
        return max(x, 1)
    }
}

/// Formats bend angles the way they're marked on a bender: `30°`, `22½°`.
public enum AngleFormat {
    public static func string(_ degrees: Double) -> String {
        guard degrees.isFinite else { return "—" }
        let halves = (degrees * 2).rounded()
        if abs(degrees * 2 - halves) < 0.002 {
            let whole = Int(halves) / 2
            let hasHalf = Int(halves) % 2 != 0
            if hasHalf { return whole == 0 ? "½°" : "\(whole)½°" }
            return "\(whole)°"
        }
        let tenths = (degrees * 10).rounded() / 10
        return "\(tenths)°"
    }
}

/// Parses tape-style text into inches. Accepts `40`, `40.5`, `40 5/8`, `40-5/8`, `5/8`,
/// `3'`, `3' 4-5/8"`, `3ft 4in` and similar. Returns nil for anything it can't read.
public enum LengthParser {
    public static func inches(from raw: String) -> Double? {
        var text = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.hasPrefix("-") else { return nil }

        let replacements: [(String, String)] = [
            ("″", "\""), ("”", "\""), ("“", "\""),
            ("′", "'"), ("’", "'"), ("‘", "'"),
            ("''", "\""),
            ("inches", "\""), ("inch", "\""), ("in", "\""),
            ("feet", "'"), ("foot", "'"), ("ft", "'")
        ]
        for (from, to) in replacements {
            text = text.replacingOccurrences(of: from, with: to)
        }

        let feetParts = text.split(separator: "'", omittingEmptySubsequences: false)
        guard feetParts.count <= 2 else { return nil }

        var total = 0.0
        let inchPart: Substring
        if feetParts.count == 2 {
            let feetText = feetParts[0].trimmingCharacters(in: .whitespaces)
            guard let feet = Double(feetText), feet >= 0 else { return nil }
            total = feet * 12
            inchPart = feetParts[1]
        } else {
            inchPart = feetParts[0]
        }

        var inchText = String(inchPart).trimmingCharacters(in: .whitespaces)
        if inchText.hasSuffix("\"") {
            inchText.removeLast()
            inchText = inchText.trimmingCharacters(in: .whitespaces)
        }
        guard !inchText.contains("\"") else { return nil }
        if inchText.isEmpty {
            return feetParts.count == 2 ? total : nil
        }

        let tokens = inchText
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map(String.init)

        switch tokens.count {
        case 1:
            guard let value = numberOrFraction(tokens[0]) else { return nil }
            total += value
        case 2:
            guard !tokens[0].contains("/"),
                  let whole = Double(tokens[0]),
                  tokens[1].contains("/"),
                  let fraction = fraction(tokens[1]) else { return nil }
            total += whole + fraction
        default:
            return nil
        }
        return (total.isFinite && total >= 0) ? total : nil
    }

    static func numberOrFraction(_ token: String) -> Double? {
        if token.contains("/") { return fraction(token) }
        return Double(token)
    }

    static func fraction(_ token: String) -> Double? {
        let parts = token.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let numerator = Int(parts[0]),
              let denominator = Int(parts[1]),
              numerator >= 0, denominator > 0 else { return nil }
        return Double(numerator) / Double(denominator)
    }
}
