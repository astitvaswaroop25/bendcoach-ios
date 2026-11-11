import Foundation

/// What the distance you measured for an offset runs to.
public enum OffsetMeasure: String, Codable, CaseIterable, Sendable, Identifiable {
    /// To the obstruction: the offset has to be finished by then, so shrink is added.
    case toObstruction
    /// To where the first bend should start: shrink doesn't matter.
    case toOffsetStart

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .toObstruction: return "Obstruction"
        case .toOffsetStart: return "First bend"
        }
    }
}

/// The two common 3-point saddles.
public enum SaddleStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case fortyFive
    case sixty

    public var id: String { rawValue }

    public var centerAngle: Double { self == .fortyFive ? 45 : 60 }
    public var outerAngle: Double { self == .fortyFive ? 22.5 : 30 }
    /// Center-to-outer-mark distance per inch of obstruction, from the bender saddle charts.
    public var spacingMultiplier: Double { self == .fortyFive ? 2.5 : 2.0 }
    /// How far the center mark moves ahead per inch of obstruction.
    public var shrinkPerInch: Double { self == .fortyFive ? 3.0 / 16 : 1.0 / 4 }

    public var displayName: String {
        "\(AngleFormat.string(centerAngle)) / \(AngleFormat.string(outerAngle))"
    }
}

/// Turns measurements into marks and steps. Every function is pure and throws
/// `BendInputError` for measurements it can't use.
public enum BendCalculator {
    static let leadIn = 12.0
    static let tailOut = 12.0

    static func fmt(_ inches: Double) -> String { LengthFormat.standard.string(inches) }

    static func validateOffsetAngle(_ angle: Double) throws {
        guard angle.isFinite, angle >= 5, angle <= 75 else {
            throw BendInputError.angleOutOfRange(angle)
        }
    }

    static func validateDistance(_ distance: Double?) throws {
        if let distance, !(distance >= 0) {
            throw BendInputError.negative("Distance")
        }
    }

    static func offEndWarning(_ mark: Double) -> String {
        "Mark A lands \(fmt(-mark)) past the end of the conduit. Pick a steeper angle or lay out from a longer piece."
    }

    // MARK: - 90° stub-up

    public static func stub90(stubHeight: Double, bender: BenderProfile) throws -> BendPlan {
        guard stubHeight > 0 else { throw BendInputError.notPositive("Stub height") }
        let markA = stubHeight - bender.takeUp
        var warnings: [String] = []
        if markA < 0 {
            warnings.append("This stub is shorter than the bender's \(fmt(bender.takeUp)) take-up. Bend a longer stub and cut it down.")
        }
        let marks = [
            BendMark(label: "A", distance: markA, reference: .conduitEnd, benderMark: .arrow, angle: 90)
        ]
        let steps = [
            BendStep(number: 1, markLabel: "A", benderMark: .arrow, angle: 90,
                     instruction: "Line up mark A with the arrow. Keep heavy foot pressure on the bender and bend to 90°."),
            BendStep(number: 2,
                     instruction: "Check: the stub should measure \(fmt(stubHeight)) from the end to the back of the bend.")
        ]
        let facts = [
            PlanFact("Take-up", bender.takeUp, .length),
            PlanFact("Mark A from the end", markA, .length)
        ]
        let shape = [Point2D(0, stubHeight), Point2D(0, 0), Point2D(max(stubHeight, leadIn), 0)]
        return BendPlan(kind: .stub90, inputs: [PlanFact("Stub height", stubHeight, .length)],
                        marks: marks, steps: steps, facts: facts, warnings: warnings,
                        shape: shape, benderName: bender.name)
    }

    // MARK: - Offset

