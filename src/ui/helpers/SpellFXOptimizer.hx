package ui.helpers;

#if flash
import flash.display.DisplayObject;
import flash.display.DisplayObjectContainer;
import flash.events.Event;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiConfig;

/**
 * SpellFXOptimizer:
 * Automatically reduces expensive multi-pass filter convolution on spell animations
 * down to 1x pass (BitmapFilterQuality.LOW) and clamps excessive blur kernels,
 * preserving colors and glows while eliminating CPU lag.
 */
class SpellFXOptimizer {
    public static inline var CONFIG_KEY:String = "api_optimize_spell_fx";

    private static var _initialized:Bool = false;
    private static var _hookedChars:Dynamic = null;

    public static function init(gameRef:Dynamic = null):Void {
        if (_initialized) return;
        _initialized = true;

        if (isEnabled()) {
            ensureHook();
        }

        try {
            if (Api.dispatcher != null) {
                Api.dispatcher.addEventListener("zoneEntered", function(_):Void {
                    if (isEnabled()) ensureHook();
                });
            }
        } catch (_:Dynamic) {}
    }

    public static inline function isEnabled():Bool {
        return ApiConfig.getBool(CONFIG_KEY, true);
    }

    public static function setEnabled(v:Bool):Void {
        ApiConfig.setBool(CONFIG_KEY, v);
        if (v) {
            ensureHook();
        }
    }

    public static function ensureHook():Void {
        var g:Dynamic = Api.game;
        if (g == null || g.world == null) return;
        var chars:Dynamic = g.world.CHARS;
        if (chars == null || chars == _hookedChars) return;
        _hookedChars = chars;
        try {
            chars.addEventListener(Event.ADDED, onCharChildAdded, false, 0, true);
        } catch (_:Dynamic) {}
    }

    private static function onCharChildAdded(e:Event):Void {
        if (!isEnabled()) return;
        var child:Dynamic = e.target;
        if (child == null) return;
        if (Std.isOfType(child, DisplayObject)) {
            optimizeFilters(cast child);
            try {
                child.addEventListener(Event.ADDED, onSpellChildAdded, false, 0, true);
            } catch (_:Dynamic) {}
        }
    }

    private static function onSpellChildAdded(e:Event):Void {
        if (!isEnabled()) return;
        var sub:Dynamic = e.target;
        if (sub != null && sub != e.currentTarget && Std.isOfType(sub, DisplayObject)) {
            optimizeFilters(cast sub);
        }
    }

    public static function optimizeFilters(clip:DisplayObject):Void {
        if (clip == null) return;
        try {
            var filters:Array<Dynamic> = clip.filters;
            if (filters != null && filters.length > 0) {
                var changed:Bool = false;
                for (i in 0...filters.length) {
                    var f:Dynamic = filters[i];
                    if (f == null) continue;

                    // Lower filter quality to 1x (BitmapFilterQuality.LOW)
                    if (Reflect.hasField(f, "quality")) {
                        var q:Int = Reflect.field(f, "quality");
                        if (q > 1) {
                            Reflect.setField(f, "quality", 1);
                            changed = true;
                        }
                    }

                    // Clamp blur radius to prevent expensive 16px+ convolution kernels
                    if (Reflect.hasField(f, "blurX")) {
                        var bx:Float = Reflect.field(f, "blurX");
                        if (bx > 6.0) {
                            Reflect.setField(f, "blurX", 6.0);
                            changed = true;
                        }
                    }
                    if (Reflect.hasField(f, "blurY")) {
                        var by:Float = Reflect.field(f, "blurY");
                        if (by > 6.0) {
                            Reflect.setField(f, "blurY", 6.0);
                            changed = true;
                        }
                    }
                }
                if (changed) {
                    clip.filters = cast filters;
                }
            }
        } catch (_:Dynamic) {}

        if (Std.isOfType(clip, DisplayObjectContainer)) {
            var container:DisplayObjectContainer = cast clip;
            try {
                var count = container.numChildren;
                for (i in 0...count) {
                    var sub = container.getChildAt(i);
                    if (sub != null) {
                        optimizeFilters(sub);
                    }
                }
            } catch (_:Dynamic) {}
        }
    }
}
#else
class SpellFXOptimizer {
    public static function init(gameRef:Dynamic = null):Void {}
    public static inline function isEnabled():Bool return true;
    public static inline function setEnabled(v:Bool):Void {}
}
#end
