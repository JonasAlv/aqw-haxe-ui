package ui.dashboard.tabs;

#if flash
import com.aqwapi.utils.ApiConfig;
import ui.ApiDashboardModal;
import ui.ApiHudManager;
import ui.ApiMenus;
import ui.ApiNotificationManager;
import ui.dashboard.IDashboardTab;
import ui.topbar.TopBar;
import ui.widgets.WidgetManager;

class HudTab implements IDashboardTab {
    public function new() {}

    public function render(modal:ApiDashboardModal):Void {
        modal.addInfoBanner("Configure the top control bar and optional floating HUD widgets.");

        modal.addSectionHeader("Top Control Bar (Skua Style)");

        modal.addItemRow(
            "Top Bar: Enabled",
            "Anchored top-right bar with Auto, Jump, Players, and Menu dropdown tabs.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = TopBar.isTopBarEnabled();
                var next = !cur;
                TopBar.setTopBarEnabled(next);
                ApiNotificationManager.notify(next ? "Top Bar: Visible" : "Top Bar: Hidden (Floating Menu active)");
            },
            function():Bool {
                return TopBar.isTopBarEnabled();
            }
        );

        modal.addItemRow(
            "Standalone Floating Menu",
            "Always show floating Menu button even when Top Bar is active.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiConfig.getBool("api_floating_menu_enabled", false);
                var next = !cur;
                ApiConfig.setBool("api_floating_menu_enabled", next);
                ApiMenus.updateFloatingMenuVisibility();
                ApiNotificationManager.notify("Floating Menu: " + (next ? "Always Visible" : "Only when Top Bar is hidden"));
            },
            function():Bool {
                return ApiConfig.getBool("api_floating_menu_enabled", false);
            }
        );

        modal.addItemRow(
            "Reset Menu Button Position",
            "Reset standalone floating Menu button position to default (x=80, y=10).",
            "button",
            "Reset",
            false,
            function():Void {
                ApiMenus.resetMenuButtonPosition();
                ApiNotificationManager.notify("Menu button position reset!");
            }
        );

        modal.addSectionHeader("Modular Custom Widgets");

        // Modular Custom Widgets (Managed by WidgetManager)
        var widgets = WidgetManager.getCustomWidgets();
        for (wDef in widgets) {
            modal.addItemRow(
                "HUD: " + wDef.title,
                "Custom widget with " + wDef.items.length + " tools.",
                "toggle",
                "",
                false,
                function():Void {
                    var next = !wDef.enabled;
                    WidgetManager.setCustomWidgetEnabled(wDef.id, next);
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
                    WidgetManager.openEditor(wDef);
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
                WidgetManager.createNewWidget();
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
                WidgetManager.resetAllWidgets();
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
