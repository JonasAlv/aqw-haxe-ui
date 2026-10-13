package ui.frames;

#if flash
import flash.display.DisplayObject;
import flash.display.Stage;
import flash.display.Sprite;
import flash.display.Shape;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.utils.Timer;
import flash.events.TimerEvent;
import flash.Lib;
import com.aqwapi.Api;
import com.aqwapi.data.PartyMemberDTO;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.utils.ApiConfig;
import ui.ApiStyle;
import ui.ApiNotificationManager;
import ui.ApiMenus;
import ui.ApiDashboardModal;

/**
 * PartyUnitFrame:
 * Modern, high-performance compact square party & raid frames (Grid / Grid2 style).
 *
 * Features:
 * - Compact square tiles with Healthcolor gradient fill (Healthy Green > 50%, Low Yellow 20-50%, Critical Red < 20%).
 * - Single bold % indicator for health at the center of each square.
 * - Thin mana indicator bar below health bar with no text.
 * - Draggable anywhere on screen, fully synchronized with AE's native posParty / HudDrag coordinates.
 * - Configurable orientation: Vertical (default) or Horizontal (optional).
 * - Instant left-click to target party members in combat.
 * - Out-of-range dimming and DEAD indicator.
 * - Test preview mode with simulated 4-member party.
 */
class PartyUnitFrame {
    public static inline var CONFIG_ENABLED:String       = "api_frame_party_enabled";
    public static inline var CONFIG_HORIZONTAL:String    = "api_frame_party_horizontal";
    public static inline var CONFIG_INCLUDE_SELF:String  = "api_frame_party_include_self";
    public static inline var CONFIG_SHOW_CLASS:String   = "api_frame_party_show_class";
    public static inline var CONFIG_POS_X:String         = "api_frame_party_x";
    public static inline var CONFIG_POS_Y:String         = "api_frame_party_y";

    // Geometry (Ultra-compact modern raid frame style)
    public static inline var TILE_W:Float                = 88.0;
    public static inline var TILE_H:Float                = 22.0;
    public static inline var GAP:Float                   = 2.0;
    public static inline var MANA_H:Float                = 3.0;

    // Palette
    public static inline var COLOR_BG:Int                = 0x0F1117; // Obsidian plate
    public static inline var COLOR_BORDER:Int            = 0x000000; // 1px solid black border
    public static inline var COLOR_WELL:Int              = 0x141721; // Bar well
    public static inline var COLOR_HP_HEALTHY:Int        = 0x22C55E; // Green (> 50%)
    public static inline var COLOR_HP_LOW:Int            = 0xEAB308; // Yellow/Gold (20% - 50%)
    public static inline var COLOR_HP_CRITICAL:Int       = 0xEF4444; // Red (< 20%)
    public static inline var COLOR_MP:Int                = 0x2563EB; // Mana blue
    public static inline var COLOR_MP_WELL:Int           = 0x0A0F1D; // Mana well dark
    public static inline var COLOR_SHIELD:Int            = 0x00E5FF; // Shield cyan
    public static inline var COLOR_NAME:Int              = 0x38BDF8; // Player name sky cyan
    public static inline var COLOR_LEADER:Int            = 0xFACC15; // Leader tag/name gold
    public static inline var COLOR_WHITE:Int             = 0xFFFFFF; // Crisp white
    public static inline var COLOR_MUTED:Int             = 0x64748B; // Slate muted for out of range

    private static var _pocket:Dynamic                   = null;
    private static var _overlay:Dynamic                  = null;
    private static var _widget:Sprite                    = null;
    private static var _tilesContainer:Sprite            = null;
    private static var _tiles:Array<PartyTile>           = [];
    private static var _initialized:Bool                 = false;

    // Dragging
    private static var _isDragging:Bool                  = false;
    private static var _hasDragged:Bool                  = false;
    private static var _dragStartX:Float                 = 0.0;
    private static var _dragStartY:Float                 = 0.0;
    private static var _startDownX:Float                 = 0.0;
    private static var _startDownY:Float                 = 0.0;

