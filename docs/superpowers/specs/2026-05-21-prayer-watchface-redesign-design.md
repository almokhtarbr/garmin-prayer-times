# Prayer Times Watch Face — Multi-Face Redesign

**Date:** 2026-05-21
**Status:** Approved design — ready for implementation planning

## Context & Problem

The Garmin Prayer Times watch face works (prayer math, Hijri calendar, GPS, and
state caching were all audited and bug-fixed — see `DEVLOG.md`), but the UI layer
is poor:

- `GarminPrayerTimesView.mc` crams a 6-cell grid + clock + two countdowns + Hijri
  date into one `onUpdate()` with no visual hierarchy.
- Layout uses negative-offset hacks (`y + fhX - 30`) to claw back space — a sign
  it is over-stuffed for a small round screen.
- The progress arc is buggy: the track spans 120° (`drawArc(..., 210, 330)`) but
  the fill is computed over a 240° span — they do not match.
- A 2-column grid wastes the cut corners of a round display.

The goal is a redesign with Apple-Watch-grade hierarchy: each screen has **one
hero element**, everything else supports it.

## Goals

- Rebuild the UI layer as **four switchable watch faces**, selected via a phone
  setting. Default and primary-focus face: **Twilight Horizon**.
- Clean, isolated module boundaries — each face is one file with one job.
- Keep the audited data layer (`PrayerCalculator`, `HijriCalendar`, prayer-time
  caching) intact.
- Look excellent on all 7 manifest devices (390–454px round AMOLED), designed
  for the 390px floor so it never looks cramped.

## Non-Goals (out of scope)

- Vibration / notification alerts — Garmin watch faces cannot use the Attention
  API. A companion app would be required; noted as possible future work.
- New calculation methods — the existing 11 are sufficient.
- Tap / button interaction — watch faces receive no input on Garmin; face
  switching is settings-only by platform necessity.

## The Four Faces

All faces share: black background (AMOLED battery + burn-in), an amber accent for
the next prayer, the digital clock, the Hijri date, and a next-prayer countdown.

1. **Twilight Horizon** *(default, most polish)* — a horizon line across the
   face. The four daytime prayers (Sunrise, Dhuhr, Asr, Maghrib) sit on a sky
   dome; the sun rides the dome at the current time. Isha and Fajr sit below the
   horizon in the night zone with a crescent moon. A soft twilight gradient glows
   above the horizon. Clock + next prayer sit just below the horizon line.
2. **Solar Dial** — a true 24-hour ring: noon at top, midnight at bottom. The
   ring is split into a lit daytime band (sunrise→sunset) and a dark night band.
   All six prayers are markers at their real angular positions; a sun bead rides
   the ring to "now." Clock + countdown in the center.
3. **Crescent Month** — a crescent moon hero whose phase matches the current
   Hijri date. The Hijri date gets visual weight; the six prayers wrap a quiet
   arc along the bottom bezel. Clock + countdown center.
4. **Gradient Sky Arc** — a ~280° arc whose stroke is segmented into the day's
   real light (indigo night → rose dawn → gold noon → amber dusk). A sun bead
   rides the arc; a soft warm glow sits behind the clock.

## Architecture

The data layer is kept; the UI layer is rebuilt around a dispatcher + isolated
face renderers that share a geometry/drawing toolkit.

```
source/
├── GarminPrayerTimesApp.mc   App entry, GPS                    — minor changes
├── GarminPrayerTimesView.mc  Slim dispatcher (~40 lines)       — rewritten
├── PrayerCalculator.mc       Prayer-time math                  — unchanged
├── HijriCalendar.mc          Gregorian → Hijri                 — unchanged
├── PrayerState.mc            Cached data feeding the faces     — extended
├── MoonPhase.mc              Lunar phase from Hijri day        — NEW
├── FaceKit.mc                Polar/arc geometry + draw helpers — NEW (shared)
├── Theme.mc                  Palette + accent color            — NEW
└── faces/
    ├── HorizonFace.mc        Twilight Horizon renderer         — NEW
    ├── SolarDialFace.mc      Solar Dial renderer               — NEW
    ├── CrescentFace.mc       Crescent Month renderer           — NEW
    └── GradientArcFace.mc    Gradient Sky Arc renderer         — NEW
```

`monkey.jungle` is updated if needed so `source/faces/` is compiled.

### Module responsibilities

- **PrayerCalculator** — pure prayer-time math. No change.
- **HijriCalendar** — Gregorian → Hijri conversion. No change.
- **MoonPhase** — given a Hijri day (1–30), returns illuminated fraction and a
  waxing/waning flag. Approximation: `illum = (1 - cos(2π·(day-1)/29.53)) / 2`,
  waxing when `day < 15`. Sufficient for a crescent glyph.
- **PrayerState** — caches today's prayer times, next prayer, countdown, and
  progress (existing). **Extended** to also expose:
  - `sunrise`, `sunset` (hours) — read from `todayTimes`.
  - `dayFraction` — current position between sunrise and sunset (0–1), clamped.
  - `prayerStatus` — a 6-element array: `0`=passed, `1`=next, `2`=upcoming.
  - `moonPhase` — illuminated fraction + waxing flag, via `MoonPhase` from the
    Hijri day, recomputed on date change only.
