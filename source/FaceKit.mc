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

    // Linear-interpolate two RGB colours. t is clamped to 0.0-1.0.
    function lerpColor(c1 as Number, c2 as Number, t as Float) as Number {
        var tt = t;
        if (tt < 0.0) { tt = 0.0; }
        if (tt > 1.0) { tt = 1.0; }
        var r1 = (c1 >> 16) & 0xFF;
        var g1 = (c1 >> 8) & 0xFF;
        var b1 = c1 & 0xFF;
        var r = (r1 + (((c2 >> 16) & 0xFF) - r1) * tt).toNumber();
        var g = (g1 + (((c2 >> 8) & 0xFF) - g1) * tt).toNumber();
        var b = (b1 + ((c2 & 0xFF) - b1) * tt).toNumber();
        return (r << 16) | (g << 8) | b;
    }

    // Fill the screen with a vertical banded gradient (top -> horizon colour).
    function drawSky(dc as Graphics.Dc, topColor as Number,
                     horizonColor as Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var bands = 40;
        for (var i = 0; i < bands; i++) {
            var t = i.toFloat() / (bands - 1);
            var c = lerpColor(topColor, horizonColor, t);
            dc.setColor(c, c);
            dc.fillRectangle(0, i * h / bands, w, (h / bands) + 2);
        }
    }

    // A glowing sun: a coloured disc, a lighter ring, a white core.
    function drawSun(dc as Graphics.Dc, x as Float, y as Float,
                     color as Number) as Void {
        var xi = x.toNumber();
        var yi = y.toNumber();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xi, yi, 13);
        dc.setColor(lerpColor(color, 0xFFFFFF, 0.55), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xi, yi, 8);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xi, yi, 4);
    }

    // Scatter fixed stars across the screen (deterministic positions).
    function drawStarfield(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var stars = [
            [0.16,0.12,1],[0.30,0.07,1],[0.44,0.13,2],[0.58,0.06,1],
            [0.70,0.11,1],[0.84,0.18,2],[0.12,0.26,1],[0.90,0.30,1],
            [0.22,0.40,1],[0.79,0.42,1],[0.07,0.48,1],[0.93,0.52,2],
            [0.35,0.22,1],[0.64,0.24,1],[0.50,0.32,1],[0.27,0.52,1],
            [0.73,0.56,1],[0.18,0.62,1],[0.86,0.64,1],[0.40,0.30,1],
            [0.60,0.16,2],[0.52,0.46,1],[0.10,0.36,1],[0.88,0.44,1]
        ];
        dc.setColor(0xCFD4FF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < stars.size(); i++) {
            var s = stars[i];
            dc.fillCircle(((s[0] as Float) * w).toNumber(),
                          ((s[1] as Float) * h).toNumber(),
                          s[2] as Number);
        }
    }

    // Small weather icon centred at (x,y). cond: 0 clear,1 cloud,2 rain,3 snow.
    function drawWeatherGlyph(dc as Graphics.Dc, x as Number, y as Number,
                              cond as Number) as Void {
        if (cond == 0) {
            dc.setColor(0xFFD98A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, 5);
            return;
        }
        dc.setColor(0xB0B6C8, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - 4, y, 4);
        dc.fillCircle(x + 4, y, 4);
        dc.fillCircle(x, y - 3, 5);
        if (cond == 2) {
            dc.setColor(0x6E9AD0, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 5, y + 5, 2, 4);
            dc.fillRectangle(x + 1, y + 5, 2, 4);
        } else if (cond == 3) {
            dc.setColor(0xE6ECFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x - 3, y + 7, 1);
            dc.fillCircle(x + 3, y + 7, 1);
        }
    }

    // Paint the living time-of-day background (+ stars at night).
    // Call as the first line of a face's draw(). Returns the Sky phase.
    function drawSkyLayer(dc as Graphics.Dc, state as PrayerState) as Number {
        var t = System.getClockTime();
        var nowHour = (t.hour + t.min / 60.0).toDouble();
        var ph = Sky.phase(nowHour, state.sunrise, state.sunset);
        var wx = WeatherData.condition();
        drawSky(dc, Sky.topColor(ph, wx), Sky.horizonColor(ph, wx));
        if (Sky.showStars(ph)) { drawStarfield(dc); }
        return ph;
    }

    // Weather readout: glyph + temperature near (cx, y). Silent when no data.
    function drawWeather(dc as Graphics.Dc, cx as Number, y as Number) as Void {
        if (!WeatherData.isAvailable()) { return; }
        var temp = WeatherData.temperature();
        if (temp == null) { return; }
        drawWeatherGlyph(dc, cx - 15, y, WeatherData.condition());
        dc.setColor(Theme.TEXT_MID, Graphics.COLOR_TRANSPARENT);
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.drawText(cx + 4, y - fh / 2, Graphics.FONT_XTINY,
            temp.toNumber().toString() + "°", Graphics.TEXT_JUSTIFY_LEFT);
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
        var d = (2.0 * r * illum).toNumber();
        var sx = waxing ? cx - d : cx + d;
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, cy, r);
    }

    // Current time as HH:MM, centered on (cx, y).
    function drawClock(dc as Graphics.Dc, cx as Float, y as Float,
                       font as Graphics.FontDefinition, color as Number) as Void {
        var t = System.getClockTime();
        var s = PrayerState.pad2(t.hour) + ":" + PrayerState.pad2(t.min);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var fh = dc.getFontHeight(font);
        dc.drawText(cx.toNumber(), (y - fh / 2.0).toNumber(), font, s,
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    // "Asr in 2h 23m" in the accent color, centered on (cx, y).
    function drawNextLine(dc as Graphics.Dc, cx as Float, y as Float,
                          state as PrayerState) as Void {
        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        var fh = dc.getFontHeight(Graphics.FONT_TINY);
        dc.drawText(cx.toNumber(), (y - fh / 2.0).toNumber(), Graphics.FONT_TINY,
            state.nextPrayerName + " in " + state.countdownString,
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Hijri date, dim, centered on (cx, y).
    function drawHijri(dc as Graphics.Dc, cx as Float, y as Float,
                       state as PrayerState) as Void {
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.drawText(cx.toNumber(), (y - fh / 2.0).toNumber(), Graphics.FONT_XTINY,
            state.hijriDate, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // A small label, centered on (x, y).
    function drawLabel(dc as Graphics.Dc, x as Float, y as Float,
                       text as String, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.drawText(x.toNumber(), (y - fh / 2.0).toNumber(), Graphics.FONT_XTINY,
            text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Color for a prayer status: 0 passed, 1 next, 2 upcoming.
    function statusColor(status as Number) as Number {
        if (status == 1) { return Theme.accent(); }
        if (status == 0) { return Theme.DOT_PASSED; }
        return Theme.DOT_UPCOMING;
    }
}
