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
    "$SDK/bin/monkeydo" "bin/GarminPrayerTimesTest.prg" "$DEVICE" -t
    ;;
  sim)
    "$SDK/bin/monkeydo" "bin/GarminPrayerTimes.prg" "$DEVICE"
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
