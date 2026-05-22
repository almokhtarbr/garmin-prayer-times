# Dynamic & Realistic Faces

**Date:** 2026-05-21
**Status:** Approved design — ready for implementation planning
**Branch:** `enhance/dynamic-realistic` (off `enhance/living-weather-faces`)

## Context

The four faces now have a living, weather-aware sky (round 2). This round makes
them more *dynamic* (visibly changing) and more *realistic* (higher-fidelity
rendering), building directly on that work.

## Goals

1. **Continuous sky** — the sky currently snaps between four fixed palettes
   (night / dawn / day / dusk). Replace that with a smooth, continuous colour
   function of the sun's real position, so the sky flows imperceptibly all day
   and is genuinely different every minute.
2. **Approach Glow** — in the final ~15 minutes before a prayer, the next-prayer
   element builds a growing glow; the face leans in as the time comes.
3. **Realistic celestial** — the sun gets a soft layered corona; the crescent
   moon gets faint earthshine on its dark limb; stars get varied brightness.
4. **Live seconds** — a quiet per-second indicator (a small sweeping mark) so the
   face visibly ticks.

## Non-Goals

- Health complications, new faces, new calculation methods.

## Architecture

Built on the existing shared modules; the four faces consume the changes.

```
source/
├── Sky.mc          MODIFY — continuous colour function (replaces 4 buckets)
├── FaceKit.mc      MODIFY — corona sun, earthshine crescent, varied stars,
│                            drawApproachGlow; drawSkyLayer signature update
├── PrayerState.mc  MODIFY — expose minutesToNext (for approach detection)
├── GarminPrayerTimesView.mc  MODIFY — onPartialUpdate for the live seconds
└── faces/*.mc      MODIFY — adopt continuous sky + approach glow + seconds mark
```

### Continuous sky

`Sky` stops returning a discrete phase. Instead it defines keyframe colours at
key sun positions (deep night, pre-dawn, sunrise, midday, sunset, dusk) and
interpolates between the two surrounding keyframes with `FaceKit.lerpColor`,
based on where `nowHour` falls relative to `sunrise` / `sunset`. Public surface:
- `topColor(nowHour, sunrise, sunset, weather)` — continuous top colour.
- `horizonColor(nowHour, sunrise, sunset, weather)` — continuous horizon colour.
- `glowColor(nowHour, sunrise, sunset)` — continuous sun-glow colour.
- `starAlpha(nowHour, sunrise, sunset)` — 0.0 (full day) … 1.0 (deep night),
  so stars can fade in/out instead of popping. Weather tinting is unchanged.

`FaceKit.drawSkyLayer` is updated to call the new signatures and to fade the
starfield by `starAlpha` rather than an on/off `showStars`.

### Approach Glow

`PrayerState` exposes `minutesToNext` (Number) — minutes until the next prayer.
`FaceKit.drawApproachGlow(dc, minutesToNext)` draws nothing when more than 15
minutes remain; inside 15 minutes it draws a soft halo around the screen edge
whose intensity scales as the time shrinks. Each face calls it once.

### Realistic celestial

- `drawSun` — add two faint outer corona rings beneath the existing disc.
- `drawCrescent` — draw a very dim full-disc (earthshine) before carving the
  crescent, so the moon's dark limb is faintly visible.
- `drawStarfield` — vary star brightness (the fixed star table gains a
  brightness value per star); accepts an alpha factor for fade.

### Live seconds

`GarminPrayerTimesView` implements `onPartialUpdate(dc)` — called about once per
second. It draws a small mark that advances each second around the bezel. The
drawn region is kept minimal to stay within Connect IQ's partial-update power
budget. The mark is not drawn in always-on mode.

## Connect IQ Realities

- No gradient fill / no alpha — gradients are colour bands, glows are concentric
  circles, "alpha" is simulated by interpolating toward the background colour.
- Always-on mode stays pure black and minimal; the seconds mark and rich sky do
  not run in low power.
- **Live-seconds risk:** per-second drawing runs on a strict power budget. The
  mark is deliberately tiny. If simulator/device testing shows it is too costly,
  it is demoted to an optional setting (default off) — this is a known fallback,
  not a blocker.

## Build Order

1. `Sky` continuous colour function + `FaceKit.lerpColor` already present.
2. `FaceKit` — corona, earthshine, varied stars, `drawApproachGlow`, updated
   `drawSkyLayer`.
3. `PrayerState.minutesToNext`.
4. `GarminPrayerTimesView.onPartialUpdate` — live seconds.
5. Apply continuous sky + approach glow to each of the four faces.
6. Cross-device verification and store package.

## Verification

- Unit tests pass (continuous `Sky` colour at sample times; `minutesToNext`).
- Builds clean on `epix2pro42mm`, `epix2pro47mm`, `venu3`.
- Simulator: each face checked at several simulated times — the sky transition
  is smooth, the approach glow appears inside 15 minutes, the seconds mark
  advances, sun/moon/stars render with the new fidelity.
- Always-on mode stays black and minimal.
