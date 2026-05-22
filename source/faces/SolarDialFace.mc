import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

// A 24-hour dial: noon at top, midnight at bottom. The ring splits into a lit
// daytime band and a dark night band; prayers sit at their real positions.
class SolarDialFace {

    const RING_R   = 0.43;   // fraction of width
    const DAY_PEN  = 8;
    const ALL_IDX  = [0, 1, 2, 3, 4, 5];

    function initialize() {}

    function draw(dc as Graphics.Dc, state as PrayerState) as Void {
        var times = state.todayTimes;
        if (times == null) { return; }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;
        var r = w * RING_R;

        var sunriseAng = FaceKit.hourToDialAngle(state.sunrise.toFloat());
        var sunsetAng  = FaceKit.hourToDialAngle(state.sunset.toFloat());

        // night band first (full ring), then day band on top
        FaceKit.drawArcSegment(dc, cx, cy, r, 0.0, 359.9, DAY_PEN, Theme.NIGHT);
        FaceKit.drawArcSegment(dc, cx, cy, r, sunriseAng, sunsetAng,
            DAY_PEN, FaceKit.dim(Theme.NOON, 1, 3));

        // prayer markers at their real dial positions
        for (var k = 0; k < 6; k++) {
            var i = ALL_IDX[k];
            var ang = FaceKit.hourToDialAngle((times[i] as Double).toFloat());
            FaceKit.drawPrayerDot(dc,
                FaceKit.polarX(cx, r, ang), FaceKit.polarY(cy, r, ang),
                state.prayerStatus[i], 5);
        }

        // sun bead at the current time
        var now = System.getClockTime();
        var nowHour = now.hour + now.min / 60.0;
        var nowAng = FaceKit.hourToDialAngle(nowHour.toFloat());
        FaceKit.drawGlowDot(dc,
            FaceKit.polarX(cx, r, nowAng), FaceKit.polarY(cy, r, nowAng),
            6, Theme.NOON);

        // center stack
        FaceKit.drawHijri(dc, cx, cy - h * 0.16, state);
        FaceKit.drawClock(dc, cx, cy - h * 0.11,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_BRIGHT);
        FaceKit.drawNextLine(dc, cx, cy + h * 0.04, state);
    }

    function drawLowPower(dc as Graphics.Dc, state as PrayerState) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;
        var r = w * RING_R;
        FaceKit.drawArcSegment(dc, cx, cy, r, 0.0, 359.9, 3,
            FaceKit.dim(Theme.NIGHT, 1, 2));
        FaceKit.drawClock(dc, cx, cy - h * 0.11,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_MID);
        FaceKit.drawNextLine(dc, cx, cy + h * 0.04, state);
    }
}
