package ui.topbar;

#if flash
import flash.display.DisplayObject;
import flash.display.Shape;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiConfig;
import ui.ApiDashboardModal;
import ui.ApiMenus;
import ui.ApiStyle;
import ui.topbar.TopBar;

/**
 * Standalone floating buttons for Menu, Auto, Jump, and Players.
 * Active automatically when TopBar is disabled, or can be pinned standalone.
 */
class StandaloneButtons {
    private static var _stage:Stage = null;
    private static var _host:Dynamic = null;

    private static var _btnMenu:Sprite = null;
    private static var _btnAuto:Sprite = null;
    private static var _dotAuto:Shape = null;
    private static var _btnJump:Sprite = null;
    private static var _btnPlayers:Sprite = null;

    private static var _allButtons:Array<Sprite> = [];
    private static var _buttonMap:Map<String, Sprite> = new Map();

    public static function init(stageObj:Stage, hostObj:Dynamic = null):Void {
        _stage = stageObj;
        _host = hostObj;

        if (_allButtons.length > 0) return;

        var btnW:Float = 78.0;
        var btnH:Float = 26.0;

        // 1. Menu button
        _btnMenu = createButton(
            "menu",
            "Menu",
            80.0,
            10.0,
            btnW,
            btnH,
            ApiStyle.COLOR_ACCENT_CRIMSON,
            false,
            function(btn:Sprite):Void {
                if (ApiDashboardModal.isOpen()) {
                    ApiDashboardModal.close();
                } else {
                    ApiDashboardModal.show(_stage, _host);
                }
            }
        );

        // 2. Auto / Combat button
        _btnAuto = createButton(
            "auto",
            "Auto",
            162.0,
            10.0,
            btnW,
            btnH,
            0x2ECC71,
            true,
            function(btn:Sprite):Void {
                TopBar.toggleAuto(btn.x, btn.y + btnH + 2.0);
            }
        );

        // 3. Jump button
        _btnJump = createButton(
            "jump",
            "Jump",
            244.0,
            10.0,
            btnW,
            btnH,
            0x38BDF8,
            false,
            function(btn:Sprite):Void {
                TopBar.toggleJump(btn.x, btn.y + btnH + 2.0);
            }
        );

        // 4. Players button
        _btnPlayers = createButton(
            "players",
            "Players",
            326.0,
            10.0,
            btnW,
            btnH,
            0xC084FC,
            false,
            function(btn:Sprite):Void {
                TopBar.togglePlayers(btn.x, btn.y + btnH + 2.0);
            }
        );

        _stage.addEventListener(Event.ENTER_FRAME, onStageFrame);
    }

    public static function isStandaloneButton(disp:DisplayObject):Bool {
        if (disp == null) return false;
        for (btn in _allButtons) {
            if (btn == disp || btn.contains(disp)) return true;
        }
        return false;
    }

    public static function isButtonEnabled(id:String):Bool {
        var topBarActive = TopBar.isTopBarEnabled();
        var key = "api_standalone_" + id + "_enabled";
        if (id == "menu") key = "api_floating_menu_enabled";

        if (!topBarActive) {
            return ApiConfig.getBool(key, true);
        } else {
            return ApiConfig.getBool(key, false);
        }
    }

    public static function setButtonEnabled(id:String, enabled:Bool):Void {
        var key = "api_standalone_" + id + "_enabled";
        if (id == "menu") key = "api_floating_menu_enabled";
        ApiConfig.setBool(key, enabled);
        updateVisibility();
    }

    public static function resetPositions():Void {
        setBtnPos("menu", 80.0, 10.0);
        setBtnPos("auto", 162.0, 10.0);
        setBtnPos("jump", 244.0, 10.0);
        setBtnPos("players", 326.0, 10.0);
    }

    private static function setBtnPos(id:String, px:Float, py:Float):Void {
        ApiConfig.setInt("api_floating_" + id + "_x", Math.round(px));
        ApiConfig.setInt("api_floating_" + id + "_y", Math.round(py));
        var btn = _buttonMap.get(id);
        if (btn != null) {
            btn.x = px;
            btn.y = py;
        }
    }

