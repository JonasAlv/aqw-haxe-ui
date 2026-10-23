package ui;

#if flash
import com.aqwapi.Api;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.utils.ApiConfig;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiStorage;
import flash.display.DisplayObject;
import flash.display.Shape;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.events.TimerEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.utils.Timer;
import ui.ApiDashboardModal;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.ScreenFilterManager;
import ui.topbar.StandaloneButtons;
import ui.topbar.TopBar;
import ui.widgets.WidgetManager;

class ApiMenus {
    private static var _injected:Bool = false;
    private static var _stage:Stage = null;
    private static var _host:Dynamic = null;
    private static var _runtimeTimer:Timer = null;
    private static var _accountListener:Dynamic = null;

    public static function isInGame():Bool {
        try {
            if (Api.game == null || Api.game.world == null) return false;
            var w:Dynamic = Api.game.world;
            if (w.myAvatar == null) return false;
            if (w.myAvatar.objData == null || w.myAvatar.objData.strUsername == null) return false;
            var mapStr:String = (w.strMapName != null) ? Std.string(w.strMapName) : "";
            if (mapStr == "" || mapStr == "null") return false;
            if (Api.game.sfc != null && Api.game.sfc.isConnected == false) return false;
            return true;
        } catch (_:Dynamic) {
            return false;
        }
    }

    public static function resetMenuButtonPosition():Void {
        StandaloneButtons.resetPositions();
    }

    public static function updateFloatingMenuVisibility():Void {
        StandaloneButtons.updateVisibility();
    }

    /**
     * Universal mod UI entry point. Works with any container:
     * - The Flash Stage (official AQWorlds launcher)
     * - A DisplayObject/Sprite container (aqw-mobile-mod or any custom host)
     */
    public static function inject(target:Dynamic = null):Void {
        if (_injected) return;

        var theStage:Stage = null;
        if (target != null && Std.isOfType(target, Stage)) {
            theStage = cast target;
        } else if (target != null && target.stage != null) {
            theStage = cast target.stage;
        } else {
            try {
                if (flash.Lib.current != null && flash.Lib.current.stage != null) {
                    theStage = flash.Lib.current.stage;
                }
            } catch (_:Dynamic) {}
        }

        if (theStage != null) {
            initOnStage(theStage, target);
        } else if (target != null && Std.isOfType(target, DisplayObject)) {
            var disp:DisplayObject = cast target;
            var onAdded:Dynamic = null;
            onAdded = function(e:Event):Void {
                disp.removeEventListener(Event.ADDED_TO_STAGE, onAdded);
                if (disp.stage != null) {
                    initOnStage(disp.stage, target);
                }
            };
            disp.addEventListener(Event.ADDED_TO_STAGE, onAdded);
        } else {
            ApiLogger.error("UI", "inject failed: could not resolve stage from target: " + Std.string(target));
        }
    }

    /**
     * Backwards-compatible entry point for standalone launchers.
     */
    public static function injectStandalone(stage:Dynamic):Void {
        inject(stage);
    }

    private static function initOnStage(theStage:Stage, host:Dynamic):Void {
        if (_injected) return;
        _injected = true;
        _stage = theStage;
        _host = host;

        // Initialize ScreenFilterManager (respecting native stage frame rate)
        try {
            ScreenFilterManager.init(theStage);
        } catch (_:Dynamic) {}

        // 1. Initialize notification HUD container
        var apiNotifs = new Sprite();
        apiNotifs.name = "ApiNotificationsHUD";
        apiNotifs.mouseEnabled = false;
        theStage.addChild(apiNotifs);
        ApiNotificationManager.instance.init(apiNotifs);

        // 2. Restore Combat Manager state from persistent settings (account-bound via ApiConfig)
        ApiConfig.reload();

        if (Api.dispatcher != null) {
            _accountListener = function(e:Dynamic):Void {
                ApiConfig.reload();
                var acc = (ApiStorage.currentAccount != null) ? ApiStorage.currentAccount : "";
                if (acc != "") {
                    ApiNotificationManager.notify("Active profile: " + acc);
                }
            };
            Api.dispatcher.addEventListener(ApiEvent.ACCOUNT_CHANGED, _accountListener);
        }

        // 3. Restore loot and AC settings
        var initialLootState = ApiConfig.getBool("api_accept_loot", false);
        if (Api.drop != null) {
            Api.drop.acceptAll = initialLootState;
            if (initialLootState) {
                Api.drop.scanScreenDrops();
                Api.drop.acceptAllDrops();
            }
        }
        var initialACState = ApiConfig.getBool("api_accept_ac_drops", false);
        if (Api.drop != null) {
            Api.drop.acceptACs = initialACState;
            if (initialACState && !initialLootState) {
                Api.drop.scanScreenDrops();
                Api.drop.acceptACDrops();
            }
        }

        // 4. Skua-Style Top Control Bar (Auto, Jump, Players, Menu)
        TopBar.init(theStage, host);

        // 5. Standalone Floating Buttons (Menu, Auto, Jump, Players)
        StandaloneButtons.init(theStage, host);

        // 6. Master Modular Widgets & Widget Creation System (WidgetManager)
        WidgetManager.init(theStage, host);

        // 7. Central API keybind registry and input dispatcher.
        ApiKeybinds.init(theStage, host);

        // 8. Frame hooks (cutscenes, infinite range, death spawn)
        setupFrameHooks(theStage);
    }

