import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

// Prayer time calculation engine — ported from praytimes.org algorithm
// All angles in degrees unless noted. Trigonometric functions use radians internally.

class PrayerCalculator {
    // Calculation method parameters: [fajrAngle, ishaAngle, ishaMinutes]
    // If ishaMinutes > 0, isha = maghrib + ishaMinutes (ignoring ishaAngle)
    static const METHOD_ISNA       = 0;
    static const METHOD_MWL        = 1;
    static const METHOD_EGYPTIAN   = 2;
    static const METHOD_UMM_ALQURA = 3;
    static const METHOD_DUBAI      = 4;
    static const METHOD_KARACHI    = 5;
    static const METHOD_KUWAIT     = 6;
    static const METHOD_QATAR      = 7;
    static const METHOD_SINGAPORE  = 8;
    static const METHOD_TEHRAN     = 9;
    static const METHOD_TURKEY     = 10;

    // [fajrAngle, ishaAngle, ishaMinutesAfterMaghrib]
    static const METHODS = [
        [15.0,  15.0,  0],    // ISNA
        [18.0,  17.0,  0],    // MWL
        [19.5,  17.5,  0],    // Egyptian
        [18.5,   0.0, 90],    // Umm al-Qura (isha = maghrib + 90min)
        [18.2,  18.2,  0],    // Dubai
        [18.0,  18.0,  0],    // Karachi
        [18.0,  17.5,  0],    // Kuwait
        [18.0,   0.0, 90],    // Qatar (isha = maghrib + 90min)
        [20.0,  18.0,  0],    // Singapore
        [17.7,  14.0,  0],    // Tehran
        [18.0,  17.0,  0],    // Turkey
    ];

    // Pre-computed constants (avoid runtime Math.PI evaluation in const)
    static const DEG_TO_RAD = 0.017453292519943295;
    static const RAD_TO_DEG = 57.29577951308232;

    // Calculate all 6 prayer times for a given date and location.
    // Returns array of 6 floats: hours since midnight (fractional) for
    // [Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha]
    // Returns null if calculation fails.
    static function calculate(
        year as Number, month as Number, day as Number,
        latitude as Double, longitude as Double,
        timezone as Double, methodIndex as Number,
        asrFactor as Number  // 1=Shafi, 2=Hanafi
    ) as Array? {
        var method = METHODS[methodIndex] as Array;
        var fajrAngle = (method[0] as Float).toDouble();
        var ishaAngle = (method[1] as Float).toDouble();
        var ishaMinutes = (method[2] as Number);

        // Julian date at noon
        var jd = julianDate(year, month, day);

        // Sun declination and equation of time
        var sunPos = sunPosition(jd);
        var decl = sunPos[0] as Double;
        var eqt = sunPos[1] as Double;

        // Transit time (Dhuhr) in hours
        var transit = 12.0 + timezone - (longitude / 15.0) - (eqt / 60.0);

        // Sunrise & sunset hour angles
        var haSunrise = hourAngle(latitude, decl, -0.8333d);
        if (haSunrise == null) {
            return null; // no sunrise/sunset (polar regions)
        }

        var sunrise = transit - (haSunrise as Double) / 15.0;
        var sunset  = transit + (haSunrise as Double) / 15.0;

        // Fajr
        var haFajr = hourAngle(latitude, decl, -fajrAngle);
        var fajr = (haFajr != null) ? transit - (haFajr as Double) / 15.0 : sunrise - 1.5;

        // Dhuhr (add 65 seconds as safety margin per praytimes.org)
        var dhuhr = transit + (65.0 / 3600.0);

        // Asr
        var asrTime = computeAsr(asrFactor, latitude, decl, transit);

        // Maghrib = sunset
        var maghrib = sunset;

        // Isha
        var isha;
        if (ishaMinutes > 0) {
            isha = maghrib + (ishaMinutes.toDouble() / 60.0);
        } else {
            var haIsha = hourAngle(latitude, decl, -ishaAngle);
            isha = (haIsha != null) ? transit + (haIsha as Double) / 15.0 : maghrib + 1.5;
        }

        return [
            normalizeHour(fajr),
            normalizeHour(sunrise),
            normalizeHour(dhuhr),
            normalizeHour(asrTime),
            normalizeHour(maghrib),
            normalizeHour(isha),
        ];
    }

