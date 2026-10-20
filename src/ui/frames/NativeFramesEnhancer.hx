package ui.frames;

#if flash
import flash.Lib;
import flash.display.DisplayObject;
import flash.display.DisplayObjectContainer;
import flash.display.MovieClip;
import flash.display.Shape;
import flash.display.SimpleButton;
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
    public static inline var CONFIG_TOT:String            = "api_native_frames_tot";
    public static inline var CONFIG_MOVABLE:String        = "api_native_frames_movable";

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

    private static var _playerDrag:NativeFrameDrag = null;
    private static var _targetDrag:NativeFrameDrag = null;

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

        // Initialize frame draggers for player and target unitframes
        if (g.ui.mcPortrait != null && _playerDrag == null) {
            _playerDrag = new NativeFrameDrag(cast g.ui.mcPortrait, "api_pos_player_frame", "posPlayerFrame", "PLAYER");
        } else if (_playerDrag != null) {
            _playerDrag.ensureAttached();
        }
        if (g.ui.mcPortraitTarget != null && _targetDrag == null) {
            _targetDrag = new NativeFrameDrag(cast g.ui.mcPortraitTarget, "api_pos_target_frame", "posTargetFrame", "TARGET");
        } else if (_targetDrag != null) {
            _targetDrag.ensureAttached();
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

        // Show class names option for player frame
        if (mcPortrait.strName != null) {
            var myClass:String = (Api.player != null && Api.player.className != null && Api.player.className != "") ? Api.player.className : "";
            var myUser:String = (Api.player != null && Api.player.username != null && Api.player.username != "") ? Api.player.username : ((g.world != null && g.world.myAvatar != null && g.world.myAvatar.objData != null) ? g.world.myAvatar.objData.strUsername : "");

            if (UnitFramesManager.isShowClassNames() && myClass != "") {
                if (mcPortrait.strName.text != myClass) {
                    mcPortrait.strName.text = myClass;
                }
            } else if (myUser != "") {
                if (mcPortrait.strName.text != myUser && mcPortrait.strName.text == myClass) {
                    mcPortrait.strName.text = myUser;
                }
            }
        }

        if (_playerDrag != null) {
            _playerDrag.syncSatellites();
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

        // Show class names option for target frame
        if (mcPortraitTarget.strName != null && targetDTO != null && targetDTO.isPlayer) {
            var tClass:String = targetDTO.className != null ? targetDTO.className : "";
            var tUser:String = targetDTO.name != null ? targetDTO.name : "";

            if (UnitFramesManager.isShowClassNames() && tClass != "") {
                if (mcPortraitTarget.strName.text != tClass) {
                    mcPortraitTarget.strName.text = tClass;
                }
            } else if (tUser != "") {
                if (mcPortraitTarget.strName.text != tUser && mcPortraitTarget.strName.text == tClass) {
                    mcPortraitTarget.strName.text = tUser;
                }
            }
        }

        // Target of Target (replaces native Options button)
        updateTargetOfTarget(mcPortraitTarget, targetAvt);

        if (_targetDrag != null) {
            _targetDrag.syncSatellites();
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

    public static inline function isTargetOfTargetEnabled():Bool {
        return ApiConfig.getBool(CONFIG_TOT, true);
    }

    public static inline function setTargetOfTargetEnabled(enabled:Bool):Void {
        ApiConfig.setBool(CONFIG_TOT, enabled);
        updateFrames();
    }

    public static inline function isMovableFramesEnabled():Bool {
        return ApiConfig.getBool(CONFIG_MOVABLE, true);
    }

    public static inline function setMovableFramesEnabled(enabled:Bool):Void {
        ApiConfig.setBool(CONFIG_MOVABLE, enabled);
    }

    public static function resetFramePositions():Void {
        if (_playerDrag != null) _playerDrag.resetPosition();
        if (_targetDrag != null) _targetDrag.resetPosition();
    }

    public static function reloadFromConfig():Void {
        updateFrames();
    }

    // =========================================================================
    // TARGET OF TARGET (TEXT-ONLY REPLACEMENT OF NATIVE OPTIONS BUTTON)
    // =========================================================================
    private static function updateTargetOfTarget(mcPortraitTarget:Dynamic, targetAvt:Dynamic):Void {
        var btnOption:Dynamic = Reflect.field(mcPortraitTarget, "btnOption");
        var totEnabled = isTargetOfTargetEnabled();

        if (!totEnabled) {
            if (btnOption != null) btnOption.visible = true;
            var oldPlate:Sprite = cast mcPortraitTarget.getChildByName("mcTargetOfTarget");
            if (oldPlate != null) oldPlate.visible = false;
            return;
        }

        // Hide native options button so it doesn't show through or conflict
        if (btnOption != null) {
            btnOption.visible = false;
        }

        var totPlate:Sprite = cast mcPortraitTarget.getChildByName("mcTargetOfTarget");
        var txtToT:TextField = null;

        var bX:Float = (btnOption != null) ? btnOption.x : 68.0;
        var bY:Float = (btnOption != null) ? btnOption.y : 63.0;
        var bW:Float = (btnOption != null && btnOption.width > 40) ? btnOption.width : 98.0;
        var bH:Float = (btnOption != null && btnOption.height > 10) ? btnOption.height : 18.0;

        if (totPlate == null) {
            totPlate = new Sprite();
            totPlate.name = "mcTargetOfTarget";
            totPlate.buttonMode = true;
            totPlate.useHandCursor = true;
            totPlate.x = bX;
            totPlate.y = bY;

            txtToT = new TextField();
            txtToT.name = "txtToT";
            var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 9.5, 0xEEEEF2, true);
            fmt.align = TextFormatAlign.CENTER;
            txtToT.defaultTextFormat = fmt;
            txtToT.selectable = false;
            txtToT.mouseEnabled = false;
            txtToT.autoSize = TextFieldAutoSize.NONE;
            txtToT.filters = ApiStyle.getTextOutlineFilter();
            totPlate.addChild(txtToT);

            totPlate.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
                e.stopPropagation();
                e.stopImmediatePropagation();
                onToTClick();
            });

            totPlate.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
                Reflect.setField(totPlate, "_isHover", true);
                renderToTPlate(totPlate, bW, bH, true);
            });
            totPlate.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
                Reflect.setField(totPlate, "_isHover", false);
                renderToTPlate(totPlate, bW, bH, false);
            });

            mcPortraitTarget.addChild(totPlate);
        } else {
            txtToT = cast totPlate.getChildByName("txtToT");
            totPlate.x = bX;
            totPlate.y = bY;
            totPlate.visible = true;
        }

        // Keep on top of timeline children
        try {
            if (mcPortraitTarget.numChildren != null && mcPortraitTarget.getChildIndex(totPlate) < mcPortraitTarget.numChildren - 1) {
                mcPortraitTarget.setChildIndex(totPlate, mcPortraitTarget.numChildren - 1);
            }
        } catch (_:Dynamic) {}

        var isHover = (Reflect.field(totPlate, "_isHover") == true);
        renderToTPlate(totPlate, bW, bH, isHover);

        var totInfo = getTargetOfTargetInfo(targetAvt);

        if (txtToT != null) {
            txtToT.x = 2;
            txtToT.y = 1;
            txtToT.width = bW - 4;
            txtToT.height = bH;
            if (txtToT.text != totInfo.name) {
                txtToT.text = totInfo.name;
            }

            var textColor = totInfo.isSelf ? 0xFBBF24 : (totInfo.isNone ? 0x8E95AA : (isHover ? 0xFFFFFF : 0xEEEEF2));
            txtToT.textColor = textColor;
        }
    }

    private static function renderToTPlate(plate:Sprite, w:Float, h:Float, hover:Bool):Void {
        var g = plate.graphics;
        g.clear();
        var bg = hover ? 0x22252E : 0x141519;
        var border = hover ? 0x475569 : 0x262832;

        g.beginFill(bg, 0.96);
        g.lineStyle(1.0, border, 0.9);
        g.moveTo(0, 0);
        g.lineTo(w, 0);
        g.lineTo(w - 3, h);
        g.lineTo(3, h);
        g.lineTo(0, 0);
        g.endFill();

        // Subtle top bevel highlight matching AQW status box
        g.lineStyle(1.0, 0x3E4250, hover ? 0.6 : 0.35);
        g.moveTo(1, 1);
        g.lineTo(w - 1, 1);
    }

    private static function onToTClick():Void {
        var curTgt:Dynamic = (Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null) ? Api.game.world.myAvatar.target : null;
        var curTot = getTargetOfTarget(curTgt);
        if (curTot != null && Api.game != null && Api.game.world != null) {
            try {
                Api.game.world.setTarget(curTot);
            } catch (_:Dynamic) {}
        }
    }

    public static function getTargetOfTarget(targetAvt:Dynamic):Dynamic {
        if (targetAvt == null) return null;
        var g:Dynamic = Api.game;
        if (g == null || g.world == null) return null;

        // 1. Direct target property
        try {
            if (Reflect.hasField(targetAvt, "target") && targetAvt.target != null) {
                return targetAvt.target;
            }
        } catch (_:Dynamic) {}

        // 2. dataLeaf.targets or targets map on avatar
        try {
            var targetsObj:Dynamic = null;
            if (targetAvt.dataLeaf != null && targetAvt.dataLeaf.targets != null) {
                targetsObj = targetAvt.dataLeaf.targets;
            } else if (Reflect.hasField(targetAvt, "targets") && targetAvt.targets != null) {
                targetsObj = targetAvt.targets;
            }

            // 3. AQW Monster tree targets lookup: world.monTree[MonMapID].targets
            if (targetsObj == null && targetAvt.objData != null && targetAvt.objData.MonMapID != null) {
                var monId = targetAvt.objData.MonMapID;
                var monNode:Dynamic = null;
                if (g.world.monTree != null) {
                    try { monNode = Reflect.field(g.world.monTree, Std.string(monId)); } catch (_:Dynamic) {}
                    if (monNode == null) {
                        try { monNode = g.world.monTree[monId]; } catch (_:Dynamic) {}
                    }
                }
                if (monNode != null && monNode.targets != null) {
                    targetsObj = monNode.targets;
                }
            }

            // 4. AQW Player tree targets lookup: world.uoTree[username].targets
            if (targetsObj == null && targetAvt.objData != null && targetAvt.objData.strUsername != null) {
                var uName = Std.string(targetAvt.objData.strUsername).toLowerCase();
                var uNode:Dynamic = null;
                if (g.world.uoTree != null) {
                    try { uNode = Reflect.field(g.world.uoTree, uName); } catch (_:Dynamic) {}
                }
                if (uNode != null && uNode.targets != null) {
                    targetsObj = uNode.targets;
                }
            }

            if (targetsObj != null) {
                var myUid:String = (g.world.myAvatar != null && g.world.myAvatar.objData != null) ? Std.string(g.world.myAvatar.objData.uid) : "";
                var myCharId:String = (g.world.myAvatar != null && g.world.myAvatar.objData != null) ? Std.string(g.world.myAvatar.objData.CharID) : "";
                var mySfcId:String = (g.sfc != null && g.sfc.myUserId != null) ? Std.string(g.sfc.myUserId) : "";

                for (key in Reflect.fields(targetsObj)) {
                    if (key == myUid || key == myCharId || key == mySfcId) {
                        return g.world.myAvatar;
                    }
                    try {
                        var numKey = Std.parseInt(key);
                        if (numKey != null) {
                            var avt = g.world.getAvatarByUserID(numKey);
                            if (avt != null) return avt;
                            var mon = g.world.getMonster(numKey);
                            if (mon != null) return mon;
                        }
                    } catch (_:Dynamic) {}
                }
            }
        } catch (_:Dynamic) {}

        // 5. Fallback: If player is currently targeting monster and monster is in combat with player
        try {
            if (g.world.myAvatar != null && g.world.myAvatar.dataLeaf != null && g.world.myAvatar.dataLeaf.targets != null) {
                var myTargets = g.world.myAvatar.dataLeaf.targets;
                if (targetAvt.objData != null && targetAvt.objData.MonMapID != null) {
                    var monIdStr = Std.string(targetAvt.objData.MonMapID);
                    if (Reflect.hasField(myTargets, monIdStr)) {
                        return g.world.myAvatar;
                    }
                }
            }
        } catch (_:Dynamic) {}

        return null;
    }

    public static function getTargetOfTargetInfo(targetAvt:Dynamic):{ name:String, isSelf:Bool, isNone:Bool, entity:Dynamic } {
        var tot = getTargetOfTarget(targetAvt);
        if (tot == null) {
            return { name: "No Target", isSelf: false, isNone: true, entity: null };
        }

        var g:Dynamic = Api.game;
        var isSelf:Bool = (g != null && g.world != null && g.world.myAvatar != null && tot == g.world.myAvatar);

        var nameStr:String = "";
        try {
            if (tot.objData != null) {
                if (tot.objData.strUsername != null && tot.objData.strUsername != "") {
                    nameStr = tot.objData.strUsername;
                } else if (tot.objData.strMonName != null && tot.objData.strMonName != "") {
                    nameStr = tot.objData.strMonName;
                }
            }
            if (nameStr == "" && tot.pAV != null && tot.pAV.objData != null) {
                if (tot.pAV.objData.strUsername != null) nameStr = tot.pAV.objData.strUsername;
                else if (tot.pAV.objData.strMonName != null) nameStr = tot.pAV.objData.strMonName;
            }
        } catch (_:Dynamic) {}

        if (nameStr == "") nameStr = "Target";

        return {
            name: isSelf ? "► YOU ◄" : nameStr,
            isSelf: isSelf,
            isNone: false,
            entity: tot
        };
    }
}

