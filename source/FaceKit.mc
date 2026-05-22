import Toybox.Lang;
import Toybox.Math;
import Toybox.Graphics;
import Toybox.System;

// Stateless geometry + drawing helpers shared by every face.
// Angle convention: 0 deg = top of screen, increasing clockwise.
module FaceKit {

    const DEG2RAD = 0.0174532925199433;

    function polarX(cx as Float, r as Float, angleDeg as Float) as Float {
        return cx + r * Math.sin(angleDeg * DEG2RAD);
    }

    function polarY(cy as Float, r as Float, angleDeg as Float) as Float {
        return cy - r * Math.cos(angleDeg * DEG2RAD);
    }

    // Clock hour (0-24, fractional) -> 24h dial angle.
    // Noon = 0 deg (top); midnight = 180 deg (bottom).
    function hourToDialAngle(hour as Float) as Float {
        return normalizeAngle(((hour - 12.0) / 24.0) * 360.0);
    }

    function normalizeAngle(deg as Float) as Float {
        var a = deg;
        while (a < 0.0)    { a += 360.0; }
        while (a >= 360.0) { a -= 360.0; }
        return a;
    }

    function approxEqual(a as Float, b as Float, tol as Float) as Boolean {
        var d = a - b;
        if (d < 0.0) { d = -d; }
        return d < tol;
    }

    // Scale an RGB color down by num/den (for glow halos / dimming).
    function dim(color as Number, num as Number, den as Number) as Number {
        var r = ((color >> 16) & 0xFF) * num / den;
        var g = ((color >> 8) & 0xFF) * num / den;
        var b = (color & 0xFF) * num / den;
        return (r << 16) | (g << 8) | b;
    }

    // Draw an arc in the FaceKit convention (0 deg = top, clockwise).
    // Converts to Garmin's native convention (0 = 3 o'clock, counter-clockwise).
    function drawArcSegment(dc as Graphics.Dc, cx as Float, cy as Float, r as Float,
                            startDeg as Float, endDeg as Float,
                            penWidth as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(penWidth);
        var gStart = 90.0 - startDeg;
        var gEnd   = 90.0 - endDeg;
        dc.drawArc(cx.toNumber(), cy.toNumber(), r.toNumber(),
                   Graphics.ARC_CLOCKWISE, gStart.toNumber(), gEnd.toNumber());
        dc.setPenWidth(1);
    }

    // A filled dot with a soft glow halo.
    function drawGlowDot(dc as Graphics.Dc, x as Float, y as Float,
                         radius as Number, color as Number) as Void {
        var xi = x.toNumber();
        var yi = y.toNumber();
        dc.setColor(dim(color, 1, 4), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xi, yi, (radius * 2.2).toNumber());
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xi, yi, radius);
    }

    // A prayer marker. status: 0 passed, 1 next, 2 upcoming.
    function drawPrayerDot(dc as Graphics.Dc, x as Float, y as Float,
                           status as Number, radius as Number) as Void {
        if (status == 1) {
            drawGlowDot(dc, x, y, radius + 1, Theme.accent());
            return;
        }
        var color = (status == 0) ? Theme.DOT_PASSED : Theme.DOT_UPCOMING;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x.toNumber(), y.toNumber(), radius);
    }

    // A crescent: a lit disc carved by an offset background disc.
    function drawCrescent(dc as Graphics.Dc, cx as Number, cy as Number, r as Number,
                          illum as Float, waxing as Boolean) as Void {
        dc.setColor(Theme.MOON, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        var d = (r * (1.55 - illum * 1.1)).toNumber();
        var sx = waxing ? cx - d : cx + d;
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, cy, r);
    }

    // Current time as HH:MM, horizontally centered at (cx, y).
    function drawClock(dc as Graphics.Dc, cx as Float, y as Float,
                       font as Graphics.FontDefinition, color as Number) as Void {
        var t = System.getClockTime();
        var s = PrayerState.pad2(t.hour) + ":" + PrayerState.pad2(t.min);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx.toNumber(), y.toNumber(), font, s, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // "Asr in 2h 23m" in the accent color, centered at (cx, y).
    function drawNextLine(dc as Graphics.Dc, cx as Float, y as Float,
                          state as PrayerState) as Void {
        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx.toNumber(), y.toNumber(), Graphics.FONT_TINY,
            state.nextPrayerName + " in " + state.countdownString,
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Hijri date, dim, centered at (cx, y).
    function drawHijri(dc as Graphics.Dc, cx as Float, y as Float,
                       state as PrayerState) as Void {
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx.toNumber(), y.toNumber(), Graphics.FONT_XTINY,
            state.hijriDate, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
