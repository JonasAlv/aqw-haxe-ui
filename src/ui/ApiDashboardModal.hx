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

enum DashboardTab {
    TabScripts;
    TabAutomation;
    TabEnhancements;
    TabHud;
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

    private function updateScrollbar():Void {
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

    private function addSectionHeader(title:String):Void {
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

    private function addInfoBanner(text:String):Void {
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

    private function addItemRow(
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

        switch (tabId) {
            case TabScripts:
                renderScriptsTab();
            case TabAutomation:
                renderAutomationTab();
            case TabEnhancements:
                renderEnhancementsTab();
            case TabHud:
                renderHudTab();
            case TabSettings:
                renderSettingsTab();
        }
    }

    private function renderScriptsTab():Void {
        addSectionHeader("Script Execution");

        // 1. Script Manager
        addItemRow(
            "Script Manager",
            "Manage, edit, create, save, and run automation scripts.",
            "button",
            "Open",
            true, // Primary red button!
            function():Void {
                ApiPrompts.showScriptManager(_overlay);
            }
        );

        // 2. Script Engine State (Run/Stop toggle)
        addItemRow(
            "Script Runner",
            "Controls active script execution. Turn off to immediately abort any running script.",
            "toggle",
            "",
            false,
            function():Void {
                if (ScriptManager.SINGLETON.isRunning) {
                    ScriptManager.SINGLETON.stop();
                    ApiNotificationManager.notify("Script stopped.");
                } else {
                    ScriptManager.SINGLETON.start();
                    if (ScriptManager.SINGLETON.isRunning) {
                        ApiNotificationManager.notify("Script started.");
                    } else {
                        ApiNotificationManager.notify("No script loaded! Open Script Manager to select one.");
                    }
                }
            },
            function():Bool {
                return ScriptManager.SINGLETON.isRunning;
            }
        );

        // 3. Load Script from file
        #if air
        addItemRow(
            "Load Script File",
            "Browse and load an .hscript or text file directly from your local filesystem.",
            "button",
            "Load",
            false,
            function():Void {
                try {
                    var fileCls:Dynamic = untyped __global__["flash.filesystem.File"];
                    var fsCls:Dynamic = untyped __global__["flash.filesystem.FileStream"];
                    var fmCls:Dynamic = untyped __global__["flash.filesystem.FileMode"];
                    var ffCls:Dynamic = untyped __global__["flash.net.FileFilter"];

                    var file = fileCls.desktopDirectory;
                    file.addEventListener("select", function(ev:Dynamic):Void {
                        var stream = Type.createInstance(fsCls, []);
                        stream.open(file, fmCls.READ);
                        var content:String = stream.readUTFBytes(stream.bytesAvailable);
                        stream.close();

                        ScriptManager.SINGLETON.loadScript(content);
                        ScriptManager.SINGLETON.start();
                        ApiNotificationManager.notify("Loaded: " + file.name);
                    });
                    file.browseForOpen("Select Script", [Type.createInstance(ffCls, ["HScript / Text (*.hscript, *.txt)", "*.hscript;*.txt"])]);
                } catch (e:Dynamic) {
                    ApiNotificationManager.notify("File error: " + e);
                }
            }
        );
        #end

        // 4. Paste Script
        addItemRow(
            "Paste Script",
            "Paste raw HScript code and execute it immediately in the runtime engine.",
            "button",
            "Paste",
            false,
            function():Void {
                ApiPrompts.showPastePrompt(_overlay);
            }
        );

        addSectionHeader("Automation & Logging");

        // 5. Class Loadouts (For Scripts)
        addItemRow(
            "Class Loadouts (Scripting)",
            "Configure default Farm, Solo, Boss, and Dodge classes for script auto-swapping.",
            "button",
            "Setup",
            false,
            function():Void {
                ApiPrompts.showLoadoutsPrompt(_overlay);
            }
        );

        // 6. Clear Log
        addItemRow(
            "Clear Bot Log",
            "Truncates bot.log to start fresh for monitoring and debugging sessions.",
            "button",
            "Clear Log",
            false,
            function():Void {
                ApiLogger.clearLog();
                ApiNotificationManager.notify("bot.log cleared!");
            }
        );
    }

    private function renderAutomationTab():Void {
        addSectionHeader("Smart Combat");

        // 1. Smart Combat Toggle
        addItemRow(
            "Smart Combat",
            "Auto-detects equipped class and executes optimal skill combos and priority rotations.",
            "toggle",
            "",
            false,
            function():Void {
                var current = (Api.combat != null && Api.combat.isRunning());
                var next = !current;
                ApiConfig.setBool("api_smart_combat_active", next);
                if (Api.combat != null) {
                    if (next) {
                        var confClass = ApiConfig.getString("api_smart_class", "Current");
                        var confMode = ApiConfig.getString("api_smart_mode", "Auto");
                        Api.combat.startSmartStandalone(confClass, confMode);
                    } else {
                        Api.combat.stop();
                    }
                }
                ApiNotificationManager.notify("Smart Combat: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.combat != null && Api.combat.isRunning());
            }
        );

        // 2. Smart Combat Setup (Standalone)
        addItemRow(
            "Smart Combat Setup",
            "Standalone Smart Combat setup. Choose target class and mode (or set to 'Current').",
            "button",
            "Configure",
            false,
            function():Void {
                ApiPrompts.showSmartCombatPrompt(_overlay);
            }
        );

        // 3. Combat Modes Editor
        addItemRow(
            "Combat Modes",
            "Create, edit, and save skill rotations directly to userSkills.json.",
            "button",
            "Editor",
            false,
            function():Void {
                ApiPrompts.showCombatModeEditorPrompt(_overlay);
            }
        );

        addSectionHeader("Custom Combos & Quests");

        // 4. Custom Auto-Combat
        addItemRow(
            "Custom Combat",
            "Setup custom skill combo sequences and targeting rules.",
            "button",
            "Configure",
            false,
            function():Void {
                ApiPrompts.showCombatPrompt(_overlay);
            }
        );

        // 5. Auto-Quest
        var isQuestAuto = (Api.quest != null && Api.quest.isAutoRunning);
        var qStr = (Api.quest != null) ? Api.quest.autoQuestString : "";
        var questDesc = isQuestAuto
            ? ("Active: Safe looping accept & turn-in (" + (qStr != "" ? qStr : "Running") + ")")
            : "Automatically accept and turn in quests by IDs in the background using safe queue pacing.";
        addItemRow(
            "Auto-Quest",
            questDesc,
            "button",
            isQuestAuto ? "Running" : "Configure",
            isQuestAuto,
            function():Void {
                ApiPrompts.showQuestPrompt(_overlay);
            }
        );
    }

    private function addEnhancementLoadoutCard():Void {
        var rowW:Float = _contentWidth - 20;
        var cardH:Float = 88;
        var card = new Sprite();

        var curClass = (Api.player != null && Api.player.className != null && Api.player.className != "") ? Api.player.className : "Equipped Class";
        var playerLvl:Int = (Api.player != null) ? Api.player.level : 100;
        var slots = (Api.enhancement != null) ? Api.enhancement.getEquippedSlots() : null;
        var rec = (Api.enhancement != null) ? Api.enhancement.getRecommendation(curClass) : null;

        var wItem = (slots != null) ? slots.weapon : null;
        var wBase = (wItem != null && Api.enhancement != null) ? Api.enhancement.patternIdToName(wItem.enhPatternId) : "None";
        var wSpec = (Api.enhancement != null) ? Api.enhancement.currentWeaponSpecial() : "None";
        var wName = (wSpec != "None" && wSpec != "") ? wSpec : wBase;
        var wLvl:Int = (wItem != null) ? wItem.enhLevel : 0;

        var cTarget = (slots != null) ? ((slots.classItem != null) ? slots.classItem : slots.armor) : null;
        var cEnh = (Api.enhancement != null) ? Api.enhancement.currentClassEnh() : "None";
        var cLvl:Int = (cTarget != null) ? cTarget.enhLevel : 0;

        var hItem = (slots != null) ? slots.helm : null;
        var hBase = (hItem != null && Api.enhancement != null) ? Api.enhancement.patternIdToName(hItem.enhPatternId) : "None";
        var hSpec = (Api.enhancement != null) ? Api.enhancement.currentHelmSpecial() : "None";
        var hName = (hSpec != "None" && hSpec != "") ? hSpec : hBase;
        var hLvl:Int = (hItem != null) ? hItem.enhLevel : 0;

        var capeItem = (slots != null) ? slots.cape : null;
        var capeBase = (capeItem != null && Api.enhancement != null) ? Api.enhancement.patternIdToName(capeItem.enhPatternId) : "None";
        var capeSpec = (Api.enhancement != null) ? Api.enhancement.currentCapeSpecial() : "None";
        var capeName = (capeSpec != "None" && capeSpec != "") ? capeSpec : capeBase;
        var capeLvl:Int = (capeItem != null) ? capeItem.enhLevel : 0;

        var isOptimal:Bool = false;
        if (rec != null && slots != null) {
            var wMaxLvl = (Api.enhancement != null) ? Api.enhancement.getMaxAvailableLevel("Weapon", rec.type, rec.weapon) : playerLvl;
            var cMaxLvl = (Api.enhancement != null) ? Api.enhancement.getMaxAvailableLevel("ar", rec.type, "None") : playerLvl;
            var hMaxLvl = (Api.enhancement != null) ? Api.enhancement.getMaxAvailableLevel("he", rec.type, rec.helm) : playerLvl;
            var capeMaxLvl = (Api.enhancement != null) ? Api.enhancement.getMaxAvailableLevel("ba", rec.type, rec.cape) : playerLvl;

            var wMatches = (rec.weapon == "None" || rec.weapon == wSpec) && (wLvl >= wMaxLvl);
            var cMatches = (rec.type == cEnh) && (cLvl >= cMaxLvl);
            var hMatches = (rec.helm == "None" || rec.helm == hSpec) && (hLvl >= hMaxLvl);
            var capeMatches = (rec.cape == "None" || rec.cape == capeSpec) && (capeLvl >= capeMaxLvl);
            isOptimal = (wMatches && cMatches && hMatches && capeMatches);
        }

        card.graphics.beginFill(ApiStyle.COLOR_BG_CARD, 1);
        card.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_CARD);
        card.graphics.drawRoundRect(0, 0, rowW, cardH, 6, 6);

        card.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DIVIDER);
        card.graphics.moveTo(12, 28);
        card.graphics.lineTo(rowW - 12, 28);
        card.graphics.endFill();

        var titleTxt = new TextField();
        var titleFmt = new TextFormat(ApiStyle.FONT_FAMILY, 12, ApiStyle.COLOR_TEXT_PRIMARY, true);
        titleTxt.defaultTextFormat = titleFmt;
        titleTxt.text = "Active Loadout: " + curClass + " (Lvl " + playerLvl + ")";
        titleTxt.x = 12;
        titleTxt.y = 7;
        titleTxt.width = rowW - 150;
        titleTxt.height = 18;
        titleTxt.selectable = false;
        titleTxt.mouseEnabled = false;
        card.addChild(titleTxt);

        var tagTxt = new TextField();
        var tagColor:Int = isOptimal ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_STATUS_WARN;
        var tagFmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, tagColor, true);
        tagFmt.align = TextFormatAlign.RIGHT;
        tagTxt.defaultTextFormat = tagFmt;
        tagTxt.text = isOptimal ? "[Optimal]" : "[Upgrade Available]";
        tagTxt.x = rowW - 145;
        tagTxt.y = 7;
        tagTxt.width = 135;
        tagTxt.height = 18;
        tagTxt.selectable = false;
        tagTxt.mouseEnabled = false;
        card.addChild(tagTxt);

        var drawSlotEntry = function(label:String, val:String, lvl:Int, dotColor:Null<Int>, sx:Float, sy:Float, maxW:Float):Void {
            var dot = new Shape();
            dot.graphics.beginFill(dotColor != null ? dotColor : ApiStyle.COLOR_TEXT_MUTED, 1);
            dot.graphics.drawCircle(sx + 4, sy + 7, 3.5);
            dot.graphics.endFill();
            card.addChild(dot);

            var sTxt = new TextField();
            var sFmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_PRIMARY, false);
            sTxt.defaultTextFormat = sFmt;
            var lvlStr = (lvl > 0) ? " (Lvl " + lvl + ")" : "";
            sTxt.text = label + ": " + val + lvlStr;
            sTxt.x = sx + 12;
            sTxt.y = sy;
            sTxt.width = maxW - 14;
            sTxt.height = 18;
            sTxt.selectable = false;
            sTxt.mouseEnabled = false;
            card.addChild(sTxt);
        };

        var halfW:Float = (rowW - 24) / 2;
        var col1X:Float = 12;
        var col2X:Float = 12 + halfW + 6;

        var wCol = EnhancementColors.getColor(wName, wBase);
        drawSlotEntry("Weapon", wName, wLvl, wCol, col1X, 36, halfW);

        var cCol = EnhancementColors.getColor(cEnh);
        drawSlotEntry("Class", cEnh, cLvl, cCol, col2X, 36, halfW);

        var hCol = EnhancementColors.getColor(hName, hBase);
        drawSlotEntry("Helm", hName, hLvl, hCol, col1X, 58, halfW);

        var capeCol = EnhancementColors.getColor(capeName, capeBase);
        drawSlotEntry("Cape", capeName, capeLvl, capeCol, col2X, 58, halfW);

        card.cacheAsBitmap = true;
        card.x = 0;
        card.y = _totalContentHeight;
        _contentContainer.addChild(card);

        _totalContentHeight += cardH + 10;
        updateScrollbar();
    }

