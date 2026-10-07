package ui;

#if flash
import com.aqwapi.Api;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.modules.CombatEngine;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.utils.ApiConfig;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiStorage;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.Vector;
import ui.Overlay;
import ui.option.Button;
import ui.option.Check;
import ui.option.Menu;
import ui.option.Option;
import ui.prompts.ApiPrompts;
import util.HelperSetting;

class ApiMenus {
    private static var _injected:Bool = false;
    private static var _overlay:Overlay;
    private static var _pocket:Dynamic = null;

    public static function isInGame():Bool {
        try {
            if (Api.game == null || Api.game.world == null) return false;
            var w:Dynamic = Api.game.world;
            if (w.myAvatar == null) return false;
            if (w.myAvatar.objData == null || w.myAvatar.objData.strUsername == null) return false;
            var mapStr:String = (w.strMapName != null) ? Std.string(w.strMapName) : "";
            if (mapStr == "" || mapStr == "null") return false;

            var p:Dynamic = (_pocket != null) ? _pocket : untyped __global__["Pocket"].SINGLETON;
            if (p != null && p.gameCore != null && p.gameCore.currentFrame != null) {
                var frame:String = Std.string(p.gameCore.currentFrame);
                if (frame != "Game") return false;
            }
            if (Api.game.sfc != null && Api.game.sfc.isConnected == false) return false;
            return true;
        } catch (_:Dynamic) {
            return false;
        }
    }

    public static function resetMenuButtonPosition():Void {
        ApiMenuHubWidget.resetPosition();
    }

    public static var anthonyMenus:Dynamic;
    public static var apiMenus:Vector<Menu>;
    public static var lastSelectedMenu:Menu = null;

