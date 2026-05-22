# Living, Weather-Aware Faces

**Date:** 2026-05-21
**Status:** Approved design — ready for implementation planning
**Branch:** `enhance/living-weather-faces` (off `redesign/multi-face-watch-faces`)

## Context & Problem

The four watch faces (Twilight Horizon, Solar Dial, Crescent Month, Gradient
Sky Arc) are clean but static — they redraw once a minute and look identical at
03:00 and at 18:00. This round makes all four feel alive and connected to the
real world, drawing on Apple's design language (Solar Analog, Astronomy,
Typograph): light, depth, restraint.

## Goals

Three capabilities, woven into **all four existing faces** — no new faces:

1. **Real-time weather** — current temperature and condition from Garmin's
   Weather API, shown on the face; the sky palette reacts to conditions.
2. **Living time-of-day** — the face's background light and colour shift with
   the real sun: dawn warmth low, midday light high, dusk amber, night with
   stars. A soft sun-glow travels the face across the day.
3. **Apple polish** — refined typographic layout, soft depth via layered glows,
   a starfield at night.

## Non-Goals (a later round)

- "Approach Glow" — escalation as a prayer nears.
- A per-second seconds indicator.
- Health complications (HR, Body Battery, steps).

These are deliberately deferred to keep this round's PR focused.

## The Connect IQ Reality

The implementation must respect three hard platform facts:

- **No gradient fill, no alpha.** `Dc` cannot fill a gradient or blend
  transparency. The time-of-day background is rendered as a stack of ~40 thin
  horizontal colour bands (a stepped gradient); the sun-glow as concentric
  solid circles in progressively brighter colours. `onUpdate()` runs about once
  a minute, so the extra draw calls are affordable.
- **AMOLED battery & burn-in.** The rich sky renders **only in active mode**.
  Always-on (low-power) mode stays pure black with the existing minimal layout.
- **Weather can be absent.** `Weather.getCurrentConditions()` returns `null`
  when the watch has not synced weather from the phone. Faces must degrade
  gracefully — hide the temperature, use a clear-sky default — never error or
  blank.

## Architecture

The three capabilities apply to every face, so they live in shared modules; the
four face files consume them. The audited prayer/Hijri data layer is untouched.

```
source/
├── WeatherData.mc   CREATE — wraps Toybox.Weather; safe when unavailable
├── Sky.mc           CREATE — time-of-day "sky engine": palette + glow + stars
├── Theme.mc         MODIFY — twilight colour ramps, weather tints
├── FaceKit.mc       MODIFY — drawSky, drawLightGlow, drawStarfield, lerpColor,
│                             weather glyph
├── Tests.mc         MODIFY — unit tests for lerpColor and Sky.phase
└── faces/
    ├── HorizonFace.mc      MODIFY — sky behind dome, travelling glow, weather
    ├── SolarDialFace.mc    MODIFY — sky behind ring, weather
    ├── CrescentFace.mc     MODIFY — night sky + stars around the crescent
    └── GradientArcFace.mc  MODIFY — background driven by the real palette
```

### Module responsibilities

- **`WeatherData`** — wraps `Toybox.Weather`. Public:
  - `isAvailable() as Boolean` — true if current conditions exist.
  - `temperature() as Number?` — degrees Celsius, or `null`.
  - `condition() as Number` — a simplified category: `0` clear, `1` cloudy,
    `2` rain, `3` snow. The many `Weather.CONDITION_*` codes map into these four;
    unknown/unavailable maps to `0` clear.
  - Reads conditions once per `onUpdate` (cheap); no caching needed.
  - Note: `Toybox.Weather` requires no `uses-permission`; if a build error says
    otherwise, add it to `manifest.xml`.

