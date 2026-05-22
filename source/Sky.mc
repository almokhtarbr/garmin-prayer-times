import Toybox.Lang;

// Time-of-day "sky engine" — turns the clock, sun, and weather into a palette.
// weather param: 0 clear, 1 cloudy, 2 rain, 3 snow.
module Sky {

    const NIGHT = 0;
    const DAWN  = 1;
    const DAY   = 2;
    const DUSK  = 3;

    // Twilight ramp — top and horizon colour per phase.
    const NIGHT_TOP = 0x05060E;  const NIGHT_HZN = 0x141A38;
    const DAWN_TOP  = 0x141533;  const DAWN_HZN  = 0x6A4660;
    const DAY_TOP   = 0x142038;  const DAY_HZN   = 0x35506E;
    const DUSK_TOP  = 0x1A1636;  const DUSK_HZN  = 0x9A5630;

    // Weather tint targets.
    const WX_CLOUD = 0x3A3A42;
    const WX_RAIN  = 0x1C2433;
    const WX_SNOW  = 0x4A5460;

    function phase(nowHour as Double, sunrise as Double, sunset as Double) as Number {
        if (nowHour >= sunrise - 1.0 && nowHour < sunrise) { return DAWN; }
        if (nowHour >= sunrise && nowHour < sunset)        { return DAY; }
        if (nowHour >= sunset && nowHour < sunset + 1.0)   { return DUSK; }
        return NIGHT;
    }

    function topColor(ph as Number, weather as Number) as Number {
        var c = NIGHT_TOP;
        if (ph == DAWN) { c = DAWN_TOP; }
        else if (ph == DAY) { c = DAY_TOP; }
        else if (ph == DUSK) { c = DUSK_TOP; }
        return tint(c, weather);
    }

    function horizonColor(ph as Number, weather as Number) as Number {
        var c = NIGHT_HZN;
        if (ph == DAWN) { c = DAWN_HZN; }
        else if (ph == DAY) { c = DAY_HZN; }
        else if (ph == DUSK) { c = DUSK_HZN; }
        return tint(c, weather);
    }

    function glowColor(ph as Number) as Number {
        if (ph == DAWN) { return 0xFFB079; }
        if (ph == DUSK) { return 0xFF9A40; }
        return 0xFFE2A0;
    }

    function showStars(ph as Number) as Boolean {
        return ph == NIGHT || ph == DAWN;
    }

    function tint(c as Number, weather as Number) as Number {
        if (weather == 1) { return FaceKit.lerpColor(c, WX_CLOUD, 0.35); }
        if (weather == 2) { return FaceKit.lerpColor(c, WX_RAIN, 0.45); }
        if (weather == 3) { return FaceKit.lerpColor(c, WX_SNOW, 0.30); }
        return c;
    }
}