    private static function setupFrameHooks(theStage:Stage):Void {
        if (_runtimeTimer != null) return;
        _stage = theStage;
        // State-maintenance work does not need a render-frame callback. Keep a small watchdog
        // for missed game events while avoiding repeated AQW object mutation at 60 FPS.
        _runtimeTimer = new Timer(250);
        _runtimeTimer.addEventListener(TimerEvent.TIMER, onRuntimeTick, false, 0, true);
        _runtimeTimer.start();
    }

    private static function onRuntimeTick(e:TimerEvent):Void {
        if (!isInGame()) return;
        var isScriptRunning = ScriptManager.SINGLETON.isRunning;
        var skipCutscenesActive = isScriptRunning || ApiConfig.getBool("api_skip_cutscenes", false) || ApiConfig.getBool("option_disable_cutscenes", false);
        var infiniteRangeActive = isScriptRunning || ApiConfig.getBool("api_infinite_range", false);
        var dropCombatActive = isScriptRunning || ApiConfig.getBool("api_drop_combat_on_stop", false);
        var deathSpawnActive = isScriptRunning || ApiConfig.getBool("api_death_spawn", false);

        if (Api.map != null) {
            if (Api.map.skipCutscenes != skipCutscenesActive) Api.map.skipCutscenes = skipCutscenesActive;
            if (skipCutscenesActive) Api.map.checkSkipCutscenes();
            if (Api.map.autoDeathSpawn != deathSpawnActive) Api.map.autoDeathSpawn = deathSpawnActive;
            if (deathSpawnActive) Api.map.checkAutoDeathSpawn();
        }
        if (Api.combat != null) {
            if (Api.combat.infiniteRange != infiniteRangeActive) Api.combat.infiniteRange = infiniteRangeActive;
            if (Api.combat.dropCombatOnStop != dropCombatActive) Api.combat.dropCombatOnStop = dropCombatActive;
            if (infiniteRangeActive) Api.combat.applyInfiniteRange();
        }
    }

    public static function dispose():Void {
        if (_runtimeTimer != null) {
            _runtimeTimer.stop();
            _runtimeTimer.removeEventListener(TimerEvent.TIMER, onRuntimeTick);
            _runtimeTimer = null;
        }
        if (_accountListener != null && Api.dispatcher != null) {
            Api.dispatcher.removeEventListener(ApiEvent.ACCOUNT_CHANGED, _accountListener);
            _accountListener = null;
        }
        // These managers own their own stage/container resources. Dispose them
        // before allowing a future injection so a reinjected UI cannot retain
        // stale notification, HUD, or filter listeners.
        try { ApiNotificationManager.instance.destroy(); } catch (_:Dynamic) {}
        try { ApiHudManager.dispose(); } catch (_:Dynamic) {}
        try { ScreenFilterManager.dispose(); } catch (_:Dynamic) {}
        try { ApiKeybinds.dispose(); } catch (_:Dynamic) {}
        _injected = false;
        _stage = null;
        _host = null;
    }
}
#else
class ApiMenus {
    public static function inject(target:Dynamic = null):Void {}
    public static function injectStandalone(stage:Dynamic):Void {}
    public static function resetMenuButtonPosition():Void {}
    public static function updateFloatingMenuVisibility():Void {}
    public static function dispose():Void {}
}
#end
