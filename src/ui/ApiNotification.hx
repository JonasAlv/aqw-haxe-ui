package ui;

#if flash
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.events.TimerEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.utils.Timer;

class ApiNotification extends Sprite {
    private static inline var DISMISS_DELAY:Float = 4000.0;
    private static inline var FADE_SPEED:Float = 0.07;
    private static inline var PAD_X:Float = 10.0;
    private static inline var PAD_Y:Float = 9.0;
    private static inline var CLOSE_W:Float = 16.0;
    private static inline var FONT_SIZE:Int = 12;
    private static inline var LINE_H:Float = 15.0;

    /** Fixed card width; only the height follows the message. */
    public static inline var CARD_WIDTH:Float = 280.0;
    public static inline var MIN_HEIGHT:Float = 38.0;
    /** Past this the text field scrolls instead of growing, so one huge message cannot fill the screen. */
    public static inline var MAX_HEIGHT:Float = 220.0;

    private var _messageTxt:TextField;
    private var _closeBtn:Sprite;
    private var _timer:Timer;
    private var _onDismiss:ApiNotification->Void;
    private var _fading:Bool = false;
    private var _boxHeight:Float = MIN_HEIGHT;
    private var _scrolling:Bool = false;
    private var _baseMessage:String;
    private var _repeatCount:Int = 1;
    private var _fmt:TextFormat;

    public var id:String;
    public var sticky:Bool;

    /** Height the manager should reserve when stacking cards. */
    public var contentHeight(get, never):Float;

    public var baseMessage(get, never):String;
    public var repeatCount(get, never):Int;

    // Plain Haxe accessors, no @:getter. Combining @:getter with a method already named
    // `get_<prop>` emits no accessor at all, which made `notif.contentHeight` throw Error #1069
    // on these sealed classes; the `_prop` + @:getter form used elsewhere needs a duplicate
    // `get_<prop>` alongside it and is not worth the boilerplate here.
    public function get_contentHeight():Float { return _boxHeight; }
    public function get_baseMessage():String { return _baseMessage; }
    public function get_repeatCount():Int { return _repeatCount; }

    public function new(id:String, message:String, sticky:Bool = false) {
        super();
        this.id = id;
        this.sticky = sticky;
        _baseMessage = message != null ? message : "";

        _fmt = new TextFormat("_sans", FONT_SIZE, 0xEEEEEE, true);
        _fmt.align = TextFormatAlign.LEFT;
        _fmt.leading = 2;

        _messageTxt = new TextField();
        _messageTxt.defaultTextFormat = _fmt;
        _messageTxt.selectable = false;
        _messageTxt.mouseEnabled = false;
        _messageTxt.wordWrap = true;
        _messageTxt.x = PAD_X;
        // Measured and placed by layout(), which needs the field on the display list first.
        this.addChild(_messageTxt);
        this.renderMessage();

        if (!sticky) {
            _closeBtn = new Sprite();
            _closeBtn.buttonMode = true;
            _closeBtn.useHandCursor = true;
            _closeBtn.addEventListener(MouseEvent.CLICK, onCloseClick);
            _closeBtn.addEventListener(MouseEvent.MOUSE_OVER, onCloseBtnOver);
            _closeBtn.addEventListener(MouseEvent.MOUSE_OUT, onCloseBtnOut);
            this.addChild(_closeBtn);
        }

        this.layout();

        this.addEventListener(MouseEvent.MOUSE_OVER, onMouseOver);
        this.addEventListener(MouseEvent.MOUSE_OUT, onMouseOut);

        if (!sticky) {
            _timer = new Timer(DISMISS_DELAY, 1);
            _timer.addEventListener(TimerEvent.TIMER, onDismissTimer);
            _timer.start();
        }

        this.alpha = 0;
        this.addEventListener(Event.ENTER_FRAME, onFadeIn);
    }

    private function renderMessage():Void {
        var text:String = _baseMessage;
        if (_repeatCount > 1) text += " (x" + Std.string(_repeatCount) + ")";
        _messageTxt.text = text;
    }

    /**
     * Sizes the card to the wrapped text and repaints the chrome around it.
     *
     * The text field must already be on the display list with a fixed width before `textHeight` is
     * meaningful, which is why layout runs after `addChild` rather than in the constructor. Anything
     * taller than `MAX_HEIGHT` keeps the cap and lets the field scroll, so long messages are never
     * silently cut.
     */
    private function layout():Void {
        var textW:Float = CARD_WIDTH - PAD_X * 2 - (sticky ? 0 : CLOSE_W);
        if (_messageTxt.width != textW) _messageTxt.width = textW;

        var measured:Float = _messageTxt.textHeight;
        if (!(measured > 0)) measured = LINE_H;
        var desired:Float = measured + PAD_Y * 2;
        if (desired < MIN_HEIGHT) desired = MIN_HEIGHT;

        _scrolling = desired > MAX_HEIGHT;
        _boxHeight = _scrolling ? MAX_HEIGHT : desired;

        _messageTxt.height = _boxHeight - PAD_Y * 2;
        _messageTxt.y = PAD_Y;
        _messageTxt.scrollV = 0;
        _messageTxt.mouseEnabled = _scrolling;

        this.graphics.clear();
        this.graphics.beginFill(0x111111, 0.92);
        this.graphics.drawRect(0, 0, CARD_WIDTH, _boxHeight);
        this.graphics.endFill();

        this.graphics.beginFill(0x4a9eff, 1);
        this.graphics.drawRect(0, 0, 4, _boxHeight);
        this.graphics.endFill();

        if (_closeBtn != null) {
            _closeBtn.graphics.clear();
            var cx:Float = CARD_WIDTH - CLOSE_W / 2 - 2;
            var cy:Float = _boxHeight / 2;
            var r:Float = 5;
            _closeBtn.graphics.lineStyle(2, 0x888888, 1);
            _closeBtn.graphics.moveTo(cx - r, cy - r);
            _closeBtn.graphics.lineTo(cx + r, cy + r);
            _closeBtn.graphics.moveTo(cx + r, cy - r);
            _closeBtn.graphics.lineTo(cx - r, cy + r);
            _closeBtn.graphics.beginFill(0x000000, 0);
            _closeBtn.graphics.drawRect(cx - r - 4, cy - r - 4, (r + 4) * 2, (r + 4) * 2);
            _closeBtn.graphics.endFill();
        }
    }

