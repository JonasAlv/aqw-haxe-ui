package ui;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import com.aqwapi.Api;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.utils.ApiLogger;
import ui.Overlay;
import ui.ApiDashboardModal;
import ui.ApiNotificationManager;
import ui.prompts.ApiPromptModal;
import util.HelperSetting;

typedef ToolDef = {
    id:String,
    name:String,
    defaultLabel:String,
    activeText:String,
    inactiveText:String,
    isToggle:Bool,
    getState:Void->Bool,
    onAction:Void->Void
};

typedef WidgetItemConfig = {
    toolId:String,
    isFixed:Bool
};

typedef CustomWidgetDef = {
    id:String,
    title:String,
    x:Float,
    y:Float,
    isCollapsed:Bool,
    enabled:Bool,
    items:Array<WidgetItemConfig>
};

/**
 * Customizable In-Game Tools Widget System.
 *
 * Allows users to create, configure, and rename custom widgets with selectable misc options:
 * - Select which options/tools appear in each widget
 * - Choose which items are "Fixed" (pinned / visible when collapsed) vs hidden when collapsed
 * - Freely rename widgets to custom titles
 * - Drag anywhere with persistent position saving
 * - Click title bar to toggle collapse/hide
 * - 1-tap [*] gear button to open in-game Widget Customizer
 */
class ApiToolsWidget {
    private static var _pocket:Dynamic = null;
    private static var _overlay:Overlay = null;
    private static var _theStage:Dynamic = null;
    private static var _initialized:Bool = false;

    private static var _activeWidgets:Map<String, CustomWidgetInstance> = new Map<String, CustomWidgetInstance>();
    private static var _widgetDefs:Array<CustomWidgetDef> = [];

    private static inline var SETTING_KEY:String = "api_custom_widgets_v1";
    public static inline var WIDGET_W:Float = 230;

    // Registry of all available misc tools
    public static var toolRegistry:Array<ToolDef> = [];

    public static function init(pocket:Dynamic, overlay:Overlay):Void {
        if (_initialized) return;
        _initialized = true;
        _pocket = pocket;
        _overlay = overlay;

        setupRegistry();

        var stageObj:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);

        var attach = function(st:Dynamic):Void {
            if (st == null || _theStage != null) return;
            _theStage = st;
            loadAndBuildWidgets();
        };

