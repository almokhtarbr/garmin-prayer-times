import Toybox.Lang;
import Toybox.Weather;

// Wraps Toybox.Weather. Every accessor degrades to a clear-sky default when
// the watch has no synced weather, rather than failing.
module WeatherData {

    const CLEAR  = 0;
    const CLOUDY = 1;
    const RAIN   = 2;
    const SNOW   = 3;

    function isAvailable() as Boolean {
        return Weather.getCurrentConditions() != null;
    }

    function temperature() as Number? {
        var cc = Weather.getCurrentConditions();
        if (cc == null) { return null; }
        return cc.temperature;
    }

    // Current condition mapped to CLEAR / CLOUDY / RAIN / SNOW.
    function condition() as Number {
        var cc = Weather.getCurrentConditions();
        if (cc == null) { return CLEAR; }
        var c = cc.condition;
        if (c == null) { return CLEAR; }
        if (c == Weather.CONDITION_RAIN
         || c == Weather.CONDITION_THUNDERSTORMS) { return RAIN; }
        if (c == Weather.CONDITION_SNOW) { return SNOW; }
        if (c == Weather.CONDITION_CLOUDY
         || c == Weather.CONDITION_MOSTLY_CLOUDY
         || c == Weather.CONDITION_PARTLY_CLOUDY
         || c == Weather.CONDITION_FOG) { return CLOUDY; }
        return CLEAR;
    }
}
