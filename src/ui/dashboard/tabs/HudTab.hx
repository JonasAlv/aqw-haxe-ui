package ui.dashboard.tabs;

#if flash
import com.aqwapi.utils.ApiConfig;
import ui.ApiDashboardModal;
import ui.ApiHudManager;
import ui.ApiMenus;
import ui.ApiNotificationManager;
import ui.dashboard.IDashboardTab;
import ui.topbar.StandaloneButtons;
import ui.topbar.TopBar;
import ui.widgets.WidgetManager;

class HudTab implements IDashboardTab {
    public function new() {}

    public function render(modal:ApiDashboardModal):Void {
        modal.addInfoBanner("Configure the top control bar and optional floating HUD widgets.");

        modal.addSectionHeader("Top Control Bar (Skua Style)");

        modal.addItemRow(
            "Top Bar: Enabled",
            "Anchored control bar with Auto, Jump, Players, and quick action tabs.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = TopBar.isTopBarEnabled();
                var next = !cur;
                TopBar.setTopBarEnabled(next);
                ApiNotificationManager.notify(next ? "Top Bar: Visible" : "Top Bar: Hidden (Standalone buttons active)");
            },
            function():Bool {
                return TopBar.isTopBarEnabled();
            }
        );

        modal.addItemRow(
            "Top Bar: Orientation",
            "Switch layout style between Horizontal Bar and Vertical Stack.",
            "button",
            TopBar.isVertical() ? "Vertical" : "Horizontal",
            false,
            function():Void {
                var nextVert = !TopBar.isVertical();
                TopBar.setVertical(nextVert);
                ApiNotificationManager.notify("Top Bar Orientation: " + (nextVert ? "Vertical Stack" : "Horizontal Bar"));
                ApiDashboardModal.refreshCurrentTab();
            },
            null,
            function():String {
                return TopBar.isVertical() ? "Vertical" : "Horizontal";
            }
        );

        modal.addItemRow(
            "Top Bar: Lock Position",
            "Lock the top bar in place to prevent accidental dragging with mouse.",
            "toggle",
            "",
            false,
            function():Void {
                var next = !TopBar.isLocked();
                TopBar.setLocked(next);
                ApiNotificationManager.notify("Top Bar: " + (next ? "Position Locked" : "Position Unlocked (Draggable)"));
            },
            function():Bool {
                return TopBar.isLocked();
            }
        );

        modal.addItemRow(
            "Reset Top Bar Position",
            "Snap the top control bar back to default Top Center position.",
            "button",
            "Reset",
            false,
            function():Void {
                TopBar.resetPosition();
                ApiNotificationManager.notify("Top Bar reset to Top Center!");
            }
        );

        modal.addSectionHeader("Top Bar Buttons");

        modal.addItemRow(
            "Top Bar: Auto Button",
            "Show or hide the combat Auto panel dropdown tab.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = TopBar.isButtonVisible("auto", true);
                var next = !cur;
                TopBar.setButtonVisible("auto", next);
                ApiNotificationManager.notify("Top Bar Auto: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return TopBar.isButtonVisible("auto", true);
            }
        );

        modal.addItemRow(
            "Top Bar: Jump Button",
            "Show or hide the Jump & Navigation dropdown tab.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = TopBar.isButtonVisible("jump", true);
                var next = !cur;
                TopBar.setButtonVisible("jump", next);
                ApiNotificationManager.notify("Top Bar Jump: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return TopBar.isButtonVisible("jump", true);
            }
        );

        modal.addItemRow(
            "Top Bar: Players Button",
            "Show or hide the Area Players dropdown tab.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = TopBar.isButtonVisible("players", true);
                var next = !cur;
                TopBar.setButtonVisible("players", next);
                ApiNotificationManager.notify("Top Bar Players: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return TopBar.isButtonVisible("players", true);
            }
        );

        modal.addItemRow(
            "Top Bar: Menu Button",
            "Show or hide the Dashboard Menu button.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = TopBar.isButtonVisible("menu", true);
                var next = !cur;
                TopBar.setButtonVisible("menu", next);
                ApiNotificationManager.notify("Top Bar Menu: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return TopBar.isButtonVisible("menu", true);
            }
        );

        modal.addItemRow(
            "Top Bar: Bank Button",
            "Quick 1-click bank opener on the top bar.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = TopBar.isButtonVisible("bank", false);
                var next = !cur;
                TopBar.setButtonVisible("bank", next);
                ApiNotificationManager.notify("Top Bar Bank: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return TopBar.isButtonVisible("bank", false);
            }
        );

        modal.addSectionHeader("Standalone Control Buttons");

        modal.addItemRow(
            "Standalone: Menu",
            "Floating button to open mod dashboard directly.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = StandaloneButtons.isButtonEnabled("menu");
                var next = !cur;
                StandaloneButtons.setButtonEnabled("menu", next);
                ApiNotificationManager.notify("Standalone Menu: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return StandaloneButtons.isButtonEnabled("menu");
            }
        );

        modal.addItemRow(
            "Standalone: Auto / Hunt",
            "Floating button with live combat LED to toggle Auto panel.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = StandaloneButtons.isButtonEnabled("auto");
                var next = !cur;
                StandaloneButtons.setButtonEnabled("auto", next);
                ApiNotificationManager.notify("Standalone Auto: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return StandaloneButtons.isButtonEnabled("auto");
            }
        );

        modal.addItemRow(
            "Standalone: Jump",
            "Floating button to toggle Jump & Navigation panel.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = StandaloneButtons.isButtonEnabled("jump");
                var next = !cur;
                StandaloneButtons.setButtonEnabled("jump", next);
                ApiNotificationManager.notify("Standalone Jump: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return StandaloneButtons.isButtonEnabled("jump");
            }
        );

        modal.addItemRow(
            "Standalone: Players",
            "Floating button to toggle Area Players panel.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = StandaloneButtons.isButtonEnabled("players");
                var next = !cur;
                StandaloneButtons.setButtonEnabled("players", next);
                ApiNotificationManager.notify("Standalone Players: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return StandaloneButtons.isButtonEnabled("players");
            }
        );

        modal.addItemRow(
            "Reset Standalone Positions",
            "Reset standalone Menu, Auto, Jump, and Players buttons to defaults.",
            "button",
            "Reset",
            false,
            function():Void {
                StandaloneButtons.resetPositions();
                ApiNotificationManager.notify("Standalone button positions reset!");
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

        modal.addSectionHeader("HUD Tool Buttons");

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
