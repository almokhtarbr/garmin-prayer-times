import Toybox.Lang;

// Continuous time-of-day "sky engine" — colours flow smoothly through the day.
// weather param: 0 clear, 1 cloudy, 2 rain, 3 snow.
module Sky {

    // Keyframe colours — top and horizon, at night / dawn / day / dusk.
    const NIGHT_TOP = 0x05060E;  const NIGHT_HZN = 0x141A38;
    const DAWN_TOP  = 0x141533;  const DAWN_HZN  = 0x6A4660;
    const DAY_TOP   = 0x142038;  const DAY_HZN   = 0x35506E;
    const DUSK_TOP  = 0x1A1636;  const DUSK_HZN  = 0x9A5630;

    const WX_CLOUD = 0x3A3A42;
    const WX_RAIN  = 0x1C2433;
    const WX_SNOW  = 0x4A5460;

    // Continuous top-of-screen colour for the current moment.
    function topColor(nowHour as Double, sunrise as Double, sunset as Double,
                      weather as Number) as Number {
        return tint(ramp(nowHour, sunrise, sunset,
            NIGHT_TOP, DAWN_TOP, DAY_TOP, DUSK_TOP), weather);
    }

    // Continuous horizon colour for the current moment.
    function horizonColor(nowHour as Double, sunrise as Double, sunset as Double,
                          weather as Number) as Number {
        return tint(ramp(nowHour, sunrise, sunset,
            NIGHT_HZN, DAWN_HZN, DAY_HZN, DUSK_HZN), weather);
    }

    // Sun-glow colour — warm at the day's edges, pale gold at midday.
    function glowColor(nowHour as Double, sunrise as Double,
                       sunset as Double) as Number {
        return ramp(nowHour, sunrise, sunset,
            0xFFE2A0, 0xFFB079, 0xFFE2A0, 0xFF9A40);
    }

    // Star visibility, 0.0 (full day) .. 1.0 (deep night), ramped over 1h edges.
    function starAlpha(nowHour as Double, sunrise as Double,
                       sunset as Double) as Float {
        if (nowHour <= sunrise - 1.0 || nowHour >= sunset + 1.0) { return 1.0; }
        if (nowHour >= sunrise && nowHour <= sunset)             { return 0.0; }
        if (nowHour < sunrise) {
            return ((sunrise - nowHour) / 1.0).toFloat();
        }
        return ((nowHour - sunset) / 1.0).toFloat();
    }

    // Interpolate between the four keyframe colours by the sun's position.
    function ramp(nowHour as Double, sunrise as Double, sunset as Double,
                  night as Number, dawn as Number, day as Number,
                  dusk as Number) as Number {
        var k0 = sunrise - 1.0;
        var k1 = sunrise;
        var k2 = sunrise + 1.5;
        var k3 = sunset - 1.5;
        var k4 = sunset;
        var k5 = sunset + 1.0;
        if (nowHour <= k0 || nowHour >= k5) { return night; }
        if (nowHour < k1) { return seg(nowHour, k0, k1, night, dawn); }
        if (nowHour < k2) { return seg(nowHour, k1, k2, dawn, day); }
        if (nowHour < k3) { return day; }
        if (nowHour < k4) { return seg(nowHour, k3, k4, day, dusk); }
        return seg(nowHour, k4, k5, dusk, night);
    }

    // Lerp colour a->b across the time window [t0, t1].
    function seg(now as Double, t0 as Double, t1 as Double,
                 a as Number, b as Number) as Number {
        var span = t1 - t0;
        if (span <= 0.0) { return b; }
        var f = ((now - t0) / span).toFloat();
        return FaceKit.lerpColor(a, b, f);
    }

    function tint(c as Number, weather as Number) as Number {
        if (weather == 1) { return FaceKit.lerpColor(c, WX_CLOUD, 0.35); }
        if (weather == 2) { return FaceKit.lerpColor(c, WX_RAIN, 0.45); }
        if (weather == 3) { return FaceKit.lerpColor(c, WX_SNOW, 0.30); }
        return c;
    }
}
