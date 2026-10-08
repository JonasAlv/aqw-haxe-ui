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
import ui.Overlay;
import ui.ApiDashboardModal;
import ui.ApiMenus;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.prompts.ApiPrompts;
import ui.prompts.ApiPromptModal;
import ui.components.ClassModeSelector;
import util.HelperSetting;

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
class CombatWidget {
    private static var _pocket:Dynamic = null;
    private static var _overlay:Overlay = null;
    private static var _widget:Sprite = null;
    private static var _initialized:Bool = false;

    // Component references
    private static var _bg:Sprite = null;
    private static var _headerBar:Sprite = null;
    private static var _accentShape:Shape = null;
    private static var _titleTxt:TextField = null;
    private static var _btnConfig:Sprite = null;
    private static var _btnCollapse:Sprite = null;
    private static var _btnCounter:Sprite = null;
    private static var _txtCounter:TextField = null;
    private static var _iconCounter:Shape = null;
    private static var _btnAtk:Sprite = null;
    private static var _txtAtk:TextField = null;
    private static var _btnHunt:Sprite = null;
    private static var _txtHunt:TextField = null;
    private static var _bodyContainer:Sprite = null;
    private static var _ddClass:Dropdown = null;
    private static var _ddMode:Dropdown = null;
    private static var _classSelector:ClassModeSelector = null;
    private static var _inputPlate:Sprite = null;
    private static var _targetInput:TextField = null;
    private static var _btnGetTarget:Sprite = null;

    // State
    private static var _isHunting:Bool = false;
    private static var _huntTimer:Timer = null;
    private static var _selectedClass:String = "Current";
    private static var _selectedMode:String = "Auto";
    private static var _isCollapsed:Bool = false;
    private static var _lastEquippedClass:String = "";
    private static var _hasRescannedBagOnEntry:Bool = false;
    private static var _curAtkW:Float = 148;
    private static var _curHuntW:Float = 148;

    private static inline var WIDGET_W:Float = 320;
    private static inline var COMPACT_W:Float = 78;
    private static inline var COMPACT_H:Float = 26;
    private static inline var HEIGHT_EXPANDED:Float = 118;

    public static function getFixedOptions():Array<String> {
        var str = HelperSetting.getString("api_widget_combat_fixed", "");
        if (str == "") return [];
        return str.split(",");
    }

    public static function isOptionFixed(optId:String):Bool {
        return getFixedOptions().indexOf(optId) >= 0;
    }

    private static function computeCollapsedWidth():Float {
        var fixedOpts = getFixedOptions();
        if (fixedOpts.length == 0) return COMPACT_W;
        if (fixedOpts.length == 1 && fixedOpts[0] == "counter") return COMPACT_W;
        return WIDGET_W;
    }

    private static function computeCollapsedHeight():Float {
        var fixedOpts = getFixedOptions();
        if (fixedOpts.length == 0) return COMPACT_H;
        if (fixedOpts.length == 1 && fixedOpts[0] == "counter") return COMPACT_H;

        var curY:Float = 6;
        if (isOptionFixed("counter")) curY += 26;
        if (isOptionFixed("atk") || isOptionFixed("hunt")) curY += 32;
        if (isOptionFixed("class")) curY += 28;
        if (isOptionFixed("target")) curY += 28;
        return (curY > 6) ? (curY + 4) : COMPACT_H;
    }

    private static function renderCollapseIcon(collapsed:Bool, hover:Bool = false):Void {
        if (_btnCollapse == null) return;
        var g = _btnCollapse.graphics;
        g.clear();

        // Extended touch hit area for mobile
        g.beginFill(0x000000, 0.0);
        g.drawRect(-4, -2, 28, 24);
        g.endFill();

        var bg = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE;
        var border = hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT;
        g.beginFill(bg, 0.85);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 20, 18, 4, 4);
        g.endFill();

