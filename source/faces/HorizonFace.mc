import Toybox.Graphics;
import Toybox.Lang;

class HorizonFace {
    function initialize() {}

    function draw(dc as Graphics.Dc, state as PrayerState) as Void {
        var cx = dc.getWidth() / 2;
        dc.setColor(Theme.TEXT_BRIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, dc.getHeight() / 2, Graphics.FONT_SMALL,
            "Horizon", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawLowPower(dc as Graphics.Dc, state as PrayerState) as Void {
        draw(dc, state);
    }
}
