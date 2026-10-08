package ui.frames;

#if flash
import ui.Overlay;
import ui.ApiNotificationManager;
import com.aqwapi.Api;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.utils.ApiConfig;

/**
 * UnitFramesManager:
 * Coordinator for modern, portrait-less, compact unit frames and aura frames (ElvUI / oUF style).
 *
 * Coordinates:
 * - PlayerUnitFrame: [Level] Username - Class R<Rank>, HP + Shield, MP, SP stamina line.
 * - TargetUnitFrame: [Level] TargetName - Race/Class, HP + Shield, MP, [x] cancel target.
 * - PlayerAuraFrame: 24x24 px aura tiles with buff/debuff color borders, stack counts, duration timers.
 * - TargetAuraFrame: Target's active debuffs/buffs, stacks, and timers.
 */
class UnitFramesManager {
    private static var _initialized:Bool = false;

    public static function init(pocket:Dynamic, overlay:Overlay):Void {
        if (_initialized) return;
        _initialized = true;

        PlayerUnitFrame.init(pocket, overlay);
        TargetUnitFrame.init(pocket, overlay);
        PlayerAuraFrame.init(pocket, overlay);
        TargetAuraFrame.init(pocket, overlay);
        syncNativeHideUI();

        if (Api.dispatcher != null) {
            Api.dispatcher.addEventListener(ApiEvent.ACCOUNT_CHANGED, function(_:Dynamic):Void {
                reloadFromConfig();
            });
        }
    }

    public static inline function isPlayerFrameEnabled():Bool {
        return PlayerUnitFrame.isWidgetEnabled();
    }

    public static inline function setPlayerFrameEnabled(enabled:Bool):Void {
        PlayerUnitFrame.setWidgetEnabled(enabled);
        syncNativeHideUI();
    }

    public static inline function isTargetFrameEnabled():Bool {
        return TargetUnitFrame.isWidgetEnabled();
    }

    public static inline function setTargetFrameEnabled(enabled:Bool):Void {
        TargetUnitFrame.setWidgetEnabled(enabled);
        syncNativeHideUI();
    }

    public static inline function isPlayerAurasEnabled():Bool {
        return PlayerAuraFrame.isWidgetEnabled();
    }

    public static inline function setPlayerAurasEnabled(enabled:Bool):Void {
        PlayerAuraFrame.setWidgetEnabled(enabled);
    }

    public static inline function isTargetAurasEnabled():Bool {
        return TargetAuraFrame.isWidgetEnabled();
    }

    public static inline function setTargetAurasEnabled(enabled:Bool):Void {
        TargetAuraFrame.setWidgetEnabled(enabled);
    }