/**
 * NativeFrameDrag:
 * Draggable frame controller for default AQW player (mcPortrait) and target (mcPortraitTarget) frames.
 * Recreates the exact native feel of party and aura frames (HudDrag):
 * - Mouse drag anywhere on frame
 * - Screen boundary clamping
 * - Hover backdrop with "PLAYER" / "TARGET" caption tag
 * - Suppressed click on release so dragging doesn't open menu / cancel target
 * - Persistent saved coordinates synced with config
 */
class NativeFrameDrag {
    private static inline var THRESHOLD_SQ:Float = 16.0;
    private static inline var CAP_H:Float = 14.0;
    private static inline var PAD:Float = 5.0;

    private var _target:Sprite;
    private var _key:String;
    private var _litePrefKey:String;
    private var _caption:String;
    private var _defaultX:Float = 0;
    private var _defaultY:Float = 0;
    private var _defaultRecorded:Bool = false;

    private var _isTarget:Bool = false;

    // Satellites offsets relative to frame
    private var _closeOffsetX:Float = 178.7;
    private var _closeOffsetY:Float = 10.0;
    private var _closeRecorded:Bool = false;

    private var _questOffsetX:Float = 14.25;
    private var _questOffsetY:Float = 64.15;
    private var _questRecorded:Bool = false;

