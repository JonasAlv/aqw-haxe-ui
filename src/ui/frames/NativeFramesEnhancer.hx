package ui.frames;

#if flash
import flash.Lib;
import flash.display.DisplayObject;
import flash.display.MovieClip;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.geom.ColorTransform;
import flash.geom.Point;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import com.aqwapi.Api;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.utils.ApiConfig;
import ui.ApiStyle;

/**
 * NativeFramesEnhancer:
 * Directly enhances AQW's native player (mcPortrait) and target (mcPortraitTarget) frames.
 *
 * Text-Only Enhancements:
 * - Clean health text layout: formatted curHP / maxHP (e.g. 2,995 / 2,995 or 100M / 100M) on the left, live % on the right.
 * - Zero graphics drawing or bar modifications: leaves native AQW health bar art and fills 100% untouched.
 * - Right-click context menu on player and target portraits (opens cMenu directly at mouse cursor).
 * - Full native fidelity: preserves native portrait medallion, art, animations, and native auras.
 */
class NativeFramesEnhancer {
    // Config keys
    public static inline var CONFIG_ENHANCED:String       = "api_native_frames_enhanced";
    public static inline var CONFIG_HP_PERCENT:String     = "api_native_frames_hp_pct";
    public static inline var CONFIG_RIGHT_CLICK:String    = "api_native_frames_right_click";

    // Health Colors (used by Nameplates and external frames)
    public static inline var COLOR_HP_HEALTHY:Int        = 0x22C55E; // Healthy vibrant green (> 50%)
    public static inline var COLOR_HP_LOW:Int            = 0xEAB308; // Getting low gold/yellow (20% - 50%)
    public static inline var COLOR_HP_CRITICAL:Int       = 0xEF4444; // Critical danger red (< 20%)
    public static inline var HP_THRESHOLD_HEALTHY:Float  = 0.50;
    public static inline var HP_THRESHOLD_CRITICAL:Float = 0.20;

    private static var _initialized:Bool = false;
    private static var _theStage:Stage = null;

    private static var _playerBarWidth:Float = 0;
    private static var _targetBarWidth:Float = 0;

    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {
        if (_initialized) return;
        _initialized = true;

        var theStage:Dynamic = null;
        if (pocket != null && Std.isOfType(pocket, Stage)) {
            theStage = pocket;
        } else if (pocket != null && Reflect.hasField(pocket, "stage") && pocket.stage != null) {
            theStage = pocket.stage;
        } else if (overlay != null && Reflect.hasField(overlay, "stage") && overlay.stage != null) {
            theStage = overlay.stage;
        } else {
            try {
                if (Lib.current != null && Lib.current.stage != null) {
                    theStage = Lib.current.stage;
                }
            } catch (_:Dynamic) {}
        }
        if (theStage == null && Api.game != null && Api.game.stage != null) {
            theStage = Api.game.stage;
        }
        _theStage = theStage;

        if (_theStage != null) {
            _theStage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
        } else if (overlay != null && Std.isOfType(overlay, DisplayObject)) {
            cast(overlay, DisplayObject).addEventListener(Event.ENTER_FRAME, onEnterFrame);
        }

        if (Api.dispatcher != null) {
            Api.dispatcher.addEventListener(ApiEvent.ACCOUNT_CHANGED, function(_:Dynamic):Void {
                reloadFromConfig();
            });
        }
    }

    private static function onEnterFrame(e:Event):Void {
        updateFrames();
    }

    public static function updateFrames():Void {
        var g:Dynamic = Api.game;
        if (g == null || g.ui == null) return;

        // Ensure ENTER_FRAME listener is running on stage if stage was acquired late
        if (_theStage == null && g.stage != null) {
            _theStage = g.stage;
            _theStage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
        }

        setupRightClickMenu(g);
        updatePlayerFrame(g);
        updateTargetFrame(g);
    }

