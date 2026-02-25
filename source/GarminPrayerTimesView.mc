import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Application;
import Toybox.Application.Properties;

class GarminPrayerTimesView extends WatchUi.WatchFace {

    const COLOR_BG       = 0x000000;
    const COLOR_BRIGHT   = 0xFFFFFF;  // white — clock, upcoming times
    const COLOR_MID      = 0xAAAAAA;  // light gray — hijri, secondary
    const COLOR_FADED    = 0x444444;  // dark gray — passed prayers
    const COLOR_CELL_DIM = 0x0D0D0D;  // passed cell bg
    const COLOR_CELL     = 0x1A1A1A;  // upcoming cell bg
    const COLOR_TRACK    = 0x1A1A1A;
    const COLOR_ACCENT   = 0x42A5F5;  // light blue

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
            dc.setColor(COLOR_BRIGHT, COLOR_BG);
            dc.clear();
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2,
                Graphics.FONT_SMALL, "Loading...",
                Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        state.update();

        // Force amber accent — ignore old cached red from previous builds
        var accent = COLOR_ACCENT;
        var h = dc.getHeight();
        var cx = dc.getWidth() / 2;

        if (isLowPower) {
            drawLowPower(dc, state, h, cx, accent);
            return;
        }

        dc.setColor(COLOR_BRIGHT, COLOR_BG);
        dc.clear();

        // ── Outer progress arc ──
        drawOuterArc(dc, cx, h, state.progressFraction, accent);

        // ── Layout flows top to bottom ──
        var fhX = dc.getFontHeight(Graphics.FONT_XTINY);
        var fhT = dc.getFontHeight(Graphics.FONT_TINY);
        var fhTime = dc.getFontHeight(Graphics.FONT_NUMBER_HOT);

        // Hijri date — tight to top
        var y = h * 48 / 416;
        dc.setColor(COLOR_BRIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY,
            state.hijriDate, Graphics.TEXT_JUSTIFY_CENTER);
        y = y + fhX - 30;

        // Clock — no gap
        dc.setColor(COLOR_BRIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_NUMBER_HOT,
            PrayerState.pad2(System.getClockTime().hour) + ":" +
            PrayerState.pad2(System.getClockTime().min),
            Graphics.TEXT_JUSTIFY_CENTER);
        y = y + fhTime - 30;

        // Next prayer countdown — tight
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_TINY,
            state.nextPrayerName + " in " + state.countdownString,
            Graphics.TEXT_JUSTIFY_CENTER);
        y = y + fhT;

        // Iqama countdown
        if (state.showIqama && !state.iqamaCountdownString.equals("")) {
            dc.setColor(COLOR_BRIGHT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY,
                state.iqamaCountdownString, Graphics.TEXT_JUSTIFY_CENTER);
            y = y + fhX + 4;
        } else {
            y = y + 4;
        }

        // Prayer grid
        drawPrayerGrid(dc, state, cx, h, y, accent, fhT, fhX);
    }

    hidden function drawOuterArc(
        dc as Dc, cx as Number, h as Number, fraction as Float, accent as Number
    ) as Void {
        var cy = h / 2;
        var radius = h / 2 - 8;
        dc.setPenWidth(6);

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

    hidden function drawPrayerGrid(
        dc as Dc, state as PrayerState, cx as Number, h as Number,
        gridTop as Number, accent as Number, fhT as Number, fhX as Number
    ) as Void {
        if (state.todayTimes == null) { return; }

        var times = state.todayTimes as Array;
        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var hour = (nowInfo.hour as Number).toDouble()
                 + (nowInfo.min as Number).toDouble() / 60.0;

        var gap = h * 3 / 416;
        var gridW = h * 250 / 416;
        var colW = (gridW - gap) / 2;
        var gridLeft = cx - gridW / 2;
        var cellPad = 4;

        // Compact single-line cells
        var rowH = fhT + cellPad * 2;

        for (var row = 0; row < 3; row++) {
            for (var col = 0; col < 2; col++) {
                var i = row * 2 + col;
                var cellX = gridLeft + col * (colW + gap);
                var cellY = gridTop + row * (rowH + gap);

                var prayerTime = times[i] as Double;
                var isPassed = (hour >= prayerTime) && !state.isNextTomorrowFajr;
                var isNext = (i == state.nextPrayerIndex) && !state.isNextTomorrowFajr;

                if (i == PrayerState.SUNRISE) { isNext = false; }
                if (state.isNextTomorrowFajr) { isPassed = true; }

                // Cell background
                if (isNext) {
                    dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
                } else if (isPassed) {
                    dc.setColor(COLOR_CELL_DIM, Graphics.COLOR_TRANSPARENT);
                } else {
                    dc.setColor(COLOR_CELL, Graphics.COLOR_TRANSPARENT);
                }
                dc.fillRectangle(cellX, cellY, colW, rowH);

                // Time — left side of cell
                var textY = cellY + cellPad;
                if (isNext) {
                    dc.setColor(COLOR_BG, Graphics.COLOR_TRANSPARENT);
                } else if (isPassed) {
                    dc.setColor(COLOR_FADED, Graphics.COLOR_TRANSPARENT);
                } else {
                    dc.setColor(COLOR_BRIGHT, Graphics.COLOR_TRANSPARENT);
                }
                dc.drawText(cellX + 10, textY, Graphics.FONT_TINY,
                    PrayerState.formatTime(prayerTime), Graphics.TEXT_JUSTIFY_LEFT);

                // Iqama offset "+X" — right side, smaller, baseline-aligned
                if (state.showIqama && i != PrayerState.SUNRISE) {
                    var offset = state.iqamaOffsets[i] as Number;
                    if (offset > 0) {
                        if (isNext) {
                            dc.setColor(COLOR_BRIGHT, Graphics.COLOR_TRANSPARENT);
                        } else if (isPassed) {
                            dc.setColor(COLOR_FADED, Graphics.COLOR_TRANSPARENT);
                        } else {
                            dc.setColor(COLOR_BRIGHT, Graphics.COLOR_TRANSPARENT);
                        }
                        // Align to bottom of time text
                        var iqY = textY + fhT - fhX - 30;
                        dc.drawText(cellX + colW - 8, iqY, Graphics.FONT_XTINY,
                            "+" + offset.toString(), Graphics.TEXT_JUSTIFY_RIGHT);
                    }
                }
            }
        }
    }

    hidden function drawLowPower(
        dc as Dc, state as PrayerState, h as Number, cx as Number, accent as Number
    ) as Void {
        dc.setColor(COLOR_BRIGHT, COLOR_BG);
        dc.clear();

        var clockTime = System.getClockTime();
        var timeStr = PrayerState.pad2(clockTime.hour) + ":" + PrayerState.pad2(clockTime.min);
        var fhTime = dc.getFontHeight(Graphics.FONT_NUMBER_MILD);
        dc.setColor(COLOR_BRIGHT, Graphics.COLOR_TRANSPARENT);
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
