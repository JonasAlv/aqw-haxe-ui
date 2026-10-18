package ui.dashboard.tabs;

#if flash
import ui.ApiDashboardModal;
import ui.ApiNotificationManager;
import ui.frames.DamageNumbers;
import ui.frames.AuraFramesManager;
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

        // 3. Show Class Names (All Frames)
        modal.addItemRow(
            "Show Class Names",
            "Replaces player usernames with class names across all frames and nameplates.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = UnitFramesManager.isShowClassNames();
                var next = !cur;
                UnitFramesManager.setShowClassNames(next);
                ApiNotificationManager.notify("Show Class Names: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return UnitFramesManager.isShowClassNames();
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

        modal.addSectionHeader("Party & Raid Frames (Grid2 Style)");

        // 1. Party Frames Master Toggle
        modal.addItemRow(
            "Party Frames",
            "Compact square party frames with Healthcolor healthbars, center % indicator, and thin mana bar.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = UnitFramesManager.isPartyFramesEnabled();
                var next = !cur;
                UnitFramesManager.setPartyFramesEnabled(next);
                ApiNotificationManager.notify("Party Frames: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return UnitFramesManager.isPartyFramesEnabled();
            }
        );

        // 2. Horizontal / Vertical Orientation
        modal.addItemRow(
            "Horizontal Layout",
            "Arrange party frames horizontally in a row instead of vertically (default).",
            "toggle",
            "",
            false,
            function():Void {
                var cur = UnitFramesManager.isPartyHorizontal();
                var next = !cur;
                UnitFramesManager.setPartyHorizontal(next);
                ApiNotificationManager.notify("Party Layout: " + (next ? "Horizontal" : "Vertical"));
            },
            function():Bool {
                return UnitFramesManager.isPartyHorizontal();
            }
        );

        // 3. Include Self
        modal.addItemRow(
            "Include Self in Party",
            "Display your own character alongside party members in the grid (useful for healers/buffers).",
            "toggle",
            "",
            false,
            function():Void {
                var cur = UnitFramesManager.isPartyIncludeSelf();
                var next = !cur;
                UnitFramesManager.setPartyIncludeSelf(next);
                ApiNotificationManager.notify("Include Self: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return UnitFramesManager.isPartyIncludeSelf();
            }
        );

        // 4. Show Class Names (Party)
        modal.addItemRow(
            "Show Class Names",
            "Show class names instead of player usernames on party frame tiles (e.g. 'Lord of Order' instead of player name).",
            "toggle",
            "",
            false,
            function():Void {
                var cur = UnitFramesManager.isPartyShowClassNames();
                var next = !cur;
                UnitFramesManager.setPartyShowClassNames(next);
                ApiNotificationManager.notify("Party Class Names: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return UnitFramesManager.isPartyShowClassNames();
            }
        );

        // 5. Test Preview
        modal.addItemRow(
            "Test Party Frames",
            "Previews 4 draggable Grid2 party frames with healthcolor gradients for 15 seconds.",
            "button",
            "Preview",
            false,
            function():Void {
                UnitFramesManager.testPartyFrames();
            },
            function():Bool {
                return false;
            }
        );

        // 6. Reset Party Position
        modal.addItemRow(
            "Reset Party Position",
            "Reset Party & Raid Frames to default position (x: 16, y: 110).",
            "button",
            "Reset",
            false,
            function():Void {
                UnitFramesManager.resetPartyPosition();
            },
            function():Bool {
                return false;
            }
        );

        modal.addSectionHeader("Overhead Nameplates (WoW Style)");

        // 1. Master Nameplates
        modal.addItemRow(
            "Nameplates",
            "Zero-lag overhead nameplates with fast font, replacing native AQW names and health bars.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = UnitFramesManager.isNameplatesEnabled();
                var next = !cur;
                UnitFramesManager.setNameplatesEnabled(next);
                ApiNotificationManager.notify("Nameplates: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return UnitFramesManager.isNameplatesEnabled();
            }
        );

        // 2. Enemy Overhead Bars
        modal.addItemRow(
            "Enemy Overhead Bars",
            "Show red health bars above monsters and hostile units.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = UnitFramesManager.isEnemyNameplatesEnabled();
                var next = !cur;
                UnitFramesManager.setEnemyNameplatesEnabled(next);
                ApiNotificationManager.notify("Enemy Overhead Bars: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return UnitFramesManager.isEnemyNameplatesEnabled();
            }
        );

        // 3. Enemy Names
        modal.addItemRow(
            "Enemy Names",
            "Show names and race subtitles for enemies. Turn OFF for healthbars only.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = UnitFramesManager.isEnemyNamesEnabled();
                var next = !cur;
                UnitFramesManager.setEnemyNamesEnabled(next);
                ApiNotificationManager.notify("Enemy Names: " + (next ? "Enabled" : "Disabled (Bars Only)"));
            },
            function():Bool {
                return UnitFramesManager.isEnemyNamesEnabled();
            }
        );

        // 4. Player Overhead Bars
        modal.addItemRow(
            "Player Overhead Bars",
            "Show green health bars above players.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = UnitFramesManager.isPlayerNameplatesEnabled();
                var next = !cur;
                UnitFramesManager.setPlayerNameplatesEnabled(next);
                ApiNotificationManager.notify("Player Overhead Bars: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return UnitFramesManager.isPlayerNameplatesEnabled();
            }
        );

        // 5. Player Names
        modal.addItemRow(
            "Player Names",
            "Show usernames for players. Turn OFF for healthbars only.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = UnitFramesManager.isPlayerNamesEnabled();
                var next = !cur;
                UnitFramesManager.setPlayerNamesEnabled(next);
                ApiNotificationManager.notify("Player Names: " + (next ? "Enabled" : "Disabled (Bars Only)"));
            },
            function():Bool {
                return UnitFramesManager.isPlayerNamesEnabled();
            }
        );

        // 6. Player Guild Names
        modal.addItemRow(
            "Player Guild Names",
            "Show guild subtitles < Guild > under player names on overhead nameplates.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = UnitFramesManager.isPlayerGuildNamesEnabled();
                var next = !cur;
                UnitFramesManager.setPlayerGuildNamesEnabled(next);
                ApiNotificationManager.notify("Player Guild Names: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return UnitFramesManager.isPlayerGuildNamesEnabled();
            }
        );

        modal.addSectionHeader("Aura Frames (Buffs & Debuffs)");

        // 1. Aura Lag Killer
        modal.addItemRow(
            "Aura Lag Killer",
            "Eliminates heavy 90-frame vector mask sweeps and software rasterization on native auras.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = AuraFramesManager.isLagKillerEnabled();
                var next = !cur;
                AuraFramesManager.setLagKillerEnabled(next);
                ApiNotificationManager.notify("Aura Lag Killer: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return AuraFramesManager.isLagKillerEnabled();
            }
        );

        // 2. Cooldown Timers
        modal.addItemRow(
            "Aura CD Timers",
            "Display numeric countdown seconds in the center of aura icons (e.g. 15s, 4s, 0.8s).",
            "toggle",
            "",
            false,
            function():Void {
                var cur = AuraFramesManager.isCdTimersEnabled();
                var next = !cur;
                AuraFramesManager.setCdTimersEnabled(next);
                ApiNotificationManager.notify("Aura CD Timers: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return AuraFramesManager.isCdTimersEnabled();
            }
        );

        // 3. Target Auras Filter
        modal.addItemRow(
            "Target Auras Filter",
            "Show My Auras Only: Displays only your debuffs and boss mechanics (reflect, shields, stances), hiding other players' clutter.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = AuraFramesManager.isMyAurasOnly();
                var next = !cur;
                AuraFramesManager.setMyAurasOnly(next);
                ApiNotificationManager.notify("Target Auras Filter: " + (next ? "My Auras Only" : "All Auras"));
            },
            function():Bool {
                return AuraFramesManager.isMyAurasOnly();
            }
        );

        // 4. Reset Aura Positions
        modal.addItemRow(
            "Reset Aura Positions",
            "Reset Player and Target aura frame positions to default native coordinates.",
            "button",
            "Reset",
            false,
            function():Void {
                UnitFramesManager.resetAuraPositions();
            },
            function():Bool {
                return false;
            }
        );

        modal.addSectionHeader("Boss Mechanics & Cast Bar");

        // 1. Boss Alert Bar
        modal.addItemRow(
            "Boss Alert Bar",
            "Live countdown cast bar for Ultra Boss charge-ups, wipe mechanics, and destructive attacks.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = UnitFramesManager.isBossMechanicsBarEnabled();
                var next = !cur;
                UnitFramesManager.setBossMechanicsBarEnabled(next);
                ApiNotificationManager.notify("Boss Alert Bar: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return UnitFramesManager.isBossMechanicsBarEnabled();
            }
        );

        // 2. Taunt Expiry Alerts
        modal.addItemRow(
            "Taunt Expiry Alerts",
            "Displays an alert when boss Focus (taunt) drops below 3s so the group knows to re-taunt.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = UnitFramesManager.isTauntAlertsEnabled();
                var next = !cur;
                UnitFramesManager.setTauntAlertsEnabled(next);
                ApiNotificationManager.notify("Taunt Expiry Alerts: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return UnitFramesManager.isTauntAlertsEnabled();
            }
        );

        // 3. Test Preview
        modal.addItemRow(
            "Test Alert Bar",
            "Simulate a live 4-second boss alert bar to preview and drag into position.",
            "button",
            "Preview",
            false,
            function():Void {
                UnitFramesManager.testBossMechanicsBar();
            },
            function():Bool {
                return false;
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

        // 7. Modern Gold & XP
        modal.addItemRow(
            "Modern Gold & XP",
            "Replace clunky Flash popups with smooth, modern floating Gold and XP text.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = DamageNumbers.isModernRewardsEnabled();
                var next = !cur;
                DamageNumbers.setModernRewardsEnabled(next);
                ApiNotificationManager.notify("Modern Gold & XP: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return DamageNumbers.isModernRewardsEnabled();
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