    /**
     * Synchronizes native AQW portrait suppression with our custom unit frames.
     * When any custom unit frame (Player or Target) is active:
     * - Re-parents default pAurasUI / tAurasUI to g.ui so they are not tied to mcPortrait
     * - Keeps bHideUI = false so default aura frames continue processing all packets and animations
     * - Hides native mcPortrait, mcPortraitTarget, and areaList
     * When all custom unit frames are disabled:
     * - Restores native portraits and areaList
     */
    public static function syncNativeHideUI():Void {
        try {
            var g:Dynamic = com.aqwapi.Api.game;
            if (g == null || g.ui == null) return;

            var shouldHide:Bool = (isPlayerFrameEnabled() || isTargetFrameEnabled());

            // Ensure bHideUI is false so native playerAuras and targetAuras continue running!
            if (g.litePreference != null && g.litePreference.data != null) {
                if (g.litePreference.data.bHideUI == true) {
                    g.litePreference.data.bHideUI = false;
                    try { g.litePreference.flush(); } catch (_:Dynamic) {}
                }
            }

            if (shouldHide) {
                // Ensure native aura frames are re-parented out of mcPortrait/mcPortraitTarget into g.ui
                if (g.pAurasUI != null && g.pAurasUI.parent != null && g.pAurasUI.parent != g.ui) {
                    try {
                        g.pAurasUI.parent.removeChild(g.pAurasUI);
                        g.ui.addChild(g.pAurasUI);
                    } catch (_:Dynamic) {}
                }
                if (g.tAurasUI != null && g.tAurasUI.parent != null && g.tAurasUI.parent != g.ui) {
                    try {
                        g.tAurasUI.parent.removeChild(g.tAurasUI);
                        g.ui.addChild(g.tAurasUI);
                    } catch (_:Dynamic) {}
                }

                // Hide native portraits
                if (g.ui.mcPortrait != null) {
                    g.ui.mcPortrait.visible = false;
                    g.ui.mcPortrait.y = -9999;
                }
                if (g.ui.mcPortraitTarget != null) {
                    g.ui.mcPortraitTarget.visible = false;
                    g.ui.mcPortraitTarget.y = -9999;
                }
                if (g.ui.monsterIcon != null) g.ui.monsterIcon.visible = false;
                if (g.ui.iconQuest != null) g.ui.iconQuest.visible = false;
                if (g.ui.btnTargetPortraitClose != null) g.ui.btnTargetPortraitClose.visible = false;
                if (g.ui.mcInterface != null && g.ui.mcInterface.areaList != null) {
                    g.ui.mcInterface.areaList.visible = false;
                }
            } else {
                // Restore native portraits
                if (g.ui.mcPortrait != null) {
                    g.ui.mcPortrait.y = 0;
                    g.ui.mcPortrait.visible = true;
                }
                if (g.ui.mcPortraitTarget != null) {
                    g.ui.mcPortraitTarget.y = 0;
                    g.ui.mcPortraitTarget.visible = true;
                }
                if (g.ui.mcInterface != null && g.ui.mcInterface.areaList != null) {
                    g.ui.mcInterface.areaList.visible = true;
                }
                if (g.world != null && g.world.myAvatar != null) {
                    if (Reflect.isFunction(g.showPortrait)) {
                        try { g.showPortrait(g.world.myAvatar); } catch (_:Dynamic) {}
                    }
                    if (g.world.myAvatar.target != null && Reflect.isFunction(g.showPortraitTarget)) {
                        try { g.showPortraitTarget(g.world.myAvatar.target); } catch (_:Dynamic) {}
                    }
                }
            }
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
        PlayerAuraFrame.onAnchorModeChanged();
    }

    public static inline function getTargetAuraAnchorMode():Int {
        return ApiConfig.getInt("api_frame_target_auras_anchor_mode", AURA_ANCHOR_FRAMES);
    }

    public static inline function setTargetAuraAnchorMode(mode:Int):Void {
        ApiConfig.setInt("api_frame_target_auras_anchor_mode", mode);
        TargetAuraFrame.onAnchorModeChanged();
    }

    public static inline function getAuraAnchorMode():Int {
        return getPlayerAuraAnchorMode();
    }

    public static inline function setAuraAnchorMode(mode:Int):Void {
        setPlayerAuraAnchorMode(mode);
        setTargetAuraAnchorMode(mode);
    }

    public static function reloadFromConfig():Void {
        PlayerUnitFrame.reloadFromConfig();
        TargetUnitFrame.reloadFromConfig();
        PlayerAuraFrame.reloadFromConfig();
        TargetAuraFrame.reloadFromConfig();
        try { ui.widgets.PlayersWidget.reloadFromConfig(); } catch (_:Dynamic) {}
        syncNativeHideUI();
    }

    public static function resetAllPositions():Void {
        PlayerUnitFrame.resetPosition();
        TargetUnitFrame.resetPosition();
        PlayerAuraFrame.resetPosition();
        TargetAuraFrame.resetPosition();
        ApiNotificationManager.notify("Unit frame positions reset!");
    }
}
#else
class UnitFramesManager {
    public static inline var AURA_ANCHOR_FRAMES:Int = 0;
    public static inline var AURA_ANCHOR_UNITS:Int = 1;
    public static inline var AURA_ANCHOR_FREE:Int = 2;
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isPlayerFrameEnabled():Bool return false;
    public static function setPlayerFrameEnabled(enabled:Bool):Void {}
    public static function isTargetFrameEnabled():Bool return false;
    public static function setTargetFrameEnabled(enabled:Bool):Void {}
    public static function isPlayerAurasEnabled():Bool return false;
    public static function setPlayerAurasEnabled(enabled:Bool):Void {}
    public static function isTargetAurasEnabled():Bool return false;
    public static function setTargetAurasEnabled(enabled:Bool):Void {}
    public static function syncNativeHideUI():Void {}
    public static inline function getPlayerAuraAnchorMode():Int return AURA_ANCHOR_FRAMES;
    public static inline function setPlayerAuraAnchorMode(mode:Int):Void {}
    public static inline function getTargetAuraAnchorMode():Int return AURA_ANCHOR_FRAMES;
    public static inline function setTargetAuraAnchorMode(mode:Int):Void {}
    public static inline function getAuraAnchorMode():Int return AURA_ANCHOR_FRAMES;
    public static inline function setAuraAnchorMode(mode:Int):Void {}
    public static function reloadFromConfig():Void {}
    public static function resetAllPositions():Void {}
}
#end
