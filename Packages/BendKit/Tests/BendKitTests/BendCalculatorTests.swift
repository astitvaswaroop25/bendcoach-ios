import XCTest
@testable import BendKit

/// Expected values come from manufacturer guides where noted, otherwise from
/// tools/crosscheck.py (the Python reference implementation).
final class BendCalculatorTests: XCTestCase {
    let halfInchEMT = BenderPresets.standard

    private func distance(_ plan: BendPlan, _ label: String, file: StaticString = #filePath, line: UInt = #line) -> Double {
        guard let mark = plan.mark(label) else {
            XCTFail("No mark \(label)", file: file, line: line)
            return .nan
        }
        return mark.distance
    }

    private func assertMarks(_ plan: BendPlan, _ expected: [Double], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(plan.marks.count, expected.count, file: file, line: line)
        for (mark, value) in zip(plan.marks, expected) {
            XCTAssertEqual(mark.distance, value, accuracy: 1e-9, "mark \(mark.label)", file: file, line: line)
        }
    }

    // MARK: Stub-ups

    func testStubUp() throws {
        let plan = try BendCalculator.stub90(stubHeight: 11, bender: halfInchEMT)
        XCTAssertEqual(distance(plan, "A"), 6, accuracy: 1e-12)
        XCTAssertEqual(plan.mark("A")?.benderMark, .arrow)
        XCTAssertTrue(plan.warnings.isEmpty)
        XCTAssertEqual(plan.bendSteps.count, 1)
        XCTAssertEqual(plan.benderName, halfInchEMT.name)
    }

    func testIdealStubExample() throws {
        // Ideal guide: 14" stub with a 3/4" EMT bender (6" take-up) → mark at 8".
        let plan = try BendCalculator.stub90(stubHeight: 14, bender: BenderPresets.all[1])
        XCTAssertEqual(distance(plan, "A"), 8, accuracy: 1e-12)
    }

    func testShortStubWarns() throws {
        let plan = try BendCalculator.stub90(stubHeight: 4, bender: halfInchEMT)
        XCTAssertEqual(plan.warnings.count, 1)
        XCTAssertThrowsError(try BendCalculator.stub90(stubHeight: 0, bender: halfInchEMT))
    }

    // MARK: Offsets

    func testOffsetTowardObstruction() throws {
        let plan = try BendCalculator.offset(depth: 6, angle: 30, distance: 24, measuredTo: .toObstruction)
        assertMarks(plan, [13.5, 25.5])
        XCTAssertEqual(plan.steps[1].prep, .rotate180)
        XCTAssertEqual(plan.bendSteps.compactMap { $0.markLabel }, ["A", "B"])
    }

    func testOffsetFromFirstBend() throws {
        let plan = try BendCalculator.offset(depth: 6, angle: 30, distance: 24, measuredTo: .toOffsetStart)
        assertMarks(plan, [24, 36])
    }

    func testGreenleeFortyFiveOffsetExample() throws {
        // Greenlee SITE-RITE guide: 45° x 45°, 10" deep, obstruction 30" away → mark at 33-3/4",
        // with 14" between marks on their rounded chart.
        let exact = try BendCalculator.offset(depth: 10, angle: 45, distance: 30)
        XCTAssertEqual(distance(exact, "B"), 33.75, accuracy: 1e-12)
        XCTAssertEqual(distance(exact, "A"), 19.6079, accuracy: 1e-4)
        let chart = try BendCalculator.offset(depth: 10, angle: 45, distance: 30, mode: .benderChart)
        XCTAssertEqual(distance(chart, "A"), 19.75, accuracy: 1e-9)
    }

    func testOffsetWithoutADistanceIsRelativeToMarkA() throws {
        let plan = try BendCalculator.offset(depth: 4, angle: 22.5)
        XCTAssertEqual(plan.mark("A")?.reference, .firstMark)
        XCTAssertEqual(distance(plan, "A"), 0, accuracy: 1e-12)
        XCTAssertEqual(distance(plan, "B"), 10.4525, accuracy: 1e-4)
    }

    func testOffsetThatRunsOffTheEndWarns() throws {
        let plan = try BendCalculator.offset(depth: 10, angle: 10, distance: 12)
        XCTAssertEqual(plan.warnings.count, 1)
    }

    func testOffsetRejectsBadInput() {
        XCTAssertThrowsError(try BendCalculator.offset(depth: 0, angle: 30)) { error in
            XCTAssertEqual(error as? BendInputError, .notPositive("Offset depth"))
        }
        XCTAssertThrowsError(try BendCalculator.offset(depth: 4, angle: 90)) { error in
            XCTAssertEqual(error as? BendInputError, .angleOutOfRange(90))
        }
        XCTAssertThrowsError(try BendCalculator.offset(depth: 4, angle: 30, distance: -1))
        XCTAssertNotNil(BendInputError.notPositive("Offset depth").errorDescription)
    }

    // MARK: Saddles

