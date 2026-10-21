package ui.widgets;

#if flash
import flash.display.Stage;
import flash.events.Event;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiConfig;
import com.aqwapi.utils.ApiLogger;
import ui.ApiDashboardModal;
import ui.ApiMenus;
import ui.ApiNotificationManager;
import ui.ApiToolRegistry;
import ui.prompts.ApiPromptModal;
import ui.widgets.BaseWidget;
import ui.widgets.CustomWidgetDef;
import ui.widgets.CustomWidgetInstance;
import ui.widgets.WidgetEditorModal;
import ui.frames.UnitFramesManager;
import ui.frames.DamageNumbers;
import ui.ApiHudManager;

/**
 * WidgetManager:
 * Centralized coordinator and lifecycle manager for all in-game floating widgets.
 *
 * Responsibilities:
 * - Registers, instantiates, and tracks built-in and user-created widgets.
 * - Single Event.ENTER_FRAME tick loop on the stage: evaluates game/modal state once
 *   per frame and dispatches updates to active widgets.
 * - Handles persistence and CRUD for custom widgets.
 * - Provides unified manipulation (enable/disable, reset positions, open config modals).
 */
class WidgetManager {
    private static var _theStage:Stage = null;
    private static var _overlay:Dynamic = null;
    private static var _initialized:Bool = false;

    // Registry of all active BaseWidget instances (id -> widget)
    private static var _widgets:Map<String, BaseWidget> = new Map<String, BaseWidget>();
    private static var _widgetList:Array<BaseWidget> = [];

    // Custom widget definitions
    private static var _customWidgetDefs:Array<CustomWidgetDef> = [];
    private static inline var CUSTOM_WIDGETS_KEY:String = "api_custom_widgets_v1";

    public static function init(stageObj:Dynamic, overlayObj:Dynamic):Void {
        if (_initialized) return;
        _initialized = true;
        _overlay = overlayObj;

        ApiToolRegistry.overlay = overlayObj;
        ApiToolRegistry.init();

        var theStage:Dynamic = (stageObj != null && Reflect.hasField(stageObj, "stage") && stageObj.stage != null) ? stageObj.stage : stageObj;

        var attachAll = function(st:Stage):Void {
            if (st == null || _theStage != null) return;
            _theStage = st;

            // 1. Load and build custom widgets
            loadAndBuildCustomWidgets();

            // 2. Subsystem managers
            try { UnitFramesManager.init(st, _overlay); } catch (e:Dynamic) { trace("[WidgetManager] UnitFramesManager init error: " + e); }
            try { DamageNumbers.init(st, _overlay); } catch (e:Dynamic) { trace("[WidgetManager] DamageNumbers init error: " + e); }
            try { ApiHudManager.init(st, _overlay); } catch (e:Dynamic) { trace("[WidgetManager] ApiHudManager init error: " + e); }
            try { ui.helpers.SpellFXOptimizer.init(); } catch (e:Dynamic) {}

            // 3. Single master frame tick loop
            _theStage.addEventListener(Event.ENTER_FRAME, onStageFrame);
        };

        if (theStage != null && Std.isOfType(theStage, Stage)) {
            attachAll(cast theStage);
        } else if (_overlay != null) {
            _overlay.addEventListener(Event.ADDED_TO_STAGE, function(ev:Event):Void {
                if (_overlay.stage != null && _theStage == null) {
                    attachAll(_overlay.stage);
                }
            });
        }
    }

    public static function registerWidget(widget:BaseWidget):Void {
        if (widget == null) return;
        _widgets.set(widget.widgetId, widget);
        if (_widgetList.indexOf(widget) == -1) {
            _widgetList.push(widget);
        }
        if (_theStage != null && widget.parent == null) {
            widget.attach(_theStage, _overlay);
        }
    }

    public static function unregisterWidget(id:String):Void {
        var widget = _widgets.get(id);
        if (widget != null) {
            widget.detach();
            _widgets.remove(id);
            _widgetList.remove(widget);
        }
    }

