package ui.dashboard.tabs;

#if flash
import ui.ApiDashboardModal;
import ui.ApiNotificationManager;
import ui.DamageNumbers;
import ui.frames.UnitFramesManager;
import ui.dashboard.IDashboardTab;

class UnitFramesTab implements IDashboardTab {
    public function new() {}

    public function render(modal:ApiDashboardModal):Void {
        modal.addInfoBanner("Configure modern ElvUI-style unit frames and custom floating combat text. All frames are portrait-less, lightweight, and freely draggable on screen.");

        modal.addSectionHeader("Unit Frames (ElvUI Style)");

        // 1. Player Unit Frame
        modal.addItemRow(
            "Player Unit Frame",
            "Compact portrait-less frame with Level, Class, HP, Shield, MP, and SP stamina.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = UnitFramesManager.isPlayerFrameEnabled();
                var next = !cur;
                UnitFramesManager.setPlayerFrameEnabled(next);
                ApiNotificationManager.notify("Player Frame: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return UnitFramesManager.isPlayerFrameEnabled();
            }
        );

        // 2. Target Unit Frame
        modal.addItemRow(
            "Target Unit Frame",
            "Compact portrait-less frame with Level, Race, HP, Shield, MP, and cancel target [x].",
            "toggle",
            "",
            false,
            function():Void {
                var cur = UnitFramesManager.isTargetFrameEnabled();
                var next = !cur;
                UnitFramesManager.setTargetFrameEnabled(next);
                ApiNotificationManager.notify("Target Frame: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return UnitFramesManager.isTargetFrameEnabled();
            }
        );

        // Reset Unit Frames Position
        modal.addItemRow(
            "Reset Frame Positions",
            "Reset player and target frames to default screen coordinates.",
            "button",
            "Reset",
            false,
            function():Void {
                UnitFramesManager.resetAllPositions();
            }
        );

        modal.addSectionHeader("Floating Combat Text (Damage Numbers)");

        // 1. Floating Combat Text
        modal.addItemRow(
            "Damage Numbers",
            "Smooth 60 FPS floating combat text centered on units with zero latency.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = DamageNumbers.isEnabled();
                var next = !cur;
                DamageNumbers.setEnabled(next);
                ApiNotificationManager.notify("Damage Numbers: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return DamageNumbers.isEnabled();
            }
        );

        // 2. Filter Mode
        var filterNames = ["Self & Target", "Self Only", "Target Only", "All Units"];
        modal.addItemRow(
            "Filter Mode",
            "Filter which combat hits are shown on screen.",
            "button",
            "",
            false,
            function():Void {
                var nextMode = (DamageNumbers.getFilterMode() + 1) % filterNames.length;
                DamageNumbers.setFilterMode(nextMode);
                ApiNotificationManager.notify("FCT Filter: " + filterNames[nextMode]);
            },
            null,
            function():String {
                return filterNames[DamageNumbers.getFilterMode()];
            }
        );

        // 3. Compact Formatting
        modal.addItemRow(
            "Compact Numbers",
            "Abbreviate large damage numbers (e.g. 1.2M, 45K).",
            "toggle",
            "",
            false,
            function():Void {
                var cur = DamageNumbers.isCompactFormat();
                var next = !cur;
                DamageNumbers.setCompactFormat(next);
                ApiNotificationManager.notify("Compact Numbers: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return DamageNumbers.isCompactFormat();
            }
        );

        // 4. Show Incoming Damage
        modal.addItemRow(
            "Show Damage Taken",
            "Display combat numbers when monsters attack your character.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = DamageNumbers.isShowIncoming();
                var next = !cur;
                DamageNumbers.setShowIncoming(next);
                ApiNotificationManager.notify("Damage Taken: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return DamageNumbers.isShowIncoming();
            }
        );

        // 5. Show DoT Ticks
        modal.addItemRow(
            "Show DoT / HoT Ticks",
            "Display damage over time and heal over time numbers.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = DamageNumbers.isShowDots();
                var next = !cur;
                DamageNumbers.setShowDots(next);
                ApiNotificationManager.notify("DoT / HoT Ticks: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return DamageNumbers.isShowDots();
            }
        );

        // 6. Show Healing
        modal.addItemRow(
            "Show Healing Numbers",
            "Display green health recovery numbers.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = DamageNumbers.isShowHeals();
                var next = !cur;
                DamageNumbers.setShowHeals(next);
                ApiNotificationManager.notify("Healing Numbers: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return DamageNumbers.isShowHeals();
            }
        );
    }
}
#else
class UnitFramesTab implements ui.dashboard.IDashboardTab {
    public function new() {}
    public function render(modal:Dynamic):Void {}
}
#end
