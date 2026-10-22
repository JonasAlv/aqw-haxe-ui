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
import flash.geom.Rectangle;
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

        // Clean up any legacy player frame configs without touching mcPortrait position (native defaults)
        if (ApiConfig.has("api_pos_player_frame_x")) ApiConfig.delete("api_pos_player_frame_x");
        if (ApiConfig.has("api_pos_player_frame_y")) ApiConfig.delete("api_pos_player_frame_y");

        // Target unitframe is movable
        var targetMc:Dynamic = g.ui.mcPortraitTarget;
        if (targetMc != null) {
            if (_targetDrag == null) {
                _targetDrag = new NativeFrameDrag(cast targetMc, "api_pos_target_frame", "posTargetFrame");
            } else if (_targetDrag.isStale(cast targetMc)) {
                _targetDrag.rebind(cast targetMc);
            } else {
                _targetDrag.ensureAttached();
            }
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

        // Hide native text field to completely eliminate rendering flicker when AQW updates health
        strIntHP.visible = false;

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
        var rightReserve:Float = showPct ? 34.0 : 0.0;

        // Persistent enhanced HP text field (separate from native strIntHP to avoid flicker)
        var txtEnhancedHP:TextField = cast hpClip.getChildByName("_txtEnhancedHP");
        if (txtEnhancedHP == null) {
            txtEnhancedHP = new TextField();
            txtEnhancedHP.name = "_txtEnhancedHP";
            txtEnhancedHP.selectable = false;
            txtEnhancedHP.mouseEnabled = false;
            txtEnhancedHP.autoSize = TextFieldAutoSize.NONE;

            var tf = strIntHP.defaultTextFormat;
            var myTf = new TextFormat(tf.font, tf.size, 0xFFFFFF, true);
            myTf.align = TextFormatAlign.LEFT;
            txtEnhancedHP.defaultTextFormat = myTf;
            txtEnhancedHP.setTextFormat(myTf);
            txtEnhancedHP.filters = ApiStyle.getTextOutlineFilter();
            hpClip.addChild(txtEnhancedHP);
        }

        // Persistent enhanced Percent text field
        var txtEnhancedPct:TextField = cast hpClip.getChildByName("_txtEnhancedPct");
        if (txtEnhancedPct == null) {
            txtEnhancedPct = new TextField();
            txtEnhancedPct.name = "_txtEnhancedPct";
            txtEnhancedPct.selectable = false;
            txtEnhancedPct.mouseEnabled = false;
            txtEnhancedPct.autoSize = TextFieldAutoSize.NONE;

            var tf = strIntHP.defaultTextFormat;
            var pctTf = new TextFormat(tf.font, tf.size, 0xFFFFFF, true);
            pctTf.align = TextFormatAlign.RIGHT;
            txtEnhancedPct.defaultTextFormat = pctTf;
            txtEnhancedPct.setTextFormat(pctTf);
            txtEnhancedPct.filters = ApiStyle.getTextOutlineFilter();
            hpClip.addChild(txtEnhancedPct);
        }

        txtEnhancedHP.visible = true;
        txtEnhancedHP.x = 3.0;
        txtEnhancedHP.y = strIntHP.y;
        txtEnhancedHP.width = barW - rightReserve - 5.0;
        txtEnhancedHP.height = strIntHP.height > 0 ? strIntHP.height : 16.0;

        txtEnhancedPct.visible = showPct;
        if (showPct) {
            txtEnhancedPct.x = barW - 35.0;
            txtEnhancedPct.y = strIntHP.y;
            txtEnhancedPct.width = 33.0;
            txtEnhancedPct.height = strIntHP.height > 0 ? strIntHP.height : 16.0;
        }

        // Update text values only when modified to avoid unnecessary redraws
        var hpStr:String;
        if (hp <= 0) {
            hpStr = "0 / " + formatNumber(maxHp);
        } else {
            var shieldStr = (shield > 0) ? " +" + formatNumber(shield) : "";
            hpStr = formatNumber(hp) + " / " + formatNumber(maxHp) + shieldStr;
        }

        if (txtEnhancedHP.text != hpStr) {
            txtEnhancedHP.text = hpStr;
        }

        if (showPct) {
            var hpRatio:Float = Math.max(0.0, Math.min(1.0, hp / maxHp));
            var pctVal:Int = (hp > 0 && hpRatio < 0.01) ? 1 : Math.round(hpRatio * 100);
            var pctStr:String = pctVal + "%";
            if (txtEnhancedPct.text != pctStr) {
                txtEnhancedPct.text = pctStr;
            }
        }

        // Show class names option for player frame (flicker-free overlay)
        if (mcPortrait.strName != null) {
            var strPlayerName:TextField = cast mcPortrait.strName;
            var myClass:String = (Api.player != null && Api.player.className != null && Api.player.className != "") ? Api.player.className : "";
            var myUser:String = (Api.player != null && Api.player.username != null && Api.player.username != "") ? Api.player.username : ((g.world != null && g.world.myAvatar != null && g.world.myAvatar.objData != null) ? g.world.myAvatar.objData.strUsername : "");

            if (UnitFramesManager.isShowClassNames() && myClass != "") {
                strPlayerName.visible = false;
                var txtEnhancedName:TextField = cast mcPortrait.getChildByName("_txtEnhancedName");
                if (txtEnhancedName == null) {
                    txtEnhancedName = new TextField();
                    txtEnhancedName.name = "_txtEnhancedName";
                    txtEnhancedName.selectable = false;
                    txtEnhancedName.mouseEnabled = false;
                    txtEnhancedName.autoSize = TextFieldAutoSize.NONE;
                    txtEnhancedName.x = strPlayerName.x;
                    txtEnhancedName.y = strPlayerName.y;
                    txtEnhancedName.width = strPlayerName.width > 0 ? strPlayerName.width : 140.0;
                    txtEnhancedName.height = strPlayerName.height > 0 ? strPlayerName.height : 20.0;

                    var tf = strPlayerName.defaultTextFormat;
                    txtEnhancedName.defaultTextFormat = tf;
                    txtEnhancedName.setTextFormat(tf);
                    txtEnhancedName.filters = strPlayerName.filters;
                    mcPortrait.addChild(txtEnhancedName);
                }
                txtEnhancedName.visible = true;
                if (txtEnhancedName.text != myClass) {
                    txtEnhancedName.text = myClass;
                }
            } else {
                var oldTxt = mcPortrait.getChildByName("_txtEnhancedName");
                if (oldTxt != null) oldTxt.visible = false;
                strPlayerName.visible = true;
                if (myUser != "" && strPlayerName.text == myClass) {
                    strPlayerName.text = myUser;
                }
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

        // Hide native text field to completely eliminate rendering flicker when AQW updates health
        strIntHP.visible = false;

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
        var rightReserve:Float = showPct ? 34.0 : 0.0;

        // Persistent enhanced HP text field (separate from native strIntHP to avoid flicker)
        var txtEnhancedHP:TextField = cast hpClip.getChildByName("_txtEnhancedHP");
        if (txtEnhancedHP == null) {
            txtEnhancedHP = new TextField();
            txtEnhancedHP.name = "_txtEnhancedHP";
            txtEnhancedHP.selectable = false;
            txtEnhancedHP.mouseEnabled = false;
            txtEnhancedHP.autoSize = TextFieldAutoSize.NONE;

            var tf = strIntHP.defaultTextFormat;
            var myTf = new TextFormat(tf.font, tf.size, 0xFFFFFF, true);
            myTf.align = TextFormatAlign.LEFT;
            txtEnhancedHP.defaultTextFormat = myTf;
            txtEnhancedHP.setTextFormat(myTf);
            txtEnhancedHP.filters = ApiStyle.getTextOutlineFilter();
            hpClip.addChild(txtEnhancedHP);
        }

        // Persistent enhanced Percent text field
        var txtEnhancedPct:TextField = cast hpClip.getChildByName("_txtEnhancedPct");
        if (txtEnhancedPct == null) {
            txtEnhancedPct = new TextField();
            txtEnhancedPct.name = "_txtEnhancedPct";
            txtEnhancedPct.selectable = false;
            txtEnhancedPct.mouseEnabled = false;
            txtEnhancedPct.autoSize = TextFieldAutoSize.NONE;

            var tf = strIntHP.defaultTextFormat;
            var pctTf = new TextFormat(tf.font, tf.size, 0xFFFFFF, true);
            pctTf.align = TextFormatAlign.RIGHT;
            txtEnhancedPct.defaultTextFormat = pctTf;
            txtEnhancedPct.setTextFormat(pctTf);
            txtEnhancedPct.filters = ApiStyle.getTextOutlineFilter();
            hpClip.addChild(txtEnhancedPct);
        }

        txtEnhancedHP.visible = true;
        txtEnhancedHP.x = 3.0;
        txtEnhancedHP.y = strIntHP.y;
        txtEnhancedHP.width = barW - rightReserve - 5.0;
        txtEnhancedHP.height = strIntHP.height > 0 ? strIntHP.height : 16.0;

        txtEnhancedPct.visible = showPct;
        if (showPct) {
            txtEnhancedPct.x = barW - 35.0;
            txtEnhancedPct.y = strIntHP.y;
            txtEnhancedPct.width = 33.0;
            txtEnhancedPct.height = strIntHP.height > 0 ? strIntHP.height : 16.0;
        }

        // Update text values only when modified to avoid unnecessary redraws
        var hpStr:String;
        if (hp <= 0) {
            hpStr = "0 / " + formatNumber(maxHp);
        } else {
            var shieldStr = (shield > 0) ? " +" + formatNumber(shield) : "";
            hpStr = formatNumber(hp) + " / " + formatNumber(maxHp) + shieldStr;
        }

        if (txtEnhancedHP.text != hpStr) {
            txtEnhancedHP.text = hpStr;
        }

        if (showPct) {
            var hpRatio:Float = Math.max(0.0, Math.min(1.0, hp / maxHp));
            var pctVal:Int = (hp > 0 && hpRatio < 0.01) ? 1 : Math.round(hpRatio * 100);
            var pctStr:String = pctVal + "%";
            if (txtEnhancedPct.text != pctStr) {
                txtEnhancedPct.text = pctStr;
            }
        }

        // Show class names option for target frame (flicker-free overlay)
        if (mcPortraitTarget.strName != null) {
            var strTargetName:TextField = cast mcPortraitTarget.strName;
            var isPlayer = (targetDTO != null && targetDTO.isPlayer);
            var tClass:String = (isPlayer && targetDTO.className != null) ? targetDTO.className : "";
            var tUser:String = (isPlayer && targetDTO.name != null) ? targetDTO.name : "";

            if (isPlayer && UnitFramesManager.isShowClassNames() && tClass != "") {
                strTargetName.visible = false;
                var txtEnhancedTName:TextField = cast mcPortraitTarget.getChildByName("_txtEnhancedName");
                if (txtEnhancedTName == null) {
                    txtEnhancedTName = new TextField();
                    txtEnhancedTName.name = "_txtEnhancedName";
                    txtEnhancedTName.selectable = false;
                    txtEnhancedTName.mouseEnabled = false;
                    txtEnhancedTName.autoSize = TextFieldAutoSize.NONE;
                    txtEnhancedTName.x = strTargetName.x;
                    txtEnhancedTName.y = strTargetName.y;
                    txtEnhancedTName.width = strTargetName.width > 0 ? strTargetName.width : 140.0;
                    txtEnhancedTName.height = strTargetName.height > 0 ? strTargetName.height : 20.0;

                    var tf = strTargetName.defaultTextFormat;
                    txtEnhancedTName.defaultTextFormat = tf;
                    txtEnhancedTName.setTextFormat(tf);
                    txtEnhancedTName.filters = strTargetName.filters;
                    mcPortraitTarget.addChild(txtEnhancedTName);
                }
                txtEnhancedTName.visible = true;
                if (txtEnhancedTName.text != tClass) {
                    txtEnhancedTName.text = tClass;
                }
            } else {
                var oldTTxt = mcPortraitTarget.getChildByName("_txtEnhancedName");
                if (oldTTxt != null) oldTTxt.visible = false;
                strTargetName.visible = true;
                if (tUser != "" && strTargetName.text == tClass) {
                    strTargetName.text = tUser;
                }
            }
        }

        // Restore native options button and remove any legacy ToT plate
        var btnOption:Dynamic = Reflect.field(mcPortraitTarget, "btnOption");
        if (btnOption != null) {
            btnOption.visible = true;
        }
        var oldPlate:Dynamic = mcPortraitTarget.getChildByName("mcTargetOfTarget");
        if (oldPlate != null && oldPlate.parent != null) {
            try { oldPlate.parent.removeChild(oldPlate); } catch (_:Dynamic) {}
        }

        if (_targetDrag != null) {
            _targetDrag.syncSatellites();
        }
    }

    // =========================================================================
    // RESTORE NATIVE BEHAVIOR
    // =========================================================================
    private static function restoreNativeFrame(hpClip:Dynamic, strIntHP:TextField):Void {
        if (strIntHP != null) {
            strIntHP.visible = true;
        }
        var oldHP:Dynamic = hpClip.getChildByName("_txtEnhancedHP");
        if (oldHP != null) oldHP.visible = false;
        var oldPct:Dynamic = hpClip.getChildByName("_txtEnhancedPct");
        if (oldPct != null) oldPct.visible = false;
        var legacyPct:Dynamic = hpClip.getChildByName("strIntHPPct");
        if (legacyPct != null) legacyPct.visible = false;
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

    public static inline function isMovableFramesEnabled():Bool {
        return ApiConfig.getBool(CONFIG_MOVABLE, true);
    }

    public static inline function setMovableFramesEnabled(enabled:Bool):Void {
        ApiConfig.setBool(CONFIG_MOVABLE, enabled);
        if (!enabled) {
            // Give position controls back to the game:
            // Stop any active dragging / outlines
            if (_targetDrag != null) {
                _targetDrag.stopPress();
                _targetDrag.hideBackdrop();
            }
            // Reset target frame and close button back to game's native default coordinates
            try {
                if (Api.game != null && Api.game.ui != null) {
                    if (Api.game.ui.mcPortraitTarget != null) {
                        Api.game.ui.mcPortraitTarget.x = 235.0;
                        Api.game.ui.mcPortraitTarget.y = 2.0;
                    }
                    if (Api.game.ui.btnTargetPortraitClose != null) {
                        Api.game.ui.btnTargetPortraitClose.x = 413.7;
                        Api.game.ui.btnTargetPortraitClose.y = 10.0;
                    }
                }
            } catch (_:Dynamic) {}
        } else {
            // Restore custom movable coordinates
            if (_targetDrag != null) {
                _targetDrag.restorePosition();
            }
        }
    }

    public static function resetFramePositions():Void {
        ApiConfig.delete("api_pos_player_frame_x");
        ApiConfig.delete("api_pos_player_frame_y");
        try {
            if (Api.game != null && Api.game.ui != null && Api.game.ui.mcPortrait != null) {
                Api.game.ui.mcPortrait.x = 0;
                Api.game.ui.mcPortrait.y = 0;
            }
        } catch (_:Dynamic) {}
        if (_targetDrag != null) {
            _targetDrag.resetPosition();
        } else {
            try {
                if (Api.game != null && Api.game.ui != null) {
                    if (Api.game.ui.mcPortraitTarget != null) {
                        Api.game.ui.mcPortraitTarget.x = 235.0;
                        Api.game.ui.mcPortraitTarget.y = 2.0;
                    }
                    if (Api.game.ui.btnTargetPortraitClose != null) {
                        Api.game.ui.btnTargetPortraitClose.x = 413.7;
                        Api.game.ui.btnTargetPortraitClose.y = 10.0;
                    }
                }
            } catch (_:Dynamic) {}
        }
    }

    public static function reloadFromConfig():Void {
        updateFrames();
    }



}

/**
 * NativeFrameDrag:
 * Draggable frame controller for default AQW target frame (mcPortraitTarget).
 * - Mouse drag anywhere on target frame (with full-coverage transparent hit area)
 * - Screen boundary clamping strictly to physical borders (no off-screen hiding)
 * - Clean outline border highlight when hovering/dragging (no black background pad)
 * - Suppressed click on release so dragging doesn't untarget or open options
 * - Close button (btnTargetPortraitClose) anchored 1:1 with frame
 * - Persistent saved coordinates synced with config and kept in sync during target switches
 */
class NativeFrameDrag {
    private static inline var THRESHOLD_SQ:Float = 9.0; // 3px drag threshold

    // Visual frame physical offsets & dimensions relative to mcPortraitTarget origin
    public static inline var FRAME_OFFSET_X:Float = 14.0;
    public static inline var FRAME_OFFSET_Y:Float = 12.0;
    public static inline var FRAME_WIDTH:Float    = 188.0;
    public static inline var FRAME_HEIGHT:Float   = 81.0;

    // Close button offset relative to target frame origin (native AQW: 413.7 - 235.0 = 178.7, 10.0 - 2.0 = 8.0)
    public static inline var CLOSE_OFFSET_X:Float = 178.7;
    public static inline var CLOSE_OFFSET_Y:Float = 8.0;

    private var _target:Sprite;
    private var _key:String;
    private var _litePrefKey:String;
    private var _defaultX:Float = 235.0;
    private var _defaultY:Float = 2.0;
    private var _defaultRecorded:Bool = false;

    private var _closeOffsetX:Float = CLOSE_OFFSET_X;
    private var _closeOffsetY:Float = CLOSE_OFFSET_Y;

    private var _stage:Stage = null;
    private var _isDragging:Bool = false;
    private var _hasDragged:Bool = false;
    private var _startX:Float = 0;
    private var _startY:Float = 0;
    private var _origX:Float = 0;
    private var _origY:Float = 0;

    private var _backdrop:Sprite = null;
    private var _bgShape:Shape = null;
    private var _hitLayer:Sprite = null;

    public var target(get, never):Sprite;
    private inline function get_target():Sprite {
        return _target;
    }

    public function new(target:Sprite, key:String, litePrefKey:String) {
        _key = key;
        _litePrefKey = litePrefKey;
        rebind(target);
    }

    public function isStale(current:Sprite):Bool {
        if (current == null) return false;
        if (_target != current) return true;
        if (_target == null) return true;
        if (_target.parent == null && current.parent != null) return true;
        return false;
    }

    public function rebind(newTarget:Sprite):Void {
        if (_target == newTarget && _target != null && _target.parent != null) return;

        destroy();
        _target = newTarget;
        if (_target == null) return;

        _target.mouseEnabled = true;
        ensureHitLayer();

        _target.addEventListener(MouseEvent.MOUSE_DOWN, onDown, false);
        _target.addEventListener(MouseEvent.MOUSE_DOWN, onDown, true);
        _target.addEventListener(MouseEvent.ROLL_OVER, onRollOver, false);
        _target.addEventListener(MouseEvent.ROLL_OUT, onRollOut, false);
        _target.addEventListener(MouseEvent.CLICK, onClickCapture, true);

        _defaultRecorded = false;
        ensureAttached();
    }

    public function destroy():Void {
        stopPress();
        hideBackdrop();
        if (_target != null) {
            try {
                _target.removeEventListener(MouseEvent.MOUSE_DOWN, onDown, false);
                _target.removeEventListener(MouseEvent.MOUSE_DOWN, onDown, true);
                _target.removeEventListener(MouseEvent.ROLL_OVER, onRollOver, false);
                _target.removeEventListener(MouseEvent.ROLL_OUT, onRollOut, false);
                _target.removeEventListener(MouseEvent.CLICK, onClickCapture, true);
            } catch (_:Dynamic) {}
            if (_hitLayer != null && _hitLayer.parent == _target) {
                try { _target.removeChild(_hitLayer); } catch (_:Dynamic) {}
            }
        }
        if (_hitLayer != null) {
            _hitLayer.removeEventListener(MouseEvent.MOUSE_DOWN, onDown, false);
            _hitLayer = null;
        }
        _target = null;
    }

    private function ensureHitLayer():Void {
        if (_target == null) return;
        // When movable is OFF, do not attach custom hit interception layer
        if (!NativeFramesEnhancer.isMovableFramesEnabled()) {
            if (_hitLayer != null && _hitLayer.parent != null) {
                try { _hitLayer.parent.removeChild(_hitLayer); } catch (_:Dynamic) {}
            }
            return;
        }
        if (_hitLayer == null) {
            _hitLayer = new Sprite();
            _hitLayer.name = "_dragHitLayer";
            _hitLayer.mouseEnabled = true;
            _hitLayer.buttonMode = false;
            _hitLayer.graphics.beginFill(0x000000, 0.01);
            _hitLayer.graphics.drawRect(FRAME_OFFSET_X, FRAME_OFFSET_Y, FRAME_WIDTH, FRAME_HEIGHT);
            _hitLayer.graphics.endFill();
            _hitLayer.addEventListener(MouseEvent.MOUSE_DOWN, onDown, false);
            try {
                _target.addChildAt(_hitLayer, 0);
            } catch (_:Dynamic) {
                try { _target.addChild(_hitLayer); } catch (_:Dynamic) {}
            }
        } else if (_hitLayer.parent != _target) {
            try {
                _target.addChildAt(_hitLayer, 0);
            } catch (_:Dynamic) {
                try { _target.addChild(_hitLayer); } catch (_:Dynamic) {}
            }
        }
    }

    public function ensureAttached():Void {
        if (_target == null) return;
        ensureHitLayer();

        // When movable is OFF, give position controls completely to the game
        if (!NativeFramesEnhancer.isMovableFramesEnabled()) {
            return;
        }

        var g:Dynamic = Api.game;
        var closeBtn:Dynamic = (g != null && g.ui != null) ? g.ui.btnTargetPortraitClose : null;

        // Verify close button offset within expected bounds or lock to exact native constants
        if (closeBtn != null && _target.x > 100) {
            var diffX = closeBtn.x - _target.x;
            var diffY = closeBtn.y - _target.y;
            if (diffX >= 170.0 && diffX <= 190.0) {
                _closeOffsetX = diffX;
            } else {
                _closeOffsetX = CLOSE_OFFSET_X;
            }
            if (diffY >= 0.0 && diffY <= 20.0) {
                _closeOffsetY = diffY;
            } else {
                _closeOffsetY = CLOSE_OFFSET_Y;
            }
        } else {
            _closeOffsetX = CLOSE_OFFSET_X;
            _closeOffsetY = CLOSE_OFFSET_Y;
        }

        if (!_defaultRecorded) {
            if (_target.x > 100) {
                _defaultX = _target.x;
                _defaultY = _target.y;
                _defaultRecorded = true;
                restorePosition();
            } else if (_target.parent != null && (ApiConfig.has(_key + "_x") || hasLitePref())) {
                _defaultRecorded = true;
                restorePosition();
            }
        } else {
            syncSatellites();
        }
    }

    private function hasLitePref():Bool {
        try {
            if (Api.game != null && Api.game.litePreference != null && Api.game.litePreference.data != null) {
                var lp:Dynamic = Reflect.field(Api.game.litePreference.data, _litePrefKey);
                return lp != null && lp.x != null && lp.y != null;
            }
        } catch (_:Dynamic) {}
        return false;
    }

    public function syncSatellites():Void {
        if (_target == null) return;
        if (!NativeFramesEnhancer.isMovableFramesEnabled()) return;
        ensureHitLayer();

        // Keep target at saved coordinates if movable frames is active, but never interrupt active click/drag!
        if (!_isDragging && _stage == null) {
            if (ApiConfig.has(_key + "_x") && ApiConfig.has(_key + "_y")) {
                var savedX = ApiConfig.getFloat(_key + "_x", _defaultX);
                var savedY = ApiConfig.getFloat(_key + "_y", _defaultY);
                if (_target.x != savedX || _target.y != savedY) {
                    _target.x = savedX;
                    _target.y = savedY;
                }
            }
        }

        syncCloseButton();
    }

    public function syncCloseButton():Void {
        if (_target == null) return;
        if (!NativeFramesEnhancer.isMovableFramesEnabled()) return;
        var g:Dynamic = Api.game;
        if (g == null || g.ui == null) return;

        var closeBtn:Dynamic = g.ui.btnTargetPortraitClose;
        if (closeBtn != null) {
            closeBtn.x = _target.x + _closeOffsetX;
            closeBtn.y = _target.y + _closeOffsetY;
        }
    }

    public inline function getVisualWidth():Float {
        return FRAME_WIDTH;
    }

    public inline function getVisualHeight():Float {
        return FRAME_HEIGHT;
    }

    private function onClickCapture(e:MouseEvent):Void {
        if (_hasDragged) {
            e.stopImmediatePropagation();
            e.stopPropagation();
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

    public function drawBackdrop():Void {
        if (!NativeFramesEnhancer.isMovableFramesEnabled()) {
            hideBackdrop();
            return;
        }
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
        }

        var parent = _target.parent;
        if (_backdrop.parent != parent) {
            var idx = parent.getChildIndex(_target);
            if (idx + 1 < parent.numChildren) {
                parent.addChildAt(_backdrop, idx + 1);
            } else {
                parent.addChild(_backdrop);
            }
        }

        var vx = _target.x + FRAME_OFFSET_X;
        var vy = _target.y + FRAME_OFFSET_Y;
        var bw = FRAME_WIDTH;
        var bh = FRAME_HEIGHT;

        // Exact physical boundaries - zero black pad, crisp 1.5px cyan outline
        _bgShape.graphics.clear();
        _bgShape.graphics.lineStyle(1.5, 0x38BDF8, 0.85);
        _bgShape.graphics.drawRoundRect(vx, vy, bw, bh, 6, 6);

        _backdrop.visible = true;
    }

    public function hideBackdrop():Void {
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
        if (_target == null) return;

        var stg:Stage = _target.stage;
        if (stg == null && Api.game != null && Api.game.stage != null) stg = Api.game.stage;
        if (stg == null) {
            try {
                if (Lib.current != null && Lib.current.stage != null) stg = Lib.current.stage;
            } catch (_:Dynamic) {}
        }
        if (stg == null) return;

        _stage = stg;
        _isDragging = false;
        _hasDragged = false;
        _startX = e.stageX;
        _startY = e.stageY;
        _origX = _target.x;
        _origY = _target.y;

        _stage.addEventListener(MouseEvent.MOUSE_MOVE, onMove, false, 0, true);
        _stage.addEventListener(MouseEvent.MOUSE_UP, onUp, false, 0, true);
        _stage.addEventListener(Event.MOUSE_LEAVE, onStageLeave, false, 0, true);
    }

    private function onStageLeave(e:Event):Void {
        onUp(null);
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

        // Exact clamping to screen boundaries
        var minX = Math.round(-FRAME_OFFSET_X);
        var minY = Math.round(-FRAME_OFFSET_Y);
        var maxX = Math.round(stageW - FRAME_OFFSET_X - FRAME_WIDTH);
        var maxY = Math.round(maxBottom - FRAME_OFFSET_Y - FRAME_HEIGHT);

        if (newX < minX) newX = minX;
        if (newY < minY) newY = minY;
        if (newX > maxX) newX = maxX;
        if (newY > maxY) newY = maxY;

        _target.x = newX;
        _target.y = newY;

        syncCloseButton();
        drawBackdrop();
        e.updateAfterEvent();
    }

    private function onUp(e:MouseEvent):Void {
        var wasDragging = _isDragging;
        stopPress();
        if (wasDragging) {
            _hasDragged = true;
            savePosition();
            haxe.Timer.delay(function() {
                _hasDragged = false;
            }, 150);
        }
        hideBackdrop();
    }

    public function stopPress():Void {
        _isDragging = false;
        if (_stage != null) {
            _stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMove);
            _stage.removeEventListener(MouseEvent.MOUSE_UP, onUp);
            _stage.removeEventListener(Event.MOUSE_LEAVE, onStageLeave);
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
        if (!NativeFramesEnhancer.isMovableFramesEnabled()) return;

        if (ApiConfig.has(_key + "_x") && ApiConfig.has(_key + "_y")) {
            _target.x = ApiConfig.getFloat(_key + "_x", _defaultX);
            _target.y = ApiConfig.getFloat(_key + "_y", _defaultY);
        } else {
            try {
                if (Api.game != null && Api.game.litePreference != null && Api.game.litePreference.data != null) {
                    var lp:Dynamic = Reflect.field(Api.game.litePreference.data, _litePrefKey);
                    if (lp != null && lp.x != null && lp.y != null) {
                        var px:Float = Std.parseFloat(Std.string(lp.x));
                        var py:Float = Std.parseFloat(Std.string(lp.y));
                        _target.x = px;
                        _target.y = py;
                        ApiConfig.setFloat(_key + "_x", px);
                        ApiConfig.setFloat(_key + "_y", py);
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

        var g:Dynamic = Api.game;
        if (g != null && g.ui != null && g.ui.btnTargetPortraitClose != null) {
            g.ui.btnTargetPortraitClose.x = _defaultX + _closeOffsetX;
            g.ui.btnTargetPortraitClose.y = _defaultY + _closeOffsetY;
        }

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
    public static function isMovableFramesEnabled():Bool return true;
    public static function setMovableFramesEnabled(enabled:Bool):Void {}
    public static function resetFramePositions():Void {}
    public static function reloadFromConfig():Void {}
}
#end
