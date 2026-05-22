import Toybox.Graphics;
import Toybox.Lang;

// The lunar calendar as hero: a crescent matching today's Hijri date, with a
// quiet six-prayer arc along the bottom bezel.
class CrescentFace {

    const ARC_R      = 0.43;
    const ARC_START  = 235.0;   // lower-left
    const ARC_SWEEP  = 250.0;   // clockwise through the bottom
    const ALL_IDX    = [0, 1, 2, 3, 4, 5];

    function initialize() {}

    function draw(dc as Graphics.Dc, state as PrayerState) as Void {
        var times = state.todayTimes;
        if (times == null) { return; }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var r = w * ARC_R;

        // crescent hero, upper third
        FaceKit.drawCrescent(dc, cx.toNumber(), (h * 0.26).toNumber(),
            (w * 0.11).toNumber(), state.moonIllumination, state.moonWaxing);

        // quiet prayer arc along the bottom bezel
        var cy = h / 2.0;
        var endAng = ARC_START + ARC_SWEEP;
        FaceKit.drawArcSegment(dc, cx, cy, r, ARC_START, endAng, 3, Theme.TRACK);
        for (var k = 0; k < 6; k++) {
            var ang = ARC_START + (k / 5.0) * ARC_SWEEP;
            FaceKit.drawPrayerDot(dc,
                FaceKit.polarX(cx, r, ang), FaceKit.polarY(cy, r, ang),
                state.prayerStatus[ALL_IDX[k]], 5);
        }

        // center stack: hijri (emphasized), clock, next prayer
        dc.setColor(Theme.TEXT_MID, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx.toNumber(), (h * 0.43).toNumber(), Graphics.FONT_XTINY,
            state.hijriDate, Graphics.TEXT_JUSTIFY_CENTER);
        FaceKit.drawClock(dc, cx, h * 0.48,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_BRIGHT);
        FaceKit.drawNextLine(dc, cx, h * 0.63, state);
    }

    function drawLowPower(dc as Graphics.Dc, state as PrayerState) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        FaceKit.drawCrescent(dc, cx.toNumber(), (h * 0.26).toNumber(),
            (w * 0.09).toNumber(), state.moonIllumination, state.moonWaxing);
        FaceKit.drawClock(dc, cx, h * 0.48,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_MID);
        FaceKit.drawNextLine(dc, cx, h * 0.63, state);
    }
}