    // =========================================================================
    // HEALTH COLOR GRADIENT (Utility for Nameplates & Party Frames)
    // =========================================================================
    public static function getHealthColor(ratio:Float):Int {
        if (ratio >= HP_THRESHOLD_HEALTHY) {
            var t:Float = (ratio - HP_THRESHOLD_HEALTHY) / (1.0 - HP_THRESHOLD_HEALTHY);
            var r = Std.int(0xEA + (0x22 - 0xEA) * t);
            var g = Std.int(0xB3 + (0xC5 - 0xB3) * t);
            var b = Std.int(0x08 + (0x5E - 0x08) * t);
            return (r << 16) | (g << 8) | b;
        } else if (ratio >= HP_THRESHOLD_CRITICAL) {
            var t:Float = (ratio - HP_THRESHOLD_CRITICAL) / (HP_THRESHOLD_HEALTHY - HP_THRESHOLD_CRITICAL);
            var r = Std.int(0xEF + (0xEA - 0xEF) * t);
            var g = Std.int(0x44 + (0xB3 - 0x44) * t);
            var b = Std.int(0x44 + (0x08 - 0x44) * t);
            return (r << 16) | (g << 8) | b;
        } else {
            return COLOR_HP_CRITICAL;
        }
    }

    // =========================================================================
    // COMPACT & COMMA-FORMATTED NUMBERS
    // =========================================================================
    public static function formatNumber(n:Int):String {
        if (n < 0) return "0";
        if (n >= 10000000) {
            return Std.string(Math.round(n / 1000000)) + "M";
        }
        if (n >= 1000000) {
            var m:Float = Math.round(n / 100000) / 10.0;
            return m + "M";
        }
        if (n >= 100000) {
            var k:Float = Math.round(n / 1000);
            return k + "k";
        }
        // Numbers under 100k: comma separated (e.g. 2,995 or 45,200)
        var s:String = Std.string(n);
        var len:Int = s.length;
        if (len <= 3) return s;
        var res:String = "";
        for (i in 0...len) {
            if (i > 0 && (len - i) % 3 == 0) res += ",";
            res += s.charAt(i);
        }
        return res;
    }

    // =========================================================================
    // PLAYER FRAME ENHANCEMENT (TEXT ONLY)
    // =========================================================================
    private static function updatePlayerFrame(g:Dynamic):Void {
        if (g == null || g.ui == null || g.ui.mcPortrait == null) return;
        var mcPortrait:Dynamic = g.ui.mcPortrait;
        if (!mcPortrait.visible) return;

        var hpClip:Dynamic = mcPortrait.HP;
        if (hpClip == null) return;

        var strIntHP:TextField = cast hpClip.strIntHP;
        if (strIntHP == null) return;

        // Ensure native bar fill graphics are untouched (no color transform)
        if (hpClip.intHPbar != null && hpClip.intHPbar.transform != null) {
            hpClip.intHPbar.transform.colorTransform = new ColorTransform();
        }

        if (!isEnhanced()) {
            restoreNativeFrame(hpClip, strIntHP);
            return;
        }

        // Determine health bar width
        if (_playerBarWidth <= 0) {
            if (hpClip.intHPbar != null && Math.abs(hpClip.intHPbar.width) > 30) {
                _playerBarWidth = Math.abs(hpClip.intHPbar.width);
            } else {
                _playerBarWidth = 122.0;
            }
        }
        var barW:Float = _playerBarWidth;

        // Obtain player HP, MaxHP, and Shield
        var hp:Int = Api.player.hp;
        var maxHp:Int = Api.player.maxHp;
        var shield:Int = 0;
        try {
            if (g.world != null && g.world.myAvatar != null && g.world.myAvatar.dataLeaf != null) {
                var sg = g.world.myAvatar.dataLeaf.intSG;
                if (sg != null) shield = Std.int(sg);
            }
        } catch (_:Dynamic) {}

        if (maxHp <= 0) maxHp = 1;

        var showPct:Bool = isHpPercentEnabled();

        // Ensure percent text field exists on hpClip
        var pctTxt:TextField = cast hpClip.getChildByName("strIntHPPct");
        if (pctTxt == null) {
            pctTxt = new TextField();
            pctTxt.name = "strIntHPPct";
            pctTxt.selectable = false;
            pctTxt.mouseEnabled = false;
            pctTxt.autoSize = TextFieldAutoSize.NONE;
            hpClip.addChild(pctTxt);
        }

        // Setup layouts & formats (Text only)
        var rightReserve:Float = showPct ? 34.0 : 0.0;
        strIntHP.autoSize = TextFieldAutoSize.NONE;
        strIntHP.selectable = false;
        strIntHP.mouseEnabled = false;
        strIntHP.x = 3.0;
        strIntHP.width = barW - rightReserve - 5.0;

        var tf = strIntHP.defaultTextFormat;
        if (tf.align != TextFormatAlign.LEFT) {
            tf.align = TextFormatAlign.LEFT;
            strIntHP.defaultTextFormat = tf;
            strIntHP.setTextFormat(tf);
        }

        pctTxt.visible = showPct;
        if (showPct) {
            pctTxt.x = barW - 35.0;
            pctTxt.y = strIntHP.y;
            pctTxt.width = 33.0;
            pctTxt.height = strIntHP.height;
            var pctTf = new TextFormat(tf.font, tf.size, 0xFFFFFF, true);
            pctTf.align = TextFormatAlign.RIGHT;
            pctTxt.defaultTextFormat = pctTf;
            pctTxt.setTextFormat(pctTf);
            pctTxt.filters = ApiStyle.getTextOutlineFilter();
        }

        strIntHP.filters = ApiStyle.getTextOutlineFilter();

        // Update Text
        var hpStr:String;
        if (hp <= 0) {
            hpStr = "0 / " + formatNumber(maxHp);
        } else {
            var shieldStr = (shield > 0) ? " +" + formatNumber(shield) : "";
            hpStr = formatNumber(hp) + " / " + formatNumber(maxHp) + shieldStr;
        }

        if (strIntHP.text != hpStr) {
            strIntHP.text = hpStr;
        }

        var hpRatio:Float = Math.max(0.0, Math.min(1.0, hp / maxHp));
        if (showPct) {
            var pctVal:Int = (hp > 0 && hpRatio < 0.01) ? 1 : Math.round(hpRatio * 100);
            var pctStr:String = pctVal + "%";
            if (pctTxt.text != pctStr) {
                pctTxt.text = pctStr;
            }
        }
    }