    // Julian Date for a calendar date at noon UT
    static function julianDate(year as Number, month as Number, day as Number) as Double {
        if (month <= 2) {
            year = year - 1;
            month = month + 12;
        }
        var a = (year / 100).toNumber();
        var b = 2 - a + (a / 4).toNumber();

        return (365.25 * (year + 4716)).toNumber().toDouble()
             + (30.6001 * (month + 1)).toNumber().toDouble()
             + day.toDouble() + b.toDouble() - 1524.5;
    }

    // Returns [declination_degrees, equation_of_time_minutes]
    static function sunPosition(jd as Double) as Array {
        var d = jd - 2451545.0;
        var g = normalizeAngle(357.529 + 0.98560028 * d);
        var q = normalizeAngle(280.459 + 0.98564736 * d);
        var l = normalizeAngle(q + 1.915 * dsin(g) + 0.020 * dsin(2.0 * g));

        var e = 23.439 - 0.00000036 * d;
        var ra = datan2(dcos(e) * dsin(l), dcos(l)) / 15.0;
        var decl = dasin(dsin(e) * dsin(l));

        // Equation of time
        var eqt = (q / 15.0) - normalizeHour(ra);

        return [decl, eqt * 60.0];
    }

    // Hour angle for a given altitude (degrees)
    // Returns degrees or null if no solution (always above/below horizon)
    // NOTE: Callers pass negative angles for below-horizon events (Fajr, Sunrise, Isha)
    static function hourAngle(lat as Double, decl as Double, altitude as Double) as Double? {
        var cosHA = (dsin(altitude) - dsin(lat) * dsin(decl))
                  / (dcos(lat) * dcos(decl));

        if (cosHA < -1.0 || cosHA > 1.0) {
            return null;
        }
        return dacos(cosHA);
    }

    // Asr time computation
    // Uses negative angle convention to match hourAngle() sign expectations
    static function computeAsr(
        factor as Number, lat as Double, decl as Double, transit as Double
    ) as Double {
        var diff = lat - decl;
        if (diff < 0.0) { diff = -diff; }
        // acot(factor + tan(|lat-decl|)) gives the sun altitude angle for Asr
        // Negate it to match hourAngle() convention (negative = below reference)
        var angle = dacot(factor.toDouble() + dtan(diff));
        var ha = hourAngle(lat, decl, -angle);
        if (ha == null) {
            return transit + 4.0; // fallback
        }
        // Asr is afternoon, so add hour angle
        return transit + (ha as Double) / 15.0;
    }

    // ── Trig helpers (degree-based) ──

    static function dsin(deg as Double) as Double {
        return Math.sin(deg * DEG_TO_RAD);
    }

    static function dcos(deg as Double) as Double {
        return Math.cos(deg * DEG_TO_RAD);
    }

    static function dtan(deg as Double) as Double {
        return Math.tan(deg * DEG_TO_RAD);
    }

    static function dasin(x as Double) as Double {
        return Math.asin(x) * RAD_TO_DEG;
    }

    static function dacos(x as Double) as Double {
        return Math.acos(x) * RAD_TO_DEG;
    }

    static function datan2(y as Double, x as Double) as Double {
        return Math.atan2(y, x) * RAD_TO_DEG;
    }

    static function dacot(x as Double) as Double {
        // acot(x) = atan(1/x) in degrees
        return Math.atan(1.0 / x) * RAD_TO_DEG;
    }

    static function normalizeAngle(a as Double) as Double {
        a = a - 360.0 * (a / 360.0).toNumber().toDouble();
        if (a < 0.0) {
            a = a + 360.0;
        }
        return a;
    }

    static function normalizeHour(h as Double) as Double {
        h = h - 24.0 * (h / 24.0).toNumber().toDouble();
        if (h < 0.0) {
            h = h + 24.0;
        }
        return h;
    }
}