    public static function updateVisibility():Void {
        var inGame = ApiMenus.isInGame();
        var isModalOpen = ApiDashboardModal.isOpen() || isBlockedByHostPanel();

        for (id in _buttonMap.keys()) {
            var btn = _buttonMap.get(id);
            if (btn != null) {
                if (!inGame || isModalOpen) {
                    btn.visible = false;
                } else {
                    btn.visible = isButtonEnabled(id);
                }
            }
        }
    }

    private static function isBlockedByHostPanel():Bool {
        try {
            if (_host != null && Reflect.hasField(_host, "currentFrameLabel") && Reflect.field(_host, "currentFrameLabel") == "Panel") {
                return true;
            }
        } catch (_:Dynamic) {}
        return false;
    }

    private static var _lastAutoRunning:Int = -1;

    private static function onStageFrame(e:Event):Void {
        updateVisibility();

        if (_stage != null) {
            var sw:Float = (_stage.stageWidth > 0) ? _stage.stageWidth : 960.0;
            var sh:Float = (_stage.stageHeight > 0) ? _stage.stageHeight : 550.0;
            var btnW:Float = 78.0;
            var btnH:Float = 26.0;
            for (btn in _allButtons) {
                if (btn != null && btn.visible) {
                    if (btn.x > sw - btnW - ApiStyle.SCREEN_MARGIN) btn.x = Math.max(ApiStyle.SCREEN_MARGIN, sw - btnW - ApiStyle.SCREEN_MARGIN);
                    if (btn.y > sh - btnH - ApiStyle.SCREEN_MARGIN) btn.y = Math.max(ApiStyle.SCREEN_MARGIN, sh - btnH - ApiStyle.SCREEN_MARGIN);
                    if (btn.x < ApiStyle.SCREEN_MARGIN) btn.x = ApiStyle.SCREEN_MARGIN;
                    if (btn.y < ApiStyle.SCREEN_MARGIN) btn.y = ApiStyle.SCREEN_MARGIN;
                }
            }
        }

        if (_dotAuto != null && _btnAuto != null && _btnAuto.visible) {
            var running = (Api.combat != null && Api.combat.isRunning());
            if (TopBar.instance != null && TopBar.instance.isHunting()) running = true;
            var runningInt = running ? 1 : 0;
            if (runningInt != _lastAutoRunning) {
                _lastAutoRunning = runningInt;
                renderAutoDot(_dotAuto, running);
            }
        }
    }

    private static function renderAutoDot(dot:Shape, running:Bool):Void {
        dot.graphics.clear();
        dot.graphics.lineStyle(0, 0, 0);
        if (running) {
            dot.graphics.beginFill(ApiStyle.COLOR_STATUS_ACTIVE, 0.35);
            dot.graphics.drawCircle(8, 13, 4.5);
            dot.graphics.endFill();
            dot.graphics.beginFill(ApiStyle.COLOR_STATUS_ACTIVE, 1.0);
            dot.graphics.drawCircle(8, 13, 2.5);
            dot.graphics.endFill();
        } else {
            dot.graphics.beginFill(ApiStyle.COLOR_STATUS_INACTIVE, 0.85);
            dot.graphics.drawCircle(8, 13, 2.5);
            dot.graphics.endFill();
        }
    }

    private static function createButton(
        id:String,
        label:String,
        defaultX:Float,
        defaultY:Float,
        btnW:Float,
        btnH:Float,
        accentColor:Int,
        hasDot:Bool,
        onClick:Sprite->Void
    ):Sprite {
        var icon = new Sprite();
        icon.name = "ApiStandalone_" + id;
        icon.buttonMode = true;
        icon.useHandCursor = true;

        var bg = new Sprite();
        icon.addChild(bg);

        if (hasDot) {
            var dot = new Shape();
            icon.addChild(dot);
            if (id == "auto") _dotAuto = dot;
            renderAutoDot(dot, false);
        } else {
            var accentShape = new Shape();
            accentShape.graphics.beginFill(accentColor, 1.0);
            accentShape.graphics.drawRoundRect(5, 5, 3.5, 16, 1.5, 1.5);
            accentShape.graphics.endFill();
            icon.addChild(accentShape);
        }

        var txt = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_PRIMARY, true);
        fmt.align = hasDot ? TextFormatAlign.LEFT : TextFormatAlign.CENTER;
        txt.defaultTextFormat = fmt;
        txt.text = label;
        txt.x = hasDot ? 17 : 12;
        txt.y = 4;
        txt.width = hasDot ? (btnW - 20) : (btnW - 14);
        txt.height = 18;
        txt.selectable = false;
        txt.mouseEnabled = false;
        icon.addChild(txt);