        var color:Int = hover ? ApiStyle.COLOR_ACCENT_PRIMARY : ApiStyle.COLOR_TEXT_MUTED;
        g.lineStyle(2.2, color, 1.0, true);
        var cx = 10.0;
        var cy = 9.0;
        if (collapsed) {
            // Modern Chevron Down (closed, tap to expand)
            g.moveTo(cx - 4.5, cy - 2.5);
            g.lineTo(cx, cy + 2.5);
            g.lineTo(cx + 4.5, cy - 2.5);
        } else {
            // Modern Chevron Up (open, tap to fold)
            g.moveTo(cx - 4.5, cy + 2.5);
            g.lineTo(cx, cy - 2.5);
            g.lineTo(cx + 4.5, cy + 2.5);
        }
    }

    private static function renderMiniChevronDown():Void {
        if (_btnCollapse == null) return;
        var g = _btnCollapse.graphics;
        g.clear();
        g.lineStyle(2.0, ApiStyle.COLOR_TEXT_MUTED, 0.9, true);
        var cx:Float = 4.0;
        var cy:Float = 9.0;
        g.moveTo(cx - 3.5, cy - 2.0);
        g.lineTo(cx, cy + 2.0);
        g.lineTo(cx + 3.5, cy - 2.0);
    }

    private static function renderConfigIcon(hover:Bool = false):Void {
        if (_btnConfig == null) return;
        var g = _btnConfig.graphics;
        g.clear();

        g.beginFill(0x000000, 0.0);
        g.drawRect(-4, -2, 28, 24);
        g.endFill();

        var bg = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE;
        var border = hover ? ApiStyle.COLOR_ACCENT_PRIMARY : ApiStyle.COLOR_BORDER_DEFAULT;
        g.beginFill(bg, 0.85);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 20, 18, 4, 4);
        g.endFill();

        var color = hover ? ApiStyle.COLOR_ACCENT_HOVER : ApiStyle.COLOR_ACCENT_PRIMARY;
        var cx = 10.0;
        var cy = 9.0;

        g.lineStyle(2.2, color, 1.0, true);
        g.moveTo(cx - 5.0, cy); g.lineTo(cx + 5.0, cy);
        g.moveTo(cx, cy - 5.0); g.lineTo(cx, cy + 5.0);
        var d = 3.6;
        g.moveTo(cx - d, cy - d); g.lineTo(cx + d, cy + d);
        g.moveTo(cx - d, cy + d); g.lineTo(cx + d, cy - d);

        g.lineStyle(1.4, color, 1.0, true);
        g.beginFill(bg, 1.0);
        g.drawCircle(cx, cy, 3.4);
        g.endFill();

        g.lineStyle(0, 0, 0);
        g.beginFill(color, 1.0);
        g.drawCircle(cx, cy, 1.3);
        g.endFill();
    }

    private static function renderCounterBtnStyle(active:Bool, paused:Bool, hover:Bool = false):Void {
        if (_btnCounter == null) return;
        var g = _btnCounter.graphics;
        g.clear();

        // Extended touch hit area for mobile
        g.beginFill(0x000000, 0.0);
        g.drawRect(-3, -3, 76, 24);
        g.endFill();

        var bg:Int = ApiStyle.COLOR_BG_CARD;
        var border:Int = ApiStyle.COLOR_BORDER_DEFAULT;
        var textCol:Int = ApiStyle.COLOR_TEXT_MUTED;
        var iconCol:Int = ApiStyle.COLOR_TEXT_MUTED;
        var bgAlpha:Float = 0.88;
        var labelText:String = "Counter";

        if (paused) {
            bg = ApiStyle.COLOR_STATUS_WARN;
            bgAlpha = 0.25;
            border = ApiStyle.COLOR_STATUS_WARN;
            textCol = ApiStyle.COLOR_STATUS_WARN;
            iconCol = ApiStyle.COLOR_STATUS_WARN;
            labelText = "HOLDING";
        } else if (active) {
            bg = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE;
            bgAlpha = 0.95;
            border = hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_STATUS_ACTIVE;
            textCol = ApiStyle.COLOR_STATUS_ACTIVE;
            iconCol = ApiStyle.COLOR_STATUS_ACTIVE;
            labelText = "Counter";
        } else {
            bg = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_CARD;
            border = hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT;
            textCol = hover ? ApiStyle.COLOR_TEXT_PRIMARY : ApiStyle.COLOR_TEXT_MUTED;
            iconCol = hover ? ApiStyle.COLOR_TEXT_PRIMARY : ApiStyle.COLOR_TEXT_MUTED;
            labelText = "Counter";
        }

        g.beginFill(bg, bgAlpha);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 70, 18, 4, 4);
        g.endFill();

        // Mini tactical shield icon
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

    private static function toggleCounterHandler():Void {
        var next = !CombatEngine.counterHandler;
        if (Api.combat != null) Api.combat.enableCounterHandler(next);
        else CombatEngine.counterHandler = next;
        ApiConfig.setBool("api_counter_handler", next);
        ApiNotificationManager.notify("Counter Handler: " + (next ? "Enabled (Pauses on Reflect)" : "Disabled"));
        renderCounterBtnStyle(next, CombatEngine.isPausedByAura, false);
    }

    public static function openConfigModal():Void {
        if (_overlay == null) return;
        var fixedOpts = getFixedOptions();
        var isFixed = function(id:String) return fixedOpts.indexOf(id) >= 0;

        var options:Array<WidgetConfigModal.WidgetOptionItem> = [
            { id: "atk", label: "Attack", desc: "Show Attack button when collapsed", isFixed: isFixed("atk") },
            { id: "hunt", label: "Hunt", desc: "Show Hunt button when collapsed", isFixed: isFixed("hunt") },
            { id: "counter", label: "Counter", desc: "Show Counter toggle when collapsed", isFixed: isFixed("counter") },
            { id: "class", label: "Class & Mode", desc: "Show Class & Mode dropdowns when collapsed", isFixed: isFixed("class") },
            { id: "target", label: "Target", desc: "Show Target input & grabber when collapsed", isFixed: isFixed("target") }
        ];

        WidgetConfigModal.show(_overlay, "Combat Widget", options, function(savedIds:Array<String>):Void {
            HelperSetting.setString("api_widget_combat_fixed", savedIds.join(","));
            clampToScreen();
            updateLayout();
        });
    }

    private static function clampToScreen():Void {
        if (_widget == null) return;
        var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);
        if (theStage == null) return;
        var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
        var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
        var curW:Float = _isCollapsed ? computeCollapsedWidth() : WIDGET_W;
        var curH:Float = _isCollapsed ? computeCollapsedHeight() : HEIGHT_EXPANDED;

        if (_widget.x > sw - curW - ApiStyle.SCREEN_MARGIN) _widget.x = Math.max(ApiStyle.SCREEN_MARGIN, sw - curW - ApiStyle.SCREEN_MARGIN);
        if (_widget.y > sh - curH - ApiStyle.SCREEN_MARGIN) _widget.y = Math.max(ApiStyle.SCREEN_MARGIN, sh - curH - ApiStyle.SCREEN_MARGIN);
        if (_widget.x < ApiStyle.SCREEN_MARGIN) _widget.x = ApiStyle.SCREEN_MARGIN;
        if (_widget.y < ApiStyle.SCREEN_MARGIN) _widget.y = ApiStyle.SCREEN_MARGIN;

        HelperSetting.setInt("api_widget_combat_x", Math.round(_widget.x));
        HelperSetting.setInt("api_widget_combat_y", Math.round(_widget.y));
    }

    private static function renderGetTargetBtn(hover:Bool = false, active:Bool = false):Void {
        if (_btnGetTarget == null) return;
        var g = _btnGetTarget.graphics;
        g.clear();

        // Extended touch hit boundary for mobile
        g.beginFill(0x000000, 0.0);
        g.drawRect(-4, -4, 38, 32);
        g.endFill();

        var bg = active ? ApiStyle.COLOR_BG_SURFACE : (hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE);
        var border = active ? ApiStyle.COLOR_STATUS_ACTIVE : (hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT);
        var iconColor = active ? ApiStyle.COLOR_STATUS_ACTIVE : (hover ? ApiStyle.COLOR_TEXT_TITLE : ApiStyle.COLOR_TEXT_MUTED);

        g.beginFill(bg, 0.95);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 30, 24, 4, 4);
        g.endFill();

        // Tactical Reticle Icon
        var cx = 15.0;
        var cy = 12.0;
        g.lineStyle(1.8, iconColor, 1.0, true);
        g.drawCircle(cx, cy, 5.0);
        // Crosshair ticks
        g.moveTo(cx - 7.5, cy); g.lineTo(cx - 3.5, cy);
        g.moveTo(cx + 3.5, cy); g.lineTo(cx + 7.5, cy);
        g.moveTo(cx, cy - 7.5); g.lineTo(cx, cy - 3.5);
        g.moveTo(cx, cy + 3.5); g.lineTo(cx, cy + 7.5);
        // Center pip
        g.lineStyle(0, 0, 0);
        g.beginFill(iconColor, 1.0);
        g.drawCircle(cx, cy, 1.5);
        g.endFill();
    }

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
        _widget.name = "CombatWidget";

        // Restore saved position
        var savedX = HelperSetting.getInt("api_widget_combat_x", -1);
        var savedY = HelperSetting.getInt("api_widget_combat_y", -1);
        var defaultX:Float = 180;
        var defaultY:Float = 82;

        var initX:Float = (savedX >= 0) ? savedX : defaultX;
        var initY:Float = (savedY >= 0) ? savedY : defaultY;

        var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
        var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
        if (initX > sw - WIDGET_W - ApiStyle.SCREEN_MARGIN) initX = sw - WIDGET_W - ApiStyle.SCREEN_MARGIN;
        if (initY > sh - HEIGHT_EXPANDED - ApiStyle.SCREEN_MARGIN) initY = sh - HEIGHT_EXPANDED - ApiStyle.SCREEN_MARGIN;
        if (initX < ApiStyle.SCREEN_MARGIN) initX = ApiStyle.SCREEN_MARGIN;
        if (initY < ApiStyle.SCREEN_MARGIN) initY = ApiStyle.SCREEN_MARGIN;

        _widget.x = initX;
        _widget.y = initY;

        _isCollapsed = HelperSetting.getBool("api_widget_combat_collapsed", false);

        // 1. Background plate
        _bg = new Sprite();
        _widget.addChild(_bg);

        // 2. Header Bar (Drag & Click-to-collapse zone)
        _headerBar = new Sprite();
        _headerBar.buttonMode = true;
        _headerBar.useHandCursor = true;

        // Full transparent hit plate for the entire header area
        _headerBar.graphics.beginFill(0x000000, 0.0);
        _headerBar.graphics.drawRect(0, 0, WIDGET_W, 24);
        _headerBar.graphics.endFill();
        _widget.addChild(_headerBar);

        // Header Accent Bar
        _accentShape = new Shape();
        _accentShape.graphics.beginFill(ApiStyle.COLOR_ACCENT_PRIMARY, 1.0);
        _accentShape.graphics.drawRoundRect(6, 4, 3, 14, 1, 1);
        _accentShape.graphics.endFill();
        _headerBar.addChild(_accentShape);

        // Header Title
        _titleTxt = new TextField();
        var titleFmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_PRIMARY, true);
        _titleTxt.defaultTextFormat = titleFmt;
        _titleTxt.text = "Combat";
        _titleTxt.x = 13;
        _titleTxt.y = 3;
        _titleTxt.width = 120;
        _titleTxt.height = 18;
        _titleTxt.selectable = false;
        _titleTxt.mouseEnabled = false;
        _headerBar.addChild(_titleTxt);

        // Header Collapse Indicator (Vector Chevron)
        _btnCollapse = new Sprite();
        _btnCollapse.mouseEnabled = false;
        _btnCollapse.mouseChildren = false;
        _btnCollapse.x = WIDGET_W - 25;
        _btnCollapse.y = 3;
        renderCollapseIcon(_isCollapsed, false);
        _headerBar.addChild(_btnCollapse);

        // Header Config Gear Button
        _btnConfig = new Sprite();
        _btnConfig.buttonMode = true;
        _btnConfig.useHandCursor = true;
        _btnConfig.x = WIDGET_W - 48;
        _btnConfig.y = 3;
        renderConfigIcon(false);

        _btnConfig.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void renderConfigIcon(true));
        _btnConfig.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void renderConfigIcon(false));
        _btnConfig.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void e.stopPropagation());
        _btnConfig.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void e.stopPropagation());
        _btnConfig.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            e.stopPropagation();
            openConfigModal();
        });
        _headerBar.addChild(_btnConfig);

        // Header Counter Attack Toggle Button
        _btnCounter = new Sprite();
        _btnCounter.buttonMode = true;
        _btnCounter.useHandCursor = true;
        _btnCounter.x = WIDGET_W - 48 - 6 - 70;
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

        _widget.addChild(_btnCounter);

        // Subtle hover brightness feedback on title bar
        _headerBar.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            _titleTxt.textColor = ApiStyle.COLOR_TEXT_TITLE;
            var isCompact = _isCollapsed && (getFixedOptions().length == 0);
            if (!isCompact) renderCollapseIcon(_isCollapsed, true);
            _bg.alpha = 1.0;
        });
        _headerBar.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            _titleTxt.textColor = ApiStyle.COLOR_TEXT_PRIMARY;
            var isCompact = _isCollapsed && (getFixedOptions().length == 0);
            if (!isCompact) renderCollapseIcon(_isCollapsed, false);
            _bg.alpha = _isCollapsed ? 0.78 : 0.94;
        });

        // 3. Row 1: Action Buttons (Atk & Hunt)
        var btnW:Float = 148;
        var btnH:Float = 28;

        _btnAtk = createActionButton(btnW, btnH);
        _btnAtk.x = 8;
        _btnAtk.y = 25;
        _widget.addChild(_btnAtk);
        _txtAtk = cast _btnAtk.getChildByName("label");

        _btnHunt = createActionButton(btnW, btnH);
        _btnHunt.x = 164;
        _btnHunt.y = 25;
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
            var inGame = ApiMenus.isInGame();
            if (!inGame) {
                _widget.visible = false;
                _hasRescannedBagOnEntry = false;
                return;
            }
            var isEnabled = HelperSetting.getBool("api_widget_combat_enabled", true);
            if (!isEnabled) {
                _widget.visible = false;
                return;
            }
            var isBlocked:Bool = isBlockedByWindowOrModal();
            _widget.visible = !isBlocked;
            if (_widget.visible) {
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
        });

        updateLayout();
        updateButtonVisuals();

        theStage.addChild(_widget);
    }

    public static function isBlockedByWindowOrModal():Bool {
        if (_overlay != null && _overlay.currentFrameLabel == "Panel") return true;
        if (ApiDashboardModal.isOpen()) return true;
        if (ApiPromptModal.isOpen()) return true;
        try {
            if (Api.game != null && Api.game.ui != null && Api.game.ui.mcPopup != null) {
                var cur = Std.string(Api.game.ui.mcPopup.currentLabel);
                if (cur != null && cur != "" && cur != "Init" && cur != "Idle" && cur != "null") return true;
            }
        } catch (_:Dynamic) {}
        return false;
    }

    public static inline function getModesForClass(cName:String):Array<String> {
        return ClassModeSelector.getModesForClass(cName, "Auto");
    }

    public static function refreshClassOptions():Void {
        if (_classSelector != null) {
            _classSelector.refreshClasses();
            _selectedClass = _classSelector.selectedClass;
        }
    }

    public static function refreshModeOptions():Void {
        if (_classSelector != null) {
            _classSelector.refreshModes();
            _selectedMode = _classSelector.selectedMode;
        }
    }

    private static function setupDropdownsAndInputs():Void {
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
        _bodyContainer.addChild(_classSelector);

        // Row 3: Target Input Plate
        _inputPlate = new Sprite();
        _inputPlate.graphics.beginFill(ApiStyle.COLOR_BG_INPUT, 0.95);
        _inputPlate.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT);
        _inputPlate.graphics.drawRoundRect(0, 0, 268, 24, 4, 4);
        _inputPlate.graphics.endFill();
        _inputPlate.x = 8;
        _inputPlate.y = 84;
        _bodyContainer.addChild(_inputPlate);

        var savedTarget = HelperSetting.getString("api_widget_hunt_target", "");

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
                HelperSetting.setString("api_widget_hunt_target", "");
            } else {
                HelperSetting.setString("api_widget_hunt_target", trimmed);
            }
        });

        _bodyContainer.addChild(_targetInput);

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
                HelperSetting.setString("api_widget_hunt_target", ent.name);
                renderGetTargetBtn(false, true);
                haxe.Timer.delay(function():Void {
                    renderGetTargetBtn(false, false);
                }, 180);
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
        sp.scaleX = 1.0;
        sp.scaleY = 1.0;

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

    private static function updateLayout():Void {
        var fixedOpts = getFixedOptions();
        var isCompact:Bool = _isCollapsed && (fixedOpts.length == 0);

        if (isCompact) {
            // COMPACT MINIMIZED MODE: 78x26 (matching Main Menu button)
            var w:Float = COMPACT_W;
            var h:Float = COMPACT_H;

            _bg.graphics.clear();
            _bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.88);
            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.85);
            _bg.graphics.drawRoundRect(0, 0, w, h, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
            _bg.graphics.endFill();

            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
            _bg.graphics.moveTo(3, 1);
            _bg.graphics.lineTo(w - 3, 1);

            _accentShape.visible = true;
            _accentShape.graphics.clear();
            _accentShape.graphics.beginFill(ApiStyle.COLOR_ACCENT_PRIMARY, 1.0);
            _accentShape.graphics.drawRoundRect(5, 5, 3.5, 16, 1.5, 1.5);
            _accentShape.graphics.endFill();

            _titleTxt.visible = true;
            _titleTxt.text = "Combat";
            _titleTxt.x = 13;
            _titleTxt.y = 4;
            _titleTxt.width = COMPACT_W - 16;

            _headerBar.graphics.clear();
            _headerBar.graphics.beginFill(0x000000, 0.0);
            _headerBar.graphics.drawRect(0, 0, w, h);
            _headerBar.graphics.endFill();

            _btnCollapse.visible = false;
            _btnConfig.visible = false;
            _btnCounter.visible = false;
            _btnAtk.visible = false;
            _btnHunt.visible = false;
            _classSelector.visible = false;
            _inputPlate.visible = false;
            _targetInput.visible = false;
            _btnGetTarget.visible = false;
            _bodyContainer.visible = false;
        } else if (_isCollapsed) {
            // COLLAPSED WITH FIXED PINNED OPTIONS
            // When at least one option is fixed, label text and accent bar are hidden!
            _titleTxt.visible = false;
            _accentShape.visible = false;
            _btnCollapse.visible = false;
            _btnConfig.visible = false; // Setting icon only shows when widget is opened!

            if (fixedOpts.length == 1 && fixedOpts[0] == "counter") {
                // Counter-only compact pill
                var w:Float = COMPACT_W;
                var h:Float = COMPACT_H;

                _btnCounter.visible = true;
                _btnCounter.x = 4;
                _btnCounter.y = 3;

                _btnAtk.visible = false;
                _btnHunt.visible = false;
                _classSelector.visible = false;
                _inputPlate.visible = false;
                _targetInput.visible = false;
                _btnGetTarget.visible = false;
                _bodyContainer.visible = false;

                _bg.graphics.clear();
                _bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.88);
                _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.85);
                _bg.graphics.drawRoundRect(0, 0, w, h, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
                _bg.graphics.endFill();

                _bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
                _bg.graphics.moveTo(3, 1);
                _bg.graphics.lineTo(w - 3, 1);

                _headerBar.graphics.clear();
                _headerBar.graphics.beginFill(0x000000, 0.0);
                _headerBar.graphics.drawRect(0, 0, w, h);
                _headerBar.graphics.endFill();
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

                var totalH:Float = (curY > 6) ? (curY + 4) : COMPACT_H;
                _bodyContainer.visible = (curY > 6);

                _bg.graphics.clear();
                _bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.88);
                _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.85);
                _bg.graphics.drawRoundRect(0, 0, WIDGET_W, totalH, 6, 6);
                _bg.graphics.endFill();

                _bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
                _bg.graphics.moveTo(3, 1);
                _bg.graphics.lineTo(WIDGET_W - 3, 1);

                _headerBar.graphics.clear();
                _headerBar.graphics.beginFill(0x000000, 0.0);
                _headerBar.graphics.drawRect(0, 0, WIDGET_W, totalH);
                _headerBar.graphics.endFill();
            }
        } else {
            // FULLY EXPANDED
            _titleTxt.visible = true;
            _titleTxt.text = "Combat";
            _titleTxt.x = 13;
            _titleTxt.y = 3;
            _titleTxt.width = 120;

            _accentShape.visible = true;
            _accentShape.graphics.clear();
            _accentShape.graphics.beginFill(ApiStyle.COLOR_ACCENT_PRIMARY, 1.0);
            _accentShape.graphics.drawRoundRect(6, 4, 3, 14, 1, 1);
            _accentShape.graphics.endFill();

            _btnCollapse.visible = false; // Chevron removed everywhere

            _btnConfig.visible = true; // Settings icon only when opened
            _btnConfig.x = WIDGET_W - 25;
            _btnConfig.y = 3;
            renderConfigIcon(false);

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

            _bodyContainer.visible = true;

            _bg.graphics.clear();
            _bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.94);
            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 1.0);
            _bg.graphics.drawRoundRect(0, 0, WIDGET_W, HEIGHT_EXPANDED, 6, 6);
            _bg.graphics.endFill();

            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.55);
            _bg.graphics.moveTo(3, 1);
            _bg.graphics.lineTo(WIDGET_W - 3, 1);

            _headerBar.graphics.clear();
            _headerBar.graphics.beginFill(0x000000, 0.0);
            _headerBar.graphics.drawRect(0, 0, WIDGET_W, 24);
            _headerBar.graphics.endFill();
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

    private static var _lastAtkActive:Int = -1;
    private static var _lastHuntActive:Int = -1;
    private static var _lastCounterActive:Int = -1;
    private static var _lastCounterPaused:Bool = false;

    private static function updateButtonVisuals():Void {
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

    private static function flashActionButton(btn:Sprite, active:Bool, label:String, w:Float, h:Float):Void {
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

    private static function renderBtnStyle(btn:Sprite, active:Bool, label:String, w:Float, h:Float):Void {
        if (btn == null) return;
        btn.scaleX = 1.0;
        btn.scaleY = 1.0;
        btn.graphics.clear();
        var bg = active ? ApiStyle.COLOR_BG_SURFACE : ApiStyle.COLOR_BG_CARD;
        var border = active ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_BORDER_DEFAULT;
        var textColor = active ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_TEXT_PRIMARY;

        btn.graphics.beginFill(bg, 0.94);
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

    private static function toggleAutoAttack():Void {
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

    private static function toggleAutoHunt():Void {
        var next = !_isHunting;
        flashActionButton(_btnHunt, next, "Hunt", _curHuntW, 28);
        if (_isHunting) {
            stopAutoHunt();
        } else {
            startAutoHunt();
        }
        _lastHuntActive = -1;
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
        ApiNotificationManager.notify("Hunt: " + targetStr);
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
        ApiNotificationManager.notify("Hunt stopped.");
    }

    public static function toggleCollapse():Void {
        _isCollapsed = !_isCollapsed;
        HelperSetting.setBool("api_widget_combat_collapsed", _isCollapsed);
        clampToScreen();
        updateLayout();
    }

    private static function setupDragging(theStage:Dynamic):Void {
        var isDragging:Bool = false;
        var hasDragged:Bool = false;
        var startDownX:Float = 0;
        var startDownY:Float = 0;
        var dragStartX:Float = 0;
        var dragStartY:Float = 0;

        _headerBar.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            isDragging = true;
            hasDragged = false;
            startDownX = e.stageX;
            startDownY = e.stageY;
            _widget.cacheAsBitmap = false;
            dragStartX = e.stageX - _widget.x;
            dragStartY = e.stageY - _widget.y;
        });

        theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (isDragging) {
                var dx = e.stageX - startDownX;
                var dy = e.stageY - startDownY;
                if (Math.abs(dx) > 4 || Math.abs(dy) > 4) {
                    hasDragged = true;
                }
                if (hasDragged) {
                    var nx:Float = Math.round(e.stageX - dragStartX);
                    var ny:Float = Math.round(e.stageY - dragStartY);
                    var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
                    var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
                    var curW:Float = _isCollapsed ? computeCollapsedWidth() : WIDGET_W;
                    var curH:Float = _isCollapsed ? computeCollapsedHeight() : HEIGHT_EXPANDED;

                    if (nx < ApiStyle.SCREEN_MARGIN) nx = ApiStyle.SCREEN_MARGIN;
                    if (ny < ApiStyle.SCREEN_MARGIN) ny = ApiStyle.SCREEN_MARGIN;
                    if (nx > sw - curW - ApiStyle.SCREEN_MARGIN) nx = sw - curW - ApiStyle.SCREEN_MARGIN;
                    if (ny > sh - curH - ApiStyle.SCREEN_MARGIN) ny = sh - curH - ApiStyle.SCREEN_MARGIN;

                    _widget.x = nx;
                    _widget.y = ny;
                }
            }
        });

        theStage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            if (isDragging) {
                isDragging = false;
                _widget.cacheAsBitmap = true;
                if (hasDragged) {
                    var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
                    var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
                    var curW:Float = _isCollapsed ? computeCollapsedWidth() : WIDGET_W;
                    var curH:Float = _isCollapsed ? computeCollapsedHeight() : HEIGHT_EXPANDED;
                    if (_widget.x < ApiStyle.SCREEN_MARGIN) _widget.x = ApiStyle.SCREEN_MARGIN;
                    if (_widget.y < ApiStyle.SCREEN_MARGIN) _widget.y = ApiStyle.SCREEN_MARGIN;
                    if (_widget.x > sw - curW - ApiStyle.SCREEN_MARGIN) _widget.x = sw - curW - ApiStyle.SCREEN_MARGIN;
                    if (_widget.y > sh - curH - ApiStyle.SCREEN_MARGIN) _widget.y = sh - curH - ApiStyle.SCREEN_MARGIN;

                    HelperSetting.setInt("api_widget_combat_x", Math.round(_widget.x));
                    HelperSetting.setInt("api_widget_combat_y", Math.round(_widget.y));
                } else {
                    toggleCollapse();
                }
            }
        });
    }

    public static function isWidgetEnabled():Bool {
        return HelperSetting.getBool("api_widget_combat_enabled", true);
    }

    public static function setWidgetEnabled(enabled:Bool):Void {
        HelperSetting.setBool("api_widget_combat_enabled", enabled);
        if (_widget != null) _widget.visible = enabled;
    }

    public static function resetPosition():Void {
        HelperSetting.setInt("api_widget_combat_x", 180);
        HelperSetting.setInt("api_widget_combat_y", 82);
        if (_widget != null) {
            _widget.x = 180;
            _widget.y = 82;
        }
    }
}
#else
class CombatWidget {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isWidgetEnabled():Bool return false;
    public static function setWidgetEnabled(enabled:Bool):Void {}
    public static function resetPosition():Void {}
    public static function openConfigModal():Void {}
}
#end
