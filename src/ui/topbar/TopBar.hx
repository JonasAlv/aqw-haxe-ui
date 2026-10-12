package ui.topbar;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiConfig;
import ui.ApiDashboardModal;
import ui.ApiStyle;

/**
 * TopBar: Sleek Skua-style control bar anchored to the top-right of the screen.
 *
 * Provides:
 * - [Auto]    -> Toggles TopBarAutoPanel (combat automation)
 * - [Jump]    -> Toggles TopBarJumpPanel (map/cell navigation)
 * - [Players] -> Toggles TopBarPlayersPanel (area players list)
 * - [Menu]    -> Toggles ApiDashboardModal
 *
 * Features:
 * - Strict mutual exclusion: opening one panel closes any other open panel.
 * - Clicking the active tab or clicking outside on the stage closes the panel.
 * - 100% pure ASCII strings and vector graphics (zero Unicode glyphs).
 */
class TopBar extends Sprite {
    public static var instance:TopBar = null;

    private var _stage:Stage;
    private var _host:Dynamic;

    // Bar dimensions
    private var _barBg:Shape;
    private var _barWidth:Float = 248.0;
    private var _barHeight:Float = 26.0;

    // Tabs
    private var _tabAuto:Sprite;
    private var _txtAuto:TextField;
    private var _dotAuto:Shape;

    private var _tabJump:Sprite;
    private var _txtJump:TextField;

    private var _tabPlayers:Sprite;
    private var _txtPlayers:TextField;

    private var _tabMenu:Sprite;
    private var _txtMenu:TextField;
    private var _accentMenu:Shape;

    // Dropdown Panels
    private var _dropdownContainer:Sprite;
    private var _autoPanel:TopBarAutoPanel;
    private var _jumpPanel:TopBarJumpPanel;
    private var _playersPanel:TopBarPlayersPanel;

    // State
    private var _activeTab:String = null;
    private var _lastPlayerCount:Int = -1;
    private var _lastCombatActive:Bool = false;

    public function new(stageObj:Stage, hostObj:Dynamic = null) {
        super();
        _stage = stageObj;
        _host = hostObj;
        instance = this;

        buildBar();
        buildDropdowns();
        setupEvents();
        updatePosition();
        this.visible = isTopBarEnabled();
    }

    public static function isTopBarEnabled():Bool {
        return ApiConfig.getBool("api_topbar_enabled", true);
    }

    public static function setTopBarEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_topbar_enabled", enabled);
        if (instance != null) instance.visible = enabled;
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

