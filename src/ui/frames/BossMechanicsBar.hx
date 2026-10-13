package ui.frames;

#if flash
import flash.display.Sprite;
import flash.display.Shape;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.Lib;
import com.aqwapi.Api;
import com.aqwapi.data.EntityDTO;
import com.aqwapi.utils.ApiConfig;
import ui.ApiMenus;
import ui.ApiStyle;
import ui.ApiDashboardModal;

/**
 * BossMechanicsBar:
 * Ultra-precision Boss Mechanic & Cast Alert Bar for AQW.
 *
 * Catches:
 * 1. Server event broadcasts (e.g. "Drakath gains power, and unleashes a destructive attack!").
 * 2. Lethal boss auras (Ultra Dage Counter Attack, Ultra Speaker Truth, Ultra Warden Enrage).
 * 3. Exact boss HP thresholds (Drakath 80% / 50% / 20% nukes).
 * 4. Taunt timers (Focus remaining on bosses).
 *
 * Uses pure TextFormat colors and standard ASCII tags (no broken unicode emojis).
 */
class BossMechanicsBar {
    public static inline var CONFIG_ENABLED:String       = "api_boss_bar_enabled";
    public static inline var CONFIG_TAUNT_ALERTS:String  = "api_boss_bar_taunts";
    public static inline var CONFIG_POS_X:String         = "api_boss_bar_x";
    public static inline var CONFIG_POS_Y:String         = "api_boss_bar_y";

    // Geometry
    public static inline var BAR_W:Float                 = 300.0;
    public static inline var BAR_H:Float                 = 22.0;

    // Palette (Strict standard TextFormat colors - no broken unicode emojis)
    public static inline var COLOR_BG:Int                = 0x0F1117; // Deep obsidian well
    public static inline var COLOR_BORDER:Int            = 0x000000; // Crisp black outer border
    public static inline var COLOR_WELL:Int              = 0x141721; // Dark well fill

    // Severity Fill & Text Colors
    public static inline var COLOR_DANGER:Int            = 0xEF4444; // Red: Stop attacking / Fatal nuke
    public static inline var COLOR_WARN:Int              = 0xF59E0B; // Amber: Taunt needed / Mechanic
    public static inline var COLOR_INFO:Int              = 0x38BDF8; // Blue: Shield / Defensive / Group phase
    public static inline var COLOR_SUCCESS:Int           = 0x22C55E; // Green: Safe / Taunt Active
    public static inline var COLOR_WHITE:Int             = 0xFFFFFF; // White primary text

    private static var _pocket:Dynamic                   = null;
    private static var _overlay:Dynamic                  = null;
    private static var _widget:Sprite                    = null;
    private static var _initialized:Bool                 = false;

    // Display components
    private static var _bgWell:Shape                     = null;
    private static var _barFill:Shape                    = null;
    private static var _barBorder:Shape                  = null;
    private static var _labelTxt:TextField               = null;
    private static var _timerTxt:TextField               = null;

    // Live Cast / Mechanic State
    private static var _active:Bool                      = false;
    private static var _castTag:String                   = "";
    private static var _castName:String                  = "";
    private static var _castColor:Int                    = COLOR_WARN;
    private static var _castDuration:Float               = 0.0; // Seconds
    private static var _startTs:Int                      = 0;   // getTimer() ms
    private static var _expireTs:Int                     = 0;   // getTimer() ms
    private static var _holdUntilTs:Int                  = 0;   // Keep visible briefly upon completion

    // Drakath Threshold State tracking
    private static var _lastDrakathHp:Int                = -1;
    private static var _drakathP1Fired:Bool              = false; // 80% (16M)
    private static var _drakathP2Fired:Bool              = false; // 50% (10M)
    private static var _drakathP3Fired:Bool              = false; // 20% (4M)

    // Last seen aura states to detect new applications
    private static var _lastCounterAttackActive:Bool     = false;
    private static var _lastTruthActive:Bool             = false;
    private static var _lastFocusActive:Bool             = false;

    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {
        if (_initialized) return;
        _initialized = true;
        _pocket = pocket;
        _overlay = overlay;

        var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);