    // Preview state
    private static var _previewActive:Bool               = false;
    private static var _previewTimer:Timer               = null;
    private static var _tickTimer:Timer                  = null;

    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {
        if (_initialized) return;
        _initialized = true;

        _pocket = pocket;
        _overlay = overlay;

        var theStage:Dynamic = null;
        if (pocket != null && Std.isOfType(pocket, Stage)) {
            theStage = pocket;
        } else if (pocket != null && Reflect.hasField(pocket, "stage") && pocket.stage != null) {
            theStage = pocket.stage;
        } else if (overlay != null && Reflect.hasField(overlay, "stage") && overlay.stage != null) {
            theStage = overlay.stage;
        } else {
            try {
                if (Lib.current != null && Lib.current.stage != null) {
                    theStage = Lib.current.stage;
                }
            } catch (_:Dynamic) {}
        }

        var attach = function(stageObj:Dynamic):Void {
            if (stageObj == null || _widget != null) return;
            buildFrame(stageObj);
        };

        if (theStage != null) {
            attach(theStage);
        } else {
            if (_overlay != null && Std.isOfType(_overlay, DisplayObject)) {
                cast(_overlay, DisplayObject).addEventListener(Event.ADDED_TO_STAGE, function(ev:Event):Void {
                    if (_overlay.stage != null && _widget == null) {
                        attach(_overlay.stage);
                    }
                });
            }
            if (_pocket != null && Std.isOfType(_pocket, DisplayObject)) {
                cast(_pocket, DisplayObject).addEventListener(Event.ADDED_TO_STAGE, function(ev:Event):Void {
                    if (_pocket.stage != null && _widget == null) {
                        attach(_pocket.stage);
                    }
                });
            }
        }
    }

    private static function buildFrame(theStage:Dynamic):Void {
        if (_widget != null) return;

        _widget = new Sprite();
        _widget.name = "PartyUnitFrameWidget";
        _widget.mouseChildren = true;
        _widget.buttonMode = false;

        _tilesContainer = new Sprite();
        _tilesContainer.name = "PartyTilesContainer";
        _widget.addChild(_tilesContainer);

        // Restore saved position (or sync with native posParty)
        reloadFromConfig();

        if (theStage != null) {
            setupDragging(theStage);
            try {
                theStage.addChild(_widget);
            } catch (_:Dynamic) {}
        }

        startTickTimer();
        syncNativePartyFrame();
    }

    // =========================================================================
    // COLOR INTERPOLATION
    // =========================================================================
    public static function getHealthColor(ratio:Float):Int {
        if (ratio >= 0.50) {
            var t:Float = (ratio - 0.50) / 0.50;
            var r = Std.int(0xEA + (0x22 - 0xEA) * t);
            var g = Std.int(0xB3 + (0xC5 - 0xB3) * t);
            var b = Std.int(0x08 + (0x5E - 0x08) * t);
            return (r << 16) | (g << 8) | b;
        } else if (ratio >= 0.20) {
            var t:Float = (ratio - 0.20) / 0.30;
            var r = Std.int(0xEF + (0xEA - 0xEF) * t);
            var g = Std.int(0x44 + (0xB3 - 0x44) * t);
            var b = Std.int(0x44 + (0x08 - 0x44) * t);
            return (r << 16) | (g << 8) | b;
        } else {
            return COLOR_HP_CRITICAL;
        }
    }

    // =========================================================================
    // TICK & UPDATE LOOP (Isolated 80ms Timer)
    // =========================================================================
    private static function startTickTimer():Void {
        if (_tickTimer != null) return;
        _tickTimer = new Timer(80);
        _tickTimer.addEventListener(TimerEvent.TIMER, function(_):Void {
            onTick();
        });
        _tickTimer.start();
    }