        var renderBtn = function(isHover:Bool):Void {
            bg.graphics.clear();
            var bgCol = isHover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_WIDGET;
            var borderCol = isHover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT;

            bg.graphics.beginFill(bgCol, ApiStyle.ALPHA_WIDGET);
            bg.graphics.lineStyle(1, borderCol);
            bg.graphics.drawRoundRect(0, 0, btnW, btnH, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
            bg.graphics.endFill();

            bg.graphics.lineStyle(1, isHover ? ApiStyle.COLOR_BEVEL_LIGHT : ApiStyle.COLOR_BEVEL_SUBTLE, 0.55);
            bg.graphics.moveTo(3, 1);
            bg.graphics.lineTo(btnW - 3, 1);
        };
        renderBtn(false);

        icon.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void renderBtn(true));
        icon.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void renderBtn(false));

        var savedX = ApiConfig.getInt("api_floating_" + id + "_x", Math.round(defaultX));
        var savedY = ApiConfig.getInt("api_floating_" + id + "_y", Math.round(defaultY));
        icon.x = savedX;
        icon.y = savedY;

        _stage.addChild(icon);
        _allButtons.push(icon);
        _buttonMap.set(id, icon);

        var isDragging:Bool = false;
        var hasDragged:Bool = false;
        var startDownX:Float = 0;
        var startDownY:Float = 0;
        var dragStartX:Float = 0;
        var dragStartY:Float = 0;

        icon.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            isDragging = true;
            hasDragged = false;
            startDownX = e.stageX;
            startDownY = e.stageY;
            dragStartX = e.stageX - icon.x;
            dragStartY = e.stageY - icon.y;
            icon.cacheAsBitmap = false;
            if (_stage != null && icon.parent == _stage) {
                _stage.setChildIndex(icon, _stage.numChildren - 1);
            }
        });

        _stage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (isDragging) {
                var dx = e.stageX - startDownX;
                var dy = e.stageY - startDownY;
                if (Math.abs(dx) > 4 || Math.abs(dy) > 4) {
                    hasDragged = true;
                }
                if (hasDragged) {
                    var nx:Float = Math.round(e.stageX - dragStartX);
                    var ny:Float = Math.round(e.stageY - dragStartY);
                    var sw:Float = (_stage.stageWidth > 0) ? _stage.stageWidth : 960;
                    var sh:Float = (_stage.stageHeight > 0) ? _stage.stageHeight : 550;

                    if (nx < ApiStyle.SCREEN_MARGIN) nx = ApiStyle.SCREEN_MARGIN;
                    if (ny < ApiStyle.SCREEN_MARGIN) ny = ApiStyle.SCREEN_MARGIN;
                    if (nx > sw - btnW - ApiStyle.SCREEN_MARGIN) nx = sw - btnW - ApiStyle.SCREEN_MARGIN;
                    if (ny > sh - btnH - ApiStyle.SCREEN_MARGIN) ny = sh - btnH - ApiStyle.SCREEN_MARGIN;

                    icon.x = nx;
                    icon.y = ny;
                }
            }
        });

        _stage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            if (isDragging) {
                isDragging = false;
                icon.cacheAsBitmap = true;
                if (hasDragged) {
                    ApiConfig.setInt("api_floating_" + id + "_x", Math.round(icon.x));
                    ApiConfig.setInt("api_floating_" + id + "_y", Math.round(icon.y));
                } else {
                    if (onClick != null) onClick(icon);
                }
            }
        });

        return icon;
    }
}
#else
class StandaloneButtons {
    public static function init(stageObj:Dynamic, hostObj:Dynamic = null):Void {}
    public static function isButtonEnabled(id:String):Bool return false;
    public static function setButtonEnabled(id:String, enabled:Bool):Void {}
    public static function resetPositions():Void {}
    public static function updateVisibility():Void {}
    public static function isStandaloneButton(disp:Dynamic):Bool return false;
}
#end
