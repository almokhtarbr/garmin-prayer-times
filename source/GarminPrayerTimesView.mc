import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Application;
import Toybox.Application.Properties;

class GarminPrayerTimesView extends WatchUi.WatchFace {

    const COLOR_BG      = 0x000000;
    const COLOR_PRIMARY = 0xFFFFFF;
    const COLOR_SECOND  = 0x888888;
    const COLOR_PASSED  = 0x383838;
    const COLOR_TRACK   = 0x1A1A1A;

    const DISPLAY_PRAYERS = [0, 2, 3, 4, 5];

    var isLowPower as Boolean = false;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var app = Application.getApp() as GarminPrayerTimesApp;
        var state = app.prayerState;
        if (state == null) {
            dc.setColor(COLOR_PRIMARY, COLOR_BG);
            dc.clear();
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2,
                Graphics.FONT_SMALL, "Loading...",
                Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        state.update();

        var acVal = Properties.getValue("accentColor");
        var accent = (acVal != null) ? (acVal as Number) : 0x66BB6A;
        var h = dc.getHeight();
        var cx = dc.getWidth() / 2;

        if (isLowPower) {
            drawLowPower(dc, state, h, cx, accent);
            return;
        }

        dc.setColor(COLOR_PRIMARY, COLOR_BG);
        dc.clear();

        // ── Outer progress arc ──
        drawOuterArc(dc, cx, h, state.progressFraction, accent);

        var fhX = dc.getFontHeight(Graphics.FONT_XTINY);

        // ── Hijri date ──
        dc.setColor(COLOR_SECOND, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 35 / 416 - fhX / 2, Graphics.FONT_XTINY,
            state.hijriDate, Graphics.TEXT_JUSTIFY_CENTER);

        // ── Clock ──
        var clockTime = System.getClockTime();
        var timeStr = PrayerState.pad2(clockTime.hour) + ":" + PrayerState.pad2(clockTime.min);
        var fhTime = dc.getFontHeight(Graphics.FONT_NUMBER_HOT);
        dc.setColor(COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 86 / 416 - fhTime / 2, Graphics.FONT_NUMBER_HOT,
            timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // ── Day name ──
        var now = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        dc.setColor(COLOR_SECOND, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 138 / 416 - fhX / 2, Graphics.FONT_XTINY,
            now.day_of_week as String, Graphics.TEXT_JUSTIFY_CENTER);

        // ── Next prayer + countdown ──
        var fhT = dc.getFontHeight(Graphics.FONT_TINY);
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 170 / 416 - fhT / 2, Graphics.FONT_TINY,
            state.nextPrayerName + " in " + state.countdownString,
            Graphics.TEXT_JUSTIFY_CENTER);

        // ── Iqama ──
        if (state.showIqama && !state.iqamaCountdownString.equals("")) {
            dc.setColor(COLOR_SECOND, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 196 / 416 - fhX / 2, Graphics.FONT_XTINY,
                state.iqamaCountdownString, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── Prayer list with timeline ──
        drawPrayerList(dc, state, cx, h, accent);
    }

    hidden function drawOuterArc(
        dc as Dc, cx as Number, h as Number, fraction as Float, accent as Number
    ) as Void {
        var cy = h / 2;
        var radius = h / 2 - 8;
        dc.setPenWidth(8);

        // 240° arc from 8 o'clock to 4 o'clock, gap at bottom
        dc.setColor(COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 210, 330);

        if (fraction > 0.01f) {
            var filledDeg = (240.0 * fraction).toNumber();
            var endAngle = 210 - filledDeg;
            if (endAngle < 0) { endAngle = endAngle + 360; }
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 210, endAngle);
        }

        dc.setPenWidth(1);
    }

    hidden function drawPrayerList(
        dc as Dc, state as PrayerState, cx as Number, h as Number, accent as Number
    ) as Void {
        if (state.todayTimes == null) { return; }

        var times = state.todayTimes as Array;
        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var hour = (nowInfo.hour as Number).toDouble()
                 + (nowInfo.min as Number).toDouble() / 60.0;
        var dayOfWeek = nowInfo.day_of_week as Number;

        var fhX = dc.getFontHeight(Graphics.FONT_XTINY);
        var rowH = fhX + 4;

        // Compute startY so the list always fits within safe zone
        var safeBottom = h * 375 / 416;
        var totalHeight = 5 * rowH;
        var startY = safeBottom - totalHeight;

        var nameX = cx - h * 58 / 416;
        var timeX = cx + h * 68 / 416;
        var lineX = nameX - h * 18 / 416;

        // Vertical timeline line
        var lineTop = startY + fhX / 2;
        var lineBot = startY + 4 * rowH + fhX / 2;
        dc.setColor(COLOR_PASSED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(lineX, lineTop, lineX, lineBot);
        dc.setPenWidth(1);

        for (var di = 0; di < 5; di++) {
            var i = DISPLAY_PRAYERS[di] as Number;
            var y = startY + di * rowH;
            var dotY = y + fhX / 2;
            var prayerTime = times[i] as Double;
            var isPassed = (hour >= prayerTime) && !state.isNextTomorrowFajr;
            var isNext = (i == state.nextPrayerIndex) && !state.isNextTomorrowFajr;

            if (state.isNextTomorrowFajr && i == PrayerState.FAJR) {
                isNext = false;
                isPassed = true;
            }

            // Timeline dot
            if (isNext) {
                // Glow ring behind the dot
                dc.setColor(COLOR_PASSED, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(lineX, dotY, 8);
                dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(lineX, dotY, 5);
            } else if (isPassed) {
                dc.setColor(COLOR_SECOND, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(lineX, dotY, 3);
            } else {
                // Open circle for upcoming
                dc.setColor(COLOR_SECOND, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
                dc.drawCircle(lineX, dotY, 3);
                dc.setPenWidth(1);
            }

            // Text color
            var color;
            if (isNext) {
                color = accent;
            } else if (isPassed) {
                color = COLOR_PASSED;
            } else {
                color = COLOR_PRIMARY;
            }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);

            // Prayer name
            dc.drawText(nameX, y, Graphics.FONT_XTINY,
                state.getPrayerName(i, dayOfWeek), Graphics.TEXT_JUSTIFY_LEFT);

            // Prayer time (right aligned for clean columns)
            dc.drawText(timeX, y, Graphics.FONT_XTINY,
                PrayerState.formatTime(prayerTime), Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }

    hidden function drawLowPower(
        dc as Dc, state as PrayerState, h as Number, cx as Number, accent as Number
    ) as Void {
        dc.setColor(COLOR_PRIMARY, COLOR_BG);
        dc.clear();

        var clockTime = System.getClockTime();
        var timeStr = PrayerState.pad2(clockTime.hour) + ":" + PrayerState.pad2(clockTime.min);
        var fhTime = dc.getFontHeight(Graphics.FONT_NUMBER_MILD);
        dc.setColor(COLOR_SECOND, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 30 - fhTime / 2, Graphics.FONT_NUMBER_MILD,
            timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        if (state.nextPrayerName.length() > 0) {
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 + 20, Graphics.FONT_XTINY,
                state.nextPrayerName + " in " + state.countdownString,
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function onEnterSleep() as Void {
        isLowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        isLowPower = false;
        WatchUi.requestUpdate();
    }
}
