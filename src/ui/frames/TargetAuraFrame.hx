package ui.frames;

#if flash
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.geom.Point;
import flash.system.ApplicationDomain;
import com.aqwapi.Api;
import ui.Overlay;
import ui.ApiDashboardModal;
import ui.ApiMenus;
import ui.ApiStyle;
import com.aqwapi.utils.ApiConfig;

/**
 * Target Aura Frame:
 * Hooks and anchors AQW's native target aura frame (tAurasUI / tAuraContainer)
 * directly to the compact TargetUnitFrame (or to enemy feet / draggable).
 */
class TargetAuraFrame {
    private static var _pocket:Dynamic = null;
    private static var _overlay:Overlay = null;
    private static var _widget:Sprite = null;
    private static var _dragBar:Sprite = null;
    private static var _initialized:Bool = false;
    private static var _lastTargetId:String = "";

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

    private static function buildFrame(theStage:Dynamic):Void {
        _widget = new Sprite();
        _widget.name = "TargetAuraFrame";

        var savedX = ApiConfig.getInt("api_frame_target_auras_x", -1);
        var savedY = ApiConfig.getInt("api_frame_target_auras_y", -1);
        var initX:Float = (savedX >= 0) ? savedX : 370;
        var initY:Float = (savedY >= 0) ? savedY : 426;

        _widget.x = initX;
        _widget.y = initY;
        _widget.visible = false;

        // Drag handle bar for Free mode
        _dragBar = new Sprite();
        _dragBar.buttonMode = true;
        _dragBar.useHandCursor = true;
        renderDragBar(128, false);
        _dragBar.visible = (UnitFramesManager.getTargetAuraAnchorMode() == UnitFramesManager.AURA_ANCHOR_FREE);
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
                hideNativeTargetAuras();
                return;
            }
            var isEnabled = isWidgetEnabled();
            if (!isEnabled) {
                _widget.visible = false;
                restoreNativeTargetAuras();
                return;
            }
            var isPanelOpen:Bool = (_overlay != null && (_overlay.currentFrameLabel == "Panel" || ApiDashboardModal.isOpen()));
            if (isPanelOpen) {
                _widget.visible = false;
                hideNativeTargetAuras();
                return;
            }

            var t = (Api.player != null) ? Api.player.target : null;
            if (t == null || !t.isAlive) {
                _widget.visible = false;
                hideNativeTargetAuras();
                _lastTargetId = "";
                return;
            }

            var curTargetId:String = (t.id != null) ? Std.string(t.id) : (t.name != null ? t.name : "");
            if (curTargetId != _lastTargetId) {
                _lastTargetId = curTargetId;
                var g:Dynamic = Api.game;
                if (g != null && g.tAurasUI != null) {
                    try {
                        if (Reflect.hasField(g.tAurasUI, "clearMCs")) {
                            Reflect.callMethod(g.tAurasUI, Reflect.field(g.tAurasUI, "clearMCs"), []);
                        }
                    } catch (_:Dynamic) {}
                }
            }

            _widget.visible = true;
            syncTargetAuras();
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

    public static function ensureNativeTargetAuras():Void {
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

        if (g.tAurasUI == null) {
            try {
                var domain = ApplicationDomain.currentDomain;
                if (domain != null && domain.hasDefinition("liteAssets.draw.targetAuras")) {
                    var clsT:Dynamic = domain.getDefinition("liteAssets.draw.targetAuras");
                    g.tAurasUI = Type.createInstance(clsT, [g]);
                    g.ui.addChild(g.tAurasUI);
                }
            } catch (_:Dynamic) {}
        }
    }

    public static function getActiveAuraCount():Int {
        try {
            var g:Dynamic = Api.game;
            if (g == null || g.ui == null) return 0;
            // 1. Direct check of the display list container attached to g.ui
            var container:Dynamic = null;
            try { container = g.ui.getChildByName("tAuraContainer"); } catch (_:Dynamic) {}
            if (container != null && container.numChildren != null && container.numChildren > 0) {
                return container.numChildren;
            }
            // 2. Safe check via Reflect on public dynamic fields (avoids Error #1069 on protected members)
            var tUI:Dynamic = g.tAurasUI;
            if (tUI != null) {
                if (Reflect.hasField(tUI, "icons")) {
                    var icons = Reflect.field(tUI, "icons");
                    if (icons != null) {
                        var count:Int = 0;
                        for (_ in Reflect.fields(icons)) count++;
                        if (count > 0) return count;
                    }
                }
            }
            // 3. Fallback: check target's auras array
            var t:Dynamic = (Api.player != null) ? Api.player.target : null;
            if (t != null) {
                if (t.raw != null && t.raw.auras != null && t.raw.auras.length > 0) {
                    return t.raw.auras.length;
                }
                if (t.auras != null && t.auras.length > 0) {
                    return t.auras.length;
                }
            }
        } catch (_:Dynamic) {}
        return 0;
    }

