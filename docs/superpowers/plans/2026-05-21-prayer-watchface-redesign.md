# Prayer Times Multi-Face Watch Face — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the watch face UI layer as four switchable faces (Twilight Horizon, Solar Dial, Crescent Month, Gradient Sky Arc) selected by a phone setting, default Twilight Horizon.

**Architecture:** Keep the audited data layer (`PrayerCalculator`, `HijriCalendar`, prayer caching). Replace the UI layer with a slim dispatcher (`GarminPrayerTimesView`) that picks one of four isolated face classes. Faces share a stateless geometry/drawing toolkit (`FaceKit`), a palette module (`Theme`), and a lunar-phase module (`MoonPhase`). `PrayerState` is extended to feed the faces.

**Tech Stack:** Monkey C, Connect IQ SDK 8.4.0, target watch face on AMOLED Garmin devices (Epix Pro 2 / Venu series, 390–454px round).

---

## Conventions used throughout this plan

**SDK paths (macOS):**
- SDK: `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc`
- Developer key: `~/Library/Application Support/Garmin/ConnectIQ/developer_key`

**Build / test / run** are wrapped in `scripts/dev.sh` (created in Task 1). After Task 1, use:
- `./scripts/dev.sh build` — compile for the simulator
- `./scripts/dev.sh test` — compile a unit-test build and run it
- `./scripts/dev.sh sim` — load the built app into the running simulator
- `./scripts/dev.sh package` — build the `.iq` store package

**The simulator must be open.** It was launched earlier this session. If not running:
`"$SDK/bin/connectiq" &`

**Testing approach.** Monkey C unit tests (`(:test)` functions, run via `dev.sh test`)
cover pure logic only — geometry math, lunar phase, prayer status. Rendering
(the four faces, the dispatcher) cannot be unit-tested; each rendering task ends
with a build-and-observe step in the simulator. This split is intentional.

**Angle convention** for all face geometry: `0° = top of screen, increasing clockwise`.
`FaceKit` is the single place that converts to Garmin's native `drawArc` convention.

---

## File Structure

```
source/
├── GarminPrayerTimesApp.mc    UNCHANGED — App.onSettingsChanged already redraws
├── GarminPrayerTimesView.mc   REWRITE  — slim face dispatcher
├── PrayerCalculator.mc        UNCHANGED
├── HijriCalendar.mc           UNCHANGED — toHijri() already public
├── PrayerState.mc             MODIFY   — add sunrise/sunset/dayFraction/status/moon
├── Theme.mc                   CREATE   — palette + accent
├── FaceKit.mc                 CREATE   — geometry + drawing helpers (shared)
├── MoonPhase.mc               CREATE   — lunar phase from Hijri day
├── Tests.mc                   CREATE   — (:test) unit tests
└── faces/
    ├── HorizonFace.mc         CREATE   — default / focus
    ├── SolarDialFace.mc       CREATE
    ├── CrescentFace.mc        CREATE
    └── GradientArcFace.mc     CREATE
resources/
├── properties.xml             MODIFY   — add faceStyle
├── settings.xml               MODIFY   — add face picker
└── strings.xml                MODIFY   — add label
scripts/dev.sh                 CREATE   — build/test/sim/package wrapper
DEPLOY.md                      CREATE   — store upload steps
```

Connect IQ compiles `source/` recursively, so `source/faces/` needs no jungle change.

---

## Task 1: Dev scripts and deploy doc

**Files:**
- Create: `scripts/dev.sh`
- Create: `DEPLOY.md`

- [ ] **Step 1: Create `scripts/dev.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
KEY="$HOME/Library/Application Support/Garmin/ConnectIQ/developer_key"
DEVICE="${DEVICE:-epix2pro42mm}"
cd "$(dirname "$0")/.."

case "${1:-}" in
  build)
    "$SDK/bin/monkeyc" -o bin/GarminPrayerTimes.prg -f monkey.jungle \
      -y "$KEY" -d "$DEVICE" -l 0
    echo "built bin/GarminPrayerTimes.prg for $DEVICE"
    ;;
  test)
    "$SDK/bin/monkeyc" -o bin/GarminPrayerTimesTest.prg -f monkey.jungle \
      -y "$KEY" -d "$DEVICE" -l 0 --unit-test
    "$SDK/bin/monkeydo" bin/GarminPrayerTimesTest.prg "$DEVICE" -t
    ;;
  sim)
    "$SDK/bin/monkeydo" bin/GarminPrayerTimes.prg "$DEVICE"
    ;;
  package)
    java -jar "$SDK/bin/monkeybrains.jar" -o bin/GarminPrayerTimes.iq \
      -f monkey.jungle -y "$KEY" -e -r
    echo "built bin/GarminPrayerTimes.iq for store upload"
    ;;
  *)
    echo "usage: dev.sh {build|test|sim|package}   (override device with DEVICE=...)"
    exit 1
    ;;
esac
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/dev.sh`

- [ ] **Step 3: Create `DEPLOY.md`**

```markdown
# Deploy — Connect IQ Store

The store package is a `.iq` file (the `.prg` is only for simulator / sideload).

## Build the package

    ./scripts/dev.sh package

This runs `monkeybrains.jar` with `-e` (package) and `-r` (release / strip debug),
signed with the developer key.

## Upload

Upload `bin/GarminPrayerTimes.iq` manually to the Connect IQ Store developer
dashboard. There is no CI/CD.

## Critical: signing key

Every version MUST be signed with the original developer key at
`~/Library/Application Support/Garmin/ConnectIQ/developer_key`.
A different keypair fails the store signature check.
```

- [ ] **Step 4: Verify the build still works**

Run: `./scripts/dev.sh build`
Expected: `BUILD SUCCESSFUL` and `built bin/GarminPrayerTimes.prg for epix2pro42mm`

- [ ] **Step 5: Commit**

```bash
git add scripts/dev.sh DEPLOY.md
git commit -m "Add dev script and deploy doc"
```

---

## Task 2: Add the faceStyle setting