    private function renderEnhancementsTab():Void {
        var curClass = (Api.player != null && Api.player.className != null && Api.player.className != "") ? Api.player.className : "Equipped Class";

        addEnhancementLoadoutCard();

        addSectionHeader("Auto-Enhance");

        // 1. One-Click Smart Enhance (Equipped)
        addItemRow(
            "Smart Enhance (Equipped)",
            "Auto-detects " + curClass + " & unlocks, then enhances equipped weapon, class, helm, and cape to the optimal build.",
            "button",
            "Enhance",
            true, // Primary red button!
            function():Void {
                if (Api.enhancement != null) {
                    if (Api.enhancement.isBusy) {
                        ApiNotificationManager.notify("Enhancement queue is currently busy!");
                        return;
                    }
                    ApiNotificationManager.notify("SmartEnhancing " + curClass + "...");
                    Api.enhancement.smartEnhance(null, function():Void {
                        ApiNotificationManager.notify("SmartEnhance finished!");
                    });
                }
            }
        );

        // 2. Custom Enhance Gear (Modal)
        addItemRow(
            "Custom Enhance Gear...",
            "Choose custom base enhancement types and Awe/Forge special traits for equipped gear.",
            "button",
            "Configure",
            false,
            function():Void {
                ApiPrompts.showCustomEnhancePrompt(_overlay);
            }
        );

        addSectionHeader("Enhancement Shops");

        // 3. Lvl 50+ Enhancements
        var lvl50Shops = [
            { name: "Healer Enh", id: 762 },
            { name: "Lucky Enh", id: 763 },
            { name: "Spellbreaker Enh", id: 764 },
            { name: "Wizard Enh", id: 765 },
            { name: "Hybrid Enh", id: 766 },
            { name: "Thief Enh", id: 767 },
            { name: "Fighter Enh", id: 768 }
        ];
        addItemRow(
            "Lvl 50+ Enhancements",
            "Browse and load level 50+ normal enhancement shops.",
            "button",
            "Open Shop",
            false,
            function():Void {
                ApiPrompts.showEnhancementPrompt(_overlay, "Lvl 50+ Enhancements", lvl50Shops, false);
            }
        );

        // 4. Awe Enhancements
        var aweShops = [
            { name: "Fighter Awe", id: 635 },
            { name: "Wizard Awe", id: 636 },
            { name: "Thief Awe", id: 637 },
            { name: "Healer Awe", id: 638 },
            { name: "Lucky Awe", id: 639 },
            { name: "Hybrid Awe", id: 633 }
        ];
        addItemRow(
            "Awe Enhancements",
            "Browse and load Blade of Awe enhancement shops.",
            "button",
            "Open Shop",
            false,
            function():Void {
                ApiPrompts.showEnhancementPrompt(_overlay, "Awe Enhancements", aweShops, false);
            }
        );

        // 5. Forge Enhancements
        var forgeShops = [
            { name: "Weapon Enh", id: 2142 },
            { name: "Cape Enh", id: 2143 },
            { name: "Helmet Enh", id: 2164 }
        ];
        addItemRow(
            "Forge Enhancements",
            "Browse and load Forge enhancement shops (auto-joins /forge).",
            "button",
            "Open Shop",
            false,
            function():Void {
                ApiPrompts.showEnhancementPrompt(_overlay, "Forge Enhancements", forgeShops, true);
            }
        );
    }

