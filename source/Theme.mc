import Toybox.Lang;
import Toybox.Application.Properties;

// Shared palette and accent color for all faces.
module Theme {
    // Core
    const BG          = 0x000000;
    const TEXT_BRIGHT = 0xF4F4F4;
    const TEXT_MID    = 0x9A9A9A;
    const TEXT_DIM    = 0x6A6A6A;
    const TRACK       = 0x1C1C1C;

    // Prayer dot states
    const DOT_PASSED   = 0x5A5A5A;
    const DOT_UPCOMING = 0xD2D2D2;

    // Twilight palette (shared by faces)
    const NIGHT = 0x2B2F4D;
    const DAWN  = 0xC97B8E;
    const NOON  = 0xE8C87A;
    const DUSK  = 0xE09A4E;
    const MOON  = 0xCFD4FF;

    const ACCENT_DEFAULT = 0xFFC34A;

    // User accent color, falling back to amber if unset.
    function accent() as Number {
        var v = Properties.getValue("accentColor");
        if (v == null) { return ACCENT_DEFAULT; }
        return v as Number;
    }
}
