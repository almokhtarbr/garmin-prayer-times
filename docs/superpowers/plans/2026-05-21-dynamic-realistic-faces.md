# Dynamic & Realistic Faces — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the four faces more dynamic and realistic — a smooth continuous sky, an approach glow before each prayer, richer celestial rendering, and a live seconds indicator.

**Architecture:** `Sky` becomes a continuous colour function (no more 4 discrete phases). `FaceKit` gains realism primitives and an approach glow. `PrayerState` exposes minutes-to-next. The `View` adds `onPartialUpdate` for live seconds. The four faces adopt the changes.

**Tech Stack:** Monkey C, Connect IQ SDK 8.4.0. Branch: `enhance/dynamic-realistic`.

---

## Conventions

- Build: `./scripts/dev.sh build` → `BUILD SUCCESSFUL`.
- Test: `./scripts/dev.sh test` → exits non-zero even on success; judge by the printed `PASSED (passed=N, failed=0, errors=0)` line. The Connect IQ simulator must be running.
- Commit messages: exactly as given. NO "Co-Authored-By", NO AI/assistant attribution — hard project rule.
- Work from `/Users/almokhtarbekkour/Developer.nosync/mvps/garmin-prayer-times`, branch `enhance/dynamic-realistic` (already checked out).

## File Structure

```
source/
├── Sky.mc          REWRITE — continuous colour function + starAlpha
├── FaceKit.mc      MODIFY  — drawSkyLayer (new), drawStarfield (alpha),
│                             drawSun (corona), drawCrescent (scanline),
│                             drawApproachGlow
├── Tests.mc        MODIFY  — replace phase tests with starAlpha tests
├── PrayerState.mc  MODIFY  — expose minutesToNext
├── GarminPrayerTimesView.mc  MODIFY — onPartialUpdate live seconds
└── faces/
    ├── HorizonFace.mc      MODIFY — continuous-sky return + approach glow
    ├── SolarDialFace.mc    MODIFY — continuous-sky return + approach glow
    ├── CrescentFace.mc     MODIFY — approach glow
    └── GradientArcFace.mc  MODIFY — continuous-sky return + approach glow
```

---

## Task 1: Continuous sky

Replaces `Sky`'s four discrete phases with a smooth continuous colour function.
This task touches `Sky`, `FaceKit.drawSkyLayer`/`drawStarfield`, `Tests.mc`, and
the three sun-drawing faces together so the build stays green.

**Files:** Modify `source/Sky.mc`, `source/FaceKit.mc`, `source/Tests.mc`,
`source/faces/HorizonFace.mc`, `source/faces/SolarDialFace.mc`, `source/faces/GradientArcFace.mc`.

- [ ] **Step 1: Replace the test block.** In `source/Tests.mc`, find the block
that starts with `// ---- sky phase ----` and contains the four
`testSkyPhase*` functions (`testSkyPhaseDay`, `testSkyPhaseNight`,
`testSkyPhaseDawn`, `testSkyPhaseDusk`). Replace that entire block with:

```monkeyc
// ---- sky star alpha ----

(:test)
function testStarAlphaNight(logger as Test.Logger) as Boolean {
    return FaceKit.approxEqual(Sky.starAlpha(2.0d, 6.0d, 19.0d), 1.0, 0.01);
}

(:test)
function testStarAlphaDay(logger as Test.Logger) as Boolean {
    return FaceKit.approxEqual(Sky.starAlpha(12.0d, 6.0d, 19.0d), 0.0, 0.01);
}

(:test)
function testStarAlphaDawnRamp(logger as Test.Logger) as Boolean {
    // half an hour before sunrise -> half-faded
    return FaceKit.approxEqual(Sky.starAlpha(5.5d, 6.0d, 19.0d), 0.5, 0.01);
}

(:test)
function testStarAlphaDuskRamp(logger as Test.Logger) as Boolean {
    return FaceKit.approxEqual(Sky.starAlpha(19.5d, 6.0d, 19.0d), 0.5, 0.01);
}
```