    private static function onTick():Void {
        if (_widget == null) return;

        try {
            var inGame = ApiMenus.isInGame();
            var isDashboardOpen = ApiDashboardModal.isOpen();

            var enabled = isEnabled();
            if (!inGame || (!enabled && !_previewActive) || isDashboardOpen) {
                if (_widget.visible) _widget.visible = false;
                return;
            }

            // Fetch members to display
            var memberList:Array<PartyMemberDTO> = [];
            if (_previewActive) {
                memberList = getPreviewMembers();
            } else if (Api.party != null && Api.party.inParty) {
                memberList = isIncludeSelf() ? Api.party.allMembers : Api.party.members;
            }

            if (memberList.length == 0) {
                if (_widget.visible) _widget.visible = false;
                return;
            }

            if (!_widget.visible) _widget.visible = true;

            // Ensure correct tile count
            while (_tiles.length < memberList.length) {
                var tile = new PartyTile();
                _tiles.push(tile);
                _tilesContainer.addChild(tile);
            }
            while (_tiles.length > memberList.length) {
                var tile = _tiles.pop();
                if (tile.parent != null) tile.parent.removeChild(tile);
            }

            // Relayout and update tiles
            var isH = isHorizontal();
            for (i in 0...memberList.length) {
                var tile = _tiles[i];
                if (isH) {
                    tile.x = i * (TILE_W + GAP);
                    tile.y = 0;
                } else {
                    tile.x = 0;
                    tile.y = i * (TILE_H + GAP);
                }
                tile.update(memberList[i]);
            }

            syncNativePartyFrame();
        } catch (_:Dynamic) {}
    }

    // =========================================================================
    // DRAGGING MECHANICS
    // =========================================================================
    public static function onTileMouseDown(e:MouseEvent):Void {
        if (_widget == null) return;
        _isDragging = true;
        _hasDragged = false;
        _startDownX = e.stageX;
        _startDownY = e.stageY;
        _dragStartX = e.stageX - _widget.x;
        _dragStartY = e.stageY - _widget.y;

        if (_widget.parent != null) {
            try {
                _widget.parent.setChildIndex(_widget, _widget.parent.numChildren - 1);
            } catch (_:Dynamic) {}
        }
    }

