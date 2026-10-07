package ui;

/**
 * ApiStyle:
 * Centralized theme, styling constants, and semantic design tokens for the AQW Mod UI.
 * Single source of truth for all windows, dashboards, widgets, and dialogs.
 *
 * All external UI components reference ONLY these generic semantic constants.
 * If the active theme or color palette changes in the future, only the private palette
 * definitions in this file need to be edited, with zero impact on consuming UI components.
 */
class ApiStyle {
    // =========================================================================
    // ACTIVE PALETTE DEFINITION: Dark Modern Clean with Rad/Red Accent
    // Deep obsidian/carbon surfaces, crisp slate borders, radiant cyber-crimson accent.
    // =========================================================================
    private static inline var _PALETTE_BG:Int            = 0x12131A; // Base dark modern background
    private static inline var _PALETTE_BG_DARK:Int       = 0x0C0D12; // Deeper surface (sidebars, inputs, headers)
    private static inline var _PALETTE_BG_DARKER:Int     = 0x07080B; // Deepest background (modal backdrops)
    private static inline var _PALETTE_BG_LIGHT:Int      = 0x1B1D27; // Clean elevated cards & resting button plates
    private static inline var _PALETTE_BG_LIGHTER:Int    = 0x252836; // Hover plate for cards & buttons
    private static inline var _PALETTE_BORDER:Int        = 0x2A2D3C; // Crisp, subtle hairline structural border
    private static inline var _PALETTE_MUTED:Int         = 0x646C8A; // Slate muted text, subtle bevels & inactive dots
    private static inline var _PALETTE_FG:Int            = 0xEEEEF2; // High-contrast clean readable text
    private static inline var _PALETTE_WHITE:Int         = 0xFFFFFF; // Pure white title headings

    // Radiant Rad/Red Flagship Accent & Complementary States
    private static inline var _PALETTE_ACCENT:Int        = 0xFA2D4B; // Radiant Red primary accent
    private static inline var _PALETTE_ACCENT_HOVER:Int  = 0xFF4D68; // Bright radiant red hover
    private static inline var _PALETTE_PINK:Int          = 0xF43F7E; // Vibrant rose/pink accent
    private static inline var _PALETTE_CYAN:Int          = 0x38BDF8; // Modern sky cyan
    private static inline var _PALETTE_SUCCESS:Int       = 0x10B981; // Modern emerald green (active ON)
    private static inline var _PALETTE_SUCCESS_HOVER:Int = 0x34D399; // Bright emerald green hover
    private static inline var _PALETTE_WARNING:Int       = 0xF59E0B; // Modern amber warning (enhancing)
    private static inline var _PALETTE_SPECIAL:Int       = 0xFBBF24; // Radiant gold/yellow (current class)
    private static inline var _PALETTE_DANGER:Int        = 0xEF4444; // Clean danger red (close hover, delete)
    private static inline var _PALETTE_DANGER_HOVER:Int  = 0xFF5C5C; // Bright danger hover

    // =========================================================================
    // 1. GENERIC SURFACES & BACKGROUNDS
    // =========================================================================
    public static inline var COLOR_BG_BACKDROP:Int     = _PALETTE_BG_DARKER;   // Fullscreen dimmed backdrops
    public static inline var COLOR_BG_MAIN:Int         = _PALETTE_BG;          // Main window & widget body
    public static inline var COLOR_BG_DASHBOARD:Int    = _PALETTE_BG;          // Dashboard body
    public static inline var COLOR_BG_SURFACE:Int      = _PALETTE_BG_DARK;     // Sidebars, input plates, dock
    public static inline var COLOR_BG_PANEL:Int        = _PALETTE_BG_DARK;     // Sub-panels, headers
    public static inline var COLOR_BG_CARD:Int         = _PALETTE_BG_LIGHT;    // Elevated cards, resting buttons
    public static inline var COLOR_BG_CARD_HOVER:Int   = _PALETTE_BG_LIGHTER;  // Hovered cards & buttons
    public static inline var COLOR_BG_INPUT:Int        = _PALETTE_BG_DARK;     // Text input field plates
    public static inline var COLOR_BG_DIALOG:Int       = _PALETTE_BG;          // Dialog modal backgrounds
    public static inline var COLOR_BG_DIALOG_BAR:Int   = _PALETTE_BG_DARK;     // Dialog modal header bar
    public static inline var COLOR_BG_WIDGET:Int       = _PALETTE_BG;          // Modular widget backgrounds
    public static inline var COLOR_BG_HEADER:Int       = _PALETTE_BG_DARK;     // Header bars

    // =========================================================================
    // 2. GENERIC BORDERS & SEPARATORS
    // =========================================================================
    public static inline var COLOR_BORDER_DEFAULT:Int   = _PALETTE_BORDER;      // Standard container borders
    public static inline var COLOR_BORDER_PANEL:Int     = _PALETTE_BORDER;      // Panel separators
    public static inline var COLOR_BORDER_CARD:Int      = _PALETTE_BORDER;      // Card borders
    public static inline var COLOR_BORDER_HIGHLIGHT:Int = _PALETTE_MUTED;       // Hovered / highlighted borders
    public static inline var COLOR_BORDER_DIVIDER:Int   = _PALETTE_BORDER;      // Divider lines
    public static inline var COLOR_BORDER_FOCUS:Int     = _PALETTE_ACCENT;      // Focus state border
    public static inline var COLOR_BEVEL_LIGHT:Int      = _PALETTE_MUTED;       // Bevel top highlight line
    public static inline var COLOR_BEVEL_SUBTLE:Int     = _PALETTE_BORDER;      // Subtle bevel line