    /** True when `message` is the same text this card already shows. */
    public function isSameMessage(message:String):Bool {
        return message != null && message == _baseMessage;
    }

    /**
     * Folds a repeat of the same message into this card as a `(xN)` counter instead of stacking
     * another identical card, and restarts the dismiss timer.
     */
    public function bumpRepeat():Void {
        if (_fading) return;
        _repeatCount++;
        this.renderMessage();
        this.layout();
        if (_timer != null) {
            _timer.stop();
            _timer.start();
        }
    }

    /**
     * Adopts the repeat count decided upstream instead of only counting locally.
     *
     * `ApiFeedback` in the API owns the fold policy (identity window and total), so the count it
     * sends is authoritative. Local counting alone drifts whenever a card is created after the
     * message was first requested, which is exactly what the pre-init queue causes.
     */
    public function setRepeatCount(count:Int):Void {
        if (count < 1) count = 1;
        if (count == _repeatCount) return;
        _repeatCount = count;
        this.renderMessage();
        this.layout();
    }

    /** Repaints the close icon; hover feedback shares the geometry set by layout(). */
    private function drawCloseIcon(color:Int):Void {
        if (_closeBtn == null) return;
        _closeBtn.graphics.clear();
        var cx:Float = CARD_WIDTH - CLOSE_W / 2 - 2;
        var cy:Float = _boxHeight / 2;
        var r:Float = 5;
        _closeBtn.graphics.lineStyle(2, color, 1);
        _closeBtn.graphics.moveTo(cx - r, cy - r);
        _closeBtn.graphics.lineTo(cx + r, cy + r);
        _closeBtn.graphics.moveTo(cx + r, cy - r);
        _closeBtn.graphics.lineTo(cx - r, cy + r);

        // Hit area padding
        _closeBtn.graphics.beginFill(0x000000, 0);
        _closeBtn.graphics.drawRect(cx - r - 4, cy - r - 4, (r + 4) * 2, (r + 4) * 2);
        _closeBtn.graphics.endFill();
    }

    public function setOnDismiss(fn:ApiNotification->Void):Void {
        _onDismiss = fn;
    }

    public function dismiss():Void {
        if (_fading) return;
        _fading = true;
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
        this.removeEventListener(Event.ENTER_FRAME, onFadeIn);
        this.addEventListener(Event.ENTER_FRAME, onFadeOut);
    }

    private function onMouseOver(e:MouseEvent):Void {
        if (_timer != null) _timer.stop();
    }

    private function onMouseOut(e:MouseEvent):Void {
        if (_timer != null) _timer.start();
    }

    private function onCloseBtnOver(e:MouseEvent):Void {
        drawCloseIcon(0xffffff);
    }

    private function onCloseBtnOut(e:MouseEvent):Void {
        drawCloseIcon(0x888888);
    }

    private function onCloseClick(e:MouseEvent):Void {
        e.stopPropagation();
        dismiss();
    }

    private function onDismissTimer(e:TimerEvent):Void {
        dismiss();
    }

    private function onFadeIn(e:Event):Void {
        this.alpha += FADE_SPEED * 2;
        if (this.alpha >= 1) {
            this.alpha = 1;
            this.removeEventListener(Event.ENTER_FRAME, onFadeIn);
        }
    }

    private function onFadeOut(e:Event):Void {
        this.alpha -= FADE_SPEED;
        if (this.alpha <= 0) {
            this.alpha = 0;
            this.removeEventListener(Event.ENTER_FRAME, onFadeOut);
            if (this.parent != null) this.parent.removeChild(this);
            if (_onDismiss != null) _onDismiss(this);
        }
    }

    public function destroy():Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
        this.removeEventListener(Event.ENTER_FRAME, onFadeIn);
        this.removeEventListener(Event.ENTER_FRAME, onFadeOut);
        this.removeEventListener(MouseEvent.MOUSE_OVER, onMouseOver);
        this.removeEventListener(MouseEvent.MOUSE_OUT, onMouseOut);
        if (_closeBtn != null) {
            _closeBtn.removeEventListener(MouseEvent.CLICK, onCloseClick);
            _closeBtn.removeEventListener(MouseEvent.MOUSE_OVER, onCloseBtnOver);
            _closeBtn.removeEventListener(MouseEvent.MOUSE_OUT, onCloseBtnOut);
        }
        if (this.parent != null) this.parent.removeChild(this);
    }
}
#else
class ApiNotification {
    public var id:String;
    public var sticky:Bool;
    public var contentHeight:Float = 38;
    public var baseMessage:String;
    public var repeatCount:Int = 1;
    public function new(id:String, message:String, sticky:Bool = false) {
        this.id = id;
        this.sticky = sticky;
        this.baseMessage = message != null ? message : "";
    }
    public function isSameMessage(message:String):Bool { return message != null && message == baseMessage; }
    public function bumpRepeat():Void { repeatCount++; }
    public function setOnDismiss(fn:ApiNotification->Void) {}
    public function dismiss():Void {}
    public function destroy():Void {}
}
#end

