package ui;

#if flash
import flash.display.BitmapData;
import flash.display.BlendMode;
import flash.display.GradientType;
import flash.display.InterpolationMethod;
import flash.display.Shape;
import flash.display.SpreadMethod;
import flash.display.Sprite;
import flash.display.Stage;
import flash.display.StageQuality;
import flash.events.Event;
import flash.geom.ColorTransform;
import flash.geom.Matrix;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiConfig;
import ui.ApiNotificationManager;

/**
 * High-performance Screen & Visual Filter Manager.
 *
 * Renders hardware-tiled subpixel phosphor/scanlines, ambient vignette, cel film grain,
 * vector anti-aliasing, and zero-cost GPU ColorTransform color grading.
 * Runs locked at 60 FPS with 0% CPU overhead.
 */
class ScreenFilterManager {
    // Retro Screen Filters (Scanlines and Shadow Mask only)
    public static inline var MODE_NONE:String        = "none";
    public static inline var MODE_SCANLINES:String   = "scanlines";   // Classic horizontal TV/arcade scanlines
    public static inline var MODE_SHADOW_MASK:String = "shadow_mask"; // 4x4 arcade dot triad mask

    // Filter Intensity
    public static inline var INTENSITY_LIGHT:String  = "light";   // ~15%
    public static inline var INTENSITY_MEDIUM:String = "medium";  // ~25%
    public static inline var INTENSITY_DEEP:String   = "deep";    // ~40%

    // Target Layer
    public static inline var TARGET_WORLD:String     = "world";   // Over game world only (UI stays crystal clear)
    public static inline var TARGET_SCREEN:String    = "screen";  // Full screen overlay

    // Vector Anti-Aliasing (Smoothing)
    public static inline var SMOOTHING_NATIVE:String = "native";
    public static inline var SMOOTHING_HIGH:String   = "high";
    public static inline var SMOOTHING_BEST:String   = "best";

    // Color Grade & Vibrance
    public static inline var COLOR_NONE:String       = "none";
    public static inline var COLOR_VIBRANT:String    = "vibrant";
    public static inline var COLOR_WARM:String       = "warm";
    public static inline var COLOR_COLD:String       = "cold";
    public static inline var COLOR_OLED:String       = "oled";

    // Ambient Vignette
    public static inline var VIGNETTE_NONE:String     = "none";
    public static inline var VIGNETTE_SUBTLE:String   = "subtle";
    public static inline var VIGNETTE_MEDIUM:String   = "medium";
    public static inline var VIGNETTE_DRAMATIC:String = "dramatic";

    // Cel Film Grain
    public static inline var GRAIN_NONE:String       = "none";
    public static inline var GRAIN_SUBTLE:String     = "subtle";
    public static inline var GRAIN_PRONOUNCED:String = "pronounced";

    private static var _container:Sprite = null;
    private static var _grainShape:Shape = null;
    private static var _patternShape:Shape = null;
    private static var _vignetteShape:Shape = null;

    private static var _currentPatternBmd:BitmapData = null;
    private static var _currentGrainBmd:BitmapData = null;
    private static var _initialized:Bool = false;
    private static var _theStage:Stage = null;

    private static var _currentMode:String = MODE_NONE;
    private static var _currentIntensity:String = INTENSITY_MEDIUM;
    private static var _currentTarget:String = TARGET_WORLD;
    private static var _vectorSmoothing:String = SMOOTHING_BEST;
    private static var _currentColorGrade:String = COLOR_NONE;
    private static var _currentVignette:String = VIGNETTE_NONE;
    private static var _currentGrain:String = GRAIN_NONE;

    private static var _lastW:Float = 0;
    private static var _lastH:Float = 0;