**Files:**
- Modify: `resources/properties.xml`
- Modify: `resources/settings.xml`
- Modify: `resources/strings.xml`

- [ ] **Step 1: Add the property**

In `resources/properties.xml`, add this line inside `<properties>` (after the
`asrMethod` line):

```xml
    <property id="faceStyle" type="number">0</property>
```

- [ ] **Step 2: Add the strings**

In `resources/strings.xml`, add inside `<strings>`:

```xml
    <string id="faceStyleLabel">Face Style</string>
```

- [ ] **Step 3: Add the settings picker**

In `resources/settings.xml`, add as the FIRST `<setting>` inside `<settings>`:

```xml
    <setting propertyKey="@Properties.faceStyle"
             title="@Strings.faceStyleLabel">
        <settingConfig type="list">
            <listEntry value="0">Twilight Horizon</listEntry>
            <listEntry value="1">Solar Dial</listEntry>
            <listEntry value="2">Crescent Month</listEntry>
            <listEntry value="3">Gradient Sky Arc</listEntry>
        </settingConfig>
    </setting>
```

- [ ] **Step 4: Verify resources compile**

Run: `./scripts/dev.sh build`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 5: Commit**

```bash
git add resources/
git commit -m "Add Face Style setting"
```

---

## Task 3: Theme module

**Files:**
- Create: `source/Theme.mc`

- [ ] **Step 1: Create `source/Theme.mc`**

```monkeyc
import Toybox.Lang;
import Toybox.Application.Properties;

// Shared palette and accent color for all faces.
module Theme {
    // Core
    const BG          = 0x000000;
    const TEXT_BRIGHT = 0xF4F4F4;
    const TEXT_MID    = 0x9A9A9A;
    const TEXT_DIM    = 0x6A6A6A;
    const TRACK       = 0x1C1C1C;

    // Prayer dot states
    const DOT_PASSED   = 0x5A5A5A;
    const DOT_UPCOMING = 0xD2D2D2;

    // Twilight palette (shared by faces)
    const NIGHT = 0x2B2F4D;
    const DAWN  = 0xC97B8E;
    const NOON  = 0xE8C87A;
    const DUSK  = 0xE09A4E;
    const MOON  = 0xCFD4FF;

    const ACCENT_DEFAULT = 0xFFC34A;

    // User accent color, falling back to amber if unset.
    function accent() as Number {
        var v = Properties.getValue("accentColor");
        if (v == null) { return ACCENT_DEFAULT; }
        return v as Number;
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `./scripts/dev.sh build`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 3: Commit**

```bash
git add source/Theme.mc
git commit -m "Add Theme palette module"
```

---

## Task 4: FaceKit geometry math (TDD)

**Files:**
- Create: `source/FaceKit.mc`
- Create: `source/Tests.mc`

- [ ] **Step 1: Write the failing tests**

Create `source/Tests.mc`:

```monkeyc
import Toybox.Lang;
import Toybox.Test;

// ---- FaceKit geometry ----

(:test)
function testPolarYTop(logger as Test.Logger) as Boolean {
    // angle 0 = top → y = cy - r
    return FaceKit.approxEqual(FaceKit.polarY(100.0, 50.0, 0.0), 50.0, 0.01);
}

(:test)
function testPolarYBottom(logger as Test.Logger) as Boolean {
    // angle 180 = bottom → y = cy + r
    return FaceKit.approxEqual(FaceKit.polarY(100.0, 50.0, 180.0), 150.0, 0.01);
}

(:test)
function testPolarXRight(logger as Test.Logger) as Boolean {
    // angle 90 = right → x = cx + r
    return FaceKit.approxEqual(FaceKit.polarX(100.0, 50.0, 90.0), 150.0, 0.01);
}

(:test)
function testPolarXTop(logger as Test.Logger) as Boolean {
    // angle 0 = top → x = cx
    return FaceKit.approxEqual(FaceKit.polarX(100.0, 50.0, 0.0), 100.0, 0.01);
}

(:test)
function testHourToDialNoon(logger as Test.Logger) as Boolean {
    return FaceKit.approxEqual(FaceKit.hourToDialAngle(12.0), 0.0, 0.01);
}

(:test)
function testHourToDialMidnight(logger as Test.Logger) as Boolean {
    return FaceKit.approxEqual(FaceKit.hourToDialAngle(0.0), 180.0, 0.01);
}

(:test)
function testHourToDialEvening(logger as Test.Logger) as Boolean {
    return FaceKit.approxEqual(FaceKit.hourToDialAngle(18.0), 90.0, 0.01);
}

(:test)
function testNormalizeNegative(logger as Test.Logger) as Boolean {
    return FaceKit.approxEqual(FaceKit.normalizeAngle(-90.0), 270.0, 0.01);
}