    // =========================================================================
    // TARGET FRAME ENHANCEMENT (TEXT ONLY)
    // =========================================================================
    private static function updateTargetFrame(g:Dynamic):Void {
        if (g == null || g.ui == null || g.ui.mcPortraitTarget == null) return;
        var mcPortraitTarget:Dynamic = g.ui.mcPortraitTarget;
        if (!mcPortraitTarget.visible) return;

        var targetAvt:Dynamic = (g.world != null && g.world.myAvatar != null) ? g.world.myAvatar.target : null;
        if (targetAvt == null) return;

        var hpClip:Dynamic = mcPortraitTarget.HP;
        if (hpClip == null) return;

        var strIntHP:TextField = cast hpClip.strIntHP;
        if (strIntHP == null) return;

        // Ensure native bar fill graphics are untouched (no color transform)
        if (hpClip.intHPbar != null && hpClip.intHPbar.transform != null) {
            hpClip.intHPbar.transform.colorTransform = new ColorTransform();
        }

        if (!isEnhanced()) {
            restoreNativeFrame(hpClip, strIntHP);
            return;
        }

        // Determine target health bar width
        if (_targetBarWidth <= 0) {
            if (hpClip.intHPbar != null && Math.abs(hpClip.intHPbar.width) > 30) {
                _targetBarWidth = Math.abs(hpClip.intHPbar.width);
            } else {
                _targetBarWidth = 122.0;
            }
        }
        var barW:Float = _targetBarWidth;

        // Obtain target HP, MaxHP, and Shield
        var targetDTO = Api.player.target;
        var hp:Int = 0;
        var maxHp:Int = 0;
        var shield:Int = 0;

        if (targetDTO != null) {
            hp = targetDTO.hp;
            maxHp = targetDTO.maxHp;
            shield = targetDTO.shield;
        } else if (targetAvt.dataLeaf != null) {
            hp = targetAvt.dataLeaf.intHP != null ? Std.int(targetAvt.dataLeaf.intHP) : 0;
            maxHp = targetAvt.dataLeaf.intHPMax != null ? Std.int(targetAvt.dataLeaf.intHPMax) : 0;
            shield = targetAvt.dataLeaf.intSG != null ? Std.int(targetAvt.dataLeaf.intSG) : 0;
        }

        if (maxHp <= 0) maxHp = 1;

        var showPct:Bool = isHpPercentEnabled();

        // Ensure percent text field exists on target hpClip
        var pctTxt:TextField = cast hpClip.getChildByName("strIntHPPct");
        if (pctTxt == null) {
            pctTxt = new TextField();
            pctTxt.name = "strIntHPPct";
            pctTxt.selectable = false;
            pctTxt.mouseEnabled = false;
            pctTxt.autoSize = TextFieldAutoSize.NONE;
            hpClip.addChild(pctTxt);
        }

        // Setup layouts & formats (Text only)
        var rightReserve:Float = showPct ? 34.0 : 0.0;
        strIntHP.autoSize = TextFieldAutoSize.NONE;
        strIntHP.selectable = false;
        strIntHP.mouseEnabled = false;
        strIntHP.x = 3.0;
        strIntHP.width = barW - rightReserve - 5.0;

        var tf = strIntHP.defaultTextFormat;
        if (tf.align != TextFormatAlign.LEFT) {
            tf.align = TextFormatAlign.LEFT;
            strIntHP.defaultTextFormat = tf;
            strIntHP.setTextFormat(tf);
        }

        pctTxt.visible = showPct;
        if (showPct) {
            pctTxt.x = barW - 35.0;
            pctTxt.y = strIntHP.y;
            pctTxt.width = 33.0;
            pctTxt.height = strIntHP.height;
            var pctTf = new TextFormat(tf.font, tf.size, 0xFFFFFF, true);
            pctTf.align = TextFormatAlign.RIGHT;
            pctTxt.defaultTextFormat = pctTf;
            pctTxt.setTextFormat(pctTf);
            pctTxt.filters = ApiStyle.getTextOutlineFilter();
        }

        strIntHP.filters = ApiStyle.getTextOutlineFilter();

        // Update Text
        var hpStr:String;
        if (hp <= 0) {
            hpStr = "0 / " + formatNumber(maxHp);
        } else {
            var shieldStr = (shield > 0) ? " +" + formatNumber(shield) : "";
            hpStr = formatNumber(hp) + " / " + formatNumber(maxHp) + shieldStr;
        }

        if (strIntHP.text != hpStr) {
            strIntHP.text = hpStr;
        }

        var hpRatio:Float = Math.max(0.0, Math.min(1.0, hp / maxHp));
        if (showPct) {
            var pctVal:Int = (hp > 0 && hpRatio < 0.01) ? 1 : Math.round(hpRatio * 100);
            var pctStr:String = pctVal + "%";
            if (pctTxt.text != pctStr) {
                pctTxt.text = pctStr;
            }
        }

        // Show class names option
        if (UnitFramesManager.isShowClassNames()) {
            if (targetDTO != null && targetDTO.isPlayer && targetDTO.className != "") {
                if (mcPortraitTarget.strName != null && mcPortraitTarget.strName.text != targetDTO.className) {
                    mcPortraitTarget.strName.text = targetDTO.className;
                }
            }
        }
    }

