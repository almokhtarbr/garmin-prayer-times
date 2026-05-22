import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// State manager: caches today's prayer times, tracks next prayer, countdown.
// Recalculates once per day or on location/settings change.

class PrayerState {
    // Prayer names
    static const PRAYER_NAMES = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"];
    static const PRAYER_COUNT = 6;

    // Indices
    static const FAJR = 0;
    static const SUNRISE = 1;
    static const DHUHR = 2;
    static const ASR = 3;
    static const MAGHRIB = 4;
    static const ISHA = 5;

    // Prayer status values
    static const STATUS_PASSED   = 0;
    static const STATUS_NEXT     = 1;
    static const STATUS_UPCOMING = 2;

    // Cached prayer times as hours (fractional) for today
    var todayTimes as Array?;
    // Tomorrow's Fajr time (hours, fractional)
    var tomorrowFajr as Double?;

    // Current location
    var latitude as Double?;
    var longitude as Double?;

    // Date key for cache invalidation ("YYYYMMDD")
    var currentDateKey as String = "";

    // Next prayer index (0-5), or -1 if tomorrow's Fajr
    var nextPrayerIndex as Number = -1;
    // Is the next prayer tomorrow's Fajr?
    var isNextTomorrowFajr as Boolean = false;

    // Countdown string (e.g. "1h 23m", "45m")
    var countdownString as String = "";
    // Iqama countdown string (e.g. "iqama in 23m")
    var iqamaCountdownString as String = "";
    // Next prayer name for display
    var nextPrayerName as String = "";

    // Hijri date string
    var hijriDate as String = "";

    // Progress fraction (0.0 - 1.0) between current and next prayer
    var progressFraction as Float = 0.0f;

    // Derived data for the faces
    var sunrise as Double = 0.0d;
    var sunset as Double = 0.0d;
    var dayFraction as Float = 0.0f;
    var prayerStatus as Array = [0, 0, 0, 0, 0, 0];
    var moonIllumination as Float = 0.0f;
    var moonWaxing as Boolean = true;

    // Minutes until the next prayer (for the approach glow).
    var minutesToNext as Number = 999;

    // Settings cache
    var calcMethod as Number = 0;
    var asrMethod as Number = 0;
    var showIqama as Boolean = true;
    var iqamaOffsets as Array = [20, 0, 15, 10, 5, 15];

    function initialize() {
        loadSettings();
    }

    function loadSettings() {
        var val;

        val = Properties.getValue("calcMethod");
        calcMethod = (val != null) ? (val as Number) : 0;

        val = Properties.getValue("asrMethod");
        asrMethod = (val != null) ? (val as Number) : 0;

        val = Properties.getValue("showIqama");
        showIqama = (val != null) ? (val as Boolean) : true;

        val = Properties.getValue("iqamaFajr");
        var iFajr = (val != null) ? (val as Number) : 20;

        val = Properties.getValue("iqamaDhuhr");
        var iDhuhr = (val != null) ? (val as Number) : 15;

        val = Properties.getValue("iqamaAsr");
        var iAsr = (val != null) ? (val as Number) : 10;

        val = Properties.getValue("iqamaMaghrib");
        var iMaghrib = (val != null) ? (val as Number) : 5;

        val = Properties.getValue("iqamaIsha");
        var iIsha = (val != null) ? (val as Number) : 15;

        iqamaOffsets = [iFajr, 0, iDhuhr, iAsr, iMaghrib, iIsha];
    }

    function onSettingsChanged() {
        loadSettings();
        // Force recalculation
        currentDateKey = "";
        update();
    }

    function updateLocation(lat as Double, lng as Double) {
        // Ignore invalid coordinates (e.g. a no-GPS-fix sentinel).
        if (!isValidLocation(lat, lng)) { return; }
        // Only recalculate if location changed significantly (>~100m)
        if (latitude != null && longitude != null) {
            var dlat = lat - (latitude as Double);
            if (dlat < 0.0) { dlat = -dlat; }
            var dlng = lng - (longitude as Double);
            if (dlng < 0.0) { dlng = -dlng; }
            if (dlat < 0.001 && dlng < 0.001) {
                return;
            }
        }
        latitude = lat;
        longitude = lng;
        // Force recalculation
        currentDateKey = "";
        update();
    }

    // Main update — called from onUpdate(). Recalculates if needed, then updates state.
    function update() {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var year = now.year as Number;
        var month = now.month as Number;
        var day = now.day as Number;
        var dateKey = year.toString() + pad2(month) + pad2(day);

        // Recalculate prayer times if date changed or not yet calculated
        if (!dateKey.equals(currentDateKey) && latitude != null && longitude != null) {
            recalculate(year, month, day);
            currentDateKey = dateKey;
            // Update Hijri date only on date change
            hijriDate = HijriCalendar.format(year, month, day);
            var hParts = HijriCalendar.toHijri(year, month, day);
            var hDay = hParts[2] as Number;
            moonIllumination = MoonPhase.illumination(hDay);
            moonWaxing = MoonPhase.isWaxing(hDay);
        }

        // Update next prayer, countdown, and derived face data
        if (todayTimes != null) {
            updateNextPrayer(now);
            var hr = (now.hour as Number).toDouble()
                   + (now.min as Number).toDouble() / 60.0;
            dayFraction = computeDayFraction(hr, sunrise, sunset);
            prayerStatus = computeStatus(todayTimes as Array, hr,
                nextPrayerIndex, isNextTomorrowFajr);
        }
    }

