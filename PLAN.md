# Garmin Prayer Times Watch Face — Implementation Plan

## Context

Build a prayer times watch face for Garmin Epix Pro Sapphire, porting the logic from the existing Mac menu bar app at `/Users/almokhtarbekkour/Developer.nosync/mvps/mac-prayer-times/`. The existing Garmin prayer apps are widgets (slow, require navigation). A watch face is always visible — zero lag, zero scrolling.

## Project Setup

**Location:** `/Users/almokhtarbekkour/Developer.nosync/mvps/garmin-prayer-times/`

**Prerequisites:** Install Connect IQ SDK via VS Code "Monkey C" extension.

**Target device:** Garmin Epix Pro (Gen 2) — AMOLED, 416x416px round display

## Architecture

```
garmin-prayer-times/
├── manifest.xml                    # App metadata, device targets, permissions
├── monkey.jungle                   # Build config
├── resources/
│   ├── properties.xml              # User settings definitions
│   ├── settings.xml                # Phone-side settings UI
│   └── strings.xml                 # String resources
└── source/
    ├── GarminPrayerTimesApp.mc     # App entry point
    ├── GarminPrayerTimesView.mc    # Watch face view (onLayout, onUpdate)
    ├── PrayerCalculator.mc         # Core prayer time math (port from praytimes.org)
    ├── HijriCalendar.mc            # Gregorian → Hijri date conversion
    └── PrayerState.mc              # State: cached times, next prayer, countdown
```

## Implementation Steps

### Step 1: Scaffold the Connect IQ project
- Create `manifest.xml` targeting `epix2pro` with permissions: `Location`
- Create `monkey.jungle` build file
- Create app entry point (`AppBase` subclass)
- Create watch face view (`WatchFace` subclass) with stub `onUpdate()`

### Step 2: Implement `PrayerCalculator.mc` — prayer time math engine
Port the praytimes.org algorithm to Monkey C using `Toybox.Math`:

**Julian Date:**
```
JD = 1720994.5 + INT(365.25*Y) + INT(30.6001*(M+1)) + B + D
```

**Sun Declination:**
```
T = 2 * PI * (JD - 2451545) / 365.25
DELTA = 0.37877 + 23.264*sin(57.297*T - 79.547) + 0.3812*sin(2*57.297*T - 82.682) + 0.17132*sin(3*57.297*T - 59.722)
```

**Equation of Time:**
```
U = (JD - 2451545) / 36525
L0 = 280.46607 + 36000.7698*U
ET1000 = -(1789+237*U)*sin(L0) - (7146-62*U)*cos(L0) + (9934-14*U)*sin(2*L0) - (29+5*U)*cos(2*L0) + (74+10*U)*sin(3*L0) + (320-4*U)*cos(3*L0) - 212*sin(4*L0)
ET = ET1000 / 1000
```

**Transit (Dhuhr):**
```
TT = 12 + timezone - (longitude / 15) - (ET / 60)
```

**Hour Angle for twilight prayers:**
```
cos(HA) = (sin(altitude) - sin(lat)*sin(decl)) / (cos(lat)*cos(decl))
```

**Each prayer:**
- Fajr = TT - HA(fajr_angle) / 15
- Sunrise = TT - HA(-0.8333) / 15
- Dhuhr = TT (+ small correction)
- Asr = TT + HA(acot(shadow_factor + tan(|decl - lat|))) / 15
- Maghrib = TT + HA(-0.8333) / 15
- Isha = TT + HA(isha_angle) / 15

**11 calculation methods (same as Mac app):**

| Method | Fajr Angle | Isha Angle/Rule |
|--------|-----------|-----------------|
| ISNA | 15.0 | 15.0 |
| MWL | 18.0 | 17.0 |
| Egyptian | 19.5 | 17.5 |
| Umm al-Qura | 18.5 | 90 min after Maghrib |
| Dubai | 18.2 | 18.2 |
| Karachi | 18.0 | 18.0 |
| Kuwait | 18.0 | 17.5 |
| Qatar | 18.0 | 90 min after Maghrib |
| Singapore | 20.0 | 18.0 |
| Tehran | 17.7 | 14.0 |
| Turkey | 18.0 | 17.0 |

### Step 3: Implement `HijriCalendar.mc` — Gregorian to Hijri conversion
Use the Kuwaiti/tabular algorithm (no lookup tables needed, pure math):
- Convert Gregorian → Julian Day Number
- Convert JDN → Hijri (year, month, day)
- Month name lookup array for display

