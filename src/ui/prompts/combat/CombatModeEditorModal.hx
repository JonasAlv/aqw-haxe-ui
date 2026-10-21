package ui.prompts.combat;

#if flash
import com.aqwapi.Api;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.prompts.ApiPromptModal;

class CombatModeEditorModal {
    public static function show(overlay:Dynamic, initialClass:String = null, initialMode:String = null):Void {
        var dlg = ApiPromptModal.createDialog(440, 160, "Combat Mode Editor");
        var lbl = ApiPromptModal.createLabel(
            "Auto Combat rotation engine is stripped for Bridge Mode.\nRotations and combat automation will be powered directly by the Rust client core.",
            390, 12, false
        );
        lbl.x = 25;
        lbl.y = 45;
        lbl.textColor = ApiStyle.COLOR_TEXT_MUTED;
        dlg.addChild(lbl);

        var closeBtn = ApiPromptModal.createButton("OK", 100, 28, function():Void {
            ApiPromptModal.close();
        }, true);
        closeBtn.x = 170;
        closeBtn.y = 110;
        dlg.addChild(closeBtn);
    }
}
#else
class CombatModeEditorModal {
    public static function show(overlay:Dynamic, initialClass:String = null, initialMode:String = null):Void {}
}
#end