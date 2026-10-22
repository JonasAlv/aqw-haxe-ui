package ui.dashboard.tabs;

#if flash
import ui.ApiDashboardModal;
import ui.ApiKeybinds;
import ui.ApiNotificationManager;
import ui.dashboard.IDashboardTab;

class KeybindsTab implements IDashboardTab {
    public function new() {}

    public function render(modal:ApiDashboardModal):Void {
        modal.addInfoBanner("Bind API actions to keyboard or controller inputs exposed by Ruffle. Defaults are unbound unless shown below.");

        modal.addSectionHeader("Keybind System");
        modal.addItemRow(
            "API Keybinds",
            "Enable or disable every configured API action shortcut.",
            "toggle",
            "",
            false,
            function():Void {
                var next:Bool = !ApiKeybinds.isEnabled();
                ApiKeybinds.setEnabled(next);
                ApiNotificationManager.notify("API Keybinds: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return ApiKeybinds.isEnabled();
            }
        );
        modal.addItemRow(
            "Restore Defaults",
            "Reset all bindings to their default values.",
            "button",
            "Reset",
            false,
            function():Void {
                ApiKeybinds.resetAll();
                ApiDashboardModal.refreshCurrentTab();
            }
        );

        modal.addSectionHeader("API Actions");
        for (action in ApiKeybinds.getActions()) {
            addBindingRow(modal, action.id, action.title, action.description);
        }
    }

    private function addBindingRow(modal:ApiDashboardModal, id:String, title:String, description:String):Void {
        modal.addItemRow(
            title,
            description,
            "button",
            ApiKeybinds.getKeyLabel(id),
            false,
            function():Void {
                ApiKeybinds.beginCapture(id);
            },
            null,
            function():String {
                return ApiKeybinds.getKeyLabel(id);
            }
        );
    }
}
#else
class KeybindsTab implements ui.dashboard.IDashboardTab {
    public function new() {}
    public function render(modal:Dynamic):Void {}
}
#end
