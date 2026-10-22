package ui.dashboard.tabs;

#if flash
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.utils.ApiLogger;
import ui.ApiDashboardModal;
import ui.ApiNotificationManager;
import ui.dashboard.IDashboardTab;
import ui.prompts.ApiPrompts;

class ScriptsTab implements IDashboardTab {
    public function new() {}

    public function render(modal:ApiDashboardModal):Void {
        modal.addSectionHeader("Script Execution");

        // 1. Script Manager
        modal.addItemRow(
            "Script Manager",
            "Manage, edit, create, save, and run automation scripts.",
            "button",
            "Open",
            true, // Primary red button!
            function():Void {
                ApiPrompts.showScriptManager(modal.overlay);
            }
        );

        // 2. Script Engine State (Run/Stop toggle)
        modal.addItemRow(
            "Script Runner",
            "Controls active script execution. Turn off to immediately abort any running script.",
            "toggle",
            "",
            false,
            function():Void {
                if (ScriptManager.SINGLETON.isRunning) {
                    ScriptManager.SINGLETON.stop();
                    ApiNotificationManager.notify("Script stopped.");
                } else {
                    ScriptManager.SINGLETON.start();
                    if (ScriptManager.SINGLETON.isRunning) {
                        ApiNotificationManager.notify("Script started.");
                    } else {
                        ApiNotificationManager.notify("No script loaded! Open Script Manager to select one.");
                    }
                }
            },
            function():Bool {
                return ScriptManager.SINGLETON.isRunning;
            }
        );

        // 3. Paste Script. Ruffle scripts are managed by the API storage/editor;
        // AIR filesystem browsing is intentionally not part of this runtime.
        modal.addItemRow(
            "Paste Script",
            "Paste raw HScript code and execute it immediately in the runtime engine.",
            "button",
            "Paste",
            false,
            function():Void {
                ApiPrompts.showPastePrompt(modal.overlay);
            }
        );

        modal.addSectionHeader("Automation & Logging");

        // 4. Class Loadouts (For Scripts)
        modal.addItemRow(
            "Class Loadouts (Scripting)",
            "Configure default Farm, Solo, Boss, and Dodge classes for script auto-swapping.",
            "button",
            "Setup",
            false,
            function():Void {
                ApiPrompts.showLoadoutsPrompt(modal.overlay);
            }
        );

        // 5. Clear Log
        modal.addItemRow(
            "Clear Bot Log",
            "Clears the API runtime log and in-memory diagnostics.",
            "button",
            "Clear Log",
            false,
            function():Void {
                ApiLogger.clearLog();
                ApiNotificationManager.notify("API log cleared!");
            }
        );
    }
}
#else
class ScriptsTab implements ui.dashboard.IDashboardTab {
    public function new() {}
    public function render(modal:Dynamic):Void {}
}
#end