- **FaceKit** — shared, stateless drawing helpers used by every face:
  - `polarX(cx, r, angleDeg)` / `polarY(cy, r, angleDeg)` — angle convention
    0° = top, increasing clockwise.
  - `drawArcSegment(dc, cx, cy, r, startDeg, endDeg, penWidth, color)`.
  - `drawGlowDot(dc, x, y, radius, color)` — a dot with a translucent halo.
  - `drawCrescent(dc, cx, cy, r, illumFraction, waxing)` — crescent via two
    overlapping circles, offset proportional to phase.
  - `hourToDialAngle(hour)` — for the 24-hour dial: `((hour-12)/24)·360`.
- **Theme** — palette constants (extracted from the current `COLOR_*` set) plus
  the twilight palette (indigo / rose / gold / amber) and the user's accent color
  from settings.
- **Face renderers** — each is a class with two methods:
  ```
  function draw(dc as Dc, state as PrayerState) as Void;
  function drawLowPower(dc as Dc, state as PrayerState) as Void;
  ```
  A face draws only — it never calculates. It reads `PrayerState` and calls
  `FaceKit` helpers. Each face is independently understandable and testable.
- **GarminPrayerTimesView** — slim dispatcher. On layout and on settings change,
  reads the `faceStyle` setting and instantiates the matching face. `onUpdate()`
  calls `state.update()` then delegates to the active face's `draw` or
  `drawLowPower`. Handles `onEnterSleep` / `onExitSleep`.
- **GarminPrayerTimesApp** — entry point and GPS. Minor change: on settings
  change, also tell the View to re-pick the face.

### Data flow

```
GPS → App → PrayerState (recalculate once/day or on location change)
                  │
GarminPrayerTimesView.onUpdate()
   reads faceStyle setting → active face
   state.update()  → activeFace.draw(dc, state)  → FaceKit helpers render
```

## Face Geometry (mapping rules)

Faces compute positions from the day's actual prayer times — no hardcoded pixels.
Angle convention everywhere: 0° = top of screen, increasing clockwise.

- **Twilight Horizon** — daytime prayers placed on the dome by fraction
  `(prayerHour - sunrise) / (sunset - sunrise)`, mapped to a 180°→0° sweep over
  the top. The sun is placed at `dayFraction`. Isha and Fajr are placed in the
  night zone below the horizon line. Crescent drawn from `moonPhase`.
- **Solar Dial** — every prayer placed at `hourToDialAngle(prayerHour)`. Daytime
  band drawn from sunrise angle to sunset angle; night band fills the remainder.
  Sun bead placed at `hourToDialAngle(nowHour)`.
- **Crescent Month** — crescent drawn from `moonPhase`. Six prayers placed evenly
  along a bottom-bezel arc; the elapsed portion is filled to the next prayer.
- **Gradient Sky Arc** — a fixed ~280° arc (80° gap at the bottom). Prayers
  placed by fraction `(prayerHour - fajr) / (isha - fajr)`. The stroke is drawn
  as five colored segments between consecutive prayers. Sun bead at the now
  fraction.

Per-prayer rendering uses `prayerStatus`: passed = dim gray, upcoming = light
gray/white, next = amber with a glow halo.

## Low-Power / Always-On Display

Every face implements `drawLowPower()`. AMOLED always-on requires minimal lit
pixels for battery and burn-in protection. Each AOD variant shows: the clock, the
next prayer + countdown, and a stripped-down version of the face's signature
element (e.g., Horizon AOD = horizon line + dimmed sun position only). Background
stays pure black.

## Settings

Add a face-selection setting; keep all existing settings.

- `resources/properties.xml` — add `faceStyle` (number, default `0`).
- `resources/settings.xml` — add a list picker:
  `0` Twilight Horizon · `1` Solar Dial · `2` Crescent Month · `3` Gradient Sky Arc.
- `resources/strings.xml` — add the `faceStyle` label string.

Existing settings unchanged: `calcMethod`, `asrMethod`, `showIqama`, the five
iqama offsets, `accentColor`. Iqama, when enabled, is shown subtly near the
next-prayer line on faces that have room.

## Garmin Platform Constraints

- Watch faces receive no button or touch input — face switching is settings-only.
- `onUpdate()` runs about once per minute in high-power mode; calculation must
  stay out of the render path (already true — `PrayerState` caches).
- `onPartialUpdate()` may update a small region once per second in low power; AOD
  variants stay minimal.
- AMOLED burn-in: keep the background black and AOD content sparse.

## Build Order

1. **Scaffolding** — `Theme`, `FaceKit`, `MoonPhase`, `PrayerState` extensions,
   the `faceStyle` setting, and the slim `View` dispatcher.
2. **Twilight Horizon** — built and polished fully (default + focus face).
3. **Solar Dial** — reuses `FaceKit`.
4. **Crescent Month** — reuses `FaceKit` + `MoonPhase`.
5. **Gradient Sky Arc** — reuses `FaceKit`.
6. **Low-power variants** for all four faces.

## Verification

- Build with the Connect IQ SDK; run in the simulator on `epix2pro42mm` (390px),
  `epix2pro47mm` (416px), and `venu3` (454px) — confirm each face is uncramped at
  every size.
- Switch `faceStyle` through all four values; confirm the correct face renders.
- Confirm prayer times still match the reference (Mac app) for the same location
  and method.
- Confirm day rollover (after Isha, next = tomorrow's Fajr).
- Confirm AOD: enter sleep, confirm each face's low-power variant.