    // =========================================================================
    // RESTORE NATIVE BEHAVIOR
    // =========================================================================
    private static function restoreNativeFrame(hpClip:Dynamic, strIntHP:TextField):Void {
        var pctTxt:TextField = cast hpClip.getChildByName("strIntHPPct");
        if (pctTxt != null) {
            pctTxt.visible = false;
        }
        if (hpClip.intHPbar != null && hpClip.intHPbar.transform != null) {
            hpClip.intHPbar.transform.colorTransform = new ColorTransform();
        }
    }

    // =========================================================================
    // RIGHT CLICK CONTEXT MENU
    // =========================================================================
    private static function setupRightClickMenu(g:Dynamic):Void {
        if (g == null || g.ui == null) return;

        // Player portrait right-click
        if (g.ui.mcPortrait != null && !Reflect.hasField(g.ui.mcPortrait, "_hasRightClickHook")) {
            Reflect.setField(g.ui.mcPortrait, "_hasRightClickHook", true);
            g.ui.mcPortrait.addEventListener(MouseEvent.RIGHT_CLICK, function(e:MouseEvent):Void {
                if (!isRightClickEnabled()) return;
                e.stopPropagation();
                try {
                    if (g.ui != null && g.ui.cMenu != null && g.world != null && g.world.myAvatar != null && g.world.myAvatar.objData != null) {
                        var params:Dynamic = {};
                        params.ID = g.world.myAvatar.objData.CharID;
                        params.strUsername = g.world.myAvatar.objData.strUsername;
                        g.ui.cMenu.fOpenWith("self", params);
                        positionMenuAtCursor(g);
                    }
                } catch (_:Dynamic) {}
            });
        }

        // Target portrait right-click
        if (g.ui.mcPortraitTarget != null && !Reflect.hasField(g.ui.mcPortraitTarget, "_hasRightClickHook")) {
            Reflect.setField(g.ui.mcPortraitTarget, "_hasRightClickHook", true);
            g.ui.mcPortraitTarget.addEventListener(MouseEvent.RIGHT_CLICK, function(e:MouseEvent):Void {
                if (!isRightClickEnabled()) return;
                e.stopPropagation();
                try {
                    var tgt:Dynamic = (g.world != null && g.world.myAvatar != null) ? g.world.myAvatar.target : null;
                    if (tgt != null && tgt.objData != null && g.ui != null && g.ui.cMenu != null) {
                        var params:Dynamic = {};
                        if (tgt.npcType == "player") {
                            params.ID = tgt.objData.CharID;
                            params.strUsername = tgt.objData.strUsername;
                            if (tgt != g.world.myAvatar) {
                                g.ui.cMenu.fOpenWith("user", params);
                            } else {
                                g.ui.cMenu.fOpenWith("self", params);
                            }
                        } else if (tgt.npcType == "monster") {
                            params.ID = tgt.objData.MonMapID;
                            params.strUsername = tgt.objData.strMonName;
                            params.target = tgt.pMC != null ? tgt.pMC : (g.world.getMonster(params.ID) != null ? g.world.getMonster(params.ID).pMC : null);
                            g.ui.cMenu.fOpenWith("mons", params);
                        }
                        positionMenuAtCursor(g);
                    }
                } catch (_:Dynamic) {}
            });
        }
    }

