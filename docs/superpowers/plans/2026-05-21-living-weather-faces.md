# Living, Weather-Aware Faces — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all four watch faces feel alive — a time-of-day "living sky" background, real-time weather, and Apple-grade light/depth — without adding new faces.

**Architecture:** Three shared modules (`WeatherData`, `Sky`, plus `FaceKit` rendering primitives) supply the new behaviour; each of the four face files paints the sky first, then its existing elements, then weather. The audited prayer/Hijri data layer is untouched.

**Tech Stack:** Monkey C, Connect IQ SDK 8.4.0, `Toybox.Weather`. Branch: `enhance/living-weather-faces`.

---

## Conventions

- Build: `./scripts/dev.sh build` → `BUILD SUCCESSFUL`.
- Test: `./scripts/dev.sh test` → exits non-zero even on success; judge by the printed `PASSED (passed=N, failed=0, errors=0)` line.
- Commit messages: exactly as given. NO "Co-Authored-By", NO AI/assistant attribution — hard project rule.
- Work from `/Users/almokhtarbekkour/Developer.nosync/mvps/garmin-prayer-times`, branch `enhance/living-weather-faces` (already checked out).
- Rendering correctness is verified later in the simulator by the controller; an implementer's gate is a clean compile + passing unit tests.

## File Structure

```
source/
├── WeatherData.mc   CREATE — wraps Toybox.Weather, safe when unavailable
├── Sky.mc           CREATE — time-of-day palette engine
├── FaceKit.mc       MODIFY — lerpColor, drawSky, drawSun, drawStarfield,
│                             drawWeatherGlyph, drawSkyLayer, drawWeather
├── Tests.mc         MODIFY — unit tests for lerpColor and Sky.phase
└── faces/
    ├── HorizonFace.mc      MODIFY — sky layer, living sun, weather
    ├── SolarDialFace.mc    MODIFY — sky layer, living sun, weather
    ├── CrescentFace.mc     MODIFY — sky layer, weather
    └── GradientArcFace.mc  MODIFY — sky layer, living sun, weather
```

`manifest.xml` needs no change — `Toybox.Weather` requires no permission. (If a build error says otherwise, add the permission and note it.)

---

## Task 1: Data + logic modules (WeatherData, Sky, FaceKit.lerpColor)

**Files:**
- Create: `source/WeatherData.mc`, `source/Sky.mc`
- Modify: `source/FaceKit.mc`, `source/Tests.mc`

- [ ] **Step 1: Write the failing tests.** Append to `source/Tests.mc`:

```monkeyc

// ---- color interpolation ----

(:test)
function testLerpStart(logger as Test.Logger) as Boolean {
    return FaceKit.lerpColor(0x000000, 0xFFFFFF, 0.0) == 0x000000;
}

(:test)
function testLerpEnd(logger as Test.Logger) as Boolean {
    return FaceKit.lerpColor(0x000000, 0xFFFFFF, 1.0) == 0xFFFFFF;
}

(:test)
function testLerpMid(logger as Test.Logger) as Boolean {
    // 255 * 0.5 = 127.5 -> 127 per channel
    return FaceKit.lerpColor(0x000000, 0xFFFFFF, 0.5) == 0x7F7F7F;
}

(:test)
function testLerpClampsBelowZero(logger as Test.Logger) as Boolean {
    return FaceKit.lerpColor(0x101010, 0xFFFFFF, -1.0) == 0x101010;
}

// ---- sky phase ----

(:test)
function testSkyPhaseDay(logger as Test.Logger) as Boolean {
    return Sky.phase(12.0d, 6.0d, 19.0d) == Sky.DAY;
}

(:test)
function testSkyPhaseNight(logger as Test.Logger) as Boolean {
    return Sky.phase(2.0d, 6.0d, 19.0d) == Sky.NIGHT;
}

(:test)
function testSkyPhaseDawn(logger as Test.Logger) as Boolean {
    return Sky.phase(5.5d, 6.0d, 19.0d) == Sky.DAWN;
}

(:test)
function testSkyPhaseDusk(logger as Test.Logger) as Boolean {
    return Sky.phase(19.5d, 6.0d, 19.0d) == Sky.DUSK;
}
```