    public static func offset(depth: Double, angle: Double, distance: Double? = nil,
                              measuredTo: OffsetMeasure = .toObstruction,
                              mode: MultiplierMode = .exact) throws -> BendPlan {
        try validateOffsetAngle(angle)
        guard depth > 0 else { throw BendInputError.notPositive("Offset depth") }
        try validateDistance(distance)

        let multiplier = BendMath.multiplier(angle, mode: mode)
        let spacing = depth * multiplier
        let shrink = depth * BendMath.shrinkPerInch(angle)

        var warnings: [String] = []
        let marks: [BendMark]
        if let distance {
            let markA: Double
            let markB: Double
            switch measuredTo {
            case .toOffsetStart:
                markA = distance
                markB = distance + spacing
            case .toObstruction:
                markB = distance + shrink
                markA = markB - spacing
            }
            if markA < 0 { warnings.append(offEndWarning(markA)) }
            marks = [
                BendMark(label: "A", distance: markA, reference: .conduitEnd, benderMark: .arrow, angle: angle),
                BendMark(label: "B", distance: markB, reference: .conduitEnd, benderMark: .arrow, angle: angle)
            ]
        } else {
            marks = [
                BendMark(label: "A", distance: 0, reference: .firstMark, benderMark: .arrow, angle: angle),
                BendMark(label: "B", distance: spacing, reference: .firstMark, benderMark: .arrow, angle: angle)
            ]
        }

        let angleText = AngleFormat.string(angle)
        let steps = [
            BendStep(number: 1, markLabel: "A", benderMark: .arrow, angle: angle,
                     instruction: "Line up mark A with the arrow and bend to \(angleText)."),
            BendStep(number: 2, markLabel: "B", benderMark: .arrow, angle: angle, prep: .rotate180,
                     instruction: "Slide the conduit to mark B and rotate it 180°. Line up mark B with the arrow and bend to \(angleText)."),
            BendStep(number: 3,
                     instruction: "Check: the offset should be \(fmt(depth)) deep, with both bends in the same plane.")
        ]

        let facts = [
            PlanFact("Multiplier", multiplier, .multiplier),
            PlanFact("Distance between marks", spacing, .length),
            PlanFact("Shrink", shrink, .length)
        ]
        var inputs = [PlanFact("Offset depth", depth, .length), PlanFact("Angle", angle, .angle)]
        if let distance {
            let label = measuredTo == .toObstruction ? "End to obstruction" : "End to first bend"
            inputs.append(PlanFact(label, distance, .length))
        }

        let run = depth / tan(BendMath.radians(angle))
        let shape = [
            Point2D(0, 0), Point2D(leadIn, 0),
            Point2D(leadIn + run, depth), Point2D(leadIn + run + tailOut, depth)
        ]
        return BendPlan(kind: .offset, inputs: inputs, marks: marks, steps: steps, facts: facts,
                        warnings: warnings, shape: shape)
    }

    // MARK: - 3-point saddle

    public static func threePointSaddle(obstructionHeight: Double, distanceToCenter: Double? = nil,
                                        style: SaddleStyle = .fortyFive) throws -> BendPlan {
        guard obstructionHeight > 0 else { throw BendInputError.notPositive("Obstruction height") }
        try validateDistance(distanceToCenter)

        let spacing = obstructionHeight * style.spacingMultiplier
        let centerShift = obstructionHeight * style.shrinkPerInch
        let center: Double
        let reference: MarkReference
        if let distanceToCenter {
            center = distanceToCenter + centerShift
            reference = .conduitEnd
        } else {
            center = spacing
            reference = .firstMark
        }
        let markA = center - spacing
        let markC = center + spacing

        var warnings: [String] = []
        if reference == .conduitEnd && markA < 0 { warnings.append(offEndWarning(markA)) }

        let marks = [
            BendMark(label: "A", distance: markA, reference: reference, benderMark: .arrow, angle: style.outerAngle),
            BendMark(label: "B", distance: center, reference: reference, benderMark: .centerNotch, angle: style.centerAngle),
            BendMark(label: "C", distance: markC, reference: reference, benderMark: .arrow, angle: style.outerAngle)
        ]
        let centerText = AngleFormat.string(style.centerAngle)
        let outerText = AngleFormat.string(style.outerAngle)
        let steps = [
            BendStep(number: 1, markLabel: "B", benderMark: .centerNotch, angle: style.centerAngle,
                     instruction: "Line up mark B (the center) with the rim notch or teardrop and bend to \(centerText)."),
            BendStep(number: 2, markLabel: "C", benderMark: .arrow, angle: style.outerAngle, prep: .rotate180,
                     instruction: "Rotate the conduit 180° so this bend goes the other way. Line up mark C with the arrow and bend to \(outerText)."),
            BendStep(number: 3, markLabel: "A", benderMark: .arrow, angle: style.outerAngle, prep: .turnEndForEnd,
                     instruction: "Take the conduit out and turn it end for end. Line up mark A with the arrow and bend to \(outerText), the same way as mark C."),
            BendStep(number: 4,
                     instruction: "Check: the saddle should clear \(fmt(obstructionHeight)) with all three bends in one plane.")
        ]

        var facts = [
            PlanFact("Center bend", style.centerAngle, .angle),
            PlanFact("Outer bends", style.outerAngle, .angle),
            PlanFact("Outer marks from center", spacing, .length)
        ]
        if distanceToCenter != nil {
            facts.append(PlanFact("Center mark moved ahead", centerShift, .length))
        }
        facts.append(PlanFact("Total shrink", centerShift * 2, .length))

        var inputs = [
            PlanFact("Obstruction height", obstructionHeight, .length),
            PlanFact("Saddle", text: style.displayName)
        ]
        if let distanceToCenter {
            inputs.append(PlanFact("End to center of obstruction", distanceToCenter, .length))
        }

        let run = obstructionHeight / tan(BendMath.radians(style.outerAngle))
        let shape = [
            Point2D(0, 0), Point2D(leadIn, 0), Point2D(leadIn + run, obstructionHeight),
            Point2D(leadIn + 2 * run, 0), Point2D(leadIn + 2 * run + tailOut, 0)
        ]
        return BendPlan(kind: .threePointSaddle, inputs: inputs, marks: marks, steps: steps, facts: facts,
                        warnings: warnings, shape: shape)
    }