    private var _monsterOffsetX:Float = 76.0;
    private var _monsterOffsetY:Float = 23.7;
    private var _monsterRecorded:Bool = false;

    private var _stage:Stage = null;
    private var _isDragging:Bool = false;
    private var _hasDragged:Bool = false;
    private var _startX:Float = 0;
    private var _startY:Float = 0;
    private var _origX:Float = 0;
    private var _origY:Float = 0;
    private var _kidsWas:Bool = true;
    private var _kidsOff:Bool = false;

    private var _backdrop:Sprite = null;
    private var _bgShape:Shape = null;
    private var _capTxt:TextField = null;

    public function new(target:Sprite, key:String, litePrefKey:String, caption:String) {
        _target = target;
        _key = key;
        _litePrefKey = litePrefKey;
        _caption = caption;
        _isTarget = (_caption == "TARGET");

        _target.addEventListener(MouseEvent.MOUSE_DOWN, onDown, false, 0, true);
        _target.addEventListener(MouseEvent.ROLL_OVER, onRollOver, false, 0, true);
        _target.addEventListener(MouseEvent.ROLL_OUT, onRollOut, false, 0, true);
        _target.addEventListener(MouseEvent.CLICK, onClickCapture, true, 0, true);

        ensureAttached();
    }

    public function ensureAttached():Void {
        if (_target == null) return;
        if (!_defaultRecorded && _target.x != 0 && _target.y != 0) {
            _defaultX = _target.x;
            _defaultY = _target.y;
            _defaultRecorded = true;
            restorePosition();
        } else if (!_defaultRecorded && _target.parent != null) {
            _defaultX = _target.x;
            _defaultY = _target.y;
            _defaultRecorded = true;
            restorePosition();
        } else if (_defaultRecorded) {
            syncSatellites();
        }
    }