    private static function updatePosition():Void {
        try {
            var g:Dynamic = Api.game;
            if (g == null || g.ui == null) return;

            ensureNativeTargetAuras();

            var tUI:Dynamic = g.tAurasUI;
            if (tUI == null) return;

            // Ensure tAurasUI is attached directly to g.ui rather than mcPortraitTarget
            if (tUI.parent != null && tUI.parent != g.ui) {
                try {
                    tUI.parent.removeChild(tUI);
                    g.ui.addChild(tUI);
                } catch (_:Dynamic) {}
            }

            var auraContainer:Dynamic = null;
            try { auraContainer = g.ui.getChildByName("tAuraContainer"); } catch (_:Dynamic) {}

            var t = (Api.player != null) ? Api.player.target : null;
            var isTargetAlive = (t != null && t.isAlive);
            var numAuras:Int = getActiveAuraCount();
            var hasAuras:Bool = (numAuras > 0);

            if (!isTargetAlive || !hasAuras || !TargetUnitFrame.isFrameVisible()) {
                tUI.visible = false;
                if (auraContainer != null) auraContainer.visible = false;
                return;
            }

            var mode = UnitFramesManager.getTargetAuraAnchorMode();
            var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);
            var sw:Float = (theStage != null && theStage.stageWidth > 0) ? theStage.stageWidth : 960.0;
            var sh:Float = (theStage != null && theStage.stageHeight > 0) ? theStage.stageHeight : 550.0;

            var targetStageX:Float = 370.0;
            var targetStageY:Float = 426.0;

            if (mode == UnitFramesManager.AURA_ANCHOR_FRAMES) {
                // Anchored directly to TargetUnitFrame!
                var tfx:Float = TargetUnitFrame.getFrameX();
                var tfy:Float = TargetUnitFrame.getFrameY();
                targetStageX = tfx;

                var spaceBelow:Float = sh - (tfy + TargetUnitFrame.FRAME_H);
                var spaceAbove:Float = tfy;

                var numRows:Int = (numAuras > 4) ? Math.ceil(numAuras / 4.0) : 1;
                var totalH:Float = numRows * 28.0;

                if (spaceAbove > spaceBelow) {
                    // More room above -> show UP
                    targetStageY = tfy - totalH - 3.0;
                } else {
                    // More room below -> show DOWN
                    targetStageY = tfy + TargetUnitFrame.FRAME_H + 3.0;
                }
            } else if (mode == UnitFramesManager.AURA_ANCHOR_UNITS) {
                // Anchored below target feet in world
                var feetPt = getTargetFeetGlobalPos();
                if (feetPt != null) {
                    var colCount = (numAuras < 4) ? numAuras : 4;
                    var totalW = (colCount > 0) ? colCount * ICON_W : 64.0;
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

            tUI.x = localPt.x;
            tUI.y = localPt.y;
            tUI.visible = true;
        } catch (_:Dynamic) {}
    }

    public static function syncTargetAuras():Void {
        try {
            var g:Dynamic = Api.game;
            if (g == null || g.world == null || g.world.myAvatar == null) return;
            var tObj:Dynamic = g.world.myAvatar.target;
            if (tObj == null) return;

            var rawAuras:Dynamic = Api.aura.getRawAuras("target");
            if (rawAuras != null) {
                if (tObj.dataLeaf != null) {
                    tObj.dataLeaf.auras = rawAuras;
                }
                var tUI:Dynamic = g.tAurasUI;
                if (tUI != null && Std.isOfType(rawAuras, Array)) {
                    var arr:Array<Dynamic> = cast rawAuras;
                    var tInfStr:String = "";
                    if (tObj.dataLeaf != null && tObj.dataLeaf.MonID != null && tObj.dataLeaf.MonMapID != null) {
                        tInfStr = "m:" + tObj.dataLeaf.MonMapID;
                    } else if (tObj.dataLeaf != null && tObj.dataLeaf.entID != null) {
                        tInfStr = "p:" + tObj.dataLeaf.entID;
                    }

                    // Feed any missing raw aura into tAurasUI.handleAura
                    for (auraItem in arr) {
                        if (auraItem != null && auraItem.nam != null) {
                            var nam:String = Std.string(auraItem.nam);
                            var hasIcon:Bool = false;
                            if (tUI.icons != null && Reflect.hasField(tUI.icons, nam)) {
                                hasIcon = true;
                            }
                            if (!hasIcon && tInfStr != "") {
                                var packet = {
                                    a: [
                                        {
                                            tInf: tInfStr,
                                            auras: [ auraItem ],
                                            cmd: "+auras"
                                        }
                                    ]
                                };
                                tUI.handleAura(packet);
                            }
                        }
                    }
                }
            }
        } catch (_:Dynamic) {}
    }

    public static function getTargetFeetGlobalPos():Point {
        try {
            var g:Dynamic = Api.game;
            if (g == null || g.world == null || g.world.myAvatar == null) return null;
            var t:Dynamic = g.world.myAvatar.target;
            if (t == null) return null;
            var pMC:Dynamic = t.pMC;
            if (pMC == null) return null;

            var charX:Float = 0;
            if (pMC.mcChar != null) {
                try { charX = pMC.mcChar.x; } catch (_:Dynamic) {}
            }
            return pMC.localToGlobal(new Point(charX, 0));
        } catch (_:Dynamic) {}
        return null;
    }

    private static function hideNativeTargetAuras():Void {
        try {
            var g:Dynamic = Api.game;
            var auraContainer:Dynamic = null;
            if (g != null && g.ui != null) {
                try { auraContainer = g.ui.getChildByName("tAuraContainer"); } catch (_:Dynamic) {}
            }
            if (auraContainer != null) auraContainer.visible = false;
            if (g != null && g.tAurasUI != null) {
                g.tAurasUI.visible = false;
            }
        } catch (_:Dynamic) {}
    }

    private static function restoreNativeTargetAuras():Void {
        try {
            var g:Dynamic = Api.game;
            var auraContainer:Dynamic = null;
            if (g != null && g.ui != null) {
                try { auraContainer = g.ui.getChildByName("tAuraContainer"); } catch (_:Dynamic) {}
            }
            if (auraContainer != null) {
                auraContainer.x = 320;
                auraContainer.y = 95;
                auraContainer.visible = true;
            }
            if (g != null && g.tAurasUI != null) {
                g.tAurasUI.x = 85;
                g.tAurasUI.y = 93;
                g.tAurasUI.visible = true;
                if (g.ui != null && g.ui.mcPortraitTarget != null) {
                    try { g.ui.mcPortraitTarget.addChild(g.tAurasUI); } catch (_:Dynamic) {}
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
            if (UnitFramesManager.getTargetAuraAnchorMode() != UnitFramesManager.AURA_ANCHOR_FREE) return;
            isDragging = true;
            hasDragged = false;
            startDownX = e.stageX;
            startDownY = e.stageY;
            _widget.cacheAsBitmap = false;
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
                    ApiConfig.setInt("api_frame_target_auras_x", Math.round(_widget.x));
                    ApiConfig.setInt("api_frame_target_auras_y", Math.round(_widget.y));
                }
            }
        });
    }