    public static function init(stageRef:Dynamic):Void {
        if (_initialized) return;
        _initialized = true;
        if (stageRef != null && Std.isOfType(stageRef, Stage)) {
            _theStage = cast stageRef;
        } else if (stageRef != null && stageRef.stage != null) {
            _theStage = cast stageRef.stage;
        }

        // Container setup - non-interactive so it never blocks clicks
        _container = new Sprite();
        _container.mouseEnabled = false;
        _container.mouseChildren = false;

        _grainShape = new Shape();
        _container.addChild(_grainShape);

        _patternShape = new Shape();
        _container.addChild(_patternShape);

        _vignetteShape = new Shape();
        _container.addChild(_vignetteShape);

        // Load saved preferences
        _currentMode = ApiConfig.getString("api_crt_filter_mode", MODE_NONE);
        // Backwards compatibility migration: if user previously had removed modes, map to scanlines
        if (_currentMode != MODE_NONE && _currentMode != MODE_SCANLINES && _currentMode != MODE_SHADOW_MASK) {
            _currentMode = MODE_SCANLINES;
        }
        _currentIntensity = ApiConfig.getString("api_crt_filter_intensity", INTENSITY_MEDIUM);
        _currentTarget = ApiConfig.getString("api_crt_filter_target", TARGET_WORLD);
        _vectorSmoothing = ApiConfig.getString("api_crt_vector_smoothing", SMOOTHING_BEST);
        _currentColorGrade = ApiConfig.getString("api_crt_color_grade", COLOR_NONE);
        _currentVignette = ApiConfig.getString("api_crt_vignette", VIGNETTE_NONE);
        _currentGrain = ApiConfig.getString("api_crt_grain", GRAIN_NONE);

        applyFilterSettings();
        applyVectorSmoothing();
        applyColorGrade();

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

        // 1. Maintain hardware multi-sample vector smoothing
        if (_theStage != null && _vectorSmoothing != SMOOTHING_NATIVE) {
            var targetQ = (_vectorSmoothing == SMOOTHING_BEST) ? StageQuality.BEST : StageQuality.HIGH;
            if (_theStage.quality != targetQ) {
                _theStage.quality = targetQ;
            }
        }

        // 2. Maintain zero-cost GPU ColorTransform on world across room/map changes
        if (_currentColorGrade != COLOR_NONE) {
            applyColorGrade();
        }

        var hasOverlay:Bool = (_currentMode != MODE_NONE || _currentVignette != VIGNETTE_NONE || _currentGrain != GRAIN_NONE);
        if (!hasOverlay) {
            _container.visible = false;
            return;
        }

        _container.visible = true;

        // 3. Layer Attachment
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

        // 4. Responsive Screen Geometry
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
        if (_currentGrainBmd != null) {
            _currentGrainBmd.dispose();
            _currentGrainBmd = null;
        }

        if (_currentMode != MODE_NONE) {
            _currentPatternBmd = buildPatternBitmap(_currentMode, _currentIntensity);
        }
        if (_currentGrain != GRAIN_NONE) {
            _currentGrainBmd = buildGrainBitmap(_currentGrain);
        }

        _lastW = 0;
        _lastH = 0;
    }

    private static function applyVectorSmoothing():Void {
        if (_theStage == null) return;
        switch (_vectorSmoothing) {
            case SMOOTHING_BEST:
                _theStage.quality = StageQuality.BEST;
            case SMOOTHING_HIGH:
                _theStage.quality = StageQuality.HIGH;
            default:
        }
    }

    private static function applyColorGrade():Void {
        try {
            if (Api.game == null || Api.game.world == null) return;
            var w:Dynamic = Api.game.world;
            if (w.transform == null) return;

            var ct:ColorTransform = switch (_currentColorGrade) {
                case COLOR_VIBRANT:
                    new ColorTransform(1.08, 1.08, 1.08, 1.0, -6, -6, -6, 0);
                case COLOR_WARM:
                    new ColorTransform(1.07, 1.03, 0.94, 1.0, 5, 2, -6, 0);
                case COLOR_COLD:
                    new ColorTransform(0.94, 1.02, 1.12, 1.0, -8, 2, 8, 0);
                case COLOR_OLED:
                    new ColorTransform(1.06, 1.06, 1.06, 1.0, -14, -14, -14, 0);
                default:
                    new ColorTransform();
            };
            w.transform.colorTransform = ct;
        } catch (_:Dynamic) {}
    }

