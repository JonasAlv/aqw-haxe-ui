package ui;

#if flash
import ui.widgets.WidgetManager;
import ui.widgets.CustomWidgetDef;

/**
 * ApiMenuHubWidget:
 * Facade preserving 100% backward compatibility with existing tabs and external calls,
 * delegating directly to the centralized WidgetManager.
 */
class ApiMenuHubWidget {
    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {
        WidgetManager.init(pocket, overlay);
    }

    public static inline function createNewWidget():Void {
        WidgetManager.createNewWidget();
    }

    public static inline function getWidgets():Array<CustomWidgetDef> {
        return WidgetManager.getCustomWidgets();
    }

    public static inline function openEditor(def:CustomWidgetDef):Void {
        WidgetManager.openEditor(def);
    }

    public static inline function deleteWidget(id:String):Void {
        WidgetManager.deleteWidget(id);
    }

    public static inline function setWidgetEnabled(idOrEnabled:Dynamic, ?enabledVal:Null<Bool>):Void {
        WidgetManager.setCustomWidgetEnabled(idOrEnabled, enabledVal);
    }

    public static inline function isCombatWidgetEnabled():Bool {
        return WidgetManager.isCombatWidgetEnabled();
    }

    public static inline function setCombatWidgetEnabled(enabled:Bool):Void {
        WidgetManager.setCombatWidgetEnabled(enabled);
    }

    public static inline function resetCombatWidgetPosition():Void {
        WidgetManager.resetCombatWidgetPosition();
    }

    public static inline function openCombatConfig():Void {
        WidgetManager.openCombatConfig();
    }

    public static inline function isJumpWidgetEnabled():Bool {
        return WidgetManager.isJumpWidgetEnabled();
    }

    public static inline function setJumpWidgetEnabled(enabled:Bool):Void {
        WidgetManager.setJumpWidgetEnabled(enabled);
    }

    public static inline function resetJumpWidgetPosition():Void {
        WidgetManager.resetJumpWidgetPosition();
    }

    public static inline function openJumpConfig():Void {
        WidgetManager.openJumpConfig();
    }

    public static inline function isPlayersWidgetEnabled():Bool {
        return WidgetManager.isPlayersWidgetEnabled();
    }

    public static inline function setPlayersWidgetEnabled(enabled:Bool):Void {
        WidgetManager.setPlayersWidgetEnabled(enabled);
    }

    public static inline function resetPlayersWidgetPosition():Void {
        WidgetManager.resetPlayersWidgetPosition();
    }

    public static inline function openPlayersConfig():Void {
        WidgetManager.openPlayersConfig();
    }

    public static inline function resetPosition():Void {
        resetAllWidgets();
    }

    public static inline function resetAllWidgets():Void {
        WidgetManager.resetAllWidgets();
    }
}
#else
class ApiMenuHubWidget {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function createNewWidget():Void {}
    public static function getWidgets():Array<Dynamic> return [];
    public static function openEditor(def:Dynamic):Void {}
    public static function deleteWidget(id:String):Void {}
    public static function setWidgetEnabled(idOrEnabled:Dynamic, ?enabledVal:Null<Bool>):Void {}
    public static function isCombatWidgetEnabled():Bool return false;
    public static function setCombatWidgetEnabled(enabled:Bool):Void {}
    public static function openCombatConfig():Void {}
    public static function isJumpWidgetEnabled():Bool return false;
    public static function setJumpWidgetEnabled(enabled:Bool):Void {}
    public static function openJumpConfig():Void {}
    public static function isPlayersWidgetEnabled():Bool return false;
    public static function setPlayersWidgetEnabled(enabled:Bool):Void {}
    public static function openPlayersConfig():Void {}
    public static function resetPosition():Void {}
    public static function resetAllWidgets():Void {}
}
#end
