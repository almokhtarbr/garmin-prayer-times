# Development Log

## 2026-02-15 — Initial Implementation + Audit

### Step 1: Scaffold — DONE
- Created `manifest.xml`, `monkey.jungle`, app entry point, watch face view stub
- Target: Epix Pro (Gen 2) AMOLED 416x416

### Step 2: PrayerCalculator.mc — DONE + BUGS FIXED
- Ported praytimes.org algorithm to Monkey C
- All 11 calculation methods with correct angles verified against reference
- Julian Date, Sun Position, Hour Angle, Transit — all verified correct

**Bugs found & fixed:**
- **[CRITICAL] Asr formula error**: Used `acos(sin(acot(...)))` which gives `|cos(acot(x))|` instead of `sin(acot(x))`. Fixed to pass `-acot(angle)` to hourAngle(), matching the sign convention of all other callers.
- **[CRITICAL] Timezone as integer**: `timezone as Number` truncates fractional timezones (India +5:30, Iran +3:30, Nepal +5:45). Changed to `Double`. Also fixed integer division in PrayerState.mc: `/ 3600` → `/ 3600.0`.
- **[LOW] `static const` with `Math.PI`**: Replaced with literal values to avoid potential older SDK issues.

### Step 3: HijriCalendar.mc — DONE, VERIFIED
- Kuwaiti/tabular algorithm, pure math
- JDN calculation verified, no overflow risk (JDN ~2.4M vs 32-bit int max ~2.1B)
- All 12 month names correct and in order
- Integer arithmetic confirmed safe for modern dates

### Step 4: PrayerState.mc — DONE + BUGS FIXED
- Caches today's 6 prayer times, recalculates once/day or on location change
- Next prayer detection skipping Sunrise — verified correct
- Tomorrow's Fajr rollover — verified correct
- Friday/Jumuah detection — `Gregorian.DAY_FRIDAY` confirmed valid (value=6)

**Bugs found & fixed:**
- **[CRITICAL] Timezone integer division**: `timeZoneOffset / 3600` → `timeZoneOffset.toDouble() / 3600.0`
- **[LOW] Missing progress clamp**: Added `if (progressFraction > 1.0f)` clamp in tomorrow-Fajr path
- **[LOW] Uninitialized prevTime**: Changed to `var prevTime = 0.0;`
- **[LOW] Hijri recalculated every frame**: Moved inside date-change check
- **[LOW] Deprecated getProperty()**: Migrated to `Application.Properties.getValue()`

### Step 5: GarminPrayerTimesView.mc — DONE + BUGS FIXED
- Full watch face rendering: Hijri date, clock, day, progress arc, countdown, prayer list, status bar
- Always-on low-power mode for AMOLED

**Bugs found & fixed:**
- **[CRITICAL] `TEXT_JUSTIFY_VCENTER` doesn't exist**: Removed all usages, adjusted Y coords by subtracting `fontHeight/2` for vertical centering
- **[CRITICAL] `drawArc()` angle math inverted**: Rewrote to use `ARC_COUNTER_CLOCKWISE` with correct start/end angles
- **[MODERATE] `FONT_NUMBER_HOT`/`FONT_NUMBER_MILD` MIP-incompatible**: Removed non-AMOLED devices from manifest (fenix7, fenix7pro)
- **[MODERATE] Hardcoded 416x416 layout**: Changed to proportional layout based on `dc.getHeight()`
- **[MODERATE] Position accuracy check**: Added `accuracy != QUALITY_NOT_AVAILABLE` check
- **[MODERATE] LOCATION_DISABLE callback**: Pass `null` instead of method reference

### Step 6: GPS Location — DONE
- One-shot GPS for battery efficiency
- Falls back to cached/last-known position on app start
- Added accuracy check to avoid (0,0) coordinates

### Step 7: Settings — DONE + BUGS FIXED
- 9 configurable properties via phone app
- 11 calculation methods in list picker

**Bugs found & fixed:**
- **[MODERATE] Missing XML namespace**: Added `iq` namespace to properties.xml and settings.xml
- **[MODERATE] Missing Sensor permission**: Added to manifest

### Step 8: Testing & Deployment — PENDING
- Requires Connect IQ SDK installation
- Test in simulator with Epix Pro profile
- Cross-verify prayer times with Mac app
- Side-load to actual watch

### Feature Parity with Mac App
- All 11 calculation methods — MATCH
- Default iqama offsets — MATCH
- Next prayer logic — MATCH (minor: Garmin switches to tomorrow Fajr at adhan time, Mac waits for iqama)
- Friday/Jumuah — MATCH
- Countdown format ("Xh Ym") — MATCH
- Hijri date — MATCH

**Mac features NOT ported (by design):**
- Adhan audio playback (watch face can't use Attention API)
- System notifications (watch face limitation)
- Iqama countdown phase (post-adhan countdown to iqama)
- Location name display (no reverse geocoding on Garmin)

**Garmin-only features:**
- Asr juristic method toggle (Shafi/Hanafi)
- Accent color customization
- Progress arc between prayers
- Show/hide iqama toggle
- AMOLED always-on low-power mode
