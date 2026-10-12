package ui.widgets;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.FocusEvent;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.utils.Timer;
import flash.events.TimerEvent;
import com.aqwapi.Api;
import com.aqwapi.modules.CombatEngine;
import com.aqwapi.utils.ApiConfig;
import com.aqwapi.utils.ApiLogger;
import ui.Dropdown;
import ui.ApiDashboardModal;
import ui.ApiMenus;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.components.ClassModeSelector;
import ui.widgets.BaseWidget;
import ui.widgets.WidgetConfigModal;

/**
 * Compact in-game Combat & Hunt Widget.
 *
 * Standalone default widget providing instant 1-tap controls for:
 * - Auto Attack (Smart Combat standalone toggle)
 * - Auto Hunt (Targeted hunt function loop)
 * - Counter Handler toggle (Tactical shield, stops on enemy reflect auras)
 * - On-the-fly Class selection dropdown
 * - On-the-fly Combat Mode selection dropdown (Auto, Solo, Farm)
 * - Target Name / ID / MMID input with 1-click monster grabber
 * - Draggable, collapsible header with persistent positions
 */
class CombatWidget extends BaseWidget {
    public static var instance:CombatWidget = null;

    // Component references
    private var _btnCounter:Sprite = null;
    private var _txtCounter:TextField = null;
    private var _iconCounter:Shape = null;
    private var _btnAtk:Sprite = null;
    private var _txtAtk:TextField = null;
    private var _btnHunt:Sprite = null;
    private var _txtHunt:TextField = null;
    private var _ddClass:Dropdown = null;
    private var _ddMode:Dropdown = null;
    private var _classSelector:ClassModeSelector = null;
    private var _inputPlate:Sprite = null;
    private var _targetInput:TextField = null;
    private var _btnGetTarget:Sprite = null;

    // State
    private var _isHunting:Bool = false;
    private var _huntTimer:Timer = null;
    private var _selectedClass:String = "Current";
    private var _selectedMode:String = "Auto";
    private var _lastEquippedClass:String = "";
    private var _hasRescannedBagOnEntry:Bool = false;
    private var _curAtkW:Float = 148;
    private var _curHuntW:Float = 148;

    private var _lastAtkActive:Int = -1;
    private var _lastHuntActive:Int = -1;
    private var _lastCounterActive:Int = -1;
    private var _lastCounterPaused:Bool = false;

    public static inline var WIDGET_W:Float = ApiStyle.WIDGET_WIDTH_STANDARD;
    public static inline var HEIGHT_EXPANDED:Float = 118;

    public function new() {
        super("combat", "Combat", 180, 82, WIDGET_W, HEIGHT_EXPANDED, true, false, true);
        instance = this;
    }

    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {
        if (instance == null) {
            instance = new CombatWidget();
        }
        var theStage:Dynamic = (pocket != null && pocket.stage != null) ? pocket.stage : (overlay != null ? overlay.stage : null);
        if (theStage != null && instance.theStage == null) {
            instance.attach(theStage, overlay);
        }
    }

    public static function getFixedOptions():Array<String> {
        var str = ApiConfig.getString("api_widget_combat_fixed", "");
        if (str == "") return [];
        return str.split(",");
    }

    public static function isOptionFixed(optId:String):Bool {
        return getFixedOptions().indexOf(optId) >= 0;
    }

    override public function computeCollapsedWidth():Float {
        var fixedOpts = getFixedOptions();
        if (fixedOpts.length == 0) return BaseWidget.COMPACT_W;
        if (fixedOpts.length == 1 && fixedOpts[0] == "counter") return BaseWidget.COMPACT_W;
        return defaultWidth;
    }

    override public function computeCollapsedHeight():Float {
        var fixedOpts = getFixedOptions();
        if (fixedOpts.length == 0) return BaseWidget.COMPACT_H;
        if (fixedOpts.length == 1 && fixedOpts[0] == "counter") return BaseWidget.COMPACT_H;

        var curY:Float = 6;
        if (isOptionFixed("counter")) curY += 26;
        if (isOptionFixed("atk") || isOptionFixed("hunt")) curY += 32;
        if (isOptionFixed("class")) curY += 28;
        if (isOptionFixed("target")) curY += 28;
        return (curY > 6) ? (curY + 4) : BaseWidget.COMPACT_H;
    }

