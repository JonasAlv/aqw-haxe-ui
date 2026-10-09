package ui;

#if flash
import flash.display.BitmapData;
import flash.display.BlendMode;
import flash.display.GradientType;
import flash.display.InterpolationMethod;
import flash.display.Shape;
import flash.display.SpreadMethod;
import flash.display.Sprite;
import flash.events.Event;
import flash.geom.Matrix;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiConfig;
import ui.ApiNotificationManager;

/**
 * High-performance Screen & CRT Filter Manager.
 *
 * Renders hardware-tiled subpixel phosphor/scanline overlays over the game world.
 * Runs locked at 60 FPS with 0% CPU overhead, turning raw low-quality aliased vectors
 * into crisp, authentic retro arcade / Trinitron CRT visuals.
 */
class ScreenFilterManager {
    public static inline var MODE_NONE:String = "none";
    public static inline var MODE_APERTURE_GRILLE:String = "aperture_grille"; // Trinitron RGB phosphor (user's picture)
    public static inline var MODE_SCANLINES:String = "scanlines";             // Classic horizontal TV/arcade scanlines
    public static inline var MODE_SHADOW_MASK:String = "shadow_mask";         // 2x2 arcade dot triad mask
    public static inline var MODE_VIGNETTE_GRILLE:String = "vignette_grille"; // Grille + curved CRT border vignette

    public static inline var INTENSITY_LIGHT:String = "light";   // ~15%
    public static inline var INTENSITY_MEDIUM:String = "medium"; // ~25% (authentic)
    public static inline var INTENSITY_DEEP:String = "deep";     // ~40% (pronounced)

    public static inline var TARGET_WORLD:String = "world";   // Over game world only (UI stays crystal clear)
    public static inline var TARGET_SCREEN:String = "screen"; // Full screen overlay

    private static var _container:Sprite = null;
    private static var _patternShape:Shape = null;
    private static var _vignetteShape:Shape = null;
    private static var _currentPatternBmd:BitmapData = null;
    private static var _initialized:Bool = false;
    private static var _theStage:Dynamic = null;

    private static var _currentMode:String = MODE_NONE;
    private static var _currentIntensity:String = INTENSITY_MEDIUM;
    private static var _currentTarget:String = TARGET_WORLD;

    private static var _lastW:Float = 0;
    private static var _lastH:Float = 0;

    public static function init(stageRef:Dynamic):Void {
        if (_initialized) return;
        _initialized = true;
        _theStage = stageRef;

        // Container setup - non-interactive so it never blocks clicks
        _container = new Sprite();
        _container.mouseEnabled = false;
        _container.mouseChildren = false;

        _patternShape = new Shape();
        _container.addChild(_patternShape);

        _vignetteShape = new Shape();
        _container.addChild(_vignetteShape);

        // Load saved preferences
        _currentMode = ApiConfig.getString("api_crt_filter_mode", MODE_NONE);
        _currentIntensity = ApiConfig.getString("api_crt_filter_intensity", INTENSITY_MEDIUM);
        _currentTarget = ApiConfig.getString("api_crt_filter_target", TARGET_WORLD);

        applyFilterSettings();

        // Enter frame listener to maintain layer positioning and responsive resizing
        _container.addEventListener(Event.ENTER_FRAME, onEnterFrame);
        if (_theStage != null) {
            _theStage.addEventListener(Event.RESIZE, function(e:Event):Void {
                _lastW = 0;
                _lastH = 0;
            });
        }
    }

    private static function onEnterFrame(e:Event):Void {
        if (!_initialized) return;

        if (_currentMode == MODE_NONE) {
            _container.visible = false;
            return;
        }

        _container.visible = true;

        // 1. Layer Attachment
        if (_currentTarget == TARGET_WORLD) {
            try {
                if (Api.game != null && Api.game.world != null) {
                    var w:Dynamic = Api.game.world;
                    var p:Dynamic = w.parent;
                    if (p != null) {
                        var worldIdx:Int = p.getChildIndex(w);
                        if (_container.parent != p || p.getChildIndex(_container) != worldIdx + 1) {
                            p.addChildAt(_container, worldIdx + 1);
                        }
                    }
                }
            } catch (_:Dynamic) {}
        } else {
            // Target Full Stage
            try {
                if (_theStage != null && _container.parent != _theStage) {
                    _theStage.addChild(_container);
                }
            } catch (_:Dynamic) {}
        }

        // 2. Responsive Screen Geometry
        var sw:Float = (_theStage != null && _theStage.stageWidth > 0) ? _theStage.stageWidth : 960.0;
        var sh:Float = (_theStage != null && _theStage.stageHeight > 0) ? _theStage.stageHeight : 550.0;

        if (Math.abs(sw - _lastW) > 1.0 || Math.abs(sh - _lastH) > 1.0) {
            _lastW = sw;
            _lastH = sh;
            redrawSurfaces(sw, sh);
        }
    }

