package ui.dashboard.tabs;

#if flash
import com.aqwapi.Api;
import com.aqwapi.modules.CombatEngine;
import com.aqwapi.utils.ApiConfig;
import ui.ApiDashboardModal;
import ui.ApiNotificationManager;
import ui.dashboard.IDashboardTab;
import ui.prompts.ApiPrompts;

class AutomationTab implements IDashboardTab {
    public function new() {}

    public function render(modal:ApiDashboardModal):Void {
        modal.addSectionHeader("Smart Combat");

        // 1. Smart Combat Toggle
        modal.addItemRow(
            "Smart Combat",
            "Auto-detects equipped class and executes optimal skill combos and priority rotations.",
            "toggle",
            "",
            false,
            function():Void {
                var current = (Api.combat != null && Api.combat.isRunning());
                var next = !current;
                ApiConfig.setBool("api_smart_combat_active", next);
                if (Api.combat != null) {
                    if (next) {
                        var confClass = ApiConfig.getString("api_smart_class", "Current");
                        var confMode = ApiConfig.getString("api_smart_mode", "Auto");
                        Api.combat.startSmartStandalone(confClass, confMode);
                    } else {
                        Api.combat.stop();
                    }
                }
                ApiNotificationManager.notify("Smart Combat: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.combat != null && Api.combat.isRunning());
            }
        );

        // 2. Global Counter Attack Handler Toggle
        modal.addItemRow(
            "Counter Handler",
            "Automatically pauses attacks when monsters have Counter Attack, Retaliate, Fox or Reflect shields.",
            "toggle",
            "",
            false,
            function():Void {
                var next = !CombatEngine.counterHandler;
                if (Api.combat != null) {
                    Api.combat.enableCounterHandler(next);
                } else {
                    CombatEngine.counterHandler = next;
                }
                ApiConfig.setBool("api_counter_handler", next);
                ApiNotificationManager.notify("Counter Handler: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return CombatEngine.counterHandler;
            }
        );

        // 3. Smart Combat Setup (Standalone)
        modal.addItemRow(
            "Smart Combat Setup",
            "Standalone Smart Combat setup. Choose target class and mode (or set to 'Current').",
            "button",
            "Configure",
            false,
            function():Void {
                ApiPrompts.showSmartCombatPrompt(modal.overlay);
            }
        );

        // 3. Combat Modes Editor
        modal.addItemRow(
            "Combat Modes",
            "Create, edit, and save skill rotations directly to userSkills.json.",
            "button",
            "Editor",
            false,
            function():Void {
                ApiPrompts.showCombatModeEditorPrompt(modal.overlay);
            }
        );

        modal.addSectionHeader("Custom Combos & Quests");

        // 4. Custom Auto-Combat
        modal.addItemRow(
            "Custom Combat",
            "Setup custom skill combo sequences and targeting rules.",
            "button",
            "Configure",
            false,
            function():Void {
                ApiPrompts.showCombatPrompt(modal.overlay);
            }
        );

        // 5. Auto-Quest
        var isQuestAuto = (Api.quest != null && Api.quest.isAutoRunning);
        var qStr = (Api.quest != null) ? Api.quest.autoQuestString : "";
        var questDesc = isQuestAuto
            ? ("Active: Safe looping accept & turn-in (" + (qStr != "" ? qStr : "Running") + ")")
            : "Automatically accept and turn in quests by IDs in the background using safe queue pacing.";
        modal.addItemRow(
            "Auto-Quest",
            questDesc,
            "button",
            isQuestAuto ? "Running" : "Configure",
            isQuestAuto,
            function():Void {
                ApiPrompts.showQuestPrompt(modal.overlay);
            }
        );
    }
}
#else
class AutomationTab implements ui.dashboard.IDashboardTab {
    public function new() {}
    public function render(modal:Dynamic):Void {}
}
#end
