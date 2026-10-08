package ui.widgets;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import ui.ApiDashboardModal;
import ui.ApiMenus;
import ui.ApiStyle;
import ui.ApiToolRegistry;
import ui.Overlay;
import ui.widgets.CustomWidgetDef;

/**
 * Visual instance of a single customizable widget on screen.
 */
class CustomWidgetInstance extends Sprite {
    public static inline var WIDGET_W:Float = 230;
    public static inline var COMPACT_W:Float = 78;
    public static inline var COMPACT_H:Float = 26;

    public var def:CustomWidgetDef;
    private var _theStage:Dynamic;
    private var _overlay:Overlay;

    private var _bg:Sprite;
    private var _headerBar:Sprite;
    private var _accentShape:Shape;
    private var _titleTxt:TextField;
    private var _btnConfig:Sprite;
    private var _btnCollapse:Sprite;

    private var _fixedContainer:Sprite;
    private var _collapsibleContainer:Sprite;

    private var _buttons:Map<String, { btn:Sprite, dot:Shape, lbl:TextField, tool:ToolDef, isFixed:Bool }> = new Map();
    private var _lastStates:Map<String, Int> = new Map();

    private var _fixedRows:Int = 0;
    private var _collapsibleRows:Int = 0;
    private var _totalRows:Int = 0;

    private var _onStageMouseMove:Dynamic = null;
    private var _onStageMouseUp:Dynamic = null;

    private function renderConfigIcon(hover:Bool = false):Void {
        if (_btnConfig == null) return;
        var g = _btnConfig.graphics;
        g.clear();

        // Extended transparent hit boundary for mobile touch
        g.beginFill(0x000000, 0.0);
        g.drawRect(-4, -2, 28, 24);
        g.endFill();

        var bg = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE;
        var border = hover ? ApiStyle.COLOR_ACCENT_PRIMARY : ApiStyle.COLOR_BORDER_DEFAULT;
        g.beginFill(bg, 0.85);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 20, 18, 4, 4);
        g.endFill();

        var color = hover ? ApiStyle.COLOR_ACCENT_HOVER : ApiStyle.COLOR_ACCENT_PRIMARY;
        var cx = 10.0;
        var cy = 9.0;

        // 6-tooth gear spokes
        g.lineStyle(2.2, color, 1.0, true);
        g.moveTo(cx - 5.0, cy); g.lineTo(cx + 5.0, cy);
        g.moveTo(cx, cy - 5.0); g.lineTo(cx, cy + 5.0);
        var d = 3.6;
        g.moveTo(cx - d, cy - d); g.lineTo(cx + d, cy + d);
        g.moveTo(cx - d, cy + d); g.lineTo(cx + d, cy - d);

        // Gear body circle
        g.lineStyle(1.4, color, 1.0, true);
        g.beginFill(bg, 1.0);
        g.drawCircle(cx, cy, 3.4);
        g.endFill();