    private static function setupDragging(theStage:Dynamic):Void {
        if (theStage == null) return;

        theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (_isDragging && _widget != null) {
                var dx = e.stageX - _startDownX;
                var dy = e.stageY - _startDownY;
                if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
                    _hasDragged = true;
                }
                if (_hasDragged) {
                    var nx:Float = Math.round(e.stageX - _dragStartX);
                    var ny:Float = Math.round(e.stageY - _dragStartY);
                    var sw:Float = (theStage.stageWidth > 0) ? theStage.stageWidth : 960;
                    var sh:Float = (theStage.stageHeight > 0) ? theStage.stageHeight : 550;

                    var count:Int = (_tiles.length > 0) ? _tiles.length : 1;
                    var totalW:Float = isHorizontal() ? (count * (TILE_W + GAP) - GAP) : TILE_W;
                    var totalH:Float = isHorizontal() ? TILE_H : (count * (TILE_H + GAP) - GAP);
                    if (totalW <= 0) totalW = TILE_W;
                    if (totalH <= 0) totalH = TILE_H;

                    if (nx < ApiStyle.SCREEN_MARGIN) nx = ApiStyle.SCREEN_MARGIN;
                    if (ny < ApiStyle.SCREEN_MARGIN) ny = ApiStyle.SCREEN_MARGIN;
                    if (nx > sw - totalW - ApiStyle.SCREEN_MARGIN) nx = sw - totalW - ApiStyle.SCREEN_MARGIN;
                    if (ny > sh - totalH - ApiStyle.SCREEN_MARGIN) ny = sh - totalH - ApiStyle.SCREEN_MARGIN;

                    _widget.x = nx;
                    _widget.y = ny;
                }
            }
        });

        theStage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            if (_isDragging) {
                _isDragging = false;
                if (_hasDragged && _widget != null) {
                    var savedX = Math.round(_widget.x);
                    var savedY = Math.round(_widget.y);
                    ApiConfig.setInt(CONFIG_POS_X, savedX);
                    ApiConfig.setInt(CONFIG_POS_Y, savedY);

                    // Sync with native posParty in litePreference so AE's native drag matches
                    try {
                        var g:Dynamic = Api.game;
                        if (g != null && g.litePreference != null && g.litePreference.data != null) {
                            g.litePreference.data.posParty = { "x": savedX, "y": savedY };
                            g.litePreference.flush();
                        }
                        if (g != null && g.ui != null && g.ui.mcPartyFrame != null) {
                            g.ui.mcPartyFrame.x = savedX;
                            g.ui.mcPartyFrame.y = savedY;
                        }
                    } catch (_:Dynamic) {}
                }
            }
        });
    }

    public static inline function hasDragged():Bool {
        return _hasDragged;
    }

    // =========================================================================
    // NATIVE PARTY FRAME SUPPRESSION
    // =========================================================================
    public static function syncNativePartyFrame():Void {
        try {
            var g:Dynamic = Api.game;
            if (g == null || g.ui == null || g.ui.mcPartyFrame == null) return;

            var customEnabled = isEnabled();
            if (customEnabled) {
                // Hide native party MovieClips to kill render lag
                g.ui.mcPartyFrame.visible = false;
                g.ui.mcPartyFrame.y = -9999;
            } else {
                g.ui.mcPartyFrame.visible = true;
                if (g.litePreference != null && g.litePreference.data != null && g.litePreference.data.posParty != null) {
                    var py = g.litePreference.data.posParty.y;
                    g.ui.mcPartyFrame.y = (py != null) ? py : 110.85;
                } else {
                    g.ui.mcPartyFrame.y = 110.85;
                }
            }
        } catch (_:Dynamic) {}
    }

    // =========================================================================
    // CONFIG & POSITION MANAGEMENT
    // =========================================================================
    public static function reloadFromConfig():Void {
        if (_widget == null) return;

        var defaultX:Int = 10;
        var defaultY:Int = 110;

        // Try reading native posParty first if not explicitly configured in ApiConfig
        try {
            var g:Dynamic = Api.game;
            if (g != null && g.litePreference != null && g.litePreference.data != null && g.litePreference.data.posParty != null) {
                var pos = g.litePreference.data.posParty;
                if (pos.x != null) defaultX = Std.int(pos.x);
                if (pos.y != null) defaultY = Std.int(pos.y);
            }
        } catch (_:Dynamic) {}

        var savedX = ApiConfig.getInt(CONFIG_POS_X, defaultX);
        var savedY = ApiConfig.getInt(CONFIG_POS_Y, defaultY);

        _widget.x = (savedX >= 0) ? savedX : defaultX;
        _widget.y = (savedY >= 0) ? savedY : defaultY;
        _widget.visible = isEnabled() && (Api.party != null && Api.party.inParty);

        syncNativePartyFrame();
    }

    public static inline function isEnabled():Bool {
        return ApiConfig.getBool(CONFIG_ENABLED, false);
    }

    public static function setEnabled(enabled:Bool):Void {
        ApiConfig.setBool(CONFIG_ENABLED, enabled);
        if (_widget != null) {
            _widget.visible = enabled && (Api.party != null && Api.party.inParty);
        }
        syncNativePartyFrame();
    }

    public static inline function isHorizontal():Bool {
        return ApiConfig.getBool(CONFIG_HORIZONTAL, false);
    }

    public static function setHorizontal(horizontal:Bool):Void {
        ApiConfig.setBool(CONFIG_HORIZONTAL, horizontal);
    }

    public static inline function isIncludeSelf():Bool {
        return ApiConfig.getBool(CONFIG_INCLUDE_SELF, false);
    }

    public static function setIncludeSelf(includeSelf:Bool):Void {
        ApiConfig.setBool(CONFIG_INCLUDE_SELF, includeSelf);
    }

    public static inline function isPartySpecificShowClassNames():Bool {
        return ApiConfig.getBool(CONFIG_SHOW_CLASS, false);
    }

    public static inline function isShowClassNames():Bool {
        return isPartySpecificShowClassNames() || UnitFramesManager.isShowClassNames();
    }

    public static function setShowClassNames(showClass:Bool):Void {
        ApiConfig.setBool(CONFIG_SHOW_CLASS, showClass);
    }

    public static function resetPosition():Void {
        var defX = 10;
        var defY = 110;
        ApiConfig.setInt(CONFIG_POS_X, defX);
        ApiConfig.setInt(CONFIG_POS_Y, defY);
        if (_widget != null) {
            _widget.x = defX;
            _widget.y = defY;
        }
        try {
            var g:Dynamic = Api.game;
            if (g != null && g.litePreference != null && g.litePreference.data != null) {
                g.litePreference.data.posParty = { "x": defX, "y": defY };
                g.litePreference.flush();
            }
            if (g != null && g.ui != null && g.ui.mcPartyFrame != null) {
                g.ui.mcPartyFrame.x = defX;
                g.ui.mcPartyFrame.y = defY;
            }
        } catch (_:Dynamic) {}
    }

    // =========================================================================
    // TEST PREVIEW SIMULATION
    // =========================================================================
    public static function testPreview():Void {
        _previewActive = true;
        if (_widget != null) _widget.visible = true;

        if (_previewTimer != null) {
            _previewTimer.stop();
            _previewTimer = null;
        }

        _previewTimer = new Timer(15000, 1);
        _previewTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function(_):Void {
            _previewActive = false;
            if (_widget != null) {
                _widget.visible = isEnabled() && (Api.party != null && Api.party.inParty);
            }
            _previewTimer = null;
        });
        _previewTimer.start();

        ApiNotificationManager.notify("Party Frames Preview (15s): Draggable Grid2 compact squares");
    }

    private static function getPreviewMembers():Array<PartyMemberDTO> {
        var m1 = new PartyMemberDTO();
        m1.username = (Api.player != null && Api.player.username != "") ? Api.player.username : "You";
        m1.className = (Api.player != null && Api.player.className != "") ? Api.player.className : "Dragon of Time";
        m1.hp = 3500; m1.maxHp = 3500;
        m1.mp = 100;  m1.maxMp = 100;
        m1.isLeader = true;
        m1.inRange = true;
        m1.inCell = true;

        var m2 = new PartyMemberDTO();
        m2.username = "Zhonya";
        m2.className = "ArchPaladin";
        m2.hp = 3120; m2.maxHp = 4000; // 78%
        m2.mp = 75;   m2.maxMp = 100;
        m2.isLeader = false;
        m2.inRange = true;
        m2.inCell = true;

        var m3 = new PartyMemberDTO();
        m3.username = "Kira";
        m3.className = "Lord of Order";
        m3.hp = 1260; m3.maxHp = 3000; // 42%
        m3.mp = 35;   m3.maxMp = 100;
        m3.isLeader = false;
        m3.inRange = true;
        m3.inCell = true;

        var m4 = new PartyMemberDTO();
        m4.username = "Aether";
        m4.className = "Legion Revenant";
        m4.hp = 540;  m4.maxHp = 3000; // 18% (Critical)
        m4.mp = 80;   m4.maxMp = 100;
        m4.isLeader = false;
        m4.inRange = true;
        m4.inCell = true;

        return isIncludeSelf() ? [m1, m2, m3, m4] : [m2, m3, m4];
    }
}

