#!/usr/bin/env python3
"""Reference implementation of BendCoach's bending math.

It does two jobs:
  1. Checks the formulas against worked examples printed in the Klein,
     Ideal and Greenlee hand-bender guides (see docs/MATH.md for sources).
  2. Prints the expected values that are hard-coded in
     Packages/BendKit/Tests/BendKitTests, so the Swift tests and this
     script can't silently drift apart.

Run:  python3 tools/crosscheck.py
Exit code is non-zero if any check fails.
"""
import math
import sys

# Shrink per inch of offset depth, as printed on Klein/Ideal/Greenlee charts.
SHRINK_TABLE = [(0.0, 0.0), (10.0, 1 / 16), (15.0, 1 / 8), (22.5, 3 / 16),
                (30.0, 1 / 4), (45.0, 3 / 8), (60.0, 1 / 2)]
# Rounded multipliers printed on many bender charts (Greenlee / Gardner Bender).
CHART_MULTIPLIERS = {10.0: 6.0, 15.0: 3.9, 22.5: 2.6, 30.0: 2.0, 45.0: 1.4, 60.0: 1.2}
SADDLE = {  # style: (center angle, outer angle, outer-mark multiplier, shrink/in)
    "45": (45.0, 22.5, 2.5, 3 / 16),
    "60": (60.0, 30.0, 2.0, 1 / 4),
}

failures = 0


def check(name, got, want, tol=1 / 64):
    global failures
    ok = abs(got - want) <= tol
    if not ok:
        failures += 1
    print(f"  [{'ok' if ok else 'FAIL'}] {name}: got {got:.4f}, want {want:.4f}")


def multiplier(angle, chart=False):
    if chart and angle in CHART_MULTIPLIERS:
        return CHART_MULTIPLIERS[angle]
    return 1 / math.sin(math.radians(angle))


def shrink_per_inch(angle):
    if angle <= 0:
        return 0.0
    last_angle, last_value = SHRINK_TABLE[-1]
    if angle > last_angle:
        g = lambda deg: math.tan(math.radians(deg) / 2)
        return last_value * g(angle) / g(last_angle)
    for (a0, s0), (a1, s1) in zip(SHRINK_TABLE, SHRINK_TABLE[1:]):
        if angle <= a1 + 1e-9:
            return s0 + (angle - a0) / (a1 - a0) * (s1 - s0)
    return last_value


def fmt(inches, den=16):
    units = round(abs(inches) * den)
    whole, num = divmod(units, den)
    g = math.gcd(num, den) if num else 1
    sign = "-" if inches < 0 and units else ""
    if num == 0:
        return f'{sign}{whole}"'
    return f'{sign}{whole}-{num // g}/{den // g}"' if whole else f'{sign}{num // g}/{den // g}"'


def stub90(stub, take_up):
    return stub - take_up


def offset(depth, angle, distance=None, to="obstruction", chart=False):
    spacing = depth * multiplier(angle, chart)
    shrink = depth * shrink_per_inch(angle)
    if distance is None:
        return dict(A=0.0, B=spacing, spacing=spacing, shrink=shrink)
    if to == "start":
        a = distance
        b = a + spacing
    else:
        b = distance + shrink
        a = b - spacing
    return dict(A=a, B=b, spacing=spacing, shrink=shrink)


def three_point_saddle(height, distance=None, style="45"):
    _, _, k, s = SADDLE[style]
    spacing = height * k
    shrink = height * s
    b = (distance + shrink) if distance is not None else spacing
    return dict(A=b - spacing, B=b, C=b + spacing, spacing=spacing, shrink=shrink,
                total_shrink=2 * shrink)


def four_point_saddle(height, width, distance=None, angle=30.0, chart=False):
    spacing = height * multiplier(angle, chart)
    shrink = height * shrink_per_inch(angle)
    b = (distance + shrink) if distance is not None else spacing
    a = b - spacing
    c = b + width
    d = c + spacing
    return dict(A=a, B=b, C=c, D=d, spacing=spacing, shrink=shrink, total_shrink=2 * shrink)


def rolling_offset(rise, roll, angle, distance=None, to="obstruction"):
    true_offset = math.hypot(rise, roll)
    plan = offset(true_offset, angle, distance, to)
    plan["true"] = true_offset
    plan["roll_angle"] = math.degrees(math.atan2(roll, rise))
    plan["advance"] = true_offset / math.tan(math.radians(angle))
    return plan