- [ ] **Step 2: Run tests — verify they fail.** Run `./scripts/dev.sh test`.
Expected: build fails (`Sky.starAlpha` undefined; possibly `Sky.phase`/`Sky.DAY`
now referenced nowhere — that is fine).

- [ ] **Step 3: Replace `source/Sky.mc`** with EXACTLY this content:

```monkeyc
import Toybox.Lang;

// Continuous time-of-day "sky engine" — colours flow smoothly through the day.
// weather param: 0 clear, 1 cloudy, 2 rain, 3 snow.
module Sky {

    // Keyframe colours — top and horizon, at night / dawn / day / dusk.
    const NIGHT_TOP = 0x05060E;  const NIGHT_HZN = 0x141A38;
    const DAWN_TOP  = 0x141533;  const DAWN_HZN  = 0x6A4660;
    const DAY_TOP   = 0x142038;  const DAY_HZN   = 0x35506E;
    const DUSK_TOP  = 0x1A1636;  const DUSK_HZN  = 0x9A5630;

    const WX_CLOUD = 0x3A3A42;
    const WX_RAIN  = 0x1C2433;
    const WX_SNOW  = 0x4A5460;

    // Continuous top-of-screen colour for the current moment.
    function topColor(nowHour as Double, sunrise as Double, sunset as Double,
                      weather as Number) as Number {
        return tint(ramp(nowHour, sunrise, sunset,
            NIGHT_TOP, DAWN_TOP, DAY_TOP, DUSK_TOP), weather);
    }

    // Continuous horizon colour for the current moment.
    function horizonColor(nowHour as Double, sunrise as Double, sunset as Double,
                          weather as Number) as Number {
        return tint(ramp(nowHour, sunrise, sunset,
            NIGHT_HZN, DAWN_HZN, DAY_HZN, DUSK_HZN), weather);
    }

    // Sun-glow colour — warm at the day's edges, pale gold at midday.
    function glowColor(nowHour as Double, sunrise as Double,
                       sunset as Double) as Number {
        return ramp(nowHour, sunrise, sunset,
            0xFFE2A0, 0xFFB079, 0xFFE2A0, 0xFF9A40);
    }

    // Star visibility, 0.0 (full day) .. 1.0 (deep night), ramped over 1h edges.
    function starAlpha(nowHour as Double, sunrise as Double,
                       sunset as Double) as Float {
        if (nowHour <= sunrise - 1.0 || nowHour >= sunset + 1.0) { return 1.0; }
        if (nowHour >= sunrise && nowHour <= sunset)             { return 0.0; }
        if (nowHour < sunrise) {
            return ((sunrise - nowHour) / 1.0).toFloat();
        }
        return ((nowHour - sunset) / 1.0).toFloat();
    }

    // Interpolate between the four keyframe colours by the sun's position.
    function ramp(nowHour as Double, sunrise as Double, sunset as Double,
                  night as Number, dawn as Number, day as Number,
                  dusk as Number) as Number {
        var k0 = sunrise - 1.0;
        var k1 = sunrise;
        var k2 = sunrise + 1.5;
        var k3 = sunset - 1.5;
        var k4 = sunset;
        var k5 = sunset + 1.0;
        if (nowHour <= k0 || nowHour >= k5) { return night; }
        if (nowHour < k1) { return seg(nowHour, k0, k1, night, dawn); }
        if (nowHour < k2) { return seg(nowHour, k1, k2, dawn, day); }
        if (nowHour < k3) { return day; }
        if (nowHour < k4) { return seg(nowHour, k3, k4, day, dusk); }
        return seg(nowHour, k4, k5, dusk, night);
    }

    // Lerp colour a->b across the time window [t0, t1].
    function seg(now as Double, t0 as Double, t1 as Double,
                 a as Number, b as Number) as Number {
        var span = t1 - t0;
        if (span <= 0.0) { return b; }
        var f = ((now - t0) / span).toFloat();
        return FaceKit.lerpColor(a, b, f);
    }

    function tint(c as Number, weather as Number) as Number {
        if (weather == 1) { return FaceKit.lerpColor(c, WX_CLOUD, 0.35); }
        if (weather == 2) { return FaceKit.lerpColor(c, WX_RAIN, 0.45); }
        if (weather == 3) { return FaceKit.lerpColor(c, WX_SNOW, 0.30); }
        return c;
    }
}
```

