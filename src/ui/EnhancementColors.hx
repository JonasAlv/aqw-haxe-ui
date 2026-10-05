package ui;

class EnhancementColors {
    // Base Enhancements (from in-game shops)
    public static inline var FIGHTER:Int = 0xB23838;       // Crimson Red
    public static inline var THIEF:Int = 0x2E7D32;         // Forest Green
    public static inline var WIZARD:Int = 0x3F51B5;        // Royal Blue
    public static inline var HEALER:Int = 0x9E9E9E;        // Silver / Grey
    public static inline var HYBRID:Int = 0x8D6E63;        // Tan / Bronze Brown
    public static inline var LUCKY:Int = 0x9C27B0;         // Violet / Purple
    public static inline var SPELLBREAKER:Int = 0xD35400;  // Burnt Orange / Copper

    // Forge Enhancements (from in-game /forge shops)
    public static inline var FORGE_DEFAULT:Int = 0xFFA726; // Signature Forge Amber / Orange
    public static inline var FORGE_RED:Int = 0xD32F2F;     // Dauntless, Anima (STR / Physical)
    public static inline var FORGE_BLUE:Int = 0x3F51B5;    // Elysium (INT / Magic)
    public static inline var FORGE_CYAN:Int = 0x00BCD4;    // Pneuma (Sky Blue / Cyan)
    public static inline var FORGE_GREEN:Int = 0x4CAF50;   // Vim (Lime Green)
    public static inline var FORGE_YELLOW:Int = 0xFDD835;  // Examen (Golden Yellow)
    public static inline var FORGE_PINK:Int = 0xE91E63;    // Hearty (Hot Pink / Magenta)
    public static inline var FORGE_SILVER:Int = 0xA0A0A0;  // Acheron (Silver / Metal Grey)

    public static function isAwe(name:String):Bool {
        if (name == null) return false;
        var n = normalize(name);
        return (n == "spiral_carve" || n == "awe_blast" ||
                n == "health_vamp" || n == "mana_vamp" ||
                n == "powerword_die");
    }

    public static function getColor(name:String, ?baseType:String):Null<Int> {
        if (name == null || name == "" || name == "None") return null;
        var n = normalize(name);

        // Awe procs inherit base enhancement color (e.g. Lucky Awe = Purple, Wizard Awe = Royal Blue)
        if (isAwe(n)) {
            if (baseType != null && baseType != "" && baseType != "None") {
                var bCol = getColor(baseType);
                if (bCol != null) return bCol;
            }
            return LUCKY; // Default Lucky Awe
        }

        return switch (n) {
            // Base Types
            case "fighter": FIGHTER;
            case "thief": THIEF;
            case "wizard": WIZARD;
            case "healer": HEALER;
            case "hybrid": HYBRID;
            case "lucky": LUCKY;
            case "spellbreaker": SPELLBREAKER;

            // Specialized Forge Items
            case "dauntless", "anima": FORGE_RED;
            case "elysium": FORGE_BLUE;
            case "pneuma": FORGE_CYAN;
            case "vim": FORGE_GREEN;
            case "examen": FORGE_YELLOW;
            case "hearty": FORGE_PINK;
            case "acheron": FORGE_SILVER;

            // Signature Forge Items (Amber / Orange)
            case "forge", "smite", "valiance", "arcanas_concerto", "arcanasconcerto",
                 "lacerate", "praxis", "ravenous",
                 "absolution", "avarice", "lament", "penitence", "vainglory": FORGE_DEFAULT;

            default: null;
        }
    }

    private static function normalize(s:String):String {
        if (s == null) return "";
        var k = StringTools.trim(s).toLowerCase();
        k = StringTools.replace(k, " ", "_");
        k = StringTools.replace(k, "'", "");
        k = StringTools.replace(k, "-", "_");
        return k;
    }
}