        if (stageObj != null) {
            attach(stageObj);
        } else if (_overlay != null) {
            _overlay.addEventListener(Event.ADDED_TO_STAGE, function(ev:Event):Void {
                if (_overlay.stage != null && _theStage == null) {
                    attach(_overlay.stage);
                }
            });
        }
    }

    private static function setupRegistry():Void {
        toolRegistry = [
            {
                id: "script_runner",
                name: "Script Runner",
                defaultLabel: "Script",
                activeText: "Script: RUN",
                inactiveText: "Script: STOP",
                isToggle: true,
                getState: function():Bool return (ScriptManager.SINGLETON != null && ScriptManager.SINGLETON.isRunning),
                onAction: function():Void {
                    if (ScriptManager.SINGLETON.isRunning) {
                        ScriptManager.SINGLETON.stop();
                        ApiNotificationManager.notify("Script stopped.");
                    } else {
                        ScriptManager.SINGLETON.start();
                        if (ScriptManager.SINGLETON.isRunning) ApiNotificationManager.notify("Script started.");
                        else ApiNotificationManager.notify("No script loaded! Open Script Manager.");
                    }
                }
            },
            {
                id: "lag_killer",
                name: "Lag Killer",
                defaultLabel: "Lag",
                activeText: "Lag: ON",
                inactiveText: "Lag: OFF",
                isToggle: true,
                getState: function():Bool return (Api.visual != null && Api.visual.lagKiller),
                onAction: function():Void {
                    if (Api.visual != null) {
                        Api.visual.lagKiller = !Api.visual.lagKiller;
                        ApiNotificationManager.notify("Lag Killer: " + (Api.visual.lagKiller ? "ON" : "OFF"));
                    }
                }
            },
            {
                id: "infinite_range",
                name: "Infinite Range",
                defaultLabel: "Range",
                activeText: "Range: ON",
                inactiveText: "Range: OFF",
                isToggle: true,
                getState: function():Bool return (Api.combat != null && Api.combat.infiniteRange),
                onAction: function():Void {
                    var cur = HelperSetting.getBool("api_infinite_range", false);
                    var next = !cur;
                    HelperSetting.setBool("api_infinite_range", next);
                    if (Api.combat != null) {
                        Api.combat.infiniteRange = next;
                        if (next) Api.combat.applyInfiniteRange();
                    }
                    ApiNotificationManager.notify("Infinite Range: " + (next ? "ON" : "OFF"));
                }
            },
            {
                id: "accept_loot",
                name: "Accept Loot",
                defaultLabel: "Loot",
                activeText: "Loot: ON",
                inactiveText: "Loot: OFF",
                isToggle: true,
                getState: function():Bool return (Api.drop != null && Api.drop.acceptAll),
                onAction: function():Void {
                    var cur = HelperSetting.getBool("api_accept_loot", false);
                    var next = !cur;
                    HelperSetting.setBool("api_accept_loot", next);
                    if (Api.drop != null) {
                        Api.drop.acceptAll = next;
                        if (next) {
                            Api.drop.scanScreenDrops();
                            Api.drop.acceptAllDrops();
                        }
                    }
                    ApiNotificationManager.notify("Accept Loot: " + (next ? "ON" : "OFF"));
                }
            },
            {
                id: "provoke_all",
                name: "Provoke All",
                defaultLabel: "Provoke",
                activeText: "Provoke: ON",
                inactiveText: "Provoke: OFF",
                isToggle: true,
                getState: function():Bool return (Api.combat != null && Api.combat.autoProvoke),
                onAction: function():Void {
                    if (Api.combat != null) {
                        var next = !Api.combat.autoProvoke;
                        Api.combat.provokeAll(next);
                        ApiNotificationManager.notify("Provoke All: " + (next ? "ON" : "OFF"));
                    }
                }
            },
            {
                id: "toggle_bank",
                name: "Bank",
                defaultLabel: "Bank",
                activeText: "Bank",
                inactiveText: "Bank",
                isToggle: false,
                getState: function():Bool return false,
                onAction: function():Void {
                    if (Api.inventory != null) Api.inventory.toggleBank();
                }
            },
            {
                id: "smart_enhance",
                name: "Smart Enhance",
                defaultLabel: "Enhance",
                activeText: "Enhancing...",
                inactiveText: "Enhance",
                isToggle: false,
                getState: function():Bool return (Api.enhancement != null && Api.enhancement.isBusy),
                onAction: function():Void {
                    if (Api.enhancement != null) {
                        if (Api.enhancement.isBusy) {
                            ApiNotificationManager.notify("Enhancement queue busy!");
                            return;
                        }
                        var curClass = (Api.player != null && Api.player.className != null && Api.player.className != "") ? Api.player.className : "Equipped Class";
                        ApiNotificationManager.notify("SmartEnhancing " + curClass + "...");
                        Api.enhancement.smartEnhance(null, function():Void {
                            ApiNotificationManager.notify("SmartEnhance finished!");
                        });
                    }
                }
            },
            {
                id: "open_dashboard",
                name: "Dashboard Menu",
                defaultLabel: "Menu",
                activeText: "Menu",
                inactiveText: "Menu",
                isToggle: false,
                getState: function():Bool return false,
                onAction: function():Void {
                    ApiDashboardModal.show(_overlay);
                }
            },
            {
                id: "accept_acs",
                name: "Accept AC Drops",
                defaultLabel: "ACs",
                activeText: "ACs: ON",
                inactiveText: "ACs: OFF",
                isToggle: true,
                getState: function():Bool return (Api.drop != null && Api.drop.acceptACs),
                onAction: function():Void {
                    var cur = (Api.drop != null && Api.drop.acceptACs);
                    var next = !cur;
                    HelperSetting.setBool("api_accept_ac_drops", next);
                    if (Api.drop != null) {
                        Api.drop.acceptACs = next;
                        if (next) {
                            Api.drop.scanScreenDrops();
                            Api.drop.acceptACDrops();
                        }
                    }
                    ApiNotificationManager.notify("Accept AC Drops: " + (next ? "ON" : "OFF"));
                }
            },
            {
                id: "skip_cutscenes",
                name: "Skip Cutscenes",
                defaultLabel: "Cutscenes",
                activeText: "Cutscene: SKIP",
                inactiveText: "Cutscene: PLAY",
                isToggle: true,
                getState: function():Bool return (Api.map != null && Api.map.skipCutscenes),
                onAction: function():Void {
                    if (Api.map != null) {
                        var next = !Api.map.skipCutscenes;
                        Api.map.skipCutscenes = next;
                        HelperSetting.setBool("api_skip_cutscenes", next);
                        ApiNotificationManager.notify("Skip Cutscenes: " + (next ? "ON" : "OFF"));
                    }
                }
            },
            {
                id: "clean_rejoin",
                name: "Clean Rejoin",
                defaultLabel: "Rejoin",
                activeText: "Rejoin",
                inactiveText: "Rejoin",
                isToggle: false,
                getState: function():Bool return false,
                onAction: function():Void {
                    if (Api.map != null) {
                        ApiNotificationManager.notify("Reloading map...");
                        Api.map.reload();
                    }
                }
            },
            {
                id: "auto_relog",
                name: "Auto Relogin",
                defaultLabel: "Relog",
                activeText: "Relog: ON",
                inactiveText: "Relog: OFF",
                isToggle: true,
                getState: function():Bool return HelperSetting.getBool("api_auto_relogin", false),
                onAction: function():Void {
                    var cur = HelperSetting.getBool("api_auto_relogin", false);
                    var next = !cur;
                    HelperSetting.setBool("api_auto_relogin", next);
                    ApiNotificationManager.notify("Auto Relogin: " + (next ? "Enabled" : "Disabled"));
                }
            }
        ];
    }

    public static function getToolDef(id:String):ToolDef {
        for (t in toolRegistry) {
            if (t.id == id) return t;
        }
        return null;
    }

    public static function getDefaultWidgetDef():CustomWidgetDef {
        return {
            id: "quick_tools",
            title: "Quick Tools",
            x: 445,
            y: 82,
            isCollapsed: false,
            enabled: true,
            items: [
                { toolId: "script_runner", isFixed: true },
                { toolId: "lag_killer", isFixed: true },
                { toolId: "infinite_range", isFixed: false },
                { toolId: "accept_loot", isFixed: false },
                { toolId: "provoke_all", isFixed: false },
                { toolId: "toggle_bank", isFixed: false },
                { toolId: "smart_enhance", isFixed: false },
                { toolId: "open_dashboard", isFixed: false }
            ]
        };
    }

    public static function loadWidgets():Array<CustomWidgetDef> {
        var raw = HelperSetting.getString(SETTING_KEY, "");
        if (raw != null && raw != "") {
            try {
                var parsed:Dynamic = haxe.Json.parse(raw);
                if (Std.isOfType(parsed, Array)) {
                    var arr:Array<Dynamic> = cast parsed;
                    var list:Array<CustomWidgetDef> = [];
                    for (item in arr) {
                        if (item != null && item.id != null) {
                            var itemsArr:Array<WidgetItemConfig> = [];
                            if (item.items != null && Std.isOfType(item.items, Array)) {
                                for (it in (cast item.items : Array<Dynamic>)) {
                                    if (it != null && it.toolId != null) {
                                        itemsArr.push({
                                            toolId: Std.string(it.toolId),
                                            isFixed: (it.isFixed == true || it.isFixed == 1)
                                        });
                                    }
                                }
                            }
                            list.push({
                                id: Std.string(item.id),
                                title: (item.title != null && item.title != "") ? Std.string(item.title) : "Quick Tools",
                                x: (item.x != null) ? Std.parseFloat(Std.string(item.x)) : 445,
                                y: (item.y != null) ? Std.parseFloat(Std.string(item.y)) : 82,
                                isCollapsed: (item.isCollapsed == true || item.isCollapsed == 1),
                                enabled: (item.enabled != false && item.enabled != 0),
                                items: itemsArr
                            });
                        }
                    }
                    if (list.length > 0) return list;
                }
            } catch (err:Dynamic) {
                trace("Error parsing custom widgets: " + err);
            }
        }
        return [getDefaultWidgetDef()];
    }

    public static function saveWidgets():Void {
        try {
            var raw = haxe.Json.stringify(_widgetDefs);
            HelperSetting.setString(SETTING_KEY, raw);
        } catch (err:Dynamic) {
            trace("Error saving custom widgets: " + err);
        }
    }

    public static function loadAndBuildWidgets():Void {
        if (_theStage == null) return;

        // Clear existing widget instances
        for (w in _activeWidgets) {
            if (w.parent != null) w.parent.removeChild(w);
            w.destroy();
        }
        _activeWidgets = new Map<String, CustomWidgetInstance>();

        _widgetDefs = loadWidgets();

        for (def in _widgetDefs) {
            if (def.enabled) {
                var inst = new CustomWidgetInstance(def, _theStage, _overlay);
                _activeWidgets.set(def.id, inst);
                _theStage.addChild(inst);
            }
        }
    }

    public static function getWidgets():Array<CustomWidgetDef> {
        return _widgetDefs;
    }

    public static function createNewWidget():Void {
        var id = "widget_" + Date.now().getTime();
        var newDef:CustomWidgetDef = {
            id: id,
            title: "Custom Widget " + (_widgetDefs.length + 1),
            x: 445,
            y: 82 + (_widgetDefs.length * 30),
            isCollapsed: false,
            enabled: true,
            items: [
                { toolId: "script_runner", isFixed: true },
                { toolId: "accept_loot", isFixed: true },
                { toolId: "infinite_range", isFixed: false },
                { toolId: "provoke_all", isFixed: false }
            ]
        };
        _widgetDefs.push(newDef);
        saveWidgets();
        loadAndBuildWidgets();
        openEditor(newDef);
    }

    public static function deleteWidget(id:String):Void {
        for (i in 0..._widgetDefs.length) {
            if (_widgetDefs[i].id == id) {
                _widgetDefs.splice(i, 1);
                break;
            }
        }
        if (_widgetDefs.length == 0) {
            _widgetDefs.push(getDefaultWidgetDef());
        }
        saveWidgets();
        loadAndBuildWidgets();
        ApiNotificationManager.notify("Widget deleted.");
    }

    public static function setWidgetEnabled(idOrEnabled:Dynamic, ?enabledVal:Null<Bool>):Void {
        if (Std.isOfType(idOrEnabled, Bool)) {
            var en:Bool = cast idOrEnabled;
            if (_widgetDefs.length > 0) {
                _widgetDefs[0].enabled = en;
                saveWidgets();
                loadAndBuildWidgets();
            }
        } else {
            var id:String = Std.string(idOrEnabled);
            var en:Bool = (enabledVal != null) ? enabledVal : true;
            for (def in _widgetDefs) {
                if (def.id == id) {
                    def.enabled = en;
                    break;
                }
            }
            saveWidgets();
            loadAndBuildWidgets();
        }
    }

    public static function resetAllPositions():Void {
        for (i in 0..._widgetDefs.length) {
            _widgetDefs[i].x = 445;
            _widgetDefs[i].y = 82 + (i * 35);
        }
        saveWidgets();
        loadAndBuildWidgets();
        ApiNotificationManager.notify("Widgets reset to default positions!");
    }

    public static function openEditor(def:CustomWidgetDef):Void {
        if (_overlay == null) return;

        var dlgW:Float = 400;
        var dlgH:Float = 475;
        var dlg = ApiPromptModal.createDialog(dlgW, dlgH, "Configure Widget");

        // 1. Widget Name Input
        var lblName = ApiPromptModal.createLabel("Widget Title:", 360, 11, true);
        lblName.x = 20;
        lblName.y = 36;
        dlg.addChild(lblName);

        var txtName = ApiPromptModal.createInput(360, 24, def.title);
        txtName.x = 20;
        txtName.y = 54;
        dlg.addChild(txtName);

        // 2. Instructions Subtitle
        var lblDesc = ApiPromptModal.createLabel("Select tools to include. Check 'Fixed' to keep a tool visible when collapsed:", 360, 10, false);
        lblDesc.x = 20;
        lblDesc.y = 84;
        lblDesc.textColor = 0x888888;
        dlg.addChild(lblDesc);

        // 3. Tools Scroll Container
        var listW:Float = 360;
        var listH:Float = 290;
        var listContainer = new Sprite();
        listContainer.x = 20;
        listContainer.y = 104;
        listContainer.graphics.beginFill(0x161616, 0.95);
        listContainer.graphics.lineStyle(1, 0x2A2A2A);
        listContainer.graphics.drawRoundRect(0, 0, listW, listH, 6, 6);
        listContainer.graphics.endFill();
        dlg.addChild(listContainer);

        var maskShape = new Shape();
        maskShape.graphics.beginFill(0xFF0000);
        maskShape.graphics.drawRoundRect(0, 0, listW, listH, 6, 6);
        maskShape.graphics.endFill();
        listContainer.addChild(maskShape);

        var content = new Sprite();
        content.mask = maskShape;
        listContainer.addChild(content);

        // State trackers for dialog
        var includedMap:Map<String, Bool> = new Map<String, Bool>();
        var fixedMap:Map<String, Bool> = new Map<String, Bool>();

        for (it in def.items) {
            includedMap.set(it.toolId, true);
            if (it.isFixed) fixedMap.set(it.toolId, true);
        }

        var rowH:Float = 24;
        for (i in 0...toolRegistry.length) {
            var tool = toolRegistry[i];
            var row = new Sprite();
            row.y = i * rowH + 2;

            // Zebra striping
            row.graphics.beginFill((i % 2 == 0) ? 0x1A1A1A : 0x141414, 0.8);
            row.graphics.drawRoundRect(2, 0, listW - 4, rowH - 2, 4, 4);
            row.graphics.endFill();

            // Checkbox 1: Include in widget
            var isInc = includedMap.exists(tool.id) && includedMap.get(tool.id);
            var chkInc = createCheckbox(tool.name, isInc, function(c:Bool):Void {
                includedMap.set(tool.id, c);
            }, 180);
            chkInc.x = 8;
            chkInc.y = 2;
            row.addChild(chkInc);

            // Checkbox 2: Fixed (pin when collapsed)
            var isFix = fixedMap.exists(tool.id) && fixedMap.get(tool.id);
            var chkFix = createCheckbox("Fixed (Pinned)", isFix, function(c:Bool):Void {
                fixedMap.set(tool.id, c);
            }, 130);
            chkFix.x = 210;
            chkFix.y = 2;
            row.addChild(chkFix);

            content.addChild(row);
        }

        // Mouse wheel scroll for tools container
        listContainer.addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent):Void {
            var totalContentH = toolRegistry.length * rowH;
            if (totalContentH <= listH) return;
            var maxScroll = listH - totalContentH;
            content.y += e.delta * 20;
            if (content.y > 0) content.y = 0;
            if (content.y < maxScroll) content.y = maxScroll;
        });

        // 4. Dialog Action Buttons
        var btnY:Float = 405;

        // [Save Widget]
        var btnSave = ApiPromptModal.createButton("Save Widget", 110, 28, function():Void {
            var newTitle = StringTools.trim(txtName.text);
            if (newTitle == "") newTitle = "Quick Tools";
            def.title = newTitle;

            var newItems:Array<WidgetItemConfig> = [];
            for (t in toolRegistry) {
                if (includedMap.exists(t.id) && includedMap.get(t.id)) {
                    newItems.push({
                        toolId: t.id,
                        isFixed: (fixedMap.exists(t.id) && fixedMap.get(t.id))
                    });
                }
            }
            if (newItems.length == 0) {
                newItems.push({ toolId: "script_runner", isFixed: true });
            }
            def.items = newItems;

            saveWidgets();
            loadAndBuildWidgets();
            ApiPromptModal.close();
            ApiNotificationManager.notify("Widget '" + newTitle + "' saved!");
        }, true);
        btnSave.x = 20;
        btnSave.y = btnY;
        dlg.addChild(btnSave);

        // [Reset Defaults]
        var btnReset = ApiPromptModal.createButton("Reset", 75, 28, function():Void {
            def.items = getDefaultWidgetDef().items;
            def.title = "Quick Tools";
            saveWidgets();
            loadAndBuildWidgets();
            ApiPromptModal.close();
            ApiNotificationManager.notify("Widget reset to defaults.");
        }, false);
        btnReset.x = 138;
        btnReset.y = btnY;
        dlg.addChild(btnReset);

        // [Delete Widget]
        if (_widgetDefs.length > 1) {
            var btnDel = ApiPromptModal.createButton("Delete", 75, 28, function():Void {
                deleteWidget(def.id);
                ApiPromptModal.close();
            }, false, 0x881111, 0xAA2222);
            btnDel.x = 221;
            btnDel.y = btnY;
            dlg.addChild(btnDel);
        }

        // [Cancel]
        var btnCancel = ApiPromptModal.createButton("Cancel", 70, 28, function():Void {
            ApiPromptModal.close();
        }, false);
        btnCancel.x = 310;
        btnCancel.y = btnY;
        dlg.addChild(btnCancel);

        ApiPromptModal.show(_overlay, dlg);
    }

    private static function createCheckbox(label:String, initialChecked:Bool, onChange:Bool->Void, totalWidth:Float):Sprite {
        var sp = new Sprite();
        sp.buttonMode = true;
        var checked:Bool = initialChecked;

        var box = new Shape();
        sp.addChild(box);

        var txt = new TextField();
        var fmt = new TextFormat("_sans", 11, 0xCCCCCC);
        txt.defaultTextFormat = fmt;
        txt.text = label;
        txt.x = 20;
        txt.y = 0;
        txt.width = totalWidth - 22;
        txt.height = 18;
        txt.selectable = false;
        txt.mouseEnabled = false;
        sp.addChild(txt);

        var redraw = function():Void {
            box.graphics.clear();
            box.graphics.beginFill(checked ? 0x00BCD4 : 0x222222, 1);
            box.graphics.lineStyle(1, checked ? 0x00E5FF : 0x555555);
            box.graphics.drawRoundRect(0, 2, 14, 14, 3, 3);
            box.graphics.endFill();
            if (checked) {
                box.graphics.lineStyle(2, 0xFFFFFF);
                box.graphics.moveTo(3, 9);
                box.graphics.lineTo(6, 12);
                box.graphics.lineTo(11, 5);
            }
        };
        redraw();

        sp.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            checked = !checked;
            redraw();
            if (onChange != null) onChange(checked);
        });

        return sp;
    }

    // Compatibility helpers for Dashboard Modal
    public static function isWidgetEnabled():Bool {
        return (_widgetDefs.length > 0 && _widgetDefs[0].enabled);
    }

    public static function resetPosition():Void {
        resetAllPositions();
    }
}

