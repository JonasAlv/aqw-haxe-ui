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

class ApiPromptModal {
    private static var _currentContainer:Sprite;
    private static var _backdrop:Sprite;
    private static var _dialogWidth:Float = 0;
    private static var _dialogHeight:Float = 0;

    public static function createDialog(w:Float, h:Float, titleText:String):Sprite {
        close();
        _dialogWidth = w;
        _dialogHeight = h;

        var container = new Sprite();
        // Modern glass plate
        container.graphics.beginFill(0x161616, 0.96);
        container.graphics.lineStyle(1, 0x2E2E2E);
        container.graphics.drawRoundRect(0, 0, w, h, 6, 6);
        container.graphics.endFill();

        // Top glass bevel highlight
        container.graphics.lineStyle(1, 0x383838, 0.55);
        container.graphics.moveTo(3, 1);
        container.graphics.lineTo(w - 3, 1);

        // Crimson accent pill on top left
        container.graphics.lineStyle(0, 0, 0);
        container.graphics.beginFill(0xC82333, 1.0);
        container.graphics.drawRoundRect(14, 12, 3.5, 16, 1, 1);
        container.graphics.endFill();

        container.x = (960 - w) / 2;
        container.y = (500 - h) / 2;
        if (container.x < 0) container.x = 0;
        if (container.y < 0) container.y = 0;

        var title = new TextField();
        var fmt = new TextFormat("_sans", 13, 0xEEEEEE, true);
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
        div.graphics.lineStyle(1, 0x262626, 0.9);
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
            var bg = isHover ? 0x2A2A2A : 0x1A1A1A;
            var border = isHover ? 0xC82333 : 0x282828;
            var xColor = isHover ? 0xFF5555 : 0x999999;

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
        fontSize:Int = 11
    ):Sprite {
        var btn = new Sprite();
        var baseBg = customBg != null ? customBg : (isPrimary ? 0x1F1414 : 0x161616);
        var baseBorder = customBorder != null ? customBorder : (isPrimary ? 0xC82333 : 0x2E2E2E);
        var textColor = (customBorder != null || isPrimary) ? 0xFF8888 : 0xCCCCCC;

        var redraw = function(hover:Bool):Void {
            btn.graphics.clear();
            var bg = hover ? 0x282828 : baseBg;
            var border = hover ? (isPrimary ? 0xE53935 : 0x555555) : baseBorder;
            btn.graphics.beginFill(bg, 0.95);
            btn.graphics.lineStyle(1, border);
            btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
            btn.graphics.endFill();

            btn.graphics.lineStyle(1, hover ? 0x555555 : 0x383838, 0.5);
            btn.graphics.moveTo(2, 1);
            btn.graphics.lineTo(w - 2, 1);
        };
        redraw(false);

        btn.buttonMode = true;
        btn.mouseChildren = false;

        var txt = new TextField();
        var fmt = new TextFormat("_sans", fontSize, textColor, true);
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
            txt.textColor = 0xFFFFFF;
        });
        btn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            redraw(false);
            txt.textColor = textColor;
        });

        var flashBtn = function():Void {
            var prevAlpha = btn.alpha;
            btn.alpha = 1.0;
            var highlight = new Shape();
            highlight.graphics.lineStyle(1.8, isPrimary ? 0xFF5555 : 0x00FF88);
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
        var fmt = new TextFormat("_sans", multiline ? 11 : 12, 0xEEEEEE);
        input.defaultTextFormat = fmt;
        input.border = true;
        input.borderColor = 0x2E2E2E;
        input.background = true;
        input.backgroundColor = 0x181818;
        input.width = w;
        input.height = h;
        input.text = initialText != null ? initialText : "";
        return input;
    }

    public static function createLabel(text:String, w:Float, size:Int = 11, isBold:Bool = false):TextField {
        var lbl = new TextField();
        lbl.defaultTextFormat = new TextFormat("_sans", size, 0xCCCCCC, isBold);
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
            var sw:Float = 960;
            var sh:Float = 500;
            if (overlay.stage != null) {
                sw = overlay.stage.stageWidth > 0 ? overlay.stage.stageWidth : 960;
                sh = overlay.stage.stageHeight > 0 ? overlay.stage.stageHeight : 500;
            }

            if (_backdrop == null) {
                _backdrop = new Sprite();
            }
            _backdrop.graphics.clear();
            _backdrop.graphics.beginFill(0x000000, 0.65);
            _backdrop.graphics.drawRect(0, 0, sw, sh);
            _backdrop.graphics.endFill();

            if (container != null) {
                var dw:Float = _dialogWidth > 0 ? _dialogWidth : container.width;
                var dh:Float = _dialogHeight > 0 ? _dialogHeight : container.height;
                container.x = Math.max(0, (sw - dw) / 2);
                container.y = Math.max(0, (sh - dh) / 2);
            }

            overlay.addChild(_backdrop);
            overlay.addChild(container);

            if (overlay.stage != null) {
                overlay.stage.addEventListener(KeyboardEvent.KEY_DOWN, onStageKeyDown);
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
    public static function close():Void {}
}
#end