- [ ] **Step 2: Run tests — verify they fail.** Run `./scripts/dev.sh test`. Expected: build fails (`lerpColor` / `Sky` undefined).

- [ ] **Step 3: Add `lerpColor` to `source/FaceKit.mc`.** Inside `module FaceKit`, after the existing `dim` function, add:

```monkeyc
    // Linear-interpolate two RGB colours. t is clamped to 0.0-1.0.
    function lerpColor(c1 as Number, c2 as Number, t as Float) as Number {
        var tt = t;
        if (tt < 0.0) { tt = 0.0; }
        if (tt > 1.0) { tt = 1.0; }
        var r1 = (c1 >> 16) & 0xFF;
        var g1 = (c1 >> 8) & 0xFF;
        var b1 = c1 & 0xFF;
        var r = (r1 + (((c2 >> 16) & 0xFF) - r1) * tt).toNumber();
        var g = (g1 + (((c2 >> 8) & 0xFF) - g1) * tt).toNumber();
        var b = (b1 + ((c2 & 0xFF) - b1) * tt).toNumber();
        return (r << 16) | (g << 8) | b;
    }
```

- [ ] **Step 4: Create `source/Sky.mc`** with EXACTLY this content:

```monkeyc
import Toybox.Lang;

// Time-of-day "sky engine" — turns the clock, sun, and weather into a palette.
// weather param: 0 clear, 1 cloudy, 2 rain, 3 snow.
module Sky {

    const NIGHT = 0;
    const DAWN  = 1;
    const DAY   = 2;
    const DUSK  = 3;

    // Twilight ramp — top and horizon colour per phase.
    const NIGHT_TOP = 0x05060E;  const NIGHT_HZN = 0x141A38;
    const DAWN_TOP  = 0x141533;  const DAWN_HZN  = 0x6A4660;
    const DAY_TOP   = 0x142038;  const DAY_HZN   = 0x35506E;
    const DUSK_TOP  = 0x1A1636;  const DUSK_HZN  = 0x9A5630;

    // Weather tint targets.
    const WX_CLOUD = 0x3A3A42;
    const WX_RAIN  = 0x1C2433;
    const WX_SNOW  = 0x4A5460;

    function phase(nowHour as Double, sunrise as Double, sunset as Double) as Number {
        if (nowHour >= sunrise - 1.0 && nowHour < sunrise) { return DAWN; }
        if (nowHour >= sunrise && nowHour < sunset)        { return DAY; }
        if (nowHour >= sunset && nowHour < sunset + 1.0)   { return DUSK; }
        return NIGHT;
    }

    function topColor(ph as Number, weather as Number) as Number {
        var c = NIGHT_TOP;
        if (ph == DAWN) { c = DAWN_TOP; }
        else if (ph == DAY) { c = DAY_TOP; }
        else if (ph == DUSK) { c = DUSK_TOP; }
        return tint(c, weather);
    }

    function horizonColor(ph as Number, weather as Number) as Number {
        var c = NIGHT_HZN;
        if (ph == DAWN) { c = DAWN_HZN; }
        else if (ph == DAY) { c = DAY_HZN; }
        else if (ph == DUSK) { c = DUSK_HZN; }
        return tint(c, weather);
    }

    function glowColor(ph as Number) as Number {
        if (ph == DAWN) { return 0xFFB079; }
        if (ph == DUSK) { return 0xFF9A40; }
        return 0xFFE2A0;
    }

    function showStars(ph as Number) as Boolean {
        return ph == NIGHT || ph == DAWN;
    }

    function tint(c as Number, weather as Number) as Number {
        if (weather == 1) { return FaceKit.lerpColor(c, WX_CLOUD, 0.35); }
        if (weather == 2) { return FaceKit.lerpColor(c, WX_RAIN, 0.45); }
        if (weather == 3) { return FaceKit.lerpColor(c, WX_SNOW, 0.30); }
        return c;
    }
}
```

- [ ] **Step 5: Create `source/WeatherData.mc`** with EXACTLY this content:

