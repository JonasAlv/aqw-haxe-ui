package ui.topbar;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.FocusEvent;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import com.aqwapi.Api;

import com.aqwapi.utils.ApiConfig;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.components.ClassModeSelector;

/**
 * Dropdown panel for Combat / Auto controls attached directly beneath the TopBar.
 * 100% pure ASCII strings and Flash vector graphics (zero Unicode glyphs).
 */
class TopBarAutoPanel extends Sprite {
    public static inline var PANEL_WIDTH:Float = 220.0;
    public static inline var PANEL_HEIGHT:Float = 120.0;

    private var _bg:Shape;
    private var _btnAtk:Sprite;
    private var _txtAtk:TextField;
    private var _dotAtk:Shape;

    private var _btnHunt:Sprite;
    private var _txtHunt:TextField;
    private var _dotHunt:Shape;

    private var _classSelector:ClassModeSelector;
    private var _selectedClass:String = "Current";
    private var _selectedMode:String = "Auto";

    private var _targetInput:TextField;
    private var _inputPlate:Sprite;
    private var _btnGetTarget:Sprite;

    private var _btnCounter:Sprite;
    private var _txtCounter:TextField;
    private var _iconCounter:Shape;

    private var _isHunting:Bool = false;
    private var _huntTimer:flash.utils.Timer = null;
    private var _lastAtkActive:Int = -1;
    private var _lastHuntActive:Int = -1;
    private var _lastCounterActive:Int = -1;
    private var _lastCounterPaused:Bool = false;

    public function new() {
        super();
        buildUI();
    }

    public function isHunting():Bool {
        return _isHunting;
    }

    private function buildUI():Void {
        // Background card
        _bg = new Shape();
        var g = _bg.graphics;
        g.beginFill(ApiStyle.COLOR_BG_CARD, 0.96);
        g.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.95);
        g.drawRoundRect(0, 0, PANEL_WIDTH, PANEL_HEIGHT, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
        g.endFill();

        g.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.5);
        g.moveTo(3, 1);
        g.lineTo(PANEL_WIDTH - 3, 1);
        addChild(_bg);

        var btnW:Float = 98.0;
        var btnH:Float = 24.0;