- [ ] **Step 4: Update `FaceKit.drawSkyLayer` and `drawStarfield`.** In
`source/FaceKit.mc`, find the current `drawStarfield` function and the current
`drawSkyLayer` function and replace BOTH with:

```monkeyc
    // Scatter fixed stars; alpha 0.0 (invisible) .. 1.0 (full night).
    // Each star entry is [xFrac, yFrac, brightness] with brightness 1..3.
    function drawStarfield(dc as Graphics.Dc, alpha as Float) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var stars = [
            [0.16,0.12,1],[0.30,0.07,2],[0.44,0.13,1],[0.58,0.06,3],
            [0.70,0.11,1],[0.84,0.18,2],[0.12,0.26,1],[0.90,0.30,1],
            [0.22,0.40,2],[0.79,0.42,1],[0.07,0.48,1],[0.93,0.52,1],
            [0.35,0.22,1],[0.64,0.24,3],[0.50,0.32,1],[0.27,0.52,2],
            [0.73,0.56,1],[0.18,0.62,1],[0.86,0.64,2],[0.40,0.30,1],
            [0.60,0.16,1],[0.52,0.46,3],[0.10,0.36,1],[0.88,0.44,1]
        ];
        for (var i = 0; i < stars.size(); i++) {
            var s = stars[i];
            var b = s[2] as Number;
            var c = lerpColor(0x0A0C18, 0xE0E6FF, alpha * (0.4 + 0.2 * b));
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(((s[0] as Float) * w).toNumber(),
                          ((s[1] as Float) * h).toNumber(),
                          (b >= 3) ? 2 : 1);
        }
    }

    // Paint the continuous time-of-day background (+ fading stars).
    // Call as the first line of a face's draw(). Returns the sun-glow colour.
    function drawSkyLayer(dc as Graphics.Dc, state as PrayerState) as Number {
        var t = System.getClockTime();
        var nowHour = (t.hour + t.min / 60.0).toDouble();
        var sr = state.sunrise;
        var ss = state.sunset;
        var wx = WeatherData.condition();
        drawSky(dc, Sky.topColor(nowHour, sr, ss, wx),
                    Sky.horizonColor(nowHour, sr, ss, wx));
        var sa = Sky.starAlpha(nowHour, sr, ss);
        if (sa > 0.0) { drawStarfield(dc, sa); }
        return Sky.glowColor(nowHour, sr, ss);
    }
```

- [ ] **Step 5: Update the three sun-drawing faces.** `drawSkyLayer` now returns
the sun-glow colour instead of a phase. In each of `HorizonFace.mc`,
`SolarDialFace.mc`, `GradientArcFace.mc`:

  (a) Change the line `var ph = FaceKit.drawSkyLayer(dc, state);` to
  `var sunColor = FaceKit.drawSkyLayer(dc, state);`

  (b) Change the sun-draw call's last argument from `Sky.glowColor(ph)` to
  `sunColor`. The call looks like `FaceKit.drawSun(dc, ..., Sky.glowColor(ph));`
  — only the `Sky.glowColor(ph)` part changes to `sunColor`.

`CrescentFace.mc` calls `FaceKit.drawSkyLayer(dc, state);` without capturing the
return and draws no sun — leave it unchanged in this task.

- [ ] **Step 6: Run tests — verify they pass.** Run `./scripts/dev.sh test`.
Expected: `PASSED (passed=29, failed=0, errors=0)` (25 prior + 4 new starAlpha).

