# Putting BendCoach on the App Store

The app side is ready: version 1.0, privacy manifest, no export-compliance questions, a
release workflow that signs and uploads builds, and App Store screenshots. The steps below need
your Apple account. Do them in order. Apple's own waits are noted.

## What only you can do

### 1. Join the Apple Developer Program ($99 a year)
Easiest from an iPhone: install the **Apple Developer** app, sign in with your Apple ID, tap
**Account → Enroll Now**. Or use https://developer.apple.com/programs/enroll/. Enroll as an
individual unless you have a company; your name becomes the seller name on the App Store.
Approval usually takes a day or two.

### 2. Sign the paid apps agreement
In https://appstoreconnect.apple.com go to **Business** and accept the **Paid Apps** agreement,
then add your bank and tax details. Without it, BendCoach Pro can't be sold.

### 3. Register the bundle ID and create the app
1. https://developer.apple.com/account → **Certificates, IDs & Profiles → Identifiers → +** →
   **App IDs → App**. Description `BendCoach`, Bundle ID **Explicit**
   `com.astitvaswaroop.bendcoach`. Leave the capabilities as they are (In-App Purchase is on).
2. App Store Connect → **Apps → + → New App**: platform **iOS**, name
   **BendCoach: Conduit Bending**, primary language **English (U.S.)**, bundle ID
   `com.astitvaswaroop.bendcoach`, SKU `bendcoach-ios`.
   If the name is taken, try **BendCoach – Conduit Bender**.

### 4. Let GitHub upload builds for you
1. App Store Connect → **Users and Access → Integrations → App Store Connect API → Team Keys →
   +**. Name it `GitHub release`, access **Admin**. Download the `.p8` file (Apple only lets you
   download it once) and note the **Key ID** and the **Issuer ID** shown above the list.
2. Your **Team ID** is under https://developer.apple.com/account → **Membership details**.
3. On GitHub, open the repo → **Settings → Secrets and variables → Actions → New repository
   secret**, and add four secrets:

   | Name | Value |
   |---|---|
   | `APPLE_TEAM_ID` | Team ID, 10 characters |
   | `ASC_KEY_ID` | Key ID |
   | `ASC_ISSUER_ID` | Issuer ID |
   | `ASC_KEY_P8` | Open the `.p8` in Notepad and paste all of it, including the BEGIN and END lines |

   Secrets stay hidden even though the repo is public.

### 5. Upload a build
GitHub → **Actions → Release → Run workflow**. It takes about 15 minutes, then Apple processes
the build for 5 to 30 minutes. It appears in App Store Connect under **TestFlight**.

### 6. Try it from TestFlight (recommended)
App Store Connect → **TestFlight → Internal Testing → +**, add yourself, then install the
**TestFlight** app on your iPhone. TestFlight purchases are free test purchases, so you can
buy Pro and use **Restore purchases** to check both work.

### 7. Create the in-app purchase
App Store Connect → BendCoach → **Monetization → In-App Purchases → +**:

| Field | Value |
|---|---|
| Type | Non-Consumable |
| Reference name | BendCoach Pro |
| Product ID | `com.astitvaswaroop.bendcoach.pro` (must match exactly) |
| Price | $7.99, or your choice |
| Display name | BendCoach Pro |
| Description | Saddles, back-to-backs, rolling offsets and more |
| Review screenshot | `iap-review-01-paywall-store.jpg` (shows $7.99; ask Claude to retake it if you pick another price) |

