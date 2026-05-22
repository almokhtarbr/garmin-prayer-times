import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

// A 24-hour dial: noon at top, midnight at bottom. A lit daytime band and a
// dark night band; the six prayers sit at their true clock positions.
class SolarDialFace {

    const RING_R   = 0.40;
    const BAND_PEN = 9;
    const NAMES = ["Fajr", "Shrq", "Dhuhr", "Asr", "Mgrb", "Isha"];

    function initialize() {}

    function draw(dc as Graphics.Dc, state as PrayerState) as Void {
        var times = state.todayTimes;
        if (times == null) { return; }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;
        var r = w * RING_R;

        // living time-of-day background
        var ph = FaceKit.drawSkyLayer(dc, state);

        var sunriseAng = FaceKit.hourToDialAngle(state.sunrise.toFloat());
        var sunsetAng  = FaceKit.hourToDialAngle(state.sunset.toFloat());

        // night band (full ring), then the lit daytime band over it
        FaceKit.drawArcSegment(dc, cx, cy, r, 0.0, 359.9, BAND_PEN, 0x3C4168);
        FaceKit.drawArcSegment(dc, cx, cy, r, sunriseAng, sunsetAng, BAND_PEN, 0x9A8348);

        // prayer markers + labels at their true dial positions
        for (var i = 0; i < 6; i++) {
            var ang = FaceKit.hourToDialAngle((times[i] as Double).toFloat());
            FaceKit.drawPrayerDot(dc,
                FaceKit.polarX(cx, r, ang), FaceKit.polarY(cy, r, ang),
                state.prayerStatus[i], 6);
            FaceKit.drawLabel(dc,
                FaceKit.polarX(cx, r - 23, ang), FaceKit.polarY(cy, r - 23, ang),
                NAMES[i], FaceKit.statusColor(state.prayerStatus[i]));
        }

        // sun bead at the current time
        var now = System.getClockTime();
        var nowHour = now.hour + now.min / 60.0;
        var nowAng = FaceKit.hourToDialAngle(nowHour.toFloat());
        FaceKit.drawSun(dc,
            FaceKit.polarX(cx, r, nowAng), FaceKit.polarY(cy, r, nowAng),
            Sky.glowColor(ph));

        // center stack
        FaceKit.drawHijri(dc, cx, cy - h * 0.135, state);
        FaceKit.drawClock(dc, cx, cy + h * 0.01,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_BRIGHT);
        FaceKit.drawNextLine(dc, cx, cy + h * 0.15, state);
        FaceKit.drawWeather(dc, cx.toNumber(), (cy + h * 0.26).toNumber());
    }

    function drawLowPower(dc as Graphics.Dc, state as PrayerState) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;
        var r = w * RING_R;
        FaceKit.drawArcSegment(dc, cx, cy, r, 0.0, 359.9, 3, 0x3C4168);
        FaceKit.drawClock(dc, cx, cy + h * 0.01,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_MID);
        FaceKit.drawNextLine(dc, cx, cy + h * 0.15, state);
    }
}
