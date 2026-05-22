import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Application;
import Toybox.Application.Properties;

// Slim dispatcher: picks one of four faces by the faceStyle setting.
class GarminPrayerTimesView extends WatchUi.WatchFace {

    hidden var face;
    hidden var faceStyle as Number = -1;
    hidden var isLowPower as Boolean = false;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    // Re-pick the face when the setting changes (or on first draw).
    hidden function ensureFace() as Void {
        var style = Properties.getValue("faceStyle");
        if (style == null) { style = 0; }
        if (face != null && (style as Number) == faceStyle) { return; }
        faceStyle = style as Number;
        if (faceStyle == 1) {
            face = new SolarDialFace();
        } else if (faceStyle == 2) {
            face = new CrescentFace();
        } else if (faceStyle == 3) {
            face = new GradientArcFace();
        } else {
            face = new HorizonFace();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        ensureFace();
        dc.setColor(Theme.TEXT_BRIGHT, Theme.BG);
        dc.clear();

        var app = Application.getApp() as GarminPrayerTimesApp;
        var state = app.prayerState;
        if (state == null) {
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2,
                Graphics.FONT_SMALL, "Loading...", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        state.update();
        if (isLowPower) {
            face.drawLowPower(dc, state);
        } else {
            face.draw(dc, state);
        }
    }

    // Called about once per second — draws the live seconds indicator.
    // Dots accumulate into a filling ring; the once-a-minute onUpdate clears them.
    function onPartialUpdate(dc as Graphics.Dc) as Void {
        if (isLowPower) { return; }
        var sec = System.getClockTime().sec;
        var w = dc.getWidth();
        var cx = w / 2.0;
        var cy = dc.getHeight() / 2.0;
        var r = w / 2.0 - 6.0;
        var ang = (sec / 60.0) * 360.0;
        dc.setColor(Theme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(FaceKit.polarX(cx, r, ang).toNumber(),
                      FaceKit.polarY(cy, r, ang).toNumber(), 2);
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