    public static function getWidget(id:String):BaseWidget {
        return _widgets.get(id);
    }

    public static function getAllWidgets():Array<BaseWidget> {
        return _widgetList.copy();
    }

    // --- Master Per-Frame Tick ---

    private static function onStageFrame(e:Event):Void {
        var inGame = ApiMenus.isInGame();
        if (!inGame) {
            for (w in _widgetList) w.visible = false;
            return;
        }

        var isBlocked = isBlockedByWindowOrModal();
        if (isBlocked) {
            for (w in _widgetList) w.visible = false;
            return;
        }

        for (w in _widgetList) {
            if (w.isEnabled) {
                w.visible = true;
                w.onTick();
            } else {
                w.visible = false;
            }
        }
    }

    public static function isBlockedByWindowOrModal():Bool {
        var isHostPanel = (_overlay != null && Reflect.hasField(_overlay, "currentFrameLabel") && Reflect.field(_overlay, "currentFrameLabel") == "Panel");
        if (isHostPanel) return true;
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

    // --- Custom Widget Management ---

    public static function getDefaultCustomWidgetItems():Array<WidgetItemConfig> {
        return [
            { toolId: "script_runner", isFixed: true },
            { toolId: "infinite_range", isFixed: false },
            { toolId: "accept_loot", isFixed: false },
            { toolId: "provoke_all", isFixed: false },
            { toolId: "toggle_bank", isFixed: false },
            { toolId: "smart_enhance", isFixed: false },
            { toolId: "open_dashboard", isFixed: false }
        ];
    }

    public static function loadCustomWidgets():Array<CustomWidgetDef> {
        var raw:String = ApiConfig.getGlobalString(CUSTOM_WIDGETS_KEY, "");
        if (raw == null || raw == "") {
            raw = ApiConfig.getString(CUSTOM_WIDGETS_KEY, "");
            // Cross-tier migration: if found in legacy account config, persist to global storage
            if (raw != null && raw != "") {
                ApiConfig.setGlobalString(CUSTOM_WIDGETS_KEY, raw);
            }
        }
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
                            var px:Float = (item.x != null) ? Std.parseFloat(Std.string(item.x)) : 445;
                            var py:Float = (item.y != null) ? Std.parseFloat(Std.string(item.y)) : 82;
                            if (Math.isNaN(px)) px = 445;
                            if (Math.isNaN(py)) py = 82;
                            list.push({
                                id: Std.string(item.id),
                                title: (item.title != null && item.title != "") ? Std.string(item.title) : "Quick Tools",
                                x: px,
                                y: py,
                                isCollapsed: (item.isCollapsed == true || item.isCollapsed == 1),
                                enabled: (item.enabled == true || item.enabled == 1),
                                items: itemsArr
                            });
                        }
                    }
                    return list;
                }
            } catch (err:Dynamic) {
                ApiLogger.error("WidgetManager", "Error parsing custom widgets: " + err);
            }
        }
        return [];
    }

    public static function saveCustomWidgets():Void {
        try {
            var raw = haxe.Json.stringify(_customWidgetDefs);
            ApiConfig.setGlobalString(CUSTOM_WIDGETS_KEY, raw);
            ApiConfig.setString(CUSTOM_WIDGETS_KEY, raw);
        } catch (err:Dynamic) {
            ApiLogger.error("WidgetManager", "Error saving custom widgets: " + err);
        }
    }

    public static function loadAndBuildCustomWidgets():Void {
        // Remove existing custom widgets from registry
        var toRemove:Array<String> = [];
        for (w in _widgetList) {
            if (Std.isOfType(w, CustomWidgetInstance)) {
                toRemove.push(w.widgetId);
            }
        }
        for (id in toRemove) {
            unregisterWidget(id);
        }

        // Safety cleanup for any orphaned CustomWidgetInstance directly on stage
        if (_theStage != null) {
            var i = _theStage.numChildren - 1;
            while (i >= 0) {
                var child = _theStage.getChildAt(i);
                if (Std.isOfType(child, CustomWidgetInstance)) {
                    var cWidget:CustomWidgetInstance = cast child;
                    cWidget.detach();
                }
                i--;
            }
        }

        _customWidgetDefs = loadCustomWidgets();

        for (def in _customWidgetDefs) {
            if (def.enabled) {
                var inst = new CustomWidgetInstance(def);
                registerWidget(inst);
            }
        }
    }

    public static function getCustomWidgets():Array<CustomWidgetDef> {
        return _customWidgetDefs;
    }

    public static function createNewWidget():Void {
        var id = "widget_" + Std.string(Date.now().getTime());
        var newDef:CustomWidgetDef = {
            id: id,
            title: "Custom Widget " + (_customWidgetDefs.length + 1),
            x: 445,
            y: 82 + (_customWidgetDefs.length * 30),
            isCollapsed: false,
            enabled: true,
            items: getDefaultCustomWidgetItems()
        };
        openEditor(newDef);
    }

    public static function deleteWidget(id:String):Void {
        for (i in 0..._customWidgetDefs.length) {
            if (_customWidgetDefs[i].id == id) {
                _customWidgetDefs.splice(i, 1);
                break;
            }
        }
        saveCustomWidgets();
        loadAndBuildCustomWidgets();
        ApiNotificationManager.notify("Widget deleted.");
        ApiDashboardModal.refreshCurrentTab();
    }

    public static function setCustomWidgetEnabled(idOrEnabled:Dynamic, ?enabledVal:Null<Bool>):Void {
        if (Std.isOfType(idOrEnabled, Bool)) {
            var en:Bool = cast idOrEnabled;
            if (_customWidgetDefs.length > 0) {
                _customWidgetDefs[0].enabled = en;
                saveCustomWidgets();
                loadAndBuildCustomWidgets();
            }
        } else {
            var id:String = Std.string(idOrEnabled);
            var en:Bool = (enabledVal != null) ? enabledVal : true;
            for (def in _customWidgetDefs) {
                if (def.id == id) {
                    def.enabled = en;
                    break;
                }
            }
            saveCustomWidgets();
            loadAndBuildCustomWidgets();
        }
    }

    public static function openEditor(def:CustomWidgetDef):Void {
        if (_overlay == null || def == null) return;
        WidgetEditorModal.show(
            _overlay,
            def,
            function():Array<WidgetItemConfig> {
                return getDefaultCustomWidgetItems();
            },
            function():Void {
                var found = false;
                for (i in 0..._customWidgetDefs.length) {
                    if (_customWidgetDefs[i].id == def.id) {
                        _customWidgetDefs[i] = def;
                        found = true;
                        break;
                    }
                }
                if (!found) _customWidgetDefs.push(def);

                saveCustomWidgets();
                loadAndBuildCustomWidgets();
                ApiDashboardModal.refreshCurrentTab();
            },
            function(id:String):Void {
                deleteWidget(id);
            }
        );
    }

    public static function resetAllWidgets():Void {
        for (w in _widgetList) {
            w.resetToDefaultPosition();
        }
        for (i in 0..._customWidgetDefs.length) {
            _customWidgetDefs[i].x = 445;
            _customWidgetDefs[i].y = 82 + (i * 35);
        }
        saveCustomWidgets();
        loadAndBuildCustomWidgets();

        UnitFramesManager.resetAllPositions();
        ApiHudManager.resetAllPositions();
        ApiNotificationManager.notify("All widgets reset to default positions!");
    }
}
#else
class WidgetManager {
    public static function init(stageObj:Dynamic, overlayObj:Dynamic):Void {}
    public static function getCustomWidgets():Array<Dynamic> return [];
    public static function setCustomWidgetEnabled(idOrEnabled:Dynamic, ?enabledVal:Null<Bool>):Void {}
    public static function openEditor(def:Dynamic):Void {}
    public static function createNewWidget():Void {}
    public static function resetAllWidgets():Void {}
}
#end