    private static function positionMenuAtCursor(g:Dynamic):Void {
        try {
            if (g.ui != null && g.ui.cMenu != null) {
                var theStage = g.stage != null ? g.stage : (_theStage != null ? _theStage : g.ui.stage);
                if (theStage != null) {
                    var pt:Point = g.ui.globalToLocal(new Point(theStage.mouseX, theStage.mouseY));
                    g.ui.cMenu.x = pt.x;
                    g.ui.cMenu.y = pt.y;
                }
                if (g.ui.cMenu.parent != null) {
                    g.ui.cMenu.parent.setChildIndex(g.ui.cMenu, g.ui.cMenu.parent.numChildren - 1);
                }
            }
        } catch (_:Dynamic) {}
    }

    // =========================================================================
    // CONFIGURATION ACCESSORS
    // =========================================================================
    public static inline function isEnhanced():Bool {
        return ApiConfig.getBool(CONFIG_ENHANCED, true);
    }

    public static inline function setEnhanced(enabled:Bool):Void {
        ApiConfig.setBool(CONFIG_ENHANCED, enabled);
        updateFrames();
    }

    public static inline function isHpPercentEnabled():Bool {
        return ApiConfig.getBool(CONFIG_HP_PERCENT, true);
    }

    public static inline function setHpPercentEnabled(enabled:Bool):Void {
        ApiConfig.setBool(CONFIG_HP_PERCENT, enabled);
        updateFrames();
    }

    public static inline function isRightClickEnabled():Bool {
        return ApiConfig.getBool(CONFIG_RIGHT_CLICK, true);
    }

    public static inline function setRightClickEnabled(enabled:Bool):Void {
        ApiConfig.setBool(CONFIG_RIGHT_CLICK, enabled);
    }

    public static function reloadFromConfig():Void {
        updateFrames();
    }
}
#else
class NativeFramesEnhancer {
    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {}
    public static function updateFrames():Void {}
    public static function getHealthColor(ratio:Float):Int return 0x22C55E;
    public static function formatNumber(n:Int):String return Std.string(n);
    public static function isEnhanced():Bool return true;
    public static function setEnhanced(enabled:Bool):Void {}
    public static function isHpPercentEnabled():Bool return true;
    public static function setHpPercentEnabled(enabled:Bool):Void {}
    public static function isRightClickEnabled():Bool return true;
    public static function setRightClickEnabled(enabled:Bool):Void {}
    public static function reloadFromConfig():Void {}
}
#end
