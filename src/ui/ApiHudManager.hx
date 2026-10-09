package ui;

#if flash
import com.aqwapi.Api;
import com.aqwapi.modules.CombatEngine;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.utils.ApiLogger;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import ui.ApiDashboardModal;
import ui.ApiStyle;
import ui.Overlay;
import com.aqwapi.utils.ApiConfig;

typedef HudButtonDef = {
    id:String,
    label:String,
    defaultX:Float,
    defaultY:Float,
    activeText:String,
    inactiveText:String,
    getState:Void->Bool,
    onToggle:Void->Void
};

class ApiHudManager {
    private static var _pocket:Dynamic = null;
    private static var _overlay:Overlay = null;
    private static var _buttons:Map<String, Sprite> = new Map<String, Sprite>();
    private static var _defs:Array<HudButtonDef> = [];
    private static var _initialized:Bool = false;

    public static function init(pocket:Dynamic, overlay:Overlay):Void {
        if (_initialized) return;
        _initialized = true;
        _pocket = pocket;
        _overlay = overlay;

        setupDefs();
        buildButtons();
    }

    private static function setupDefs():Void {
        _defs = [];
        for (t in ApiToolRegistry.getHudDefs()) {
            _defs.push({
                id: t.id,
                label: t.name,
                defaultX: t.defaultHudX,
                defaultY: t.defaultHudY,
                activeText: t.activeText,
                inactiveText: t.inactiveText,
                getState: t.getState,
                onToggle: t.onAction
            });
        }
    }

    private static function buildButtons():Void {
        var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);

        var attachToStage = function(stageObj:Dynamic):Void {
            if (stageObj == null) return;
            for (def in _defs) {
                if (!_buttons.exists(def.id)) {
                    var btn = createButton(def, stageObj);
                    _buttons.set(def.id, btn);
                    stageObj.addChild(btn);
                }
            }
        };

