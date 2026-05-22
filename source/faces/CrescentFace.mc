import Toybox.Graphics;
import Toybox.Lang;

// The lunar calendar as hero — a crescent matching today's Hijri date — with
// a quiet six-prayer arc along the bottom bezel.
class CrescentFace {

    const ARC_R     = 0.44;
    const ARC_START = 130.0;
    const ARC_SWEEP = 100.0;

    function initialize() {}

    function draw(dc as Graphics.Dc, state as PrayerState) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;

        // living time-of-day background
        FaceKit.drawSkyLayer(dc, state);
        FaceKit.drawApproachGlow(dc, state.minutesToNext);

        // crescent hero
        FaceKit.drawCrescent(dc, cx.toNumber(), (h * 0.25).toNumber(),
            (w * 0.13).toNumber(), state.moonIllumination, state.moonWaxing);

        // Hijri date — prominent (this is the lunar-calendar face)
        dc.setColor(Theme.TEXT_MID, Graphics.COLOR_TRANSPARENT);
        var fhT = dc.getFontHeight(Graphics.FONT_TINY);
        dc.drawText(cx.toNumber(), (h * 0.45 - fhT / 2.0).toNumber(),
            Graphics.FONT_TINY, state.hijriDate, Graphics.TEXT_JUSTIFY_CENTER);

        // clock + next prayer
        FaceKit.drawClock(dc, cx, h * 0.57,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_BRIGHT);
        FaceKit.drawNextLine(dc, cx, h * 0.70, state);
        FaceKit.drawWeather(dc, cx.toNumber(), (h * 0.80).toNumber());

        // quiet six-prayer arc along the bottom bezel
        var r = w * ARC_R;
        FaceKit.drawArcSegment(dc, cx, cy, r, ARC_START, ARC_START + ARC_SWEEP,
            2, Theme.SKY_DIM);
        for (var i = 0; i < 6; i++) {
            var ang = ARC_START + (i / 5.0) * ARC_SWEEP;
            FaceKit.drawPrayerDot(dc,
                FaceKit.polarX(cx, r, ang), FaceKit.polarY(cy, r, ang),
                state.prayerStatus[i], 5);
        }
    }

    function drawLowPower(dc as Graphics.Dc, state as PrayerState) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        FaceKit.drawCrescent(dc, cx.toNumber(), (h * 0.25).toNumber(),
            (w * 0.11).toNumber(), state.moonIllumination, state.moonWaxing);
        FaceKit.drawClock(dc, cx, h * 0.57,
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT_MID);
        FaceKit.drawNextLine(dc, cx, h * 0.70, state);
    }
}