### Step 4: Implement `PrayerState.mc` — state management
- Cache today's 6 prayer times (recalculate once per day or on location change)
- Track `currentDateKey` to detect day change
- Determine next prayer (skip Sunrise, handle tomorrow's Fajr after Isha)
- Compute countdown string ("1h 23m" / "45m")
- Friday → "Jumuah" instead of "Dhuhr"
- Iqama offset logic (configurable per prayer)

### Step 5: Implement `GarminPrayerTimesView.mc` — watch face rendering
Draw on the `Dc` (device context) in `onUpdate()`:

**Layout (416x416 round AMOLED):**
```
┌─────────────────────────────┐
│     16 Sha'ban 1446 AH      │  y=35, small font, center
│                              │
│          14:37               │  y=80, large bold font
│         Sunday               │  y=140, medium font
│                              │
│   ▓▓▓▓▓▓▓▓▓░░░░  72%       │  y=175, arc/bar, progress to next
│     Asr in 1h 23m           │  y=200, medium font, accent color
│                              │
│   Fajr      05:12   ✓       │  y=235, rows ~28px apart
│   Sunrise   06:41   ✓       │
│   Dhuhr     12:15   ✓       │
│   Asr       15:48   ←       │  highlight current/next
│   Maghrib   18:22           │
│   Isha      19:45           │
│                              │
│   🔋 82%        ❤ 72        │  y=410, small font
│   📍 Casablanca             │  (or GPS coords if no city)
└─────────────────────────────┘
```

**Drawing strategy:**
- `dc.drawText()` for all text elements
- `dc.drawArc()` for progress bar (circular arc suits the round display)
- Use color: dim gray for passed prayers, white for upcoming, accent for next prayer
- `onUpdate()` only draws cached data — no calculation in render loop

**Always-On Display (low power):**
- Simplified layout: time + next prayer + countdown only
- Minimal pixels lit (AMOLED burn-in protection)
- No progress bar, no full prayer list

### Step 6: GPS location via `Toybox.Position`
- Request location on app start
- Cache coordinates — only re-request if null or on manual refresh
- Use `Position.getInfo()` to get lat/lng
- Fall back to last known position if GPS unavailable

### Step 7: Settings via phone app
**`properties.xml`** — define configurable properties:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| calcMethod | number | 0 | Calculation method index (0-10) |
| iqamaFajr | number | 20 | Fajr iqama offset (minutes) |
| iqamaDhuhr | number | 15 | Dhuhr offset |
| iqamaAsr | number | 10 | Asr offset |
| iqamaMaghrib | number | 5 | Maghrib offset |
| iqamaIsha | number | 15 | Isha offset |
| showIqama | boolean | true | Show iqama times |
| accentColor | number | 0xFF4444 | Accent color for next prayer |
| asrMethod | number | 0 | 0=Shafi, 1=Hanafi |

**`settings.xml`** — phone-side UI for these settings (list pickers, numeric steppers)

### Step 8: Testing & deployment
- Test in Connect IQ Simulator (Epix Pro device profile)
- Verify prayer times match the Mac app for same location/method
- Side-load to watch via USB for real-device testing
- Verify AMOLED always-on mode

## Key Technical Decisions

1. **Watch face, not app** — always visible, no navigation, instant. Trade-off: no vibration alerts from the face itself.
2. **Local calculation, no API** — all math on-device using GPS. Works offline, no phone needed.
3. **Calculate once per day** — recompute only on day change or location change. `onUpdate()` just draws cached values = fast.
4. **Port praytimes.org math** — well-documented, same underlying algorithm as adhan-swift. Pure math, no dependencies.
5. **Hijri via tabular algorithm** — lightweight, no lookup tables, accurate enough for display.

## Constraint: No Vibration on Watch Face

`Toybox.Attention` is unavailable for watch faces. Options for future:
- Build a companion Connect IQ **app** that runs alongside for vibration alerts
- Use background temporal events (if supported on Epix Pro)
- For now: visual-only — the watch face shows prayer times, user glances at wrist

## Verification

1. Run in Connect IQ Simulator → verify layout renders correctly on Epix Pro profile
2. Compare calculated prayer times with Mac app output for same GPS coords + method
3. Verify day rollover (tomorrow's Fajr after Isha)
4. Test all 11 calculation methods
5. Verify settings changes reflect on face
6. Side-load to actual Epix Pro and verify AMOLED always-on mode
