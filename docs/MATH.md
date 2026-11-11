# How BendCoach does the math

Everything lives in `Packages/BendKit` and is covered by unit tests. `tools/crosscheck.py` is an
independent Python version of the same formulas, checked against worked examples printed by
bender manufacturers. Both run in CI.

All lengths are inches. The app rounds what it shows to the nearest 1/16" by default
(1/8" or 1/32" in Settings), but keeps full precision underneath.

## Offsets

| Angle | Exact multiplier (1 ÷ sin θ) | Chart multiplier | Shrink per inch of depth |
|---|---|---|---|
| 10° | 5.76 | 6.0 | 1/16" |
| 15° | 3.86 | 3.9 | 1/8" |
| 22½° | 2.61 | 2.6 | 3/16" |
| 30° | 2.00 | 2.0 | 1/4" |
| 45° | 1.41 | 1.4 | 3/8" |
| 60° | 1.15 | 1.2 | 1/2" |

- Distance between marks: `D = depth × multiplier`. Exact trig is the default. Settings can
  switch to the rounded chart multipliers so the app matches what's printed on a bender. At
  60° they differ by about 1/2" for a 10" offset.
- Shrink: `S = depth × shrink-per-inch`, from the chart values above, linearly interpolated
  between them, and scaled by tan(θ/2) past 60°.
- Distance measured **to the obstruction** (the offset must be finished there):
  `B = X + S`, `A = B − D`.
- Distance measured **to the first bend**: `A = X`, `B = X + D`. Shrink doesn't move the marks.
- Why the shrink goes on the far mark: with sharp corners, the second bend lands
  `depth × tan(θ/2)` closer than its mark. The chart's shrink is a little smaller than
  tan(θ/2) because real bends have a radius.
- Steps: bend at A on the arrow; rotate the conduit 180°; bend at B on the arrow.

## 90° stub-ups

`mark = stub height − take-up`, lined up with the arrow, with the stub measured to the back of the bend.

Typical take-ups printed on Klein, Ideal and Gardner Bender benders:

| Bender | Take-up |
|---|---|
| 1/2" EMT | 5" |
| 3/4" EMT, 1/2" rigid | 6" |
| 1" EMT, 3/4" rigid | 8" |
| 1-1/4" EMT, 1" rigid | 11" |

**Calibration.** Mark scrap X from the end, bend a 90° on the arrow, and measure the stub S.
Then `take-up = S − X`.

## Back-to-back 90s

Bend the first 90° as a stub-up. Measure the back-to-back distance from the back of that 90°,
mark it, line the mark up with the **star** (the back-of-90 mark) and bend.

## 3-point saddles

| Saddle | Outer marks from center | Center mark moves ahead |
|---|---|---|
| 45° center, 22½° outers | 2½ × height | 3/16" per inch of height |
| 60° center, 30° outers | 2 × height | 1/4" per inch of height |

- Center mark `B = X + move`, outer marks `A = B − spacing` and `C = B + spacing`. X is measured
  to the center of the obstruction.
- Total shrink of the run is twice the center move. For example, a 2" saddle moves the center
  3/8" and shrinks the run 3/4".
- Steps: center mark on the rim notch or teardrop; outer marks on the arrow, bent the opposite
  way from the center bend.

## 4-point saddles

These are two equal offsets with the obstruction's width between them:
`B = X + S`, `A = B − D`, `C = B + W`, `D₄ = C + D`.
The bends go up, down, down, up, so the conduit is rotated 180° before bends 2 and 4 only.
X is measured to the near edge of the obstruction, and W should include any clearance you want.

## Rolling offsets

`true offset T = √(rise² + roll²)`. Bend T as a normal offset, then turn the conduit
`atan(roll ÷ rise)` from vertical toward the roll side before fastening.
Advance (run used up) is `T ÷ tan θ`.

## Drawings and gain

The finished-shape drawing uses sharp-corner geometry rounded with the bender's centerline
radius. Typical radii for Greenlee SITE-RITE shoes: 1/2" EMT 4-3/16", 3/4" EMT 5-1/8",
1" EMT 6-1/2", 1-1/4" EMT 9-5/8".
Gain for a 90°, with legs measured to the back of the bend, is `2(R + OD/2) − πR/2`.
It's informational only for now.

## Checked against

| Example (source) | Expected | BendCoach |
|---|---|---|
| 3-point saddle, 3" pipe at 48" (Ideal) | 41-1/16", 48-9/16", 56-1/16" | same |
| 3-point saddle, 2" at 15" (Greenlee) | center 15-3/8" | same |
| 45° offset, 10" deep, obstruction at 30" (Greenlee) | far mark 33-3/4", 14" apart | 33-3/4"; 14" in chart mode, 14-1/8" exact |
| 14" stub, 3/4" EMT (Ideal) | mark at 8" | same |
| Offset chart, 2"–10" deep at 22½°–60° (Klein / Ideal) | shrink and spacing | shrink exact on every row; spacing within the chart's 1/4" rounding |

## Known limits

- Hand-bender steps assume the bender faces the same way for every bend in a sequence. If you
  flip the bender around, measure from the other end.
- Offset marks don't use the bender radius yet. A radius-corrected mode could come after field
  testing.
- No springback compensation for rigid, and imperial units only for now.

## Sources

- Ideal conduit bender guide: https://manuals.plus/ideal/conduit-bending-guide-manual
- Greenlee SITE-RITE hand bender instructions (offset, saddle and shrink examples): https://punchout.acklandsgrainger.com/ec/pdf/34F146_1.pdf
- Greenlee offset table: https://www.manualslib.fr/manual/433007/Greenlee-Site-Rite-840A.html?page=6
- Klein conduit bender and angle setter guide: https://www.itm.com/pdfs/cache/www.itm.com/51609/manual/51609-manual.pdf
- Gardner Bender hand bender guide: https://images.toolsid.com/gardner-bender/items/pdf/b-0040-guide.pdf
- Elliott Electric EMT bending instructions (take-ups): https://elliottelectric.com/StaticPages/ElectricalReferences/Guides/EMT_coduit_bending_guide.html
- Greenlee centerline radii: https://ebhorsman.com/amfile/file/download/file/52853/product/63173
- Milwaukee bender instructions (saddle center and total shrink): https://images.toolsid.com/milwaukee/items/pdf/48-22-4071-instructions.pdf
- EMT outside diameters (ANSI C80.3): https://www.wheatland.com/wp-content/uploads/2018/03/EMT-and-Conduit-Brochure.pdf
- Shrink per inch by angle: https://forums.mikeholt.com/goto/post?id=1097618
