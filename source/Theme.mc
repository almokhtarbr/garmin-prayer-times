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
    const DOT_PASSED   = 0x808080;
    const DOT_UPCOMING = 0xE6E6E6;

    // Twilight palette (shared by faces)
    const NIGHT = 0x2B2F4D;
    const DAWN  = 0xC97B8E;
    const NOON  = 0xF2C75B;
    const DUSK  = 0xE09A4E;
    const MOON  = 0xCFD4FF;

    // Sky (dome / arc structure)
    const SKY     = 0x6E78AE;
    const SKY_DIM = 0x2E3354;

    const ACCENT_DEFAULT = 0xFFC34A;

    // User accent color, falling back to amber if unset.
    function accent() as Number {
        var v = Properties.getValue("accentColor");
        if (v == null) { return ACCENT_DEFAULT; }
        return v as Number;
    }
}