def gain90(radius, od):
    return 2 * (radius + od / 2) - math.pi / 2 * radius


def main():
    print("Manufacturer examples")
    # Ideal bender guide: 3" pipe, 48" from the last coupling, 45/22.5 saddle.
    s = three_point_saddle(3, 48)
    check("Ideal saddle center (48-9/16)", s["B"], 48 + 9 / 16)
    check("Ideal saddle outer A (41-1/16)", s["A"], 41 + 1 / 16)
    check("Ideal saddle outer C (56-1/16)", s["C"], 56 + 1 / 16)
    # Greenlee SITE-RITE guide: 2" obstruction centered 15" from the end.
    check("Greenlee saddle center (15-3/8)", three_point_saddle(2, 15)["B"], 15 + 3 / 8)
    # Greenlee: 45 x 45 offset, 10" deep, working toward an obstruction 30" away.
    o = offset(10, 45, 30, "obstruction")
    check("Greenlee 45° offset far mark (33-3/4)", o["B"], 33.75)
    check("Greenlee 45° offset spacing with chart 1.4 (14)",
          offset(10, 45, chart=True)["spacing"], 14.0)
    # Stub-ups: 1/2" EMT 11" stub -> mark at 6"; Ideal 3/4" EMT 14" stub -> 8".
    check("1/2\" EMT 11\" stub mark", stub90(11, 5), 6)
    check("3/4\" EMT 14\" stub mark", stub90(14, 6), 8)

    print("Klein/Ideal offset table (exact trig vs printed, tolerance 1/4\")")
    table = {  # depth: {angle: (spacing, shrink)}
        2: {22.5: (5.25, 3 / 8)},
        3: {22.5: (7.75, 9 / 16), 30: (6, 3 / 4)},
        4: {22.5: (10.5, 3 / 4), 30: (8, 1)},
        5: {22.5: (13, 15 / 16), 30: (10, 1.25), 45: (7, 1 + 7 / 8)},
        6: {22.5: (15.5, 1 + 1 / 8), 30: (12, 1.5), 45: (8.5, 2.25), 60: (7.25, 3)},
        8: {22.5: (20.75, 1.5), 30: (16, 2), 45: (11.25, 3), 60: (9 + 5 / 8, 4)},
        10: {22.5: (26, 1 + 7 / 8), 30: (20, 2.5), 45: (14, 3.75), 60: (12, 5)},
    }
    for depth, row in table.items():
        for angle, (spacing, shrink) in row.items():
            o = offset(depth, angle)
            check(f"{depth}\" @ {angle}° shrink", o["shrink"], shrink, tol=1 / 64)
            # 60° charts use the rounded 1.2 multiplier; compare those in chart mode.
            chart = angle == 60
            o = offset(depth, angle, chart=chart)
            check(f"{depth}\" @ {angle}° spacing{' (chart)' if chart else ''}",
                  o["spacing"], spacing, tol=0.25)

    print("Values used by the Swift tests")
    o = offset(6, 30, 24, "obstruction")
    print("  offset 6@30 to obstruction 24:", {k: fmt(v) for k, v in o.items()})
    o = offset(6, 30, 24, "start")
    print("  offset 6@30 from start 24:", {k: fmt(v) for k, v in o.items()})
    o = offset(10, 45, 30, "obstruction")
    print("  offset 10@45 to obstruction 30:", {k: f"{v:.4f}" for k, v in o.items()},
          "A rounds to", fmt(o["A"]))
    f = four_point_saddle(4, 12, 36, 30)
    print("  4-pt 4x12 @30 at 36:", {k: fmt(v) for k, v in f.items()})
    r = rolling_offset(12, 9, 45)
    print("  rolling 12 rise 9 roll @45:", {k: f"{v:.4f}" for k, v in r.items()})
    print("  shrink/in 37.5° (interpolated):", shrink_per_inch(37.5))
    print("  shrink/in 70° (extrapolated):", round(shrink_per_inch(70), 6))
    print("  gain 1/2\" EMT (R 4-3/16, OD .706):", round(gain90(4.1875, 0.706), 4))
    print("  csc 10/15/22.5/30/45/60:", [round(multiplier(a), 4) for a in (10, 15, 22.5, 30, 45, 60)])

    print()
    print("All checks passed." if failures == 0 else f"{failures} check(s) FAILED.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