// =============================================================================
// PARTY MEMBER TILE (Grid / Grid2 Compact Square)
// =============================================================================
class PartyTile extends Sprite {
    private var _bgWell:Shape;
    private var _hpBarWell:Shape;
    private var _hpBarFill:Shape;
    private var _hpBarBorder:Shape;
    private var _shieldFill:Shape;
    private var _mpBarWell:Shape;
    private var _mpBarFill:Shape;
    private var _mpBarBorder:Shape;
    private var _tileBorder:Shape;

    private var _nameTxt:TextField;
    private var _pctTxt:TextField;

    // Data cache
    private var _currentMember:PartyMemberDTO = null;
    private var _lastHp:Int                   = -9999;
    private var _lastMaxHp:Int                = -9999;
    private var _lastMp:Int                   = -9999;
    private var _lastMaxMp:Int                = -9999;
    private var _lastShield:Int               = -9999;
    private var _lastName:String              = "";
    private var _lastIsLeader:Bool            = false;
    private var _lastShowClass:Bool           = false;
    private var _lastInCell:Bool              = true;
    private var _lastInRange:Bool             = true;

    public function new() {
        super();
        this.mouseChildren = false;
        this.buttonMode = true;
        this.useHandCursor = true;

        buildDisplay();
        setupEvents();
    }

