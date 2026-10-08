package ui.dashboard.tabs;

#if flash
import ui.ApiDashboardModal;
import ui.ApiHudManager;
import ui.ApiMenuHubWidget;
import ui.ApiNotificationManager;
import ui.dashboard.IDashboardTab;

class HudTab implements IDashboardTab {
    public function new() {}

    public function render(modal:ApiDashboardModal):Void {
        modal.addInfoBanner("Configure floating on-screen widgets and HUD buttons. Widgets can be collapsed with [-]/[+] and freely dragged anywhere on screen. Positions are saved automatically.");

        modal.addSectionHeader("Modular Widgets");

        // 0. HUD: Combat Widget
        modal.addItemRow(
            "HUD: Combat",
            "Floating widget with Attack, Hunt, Class, Mode, and Target controls.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiMenuHubWidget.isCombatWidgetEnabled();
                var next = !cur;
                ApiMenuHubWidget.setCombatWidgetEnabled(next);
                ApiNotificationManager.notify("Combat: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiMenuHubWidget.isCombatWidgetEnabled();
            }
        );

        modal.addItemRow(
            "Configure Combat",
            "Choose options to keep visible when collapsed.",
            "button",
            "Configure",
            false,
            function():Void {
                ApiMenuHubWidget.openCombatConfig();
            }
        );

        // 0b. HUD: Room Navigation Widget
        modal.addItemRow(
            "HUD: Navigation",
            "Floating widget with Map joiner and Room / Pad jump controls.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiMenuHubWidget.isJumpWidgetEnabled();
                var next = !cur;
                ApiMenuHubWidget.setJumpWidgetEnabled(next);
                ApiNotificationManager.notify("Navigation: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiMenuHubWidget.isJumpWidgetEnabled();
            }
        );

        modal.addItemRow(
            "Configure Navigation",
            "Choose options to keep visible when collapsed.",
            "button",
            "Configure",
            false,
            function():Void {
                ApiMenuHubWidget.openJumpConfig();
            }
        );

        // 0c. HUD: Area Players Widget
        modal.addItemRow(
            "HUD: Players",
            "Floating widget listing map players with 1-tap Goto jump.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiMenuHubWidget.isPlayersWidgetEnabled();
                var next = !cur;
                ApiMenuHubWidget.setPlayersWidgetEnabled(next);
                ApiNotificationManager.notify("Players: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiMenuHubWidget.isPlayersWidgetEnabled();
            }
        );

        modal.addItemRow(
            "Configure Players",
            "Choose options to keep visible when collapsed.",
            "button",
            "Configure",
            false,
            function():Void {
                ApiMenuHubWidget.openPlayersConfig();
            }
        );

        // Modular Custom Widgets (Managed by ApiMenuHubWidget)
        var widgets = ApiMenuHubWidget.getWidgets();
        for (wDef in widgets) {
            modal.addItemRow(
                "HUD: " + wDef.title,
                "Custom widget with " + wDef.items.length + " tools.",
                "toggle",
                "",
                false,
                function():Void {
                    var next = !wDef.enabled;
                    ApiMenuHubWidget.setWidgetEnabled(wDef.id, next);
                    ApiNotificationManager.notify("Widget '" + wDef.title + "': " + (next ? "Visible" : "Hidden"));
                },
                function():Bool {
                    return wDef.enabled;
                }
            );

            modal.addItemRow(
                "Configure " + wDef.title,
                "Customize tools, pinned buttons, and title.",
                "button",
                "Configure",
                false,
                function():Void {
                    ApiMenuHubWidget.openEditor(wDef);
                }
            );
        }

        // Add [+ Create Custom Widget] button
        modal.addItemRow(
            "+ Create Custom Widget",
            "Create a new custom floating widget with selected tools.",
            "button",
            "Create",
            false,
            function():Void {
                ApiMenuHubWidget.createNewWidget();
            }
        );

        // Reset Widget Positions
        modal.addItemRow(
            "Reset Widget Positions",
            "Reset all floating widgets to default screen positions.",
            "button",
            "Reset",
            false,
            function():Void {
                ApiMenuHubWidget.resetAllWidgets();
            }
        );

        modal.addSectionHeader("Standalone Buttons");

        // 1. HUD: Smart Combat
        modal.addItemRow(
            "HUD: Smart Combat",
            "Floating button to toggle Smart Combat directly.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("smart_combat");
                var next = !cur;
                ApiHudManager.setButtonEnabled("smart_combat", next);
                ApiNotificationManager.notify("Smart Combat Button: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("smart_combat");
            }
        );

        // 2. HUD: Script Runner
        modal.addItemRow(
            "HUD: Script Runner",
            "Floating button to start or stop running scripts.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("script_runner");
                var next = !cur;
                ApiHudManager.setButtonEnabled("script_runner", next);
                ApiNotificationManager.notify("Script Runner Button: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("script_runner");
            }
        );

        modal.addSectionHeader("Gear & Loot");

        // 3. HUD: Smart Enhance
        modal.addItemRow(
            "HUD: Smart Enhance",
            "Enhance equipped gear for your active class.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("smart_enhance");
                var next = !cur;
                ApiHudManager.setButtonEnabled("smart_enhance", next);
                ApiNotificationManager.notify("Smart Enhance Button: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("smart_enhance");
            }
        );

        // 4. HUD: Infinite Range
        modal.addItemRow(
            "HUD: Infinite Range",
            "Toggle infinite combat attack range.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("infinite_range");
                var next = !cur;
                ApiHudManager.setButtonEnabled("infinite_range", next);
                ApiNotificationManager.notify("Infinite Range Button: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("infinite_range");
            }
        );

        // 5. HUD: Bank
        modal.addItemRow(
            "HUD: Bank",
            "Open or close bank storage with 1 tap.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("toggle_bank");
                var next = !cur;
                ApiHudManager.setButtonEnabled("toggle_bank", next);
                ApiNotificationManager.notify("Bank Button: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("toggle_bank");
            }
        );

        // 6. HUD: Accept Loot
        modal.addItemRow(
            "HUD: Accept Loot",
            "Toggle automatic loot drop pickup.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("accept_loot");
                var next = !cur;
                ApiHudManager.setButtonEnabled("accept_loot", next);
                ApiNotificationManager.notify("Accept Loot Button: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("accept_loot");
            }
        );

        // 7. HUD: Provoke All
        modal.addItemRow(
            "HUD: Provoke All",
            "Provoke all living monsters in the room.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("provoke_all");
                var next = !cur;
                ApiHudManager.setButtonEnabled("provoke_all", next);
                ApiNotificationManager.notify("Provoke All Button: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("provoke_all");
            }
        );

        // 8. HUD: Lag Killer
        modal.addItemRow(
            "HUD: Lag Killer",
            "Toggle performance optimization mode.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("lag_killer");
                var next = !cur;
                ApiHudManager.setButtonEnabled("lag_killer", next);
                ApiNotificationManager.notify("Lag Killer Button: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("lag_killer");
            }
        );

        modal.addSectionHeader("Layout Controls");

        // Reset HUD Button Positions
        modal.addItemRow(
            "Reset HUD Positions",
            "Reset all standalone buttons and floating Menu button to default layout.",
            "button",
            "Reset",
            false,
            function():Void {
                ApiHudManager.resetAllPositions();
                ApiNotificationManager.notify("HUD buttons reset to default layout!");
            }
        );
    }
}
#else
class HudTab implements ui.dashboard.IDashboardTab {
    public function new() {}
    public function render(modal:Dynamic):Void {}
}
#end