    public static function onAnchorModeChanged():Void {
        if (_widget == null) return;
        var mode = UnitFramesManager.getTargetAuraAnchorMode();
        if (mode == UnitFramesManager.AURA_ANCHOR_FREE) {
            var savedX = ApiConfig.getInt("api_frame_target_auras_x", -1);
            var savedY = ApiConfig.getInt("api_frame_target_auras_y", -1);
            _widget.x = (savedX >= 0) ? savedX : 370;
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
        return ApiConfig.getBool("api_frame_target_auras_enabled", true);
    }

    public static function setWidgetEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_target_auras_enabled", enabled);
        if (!enabled) restoreNativeTargetAuras();
        else updatePosition();
    }

    public static function resetPosition():Void {
        ApiConfig.setInt("api_frame_target_auras_x", 370);
        ApiConfig.setInt("api_frame_target_auras_y", 426);
        if (_widget != null) {
            _widget.x = 370;
            _widget.y = 426;
        }
        updatePosition();
    }
}
#else
class TargetAuraFrame {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isWidgetEnabled():Bool return false;
    public static function setWidgetEnabled(enabled:Bool):Void {}
    public static function resetPosition():Void {}
    public static function onAnchorModeChanged():Void {}
    public static function reloadFromConfig():Void {}
}
#end
