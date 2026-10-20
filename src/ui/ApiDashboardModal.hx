package ui;

#if flash
import com.aqwapi.Api;
import com.aqwapi.modules.CombatEngine;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.utils.ApiLogger;
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.geom.Point;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.ui.Keyboard;
import ui.prompts.ApiPrompts;
import com.aqwapi.utils.ApiConfig;
import ui.ApiStyle;
import ui.dashboard.IDashboardTab;
import ui.dashboard.tabs.ScriptsTab;
import ui.dashboard.tabs.AutomationTab;
import ui.dashboard.tabs.EnhancementsTab;
import ui.dashboard.tabs.HudTab;
import ui.dashboard.tabs.UnitFramesTab;
import ui.dashboard.tabs.SettingsTab;

enum DashboardTab {
    TabScripts;
    TabAutomation;
    TabEnhancements;
    TabHud;
    TabUnitFrames;
    TabSettings;
}

class ApiDashboardModal extends Sprite {
    private static var _instance:ApiDashboardModal = null;

    public static function show(overlay:Dynamic, pocket:Dynamic = null):Void {
        close();
        _instance = new ApiDashboardModal(overlay, pocket);
        var target:Dynamic = (overlay != null && overlay.stage != null) ? overlay.stage : ((pocket != null && pocket.stage != null) ? pocket.stage : overlay);
        if (target != null) {
            target.addChild(_instance);
        }
    }

    public static function close():Void {
        if (_instance != null && _instance.parent != null) {
            _instance.parent.removeChild(_instance);
        }
        _instance = null;
    }

    public static function isOpen():Bool {
        return _instance != null && _instance.parent != null;
    }

    public static function refreshCurrentTab():Void {
        if (_instance != null && _instance.parent != null) {
            _instance.renderTabContent(_instance._currentTab, true);
        }
    }

    // Modal layout dimensions
    private static inline var SIDEBAR_WIDTH:Float = 150;

    private var _stageW:Float = 960;
    private var _stageH:Float = 550;
    private var _winW:Float = 960;
    private var _winH:Float = 550;
    private var _contentWidth:Float = 770;
    private var _contentHeight:Float = 482;

    private var _overlay:Dynamic;
    private var _pocket:Dynamic;
    private var _backdrop:Sprite;
    private var _window:Sprite;
    private var _closeBtn:Sprite;
    private var _escHintTxt:TextField;

    private var _currentTab:DashboardTab = TabScripts;
    private var _tabButtons:Map<DashboardTab, Sprite> = new Map<DashboardTab, Sprite>();
    private var _tabLabels:Map<DashboardTab, TextField> = new Map<DashboardTab, TextField>();
    private var _tabHandlers:Map<DashboardTab, IDashboardTab>;

    public var overlay(get, never):Dynamic;
    private inline function get_overlay():Dynamic return _overlay;

    public var pocket(get, never):Dynamic;
    private inline function get_pocket():Dynamic return _pocket;

    public var contentWidth(get, never):Float;
    private inline function get_contentWidth():Float return _contentWidth;

    public var contentContainer(get, never):Sprite;
    private inline function get_contentContainer():Sprite return _contentContainer;

    public var totalContentHeight(get, set):Float;
    private inline function get_totalContentHeight():Float {
        var h = (_gridCol > 0) ? (_gridRowY + _gridRowH + 6) : _totalContentHeight;
        return h > 6 ? (h - 6) : h;
    }
    private inline function set_totalContentHeight(v:Float):Float {
        _gridCol = 0;
        _gridRowH = 0;
        _pendingRowRenderBgs = [];
        return _totalContentHeight = v;
    }

    private var _contentViewport:Sprite;
    private var _contentMask:Shape;
    private var _contentContainer:Sprite;
    private var _totalContentHeight:Float = 0;

    // Dynamic Multi-Column Grid Layout Tracking
    private var _gridCol:Int = 0; // Current column index (0 to numCols - 1)
    private var _gridRowY:Float = 0;
    private var _gridRowH:Float = 0;
    private var _pendingRowRenderBgs:Array<Float->Void> = [];

    // Scrolling state
    private var _scrollbarTrack:Shape;
    private var _scrollbarThumb:Shape;
    private var _isDraggingScroll:Bool = false;
    private var _hasDraggedScroll:Bool = false;
    private var _dragStartY:Float = 0;
    private var _dragStartContentY:Float = 0;

