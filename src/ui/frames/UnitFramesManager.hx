package ui.frames;

#if flash
import ui.ApiNotificationManager;
import com.aqwapi.Api;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.utils.ApiConfig;

/**
 * UnitFramesManager:
 * Coordinator for native unit frames enhancements, party/raid grid, quest tracker,
 * and nameplates.
 *
 * Enhancements:
 * - NativeFramesEnhancer: Formatted HP / Max HP on left, % on right, dynamic health colors (green -> yellow -> red),
 *   and right-click context menu directly on default AQW mcPortrait & mcPortraitTarget.
 * - PartyUnitFrame: Compact Grid2-style party & raid frames.
 * - QuestUnitFrame: Modern sleek docked quest tracker.
 * - NameplateUnitFrame: Clean floating overhead plates.
 * - BossMechanicsBar: BigWigs-style boss cast and cooldown timer bars.
 */
class UnitFramesManager {
    private static var _initialized:Bool = false;

    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {
        if (_initialized) return;
        _initialized = true;

        try { NativeFramesEnhancer.init(pocket, overlay); } catch (e:Dynamic) { trace("[UnitFramesManager] NativeFramesEnhancer init error: " + e); }
        try { NameplateUnitFrame.init(pocket, overlay); } catch (e:Dynamic) { trace("[UnitFramesManager] NameplateUnitFrame init error: " + e); }
        try { AuraFramesManager.init(pocket, overlay); } catch (e:Dynamic) { trace("[UnitFramesManager] AuraFramesManager init error: " + e); }
        try { BossMechanicsBar.init(pocket, overlay); } catch (e:Dynamic) { trace("[UnitFramesManager] BossMechanicsBar init error: " + e); }
        try { PartyUnitFrame.init(pocket, overlay); } catch (e:Dynamic) { trace("[UnitFramesManager] PartyUnitFrame init error: " + e); }
        try { QuestUnitFrame.init(pocket, overlay); } catch (e:Dynamic) { trace("[UnitFramesManager] QuestUnitFrame init error: " + e); }
        try { syncNativeHideUI(); } catch (e:Dynamic) {}

        if (Api.dispatcher != null) {
            Api.dispatcher.addEventListener(ApiEvent.ACCOUNT_CHANGED, function(_:Dynamic):Void {
                reloadFromConfig();
            });
        }
    }

    // =========================================================================
    // NATIVE FRAMES ENHANCER TOGGLES
    // =========================================================================
    public static inline function isNativeFramesEnhanced():Bool {
        return NativeFramesEnhancer.isEnhanced();
    }

    public static inline function setNativeFramesEnhanced(enabled:Bool):Void {
        NativeFramesEnhancer.setEnhanced(enabled);
    }

    public static inline function isShowHpPercentEnabled():Bool {
        return NativeFramesEnhancer.isHpPercentEnabled();
    }

    public static inline function setShowHpPercentEnabled(enabled:Bool):Void {
        NativeFramesEnhancer.setHpPercentEnabled(enabled);
    }

    public static inline function isRightClickMenuEnabled():Bool {
        return NativeFramesEnhancer.isRightClickEnabled();
    }

    public static inline function setRightClickMenuEnabled(enabled:Bool):Void {
        NativeFramesEnhancer.setRightClickEnabled(enabled);
    }

    public static inline function isTargetOfTargetEnabled():Bool {
        return NativeFramesEnhancer.isTargetOfTargetEnabled();
    }

    public static inline function setTargetOfTargetEnabled(enabled:Bool):Void {
        NativeFramesEnhancer.setTargetOfTargetEnabled(enabled);
    }

    public static inline function isMovableFramesEnabled():Bool {
        return NativeFramesEnhancer.isMovableFramesEnabled();
    }

    public static inline function setMovableFramesEnabled(enabled:Bool):Void {
        NativeFramesEnhancer.setMovableFramesEnabled(enabled);
    }

    public static inline function resetNativeFramePositions():Void {
        NativeFramesEnhancer.resetFramePositions();
    }

    // Legacy stubs (custom unit frames replaced by native frames enhancer)
    public static inline function isPlayerFrameEnabled():Bool return false;
    public static inline function setPlayerFrameEnabled(enabled:Bool):Void {}
    public static inline function isTargetFrameEnabled():Bool return false;
    public static inline function setTargetFrameEnabled(enabled:Bool):Void {}