- **`Sky`** — the time-of-day engine. Stateless pure functions:
  - `phase(nowHour, sunrise, sunset) as Number` — `0` night, `1` dawn,
    `2` day, `3` dusk. Dawn = the hour before sunrise; dusk = the hour after
    sunset; day between; night otherwise.
  - `topColor(phase, weatherCondition) as Number` — background colour at the
    top of the screen.
  - `horizonColor(phase, weatherCondition) as Number` — background colour at
    the horizon line / screen bottom.
  - `glowColor(phase) as Number` — colour of the travelling sun-glow.
  - `showStars(phase) as Boolean` — true at night and dawn.
  - Weather shifts the palette: cloudy desaturates toward grey; rain darkens
    and cools; snow lightens and cools. Colours come from `Theme`.

- **`Theme`** *(extended)* — adds the twilight ramp constants (night / dawn /
  day / dusk, each a top and horizon colour) and weather-tint constants.

- **`FaceKit`** *(extended)* — new rendering primitives:
  - `lerpColor(c1, c2, t) as Number` — linear interpolate two RGB colours
    (`t` 0.0–1.0). The basis of band rendering. **Pure — unit-tested.**
  - `drawSky(dc, topColor, horizonColor)` — fills the screen with ~40 banded
    strips from `topColor` to `horizonColor` using `lerpColor`. Active mode only.
  - `drawLightGlow(dc, x, y, color)` — a soft bloom: 3–4 concentric filled
    circles from a wide dim ring to a bright core.
  - `drawStarfield(dc)` — scatters ~26 small stars at fixed (deterministic)
    positions and varied sizes, so they never jump between minutes.
  - `drawWeatherGlyph(dc, x, y, condition)` — a small sun / cloud / rain / snow
    icon drawn from primitives.

- **Face files** — each `draw()` begins by painting the living sky
  (`FaceKit.drawSky` with colours from `Sky`) instead of a flat black clear,
  then draws stars if night, then its existing elements, then the travelling
  sun-glow, then the weather readout, with the refined text layout.
  `drawLowPower()` is unchanged — black background, minimal elements.

### Data flow

```
PrayerState (existing: dayFraction, sunrise, sunset, moon, prayer data)
WeatherData  → temperature, condition
                   │
Face.draw():  Sky.phase()/topColor()/horizonColor()/glowColor()/showStars()
              FaceKit.drawSky(...)  → banded background
              FaceKit.drawStarfield() if night
              ... existing face elements ...
              FaceKit.drawLightGlow(...) at the sun position (dayFraction)
              FaceKit.drawWeatherGlyph(...) + temperature
```

`dayFraction` (already on `PrayerState`) places the sun-glow during the day.

## Per-Face Application

- **Twilight Horizon** — the banded sky sits behind the dome; the sun-glow rides
  the dome at `dayFraction`; stars fill the sky above the dome at night.
- **Solar Dial** — the banded sky sits behind the 24h ring; the lit/dark band
  colours take their tint from `Sky`; weather sits in the centre stack.
- **Crescent Month** — emphasises the night sky: starfield around the crescent,
  deep-indigo background; weather near the Hijri date.
- **Gradient Sky Arc** — the background itself is the `Sky` palette, so the
  whole face and the arc move together through the day.

## Build Order

1. `WeatherData`, `Sky`, `Theme` ramps, `FaceKit` primitives, unit tests for
   `lerpColor` and `Sky.phase`.
2. Apply to **Twilight Horizon**; verify in the simulator (active + always-on).
3. Apply to **Solar Dial**.
4. Apply to **Crescent Month**.
5. Apply to **Gradient Sky Arc**.
6. Cross-device verification (390 / 416 / 454) and store package.

## Verification

- Unit tests pass (`./scripts/dev.sh test`) — existing 21 plus the new
  `lerpColor` / `Sky.phase` tests.
- Builds clean on `epix2pro42mm`, `epix2pro47mm`, `venu3`.
- In the simulator, each face is checked at several simulated states: day,
  night, and with weather present vs. absent. The background, glow, stars, and
  weather readout render correctly and the prayer information stays legible.
- Always-on mode confirmed to stay black and minimal on every face.
