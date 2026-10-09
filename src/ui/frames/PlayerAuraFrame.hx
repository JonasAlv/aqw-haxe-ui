package ui.frames;

#if flash
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.geom.Point;
import flash.system.ApplicationDomain;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiConfig;
import ui.Overlay;
import ui.ApiDashboardModal;
import ui.ApiMenus;
import ui.ApiStyle;
import util.HelperSetting;

/**
 * Player Aura Frame:
 * Hooks and anchors AQW's native player aura frame (pAurasUI / auraContainer)
 * directly to the compact PlayerUnitFrame (or to unit feet / draggable).
 */
class PlayerAuraFrame {
    private static var _pocket:Dynamic = null;
    private static var _overlay:Overlay = null;
    private static var _widget:Sprite = null;
    private static var _dragBar:Sprite = null;
    private static var _initialized:Bool = false;

    private static inline var ICON_W:Float = 32.0;
    private static inline var ICON_H:Float = 28.0;

    public static function init(pocket:Dynamic, overlay:Overlay):Void {
        if (_initialized) return;
        _initialized = true;
        _pocket = pocket;
        _overlay = overlay;

        var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);

        var attach = function(stageObj:Dynamic):Void {
            if (stageObj == null || _widget != null) return;
            buildFrame(stageObj);
        };

