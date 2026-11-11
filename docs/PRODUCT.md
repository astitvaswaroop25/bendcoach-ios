# BendCoach product plan

## One line

The conduit-bending app that coaches you through each pull: numbered marks on a drawing of
the stick, then a built-in level that beeps when each bend hits its angle.

## Who it's for

1. **Apprentices (years 1–3).** They're learning to bend, and a new group arrives every year.
   They search the App Store for "conduit bending" and want to understand the bend, not just
   get a number.
2. **Journeymen doing daily EMT work.** They want speed and big readable numbers, and they
   don't want to mess with fractions with gloves on.

## Why it can win in a crowded category

See `RESEARCH.md`. The leaders, QuickBend and Conduit Bender Elite, have thousands of ratings
and more bend types. BendCoach won't win on bend count. It competes on:

- **Clarity at the bender.** One step at a time, with the mark letter, distance, bender mark and
  rotation shown big. A Conduit Bender Elite reviewer complained about guessing in their diagrams.
- **The level is included.** Conduit Bender Elite charges $1.99 extra for theirs.
- **Trust.** Formulas are documented with sources, there's a "bender chart" multiplier mode so
  the numbers match the chart printed on your tool, and take-up can be calibrated from one bend.

## Pricing

- Free: 90° stub-ups and offsets (the most common bends), the level, 1 custom bender and
  5 saved bends.
- Pro: **$7.99 one-time** (placeholder) for saddles, back-to-backs, rolling offsets, unlimited
  benders and unlimited saves.

## What's built (v0.1)

- Six calculators: stub-up, offset, 3-point saddle (45/22½ and 60/30), 4-point saddle,
  back-to-back, rolling offset.
- Numbered stick layout, finished-shape drawing with the bender radius, and numbered steps
  with rotate and turn-around cues.
- Guided bend mode with a CoreMotion level: zero on the straight part, haptic and beep on
  target, and an over-bend warning.
- Bender presets (1/2"–1-1/4" EMT, 1/2"–1" rigid) and take-up calibration.
- Tape keypad, 1/8, 1/16 and 1/32 rounding, optional feet-and-inches display.
- Saved bends (SwiftData), share as text, StoreKit 2 one-time unlock with restore.

## Validate before launch (about 1–2 weeks)

1. **Field test.** Give a TestFlight build to 3–5 electricians or apprentices and have them bend
   every calculator on scrap. Log the mark, the result and the error. Check especially 60°
   offsets (exact vs chart multiplier) and 4-point saddles.
2. **Level test.** Compare the phone readout with the bender's degree marks and a
   magnetic protractor at 10°, 22½°, 30°, 45° and 90°.
3. **Listen for gaps.** Read the 1–3 star reviews of QuickBend, Conduit Bender Elite and iBend
   Pipe, and ask in r/electricians what's annoying about bending apps.

## Launch

- App Store name: "BendCoach: Conduit Bending". Keywords: conduit, bending, offset, saddle,
  EMT, electrician, bender, stub, level.
- Screenshots should lead with the guided step and level, not the calculator form.
- Post in apprentice communities (r/electricians, IBEW apprentice groups, trade-school
  instructors) with a free promo code for instructors.

## Roadmap ideas (after field feedback)

- Kicks and kick-90s, segmented 90s, and parallel/concentric offsets (QuickBend has these).
- Radius-corrected offset marks using the calibrated bender, if the field test shows it matters.
- Rigid conduit with springback, plus mechanical and hydraulic benders, for industrial users
  (iBend Pipe users ask for this).
- Apple Watch level, metric units, and multiple bends on one stick.
