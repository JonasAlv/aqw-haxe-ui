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
import ui.widgets.BaseWidget;
import ui.widgets.CustomWidgetDef;

/**
 * Visual instance of a single customizable widget on screen.
 */
class CustomWidgetInstance extends BaseWidget {
    public static inline var WIDGET_W:Float = ApiStyle.WIDGET_WIDTH_NARROW;

    public var def:CustomWidgetDef;

    private var _fixedContainer:Sprite;
    private var _collapsibleContainer:Sprite;

    private var _buttons:Map<String, { btn:Sprite, dot:Shape, lbl:TextField, tool:ToolDef, isFixed:Bool }> = new Map();
    private var _lastStates:Map<String, Int> = new Map();

    private var _fixedRows:Int = 0;
    private var _collapsibleRows:Int = 0;
    private var _totalRows:Int = 0;

    public function new(def:CustomWidgetDef) {
        this.def = def;
        super(def.id, def.title, def.x, def.y, WIDGET_W, 100, def.enabled, def.isCollapsed, true);
        this.name = "CustomWidget_" + def.id;
    }

    override public function buildContent(container:Sprite):Void {
        _fixedContainer = new Sprite();
        bodyContainer.addChild(_fixedContainer);

        _collapsibleContainer = new Sprite();
        bodyContainer.addChild(_collapsibleContainer);

        populateButtons();
    }

    private function populateButtons():Void {
        while (_fixedContainer.numChildren > 0) _fixedContainer.removeChildAt(0);
        while (_collapsibleContainer.numChildren > 0) _collapsibleContainer.removeChildAt(0);
        _buttons = new Map();
        _lastStates = new Map();

        var fixedList:Array<WidgetItemConfig> = [];
        var collapsibleList:Array<WidgetItemConfig> = [];

        for (item in def.items) {
            if (item.isFixed) {
                fixedList.push(item);
            } else {
                collapsibleList.push(item);
            }
        }

        // Layout Fixed Items (2 columns: left x=8, right x=118, row height=30)
        _fixedRows = Math.ceil(fixedList.length / 2.0);
        for (i in 0...fixedList.length) {
            var item = fixedList[i];
            var tool = ApiToolRegistry.get(item.toolId);
            if (tool == null) continue;

            var col = i % 2;
            var row = Math.floor(i / 2.0);
            var bx:Float = (col == 0) ? 8 : 118;
            var by:Float = row * 30;

            var btnView = createToolButton(tool, true);
            btnView.btn.x = bx;
            btnView.btn.y = by;
            _fixedContainer.addChild(btnView.btn);
            _buttons.set(tool.id, btnView);
        }

        // Layout Collapsible Items (placed below fixed items)
        _collapsibleRows = Math.ceil(collapsibleList.length / 2.0);
        _totalRows = _fixedRows + _collapsibleRows;

        for (i in 0...collapsibleList.length) {
            var item = collapsibleList[i];
            var tool = ApiToolRegistry.get(item.toolId);
            if (tool == null) continue;

            var col = i % 2;
            var row = Math.floor(i / 2.0);
            var bx:Float = (col == 0) ? 8 : 118;
            var by:Float = row * 30;

            var btnView = createToolButton(tool, false);
            btnView.btn.x = bx;
            btnView.btn.y = by;
            _collapsibleContainer.addChild(btnView.btn);
            _buttons.set(tool.id, btnView);
        }
    }

    private function createToolButton(tool:ToolDef, isFixed:Bool):{ btn:Sprite, dot:Shape, lbl:TextField, tool:ToolDef, isFixed:Bool } {
        var btn = new Sprite();
        btn.buttonMode = true;
        btn.useHandCursor = true;
        btn.mouseChildren = false;

        var dot = new Shape();
        btn.addChild(dot);

        var lbl = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 10, ApiStyle.COLOR_TEXT_PRIMARY, true);
        fmt.align = tool.isToggle ? TextFormatAlign.LEFT : TextFormatAlign.CENTER;
        lbl.defaultTextFormat = fmt;
        lbl.x = tool.isToggle ? 20 : 4;
        lbl.y = 4;
        lbl.width = tool.isToggle ? 80 : 96;
        lbl.height = 18;
        lbl.selectable = false;
        lbl.mouseEnabled = false;
        lbl.text = tool.defaultLabel;
        btn.addChild(lbl);

        var isState = (tool.getState != null) ? tool.getState() : false;
        renderBtnStyle(btn, dot, lbl, tool, isState);