```monkeyc
import Toybox.Lang;
import Toybox.Weather;

// Wraps Toybox.Weather. Every accessor degrades to a clear-sky default when
// the watch has no synced weather, rather than failing.
module WeatherData {

    const CLEAR  = 0;
    const CLOUDY = 1;
    const RAIN   = 2;
    const SNOW   = 3;

    function isAvailable() as Boolean {
        return Weather.getCurrentConditions() != null;
    }

    function temperature() as Number? {
        var cc = Weather.getCurrentConditions();
        if (cc == null) { return null; }
        return cc.temperature;
    }

    // Current condition mapped to CLEAR / CLOUDY / RAIN / SNOW.
    function condition() as Number {
        var cc = Weather.getCurrentConditions();
        if (cc == null) { return CLEAR; }
        var c = cc.condition;
        if (c == null) { return CLEAR; }
        if (c == Weather.CONDITION_RAIN
         || c == Weather.CONDITION_THUNDERSTORMS) { return RAIN; }
        if (c == Weather.CONDITION_SNOW) { return SNOW; }
        if (c == Weather.CONDITION_CLOUDY
         || c == Weather.CONDITION_MOSTLY_CLOUDY
         || c == Weather.CONDITION_PARTLY_CLOUDY
         || c == Weather.CONDITION_FOG) { return CLOUDY; }
        return CLEAR;
    }
}
```

- [ ] **Step 6: Run tests — verify they pass.** Run `./scripts/dev.sh test`. Expected: `PASSED (passed=29, failed=0, errors=0)` (21 existing + 8 new).

- [ ] **Step 7: Commit.**

```bash
git add source/WeatherData.mc source/Sky.mc source/FaceKit.mc source/Tests.mc
git commit -m "Add WeatherData and Sky modules with color interpolation"
```

---

## Task 2: FaceKit rendering primitives

**Files:**
- Modify: `source/FaceKit.mc`

Rendering helpers — verified by compile here, visually later.

- [ ] **Step 1: Add the primitives.** Inside `module FaceKit`, after the `lerpColor` function added in Task 1, add:

