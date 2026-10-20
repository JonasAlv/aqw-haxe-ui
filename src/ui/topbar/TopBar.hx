package ui.topbar;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.geom.Point;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiConfig;
import ui.ApiDashboardModal;
import ui.ApiMenus;
import ui.ApiNotificationManager;
import ui.ApiStyle;

/**
 * TopBar: Sleek Skua-style control bar.
 *
 * Enhancements:
 * - Default position: Top Center (x = (stageW - barWidth) / 2, y = SCREEN_MARGIN).
 * - Draggable by holding anywhere on the bar (no clunky grab handle).
 * - Stackable Vertical Layout: Can be toggled between Horizontal and Vertical Stack
 *   with left accent markers matching user theme.
 * - Configurable Buttons: Toggle visibility of Auto, Jump, Players, Menu, Bank, Drops.
 * - Adaptive Dropdown Direction: Dropdowns automatically open UP when in the lower half of screen
 *   or lacking room below, and DOWN when in the top half. Dropdowns NEVER cover or move the button!
 * - Perfectly attached: uses true visual panel heights (e.g. _playersPanel.getPanelHeight()).
 * - 100% pure ASCII strings and Flash vector graphics.
 */
class TopBar extends Sprite {
    public static var instance:TopBar = null;

    private var _stage:Stage;
    private var _host:Dynamic;

    // Bar container & background
    private var _barContainer:Sprite;
    private var _barBg:Shape;
    private var _barWidth:Float = 248.0;
    private var _barHeight:Float = 26.0;

    // Tabs map: tabId -> Sprite
    private var _tabs:Map<String, Sprite> = new Map();
    private var _tabAuto:Sprite;
    private var _txtAuto:TextField;
    private var _dotAuto:Shape;

    private var _tabJump:Sprite;
    private var _txtJump:TextField;

    private var _tabPlayers:Sprite;
    private var _txtPlayers:TextField;

    private var _tabMenu:Sprite;
    private var _txtMenu:TextField;

    private var _tabBank:Sprite;
    private var _txtBank:TextField;

    private var _tabDrops:Sprite;
    private var _txtDrops:TextField;

    // Dropdown Panels (attached to stage for pure coordinate stability)
    private var _dropdownContainer:Sprite;
    private var _autoPanel:TopBarAutoPanel;
    private var _jumpPanel:TopBarJumpPanel;
    private var _playersPanel:TopBarPlayersPanel;

    // State
    private var _activeTab:String = null;
    private var _lastPlayerCount:Int = -1;
    private var _lastCombatActive:Bool = false;

    // Dragging State
    private var _isDragging:Bool = false;
    private var _hasDragged:Bool = false;
    private var _dragMouseStartX:Float = 0;
    private var _dragMouseStartY:Float = 0;
    private var _dragBarStartX:Float = 0;
    private var _dragBarStartY:Float = 0;

    public function new(stageObj:Stage, hostObj:Dynamic = null) {
        super();
        _stage = stageObj;
        _host = hostObj;
        instance = this;

        this.name = "ApiTopBar";
        _barContainer = new Sprite();
        addChild(_barContainer);

        buildDropdowns();
        buildBar();
        setupEvents();
        updatePosition();
    }

    public function isHunting():Bool {
        return (_autoPanel != null && _autoPanel.isHunting());
    }

    // --- Configuration Accessors ---

    public static function isTopBarEnabled():Bool {
        return ApiConfig.getBool("api_topbar_enabled", true);
    }