    hidden function recalculate(year as Number, month as Number, day as Number) {
        // Use floating-point division to preserve fractional timezone offsets
        // (e.g. India +5:30 = 5.5, Iran +3:30 = 3.5)
        var tz = System.getClockTime().timeZoneOffset.toDouble() / 3600.0;
        var asrFactor = (asrMethod == 0) ? 1 : 2;

        todayTimes = PrayerCalculator.calculate(
            year, month, day,
            latitude as Double, longitude as Double,
            tz, calcMethod, asrFactor
        );

        if (todayTimes != null) {
            sunrise = (todayTimes as Array)[SUNRISE] as Double;
            sunset  = (todayTimes as Array)[MAGHRIB] as Double;
        }

        // Also calculate tomorrow's Fajr
        var tomorrow = Time.now().add(new Time.Duration(86400));
        var tmrw = Gregorian.info(tomorrow, Time.FORMAT_SHORT);
        var tmrwTimes = PrayerCalculator.calculate(
            tmrw.year as Number, tmrw.month as Number, tmrw.day as Number,
            latitude as Double, longitude as Double,
            tz, calcMethod, asrFactor
        );
        if (tmrwTimes != null) {
            tomorrowFajr = tmrwTimes[FAJR] as Double;
        }
    }

    hidden function updateNextPrayer(now as Gregorian.Info) {
        var hour = (now.hour as Number).toDouble()
                 + (now.min as Number).toDouble() / 60.0
                 + (now.sec as Number).toDouble() / 3600.0;

        var times = todayTimes as Array;
        nextPrayerIndex = -1;
        isNextTomorrowFajr = false;

        // Find next upcoming prayer (skip Sunrise for "next prayer" purpose)
        for (var i = 0; i < PRAYER_COUNT; i++) {
            if (i == SUNRISE) {
                continue; // skip sunrise
            }
            if (hour < (times[i] as Double)) {
                nextPrayerIndex = i;
                break;
            }
        }

        // All prayers passed — next is tomorrow's Fajr
        if (nextPrayerIndex == -1) {
            isNextTomorrowFajr = true;
            nextPrayerName = "Fajr";

            if (tomorrowFajr != null) {
                // Remaining = (24 - now) + tomorrowFajr
                var remaining = (24.0 - hour) + (tomorrowFajr as Double);
                countdownString = formatCountdown(remaining);
                minutesToNext = (remaining * 60.0).toNumber();
                // Progress: from Isha to tomorrow's Fajr
                var ishaTime = times[ISHA] as Double;
                var totalSpan = (24.0 - ishaTime) + (tomorrowFajr as Double);
                var elapsed = hour - ishaTime;
                if (elapsed < 0.0) { elapsed = elapsed + 24.0; }
                progressFraction = (totalSpan > 0.0) ? (elapsed / totalSpan).toFloat() : 0.0f;
                if (progressFraction > 1.0f) { progressFraction = 1.0f; }
                // Iqama countdown for tomorrow's Fajr
                updateIqamaCountdown(hour, tomorrowFajr as Double, FAJR, true);
            } else {
                countdownString = "--";
                progressFraction = 0.0f;
                iqamaCountdownString = "";
                minutesToNext = 999;
            }
            return;
        }

        // Friday → rename Dhuhr to Jumuah
        var dayOfWeek = now.day_of_week;
        if (nextPrayerIndex == DHUHR && dayOfWeek == Gregorian.DAY_FRIDAY) {
            nextPrayerName = "Jumuah";
        } else {
            nextPrayerName = PRAYER_NAMES[nextPrayerIndex] as String;
        }

        // Countdown
        var nextTime = times[nextPrayerIndex] as Double;
        var remaining = nextTime - hour;
        if (remaining < 0.0) { remaining = remaining + 24.0; }
        countdownString = formatCountdown(remaining);
        minutesToNext = (remaining * 60.0).toNumber();

        // Iqama countdown
        updateIqamaCountdown(hour, nextTime, nextPrayerIndex, false);

        // Progress between previous and next prayer
        var prevIndex = findPreviousPrayer(nextPrayerIndex);
        var prevTime = 0.0;
        if (prevIndex >= 0) {
            prevTime = times[prevIndex] as Double;
        } else {
            // Before Fajr — previous is yesterday's Isha (approximate as Isha - 24)
            prevTime = (times[ISHA] as Double) - 24.0;
        }
        var totalSpan = nextTime - prevTime;
        if (totalSpan <= 0.0) { totalSpan = totalSpan + 24.0; }
        var elapsed = hour - prevTime;
        if (elapsed < 0.0) { elapsed = elapsed + 24.0; }
        progressFraction = (totalSpan > 0.0) ? (elapsed / totalSpan).toFloat() : 0.0f;
        if (progressFraction > 1.0f) { progressFraction = 1.0f; }
    }