- [ ] **Step 7: Build.** Run `./scripts/dev.sh build`. Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 8: Commit.**
```bash
git add source/Sky.mc source/FaceKit.mc source/Tests.mc source/faces/
git commit -m "Make the sky a continuous time-of-day colour"
```

---

## Task 2: FaceKit realism primitives

**Files:** Modify `source/FaceKit.mc`.

Rendering helpers — verified by compile here, visually later.

- [ ] **Step 1: Replace `drawSun`.** Find the current `drawSun` function in
`source/FaceKit.mc` and replace it with:

```monkeyc
    // A glowing sun: a soft corona, the disc, a lighter ring, a white core.
    function drawSun(dc as Graphics.Dc, x as Float, y as Float,
                     color as Number) as Void {
        var xi = x.toNumber();
        var yi = y.toNumber();
        dc.setColor(lerpColor(0x000000, color, 0.30), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xi, yi, 21);
        dc.setColor(lerpColor(0x000000, color, 0.60), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xi, yi, 14);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xi, yi, 10);
        dc.setColor(lerpColor(color, 0xFFFFFF, 0.55), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xi, yi, 6);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xi, yi, 3);
    }
```

- [ ] **Step 2: Replace `drawCrescent`.** Find the current `drawCrescent`
function and replace it with this scanline version — it renders correctly on
any background and adds faint earthshine on the dark limb:

```monkeyc
    // A crescent moon, scanline-filled so it is correct on any background.
    // Faint earthshine fills the dark limb.
    function drawCrescent(dc as Graphics.Dc, cx as Number, cy as Number,
                          r as Number, illum as Float, waxing as Boolean) as Void {
        var d = 2.0 * r * illum;
        var earth = lerpColor(Theme.BG, Theme.MOON, 0.13);
        for (var dy = -r; dy <= r; dy++) {
            var ch2 = (r * r - dy * dy).toFloat();
            if (ch2 < 0.0) { continue; }
            var chord = Math.sqrt(ch2);
            var yy = cy + dy;
            var moonL = cx - chord;
            var moonR = cx + chord;
            dc.setColor(earth, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(moonL.toNumber(), yy, moonR.toNumber(), yy);
            dc.setColor(Theme.MOON, Graphics.COLOR_TRANSPARENT);
            if (waxing) {
                var litL = (cx - d) + chord;
                if (litL < moonR) {
                    dc.drawLine(litL.toNumber(), yy, moonR.toNumber(), yy);
                }
            } else {
                var litR = (cx + d) - chord;
                if (litR > moonL) {
                    dc.drawLine(moonL.toNumber(), yy, litR.toNumber(), yy);
                }
            }
        }
    }
```

- [ ] **Step 3: Add `drawApproachGlow`.** Add this function inside `module
FaceKit`, immediately after `drawCrescent`:

```monkeyc
    // A halo ring at the bezel that builds as a prayer nears (last 15 min).
    function drawApproachGlow(dc as Graphics.Dc, minutesToNext as Number) as Void {
        if (minutesToNext < 0 || minutesToNext > 15) { return; }
        var intensity = (15 - minutesToNext).toFloat() / 15.0;
        var w = dc.getWidth();
        var h = dc.getHeight();
        var penW = (3 + intensity * 9).toNumber();
        dc.setColor(lerpColor(0x000000, Theme.accent(), 0.25 + intensity * 0.55),
                    Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(penW);
        dc.drawCircle(w / 2, h / 2, w / 2 - penW / 2 - 1);
        dc.setPenWidth(1);
    }
```

- [ ] **Step 4: Build.** Run `./scripts/dev.sh build`. Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 5: Commit.**
```bash
git add source/FaceKit.mc
git commit -m "Add corona sun, scanline crescent, and approach glow"
```

---

## Task 3: PrayerState minutes-to-next

**Files:** Modify `source/PrayerState.mc`.

- [ ] **Step 1: Add the field.** In `source/PrayerState.mc`, find the line
`var moonWaxing as Boolean = true;` and add directly after it:

