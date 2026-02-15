# Garmin Prayer Times Watch Face

A prayer times watch face for Garmin Epix Pro (Gen 2) and compatible AMOLED devices. All prayer time calculations run on-device using GPS — no internet required.

## Features

- **6 daily prayer times**: Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha
- **Next prayer countdown** with progress arc
- **Hijri calendar date** (Kuwaiti/tabular algorithm)
- **11 calculation methods**: ISNA, MWL, Egyptian, Umm al-Qura, Dubai, Karachi, Kuwait, Qatar, Singapore, Tehran, Turkey
- **Iqama time offsets** (configurable per prayer)
- **Asr calculation**: Shafi (standard) or Hanafi
- **Friday/Jumuah** detection
- **AMOLED always-on** display (simplified low-power mode)
- **Configurable accent color**

## Architecture

```
source/
├── GarminPrayerTimesApp.mc     # App entry, GPS listener
├── GarminPrayerTimesView.mc    # Watch face rendering
├── PrayerCalculator.mc         # Prayer time math (praytimes.org port)
├── HijriCalendar.mc            # Gregorian → Hijri conversion
└── PrayerState.mc              # State management & caching
```

## Settings (via Garmin Connect phone app)

| Setting | Default | Description |
|---------|---------|-------------|
| Calculation Method | ISNA | Choose from 11 regional methods |
| Asr Method | Shafi | Shafi (standard) or Hanafi |
| Show Iqama | On | Display iqama times |
| Iqama Offsets | Varies | Minutes after adhan per prayer |
| Accent Color | Red | Highlight color for next prayer |

## Building & Running

### VS Code
1. Install [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and VS Code "Monkey C" extension
2. Open this folder in VS Code
3. Select target device (Epix Pro 47mm recommended)
4. Build: `Ctrl+Shift+B` or `Cmd+Shift+B`
5. Run in simulator: `F5`

### CLI
```bash
# Set SDK path
SDK_BIN="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc/bin"

# Build
"$SDK_BIN/monkeyc" -o bin/GarminPrayerTimes.prg -f monkey.jungle \
  -y "$HOME/Library/Application Support/Garmin/ConnectIQ/developer_key" \
  -d epix2pro47mm -l 0

# Launch simulator (first time / if not already running)
"$SDK_BIN/connectiq" &

# Run on simulator
"$SDK_BIN/monkeydo" bin/GarminPrayerTimes.prg epix2pro47mm
```

> **Note:** The simulator does not grant GPS permission to watch faces. The app falls back to hardcoded coordinates (Quebec City) when no GPS is available. On real hardware, GPS works normally.

## Design Decisions

- **Watch face** (not widget/app) — always visible, zero navigation
- **On-device calculation** — works offline, no API calls
- **Calculate once per day** — recalculate only on date or location change
- **praytimes.org algorithm** — same math as adhan-swift, battle-tested
