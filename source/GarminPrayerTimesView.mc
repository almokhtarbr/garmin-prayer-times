import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.ActivityMonitor;

class GarminPrayerTimesView extends WatchUi.WatchFace {

    const COLOR_BG   = 0x000000;
    const COLOR_WHITE = 0xFFFFFF;
    const COLOR_DIM  = 0xAAAAAA;
    const COLOR_MUTE = 0x888888;

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
        var cx = dc.getWidth() / 2;

        if (isLowPower) {
            drawLowPower(dc, state, h, cx);
            return;
        }

        dc.setColor(COLOR_WHITE, COLOR_BG);
        dc.clear();

        // ── Clock ── the hero, upper center
        var clockTime = System.getClockTime();
        var timeStr = PrayerState.pad2(clockTime.hour) + ":" + PrayerState.pad2(clockTime.min);
        var fhTime = dc.getFontHeight(Graphics.FONT_NUMBER_HOT);
        dc.drawText(cx, h * 88 / 416 - fhTime / 2, Graphics.FONT_NUMBER_HOT,
            timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // ── Date ── single dim line under clock
        var now = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var dayName = now.day_of_week as String;
        dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 152 / 416, Graphics.FONT_XTINY,
            dayName + "  ·  " + state.hijriDate,
            Graphics.TEXT_JUSTIFY_CENTER);

        // ── Next prayer name ── accent, the anchor
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 210 / 416, Graphics.FONT_TINY,
            state.nextPrayerName, Graphics.TEXT_JUSTIFY_CENTER);

        // ── Next prayer time ── white, large, prominent
        var nextTimeStr = getNextPrayerTimeStr(state);
        dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 242 / 416, Graphics.FONT_MEDIUM,
            nextTimeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // ── Iqama ── dim, small
        var iqamaStr = getNextIqamaStr(state);
        if (iqamaStr != null) {
            dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 290 / 416, Graphics.FONT_XTINY,
                "iqama " + iqamaStr, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── Countdown ── dim, below iqama
        dc.setColor(COLOR_MUTE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 316 / 416, Graphics.FONT_TINY,
            state.countdownString, Graphics.TEXT_JUSTIFY_CENTER);

        // ── Next-after-next ── peek at what's coming
        var afterNext = getAfterNextStr(state);
        if (afterNext != null) {
            dc.setColor(COLOR_MUTE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 348 / 416, Graphics.FONT_XTINY,
                afterNext, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── Status ── barely there
        drawStatus(dc, cx, h);
    }

    hidden function getNextPrayerTimeStr(state as PrayerState) as String {
        if (state.todayTimes != null && !state.isNextTomorrowFajr && state.nextPrayerIndex >= 0) {
            return PrayerState.formatTime(
                (state.todayTimes as Array)[state.nextPrayerIndex] as Double);
        }
        if (state.isNextTomorrowFajr && state.tomorrowFajr != null) {
            return PrayerState.formatTime(state.tomorrowFajr as Double);
        }
        return "--:--";
    }

    hidden function getNextIqamaStr(state as PrayerState) as String? {
        if (state.isNextTomorrowFajr && state.showIqama && state.tomorrowFajr != null) {
            var offset = state.iqamaOffsets[PrayerState.FAJR] as Number;
            if (offset > 0) {
                return PrayerState.formatTime(
                    (state.tomorrowFajr as Double) + offset.toDouble() / 60.0);
            }
            return null;
        }
        if (!state.showIqama || state.nextPrayerIndex < 0) {
            return null;
        }
        return state.getIqamaTime(state.nextPrayerIndex);
    }

    hidden function getAfterNextStr(state as PrayerState) as String? {
        if (state.todayTimes == null) {
            return null;
        }
        var times = state.todayTimes as Array;
        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayOfWeek = nowInfo.day_of_week as Number;

        if (state.isNextTomorrowFajr) {
            // After tomorrow's Fajr is tomorrow's Sunrise — skip, not useful
            return null;
        }

        // Find the prayer after nextPrayerIndex (skip Sunrise)
        for (var i = state.nextPrayerIndex + 1; i < PrayerState.PRAYER_COUNT; i++) {
            if (i == PrayerState.SUNRISE) {
                continue;
            }
            var name = state.getPrayerName(i, dayOfWeek);
            var timeStr = PrayerState.formatTime(times[i] as Double);
            return name + "  " + timeStr;
        }

        // Wrapped past Isha — next-after is tomorrow's Fajr
        if (state.tomorrowFajr != null) {
            return "Fajr  " + PrayerState.formatTime(state.tomorrowFajr as Double);
        }
        return null;
    }

    hidden function drawStatus(dc as Dc, cx as Number, h as Number) as Void {
        var y = h * 375 / 416;
        dc.setColor(COLOR_MUTE, Graphics.COLOR_TRANSPARENT);

        var batt = System.getSystemStats().battery.toNumber().toString() + "%";
        var hr = "--";
        var actInfo = ActivityMonitor.getInfo();
        if (actInfo != null && actInfo has :currentHeartRate && actInfo.currentHeartRate != null) {
            hr = (actInfo.currentHeartRate as Number).toString();
        }

        dc.drawText(cx, y, Graphics.FONT_XTINY,
            batt + "    " + hr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawLowPower(
        dc as Dc, state as PrayerState, h as Number, cx as Number
    ) as Void {
        dc.setColor(COLOR_WHITE, COLOR_BG);
        dc.clear();

        var clockTime = System.getClockTime();
        var timeStr = PrayerState.pad2(clockTime.hour) + ":" + PrayerState.pad2(clockTime.min);
        var fhTime = dc.getFontHeight(Graphics.FONT_NUMBER_MILD);
        dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 30 - fhTime / 2, Graphics.FONT_NUMBER_MILD,
            timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        if (state.nextPrayerName.length() > 0) {
            dc.drawText(cx, h / 2 + 20, Graphics.FONT_XTINY,
                state.nextPrayerName + "  " + state.countdownString,
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