    public function syncSatellites():Void {
        if (_target == null) return;
        var g:Dynamic = Api.game;
        if (g == null || g.ui == null) return;

        if (_isTarget) {
            var closeBtn:Dynamic = g.ui.btnTargetPortraitClose;
            if (closeBtn != null) {
                if (!_closeRecorded && closeBtn.x != 0) {
                    if (Math.abs(_target.x - _defaultX) < 1 && Math.abs(_target.y - _defaultY) < 1) {
                        _closeOffsetX = closeBtn.x - _target.x;
                        _closeOffsetY = closeBtn.y - _target.y;
                        _closeRecorded = true;
                    }
                }
                closeBtn.x = _target.x + _closeOffsetX;
                closeBtn.y = _target.y + _closeOffsetY;
            }
        } else {
            var iconQuest:Dynamic = g.ui.iconQuest;
            if (iconQuest != null) {
                if (!_questRecorded && iconQuest.x != 0) {
                    if (Math.abs(_target.x - _defaultX) < 1 && Math.abs(_target.y - _defaultY) < 1) {
                        _questOffsetX = iconQuest.x - _target.x;
                        _questOffsetY = iconQuest.y - _target.y;
                        _questRecorded = true;
                    }
                }
                iconQuest.x = _target.x + _questOffsetX;
                iconQuest.y = _target.y + _questOffsetY;
            }

            var monsterIcon:Dynamic = g.ui.monsterIcon;
            if (monsterIcon != null) {
                if (!_monsterRecorded && monsterIcon.x != 0) {
                    if (Math.abs(_target.x - _defaultX) < 1 && Math.abs(_target.y - _defaultY) < 1) {
                        _monsterOffsetX = monsterIcon.x - _target.x;
                        _monsterOffsetY = monsterIcon.y - _target.y;
                        _monsterRecorded = true;
                    }
                }
                monsterIcon.x = _target.x + _monsterOffsetX;
                monsterIcon.y = _target.y + _monsterOffsetY;
            }

            var btnMonster:Dynamic = Reflect.field(g.ui, "btnMonster");
            if (btnMonster != null && btnMonster != monsterIcon) {
                btnMonster.x = _target.x + _monsterOffsetX;
                btnMonster.y = _target.y + _monsterOffsetY;
            }

            try {
                if (g.mailHub != null) {
                    g.mailHub.placeHud();
                }
            } catch (_:Dynamic) {}
        }
    }

