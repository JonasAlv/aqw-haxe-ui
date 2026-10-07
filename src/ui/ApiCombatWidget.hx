package ui;

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
import com.aqwapi.utils.ApiLogger;
import ui.Dropdown;
import ui.Overlay;
import ui.ApiDashboardModal;
import ui.ApiNotificationManager;
import ui.prompts.ApiPrompts;
import util.HelperSetting;

/**
 * Compact in-game Combat & Hunt Widget.
 *
 * Provides instant 1-tap controls for:
 * - Auto Attack (Smart Combat standalone toggle)
 * - Auto Hunt (Targeted hunt function loop)
 * - On-the-fly Class selection dropdown
 * - On-the-fly Combat Mode selection dropdown (Auto, Solo, Farm)
 * - Target Name / ID / MMID input with 1-click monster grabber
 * - Draggable, collapsible header with persistent positions
 */
class ApiCombatWidget {
    private static var _pocket:Dynamic = null;
    private static var _overlay:Overlay = null;
    private static var _widget:Sprite = null;
    private static var _initialized:Bool = false;

    // Component references
    private static var _bg:Sprite = null;
    private static var _headerBar:Sprite = null;
    private static var _bodyContainer:Sprite = null;
    private static var _btnAtk:Sprite = null;
    private static var _txtAtk:TextField = null;
    private static var _btnHunt:Sprite = null;
    private static var _txtHunt:TextField = null;
    private static var _ddClass:Dropdown = null;
    private static var _ddMode:Dropdown = null;
    private static var _targetInput:TextField = null;
    private static var _btnGetTarget:Sprite = null;
    private static var _btnCollapse:Sprite = null;
    private static var _txtCollapse:TextField = null;

    // State
    private static var _isHunting:Bool = false;
    private static var _huntTimer:Timer = null;
    private static var _selectedClass:String = "Current";
    private static var _selectedMode:String = "Auto";
    private static var _isCollapsed:Bool = false;

    private static inline var WIDGET_W:Float = 230;
    private static inline var HEIGHT_EXPANDED:Float = 118;
    private static inline var HEIGHT_COLLAPSED:Float = 56;

    public static function init(pocket:Dynamic, overlay:Overlay):Void {
        if (_initialized) return;
        _initialized = true;
        _pocket = pocket;
        _overlay = overlay;

        var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);

        var attach = function(stageObj:Dynamic):Void {
            if (stageObj == null || _widget != null) return;
            buildWidget(stageObj);
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

    private static function buildWidget(theStage:Dynamic):Void {
        _widget = new Sprite();
        _widget.name = "ApiCombatWidget";

        // Restore saved position
        var savedX = HelperSetting.getInt("api_widget_combat_x", -1);
        var savedY = HelperSetting.getInt("api_widget_combat_y", -1);
        var defaultX:Float = 205;
        var defaultY:Float = 82;

        var initX:Float = (savedX >= 0) ? savedX : defaultX;
        var initY:Float = (savedY >= 0) ? savedY : defaultY;

        var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
        var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
        if (initX > sw - WIDGET_W) initX = sw - WIDGET_W;
        if (initY > sh - HEIGHT_EXPANDED) initY = sh - HEIGHT_EXPANDED;
        if (initX < 0) initX = 0;
        if (initY < 0) initY = 0;

        _widget.x = initX;
        _widget.y = initY;

        _isCollapsed = HelperSetting.getBool("api_widget_combat_collapsed", false);

        // 1. Background plate
        _bg = new Sprite();
        _widget.addChild(_bg);

        // 2. Header Bar (Drag zone)
        _headerBar = new Sprite();
        _headerBar.buttonMode = true;
        _widget.addChild(_headerBar);

        // Header Crimson Accent
        var redAccent = new Shape();
        redAccent.graphics.beginFill(0xC82333, 1.0);
        redAccent.graphics.drawRoundRect(6, 4, 3, 12, 1, 1);
        redAccent.graphics.endFill();
        _headerBar.addChild(redAccent);

        // Header Title
        var titleTxt = new TextField();
        var titleFmt = new TextFormat("_sans", 10, 0xBBBBBB, true);
        titleTxt.defaultTextFormat = titleFmt;
        titleTxt.text = "Combat & Hunt";
        titleTxt.x = 13;
        titleTxt.y = 3;
        titleTxt.width = 150;
        titleTxt.height = 16;
        titleTxt.selectable = false;
        titleTxt.mouseEnabled = false;
        _headerBar.addChild(titleTxt);

        // Header Collapse Button [-] / [+]
        _btnCollapse = new Sprite();
        _btnCollapse.buttonMode = true;
        _btnCollapse.x = WIDGET_W - 22;
        _btnCollapse.y = 2;
        _txtCollapse = new TextField();
        var colFmt = new TextFormat("_sans", 11, 0x888888, true);
        colFmt.align = TextFormatAlign.CENTER;
        _txtCollapse.defaultTextFormat = colFmt;
        _txtCollapse.text = _isCollapsed ? "+" : "_";
        _txtCollapse.width = 18;
        _txtCollapse.height = 18;
        _txtCollapse.selectable = false;
        _txtCollapse.mouseEnabled = false;
        _btnCollapse.addChild(_txtCollapse);
        _headerBar.addChild(_btnCollapse);

        _btnCollapse.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            e.stopPropagation();
            _isCollapsed = !_isCollapsed;
            HelperSetting.setBool("api_widget_combat_collapsed", _isCollapsed);
            _txtCollapse.text = _isCollapsed ? "+" : "_";
            updateLayout();
        });