    func testIdealThreePointSaddleExample() throws {
        // Ideal guide: 3" O.D. pipe 48" from the last coupling → 41-1/16", 48-9/16", 56-1/16".
        let plan = try BendCalculator.threePointSaddle(obstructionHeight: 3, distanceToCenter: 48)
        assertMarks(plan, [41.0625, 48.5625, 56.0625])
        XCTAssertEqual(plan.mark("B")?.benderMark, .centerNotch)
        XCTAssertEqual(plan.bendSteps.map { $0.angle }, [45, 22.5, 22.5])
        XCTAssertEqual(plan.bendSteps.map { $0.prep }, [.noChange, .rotate180, .turnEndForEnd])
    }

    func testGreenleeThreePointSaddleExample() throws {
        // Greenlee guide: 2" obstruction centered 15" from the end → center mark at 15-3/8".
        let plan = try BendCalculator.threePointSaddle(obstructionHeight: 2, distanceToCenter: 15)
        XCTAssertEqual(distance(plan, "B"), 15.375, accuracy: 1e-12)
        let totalShrink = plan.facts.first { $0.label == "Total shrink" }?.value
        XCTAssertEqual(totalShrink ?? .nan, 0.75, accuracy: 1e-12)
    }

    func testSixtyDegreeSaddle() throws {
        let plan = try BendCalculator.threePointSaddle(obstructionHeight: 4, distanceToCenter: 30, style: .sixty)
        assertMarks(plan, [23, 31, 39])
        XCTAssertEqual(plan.bendSteps.map { $0.angle }, [60, 30, 30])
    }

    func testFourPointSaddle() throws {
        let plan = try BendCalculator.fourPointSaddle(height: 4, width: 12, distanceToObstruction: 36, angle: 30)
        assertMarks(plan, [29, 37, 49, 57])
        XCTAssertEqual(plan.steps.map { $0.prep }, [.noChange, .rotate180, .noChange, .rotate180, .noChange])
        let totalShrink = plan.facts.first { $0.label == "Total shrink" }?.value
        XCTAssertEqual(totalShrink ?? .nan, 2, accuracy: 1e-12)
        XCTAssertThrowsError(try BendCalculator.fourPointSaddle(height: 4, width: 0))
    }

    // MARK: Back-to-back and rolling offsets

    func testBackToBack() throws {
        let plan = try BendCalculator.backToBack(firstStubHeight: 10, backToBack: 30, bender: halfInchEMT)
        XCTAssertEqual(distance(plan, "A"), 5, accuracy: 1e-12)
        XCTAssertEqual(plan.mark("B")?.reference, .backOfFirstBend)
        XCTAssertEqual(plan.mark("B")?.benderMark, .star)
        XCTAssertEqual(distance(plan, "B"), 30, accuracy: 1e-12)
        XCTAssertEqual(plan.bendSteps.count, 2)
    }

    func testRollingOffset() throws {
        let plan = try BendCalculator.rollingOffset(rise: 12, roll: 9, angle: 45)
        XCTAssertEqual(plan.kind, .rollingOffset)
        let trueOffset = plan.facts.first { $0.label == "True offset" }?.value
        XCTAssertEqual(trueOffset ?? .nan, 15, accuracy: 1e-12)
        XCTAssertEqual(distance(plan, "B"), 21.2132, accuracy: 1e-4)
        let turn = plan.facts.first { $0.label == "Turn from vertical" }?.value
        XCTAssertEqual(turn ?? .nan, 36.8699, accuracy: 1e-4)
        XCTAssertEqual(plan.inputs.first?.label, "Rise")
        XCTAssertThrowsError(try BendCalculator.rollingOffset(rise: 0, roll: 0, angle: 30))
        XCTAssertThrowsError(try BendCalculator.rollingOffset(rise: -1, roll: 4, angle: 30))
    }

    // MARK: Plans

    func testEveryKindHasATitleAndProFlag() {
        XCTAssertEqual(BendKind.allCases.filter { !$0.requiresPro }, [.stub90, .offset])
        for kind in BendKind.allCases {
            XCTAssertFalse(kind.title.isEmpty)
            XCTAssertFalse(kind.subtitle.isEmpty)
        }
    }

    func testPlanRoundTripsThroughJSON() throws {
        let plan = try BendCalculator.threePointSaddle(obstructionHeight: 3, distanceToCenter: 48)
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(BendPlan.self, from: data)
        XCTAssertEqual(decoded, plan)
    }

    func testFactFormatting() {
        XCTAssertEqual(PlanFact("Multiplier", 1.4142, .multiplier).formatted(.standard), "× 1.41")
        XCTAssertEqual(PlanFact("Angle", 22.5, .angle).formatted(.standard), "22½°")
        XCTAssertEqual(PlanFact("Mark", 33.75, .length).formatted(.standard), "33-3/4\"")
        XCTAssertEqual(PlanFact("Saddle", text: "45° / 22½°").formatted(.standard), "45° / 22½°")
    }
}
