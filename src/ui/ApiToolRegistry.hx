package ui;

#if flash
import com.aqwapi.Api;
import com.aqwapi.modules.CombatEngine;
import com.aqwapi.modules.ScriptManager;
import ui.ApiDashboardModal;
import ui.ApiNotificationManager;
import util.HelperSetting;

typedef ToolDef = {
    id:String,
    name:String,
    defaultLabel:String,
    activeText:String,
    inactiveText:String,
    isToggle:Bool,
    getState:Void->Bool,
    onAction:Void->Void,
    ?defaultHudX:Float,
    ?defaultHudY:Float
};

/**
 * ApiToolRegistry:
 * Central source of truth for all tools, quick actions, and toggles across
 * the Custom Widgets system, Standalone HUD buttons, and Dashboard menus.
 */
class ApiToolRegistry {
    public static var overlay:Dynamic = null;

    private static var _tools:Array<ToolDef> = null;
    private static var _toolMap:Map<String, ToolDef> = null;

    public static function getAll():Array<ToolDef> {
        if (_tools == null) init();
        return _tools;
    }

    public static function get(id:String):ToolDef {
        if (_toolMap == null) init();
        return _toolMap.get(id);
    }

    public static function getHudDefs():Array<ToolDef> {
        var hudTools:Array<ToolDef> = [];
        for (t in getAll()) {
            if (t.defaultHudX != null && t.defaultHudY != null) {
                hudTools.push(t);
            }
        }
        return hudTools;
    }