    private function buildBar():Void {
        this.name = "ApiTopBar";

        _barBg = new Shape();
        addChild(_barBg);

        var curX:Float = 4.0;
        var tabH:Float = 20.0;
        var tabY:Float = 3.0;

        // 1. Tab Auto
        var autoW:Float = 46.0;
        _tabAuto = createTabButton(autoW, tabH, "Auto");
        _tabAuto.x = curX;
        _tabAuto.y = tabY;
        _txtAuto = cast _tabAuto.getChildByName("label");
        _txtAuto.x = 10.0;
        _txtAuto.width = autoW - 12.0;

        _dotAuto = new Shape();
        _dotAuto.name = "dot";
        _tabAuto.addChild(_dotAuto);
        renderAutoDot(false);

        _tabAuto.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            e.stopPropagation();
            toggleTab("auto");
        });
        addChild(_tabAuto);
        curX += autoW + 3.0;

        // 2. Tab Jump
        var jumpW:Float = 38.0;
        _tabJump = createTabButton(jumpW, tabH, "Jump");
        _tabJump.x = curX;
        _tabJump.y = tabY;
        _txtJump = cast _tabJump.getChildByName("label");
        _tabJump.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            e.stopPropagation();
            toggleTab("jump");
        });
        addChild(_tabJump);
        curX += jumpW + 3.0;

        // 3. Tab Players
        var playersW:Float = 62.0;
        _tabPlayers = createTabButton(playersW, tabH, "Players");
        _tabPlayers.x = curX;
        _tabPlayers.y = tabY;
        _txtPlayers = cast _tabPlayers.getChildByName("label");
        _tabPlayers.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            e.stopPropagation();
            toggleTab("players");
        });
        addChild(_tabPlayers);
        curX += playersW + 3.0;

        // 4. Tab Menu
        var menuW:Float = 42.0;
        _tabMenu = createTabButton(menuW, tabH, "Menu");
        _tabMenu.x = curX;
        _tabMenu.y = tabY;
        _txtMenu = cast _tabMenu.getChildByName("label");
        _txtMenu.x = 8.0;
        _txtMenu.width = menuW - 10.0;

        _accentMenu = new Shape();
        _accentMenu.graphics.beginFill(ApiStyle.COLOR_ACCENT_CRIMSON, 1.0);
        _accentMenu.graphics.drawRoundRect(4, 3, 2.5, 14, 1, 1);
        _accentMenu.graphics.endFill();
        _tabMenu.addChild(_accentMenu);

        _tabMenu.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            e.stopPropagation();
            closeDropdown();
            toggleDashboard();
        });
        addChild(_tabMenu);
        curX += menuW + 4.0;

        _barWidth = curX;

        // Redraw bar background
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

    private function createTabButton(w:Float, h:Float, labelText:String):Sprite {
        var tab = new Sprite();
        tab.buttonMode = true;
        tab.useHandCursor = true;

        var lbl = new TextField();
        lbl.name = "label";
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 10, ApiStyle.COLOR_TEXT_PRIMARY, true);
        fmt.align = TextFormatAlign.CENTER;
        lbl.defaultTextFormat = fmt;
        lbl.x = 0;
        lbl.y = 2;
        lbl.width = w;
        lbl.height = 16;
        lbl.selectable = false;
        lbl.mouseEnabled = false;
        lbl.text = labelText;
        tab.addChild(lbl);

        renderTabStyle(tab, w, h, false, false);

        tab.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            var isCurrentActive = (_activeTab != null && isTabActive(tab, _activeTab));
            renderTabStyle(tab, w, h, true, isCurrentActive);
        });
        tab.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            var isCurrentActive = (_activeTab != null && isTabActive(tab, _activeTab));
            renderTabStyle(tab, w, h, false, isCurrentActive);
        });

        return tab;
    }

    private function isTabActive(tab:Sprite, tabId:String):Bool {
        if (tabId == "auto" && tab == _tabAuto) return true;
        if (tabId == "jump" && tab == _tabJump) return true;
        if (tabId == "players" && tab == _tabPlayers) return true;
        return false;
    }

    private function renderTabStyle(tab:Sprite, w:Float, h:Float, hover:Bool, active:Bool):Void {
        var g = tab.graphics;
        g.clear();

        var bgCol = active ? ApiStyle.COLOR_BG_CARD : (hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE);
        var border = active ? ApiStyle.COLOR_STATUS_ACTIVE : (hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT);
        var alphaVal = active ? 0.98 : (hover ? 0.95 : 0.80);

        g.beginFill(bgCol, alphaVal);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, w, h, 3, 3);
        g.endFill();

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
        g.drawCircle(5.5, 10, 2.2);
        g.endFill();
    }

    private function buildDropdowns():Void {
        _dropdownContainer = new Sprite();
        _dropdownContainer.y = _barHeight + 2.0;
        addChild(_dropdownContainer);

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

    private function setupEvents():Void {
        if (_stage == null) return;

        _stage.addChild(this);

        // Keep anchored to top right on window resize
        _stage.addEventListener(Event.RESIZE, function(e:Event):Void updatePosition());

        // Stage click outside dismissal
        _stage.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            if (_activeTab == null) return;
            var targetObj:Dynamic = e.target;
            if (targetObj != null && Std.isOfType(targetObj, flash.display.DisplayObject)) {
                var disp:flash.display.DisplayObject = cast targetObj;
                if (this.contains(disp)) {
                    return; // Click was inside TopBar or open dropdown panel
                }
            }
            closeDropdown();
        });

        // Stage mouse move / up forwarded to players scroll list
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

        // Per-frame tick
        _stage.addEventListener(Event.ENTER_FRAME, function(e:Event):Void onTick());
    }

    public function updatePosition():Void {
        if (_stage == null) return;
        var sw:Float = (_stage.stageWidth > 0) ? _stage.stageWidth : 960.0;
        this.x = sw - _barWidth - ApiStyle.SCREEN_MARGIN;
        this.y = ApiStyle.SCREEN_MARGIN;
    }

    public function toggleTab(tabId:String):Void {
        if (_activeTab == tabId) {
            closeDropdown();
        } else {
            openTab(tabId);
        }
    }

    public function openTab(tabId:String):Void {
        _activeTab = tabId;

        _autoPanel.visible = false;
        _jumpPanel.visible = false;
        _playersPanel.visible = false;

        renderTabStyle(_tabAuto, 46.0, 20.0, false, tabId == "auto");
        renderTabStyle(_tabJump, 38.0, 20.0, false, tabId == "jump");
        renderTabStyle(_tabPlayers, 62.0, 20.0, false, tabId == "players");

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

        if (activePanel != null) {
            // Align dropdown right edge with TopBar right edge
            _dropdownContainer.x = _barWidth - activePanel.width;
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

        renderTabStyle(_tabAuto, 46.0, 20.0, false, false);
        renderTabStyle(_tabJump, 38.0, 20.0, false, false);
        renderTabStyle(_tabPlayers, 62.0, 20.0, false, false);
    }

    private function toggleDashboard():Void {
        if (ApiDashboardModal.isOpen()) {
            ApiDashboardModal.close();
        } else {
            ApiDashboardModal.show(_stage, _host);
        }
    }

    public function onTick():Void {
        // 1. Live Auto Combat dot indicator
        var isCombatRunning = (Api.combat != null && Api.combat.isRunning());
        if (isCombatRunning != _lastCombatActive) {
            _lastCombatActive = isCombatRunning;
            renderAutoDot(isCombatRunning);
        }

        // 2. Live Area Player Count update on tab
        var players = TopBarPlayersPanel.getMapPlayers();
        var count = players.length;
        if (count != _lastPlayerCount) {
            _lastPlayerCount = count;
            if (_txtPlayers != null) {
                _txtPlayers.text = "Players (" + count + ")";
            }
        }

        // 3. Tick active dropdown panel
        if (_activeTab == "auto" && _autoPanel.visible) {
            _autoPanel.onTick();
        } else if (_activeTab == "jump" && _jumpPanel.visible) {
            _jumpPanel.onTick();
        } else if (_activeTab == "players" && _playersPanel.visible) {
            _playersPanel.onTick();
        }

        // 4. Close dropdown if a modal window opens
        if (_activeTab != null && ApiDashboardModal.isOpen()) {
            closeDropdown();
        }
    }
}
#else
class TopBar {
    public static var instance:TopBar = null;
    public static function init(stageObj:Dynamic, hostObj:Dynamic = null):Void {}
}
#end