    private function renderHudTab():Void {
        addInfoBanner("Configure floating on-screen widgets and HUD buttons. Widgets can be collapsed with [-]/[+] and freely dragged anywhere on screen. Positions are saved automatically.");

        addSectionHeader("Modular On-Screen Widgets");

        // 0. HUD: Combat & Hunt Widget
        addItemRow(
            "HUD: Combat & Hunt Widget",
            "Compact on-screen widget featuring Atk / Hunt buttons, on-the-fly Class and Mode dropdowns, and target hunting input.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiMenuHubWidget.isCombatWidgetEnabled();
                var next = !cur;
                ApiMenuHubWidget.setCombatWidgetEnabled(next);
                ApiNotificationManager.notify("Combat Widget: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiMenuHubWidget.isCombatWidgetEnabled();
            }
        );

        // Modular Custom Widgets (Managed by ApiMenuHubWidget)
        var widgets = ApiMenuHubWidget.getWidgets();
        for (wDef in widgets) {
            addItemRow(
                "HUD: " + wDef.title,
                "Custom widget with " + wDef.items.length + " configured tools. Toggle visibility on screen.",
                "toggle",
                "",
                false,
                function():Void {
                    var next = !wDef.enabled;
                    ApiMenuHubWidget.setWidgetEnabled(wDef.id, next);
                    ApiNotificationManager.notify("Widget '" + wDef.title + "': " + (next ? "Visible" : "Hidden"));
                },
                function():Bool {
                    return wDef.enabled;
                }
            );

            addItemRow(
                "Configure " + wDef.title,
                "Customize tools, fixed/pinned buttons, and title for '" + wDef.title + "'.",
                "button",
                "Configure",
                false,
                function():Void {
                    ApiMenuHubWidget.openEditor(wDef);
                }
            );
        }

        // Add [+ Create New Custom Widget] button! (Widget Creation System)
        addItemRow(
            "+ Create New Custom Widget",
            "Creates a new custom floating widget with your choice of misc tools.",
            "button",
            "Create",
            false,
            function():Void {
                ApiMenuHubWidget.createNewWidget();
            }
        );

        // Reset Widget Positions
        addItemRow(
            "Reset Widget Positions",
            "Resets Combat & Hunt and all custom widgets back to their default screen positions.",
            "button",
            "Reset",
            false,
            function():Void {
                ApiMenuHubWidget.resetAllWidgets();
            }
        );

        addSectionHeader("Standalone HUD Buttons (Optional)");

        // 1. HUD: Smart Combat Button
        addItemRow(
            "HUD: Smart Combat Button",
            "Places an on-screen toggle button with live ON/OFF indicator to enable/disable Smart Combat directly.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("smart_combat");
                var next = !cur;
                ApiHudManager.setButtonEnabled("smart_combat", next);
                ApiNotificationManager.notify("HUD Smart Combat: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("smart_combat");
            }
        );

        // 2. HUD: Script Runner Button
        addItemRow(
            "HUD: Script Runner Button",
            "Places an on-screen Start/Stop button to quickly control running scripts without opening the menu.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("script_runner");
                var next = !cur;
                ApiHudManager.setButtonEnabled("script_runner", next);
                ApiNotificationManager.notify("HUD Script Runner: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("script_runner");
            }
        );

        addSectionHeader("Gear & Loot");

        // 3. HUD: Smart Enhance Button
        addItemRow(
            "HUD: Smart Enhance Button",
            "Places a 1-tap quick enhancement button on screen to enhance equipped gear for your active class.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("smart_enhance");
                var next = !cur;
                ApiHudManager.setButtonEnabled("smart_enhance", next);
                ApiNotificationManager.notify("HUD Smart Enhance: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("smart_enhance");
            }
        );

        // 4. HUD: Infinite Range Button
        addItemRow(
            "HUD: Infinite Range Button",
            "Places an on-screen toggle button to toggle Infinite Range attack capabilities on the fly.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("infinite_range");
                var next = !cur;
                ApiHudManager.setButtonEnabled("infinite_range", next);
                ApiNotificationManager.notify("HUD Infinite Range: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("infinite_range");
            }
        );

        // 5. HUD: Bank Button
        addItemRow(
            "HUD: Bank Button",
            "Places an on-screen button to open or close your bank storage at any time with a single tap.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("toggle_bank");
                var next = !cur;
                ApiHudManager.setButtonEnabled("toggle_bank", next);
                ApiNotificationManager.notify("HUD Bank: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("toggle_bank");
            }
        );

        // 6. HUD: Accept Loot Button
        addItemRow(
            "HUD: Accept Loot Button",
            "Places an on-screen toggle button to toggle automatic loot drop pickup.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("accept_loot");
                var next = !cur;
                ApiHudManager.setButtonEnabled("accept_loot", next);
                ApiNotificationManager.notify("HUD Accept Loot: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("accept_loot");
            }
        );

        // 7. HUD: Provoke All Button
        addItemRow(
            "HUD: Provoke All Button",
            "Places an on-screen toggle button to provoke and pull all living monsters in the room into combat.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("provoke_all");
                var next = !cur;
                ApiHudManager.setButtonEnabled("provoke_all", next);
                ApiNotificationManager.notify("HUD Provoke All: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("provoke_all");
            }
        );

        // 8. HUD: Lag Killer Button
        addItemRow(
            "HUD: Lag Killer Button",
            "Places an on-screen toggle button to enable/disable Lag Killer mode (high FPS boost) instantly.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiHudManager.isButtonEnabled("lag_killer");
                var next = !cur;
                ApiHudManager.setButtonEnabled("lag_killer", next);
                ApiNotificationManager.notify("HUD Lag Killer: " + (next ? "Visible" : "Hidden"));
            },
            function():Bool {
                return ApiHudManager.isButtonEnabled("lag_killer");
            }
        );