    public static function setTopBarEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_topbar_enabled", enabled);
        if (instance != null) {
            if (!enabled) {
                instance.closeDropdown();
            }
        }
        StandaloneButtons.updateVisibility();
    }

    public static function isVertical():Bool {
        return ApiConfig.getString("api_topbar_orientation", "horizontal") == "vertical";
    }

    public static function setVertical(val:Bool):Void {
        ApiConfig.setString("api_topbar_orientation", val ? "vertical" : "horizontal");
        if (instance != null) {
            instance.rebuild();
        }
    }

    public static function isLocked():Bool {
        return ApiConfig.getBool("api_topbar_locked", false);
    }

    public static function setLocked(val:Bool):Void {
        ApiConfig.setBool("api_topbar_locked", val);
    }

    public static function isButtonVisible(id:String, defaultVal:Bool = true):Bool {
        return ApiConfig.getBool("api_topbar_btn_" + id, defaultVal);
    }

    public static function setButtonVisible(id:String, visible:Bool):Void {
        ApiConfig.setBool("api_topbar_btn_" + id, visible);
        if (instance != null) {
            instance.rebuild();
        }
    }

    public static function resetPosition():Void {
        ApiConfig.delete("api_topbar_x");
        ApiConfig.delete("api_topbar_y");
        if (instance != null) {
            instance.updatePosition(true);
        }
    }

    public static function rebuildBar():Void {
        if (instance != null) {
            instance.rebuild();
        }
    }

    public static function toggleAuto(?anchorX:Float, ?anchorY:Float, ?anchorW:Float, ?anchorH:Float):Void {
        if (instance != null) {
            if (instance._activeTab == "auto") instance.closeDropdown();
            else instance.openTab("auto", anchorX, anchorY, anchorW, anchorH);
        }
    }

    public static function toggleJump(?anchorX:Float, ?anchorY:Float, ?anchorW:Float, ?anchorH:Float):Void {
        if (instance != null) {
            if (instance._activeTab == "jump") instance.closeDropdown();
            else instance.openTab("jump", anchorX, anchorY, anchorW, anchorH);
        }
    }

    public static function togglePlayers(?anchorX:Float, ?anchorY:Float, ?anchorW:Float, ?anchorH:Float):Void {
        if (instance != null) {
            if (instance._activeTab == "players") instance.closeDropdown();
            else instance.openTab("players", anchorX, anchorY, anchorW, anchorH);
        }
    }

    public static function init(stageObj:Dynamic, hostObj:Dynamic = null):Void {
        if (instance != null) return;
        var theStage:Stage = null;
        if (Std.isOfType(stageObj, Stage)) {
            theStage = cast stageObj;
        } else if (stageObj != null && stageObj.stage != null) {
            theStage = cast stageObj.stage;
        } else {
            theStage = flash.Lib.current.stage;
        }
        if (theStage != null) {
            new TopBar(theStage, hostObj);
        }
    }

    // --- Bar Construction & Layout ---

    public function rebuild():Void {
        var prevTab = _activeTab;
        closeDropdown();

        // Clear container
        while (_barContainer.numChildren > 0) {
            _barContainer.removeChildAt(0);
        }
        _tabs = new Map();

        buildBar();
        updatePosition();

        if (prevTab != null) {
            openTab(prevTab);
        }
    }

    private function buildBar():Void {
        _barBg = new Shape();
        _barContainer.addChild(_barBg);

        var vert:Bool = isVertical();

        // Drag listener on bar container background: holding on the bar moves it!
        _barContainer.addEventListener(MouseEvent.MOUSE_DOWN, onDragStart);

        // Buttons List Definition
        var buttonDefs = [
            { id: "auto",    label: "Auto",    accent: 0x2ECC71, defVis: true,  hWidth: 46.0 },
            { id: "jump",    label: "Jump",    accent: 0x38BDF8, defVis: true,  hWidth: 38.0 },
            { id: "players", label: "Players", accent: 0xC084FC, defVis: true,  hWidth: 76.0 },
            { id: "menu",    label: "Menu",    accent: 0xEF4444, defVis: true,  hWidth: 42.0 },
            { id: "bank",    label: "Bank",    accent: 0xF59E0B, defVis: false, hWidth: 40.0 },
            { id: "drops",   label: "Drops",   accent: 0x14B8A6, defVis: false, hWidth: 44.0 }
        ];

        var curX:Float = 4.0;
        var curY:Float = 4.0;
        var tabH:Float = vert ? 22.0 : 20.0;
        var tabW:Float = vert ? 76.0 : 40.0;

        for (bDef in buttonDefs) {
            if (!isButtonVisible(bDef.id, bDef.defVis)) continue;

            var thisW:Float = vert ? tabW : bDef.hWidth;
            var tabBtn:Sprite = createTabButton(bDef.id, bDef.label, thisW, tabH, bDef.accent, vert);

            if (vert) {
                tabBtn.x = 4.0;
                tabBtn.y = curY;
                curY += tabH + 3.0;
            } else {
                tabBtn.x = curX;
                tabBtn.y = 3.0;
                curX += thisW + 3.0;
            }

            _tabs.set(bDef.id, tabBtn);
            _barContainer.addChild(tabBtn);

            // Hook up specific references
            if (bDef.id == "auto") {
                _tabAuto = tabBtn;
                _txtAuto = cast tabBtn.getChildByName("label");
                _dotAuto = cast tabBtn.getChildByName("dot");
                renderAutoDot(_lastCombatActive);
            } else if (bDef.id == "jump") {
                _tabJump = tabBtn;
                _txtJump = cast tabBtn.getChildByName("label");
            } else if (bDef.id == "players") {
                _tabPlayers = tabBtn;
                _txtPlayers = cast tabBtn.getChildByName("label");
                if (_lastPlayerCount >= 0) {
                    _txtPlayers.text = "Players (" + _lastPlayerCount + ")";
                }
            } else if (bDef.id == "menu") {
                _tabMenu = tabBtn;
                _txtMenu = cast tabBtn.getChildByName("label");
            } else if (bDef.id == "bank") {
                _tabBank = tabBtn;
                _txtBank = cast tabBtn.getChildByName("label");
            } else if (bDef.id == "drops") {
                _tabDrops = tabBtn;
                _txtDrops = cast tabBtn.getChildByName("label");
            }
        }

        if (vert) {
            _barWidth = 84.0;
            _barHeight = Math.max(26.0, curY + 2.0);
        } else {
            _barWidth = Math.max(48.0, curX + 1.0);
            _barHeight = 26.0;
        }

        // Draw bar background & top bevel highlight
        var g = _barBg.graphics;
        g.clear();
        g.beginFill(ApiStyle.COLOR_BG_WIDGET, 0.94);
        g.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.9);
        g.drawRoundRect(0, 0, _barWidth, _barHeight, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
        g.endFill();

        g.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
        g.moveTo(3, 1);
        g.lineTo(_barWidth - 3, 1);
    }

    private function createTabButton(id:String, labelText:String, w:Float, h:Float, accentColor:Int, isVert:Bool):Sprite {
        var tab = new Sprite();
        tab.name = "tab_" + id;
        tab.buttonMode = true;
        tab.useHandCursor = true;

        var lbl = new TextField();
        lbl.name = "label";
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 10, ApiStyle.COLOR_TEXT_PRIMARY, true);
        fmt.align = isVert ? TextFormatAlign.LEFT : TextFormatAlign.CENTER;
        lbl.defaultTextFormat = fmt;
        lbl.selectable = false;
        lbl.mouseEnabled = false;

        if (isVert) {
            lbl.x = 12.0;
            lbl.y = 3.0;
            lbl.width = w - 16.0;
            lbl.height = 16.0;
        } else {
            if (id == "auto") {
                lbl.x = 10.0;
                lbl.width = w - 12.0;
            } else if (id == "menu") {
                lbl.x = 7.0;
                lbl.width = w - 9.0;
            } else {
                lbl.x = 0.0;
                lbl.width = w;
            }
            lbl.y = 2.0;
            lbl.height = 16.0;
        }
        lbl.text = labelText;
        tab.addChild(lbl);

        // Auto Live LED Dot
        if (id == "auto") {
            var dot = new Shape();
            dot.name = "dot";
            tab.addChild(dot);
        }

        renderTabStyle(tab, w, h, false, false, accentColor, isVert);

        tab.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            var isCurrentActive = (_activeTab != null && _activeTab == id);
            renderTabStyle(tab, w, h, true, isCurrentActive, accentColor, isVert);
        });
        tab.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            var isCurrentActive = (_activeTab != null && _activeTab == id);
            renderTabStyle(tab, w, h, false, isCurrentActive, accentColor, isVert);
        });

        // Tab click vs drag handling:
        var downX:Float = 0;
        var downY:Float = 0;
        tab.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            downX = e.stageX;
            downY = e.stageY;
        });

        tab.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            e.stopPropagation();
            if (_hasDragged) return;
            var dx = e.stageX - downX;
            var dy = e.stageY - downY;
            if (dx * dx + dy * dy > 16.0) return; // Ignore if dragged
            onTabClicked(id);
        });

        return tab;
    }

    private function onTabClicked(id:String):Void {
        if (id == "auto" || id == "jump" || id == "players") {
            toggleTab(id);
        } else if (id == "menu") {
            closeDropdown();
            toggleDashboard();
        } else if (id == "bank") {
            closeDropdown();
            toggleBank();
        } else if (id == "drops") {
            closeDropdown();
            toggleDrops();
        }
    }

    private function toggleBank():Void {
        try {
            if (Api.inventory != null) {
                Api.inventory.toggleBank();
            } else if (Api.game != null && Api.game.world != null) {
                Api.game.world.toggleBank();
            }
        } catch (_:Dynamic) {}
    }

    private function toggleDrops():Void {
        try {
            if (Api.drop != null) {
                Api.drop.scanScreenDrops();
                Api.drop.acceptAllDrops();
                ApiNotificationManager.notify("Drops collected!");
            } else if (Api.game != null && Api.game.ui != null && Api.game.ui.mcPortrait != null && Api.game.ui.mcPortrait.iconDrops != null) {
                Api.game.ui.mcPortrait.iconDrops.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
            }
        } catch (_:Dynamic) {}
    }

    private function renderTabStyle(tab:Sprite, w:Float, h:Float, hover:Bool, active:Bool, accentColor:Int, isVert:Bool):Void {
        var g = tab.graphics;
        g.clear();

        var bgCol = active ? ApiStyle.COLOR_BG_CARD : (hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE);
        var border = active ? ApiStyle.COLOR_STATUS_ACTIVE : (hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT);
        var alphaVal = active ? 0.98 : (hover ? 0.95 : 0.80);

        g.beginFill(bgCol, alphaVal);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, w, h, 3, 3);
        g.endFill();

        // Accent striping
        if (isVert) {
            // Sleek left accent stripe in vertical stack mode
            g.lineStyle(0, 0, 0);
            g.beginFill(accentColor, active ? 1.0 : (hover ? 0.95 : 0.80));
            g.drawRoundRect(3.5, 3.0, 3.0, h - 6.0, 1.5, 1.5);
            g.endFill();
        } else if (tab.name == "tab_menu") {
            // Horizontal menu accent strip
            g.lineStyle(0, 0, 0);
            g.beginFill(accentColor, 1.0);
            g.drawRoundRect(3.5, 3.0, 2.5, 14.0, 1.0, 1.0);
            g.endFill();
        }

        var lbl:TextField = cast tab.getChildByName("label");
        if (lbl != null) {
            lbl.textColor = active ? ApiStyle.COLOR_STATUS_ACTIVE : (hover ? ApiStyle.COLOR_TEXT_TITLE : ApiStyle.COLOR_TEXT_PRIMARY);
        }
    }

    private function renderAutoDot(running:Bool):Void {
        if (_dotAuto == null) return;
        var g = _dotAuto.graphics;
        g.clear();
        var dotColor = running ? 0x2ECC71 : 0x717789;
        g.beginFill(dotColor, running ? 1.0 : 0.6);

        var isVert = isVertical();
        if (isVert) {
            g.drawCircle(66.0, 11.0, 2.5);
        } else {
            g.drawCircle(5.5, 10.0, 2.2);
        }
        g.endFill();
    }

    private function updateAllTabStyles():Void {
        var isVert = isVertical();
        var accents = [
            "auto" => 0x2ECC71,
            "jump" => 0x38BDF8,
            "players" => 0xC084FC,
            "menu" => 0xEF4444,
            "bank" => 0xF59E0B,
            "drops" => 0x14B8A6
        ];
        var tabH:Float = isVert ? 22.0 : 20.0;
        var tabW:Float = isVert ? 76.0 : 40.0;

        for (id in _tabs.keys()) {
            var tab = _tabs.get(id);
            if (tab == null) continue;
            var thisW:Float = isVert ? tabW : tab.width;
            var accent = accents.exists(id) ? accents.get(id) : 0x8B5CF6;
            renderTabStyle(tab, thisW, tabH, false, (_activeTab == id), accent, isVert);
        }
    }

    // --- Dropdowns Construction & Adaptive Direction Algorithm ---

    private function buildDropdowns():Void {
        _dropdownContainer = new Sprite();
        _dropdownContainer.visible = false;

        _autoPanel = new TopBarAutoPanel();
        _autoPanel.visible = false;
        _dropdownContainer.addChild(_autoPanel);

        _jumpPanel = new TopBarJumpPanel();
        _jumpPanel.visible = false;
        _dropdownContainer.addChild(_jumpPanel);

        _playersPanel = new TopBarPlayersPanel();
        _playersPanel.visible = false;
        _dropdownContainer.addChild(_playersPanel);
    }

    public function toggleTab(tabId:String):Void {
        if (_activeTab == tabId) {
            closeDropdown();
        } else {
            openTab(tabId);
        }
    }

    private function getActivePanelVisualHeight(tabId:String):Float {
        if (tabId == "auto") return TopBarAutoPanel.PANEL_HEIGHT;
        if (tabId == "jump") return TopBarJumpPanel.PANEL_HEIGHT;
        if (tabId == "players" && _playersPanel != null) return _playersPanel.getPanelHeight();
        return 120.0;
    }

    /**
     * Adaptive Dropdown Placement:
     * - Uses true visual panel height (_playersPanel.getPanelHeight(), not bloated Flash sprite bounds).
     * - Opens UP when in bottom half or lacking room below, DOWN when in top half.
     * - NEVER covers or shifts the button.
     * - Placed directly on stage so TopBar bounds are never affected.
     */
    public function openTab(tabId:String, ?anchorX:Float, ?anchorY:Float, ?anchorW:Float, ?anchorH:Float):Void {
        _activeTab = tabId;

        _autoPanel.visible = false;
        _jumpPanel.visible = false;
        _playersPanel.visible = false;

        updateAllTabStyles();

        var activePanel:Sprite = null;
        if (tabId == "auto") {
            _autoPanel.visible = true;
            activePanel = _autoPanel;
        } else if (tabId == "jump") {
            _jumpPanel.visible = true;
            _jumpPanel.refreshRoomList();
            _jumpPanel.refreshPadList();
            activePanel = _jumpPanel;
        } else if (tabId == "players") {
            _playersPanel.visible = true;
            _playersPanel.refreshPlayers();
            activePanel = _playersPanel;
        }

        if (activePanel != null && _stage != null) {
            if (_dropdownContainer.parent != _stage) {
                _stage.addChild(_dropdownContainer);
            }
            _dropdownContainer.visible = true;

            var sw:Float = (_stage.stageWidth > 0) ? _stage.stageWidth : 960.0;
            var sh:Float = (_stage.stageHeight > 0) ? _stage.stageHeight : 550.0;
            var margin:Float = ApiStyle.SCREEN_MARGIN;

            var btnX:Float;
            var btnY:Float;
            var btnW:Float;
            var btnH:Float;

            if (anchorX != null && anchorY != null) {
                btnX = anchorX;
                btnY = anchorY;
                btnW = (anchorW != null && anchorW > 0) ? anchorW : 78.0;
                btnH = (anchorH != null && anchorH > 0) ? anchorH : 26.0;
            } else {
                var tabSprite = _tabs.get(tabId);
                if (tabSprite != null) {
                    var pt = tabSprite.localToGlobal(new Point(0, 0));
                    btnX = pt.x;
                    btnY = pt.y;
                    btnW = tabSprite.width;
                    btnH = tabSprite.height;
                } else {
                    btnX = this.x;
                    btnY = this.y;
                    btnW = _barWidth;
                    btnH = _barHeight;
                }
            }

            var panelW:Float = TopBarAutoPanel.PANEL_WIDTH; // 220.0
            var panelH:Float = getActivePanelVisualHeight(tabId); // Exact visual height

            var isVert:Bool = isVertical();

            // Check if opening from vertical stack
            if (isVert && (anchorX == null || Math.abs(anchorX - (this.x + 4.0)) < 2.0)) {
                // In vertical stack mode: try placing beside the stack
                var gap:Float = 4.0;
                var spaceRight:Float = sw - margin - (this.x + _barWidth);
                var spaceLeft:Float = this.x - margin;

                var targetStageX:Float;
                var targetStageY:Float = Math.max(margin, Math.min(sh - panelH - margin, btnY));

                if (spaceRight >= panelW + gap) {
                    targetStageX = this.x + _barWidth + gap;
                } else if (spaceLeft >= panelW + gap) {
                    targetStageX = this.x - panelW - gap;
                } else {
                    // Fallback to vertical up/down if screen is ultra narrow
                    var spaceAbove:Float = btnY - margin;
                    var spaceBelow:Float = sh - margin - (btnY + btnH);
                    var openUp:Bool = (spaceBelow < panelH + 4.0) || (spaceAbove >= spaceBelow);
                    if (openUp) {
                        targetStageY = Math.max(margin, Math.min(btnY - panelH - 1.0, btnY - panelH - gap));
                    } else {
                        targetStageY = Math.max(btnY + btnH + 1.0, Math.min(sh - panelH - margin, btnY + btnH + gap));
                    }
                    targetStageX = Math.max(margin, Math.min(sw - panelW - margin, btnX));
                }

                _dropdownContainer.x = targetStageX;
                _dropdownContainer.y = targetStageY;
            } else {
                // Horizontal bar or Standalone button: strictly UP or DOWN outside button bounds
                var spaceAbove:Float = btnY - margin;
                var spaceBelow:Float = sh - margin - (btnY + btnH);

                var pastMid:Bool = (btnY + btnH * 0.5) > (sh * 0.5);
                var fitsAbove:Bool = spaceAbove >= (panelH + 4.0);
                var fitsBelow:Bool = spaceBelow >= (panelH + 4.0);

                var openUp:Bool = false;
                if (pastMid) {
                    openUp = fitsAbove || (spaceAbove >= spaceBelow);
                } else {
                    openUp = !fitsBelow && (spaceAbove > spaceBelow);
                }

                var gap:Float = 3.0;
                var targetStageY:Float;

                if (openUp) {
                    // Strictly ABOVE: bottom of panel is at btnY - gap
                    targetStageY = btnY - panelH - gap;
                    var maxAllowedY:Float = btnY - panelH - 1.0;
                    targetStageY = Math.max(margin, Math.min(maxAllowedY, targetStageY));
                } else {
                    // Strictly BELOW: top of panel is at btnY + btnH + gap
                    targetStageY = btnY + btnH + gap;
                    var minAllowedY:Float = btnY + btnH + 1.0;
                    targetStageY = Math.max(minAllowedY, Math.min(sh - panelH - margin, targetStageY));
                }

                var targetStageX:Float = btnX;
                if (targetStageX + panelW > sw - margin) {
                    targetStageX = (btnX + btnW) - panelW;
                }
                targetStageX = Math.max(margin, Math.min(sw - panelW - margin, targetStageX));

                _dropdownContainer.x = targetStageX;
                _dropdownContainer.y = targetStageY;
            }

            _stage.setChildIndex(_dropdownContainer, _stage.numChildren - 1);
        }

        // Raise TopBar to top display layer
        if (_stage != null && this.parent == _stage) {
            _stage.setChildIndex(this, _stage.numChildren - 1);
        }
    }

    public function closeDropdown():Void {
        _activeTab = null;
        if (_autoPanel != null) _autoPanel.visible = false;
        if (_jumpPanel != null) _jumpPanel.visible = false;
        if (_playersPanel != null) _playersPanel.visible = false;
        if (_dropdownContainer != null) _dropdownContainer.visible = false;

        updateAllTabStyles();
    }

    // --- Dragging & Repositioning ---

    private function onDragStart(e:MouseEvent):Void {
        if (isLocked()) return;
        if (_stage == null) return;

        _isDragging = false;
        _hasDragged = false;
        _dragMouseStartX = e.stageX;
        _dragMouseStartY = e.stageY;
        _dragBarStartX = this.x;
        _dragBarStartY = this.y;

        _stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageDragMove);
        _stage.addEventListener(MouseEvent.MOUSE_UP, onStageDragUp);
    }

    private function onStageDragMove(e:MouseEvent):Void {
        if (_stage == null) return;

        var dx = e.stageX - _dragMouseStartX;
        var dy = e.stageY - _dragMouseStartY;

        if (!_isDragging) {
            if (dx * dx + dy * dy < 16.0) return; // 4px deadzone threshold
            _isDragging = true;
            _hasDragged = true;
            closeDropdown();
        }

        var sw = (_stage.stageWidth > 0) ? _stage.stageWidth : 960.0;
        var sh = (_stage.stageHeight > 0) ? _stage.stageHeight : 550.0;
        var margin = ApiStyle.SCREEN_MARGIN;

        var nx = _dragBarStartX + dx;
        var ny = _dragBarStartY + dy;
        nx = Math.max(margin, Math.min(sw - _barWidth - margin, nx));
        ny = Math.max(margin, Math.min(sh - _barHeight - margin, ny));

        this.x = nx;
        this.y = ny;
    }

    private function onStageDragUp(e:MouseEvent):Void {
        if (_stage != null) {
            _stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageDragMove);
            _stage.removeEventListener(MouseEvent.MOUSE_UP, onStageDragUp);
        }

        if (_isDragging) {
            _isDragging = false;
            ApiConfig.setInt("api_topbar_x", Math.round(this.x));
            ApiConfig.setInt("api_topbar_y", Math.round(this.y));
            haxe.Timer.delay(function() {
                _hasDragged = false;
            }, 100);
        } else {
            _hasDragged = false;
        }
    }

    public function updatePosition(forceCenter:Bool = false):Void {
        if (_stage == null) return;
        var sw:Float = (_stage.stageWidth > 0) ? _stage.stageWidth : 960.0;
        var sh:Float = (_stage.stageHeight > 0) ? _stage.stageHeight : 550.0;
        var margin:Float = ApiStyle.SCREEN_MARGIN;

        if (!forceCenter && ApiConfig.has("api_topbar_x") && ApiConfig.has("api_topbar_y")) {
            var px:Float = ApiConfig.getInt("api_topbar_x");
            var py:Float = ApiConfig.getInt("api_topbar_y");
            this.x = Math.max(margin, Math.min(sw - _barWidth - margin, px));
            this.y = Math.max(margin, Math.min(sh - _barHeight - margin, py));
        } else {
            // DEFAULT POSITION: STRICTLY TOP CENTER
            this.x = Math.round((sw - _barWidth) / 2.0);
            this.y = margin;
        }
    }

    // --- Events & Tick Loop ---

    private function setupEvents():Void {
        if (_stage == null) return;

        _stage.addChild(this);

        // Keep anchored / clamped on stage resize
        _stage.addEventListener(Event.RESIZE, function(e:Event):Void {
            if (!_isDragging) updatePosition();
        });

        // Stage click outside dismissal
        _stage.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            if (_activeTab == null) return;
            var targetObj:Dynamic = e.target;
            if (targetObj != null && Std.isOfType(targetObj, flash.display.DisplayObject)) {
                var disp:flash.display.DisplayObject = cast targetObj;
                if (this.contains(disp)) {
                    return; // Inside TopBar
                }
                if (_dropdownContainer != null && _dropdownContainer.contains(disp)) {
                    return; // Inside open dropdown panel
                }
                if (StandaloneButtons.isStandaloneButton(disp)) {
                    return; // On a standalone button
                }
            }
            closeDropdown();
        });

        // Forward stage mouse movement to players scroll list
        _stage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (_playersPanel != null && _playersPanel.visible) {
                _playersPanel.handleStageMouseMove(e);
            }
        });
        _stage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            if (_playersPanel != null && _playersPanel.visible) {
                _playersPanel.handleStageMouseUp(e);
            }
        });

        // ESC key closes active dropdown
        _stage.addEventListener(KeyboardEvent.KEY_DOWN, function(e:KeyboardEvent):Void {
            if (e.keyCode == 27 && _activeTab != null) {
                closeDropdown();
            }
        });

        // Frame tick
        _stage.addEventListener(Event.ENTER_FRAME, function(e:Event):Void onTick());
    }

    private function toggleDashboard():Void {
        if (ApiDashboardModal.isOpen()) {
            ApiDashboardModal.close();
        } else {
            ApiDashboardModal.show(_stage, _host);
        }
    }

    private function isBlockedByHostPanel():Bool {
        try {
            if (_host != null && Reflect.hasField(_host, "currentFrameLabel") && Reflect.field(_host, "currentFrameLabel") == "Panel") {
                return true;
            }
        } catch (_:Dynamic) {}
        return false;
    }

    public function onTick():Void {
        // 1. In-game visibility check
        var inGame = ApiMenus.isInGame();
        if (!inGame) {
            this.visible = false;
            closeDropdown();
            return;
        }
        this.visible = true;

        var isBlocked = ApiDashboardModal.isOpen() || isBlockedByHostPanel();
        var topBarActive = isTopBarEnabled() && !isBlocked;
        if (_barContainer != null) _barContainer.visible = topBarActive;

        // 2. Live Auto Combat dot indicator
        var isCombatRunning = (Api.combat != null && Api.combat.isRunning()) || isHunting();
        if (isCombatRunning != _lastCombatActive) {
            _lastCombatActive = isCombatRunning;
            renderAutoDot(isCombatRunning);
        }

        // 3. Live Area Player Count update on tab
        var players = TopBarPlayersPanel.getMapPlayers();
        var count = players.length;
        if (count != _lastPlayerCount) {
            _lastPlayerCount = count;
            if (_txtPlayers != null) {
                _txtPlayers.text = "Players (" + count + ")";
            }
        }

        // 4. Tick active dropdown panel
        if (_activeTab == "auto" && _autoPanel.visible) {
            _autoPanel.onTick();
        } else if (_activeTab == "jump" && _jumpPanel.visible) {
            _jumpPanel.onTick();
        } else if (_activeTab == "players" && _playersPanel.visible) {
            _playersPanel.onTick();
        }

        // 5. Close dropdown if a modal window opens
        if (_activeTab != null && isBlocked) {
            closeDropdown();
        }

        // 6. Ensure default centered anchor if uncustomized
        if (!_isDragging && _stage != null) {
            if (!ApiConfig.has("api_topbar_x")) {
                var sw:Float = (_stage.stageWidth > 0) ? _stage.stageWidth : 960.0;
                var targetCenterX = Math.round((sw - _barWidth) / 2.0);
                if (Math.abs(this.x - targetCenterX) > 1.0) {
                    this.x = targetCenterX;
                    this.y = ApiStyle.SCREEN_MARGIN;
                }
            } else {
                var sw:Float = (_stage.stageWidth > 0) ? _stage.stageWidth : 960.0;
                var sh:Float = (_stage.stageHeight > 0) ? _stage.stageHeight : 550.0;
                var margin = ApiStyle.SCREEN_MARGIN;
                if (this.x > sw - _barWidth - margin) this.x = Math.max(margin, sw - _barWidth - margin);
                if (this.y > sh - _barHeight - margin) this.y = Math.max(margin, sh - _barHeight - margin);
            }
        }
    }
}
#else
class TopBar {
    public static var instance:TopBar = null;
    public static function init(stageObj:Dynamic, hostObj:Dynamic = null):Void {}
    public static function isTopBarEnabled():Bool return false;
    public static function setTopBarEnabled(enabled:Bool):Void {}
    public static function isVertical():Bool return false;
    public static function setVertical(val:Bool):Void {}
    public static function isLocked():Bool return false;
    public static function setLocked(val:Bool):Void {}
    public static function isButtonVisible(id:String, defaultVal:Bool = true):Bool return false;
    public static function setButtonVisible(id:String, visible:Bool):Void {}
    public static function resetPosition():Void {}
    public static function rebuildBar():Void {}
    public static function toggleAuto(?anchorX:Float, ?anchorY:Float, ?anchorW:Float, ?anchorH:Float):Void {}
    public static function toggleJump(?anchorX:Float, ?anchorY:Float, ?anchorW:Float, ?anchorH:Float):Void {}
    public static function togglePlayers(?anchorX:Float, ?anchorY:Float, ?anchorW:Float, ?anchorH:Float):Void {}
    public function isHunting():Bool return false;
}
#end