        // --- Row 1 (y = 8): Action Buttons (Auto | Hunt) ---
        _btnAtk = createActionButton(btnW, btnH, "Auto");
        _btnAtk.x = 8.0;
        _btnAtk.y = 8.0;
        _btnAtk.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void toggleAutoAttack());
        addChild(_btnAtk);
        _txtAtk = cast _btnAtk.getChildByName("label");
        _dotAtk = cast _btnAtk.getChildByName("dot");

        _btnHunt = createActionButton(btnW, btnH, "Hunt");
        _btnHunt.x = 114.0;
        _btnHunt.y = 8.0;
        _btnHunt.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void toggleAutoHunt());
        addChild(_btnHunt);
        _txtHunt = cast _btnHunt.getChildByName("label");
        _dotHunt = cast _btnHunt.getChildByName("dot");

        // --- Row 2 (y = 36): Class & Mode Selector ---
        _classSelector = new ClassModeSelector(120.0, 78.0, 24.0, 6.0, false, "Auto", function(selClass:String, selMode:String):Void {
            _selectedClass = selClass;
            _selectedMode = selMode;
            if (Api.combat != null && Api.combat.isRunning()) {
                Api.combat.startSmartStandalone(_selectedClass, _selectedMode);
            } else if (selClass != "Current" && Api.inventory != null) {
                try {
                    var curClass = (Api.player != null && Api.player.className != null) ? Api.player.className : "";
                    if (curClass == "" || curClass.toLowerCase() != selClass.toLowerCase()) {
                        Api.inventory.equip(selClass);
                    }
                } catch (_:Dynamic) {}
            }
            ApiNotificationManager.notify("Combat: " + selClass + " [" + selMode + "]");
        });
        _classSelector.x = 8.0;
        _classSelector.y = 36.0;
        _classSelector.bindConfig("api_smart_class", "api_smart_mode", "Current", "Auto");
        _selectedClass = _classSelector.selectedClass;
        _selectedMode = _classSelector.selectedMode;
        addChild(_classSelector);

        // --- Row 3 (y = 64): Target Input & Crosshair Button ---
        _inputPlate = new Sprite();
        _inputPlate.graphics.beginFill(ApiStyle.COLOR_BG_INPUT, 0.95);
        _inputPlate.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT);
        _inputPlate.graphics.drawRoundRect(0, 0, 174.0, 24.0, 4, 4);
        _inputPlate.graphics.endFill();
        _inputPlate.x = 8.0;
        _inputPlate.y = 64.0;
        addChild(_inputPlate);

        var savedTarget = ApiConfig.getString("api_widget_hunt_target", "");

        _targetInput = new TextField();
        _targetInput.type = TextFieldType.INPUT;
        var inFmt = new TextFormat(ApiStyle.FONT_FAMILY, 10, ApiStyle.COLOR_TEXT_PRIMARY);
        _targetInput.defaultTextFormat = inFmt;
        _targetInput.x = 12.0;
        _targetInput.y = 67.0;
        _targetInput.width = 166.0;
        _targetInput.height = 18.0;
        _targetInput.selectable = true;
        _targetInput.text = (savedTarget != "") ? savedTarget : "Target (Name/ID)";
        _targetInput.textColor = (savedTarget != "") ? ApiStyle.COLOR_TEXT_PRIMARY : ApiStyle.COLOR_TEXT_MUTED;

        _targetInput.addEventListener(FocusEvent.FOCUS_IN, function(e:FocusEvent):Void {
            if (_targetInput.text == "Target (Name/ID)" || _targetInput.text == "Target (Name / ID / MMID)") {
                _targetInput.text = "";
                _targetInput.textColor = ApiStyle.COLOR_TEXT_PRIMARY;
            }
        });

        _targetInput.addEventListener(FocusEvent.FOCUS_OUT, function(e:FocusEvent):Void {
            var trimmed = StringTools.trim(_targetInput.text);
            if (trimmed == "") {
                _targetInput.text = "Target (Name/ID)";
                _targetInput.textColor = ApiStyle.COLOR_TEXT_MUTED;
                ApiConfig.setString("api_widget_hunt_target", "");
            } else {
                ApiConfig.setString("api_widget_hunt_target", trimmed);
            }
        });

        _targetInput.addEventListener(KeyboardEvent.KEY_DOWN, function(e:KeyboardEvent):Void {
            if (e.keyCode == 13) {
                var trimmed = StringTools.trim(_targetInput.text);
                if (trimmed == "Target (Name/ID)" || trimmed == "Target (Name / ID / MMID)") trimmed = "";
                ApiConfig.setString("api_widget_hunt_target", trimmed);
                if (theStage != null) theStage.focus = null;
            }
        });
        addChild(_targetInput);

        // Crosshair Button to acquire current target
        _btnGetTarget = new Sprite();
        _btnGetTarget.buttonMode = true;
        _btnGetTarget.useHandCursor = true;
        _btnGetTarget.x = 188.0;
        _btnGetTarget.y = 64.0;
        renderGetTargetBtn(false, false);

        _btnGetTarget.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void renderGetTargetBtn(true, false));
        _btnGetTarget.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void renderGetTargetBtn(false, false));
        _btnGetTarget.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            acquireCurrentTarget();
        });
        addChild(_btnGetTarget);

        // --- Row 4 (y = 92): Counter Mechanic Guard ---
        _btnCounter = new Sprite();
        _btnCounter.buttonMode = true;
        _btnCounter.useHandCursor = true;
        _btnCounter.x = 8.0;
        _btnCounter.y = 92.0;

        _iconCounter = new Shape();
        _btnCounter.addChild(_iconCounter);

        _txtCounter = new TextField();
        var ctrFmt = new TextFormat(ApiStyle.FONT_FAMILY, 9, ApiStyle.COLOR_TEXT_MUTED, true);
        ctrFmt.align = TextFormatAlign.LEFT;
        _txtCounter.defaultTextFormat = ctrFmt;
        _txtCounter.x = 18.0;
        _txtCounter.y = 1.0;
        _txtCounter.width = 86.0;
        _txtCounter.height = 16.0;
        _txtCounter.selectable = false;
        _txtCounter.mouseEnabled = false;
        _btnCounter.addChild(_txtCounter);

        var isCounter = (Api.combat != null ? Api.combat.counterHandler : false);
        var isPaused = (Api.combat != null ? Api.combat.isPausedByAura : false);
        renderCounterBtnStyle(isCounter, isPaused, false);

        _btnCounter.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            var c = (Api.combat != null ? Api.combat.counterHandler : false);
            var p = (Api.combat != null ? Api.combat.isPausedByAura : false);
            renderCounterBtnStyle(c, p, true);
        });
        _btnCounter.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            var c = (Api.combat != null ? Api.combat.counterHandler : false);
            var p = (Api.combat != null ? Api.combat.isPausedByAura : false);
            renderCounterBtnStyle(c, p, false);
        });
        _btnCounter.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            toggleCounterHandler();
        });
        addChild(_btnCounter);
    }

    private var theStage(get, never):flash.display.Stage;
    private function get_theStage():flash.display.Stage {
        return (this.stage != null) ? this.stage : flash.Lib.current.stage;
    }

    private function createActionButton(w:Float, h:Float, label:String):Sprite {
        var btn = new Sprite();
        btn.buttonMode = true;
        btn.useHandCursor = true;

        var dot = new Shape();
        dot.name = "dot";
        btn.addChild(dot);

        var lbl = new TextField();
        lbl.name = "label";
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 10, ApiStyle.COLOR_TEXT_PRIMARY, true);
        fmt.align = TextFormatAlign.CENTER;
        lbl.defaultTextFormat = fmt;
        lbl.x = 12.0;
        lbl.y = 3.0;
        lbl.width = w - 14.0;
        lbl.height = 18.0;
        lbl.selectable = false;
        lbl.mouseEnabled = false;
        lbl.text = label;
        btn.addChild(lbl);

        var drawState = function(hover:Bool, active:Bool):Void {
            renderActionBtnStyle(btn, active, label, w, h, hover);
        };
        drawState(false, false);

        btn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            var active = (btn == _btnAtk) ? (Api.combat != null && Api.combat.isRunning() && !_isHunting) : _isHunting;
            drawState(true, active);
        });
        btn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            var active = (btn == _btnAtk) ? (Api.combat != null && Api.combat.isRunning() && !_isHunting) : _isHunting;
            drawState(false, active);
        });

        return btn;
    }

    private function renderActionBtnStyle(btn:Sprite, active:Bool, label:String, w:Float, h:Float, hover:Bool = false):Void {
        btn.graphics.clear();
        var bgCol = active ? ApiStyle.COLOR_BG_SURFACE : (hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_CARD);
        var border = active ? ApiStyle.COLOR_STATUS_ACTIVE : (hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT);
        var textColor = active ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_TEXT_PRIMARY;

        btn.graphics.beginFill(bgCol, 0.94);
        btn.graphics.lineStyle(1, border);
        btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
        btn.graphics.endFill();

        btn.graphics.lineStyle(1, active ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_BEVEL_LIGHT, 0.55);
        btn.graphics.moveTo(2, 1);
        btn.graphics.lineTo(w - 2, 1);

        var dot:Shape = cast btn.getChildByName("dot");
        if (dot != null) {
            dot.graphics.clear();
            var dotX:Float = 9.0;
            var dotY:Float = h / 2.0;
            dot.graphics.lineStyle(0, 0, 0);
            if (active) {
                dot.graphics.beginFill(ApiStyle.COLOR_STATUS_ACTIVE, 0.35);
                dot.graphics.drawCircle(dotX, dotY, 4.0);
                dot.graphics.endFill();
                dot.graphics.beginFill(ApiStyle.COLOR_STATUS_ACTIVE, 1.0);
                dot.graphics.drawCircle(dotX, dotY, 2.2);
                dot.graphics.endFill();
            } else {
                dot.graphics.beginFill(ApiStyle.COLOR_STATUS_INACTIVE, 0.85);
                dot.graphics.drawCircle(dotX, dotY, 2.2);
                dot.graphics.endFill();
            }
        }

        var lbl:TextField = cast btn.getChildByName("label");
        if (lbl != null) {
            lbl.text = label;
            lbl.textColor = textColor;
        }
    }

    private function renderGetTargetBtn(hover:Bool = false, active:Bool = false):Void {
        if (_btnGetTarget == null) return;
        var g = _btnGetTarget.graphics;
        g.clear();

        var bgCol = active ? ApiStyle.COLOR_BG_SURFACE : (hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE);
        var border = active ? ApiStyle.COLOR_STATUS_ACTIVE : (hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT);
        var iconColor = active ? ApiStyle.COLOR_STATUS_ACTIVE : (hover ? ApiStyle.COLOR_TEXT_TITLE : ApiStyle.COLOR_TEXT_MUTED);

        g.beginFill(bgCol, 0.95);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 24.0, 24.0, 4, 4);
        g.endFill();

        var cx = 12.0;
        var cy = 12.0;
        g.lineStyle(1.8, iconColor, 1.0, true);
        g.drawCircle(cx, cy, 4.5);
        g.moveTo(cx - 6.5, cy); g.lineTo(cx - 3.0, cy);
        g.moveTo(cx + 3.0, cy); g.lineTo(cx + 6.5, cy);
        g.moveTo(cx, cy - 6.5); g.lineTo(cx, cy - 3.0);
        g.moveTo(cx, cy + 3.0); g.lineTo(cx, cy + 6.5);
    }

    private function renderCounterBtnStyle(active:Bool, paused:Bool, hover:Bool = false):Void {
        if (_btnCounter == null) return;
        var g = _btnCounter.graphics;
        g.clear();

        var bgCol:Int = ApiStyle.COLOR_BG_CARD;
        var border:Int = ApiStyle.COLOR_BORDER_DEFAULT;
        var textCol:Int = ApiStyle.COLOR_TEXT_MUTED;
        var iconCol:Int = ApiStyle.COLOR_TEXT_MUTED;
        var bgAlpha:Float = 0.88;
        var labelText:String = "Counter: OFF";

        if (paused) {
            bgCol = ApiStyle.COLOR_STATUS_WARN;
            bgAlpha = 0.25;
            border = ApiStyle.COLOR_STATUS_WARN;
            textCol = ApiStyle.COLOR_STATUS_WARN;
            iconCol = ApiStyle.COLOR_STATUS_WARN;
            labelText = "Counter: HOLD";
        } else if (active) {
            bgCol = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE;
            bgAlpha = 0.95;
            border = hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_STATUS_ACTIVE;
            textCol = ApiStyle.COLOR_STATUS_ACTIVE;
            iconCol = ApiStyle.COLOR_STATUS_ACTIVE;
            labelText = "Counter: ON";
        } else {
            bgCol = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_CARD;
            border = hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT;
            textCol = hover ? ApiStyle.COLOR_TEXT_PRIMARY : ApiStyle.COLOR_TEXT_MUTED;
            iconCol = hover ? ApiStyle.COLOR_TEXT_PRIMARY : ApiStyle.COLOR_TEXT_MUTED;
            labelText = "Counter: OFF";
        }

        g.beginFill(bgCol, bgAlpha);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 106.0, 20.0, 4, 4);
        g.endFill();

        if (_iconCounter != null) {
            var ig = _iconCounter.graphics;
            ig.clear();
            var cx:Float = 9.0;
            var cy:Float = 10.0;
            ig.lineStyle(1.4, iconCol, 1.0, true);
            if (active || paused) {
                ig.beginFill(iconCol, paused ? 0.45 : 0.25);
            }
            ig.moveTo(cx - 3.8, cy - 4.2);
            ig.lineTo(cx + 3.8, cy - 4.2);
            ig.lineTo(cx + 3.8, cy + 0.2);
            ig.curveTo(cx + 3.8, cy + 4.2, cx, cy + 5.2);
            ig.curveTo(cx - 3.8, cy + 4.2, cx - 3.8, cy + 0.2);
            ig.lineTo(cx - 3.8, cy - 4.2);
            if (active || paused) {
                ig.endFill();
            }
        }

        if (_txtCounter != null) {
            _txtCounter.text = labelText;
            _txtCounter.textColor = textCol;
        }
    }

    public function toggleAutoAttack():Void {
        var running = (Api.combat != null && Api.combat.isRunning());
        var next = !running;
        if (Api.combat != null) {
            if (next) {
                Api.combat.startSmartStandalone(_selectedClass, _selectedMode);
            } else {
                if (!_isHunting) {
                    Api.combat.stop();
                }
            }
        }
        ApiNotificationManager.notify("Auto: " + (next ? "ON" : "OFF"));
        _lastAtkActive = -1;
    }

    public function toggleAutoHunt():Void {
        var next = !_isHunting;
        if (_isHunting) {
            stopAutoHunt();
        } else {
            startAutoHunt();
        }
        _lastHuntActive = -1;
    }

    public function startAutoHunt():Void {
        _isHunting = true;
        var targetStr = (_targetInput != null && _targetInput.text != "Target (Name/ID)" && _targetInput.text != "Target (Name / ID / MMID)") ? StringTools.trim(_targetInput.text) : "*";
        if (targetStr == "") targetStr = "*";

        if (Api.combat != null && !Api.combat.isRunning()) {
            Api.combat.startSmartStandalone(_selectedClass, _selectedMode);
        }

        ApiNotificationManager.notify("Hunt: " + targetStr);
        _lastHuntActive = -1;
    }

    public function stopAutoHunt():Void {
        _isHunting = false;
        if (_huntTimer != null) {
            _huntTimer.stop();
            _huntTimer = null;
        }
        if (Api.combat != null) {
            Api.combat.stop();
        }
        ApiNotificationManager.notify("Hunt: OFF");
        _lastHuntActive = -1;
    }

    public function toggleCounterHandler():Void {
        var cur = (Api.combat != null ? Api.combat.counterHandler : false);
        var next = !cur;
        if (Api.combat != null) Api.combat.enableCounterHandler(next);
        ApiNotificationManager.notify("Counter: " + (next ? "ON" : "OFF"));
        var isPaused = (Api.combat != null ? Api.combat.isPausedByAura : false);
        renderCounterBtnStyle(next, isPaused, false);
    }

    private function acquireCurrentTarget():Void {
        var ent = (Api.player != null) ? Api.player.target : null;
        if (ent != null && ent.name != null && ent.name != "") {
            _targetInput.text = ent.name;
            _targetInput.textColor = ApiStyle.COLOR_TEXT_PRIMARY;
            ApiConfig.setString("api_widget_hunt_target", ent.name);
            renderGetTargetBtn(false, true);
            haxe.Timer.delay(function():Void {
                renderGetTargetBtn(false, false);
            }, 180);
            ApiNotificationManager.notify("Target: " + ent.name);
        } else {
            ApiNotificationManager.notify("No target selected");
        }
    }

    public function onTick():Void {
        var atkRunning = (Api.combat != null && Api.combat.isRunning() && !_isHunting);
        var atkInt = atkRunning ? 1 : 0;
        if (atkInt != _lastAtkActive) {
            _lastAtkActive = atkInt;
            renderActionBtnStyle(_btnAtk, atkRunning, "Auto", 98.0, 24.0, false);
        }

        var huntRunning = _isHunting;
        var huntInt = huntRunning ? 1 : 0;
        if (huntInt != _lastHuntActive) {
            _lastHuntActive = huntInt;
            renderActionBtnStyle(_btnHunt, huntRunning, "Hunt", 98.0, 24.0, false);
        }

        var isCounter = (Api.combat != null ? Api.combat.counterHandler : false);
        var isPaused = (Api.combat != null ? Api.combat.isPausedByAura : false);
        var counterInt = isCounter ? 1 : 0;
        if (counterInt != _lastCounterActive || isPaused != _lastCounterPaused) {
            _lastCounterActive = counterInt;
            _lastCounterPaused = isPaused;
            renderCounterBtnStyle(isCounter, isPaused, false);
        }
    }
}
#else
class TopBarAutoPanel {
    public function isHunting():Bool return false;
}
#end
