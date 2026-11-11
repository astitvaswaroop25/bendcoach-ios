import Foundation

/// State behind the glove-friendly keypad: feet, whole inches and a tape fraction,
/// entered one tap at a time.
public struct MeasurementEntry: Equatable, Sendable {
    public struct Fraction: Equatable, Sendable {
        public let numerator: Int
        public let denominator: Int

        public init(_ numerator: Int, _ denominator: Int) {
            let divisor = LengthFormat.gcd(numerator, denominator)
            self.numerator = numerator / divisor
            self.denominator = denominator / divisor
        }

        public var value: Double { Double(numerator) / Double(denominator) }
        public var text: String { "\(numerator)/\(denominator)" }
    }

    public static let maxDigits = 4

    public private(set) var feet: Int?
    public private(set) var inchText: String
    public private(set) var fraction: Fraction?

    public init() {
        feet = nil
        inchText = ""
        fraction = nil
    }

    /// Pre-fills the entry from an existing value, rounded to 1/denominator.
    public init(inches: Double?, denominator: Int = 16) {
        self.init()
        guard let inches, inches.isFinite, inches > 0, denominator > 0 else { return }
        let units = Int((inches * Double(denominator)).rounded())
        let whole = units / denominator
        let remainder = units % denominator
        if whole > 0 { inchText = String(whole) }
        if remainder > 0 { fraction = Fraction(remainder, denominator) }
    }

    public var isEmpty: Bool { feet == nil && inchText.isEmpty && fraction == nil }

    /// Total in inches, or nil when nothing has been entered.
    public var value: Double? {
        guard !isEmpty else { return nil }
        let inches = inchText.isEmpty ? 0 : (Double(inchText) ?? 0)
        return Double(feet ?? 0) * 12 + inches + (fraction?.value ?? 0)
    }

    public var display: String {
        if isEmpty { return "0\"" }
        var parts: [String] = []
        if let feet { parts.append("\(feet)'") }
        var inches = inchText
        if let fraction {
            inches = inches.isEmpty ? fraction.text : inches + " " + fraction.text
        }
        if !inches.isEmpty { parts.append(inches + "\"") }
        return parts.joined(separator: " ")
    }

    public mutating func appendDigit(_ digit: Int) {
        guard (0...9).contains(digit), fraction == nil else { return }
        let digitCount = inchText.filter { $0.isNumber }.count
        guard digitCount < Self.maxDigits else { return }
        if inchText == "0" { inchText = "" }
        inchText.append(String(digit))
    }

    public mutating func appendDecimalPoint() {
        guard fraction == nil, !inchText.contains(".") else { return }
        inchText = inchText.isEmpty ? "0." : inchText + "."
    }

    /// Turns the whole number typed so far into feet.
    public mutating func commitFeet() {
        guard feet == nil, fraction == nil, !inchText.isEmpty, !inchText.contains("."),
              let value = Int(inchText) else { return }
        feet = value
        inchText = ""
    }

    /// Sets (or replaces) the fraction part, e.g. 5/8.
    public mutating func setFraction(_ numerator: Int, _ denominator: Int) {
        guard denominator > 0, numerator > 0, numerator < denominator,
              !inchText.contains(".") else { return }
        fraction = Fraction(numerator, denominator)
    }

    public mutating func backspace() {
        if fraction != nil {
            fraction = nil
        } else if !inchText.isEmpty {
            inchText.removeLast()
        } else if let feet {
            self.feet = nil
            inchText = String(feet)
        }
    }

    public mutating func clear() {
        self = MeasurementEntry()
    }
}
