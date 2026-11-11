import XCTest
@testable import BendKit

final class LengthFormatTests: XCTestCase {
    func testFormatsWholeInchesAndFractions() {
        let format = LengthFormat.standard
        XCTAssertEqual(format.string(40.625), "40-5/8\"")
        XCTAssertEqual(format.string(0.5), "1/2\"")
        XCTAssertEqual(format.string(12), "12\"")
        XCTAssertEqual(format.string(0), "0\"")
        XCTAssertEqual(format.string(0.0625), "1/16\"")
        XCTAssertEqual(format.string(19.6079), "19-5/8\"")
        XCTAssertEqual(format.string(11.97), "12\"")
        XCTAssertEqual(format.string(-1.5), "-1-1/2\"")
    }

    func testEighthsPrecision() {
        let format = LengthFormat(denominator: 8)
        XCTAssertEqual(format.string(40.5625), "40-5/8\"")
        XCTAssertEqual(format.string(3.0625), "3-1/8\"")
        XCTAssertEqual(format.string(3.25), "3-1/4\"")
    }

    func testFeetAndInches() {
        let format = LengthFormat(denominator: 16, useFeet: true)
        XCTAssertEqual(format.string(40.625), "3' 4-5/8\"")
        XCTAssertEqual(format.string(12), "1' 0\"")
        XCTAssertEqual(format.string(12.5), "1' 1/2\"")
        XCTAssertEqual(format.string(11.5), "11-1/2\"")
    }

    func testRounding() {
        XCTAssertEqual(LengthFormat.standard.rounded(19.6079), 19.625, accuracy: 1e-12)
        XCTAssertEqual(LengthFormat(denominator: 8).rounded(3.3), 3.25, accuracy: 1e-12)
    }

    func testAngleFormat() {
        XCTAssertEqual(AngleFormat.string(30), "30°")
        XCTAssertEqual(AngleFormat.string(22.5), "22½°")
        XCTAssertEqual(AngleFormat.string(90), "90°")
        XCTAssertEqual(AngleFormat.string(36.8699), "36.9°")
    }

    func testParserAcceptsTapeFormats() {
        let cases: [(String, Double)] = [
            ("40", 40), ("40.5", 40.5), ("40 5/8", 40.625), ("40-5/8", 40.625), ("5/8", 0.625),
            ("40 5/8\"", 40.625), ("3'", 36), ("3' 4-5/8\"", 40.625), ("3'4\"", 40),
            ("3 ft 4 in", 40), ("1.5'", 18), ("4 1/2 in", 4.5), ("12in", 12), ("3′ 4″", 40)
        ]
        for (text, expected) in cases {
            guard let value = LengthParser.inches(from: text) else {
                XCTFail("Couldn't parse \(text)")
                continue
            }
            XCTAssertEqual(value, expected, accuracy: 1e-12, text)
        }
    }

    func testParserRejectsGarbage() {
        for text in ["", "abc", "3/0", "4 5", "-4", "1'2'3", "5/8 4", "4\" 3"] {
            XCTAssertNil(LengthParser.inches(from: text), text)
        }
    }
}

final class MeasurementEntryTests: XCTestCase {
    func testTypingInchesAndAFraction() {
        var entry = MeasurementEntry()
        XCTAssertNil(entry.value)
        XCTAssertEqual(entry.display, "0\"")
        entry.appendDigit(4)
        entry.appendDigit(0)
        entry.setFraction(5, 8)
        XCTAssertEqual(entry.value ?? .nan, 40.625, accuracy: 1e-12)
        XCTAssertEqual(entry.display, "40 5/8\"")
    }

    func testFeetThenInches() {
        var entry = MeasurementEntry()
        entry.appendDigit(3)
        entry.commitFeet()
        entry.appendDigit(4)
        entry.setFraction(10, 16)
        XCTAssertEqual(entry.value ?? .nan, 40.625, accuracy: 1e-12)
        XCTAssertEqual(entry.display, "3' 4 5/8\"")
    }

    func testBackspaceUnwindsFractionThenDigitsThenFeet() {
        var entry = MeasurementEntry()
        entry.appendDigit(3)
        entry.commitFeet()
        entry.appendDigit(4)
        entry.setFraction(1, 2)
        entry.backspace()
        XCTAssertEqual(entry.display, "3' 4\"")
        entry.backspace()
        XCTAssertEqual(entry.display, "3'")
        entry.backspace()
        XCTAssertEqual(entry.display, "3\"")
        XCTAssertEqual(entry.value ?? .nan, 3, accuracy: 1e-12)
        entry.clear()
        XCTAssertTrue(entry.isEmpty)
    }

    func testDecimalsAndLimits() {
        var entry = MeasurementEntry()
        entry.appendDecimalPoint()
        entry.appendDigit(5)
        XCTAssertEqual(entry.value ?? .nan, 0.5, accuracy: 1e-12)
        entry.setFraction(1, 2)
        XCTAssertNil(entry.fraction, "A fraction can't follow a decimal point")

        var long = MeasurementEntry()
        for _ in 0..<6 { long.appendDigit(9) }
        XCTAssertEqual(long.inchText, "9999")

        var leadingZero = MeasurementEntry()
        leadingZero.appendDigit(0)
        leadingZero.appendDigit(7)
        XCTAssertEqual(leadingZero.inchText, "7")
    }

    func testPrefillFromValue() {
        let entry = MeasurementEntry(inches: 40.625)
        XCTAssertEqual(entry.inchText, "40")
        XCTAssertEqual(entry.fraction, MeasurementEntry.Fraction(5, 8))
        XCTAssertTrue(MeasurementEntry(inches: nil).isEmpty)
        XCTAssertTrue(MeasurementEntry(inches: 0).isEmpty)
    }
}