        addSectionHeader("Layout Controls");

        // 7. Reset HUD Button Positions
        addItemRow(
            "Reset HUD Button Positions",
            "Resets all on-screen draggable HUD buttons and the floating Menu button to default layout.",
            "button",
            "Reset",
            false,
            function():Void {
                ApiHudManager.resetAllPositions();
                ApiNotificationManager.notify("HUD button positions reset to defaults!");
            }
        );
    }

    private function renderSettingsTab():Void {
        addSectionHeader("Combat & Movement");

        // 1. Infinite Range
        addItemRow(
            "Infinite Range",
            "Attack and use skills across the entire screen without range limits.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiConfig.getBool("api_infinite_range", false);
                var next = !cur;
                ApiConfig.setBool("api_infinite_range", next);
                if (Api.combat != null) {
                    Api.combat.infiniteRange = next;
                    if (next) Api.combat.applyInfiniteRange();
                }
                ApiNotificationManager.notify("Infinite Range: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.combat != null) ? Api.combat.infiniteRange : ApiConfig.getBool("api_infinite_range", false);
            }
        );

        // 2. Provoke All (Cell Farm)
        addItemRow(
            "Provoke All (Cell Farm)",
            "Aggro and magnetize all living monsters in the room simultaneously for rapid clearing.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = (Api.combat != null && Api.combat.autoProvoke);
                var next = !cur;
                if (Api.combat != null) {
                    Api.combat.provokeAll(next);
                }
                ApiNotificationManager.notify("Provoke All: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.combat != null && Api.combat.autoProvoke);
            }
        );

        // 3. Death Spawn
        addItemRow(
            "Death Spawn (Same Room)",
            "Automatically sets your respawn point to your current room so you never walk back on death.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiConfig.getBool("api_death_spawn", false);
                var next = !cur;
                ApiConfig.setBool("api_death_spawn", next);
                if (Api.map != null) Api.map.autoDeathSpawn = next;
                ApiNotificationManager.notify("Death Spawn: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.map != null) ? Api.map.autoDeathSpawn : ApiConfig.getBool("api_death_spawn", false);
            }
        );

        // 3. Skip Cutscenes
        addItemRow(
            "Skip Cutscenes",
            "Automatically cancel cutscene animations whenever they appear.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiConfig.getBool("api_skip_cutscenes", false) || HelperSetting.getBool("option_disable_cutscenes", false);
                var next = !cur;
                ApiConfig.setBool("api_skip_cutscenes", next);
                HelperSetting.setBool("option_disable_cutscenes", next);
                if (Api.map != null) Api.map.skipCutscenes = next;
                ApiNotificationManager.notify("Skip Cutscenes: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.map != null) ? Api.map.skipCutscenes : (ApiConfig.getBool("api_skip_cutscenes", false) || HelperSetting.getBool("option_disable_cutscenes", false));
            }
        );

        // 4. Private Rooms
        addItemRow(
            "Private Rooms",
            "Automatically join private rooms (e.g. map-100000). Turn off to join public rooms.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiConfig.getBool("api_private_rooms", true);
                var next = !cur;
                ApiConfig.setBool("api_private_rooms", next);
                if (Api.map != null) Api.map.usePrivateRoom = next;
                ApiNotificationManager.notify("Private Rooms: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.map != null) ? Api.map.usePrivateRoom : ApiConfig.getBool("api_private_rooms", true);
            }
        );

        addSectionHeader("Loot & Inventory");

        // 5. Accept All Loot
        addItemRow(
            "Accept All Loot",
            "Automatically accept and pick up all dropped items.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiConfig.getBool("api_accept_loot", false);
                var next = !cur;
                ApiConfig.setBool("api_accept_loot", next);
                if (Api.drop != null) {
                    Api.drop.acceptAll = next;
                    if (next) {
                        Api.drop.scanScreenDrops();
                        Api.drop.acceptAllDrops();
                    }
                }
                ApiNotificationManager.notify("Accept All Loot: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.drop != null) ? Api.drop.acceptAll : ApiConfig.getBool("api_accept_loot", false);
            }
        );

        // 6. Accept AC Drops
        addItemRow(
            "Accept AC Drops",
            "Automatically accept all AC-tagged (free storage) items.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = ApiConfig.getBool("api_accept_ac_drops", false);
                var next = !cur;
                ApiConfig.setBool("api_accept_ac_drops", next);
                if (Api.drop != null) {
                    Api.drop.acceptACs = next;
                    if (next) {
                        Api.drop.scanScreenDrops();
                        Api.drop.acceptACDrops();
                    }
                }
                ApiNotificationManager.notify("Accept AC Drops: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.drop != null) ? Api.drop.acceptACs : ApiConfig.getBool("api_accept_ac_drops", false);
            }
        );

        // 7. Manage Blacklist
        addItemRow(
            "Manage Blacklist",
            "Add or remove items from the blacklist. Blacklisted items are never looted and can be mass-sold.",
            "button",
            "Manage",
            false,
            function():Void {
                ApiPrompts.showBlacklistPrompt(_overlay);
            }
        );

        // 8. Sell Blacklisted Items
        addItemRow(
            "Sell Blacklisted Items",
            "Sell all unequipped inventory items that are on your blacklist.",
            "button",
            "Sell",
            false,
            function():Void {
                if (Api.blacklist != null) {
                    Api.blacklist.sellBlacklist();
                    ApiNotificationManager.notify("Selling blacklisted items...");
                }
            }
        );

        addSectionHeader("Game Utilities");

        // 9. Toggle Bank
        addItemRow(
            "Open / Close Bank",
            "Open or close your bank storage from anywhere without needing a bank pet.",
            "button",
            "Toggle Bank",
            false,
            function():Void {
                if (Api.inventory != null) Api.inventory.toggleBank();
            }
        );

        // 10. Load Shop by ID
        addItemRow(
            "Load Shop by ID",
            "Load any game shop directly by entering its numeric Shop ID.",
            "button",
            "Load Shop",
            false,
            function():Void {
                ApiPrompts.showShopPrompt(_overlay);
            }
        );

        addSectionHeader("Graphics & Lag Killer");

        // 11. Master Lag Killer
        addItemRow(
            "Lag Killer (FPS Boost)",
            "Master performance switch. Disables other player avatars, skill FX particles, and freezes monster loops while preserving 60 FPS combat.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = (Api.visual != null) ? Api.visual.lagKiller : false;
                var next = !cur;
                if (Api.visual != null) Api.visual.lagKiller = next;
                ApiNotificationManager.notify("Lag Killer: " + (next ? "Enabled (High FPS)" : "Disabled"));
            },
            function():Bool {
                return (Api.visual != null) ? Api.visual.lagKiller : false;
            }
        );

        // 12. Hide Other Players
        addItemRow(
            "Hide Other Players",
            "Hides character models of other players in the room to eliminate vector rasterization lag in crowded fights.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = (Api.visual != null) ? Api.visual.hidePlayers : false;
                var next = !cur;
                if (Api.visual != null) Api.visual.hidePlayers = next;
                ApiNotificationManager.notify("Hide Players: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.visual != null) ? Api.visual.hidePlayers : false;
            }
        );

        // 13. Disable Skill FX
        addItemRow(
            "Disable Skill FX",
            "Disables all skill spell effects and projectile particles, clearing the special effects queue.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = (Api.visual != null) ? Api.visual.disableSkillAnims : false;
                var next = !cur;
                if (Api.visual != null) Api.visual.disableSkillAnims = next;
                ApiNotificationManager.notify("Skill FX: " + (next ? "Disabled" : "Enabled"));
            },
            function():Bool {
                return (Api.visual != null) ? Api.visual.disableSkillAnims : false;
            }
        );

        // 14. Freeze Monster Animations
        addItemRow(
            "Freeze Monster Animations",
            "Halts animation frame loops on monsters without affecting hitboxes or combat targeting.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = (Api.visual != null) ? Api.visual.disableMonsterAnims : false;
                var next = !cur;
                if (Api.visual != null) Api.visual.disableMonsterAnims = next;
                ApiNotificationManager.notify("Freeze Monster Anims: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.visual != null) ? Api.visual.disableMonsterAnims : false;
            }
        );

        // 15. Clean Arena (Hide Map Art)
        addItemRow(
            "Clean Arena (Hide Map)",
            "Hides static background map artwork to maximize rendering speed in crowded rooms.",
            "toggle",
            "",
            false,
            function():Void {
                var cur = (Api.visual != null) ? Api.visual.cleanArena : false;
                var next = !cur;
                if (Api.visual != null) Api.visual.cleanArena = next;
                ApiNotificationManager.notify("Clean Arena: " + (next ? "Enabled" : "Disabled"));
            },
            function():Bool {
                return (Api.visual != null) ? Api.visual.cleanArena : false;
            }
        );

        // 16. Show Names When Hidden
        addItemRow(
            "Show Names When Hidden",
            "Keep username labels visible above players even when player character models are hidden.",
            "toggle",
            "",
            false,
            function():Void {
                if (Api.visual != null) {
                    Api.visual.showNames = !Api.visual.showNames;
                    Api.visual.apply();
                    ApiNotificationManager.notify("Player Names: " + (Api.visual.showNames ? "Visible" : "Hidden"));
                }
            },
            function():Bool {
                return (Api.visual != null) ? Api.visual.showNames : true;
            }
        );
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