    private function buildDisplay():Void {
        var w = PartyUnitFrame.TILE_W;
        var h = PartyUnitFrame.TILE_H;
        var hpW = w - 2.0;
        var hpH = h - PartyUnitFrame.MANA_H - 2.0; // 22 - 3 - 2 = 17px
        var mpY = 1.0 + hpH; // 18.0
        var mpH = PartyUnitFrame.MANA_H; // 3.0

        // 1. Tile Background Plate
        _bgWell = new Shape();
        var g = _bgWell.graphics;
        g.beginFill(PartyUnitFrame.COLOR_BG, 0.95);
        g.drawRect(0, 0, w, h);
        g.endFill();
        addChild(_bgWell);

        // 2. Health Bar Well
        _hpBarWell = new Shape();
        var gw = _hpBarWell.graphics;
        gw.beginFill(PartyUnitFrame.COLOR_WELL, 0.9);
        gw.drawRect(1, 1, hpW, hpH);
        gw.endFill();
        addChild(_hpBarWell);

        // 3. Health Bar Fill
        _hpBarFill = new Shape();
        addChild(_hpBarFill);

        // 4. Shield Overlay
        _shieldFill = new Shape();
        addChild(_shieldFill);

        // 5. Thin Mana Bar Well
        _mpBarWell = new Shape();
        var gmw = _mpBarWell.graphics;
        gmw.beginFill(PartyUnitFrame.COLOR_MP_WELL, 0.9);
        gmw.drawRect(1, mpY, hpW, mpH);
        gmw.endFill();
        addChild(_mpBarWell);

        // 6. Mana Bar Fill
        _mpBarFill = new Shape();
        addChild(_mpBarFill);

        // 7. Outer 1px Solid Border
        _tileBorder = new Shape();
        var gtb = _tileBorder.graphics;
        gtb.lineStyle(1.0, PartyUnitFrame.COLOR_BORDER, 1.0, true);
        gtb.drawRect(0.5, 0.5, w - 1.0, h - 1.0);
        addChild(_tileBorder);

        // 8. Player Name (Top-left aligned over HP bar)
        _nameTxt = new TextField();
        _nameTxt.x = 2;
        _nameTxt.y = 0;
        _nameTxt.width = w - 4; // Spans full width for full names
        _nameTxt.height = 12;
        _nameTxt.selectable = false;
        _nameTxt.mouseEnabled = false;
        var tfName = new TextFormat(ApiStyle.FONT_FAMILY, 8, PartyUnitFrame.COLOR_NAME, true);
        tfName.align = TextFormatAlign.LEFT;
        _nameTxt.defaultTextFormat = tfName;
        _nameTxt.filters = ApiStyle.getTextOutlineFilter();
        addChild(_nameTxt);

        // 9. Health % Indicator (Centered inside health frame)
        _pctTxt = new TextField();
        _pctTxt.x = 0;
        _pctTxt.y = 6.5;
        _pctTxt.width = w;
        _pctTxt.height = 12;
        _pctTxt.selectable = false;
        _pctTxt.mouseEnabled = false;
        var tfPct = new TextFormat(ApiStyle.FONT_FAMILY, 8.5, PartyUnitFrame.COLOR_WHITE, true);
        tfPct.align = TextFormatAlign.CENTER;
        _pctTxt.defaultTextFormat = tfPct;
        _pctTxt.filters = ApiStyle.getTextOutlineFilter();
        addChild(_pctTxt);
    }

