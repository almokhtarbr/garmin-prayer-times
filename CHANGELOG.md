# Changelog

All notable changes to this project. Format based on
[Keep a Changelog](https://keepachangelog.com/).

## [0.3.0] — 2026-05-21 — Dynamic & realistic

### Added
- Continuous time-of-day sky — the background flows smoothly all day instead of
  snapping between fixed palettes.
- Approach glow — a halo builds at the bezel through the final 15 minutes before
  each prayer.
- Live seconds indicator — a dot fills a ring around the bezel each minute.
- Sun corona; stars now vary in brightness and fade through twilight.

### Changed
- The crescent moon is scanline-rendered with faint earthshine.

### Fixed
- The crescent no longer leaves a background-coloured blob on a coloured sky.

## [0.2.0] — 2026-05-21 — Living, weather-aware faces

### Added
- Living time-of-day sky behind every face — colour and light shift with the
  sun; a starfield appears at night.
- Real-time weather (temperature + condition) from Garmin's Weather API, with a
  graceful fallback when no weather has synced.

## [0.1.0] — 2026-05-21 — Multi-face redesign

### Added
- Four switchable watch faces — Twilight Horizon, Solar Dial, Crescent Month,
  Gradient Sky Arc — selected by a new Face Style setting.
- Shared modules: `FaceKit` (geometry + drawing), `Theme` (palette),
  `MoonPhase` (lunar phase).

### Changed
- Rebuilt the UI layer with a slim face dispatcher; the audited prayer-time and
  Hijri data layer is unchanged.

### Fixed
- Prayer times computed from an invalid `(180,180)` GPS sentinel — coordinates
  are now range-validated, with a fallback to the default location.
