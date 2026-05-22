import Toybox.Lang;
import Toybox.Test;

// ---- FaceKit geometry ----

(:test)
function testPolarYTop(logger as Test.Logger) as Boolean {
    // angle 0 = top → y = cy - r
    return FaceKit.approxEqual(FaceKit.polarY(100.0, 50.0, 0.0), 50.0, 0.01);
}

(:test)
function testPolarYBottom(logger as Test.Logger) as Boolean {
    // angle 180 = bottom → y = cy + r
    return FaceKit.approxEqual(FaceKit.polarY(100.0, 50.0, 180.0), 150.0, 0.01);
}

(:test)
function testPolarXRight(logger as Test.Logger) as Boolean {
    // angle 90 = right → x = cx + r
    return FaceKit.approxEqual(FaceKit.polarX(100.0, 50.0, 90.0), 150.0, 0.01);
}

(:test)
function testPolarXTop(logger as Test.Logger) as Boolean {
    // angle 0 = top → x = cx
    return FaceKit.approxEqual(FaceKit.polarX(100.0, 50.0, 0.0), 100.0, 0.01);
}

(:test)
function testHourToDialNoon(logger as Test.Logger) as Boolean {
    return FaceKit.approxEqual(FaceKit.hourToDialAngle(12.0), 0.0, 0.01);
}

(:test)
function testHourToDialMidnight(logger as Test.Logger) as Boolean {
    return FaceKit.approxEqual(FaceKit.hourToDialAngle(0.0), 180.0, 0.01);
}

(:test)
function testHourToDialEvening(logger as Test.Logger) as Boolean {
    return FaceKit.approxEqual(FaceKit.hourToDialAngle(18.0), 90.0, 0.01);
}

(:test)
function testNormalizeNegative(logger as Test.Logger) as Boolean {
    return FaceKit.approxEqual(FaceKit.normalizeAngle(-90.0), 270.0, 0.01);
}

(:test)
function testNormalizeOver(logger as Test.Logger) as Boolean {
    return FaceKit.approxEqual(FaceKit.normalizeAngle(450.0), 90.0, 0.01);
}

// ---- MoonPhase ----

(:test)
function testMoonNewMoon(logger as Test.Logger) as Boolean {
    // Hijri day 1 -> illumination ~0 (new moon)
    return FaceKit.approxEqual(MoonPhase.illumination(1), 0.0, 0.02);
}

(:test)
function testMoonFull(logger as Test.Logger) as Boolean {
    // Hijri day 15 -> illumination near full
    return MoonPhase.illumination(15) > 0.95;
}

(:test)
function testMoonWaxingEarly(logger as Test.Logger) as Boolean {
    return MoonPhase.isWaxing(5) == true;
}

(:test)
function testMoonWaningLate(logger as Test.Logger) as Boolean {
    return MoonPhase.isWaxing(22) == false;
}

// ---- PrayerState pure logic ----

(:test)
function testDayFractionMidday(logger as Test.Logger) as Boolean {
    // sunrise 6, sunset 18, now 12 -> 0.5
    return FaceKit.approxEqual(
        PrayerState.computeDayFraction(12.0d, 6.0d, 18.0d), 0.5, 0.01);
}

(:test)
function testDayFractionClampLow(logger as Test.Logger) as Boolean {
    // before sunrise -> clamped to 0
    return FaceKit.approxEqual(
        PrayerState.computeDayFraction(3.0d, 6.0d, 18.0d), 0.0, 0.01);
}

(:test)
function testStatusMarksNextAndPassed(logger as Test.Logger) as Boolean {
    // times: Fajr 5, Sunrise 6, Dhuhr 12, Asr 16, Maghrib 20, Isha 22
    // now 13.0, next index 3 (Asr)
    var times = [5.0d, 6.0d, 12.0d, 16.0d, 20.0d, 22.0d];
    var s = PrayerState.computeStatus(times, 13.0d, 3, false);
    // Fajr/Sunrise/Dhuhr passed (0), Asr next (1), Maghrib/Isha upcoming (2)
    return s[0] == 0 && s[1] == 0 && s[2] == 0
        && s[3] == 1 && s[4] == 2 && s[5] == 2;
}

(:test)
function testStatusAllPassedAfterIsha(logger as Test.Logger) as Boolean {
    var times = [5.0d, 6.0d, 12.0d, 16.0d, 20.0d, 22.0d];
    var s = PrayerState.computeStatus(times, 23.0d, -1, true);
    return s[0] == 0 && s[3] == 0 && s[5] == 0;
}