        if (theStage != null) {
            attachToStage(theStage);
        } else if (_overlay != null) {
            _overlay.addEventListener(Event.ADDED_TO_STAGE, function(ev:Event):Void {
                if (_overlay.stage != null) {
                    attachToStage(_overlay.stage);
                }
            });
        }
    }

    private static function createButton(def:HudButtonDef, theStage:Dynamic):Sprite {
        var btnW:Float = 106;
        var btnH:Float = 30;

        var btn = new Sprite();
        btn.buttonMode = true;
        btn.mouseChildren = false;

        // Position restoring
        var savedX = ApiConfig.getInt("api_hud_" + def.id + "_x", -1);
        var savedY = ApiConfig.getInt("api_hud_" + def.id + "_y", -1);
        var initX:Float = (savedX >= 0) ? savedX : def.defaultX;
        var initY:Float = (savedY >= 0) ? savedY : def.defaultY;

        var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
        var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
        if (initX > sw - btnW) initX = sw - btnW;
        if (initY > sh - btnH) initY = sh - btnH;
        if (initX < 0) initX = 0;
        if (initY < 0) initY = 0;

        btn.x = initX;
        btn.y = initY;

        var hasIndicator:Bool = (def.id != "toggle_bank");

        var txt = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_PRIMARY, true);
        fmt.align = hasIndicator ? TextFormatAlign.LEFT : TextFormatAlign.CENTER;
        txt.defaultTextFormat = fmt;
        txt.x = hasIndicator ? 21 : 0;
        txt.y = 6;
        txt.width = hasIndicator ? (btnW - 24) : btnW;
        txt.height = 20;
        txt.selectable = false;
        txt.mouseEnabled = false;
        btn.addChild(txt);

        var lastActive:Int = -1;
        var isHovered:Bool = false;

        var renderBtn = function(active:Bool, hover:Bool):Void {
            btn.graphics.clear();
            var bg:Int = ApiStyle.COLOR_BG_CARD;
            var border:Int = ApiStyle.COLOR_BORDER_DEFAULT;
            var textColor:Int = ApiStyle.COLOR_TEXT_PRIMARY;

            if (active) {
                if (def.id == "smart_enhance") {
                    bg = hover ? ApiStyle.COLOR_BG_SURFACE : ApiStyle.COLOR_BG_SURFACE;
                    border = hover ? ApiStyle.COLOR_STATUS_WARN : ApiStyle.COLOR_STATUS_WARN;
                    textColor = hover ? ApiStyle.COLOR_TEXT_YELLOW : ApiStyle.COLOR_STATUS_WARN;
                } else {
                    bg = hover ? ApiStyle.COLOR_BG_SURFACE : ApiStyle.COLOR_BG_SURFACE;
                    border = hover ? ApiStyle.COLOR_STATUS_ACTIVE_HOVER : ApiStyle.COLOR_STATUS_ACTIVE;
                    textColor = hover ? ApiStyle.COLOR_STATUS_ACTIVE_HOVER : ApiStyle.COLOR_STATUS_ACTIVE;
                }
                txt.text = def.activeText;
            } else {
                bg = hover ? ApiStyle.COLOR_BG_CARD_HOVER : ApiStyle.COLOR_BG_CARD;
                border = hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT;
                textColor = hover ? ApiStyle.COLOR_TEXT_TITLE : ApiStyle.COLOR_TEXT_PRIMARY;
                txt.text = def.inactiveText;
            }

            // Plate fill
            btn.graphics.beginFill(bg, 0.94);
            btn.graphics.lineStyle(1, border);
            btn.graphics.drawRoundRect(0, 0, btnW, btnH, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
            btn.graphics.endFill();

            // Subtle top highlight line for crisp glass bevel look
            btn.graphics.lineStyle(1, hover ? ApiStyle.COLOR_BEVEL_LIGHT : ApiStyle.COLOR_BEVEL_SUBTLE, 0.55);
            btn.graphics.moveTo(3, 1);
            btn.graphics.lineTo(btnW - 3, 1);

            // Native vector LED status indicator dot
            if (hasIndicator) {
                var dotX:Float = 12;
                var dotY:Float = btnH / 2;
                btn.graphics.lineStyle(0, 0, 0);

                if (active) {
                    if (def.id == "smart_enhance") {
                        // Amber glow & core
                        btn.graphics.beginFill(ApiStyle.COLOR_STATUS_WARN, 0.35);
                        btn.graphics.drawCircle(dotX, dotY, 4.5);
                        btn.graphics.endFill();
                        btn.graphics.beginFill(ApiStyle.COLOR_STATUS_WARN, 1.0);
                        btn.graphics.drawCircle(dotX, dotY, 2.5);
                        btn.graphics.endFill();
                    } else {
                        // Luminous green glow & core
                        btn.graphics.beginFill(ApiStyle.COLOR_STATUS_ACTIVE, 0.35);
                        btn.graphics.drawCircle(dotX, dotY, 4.5);
                        btn.graphics.endFill();
                        btn.graphics.beginFill(ApiStyle.COLOR_STATUS_ACTIVE_HOVER, 1.0);
                        btn.graphics.drawCircle(dotX, dotY, 2.5);
                        btn.graphics.endFill();
                    }
                } else {
                    // Muted inactive dot
                    btn.graphics.beginFill(ApiStyle.COLOR_STATUS_INACTIVE, 0.85);
                    btn.graphics.drawCircle(dotX, dotY, 2.5);
                    btn.graphics.endFill();
                }
            }

            txt.textColor = textColor;
        };

        var updateVisual = function():Void {
            var active = (def.getState != null) ? def.getState() : false;
            var activeInt = active ? 1 : 0;
            if (activeInt != lastActive) {
                lastActive = activeInt;
                renderBtn(active, isHovered);
            }
        };

        btn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            isHovered = true;
            renderBtn(lastActive == 1, true);
        });

        btn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            isHovered = false;
            renderBtn(lastActive == 1, false);
        });

        // Fast bitmap caching for Flash AIR rendering performance
        btn.cacheAsBitmap = true;

        // Drag & Drop
        var isDragging:Bool = false;
        var hasDragged:Bool = false;
        var dragStartX:Float = 0;
        var dragStartY:Float = 0;

        btn.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            isDragging = true;
            hasDragged = false;
            btn.cacheAsBitmap = false;
            dragStartX = e.stageX - btn.x;
            dragStartY = e.stageY - btn.y;
        });

        theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (isDragging) {
                var dx = (e.stageX - dragStartX) - btn.x;
                var dy = (e.stageY - dragStartY) - btn.y;
                if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
                    hasDragged = true;
                }
                var nx:Float = Math.round(e.stageX - dragStartX);
                var ny:Float = Math.round(e.stageY - dragStartY);
                var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
                var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 500;
                if (nx < ApiStyle.SCREEN_MARGIN) nx = ApiStyle.SCREEN_MARGIN;
                if (ny < ApiStyle.SCREEN_MARGIN) ny = ApiStyle.SCREEN_MARGIN;
                if (nx > sw - btnW - ApiStyle.SCREEN_MARGIN) nx = sw - btnW - ApiStyle.SCREEN_MARGIN;
                if (ny > sh - btnH - ApiStyle.SCREEN_MARGIN) ny = sh - btnH - ApiStyle.SCREEN_MARGIN;
                btn.x = nx;
                btn.y = ny;
            }
        });

        theStage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            if (isDragging) {
                btn.cacheAsBitmap = true;
                if (hasDragged) {
                    var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
                    var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
                    if (btn.x < ApiStyle.SCREEN_MARGIN) btn.x = ApiStyle.SCREEN_MARGIN;
                    if (btn.y < ApiStyle.SCREEN_MARGIN) btn.y = ApiStyle.SCREEN_MARGIN;
                    if (btn.x > sw - btnW - ApiStyle.SCREEN_MARGIN) btn.x = sw - btnW - ApiStyle.SCREEN_MARGIN;
                    if (btn.y > sh - btnH - ApiStyle.SCREEN_MARGIN) btn.y = sh - btnH - ApiStyle.SCREEN_MARGIN;

                    ApiConfig.setInt("api_hud_" + def.id + "_x", Math.round(btn.x));
                    ApiConfig.setInt("api_hud_" + def.id + "_y", Math.round(btn.y));
                }
            }
            isDragging = false;
        });

        btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (hasDragged) {
                hasDragged = false;
                return;
            }
            if (def.onToggle != null) {
                def.onToggle();
                lastActive = -1; // Force immediate visual refresh
                updateVisual();
            }
        });

        // Visibility and live state update loop
        btn.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            var inGame = ApiMenus.isInGame();
            if (!inGame) {
                btn.visible = false;
                return;
            }
            var isEnabled = ApiConfig.getBool("api_hud_" + def.id + "_enabled", false);
            if (!isEnabled) {
                btn.visible = false;
                return;
            }
            var isPanelOpen:Bool = (_overlay != null && (_overlay.currentFrameLabel == "Panel" || ApiDashboardModal.isOpen()));
            btn.visible = !isPanelOpen;
            if (btn.visible) {
                updateVisual();
            }
        });

        updateVisual();
        return btn;
    }

    public static function isButtonEnabled(id:String):Bool {
        return ApiConfig.getBool("api_hud_" + id + "_enabled", false);
    }

    public static function setButtonEnabled(id:String, enabled:Bool):Void {
        ApiConfig.setBool("api_hud_" + id + "_enabled", enabled);
    }

    public static function resetAllPositions():Void {
        for (def in _defs) {
            ApiConfig.setInt("api_hud_" + def.id + "_x", Math.round(def.defaultX));
            ApiConfig.setInt("api_hud_" + def.id + "_y", Math.round(def.defaultY));
            var btn = _buttons.get(def.id);
            if (btn != null) {
                btn.x = def.defaultX;
                btn.y = def.defaultY;
            }
        }
        try {
            ApiMenus.resetMenuButtonPosition();
        } catch (_:Dynamic) {}
    }
}
#else
class ApiHudManager {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isButtonEnabled(id:String):Bool return false;
    public static function setButtonEnabled(id:String, enabled:Bool):Void {}
    public static function resetAllPositions():Void {}
}
#end