        // 3. Row 1: Action Buttons (Atk & Hunt)
        var btnW:Float = 104;
        var btnH:Float = 26;

        _btnAtk = createActionButton(btnW, btnH);
        _btnAtk.x = 8;
        _btnAtk.y = 22;
        _widget.addChild(_btnAtk);
        _txtAtk = cast _btnAtk.getChildByName("label");

        _btnHunt = createActionButton(btnW, btnH);
        _btnHunt.x = 118;
        _btnHunt.y = 22;
        _widget.addChild(_btnHunt);
        _txtHunt = cast _btnHunt.getChildByName("label");

        _btnAtk.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            toggleAutoAttack();
        });

        _btnHunt.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            toggleAutoHunt();
        });

        // 4. Body Container (Dropdowns & Target Input)
        _bodyContainer = new Sprite();
        _widget.addChild(_bodyContainer);

        setupDropdownsAndInputs();

        // 5. Drag & Drop Handling
        setupDragging(theStage);

        // 6. Live frame state loop
        _widget.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            var isEnabled = HelperSetting.getBool("api_widget_combat_enabled", true);
            if (!isEnabled) {
                _widget.visible = false;
                return;
            }
            var isPanelOpen:Bool = (_overlay != null && (_overlay.currentFrameLabel == "Panel" || ApiDashboardModal.isOpen()));
            _widget.visible = !isPanelOpen;
            if (_widget.visible) {
                updateButtonVisuals();
            }
        });

        updateLayout();
        updateButtonVisuals();

        theStage.addChild(_widget);
    }

    private static function setupDropdownsAndInputs():Void {
        // Dropdown options
        var availableClasses = ApiPrompts.getAvailableClasses();
        if (availableClasses == null || availableClasses.length == 0) availableClasses = ["Current"];

        _selectedClass = HelperSetting.getString("api_smart_class", "Current");
        if (_selectedClass == "" || availableClasses.indexOf(_selectedClass) == -1) {
            _selectedClass = "Current";
        }

        var getModesForClass = function(cName:String):Array<String> {
            var modes:Array<String> = [];
            if (cName == null || cName == "" || cName.toLowerCase() == "current") {
                modes = ["Auto", "Solo", "Farm"];
            } else {
                try {
                    modes = CombatEngine.getAvailableModes(cName);
                } catch (_:Dynamic) {}
            }
            if (modes == null || modes.length == 0) modes = ["Auto", "Solo", "Farm"];
            return modes;
        };

        var availableModes = getModesForClass(_selectedClass);
        _selectedMode = HelperSetting.getString("api_smart_mode", "Auto");
        if (_selectedMode == "" || availableModes.indexOf(_selectedMode) == -1) {
            _selectedMode = availableModes[0];
        }

        // Dropdown: Class
        _ddClass = new Dropdown(104, 22, availableClasses, function(sel:String):Void {
            _selectedClass = sel;
            HelperSetting.setString("api_smart_class", sel);
            var newModes = getModesForClass(sel);
            _ddMode.setOptions(newModes);
            if (newModes.indexOf(_selectedMode) == -1) {
                _selectedMode = newModes[0];
                _ddMode.setSelectedItem(_selectedMode);
                HelperSetting.setString("api_smart_mode", _selectedMode);
            }
            if (Api.combat != null && Api.combat.isRunning()) {
                Api.combat.startSmartStandalone(_selectedClass, _selectedMode);
            }
            ApiNotificationManager.notify("Combat Class: " + sel);
        });
        _ddClass.x = 8;
        _ddClass.y = 54;
        _ddClass.setSelectedItem(_selectedClass);
        _bodyContainer.addChild(_ddClass);

        // Dropdown: Mode
        _ddMode = new Dropdown(104, 22, availableModes, function(sel:String):Void {
            _selectedMode = sel;
            HelperSetting.setString("api_smart_mode", sel);
            if (Api.combat != null && Api.combat.isRunning()) {
                Api.combat.startSmartStandalone(_selectedClass, _selectedMode);
            }
            ApiNotificationManager.notify("Combat Mode: " + sel);
        });
        _ddMode.x = 118;
        _ddMode.y = 54;
        _ddMode.setSelectedItem(_selectedMode);
        _bodyContainer.addChild(_ddMode);

        // Row 3: Target Input Plate
        var inputPlate = new Sprite();
        inputPlate.graphics.beginFill(0x111111, 0.95);
        inputPlate.graphics.lineStyle(1, 0x333333);
        inputPlate.graphics.drawRoundRect(0, 0, 180, 24, 4, 4);
        inputPlate.graphics.endFill();
        inputPlate.x = 8;
        inputPlate.y = 82;
        _bodyContainer.addChild(inputPlate);

        var savedTarget = HelperSetting.getString("api_widget_hunt_target", "");

        _targetInput = new TextField();
        _targetInput.type = TextFieldType.INPUT;
        var inFmt = new TextFormat("_sans", 11, 0xEEEEEE);
        _targetInput.defaultTextFormat = inFmt;
        _targetInput.x = 12;
        _targetInput.y = 85;
        _targetInput.width = 172;
        _targetInput.height = 18;
        _targetInput.selectable = true;
        _targetInput.text = (savedTarget != "") ? savedTarget : "Target (Name / ID / MMID)";
        _targetInput.textColor = (savedTarget != "") ? 0xFFFFFF : 0x777777;

        _targetInput.addEventListener(FocusEvent.FOCUS_IN, function(e:FocusEvent):Void {
            if (_targetInput.text == "Target (Name / ID / MMID)") {
                _targetInput.text = "";
                _targetInput.textColor = 0xFFFFFF;
            }
        });

        _targetInput.addEventListener(FocusEvent.FOCUS_OUT, function(e:FocusEvent):Void {
            var trimmed = StringTools.trim(_targetInput.text);
            if (trimmed == "") {
                _targetInput.text = "Target (Name / ID / MMID)";
                _targetInput.textColor = 0x777777;
                HelperSetting.setString("api_widget_hunt_target", "");
            } else {
                HelperSetting.setString("api_widget_hunt_target", trimmed);
            }
        });

        _bodyContainer.addChild(_targetInput);

        // Target Grabber Button [Get]
        _btnGetTarget = new Sprite();
        _btnGetTarget.buttonMode = true;
        _btnGetTarget.x = 192;
        _btnGetTarget.y = 82;

        var renderGetBtn = function(hover:Bool):Void {
            _btnGetTarget.graphics.clear();
            _btnGetTarget.graphics.beginFill(hover ? 0x2A2A2A : 0x1A1A1A, 0.95);
            _btnGetTarget.graphics.lineStyle(1, hover ? 0x666666 : 0x3E3E3E);
            _btnGetTarget.graphics.drawRoundRect(0, 0, 30, 24, 4, 4);
            _btnGetTarget.graphics.endFill();
        };
        renderGetBtn(false);

        var txtGet = new TextField();
        var getFmt = new TextFormat("_sans", 10, 0xDDDDDD, true);
        getFmt.align = TextFormatAlign.CENTER;
        txtGet.defaultTextFormat = getFmt;
        txtGet.text = "Get";
        txtGet.width = 30;
        txtGet.height = 18;
        txtGet.y = 3;
        txtGet.selectable = false;
        txtGet.mouseEnabled = false;
        _btnGetTarget.addChild(txtGet);

        _btnGetTarget.addEventListener(MouseEvent.MOUSE_OVER, function(e) renderGetBtn(true));
        _btnGetTarget.addEventListener(MouseEvent.MOUSE_OUT, function(e) renderGetBtn(false));

        _btnGetTarget.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            var ent = (Api.player != null) ? Api.player.target : null;
            if (ent != null && ent.name != null && ent.name != "") {
                _targetInput.text = ent.name;
                _targetInput.textColor = 0xFFFFFF;
                HelperSetting.setString("api_widget_hunt_target", ent.name);
                ApiNotificationManager.notify("Target set: " + ent.name);
                return;
            }
            ApiNotificationManager.notify("No monster targeted to grab!");
        });

        _bodyContainer.addChild(_btnGetTarget);
    }

    private static function createActionButton(w:Float, h:Float):Sprite {
        var sp = new Sprite();
        sp.buttonMode = true;
        sp.mouseChildren = false;

        var dot = new Shape();
        dot.name = "dot";
        sp.addChild(dot);

        var txt = new TextField();
        txt.name = "label";
        var fmt = new TextFormat("_sans", 11, 0xCCCCCC, true);
        fmt.align = TextFormatAlign.LEFT;
        txt.defaultTextFormat = fmt;
        txt.x = 21;
        txt.y = 4;
        txt.width = w - 24;
        txt.height = 18;
        txt.selectable = false;
        txt.mouseEnabled = false;
        sp.addChild(txt);

        return sp;
    }

    private static function updateLayout():Void {
        var h:Float = _isCollapsed ? HEIGHT_COLLAPSED : HEIGHT_EXPANDED;

        _bg.graphics.clear();
        _bg.graphics.beginFill(0x161616, 0.94);
        _bg.graphics.lineStyle(1, 0x2E2E2E);
        _bg.graphics.drawRoundRect(0, 0, WIDGET_W, h, 6, 6);
        _bg.graphics.endFill();

        // Top bevel highlight line
        _bg.graphics.lineStyle(1, 0x383838, 0.55);
        _bg.graphics.moveTo(3, 1);
        _bg.graphics.lineTo(WIDGET_W - 3, 1);

        _bodyContainer.visible = !_isCollapsed;
    }

    private static var _lastAtkActive:Int = -1;
    private static var _lastHuntActive:Int = -1;

    private static function updateButtonVisuals():Void {
        var isAtk = (Api.combat != null && Api.combat.isRunning());
        var isHunt = _isHunting;

        var atkInt = isAtk ? 1 : 0;
        if (atkInt != _lastAtkActive) {
            _lastAtkActive = atkInt;
            renderBtnStyle(_btnAtk, isAtk, "Atk: ON", "Atk: OFF", 104, 26);
        }

        var huntInt = isHunt ? 1 : 0;
        if (huntInt != _lastHuntActive) {
            _lastHuntActive = huntInt;
            renderBtnStyle(_btnHunt, isHunt, "Hunt: ON", "Hunt: OFF", 104, 26);
        }
    }

    private static function renderBtnStyle(btn:Sprite, active:Bool, onText:String, offText:String, w:Float, h:Float):Void {
        btn.graphics.clear();
        var bg = active ? 0x0C1F11 : 0x161616;
        var border = active ? 0x2ECC71 : 0x2E2E2E;
        var textColor = active ? 0x76FF9F : 0xCCCCCC;

        btn.graphics.beginFill(bg, 0.94);
        btn.graphics.lineStyle(1, border);
        btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
        btn.graphics.endFill();

        btn.graphics.lineStyle(1, active ? 0x2ECC71 : 0x383838, 0.55);
        btn.graphics.moveTo(2, 1);
        btn.graphics.lineTo(w - 2, 1);

        var dot:Shape = cast btn.getChildByName("dot");
        if (dot != null) {
            dot.graphics.clear();
            var dotX:Float = 11;
            var dotY:Float = h / 2;
            dot.graphics.lineStyle(0, 0, 0);
            if (active) {
                dot.graphics.beginFill(0x2ECC71, 0.35);
                dot.graphics.drawCircle(dotX, dotY, 4.5);
                dot.graphics.endFill();
                dot.graphics.beginFill(0x00E676, 1.0);
                dot.graphics.drawCircle(dotX, dotY, 2.5);
                dot.graphics.endFill();
            } else {
                dot.graphics.beginFill(0x444444, 0.85);
                dot.graphics.drawCircle(dotX, dotY, 2.5);
                dot.graphics.endFill();
            }
        }

        var lbl:TextField = cast btn.getChildByName("label");
        if (lbl != null) {
            lbl.text = active ? onText : offText;
            lbl.textColor = textColor;
        }
    }

    private static function toggleAutoAttack():Void {
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
        ApiNotificationManager.notify("Auto Attack: " + (next ? "Enabled" : "Disabled"));
        _lastAtkActive = -1;
        updateButtonVisuals();
    }

    private static function toggleAutoHunt():Void {
        if (_isHunting) {
            stopAutoHunt();
        } else {
            startAutoHunt();
        }
        _lastHuntActive = -1;
        updateButtonVisuals();
    }

    private static function getTargetInputText():String {
        if (_targetInput == null) return "*";
        var txt = StringTools.trim(_targetInput.text);
        if (txt == "" || txt == "Target (Name / ID / MMID)") return "*";
        return txt;
    }

    private static function startAutoHunt():Void {
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

            // Numeric MonMapID / Monster ID
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
        ApiNotificationManager.notify("Auto Hunt: " + targetStr);
    }

    private static function stopAutoHunt():Void {
        _isHunting = false;
        if (_huntTimer != null) {
            _huntTimer.stop();
            _huntTimer = null;
        }
        if (Api.combat != null) {
            Api.combat.stop();
        }
        ApiNotificationManager.notify("Auto Hunt stopped.");
    }

    private static function setupDragging(theStage:Dynamic):Void {
        var isDragging:Bool = false;
        var hasDragged:Bool = false;
        var dragStartX:Float = 0;
        var dragStartY:Float = 0;

        _headerBar.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            isDragging = true;
            hasDragged = false;
            dragStartX = e.stageX - _widget.x;
            dragStartY = e.stageY - _widget.y;
        });

        theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (isDragging) {
                var dx = (e.stageX - dragStartX) - _widget.x;
                var dy = (e.stageY - dragStartY) - _widget.y;
                if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
                    hasDragged = true;
                }
                var nx:Float = Math.round(e.stageX - dragStartX);
                var ny:Float = Math.round(e.stageY - dragStartY);
                var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
                var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
                var curH:Float = _isCollapsed ? HEIGHT_COLLAPSED : HEIGHT_EXPANDED;

                if (nx < 0) nx = 0;
                if (ny < 0) ny = 0;
                if (nx > sw - WIDGET_W) nx = sw - WIDGET_W;
                if (ny > sh - curH) ny = sh - curH;

                _widget.x = nx;
                _widget.y = ny;
            }
        });

        theStage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            if (isDragging) {
                if (hasDragged) {
                    HelperSetting.setInt("api_widget_combat_x", Math.round(_widget.x));
                    HelperSetting.setInt("api_widget_combat_y", Math.round(_widget.y));
                }
            }
            isDragging = false;
        });
    }

    public static function isWidgetEnabled():Bool {
        return HelperSetting.getBool("api_widget_combat_enabled", true);
    }

    public static function setWidgetEnabled(enabled:Bool):Void {
        HelperSetting.setBool("api_widget_combat_enabled", enabled);
        if (_widget != null) _widget.visible = enabled;
    }
}
#else
class ApiCombatWidget {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isWidgetEnabled():Bool return false;
    public static function setWidgetEnabled(enabled:Bool):Void {}
}
#end