(:test)
function testNormalizeOver(logger as Test.Logger) as Boolean {
    return FaceKit.approxEqual(FaceKit.normalizeAngle(450.0), 90.0, 0.01);
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/dev.sh test`
Expected: build fails — `FaceKit` is undefined.

- [ ] **Step 3: Create `source/FaceKit.mc` with the geometry functions**

```monkeyc
import Toybox.Lang;
import Toybox.Math;

// Stateless geometry + drawing helpers shared by every face.
// Angle convention: 0 deg = top of screen, increasing clockwise.
module FaceKit {

    const DEG2RAD = 0.0174532925199433;

    function polarX(cx as Float, r as Float, angleDeg as Float) as Float {
        return cx + r * Math.sin(angleDeg * DEG2RAD);
    }

    function polarY(cy as Float, r as Float, angleDeg as Float) as Float {
        return cy - r * Math.cos(angleDeg * DEG2RAD);
    }

    // Clock hour (0-24, fractional) -> 24h dial angle.
    // Noon = 0 deg (top); midnight = 180 deg (bottom).
    function hourToDialAngle(hour as Float) as Float {
        return normalizeAngle(((hour - 12.0) / 24.0) * 360.0);
    }

    function normalizeAngle(deg as Float) as Float {
        var a = deg;
        while (a < 0.0)    { a += 360.0; }
        while (a >= 360.0) { a -= 360.0; }
        return a;
    }

    function approxEqual(a as Float, b as Float, tol as Float) as Boolean {
        var d = a - b;
        if (d < 0.0) { d = -d; }
        return d < tol;
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./scripts/dev.sh test`
Expected: 9 tests run, all PASS.

- [ ] **Step 5: Commit**

```bash
git add source/FaceKit.mc source/Tests.mc
git commit -m "Add FaceKit geometry helpers with tests"
```

---

## Task 5: FaceKit drawing helpers

**Files:**
- Modify: `source/FaceKit.mc`

These are rendering helpers — verified visually later, not unit-tested.

- [ ] **Step 1: Add imports**

At the top of `source/FaceKit.mc`, add to the existing imports:

```monkeyc
import Toybox.Graphics;
import Toybox.System;
```

- [ ] **Step 2: Add the drawing helpers**

Add these functions inside the `module FaceKit` block, after `approxEqual`:

```monkeyc
    // Scale an RGB color down by num/den (for glow halos / dimming).
    function dim(color as Number, num as Number, den as Number) as Number {
        var r = ((color >> 16) & 0xFF) * num / den;
        var g = ((color >> 8) & 0xFF) * num / den;
        var b = (color & 0xFF) * num / den;
        return (r << 16) | (g << 8) | b;
    }

    // Draw an arc in the FaceKit convention (0 deg = top, clockwise).
    // Converts to Garmin's native convention (0 = 3 o'clock, counter-clockwise).
    function drawArcSegment(dc as Graphics.Dc, cx as Float, cy as Float, r as Float,
                            startDeg as Float, endDeg as Float,
                            penWidth as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(penWidth);
        var gStart = 90.0 - startDeg;
        var gEnd   = 90.0 - endDeg;
        dc.drawArc(cx.toNumber(), cy.toNumber(), r.toNumber(),
                   Graphics.ARC_CLOCKWISE, gStart.toNumber(), gEnd.toNumber());
        dc.setPenWidth(1);
    }

    // A filled dot with a soft glow halo.
    function drawGlowDot(dc as Graphics.Dc, x as Float, y as Float,
                         radius as Number, color as Number) as Void {
        var xi = x.toNumber();
        var yi = y.toNumber();
        dc.setColor(dim(color, 1, 4), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xi, yi, (radius * 2.2).toNumber());
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xi, yi, radius);
    }

    // A prayer marker. status: 0 passed, 1 next, 2 upcoming.
    function drawPrayerDot(dc as Graphics.Dc, x as Float, y as Float,
                           status as Number, radius as Number) as Void {
        if (status == 1) {
            drawGlowDot(dc, x, y, radius + 1, Theme.accent());
            return;
        }
        var color = (status == 0) ? Theme.DOT_PASSED : Theme.DOT_UPCOMING;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x.toNumber(), y.toNumber(), radius);
    }

    // A crescent: a lit disc carved by an offset background disc.
    function drawCrescent(dc as Graphics.Dc, cx as Number, cy as Number, r as Number,
                          illum as Float, waxing as Boolean) as Void {
        dc.setColor(Theme.MOON, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        var d = (r * (1.55 - illum * 1.1)).toNumber();
        var sx = waxing ? cx - d : cx + d;
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, cy, r);
    }

    // Current time as HH:MM, horizontally centered at (cx, y).
    function drawClock(dc as Graphics.Dc, cx as Float, y as Float,
                       font as Graphics.FontDefinition, color as Number) as Void {
        var t = System.getClockTime();
        var s = PrayerState.pad2(t.hour) + ":" + PrayerState.pad2(t.min);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx.toNumber(), y.toNumber(), font, s, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // "Asr in 2h 23m" in the accent color, centered at (cx, y).
    function drawNextLine(dc as Graphics.Dc, cx as Float, y as Float,
                          state as PrayerState) as Void {
        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx.toNumber(), y.toNumber(), Graphics.FONT_TINY,
            state.nextPrayerName + " in " + state.countdownString,
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Hijri date, dim, centered at (cx, y).
    function drawHijri(dc as Graphics.Dc, cx as Float, y as Float,
                       state as PrayerState) as Void {
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx.toNumber(), y.toNumber(), Graphics.FONT_XTINY,
            state.hijriDate, Graphics.TEXT_JUSTIFY_CENTER);
    }
```

- [ ] **Step 3: Verify it compiles**

Run: `./scripts/dev.sh build`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 4: Commit**

```bash
git add source/FaceKit.mc
git commit -m "Add FaceKit drawing helpers"
```

---

## Task 6: MoonPhase module (TDD)

**Files:**
- Create: `source/MoonPhase.mc`
- Modify: `source/Tests.mc`

- [ ] **Step 1: Write the failing tests**

Append to `source/Tests.mc`:

```monkeyc
// ---- MoonPhase ----

(:test)
function testMoonNewMoon(logger as Test.Logger) as Boolean {
    // Hijri day 1 -> illumination ~0 (new moon)
    return FaceKit.approxEqual(MoonPhase.illumination(1), 0.0, 0.02);
}

(:test)
function testMoonFull(logger as Test.Logger) as Boolean {
    // Hijri day 15 -> illumination near full
    return MoonPhase.illumination(15) > 0.95;
}

(:test)
function testMoonWaxingEarly(logger as Test.Logger) as Boolean {
    return MoonPhase.isWaxing(5) == true;
}

(:test)
function testMoonWaningLate(logger as Test.Logger) as Boolean {
    return MoonPhase.isWaxing(22) == false;
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/dev.sh test`
Expected: build fails — `MoonPhase` is undefined.

- [ ] **Step 3: Create `source/MoonPhase.mc`**

```monkeyc
import Toybox.Lang;
import Toybox.Math;

// Lunar phase derived from the Hijri day-of-month (1-30).
module MoonPhase {

    const SYNODIC = 29.530588853;
    const TWO_PI  = 6.283185307179586;

    // Illuminated fraction, 0.0 (new) to 1.0 (full).
    function illumination(hijriDay as Number) as Float {
        var f = (1.0 - Math.cos(TWO_PI * (hijriDay - 1) / SYNODIC)) / 2.0;
        if (f < 0.0) { f = 0.0; }
        if (f > 1.0) { f = 1.0; }
        return f.toFloat();
    }

    // True for the first half of the lunar month.
    function isWaxing(hijriDay as Number) as Boolean {
        return hijriDay < 15;
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./scripts/dev.sh test`
Expected: 13 tests run, all PASS.

- [ ] **Step 5: Commit**

```bash
git add source/MoonPhase.mc source/Tests.mc
git commit -m "Add MoonPhase module with tests"
```

---

## Task 7: PrayerState extensions (TDD)

**Files:**
- Modify: `source/PrayerState.mc`
- Modify: `source/Tests.mc`

`PrayerState` gains: status constants, six new fields, two pure static functions,
and wiring in `update()` / `recalculate()`.

- [ ] **Step 1: Write the failing tests**

Append to `source/Tests.mc`:

```monkeyc
// ---- PrayerState pure logic ----

(:test)
function testDayFractionMidday(logger as Test.Logger) as Boolean {
    // sunrise 6, sunset 18, now 12 -> 0.5
    return FaceKit.approxEqual(
        PrayerState.computeDayFraction(12.0, 6.0, 18.0), 0.5, 0.01);
}

(:test)
function testDayFractionClampLow(logger as Test.Logger) as Boolean {
    // before sunrise -> clamped to 0
    return FaceKit.approxEqual(
        PrayerState.computeDayFraction(3.0, 6.0, 18.0), 0.0, 0.01);
}

(:test)
function testStatusMarksNextAndPassed(logger as Test.Logger) as Boolean {
    // times: Fajr 5, Sunrise 6, Dhuhr 12, Asr 16, Maghrib 20, Isha 22
    // now 13.0, next index 3 (Asr)
    var times = [5.0, 6.0, 12.0, 16.0, 20.0, 22.0];
    var s = PrayerState.computeStatus(times, 13.0, 3, false);
    // Fajr/Sunrise/Dhuhr passed (0), Asr next (1), Maghrib/Isha upcoming (2)
    return s[0] == 0 && s[1] == 0 && s[2] == 0
        && s[3] == 1 && s[4] == 2 && s[5] == 2;
}

(:test)
function testStatusAllPassedAfterIsha(logger as Test.Logger) as Boolean {
    var times = [5.0, 6.0, 12.0, 16.0, 20.0, 22.0];
    var s = PrayerState.computeStatus(times, 23.0, -1, true);
    return s[0] == 0 && s[3] == 0 && s[5] == 0;
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/dev.sh test`
Expected: build fails — `computeDayFraction` / `computeStatus` undefined.

- [ ] **Step 3: Add status constants and fields**

In `source/PrayerState.mc`, after the existing `static const ISHA = 5;` line, add:

```monkeyc
    // Prayer status values
    static const STATUS_PASSED   = 0;
    static const STATUS_NEXT     = 1;
    static const STATUS_UPCOMING = 2;
```

After the existing `var progressFraction as Float = 0.0f;` line, add:

```monkeyc
    // Derived data for the faces
    var sunrise as Double = 0.0d;
    var sunset as Double = 0.0d;
    var dayFraction as Float = 0.0f;
    var prayerStatus as Array = [0, 0, 0, 0, 0, 0];
    var moonIllumination as Float = 0.0f;
    var moonWaxing as Boolean = true;
```

- [ ] **Step 4: Add the two pure static functions**

In `source/PrayerState.mc`, add these after the existing `static function pad2`:

```monkeyc
    // Current position between sunrise and sunset, clamped 0.0-1.0.
    static function computeDayFraction(hour as Double, sr as Double, ss as Double) as Float {
        if (ss <= sr) { return 0.0f; }
        var f = (hour - sr) / (ss - sr);
        if (f < 0.0) { f = 0.0; }
        if (f > 1.0) { f = 1.0; }
        return f.toFloat();
    }

    // Per-prayer status array: 0 passed, 1 next, 2 upcoming.
    static function computeStatus(times as Array, hour as Double,
                                  nextIdx as Number, allPassed as Boolean) as Array {
        var s = [0, 0, 0, 0, 0, 0];
        for (var i = 0; i < PRAYER_COUNT; i++) {
            if (allPassed) {
                s[i] = STATUS_PASSED;
            } else if (i == nextIdx) {
                s[i] = STATUS_NEXT;
            } else if (hour >= (times[i] as Double)) {
                s[i] = STATUS_PASSED;
            } else {
                s[i] = STATUS_UPCOMING;
            }
        }
        return s;
    }
```

- [ ] **Step 5: Set sunrise/sunset/moon in `recalculate()`**

In `source/PrayerState.mc`, inside `recalculate()`, immediately after
`todayTimes = PrayerCalculator.calculate(...)` is assigned, add:

```monkeyc
        if (todayTimes != null) {
            sunrise = (todayTimes as Array)[SUNRISE] as Double;
            sunset  = (todayTimes as Array)[MAGHRIB] as Double;
        }
```

- [ ] **Step 6: Set moon phase on date change in `update()`**

In `source/PrayerState.mc`, inside `update()`, find the line
`hijriDate = HijriCalendar.format(year, month, day);` and add directly after it:

```monkeyc
            var hParts = HijriCalendar.toHijri(year, month, day);
            var hDay = hParts[2] as Number;
            moonIllumination = MoonPhase.illumination(hDay);
            moonWaxing = MoonPhase.isWaxing(hDay);
```

- [ ] **Step 7: Set dayFraction and prayerStatus in `update()`**

`updateNextPrayer()` has an early `return` in the all-prayers-passed branch, so
the derived data is set in `update()` after the call instead — this covers both
branches. In `source/PrayerState.mc`, find this block in `update()`:

```monkeyc
        // Update next prayer and countdown
        if (todayTimes != null) {
            updateNextPrayer(now);
        }
```

Replace it with:

```monkeyc
        // Update next prayer, countdown, and derived face data
        if (todayTimes != null) {
            updateNextPrayer(now);
            var hr = (now.hour as Number).toDouble()
                   + (now.min as Number).toDouble() / 60.0;
            dayFraction = computeDayFraction(hr, sunrise, sunset);
            prayerStatus = computeStatus(todayTimes as Array, hr,
                nextPrayerIndex, isNextTomorrowFajr);
        }
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `./scripts/dev.sh test`
Expected: 17 tests run, all PASS.

- [ ] **Step 9: Commit**

```bash
git add source/PrayerState.mc source/Tests.mc
git commit -m "Extend PrayerState with face-rendering data"
```

---

## Task 8: View dispatcher and four face stubs

**Files:**
- Modify (rewrite): `source/GarminPrayerTimesView.mc`
- Create: `source/faces/HorizonFace.mc`
- Create: `source/faces/SolarDialFace.mc`
- Create: `source/faces/CrescentFace.mc`
- Create: `source/faces/GradientArcFace.mc`

- [ ] **Step 1: Create the four face stubs**

Create `source/faces/HorizonFace.mc`:

```monkeyc
import Toybox.Graphics;
import Toybox.Lang;

class HorizonFace {
    function initialize() {}

    function draw(dc as Graphics.Dc, state as PrayerState) as Void {
        var cx = dc.getWidth() / 2;
        dc.setColor(Theme.TEXT_BRIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, dc.getHeight() / 2, Graphics.FONT_SMALL,
            "Horizon", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawLowPower(dc as Graphics.Dc, state as PrayerState) as Void {
        draw(dc, state);
    }
}
```

Create `source/faces/SolarDialFace.mc` — identical but class `SolarDialFace`
and the text `"Solar Dial"`.

Create `source/faces/CrescentFace.mc` — identical but class `CrescentFace`
and the text `"Crescent"`.

Create `source/faces/GradientArcFace.mc` — identical but class `GradientArcFace`
and the text `"Gradient"`.

- [ ] **Step 2: Rewrite `source/GarminPrayerTimesView.mc` as the dispatcher**

Replace the ENTIRE contents of `source/GarminPrayerTimesView.mc` with:

```monkeyc
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Application;
import Toybox.Application.Properties;

// Slim dispatcher: picks one of four faces by the faceStyle setting.
class GarminPrayerTimesView extends WatchUi.WatchFace {

    hidden var face;
    hidden var faceStyle as Number = -1;
    hidden var isLowPower as Boolean = false;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    // Re-pick the face when the setting changes (or on first draw).
    hidden function ensureFace() as Void {
        var style = Properties.getValue("faceStyle");
        if (style == null) { style = 0; }
        if (face != null && (style as Number) == faceStyle) { return; }
        faceStyle = style as Number;
        if (faceStyle == 1) {
            face = new SolarDialFace();
        } else if (faceStyle == 2) {
            face = new CrescentFace();
        } else if (faceStyle == 3) {
            face = new GradientArcFace();
        } else {
            face = new HorizonFace();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        ensureFace();
        dc.setColor(Theme.TEXT_BRIGHT, Theme.BG);
        dc.clear();

        var app = Application.getApp() as GarminPrayerTimesApp;
        var state = app.prayerState;
        if (state == null) {
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2,
                Graphics.FONT_SMALL, "Loading...", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        state.update();
        if (isLowPower) {
            face.drawLowPower(dc, state);
        } else {
            face.draw(dc, state);
        }
    }

    function onEnterSleep() as Void {
        isLowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        isLowPower = false;
        WatchUi.requestUpdate();
    }
}
```

- [ ] **Step 3: Build and load in the simulator**

Run: `./scripts/dev.sh build && ./scripts/dev.sh sim`
Expected: the simulator shows `Horizon` centered on a black screen.

- [ ] **Step 4: Verify face switching**

In the simulator menu, open the app settings editor
(`Settings` → `Edit Persistent Storage` / the Connect IQ settings panel),
set `Face Style` to `Solar Dial`, apply.
Expected: the screen now shows `Solar Dial`. Repeat for `Crescent` and `Gradient`.

- [ ] **Step 5: Commit**

```bash
git add source/GarminPrayerTimesView.mc source/faces/
git commit -m "Add face dispatcher and stub faces"
```

---

## Task 9: Twilight Horizon face (default / focus)

**Files:**
- Modify (replace): `source/faces/HorizonFace.mc`

Rendering task — verified in the simulator. Constants near the top are tunable;
adjust them in Step 3 if spacing looks off.

- [ ] **Step 1: Replace `source/faces/HorizonFace.mc` with the full face**

```monkeyc
import Toybox.Graphics;
import Toybox.Lang;

// Default face. A horizon line: the sun rides a sky dome for the four daytime
// prayers; Isha and Fajr sit below in the night with a crescent moon.
class HorizonFace {

    // Tunable layout fractions (of screen width/height)
    const HORIZON_Y   = 0.56;
    const DOME_R      = 0.40;
    const NIGHT_R     = 0.36;
    const ISHA_ANGLE  = 138.0;
    const FAJR_ANGLE  = 222.0;

    function initialize() {}

    function draw(dc as Graphics.Dc, state as PrayerState) as Void {
        var times = state.todayTimes;
        if (times == null) { return; }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var horizonY = h * HORIZON_Y;
        var domeR = w * DOME_R;
        var nightR = w * NIGHT_R;

        // sky dome (270 deg left -> 360 top -> 450/90 right)
        FaceKit.drawArcSegment(dc, cx, horizonY, domeR, 270.0, 450.0, 3, Theme.NIGHT);

        // horizon line
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine((cx - domeR).toNumber(), horizonY.toNumber(),
                    (cx + domeR).toNumber(), horizonY.toNumber());
        dc.setPenWidth(1);

        // daytime prayers on the dome
        var sr = state.sunrise;
        var span = state.sunset - sr;
        if (span <= 0.0) { span = 1.0d; }
        var dayIdx = [PrayerState.SUNRISE, PrayerState.DHUHR,
                      PrayerState.ASR, PrayerState.MAGHRIB];
        for (var k = 0; k < 4; k++) {
            var i = dayIdx[k];
            var f = (((times[i] as Double) - sr) / span).toFloat();
            if (f < 0.0) { f = 0.0; }
            if (f > 1.0) { f = 1.0; }
            var ang = 270.0 + f * 180.0;
            FaceKit.drawPrayerDot(dc,
                FaceKit.polarX(cx, domeR, ang),
                FaceKit.polarY(horizonY, domeR, ang),
                state.prayerStatus[i], 5);
        }

        // sun on the dome at the current day fraction
        var sunAng = 270.0 + state.dayFraction * 180.0;
        FaceKit.drawGlowDot(dc,
            FaceKit.polarX(cx, domeR, sunAng),
            FaceKit.polarY(horizonY, domeR, sunAng),
            6, Theme.NOON);

        // night prayers below the horizon
        FaceKit.drawPrayerDot(dc,
            FaceKit.polarX(cx, nightR, ISHA_ANGLE),
            FaceKit.polarY(horizonY, nightR, ISHA_ANGLE),
            state.prayerStatus[PrayerState.ISHA], 5);
        FaceKit.drawPrayerDot(dc,
            FaceKit.polarX(cx, nightR, FAJR_ANGLE),
            FaceKit.polarY(horizonY, nightR, FAJR_ANGLE),
            state.prayerStatus[PrayerState.FAJR], 5);

        // crescent moon in the night zone
        FaceKit.drawCrescent(dc,
            (cx - w * 0.20).toNumber(), (horizonY + h * 0.22).toNumber(),
            (w * 0.05).toNumber(), state.moonIllumination, state.moonWaxing);

        // center stack: clock, next prayer, hijri
        FaceKit.drawClock(dc, cx, horizonY + h * 0.04,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_BRIGHT);
        FaceKit.drawNextLine(dc, cx, horizonY + h * 0.21, state);
        FaceKit.drawHijri(dc, cx, horizonY + h * 0.29, state);
    }

    function drawLowPower(dc as Graphics.Dc, state as PrayerState) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var horizonY = h * HORIZON_Y;
        var domeR = w * DOME_R;

        // horizon line + dimmed sun only
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine((cx - domeR).toNumber(), horizonY.toNumber(),
                    (cx + domeR).toNumber(), horizonY.toNumber());
        dc.setPenWidth(1);
        var sunAng = 270.0 + state.dayFraction * 180.0;
        dc.setColor(FaceKit.dim(Theme.NOON, 1, 2), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(FaceKit.polarX(cx, domeR, sunAng).toNumber(),
                      FaceKit.polarY(horizonY, domeR, sunAng).toNumber(), 5);

        FaceKit.drawClock(dc, cx, horizonY + h * 0.04,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_MID);
        FaceKit.drawNextLine(dc, cx, horizonY + h * 0.21, state);
    }
}
```

- [ ] **Step 2: Build and view**

Run: `./scripts/dev.sh build && ./scripts/dev.sh sim`
Expected: the dome arc, horizon line, four day-prayer dots, the glowing sun, the
two night dots, the crescent, and the centered clock/next/hijri all render with
`Face Style` set to `Twilight Horizon`.

- [ ] **Step 3: Tune spacing**

If the clock overlaps the horizon line, dots collide with the center text, or the
crescent overlaps the Fajr dot, adjust the `const` fractions at the top of the
class and the `horizonY + h * X` offsets, then rebuild. Repeat until clean.

- [ ] **Step 4: Verify always-on mode**

In the simulator, trigger sleep mode (`Settings` → `Low Power Mode`, or the
power/sleep toggle). Expected: only the horizon line, dimmed sun, clock, and next
prayer show.

- [ ] **Step 5: Commit**

```bash
git add source/faces/HorizonFace.mc
git commit -m "Implement Twilight Horizon face"
```

---

## Task 10: Solar Dial face

**Files:**
- Modify (replace): `source/faces/SolarDialFace.mc`

- [ ] **Step 1: Replace `source/faces/SolarDialFace.mc` with the full face**

```monkeyc
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

// A 24-hour dial: noon at top, midnight at bottom. The ring splits into a lit
// daytime band and a dark night band; prayers sit at their real positions.
class SolarDialFace {

    const RING_R   = 0.43;   // fraction of width
    const DAY_PEN  = 8;
    const ALL_IDX  = [0, 1, 2, 3, 4, 5];

    function initialize() {}

    function draw(dc as Graphics.Dc, state as PrayerState) as Void {
        var times = state.todayTimes;
        if (times == null) { return; }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;
        var r = w * RING_R;

        var sunriseAng = FaceKit.hourToDialAngle(state.sunrise.toFloat());
        var sunsetAng  = FaceKit.hourToDialAngle(state.sunset.toFloat());

        // night band first (full ring), then day band on top
        FaceKit.drawArcSegment(dc, cx, cy, r, 0.0, 359.9, DAY_PEN, Theme.NIGHT);
        FaceKit.drawArcSegment(dc, cx, cy, r, sunriseAng, sunsetAng,
            DAY_PEN, FaceKit.dim(Theme.NOON, 1, 3));

        // prayer markers at their real dial positions
        for (var k = 0; k < 6; k++) {
            var i = ALL_IDX[k];
            var ang = FaceKit.hourToDialAngle((times[i] as Double).toFloat());
            FaceKit.drawPrayerDot(dc,
                FaceKit.polarX(cx, r, ang), FaceKit.polarY(cy, r, ang),
                state.prayerStatus[i], 5);
        }

        // sun bead at the current time
        var now = System.getClockTime();
        var nowHour = now.hour + now.min / 60.0;
        var nowAng = FaceKit.hourToDialAngle(nowHour.toFloat());
        FaceKit.drawGlowDot(dc,
            FaceKit.polarX(cx, r, nowAng), FaceKit.polarY(cy, r, nowAng),
            6, Theme.NOON);

        // center stack
        FaceKit.drawHijri(dc, cx, cy - h * 0.16, state);
        FaceKit.drawClock(dc, cx, cy - h * 0.11,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_BRIGHT);
        FaceKit.drawNextLine(dc, cx, cy + h * 0.04, state);
    }

    function drawLowPower(dc as Graphics.Dc, state as PrayerState) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;
        var r = w * RING_R;
        FaceKit.drawArcSegment(dc, cx, cy, r, 0.0, 359.9, 3,
            FaceKit.dim(Theme.NIGHT, 1, 2));
        FaceKit.drawClock(dc, cx, cy - h * 0.11,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_MID);
        FaceKit.drawNextLine(dc, cx, cy + h * 0.04, state);
    }
}
```

- [ ] **Step 2: Build and view**

Run: `./scripts/dev.sh build && ./scripts/dev.sh sim`
Set `Face Style` to `Solar Dial`.
Expected: a 24h ring with a lighter daytime band and darker night band, six
prayer dots at real positions, a glowing sun bead, centered clock stack.

- [ ] **Step 3: Tune**

Adjust `RING_R`, `DAY_PEN`, and the `cy ± h * X` offsets if the ring clips the
edge or the center text crowds the ring. Rebuild until clean.

- [ ] **Step 4: Verify always-on mode**

Trigger sleep mode. Expected: a dim thin ring + clock + next prayer only.

- [ ] **Step 5: Commit**

```bash
git add source/faces/SolarDialFace.mc
git commit -m "Implement Solar Dial face"
```

---

## Task 11: Crescent Month face

**Files:**
- Modify (replace): `source/faces/CrescentFace.mc`

- [ ] **Step 1: Replace `source/faces/CrescentFace.mc` with the full face**

```monkeyc
import Toybox.Graphics;
import Toybox.Lang;

// The lunar calendar as hero: a crescent matching today's Hijri date, with a
// quiet six-prayer arc along the bottom bezel.
class CrescentFace {

    const ARC_R      = 0.43;
    const ARC_START  = 235.0;   // lower-left
    const ARC_SWEEP  = 250.0;   // clockwise through the bottom
    const ALL_IDX    = [0, 1, 2, 3, 4, 5];

    function initialize() {}

    function draw(dc as Graphics.Dc, state as PrayerState) as Void {
        var times = state.todayTimes;
        if (times == null) { return; }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var r = w * ARC_R;

        // crescent hero, upper third
        FaceKit.drawCrescent(dc, cx.toNumber(), (h * 0.26).toNumber(),
            (w * 0.11).toNumber(), state.moonIllumination, state.moonWaxing);

        // quiet prayer arc along the bottom bezel
        var cy = h / 2.0;
        var endAng = ARC_START + ARC_SWEEP;
        FaceKit.drawArcSegment(dc, cx, cy, r, ARC_START, endAng, 3, Theme.TRACK);
        for (var k = 0; k < 6; k++) {
            var ang = ARC_START + (k / 5.0) * ARC_SWEEP;
            FaceKit.drawPrayerDot(dc,
                FaceKit.polarX(cx, r, ang), FaceKit.polarY(cy, r, ang),
                state.prayerStatus[ALL_IDX[k]], 5);
        }

        // center stack: hijri (emphasized), clock, next prayer
        dc.setColor(Theme.TEXT_MID, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx.toNumber(), (h * 0.43).toNumber(), Graphics.FONT_XTINY,
            state.hijriDate, Graphics.TEXT_JUSTIFY_CENTER);
        FaceKit.drawClock(dc, cx, h * 0.48,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_BRIGHT);
        FaceKit.drawNextLine(dc, cx, h * 0.63, state);
    }

    function drawLowPower(dc as Graphics.Dc, state as PrayerState) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        FaceKit.drawCrescent(dc, cx.toNumber(), (h * 0.26).toNumber(),
            (w * 0.09).toNumber(), state.moonIllumination, state.moonWaxing);
        FaceKit.drawClock(dc, cx, h * 0.48,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_MID);
        FaceKit.drawNextLine(dc, cx, h * 0.63, state);
    }
}
```

- [ ] **Step 2: Build and view**

Run: `./scripts/dev.sh build && ./scripts/dev.sh sim`
Set `Face Style` to `Crescent Month`.
Expected: a crescent at the top, the Hijri date, clock, next prayer, and a quiet
six-dot arc along the bottom.

- [ ] **Step 3: Tune**

Check the crescent is a believable shape (not a full disc, not a sliver). If
wrong, adjust the `1.55 - illum * 1.1` factor in `FaceKit.drawCrescent`. Adjust
the `h * X` offsets if the stack crowds the crescent or the arc.

- [ ] **Step 4: Verify always-on mode**

Trigger sleep mode. Expected: crescent + clock + next prayer only.

- [ ] **Step 5: Commit**

```bash
git add source/faces/CrescentFace.mc
git commit -m "Implement Crescent Month face"
```

---

## Task 12: Gradient Sky Arc face

**Files:**
- Modify (replace): `source/faces/GradientArcFace.mc`

- [ ] **Step 1: Replace `source/faces/GradientArcFace.mc` with the full face**

```monkeyc
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

// A ~280 deg arc painted with the day's light, segmented between prayers:
// night -> dawn -> noon -> dusk -> night. A sun bead rides the arc.
class GradientArcFace {

    const ARC_R     = 0.43;
    const ARC_START = 220.0;   // Fajr, lower-left
    const ARC_SWEEP = 280.0;   // clockwise over the top to Isha
    const SEG_COLORS = [Theme.NIGHT, Theme.DAWN, Theme.NOON, Theme.DUSK, Theme.NIGHT];
    // segment k spans prayer index PAIRS[k][0] -> PAIRS[k][1]
    const PAIRS = [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5]];

    function initialize() {}

    // Fraction along Fajr->Isha for a prayer time.
    hidden function frac(t as Double, fajr as Double, isha as Double) as Float {
        var span = isha - fajr;
        if (span <= 0.0) { span = 1.0d; }
        var f = ((t - fajr) / span).toFloat();
        if (f < 0.0) { f = 0.0; }
        if (f > 1.0) { f = 1.0; }
        return f;
    }

    function draw(dc as Graphics.Dc, state as PrayerState) as Void {
        var times = state.todayTimes;
        if (times == null) { return; }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;
        var r = w * ARC_R;
        var fajr = times[PrayerState.FAJR] as Double;
        var isha = times[PrayerState.ISHA] as Double;

        // track
        FaceKit.drawArcSegment(dc, cx, cy, r, ARC_START, ARC_START + ARC_SWEEP,
            6, Theme.TRACK);

        // colored segments between consecutive prayers
        for (var k = 0; k < 5; k++) {
            var a = times[PAIRS[k][0]] as Double;
            var b = times[PAIRS[k][1]] as Double;
            var sa = ARC_START + frac(a, fajr, isha) * ARC_SWEEP;
            var sb = ARC_START + frac(b, fajr, isha) * ARC_SWEEP;
            FaceKit.drawArcSegment(dc, cx, cy, r, sa, sb, 6, SEG_COLORS[k]);
        }

        // prayer dots
        for (var i = 0; i < 6; i++) {
            var ang = ARC_START + frac(times[i] as Double, fajr, isha) * ARC_SWEEP;
            FaceKit.drawPrayerDot(dc,
                FaceKit.polarX(cx, r, ang), FaceKit.polarY(cy, r, ang),
                state.prayerStatus[i], 4);
        }

        // sun bead at the current time
        var now = System.getClockTime();
        var nowHour = (now.hour + now.min / 60.0).toDouble();
        var nowAng = ARC_START + frac(nowHour, fajr, isha) * ARC_SWEEP;
        FaceKit.drawGlowDot(dc,
            FaceKit.polarX(cx, r, nowAng), FaceKit.polarY(cy, r, nowAng),
            6, Theme.NOON);

        // center stack
        FaceKit.drawHijri(dc, cx, cy - h * 0.16, state);
        FaceKit.drawClock(dc, cx, cy - h * 0.11,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_BRIGHT);
        FaceKit.drawNextLine(dc, cx, cy + h * 0.04, state);
    }

    function drawLowPower(dc as Graphics.Dc, state as PrayerState) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;
        var r = w * ARC_R;
        FaceKit.drawArcSegment(dc, cx, cy, r, ARC_START, ARC_START + ARC_SWEEP,
            3, FaceKit.dim(Theme.DUSK, 1, 2));
        FaceKit.drawClock(dc, cx, cy - h * 0.11,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_MID);
        FaceKit.drawNextLine(dc, cx, cy + h * 0.04, state);
    }
}
```

- [ ] **Step 2: Build and view**

Run: `./scripts/dev.sh build && ./scripts/dev.sh sim`
Set `Face Style` to `Gradient Sky Arc`.
Expected: a ~280° arc with five colored segments, six prayer dots, a glowing sun
bead, and the centered clock stack.

- [ ] **Step 3: Tune**

Adjust `ARC_R` and the `cy ± h * X` offsets if the arc clips or the text crowds.

- [ ] **Step 4: Verify always-on mode**

Trigger sleep mode. Expected: a dim thin arc + clock + next prayer only.

- [ ] **Step 5: Commit**

```bash
git add source/faces/GradientArcFace.mc
git commit -m "Implement Gradient Sky Arc face"
```

---

## Task 13: Cross-device verification and store package

**Files:** none modified — verification only.

- [ ] **Step 1: Run the full test suite**

Run: `./scripts/dev.sh test`
Expected: 17 tests run, all PASS.

- [ ] **Step 2: Verify on the smallest device (390px)**

Run: `DEVICE=epix2pro42mm ./scripts/dev.sh build && DEVICE=epix2pro42mm ./scripts/dev.sh sim`
Cycle `Face Style` through all four values. Expected: each face renders uncramped,
nothing clips the round edge.

- [ ] **Step 3: Verify on a mid device (416px)**

Run: `DEVICE=epix2pro47mm ./scripts/dev.sh build && DEVICE=epix2pro47mm ./scripts/dev.sh sim`
Cycle all four faces. Expected: layouts scale correctly.

- [ ] **Step 4: Verify on the largest device (454px)**

Run: `DEVICE=venu3 ./scripts/dev.sh build && DEVICE=venu3 ./scripts/dev.sh sim`
Cycle all four faces. Expected: layouts scale correctly.

- [ ] **Step 5: Verify behavior**

In the simulator, confirm: the next-prayer dot is amber with a glow; passed
prayers are dim; the countdown text matches `next prayer in Xh Ym`; switching
`Face Style` changes the face without a restart.

- [ ] **Step 6: Build the store package**

Run: `./scripts/dev.sh package`
Expected: `built bin/GarminPrayerTimes.iq for store upload`.

- [ ] **Step 7: Commit**

```bash
git commit --allow-empty -m "Verify all faces across devices"
```

---

## Self-Review (completed by plan author)

- **Spec coverage:** All four faces (Tasks 9–12), dispatcher (Task 8), `FaceKit`
  (4–5), `Theme` (3), `MoonPhase` (6), `PrayerState` extensions (7), `faceStyle`
  setting (2), low-power variants (in each face task), cross-device verification
  (13). `App.mc` and `HijriCalendar.mc` are correctly left unchanged —
  `onSettingsChanged()` already redraws and `toHijri()` is already public.
- **Placeholder scan:** none — all steps contain real code or exact commands.
- **Type consistency:** `draw(dc, state)` / `drawLowPower(dc, state)` signatures
  match across all four faces and the dispatcher; status values `0/1/2` are
  consistent between `PrayerState.computeStatus` and `FaceKit.drawPrayerDot`;
  `FaceKit` function names match every call site.
- **Note for executor:** rendering coordinates are tunable constants — the
  build-and-observe steps exist precisely to nudge them; this is expected, not a
  plan gap.