    // MARK: - 4-point saddle

    public static func fourPointSaddle(height: Double, width: Double, distanceToObstruction: Double? = nil,
                                       angle: Double = 30, mode: MultiplierMode = .exact) throws -> BendPlan {
        try validateOffsetAngle(angle)
        guard height > 0 else { throw BendInputError.notPositive("Obstruction height") }
        guard width > 0 else { throw BendInputError.notPositive("Width") }
        try validateDistance(distanceToObstruction)

        let multiplier = BendMath.multiplier(angle, mode: mode)
        let spacing = height * multiplier
        let shrink = height * BendMath.shrinkPerInch(angle)
        let markB: Double
        let reference: MarkReference
        if let distanceToObstruction {
            markB = distanceToObstruction + shrink
            reference = .conduitEnd
        } else {
            markB = spacing
            reference = .firstMark
        }
        let markA = markB - spacing
        let markC = markB + width
        let markD = markC + spacing

        var warnings: [String] = []
        if reference == .conduitEnd && markA < 0 { warnings.append(offEndWarning(markA)) }

        let marks = [
            BendMark(label: "A", distance: markA, reference: reference, benderMark: .arrow, angle: angle),
            BendMark(label: "B", distance: markB, reference: reference, benderMark: .arrow, angle: angle),
            BendMark(label: "C", distance: markC, reference: reference, benderMark: .arrow, angle: angle),
            BendMark(label: "D", distance: markD, reference: reference, benderMark: .arrow, angle: angle)
        ]
        let angleText = AngleFormat.string(angle)
        let steps = [
            BendStep(number: 1, markLabel: "A", benderMark: .arrow, angle: angle,
                     instruction: "Line up mark A with the arrow and bend to \(angleText)."),
            BendStep(number: 2, markLabel: "B", benderMark: .arrow, angle: angle, prep: .rotate180,
                     instruction: "Rotate the conduit 180°. Line up mark B with the arrow and bend to \(angleText)."),
            BendStep(number: 3, markLabel: "C", benderMark: .arrow, angle: angle,
                     instruction: "Don't rotate. Slide to mark C, line it up with the arrow and bend to \(angleText)."),
            BendStep(number: 4, markLabel: "D", benderMark: .arrow, angle: angle, prep: .rotate180,
                     instruction: "Rotate the conduit 180°. Line up mark D with the arrow and bend to \(angleText)."),
            BendStep(number: 5,
                     instruction: "Check: both offsets should be \(fmt(height)) deep with \(fmt(width)) of flat between B and C. Keep the bender facing the same way for all four bends.")
        ]
        let facts = [
            PlanFact("Multiplier", multiplier, .multiplier),
            PlanFact("A to B and C to D", spacing, .length),
            PlanFact("B to C (flat)", width, .length),
            PlanFact("Shrink per offset", shrink, .length),
            PlanFact("Total shrink", shrink * 2, .length)
        ]
        var inputs = [
            PlanFact("Obstruction height", height, .length),
            PlanFact("Width to clear", width, .length),
            PlanFact("Angle", angle, .angle)
        ]
        if let distanceToObstruction {
            inputs.append(PlanFact("End to obstruction", distanceToObstruction, .length))
        }

        let run = height / tan(BendMath.radians(angle))
        let shape = [
            Point2D(0, 0), Point2D(leadIn, 0), Point2D(leadIn + run, height),
            Point2D(leadIn + run + width, height), Point2D(leadIn + 2 * run + width, 0),
            Point2D(leadIn + 2 * run + width + tailOut, 0)
        ]
        return BendPlan(kind: .fourPointSaddle, inputs: inputs, marks: marks, steps: steps, facts: facts,
                        warnings: warnings, shape: shape)
    }

    // MARK: - Back-to-back 90s