```monkeyc
    // Fill the screen with a vertical banded gradient (top -> horizon colour).
    function drawSky(dc as Graphics.Dc, topColor as Number,
                     horizonColor as Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var bands = 40;
        for (var i = 0; i < bands; i++) {
            var t = i.toFloat() / (bands - 1);
            var c = lerpColor(topColor, horizonColor, t);
            dc.setColor(c, c);
            dc.fillRectangle(0, i * h / bands, w, (h / bands) + 2);
        }
    }

    // A glowing sun: a coloured disc, a lighter ring, a white core.
    function drawSun(dc as Graphics.Dc, x as Float, y as Float,
                     color as Number) as Void {
        var xi = x.toNumber();
        var yi = y.toNumber();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xi, yi, 13);
        dc.setColor(lerpColor(color, 0xFFFFFF, 0.55), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xi, yi, 8);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xi, yi, 4);
    }

    // Scatter fixed stars across the screen (deterministic positions).
    function drawStarfield(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var stars = [
            [0.16,0.12,1],[0.30,0.07,1],[0.44,0.13,2],[0.58,0.06,1],
            [0.70,0.11,1],[0.84,0.18,2],[0.12,0.26,1],[0.90,0.30,1],
            [0.22,0.40,1],[0.79,0.42,1],[0.07,0.48,1],[0.93,0.52,2],
            [0.35,0.22,1],[0.64,0.24,1],[0.50,0.32,1],[0.27,0.52,1],
            [0.73,0.56,1],[0.18,0.62,1],[0.86,0.64,1],[0.40,0.30,1],
            [0.60,0.16,2],[0.52,0.46,1],[0.10,0.36,1],[0.88,0.44,1]
        ];
        dc.setColor(0xCFD4FF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < stars.size(); i++) {
            var s = stars[i];
            dc.fillCircle(((s[0] as Float) * w).toNumber(),
                          ((s[1] as Float) * h).toNumber(),
                          s[2] as Number);
        }
    }

    // Small weather icon centred at (x,y). cond: 0 clear,1 cloud,2 rain,3 snow.
    function drawWeatherGlyph(dc as Graphics.Dc, x as Number, y as Number,
                              cond as Number) as Void {
        if (cond == 0) {
            dc.setColor(0xFFD98A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, 5);
            return;
        }
        dc.setColor(0xB0B6C8, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - 4, y, 4);
        dc.fillCircle(x + 4, y, 4);
        dc.fillCircle(x, y - 3, 5);
        if (cond == 2) {
            dc.setColor(0x6E9AD0, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 5, y + 5, 2, 4);
            dc.fillRectangle(x + 1, y + 5, 2, 4);
        } else if (cond == 3) {
            dc.setColor(0xE6ECFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x - 3, y + 7, 1);
            dc.fillCircle(x + 3, y + 7, 1);
        }
    }

    // Paint the living time-of-day background (+ stars at night).
    // Call as the first line of a face's draw(). Returns the Sky phase.
    function drawSkyLayer(dc as Graphics.Dc, state as PrayerState) as Number {
        var t = System.getClockTime();
        var nowHour = (t.hour + t.min / 60.0).toDouble();
        var ph = Sky.phase(nowHour, state.sunrise, state.sunset);
        var wx = WeatherData.condition();
        drawSky(dc, Sky.topColor(ph, wx), Sky.horizonColor(ph, wx));
        if (Sky.showStars(ph)) { drawStarfield(dc); }
        return ph;
    }

    // Weather readout: glyph + temperature near (cx, y). Silent when no data.
    function drawWeather(dc as Graphics.Dc, cx as Number, y as Number) as Void {
        if (!WeatherData.isAvailable()) { return; }
        var temp = WeatherData.temperature();
        if (temp == null) { return; }
        drawWeatherGlyph(dc, cx - 15, y, WeatherData.condition());
        dc.setColor(Theme.TEXT_MID, Graphics.COLOR_TRANSPARENT);
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.drawText(cx + 4, y - fh / 2, Graphics.FONT_XTINY,
            temp.toString() + "°", Graphics.TEXT_JUSTIFY_LEFT);
    }
```

- [ ] **Step 2: Build — verify it compiles.** Run `./scripts/dev.sh build`. Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Commit.**

```bash
git add source/FaceKit.mc
git commit -m "Add sky, sun, starfield, and weather rendering primitives"
```

---

## Task 3: Twilight Horizon — living sky

**Files:**
- Modify: `source/faces/HorizonFace.mc`

- [ ] **Step 1: Paint the sky first.** In `draw()`, find:

```monkeyc
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var hy = h * HORIZON_Y;
        var domeR = w * DOME_R;

        // crescent moon in the twilight sky
```

Replace with:

```monkeyc
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var hy = h * HORIZON_Y;
        var domeR = w * DOME_R;

        // living time-of-day background
        var ph = FaceKit.drawSkyLayer(dc, state);

        // crescent moon in the twilight sky
```

- [ ] **Step 2: Make the sun live.** In `draw()`, find:

```monkeyc
        // sun riding the dome
        var sunAng = 287.0 + state.dayFraction * 146.0;
        FaceKit.drawGlowDot(dc,
            FaceKit.polarX(cx, domeR, sunAng),
            FaceKit.polarY(hy, domeR, sunAng), 7, Theme.NOON);
```

Replace with:

```monkeyc
        // sun riding the dome — colour shifts with the time of day
        var sunAng = 287.0 + state.dayFraction * 146.0;
        FaceKit.drawSun(dc,
            FaceKit.polarX(cx, domeR, sunAng),
            FaceKit.polarY(hy, domeR, sunAng), Sky.glowColor(ph));
```

- [ ] **Step 3: Add the weather readout.** In `draw()`, find:

```monkeyc
        // center stack below the horizon
        FaceKit.drawClock(dc, cx, hy + h * 0.165,
```

Replace with:

```monkeyc
        // weather, just above the clock
        FaceKit.drawWeather(dc, cx.toNumber(), (hy - h * 0.04).toNumber());

        // center stack below the horizon
        FaceKit.drawClock(dc, cx, hy + h * 0.165,
```