    hidden function updateIqamaCountdown(
        hour as Double, prayerTime as Double, prayerIdx as Number, isTomorrow as Boolean
    ) {
        if (!showIqama || prayerIdx == SUNRISE) {
            iqamaCountdownString = "";
            return;
        }
        var offset = iqamaOffsets[prayerIdx] as Number;
        if (offset <= 0) {
            iqamaCountdownString = "";
            return;
        }
        var iqamaTime = prayerTime + offset.toDouble() / 60.0;
        var remaining;
        if (isTomorrow) {
            remaining = (24.0 - hour) + iqamaTime;
        } else {
            remaining = iqamaTime - hour;
        }
        if (remaining < 0.0) { remaining = remaining + 24.0; }
        iqamaCountdownString = "iqama " + formatCountdown(remaining);
    }

    hidden function findPreviousPrayer(nextIdx as Number) as Number {
        // Walk backwards, skipping Sunrise
        for (var i = nextIdx - 1; i >= 0; i--) {
            if (i != SUNRISE) {
                return i;
            }
        }
        return -1; // before Fajr
    }

    // Format fractional hours to "Xh Ym" or "Ym"
    static function formatCountdown(hours as Double) as String {
        var totalMin = (hours * 60.0 + 0.5).toNumber();
        if (totalMin < 0) { totalMin = 0; }
        var h = totalMin / 60;
        var m = totalMin % 60;
        if (h > 0) {
            return h.toString() + "h " + m.toString() + "m";
        }
        return m.toString() + "m";
    }

    // Format fractional hours to "HH:MM"
    static function formatTime(hours as Double) as String {
        var totalMin = (hours * 60.0 + 0.5).toNumber();
        if (totalMin < 0) { totalMin = totalMin + 1440; }
        if (totalMin >= 1440) { totalMin = totalMin - 1440; }
        var h = totalMin / 60;
        var m = totalMin % 60;
        return pad2(h) + ":" + pad2(m);
    }

    static function pad2(n as Number) as String {
        if (n < 10) {
            return "0" + n.toString();
        }
        return n.toString();
    }

    // Current position between sunrise and sunset, clamped 0.0-1.0.
    static function computeDayFraction(hour as Double, sr as Double, ss as Double) as Float {
        if (ss <= sr) { return 0.0f; }
        var f = (hour - sr) / (ss - sr);
        if (f < 0.0) { f = 0.0; }
        if (f > 1.0) { f = 1.0; }
        return f.toFloat();
    }

    // Per-prayer status array: 0 passed, 1 next, 2 upcoming.
    static function computeStatus(times as Array, hour as Double,
                                  nextIdx as Number, allPassed as Boolean) as Array {
        var s = [0, 0, 0, 0, 0, 0];
        for (var i = 0; i < PRAYER_COUNT; i++) {
            if (allPassed) {
                s[i] = STATUS_PASSED;
            } else if (i == nextIdx) {
                s[i] = STATUS_NEXT;
            } else if (hour >= (times[i] as Double)) {
                s[i] = STATUS_PASSED;
            } else {
                s[i] = STATUS_UPCOMING;
            }
        }
        return s;
    }

    // True if (lat, lng) is a usable geographic coordinate.
    // Rejects out-of-range values and the (0,0) / no-fix sentinels.
    static function isValidLocation(lat as Double, lng as Double) as Boolean {
        if (lat < -90.0 || lat > 90.0)   { return false; }
        if (lng < -180.0 || lng > 180.0) { return false; }
        if (lat == 0.0 && lng == 0.0)    { return false; }
        return true;
    }

    // Get prayer display name, handling Friday/Jumuah
    function getPrayerName(index as Number, dayOfWeek as Number) as String {
        if (index == DHUHR && dayOfWeek == Gregorian.DAY_FRIDAY) {
            return "Jumuah";
        }
        return PRAYER_NAMES[index] as String;
    }

    // Get iqama time string for a prayer
    function getIqamaTime(index as Number) as String? {
        if (!showIqama || todayTimes == null || index == SUNRISE) {
            return null;
        }
        var offset = iqamaOffsets[index] as Number;
        if (offset <= 0) {
            return null;
        }
        var prayerHours = (todayTimes as Array)[index] as Double;
        var iqamaHours = prayerHours + (offset.toDouble() / 60.0);
        return formatTime(iqamaHours);
    }
}
