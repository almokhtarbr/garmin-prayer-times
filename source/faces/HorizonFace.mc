import Toybox.Graphics;
import Toybox.Lang;

// Default face. A horizon line: the sun rides a sky dome for the four daytime
// prayers; Isha and Fajr sit below in the night with a crescent moon.
class HorizonFace {

    // Tunable layout fractions (of screen width/height)
    const HORIZON_Y   = 0.56;
    const DOME_R      = 0.40;
    const NIGHT_R     = 0.36;
    const ISHA_ANGLE  = 138.0;
    const FAJR_ANGLE  = 222.0;

    function initialize() {}

    function draw(dc as Graphics.Dc, state as PrayerState) as Void {
        var times = state.todayTimes;
        if (times == null) { return; }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var horizonY = h * HORIZON_Y;
        var domeR = w * DOME_R;
        var nightR = w * NIGHT_R;

        // sky dome (270 deg left -> 360 top -> 450/90 right)
        FaceKit.drawArcSegment(dc, cx, horizonY, domeR, 270.0, 450.0, 3, Theme.NIGHT);

        // horizon line
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine((cx - domeR).toNumber(), horizonY.toNumber(),
                    (cx + domeR).toNumber(), horizonY.toNumber());
        dc.setPenWidth(1);

        // daytime prayers on the dome
        var sr = state.sunrise;
        var span = state.sunset - sr;
        if (span <= 0.0) { span = 1.0d; }
        var dayIdx = [PrayerState.SUNRISE, PrayerState.DHUHR,
                      PrayerState.ASR, PrayerState.MAGHRIB];
        for (var k = 0; k < 4; k++) {
            var i = dayIdx[k];
            var f = (((times[i] as Double) - sr) / span).toFloat();
            if (f < 0.0) { f = 0.0; }
            if (f > 1.0) { f = 1.0; }
            var ang = 270.0 + f * 180.0;
            FaceKit.drawPrayerDot(dc,
                FaceKit.polarX(cx, domeR, ang),
                FaceKit.polarY(horizonY, domeR, ang),
                state.prayerStatus[i], 5);
        }

        // sun on the dome at the current day fraction
        var sunAng = 270.0 + state.dayFraction * 180.0;
        FaceKit.drawGlowDot(dc,
            FaceKit.polarX(cx, domeR, sunAng),
            FaceKit.polarY(horizonY, domeR, sunAng),
            6, Theme.NOON);

        // night prayers below the horizon
        FaceKit.drawPrayerDot(dc,
            FaceKit.polarX(cx, nightR, ISHA_ANGLE),
            FaceKit.polarY(horizonY, nightR, ISHA_ANGLE),
            state.prayerStatus[PrayerState.ISHA], 5);
        FaceKit.drawPrayerDot(dc,
            FaceKit.polarX(cx, nightR, FAJR_ANGLE),
            FaceKit.polarY(horizonY, nightR, FAJR_ANGLE),
            state.prayerStatus[PrayerState.FAJR], 5);

        // crescent moon in the night zone
        FaceKit.drawCrescent(dc,
            (cx - w * 0.20).toNumber(), (horizonY + h * 0.22).toNumber(),
            (w * 0.05).toNumber(), state.moonIllumination, state.moonWaxing);

        // center stack: clock, next prayer, hijri
        FaceKit.drawClock(dc, cx, horizonY + h * 0.04,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_BRIGHT);
        FaceKit.drawNextLine(dc, cx, horizonY + h * 0.21, state);
        FaceKit.drawHijri(dc, cx, horizonY + h * 0.29, state);
    }

    function drawLowPower(dc as Graphics.Dc, state as PrayerState) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var horizonY = h * HORIZON_Y;
        var domeR = w * DOME_R;

        // horizon line + dimmed sun only
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine((cx - domeR).toNumber(), horizonY.toNumber(),
                    (cx + domeR).toNumber(), horizonY.toNumber());
        dc.setPenWidth(1);
        var sunAng = 270.0 + state.dayFraction * 180.0;
        dc.setColor(FaceKit.dim(Theme.NOON, 1, 2), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(FaceKit.polarX(cx, domeR, sunAng).toNumber(),
                      FaceKit.polarY(horizonY, domeR, sunAng).toNumber(), 5);

        FaceKit.drawClock(dc, cx, horizonY + h * 0.04,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_MID);
        FaceKit.drawNextLine(dc, cx, horizonY + h * 0.21, state);
    }
}
