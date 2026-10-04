package ui.prompts;

#if flash
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
        container.graphics.beginFill(0x121212, 0.95);
        container.graphics.lineStyle(1, 0x2A2A2A);
        container.graphics.drawRoundRect(0, 0, w, h, 8, 8);
        container.graphics.endFill();

        container.x = (960 - w) / 2;
        container.y = (500 - h) / 2;
        if (container.x < 0) container.x = 0;
        if (container.y < 0) container.y = 0;

        var title = new TextField();
        var fmt = new TextFormat("_sans", 16, 0xE0E0E0, true);
        fmt.align = TextFormatAlign.CENTER;
        title.defaultTextFormat = fmt;
        title.text = titleText;
        title.width = w;
        title.y = 10;
        title.selectable = false;
        title.mouseEnabled = false;
        container.addChild(title);

        // Vector Close Button (✕) in top-right corner
        var closeBtn = new Sprite();
        var cbW:Float = 26;
        var cbH:Float = 22;
        closeBtn.buttonMode = true;
        closeBtn.x = w - cbW - 8;
        closeBtn.y = 8;

        var renderCloseBtn = function(isHover:Bool):Void {
            closeBtn.graphics.clear();
            var bg = isHover ? 0x990000 : 0x1E1E1E;
            var border = isHover ? 0xCC0000 : 0x333333;
            var xColor = isHover ? 0xFFFFFF : 0xAAAAAA;

            closeBtn.graphics.beginFill(bg, 1);
            closeBtn.graphics.lineStyle(1, border);
            closeBtn.graphics.drawRoundRect(0, 0, cbW, cbH, 4, 4);
            closeBtn.graphics.endFill();

            var cx:Float = cbW / 2;
            var cy:Float = cbH / 2;
            var size:Float = 3.5;
            closeBtn.graphics.lineStyle(2, xColor, 1);
            closeBtn.graphics.moveTo(cx - size, cy - size);
            closeBtn.graphics.lineTo(cx + size, cy + size);
            closeBtn.graphics.moveTo(cx + size, cy - size);
            closeBtn.graphics.lineTo(cx - size, cy + size);
        };
        renderCloseBtn(false);

        closeBtn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            renderCloseBtn(true);
        });
        closeBtn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            renderCloseBtn(false);
        });
        closeBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            close();
        });
        container.addChild(closeBtn);

        _currentContainer = container;
        return container;
    }

    public static function createButton(
        label:String,
        w:Float,
        h:Float,
        onClick:Void->Void,
        isPrimary:Bool = false
    ):Sprite {
        var btn = new Sprite();
        var bg = isPrimary ? 0x990000 : 0x1E1E1E;
        var border = isPrimary ? 0xCC0000 : 0x3A3A3A;
        var hoverBg = isPrimary ? 0xBB0000 : 0x333333;
        var hoverBorder = isPrimary ? 0xFF0000 : 0x555555;
        var textColor = isPrimary ? 0xFFFFFF : 0xCCCCCC;

        btn.graphics.beginFill(bg, 1);
        btn.graphics.lineStyle(1, border);
        btn.graphics.drawRoundRect(0, 0, w, h, 5, 5);
        btn.graphics.endFill();
        btn.buttonMode = true;
        btn.mouseChildren = false;

        var txt = new TextField();
        var fmt = new TextFormat("_sans", 12, textColor, true);
        fmt.align = TextFormatAlign.CENTER;
        txt.defaultTextFormat = fmt;
        txt.text = label;
        txt.width = w;
        txt.y = (h - 20) / 2;
        txt.selectable = false;
        txt.mouseEnabled = false;
        btn.addChild(txt);

        btn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            btn.graphics.clear();
            btn.graphics.beginFill(hoverBg, 1);
            btn.graphics.lineStyle(1, hoverBorder);
            btn.graphics.drawRoundRect(0, 0, w, h, 5, 5);
            btn.graphics.endFill();
            txt.textColor = 0xFFFFFF;
        });

        btn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            btn.graphics.clear();
            btn.graphics.beginFill(bg, 1);
            btn.graphics.lineStyle(1, border);
            btn.graphics.drawRoundRect(0, 0, w, h, 5, 5);
            btn.graphics.endFill();
            txt.textColor = textColor;
        });

        var lastTriggerTime:Float = 0;
        var handleAction = function():Void {
            var now = haxe.Timer.stamp();
            if (now - lastTriggerTime < 0.25) return;
            lastTriggerTime = now;
            if (onClick != null) {
                try {
                    onClick();
                } catch (e:Dynamic) {
                    ui.ApiNotificationManager.notify("Action error: " + e);
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
        } catch (_:Dynamic) {
            try {
                btn.addEventListener("touchTap", function(e:Dynamic):Void {
                    handleAction();
                });
            } catch (_:Dynamic) {}
        }

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
        input.defaultTextFormat = new TextFormat("_sans", multiline ? 12 : 14, 0xFFFFFF);
        input.border = true;
        input.borderColor = 0x555555;
        input.background = true;
        input.backgroundColor = 0x222222;
        input.width = w;
        input.height = h;
        input.text = initialText != null ? initialText : "";
        return input;
    }

    public static function createLabel(text:String, w:Float, size:Int = 14, isBold:Bool = false):TextField {
        var lbl = new TextField();
        lbl.defaultTextFormat = new TextFormat("_sans", size, 0xCCCCCC, isBold);
        lbl.text = text;
        lbl.width = w;
        lbl.selectable = false;
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