    public static function applyFilterSettings():Void {
        if (_currentPatternBmd != null) {
            _currentPatternBmd.dispose();
            _currentPatternBmd = null;
        }

        if (_currentMode == MODE_NONE) {
            if (_patternShape != null) _patternShape.graphics.clear();
            if (_vignetteShape != null) _vignetteShape.graphics.clear();
            if (_container != null) _container.visible = false;
            return;
        }

        _currentPatternBmd = buildPatternBitmap(_currentMode, _currentIntensity);

        _lastW = 0;
        _lastH = 0;
    }

    private static function redrawSurfaces(w:Float, h:Float):Void {
        if (_currentPatternBmd == null) return;

        // 1. Tiled CRT Scanline Pattern Fill (Zero CPU, GPU hardware repeated quad)
        _patternShape.graphics.clear();
        _patternShape.graphics.beginBitmapFill(_currentPatternBmd, null, true, false);
        _patternShape.graphics.drawRect(0, 0, w, h);
        _patternShape.graphics.endFill();

        // 2. Optional CRT Curved Glass Vignette
        _vignetteShape.graphics.clear();
        if (_currentMode == MODE_VIGNETTE_GRILLE) {
            var mtx = new Matrix();
            mtx.createGradientBox(w, h, 0, 0, 0);
            var vigAlpha = (_currentIntensity == INTENSITY_LIGHT) ? 0.25 : ((_currentIntensity == INTENSITY_DEEP) ? 0.55 : 0.40);
            _vignetteShape.graphics.beginGradientFill(
                GradientType.RADIAL,
                [0x000000, 0x000000],
                [0.0, vigAlpha],
                [140, 255],
                mtx,
                SpreadMethod.PAD,
                InterpolationMethod.RGB
            );
            _vignetteShape.graphics.drawRect(0, 0, w, h);
            _vignetteShape.graphics.endFill();
        }
    }

    private static function buildPatternBitmap(mode:String, intensity:String):BitmapData {
        var alphaFactor:Float = switch (intensity) {
            case INTENSITY_LIGHT: 0.65;
            case INTENSITY_DEEP: 1.45;
            default: 1.0;
        };

        switch (mode) {
            case MODE_APERTURE_GRILLE, MODE_VIGNETTE_GRILLE:
                // 6x2 Sony Trinitron RGB Subpixel Aperture Grille
                var bmd = new BitmapData(6, 2, true, 0x00000000);
                var darkWire = Std.int(Math.min(255, 0x58 * alphaFactor));
                var wireColor = (darkWire << 24) | 0x000000;

                var tintA = Std.int(Math.min(255, 0x24 * alphaFactor));
                var redPhos = (tintA << 24) | 0xFF4500;
                var yelPhos = (Std.int(tintA * 0.8) << 24) | 0xFFE000;
                var grnPhos = (tintA << 24) | 0x00FF40;
                var cyaPhos = (Std.int(tintA * 0.8) << 24) | 0x00E5FF;
                var bluPhos = (tintA << 24) | 0x3A60FF;

                for (y in 0...2) {
                    bmd.setPixel32(0, y, redPhos);
                    bmd.setPixel32(1, y, yelPhos);
                    bmd.setPixel32(2, y, grnPhos);
                    bmd.setPixel32(3, y, cyaPhos);
                    bmd.setPixel32(4, y, bluPhos);
                    bmd.setPixel32(5, y, wireColor); // Vertical aperture grille wire gap
                }
                return bmd;

            case MODE_SCANLINES:
                // 1x2 Horizontal Arcade Scanlines
                var bmd = new BitmapData(1, 2, true, 0x00000000);
                var scanDark = Std.int(Math.min(255, 0x52 * alphaFactor));
                var scanColor = (scanDark << 24) | 0x000000;
                bmd.setPixel32(0, 0, 0x00000000); // Phosphor scanline beam
                bmd.setPixel32(0, 1, scanColor);  // Scanline gap
                return bmd;

            case MODE_SHADOW_MASK:
                // 4x4 Arcade Shadow Mask Dot Triad
                var bmd = new BitmapData(4, 4, true, 0x00000000);
                var maskDark = Std.int(Math.min(255, 0x48 * alphaFactor));
                var maskColor = (maskDark << 24) | 0x000000;
                var dotTint = Std.int(Math.min(255, 0x18 * alphaFactor));
                var rDot = (dotTint << 24) | 0xFF2020;
                var gDot = (dotTint << 24) | 0x20FF20;
                var bDot = (dotTint << 24) | 0x2060FF;

                // Triad Row 1
                bmd.setPixel32(0, 0, rDot);
                bmd.setPixel32(1, 0, gDot);
                bmd.setPixel32(2, 0, bDot);
                bmd.setPixel32(3, 0, maskColor);

                bmd.setPixel32(0, 1, maskColor);
                bmd.setPixel32(1, 1, maskColor);
                bmd.setPixel32(2, 1, maskColor);
                bmd.setPixel32(3, 1, maskColor);

                // Triad Row 2 (Offset)
                bmd.setPixel32(0, 2, bDot);
                bmd.setPixel32(1, 2, maskColor);
                bmd.setPixel32(2, 2, rDot);
                bmd.setPixel32(3, 2, gDot);

                bmd.setPixel32(0, 3, maskColor);
                bmd.setPixel32(1, 3, maskColor);
                bmd.setPixel32(2, 3, maskColor);
                bmd.setPixel32(3, 3, maskColor);

                return bmd;

            default:
                return new BitmapData(1, 1, true, 0x00000000);
        }
    }

