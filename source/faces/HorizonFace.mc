import Toybox.Graphics;
import Toybox.Lang;

// Default face — a twilight horizon. The sun rides a sky dome past the four
// daytime prayers; Fajr and Isha sit at the horizon's edges; a crescent hangs
// in the twilight sky. Clock and next prayer read clean below the line.
class HorizonFace {

    const HORIZON_Y = 0.53;
    const DOME_R    = 0.42;

    function initialize() {}

    function draw(dc as Graphics.Dc, state as PrayerState) as Void {
        var times = state.todayTimes;
        if (times == null) { return; }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var hy = h * HORIZON_Y;
        var domeR = w * DOME_R;

        // crescent moon in the twilight sky
        FaceKit.drawCrescent(dc,
            (cx - w * 0.24).toNumber(), (h * 0.20).toNumber(),
            (w * 0.05).toNumber(), state.moonIllumination, state.moonWaxing);

        // sky dome — a layered twilight band
        FaceKit.drawArcSegment(dc, cx, hy, domeR + 4, 270.0, 450.0, 7, Theme.SKY_DIM);
        FaceKit.drawArcSegment(dc, cx, hy, domeR, 270.0, 450.0, 2, Theme.SKY);

        // daytime prayers on the dome, with labels
        var sr = state.sunrise;
        var span = state.sunset - sr;
        if (span <= 0.0) { span = 1.0d; }
        var dayIdx   = [PrayerState.SUNRISE, PrayerState.DHUHR,
                        PrayerState.ASR, PrayerState.MAGHRIB];
        var dayLabel = ["Shuruq", "Dhuhr", "Asr", "Maghrib"];
        for (var k = 0; k < 4; k++) {
            var i = dayIdx[k];
            var f = (((times[i] as Double) - sr) / span).toFloat();
            if (f < 0.0) { f = 0.0; }
            if (f > 1.0) { f = 1.0; }
            var ang = 287.0 + f * 146.0;
            FaceKit.drawPrayerDot(dc,
                FaceKit.polarX(cx, domeR, ang), FaceKit.polarY(hy, domeR, ang),
                state.prayerStatus[i], 6);
            FaceKit.drawLabel(dc,
                FaceKit.polarX(cx, domeR - 25, ang),
                FaceKit.polarY(hy, domeR - 25, ang),
                dayLabel[k], FaceKit.statusColor(state.prayerStatus[i]));
        }

        // sun riding the dome
        var sunAng = 287.0 + state.dayFraction * 146.0;
        FaceKit.drawGlowDot(dc,
            FaceKit.polarX(cx, domeR, sunAng),
            FaceKit.polarY(hy, domeR, sunAng), 7, Theme.NOON);

        // horizon line
        dc.setColor(Theme.SKY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine((cx - domeR).toNumber(), hy.toNumber(),
                    (cx + domeR).toNumber(), hy.toNumber());
        dc.setPenWidth(1);

        // Fajr and Isha at the horizon's edges
        drawEdge(dc, cx - domeR * 0.74, hy + h * 0.06, "Fajr",
            state.prayerStatus[PrayerState.FAJR]);
        drawEdge(dc, cx + domeR * 0.74, hy + h * 0.06, "Isha",
            state.prayerStatus[PrayerState.ISHA]);

        // center stack below the horizon
        FaceKit.drawClock(dc, cx, hy + h * 0.165,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_BRIGHT);
        FaceKit.drawNextLine(dc, cx, hy + h * 0.295, state);
        FaceKit.drawHijri(dc, cx, hy + h * 0.385, state);
    }

    hidden function drawEdge(dc as Graphics.Dc, x as Float, y as Float,
                             label as String, status as Number) as Void {
        FaceKit.drawPrayerDot(dc, x, y, status, 5);
        FaceKit.drawLabel(dc, x, y + 15, label, FaceKit.statusColor(status));
    }

    function drawLowPower(dc as Graphics.Dc, state as PrayerState) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var hy = h * HORIZON_Y;
        var domeR = w * DOME_R;

        dc.setColor(Theme.SKY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine((cx - domeR).toNumber(), hy.toNumber(),
                    (cx + domeR).toNumber(), hy.toNumber());
        dc.setPenWidth(1);

        var sunAng = 287.0 + state.dayFraction * 146.0;
        dc.setColor(FaceKit.dim(Theme.NOON, 1, 2), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(FaceKit.polarX(cx, domeR, sunAng).toNumber(),
                      FaceKit.polarY(hy, domeR, sunAng).toNumber(), 5);

        FaceKit.drawClock(dc, cx, hy + h * 0.165,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_MID);
        FaceKit.drawNextLine(dc, cx, hy + h * 0.295, state);
    }
}