    public inline function getVisualWidth():Float {
        return _isTarget ? 212.0 : 200.0;
    }

    public inline function getVisualHeight():Float {
        return _isTarget ? 70.0 : 82.0;
    }

    private function onClickCapture(e:MouseEvent):Void {
        if (_hasDragged) {
            e.stopImmediatePropagation();
        }
    }

    private function onRollOver(e:MouseEvent):Void {
        if (!NativeFramesEnhancer.isMovableFramesEnabled()) return;
        drawBackdrop();
    }

    private function onRollOut(e:MouseEvent):Void {
        if (!_isDragging) {
            hideBackdrop();
        }
    }

    private function drawBackdrop():Void {
        if (_target == null || _target.parent == null || !_target.visible) {
            hideBackdrop();
            return;
        }

        if (_backdrop == null) {
            _backdrop = new Sprite();
            _backdrop.mouseChildren = false;
            _backdrop.mouseEnabled = false;

            _bgShape = new Shape();
            _backdrop.addChild(_bgShape);

            _capTxt = new TextField();
            var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 9, 0xEEEEF2, true);
            _capTxt.defaultTextFormat = fmt;
            _capTxt.autoSize = TextFieldAutoSize.LEFT;
            _capTxt.selectable = false;
            _capTxt.mouseEnabled = false;
            _capTxt.filters = ApiStyle.getTextOutlineFilter();
            _capTxt.text = _caption;
            _backdrop.addChild(_capTxt);
        }

        var parent = _target.parent;
        if (_backdrop.parent != parent) {
            var idx = parent.getChildIndex(_target);
            parent.addChildAt(_backdrop, idx);
        }

        var bx = _target.x;
        var by = _target.y;
        var bw = getVisualWidth();
        var bh = getVisualHeight();

        _bgShape.graphics.clear();
        _bgShape.graphics.beginFill(0x000000, 0.45);
        _bgShape.graphics.lineStyle(1, 0x475569, 0.85);
        _bgShape.graphics.drawRoundRect(bx - PAD, by - PAD - CAP_H, bw + PAD * 2, bh + PAD * 2 + CAP_H, 8, 8);
        _bgShape.graphics.endFill();