        if (theStage != null) {
            attach(theStage);
        } else if (_overlay != null) {
            _overlay.addEventListener(Event.ADDED_TO_STAGE, function(ev:Event):Void {
                if (_overlay.stage != null && _widget == null) {
                    attach(_overlay.stage);
                }
            });
        }
    }

    public static function getActiveAuraCount():Int {
        var g:Dynamic = Api.game;
        if (g == null || g.ui == null) return 0;
        try {
            var container:Dynamic = g.ui.getChildByName("auraContainer");
            if (container != null && container.numChildren != null) {
                return container.numChildren;
            }
        } catch (_:Dynamic) {}
        try {
            var pUI:Dynamic = g.pAurasUI;
            if (pUI != null && pUI.icons != null) {
                return Reflect.fields(pUI.icons).length;
            }
        } catch (_:Dynamic) {}
        try {
            if (g.world != null && g.world.myAvatar != null && g.world.myAvatar.dataLeaf != null && g.world.myAvatar.dataLeaf.auras != null) {
                var arr:Array<Dynamic> = cast g.world.myAvatar.dataLeaf.auras;
                if (arr != null) return arr.length;
            }
        } catch (_:Dynamic) {}
        return 0;
    }

    private static function buildFrame(theStage:Dynamic):Void {
        _widget = new Sprite();
        _widget.name = "PlayerAuraFrame";

        var savedX = ApiConfig.getInt("api_frame_player_auras_x", -1);
        var savedY = ApiConfig.getInt("api_frame_player_auras_y", -1);
        var initX:Float = (savedX >= 0) ? savedX : 180;
        var initY:Float = (savedY >= 0) ? savedY : 426;

        _widget.x = initX;
        _widget.y = initY;

        // Drag handle bar for Free mode
        _dragBar = new Sprite();
        _dragBar.buttonMode = true;
        _dragBar.useHandCursor = true;
        renderDragBar(128, false);
        _dragBar.visible = (UnitFramesManager.getPlayerAuraAnchorMode() == UnitFramesManager.AURA_ANCHOR_FREE);
        _widget.addChild(_dragBar);

        _dragBar.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            renderDragBar(_dragBar.width, true);
        });
        _dragBar.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            renderDragBar(_dragBar.width, false);
        });

        setupDragging(theStage);

        _widget.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            var inGame = ApiMenus.isInGame();
            if (!inGame) {
                _widget.visible = false;
                hideNativePlayerAuras();
                return;
            }
            var isEnabled = isWidgetEnabled();
            if (!isEnabled) {
                _widget.visible = false;
                restoreNativePlayerAuras();
                return;
            }
            var isPanelOpen:Bool = (_overlay != null && (_overlay.currentFrameLabel == "Panel" || ApiDashboardModal.isOpen()));
            if (isPanelOpen) {
                _widget.visible = false;
                hideNativePlayerAuras();
                return;
            }

            _widget.visible = true;
            updatePosition();
        });

        theStage.addChild(_widget);
    }

    private static function renderDragBar(w:Float, hover:Bool):Void {
        if (_dragBar == null) return;
        var g = _dragBar.graphics;
        g.clear();
        var barW = Math.max(48.0, w);
        var bg = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE;
        var border = hover ? ApiStyle.COLOR_ACCENT_PRIMARY : ApiStyle.COLOR_BORDER_DEFAULT;
        g.beginFill(bg, hover ? 0.9 : 0.6);
        g.lineStyle(1, border, hover ? 0.95 : 0.6);
        g.drawRoundRect(0, -9, barW, 8, 2, 2);
        g.endFill();

        // Drag handle grip dot
        g.lineStyle(0, 0, 0);
        g.beginFill(hover ? ApiStyle.COLOR_ACCENT_HOVER : ApiStyle.COLOR_TEXT_MUTED, 0.9);
        g.drawCircle(barW / 2, -5, 1.5);
        g.endFill();
    }

    public static function ensureNativePlayerAuras():Void {
        var g:Dynamic = Api.game;
        if (g == null || g.ui == null) return;

        if (g.litePreference != null && g.litePreference.data != null) {
            if (g.litePreference.data.bAuras != true) {
                g.litePreference.data.bAuras = true;
                try { g.litePreference.flush(); } catch (_:Dynamic) {}
            }
            if (g.litePreference.data.bHideUI == true) {
                g.litePreference.data.bHideUI = false;
                try { g.litePreference.flush(); } catch (_:Dynamic) {}
            }
        }

        if (g.pAurasUI == null) {
            try {
                var domain = ApplicationDomain.currentDomain;
                if (domain != null && domain.hasDefinition("liteAssets.draw.playerAuras")) {
                    var clsP:Dynamic = domain.getDefinition("liteAssets.draw.playerAuras");
                    g.pAurasUI = Type.createInstance(clsP, [g]);
                    g.ui.addChild(g.pAurasUI);
                }
            } catch (_:Dynamic) {}
        }
    }

    private static function updatePosition():Void {
        try {
            var g:Dynamic = Api.game;
            if (g == null || g.ui == null) return;

            ensureNativePlayerAuras();

            var pUI:Dynamic = g.pAurasUI;
            if (pUI == null) return;

            // Ensure pAurasUI is attached directly to g.ui rather than mcPortrait
            if (pUI.parent != null && pUI.parent != g.ui) {
                try {
                    pUI.parent.removeChild(pUI);
                    g.ui.addChild(pUI);
                } catch (_:Dynamic) {}
            }

            var auraContainer:Dynamic = null;
            try { auraContainer = g.ui.getChildByName("auraContainer"); } catch (_:Dynamic) {}

            var numAuras:Int = getActiveAuraCount();
            var hasAuras:Bool = (numAuras > 0);

            if (!hasAuras) {
                pUI.visible = false;
                if (auraContainer != null) auraContainer.visible = false;
                return;
            }

            var mode = UnitFramesManager.getPlayerAuraAnchorMode();
            var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);
            var sw:Float = (theStage != null && theStage.stageWidth > 0) ? theStage.stageWidth : 960.0;
            var sh:Float = (theStage != null && theStage.stageHeight > 0) ? theStage.stageHeight : 550.0;

            var targetStageX:Float = 180.0;
            var targetStageY:Float = 426.0;

            if (mode == UnitFramesManager.AURA_ANCHOR_FRAMES) {
                // Anchored directly to PlayerUnitFrame!
                var fx:Float = PlayerUnitFrame.getFrameX();
                var fy:Float = PlayerUnitFrame.getFrameY();
                targetStageX = fx;

                var spaceBelow:Float = sh - (fy + PlayerUnitFrame.FRAME_H);
                var spaceAbove:Float = fy;

                var numRows:Int = (numAuras > 4) ? Math.ceil(numAuras / 4.0) : 1;
                var totalH:Float = numRows * 28.0;

                if (spaceAbove > spaceBelow) {
                    // More room above -> show UP
                    targetStageY = fy - totalH - 3.0;
                } else {
                    // More room below -> show DOWN
                    targetStageY = fy + PlayerUnitFrame.FRAME_H + 3.0;
                }
            } else if (mode == UnitFramesManager.AURA_ANCHOR_UNITS) {
                // Anchored below character feet in world
                var feetPt = getPlayerFeetGlobalPos();
                if (feetPt != null) {
                    var colCount = (numAuras < 4) ? numAuras : 4;
                    var totalW = (colCount > 0) ? (colCount * ICON_W) : 64.0;
                    targetStageX = Math.round(feetPt.x - (totalW / 2.0));
                    targetStageY = Math.round(feetPt.y + 4.0);
                }
            } else {
                // Free / Draggable mode
                targetStageX = _widget.x;
                targetStageY = _widget.y;
                if (_dragBar != null) {
                    _dragBar.visible = true;
                    var colCount = (numAuras < 4) ? numAuras : 4;
                    var curW = (colCount > 0) ? (colCount * ICON_W) : 64.0;
                    renderDragBar(curW, false);
                }
            }

            // Convert stage coordinates to g.ui local coordinates
            var localPt:Point = new Point(targetStageX, targetStageY);
            if (g.ui != null && g.ui.parent != null) {
                try { localPt = g.ui.globalToLocal(localPt); } catch (_:Dynamic) {}
            }

            if (auraContainer != null) {
                auraContainer.x = localPt.x;
                auraContainer.y = localPt.y;
                auraContainer.visible = true;
            }

            pUI.x = localPt.x;
            pUI.y = localPt.y;
            pUI.visible = true;
        } catch (_:Dynamic) {}
    }

    public static function getPlayerFeetGlobalPos():Point {
        try {
            var g:Dynamic = Api.game;
            if (g == null || g.world == null || g.world.myAvatar == null) return null;
            var avt:Dynamic = g.world.myAvatar;
            var pMC:Dynamic = avt.pMC;
            if (pMC == null) return null;

            var charX:Float = 0;
            if (pMC.mcChar != null) {
                try { charX = pMC.mcChar.x; } catch (_:Dynamic) {}
            }
            return pMC.localToGlobal(new Point(charX, 0));
        } catch (_:Dynamic) {}
        return null;
    }

    private static function hideNativePlayerAuras():Void {
        try {
            var g:Dynamic = Api.game;
            if (g != null) {
                var auraContainer:Dynamic = null;
                if (g.ui != null) {
                    try { auraContainer = g.ui.getChildByName("auraContainer"); } catch (_:Dynamic) {}
                }
                if (auraContainer != null) auraContainer.visible = false;
                if (g.pAurasUI != null) g.pAurasUI.visible = false;
            }
        } catch (_:Dynamic) {}
    }

    private static function restoreNativePlayerAuras():Void {
        try {
            var g:Dynamic = Api.game;
            if (g != null) {
                var auraContainer:Dynamic = null;
                if (g.ui != null) {
                    try { auraContainer = g.ui.getChildByName("auraContainer"); } catch (_:Dynamic) {}
                }
                if (auraContainer != null) {
                    auraContainer.x = 86;
                    auraContainer.y = 86;
                    auraContainer.visible = true;
                }
                if (g.pAurasUI != null) {
                    g.pAurasUI.x = 86;
                    g.pAurasUI.y = 86;
                    g.pAurasUI.visible = true;
                    if (g.ui != null && g.ui.mcPortrait != null) {
                        try { g.ui.mcPortrait.addChild(g.pAurasUI); } catch (_:Dynamic) {}
                    }
                }
            }
        } catch (_:Dynamic) {}
    }

    private static function setupDragging(theStage:Dynamic):Void {
        var isDragging:Bool = false;
        var hasDragged:Bool = false;
        var startDownX:Float = 0;
        var startDownY:Float = 0;
        var dragStartX:Float = 0;
        var dragStartY:Float = 0;

        _dragBar.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            if (UnitFramesManager.getPlayerAuraAnchorMode() != UnitFramesManager.AURA_ANCHOR_FREE) return;
            isDragging = true;
            hasDragged = false;
            startDownX = e.stageX;
            startDownY = e.stageY;
            _widget.cacheAsBitmap = true;
            dragStartX = e.stageX - _widget.x;
            dragStartY = e.stageY - _widget.y;
            theStage.setChildIndex(_widget, theStage.numChildren - 1);
        });

        theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (isDragging) {
                var dx = e.stageX - startDownX;
                var dy = e.stageY - startDownY;
                if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
                    hasDragged = true;
                }
                if (hasDragged) {
                    var nx:Float = Math.round(e.stageX - dragStartX);
                    var ny:Float = Math.round(e.stageY - dragStartY);
                    var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
                    var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;

                    if (nx < ApiStyle.SCREEN_MARGIN) nx = ApiStyle.SCREEN_MARGIN;
                    if (ny < ApiStyle.SCREEN_MARGIN) ny = ApiStyle.SCREEN_MARGIN;
                    if (nx > sw - 60) nx = sw - 60;
                    if (ny > sh - 30) ny = sh - 30;

                    _widget.x = nx;
                    _widget.y = ny;
                    updatePosition();
                }
            }
        });

        theStage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            if (isDragging) {
                isDragging = false;
                _widget.cacheAsBitmap = true;
                if (hasDragged) {
                    ApiConfig.setInt("api_frame_player_auras_x", Math.round(_widget.x));
                    ApiConfig.setInt("api_frame_player_auras_y", Math.round(_widget.y));
                }
            }
        });
    }

    public static function onAnchorModeChanged():Void {
        if (_widget == null) return;
        var mode = UnitFramesManager.getPlayerAuraAnchorMode();
        if (mode == UnitFramesManager.AURA_ANCHOR_FREE) {
            var savedX = ApiConfig.getInt("api_frame_player_auras_x", -1);
            var savedY = ApiConfig.getInt("api_frame_player_auras_y", -1);
            _widget.x = (savedX >= 0) ? savedX : 180;
            _widget.y = (savedY >= 0) ? savedY : 426;
            if (_dragBar != null) _dragBar.visible = true;
        } else {
            if (_dragBar != null) _dragBar.visible = false;
        }
        updatePosition();
    }

    public static function reloadFromConfig():Void {
        onAnchorModeChanged();
    }

    public static function isWidgetEnabled():Bool {
        return ApiConfig.getBool("api_frame_player_auras_enabled", true);
    }

    public static function setWidgetEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_player_auras_enabled", enabled);
        if (!enabled) restoreNativePlayerAuras();
        else updatePosition();
    }

    public static function resetPosition():Void {
        ApiConfig.setInt("api_frame_player_auras_x", 180);
        ApiConfig.setInt("api_frame_player_auras_y", 426);
        if (_widget != null) {
            _widget.x = 180;
            _widget.y = 426;
        }
        updatePosition();
    }
}
#else
class PlayerAuraFrame {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isWidgetEnabled():Bool return false;
    public static function setWidgetEnabled(enabled:Bool):Void {}
    public static function resetPosition():Void {}
    public static function onAnchorModeChanged():Void {}
    public static function reloadFromConfig():Void {}
}
#end
