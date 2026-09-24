package ui;

#if flash
import flash.display.DisplayObject;
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.geom.Point;
import flash.text.TextField;
import flash.text.TextFormat;

class Dropdown extends Sprite {
    private static var _activeDropdown:Dropdown = null;

    private var _options:Array<String> = [];
    private var _selectedIndex:Int = 0;
    private var _listContainer:Sprite;
    private var _listMask:Shape;
    private var _listContent:Sprite;
    private var _listBg:Sprite;
    private var _scrollbarTrack:Shape;
    private var _scrollbarThumb:Shape;
    private var _btn:Sprite;
    private var _btnText:TextField;
    private var _arrowText:TextField;
    private var _isOpen:Bool = false;
    private var _onSelect:String->Void;
    private var _width:Float;
    private var _height:Float;

    // Drag / Touch Scrolling state
    private var _isDragging:Bool = false;
    private var _hasMovedBeyondThreshold:Bool = false;
    private var _dragStartY:Float = 0;
    private var _dragStartContentY:Float = 0;

    public function new(width:Float, height:Float, options:Array<String>, onSelect:String->Void = null) {
        super();
        _width = width;
        _height = height;
        _options = options != null ? options : [];
        _onSelect = onSelect;

        _btn = new Sprite();
        _btn.graphics.beginFill(0x222222, 1);
        _btn.graphics.lineStyle(1, 0x555555);
        _btn.graphics.drawRoundRect(0, 0, width, height, 4, 4);
        _btn.graphics.endFill();
        _btn.buttonMode = true;
        addChild(_btn);

        _btnText = new TextField();
        _btnText.defaultTextFormat = new TextFormat("_sans", 12, 0xFFFFFF);
        _btnText.width = width - 25;
        _btnText.height = 20;
        _btnText.x = 6;
        _btnText.y = (height - 20) / 2;
        _btnText.mouseEnabled = false;
        _btn.addChild(_btnText);

        _arrowText = new TextField();
        _arrowText.defaultTextFormat = new TextFormat("_sans", 10, 0xAAAAAA);
        _arrowText.text = "▼";
        _arrowText.width = 16;
        _arrowText.height = 20;
        _arrowText.x = width - 18;
        _arrowText.y = (height - 18) / 2;
        _arrowText.mouseEnabled = false;
        _btn.addChild(_arrowText);

        _listContainer = new Sprite();
        _listContainer.visible = false;
        addChild(_listContainer);

        var listHeight:Float = getVisibleListHeight();

        _listBg = new Sprite();
        _listBg.graphics.beginFill(0x151515, 0.98);
        _listBg.graphics.lineStyle(1, 0x555555);
        _listBg.graphics.drawRoundRect(0, 0, width, listHeight, 4, 4);
        _listBg.graphics.endFill();
        _listContainer.addChild(_listBg);

        _listMask = new Shape();
        _listMask.graphics.beginFill(0xFF0000);
        _listMask.graphics.drawRoundRect(0, 0, width, listHeight, 4, 4);
        _listMask.graphics.endFill();
        _listContainer.addChild(_listMask);

        _listContent = new Sprite();
        _listContent.mask = _listMask;
        _listContainer.addChild(_listContent);

        _scrollbarTrack = new Shape();
        _scrollbarThumb = new Shape();
        _listContainer.addChild(_scrollbarTrack);
        _listContainer.addChild(_scrollbarThumb);

        populateList(width, height);

        if (_options.length > 0 && _options[0] != null) {
            _btnText.text = _options[0];
        }

        _btn.addEventListener(MouseEvent.CLICK, onBtnClick);

        // Touch & mouse drag scrolling on listContainer
        _listContainer.addEventListener(MouseEvent.MOUSE_DOWN, onListMouseDown);

        // Mouse wheel scroll for desktop
        _listContainer.addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent):Void {
            var curListHeight:Float = getVisibleListHeight();
            if (_listContent.height <= curListHeight) return;
            var maxScroll:Float = curListHeight - _listContent.height;
            _listContent.y += e.delta * 20;
            if (_listContent.y > 0) _listContent.y = 0;
            if (_listContent.y < maxScroll) _listContent.y = maxScroll;
            updateScrollbar();
        });

        addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
    }

    private function getVisibleListHeight():Float {
        var maxItems:Int = 7;
        var count:Int = _options.length > 0 ? _options.length : 1;
        var listHeight:Float = Math.min(count, maxItems) * _height;
        if (listHeight < _height) listHeight = _height;
        return listHeight;
    }

    public function setOptions(newOptions:Array<String>):Array<String> {
        _options = newOptions != null ? newOptions : [];
        _listContent.y = 0;
        var listHeight:Float = getVisibleListHeight();

        _listMask.graphics.clear();
        _listMask.graphics.beginFill(0xFF0000);
        _listMask.graphics.drawRoundRect(0, 0, _width, listHeight, 4, 4);
        _listMask.graphics.endFill();

        _listBg.graphics.clear();
        _listBg.graphics.beginFill(0x151515, 0.98);
        _listBg.graphics.lineStyle(1, 0x555555);
        _listBg.graphics.drawRoundRect(0, 0, _width, listHeight, 4, 4);
        _listBg.graphics.endFill();

        populateList(_width, _height);

        if (_options.length > 0 && _options[0] != null) {
            _selectedIndex = 0;
            _btnText.text = _options[0];
        } else {
            _selectedIndex = -1;
            _btnText.text = "";
        }
        return _options;
    }

    public function getOptions():Array<String> {
        return _options;
    }

    public var options(get, set):Array<String>;
    public function get_options():Array<String> { return getOptions(); }
    public function set_options(newOptions:Array<String>):Array<String> { return setOptions(newOptions); }

    public function setSelectedItem(val:String):String {
        if (val == null) return val;
        var idx:Int = _options.indexOf(val);
        if (idx != -1) {
            _selectedIndex = idx;
            _btnText.text = val;
        }
        return val;
    }

    public function getSelectedItem():String {
        if (_options.length == 0 || _selectedIndex < 0 || _selectedIndex >= _options.length) return "";
        return _options[_selectedIndex];
    }

    public var selectedItem(get, set):String;
    public function get_selectedItem():String { return getSelectedItem(); }
    public function set_selectedItem(val:String):String { return setSelectedItem(val); }

    private function populateList(w:Float, h:Float):Void {
        while (_listContent.numChildren > 0) _listContent.removeChildAt(0);
        for (i in 0..._options.length) {
            var optBtn = new Sprite();
            optBtn.graphics.beginFill(i % 2 == 0 ? 0x1e1e1e : 0x262626, 1);
            optBtn.graphics.drawRect(0, 0, w, h);
            optBtn.graphics.endFill();
            optBtn.y = i * h;
            optBtn.buttonMode = true;

            var optTxt = new TextField();
            optTxt.defaultTextFormat = new TextFormat("_sans", 12, 0xDDDDDD);
            optTxt.text = (_options[i] != null) ? _options[i] : "";
            optTxt.width = w - 16;
            optTxt.height = 20;
            optTxt.x = 6;
            optTxt.y = (h - 20) / 2;
            optTxt.mouseEnabled = false;
            optBtn.addChild(optTxt);

            optBtn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
                var tg:Sprite = cast e.currentTarget;
                tg.graphics.clear();
                tg.graphics.beginFill(0x3a3a3a, 1);
                tg.graphics.drawRect(0, 0, w, h);
                tg.graphics.endFill();
                (cast(tg.getChildAt(0), TextField)).textColor = 0xFFFFFF;
            });
            optBtn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
                var tg:Sprite = cast e.currentTarget;
                var idx:Int = _listContent.getChildIndex(tg);
                tg.graphics.clear();
                tg.graphics.beginFill(idx % 2 == 0 ? 0x1e1e1e : 0x262626, 1);
                tg.graphics.drawRect(0, 0, w, h);
                tg.graphics.endFill();
                (cast(tg.getChildAt(0), TextField)).textColor = 0xDDDDDD;
            });
            optBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
                if (_isDragging || _hasMovedBeyondThreshold) return;
                var clickedTarget:Sprite = cast e.currentTarget;
                var clickIndex:Int = _listContent.getChildIndex(clickedTarget);
                _selectedIndex = clickIndex;
                _btnText.text = _options[clickIndex];
                close();
                if (_onSelect != null) _onSelect(_options[clickIndex]);
            });
            _listContent.addChild(optBtn);
        }
        updateScrollbar();
    }

    private function updateScrollbar():Void {
        var curListHeight:Float = getVisibleListHeight();
        _scrollbarTrack.graphics.clear();
        _scrollbarThumb.graphics.clear();

        if (_listContent.height <= curListHeight) {
            _scrollbarTrack.visible = false;
            _scrollbarThumb.visible = false;
            return;
        }

        _scrollbarTrack.visible = true;
        _scrollbarThumb.visible = true;

        var sbW:Float = 5;
        var sbX:Float = _width - sbW - 2;

        _scrollbarTrack.graphics.beginFill(0x222222, 0.7);
        _scrollbarTrack.graphics.drawRoundRect(sbX, 2, sbW, curListHeight - 4, 2, 2);
        _scrollbarTrack.graphics.endFill();

        var viewRatio:Float = curListHeight / _listContent.height;
        var thumbH:Float = Math.max(16, (curListHeight - 4) * viewRatio);
        var scrollRatio:Float = -_listContent.y / (_listContent.height - curListHeight);
        var thumbY:Float = 2 + scrollRatio * (curListHeight - 4 - thumbH);

        _scrollbarThumb.graphics.beginFill(0x888888, 0.9);
        _scrollbarThumb.graphics.drawRoundRect(sbX, thumbY, sbW, thumbH, 2, 2);
        _scrollbarThumb.graphics.endFill();
    }

    private function onListMouseDown(e:MouseEvent):Void {
        if (stage == null) return;
        _isDragging = false;
        _hasMovedBeyondThreshold = false;
        _dragStartY = stage.mouseY;
        _dragStartContentY = _listContent.y;

        stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
        stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
    }

    private function onStageMouseMove(e:MouseEvent):Void {
        if (stage == null) return;
        var curListHeight:Float = getVisibleListHeight();
        if (_listContent.height <= curListHeight) return;

        var dy:Float = stage.mouseY - _dragStartY;
        if (!_hasMovedBeyondThreshold && Math.abs(dy) > 5) {
            _hasMovedBeyondThreshold = true;
            _isDragging = true;
        }

        if (_isDragging) {
            var newY:Float = _dragStartContentY + dy;
            var maxScroll:Float = curListHeight - _listContent.height;
            if (newY > 0) newY = 0;
            if (newY < maxScroll) newY = maxScroll;
            _listContent.y = newY;
            updateScrollbar();
        }
    }

    private function onStageMouseUp(e:MouseEvent):Void {
        if (stage != null) {
            stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
            stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
        }
        haxe.Timer.delay(function() {
            _isDragging = false;
            _hasMovedBeyondThreshold = false;
        }, 50);
    }

    private function onBtnClick(e:MouseEvent):Void {
        if (_isOpen) {
            close();
        } else {
            open();
        }
    }

    public function open():Void {
        if (_activeDropdown != null && _activeDropdown != this) {
            _activeDropdown.close();
        }
        _activeDropdown = this;
        _isOpen = true;
        _listContainer.visible = true;

        if (parent != null) {
            parent.setChildIndex(this, parent.numChildren - 1);
        }

        var curListHeight:Float = getVisibleListHeight();
        var opensUp:Bool = false;
        if (stage != null) {
            var globalPos:Point = localToGlobal(new Point(0, _height));
            if (globalPos.y + curListHeight > stage.stageHeight - 20) {
                opensUp = true;
            }
        } else if (this.y > 180) {
            opensUp = true;
        }

        if (opensUp) {
            _listContainer.y = -curListHeight - 2;
            _arrowText.text = "▲";
        } else {
            _listContainer.y = _height + 2;
            _arrowText.text = "▼";
        }

        updateScrollbar();

        if (stage != null) {
            stage.addEventListener(MouseEvent.MOUSE_DOWN, onStageClickOutside, true);
        }
    }

    public function close():Void {
        _isOpen = false;
        _listContainer.visible = false;
        _arrowText.text = "▼";
        if (_activeDropdown == this) {
            _activeDropdown = null;
        }
        if (stage != null) {
            stage.removeEventListener(MouseEvent.MOUSE_DOWN, onStageClickOutside, true);
        }
    }

    private function onStageClickOutside(e:MouseEvent):Void {
        if (!_isOpen) return;
        var targetObj:DisplayObject = cast e.target;
        if (targetObj != null && !contains(targetObj)) {
            close();
        }
    }

    private function onRemovedFromStage(e:Event):Void {
        close();
    }
}
#else
class Dropdown {
    public function new(width:Float, height:Float, options:Array<String>, onSelect:String->Void = null) {}
    public var selectedItem:String = "";
    public var options:Array<String> = [];
}
#end
