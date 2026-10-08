package ui;

#if flash
import flash.display.Sprite;
import ui.widgets.CombatWidget;
import ui.widgets.JumpWidget;
import ui.widgets.PlayersWidget;
import ui.frames.UnitFramesManager;
import ui.ApiHudManager;
import ui.ApiToolsWidget;
import ui.ApiNotificationManager;
import ui.Overlay;

/**
 * ApiMenuHubWidget:
 * Master Coordinator for all modular in-game widgets & the widget creation system.
 *
 * Architecture:
 * - ApiMenus: Holds the persistent floating Menu button & toggles the fullscreen Dashboard.
 * - ApiDashboardModal: The fullscreen Control Center dashboard.
 * - ApiMenuHubWidget: Holds and coordinates all in-game widgets and the widget creation system.
 *
 * Rules:
 * - All widgets are visible ONLY when in-game (isInGame()), and hidden when Dashboard or host panel is open.
 * - Widgets never snap magnetically to edges and are strictly clamped within screen boundaries (ApiStyle.SCREEN_MARGIN).
 * - Modals opened from dashboard or widgets take top foreground priority.
 */
class ApiMenuHubWidget {
    private static var _pocket:Dynamic = null;
    private static var _overlay:Overlay = null;
    private static var _initialized:Bool = false;

    public static function init(pocket:Dynamic, overlay:Overlay):Void {
        if (_initialized) return;
        _initialized = true;
        _pocket = pocket;
        _overlay = overlay;

        // Initialize all modular widget subsystems
        CombatWidget.init(pocket, overlay);
        JumpWidget.init(pocket, overlay);
        PlayersWidget.init(pocket, overlay);
        UnitFramesManager.init(pocket, overlay);
        DamageNumbers.init(pocket, overlay);
        ApiToolsWidget.init(pocket, overlay);
        ApiHudManager.init(pocket, overlay);
    }

    // --- Widget Creation System & Custom Widgets ---

    public static function createNewWidget():Void {
        ApiToolsWidget.createNewWidget();
    }

    public static function getWidgets():Array<CustomWidgetDef> {
        return ApiToolsWidget.getWidgets();
    }

    public static function openEditor(def:CustomWidgetDef):Void {
        ApiToolsWidget.openEditor(def);
    }

    public static function deleteWidget(id:String):Void {
        ApiToolsWidget.deleteWidget(id);
    }

    public static function setWidgetEnabled(idOrEnabled:Dynamic, ?enabledVal:Null<Bool>):Void {
        ApiToolsWidget.setWidgetEnabled(idOrEnabled, enabledVal);
    }

    // --- Combat & Hunt Widget ---

    public static function isCombatWidgetEnabled():Bool {
        return CombatWidget.isWidgetEnabled();
    }

    public static function setCombatWidgetEnabled(enabled:Bool):Void {
        CombatWidget.setWidgetEnabled(enabled);
    }

    public static function resetCombatWidgetPosition():Void {
        CombatWidget.resetPosition();
    }

    public static function openCombatConfig():Void {
        CombatWidget.openConfigModal();
    }

    // --- Jump / Room Navigation Widget ---

    public static function isJumpWidgetEnabled():Bool {
        return JumpWidget.isWidgetEnabled();
    }

    public static function setJumpWidgetEnabled(enabled:Bool):Void {
        JumpWidget.setWidgetEnabled(enabled);
    }

    public static function resetJumpWidgetPosition():Void {
        JumpWidget.resetPosition();
    }

    public static function openJumpConfig():Void {
        JumpWidget.openConfigModal();
    }

    // --- Area Players Widget ---

    public static function isPlayersWidgetEnabled():Bool {
        return PlayersWidget.isWidgetEnabled();
    }

    public static function setPlayersWidgetEnabled(enabled:Bool):Void {
        PlayersWidget.setWidgetEnabled(enabled);
    }

    public static function resetPlayersWidgetPosition():Void {
        PlayersWidget.resetPosition();
    }

    public static function openPlayersConfig():Void {
        PlayersWidget.openConfigModal();
    }

    // --- Reset All Widgets ---

    public static function resetPosition():Void {
        resetAllWidgets();
    }

    public static function resetAllWidgets():Void {
        CombatWidget.resetPosition();
        JumpWidget.resetPosition();
        PlayersWidget.resetPosition();
        UnitFramesManager.resetAllPositions();
        ApiToolsWidget.resetAllPositions();
        ApiHudManager.resetAllPositions();
        ApiNotificationManager.notify("All widgets reset to default positions!");
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