    // =========================================================================
    // NAMEPLATES
    // =========================================================================
    public static inline function isNameplatesEnabled():Bool {
        return NameplateUnitFrame.isWidgetEnabled();
    }

    public static function setNameplatesEnabled(enabled:Bool):Void {
        if (enabled) {
            if (!NameplateUnitFrame.isEnemiesEnabled() && !NameplateUnitFrame.isPlayersEnabled()) {
                NameplateUnitFrame.setEnemiesEnabled(true);
                NameplateUnitFrame.setPlayersEnabled(true);
            }
        }
        NameplateUnitFrame.setWidgetEnabled(enabled);
    }

    public static inline function isEnemyNameplatesEnabled():Bool {
        return NameplateUnitFrame.isEnemiesEnabled();
    }

    public static function setEnemyNameplatesEnabled(enabled:Bool):Void {
        if (enabled && !NameplateUnitFrame.isWidgetEnabled()) {
            NameplateUnitFrame.setWidgetEnabled(true);
        }
        NameplateUnitFrame.setEnemiesEnabled(enabled);
    }

    public static inline function isEnemyNamesEnabled():Bool {
        return NameplateUnitFrame.isEnemyNamesEnabled();
    }

    public static function setEnemyNamesEnabled(enabled:Bool):Void {
        if (enabled && !isNameplatesEnabled()) {
            setNameplatesEnabled(true);
        }
        NameplateUnitFrame.setEnemyNamesEnabled(enabled);
    }

    public static inline function isPlayerNameplatesEnabled():Bool {
        return NameplateUnitFrame.isPlayersEnabled();
    }

    public static function setPlayerNameplatesEnabled(enabled:Bool):Void {
        if (enabled && !NameplateUnitFrame.isWidgetEnabled()) {
            NameplateUnitFrame.setWidgetEnabled(true);
        }
        NameplateUnitFrame.setPlayersEnabled(enabled);
    }

    public static inline function isPlayerNamesEnabled():Bool {
        return NameplateUnitFrame.isPlayerNamesEnabled();
    }

    public static function setPlayerNamesEnabled(enabled:Bool):Void {
        if (enabled && !isNameplatesEnabled()) {
            setNameplatesEnabled(true);
        }
        NameplateUnitFrame.setPlayerNamesEnabled(enabled);
    }

    public static inline function isPlayerGuildNamesEnabled():Bool {
        return NameplateUnitFrame.isShowGuildNames();
    }

    public static function setPlayerGuildNamesEnabled(enabled:Bool):Void {
        NameplateUnitFrame.setShowGuildNames(enabled);
    }

    // =========================================================================
    // BOSS MECHANICS BAR
    // =========================================================================
    public static inline function isBossMechanicsBarEnabled():Bool {
        return BossMechanicsBar.isEnabled();
    }

    public static inline function setBossMechanicsBarEnabled(enabled:Bool):Void {
        BossMechanicsBar.setEnabled(enabled);
    }

    public static inline function isTauntAlertsEnabled():Bool {
        return BossMechanicsBar.isTauntAlertsEnabled();
    }

    public static inline function setTauntAlertsEnabled(enabled:Bool):Void {
        BossMechanicsBar.setTauntAlertsEnabled(enabled);
    }

    public static inline function testBossMechanicsBar():Void {
        BossMechanicsBar.testPreview();
    }

    // =========================================================================
    // PARTY / RAID FRAMES
    // =========================================================================
    public static inline function isPartyFramesEnabled():Bool {
        return PartyUnitFrame.isEnabled();
    }

    public static inline function setPartyFramesEnabled(enabled:Bool):Void {
        PartyUnitFrame.setEnabled(enabled);
    }

    public static inline function isPartyHorizontal():Bool {
        return PartyUnitFrame.isHorizontal();
    }

    public static inline function setPartyHorizontal(horizontal:Bool):Void {
        PartyUnitFrame.setHorizontal(horizontal);
    }

    public static inline function isPartyIncludeSelf():Bool {
        return PartyUnitFrame.isIncludeSelf();
    }

    public static inline function setPartyIncludeSelf(includeSelf:Bool):Void {
        PartyUnitFrame.setIncludeSelf(includeSelf);
    }

    public static inline function isShowClassNames():Bool {
        return ApiConfig.getBool("api_frame_show_class_names", false);
    }

