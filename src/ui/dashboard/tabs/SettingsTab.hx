package ui.dashboard.tabs;

#if flash
import com.aqwapi.Api;
import com.aqwapi.utils.ApiConfig;
import ui.ApiDashboardModal;
import ui.ApiNotificationManager;
import ui.dashboard.IDashboardTab;
import ui.prompts.ApiPrompts;


class SettingsTab implements IDashboardTab {
    public function new() {}

    public function render(modal:ApiDashboardModal):Void {
        modal.addSectionHeader("Combat & Movement");

        // 1. Infinite Range
        modal.addItemRow(
            "Infinite Range",
            "Attack and use skills across the entire screen without range limits.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiConfig.getBool("api_infinite_range", false);
                var next = !cur;
                ApiConfig.setBool("api_infinite_range", next);
                if (Api.combat != null) {
                    Api.combat.infiniteRange = next;
                    if (next) Api.combat.applyInfiniteRange();
                }
                ApiNotificationManager.notify("Infinite Range: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.combat != null) ? Api.combat.infiniteRange : ApiConfig.getBool("api_infinite_range", false);
            }
        );

        // 2. Provoke All (Cell Farm)
        modal.addItemRow(
            "Provoke All (Cell Farm)",
            "Aggro and magnetize all living monsters in the room simultaneously for rapid clearing.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = (Api.combat != null && Api.combat.autoProvoke);
                var next = !cur;
                if (Api.combat != null) {
                    Api.combat.provokeAll(next);
                }
                ApiNotificationManager.notify("Provoke All: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.combat != null && Api.combat.autoProvoke);
            }
        );

        // 3. Death Spawn
        modal.addItemRow(
            "Death Spawn (Same Room)",
            "Automatically sets your respawn point to your current room so you never walk back on death.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiConfig.getBool("api_death_spawn", false);
                var next = !cur;
                ApiConfig.setBool("api_death_spawn", next);
                if (Api.map != null) Api.map.autoDeathSpawn = next;
                ApiNotificationManager.notify("Death Spawn: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.map != null) ? Api.map.autoDeathSpawn : ApiConfig.getBool("api_death_spawn", false);
            }
        );

        // 4. Skip Cutscenes
        modal.addItemRow(
            "Skip Cutscenes",
            "Automatically cancel cutscene animations whenever they appear.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiConfig.getBool("api_skip_cutscenes", false) || ApiConfig.getBool("option_disable_cutscenes", false);
                var next = !cur;
                ApiConfig.setBool("api_skip_cutscenes", next);
                ApiConfig.setBool("option_disable_cutscenes", next);
                if (Api.map != null) Api.map.skipCutscenes = next;
                ApiNotificationManager.notify("Skip Cutscenes: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.map != null) ? Api.map.skipCutscenes : (ApiConfig.getBool("api_skip_cutscenes", false) || ApiConfig.getBool("option_disable_cutscenes", false));
            }
        );

        // 5. Private Rooms
        modal.addItemRow(
            "Private Rooms",
            "Automatically join private rooms (e.g. map-100000). Turn off to join public rooms.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiConfig.getBool("api_private_rooms", false);
                var next = !cur;
                ApiConfig.setBool("api_private_rooms", next);
                if (Api.map != null) Api.map.usePrivateRoom = next;
                ApiNotificationManager.notify("Private Rooms: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.map != null) ? Api.map.usePrivateRoom : ApiConfig.getBool("api_private_rooms", false);
            }
        );

        modal.addSectionHeader("Loot & Inventory");

        // 6. Accept All Loot
        modal.addItemRow(
            "Accept All Loot",
            "Automatically accept and pick up all dropped items.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiConfig.getBool("api_accept_loot", false);
                var next = !cur;
                ApiConfig.setBool("api_accept_loot", next);
                if (Api.drop != null) {
                    Api.drop.acceptAll = next;
                    if (next) {
                        Api.drop.scanScreenDrops();
                        Api.drop.acceptAllDrops();
                    }
                }
                ApiNotificationManager.notify("Accept All Loot: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.drop != null) ? Api.drop.acceptAll : ApiConfig.getBool("api_accept_loot", false);
            }
        );

        // 7. Accept AC Drops
        modal.addItemRow(
            "Accept AC Drops",
            "Automatically accept all AC-tagged (free storage) items.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiConfig.getBool("api_accept_ac_drops", false);
                var next = !cur;
                ApiConfig.setBool("api_accept_ac_drops", next);
                if (Api.drop != null) {
                    Api.drop.acceptACs = next;
                    if (next) {
                        Api.drop.scanScreenDrops();
                        Api.drop.acceptACDrops();
                    }
                }
                ApiNotificationManager.notify("Accept AC Drops: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.drop != null) ? Api.drop.acceptACs : ApiConfig.getBool("api_accept_ac_drops", false);
            }
        );

        // 8. Manage Blacklist
        modal.addItemRow(
            "Manage Blacklist",
            "Add or remove items from the blacklist. Blacklisted items are never looted and can be mass-sold.",
            "button",
            "Manage",
            false,
            function():Void {
                ApiPrompts.showBlacklistPrompt(modal.overlay);
            }
        );

        // 9. Sell Blacklisted Items
        modal.addItemRow(
            "Sell Blacklisted Items",
            "Sell all unequipped inventory items that are on your blacklist.",
            "button",
            "Sell",
            false,
            function():Void {
                if (Api.blacklist != null) {
                    Api.blacklist.sellBlacklist();
                    ApiNotificationManager.notify("Selling blacklisted items...");
                }
            }
        );

        modal.addSectionHeader("Game Utilities");

        // 10. Toggle Bank
        modal.addItemRow(
            "Open / Close Bank",
            "Open or close your bank storage from anywhere without needing a bank pet.",
            "button",
            "Toggle Bank",
            false,
            function():Void {
                if (Api.inventory != null) Api.inventory.toggleBank();
            }
        );

        // 11. Load Shop by ID
        modal.addItemRow(
            "Load Shop by ID",
            "Load any game shop directly by entering its numeric Shop ID.",
            "button",
            "Load Shop",
            false,
            function():Void {
                ApiPrompts.showShopPrompt(modal.overlay);
            }
        );

        modal.addSectionHeader("Graphics & Performance");

        // Fast Spell FX (1x Low Quality)
        modal.addItemRow(
            "Fast Spell FX (1x Low Quality)",
            "Lowers heavy 4x/3x filter convolution passes on spells to 1x low passes, preserving all original colors and glows without CPU lag.",
            "toggle",
            "",
            false,
            function():Void {
                if (Api.visual != null) {
                    var next = !Api.visual.optimizeSpellFX;
                    Api.visual.optimizeSpellFX = next;
                    ApiNotificationManager.notify("Fast Spell FX: " + (next ? "Enabled (1x Low Pass)" : "Disabled (Native)"));
                }
            },
            function():Bool {
                return (Api.visual != null) ? Api.visual.optimizeSpellFX : true;
            }
        );

        // =========================================================================
        // SCREEN & CRT FILTERS (RETRO RETRO-ARCADE MASKS)
        // =========================================================================
        modal.addSectionHeader("Screen & CRT Filters");

        // 18. CRT Filter Mode
        modal.addItemRow(
            "CRT Filter Preset",
            "Applies hardware-tiled aperture grille or scanlines, converting low-quality vector edges into crisp retro arcade pixel art.",
            "action",
            ScreenFilterManager.getModeLabel(),
            false,
            function():Void {
                ScreenFilterManager.cycleMode();
            },
            null,
            function():String {
                return ScreenFilterManager.getModeLabel();
            }
        );

        // 19. Filter Intensity
        modal.addItemRow(
            "Filter Intensity",
            "Controls the depth and opacity of the phosphor grid and scanline gaps.",
            "action",
            ScreenFilterManager.getIntensityLabel(),
            false,
            function():Void {
                ScreenFilterManager.cycleIntensity();
            },
            null,
            function():String {
                return ScreenFilterManager.getIntensityLabel();
            }
        );

        // 20. Filter Target Layer
        modal.addItemRow(
            "Filter Target Layer",
            "Game World Only applies the filter over characters/maps while keeping custom UI crisp. Full Screen overlays everything.",
            "action",
            ScreenFilterManager.getTargetLabel(),
            false,
            function():Void {
                ScreenFilterManager.cycleTarget();
            },
            null,
            function():String {
                return ScreenFilterManager.getTargetLabel();
            }
        );
    }
}
#else
class SettingsTab implements ui.dashboard.IDashboardTab {
    public function new() {}
    public function render(modal:Dynamic):Void {}
}
#end
