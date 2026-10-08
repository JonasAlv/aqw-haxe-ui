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
import ui.Overlay;
import ui.prompts.ApiPrompts;
import util.HelperSetting;
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
            _instance.renderTabContent(_instance._currentTab);
        }
    }

    // Modal layout dimensions
    private static inline var SIDEBAR_WIDTH:Float = 170;

    private var _stageW:Float = 960;
    private var _stageH:Float = 550;
    private var _contentWidth:Float = 750;
    private var _contentHeight:Float = 480;

    private var _overlay:Dynamic;
    private var _pocket:Dynamic;
    private var _backdrop:Sprite;
    private var _window:Sprite;
    private var _closeBtn:Sprite;

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
    private inline function get_totalContentHeight():Float return _totalContentHeight;
    private inline function set_totalContentHeight(v:Float):Float return _totalContentHeight = v;

    private var _contentViewport:Sprite;
    private var _contentMask:Shape;
    private var _contentContainer:Sprite;
    private var _totalContentHeight:Float = 0;

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
        _contentWidth = Math.max(300, _stageW - (SIDEBAR_WIDTH + 26) - 16);
        _contentHeight = Math.max(200, _stageH - 56 - 12);
    }

    private function redrawWindowChrome():Void {
        _backdrop.graphics.clear();
        _backdrop.graphics.beginFill(ApiStyle.COLOR_BG_BACKDROP, ApiStyle.ALPHA_BACKDROP);
        _backdrop.graphics.drawRect(0, 0, _stageW, _stageH);
        _backdrop.graphics.endFill();

        _window.graphics.clear();
        _window.graphics.beginFill(ApiStyle.COLOR_BG_DASHBOARD, ApiStyle.ALPHA_DASHBOARD);
        _window.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_PANEL);
        _window.graphics.drawRect(0, 0, _stageW, _stageH);
        _window.graphics.endFill();

        // Divider line below header
        _window.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DIVIDER);
        _window.graphics.moveTo(0, 48);
        _window.graphics.lineTo(_stageW, 48);

        // Vertical divider line between sidebar and content
        _window.graphics.moveTo(SIDEBAR_WIDTH + 14, 48);
        _window.graphics.lineTo(SIDEBAR_WIDTH + 14, _stageH);

        if (_closeBtn != null) {
            _closeBtn.x = _stageW - 32 - 14;
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
        redrawWindowChrome();
        if (_contentMask != null) {
            _contentMask.graphics.clear();
            _contentMask.graphics.beginFill(0xFF0000);
            _contentMask.graphics.drawRect(0, 0, _contentWidth, _contentHeight);
            _contentMask.graphics.endFill();
        }
        if (_scrollbarTrack != null) {
            _scrollbarTrack.x = _contentViewport.x + _contentWidth - 8;
            _scrollbarThumb.x = _scrollbarTrack.x;
        }
        renderTabContent(_currentTab);
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
        _closeBtn.x = _stageW - cbW - 14;
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

        renderTabContent(tabId);
    }

    // =========================================================================
    // CONTENT VIEWPORT & SCROLLING
    // =========================================================================

    private function setupContentViewport():Void {
        _contentViewport = new Sprite();
        _contentViewport.x = SIDEBAR_WIDTH + 26;
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
        _scrollbarTrack.x = _contentViewport.x + _contentWidth - 8;
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

    private function clearContent():Void {
        while (_contentContainer.numChildren > 0) {
            _contentContainer.removeChildAt(0);
        }
        _totalContentHeight = 0;
        _contentContainer.y = 0;
        updateScrollbar();
    }

    private function getTotalContentHeight():Float {
        return _totalContentHeight > 6 ? (_totalContentHeight - 6) : _totalContentHeight;
    }

    public function addSectionHeader(title:String):Void {
        var rowW:Float = _contentWidth - 20;
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

        _totalContentHeight += 22;
        updateScrollbar();
    }

    public function addInfoBanner(text:String):Void {
        var rowW:Float = _contentWidth - 20;
        var banner = new Sprite();

        var descTxt = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_SECONDARY, false);
        descTxt.defaultTextFormat = fmt;
        descTxt.text = text;
        descTxt.x = 10;
        descTxt.y = 8;
        descTxt.width = rowW - 20;
        descTxt.wordWrap = true;
        descTxt.multiline = true;
        descTxt.autoSize = TextFieldAutoSize.LEFT;
        descTxt.selectable = false;
        descTxt.mouseEnabled = false;
        banner.addChild(descTxt);

        var bannerH:Float = descTxt.height + 16;
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
        getToggleState:Void->Bool = null
    ):Void {
        var rowW:Float = _contentWidth - 20;
        var btnW:Float = 116;
        var btnH:Float = 32;
        var padX:Float = 14;
        var gapBtn:Float = 14;
        var textW:Float = rowW - padX - btnW - gapBtn - 8;

        var card = new Sprite();

        // Title
        var titleTxt = new TextField();
        var titleFmt = new TextFormat(ApiStyle.FONT_FAMILY, 13, ApiStyle.COLOR_TEXT_TITLE, true);
        titleTxt.defaultTextFormat = titleFmt;
        titleTxt.text = title;
        titleTxt.x = padX;
        titleTxt.y = 10;
        titleTxt.width = textW;
        titleTxt.wordWrap = true;
        titleTxt.multiline = true;
        titleTxt.autoSize = TextFieldAutoSize.LEFT;
        titleTxt.selectable = false;
        titleTxt.mouseEnabled = false;
        card.addChild(titleTxt);

        // Description (Word wrapped & autoSize so text scales dynamically without clipping!)
        var descTxt = new TextField();
        var descFmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_SECONDARY, false);
        descTxt.defaultTextFormat = descFmt;
        descTxt.text = description;
        descTxt.x = padX;
        descTxt.y = titleTxt.y + titleTxt.height + 3;
        descTxt.width = textW;
        descTxt.wordWrap = true;
        descTxt.multiline = true;
        descTxt.autoSize = TextFieldAutoSize.LEFT;
        descTxt.selectable = false;
        descTxt.mouseEnabled = false;
        card.addChild(descTxt);

        // Dynamic height calculation based on actual content
        var textBottom:Float = descTxt.y + descTxt.height + 10;
        var minCardH:Float = btnH + 18; // 50px
        var cardH:Float = Math.max(minCardH, textBottom);

        // Action button / toggle vertically centered within dynamic card height
        var actionX:Float = rowW - padX - btnW;
        var actionY:Float = (cardH - btnH) / 2;

        if (actionType == "toggle") {
            var toggleBtn = createToggleControl(btnW, btnH, getToggleState, onClick);
            toggleBtn.x = actionX;
            toggleBtn.y = actionY;
            card.addChild(toggleBtn);
        } else {
            var btn = createActionButton(actionLabel, btnW, btnH, isPrimary, onClick);
            btn.x = actionX;
            btn.y = actionY;
            card.addChild(btn);
        }

        // Draw card background with hover responsiveness
        var renderCardBg = function(isHover:Bool):Void {
            card.graphics.clear();
            card.graphics.beginFill(isHover ? ApiStyle.COLOR_BG_CARD_HOVER : ApiStyle.COLOR_BG_CARD, 1);
            card.graphics.lineStyle(1, isHover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_CARD);
            card.graphics.drawRoundRect(0, 0, rowW, cardH, ApiStyle.CORNER_RADIUS, ApiStyle.CORNER_RADIUS);
            card.graphics.endFill();
        };
        renderCardBg(false);

        card.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            renderCardBg(true);
        });
        card.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            renderCardBg(false);
        });

        // Snap vertically directly below previous card
        card.cacheAsBitmap = true;
        card.x = 0;
        card.y = _totalContentHeight;
        _contentContainer.addChild(card);

        // Advance vertical anchor snapping to the next card with 6px gap
        _totalContentHeight += cardH + 6;

        updateScrollbar();
    }

    private function createActionButton(label:String, w:Float, h:Float, isPrimary:Bool, onClick:Void->Void):Sprite {
        var btn = new Sprite();
        btn.buttonMode = true;

        var bg = isPrimary ? ApiStyle.COLOR_BTN_BG_PRIMARY : ApiStyle.COLOR_BTN_BG_NORMAL;
        var border = isPrimary ? ApiStyle.COLOR_BTN_BORDER_PRIMARY : ApiStyle.COLOR_BTN_BORDER_NORMAL;
        var hoverBg = isPrimary ? ApiStyle.COLOR_BTN_BG_PRIMARY_HOVER : ApiStyle.COLOR_BTN_BG_HOVER;
        var hoverBorder = isPrimary ? ApiStyle.COLOR_ACCENT_HOVER : ApiStyle.COLOR_BTN_BORDER_HOVER;
        var textColor = isPrimary ? ApiStyle.COLOR_TEXT_ON_ACCENT : ApiStyle.COLOR_TEXT_PRIMARY;

        btn.graphics.beginFill(bg, 1);
        btn.graphics.lineStyle(1, border);
        btn.graphics.drawRoundRect(0, 0, w, h, 5, 5);
        btn.graphics.endFill();

        var txt = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 12, textColor, true);
        fmt.align = TextFormatAlign.CENTER;
        txt.defaultTextFormat = fmt;
        txt.text = label;
        txt.width = w;
        txt.height = 20;
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
            txt.textColor = isPrimary ? ApiStyle.COLOR_TEXT_ON_ACCENT : ApiStyle.COLOR_TEXT_TITLE;
        });

        btn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            btn.graphics.clear();
            btn.graphics.beginFill(bg, 1);
            btn.graphics.lineStyle(1, border);
            btn.graphics.drawRoundRect(0, 0, w, h, 5, 5);
            btn.graphics.endFill();
            txt.textColor = textColor;
        });

        btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (_isDraggingScroll || _hasDraggedScroll) return;
            if (onClick != null) onClick();
        });

        return btn;
    }

    private function createToggleControl(w:Float, h:Float, getState:Void->Bool, onToggle:Void->Void):Sprite {
        var btn = new Sprite();
        btn.buttonMode = true;

        var txt = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_TITLE, true);
        fmt.align = TextFormatAlign.CENTER;
        txt.defaultTextFormat = fmt;
        txt.width = w;
        txt.height = 20;
        txt.y = (h - 20) / 2;
        txt.selectable = false;
        txt.mouseEnabled = false;
        btn.addChild(txt);

        var updateVisual = function():Void {
            var active = (getState != null) ? getState() : false;
            btn.graphics.clear();
            if (active) {
                btn.graphics.beginFill(ApiStyle.COLOR_BG_SURFACE, 1);
                btn.graphics.lineStyle(1, ApiStyle.COLOR_STATUS_ACTIVE);
                btn.graphics.drawRoundRect(0, 0, w, h, 5, 5);
                btn.graphics.endFill();
                txt.textColor = ApiStyle.COLOR_STATUS_ACTIVE;
                txt.text = "ON";
            } else {
                btn.graphics.beginFill(ApiStyle.COLOR_BG_SURFACE, 1);
                btn.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT);
                btn.graphics.drawRoundRect(0, 0, w, h, 5, 5);
                btn.graphics.endFill();
                txt.textColor = ApiStyle.COLOR_TEXT_MUTED;
                txt.text = "OFF";
            }
        };

        btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (_isDraggingScroll || _hasDraggedScroll) return;
            if (onToggle != null) onToggle();
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

    private function renderTabContent(tabId:DashboardTab):Void {
        clearContent();

        var handler = _tabHandlers.get(tabId);
        if (handler != null) {
            handler.render(this);
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
