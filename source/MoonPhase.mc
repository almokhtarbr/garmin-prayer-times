import Toybox.Lang;
import Toybox.Math;

// Lunar phase derived from the Hijri day-of-month (1-30).
module MoonPhase {

    const SYNODIC = 29.530588853;
    const TWO_PI  = 6.283185307179586;

    // Illuminated fraction, 0.0 (new) to 1.0 (full).
    function illumination(hijriDay as Number) as Float {
        var f = (1.0 - Math.cos(TWO_PI * (hijriDay - 1) / SYNODIC)) / 2.0;
        if (f < 0.0) { f = 0.0; }
        if (f > 1.0) { f = 1.0; }
        return f.toFloat();
    }

    // True for the first half of the lunar month.
    function isWaxing(hijriDay as Number) as Boolean {
        return hijriDay < 15;
    }
}