        // Center cutout
        g.lineStyle(0, 0, 0);
        g.beginFill(color, 1.0);
        g.drawCircle(cx, cy, 1.3);
        g.endFill();
    }

    private function renderCollapseIcon(collapsed:Bool, hover:Bool = false):Void {
        if (_btnCollapse == null) return;
        var g = _btnCollapse.graphics;
        g.clear();

        // Extended transparent hit boundary for mobile
        g.beginFill(0x000000, 0.0);
        g.drawRect(-4, -2, 28, 24);
        g.endFill();

        var bg = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE;
        var border = hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT;
        g.beginFill(bg, 0.85);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 20, 18, 4, 4);
        g.endFill();

        var color:Int = hover ? ApiStyle.COLOR_ACCENT_PRIMARY : ApiStyle.COLOR_TEXT_MUTED;
        g.lineStyle(2.2, color, 1.0, true);
        var cx = 10.0;
        var cy = 9.0;
        if (collapsed) {
            // Modern Chevron Down (closed, click to expand)
            g.moveTo(cx - 4.5, cy - 2.5);
            g.lineTo(cx, cy + 2.5);
            g.lineTo(cx + 4.5, cy - 2.5);
        } else {
            // Modern Chevron Up (open, click to collapse)
            g.moveTo(cx - 4.5, cy + 2.5);
            g.lineTo(cx, cy - 2.5);
            g.lineTo(cx + 4.5, cy + 2.5);
        }
    }

    private function renderMiniChevronDown():Void {
        if (_btnCollapse == null) return;
        var g = _btnCollapse.graphics;
        g.clear();
        g.lineStyle(2.0, ApiStyle.COLOR_TEXT_MUTED, 0.9, true);
        var cx:Float = 4.0;
        var cy:Float = 9.0;
        g.moveTo(cx - 3.5, cy - 2.0);
        g.lineTo(cx, cy + 2.0);
        g.lineTo(cx + 3.5, cy - 2.0);
    }

    public function new(def:CustomWidgetDef, theStage:Dynamic, overlay:Overlay) {
        super();
        this.def = def;
        this._theStage = theStage;
        this._overlay = overlay;
        this.name = "CustomWidget_" + def.id;

        buildUI();
    }

    private function buildUI():Void {
        var sw:Float = (_theStage != null && _theStage.stageWidth > 0) ? _theStage.stageWidth : 960;
        var sh:Float = (_theStage != null && _theStage.stageHeight > 0) ? _theStage.stageHeight : 550;

        this.x = def.x;
        this.y = def.y;

        // 1. Background plate
        _bg = new Sprite();
        addChild(_bg);

        // 2. Header Bar (Drag & Click-to-collapse)
        _headerBar = new Sprite();
        _headerBar.buttonMode = true;
        _headerBar.useHandCursor = true;

        _headerBar.graphics.beginFill(0x000000, 0.0);
        _headerBar.graphics.drawRect(0, 0, WIDGET_W, 24);
        _headerBar.graphics.endFill();
        addChild(_headerBar);

        // Header Accent
        _accentShape = new Shape();
        _headerBar.addChild(_accentShape);

        // Header Title
        _titleTxt = new TextField();
        var titleFmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_PRIMARY, true);
        _titleTxt.defaultTextFormat = titleFmt;
        _titleTxt.text = def.title;
        _titleTxt.x = 13;
        _titleTxt.y = 3;
        _titleTxt.width = WIDGET_W - 55;
        _titleTxt.height = 18;
        _titleTxt.selectable = false;
        _titleTxt.mouseEnabled = false;
        _headerBar.addChild(_titleTxt);

        // Config Gear Button (Vector Cog)
        _btnConfig = new Sprite();
        _btnConfig.buttonMode = true;
        _btnConfig.x = WIDGET_W - 48;
        _btnConfig.y = 3;
        renderConfigIcon(false);
        _headerBar.addChild(_btnConfig);

        _btnConfig.addEventListener(MouseEvent.MOUSE_OVER, function(e) renderConfigIcon(true));
        _btnConfig.addEventListener(MouseEvent.MOUSE_OUT, function(e) renderConfigIcon(false));
        _btnConfig.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void e.stopPropagation());
        _btnConfig.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void e.stopPropagation());
        _btnConfig.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            e.stopPropagation();
            ApiToolsWidget.openEditor(def);
        });

        // Collapse Indicator (Vector Chevron)
        _btnCollapse = new Sprite();
        _btnCollapse.mouseEnabled = false;
        _btnCollapse.mouseChildren = false;
        _btnCollapse.x = WIDGET_W - 24;
        _btnCollapse.y = 3;
        renderCollapseIcon(def.isCollapsed, false);
        _headerBar.addChild(_btnCollapse);

        // Title bar hover feedback
        _headerBar.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            _titleTxt.textColor = ApiStyle.COLOR_TEXT_TITLE;
            var isCompact = def.isCollapsed && (_fixedRows == 0);
            if (!isCompact) renderCollapseIcon(def.isCollapsed, true);
            _bg.alpha = 1.0;
        });
        _headerBar.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            _titleTxt.textColor = ApiStyle.COLOR_TEXT_PRIMARY;
            var isCompact = def.isCollapsed && (_fixedRows == 0);
            if (!isCompact) renderCollapseIcon(def.isCollapsed, false);
            _bg.alpha = def.isCollapsed ? 0.78 : 0.94;
        });

        // 3. Button Containers
        _fixedContainer = new Sprite();
        addChild(_fixedContainer);

        _collapsibleContainer = new Sprite();
        addChild(_collapsibleContainer);

        populateButtons();

        // 4. Setup Dragging & Click-to-collapse
        setupDragging();

        // 5. Frame state loop
        addEventListener(Event.ENTER_FRAME, onEnterFrame);

        clampToScreen();
        updateLayout();
        updateButtonVisuals();
    }

    private function populateButtons():Void {
        while (_fixedContainer.numChildren > 0) _fixedContainer.removeChildAt(0);
        while (_collapsibleContainer.numChildren > 0) _collapsibleContainer.removeChildAt(0);
        _buttons = new Map();
        _lastStates = new Map();

        var fixedList:Array<WidgetItemConfig> = [];
        var collapseList:Array<WidgetItemConfig> = [];

        for (it in def.items) {
            if (it.isFixed) fixedList.push(it);
            else collapseList.push(it);
        }

        var btnW:Float = 104;
        var btnH:Float = 26;

        var validFixed:Array<ToolDef> = [];
        for (it in fixedList) {
            var tool = ApiToolRegistry.get(it.toolId);
            if (tool != null) validFixed.push(tool);
        }

        var validCollapse:Array<ToolDef> = [];
        for (it in collapseList) {
            var tool = ApiToolRegistry.get(it.toolId);
            if (tool != null) validCollapse.push(tool);
        }

        // Render Fixed buttons
        for (idx in 0...validFixed.length) {
            var tool = validFixed[idx];
            var row = Math.floor(idx / 2);
            var col = idx % 2;
            var bx:Float = (col == 0) ? 8 : 118;
            var by:Float = 24 + (row * 30);

            var sp = createButtonSprite(tool, bx, by, btnW, btnH, true);
            _fixedContainer.addChild(sp.btn);
            _buttons.set(tool.id, sp);
        }
        _fixedRows = Math.ceil(validFixed.length / 2);

        // Render Collapsible buttons
        for (idx in 0...validCollapse.length) {
            var tool = validCollapse[idx];
            var globalIdx = validFixed.length + idx;
            var row = Math.floor(globalIdx / 2);
            var col = globalIdx % 2;
            var bx:Float = (col == 0) ? 8 : 118;
            var by:Float = 24 + (row * 30);

            var sp = createButtonSprite(tool, bx, by, btnW, btnH, false);
            _collapsibleContainer.addChild(sp.btn);
            _buttons.set(tool.id, sp);
        }
        _totalRows = Math.ceil((validFixed.length + validCollapse.length) / 2);
        _collapsibleRows = _totalRows - _fixedRows;
    }

    private function createButtonSprite(tool:ToolDef, bx:Float, by:Float, bw:Float, bh:Float, isFixed:Bool):{ btn:Sprite, dot:Shape, lbl:TextField, tool:ToolDef, isFixed:Bool } {
        var btn = new Sprite();
        btn.buttonMode = true;
        btn.mouseChildren = false;
        btn.x = bx;
        btn.y = by;

        var dot = new Shape();
        btn.addChild(dot);

        var lbl = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_PRIMARY, true);
        fmt.align = tool.isToggle ? TextFormatAlign.LEFT : TextFormatAlign.CENTER;
        lbl.defaultTextFormat = fmt;
        lbl.x = tool.isToggle ? 21 : 0;
        lbl.y = 4;
        lbl.width = tool.isToggle ? (bw - 24) : bw;
        lbl.height = 18;
        lbl.selectable = false;
        lbl.mouseEnabled = false;
        btn.addChild(lbl);

        btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            flashButton(btn, dot, lbl, tool);
            if (tool.onAction != null) {
                tool.onAction();
            }
        });

        return { btn: btn, dot: dot, lbl: lbl, tool: tool, isFixed: isFixed };
    }

    private function flashButton(btn:Sprite, dot:Shape, lbl:TextField, tool:ToolDef):Void {
        if (btn == null) return;
        var isState = (tool.getState != null) ? tool.getState() : false;
        var nextState = tool.isToggle ? !isState : isState;
        btn.graphics.clear();
        btn.graphics.beginFill(nextState ? ApiStyle.COLOR_BG_SURFACE : ApiStyle.COLOR_BG_CARD, 0.98);
        btn.graphics.lineStyle(1.8, nextState ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_BORDER_DEFAULT);
        btn.graphics.drawRoundRect(0, 0, 104, 26, 4, 4);
        btn.graphics.endFill();
        haxe.Timer.delay(function():Void {
            var active = (tool.getState != null) ? tool.getState() : false;
            renderBtnStyle(btn, dot, lbl, tool, active);
        }, 120);
    }

    public function toggleCollapse():Void {
        def.isCollapsed = !def.isCollapsed;
        clampToScreen();
        updateLayout();
    }

    private inline function computeCurrentWidth():Float {
        var isCompact = def.isCollapsed && (_fixedRows == 0);
        return isCompact ? COMPACT_W : WIDGET_W;
    }

    private inline function computeCurrentHeight():Float {
        var isCompact = def.isCollapsed && (_fixedRows == 0);
        if (isCompact) return COMPACT_H;
        return def.isCollapsed ? ((_fixedRows * 30) + 8) : (24 + (_totalRows * 30) + 4);
    }

    public function clampToScreen():Void {
        var sw:Float = (_theStage != null && _theStage.stageWidth > 0) ? _theStage.stageWidth : 960;
        var sh:Float = (_theStage != null && _theStage.stageHeight > 0) ? _theStage.stageHeight : 550;
        var curW:Float = computeCurrentWidth();
        var curH:Float = computeCurrentHeight();

        if (this.x > sw - curW - ApiStyle.SCREEN_MARGIN) this.x = Math.max(ApiStyle.SCREEN_MARGIN, sw - curW - ApiStyle.SCREEN_MARGIN);
        if (this.y > sh - curH - ApiStyle.SCREEN_MARGIN) this.y = Math.max(ApiStyle.SCREEN_MARGIN, sh - curH - ApiStyle.SCREEN_MARGIN);
        if (this.x < ApiStyle.SCREEN_MARGIN) this.x = ApiStyle.SCREEN_MARGIN;
        if (this.y < ApiStyle.SCREEN_MARGIN) this.y = ApiStyle.SCREEN_MARGIN;

        def.x = Math.round(this.x);
        def.y = Math.round(this.y);
        ApiToolsWidget.saveWidgets();
    }

    private function updateLayout():Void {
        var isCompact:Bool = def.isCollapsed && (_fixedRows == 0);

        if (isCompact) {
            // COMPACT MINIMIZED MODE: 78x26 (matching Main Menu button)
            var w:Float = COMPACT_W;
            var h:Float = COMPACT_H;

            _bg.graphics.clear();
            _bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.88);
            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.85);
            _bg.graphics.drawRoundRect(0, 0, w, h, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
            _bg.graphics.endFill();

            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
            _bg.graphics.moveTo(3, 1);
            _bg.graphics.lineTo(w - 3, 1);

            _accentShape.visible = true;
            _accentShape.graphics.clear();
            _accentShape.graphics.beginFill(ApiStyle.COLOR_ACCENT_PRIMARY, 1.0);
            _accentShape.graphics.drawRoundRect(5, 5, 3.5, 16, 1.5, 1.5);
            _accentShape.graphics.endFill();

            _titleTxt.visible = true;
            _titleTxt.text = def.title;
            _titleTxt.x = 13;
            _titleTxt.y = 4;
            _titleTxt.width = COMPACT_W - 16;

            _headerBar.graphics.clear();
            _headerBar.graphics.beginFill(0x000000, 0.0);
            _headerBar.graphics.drawRect(0, 0, w, h);
            _headerBar.graphics.endFill();

            _btnCollapse.visible = false;
            _btnConfig.visible = false;
            _fixedContainer.visible = false;
            _collapsibleContainer.visible = false;
        } else if (def.isCollapsed) {
            // COLLAPSED WITH FIXED PINNED BUTTONS
            // When at least one option is fixed, label text and accent bar are hidden!
            _titleTxt.visible = false;
            _accentShape.visible = false;
            _btnCollapse.visible = false;
            _btnConfig.visible = false; // Setting icon only shows when widget is opened!

            _fixedContainer.y = 6;
            _fixedContainer.visible = true;
            _collapsibleContainer.visible = false;

            var h:Float = (_fixedRows * 30) + 8;

            _bg.graphics.clear();
            _bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.88);
            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.85);
            _bg.graphics.drawRoundRect(0, 0, WIDGET_W, h, 6, 6);
            _bg.graphics.endFill();

            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
            _bg.graphics.moveTo(3, 1);
            _bg.graphics.lineTo(WIDGET_W - 3, 1);

            _headerBar.graphics.clear();
            _headerBar.graphics.beginFill(0x000000, 0.0);
            _headerBar.graphics.drawRect(0, 0, WIDGET_W, h);
            _headerBar.graphics.endFill();
        } else {
            // FULLY EXPANDED
            _titleTxt.visible = true;
            _titleTxt.text = def.title;
            _titleTxt.x = 13;
            _titleTxt.y = 3;
            _titleTxt.width = WIDGET_W - 35;

            _accentShape.visible = true;
            _accentShape.graphics.clear();
            _accentShape.graphics.beginFill(ApiStyle.COLOR_ACCENT_PRIMARY, 1.0);
            _accentShape.graphics.drawRoundRect(6, 5, 3, 14, 1, 1);
            _accentShape.graphics.endFill();

            _btnCollapse.visible = false; // Chevron removed everywhere

            _btnConfig.visible = true; // Settings icon only when opened
            _btnConfig.x = WIDGET_W - 25;
            _btnConfig.y = 3;
            renderConfigIcon(false);

            _fixedContainer.y = 24;
            _fixedContainer.visible = true;
            _collapsibleContainer.visible = true;

            var h:Float = 24 + (_totalRows * 30) + 4;

            _bg.graphics.clear();
            _bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.94);
            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 1.0);
            _bg.graphics.drawRoundRect(0, 0, WIDGET_W, h, 6, 6);
            _bg.graphics.endFill();

            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.55);
            _bg.graphics.moveTo(3, 1);
            _bg.graphics.lineTo(WIDGET_W - 3, 1);

            _headerBar.graphics.clear();
            _headerBar.graphics.beginFill(0x000000, 0.0);
            _headerBar.graphics.drawRect(0, 0, WIDGET_W, 24);
            _headerBar.graphics.endFill();
        }
    }

    private function updateButtonVisuals():Void {
        for (item in _buttons) {
            var tool = item.tool;
            var isState = (tool.getState != null) ? tool.getState() : false;
            var sInt:Int = isState ? 1 : 0;

            var last = _lastStates.exists(tool.id) ? _lastStates.get(tool.id) : -1;
            if (sInt != last) {
                _lastStates.set(tool.id, sInt);
                renderBtnStyle(item.btn, item.dot, item.lbl, tool, isState);
            }
        }
    }

    private function renderBtnStyle(btn:Sprite, dot:Shape, lbl:TextField, tool:ToolDef, active:Bool):Void {
        var w:Float = 104;
        var h:Float = 26;

        btn.graphics.clear();
        var bg = active ? ApiStyle.COLOR_BG_SURFACE : ApiStyle.COLOR_BG_CARD;
        var border = active ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_BORDER_DEFAULT;
        var textColor = active ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_TEXT_PRIMARY;

        if (tool.id == "smart_enhance" && active) {
            bg = ApiStyle.COLOR_BG_SURFACE;
            border = ApiStyle.COLOR_STATUS_WARN;
            textColor = ApiStyle.COLOR_STATUS_WARN;
        }

        btn.graphics.beginFill(bg, 0.94);
        btn.graphics.lineStyle(1, border);
        btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
        btn.graphics.endFill();

        btn.graphics.lineStyle(1, active ? border : ApiStyle.COLOR_BEVEL_LIGHT, 0.55);
        btn.graphics.moveTo(2, 1);
        btn.graphics.lineTo(w - 2, 1);

        if (dot != null) {
            dot.graphics.clear();
            if (tool.isToggle || (tool.id == "smart_enhance" && active)) {
                var dotX:Float = 11;
                var dotY:Float = h / 2;
                dot.graphics.lineStyle(0, 0, 0);
                if (active) {
                    var glowColor = (tool.id == "smart_enhance") ? ApiStyle.COLOR_STATUS_WARN : ApiStyle.COLOR_STATUS_ACTIVE;
                    var coreColor = (tool.id == "smart_enhance") ? ApiStyle.COLOR_STATUS_WARN : ApiStyle.COLOR_STATUS_ACTIVE;
                    dot.graphics.beginFill(glowColor, 0.35);
                    dot.graphics.drawCircle(dotX, dotY, 4.5);
                    dot.graphics.endFill();
                    dot.graphics.beginFill(coreColor, 1.0);
                    dot.graphics.drawCircle(dotX, dotY, 2.5);
                    dot.graphics.endFill();
                } else {
                    dot.graphics.beginFill(ApiStyle.COLOR_STATUS_INACTIVE, 0.85);
                    dot.graphics.drawCircle(dotX, dotY, 2.5);
                    dot.graphics.endFill();
                }
            }
        }

        if (lbl != null) {
            lbl.text = active ? tool.activeText : tool.inactiveText;
            lbl.textColor = textColor;
        }
    }

    private function setupDragging():Void {
        var isDragging:Bool = false;
        var hasDragged:Bool = false;
        var startDownX:Float = 0;
        var startDownY:Float = 0;
        var dragStartX:Float = 0;
        var dragStartY:Float = 0;

        _headerBar.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            if (parent != null) {
                try { parent.setChildIndex(this, parent.numChildren - 1); } catch (_:Dynamic) {}
            }
            isDragging = true;
            hasDragged = false;
            startDownX = e.stageX;
            startDownY = e.stageY;
            cacheAsBitmap = false;
            dragStartX = e.stageX - this.x;
            dragStartY = e.stageY - this.y;
        });

        _onStageMouseMove = function(e:MouseEvent):Void {
            if (isDragging) {
                var dx = e.stageX - startDownX;
                var dy = e.stageY - startDownY;
                if (Math.abs(dx) > 4 || Math.abs(dy) > 4) {
                    hasDragged = true;
                }
                if (hasDragged) {
                    var nx:Float = Math.round(e.stageX - dragStartX);
                    var ny:Float = Math.round(e.stageY - dragStartY);
                    var sw:Float = _theStage.stageWidth > 0 ? _theStage.stageWidth : 960;
                    var sh:Float = _theStage.stageHeight > 0 ? _theStage.stageHeight : 550;
                    var curW:Float = computeCurrentWidth();
                    var curH:Float = computeCurrentHeight();
                    if (nx < ApiStyle.SCREEN_MARGIN) nx = ApiStyle.SCREEN_MARGIN;
                    if (ny < ApiStyle.SCREEN_MARGIN) ny = ApiStyle.SCREEN_MARGIN;
                    if (nx > sw - curW - ApiStyle.SCREEN_MARGIN) nx = sw - curW - ApiStyle.SCREEN_MARGIN;
                    if (ny > sh - curH - ApiStyle.SCREEN_MARGIN) ny = sh - curH - ApiStyle.SCREEN_MARGIN;
                    this.x = nx;
                    this.y = ny;
                }
            }
        };

        _onStageMouseUp = function(e:MouseEvent):Void {
            if (isDragging) {
                isDragging = false;
                cacheAsBitmap = true;
                if (hasDragged) {
                    var sw:Float = _theStage.stageWidth > 0 ? _theStage.stageWidth : 960;
                    var sh:Float = _theStage.stageHeight > 0 ? _theStage.stageHeight : 550;
                    var curW:Float = computeCurrentWidth();
                    var curH:Float = computeCurrentHeight();
                    if (this.x < ApiStyle.SCREEN_MARGIN) this.x = ApiStyle.SCREEN_MARGIN;
                    if (this.y < ApiStyle.SCREEN_MARGIN) this.y = ApiStyle.SCREEN_MARGIN;
                    if (this.x > sw - curW - ApiStyle.SCREEN_MARGIN) this.x = sw - curW - ApiStyle.SCREEN_MARGIN;
                    if (this.y > sh - curH - ApiStyle.SCREEN_MARGIN) this.y = sh - curH - ApiStyle.SCREEN_MARGIN;

                    def.x = Math.round(this.x);
                    def.y = Math.round(this.y);
                    ApiToolsWidget.saveWidgets();
                } else {
                    toggleCollapse();
                }
            }
        };

        if (_theStage != null) {
            _theStage.addEventListener(MouseEvent.MOUSE_MOVE, _onStageMouseMove);
            _theStage.addEventListener(MouseEvent.MOUSE_UP, _onStageMouseUp);
        }
    }

    private function onEnterFrame(e:Event):Void {
        var inGame = ApiMenus.isInGame();
        if (!inGame) {
            this.visible = false;
            return;
        }
        if (!def.enabled) {
            this.visible = false;
            return;
        }
        var isPanelOpen:Bool = (_overlay != null && (_overlay.currentFrameLabel == "Panel" || ApiDashboardModal.isOpen()));
        this.visible = !isPanelOpen;
        if (this.visible) {
            updateButtonVisuals();
        }
    }

    public function destroy():Void {
        removeEventListener(Event.ENTER_FRAME, onEnterFrame);
        if (_theStage != null) {
            if (_onStageMouseMove != null) {
                try { _theStage.removeEventListener(MouseEvent.MOUSE_MOVE, _onStageMouseMove); } catch (_:Dynamic) {}
                _onStageMouseMove = null;
            }
            if (_onStageMouseUp != null) {
                try { _theStage.removeEventListener(MouseEvent.MOUSE_UP, _onStageMouseUp); } catch (_:Dynamic) {}
                _onStageMouseUp = null;
            }
        }
    }
}
#else
class CustomWidgetInstance {
    public function new(def:Dynamic, theStage:Dynamic, overlay:Dynamic) {}
    public function destroy():Void {}
}
#end