- [ ] **Step 4: Build.** Run `./scripts/dev.sh build`. Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 5: Commit.**

```bash
git add source/faces/HorizonFace.mc
git commit -m "Twilight Horizon: living sky, sun, and weather"
```

---

## Task 4: Solar Dial — living sky

**Files:**
- Modify: `source/faces/SolarDialFace.mc`

- [ ] **Step 1: Paint the sky first.** In `draw()`, find:

```monkeyc
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;
        var r = w * RING_R;

        var sunriseAng = FaceKit.hourToDialAngle(state.sunrise.toFloat());
```

Replace with:

```monkeyc
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;
        var r = w * RING_R;

        // living time-of-day background
        var ph = FaceKit.drawSkyLayer(dc, state);

        var sunriseAng = FaceKit.hourToDialAngle(state.sunrise.toFloat());
```

- [ ] **Step 2: Make the sun live.** In `draw()`, find:

```monkeyc
        FaceKit.drawGlowDot(dc,
            FaceKit.polarX(cx, r, nowAng), FaceKit.polarY(cy, r, nowAng),
            7, Theme.NOON);
```

Replace with:

```monkeyc
        FaceKit.drawSun(dc,
            FaceKit.polarX(cx, r, nowAng), FaceKit.polarY(cy, r, nowAng),
            Sky.glowColor(ph));
```

- [ ] **Step 3: Add the weather readout.** In `draw()`, find this block (the
`Theme.TEXT_BRIGHT` clock identifies the `draw()` copy, not the `drawLowPower`
copy which uses `Theme.TEXT_MID`):

```monkeyc
        FaceKit.drawClock(dc, cx, cy + h * 0.01,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_BRIGHT);
        FaceKit.drawNextLine(dc, cx, cy + h * 0.15, state);
    }
```

Replace with:

```monkeyc
        FaceKit.drawClock(dc, cx, cy + h * 0.01,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_BRIGHT);
        FaceKit.drawNextLine(dc, cx, cy + h * 0.15, state);
        FaceKit.drawWeather(dc, cx.toNumber(), (cy + h * 0.26).toNumber());
    }
```

- [ ] **Step 4: Build.** Run `./scripts/dev.sh build`. Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 5: Commit.**

```bash
git add source/faces/SolarDialFace.mc
git commit -m "Solar Dial: living sky, sun, and weather"
```

---

## Task 5: Crescent Month — living sky

**Files:**
- Modify: `source/faces/CrescentFace.mc`

- [ ] **Step 1: Paint the sky first.** In `draw()`, find:

```monkeyc
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;

        // crescent hero
```

Replace with:

```monkeyc
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;

        // living time-of-day background
        FaceKit.drawSkyLayer(dc, state);

        // crescent hero
```

- [ ] **Step 2: Add the weather readout.** In `draw()`, find:

```monkeyc
        FaceKit.drawNextLine(dc, cx, h * 0.70, state);

        // quiet six-prayer arc along the bottom bezel
```

Replace with:

```monkeyc
        FaceKit.drawNextLine(dc, cx, h * 0.70, state);
        FaceKit.drawWeather(dc, cx.toNumber(), (h * 0.80).toNumber());

        // quiet six-prayer arc along the bottom bezel
```

- [ ] **Step 3: Build.** Run `./scripts/dev.sh build`. Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 4: Commit.**

```bash
git add source/faces/CrescentFace.mc
git commit -m "Crescent Month: living sky and weather"
```

---

## Task 6: Gradient Sky Arc — living sky

**Files:**
- Modify: `source/faces/GradientArcFace.mc`

- [ ] **Step 1: Paint the sky first.** In `draw()`, find:

```monkeyc
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;
        var r = w * ARC_R;
        var fajr = times[PrayerState.FAJR] as Double;
```

Replace with:

```monkeyc
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;
        var r = w * ARC_R;

        // living time-of-day background
        var ph = FaceKit.drawSkyLayer(dc, state);

        var fajr = times[PrayerState.FAJR] as Double;
```

- [ ] **Step 2: Make the sun live.** In `draw()`, find:

```monkeyc
        FaceKit.drawGlowDot(dc,
            FaceKit.polarX(cx, r, nowAng), FaceKit.polarY(cy, r, nowAng),
            6, Theme.NOON);
```

Replace with:

```monkeyc
        FaceKit.drawSun(dc,
            FaceKit.polarX(cx, r, nowAng), FaceKit.polarY(cy, r, nowAng),
            Sky.glowColor(ph));
```

- [ ] **Step 3: Add the weather readout.** In `draw()`, find this block (the
`Theme.TEXT_BRIGHT` clock identifies the `draw()` copy, not the `drawLowPower`
copy which uses `Theme.TEXT_MID`):

```monkeyc
        FaceKit.drawClock(dc, cx, cy + h * 0.01,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_BRIGHT);
        FaceKit.drawNextLine(dc, cx, cy + h * 0.15, state);
    }
```

Replace with:

```monkeyc
        FaceKit.drawClock(dc, cx, cy + h * 0.01,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_BRIGHT);
        FaceKit.drawNextLine(dc, cx, cy + h * 0.15, state);
        FaceKit.drawWeather(dc, cx.toNumber(), (cy + h * 0.26).toNumber());
    }
```

- [ ] **Step 4: Build.** Run `./scripts/dev.sh build`. Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 5: Commit.**

```bash
git add source/faces/GradientArcFace.mc
git commit -m "Gradient Sky Arc: living sky, sun, and weather"
```

---

## Task 7: Cross-device verification and package

**Files:** none modified — verification only.

- [ ] **Step 1: Run the full test suite.** Run `./scripts/dev.sh test`. Expected: `PASSED (passed=29, failed=0, errors=0)`.

- [ ] **Step 2: Build all three device sizes.**
```bash
DEVICE=epix2pro42mm ./scripts/dev.sh build
DEVICE=epix2pro47mm ./scripts/dev.sh build
DEVICE=venu3 ./scripts/dev.sh build
```
Each must print `BUILD SUCCESSFUL`.

- [ ] **Step 3: Build the store package.** Run `./scripts/dev.sh package`. Expected: `BUILD SUCCESSFUL` and the `.iq` is produced.

- [ ] **Step 4: Commit.**
```bash
git commit --allow-empty -m "Verify living-weather faces across devices"
```

> **Visual verification (controller, after this task):** in the simulator, view each face and confirm the living sky renders, the sun colour shifts, stars appear at night, and the weather readout shows when the simulator's weather is enabled (Simulation menu → Weather) and hides cleanly when it is not. Always-on mode must stay black. Tune the band count, star positions, weather position, and sun size if needed.

---

## Self-Review (completed by plan author)

- **Spec coverage:** real-time weather → `WeatherData` + `drawWeather` (Tasks 1, 2) applied per face (3–6); living time-of-day → `Sky` + `drawSky`/`drawSkyLayer` (1, 2) applied per face; Apple polish (light/depth/stars) → `drawSun`, `drawStarfield` (2) applied per face; Connect IQ realities → banding in `drawSky`, AOD untouched (`drawLowPower` not modified anywhere), weather-null handled in `WeatherData` + `drawWeather`. All four faces covered (Tasks 3–6). Cross-device + package (7).
- **Deviation from spec:** the twilight ramp colours live in `Sky.mc`, not `Theme.mc` — `Sky` owns the sky palette, so `Theme` needs no change. Cleaner; no behaviour difference.
- **Placeholder scan:** none — every step has real code or exact commands.
- **Type consistency:** `drawSkyLayer` returns `Number` (the phase) and every face that needs the sun captures it as `ph`; `Sky.glowColor(ph)` consumes it. Crescent does not draw a sun so it ignores the return. `drawWeather`/`drawSky`/`drawSun`/`drawStarfield` signatures match all call sites. Weather categories `0/1/2/3` are consistent between `WeatherData`, `Sky.tint`, and `drawWeatherGlyph`.
- **Note for executor:** the simulator runs at the real clock time (currently night), so the day/dawn/dusk palettes are verified by the controller by temporarily adjusting the simulated state — expected, not a plan gap.