    public static func backToBack(firstStubHeight: Double, backToBack: Double,
                                  bender: BenderProfile) throws -> BendPlan {
        guard firstStubHeight > 0 else { throw BendInputError.notPositive("First stub height") }
        guard backToBack > 0 else { throw BendInputError.notPositive("Back-to-back distance") }

        let markA = firstStubHeight - bender.takeUp
        var warnings: [String] = []
        if markA < 0 {
            warnings.append("The first stub is shorter than the bender's \(fmt(bender.takeUp)) take-up. Bend a longer stub and cut it down.")
        }
        let marks = [
            BendMark(label: "A", distance: markA, reference: .conduitEnd, benderMark: .arrow, angle: 90),
            BendMark(label: "B", distance: backToBack, reference: .backOfFirstBend, benderMark: .star, angle: 90)
        ]
        let steps = [
            BendStep(number: 1, markLabel: "A", benderMark: .arrow, angle: 90,
                     instruction: "Line up mark A with the arrow and bend the first 90°."),
            BendStep(number: 2,
                     instruction: "Measure \(fmt(backToBack)) from the back of the first 90° along the conduit and mark B."),
            BendStep(number: 3, markLabel: "B", benderMark: .star, angle: 90,
                     instruction: "Line up mark B with the star (the back-of-90 mark) and bend to 90° so both stubs point the same way."),
            BendStep(number: 4,
                     instruction: "Check: the outsides of the two stubs should be \(fmt(backToBack)) apart.")
        ]
        let facts = [
            PlanFact("Take-up", bender.takeUp, .length),
            PlanFact("Mark A from the end", markA, .length),
            PlanFact("Mark B from back of first 90", backToBack, .length)
        ]
        let inputs = [
            PlanFact("First stub height", firstStubHeight, .length),
            PlanFact("Back-to-back", backToBack, .length)
        ]
        let shape = [
            Point2D(0, firstStubHeight), Point2D(0, 0),
            Point2D(backToBack, 0), Point2D(backToBack, firstStubHeight)
        ]
        return BendPlan(kind: .backToBack, inputs: inputs, marks: marks, steps: steps, facts: facts,
                        warnings: warnings, shape: shape, benderName: bender.name)
    }

    // MARK: - Rolling offset

    public static func rollingOffset(rise: Double, roll: Double, angle: Double, distance: Double? = nil,
                                     measuredTo: OffsetMeasure = .toObstruction,
                                     mode: MultiplierMode = .exact) throws -> BendPlan {
        guard rise >= 0 else { throw BendInputError.negative("Rise") }
        guard roll >= 0 else { throw BendInputError.negative("Roll") }
        let trueOffset = (rise * rise + roll * roll).squareRoot()
        guard trueOffset > 0 else { throw BendInputError.notPositive("Rise or roll") }

        var plan = try offset(depth: trueOffset, angle: angle, distance: distance,
                              measuredTo: measuredTo, mode: mode)
        let rollAngle = BendMath.degrees(atan2(roll, rise))
        let advance = trueOffset / tan(BendMath.radians(angle))
        let angleText = AngleFormat.string(angle)

        plan.kind = .rollingOffset
        var inputs = [
            PlanFact("Rise", rise, .length),
            PlanFact("Roll", roll, .length),
            PlanFact("Angle", angle, .angle)
        ]
        if let distance {
            let label = measuredTo == .toObstruction ? "End to obstruction" : "End to first bend"
            inputs.append(PlanFact(label, distance, .length))
        }
        plan.inputs = inputs
        plan.facts.insert(PlanFact("True offset", trueOffset, .length), at: 0)
        plan.facts.append(PlanFact("Turn from vertical", rollAngle, .angle))
        plan.facts.append(PlanFact("Advance", advance, .length))
        plan.steps = [
            BendStep(number: 1, markLabel: "A", benderMark: .arrow, angle: angle,
                     instruction: "Line up mark A with the arrow and bend to \(angleText)."),
            BendStep(number: 2, markLabel: "B", benderMark: .arrow, angle: angle, prep: .rotate180,
                     instruction: "Slide the conduit to mark B and rotate it 180°. Line up mark B with the arrow and bend to \(angleText)."),
            BendStep(number: 3,
                     instruction: "Check: the offset should be \(fmt(trueOffset)) deep (the true offset), with both bends in the same plane."),
            BendStep(number: 4,
                     instruction: "Before fastening, turn the conduit \(AngleFormat.string(rollAngle)) from vertical toward the roll side. It will then rise \(fmt(rise)) and roll \(fmt(roll)).")
        ]
        return plan
    }
}