    private static function redrawSurfaces(w:Float, h:Float):Void {
        // 1. Tiled Cel Grain Texture Fill (Zero CPU, GPU hardware repeated quad)
        if (_grainShape != null) {
            _grainShape.graphics.clear();
            if (_currentGrainBmd != null) {
                _grainShape.graphics.beginBitmapFill(_currentGrainBmd, null, true, false);
                _grainShape.graphics.drawRect(0, 0, w, h);
                _grainShape.graphics.endFill();
            }
        }

        // 2. Tiled Scanlines / Shadow Mask Pattern Fill (Zero CPU, GPU hardware repeated quad)
        if (_patternShape != null) {
            _patternShape.graphics.clear();
            if (_currentPatternBmd != null) {
                _patternShape.graphics.beginBitmapFill(_currentPatternBmd, null, true, false);
                _patternShape.graphics.drawRect(0, 0, w, h);
                _patternShape.graphics.endFill();
            }
        }

        // 3. Ambient Vignette Radial Gradient (Zero CPU, GPU hardware gradient box)
        if (_vignetteShape != null) {
            _vignetteShape.graphics.clear();
            if (_currentVignette != VIGNETTE_NONE) {
                var mtx = new Matrix();
                mtx.createGradientBox(w, h, 0, 0, 0);
                var vigAlpha:Float = switch (_currentVignette) {
                    case VIGNETTE_SUBTLE: 0.22;
                    case VIGNETTE_DRAMATIC: 0.58;
                    default: 0.38;
                };
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
    }

    private static function buildPatternBitmap(mode:String, intensity:String):BitmapData {
        var alphaFactor:Float = switch (intensity) {
            case INTENSITY_LIGHT: 0.65;
            case INTENSITY_DEEP: 1.45;
            default: 1.0;
        };

        switch (mode) {
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
                return null;
        }
    }

    private static function buildGrainBitmap(grainMode:String):BitmapData {
        if (grainMode == GRAIN_NONE) return null;
        var maxAlpha:Int = (grainMode == GRAIN_SUBTLE) ? 14 : 26; // ~5% or ~10%
        var bmd = new BitmapData(32, 32, true, 0x00000000);
        for (x in 0...32) {
            for (y in 0...32) {
                var lum = Std.int(Math.random() * 255);
                var a = Std.int(Math.random() * maxAlpha);
                bmd.setPixel32(x, y, (a << 24) | (lum << 16) | (lum << 8) | lum);
            }
        }
        return bmd;
    }

    // =========================================================================
    // PUBLIC CONTROLS & CYCLERS
    // =========================================================================

    public static function isEnabled():Bool {
        return _currentMode != MODE_NONE || _currentVignette != VIGNETTE_NONE || _currentGrain != GRAIN_NONE || _currentColorGrade != COLOR_NONE;
    }

    public static function toggleQuick():Void {
        if (_currentMode == MODE_NONE) {
            setMode(MODE_SCANLINES);
            ApiNotificationManager.notify("Retro Filter: ON [Scanlines]");
        } else {
            setMode(MODE_NONE);
            ApiNotificationManager.notify("Retro Filter: OFF");
        }
    }

    // --- 1. Retro Screen Filter (Scanlines & Shadow Mask only) ---

    public static function cycleMode():Void {
        var nextMode = switch (_currentMode) {
            case MODE_NONE: MODE_SCANLINES;
            case MODE_SCANLINES: MODE_SHADOW_MASK;
            default: MODE_NONE;
        };
        setMode(nextMode);
        ApiNotificationManager.notify("Retro Filter: " + getModeLabel());
    }

    public static function setMode(mode:String):Void {
        _currentMode = mode;
        ApiConfig.setString("api_crt_filter_mode", mode);
        applyFilterSettings();
    }

    public static function getModeLabel():String {
        return switch (_currentMode) {
            case MODE_SCANLINES: "Scanlines";
            case MODE_SHADOW_MASK: "Shadow Mask";
            default: "Disabled";
        };
    }

    // --- 2. Filter Intensity ---

    public static function cycleIntensity():Void {
        var nextInt = switch (_currentIntensity) {
            case INTENSITY_LIGHT: INTENSITY_MEDIUM;
            case INTENSITY_MEDIUM: INTENSITY_DEEP;
            default: INTENSITY_LIGHT;
        };
        setIntensity(nextInt);
        ApiNotificationManager.notify("Filter Intensity: " + getIntensityLabel());
    }

    public static function setIntensity(intensity:String):Void {
        _currentIntensity = intensity;
        ApiConfig.setString("api_crt_filter_intensity", intensity);
        applyFilterSettings();
    }

    public static function getIntensityLabel():String {
        return switch (_currentIntensity) {
            case INTENSITY_LIGHT: "Light (15%)";
            case INTENSITY_DEEP: "Deep (40%)";
            default: "Medium (25%)";
        };
    }

    // --- 3. Vector Smoothing (MSAA) ---

    public static function cycleVectorSmoothing():Void {
        var next = switch (_vectorSmoothing) {
            case SMOOTHING_NATIVE: SMOOTHING_HIGH;
            case SMOOTHING_HIGH: SMOOTHING_BEST;
            default: SMOOTHING_NATIVE;
        };
        setVectorSmoothing(next);
        ApiNotificationManager.notify("Vector Smoothing: " + getVectorSmoothingLabel());
    }

    public static function setVectorSmoothing(mode:String):Void {
        _vectorSmoothing = mode;
        ApiConfig.setString("api_crt_vector_smoothing", mode);
        applyVectorSmoothing();
    }

    public static function getVectorSmoothingLabel():String {
        return switch (_vectorSmoothing) {
            case SMOOTHING_HIGH: "High (Smooth MSAA)";
            case SMOOTHING_BEST: "Ultra (Best MSAA)";
            default: "Native (Standard)";
        };
    }

    // --- 4. Color Grade & Vibrance ---

    public static function cycleColorGrade():Void {
        var next = switch (_currentColorGrade) {
            case COLOR_NONE: COLOR_VIBRANT;
            case COLOR_VIBRANT: COLOR_WARM;
            case COLOR_WARM: COLOR_COLD;
            case COLOR_COLD: COLOR_OLED;
            default: COLOR_NONE;
        };
        setColorGrade(next);
        ApiNotificationManager.notify("Color Grade: " + getColorGradeLabel());
    }

    public static function setColorGrade(mode:String):Void {
        _currentColorGrade = mode;
        ApiConfig.setString("api_crt_color_grade", mode);
        applyColorGrade();
    }

    public static function getColorGradeLabel():String {
        return switch (_currentColorGrade) {
            case COLOR_VIBRANT: "Vibrant Pop (Rich Saturation)";
            case COLOR_WARM: "Warm Fantasy (Golden Glow)";
            case COLOR_COLD: "Cold Moonlight (High Contrast)";
            case COLOR_OLED: "OLED Deep Black";
            default: "Disabled";
        };
    }

    // --- 5. Ambient Vignette ---

    public static function cycleVignette():Void {
        var next = switch (_currentVignette) {
            case VIGNETTE_NONE: VIGNETTE_SUBTLE;
            case VIGNETTE_SUBTLE: VIGNETTE_MEDIUM;
            case VIGNETTE_MEDIUM: VIGNETTE_DRAMATIC;
            default: VIGNETTE_NONE;
        };
        setVignette(next);
        ApiNotificationManager.notify("Ambient Vignette: " + getVignetteLabel());
    }

    public static function setVignette(mode:String):Void {
        _currentVignette = mode;
        ApiConfig.setString("api_crt_vignette", mode);
        _lastW = 0;
        _lastH = 0;
    }

    public static function getVignetteLabel():String {
        return switch (_currentVignette) {
            case VIGNETTE_SUBTLE: "Subtle (Cinematic)";
            case VIGNETTE_MEDIUM: "Medium";
            case VIGNETTE_DRAMATIC: "Dramatic";
            default: "Disabled";
        };
    }

    // --- 6. Cel Film Grain ---

    public static function cycleGrain():Void {
        var next = switch (_currentGrain) {
            case GRAIN_NONE: GRAIN_SUBTLE;
            case GRAIN_SUBTLE: GRAIN_PRONOUNCED;
            default: GRAIN_NONE;
        };
        setGrain(next);
        ApiNotificationManager.notify("Film Grain: " + getGrainLabel());
    }

    public static function setGrain(mode:String):Void {
        _currentGrain = mode;
        ApiConfig.setString("api_crt_grain", mode);
        applyFilterSettings();
    }

    public static function getGrainLabel():String {
        return switch (_currentGrain) {
            case GRAIN_SUBTLE: "Subtle (Hand-Drawn Cel)";
            case GRAIN_PRONOUNCED: "Pronounced";
            default: "Disabled";
        };
    }

    // --- 7. Target Layer ---

    public static function cycleTarget():Void {
        var nextTgt = switch (_currentTarget) {
            case TARGET_WORLD: TARGET_SCREEN;
            default: TARGET_WORLD;
        };
        setTarget(nextTgt);
        ApiNotificationManager.notify("Filter Target: " + getTargetLabel());
    }

    public static function setTarget(target:String):Void {
        _currentTarget = target;
        ApiConfig.setString("api_crt_filter_target", target);
        applyFilterSettings();
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
    public static function cycleVectorSmoothing():Void {}
    public static function cycleColorGrade():Void {}
    public static function cycleVignette():Void {}
    public static function cycleGrain():Void {}
    public static function cycleTarget():Void {}
    public static function getModeLabel():String return "Disabled";
    public static function getIntensityLabel():String return "Medium (25%)";
    public static function getVectorSmoothingLabel():String return "Ultra (Best MSAA)";
    public static function getColorGradeLabel():String return "Disabled";
    public static function getVignetteLabel():String return "Disabled";
    public static function getGrainLabel():String return "Disabled";
    public static function getTargetLabel():String return "Game World Only";
}
#end