    override public function buildContent(container:Sprite):Void {
        // 1. Counter button on header
        _btnCounter = new Sprite();
        _btnCounter.buttonMode = true;
        _btnCounter.useHandCursor = true;
        _btnCounter.x = defaultWidth - 48 - 6 - 70;
        _btnCounter.y = 3;

        _iconCounter = new Shape();
        _btnCounter.addChild(_iconCounter);

        _txtCounter = new TextField();
        var ctrFmt = new TextFormat(ApiStyle.FONT_FAMILY, 9, ApiStyle.COLOR_TEXT_MUTED, true);
        ctrFmt.align = TextFormatAlign.LEFT;
        _txtCounter.defaultTextFormat = ctrFmt;
        _txtCounter.x = 18;
        _txtCounter.y = 1;
        _txtCounter.width = 50;
        _txtCounter.height = 16;
        _txtCounter.selectable = false;
        _txtCounter.mouseEnabled = false;
        _btnCounter.addChild(_txtCounter);

        renderCounterBtnStyle(CombatEngine.counterHandler, CombatEngine.isPausedByAura, false);

        _btnCounter.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            renderCounterBtnStyle(CombatEngine.counterHandler, CombatEngine.isPausedByAura, true);
        });
        _btnCounter.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            renderCounterBtnStyle(CombatEngine.counterHandler, CombatEngine.isPausedByAura, false);
        });
        _btnCounter.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            e.stopPropagation();
        });
        _btnCounter.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            e.stopPropagation();
        });
        _btnCounter.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            e.stopPropagation();
            toggleCounterHandler();
        });
        addChild(_btnCounter);

        // 2. Action buttons (Atk & Hunt)
        var btnW:Float = 148;
        var btnH:Float = 28;

        _btnAtk = createActionButton(btnW, btnH);
        _btnAtk.x = 8;
        _btnAtk.y = 25;
        addChild(_btnAtk);
        _txtAtk = cast _btnAtk.getChildByName("label");

        _btnHunt = createActionButton(btnW, btnH);
        _btnHunt.x = 164;
        _btnHunt.y = 25;
        addChild(_btnHunt);
        _txtHunt = cast _btnHunt.getChildByName("label");

        _btnAtk.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            toggleAutoAttack();
        });

        _btnHunt.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            toggleAutoHunt();
        });

        // 3. Dropdowns & Target inputs in bodyContainer
        setupDropdownsAndInputs();
    }

    private function setupDropdownsAndInputs():Void {
        // Row 2: Linked Class & Combat Mode Selector
        _classSelector = new ClassModeSelector(148, 148, 24, 8, false, "Auto", function(selClass:String, selMode:String):Void {
            _selectedClass = selClass;
            _selectedMode = selMode;
            if (Api.combat != null && Api.combat.isRunning()) {
                Api.combat.startSmartStandalone(_selectedClass, _selectedMode);
            } else if (selClass != "Current" && Api.inventory != null) {
                try {
                    var curClass = CombatEngine.getCurrentClassName();
                    if (curClass == "" || curClass.toLowerCase() != selClass.toLowerCase()) {
                        Api.inventory.equip(selClass);
                    }
                } catch (_:Dynamic) {}
            }
            ApiNotificationManager.notify("Combat: " + selClass + " [" + selMode + "]");
        });
        _classSelector.x = 8;
        _classSelector.y = 56;
        _classSelector.bindConfig("api_smart_class", "api_smart_mode", "Current", "Auto");
        _ddClass = _classSelector.classDropdown;
        _ddMode = _classSelector.modeDropdown;
        _selectedClass = _classSelector.selectedClass;
        _selectedMode = _classSelector.selectedMode;
        bodyContainer.addChild(_classSelector);

        // Row 3: Target Input Plate
        _inputPlate = new Sprite();
        _inputPlate.graphics.beginFill(ApiStyle.COLOR_BG_INPUT, 0.95);
        _inputPlate.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT);
        _inputPlate.graphics.drawRoundRect(0, 0, 268, 24, 4, 4);
        _inputPlate.graphics.endFill();
        _inputPlate.x = 8;
        _inputPlate.y = 84;
        bodyContainer.addChild(_inputPlate);

        var savedTarget = ApiConfig.getString("api_widget_hunt_target", "");

        _targetInput = new TextField();
        _targetInput.type = TextFieldType.INPUT;
        var inFmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_PRIMARY);
        _targetInput.defaultTextFormat = inFmt;
        _targetInput.x = 12;
        _targetInput.y = 87;
        _targetInput.width = 260;
        _targetInput.height = 18;
        _targetInput.selectable = true;
        _targetInput.text = (savedTarget != "") ? savedTarget : "Target (Name / ID / MMID)";
        _targetInput.textColor = (savedTarget != "") ? ApiStyle.COLOR_TEXT_PRIMARY : ApiStyle.COLOR_TEXT_MUTED;

        _targetInput.addEventListener(FocusEvent.FOCUS_IN, function(e:FocusEvent):Void {
            if (_targetInput.text == "Target (Name / ID / MMID)") {
                _targetInput.text = "";
                _targetInput.textColor = ApiStyle.COLOR_TEXT_PRIMARY;
            }
        });

        _targetInput.addEventListener(FocusEvent.FOCUS_OUT, function(e:FocusEvent):Void {
            var trimmed = StringTools.trim(_targetInput.text);
            if (trimmed == "") {
                _targetInput.text = "Target (Name / ID / MMID)";
                _targetInput.textColor = ApiStyle.COLOR_TEXT_MUTED;
                ApiConfig.setString("api_widget_hunt_target", "");
            } else {
                ApiConfig.setString("api_widget_hunt_target", trimmed);
            }
        });

        bodyContainer.addChild(_targetInput);

        // Target Grabber Button (Tactical Reticle)
        _btnGetTarget = new Sprite();
        _btnGetTarget.buttonMode = true;
        _btnGetTarget.x = 282;
        _btnGetTarget.y = 84;

        renderGetTargetBtn(false, false);

        _btnGetTarget.addEventListener(MouseEvent.MOUSE_OVER, function(e) renderGetTargetBtn(true, false));
        _btnGetTarget.addEventListener(MouseEvent.MOUSE_OUT, function(e) renderGetTargetBtn(false, false));

        _btnGetTarget.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            var ent = (Api.player != null) ? Api.player.target : null;
            if (ent != null && ent.name != null && ent.name != "") {
                _targetInput.text = ent.name;
                _targetInput.textColor = ApiStyle.COLOR_TEXT_PRIMARY;
                ApiConfig.setString("api_widget_hunt_target", ent.name);
                renderGetTargetBtn(false, true);
                haxe.Timer.delay(function():Void {
                    renderGetTargetBtn(false, false);
                }, 180);
                ApiNotificationManager.notify("Target set: " + ent.name);
                return;
            }
            ApiNotificationManager.notify("No monster targeted to grab!");
        });

        bodyContainer.addChild(_btnGetTarget);
    }

    private function createActionButton(w:Float, h:Float):Sprite {
        var sp = new Sprite();
        sp.buttonMode = true;
        sp.mouseChildren = false;
        sp.scaleX = 1.0;
        sp.scaleY = 1.0;

        sp.graphics.beginFill(ApiStyle.COLOR_BG_CARD, 0.94);
        sp.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT);
        sp.graphics.drawRoundRect(0, 0, w, h, 4, 4);
        sp.graphics.endFill();

        var dot = new Shape();
        dot.name = "dot";
        sp.addChild(dot);

        var txt = new TextField();
        txt.name = "label";
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_PRIMARY, true);
        fmt.align = TextFormatAlign.LEFT;
        txt.defaultTextFormat = fmt;
        txt.x = 21;
        txt.y = Math.round((h - 18) / 2);
        txt.width = w - 24;
        txt.height = 18;
        txt.selectable = false;
        txt.mouseEnabled = false;
        sp.addChild(txt);

        return sp;
    }

    override public function updateLayout():Void {
        var fixedOpts = getFixedOptions();
        var isCompact:Bool = isCollapsed && (fixedOpts.length == 0);

        if (isCompact) {
            var w:Float = BaseWidget.COMPACT_W;
            var h:Float = BaseWidget.COMPACT_H;

            bg.graphics.clear();
            bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.88);
            bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.85);
            bg.graphics.drawRoundRect(0, 0, w, h, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
            bg.graphics.endFill();

            bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
            bg.graphics.moveTo(3, 1);
            bg.graphics.lineTo(w - 3, 1);

            accentShape.visible = true;
            accentShape.graphics.clear();
            accentShape.graphics.beginFill(ApiStyle.COLOR_ACCENT_PRIMARY, 1.0);
            accentShape.graphics.drawRoundRect(5, 5, 3.5, 16, 1.5, 1.5);
            accentShape.graphics.endFill();

            titleTxt.visible = true;
            titleTxt.text = "Combat";
            titleTxt.x = 13;
            titleTxt.y = 4;
            titleTxt.width = BaseWidget.COMPACT_W - 16;

            headerBar.graphics.clear();
            headerBar.graphics.beginFill(0x000000, 0.0);
            headerBar.graphics.drawRect(0, 0, w, h);
            headerBar.graphics.endFill();

            btnCollapse.visible = false;
            if (btnConfig != null) btnConfig.visible = false;
            _btnCounter.visible = false;
            _btnAtk.visible = false;
            _btnHunt.visible = false;
            _classSelector.visible = false;
            _inputPlate.visible = false;
            _targetInput.visible = false;
            _btnGetTarget.visible = false;
            bodyContainer.visible = false;
        } else if (isCollapsed) {
            titleTxt.visible = false;
            accentShape.visible = false;
            btnCollapse.visible = false;
            if (btnConfig != null) btnConfig.visible = false;

            if (fixedOpts.length == 1 && fixedOpts[0] == "counter") {
                var w:Float = BaseWidget.COMPACT_W;
                var h:Float = BaseWidget.COMPACT_H;

                _btnCounter.visible = true;
                _btnCounter.x = 4;
                _btnCounter.y = 3;

                _btnAtk.visible = false;
                _btnHunt.visible = false;
                _classSelector.visible = false;
                _inputPlate.visible = false;
                _targetInput.visible = false;
                _btnGetTarget.visible = false;
                bodyContainer.visible = false;

                bg.graphics.clear();
                bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.88);
                bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.85);
                bg.graphics.drawRoundRect(0, 0, w, h, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
                bg.graphics.endFill();

                bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
                bg.graphics.moveTo(3, 1);
                bg.graphics.lineTo(w - 3, 1);

                headerBar.graphics.clear();
                headerBar.graphics.beginFill(0x000000, 0.0);
                headerBar.graphics.drawRect(0, 0, w, h);
                headerBar.graphics.endFill();
            } else {
                var curY:Float = 6;
                var hasCounter = isOptionFixed("counter");
                if (hasCounter) {
                    _btnCounter.visible = true;
                    _btnCounter.x = 8;
                    _btnCounter.y = curY;
                    curY += 26;
                } else {
                    _btnCounter.visible = false;
                }

                var hasAtk = isOptionFixed("atk");
                var hasHunt = isOptionFixed("hunt");

                if (hasAtk && hasHunt) {
                    _btnAtk.visible = true;
                    _btnAtk.x = 8;
                    _btnAtk.y = curY;
                    _curAtkW = 148;
                    _btnHunt.visible = true;
                    _btnHunt.x = 164;
                    _btnHunt.y = curY;
                    _curHuntW = 148;
                    curY += 32;
                } else if (hasAtk) {
                    _btnAtk.visible = true;
                    _btnAtk.x = 8;
                    _btnAtk.y = curY;
                    _curAtkW = 304;
                    _btnHunt.visible = false;
                    curY += 32;
                } else if (hasHunt) {
                    _btnHunt.visible = true;
                    _btnHunt.x = 8;
                    _btnHunt.y = curY;
                    _curHuntW = 304;
                    _btnAtk.visible = false;
                    curY += 32;
                } else {
                    _btnAtk.visible = false;
                    _btnHunt.visible = false;
                }

                var hasClass = isOptionFixed("class");
                if (hasClass) {
                    _classSelector.visible = true;
                    _classSelector.y = curY;
                    curY += 28;
                } else {
                    _classSelector.visible = false;
                }

                var hasTarget = isOptionFixed("target");
                if (hasTarget) {
                    _inputPlate.visible = true;
                    _inputPlate.y = curY;
                    _targetInput.visible = true;
                    _targetInput.y = curY + 3;
                    _btnGetTarget.visible = true;
                    _btnGetTarget.y = curY;
                    curY += 28;
                } else {
                    _inputPlate.visible = false;
                    _targetInput.visible = false;
                    _btnGetTarget.visible = false;
                }

                var totalH:Float = (curY > 6) ? (curY + 4) : BaseWidget.COMPACT_H;
                bodyContainer.visible = (curY > 6);

                bg.graphics.clear();
                bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.88);
                bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.85);
                bg.graphics.drawRoundRect(0, 0, WIDGET_W, totalH, 6, 6);
                bg.graphics.endFill();

                bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
                bg.graphics.moveTo(3, 1);
                bg.graphics.lineTo(WIDGET_W - 3, 1);

                headerBar.graphics.clear();
                headerBar.graphics.beginFill(0x000000, 0.0);
                headerBar.graphics.drawRect(0, 0, WIDGET_W, totalH);
                headerBar.graphics.endFill();
            }
        } else {
            // FULLY EXPANDED
            titleTxt.visible = true;
            titleTxt.text = "Combat";
            titleTxt.x = 13;
            titleTxt.y = 3;
            titleTxt.width = 120;

            accentShape.visible = true;
            accentShape.graphics.clear();
            accentShape.graphics.beginFill(ApiStyle.COLOR_ACCENT_PRIMARY, 1.0);
            accentShape.graphics.drawRoundRect(6, 4, 3, 14, 1, 1);
            accentShape.graphics.endFill();

            btnCollapse.visible = false;

            if (btnConfig != null) {
                btnConfig.visible = true;
                btnConfig.x = WIDGET_W - 25;
                btnConfig.y = 3;
                renderConfigIcon(false);
            }

            _btnCounter.visible = true;
            _btnCounter.x = WIDGET_W - 25 - 6 - 70;
            _btnCounter.y = 3;

            _btnAtk.visible = true;
            _btnAtk.x = 8;
            _btnAtk.y = 28;
            _curAtkW = 148;

            _btnHunt.visible = true;
            _btnHunt.x = 164;
            _btnHunt.y = 28;
            _curHuntW = 148;

            _classSelector.visible = true;
            _classSelector.y = 60;

            _inputPlate.visible = true;
            _inputPlate.y = 88;
            _targetInput.visible = true;
            _targetInput.y = 91;
            _btnGetTarget.visible = true;
            _btnGetTarget.y = 88;

            bodyContainer.visible = true;

            bg.graphics.clear();
            bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.94);
            bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 1.0);
            bg.graphics.drawRoundRect(0, 0, WIDGET_W, HEIGHT_EXPANDED, 6, 6);
            bg.graphics.endFill();

            bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.55);
            bg.graphics.moveTo(3, 1);
            bg.graphics.lineTo(WIDGET_W - 3, 1);

            headerBar.graphics.clear();
            headerBar.graphics.beginFill(0x000000, 0.0);
            headerBar.graphics.drawRect(0, 0, WIDGET_W, 24);
            headerBar.graphics.endFill();
        }

        if (_btnAtk.visible) {
            renderBtnStyle(_btnAtk, (Api.combat != null && Api.combat.isRunning()), "Attack", _curAtkW, 28);
        }
        if (_btnHunt.visible) {
            renderBtnStyle(_btnHunt, _isHunting, "Hunt", _curHuntW, 28);
        }
        _lastAtkActive = (Api.combat != null && Api.combat.isRunning()) ? 1 : 0;
        _lastHuntActive = _isHunting ? 1 : 0;
    }

    override public function onTick():Void {
        if (!_hasRescannedBagOnEntry) {
            _hasRescannedBagOnEntry = true;
            refreshClassOptions();
        }
        updateButtonVisuals();
        if (_selectedClass == "Current") {
            var curClass = "";
            try { curClass = CombatEngine.getCurrentClassName(); } catch (_:Dynamic) {}
            if (curClass != "" && curClass != _lastEquippedClass) {
                _lastEquippedClass = curClass;
                refreshModeOptions();
            }
        }
    }

    private function updateButtonVisuals():Void {
        var isAtk = (Api.combat != null && Api.combat.isRunning());
        var isHunt = _isHunting;

        var atkInt = isAtk ? 1 : 0;
        if (atkInt != _lastAtkActive) {
            _lastAtkActive = atkInt;
            renderBtnStyle(_btnAtk, isAtk, "Attack", _curAtkW, 28);
        }

        var huntInt = isHunt ? 1 : 0;
        if (huntInt != _lastHuntActive) {
            _lastHuntActive = huntInt;
            renderBtnStyle(_btnHunt, isHunt, "Hunt", _curHuntW, 28);
        }

        var isCounter = CombatEngine.counterHandler;
        var isPaused = CombatEngine.isPausedByAura;
        var counterInt = isCounter ? 1 : 0;
        if (counterInt != _lastCounterActive || isPaused != _lastCounterPaused) {
            _lastCounterActive = counterInt;
            _lastCounterPaused = isPaused;
            renderCounterBtnStyle(isCounter, isPaused, false);
        }
    }

    private function renderCounterBtnStyle(active:Bool, paused:Bool, hover:Bool = false):Void {
        if (_btnCounter == null) return;
        var g = _btnCounter.graphics;
        g.clear();

        g.beginFill(0x000000, 0.0);
        g.drawRect(-3, -3, 76, 24);
        g.endFill();

        var bgCol:Int = ApiStyle.COLOR_BG_CARD;
        var border:Int = ApiStyle.COLOR_BORDER_DEFAULT;
        var textCol:Int = ApiStyle.COLOR_TEXT_MUTED;
        var iconCol:Int = ApiStyle.COLOR_TEXT_MUTED;
        var bgAlpha:Float = 0.88;
        var labelText:String = "Counter";

        if (paused) {
            bgCol = ApiStyle.COLOR_STATUS_WARN;
            bgAlpha = 0.25;
            border = ApiStyle.COLOR_STATUS_WARN;
            textCol = ApiStyle.COLOR_STATUS_WARN;
            iconCol = ApiStyle.COLOR_STATUS_WARN;
            labelText = "HOLDING";
        } else if (active) {
            bgCol = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE;
            bgAlpha = 0.95;
            border = hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_STATUS_ACTIVE;
            textCol = ApiStyle.COLOR_STATUS_ACTIVE;
            iconCol = ApiStyle.COLOR_STATUS_ACTIVE;
            labelText = "Counter";
        } else {
            bgCol = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_CARD;
            border = hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT;
            textCol = hover ? ApiStyle.COLOR_TEXT_PRIMARY : ApiStyle.COLOR_TEXT_MUTED;
            iconCol = hover ? ApiStyle.COLOR_TEXT_PRIMARY : ApiStyle.COLOR_TEXT_MUTED;
            labelText = "Counter";
        }

        g.beginFill(bgCol, bgAlpha);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 70, 18, 4, 4);
        g.endFill();

        if (_iconCounter != null) {
            var ig = _iconCounter.graphics;
            ig.clear();
            var cx:Float = 8.5;
            var cy:Float = 9.0;
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

    private function renderGetTargetBtn(hover:Bool = false, active:Bool = false):Void {
        if (_btnGetTarget == null) return;
        var g = _btnGetTarget.graphics;
        g.clear();

        g.beginFill(0x000000, 0.0);
        g.drawRect(-4, -4, 38, 32);
        g.endFill();

        var bgCol = active ? ApiStyle.COLOR_BG_SURFACE : (hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE);
        var border = active ? ApiStyle.COLOR_STATUS_ACTIVE : (hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT);
        var iconColor = active ? ApiStyle.COLOR_STATUS_ACTIVE : (hover ? ApiStyle.COLOR_TEXT_TITLE : ApiStyle.COLOR_TEXT_MUTED);

        g.beginFill(bgCol, 0.95);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 30, 24, 4, 4);
        g.endFill();

        var cx = 15.0;
        var cy = 12.0;
        g.lineStyle(1.8, iconColor, 1.0, true);
        g.drawCircle(cx, cy, 5.0);
        g.moveTo(cx - 7.5, cy); g.lineTo(cx - 3.5, cy);
        g.moveTo(cx + 3.5, cy); g.lineTo(cx + 7.5, cy);
        g.moveTo(cx, cy - 7.5); g.lineTo(cx, cy - 3.5);
        g.moveTo(cx, cy + 3.5); g.lineTo(cx, cy + 7.5);
        g.lineStyle(0, 0, 0);
        g.beginFill(iconColor, 1.0);
        g.drawCircle(cx, cy, 1.5);
        g.endFill();
    }

    private function flashActionButton(btn:Sprite, active:Bool, label:String, w:Float, h:Float):Void {
        if (btn == null) return;
        btn.scaleX = 1.0;
        btn.scaleY = 1.0;
        btn.graphics.clear();
        btn.graphics.beginFill(active ? ApiStyle.COLOR_BG_SURFACE : ApiStyle.COLOR_BTN_BG_HOVER, 0.98);
        btn.graphics.lineStyle(1.8, active ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_BORDER_HIGHLIGHT);
        btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
        btn.graphics.endFill();
        haxe.Timer.delay(function():Void {
            renderBtnStyle(btn, active, label, w, h);
        }, 120);
    }

    private function renderBtnStyle(btn:Sprite, active:Bool, label:String, w:Float, h:Float):Void {
        if (btn == null) return;
        btn.scaleX = 1.0;
        btn.scaleY = 1.0;
        btn.graphics.clear();
        var bgCol = active ? ApiStyle.COLOR_BG_SURFACE : ApiStyle.COLOR_BG_CARD;
        var border = active ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_BORDER_DEFAULT;
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
            var dotX:Float = 11;
            var dotY:Float = h / 2;
            dot.graphics.lineStyle(0, 0, 0);
            if (active) {
                dot.graphics.beginFill(ApiStyle.COLOR_STATUS_ACTIVE, 0.35);
                dot.graphics.drawCircle(dotX, dotY, 4.5);
                dot.graphics.endFill();
                dot.graphics.beginFill(ApiStyle.COLOR_STATUS_ACTIVE, 1.0);
                dot.graphics.drawCircle(dotX, dotY, 2.5);
                dot.graphics.endFill();
            } else {
                dot.graphics.beginFill(ApiStyle.COLOR_STATUS_INACTIVE, 0.85);
                dot.graphics.drawCircle(dotX, dotY, 2.5);
                dot.graphics.endFill();
            }
        }

        var lbl:TextField = cast btn.getChildByName("label");
        if (lbl != null) {
            lbl.text = label;
            lbl.textColor = textColor;
            lbl.width = w - 24;
        }
    }

    public function toggleAutoAttack():Void {
        var running = (Api.combat != null && Api.combat.isRunning());
        var next = !running;
        flashActionButton(_btnAtk, next, "Attack", _curAtkW, 28);
        if (Api.combat != null) {
            if (next) {
                Api.combat.startSmartStandalone(_selectedClass, _selectedMode);
            } else {
                if (!_isHunting) {
                    Api.combat.stop();
                }
            }
        }
        ApiNotificationManager.notify("Attack: " + (next ? "Enabled" : "Disabled"));
        _lastAtkActive = -1;
    }

    public function toggleAutoHunt():Void {
        var next = !_isHunting;
        flashActionButton(_btnHunt, next, "Hunt", _curHuntW, 28);
        if (_isHunting) {
            stopAutoHunt();
        } else {
            startAutoHunt();
        }
        _lastHuntActive = -1;
    }

    public function toggleCounterHandler():Void {
        var next = !CombatEngine.counterHandler;
        if (Api.combat != null) Api.combat.enableCounterHandler(next);
        else CombatEngine.counterHandler = next;
        ApiConfig.setBool("api_counter_handler", next);
        ApiNotificationManager.notify("Counter Handler: " + (next ? "Enabled (Pauses on Reflect)" : "Disabled"));
        renderCounterBtnStyle(next, CombatEngine.isPausedByAura, false);
    }

    public function startAutoHunt():Void {
        _isHunting = true;
        var targetStr = getTargetInputText();

        if (Api.combat != null && !Api.combat.isRunning()) {
            Api.combat.startSmartStandalone(_selectedClass, _selectedMode);
        }

        if (_huntTimer != null) {
            _huntTimer.stop();
            _huntTimer = null;
        }

        _huntTimer = new Timer(250);
        _huntTimer.addEventListener(TimerEvent.TIMER, function(e:TimerEvent):Void {
            if (!_isHunting) {
                stopAutoHunt();
                return;
            }
            if (Api.player != null && !Api.player.isAlive) return;
            if (Api.map != null && !Api.map.isLoaded) return;

            var raw = getTargetInputText();
            var num = Std.parseInt(raw);
            if (num != null && num > 0 && !StringTools.contains(raw, " ")) {
                Api.combat.hunt("*", null, 1, num);
            } else if (StringTools.contains(raw, ",")) {
                var list = raw.split(",").map(function(s) return StringTools.trim(s));
                Api.combat.hunt(list);
            } else {
                Api.combat.hunt(raw);
            }
        });
        _huntTimer.start();
        ApiNotificationManager.notify("Hunt: " + targetStr);
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
        ApiNotificationManager.notify("Hunt stopped.");
    }

    public function getTargetInputText():String {
        if (_targetInput == null) return "*";
        var txt = StringTools.trim(_targetInput.text);
        if (txt == "" || txt == "Target (Name / ID / MMID)") return "*";
        return txt;
    }

    public function setTargetInputText(str:String):Void {
        if (_targetInput != null) {
            _targetInput.text = str;
            _targetInput.textColor = ApiStyle.COLOR_TEXT_PRIMARY;
            ApiConfig.setString("api_widget_hunt_target", str);
        }
    }

    public function refreshClassOptions():Void {
        if (_classSelector != null) {
            _classSelector.refreshClasses();
            _selectedClass = _classSelector.selectedClass;
        }
    }

    public function refreshModeOptions():Void {
        if (_classSelector != null) {
            _classSelector.refreshModes();
            _selectedMode = _classSelector.selectedMode;
        }
    }

    override public function openConfig():Void {
        if (overlay == null) return;
        var fixedOpts = getFixedOptions();
        var isFixed = function(id:String) return fixedOpts.indexOf(id) >= 0;

        var options:Array<WidgetConfigModal.WidgetOptionItem> = [
            { id: "atk", label: "Attack", desc: "Show Attack button when collapsed", isFixed: isFixed("atk") },
            { id: "hunt", label: "Hunt", desc: "Show Hunt button when collapsed", isFixed: isFixed("hunt") },
            { id: "counter", label: "Counter", desc: "Show Counter toggle when collapsed", isFixed: isFixed("counter") },
            { id: "class", label: "Class & Mode", desc: "Show Class & Mode dropdowns when collapsed", isFixed: isFixed("class") },
            { id: "target", label: "Target", desc: "Show Target input & grabber when collapsed", isFixed: isFixed("target") }
        ];

        WidgetConfigModal.show(overlay, "Combat Widget", options, function(savedIds:Array<String>):Void {
            ApiConfig.setString("api_widget_combat_fixed", savedIds.join(","));
            clampToScreen();
            updateLayout();
        });
    }

    // --- Static Facades for Backwards Compatibility ---

    public static function isWidgetEnabled():Bool {
        if (instance != null) return instance.isEnabled;
        return ApiConfig.getBool("api_widget_combat_enabled", true);
    }

    public static function setWidgetEnabled(enabled:Bool):Void {
        if (instance != null) instance.setEnabled(enabled);
        else ApiConfig.setBool("api_widget_combat_enabled", enabled);
    }

    public static function resetPosition():Void {
        if (instance != null) instance.resetToDefaultPosition();
        else {
            ApiConfig.setInt("api_widget_combat_x", 180);
            ApiConfig.setInt("api_widget_combat_y", 82);
        }
    }

    public static function openConfigModal():Void {
        if (instance != null) instance.openConfig();
    }
}
#else
class CombatWidget {
    public static var instance:CombatWidget = null;
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isWidgetEnabled():Bool return false;
    public static function setWidgetEnabled(enabled:Bool):Void {}
    public static function resetPosition():Void {}
    public static function openConfigModal():Void {}
}
#end
