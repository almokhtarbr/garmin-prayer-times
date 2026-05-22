import Toybox.Application;
import Toybox.Lang;
import Toybox.Position;
import Toybox.WatchUi;

class GarminPrayerTimesApp extends Application.AppBase {
    var prayerState as PrayerState?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        prayerState = new PrayerState();

        var hasGps = false;
        var posInfo = Position.getInfo();
        if (posInfo.accuracy != Position.QUALITY_NOT_AVAILABLE && posInfo.position != null) {
            var pos = posInfo.position.toDegrees();
            var lat = pos[0] as Double;
            var lng = pos[1] as Double;
            if (PrayerState.isValidLocation(lat, lng)) {
                prayerState.updateLocation(lat, lng);
                hasGps = true;
            }
        }

        if (!hasGps) {
            prayerState.updateLocation(46.8139d, -71.2082d);
        }
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new GarminPrayerTimesView();
        return [view] as [Views];
    }

    function onSettingsChanged() as Void {
        if (prayerState != null) {
            prayerState.onSettingsChanged();
        }
        WatchUi.requestUpdate();
    }
}