```monkeyc
    // Minutes until the next prayer (for the approach glow).
    var minutesToNext as Number = 999;
```

- [ ] **Step 2: Set it in the normal next-prayer path.** In `updateNextPrayer()`,
find:

```monkeyc
        var nextTime = times[nextPrayerIndex] as Double;
        var remaining = nextTime - hour;
        if (remaining < 0.0) { remaining = remaining + 24.0; }
        countdownString = formatCountdown(remaining);
```

Replace with:

```monkeyc
        var nextTime = times[nextPrayerIndex] as Double;
        var remaining = nextTime - hour;
        if (remaining < 0.0) { remaining = remaining + 24.0; }
        countdownString = formatCountdown(remaining);
        minutesToNext = (remaining * 60.0).toNumber();
```

- [ ] **Step 3: Set it in the tomorrow-Fajr path.** In `updateNextPrayer()`,
find (inside the `if (tomorrowFajr != null)` branch):

```monkeyc
                var remaining = (24.0 - hour) + (tomorrowFajr as Double);
                countdownString = formatCountdown(remaining);
```

Replace with:

```monkeyc
                var remaining = (24.0 - hour) + (tomorrowFajr as Double);
                countdownString = formatCountdown(remaining);
                minutesToNext = (remaining * 60.0).toNumber();
```

- [ ] **Step 4: Handle the no-data path.** In `updateNextPrayer()`, find:

```monkeyc
            } else {
                countdownString = "--";
                progressFraction = 0.0f;
                iqamaCountdownString = "";
            }
```

Replace with:

```monkeyc
            } else {
                countdownString = "--";
                progressFraction = 0.0f;
                iqamaCountdownString = "";
                minutesToNext = 999;
            }
```

- [ ] **Step 5: Build.** Run `./scripts/dev.sh build`. Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 6: Commit.**
```bash
git add source/PrayerState.mc
git commit -m "Expose minutes-to-next prayer on PrayerState"
```

---

## Task 4: Apply the approach glow to the four faces

**Files:** Modify all four files in `source/faces/`.

Each face draws the approach glow just after the sky layer, so the halo sits at
the bezel behind the face content. The find-block is the `drawSkyLayer` line
(its exact form differs per face, given below).

- [ ] **Step 1: Twilight Horizon.** In `source/faces/HorizonFace.mc`, find:

```monkeyc
        // living time-of-day background
        var sunColor = FaceKit.drawSkyLayer(dc, state);
```

Replace with:

```monkeyc
        // living time-of-day background
        var sunColor = FaceKit.drawSkyLayer(dc, state);
        FaceKit.drawApproachGlow(dc, state.minutesToNext);
```

- [ ] **Step 2: Solar Dial.** In `source/faces/SolarDialFace.mc`, find:

```monkeyc
        // living time-of-day background
        var sunColor = FaceKit.drawSkyLayer(dc, state);
```

Replace with:

```monkeyc
        // living time-of-day background
        var sunColor = FaceKit.drawSkyLayer(dc, state);
        FaceKit.drawApproachGlow(dc, state.minutesToNext);
```

- [ ] **Step 3: Crescent Month.** In `source/faces/CrescentFace.mc`, find:

```monkeyc
        // living time-of-day background
        FaceKit.drawSkyLayer(dc, state);
```

Replace with:

```monkeyc
        // living time-of-day background
        FaceKit.drawSkyLayer(dc, state);
        FaceKit.drawApproachGlow(dc, state.minutesToNext);
```

- [ ] **Step 4: Gradient Sky Arc.** In `source/faces/GradientArcFace.mc`, find:

```monkeyc
        // living time-of-day background
        var sunColor = FaceKit.drawSkyLayer(dc, state);
```

Replace with:

```monkeyc
        // living time-of-day background
        var sunColor = FaceKit.drawSkyLayer(dc, state);
        FaceKit.drawApproachGlow(dc, state.minutesToNext);
```

- [ ] **Step 5: Build.** Run `./scripts/dev.sh build`. Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 6: Commit.**
```bash
git add source/faces/
git commit -m "Draw the approach glow on all four faces"
```