    public static function inject(overlay:Overlay):Void {
        if (_injected) return;
        _injected = true;
        _overlay = overlay;

        var pocket:Dynamic = untyped __global__["Pocket"].SINGLETON;
        if (pocket == null && overlay.parent != null) {
            pocket = overlay.parent;
        }
        _pocket = pocket;

        anthonyMenus = overlay.menus;

        // 1. Initialize notification HUD container
        var apiNotifs = new Sprite();
        overlay.addChild(apiNotifs);
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

        // 3. Build Menu Tabs
        var scriptsMenu = buildScriptsMenu(pocket, overlay);
        var automationMenu = buildAutomationMenu(pocket, overlay);
        var enhancementMenu = buildEnhancementMenu(pocket, overlay);
        var settingsMenu = buildSettingsMenu(pocket, overlay);

        apiMenus = new Vector<Menu>();
        apiMenus.push(scriptsMenu);
        apiMenus.push(automationMenu);
        apiMenus.push(enhancementMenu);
        apiMenus.push(settingsMenu);

        // 4. Handle UI event delegation (restore host menus on showPanelBtn)
        overlay.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (overlay.currentFrameLabel == "Init" && overlay.showPanelBtn != null) {
                var isShowPanelBtn:Bool = false;
                var curr:Dynamic = e.target;
                while (curr != null && curr != overlay) {
                    if (curr == overlay.showPanelBtn) {
                        isShowPanelBtn = true;
                        break;
                    }
                    curr = curr.parent;
                }
                if (isShowPanelBtn) {
                    overlay.menus = anthonyMenus;
                    lastSelectedMenu = null;
                }
            }
        }, true);

        // 5. Restore loot and AC settings
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

        // 6. Master Menu Hub Widget & Screen Widgets
        ApiMenuHubWidget.init(pocket, overlay);
        ApiHudManager.init(pocket, overlay);
        ApiCombatWidget.init(pocket, overlay);
        ApiToolsWidget.init(pocket, overlay);

        // 8. Menu tracking and frame hooks
        setupFrameHooks(pocket, overlay);
    }

    private static function buildScriptsMenu(pocket:Dynamic, overlay:Overlay):Menu {
        var opts = new Vector<Option>();

        opts.push(new Button(null, "Script Manager", "Manage, create, edit, save, and run scripts.", "Open", function(o:Dynamic):Void {
            overlay.gotoAndStop("Init");
            ApiPrompts.showScriptManager(overlay);
        }));

        opts.push(new Button(null, "Paste Script", "Paste a raw text script.", "Paste", function(o:Dynamic):Void {
            overlay.gotoAndStop("Init");
            ApiPrompts.showPastePrompt(overlay);
        }));

        #if air
        opts.push(new Button(null, "Load Script (File)", "Load a script from a text file.", "Load", function(o:Dynamic):Void {
            try {
                var fileCls:Dynamic = untyped __global__["flash.filesystem.File"];
                var fsCls:Dynamic = untyped __global__["flash.filesystem.FileStream"];
                var fmCls:Dynamic = untyped __global__["flash.filesystem.FileMode"];
                var ffCls:Dynamic = untyped __global__["flash.net.FileFilter"];

                var file = fileCls.desktopDirectory;
                file.addEventListener("select", function(ev:Dynamic):Void {
                    var stream = Type.createInstance(fsCls, []);
                    stream.open(file, fmCls.READ);
                    var txt:String = stream.readUTFBytes(stream.bytesAvailable);
                    stream.close();
                    ScriptManager.SINGLETON.loadScript(txt);
                    ApiNotificationManager.notify("Script loaded successfully!");
                });
                var filters = [Type.createInstance(ffCls, ["Script Files (*.txt, *.hscript, *.hx)", "*.txt;*.hscript;*.hx"])];
                file.browseForOpen("Select Script", filters);
            } catch (e:Dynamic) {}
        }));
        #end

        var startScriptCheck = new Check(null, false, "Run Script", "Start or Stop the loaded script.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            if (c.state) {
                ScriptManager.SINGLETON.reset();
                ScriptManager.SINGLETON.start();
            } else {
                ScriptManager.SINGLETON.stop();
            }
        });
        startScriptCheck.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            if (startScriptCheck.state != ScriptManager.SINGLETON.isRunning) {
                startScriptCheck.state = ScriptManager.SINGLETON.isRunning;
                startScriptCheck.syncState();
            }
        });
        opts.push(startScriptCheck);

        var chatLogCheck = new Check(null, ApiLogger.printToChat, "Chat Logger", "Display bot and script logs in the in-game chat box.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            ApiLogger.printToChat = c.state;
        });
        opts.push(chatLogCheck);

        var loadoutsBtn = new Button(null, "Class Loadouts", "Configure your default Farm, Solo, Boss and Dodge classes for script auto-swapping.", "Setup", function(o:Dynamic):Void {
            tryAction("Class Loadouts", function() {
                overlay.gotoAndStop("Init");
                ApiPrompts.showLoadoutsPrompt(overlay);
            });
        });
        opts.push(loadoutsBtn);

        return new Menu("Scripts", opts);
    }

    private static function buildAutomationMenu(pocket:Dynamic, overlay:Overlay):Menu {
        var opts = new Vector<Option>();

        var smartCombatCheck = new Check(null, false, "Smart Combat", "Start smart auto combat.", true, function(o:Dynamic):Void {
            tryAction("Smart Combat", function() {
                var c:Check = cast o;
                if (c.state) {
                    var confClass = ApiConfig.getString("api_smart_class", "Current");
                    var confMode = ApiConfig.getString("api_smart_mode", "Auto");
                    if (Api.combat != null) {
                        Api.combat.startSmartStandalone(confClass, confMode);
                    }
                } else {
                    if (Api.combat != null) Api.combat.stop();
                }
            });
        });
        smartCombatCheck.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            if (Api.combat != null && smartCombatCheck.state != Api.combat.isSmartRunning) {
                smartCombatCheck.state = Api.combat.isSmartRunning;
                smartCombatCheck.syncState();
            }
        });
        opts.push(smartCombatCheck);

        opts.push(new Button(null, "Smart Combat (Setup)", "Configure class and mode for standalone smart combat.", "Setup", function(o:Dynamic):Void {
            tryAction("Smart Combat (Setup)", function() {
                overlay.gotoAndStop("Init");
                ApiPrompts.showSmartCombatPrompt(overlay);
            });
        }));

        opts.push(new Button(null, "Combat Modes", "Create, edit, or delete class skill modes.", "Edit", function(o:Dynamic):Void {
            tryAction("Combat Modes", function() {
                overlay.gotoAndStop("Init");
                ApiPrompts.showCombatModeEditorPrompt(overlay);
            });
        }));

        var customCombatCheck = new Check(null, false, "Custom Combat", "Start custom combat sequence.", true, function(o:Dynamic):Void {
            tryAction("Custom Combat", function() {
                var c:Check = cast o;
                if (c.state) {
                    overlay.gotoAndStop("Init");
                    ApiPrompts.showCombatPrompt(overlay);
                } else {
                    if (Api.combat != null) Api.combat.stop();
                }
            });
        });
        customCombatCheck.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            if (Api.combat != null && customCombatCheck.state != Api.combat.isCustomRunning) {
                customCombatCheck.state = Api.combat.isCustomRunning;
                customCombatCheck.syncState();
            }
        });
        opts.push(customCombatCheck);

        return new Menu("Automation", opts);
    }

    private static function buildEnhancementMenu(pocket:Dynamic, overlay:Overlay):Menu {
        var opts = new Vector<Option>();

        // 1. One-Click Smart Enhance (Equipped)
        opts.push(new Button(null, "Smart Enhance (Equipped)", "Auto-detects class & unlocks, then enhances equipped weapon, class, helm, and cape to the optimal build.", "Enhance", function(o:Dynamic):Void {
            if (Api.enhancement != null) {
                if (Api.enhancement.isBusy) {
                    ApiNotificationManager.notify("Enhancement queue is currently busy!");
                    return;
                }
                var curClass = (Api.player != null && Api.player.className != null && Api.player.className != "") ? Api.player.className : "Equipped Class";
                ApiNotificationManager.notify("SmartEnhancing " + curClass + "...");
                Api.enhancement.smartEnhance(null, function():Void {
                    ApiNotificationManager.notify("SmartEnhance finished!");
                });
            }
        }));

        // 2. Custom Enhance Gear (Modal Dialog)
        opts.push(new Button(null, "Custom Enhance Gear...", "Choose custom base enhancement types and Awe/Forge special traits for equipped gear.", "Configure", function(o:Dynamic):Void {
            overlay.gotoAndStop("Init");
            ApiPrompts.showCustomEnhancePrompt(overlay);
        }));

        var lvl50Shops = [
            { name: "Healer Enh", id: 762 },
            { name: "Lucky Enh", id: 763 },
            { name: "Spellbreaker Enh", id: 764 },
            { name: "Wizard Enh", id: 765 },
            { name: "Hybrid Enh", id: 766 },
            { name: "Thief Enh", id: 767 },
            { name: "Fighter Enh", id: 768 }
        ];
        var aweShops = [
            { name: "Fighter Awe", id: 635 },
            { name: "Wizard Awe", id: 636 },
            { name: "Thief Awe", id: 637 },
            { name: "Healer Awe", id: 638 },
            { name: "Lucky Awe", id: 639 },
            { name: "Hybrid Awe", id: 633 }
        ];
        var forgeShops = [
            { name: "Weapon Enh", id: 2142 },
            { name: "Cape Enh", id: 2143 },
            { name: "Helmet Enh", id: 2164 }
        ];

        opts.push(new Button(null, "Lvl 50+ Enhancements", "Load level 50+ normal enhancements.", "Open", function(o:Dynamic):Void {
            overlay.gotoAndStop("Init");
            ApiPrompts.showEnhancementPrompt(overlay, "Lvl 50+ Enhancements", lvl50Shops, false);
        }));

        opts.push(new Button(null, "Awe Enhancements", "Load Awe enhancements.", "Open", function(o:Dynamic):Void {
            overlay.gotoAndStop("Init");
            ApiPrompts.showEnhancementPrompt(overlay, "Awe Enhancements", aweShops, false);
        }));

        opts.push(new Button(null, "Forge Enhancements", "Load Forge enhancements (auto-joins /forge).", "Open", function(o:Dynamic):Void {
            overlay.gotoAndStop("Init");
            ApiPrompts.showEnhancementPrompt(overlay, "Forge Enhancements", forgeShops, true);
        }));

        return new Menu("Enhancements", opts);
    }

    private static function buildSettingsMenu(pocket:Dynamic, overlay:Overlay):Menu {
        var opts = new Vector<Option>();

        opts.push(new Button(null, "Load Shop", "Load a shop by its ID.", "Load", function(o:Dynamic):Void {
            overlay.gotoAndStop("Init");
            ApiPrompts.showShopPrompt(overlay);
        }));

        opts.push(new Button(null, "Toggle Bank", "Open or close your bank.", "Toggle", function(o:Dynamic):Void {
            if (Api.inventory != null) Api.inventory.toggleBank();
        }));

        opts.push(new Check("api_infinite_range", false, "Infinite Range", "Attack and use skills across the entire screen without range limits.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            ApiConfig.setBool("api_infinite_range", c.state);
            if (Api.combat != null) {
                Api.combat.infiniteRange = c.state;
                if (c.state) Api.combat.applyInfiniteRange();
            }
        }));

        opts.push(new Check("api_death_spawn", false, "Death Spawn (Same Room)", "Automatically sets your respawn point to your current room so you never walk back on death.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            ApiConfig.setBool("api_death_spawn", c.state);
            if (Api.map != null) Api.map.autoDeathSpawn = c.state;
        }));

        opts.push(new Check("api_skip_cutscenes", false, "Skip Cutscenes", "Automatically cancel cutscene animations whenever they appear.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            ApiConfig.setBool("api_skip_cutscenes", c.state);
            HelperSetting.setBool("option_disable_cutscenes", c.state);
            if (Api.map != null) Api.map.skipCutscenes = c.state;
        }));

        opts.push(new Check("api_private_rooms", true, "Private Rooms", "Automatically join private rooms (e.g. map-100000). Uncheck to join public rooms.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            ApiConfig.setBool("api_private_rooms", c.state);
            if (Api.map != null) Api.map.usePrivateRoom = c.state;
        }));

        opts.push(new Check("api_accept_loot", false, "Accept All Loot", "Automatically accept all dropped items.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            ApiConfig.setBool("api_accept_loot", c.state);
            if (Api.drop != null) {
                Api.drop.acceptAll = c.state;
                if (c.state) {
                    Api.drop.scanScreenDrops();
                    Api.drop.acceptAllDrops();
                }
            }
        }));

        opts.push(new Check("api_accept_ac_drops", false, "Accept AC Drops", "Automatically accept all AC-tagged (coin) drops.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            ApiConfig.setBool("api_accept_ac_drops", c.state);
            if (Api.drop != null) {
                Api.drop.acceptACs = c.state;
                if (c.state) {
                    Api.drop.scanScreenDrops();
                    Api.drop.acceptACDrops();
                }
            }
        }));

        opts.push(new Button(null, "Manage Blacklist", "Add or remove items from the blacklist. Blacklisted items are never looted and can be mass-sold.", "Manage", function(o:Dynamic):Void {
            overlay.gotoAndStop("Init");
            ApiPrompts.showBlacklistPrompt(overlay);
        }));

        opts.push(new Button(null, "Sell Blacklisted Items", "Sell all unequipped inventory items that are on your blacklist.", "Sell", function(o:Dynamic):Void {
            if (Api.blacklist != null) {
                Api.blacklist.sellBlacklist();
                ApiNotificationManager.notify("Selling blacklisted items...");
            }
        }));

        opts.push(new Check("api_lag_killer", false, "Lag Killer (FPS Boost)", "Master performance switch. Disables other players, skill FX, and freezes monster loops.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            ApiConfig.setBool("api_lag_killer", c.state);
            if (Api.visual != null) {
                Api.visual.lagKiller = c.state;
            }
        }));

        opts.push(new Check("api_hide_players", false, "Hide Other Players", "Hides all other player character models in the room.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            ApiConfig.setBool("api_hide_players", c.state);
            if (Api.visual != null) {
                Api.visual.hidePlayers = c.state;
            }
        }));

        opts.push(new Check("api_disable_skill_anims", false, "Disable Skill FX", "Disables all skill spell effects and projectile particles.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            ApiConfig.setBool("api_disable_skill_anims", c.state);
            if (Api.visual != null) {
                Api.visual.disableSkillAnims = c.state;
            }
        }));

        opts.push(new Check("api_disable_mon_anims", false, "Freeze Monster Anims", "Halts animation frame loops on monsters without affecting hitboxes.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            ApiConfig.setBool("api_disable_mon_anims", c.state);
            if (Api.visual != null) {
                Api.visual.disableMonsterAnims = c.state;
            }
        }));

        opts.push(new Check("api_clean_arena", false, "Clean Arena", "Hides static background map artwork.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            ApiConfig.setBool("api_clean_arena", c.state);
            if (Api.visual != null) {
                Api.visual.cleanArena = c.state;
            }
        }));

        return new Menu("Settings", opts);
    }



    private static function setupFrameHooks(pocket:Dynamic, overlay:Overlay):Void {
        overlay.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (overlay.currentFrameLabel == "Panel" && overlay.contentMenu != null) {
                var c:Dynamic = e.target;
                while (c != null && c != overlay.contentMenu && c != overlay) {
                    if (Std.isOfType(c, Menu)) {
                        lastSelectedMenu = cast c;
                        break;
                    }
                    c = c.parent;
                }
            }
        }, false);

        overlay.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            var isScriptRunning = ScriptManager.SINGLETON.isRunning;

            // Cutscene skipping (Skua logic - always active during scripts or when enabled in settings)
            var skipCutscenesActive = isScriptRunning || ApiConfig.getBool("api_skip_cutscenes", false) || HelperSetting.getBool("option_disable_cutscenes", false);
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

            // Hide host UI branding when API menu is open
            if (overlay.currentFrameLabel == "Panel") {
                for (i in 0...overlay.numChildren) {
                    var child = overlay.getChildAt(i);
                    try {
                        if (Reflect.hasField(child, "text") && Reflect.field(child, "text") == "Pocket") {
                            child.visible = false;
                        }
                    } catch (err:Dynamic) {}
                }

                var isApiMenu = (overlay.menus == apiMenus);
                if (overlay.updateBtn != null) overlay.updateBtn.visible = !isApiMenu;
                if (overlay.discordBtn != null) overlay.discordBtn.visible = !isApiMenu;
                if (overlay.reportBugBtn != null) overlay.reportBugBtn.visible = !isApiMenu;
            }
        });
    }

    private static function tryAction(action:String, fn:Void->Void):Void {
        try {
            fn();
        } catch (err:Dynamic) {
            ApiLogger.error("UI", action + " error: " + Std.string(err));
            Api.notify(action + " error: " + Std.string(err));
        }
    }
}
#else
class ApiMenus {
    public static function inject(overlay:Dynamic):Void {}
}
#end

