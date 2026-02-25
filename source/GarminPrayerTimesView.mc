import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.ActivityMonitor;
import Toybox.Math;

class GarminPrayerTimesView extends WatchUi.WatchFace {

    const COLOR_BG       = 0x000000;
    const COLOR_WHITE    = 0xFFFFFF;
    const COLOR_DIM      = 0x999999;  // passed prayers, secondary text
    const COLOR_MUTE     = 0x555555;  // status bar, very subtle
    const COLOR_ARC_BG   = 0x222222;  // progress arc background track

    // Prayer display order (skip Sunrise)
    const DISPLAY_PRAYERS = [0, 2, 3, 4, 5]; // Fajr, Dhuhr, Asr, Maghrib, Isha

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
            dc.setColor(COLOR_WHITE, COLOR_BG);
            dc.clear();
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2,
                Graphics.FONT_SMALL, "Loading...",
                Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        state.update();

        var acVal = Properties.getValue("accentColor");
        var accent = (acVal != null) ? (acVal as Number) : 0xFF4444;
        var h = dc.getHeight();
        var w = dc.getWidth();
        var cx = w / 2;

        if (isLowPower) {
            drawLowPower(dc, state, h, cx, accent);
            return;
        }

        dc.setColor(COLOR_WHITE, COLOR_BG);
        dc.clear();