---

## Task 5: Live seconds indicator

**Files:** Modify `source/GarminPrayerTimesView.mc`.

A small accent dot is drawn each second on the bezel ring; the dots accumulate
into a filling ring over the minute, and the once-a-minute full redraw clears
them. Nothing is drawn in always-on (low-power) mode.

- [ ] **Step 1: Add the System import.** In `source/GarminPrayerTimesView.mc`,
find the import block at the top and add `import Toybox.System;` to it (if it is
not already present).

- [ ] **Step 2: Add `onPartialUpdate`.** In `class GarminPrayerTimesView`, add
this method directly after the `onUpdate` function:

```monkeyc
    // Called about once per second — draws the live seconds indicator.
    function onPartialUpdate(dc as Graphics.Dc) as Void {
        if (isLowPower) { return; }
        var sec = System.getClockTime().sec;
        var w = dc.getWidth();
        var cx = w / 2.0;
        var cy = dc.getHeight() / 2.0;
        var r = w / 2.0 - 6.0;
        var ang = (sec / 60.0) * 360.0;
        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(FaceKit.polarX(cx, r, ang).toNumber(),
                      FaceKit.polarY(cy, r, ang).toNumber(), 2);
    }
```

- [ ] **Step 3: Build.** Run `./scripts/dev.sh build`. Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 4: Commit.**
```bash
git add source/GarminPrayerTimesView.mc
git commit -m "Add a live per-second indicator"
```

---

## Task 6: Cross-device verification and package

**Files:** none modified — verification only.

- [ ] **Step 1: Run the full test suite.** Run `./scripts/dev.sh test`.
Expected: `PASSED (passed=29, failed=0, errors=0)`.

- [ ] **Step 2: Build all three device sizes.**
```bash
DEVICE=epix2pro42mm ./scripts/dev.sh build
DEVICE=epix2pro47mm ./scripts/dev.sh build
DEVICE=venu3 ./scripts/dev.sh build
```
Each must print `BUILD SUCCESSFUL`.

- [ ] **Step 3: Build the store package.** Run `./scripts/dev.sh package`.
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 4: Commit.**
```bash
git commit --allow-empty -m "Verify dynamic-realistic faces across devices"
```

> **Visual verification (controller, after this task):** in the simulator,
> confirm the sky transitions smoothly (no hard jump between phases), the
> approach glow appears within 15 minutes of a prayer, the crescent renders
> with earthshine and no background blob, the sun shows a corona, stars fade
> with twilight, and the seconds dot advances each second. Always-on mode stays
> black. Tune constants if needed.

---

## Self-Review (completed by plan author)

- **Spec coverage:** continuous sky → Task 1 (`Sky` rewrite, `drawSkyLayer`);
  approach glow → `drawApproachGlow` (Task 2), `minutesToNext` (Task 3), applied
  per face (Task 4); realistic celestial → `drawSun` corona + `drawCrescent`
  earthshine (Task 2), varied/fading stars (`drawStarfield` in Task 1); live
  seconds → `onPartialUpdate` (Task 5); cross-device + package (Task 6).
- **Placeholder scan:** none — every step has real code or exact commands.
- **Type consistency:** `drawSkyLayer` returns `Number` (the sun colour);
  the three sun-faces capture it as `sunColor` and pass it to `drawSun`;
  `CrescentFace` discards it. `starAlpha` returns `Float`; `drawStarfield` takes
  `Float`. `minutesToNext` is a `Number` on `PrayerState`, consumed by
  `drawApproachGlow(dc, Number)`. Star table entries are `[Float,Float,Number]`.
- **Note for executor:** Task 1 is intentionally multi-file — the continuous-sky
  change is atomic (removing `Sky.phase` would break `drawSkyLayer` and the
  faces mid-task). Build green is only asserted at the end of Task 1.
- **Note:** colour values and glow/corona sizes are tunable; the visual
  verification step exists to nudge them.
