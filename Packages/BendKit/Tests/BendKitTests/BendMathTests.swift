import XCTest
@testable import BendKit

final class BendMathTests: XCTestCase {
    func testExactMultipliers() {
        XCTAssertEqual(BendMath.multiplier(10), 5.7588, accuracy: 1e-4)
        XCTAssertEqual(BendMath.multiplier(15), 3.8637, accuracy: 1e-4)
        XCTAssertEqual(BendMath.multiplier(22.5), 2.6131, accuracy: 1e-4)
        XCTAssertEqual(BendMath.multiplier(30), 2.0, accuracy: 1e-12)
        XCTAssertEqual(BendMath.multiplier(45), 1.4142, accuracy: 1e-4)
        XCTAssertEqual(BendMath.multiplier(60), 1.1547, accuracy: 1e-4)
    }

    func testChartMultipliers() {
        XCTAssertEqual(BendMath.multiplier(10, mode: .benderChart), 6.0)
        XCTAssertEqual(BendMath.multiplier(22.5, mode: .benderChart), 2.6)
        XCTAssertEqual(BendMath.multiplier(60, mode: .benderChart), 1.2)
        // Angles that aren't on the chart fall back to exact trig.
        XCTAssertEqual(BendMath.multiplier(37, mode: .benderChart), 1 / sin(37 * Double.pi / 180), accuracy: 1e-12)
    }

    func testShrinkMatchesPrintedCharts() {
        let expected: [(Double, Double)] = [
            (10, 1.0 / 16), (15, 1.0 / 8), (22.5, 3.0 / 16), (30, 0.25), (45, 0.375), (60, 0.5)
        ]
        for (angle, perInch) in expected {
            XCTAssertEqual(BendMath.shrinkPerInch(angle), perInch, accuracy: 1e-12, "\(angle)°")
        }
        XCTAssertEqual(BendMath.shrinkPerInch(37.5), 0.3125, accuracy: 1e-12)
        XCTAssertEqual(BendMath.shrinkPerInch(70), 0.606398, accuracy: 1e-6)
        XCTAssertEqual(BendMath.shrinkPerInch(0), 0)
    }

    func testGain() {
        XCTAssertEqual(BendMath.gain90(centerlineRadius: 4.1875, outsideDiameter: 0.706), 2.5033, accuracy: 1e-4)
        XCTAssertEqual(BenderPresets.standard.gain, 2.5033, accuracy: 1e-4)
    }

    func testCalibration() {
        XCTAssertEqual(Calibration.takeUp(markDistance: 10, measuredStub: 15.125) ?? .nan, 5.125, accuracy: 1e-12)
        XCTAssertNil(Calibration.takeUp(markDistance: 10, measuredStub: 9))
        XCTAssertNil(Calibration.takeUp(markDistance: -1, measuredStub: 9))
    }

    func testPresets() {
        XCTAssertEqual(BenderPresets.all.count, 7)
        XCTAssertEqual(Set(BenderPresets.all.map { $0.id }).count, 7)
        XCTAssertEqual(BenderPresets.all[0].id.uuidString, "00000000-0000-0000-0000-000000000001")
        XCTAssertEqual(BenderPresets.standard.takeUp, 5)
        XCTAssertEqual(BenderPresets.preset(id: BenderPresets.all[2].id)?.takeUp, 8)
        XCTAssertEqual(BenderPresets.closest(to: .imc, .half).conduitType, .rigid)
        XCTAssertEqual(BenderPresets.closest(to: .emt, .one).takeUp, 8)
        XCTAssertEqual(BenderPresets.standard.outsideDiameter, 0.706)
        XCTAssertEqual(BenderPresets.standard.conduitDescription, "1/2\" EMT")
    }
}

final class ShapeGeometryTests: XCTestCase {
    func testRightAngleFillet() {
        let points = [Point2D(0, 10), Point2D(0, 0), Point2D(10, 0)]
        let rounded = ShapeGeometry.filleted(points, radius: 2, segmentsPerArc: 4)
        XCTAssertEqual(rounded.count, 7)
        XCTAssertEqual(rounded.first, Point2D(0, 10))
        XCTAssertEqual(rounded.last, Point2D(10, 0))
        XCTAssertEqual(rounded[1].x, 0, accuracy: 1e-9)
        XCTAssertEqual(rounded[1].y, 2, accuracy: 1e-9)
        XCTAssertEqual(rounded[5].x, 2, accuracy: 1e-9)
        XCTAssertEqual(rounded[5].y, 0, accuracy: 1e-9)
        for point in rounded[1...5] {
            XCTAssertEqual(ShapeGeometry.distance(point, Point2D(2, 2)), 2, accuracy: 1e-9)
        }
    }

    func testStraightLineIsUnchanged() {
        let points = [Point2D(0, 0), Point2D(5, 0), Point2D(10, 0)]
        XCTAssertEqual(ShapeGeometry.filleted(points, radius: 3), points)
    }

    func testArcsShrinkToFitShortSegments() throws {
        let plan = try BendCalculator.offset(depth: 1, angle: 60)
        let rounded = ShapeGeometry.filleted(plan.shape, radius: 9.625)
        let box = try XCTUnwrap(ShapeGeometry.bounds(rounded))
        XCTAssertEqual(box.minY, 0, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(box.maxY, 1 + 1e-9)
        XCTAssertGreaterThan(box.maxY, 0.5)
        XCTAssertNil(ShapeGeometry.bounds([]))
    }
}