        _capTxt.x = bx - PAD + 5;
        _capTxt.y = by - PAD - CAP_H + 1;
        _backdrop.visible = true;
    }

    private function hideBackdrop():Void {
        if (_backdrop != null) {
            if (_bgShape != null) _bgShape.graphics.clear();
            if (_backdrop.parent != null) {
                _backdrop.parent.removeChild(_backdrop);
            }
            _backdrop.visible = false;
        }
    }

    private function onDown(e:MouseEvent):Void {
        if (!NativeFramesEnhancer.isMovableFramesEnabled()) return;
        if (_target == null || _target.stage == null) return;

        _stage = _target.stage;
        _isDragging = false;
        _hasDragged = false;
        _startX = e.stageX;
        _startY = e.stageY;
        _origX = _target.x;
        _origY = _target.y;

        _stage.addEventListener(MouseEvent.MOUSE_MOVE, onMove, false, 0, true);
        _stage.addEventListener(MouseEvent.MOUSE_UP, onUp, false, 0, true);
    }

    private function onMove(e:MouseEvent):Void {
        if (_target == null || _stage == null) {
            stopPress();
            return;
        }

        var dx = e.stageX - _startX;
        var dy = e.stageY - _startY;

        if (!_isDragging) {
            if (dx * dx + dy * dy < THRESHOLD_SQ) return;
            _isDragging = true;
            _kidsWas = _target.mouseChildren;
            _kidsOff = true;
            _target.mouseChildren = false;

            try {
                if (Api.game != null && Api.game.ui != null && Api.game.ui.ToolTip != null) {
                    Api.game.ui.ToolTip.close();
                }
            } catch (_:Dynamic) {}
        }

        var newX = Math.round(_origX + dx);
        var newY = Math.round(_origY + dy);

        var stageW:Float = _stage.stageWidth > 0 ? _stage.stageWidth : 960;
        var stageH:Float = _stage.stageHeight > 0 ? _stage.stageHeight : 550;
        var maxBottom:Float = stageH - 50;

        var w = Math.max(160, _target.width);
        var h = Math.max(60, _target.height);

        if (newX < 0) newX = 0;
        if (newY < 0) newY = 0;
        if (newX + w > stageW) newX = Std.int(stageW - w);
        if (newY + h > maxBottom) newY = Std.int(maxBottom - h);

        _target.x = newX;
        _target.y = newY;

        syncSatellites();
        drawBackdrop();
        e.updateAfterEvent();
    }

    private function onUp(e:MouseEvent):Void {
        stopPress();
        if (_isDragging) {
            _isDragging = false;
            _hasDragged = true;
            savePosition();
            haxe.Timer.delay(function() {
                _hasDragged = false;
            }, 100);
        }
        hideBackdrop();
    }

    private function stopPress():Void {
        if (_kidsOff) {
            _kidsOff = false;
            if (_target != null) _target.mouseChildren = _kidsWas;
        }
        if (_stage != null) {
            _stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMove);
            _stage.removeEventListener(MouseEvent.MOUSE_UP, onUp);
            _stage = null;
        }
    }

    public function savePosition():Void {
        if (_target == null) return;
        ApiConfig.setFloat(_key + "_x", _target.x);
        ApiConfig.setFloat(_key + "_y", _target.y);
        try {
            if (Api.game != null && Api.game.litePreference != null && Api.game.litePreference.data != null) {
                Reflect.setField(Api.game.litePreference.data, _litePrefKey, { x: _target.x, y: _target.y });
                Api.game.litePreference.flush();
            }
        } catch (_:Dynamic) {}
    }

    public function restorePosition():Void {
        if (_target == null) return;
        if (ApiConfig.has(_key + "_x") && ApiConfig.has(_key + "_y")) {
            _target.x = ApiConfig.getFloat(_key + "_x", _defaultX);
            _target.y = ApiConfig.getFloat(_key + "_y", _defaultY);
        } else {
            try {
                if (Api.game != null && Api.game.litePreference != null && Api.game.litePreference.data != null) {
                    var lp:Dynamic = Reflect.field(Api.game.litePreference.data, _litePrefKey);
                    if (lp != null && lp.x != null && lp.y != null) {
                        _target.x = Std.int(lp.x);
                        _target.y = Std.int(lp.y);
                    }
                }
            } catch (_:Dynamic) {}
        }
        syncSatellites();
    }

    public function resetPosition():Void {
        if (_target == null) return;
        ApiConfig.delete(_key + "_x");
        ApiConfig.delete(_key + "_y");
        try {
            if (Api.game != null && Api.game.litePreference != null && Api.game.litePreference.data != null) {
                Reflect.deleteField(Api.game.litePreference.data, _litePrefKey);
                Api.game.litePreference.flush();
            }
        } catch (_:Dynamic) {}

        _target.x = _defaultX;
        _target.y = _defaultY;
        syncSatellites();
        hideBackdrop();
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
    public static function isTargetOfTargetEnabled():Bool return true;
    public static function setTargetOfTargetEnabled(enabled:Bool):Void {}
    public static function isMovableFramesEnabled():Bool return true;
    public static function setMovableFramesEnabled(enabled:Bool):Void {}
    public static function resetFramePositions():Void {}
    public static function reloadFromConfig():Void {}
}
#end
