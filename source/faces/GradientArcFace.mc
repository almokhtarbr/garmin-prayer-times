import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

// A ~280 deg arc painted with the day's light, segmented between prayers:
// night -> dawn -> noon -> dusk -> night. A sun bead rides the arc.
class GradientArcFace {

    const ARC_R     = 0.43;
    const ARC_START = 220.0;   // Fajr, lower-left
    const ARC_SWEEP = 280.0;   // clockwise over the top to Isha

    function initialize() {}

    // Fraction along Fajr->Isha for a prayer time.
    hidden function frac(t as Double, fajr as Double, isha as Double) as Float {
        var span = isha - fajr;
        if (span <= 0.0) { span = 1.0d; }
        var f = ((t - fajr) / span).toFloat();
        if (f < 0.0) { f = 0.0; }
        if (f > 1.0) { f = 1.0; }
        return f;
    }

    function draw(dc as Graphics.Dc, state as PrayerState) as Void {
        var times = state.todayTimes;
        if (times == null) { return; }

        var segColors = [Theme.SKY, Theme.DAWN, Theme.NOON, Theme.DUSK, Theme.SKY];
        var pairs = [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5]];

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;
        var r = w * ARC_R;

        // living time-of-day background
        var sunColor = FaceKit.drawSkyLayer(dc, state);

        var fajr = times[PrayerState.FAJR] as Double;
        var isha = times[PrayerState.ISHA] as Double;

        // track
        FaceKit.drawArcSegment(dc, cx, cy, r, ARC_START, ARC_START + ARC_SWEEP,
            6, Theme.TRACK);

        // colored segments between consecutive prayers
        for (var k = 0; k < 5; k++) {
            var a = times[pairs[k][0]] as Double;
            var b = times[pairs[k][1]] as Double;
            var sa = ARC_START + frac(a, fajr, isha) * ARC_SWEEP;
            var sb = ARC_START + frac(b, fajr, isha) * ARC_SWEEP;
            FaceKit.drawArcSegment(dc, cx, cy, r, sa, sb, 6, segColors[k]);
        }

        // prayer dots
        for (var i = 0; i < 6; i++) {
            var ang = ARC_START + frac(times[i] as Double, fajr, isha) * ARC_SWEEP;
            FaceKit.drawPrayerDot(dc,
                FaceKit.polarX(cx, r, ang), FaceKit.polarY(cy, r, ang),
                state.prayerStatus[i], 5);
        }

        // sun bead at the current time
        var now = System.getClockTime();
        var nowHour = (now.hour + now.min / 60.0).toDouble();
        var nowAng = ARC_START + frac(nowHour, fajr, isha) * ARC_SWEEP;
        FaceKit.drawSun(dc,
            FaceKit.polarX(cx, r, nowAng), FaceKit.polarY(cy, r, nowAng),
            sunColor);

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
        var r = w * ARC_R;
        FaceKit.drawArcSegment(dc, cx, cy, r, ARC_START, ARC_START + ARC_SWEEP,
            3, FaceKit.dim(Theme.DUSK, 1, 2));
        FaceKit.drawClock(dc, cx, cy + h * 0.01,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_MID);
        FaceKit.drawNextLine(dc, cx, cy + h * 0.15, state);
    }
}