    private function setupEvents():Void {
        this.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            PartyUnitFrame.onTileMouseDown(e);
        });

        this.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (PartyUnitFrame.hasDragged()) return; // Was a drag, do not target
            if (_currentMember == null) return;

            if (e.shiftKey) {
                // Open native cMenu on shift-click
                try {
                    var g:Dynamic = Api.game;
                    if (g != null && g.ui != null && g.ui.cMenu != null) {
                        g.ui.cMenu.fOpenWith("party", { "strUsername": _currentMember.username });
                    }
                } catch (_:Dynamic) {}
            } else {
                // Instant left-click to target
                _currentMember.target();
            }
        });
    }

    public function update(member:PartyMemberDTO):Void {
        _currentMember = member;
        if (member == null) return;

        var hp = member.hp;
        var maxHp = member.maxHp;
        var mp = member.mp;
        var maxMp = member.maxMp;
        var shield = member.shield;
        var name = member.username;
        var isLeader = member.isLeader;
        var inCell = member.inCell;
        var inRange = member.inRange;
        var isMe = member.isMe;

        var w = PartyUnitFrame.TILE_W;
        var hpW = w - 2.0;
        var hpH = PartyUnitFrame.TILE_H - PartyUnitFrame.MANA_H - 2.0;
        var mpY = 1.0 + hpH;
        var mpH = PartyUnitFrame.MANA_H;

        // Dim tile if not in cell / out of range
        var activeCell = inCell || isMe;
        if (activeCell != _lastInCell) {
            _lastInCell = activeCell;
            this.alpha = activeCell ? 1.0 : 0.55;
        }

        var showClass = PartyUnitFrame.isShowClassNames();
        var nameToDisplay = (showClass && member.className != null && member.className != "") ? member.className : name;

        // 1. Update Name Text
        if (nameToDisplay != _lastName || isLeader != _lastIsLeader || showClass != _lastShowClass) {
            _lastName = nameToDisplay;
            _lastIsLeader = isLeader;
            _lastShowClass = showClass;

            var maxLen = isLeader ? 14 : 16;
            var displayName = (nameToDisplay.length > maxLen) ? (nameToDisplay.substr(0, maxLen - 1) + "..") : nameToDisplay;
            if (isLeader) {
                _nameTxt.text = "[L] " + displayName;
                var tf = _nameTxt.defaultTextFormat;
                tf.color = PartyUnitFrame.COLOR_LEADER;
                _nameTxt.defaultTextFormat = tf;
                _nameTxt.setTextFormat(tf);
            } else {
                _nameTxt.text = displayName;
                var tf = _nameTxt.defaultTextFormat;
                tf.color = PartyUnitFrame.COLOR_NAME;
                _nameTxt.defaultTextFormat = tf;
                _nameTxt.setTextFormat(tf);
            }
            _nameTxt.filters = ApiStyle.getTextOutlineFilter();
        }

        // 2. Update Health & % Indicator
        if (hp != _lastHp || maxHp != _lastMaxHp || shield != _lastShield || inRange != _lastInRange) {
            _lastHp = hp;
            _lastMaxHp = maxHp;
            _lastShield = shield;
            _lastInRange = inRange;

            if (!inRange && !isMe) {
                // Out of range (different map or far away)
                if (maxHp > 0) {
                    var hpRatio = member.hpRatio;
                    var pct = member.hpPercent;
                    _pctTxt.text = pct + "%";
                    var color = PartyUnitFrame.getHealthColor(hpRatio);
                    var fillW = Math.round(hpW * hpRatio);
                    var g = _hpBarFill.graphics;
                    g.clear();
                    if (fillW > 0) {
                        g.beginFill(color, 0.4); // Dimmed fill
                        g.drawRect(1, 1, fillW, hpH);
                        g.endFill();
                    }
                } else {
                    _pctTxt.text = "Far";
                    _hpBarFill.graphics.clear();
                }
                var tf = _pctTxt.defaultTextFormat;
                tf.color = PartyUnitFrame.COLOR_MUTED;
                _pctTxt.defaultTextFormat = tf;
                _pctTxt.setTextFormat(tf);
                _pctTxt.filters = ApiStyle.getTextOutlineFilter();
                _shieldFill.graphics.clear();
            } else if (hp <= 0 && inRange) {
                // Dead
                _pctTxt.text = "DEAD";
                var tf = _pctTxt.defaultTextFormat;
                tf.color = PartyUnitFrame.COLOR_HP_CRITICAL;
                _pctTxt.defaultTextFormat = tf;
                _pctTxt.setTextFormat(tf);
                _pctTxt.filters = ApiStyle.getTextOutlineFilter();

                _hpBarFill.graphics.clear();
                _shieldFill.graphics.clear();
            } else {
                var hpRatio = member.hpRatio;
                var pct = member.hpPercent;
                _pctTxt.text = pct + "%";
                var tf = _pctTxt.defaultTextFormat;
                tf.color = PartyUnitFrame.COLOR_WHITE;
                _pctTxt.defaultTextFormat = tf;
                _pctTxt.setTextFormat(tf);
                _pctTxt.filters = ApiStyle.getTextOutlineFilter();

                // Health Fill
                var color = PartyUnitFrame.getHealthColor(hpRatio);
                var fillW = Math.round(hpW * hpRatio);
                var g = _hpBarFill.graphics;
                g.clear();
                if (fillW > 0) {
                    g.beginFill(color, 0.95);
                    g.drawRect(1, 1, fillW, hpH);
                    g.endFill();
                }

                // Shield Fill (+SG overlay)
                var gs = _shieldFill.graphics;
                gs.clear();
                if (shield > 0 && maxHp > 0) {
                    var sRatio = Math.min(1.0, shield / maxHp);
                    var sW = Math.round(hpW * sRatio);
                    if (sW > 0) {
                        gs.beginFill(PartyUnitFrame.COLOR_SHIELD, 0.45);
                        gs.drawRect(1, 1, sW, hpH);
                        gs.endFill();
                    }
                }
            }
        }

        // 3. Update Mana Bar (thin bar below healthbar, no text)
        if (mp != _lastMp || maxMp != _lastMaxMp) {
            _lastMp = mp;
            _lastMaxMp = maxMp;

            var mpRatio = member.mpRatio;
            var fillW = Math.round(hpW * mpRatio);

            var gm = _mpBarFill.graphics;
            gm.clear();
            if (fillW > 0) {
                gm.beginFill(PartyUnitFrame.COLOR_MP, 0.95);
                gm.drawRect(1, mpY, fillW, mpH);
                gm.endFill();
            }
        }
    }
}
#else
class PartyUnitFrame {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isEnabled():Bool return false;
    public static function setEnabled(enabled:Bool):Void {}
    public static function isHorizontal():Bool return false;
    public static function setHorizontal(horizontal:Bool):Void {}
    public static function isIncludeSelf():Bool return false;
    public static function setIncludeSelf(includeSelf:Bool):Void {}
    public static function isPartySpecificShowClassNames():Bool return false;
    public static function isShowClassNames():Bool return false;
    public static function setShowClassNames(showClass:Bool):Void {}
    public static function resetPosition():Void {}
    public static function testPreview():Void {}
    public static function reloadFromConfig():Void {}
}
#end