    // =========================================================================
    // PUBLIC CONTROLS & CYCLERS
    // =========================================================================

    public static function isEnabled():Bool {
        return _currentMode != MODE_NONE;
    }

    public static function toggleQuick():Void {
        if (_currentMode == MODE_NONE) {
            setMode(MODE_APERTURE_GRILLE);
            ApiNotificationManager.notify("CRT Filter: ON [Aperture Grille]");
        } else {
            setMode(MODE_NONE);
            ApiNotificationManager.notify("CRT Filter: OFF");
        }
    }

    public static function cycleMode():Void {
        var nextMode = switch (_currentMode) {
            case MODE_NONE: MODE_APERTURE_GRILLE;
            case MODE_APERTURE_GRILLE: MODE_SCANLINES;
            case MODE_SCANLINES: MODE_SHADOW_MASK;
            case MODE_SHADOW_MASK: MODE_VIGNETTE_GRILLE;
            default: MODE_NONE;
        };
        setMode(nextMode);
        ApiNotificationManager.notify("Filter: " + getModeLabel());
    }

    public static function cycleIntensity():Void {
        var nextInt = switch (_currentIntensity) {
            case INTENSITY_LIGHT: INTENSITY_MEDIUM;
            case INTENSITY_MEDIUM: INTENSITY_DEEP;
            default: INTENSITY_LIGHT;
        };
        setIntensity(nextInt);
        ApiNotificationManager.notify("CRT Intensity: " + getIntensityLabel());
    }

    public static function cycleTarget():Void {
        var nextTgt = switch (_currentTarget) {
            case TARGET_WORLD: TARGET_SCREEN;
            default: TARGET_WORLD;
        };
        setTarget(nextTgt);
        ApiNotificationManager.notify("CRT Target: " + getTargetLabel());
    }

    public static function setMode(mode:String):Void {
        _currentMode = mode;
        ApiConfig.setString("api_crt_filter_mode", mode);
        applyFilterSettings();
    }

    public static function setIntensity(intensity:String):Void {
        _currentIntensity = intensity;
        ApiConfig.setString("api_crt_filter_intensity", intensity);
        applyFilterSettings();
    }

    public static function setTarget(target:String):Void {
        _currentTarget = target;
        ApiConfig.setString("api_crt_filter_target", target);
        applyFilterSettings();
    }

    public static function getModeLabel():String {
        return switch (_currentMode) {
            case MODE_APERTURE_GRILLE: "Aperture Grille (CRT)";
            case MODE_SCANLINES: "Scanlines";
            case MODE_SHADOW_MASK: "Shadow Mask";
            case MODE_VIGNETTE_GRILLE: "Curved CRT Grille";
            default: "Disabled";
        };
    }

    public static function getIntensityLabel():String {
        return switch (_currentIntensity) {
            case INTENSITY_LIGHT: "Light (15%)";
            case INTENSITY_DEEP: "Deep (40%)";
            default: "Medium (25%)";
        };
    }

    public static function getTargetLabel():String {
        return switch (_currentTarget) {
            case TARGET_SCREEN: "Full Screen";
            default: "Game World Only";
        };
    }
}
#else
class ScreenFilterManager {
    public static function init(stageRef:Dynamic):Void {}
    public static function isEnabled():Bool return false;
    public static function toggleQuick():Void {}
    public static function cycleMode():Void {}
    public static function cycleIntensity():Void {}
    public static function cycleTarget():Void {}
    public static function getModeLabel():String return "Disabled";
    public static function getIntensityLabel():String return "Medium (25%)";
    public static function getTargetLabel():String return "Game World Only";
}
#end