    public static inline function setShowClassNames(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_show_class_names", enabled);
        reloadFromConfig();
    }

    public static inline function isPartyShowClassNames():Bool {
        return PartyUnitFrame.isPartySpecificShowClassNames();
    }

    public static inline function setPartyShowClassNames(enabled:Bool):Void {
        PartyUnitFrame.setShowClassNames(enabled);
        PartyUnitFrame.reloadFromConfig();
    }

    public static inline function testPartyFrames():Void {
        PartyUnitFrame.testPreview();
    }

    // =========================================================================
    // NATIVE UI SYNC
    // =========================================================================
    public static function syncNativeHideUI():Void {
        try {
            var g:Dynamic = com.aqwapi.Api.game;
            if (g == null || g.ui == null) return;

            // Ensure bHideUI is false so native playerAuras, targetAuras, and portrait animations run smoothly
            if (g.litePreference != null && g.litePreference.data != null) {
                if (g.litePreference.data.bHideUI == true) {
                    g.litePreference.data.bHideUI = false;
                    try { g.litePreference.flush(); } catch (_:Dynamic) {}
                }
            }

            // 1. Player portrait: always fully visible
            if (g.ui.mcPortrait != null) {
                g.ui.mcPortrait.alpha = 1.0;
                if (!NativeFramesEnhancer.isMovableFramesEnabled() && !ApiConfig.has("api_pos_player_frame_x")) {
                    g.ui.mcPortrait.y = 0;
                }
                g.ui.mcPortrait.visible = true;
                if (g.world != null && g.world.myAvatar != null && Reflect.isFunction(g.showPortrait)) {
                    try { g.showPortrait(g.world.myAvatar); } catch (_:Dynamic) {}
                }
            }

            // 2. Target portrait: visible whenever an avatar is targeted
            var hasTarget:Bool = (g.world != null && g.world.myAvatar != null && g.world.myAvatar.target != null);
            if (g.ui.mcPortraitTarget != null) {
                g.ui.mcPortraitTarget.alpha = 1.0;
                if (!NativeFramesEnhancer.isMovableFramesEnabled() && !ApiConfig.has("api_pos_target_frame_x")) {
                    g.ui.mcPortraitTarget.y = 0;
                }
                g.ui.mcPortraitTarget.visible = hasTarget;
                if (g.ui.btnTargetPortraitClose != null) g.ui.btnTargetPortraitClose.visible = hasTarget;
                if (hasTarget && Reflect.isFunction(g.showPortraitTarget)) {
                    try { g.showPortraitTarget(g.world.myAvatar.target); } catch (_:Dynamic) {}
                }
            }

            if (g.world != null && isNameplatesEnabled()) {
                try { g.world.showHPBar = false; } catch (_:Dynamic) {}
            }

            NativeFramesEnhancer.updateFrames();
        } catch (_:Dynamic) {}
    }

    public static inline var AURA_ANCHOR_FRAMES:Int = 0;
    public static inline var AURA_ANCHOR_UNITS:Int = 1;
    public static inline var AURA_ANCHOR_FREE:Int = 2;

    public static inline function getPlayerAuraAnchorMode():Int {
        return ApiConfig.getInt("api_frame_player_auras_anchor_mode", AURA_ANCHOR_FRAMES);
    }

    public static inline function setPlayerAuraAnchorMode(mode:Int):Void {
        ApiConfig.setInt("api_frame_player_auras_anchor_mode", mode);
    }

    public static inline function getTargetAuraAnchorMode():Int {
        return ApiConfig.getInt("api_frame_target_auras_anchor_mode", AURA_ANCHOR_FRAMES);
    }

    public static inline function setTargetAuraAnchorMode(mode:Int):Void {
        ApiConfig.setInt("api_frame_target_auras_anchor_mode", mode);
    }

    public static inline function getAuraAnchorMode():Int {
        return getPlayerAuraAnchorMode();
    }

    public static inline function setAuraAnchorMode(mode:Int):Void {
        setPlayerAuraAnchorMode(mode);
        setTargetAuraAnchorMode(mode);
    }

    public static function reloadFromConfig():Void {
        NativeFramesEnhancer.reloadFromConfig();
        NameplateUnitFrame.reloadFromConfig();
        PartyUnitFrame.reloadFromConfig();
        QuestUnitFrame.reloadFromConfig();
        syncNativeHideUI();
    }