/**
 * Visual instance of a single customizable widget on screen.
 */
class CustomWidgetInstance extends Sprite {
    public var def:CustomWidgetDef;
    private var _theStage:Dynamic;
    private var _overlay:Overlay;

    private var _bg:Sprite;
    private var _headerBar:Sprite;
    private var _titleTxt:TextField;
    private var _btnConfig:Sprite;
    private var _btnCollapse:Sprite;
    private var _txtCollapse:TextField;

    private var _fixedContainer:Sprite;
    private var _collapsibleContainer:Sprite;

    private var _buttons:Map<String, { btn:Sprite, dot:Shape, lbl:TextField, tool:ToolDef, isFixed:Bool }> = new Map();
    private var _lastStates:Map<String, Int> = new Map();

    private var _fixedRows:Int = 0;
    private var _collapsibleRows:Int = 0;
    private var _totalRows:Int = 0;

    public function new(def:CustomWidgetDef, theStage:Dynamic, overlay:Overlay) {
        super();
        this.def = def;
        this._theStage = theStage;
        this._overlay = overlay;
        this.name = "CustomWidget_" + def.id;

        buildUI();
    }

    private function buildUI():Void {
        var sw:Float = (_theStage != null && _theStage.stageWidth > 0) ? _theStage.stageWidth : 960;
        var sh:Float = (_theStage != null && _theStage.stageHeight > 0) ? _theStage.stageHeight : 550;

        var initX:Float = def.x;
        var initY:Float = def.y;
        if (initX > sw - ApiToolsWidget.WIDGET_W) initX = sw - ApiToolsWidget.WIDGET_W;
        if (initY > sh - 100) initY = sh - 100;
        if (initX < 0) initX = 0;
        if (initY < 0) initY = 0;
        this.x = initX;
        this.y = initY;

        // 1. Background plate
        _bg = new Sprite();
        addChild(_bg);

        // 2. Header Bar (Drag & Click-to-collapse)
        _headerBar = new Sprite();
        _headerBar.buttonMode = true;
        _headerBar.useHandCursor = true;

        _headerBar.graphics.beginFill(0x000000, 0.0);
        _headerBar.graphics.drawRect(0, 0, ApiToolsWidget.WIDGET_W, 22);
        _headerBar.graphics.endFill();
        addChild(_headerBar);

        // Header Accent
        var cyanAccent = new Shape();
        cyanAccent.graphics.beginFill(0x00BCD4, 1.0);
        cyanAccent.graphics.drawRoundRect(6, 4, 3, 12, 1, 1);
        cyanAccent.graphics.endFill();
        _headerBar.addChild(cyanAccent);

        // Header Title
        _titleTxt = new TextField();
        var titleFmt = new TextFormat("_sans", 10, 0xBBBBBB, true);
        _titleTxt.defaultTextFormat = titleFmt;
        _titleTxt.text = def.title;
        _titleTxt.x = 13;
        _titleTxt.y = 3;
        _titleTxt.width = ApiToolsWidget.WIDGET_W - 55;
        _titleTxt.height = 16;
        _titleTxt.selectable = false;
        _titleTxt.mouseEnabled = false;
        _headerBar.addChild(_titleTxt);

        // Config Gear Button [*]
        _btnConfig = new Sprite();
        _btnConfig.buttonMode = true;
        _btnConfig.x = ApiToolsWidget.WIDGET_W - 38;
        _btnConfig.y = 2;

        var txtCfg = new TextField();
        var cfgFmt = new TextFormat("_sans", 11, 0x777777, true);
        cfgFmt.align = TextFormatAlign.CENTER;
        txtCfg.defaultTextFormat = cfgFmt;
        txtCfg.text = "*";
        txtCfg.width = 16;
        txtCfg.height = 18;
        txtCfg.selectable = false;
        txtCfg.mouseEnabled = false;
        _btnConfig.addChild(txtCfg);
        _headerBar.addChild(_btnConfig);

        _btnConfig.addEventListener(MouseEvent.MOUSE_OVER, function(e) txtCfg.textColor = 0x00E5FF);
        _btnConfig.addEventListener(MouseEvent.MOUSE_OUT, function(e) txtCfg.textColor = 0x777777);
        _btnConfig.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            e.stopPropagation();
            ApiToolsWidget.openEditor(def);
        });

        // Collapse Indicator [-] / [+]
        _btnCollapse = new Sprite();
        _btnCollapse.mouseEnabled = false;
        _btnCollapse.mouseChildren = false;
        _btnCollapse.x = ApiToolsWidget.WIDGET_W - 20;
        _btnCollapse.y = 2;

        _txtCollapse = new TextField();
        var colFmt = new TextFormat("_sans", 11, 0x888888, true);
        colFmt.align = TextFormatAlign.CENTER;
        _txtCollapse.defaultTextFormat = colFmt;
        _txtCollapse.text = def.isCollapsed ? "+" : "_";
        _txtCollapse.width = 18;
        _txtCollapse.height = 18;
        _txtCollapse.selectable = false;
        _txtCollapse.mouseEnabled = false;
        _btnCollapse.addChild(_txtCollapse);
        _headerBar.addChild(_btnCollapse);

        // Title bar hover feedback
        _headerBar.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            _titleTxt.textColor = 0xFFFFFF;
            _txtCollapse.textColor = 0xCCCCCC;
        });
        _headerBar.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            _titleTxt.textColor = 0xBBBBBB;
            _txtCollapse.textColor = 0x888888;
        });

        // 3. Button Containers
        _fixedContainer = new Sprite();
        addChild(_fixedContainer);

        _collapsibleContainer = new Sprite();
        addChild(_collapsibleContainer);

        populateButtons();

        // 4. Setup Dragging & Click-to-collapse
        setupDragging();

        // 5. Frame state loop
        addEventListener(Event.ENTER_FRAME, onEnterFrame);

        updateLayout();
        updateButtonVisuals();
    }

    private function populateButtons():Void {
        while (_fixedContainer.numChildren > 0) _fixedContainer.removeChildAt(0);
        while (_collapsibleContainer.numChildren > 0) _collapsibleContainer.removeChildAt(0);
        _buttons = new Map();
        _lastStates = new Map();

        var fixedList:Array<WidgetItemConfig> = [];
        var collapseList:Array<WidgetItemConfig> = [];

        for (it in def.items) {
            if (it.isFixed) fixedList.push(it);
            else collapseList.push(it);
        }

        var btnW:Float = 104;
        var btnH:Float = 26;

        // Render Fixed buttons
        for (idx in 0...fixedList.length) {
            var it = fixedList[idx];
            var tool = ApiToolsWidget.getToolDef(it.toolId);
            if (tool == null) continue;

            var row = Math.floor(idx / 2);
            var col = idx % 2;
            var bx:Float = (col == 0) ? 8 : 118;
            var by:Float = 22 + (row * 30);

            var sp = createButtonSprite(tool, bx, by, btnW, btnH, true);
            _fixedContainer.addChild(sp.btn);
            _buttons.set(tool.id, sp);
        }
        _fixedRows = Math.ceil(fixedList.length / 2);

        // Render Collapsible buttons
        for (idx in 0...collapseList.length) {
            var it = collapseList[idx];
            var tool = ApiToolsWidget.getToolDef(it.toolId);
            if (tool == null) continue;

            var globalIdx = fixedList.length + idx;
            var row = Math.floor(globalIdx / 2);
            var col = globalIdx % 2;
            var bx:Float = (col == 0) ? 8 : 118;
            var by:Float = 22 + (row * 30);

            var sp = createButtonSprite(tool, bx, by, btnW, btnH, false);
            _collapsibleContainer.addChild(sp.btn);
            _buttons.set(tool.id, sp);
        }
        _totalRows = Math.ceil((fixedList.length + collapseList.length) / 2);
        _collapsibleRows = _totalRows - _fixedRows;
    }

    private function createButtonSprite(tool:ToolDef, bx:Float, by:Float, bw:Float, bh:Float, isFixed:Bool):{ btn:Sprite, dot:Shape, lbl:TextField, tool:ToolDef, isFixed:Bool } {
        var btn = new Sprite();
        btn.buttonMode = true;
        btn.mouseChildren = false;
        btn.x = bx;
        btn.y = by;

        var dot = new Shape();
        btn.addChild(dot);

        var lbl = new TextField();
        var fmt = new TextFormat("_sans", 11, 0xCCCCCC, true);
        fmt.align = tool.isToggle ? TextFormatAlign.LEFT : TextFormatAlign.CENTER;
        lbl.defaultTextFormat = fmt;
        lbl.x = tool.isToggle ? 21 : 0;
        lbl.y = 4;
        lbl.width = tool.isToggle ? (bw - 24) : bw;
        lbl.height = 18;
        lbl.selectable = false;
        lbl.mouseEnabled = false;
        btn.addChild(lbl);

        btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (tool.onAction != null) {
                tool.onAction();
            }
        });

        return { btn: btn, dot: dot, lbl: lbl, tool: tool, isFixed: isFixed };
    }

    public function toggleCollapse():Void {
        def.isCollapsed = !def.isCollapsed;
        ApiToolsWidget.saveWidgets();
        if (_txtCollapse != null) {
            _txtCollapse.text = def.isCollapsed ? "+" : "_";
        }
        updateLayout();
    }

    private function updateLayout():Void {
        var h:Float = 22;
        if (def.isCollapsed) {
            if (_fixedRows > 0) {
                h = 22 + (_fixedRows * 30) + 4;
            } else {
                h = 22;
            }
            _collapsibleContainer.visible = false;
        } else {
            h = 22 + (_totalRows * 30) + 4;
            _collapsibleContainer.visible = true;
        }

        _bg.graphics.clear();
        _bg.graphics.beginFill(0x161616, 0.94);
        _bg.graphics.lineStyle(1, 0x2E2E2E);
        _bg.graphics.drawRoundRect(0, 0, ApiToolsWidget.WIDGET_W, h, 6, 6);
        _bg.graphics.endFill();

        _bg.graphics.lineStyle(1, 0x383838, 0.55);
        _bg.graphics.moveTo(3, 1);
        _bg.graphics.lineTo(ApiToolsWidget.WIDGET_W - 3, 1);
    }

    private function updateButtonVisuals():Void {
        for (item in _buttons) {
            var tool = item.tool;
            var isState = (tool.getState != null) ? tool.getState() : false;
            var sInt:Int = isState ? 1 : 0;

            var last = _lastStates.exists(tool.id) ? _lastStates.get(tool.id) : -1;
            if (sInt != last) {
                _lastStates.set(tool.id, sInt);
                renderBtnStyle(item.btn, item.dot, item.lbl, tool, isState);
            }
        }
    }

    private function renderBtnStyle(btn:Sprite, dot:Shape, lbl:TextField, tool:ToolDef, active:Bool):Void {
        var w:Float = 104;
        var h:Float = 26;

        btn.graphics.clear();
        var bg = active ? 0x0C1F11 : 0x161616;
        var border = active ? 0x2ECC71 : 0x2E2E2E;
        var textColor = active ? 0x76FF9F : 0xCCCCCC;

        if (tool.id == "smart_enhance" && active) {
            bg = 0x1E1408;
            border = 0xD97706;
            textColor = 0xFFE082;
        }

        btn.graphics.beginFill(bg, 0.94);
        btn.graphics.lineStyle(1, border);
        btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
        btn.graphics.endFill();

        btn.graphics.lineStyle(1, active ? border : 0x383838, 0.55);
        btn.graphics.moveTo(2, 1);
        btn.graphics.lineTo(w - 2, 1);

        if (dot != null) {
            dot.graphics.clear();
            if (tool.isToggle || (tool.id == "smart_enhance" && active)) {
                var dotX:Float = 11;
                var dotY:Float = h / 2;
                dot.graphics.lineStyle(0, 0, 0);
                if (active) {
                    var glowColor = (tool.id == "smart_enhance") ? 0xFFA726 : 0x2ECC71;
                    var coreColor = (tool.id == "smart_enhance") ? 0xFFB74D : 0x00E676;
                    dot.graphics.beginFill(glowColor, 0.35);
                    dot.graphics.drawCircle(dotX, dotY, 4.5);
                    dot.graphics.endFill();
                    dot.graphics.beginFill(coreColor, 1.0);
                    dot.graphics.drawCircle(dotX, dotY, 2.5);
                    dot.graphics.endFill();
                } else {
                    dot.graphics.beginFill(0x444444, 0.85);
                    dot.graphics.drawCircle(dotX, dotY, 2.5);
                    dot.graphics.endFill();
                }
            }
        }

        if (lbl != null) {
            lbl.text = active ? tool.activeText : tool.inactiveText;
            lbl.textColor = textColor;
        }
    }

    private function setupDragging():Void {
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
            cacheAsBitmap = false;
            dragStartX = e.stageX - this.x;
            dragStartY = e.stageY - this.y;
        });

        _theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (isDragging) {
                var dx = e.stageX - startDownX;
                var dy = e.stageY - startDownY;
                if (Math.abs(dx) > 4 || Math.abs(dy) > 4) {
                    hasDragged = true;
                }
                if (hasDragged) {
                    var nx:Float = Math.round(e.stageX - dragStartX);
                    var ny:Float = Math.round(e.stageY - dragStartY);
                    var sw:Float = _theStage.stageWidth > 0 ? _theStage.stageWidth : 960;
                    var sh:Float = _theStage.stageHeight > 0 ? _theStage.stageHeight : 550;
                    var curH:Float = _bg.height;
                    if (nx < 0) nx = 0;
                    if (ny < 0) ny = 0;
                    if (nx > sw - ApiToolsWidget.WIDGET_W) nx = sw - ApiToolsWidget.WIDGET_W;
                    if (ny > sh - curH) ny = sh - curH;
                    this.x = nx;
                    this.y = ny;
                }
            }
        });

        _theStage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            if (isDragging) {
                isDragging = false;
                cacheAsBitmap = true;
                if (hasDragged) {
                    def.x = Math.round(this.x);
                    def.y = Math.round(this.y);
                    ApiToolsWidget.saveWidgets();
                } else {
                    toggleCollapse();
                }
            }
        });
    }

    private function onEnterFrame(e:Event):Void {
        if (!def.enabled) {
            this.visible = false;
            return;
        }
        var isPanelOpen:Bool = (_overlay != null && (_overlay.currentFrameLabel == "Panel" || ApiDashboardModal.isOpen()));
        this.visible = !isPanelOpen;
        if (this.visible) {
            updateButtonVisuals();
        }
    }

    public function destroy():Void {
        removeEventListener(Event.ENTER_FRAME, onEnterFrame);
    }
}
#else
class ApiToolsWidget {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isWidgetEnabled():Bool return false;
    public static function setWidgetEnabled(enabled:Bool):Void {}
    public static function resetPosition():Void {}
}
#end