    public static function init():Void {
        _tools = [
            {
                id: "smart_combat",
                name: "Smart Combat",
                defaultLabel: "Combat",
                activeText: "Combat",
                inactiveText: "Combat",
                isToggle: true,
                defaultHudX: 205,
                defaultHudY: 10,
                getState: function():Bool {
                    return (Api.combat != null && Api.combat.isRunning());
                },
                onAction: function():Void {
                    var current = (Api.combat != null && Api.combat.isRunning());
                    var next = !current;
                    HelperSetting.setBool("api_smart_combat_active", next);
                    if (Api.combat != null) {
                        if (next) {
                            var confClass = HelperSetting.getString("api_smart_class", "Current");
                            var confMode = HelperSetting.getString("api_smart_mode", "Auto");
                            Api.combat.startSmartStandalone(confClass, confMode);
                        } else {
                            Api.combat.stop();
                        }
                    }
                    ApiNotificationManager.notify("Smart Combat: " + (next ? "Enabled" : "Disabled"));
                }
            },
            {
                id: "script_runner",
                name: "Script Runner",
                defaultLabel: "Script",
                activeText: "Script",
                inactiveText: "Script",
                isToggle: true,
                defaultHudX: 318,
                defaultHudY: 10,
                getState: function():Bool {
                    return (ScriptManager.SINGLETON != null && ScriptManager.SINGLETON.isRunning);
                },
                onAction: function():Void {
                    if (ScriptManager.SINGLETON.isRunning) {
                        ScriptManager.SINGLETON.stop();
                        ApiNotificationManager.notify("Script stopped.");
                    } else {
                        ScriptManager.SINGLETON.start();
                        if (ScriptManager.SINGLETON.isRunning) {
                            ApiNotificationManager.notify("Script started.");
                        } else {
                            ApiNotificationManager.notify("No script loaded! Open Script Manager.");
                        }
                    }
                }
            },
            {
                id: "smart_enhance",
                name: "Smart Enhance",
                defaultLabel: "Enhance",
                activeText: "Enhancing...",
                inactiveText: "Enhance",
                isToggle: false,
                defaultHudX: 431,
                defaultHudY: 10,
                getState: function():Bool {
                    return (Api.enhancement != null && Api.enhancement.isBusy);
                },
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
                id: "toggle_bank",
                name: "Bank",
                defaultLabel: "Bank",
                activeText: "Bank",
                inactiveText: "Bank",
                isToggle: false,
                defaultHudX: 544,
                defaultHudY: 10,
                getState: function():Bool return false,
                onAction: function():Void {
                    if (Api.inventory != null) Api.inventory.toggleBank();
                }
            },
            {
                id: "infinite_range",
                name: "Infinite Range",
                defaultLabel: "Range",
                activeText: "Inf Range",
                inactiveText: "Inf Range",
                isToggle: true,
                defaultHudX: 205,
                defaultHudY: 45,
                getState: function():Bool {
                    return (Api.combat != null && Api.combat.infiniteRange);
                },
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
                activeText: "Accept Loot",
                inactiveText: "Accept Loot",
                isToggle: true,
                defaultHudX: 318,
                defaultHudY: 45,
                getState: function():Bool {
                    return (Api.drop != null && Api.drop.acceptAll);
                },
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
                activeText: "Provoke",
                inactiveText: "Provoke",
                isToggle: true,
                defaultHudX: 431,
                defaultHudY: 45,
                getState: function():Bool {
                    return (Api.combat != null && Api.combat.autoProvoke);
                },
                onAction: function():Void {
                    if (Api.combat != null) {
                        var next = !Api.combat.autoProvoke;
                        Api.combat.provokeAll(next);
                        ApiNotificationManager.notify("Provoke All: " + (next ? "ON" : "OFF"));
                    }
                }
            },
            {
                id: "lag_killer",
                name: "Lag Killer",
                defaultLabel: "Lag",
                activeText: "Lag Killer",
                inactiveText: "Lag Killer",
                isToggle: true,
                defaultHudX: 544,
                defaultHudY: 45,
                getState: function():Bool {
                    return (Api.visual != null && Api.visual.lagKiller);
                },
                onAction: function():Void {
                    if (Api.visual != null) {
                        Api.visual.lagKiller = !Api.visual.lagKiller;
                        ApiNotificationManager.notify("Lag Killer: " + (Api.visual.lagKiller ? "ON" : "OFF"));
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
                    ApiDashboardModal.show(overlay);
                }
            },
            {
                id: "accept_acs",
                name: "Accept AC Drops",
                defaultLabel: "ACs",
                activeText: "AC Drops",
                inactiveText: "AC Drops",
                isToggle: true,
                getState: function():Bool {
                    return (Api.drop != null && Api.drop.acceptACs);
                },
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
                activeText: "Cutscenes",
                inactiveText: "Cutscenes",
                isToggle: true,
                getState: function():Bool {
                    return (Api.map != null && Api.map.skipCutscenes);
                },
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
                activeText: "Auto Relog",
                inactiveText: "Auto Relog",
                isToggle: true,
                getState: function():Bool return HelperSetting.getBool("api_auto_relogin", false),
                onAction: function():Void {
                    var cur = HelperSetting.getBool("api_auto_relogin", false);
                    var next = !cur;
                    HelperSetting.setBool("api_auto_relogin", next);
                    ApiNotificationManager.notify("Auto Relogin: " + (next ? "Enabled" : "Disabled"));
                }
            },
            {
                id: "crt_filter",
                name: "CRT Filter",
                defaultLabel: "CRT",
                activeText: "CRT: ON",
                inactiveText: "CRT: OFF",
                isToggle: true,
                getState: function():Bool return ScreenFilterManager.isEnabled(),
                onAction: function():Void {
                    ScreenFilterManager.toggleQuick();
                }
            }
        ];

        _toolMap = new Map<String, ToolDef>();
        for (t in _tools) {
            _toolMap.set(t.id, t);
        }
    }
}
#else
typedef ToolDef = {
    id:String,
    name:String,
    defaultLabel:String,
    activeText:String,
    inactiveText:String,
    isToggle:Bool,
    getState:Void->Bool,
    onAction:Void->Void,
    ?defaultHudX:Float,
    ?defaultHudY:Float
};

class ApiToolRegistry {
    public static var overlay:Dynamic = null;
    public static function getAll():Array<ToolDef> return [];
    public static function get(id:String):ToolDef return null;
    public static function getHudDefs():Array<ToolDef> return [];
    public static function init():Void {}
}
#end