    // =========================================================================
    // 3. GENERIC ACCENTS (Brand & System)
    // =========================================================================
    public static inline var COLOR_ACCENT_PRIMARY:Int   = _PALETTE_ACCENT;       // Primary flagship accent (Rad/Red)
    public static inline var COLOR_ACCENT_HOVER:Int     = _PALETTE_ACCENT_HOVER; // Hover state for primary accent
    public static inline var COLOR_ACCENT_ACTIVE:Int    = 0xD61F3E;              // Pressed accent
    public static inline var COLOR_ACCENT_PILL:Int      = _PALETTE_ACCENT;       // Left sidebar pill & widget title bar
    public static inline var COLOR_ACCENT_CRIMSON:Int   = _PALETTE_ACCENT;       // Backwards-compat alias for primary accent
    public static inline var COLOR_ACCENT_SECONDARY:Int = _PALETTE_CYAN;         // Secondary accent
    public static inline var COLOR_ACCENT_CYAN:Int      = _PALETTE_CYAN;         // Informational cyan
    public static inline var COLOR_ACCENT_PINK:Int      = _PALETTE_PINK;         // Hot pink accent
    public static inline var COLOR_ACCENT_YELLOW:Int    = _PALETTE_SPECIAL;      // Yellow / gold highlight

    // =========================================================================
    // 4. GENERIC STATUS & STATE COLORS
    // =========================================================================
    public static inline var COLOR_STATUS_ACTIVE:Int       = _PALETTE_SUCCESS;       // Active ON / running status
    public static inline var COLOR_STATUS_ACTIVE_HOVER:Int = _PALETTE_SUCCESS_HOVER; // Active hover state
    public static inline var COLOR_STATUS_INACTIVE:Int     = _PALETTE_MUTED;         // Inactive OFF / resting dot
    public static inline var COLOR_STATUS_WARN:Int         = _PALETTE_WARNING;       // Warning / in-progress amber
    public static inline var COLOR_STATUS_ERROR:Int        = _PALETTE_DANGER;        // Error / danger red
    public static inline var COLOR_STATUS_ERROR_HOVER:Int  = _PALETTE_DANGER_HOVER;  // Error / danger red hover

    // =========================================================================
    // 5. GENERIC BUTTON COLORS
    // =========================================================================
    public static inline var COLOR_BTN_BG_NORMAL:Int        = _PALETTE_BG_LIGHT;
    public static inline var COLOR_BTN_BG_HOVER:Int         = _PALETTE_BORDER;
    public static inline var COLOR_BTN_BORDER_NORMAL:Int    = _PALETTE_BORDER;
    public static inline var COLOR_BTN_BORDER_HOVER:Int     = _PALETTE_MUTED;

    public static inline var COLOR_BTN_BG_PRIMARY:Int       = _PALETTE_ACCENT;
    public static inline var COLOR_BTN_BG_PRIMARY_HOVER:Int = _PALETTE_ACCENT_HOVER;
    public static inline var COLOR_BTN_BORDER_PRIMARY:Int   = _PALETTE_ACCENT_HOVER;

    public static inline var COLOR_BTN_BG_DANGER:Int        = _PALETTE_DANGER;
    public static inline var COLOR_BTN_BG_DANGER_HOVER:Int  = _PALETTE_DANGER_HOVER;

    // =========================================================================
    // 6. GENERIC TYPOGRAPHY
    // =========================================================================
    public static inline var COLOR_TEXT_PRIMARY:Int    = _PALETTE_FG;          // Standard readable text
    public static inline var COLOR_TEXT_TITLE:Int      = _PALETTE_WHITE;       // Bright white headings
    public static inline var COLOR_TEXT_SECONDARY:Int  = _PALETTE_MUTED;       // Subtitles / secondary labels
    public static inline var COLOR_TEXT_MUTED:Int      = _PALETTE_MUTED;       // Placeholder / disabled text
    public static inline var COLOR_TEXT_ACCENT:Int     = _PALETTE_ACCENT;      // Accent-colored text
    public static inline var COLOR_TEXT_SUCCESS:Int    = _PALETTE_SUCCESS;     // Green text
    public static inline var COLOR_TEXT_WARNING:Int    = _PALETTE_WARNING;     // Orange/amber text
    public static inline var COLOR_TEXT_DANGER:Int     = _PALETTE_DANGER;      // Red text
    public static inline var COLOR_TEXT_CYAN:Int       = _PALETTE_CYAN;        // Cyan text
    public static inline var COLOR_TEXT_PINK:Int       = _PALETTE_PINK;        // Pink text
    public static inline var COLOR_TEXT_YELLOW:Int     = _PALETTE_SPECIAL;     // Yellow text
    public static inline var COLOR_TEXT_ON_ACCENT:Int  = 0xFFFFFF;             // Crisp white text on rad/red button

    // =========================================================================
    // 7. FONTS & ALPHAS
    // =========================================================================
    public static inline var FONT_FAMILY:String = "_sans";

    public static inline var ALPHA_BACKDROP:Float  = 0.80;
    public static inline var ALPHA_DASHBOARD:Float = 0.98;
    public static inline var ALPHA_DIALOG:Float    = 0.98;
    public static inline var ALPHA_WIDGET:Float    = 0.95;
    public static inline var ALPHA_CARD:Float      = 0.97;

    // =========================================================================
    // 8. GEOMETRY & SCREEN BOUNDS
    // =========================================================================
    public static inline var CORNER_RADIUS:Float    = 6.0;
    public static inline var CORNER_RADIUS_SM:Float = 4.0;
    public static inline var CORNER_RADIUS_LG:Float = 8.0;
    public static inline var SCREEN_MARGIN:Float    = 4.0;
}