### 8. Fill in the listing and submit
On the **1.0 Prepare for Submission** page:
- **Screenshots:** drag `iphone-*.jpg` into **iPhone 6.9" Display** and `ipad-*.jpg` into
  **iPad 13" Display**. All of them are in `BendCoach-AppStore-screenshots.zip` on the
  [appstore-assets release](https://github.com/astitvaswaroop25/bendcoach-ios/releases/tag/appstore-assets).
- **Text:** copy from [the listing below](#listing-text).
- **Build:** pick the build you uploaded. **In-App Purchases:** add BendCoach Pro.
- **App Review Information:** sign-in not required; paste the review notes below.

Then in the sidebar:
- **App Information:** category **Utilities** (secondary **Productivity**). Age rating: answer
  **None/No** to everything, which gives **4+**.
- **App Privacy:** privacy policy URL below, then **Get Started → No, we do not collect data**.
- **Pricing and Availability:** **Free**, in every country or just the United States to start.

Press **Add for Review**, then **Submit**. Review usually takes one to two days. Once approved,
the app goes live, unless you chose to release it by hand.

## Listing text

**Name** (30 max): BendCoach: Conduit Bending

**Subtitle** (30 max): Offsets, saddles & a level

**Promotional text:** Marks you can read at arm's length, a built-in level that beeps on the
angle, and step-by-step help for every bend.

**Keywords** (100 max):
```
bender,emt,imc,rigid,electrician,electrical,stub up,90,calculator,apprentice,shrink,multiplier,trade
```

**Description:**
```
BendCoach turns your measurements into marks you can read at arm's length, then walks you through each bend with a built-in level.

ENTER THE NUMBERS
Type measurements on a tape-measure keypad, in fractions down to 1/16". Pick your bender and the angle, and BendCoach works out every mark.

SEE EVERY MARK
Each mark gets a letter, its distance, the bend angle, and the bender mark to line it up with: arrow, star or rim notch. A drawing of the stick shows where each mark goes, and the steps tell you when to rotate the conduit or turn it end for end.

BEND WITH THE LEVEL
Guided mode shows one step at a time. Lay your phone on the conduit and the level counts down to the angle, then buzzes and beeps when you're on it.

MATH YOU CAN TRUST
• Shrink and offset multipliers worked out for you, with exact trigonometry or the chart numbers printed on most benders
• Presets for common EMT hand benders, and rigid in an EMT bender
• Calibrate the take-up of your own bender with one test bend
• Formulas checked against bender makers' worked examples

FREE
• 90° stub-ups
• Offsets
• The level
• 1 custom bender and 5 saved bends

BENDCOACH PRO, ONE-TIME PURCHASE
• 3-point and 4-point saddles
• Back-to-back 90s
• Rolling offsets
• Unlimited custom benders and saved bends

No account, no ads, no tracking. Everything stays on your device and works without a signal. Made for iPhone and iPad.

BendCoach is a guide. Check marks against your bender's own markings, and make a test bend when you start with a new bender.
```

**Support URL:** https://github.com/astitvaswaroop25/bendcoach-ios/blob/main/SUPPORT.md

**Privacy policy URL:** https://github.com/astitvaswaroop25/bendcoach-ios/blob/main/PRIVACY.md

**Copyright:** 2026 followed by your name, as it appears on your developer account.

**Review notes:**
```
BendCoach is a conduit-bending calculator for electricians. No account or sign-in is needed.

Free: 90° stub-ups, offsets and the level. BendCoach Pro (non-consumable, com.astitvaswaroop.bendcoach.pro) unlocks 3- and 4-point saddles, back-to-back 90s and rolling offsets. To see the purchase, tap any bend with a lock on the Bend tab, or "Unlock BendCoach Pro". Restore purchases is on that screen and in Settings.

The level uses the motion sensor, so it needs a real device. Tap "Zero here" with the phone lying flat, then tilt it.
```

## Before launch: two things to decide

- **The sideload build.** The public test build on the
  [test-build release](https://github.com/astitvaswaroop25/bendcoach-ios/releases/tag/test-build)
  is a debug build with **Unlock Pro for testing**, so anyone who sideloads it gets Pro free.
  Once TestFlight works for you, stop publishing it.
- **The public repo.** Anyone can read and build the code. Making it private hides it, but the
  privacy and support links above are on GitHub, so move them to a public page first. Private
  repos also get far fewer free macOS minutes for builds.