        // ── Hijri date ── top
        var fhXtiny = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 28 / 416 - fhXtiny / 2, Graphics.FONT_XTINY,
            state.hijriDate, Graphics.TEXT_JUSTIFY_CENTER);

        // ── Clock ── the hero
        var clockTime = System.getClockTime();
        var timeStr = PrayerState.pad2(clockTime.hour) + ":" + PrayerState.pad2(clockTime.min);
        var fhTime = dc.getFontHeight(Graphics.FONT_NUMBER_HOT);
        dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 80 / 416 - fhTime / 2, Graphics.FONT_NUMBER_HOT,
            timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // ── Day name ── under clock
        var now = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 132 / 416 - fhXtiny / 2, Graphics.FONT_XTINY,
            now.day_of_week as String, Graphics.TEXT_JUSTIFY_CENTER);

        // ── Progress arc ── between clock and next prayer info
        drawProgressArc(dc, cx, h * 170 / 416, h * 130 / 416, state.progressFraction, accent);

        // ── Next prayer + countdown ── center anchor
        var fhTiny = dc.getFontHeight(Graphics.FONT_TINY);
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 190 / 416 - fhTiny / 2, Graphics.FONT_TINY,
            state.nextPrayerName + "  ·  " + state.countdownString,
            Graphics.TEXT_JUSTIFY_CENTER);

        // ── Iqama countdown ──
        if (state.showIqama && !state.iqamaCountdownString.equals("")) {
            dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 215 / 416 - fhXtiny / 2, Graphics.FONT_XTINY,
                state.iqamaCountdownString, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── Prayer list ── 5 prayers, the core info
        drawPrayerList(dc, state, cx, h, accent);

        // ── Status bar ── bottom
        drawStatus(dc, cx, h);
    }

    hidden function drawProgressArc(
        dc as Dc, cx as Number, cy as Number, arcWidth as Number,
        fraction as Float, accent as Number
    ) as Void {
        var radius = arcWidth / 2;
        var penWidth = 4;
        dc.setPenWidth(penWidth);

        // Background track: thin arc spanning ~140 degrees centered at top
        var startAngle = 160; // left side
        var endAngle = 20;    // right side
        dc.setColor(COLOR_ARC_BG, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, startAngle, endAngle);

        // Filled portion
        if (fraction > 0.01f) {
            // Map fraction to angle span (clockwise from startAngle)
            var totalArcDeg = 140; // 160 - 20 = 140 degrees
            var filledDeg = (totalArcDeg * fraction).toNumber();
            var filledEnd = startAngle - filledDeg;
            if (filledEnd < 0) { filledEnd = filledEnd + 360; }
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, startAngle, filledEnd);
        }

        dc.setPenWidth(1);
    }

    hidden function drawPrayerList(
        dc as Dc, state as PrayerState, cx as Number, h as Number, accent as Number
    ) as Void {
        if (state.todayTimes == null) {
            return;
        }

        var times = state.todayTimes as Array;
        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var hour = (nowInfo.hour as Number).toDouble()
                 + (nowInfo.min as Number).toDouble() / 60.0;
        var dayOfWeek = nowInfo.day_of_week as Number;

        var fhXtiny = dc.getFontHeight(Graphics.FONT_XTINY);
        var rowHeight = fhXtiny + 5;
        var startY = h * 245 / 416;
        var nameX = cx - h * 80 / 416;  // left-aligned names
        var timeX = cx + h * 40 / 416;  // right-aligned times
        var iqamaX = cx + h * 100 / 416; // iqama times

        for (var di = 0; di < 5; di++) {
            var i = DISPLAY_PRAYERS[di] as Number;
            var y = startY + di * rowHeight - fhXtiny / 2;
            var prayerTime = times[i] as Double;
            var isPassed = (hour >= prayerTime) && !state.isNextTomorrowFajr;
            var isNext = (i == state.nextPrayerIndex) && !state.isNextTomorrowFajr;

            // For tomorrow's Fajr case, highlight Fajr row
            if (state.isNextTomorrowFajr && i == PrayerState.FAJR) {
                isNext = false; // Fajr today is passed
                isPassed = true;
            }

            // Color
            if (isNext) {
                dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            } else if (isPassed) {
                dc.setColor(COLOR_MUTE, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            }

            // Prayer name
            var name = state.getPrayerName(i, dayOfWeek);
            dc.drawText(nameX, y, Graphics.FONT_XTINY,
                name, Graphics.TEXT_JUSTIFY_LEFT);

            // Prayer time
            var timeStr = PrayerState.formatTime(prayerTime);
            dc.drawText(timeX, y, Graphics.FONT_XTINY,
                timeStr, Graphics.TEXT_JUSTIFY_LEFT);

            // Iqama time (dim, only for next/upcoming if enabled)
            if (state.showIqama && !isPassed) {
                var iqStr = state.getIqamaTime(i);
                if (iqStr != null) {
                    dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(iqamaX, y, Graphics.FONT_XTINY,
                        iqStr, Graphics.TEXT_JUSTIFY_LEFT);
                }
            }
        }
    }

    hidden function drawStatus(dc as Dc, cx as Number, h as Number) as Void {
        var y = h * 390 / 416;
        var fhXtiny = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setColor(COLOR_MUTE, Graphics.COLOR_TRANSPARENT);

        var batt = System.getSystemStats().battery.toNumber().toString() + "%";
        var hr = "--";
        var actInfo = ActivityMonitor.getInfo();
        if (actInfo != null && actInfo has :currentHeartRate && actInfo.currentHeartRate != null) {
            hr = (actInfo.currentHeartRate as Number).toString();
        }

        dc.drawText(cx - h * 50 / 416, y - fhXtiny / 2, Graphics.FONT_XTINY,
            batt, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx + h * 50 / 416, y - fhXtiny / 2, Graphics.FONT_XTINY,
            hr, Graphics.TEXT_JUSTIFY_CENTER);

        // Small separator dots
        dc.fillCircle(cx - h * 18 / 416, y - 1, 2);
        dc.fillCircle(cx + h * 18 / 416, y - 1, 2);
    }

    hidden function drawLowPower(
        dc as Dc, state as PrayerState, h as Number, cx as Number, accent as Number
    ) as Void {
        dc.setColor(COLOR_WHITE, COLOR_BG);
        dc.clear();

        var clockTime = System.getClockTime();
        var timeStr = PrayerState.pad2(clockTime.hour) + ":" + PrayerState.pad2(clockTime.min);
        var fhTime = dc.getFontHeight(Graphics.FONT_NUMBER_MILD);
        dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 40 - fhTime / 2, Graphics.FONT_NUMBER_MILD,
            timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        if (state.nextPrayerName.length() > 0) {
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 + 10, Graphics.FONT_XTINY,
                state.nextPrayerName + "  ·  " + state.countdownString,
                Graphics.TEXT_JUSTIFY_CENTER);

            if (state.showIqama && !state.iqamaCountdownString.equals("")) {
                dc.setColor(COLOR_MUTE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, h / 2 + 35, Graphics.FONT_XTINY,
                    state.iqamaCountdownString,
                    Graphics.TEXT_JUSTIFY_CENTER);
            }
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