    public function new(overlay:Dynamic, pocket:Dynamic) {
        super();
        _overlay = overlay;
        _pocket = pocket;

        _tabHandlers = [
            TabScripts => new ScriptsTab(),
            TabAutomation => new AutomationTab(),
            TabEnhancements => new EnhancementsTab(),
            TabHud => new HudTab(),
            TabUnitFrames => new UnitFramesTab(),
            TabSettings => new SettingsTab()
        ];

        updateDimensions();

        // 1. Semi-transparent backdrop
        _backdrop = new Sprite();
        _backdrop.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (e.target == _backdrop) close();
        });
        addChild(_backdrop);

        // 2. Main Fullscreen Window
        _window = new Sprite();
        _window.x = 0;
        _window.y = 0;
        addChild(_window);

        redrawWindowChrome();

        // 3. Header Bar
        setupHeader();

        // 4. Sidebar Tabs
        setupSidebar();

        // 5. Content Viewport
        setupContentViewport();

        // 6. Render Initial Tab
        switchTab(TabScripts);

        // 7. Global Stage Listeners
        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
    }

    private function updateDimensions():Void {
        var targetStage:Dynamic = (stage != null) ? stage : ((_overlay != null && _overlay.stage != null) ? _overlay.stage : ((_pocket != null && _pocket.stage != null) ? _pocket.stage : null));
        _stageW = (targetStage != null && targetStage.stageWidth > 0) ? targetStage.stageWidth : 960;
        _stageH = (targetStage != null && targetStage.stageHeight > 0) ? targetStage.stageHeight : 550;

        // Fullscreen: window spans the full stage to maximize usable space
        _winW = _stageW;
        _winH = _stageH;

        _contentWidth = Math.max(260, _winW - (SIDEBAR_WIDTH + 24) - 16);
        _contentHeight = Math.max(180, _winH - 56 - 12);
    }

    private function redrawWindowChrome():Void {
        _backdrop.graphics.clear();
        _backdrop.graphics.beginFill(ApiStyle.COLOR_BG_BACKDROP, 1.0);
        _backdrop.graphics.drawRect(0, 0, _stageW, _stageH);
        _backdrop.graphics.endFill();

        _window.graphics.clear();
        _window.graphics.beginFill(ApiStyle.COLOR_BG_DASHBOARD, 0.98);
        _window.graphics.drawRect(0, 0, _winW, _winH);
        _window.graphics.endFill();

        // Top Header Bar Background Plate
        _window.graphics.beginFill(ApiStyle.COLOR_BG_PANEL, 1.0);
        _window.graphics.drawRect(0, 0, _winW, 48);
        _window.graphics.endFill();

        // Sidebar Background Plate
        _window.graphics.beginFill(ApiStyle.COLOR_BG_SURFACE, 0.6);
        _window.graphics.drawRect(0, 48, SIDEBAR_WIDTH + 14, _winH - 48);
        _window.graphics.endFill();

        // Divider line below header
        _window.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DIVIDER);
        _window.graphics.moveTo(0, 48);
        _window.graphics.lineTo(_winW, 48);

        // Vertical divider line between sidebar and content
        _window.graphics.moveTo(SIDEBAR_WIDTH + 14, 48);
        _window.graphics.lineTo(SIDEBAR_WIDTH + 14, _winH);

        if (_closeBtn != null) {
            _closeBtn.x = _winW - 32 - 16;
        }
        if (_escHintTxt != null) {
            _escHintTxt.x = _winW - 32 - 16 - 96;
        }
    }

    private function onAddedToStage(e:Event):Void {
        if (stage != null) {
            stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
            stage.addEventListener(Event.RESIZE, onStageResize);
            onStageResize(null);
        }
    }

    private function onRemovedFromStage(e:Event):Void {
        if (stage != null) {
            stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
            stage.removeEventListener(Event.RESIZE, onStageResize);
            stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
            stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
        }
    }

    private function onStageResize(e:Event):Void {
        updateDimensions();
        _window.x = 0;
        _window.y = 0;
        redrawWindowChrome();
        if (_contentMask != null) {
            _contentMask.graphics.clear();
            _contentMask.graphics.beginFill(0xFF0000);
            _contentMask.graphics.drawRect(0, 0, _contentWidth, _contentHeight);
            _contentMask.graphics.endFill();
        }
        if (_scrollbarTrack != null) {
            _scrollbarTrack.x = _contentViewport.x + _contentWidth - 6;
            _scrollbarThumb.x = _scrollbarTrack.x;
        }
        renderTabContent(_currentTab, true);
    }

    private function onKeyDown(e:KeyboardEvent):Void {
        if (e.keyCode == 27) { // ESC key
            if (ui.prompts.ApiPromptModal.isOpen()) {
                return; // Let prompt modal take foreground priority
            }
            close();
        }
    }

    // =========================================================================
    // HEADER
    // =========================================================================

    private function setupHeader():Void {
        // Title
        var titleTxt = new TextField();
        var titleFmt = new TextFormat(ApiStyle.FONT_FAMILY, 16, ApiStyle.COLOR_TEXT_PRIMARY, true);
        titleTxt.defaultTextFormat = titleFmt;
        titleTxt.text = "Menu";
        titleTxt.x = 22;
        titleTxt.y = 13;
        titleTxt.width = 100;
        titleTxt.height = 28;
        titleTxt.selectable = false;
        titleTxt.mouseEnabled = false;
        _window.addChild(titleTxt);

        // Subtitle badge
        var badgeTxt = new TextField();
        var badgeFmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_MUTED, false);
        badgeTxt.defaultTextFormat = badgeFmt;
        badgeTxt.text = "Control Center";
        badgeTxt.x = 85;
        badgeTxt.y = 17;
        badgeTxt.width = 120;
        badgeTxt.height = 20;
        badgeTxt.selectable = false;
        badgeTxt.mouseEnabled = false;
        _window.addChild(badgeTxt);

        // Close Button (Vector ✕)
        _closeBtn = new Sprite();
        var cbW:Float = 32;
        var cbH:Float = 28;
        _closeBtn.buttonMode = true;
        _closeBtn.x = _winW - cbW - 16;
        _closeBtn.y = 10;

        var renderCloseBtn = function(isHover:Bool):Void {
            _closeBtn.graphics.clear();
            var bg = isHover ? ApiStyle.COLOR_STATUS_ERROR : ApiStyle.COLOR_BG_SURFACE;
            var border = isHover ? ApiStyle.COLOR_STATUS_ERROR_HOVER : ApiStyle.COLOR_BORDER_DEFAULT;
            var xColor = isHover ? ApiStyle.COLOR_TEXT_TITLE : ApiStyle.COLOR_TEXT_MUTED;

            // Background & Border
            _closeBtn.graphics.beginFill(bg, 1);
            _closeBtn.graphics.lineStyle(1, border);
            _closeBtn.graphics.drawRoundRect(0, 0, cbW, cbH, 5, 5);
            _closeBtn.graphics.endFill();

            // Crisp Vector ✕ Icon
            var cx:Float = cbW / 2;
            var cy:Float = cbH / 2;
            var size:Float = 4.5;
            _closeBtn.graphics.lineStyle(2, xColor, 1);
            _closeBtn.graphics.moveTo(cx - size, cy - size);
            _closeBtn.graphics.lineTo(cx + size, cy + size);
            _closeBtn.graphics.moveTo(cx + size, cy - size);
            _closeBtn.graphics.lineTo(cx - size, cy + size);
        };
        renderCloseBtn(false);

        _closeBtn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            renderCloseBtn(true);
        });
        _closeBtn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            renderCloseBtn(false);
        });
        _closeBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            close();
        });
        _window.addChild(_closeBtn);

        // ESC hint label next to close button
        _escHintTxt = new TextField();
        var escFmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_MUTED, false);
        escFmt.align = TextFormatAlign.RIGHT;
        _escHintTxt.defaultTextFormat = escFmt;
        _escHintTxt.text = "Press ESC or";
        _escHintTxt.width = 90;
        _escHintTxt.height = 20;
        _escHintTxt.x = _closeBtn.x - 96;
        _escHintTxt.y = 15;
        _escHintTxt.selectable = false;
        _escHintTxt.mouseEnabled = false;
        _window.addChild(_escHintTxt);
    }

    // =========================================================================
    // SIDEBAR
    // =========================================================================

    private function setupSidebar():Void {
        var tabs = [
            { id: TabScripts, label: "Scripts" },
            { id: TabAutomation, label: "Automation" },
            { id: TabEnhancements, label: "Enhancements" },
            { id: TabHud, label: "On-Screen HUD" },
            { id: TabUnitFrames, label: "Unit Frames" },
            { id: TabSettings, label: "Settings" }
        ];

        var tabY:Float = 60;
        var tabW:Float = SIDEBAR_WIDTH - 12;
        var tabH:Float = 36;

        for (t in tabs) {
            var btn = createTabButton(t.label, tabW, tabH, t.id);
            btn.x = 14;
            btn.y = tabY;
            _window.addChild(btn);
            tabY += tabH + 8;
        }
    }

    private function createTabButton(label:String, w:Float, h:Float, tabId:DashboardTab):Sprite {
        var btn = new Sprite();
        btn.buttonMode = true;

        var txt = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 13, ApiStyle.COLOR_TEXT_SECONDARY, true);
        txt.defaultTextFormat = fmt;
        txt.text = label;
        txt.x = 16;
        txt.y = (h - 18) / 2;
        txt.width = w - 24;
        txt.selectable = false;
        txt.mouseEnabled = false;

        btn.addChild(txt);
        _tabButtons.set(tabId, btn);
        _tabLabels.set(tabId, txt);

        btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            switchTab(tabId);
        });

        btn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            if (_currentTab != tabId) {
                renderTabGraphic(btn, w, h, false, true);
                txt.textColor = ApiStyle.COLOR_TEXT_PRIMARY;
            }
        });

        btn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            if (_currentTab != tabId) {
                renderTabGraphic(btn, w, h, false, false);
                txt.textColor = ApiStyle.COLOR_TEXT_SECONDARY;
            }
        });

        renderTabGraphic(btn, w, h, false, false);
        return btn;
    }

    private function renderTabGraphic(btn:Sprite, w:Float, h:Float, isActive:Bool, isHover:Bool):Void {
        btn.graphics.clear();
        if (isActive) {
            btn.graphics.beginFill(ApiStyle.COLOR_BG_CARD, 1);
            btn.graphics.lineStyle(1, ApiStyle.COLOR_ACCENT_PRIMARY);
            btn.graphics.drawRoundRect(0, 0, w, h, ApiStyle.CORNER_RADIUS, ApiStyle.CORNER_RADIUS);
            btn.graphics.endFill();

            btn.graphics.beginFill(ApiStyle.COLOR_ACCENT_PRIMARY, 1);
            btn.graphics.lineStyle(0, 0, 0);
            btn.graphics.drawRoundRect(0, 4, 3.5, h - 8, 2, 2);
            btn.graphics.endFill();
        } else if (isHover) {
            btn.graphics.beginFill(ApiStyle.COLOR_BG_CARD_HOVER, 1);
            btn.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_HIGHLIGHT);
            btn.graphics.drawRoundRect(0, 0, w, h, ApiStyle.CORNER_RADIUS, ApiStyle.CORNER_RADIUS);
            btn.graphics.endFill();
        } else {
            btn.graphics.beginFill(ApiStyle.COLOR_BG_PANEL, 1);
            btn.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_CARD);
            btn.graphics.drawRoundRect(0, 0, w, h, ApiStyle.CORNER_RADIUS, ApiStyle.CORNER_RADIUS);
            btn.graphics.endFill();
        }
    }

    private function switchTab(tabId:DashboardTab):Void {
        var isSameTab = (_currentTab == tabId);
        _currentTab = tabId;

        var tabW:Float = SIDEBAR_WIDTH - 12;
        var tabH:Float = 36;

        for (t in _tabButtons.keys()) {
            var btn = _tabButtons.get(t);
            var txt = _tabLabels.get(t);
            var isActive = (t == tabId);
            renderTabGraphic(btn, tabW, tabH, isActive, false);
            txt.textColor = isActive ? ApiStyle.COLOR_ACCENT_PRIMARY : ApiStyle.COLOR_TEXT_SECONDARY;
        }

        renderTabContent(tabId, isSameTab);
    }

    // =========================================================================
    // CONTENT VIEWPORT & SCROLLING
    // =========================================================================

    private function setupContentViewport():Void {
        _contentViewport = new Sprite();
        _contentViewport.x = SIDEBAR_WIDTH + 24;
        _contentViewport.y = 56;
        _window.addChild(_contentViewport);

        _contentMask = new Shape();
        _contentMask.graphics.beginFill(0xFF0000);
        _contentMask.graphics.drawRect(0, 0, _contentWidth, _contentHeight);
        _contentMask.graphics.endFill();
        _contentMask.x = _contentViewport.x;
        _contentMask.y = _contentViewport.y;
        _window.addChild(_contentMask);

        _contentContainer = new Sprite();
        _contentViewport.addChild(_contentContainer);
        _contentViewport.mask = _contentMask;

        _scrollbarTrack = new Shape();
        _scrollbarTrack.x = _contentViewport.x + _contentWidth - 6;
        _scrollbarTrack.y = _contentViewport.y;
        _window.addChild(_scrollbarTrack);

        _scrollbarThumb = new Shape();
        _scrollbarThumb.x = _scrollbarTrack.x;
        _scrollbarThumb.y = _scrollbarTrack.y;
        _window.addChild(_scrollbarThumb);

        _window.addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent):Void {
            var totalH = getTotalContentHeight();
            if (totalH <= _contentHeight) return;
            var maxScroll = _contentHeight - totalH;
            _contentContainer.y += e.delta * 25;
            if (_contentContainer.y > 0) _contentContainer.y = 0;
            if (_contentContainer.y < maxScroll) _contentContainer.y = maxScroll;
            updateScrollbar();
        });

        _contentViewport.addEventListener(MouseEvent.MOUSE_DOWN, onContentMouseDown);
    }

    private function onContentMouseDown(e:MouseEvent):Void {
        var totalH = getTotalContentHeight();
        if (stage == null || totalH <= _contentHeight) return;
        _isDraggingScroll = false;
        _hasDraggedScroll = false;
        _dragStartY = stage.mouseY;
        _dragStartContentY = _contentContainer.y;

        stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
        stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
    }

    private function onStageMouseMove(e:MouseEvent):Void {
        var totalH = getTotalContentHeight();
        if (stage == null || totalH <= _contentHeight) return;
        var dy = stage.mouseY - _dragStartY;
        if (!_isDraggingScroll && Math.abs(dy) > 4) {
            _isDraggingScroll = true;
            _hasDraggedScroll = true;
        }
        if (_isDraggingScroll) {
            var newY = _dragStartContentY + dy;
            var maxScroll = _contentHeight - totalH;
            if (newY > 0) newY = 0;
            if (newY < maxScroll) newY = maxScroll;
            _contentContainer.y = newY;
            updateScrollbar();
        }
    }

    private function onStageMouseUp(e:MouseEvent):Void {
        if (stage != null) {
            stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
            stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
        }
        haxe.Timer.delay(function() {
            _isDraggingScroll = false;
            _hasDraggedScroll = false;
        }, 80);
    }

    public function updateScrollbar():Void {
        var totalH = getTotalContentHeight();
        if (totalH <= _contentHeight) {
            _scrollbarTrack.visible = false;
            _scrollbarThumb.visible = false;
            return;
        }

        _scrollbarTrack.visible = true;
        _scrollbarThumb.visible = true;

        var sbW:Float = 6;
        _scrollbarTrack.graphics.clear();
        _scrollbarTrack.graphics.beginFill(ApiStyle.COLOR_BG_SURFACE, 0.95);
        _scrollbarTrack.graphics.drawRoundRect(0, 0, sbW, _contentHeight, 3, 3);
        _scrollbarTrack.graphics.endFill();

        var viewRatio = _contentHeight / totalH;
        var thumbH = Math.max(24, _contentHeight * viewRatio);
        var scrollRatio = -_contentContainer.y / (totalH - _contentHeight);
        var thumbY = scrollRatio * (_contentHeight - thumbH);

        _scrollbarThumb.graphics.clear();
        _scrollbarThumb.graphics.beginFill(ApiStyle.COLOR_TEXT_MUTED, 0.95);
        _scrollbarThumb.graphics.drawRoundRect(0, thumbY, sbW, thumbH, 3, 3);
        _scrollbarThumb.graphics.endFill();
    }

    // =========================================================================
    // ITEM ROW RENDERERS
    // =========================================================================

    private function clearContent(preserveScroll:Bool = false):Void {
        while (_contentContainer.numChildren > 0) {
            _contentContainer.removeChildAt(0);
        }
        _gridCol = 0;
        _gridRowY = 0;
        _gridRowH = 0;
        _pendingRowRenderBgs = [];
        _totalContentHeight = 0;
        if (!preserveScroll) {
            _contentContainer.y = 0;
        }
        updateScrollbar();
    }

    public function flushGrid():Void {
        if (_gridCol > 0) {
            for (renderBg in _pendingRowRenderBgs) {
                renderBg(_gridRowH);
            }
            _totalContentHeight = _gridRowY + _gridRowH + 6;
            _gridCol = 0;
            _gridRowH = 0;
            _pendingRowRenderBgs = [];
        }
    }

    private function getTotalContentHeight():Float {
        var h = (_gridCol > 0) ? (_gridRowY + _gridRowH + 6) : _totalContentHeight;
        return h > 6 ? (h - 6) : h;
    }

    public function addSectionHeader(title:String):Void {
        flushGrid();
        var rowW:Float = _contentWidth - 14;
        var header = new Sprite();

        var lbl = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_ACCENT, true);
        lbl.defaultTextFormat = fmt;
        lbl.text = title.toUpperCase();
        lbl.x = 2;
        lbl.y = 0;
        lbl.autoSize = TextFieldAutoSize.LEFT;
        lbl.selectable = false;
        lbl.mouseEnabled = false;
        header.addChild(lbl);

        var lineX:Float = lbl.x + lbl.width + 8;
        if (lineX < rowW) {
            header.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_PANEL);
            header.graphics.moveTo(lineX, 7);
            header.graphics.lineTo(rowW, 7);
        }

        header.x = 0;
        header.y = _totalContentHeight + 4;
        _contentContainer.addChild(header);

        _totalContentHeight += 24;
        updateScrollbar();
    }

    public function addInfoBanner(text:String):Void {
        flushGrid();
        var rowW:Float = _contentWidth - 14;
        var banner = new Sprite();

        var descTxt = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_SECONDARY, false);
        descTxt.defaultTextFormat = fmt;
        descTxt.text = text;
        descTxt.x = 10;
        descTxt.y = 7;
        descTxt.width = rowW - 20;
        descTxt.wordWrap = true;
        descTxt.multiline = true;
        descTxt.autoSize = TextFieldAutoSize.LEFT;
        descTxt.selectable = false;
        descTxt.mouseEnabled = false;
        banner.addChild(descTxt);

        var bannerH:Float = descTxt.height + 14;
        banner.graphics.beginFill(ApiStyle.COLOR_BG_CARD, 0.85);
        banner.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_CARD);
        banner.graphics.drawRoundRect(0, 0, rowW, bannerH, ApiStyle.CORNER_RADIUS, ApiStyle.CORNER_RADIUS);
        banner.graphics.endFill();

        banner.x = 0;
        banner.y = _totalContentHeight;
        _contentContainer.addChild(banner);

        _totalContentHeight += bannerH + 8;
        updateScrollbar();
    }

    public function addItemRow(
        title:String,
        description:String,
        actionType:String,
        actionLabel:String,
        isPrimary:Bool,
        onClick:Void->Void,
        getToggleState:Void->Bool = null,
        getButtonLabel:Void->String = null
    ):Void {
        var totalW:Float = _contentWidth - 14;
        var colGap:Float = 8;
        var numCols:Int = Std.int(Math.max(1, Math.floor((totalW + colGap) / (340 + colGap))));
        if (numCols > 4) numCols = 4;
        var colW:Float = Math.floor((totalW - (numCols - 1) * colGap) / numCols);

        var isToggle = (actionType == "toggle");
        var btnW:Float = isToggle ? 56 : 74;
        var btnH:Float = 24;
        var padX:Float = 10;
        var gapBtn:Float = 8;
        var textW:Float = colW - padX - btnW - gapBtn - 4;

        var card = new Sprite();

        // Title
        var titleTxt = new TextField();
        var titleFmt = new TextFormat(ApiStyle.FONT_FAMILY, 11.5, ApiStyle.COLOR_TEXT_TITLE, true);
        titleTxt.defaultTextFormat = titleFmt;
        titleTxt.text = title;
        titleTxt.x = padX;
        titleTxt.y = 5;
        titleTxt.width = textW;
        titleTxt.height = 16;
        titleTxt.selectable = false;
        titleTxt.mouseEnabled = false;
        card.addChild(titleTxt);

        // Description (Compact 1-2 lines)
        var descTxt = new TextField();
        var descFmt = new TextFormat(ApiStyle.FONT_FAMILY, 10, ApiStyle.COLOR_TEXT_SECONDARY, false);
        descTxt.defaultTextFormat = descFmt;
        descTxt.text = description;
        descTxt.x = padX;
        descTxt.y = 20;
        descTxt.width = textW;
        descTxt.wordWrap = true;
        descTxt.multiline = true;
        descTxt.autoSize = TextFieldAutoSize.LEFT;
        descTxt.selectable = false;
        descTxt.mouseEnabled = false;
        card.addChild(descTxt);

        // Dynamic compact height
        var textBottom:Float = descTxt.y + descTxt.height + 5;
        var minCardH:Float = 42;
        var cardH:Float = Math.max(minCardH, textBottom);

        // Action button / toggle vertically centered
        var actionX:Float = colW - padX - btnW + 2;
        var actionY:Float = Math.round((cardH - btnH) / 2);

        var actionSprite:Sprite = null;
        if (isToggle) {
            actionSprite = createToggleControl(btnW, btnH, getToggleState, onClick);
        } else {
            actionSprite = createActionButton(actionLabel, btnW, btnH, isPrimary, onClick, getButtonLabel);
        }
        actionSprite.x = actionX;
        actionSprite.y = actionY;
        card.addChild(actionSprite);

        // Background renderer with hover responsiveness
        var curRenderH:Float = cardH;
        var renderCardBg = function(h:Float, isHover:Bool):Void {
            curRenderH = h;
            card.graphics.clear();
            card.graphics.beginFill(isHover ? ApiStyle.COLOR_BG_CARD_HOVER : ApiStyle.COLOR_BG_CARD, 1);
            card.graphics.lineStyle(1, isHover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_CARD);
            card.graphics.drawRoundRect(0, 0, colW, h, ApiStyle.CORNER_RADIUS, ApiStyle.CORNER_RADIUS);
            card.graphics.endFill();

            if (actionSprite != null) {
                actionSprite.y = Math.round((h - btnH) / 2);
            }
        };
        renderCardBg(cardH, false);

        card.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            renderCardBg(curRenderH, true);
        });
        card.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            renderCardBg(curRenderH, false);
        });

        card.cacheAsBitmap = true;

        if (_gridCol == 0) {
            _gridRowY = _totalContentHeight;
            _gridRowH = cardH;
            _pendingRowRenderBgs = [];
        } else {
            if (cardH > _gridRowH) {
                _gridRowH = cardH;
            }
        }

        card.x = _gridCol * (colW + colGap);
        card.y = _gridRowY;
        _contentContainer.addChild(card);

        _pendingRowRenderBgs.push(function(maxH:Float):Void {
            renderCardBg(maxH, false);
        });

        _gridCol++;

        if (_gridCol >= numCols) {
            for (renderBg in _pendingRowRenderBgs) {
                renderBg(_gridRowH);
            }
            _totalContentHeight = _gridRowY + _gridRowH + 6;
            _gridCol = 0;
            _gridRowH = 0;
            _pendingRowRenderBgs = [];
        }

        updateScrollbar();
    }

    private function createActionButton(label:String, w:Float, h:Float, isPrimary:Bool, onClick:Void->Void, getLabel:Void->String = null):Sprite {
        var btn = new Sprite();
        btn.buttonMode = true;

        var bg = isPrimary ? ApiStyle.COLOR_BTN_BG_PRIMARY : ApiStyle.COLOR_BTN_BG_NORMAL;
        var border = isPrimary ? ApiStyle.COLOR_BTN_BORDER_PRIMARY : ApiStyle.COLOR_BTN_BORDER_NORMAL;
        var hoverBg = isPrimary ? ApiStyle.COLOR_BTN_BG_PRIMARY_HOVER : ApiStyle.COLOR_BTN_BG_HOVER;
        var hoverBorder = isPrimary ? ApiStyle.COLOR_ACCENT_HOVER : ApiStyle.COLOR_BTN_BORDER_HOVER;
        var textColor = isPrimary ? ApiStyle.COLOR_TEXT_ON_ACCENT : ApiStyle.COLOR_TEXT_PRIMARY;

        var drawBg = function(isHover:Bool):Void {
            btn.graphics.clear();
            btn.graphics.beginFill(isHover ? hoverBg : bg, 1);
            btn.graphics.lineStyle(1, isHover ? hoverBorder : border);
            btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
            btn.graphics.endFill();
        };
        drawBg(false);

        var initialText = (getLabel != null) ? getLabel() : label;
        var txt = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, textColor, true);
        fmt.align = TextFormatAlign.CENTER;
        txt.defaultTextFormat = fmt;
        txt.text = initialText;
        txt.width = w - 4;
        txt.height = 18;
        txt.x = 2;
        txt.y = Math.round((h - 18) / 2);
        txt.selectable = false;
        txt.mouseEnabled = false;
        btn.addChild(txt);

        var updateLabel = function():Void {
            if (getLabel != null) {
                var newTxt = getLabel();
                if (txt.text != newTxt) txt.text = newTxt;
            }
        };

        btn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            drawBg(true);
            txt.textColor = isPrimary ? ApiStyle.COLOR_TEXT_ON_ACCENT : ApiStyle.COLOR_TEXT_TITLE;
        });

        btn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            drawBg(false);
            txt.textColor = textColor;
        });

        btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (_isDraggingScroll || _hasDraggedScroll) return;
            if (onClick != null) onClick();
            updateLabel();
        });

        if (getLabel != null) {
            btn.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
                updateLabel();
            });
        }

        return btn;
    }

    private function createToggleControl(w:Float, h:Float, getState:Void->Bool, onToggle:Void->Void):Sprite {
        var btn = new Sprite();
        btn.buttonMode = true;

        var txt = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 10.5, ApiStyle.COLOR_TEXT_TITLE, true);
        fmt.align = TextFormatAlign.CENTER;
        txt.defaultTextFormat = fmt;
        txt.width = w - 12;
        txt.height = 18;
        txt.x = 10;
        txt.y = Math.round((h - 18) / 2);
        txt.selectable = false;
        txt.mouseEnabled = false;
        btn.addChild(txt);

        var lastState:Null<Bool> = null;

        var updateVisual = function():Void {
            var active = (getState != null) ? getState() : false;
            if (lastState == active) return;
            lastState = active;

            btn.graphics.clear();
            if (active) {
                btn.graphics.beginFill(0x133829, 1); // Dark emerald plate
                btn.graphics.lineStyle(1, ApiStyle.COLOR_STATUS_ACTIVE);
                btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
                btn.graphics.endFill();

                // Small radiant green dot
                btn.graphics.beginFill(ApiStyle.COLOR_STATUS_ACTIVE, 1);
                btn.graphics.drawCircle(8, h / 2, 2.5);
                btn.graphics.endFill();

                txt.textColor = ApiStyle.COLOR_STATUS_ACTIVE;
                txt.text = "ON";
            } else {
                btn.graphics.beginFill(ApiStyle.COLOR_BG_PANEL, 1);
                btn.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT);
                btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
                btn.graphics.endFill();

                // Small muted gray dot
                btn.graphics.beginFill(ApiStyle.COLOR_TEXT_MUTED, 0.6);
                btn.graphics.drawCircle(8, h / 2, 2);
                btn.graphics.endFill();

                txt.textColor = ApiStyle.COLOR_TEXT_MUTED;
                txt.text = "OFF";
            }
        };

        btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (_isDraggingScroll || _hasDraggedScroll) return;
            if (onToggle != null) onToggle();
            lastState = null;
            updateVisual();
        });

        btn.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            updateVisual();
        });

        updateVisual();
        return btn;
    }

    // =========================================================================
    // TAB CONTENTS
    // =========================================================================

    private function renderTabContent(tabId:DashboardTab, preserveScroll:Bool = false):Void {
        var savedScrollY:Float = _contentContainer.y;
        clearContent(preserveScroll);

        var handler = _tabHandlers.get(tabId);
        if (handler != null) {
            handler.render(this);
        }
        flushGrid();

        if (preserveScroll) {
            var totalH = getTotalContentHeight();
            var maxScroll = (totalH > _contentHeight) ? (_contentHeight - totalH) : 0;
            if (savedScrollY > 0) savedScrollY = 0;
            if (savedScrollY < maxScroll) savedScrollY = maxScroll;
            _contentContainer.y = savedScrollY;
            updateScrollbar();
        }
    }
}
#else
class ApiDashboardModal {
    public static function show(overlay:Dynamic, pocket:Dynamic = null):Void {}
    public static function close():Void {}
    public static function isOpen():Bool return false;
    public static function refreshCurrentTab():Void {}
}
#end
