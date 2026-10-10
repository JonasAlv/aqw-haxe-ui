package ui.frames;

#if flash
import ui.Overlay;
import ui.ApiNotificationManager;
import com.aqwapi.Api;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.utils.ApiConfig;

/**
     * UnitFramesManager:
     * Coordinator for modern, portrait-less, compact unit frames (ElvUI / oUF style).
     *
     * Coordinates:
     * - PlayerUnitFrame: [Level] Username - Class R<Rank>, HP + Shield, MP, SP stamina line.
     * - TargetUnitFrame: [Level] TargetName - Race/Class, HP + Shield, MP, [x] cancel target.
     *
     * Auras (player & target buff/debuff icons) are no longer managed by us — the new game
     * client keeps them visible when the UI is hidden and positions them automatically, so
     * they follow the unit frames without any code of our own. syncNativeHideUI() is the only
     * thing we still do for them: keep bHideUI = false so they keep processing.
     */
class UnitFramesManager {
    private static var _initialized:Bool = false;

    public static function init(pocket:Dynamic, overlay:Overlay):Void {
        if (_initialized) return;
        _initialized = true;

        PlayerUnitFrame.init(pocket, overlay);
        TargetUnitFrame.init(pocket, overlay);
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

    /**
     * Synchronizes native AQW portrait suppression with our custom unit frames.
     * When any custom unit frame (Player or Target) is active:
     * - Keeps bHideUI = false so default aura frames continue processing all packets and animations
     * - Hides native mcPortrait, mcPortraitTarget, and areaList
     * When all custom unit frames are disabled:
     * - Restores native portraits and areaList
     *
     * NOTE: the new game client keeps auras visible when the UI is hidden, so we no longer
     * re-parent pAurasUI / tAurasUI or toggle auraContainer visibility — only bHideUI and the
     * portrait visibility are controlled here.
     */
    public static function syncNativeHideUI():Void {
        try {
            var g:Dynamic = com.aqwapi.Api.game;
            if (g == null || g.ui == null) return;

            var playerFrameOn:Bool = isPlayerFrameEnabled();
            var targetFrameOn:Bool = isTargetFrameEnabled();
            var shouldHideAny:Bool = (playerFrameOn || targetFrameOn);

            // Ensure bHideUI is false so native playerAuras and targetAuras continue running!
            if (g.litePreference != null && g.litePreference.data != null) {
                if (g.litePreference.data.bHideUI == true) {
                    g.litePreference.data.bHideUI = false;
                    try { g.litePreference.flush(); } catch (_:Dynamic) {}
                }
            }

            if (shouldHideAny) {
                // NOTE: no longer re-parent pAurasUI / tAurasUI out of mcPortrait into g.ui.
                // The new game client keeps auras visible when the UI is hidden, so our old
                // re-parenting was redundant — and on the new client it can actually hide
                // auras that the game expects to stay on screen. Leave them where the game
                // placed them; only control bHideUI and the portrait visibility below.
            }

            // 1. Player portrait control
            if (g.ui.mcPortrait != null) {
                if (playerFrameOn) {
                    g.ui.mcPortrait.visible = false;
                    g.ui.mcPortrait.y = -9999;
                } else {
                    g.ui.mcPortrait.y = 0;
                    g.ui.mcPortrait.visible = true;
                    if (g.world != null && g.world.myAvatar != null && Reflect.isFunction(g.showPortrait)) {
                        try { g.showPortrait(g.world.myAvatar); } catch (_:Dynamic) {}
                    }
                }
            }

            // 2. Target portrait control
            var hasTarget:Bool = (g.world != null && g.world.myAvatar != null && g.world.myAvatar.target != null);
            if (g.ui.mcPortraitTarget != null) {
                if (targetFrameOn) {
                    g.ui.mcPortraitTarget.visible = false;
                    g.ui.mcPortraitTarget.y = -9999;
                    if (g.ui.btnTargetPortraitClose != null) g.ui.btnTargetPortraitClose.visible = false;
                } else {
                    g.ui.mcPortraitTarget.y = 0;
                    g.ui.mcPortraitTarget.visible = hasTarget;
                    if (g.ui.btnTargetPortraitClose != null) g.ui.btnTargetPortraitClose.visible = hasTarget;
                    if (hasTarget && Reflect.isFunction(g.showPortraitTarget)) {
                        try { g.showPortraitTarget(g.world.myAvatar.target); } catch (_:Dynamic) {}
                    }
                }
            }

            if (g.ui.monsterIcon != null) g.ui.monsterIcon.visible = (!targetFrameOn && hasTarget);
            if (g.ui.iconQuest != null) g.ui.iconQuest.visible = (!targetFrameOn && hasTarget);

            // Area list (quest / area tracker)
            if (g.ui.mcInterface != null && g.ui.mcInterface.areaList != null) {
                g.ui.mcInterface.areaList.visible = !playerFrameOn;
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
        PlayerUnitFrame.reloadFromConfig();
        TargetUnitFrame.reloadFromConfig();
        syncNativeHideUI();
    }

    public static function resetAllPositions():Void {
        PlayerUnitFrame.resetPosition();
        TargetUnitFrame.resetPosition();
        ApiNotificationManager.notify("Unit frame positions reset!");
    }
}
#else
class UnitFramesManager {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isPlayerFrameEnabled():Bool return false;
    public static function setPlayerFrameEnabled(enabled:Bool):Void {}
    public static function isTargetFrameEnabled():Bool return false;
    public static function setTargetFrameEnabled(enabled:Bool):Void {}
    public static function reloadFromConfig():Void {}
    public static function resetAllPositions():Void {}
}
#end
