package ui;

import ui.widgets.CustomWidgetDef;
import ui.widgets.WidgetManager;

typedef WidgetItemConfig = ui.widgets.CustomWidgetDef.WidgetItemConfig;
typedef CustomWidgetDef = ui.widgets.CustomWidgetDef.CustomWidgetDef;

/**
 * ApiToolsWidget:
 * Backward compatibility facade delegating custom widget management directly to WidgetManager.
 */
class ApiToolsWidget {
    public static inline var WIDGET_W:Float = ui.widgets.CustomWidgetInstance.WIDGET_W;

    public static inline function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {
        WidgetManager.init(pocket, overlay);
    }

    public static inline function getDefaultWidgetDef():CustomWidgetDef {
        return {
            id: "quick_tools",
            title: "Quick Tools",
            x: 445,
            y: 82,
            isCollapsed: false,
            enabled: false,
            items: WidgetManager.getDefaultCustomWidgetItems()
        };
    }

    public static inline function loadWidgets():Array<CustomWidgetDef> {
        return WidgetManager.loadCustomWidgets();
    }

    public static inline function saveWidgets():Void {
        WidgetManager.saveCustomWidgets();
    }

    public static inline function loadAndBuildWidgets():Void {
        WidgetManager.loadAndBuildCustomWidgets();
    }

    public static inline function getWidgets():Array<CustomWidgetDef> {
        return WidgetManager.getCustomWidgets();
    }

    public static inline function createNewWidget():Void {
        WidgetManager.createNewWidget();
    }

    public static inline function deleteWidget(id:String):Void {
        WidgetManager.deleteWidget(id);
    }

    public static inline function setWidgetEnabled(idOrEnabled:Dynamic, ?enabledVal:Null<Bool>):Void {
        WidgetManager.setCustomWidgetEnabled(idOrEnabled, enabledVal);
    }

    public static inline function resetAllPositions():Void {
        WidgetManager.resetAllWidgets();
    }

    public static inline function openEditor(def:CustomWidgetDef):Void {
        WidgetManager.openEditor(def);
    }
}
