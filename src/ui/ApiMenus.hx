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
import flash.text.TextField;
import flash.text.TextFormat;
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
            Api.dispatcher.addEventListener(ApiEvent.ACCOUNT_CHANGED, function(e:Dynamic):Void {
                ApiConfig.reload();
                var acc = (ApiStorage.currentAccount != null) ? ApiStorage.currentAccount : "";
                if (acc != "") {
                    ApiNotificationManager.notify("Active profile: " + acc);
                }
            });
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

        // 7. Frame hooks (cutscenes, infinite range, death spawn)
        setupFrameHooks(theStage);
    }

    private static function setupFrameHooks(theStage:Stage):Void {
        theStage.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            var isScriptRunning = ScriptManager.SINGLETON.isRunning;

            // Cutscene skipping (Skua logic - always active during scripts or when enabled in settings)
            var skipCutscenesActive = isScriptRunning || ApiConfig.getBool("api_skip_cutscenes", false) || ApiConfig.getBool("option_disable_cutscenes", false);
            if (Api.map != null) {
                Api.map.skipCutscenes = skipCutscenesActive;
                if (skipCutscenesActive) {
                    Api.map.checkSkipCutscenes();
                }
            }

            // Infinite range & Death spawn tick
            var infiniteRangeActive = isScriptRunning || ApiConfig.getBool("api_infinite_range", false);
            var deathSpawnActive = isScriptRunning || ApiConfig.getBool("api_death_spawn", false);

            if (Api.map != null) {
                Api.map.autoDeathSpawn = deathSpawnActive;
                if (deathSpawnActive) {
                    Api.map.checkAutoDeathSpawn();
                }
            }
            if (Api.combat != null) {
                Api.combat.infiniteRange = infiniteRangeActive;
                if (infiniteRangeActive) {
                    Api.combat.applyInfiniteRange();
                }
            }
        });
    }
}
#else
class ApiMenus {
    public static function inject(target:Dynamic = null):Void {}
    public static function injectStandalone(stage:Dynamic):Void {}
    public static function resetMenuButtonPosition():Void {}
    public static function updateFloatingMenuVisibility():Void {}
}
#end