    public static function resetAllPositions():Void {
        PartyUnitFrame.resetPosition();
        QuestUnitFrame.resetPosition();
        ApiNotificationManager.notify("Unit frame positions reset!");
    }

    public static function resetPartyPosition():Void {
        PartyUnitFrame.resetPosition();
        ApiNotificationManager.notify("Party frame position reset!");
    }

    public static function resetAuraPositions():Void {
        AuraFramesManager.resetPositions();
        ApiNotificationManager.notify("Aura positions reset!");
    }

    public static inline function isQuestFrameEnabled():Bool {
        return QuestUnitFrame.isWidgetEnabled();
    }

    public static inline function setQuestFrameEnabled(enabled:Bool):Void {
        QuestUnitFrame.setWidgetEnabled(enabled);
    }

    public static function resetQuestPosition():Void {
        QuestUnitFrame.resetPosition();
        ApiNotificationManager.notify("Quest frame position reset!");
    }

    public static inline function isHideQuestProgressTextEnabled():Bool {
        return QuestUnitFrame.isHideProgressTextEnabled();
    }

    public static inline function setHideQuestProgressTextEnabled(enabled:Bool):Void {
        QuestUnitFrame.setHideProgressTextEnabled(enabled);
    }
}
#else
class UnitFramesManager {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isNativeFramesEnhanced():Bool return true;
    public static function setNativeFramesEnhanced(enabled:Bool):Void {}
    public static function isShowHpPercentEnabled():Bool return true;
    public static function setShowHpPercentEnabled(enabled:Bool):Void {}
    public static function isRightClickMenuEnabled():Bool return true;
    public static function setRightClickMenuEnabled(enabled:Bool):Void {}
    public static function isTargetOfTargetEnabled():Bool return true;
    public static function setTargetOfTargetEnabled(enabled:Bool):Void {}
    public static function isMovableFramesEnabled():Bool return true;
    public static function setMovableFramesEnabled(enabled:Bool):Void {}
    public static function resetNativeFramePositions():Void {}
    public static function isPlayerFrameEnabled():Bool return false;
    public static function setPlayerFrameEnabled(enabled:Bool):Void {}
    public static function isTargetFrameEnabled():Bool return false;
    public static function setTargetFrameEnabled(enabled:Bool):Void {}
    public static function isNameplatesEnabled():Bool return false;
    public static function setNameplatesEnabled(enabled:Bool):Void {}
    public static function isEnemyNameplatesEnabled():Bool return false;
    public static function setEnemyNameplatesEnabled(enabled:Bool):Void {}
    public static function isPlayerNameplatesEnabled():Bool return false;
    public static function setPlayerNameplatesEnabled(enabled:Bool):Void {}
    public static function isPlayerGuildNamesEnabled():Bool return true;
    public static function setPlayerGuildNamesEnabled(enabled:Bool):Void {}
    public static function isBossMechanicsBarEnabled():Bool return false;
    public static function setBossMechanicsBarEnabled(enabled:Bool):Void {}
    public static function isTauntAlertsEnabled():Bool return false;
    public static function setTauntAlertsEnabled(enabled:Bool):Void {}
    public static function testBossMechanicsBar():Void {}
    public static function isPartyFramesEnabled():Bool return false;
    public static function setPartyFramesEnabled(enabled:Bool):Void {}
    public static function isPartyHorizontal():Bool return false;
    public static function setPartyHorizontal(horizontal:Bool):Void {}
    public static function isPartyIncludeSelf():Bool return false;
    public static function setPartyIncludeSelf(includeSelf:Bool):Void {}
    public static function isShowClassNames():Bool return false;
    public static function setShowClassNames(enabled:Bool):Void {}
    public static function isPartyShowClassNames():Bool return false;
    public static function setPartyShowClassNames(enabled:Bool):Void {}
    public static function testPartyFrames():Void {}
    public static function isQuestFrameEnabled():Bool return false;
    public static function setQuestFrameEnabled(enabled:Bool):Void {}
    public static function isHideQuestProgressTextEnabled():Bool return false;
    public static function setHideQuestProgressTextEnabled(enabled:Bool):Void {}
    public static function resetQuestPosition():Void {}
    public static function reloadFromConfig():Void {}
    public static function resetAllPositions():Void {}
    public static function resetPartyPosition():Void {}
    public static function resetAuraPositions():Void {}
}
#end
