import Toybox.Lang;

// Gregorian → Hijri date conversion using the Kuwaiti/tabular algorithm
// Pure math — no lookup tables needed.

class HijriCalendar {
    static const HIJRI_MONTHS = [
        "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
        "Jumada al-Ula", "Jumada al-Thani", "Rajab", "Sha'ban",
        "Ramadan", "Shawwal", "Dhul Qi'dah", "Dhul Hijjah"
    ];

    // Convert Gregorian date to Hijri [year, month, day]
    static function toHijri(year as Number, month as Number, day as Number) as Array {
        // Step 1: Gregorian → Julian Day Number
        var jdn = gregorianToJdn(year, month, day);

        // Step 2: JDN → Hijri (using Kuwaiti algorithm)
        return jdnToHijri(jdn);
    }

    // Format Hijri date as "day MonthName year AH"
    static function format(year as Number, month as Number, day as Number) as String {
        var hijri = toHijri(year, month, day);
        var hYear = hijri[0];
        var hMonth = hijri[1];
        var hDay = hijri[2];

        var monthName = HIJRI_MONTHS[hMonth - 1] as String;
        return hDay.toString() + " " + monthName + " " + hYear.toString() + " AH";
    }

    // Gregorian date → Julian Day Number
    static function gregorianToJdn(year as Number, month as Number, day as Number) as Number {
        if (month <= 2) {
            year = year - 1;
            month = month + 12;
        }
        var a = (year / 100).toNumber();
        var b = 2 - a + (a / 4).toNumber();
        var jdn = (365.25 * (year + 4716)).toNumber()
                + (30.6001 * (month + 1)).toNumber()
                + day + b - 1524;
        return jdn;
    }

    // Julian Day Number → Hijri date [year, month, day]
    // Kuwaiti/tabular algorithm
    static function jdnToHijri(jdn as Number) as Array {
        var l = jdn - 1948440 + 10632;
        var n = ((l - 1) / 10631).toNumber();
        l = l - 10631 * n + 354;

        var j = ((10985 - l) / 5316).toNumber() * ((50 * l) / 17719).toNumber()
              + ((l / 5670).toNumber()) * ((43 * l) / 15238).toNumber();
        l = l - ((30 - j) / 15).toNumber() * ((17719 * j) / 50).toNumber()
            - ((j / 16).toNumber()) * ((15238 * j) / 43).toNumber() + 29;

        var hMonth = ((24 * l) / 709).toNumber();
        var hDay = l - ((709 * hMonth) / 24).toNumber();
        var hYear = 30 * n + j - 30;

        return [hYear, hMonth, hDay] as Array;
    }
}