        btn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            var active = (tool.getState != null) ? tool.getState() : false;
            renderBtnStyle(btn, dot, lbl, tool, active, true);
        });
        btn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            var active = (tool.getState != null) ? tool.getState() : false;
            renderBtnStyle(btn, dot, lbl, tool, active, false);
        });

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

    override public function computeCollapsedWidth():Float {
        return (_fixedRows == 0) ? BaseWidget.COMPACT_W : WIDGET_W;
    }

    override public function computeCollapsedHeight():Float {
        if (_fixedRows == 0) return BaseWidget.COMPACT_H;
        return (_fixedRows * 30) + 8;
    }

    override public function getCurrentWidth():Float {
        var isCompact = isCollapsed && (_fixedRows == 0);
        return isCompact ? BaseWidget.COMPACT_W : WIDGET_W;
    }

    override public function getCurrentHeight():Float {
        var isCompact = isCollapsed && (_fixedRows == 0);
        if (isCompact) return BaseWidget.COMPACT_H;
        return isCollapsed ? ((_fixedRows * 30) + 8) : ((_totalRows > 0) ? (24 + (_totalRows * 30) + 4) : 32.0);
    }

    override public function loadPosition():Void {
        this.x = (def != null && def.x >= 0) ? def.x : defaultX;
        this.y = (def != null && def.y >= 0) ? def.y : defaultY;
        clampToScreen();
    }

    override public function savePosition():Void {
        super.savePosition();
        if (def != null) {
            def.x = Math.round(this.x);
            def.y = Math.round(this.y);
            WidgetManager.saveCustomWidgets();
        }
    }

    override public function toggleCollapse():Void {
        super.toggleCollapse();
        def.isCollapsed = this.isCollapsed;
        WidgetManager.saveCustomWidgets();
    }

    override public function openConfig():Void {
        WidgetManager.openEditor(def);
    }

    override public function onTick():Void {
        updateButtonVisuals();
    }

    override public function updateLayout():Void {
        var isCompact:Bool = isCollapsed && (_fixedRows == 0);

        if (isCompact) {
            var w:Float = BaseWidget.COMPACT_W;
            var h:Float = BaseWidget.COMPACT_H;

            bg.graphics.clear();
            bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.88);
            bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.85);
            bg.graphics.drawRoundRect(0, 0, w, h, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
            bg.graphics.endFill();

            bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
            bg.graphics.moveTo(3, 1);
            bg.graphics.lineTo(w - 3, 1);

            accentShape.visible = true;
            accentShape.graphics.clear();
            accentShape.graphics.beginFill(ApiStyle.COLOR_ACCENT_PRIMARY, 1.0);
            accentShape.graphics.drawRoundRect(5, 5, 3.5, 16, 1.5, 1.5);
            accentShape.graphics.endFill();

            titleTxt.visible = true;
            titleTxt.text = def.title;
            titleTxt.x = 13;
            titleTxt.y = 4;
            titleTxt.width = BaseWidget.COMPACT_W - 16;

            headerBar.graphics.clear();
            headerBar.graphics.beginFill(0x000000, 0.0);
            headerBar.graphics.drawRect(0, 0, w, h);
            headerBar.graphics.endFill();

            btnCollapse.visible = false;
            if (btnConfig != null) btnConfig.visible = false;
            _fixedContainer.visible = false;
            _collapsibleContainer.visible = false;
        } else if (isCollapsed) {
            titleTxt.visible = false;
            accentShape.visible = false;
            btnCollapse.visible = false;
            if (btnConfig != null) btnConfig.visible = false;

            _fixedContainer.y = 6;
            _fixedContainer.visible = true;
            _collapsibleContainer.visible = false;

            var h:Float = (_fixedRows * 30) + 8;

            bg.graphics.clear();
            bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.88);
            bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.85);
            bg.graphics.drawRoundRect(0, 0, WIDGET_W, h, 6, 6);
            bg.graphics.endFill();

            bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
            bg.graphics.moveTo(3, 1);
            bg.graphics.lineTo(WIDGET_W - 3, 1);

            headerBar.graphics.clear();
            headerBar.graphics.beginFill(0x000000, 0.0);
            headerBar.graphics.drawRect(0, 0, WIDGET_W, h);
            headerBar.graphics.endFill();
        } else {
            // FULLY EXPANDED
            titleTxt.visible = true;
            titleTxt.text = def.title;
            titleTxt.x = 13;
            titleTxt.y = 3;
            titleTxt.width = WIDGET_W - 35;

            accentShape.visible = true;
            accentShape.graphics.clear();
            accentShape.graphics.beginFill(ApiStyle.COLOR_ACCENT_PRIMARY, 1.0);
            accentShape.graphics.drawRoundRect(6, 5, 3, 14, 1, 1);
            accentShape.graphics.endFill();

            btnCollapse.visible = false;

            if (btnConfig != null) {
                btnConfig.visible = true;
                btnConfig.x = WIDGET_W - 25;
                btnConfig.y = 3;
                renderConfigIcon(false);
            }

            _fixedContainer.y = 24;
            _fixedContainer.visible = (_fixedRows > 0);
            _collapsibleContainer.y = 24 + (_fixedRows * 30);
            _collapsibleContainer.visible = (_collapsibleRows > 0);

            var h:Float = (_totalRows > 0) ? (24 + (_totalRows * 30) + 4) : 32.0;

            bg.graphics.clear();
            bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.94);
            bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 1.0);
            bg.graphics.drawRoundRect(0, 0, WIDGET_W, h, 6, 6);
            bg.graphics.endFill();

            bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.55);
            bg.graphics.moveTo(3, 1);
            bg.graphics.lineTo(WIDGET_W - 3, 1);

            headerBar.graphics.clear();
            headerBar.graphics.beginFill(0x000000, 0.0);
            headerBar.graphics.drawRect(0, 0, WIDGET_W, 24);
            headerBar.graphics.endFill();
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

    private function renderBtnStyle(btn:Sprite, dot:Shape, lbl:TextField, tool:ToolDef, active:Bool, hover:Bool = false):Void {
        var w:Float = 104;
        var h:Float = 26;

        btn.graphics.clear();
        var bgCol = active ? ApiStyle.COLOR_BG_SURFACE : ApiStyle.COLOR_BG_CARD;
        var border = active ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_BORDER_DEFAULT;
        var textColor = active ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_TEXT_PRIMARY;

        if (tool.id == "smart_enhance" && active) {
            bgCol = ApiStyle.COLOR_BG_SURFACE;
            border = ApiStyle.COLOR_STATUS_WARN;
            textColor = ApiStyle.COLOR_STATUS_WARN;
        }

        btn.graphics.beginFill(bgCol, 0.94);
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
            var labelText = active ? tool.activeText : tool.inactiveText;
            if (labelText == null || labelText == "") labelText = tool.defaultLabel;
            lbl.text = labelText;
            lbl.textColor = textColor;
        }
    }
}
#else
class CustomWidgetInstance {
    public function new(def:Dynamic) {}
}
#end
