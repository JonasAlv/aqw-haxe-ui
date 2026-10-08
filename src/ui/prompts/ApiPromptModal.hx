package ui.prompts;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;

import ui.ApiStyle;

class ApiPromptModal {
    private static var _currentContainer:Sprite;
    private static var _backdrop:Sprite;
    private static var _dialogWidth:Float = 0;
    private static var _dialogHeight:Float = 0;

    public static function isOpen():Bool {
        return _currentContainer != null && _currentContainer.parent != null;
    }

    public static function createDialog(w:Float, h:Float, titleText:String):Sprite {
        close();
        _dialogWidth = w;
        _dialogHeight = h;

        var container = new Sprite();
        // Modern glass plate
        container.graphics.beginFill(ApiStyle.COLOR_BG_DIALOG, ApiStyle.ALPHA_DIALOG);
        container.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT);
        container.graphics.drawRoundRect(0, 0, w, h, ApiStyle.CORNER_RADIUS, ApiStyle.CORNER_RADIUS);
        container.graphics.endFill();

        // Top glass bevel highlight
        container.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_HIGHLIGHT, 0.55);
        container.graphics.moveTo(3, 1);
        container.graphics.lineTo(w - 3, 1);

        // Crimson accent pill on top left
        container.graphics.lineStyle(0, 0, 0);
        container.graphics.beginFill(ApiStyle.COLOR_ACCENT_CRIMSON, 1.0);
        container.graphics.drawRoundRect(14, 12, 3.5, 16, 1, 1);
        container.graphics.endFill();

        container.x = (960 - w) / 2;
        container.y = (500 - h) / 2;
        if (container.x < ApiStyle.SCREEN_MARGIN) container.x = ApiStyle.SCREEN_MARGIN;
        if (container.y < ApiStyle.SCREEN_MARGIN) container.y = ApiStyle.SCREEN_MARGIN;

        var title = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 13, ApiStyle.COLOR_TEXT_PRIMARY, true);
        fmt.align = TextFormatAlign.LEFT;
        title.defaultTextFormat = fmt;
        title.text = titleText;
        title.x = 24;
        title.y = 10;
        title.width = w - 60;
        title.height = 22;
        title.selectable = false;
        title.mouseEnabled = false;
        container.addChild(title);

        // Divider below header
        var div = new Shape();
        div.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DIVIDER, 0.9);
        div.graphics.moveTo(12, 34);
        div.graphics.lineTo(w - 12, 34);
        container.addChild(div);

        // Vector Close Button (✕) in top-right corner
        var closeBtn = new Sprite();
        var cbW:Float = 22;
        var cbH:Float = 20;
        closeBtn.buttonMode = true;
        closeBtn.x = w - cbW - 10;
        closeBtn.y = 8;

        var renderCloseBtn = function(isHover:Bool):Void {
            closeBtn.graphics.clear();
            var bg = isHover ? ApiStyle.COLOR_STATUS_ERROR : ApiStyle.COLOR_BG_SURFACE;
            var border = isHover ? ApiStyle.COLOR_STATUS_ERROR_HOVER : ApiStyle.COLOR_BORDER_DEFAULT;
            var xColor = isHover ? ApiStyle.COLOR_TEXT_TITLE : ApiStyle.COLOR_TEXT_MUTED;

            closeBtn.graphics.beginFill(bg, 0.9);
            closeBtn.graphics.lineStyle(1, border);
            closeBtn.graphics.drawRoundRect(0, 0, cbW, cbH, 4, 4);
            closeBtn.graphics.endFill();

            var cx:Float = cbW / 2;
            var cy:Float = cbH / 2;
            var size:Float = 3.2;
            closeBtn.graphics.lineStyle(1.8, xColor, 1);
            closeBtn.graphics.moveTo(cx - size, cy - size);
            closeBtn.graphics.lineTo(cx + size, cy + size);
            closeBtn.graphics.moveTo(cx + size, cy - size);
            closeBtn.graphics.lineTo(cx - size, cy + size);
        };
        renderCloseBtn(false);

        closeBtn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void renderCloseBtn(true));
        closeBtn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void renderCloseBtn(false));
        closeBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void close());
        container.addChild(closeBtn);

        // Draggable header strip (strictly clamped to screen, no edge snapping)
        var dragBar = new Sprite();
        dragBar.graphics.beginFill(0x000000, 0.0);
        dragBar.graphics.drawRect(0, 0, w - cbW - 20, 34);
        dragBar.graphics.endFill();
        dragBar.buttonMode = true;
        dragBar.useHandCursor = true;
        container.addChild(dragBar);

        var isDragging:Bool = false;
        var dragStartX:Float = 0;
        var dragStartY:Float = 0;

        dragBar.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            isDragging = true;
            dragStartX = e.stageX - container.x;
            dragStartY = e.stageY - container.y;
            if (container.stage != null) {
                var onDragMove = null;
                var onDragUp = null;
                onDragMove = function(me:MouseEvent):Void {
                    if (isDragging) {
                        var nx:Float = Math.round(me.stageX - dragStartX);
                        var ny:Float = Math.round(me.stageY - dragStartY);
                        var sw:Float = (container.stage.stageWidth > 0) ? container.stage.stageWidth : 960;
                        var sh:Float = (container.stage.stageHeight > 0) ? container.stage.stageHeight : 550;
                        if (nx < ApiStyle.SCREEN_MARGIN) nx = ApiStyle.SCREEN_MARGIN;
                        if (ny < ApiStyle.SCREEN_MARGIN) ny = ApiStyle.SCREEN_MARGIN;
                        if (nx > sw - w - ApiStyle.SCREEN_MARGIN) nx = sw - w - ApiStyle.SCREEN_MARGIN;
                        if (ny > sh - h - ApiStyle.SCREEN_MARGIN) ny = sh - h - ApiStyle.SCREEN_MARGIN;
                        container.x = nx;
                        container.y = ny;
                    }
                };
                onDragUp = function(ue:MouseEvent):Void {
                    isDragging = false;
                    if (container.stage != null) {
                        container.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onDragMove);
                        container.stage.removeEventListener(MouseEvent.MOUSE_UP, onDragUp);
                    }
                };
                container.stage.addEventListener(MouseEvent.MOUSE_MOVE, onDragMove);
                container.stage.addEventListener(MouseEvent.MOUSE_UP, onDragUp);
            }
        });

        _currentContainer = container;
        return container;
    }

    public static function createButton(
        label:String,
        w:Float,
        h:Float,
        onClick:Void->Void,
        isPrimary:Bool = false,
        customBg:Null<Int> = null,
        customBorder:Null<Int> = null,
        fontSize:Int = 11,
        customTextColor:Null<Int> = null
    ):Sprite {
        var btn = new Sprite();
        var baseBg = customBg != null ? customBg : (isPrimary ? ApiStyle.COLOR_ACCENT_PRIMARY : ApiStyle.COLOR_BG_CARD);
        var baseBorder = customBorder != null ? customBorder : (isPrimary ? ApiStyle.COLOR_ACCENT_HOVER : ApiStyle.COLOR_BORDER_DEFAULT);
        var textColor = customTextColor != null ? customTextColor : (isPrimary ? ApiStyle.COLOR_TEXT_ON_ACCENT : ApiStyle.COLOR_TEXT_PRIMARY);

        var redraw = function(hover:Bool):Void {
            btn.graphics.clear();
            var bg = hover ? (isPrimary ? ApiStyle.COLOR_ACCENT_HOVER : ApiStyle.COLOR_BTN_BG_HOVER) : baseBg;
            var border = hover ? (isPrimary ? ApiStyle.COLOR_TEXT_TITLE : ApiStyle.COLOR_BORDER_HIGHLIGHT) : baseBorder;
            btn.graphics.beginFill(bg, 1.0);
            btn.graphics.lineStyle(1, border);
            btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
            btn.graphics.endFill();

            btn.graphics.lineStyle(1, hover ? ApiStyle.COLOR_BEVEL_LIGHT : ApiStyle.COLOR_BEVEL_SUBTLE, 0.5);
            btn.graphics.moveTo(2, 1);
            btn.graphics.lineTo(w - 2, 1);
        };
        redraw(false);

        btn.buttonMode = true;
        btn.mouseChildren = false;

        var txt = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, fontSize, textColor, true);
        fmt.align = TextFormatAlign.CENTER;
        txt.defaultTextFormat = fmt;
        txt.text = label;
        txt.width = w;
        txt.y = (h - (fontSize + 8)) / 2;
        txt.selectable = false;
        txt.mouseEnabled = false;
        btn.addChild(txt);

        btn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            redraw(true);
            txt.textColor = isPrimary ? ApiStyle.COLOR_TEXT_ON_ACCENT : (customTextColor != null ? customTextColor : ApiStyle.COLOR_TEXT_TITLE);
        });
        btn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            redraw(false);
            txt.textColor = textColor;
        });

        var flashBtn = function():Void {
            var prevAlpha = btn.alpha;
            btn.alpha = 1.0;
            var highlight = new Shape();
            highlight.graphics.lineStyle(1.8, isPrimary ? ApiStyle.COLOR_ACCENT_PRIMARY : ApiStyle.COLOR_STATUS_ACTIVE);
            highlight.graphics.drawRoundRect(0, 0, w, h, 4, 4);
            btn.addChild(highlight);
            haxe.Timer.delay(function():Void {
                if (highlight.parent != null) highlight.parent.removeChild(highlight);
                btn.alpha = prevAlpha;
            }, 120);
        };

        var lastTriggerTime:Float = 0;
        var handleAction = function():Void {
            var now = haxe.Timer.stamp();
            if (now - lastTriggerTime < 0.25) return;
            lastTriggerTime = now;
            flashBtn();
            if (onClick != null) {
                try {
                    onClick();
                } catch (e:Dynamic) {
                    ApiNotificationManager.notify("Action error: " + e);
                }
            }
        };

        btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            handleAction();
        });

        try {
            var touchEventCls:Dynamic = untyped __global__["flash.events.TouchEvent"];
            var touchTap:String = (touchEventCls != null && touchEventCls.TOUCH_TAP != null) ? touchEventCls.TOUCH_TAP : "touchTap";
            btn.addEventListener(touchTap, function(e:Dynamic):Void {
                handleAction();
            });
        } catch (_:Dynamic) {}

        return btn;
    }

    public static function createInput(
        w:Float,
        h:Float,
        initialText:String = "",
        multiline:Bool = false
    ):TextField {
        var input = new TextField();
        input.type = TextFieldType.INPUT;
        input.multiline = multiline;
        input.wordWrap = multiline;
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, multiline ? 11 : 12, ApiStyle.COLOR_TEXT_PRIMARY);
        input.defaultTextFormat = fmt;
        input.border = true;
        input.borderColor = ApiStyle.COLOR_BORDER_DEFAULT;
        input.background = true;
        input.backgroundColor = ApiStyle.COLOR_BG_INPUT;
        input.textColor = ApiStyle.COLOR_TEXT_PRIMARY;
        input.width = w;
        input.height = h;
        input.text = initialText != null ? initialText : "";
        return input;
    }

    public static function createLabel(text:String, w:Float, size:Int = 11, isBold:Bool = false):TextField {
        var lbl = new TextField();
        lbl.defaultTextFormat = new TextFormat(ApiStyle.FONT_FAMILY, size, isBold ? ApiStyle.COLOR_TEXT_TITLE : ApiStyle.COLOR_TEXT_PRIMARY, isBold);
        lbl.text = text;
        lbl.width = w;
        lbl.height = size + 8;
        lbl.selectable = false;
        lbl.mouseEnabled = false;
        return lbl;
    }

    public static function close():Void {
        _dialogWidth = 0;
        _dialogHeight = 0;
        if (_backdrop != null && _backdrop.parent != null) {
            _backdrop.parent.removeChild(_backdrop);
        }
        if (_currentContainer != null) {
            if (_currentContainer.stage != null) {
                _currentContainer.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onStageKeyDown);
            }
            if (_currentContainer.parent != null) {
                _currentContainer.parent.removeChild(_currentContainer);
            }
        }
        _currentContainer = null;
    }

    public static function show(overlay:Dynamic, container:Sprite):Void {
        if (overlay != null) {
            var target:Dynamic = (overlay.stage != null) ? overlay.stage : overlay;
            var sw:Float = (target.stageWidth != null && target.stageWidth > 0) ? target.stageWidth : 960;
            var sh:Float = (target.stageHeight != null && target.stageHeight > 0) ? target.stageHeight : 550;

            if (_backdrop == null) {
                _backdrop = new Sprite();
            }
            _backdrop.graphics.clear();
            _backdrop.graphics.beginFill(ApiStyle.COLOR_BG_BACKDROP, ApiStyle.ALPHA_BACKDROP);
            _backdrop.graphics.drawRect(0, 0, sw, sh);
            _backdrop.graphics.endFill();

            if (container != null) {
                var dw:Float = _dialogWidth > 0 ? _dialogWidth : container.width;
                var dh:Float = _dialogHeight > 0 ? _dialogHeight : container.height;
                container.x = Math.max(ApiStyle.SCREEN_MARGIN, Math.min(sw - dw - ApiStyle.SCREEN_MARGIN, (sw - dw) / 2));
                container.y = Math.max(ApiStyle.SCREEN_MARGIN, Math.min(sh - dh - ApiStyle.SCREEN_MARGIN, (sh - dh) / 2));
            }

            // Always add to target stage for absolute foreground priority over dashboard & widgets
            target.addChild(_backdrop);
            target.addChild(container);

            if (target.stage != null) {
                target.stage.addEventListener(KeyboardEvent.KEY_DOWN, onStageKeyDown);
            } else if (container != null) {
                container.addEventListener(Event.ADDED_TO_STAGE, function(e:Event):Void {
                    if (container.stage != null) {
                        container.stage.addEventListener(KeyboardEvent.KEY_DOWN, onStageKeyDown);
                    }
                });
            }
        }
    }

    private static function onStageKeyDown(e:KeyboardEvent):Void {
        if (e.keyCode == 27) { // ESC key
            close();
        }
    }
}
#else
class ApiPromptModal {
    public static function isOpen():Bool { return false; }
    public static function close():Void {}
}
#end