        var attach = function(stageObj:Dynamic):Void {
            if (stageObj == null || _widget != null) return;
            buildBar(stageObj);
            hookNetwork();
        };

        if (theStage != null) {
            attach(theStage);
        } else if (_overlay != null) {
            _overlay.addEventListener(Event.ADDED_TO_STAGE, function(ev:Event):Void {
                if (_overlay.stage != null && _widget == null) {
                    attach(_overlay.stage);
                }
            });
        }
    }

    public static inline function isEnabled():Bool {
        return ApiConfig.getBool(CONFIG_ENABLED, true);
    }

    public static inline function setEnabled(val:Bool):Void {
        ApiConfig.setBool(CONFIG_ENABLED, val);
        if (_widget != null && !val) {
            _widget.visible = false;
        }
    }

    public static inline function isTauntAlertsEnabled():Bool {
        return ApiConfig.getBool(CONFIG_TAUNT_ALERTS, true);
    }

    public static inline function setTauntAlertsEnabled(val:Bool):Void {
        ApiConfig.setBool(CONFIG_TAUNT_ALERTS, val);
    }

    private static function buildBar(theStage:Dynamic):Void {
        _widget = new Sprite();
        _widget.name = "__bossMechanicsBar";
        _widget.visible = false;

        // Position: top-center below target frame by default
        var savedX = ApiConfig.getInt(CONFIG_POS_X, -9999);
        var savedY = ApiConfig.getInt(CONFIG_POS_Y, -9999);
        if (savedX == -9999 || savedY == -9999) {
            var stW:Float = (theStage.stageWidth != null && theStage.stageWidth > 0) ? theStage.stageWidth : 960.0;
            _widget.x = Math.round((stW - BAR_W) / 2.0);
            _widget.y = 70.0;
        } else {
            _widget.x = savedX;
            _widget.y = savedY;
        }

        // 1. Well Background
        _bgWell = new Shape();
        _bgWell.graphics.beginFill(COLOR_WELL, 0.95);
        _bgWell.graphics.drawRect(0, 0, BAR_W, BAR_H);
        _bgWell.graphics.endFill();
        _widget.addChild(_bgWell);

        // 2. Bar Fill
        _barFill = new Shape();
        _widget.addChild(_barFill);

        // 3. Crisp 1px Black Border Framing the Bar
        _barBorder = new Shape();
        _barBorder.graphics.lineStyle(1.0, COLOR_BORDER, 1.0);
        _barBorder.graphics.drawRect(0, 0, BAR_W, BAR_H);
        _widget.addChild(_barBorder);

        // 4. Action Cue & Mechanic Label (Left)
        _labelTxt = new TextField();
        var labelFmt = new TextFormat(ApiStyle.FONT_FAMILY, 8.5, COLOR_WHITE, true, false, false, null, null, TextFormatAlign.LEFT);
        _labelTxt.defaultTextFormat = labelFmt;
        _labelTxt.x = 6.0;
        _labelTxt.y = 3.0;
        _labelTxt.width = BAR_W - 55.0;
        _labelTxt.height = BAR_H;
        _labelTxt.selectable = false;
        _labelTxt.mouseEnabled = false;
        _labelTxt.filters = ApiStyle.getBarTextOutlineFilter();
        _widget.addChild(_labelTxt);

        // 5. Live Countdown Timer (Right)
        _timerTxt = new TextField();
        var timerFmt = new TextFormat(ApiStyle.FONT_FAMILY, 8.5, COLOR_WHITE, true, false, false, null, null, TextFormatAlign.RIGHT);
        _timerTxt.defaultTextFormat = timerFmt;
        _timerTxt.x = BAR_W - 55.0;
        _timerTxt.y = 3.0;
        _timerTxt.width = 49.0;
        _timerTxt.height = BAR_H;
        _timerTxt.selectable = false;
        _timerTxt.mouseEnabled = false;
        _timerTxt.filters = ApiStyle.getBarTextOutlineFilter();
        _widget.addChild(_timerTxt);

        // Setup Dragging
        setupDragging(theStage);

        // Frame Update Loop
        _widget.addEventListener(Event.ENTER_FRAME, onEnterFrame);

        theStage.addChild(_widget);
    }

    private static function setupDragging(theStage:Dynamic):Void {
        var isDragging:Bool = false;
        var dragStartX:Float = 0;
        var dragStartY:Float = 0;

        _widget.buttonMode = true;
        _widget.useHandCursor = true;

        _widget.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            isDragging = true;
            dragStartX = e.stageX - _widget.x;
            dragStartY = e.stageY - _widget.y;
            theStage.setChildIndex(_widget, theStage.numChildren - 1);
        });

        theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (!isDragging) return;
            var newX = e.stageX - dragStartX;
            var newY = e.stageY - dragStartY;

            var stW:Float = (theStage.stageWidth != null) ? theStage.stageWidth : 960.0;
            var stH:Float = (theStage.stageHeight != null) ? theStage.stageHeight : 550.0;
            newX = Math.max(0, Math.min(stW - BAR_W, newX));
            newY = Math.max(0, Math.min(stH - BAR_H, newY));

            _widget.x = newX;
            _widget.y = newY;
        });

        theStage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            if (!isDragging) return;
            isDragging = false;
            ApiConfig.setInt(CONFIG_POS_X, Math.round(_widget.x));
            ApiConfig.setInt(CONFIG_POS_Y, Math.round(_widget.y));
        });
    }

    /**
     * Intercepts SmartFox raw server packets at Priority 100 before native AQW parses them.
     */
    private static function hookNetwork():Void {
        try {
            var g:Dynamic = Api.game;
            if (g != null && g.sfc != null) {
                g.sfc.addEventListener("onExtensionResponse", onPacketReceived, false, 100, true);
            }
        } catch (_:Dynamic) {}
    }

    private static function onPacketReceived(e:Dynamic):Void {
        if (!isEnabled()) return;
        if (e == null || e.params == null) return;

        var type:String = Std.string(e.params.type);
        var dataObj:Dynamic = e.params.dataObj;
        if (dataObj == null) return;

        var msgText:String = "";

        if (type == "str") {
            var res:Array<Dynamic> = cast dataObj;
            var cmd:String = res[0];
            if (cmd == "warning" || cmd == "server" || cmd == "em") {
                if (res.length > 2) msgText = Std.string(res[res.length - 1]);
            } else if (cmd == "popup" && res.length > 3) {
                msgText = Std.string(res[3]);
            }
        } else if (type == "json") {
            var cmd:String = Std.string(dataObj.cmd);
            if (cmd == "warning" || cmd == "server" || cmd == "message") {
                if (dataObj.msg != null) msgText = Std.string(dataObj.msg);
                else if (dataObj.strMessage != null) msgText = Std.string(dataObj.strMessage);
            }
        }

        if (msgText != "") {
            parseServerBroadcast(msgText);
        }
    }

    /**
     * Parses server broadcast text to trigger cast alert bars with exact durations.
     */
    public static function parseServerBroadcast(rawMsg:String):Void {
        if (rawMsg == null || rawMsg == "") return;
        var msgLower = rawMsg.toLowerCase();

        // 1. Champion Drakath Destructive Attack
        if (msgLower.indexOf("destructive attack") > -1 || (msgLower.indexOf("drakath") > -1 && msgLower.indexOf("gains power") > -1)) {
            triggerCast("[SHIELD / HEAL]", "Destructive Attack (Drakath)", COLOR_WARN, 3.5);
            return;
        }

        // 2. Ultra Dage Counter Attack Warning
        if (msgLower.indexOf("counter attack") > -1 || (msgLower.indexOf("dage") > -1 && msgLower.indexOf("arrogance") > -1)) {
            triggerCast("[STOP ATTACKING]", "Counter Attack (Dage)", COLOR_DANGER, 5.0);
            return;
        }

        // 3. Ultra Speaker: The Truth / Equalizer / Listen Closely
        if (msgLower.indexOf("truth") > -1 || (msgLower.indexOf("speaker") > -1 && msgLower.indexOf("truth") > -1)) {
            triggerCast("[TAUNT NOW]", "The Truth (Speaker)", COLOR_WARN, 4.0);
            return;
        }
        if (msgLower.indexOf("equalizer") > -1) {
            triggerCast("[HEAL / STACK]", "Equalizer (Speaker)", COLOR_INFO, 3.5);
            return;
        }
        if (msgLower.indexOf("listen closely") > -1) {
            triggerCast("[PREPARE DEFENSES]", "Listen Closely (Speaker)", COLOR_INFO, 4.0);
            return;
        }

        // 4. Ultra Warden Enrage
        if (msgLower.indexOf("warden") > -1 && (msgLower.indexOf("enrage") > -1 || msgLower.indexOf("savage") > -1)) {
            triggerCast("[TAUNT / SHIELD]", "Warden Enraged", COLOR_DANGER, 4.0);
            return;
        }

        // 5. Ultra Tyndarius Orbs
        if (msgLower.indexOf("tyndarius") > -1 && (msgLower.indexOf("fire") > -1 || msgLower.indexOf("orb") > -1)) {
            triggerCast("[TAUNT ORBS]", "Fire Storm (Tyndarius)", COLOR_DANGER, 4.0);
            return;
        }

        // 6. Generic Boss Charge / Channel detector
        if (msgLower.indexOf("channels") > -1 || msgLower.indexOf("charges") > -1 || msgLower.indexOf("unleashes") > -1) {
            var cleanText = rawMsg;
            if (cleanText.length > 32) cleanText = cleanText.substr(0, 32) + "...";
            triggerCast("[WARNING]", cleanText, COLOR_WARN, 3.5);
        }
    }

    /**
     * Triggers an active countdown cast bar with live millisecond timing.
     */
    public static function triggerCast(tag:String, name:String, color:Int, durationSec:Float):Void {
        _active = true;
        _castTag = tag;
        _castName = name;
        _castColor = color;
        _castDuration = Math.max(0.5, durationSec);
        _startTs = Lib.getTimer();
        _expireTs = _startTs + Std.int(_castDuration * 1000);
        _holdUntilTs = _expireTs + 600; // Hold briefly for impact

        if (_widget != null) {
            _widget.visible = true;
        }
    }

    /**
     * Update loop executed every frame (60 FPS = 16.6ms precision).
     */
    private static function onEnterFrame(e:Event):Void {
        if (!isEnabled() || !ApiMenus.isInGame() || ApiDashboardModal.isOpen()) {
            if (_widget != null) _widget.visible = false;
            return;
        }

        var now = Lib.getTimer();

        // 1. Check live Target Auras & Boss HP Breakpoints
        checkLiveCombatState(now);

        // 2. Render Active Cast Bar
        if (_active) {
            if (now >= _holdUntilTs) {
                // Completed & expired
                _active = false;
                _widget.visible = false;
                return;
            }

            _widget.visible = true;
            var remainingSec:Float = Math.max(0.0, (_expireTs - now) / 1000.0);
            var ratio:Float = Math.max(0.0, Math.min(1.0, (_expireTs - now) / (_castDuration * 1000.0)));

            // Redraw Fill
            var g = _barFill.graphics;
            g.clear();
            var fillW = Math.round(BAR_W * ratio);
            if (fillW > 0) {
                g.beginFill(_castColor, 0.95);
                g.drawRect(0, 0, fillW, BAR_H);
                g.endFill();
            }

            // Labels with pure TextFormat colors
            _labelTxt.textColor = _castColor;
            _labelTxt.text = _castTag + " " + _castName;

            if (remainingSec > 0.0) {
                _timerTxt.text = (remainingSec >= 10.0) ? (Math.round(remainingSec) + "s") : (Math.round(remainingSec * 10) / 10.0 + "s");
                _timerTxt.textColor = (remainingSec <= 1.0) ? COLOR_DANGER : COLOR_WHITE;
            } else {
                _timerTxt.text = "IMPACT!";
                _timerTxt.textColor = COLOR_DANGER;
            }
        }
    }

    /**
     * Inspects target boss HP breakpoints and aura state every frame.
     */
    private static function checkLiveCombatState(now:Int):Void {
        var t:EntityDTO = (Api.player != null) ? Api.player.target : null;
        if (t == null) return;

        var tName = (t.name != null) ? t.name.toLowerCase() : "";

        // --- A. Champion Drakath Threshold Detection ---
        if (tName.indexOf("drakath") > -1 && t.maxHp >= 15000000) {
            var hp = t.hp;
            var maxHp = t.maxHp;
            var hpRatio = hp / maxHp;

            // Phase 1: 80% (16M)
            if (hpRatio <= 0.80 && !_drakathP1Fired && _lastDrakathHp > (maxHp * 0.80)) {
                _drakathP1Fired = true;
                triggerCast("[SHIELD / HEAL]", "Destructive Attack (80%)", COLOR_WARN, 3.5);
            }
            // Phase 2: 50% (10M)
            else if (hpRatio <= 0.50 && !_drakathP2Fired && _lastDrakathHp > (maxHp * 0.50)) {
                _drakathP2Fired = true;
                triggerCast("[SHIELD / HEAL]", "Destructive Attack (50%)", COLOR_DANGER, 3.5);
            }
            // Phase 3: 20% (4M)
            else if (hpRatio <= 0.20 && !_drakathP3Fired && _lastDrakathHp > (maxHp * 0.20)) {
                _drakathP3Fired = true;
                triggerCast("[SHIELD / HEAL]", "Destructive Attack (20%)", COLOR_DANGER, 3.5);
            }
            _lastDrakathHp = hp;
        }

        // --- B. Boss Aura Tracking (Counter Attack, Truth, Focus) ---
        var rawAuras:Dynamic = null;
        try {
            rawAuras = Api.aura.getRawAuras("target");
        } catch (_:Dynamic) {}

        if (rawAuras != null) {
            var foundCounterAttack:Bool = false;
            var foundFocus:Bool = false;
            var focusRemaining:Float = 0.0;

            var inspectAura = function(auraObj:Dynamic):Void {
                if (auraObj == null || auraObj.nam == null) return;
                var aName:String = Std.string(auraObj.nam).toLowerCase();

                // Counter Attack (Dage)
                if (aName.indexOf("counter attack") > -1) {
                    foundCounterAttack = true;
                    if (!_lastCounterAttackActive && !_active) {
                        var dur:Float = (auraObj.dur != null) ? Std.parseFloat(Std.string(auraObj.dur)) : 5.0;
                        triggerCast("[STOP ATTACKING]", "Counter Attack (Dage)", COLOR_DANGER, dur);
                    }
                }

                // Focus (Taunt on target)
                if (aName == "focus" || aName.indexOf("focus") > -1) {
                    foundFocus = true;
                    if (auraObj.dur != null && auraObj.ts != null) {
                        var dur:Float = Std.parseFloat(Std.string(auraObj.dur));
                        var ts:Float = Std.parseFloat(Std.string(auraObj.ts));
                        var elapsed:Float = (Date.now().getTime() - ts) / 1000.0;
                        focusRemaining = Math.max(0.0, dur - elapsed);
                    }
                }
            };

            if (Std.isOfType(rawAuras, Array)) {
                var arr:Array<Dynamic> = cast rawAuras;
                for (a in arr) inspectAura(a);
            } else {
                for (k in Reflect.fields(rawAuras)) {
                    inspectAura(Reflect.field(rawAuras, k));
                }
            }

            _lastCounterAttackActive = foundCounterAttack;

            // If Taunt Alerts enabled and Focus is dropping low (<= 3.0s)
            if (isTauntAlertsEnabled() && foundFocus && focusRemaining > 0.0 && focusRemaining <= 3.0) {
                if (!_active) {
                    triggerCast("[TAUNT EXPIRING]", "Re-Taunt Boss Now!", COLOR_WARN, focusRemaining);
                }
            }
        }
    }

    /**
     * Preview method for testing in settings dashboard.
     */
    public static function testPreview():Void {
        triggerCast("[TEST ALERT]", "Destructive Attack Simulation", COLOR_WARN, 4.0);
    }
}
#else
class BossMechanicsBar {
    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {}
    public static function isEnabled():Bool return false;
    public static function setEnabled(val:Bool):Void {}
    public static function isTauntAlertsEnabled():Bool return false;
    public static function setTauntAlertsEnabled(val:Bool):Void {}
    public static function testPreview():Void {}
}
#end
