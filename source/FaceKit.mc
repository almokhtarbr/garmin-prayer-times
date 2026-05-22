import Toybox.Lang;
import Toybox.Math;

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
}
