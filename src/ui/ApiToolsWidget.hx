package ui;

#if flash
import flash.events.Event;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiLogger;
import ui.Overlay;
import ui.ApiDashboardModal;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.ApiToolRegistry;
import ui.widgets.CustomWidgetDef;
import ui.widgets.CustomWidgetInstance;
import ui.widgets.WidgetEditorModal;
import com.aqwapi.utils.ApiConfig;

// Re-export typedefs for backward compatibility
typedef WidgetItemConfig = ui.widgets.CustomWidgetDef.WidgetItemConfig;
typedef CustomWidgetDef = ui.widgets.CustomWidgetDef.CustomWidgetDef;

/**
 * Customizable In-Game Tools Widget System Manager.
 *
 * Coordinates creating, configuring, persisting, and managing custom in-game widgets.
 */
class ApiToolsWidget {
    private static var _pocket:Dynamic = null;
    private static var _overlay:Overlay = null;
    private static var _theStage:Dynamic = null;
    private static var _initialized:Bool = false;

    private static var _activeWidgets:Map<String, CustomWidgetInstance> = new Map<String, CustomWidgetInstance>();
    private static var _widgetDefs:Array<CustomWidgetDef> = [];

    private static inline var SETTING_KEY:String = "api_custom_widgets_v1";
    public static inline var WIDGET_W:Float = CustomWidgetInstance.WIDGET_W;

    public static var toolRegistry(get, never):Array<ToolDef>;
    private static inline function get_toolRegistry():Array<ToolDef> {
        return ApiToolRegistry.getAll();
    }

    public static function init(pocket:Dynamic, overlay:Overlay):Void {
        if (_initialized) return;
        _initialized = true;
        _pocket = pocket;
        _overlay = overlay;

        ApiToolRegistry.overlay = overlay;
        ApiToolRegistry.init();

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

    public static inline function getToolDef(id:String):ToolDef {
        return ApiToolRegistry.get(id);
    }

    public static function getDefaultWidgetDef():CustomWidgetDef {
        return {
            id: "quick_tools",
            title: "Quick Tools",
            x: 445,
            y: 82,
            isCollapsed: false,
            enabled: false,
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
        var raw = ApiConfig.getString(SETTING_KEY, "");
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
                trace("Error parsing custom widgets: " + err);
            }
        }
        return [getDefaultWidgetDef()];
    }

    public static function saveWidgets():Void {
        try {
            var raw = haxe.Json.stringify(_widgetDefs);
            ApiConfig.setString(SETTING_KEY, raw);
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
        ApiDashboardModal.refreshCurrentTab();
        openEditor(newDef);
    }

    public static function deleteWidget(id:String):Void {
        for (i in 0..._widgetDefs.length) {
            if (_widgetDefs[i].id == id) {
                _widgetDefs.splice(i, 1);
                break;
            }
        }
        saveWidgets();
        loadAndBuildWidgets();
        ApiNotificationManager.notify("Widget deleted.");
        ApiDashboardModal.refreshCurrentTab();
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
        WidgetEditorModal.show(
            _overlay,
            def,
            function():Array<WidgetItemConfig> {
                return getDefaultWidgetDef().items;
            },
            function():Void {
                saveWidgets();
                loadAndBuildWidgets();
            },
            function(id:String):Void {
                deleteWidget(id);
            }
        );
    }

    // Compatibility helpers for Dashboard Modal
    public static function isWidgetEnabled():Bool {
        return (_widgetDefs.length > 0 && _widgetDefs[0].enabled);
    }

    public static function resetPosition():Void {
        resetAllPositions();
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
