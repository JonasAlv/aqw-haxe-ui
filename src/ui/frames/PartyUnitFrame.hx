package ui.frames;

#if flash
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
    public static inline var CONFIG_POS_X:String         = "api_frame_party_x";
    public static inline var CONFIG_POS_Y:String         = "api_frame_party_y";

    // Geometry
    public static inline var TILE_W:Float                = 64.0;
    public static inline var TILE_H:Float                = 54.0;
    public static inline var GAP:Float                   = 4.0;
    public static inline var MANA_H:Float                = 3.5;
    public static inline var HEADER_H:Float              = 14.0;

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
    private static var _lastTick:Int                     = 0;

    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {
        if (_initialized) return;
        _initialized = true;

        _pocket = pocket;
        _overlay = overlay;

        _widget = new Sprite();
        _widget.name = "PartyUnitFrameWidget";
        _widget.mouseChildren = true;
        _widget.buttonMode = false;

        _tilesContainer = new Sprite();
        _tilesContainer.name = "PartyTilesContainer";
        _widget.addChild(_tilesContainer);

        // Add to overlay / pocket layer
        var container:Dynamic = (_overlay != null) ? _overlay : ((_pocket != null) ? _pocket : Lib.current.stage);
        if (container != null) {
            container.addChild(_widget);
        }

        // Setup global dragging listeners on stage
        var theStage:Dynamic = Lib.current.stage;
        if (theStage != null) {
            setupDragging(theStage);
            theStage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
        }

        // Restore saved position (or sync with native posParty)
        reloadFromConfig();
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
    // TICK & UPDATE LOOP
    // =========================================================================
    private static function onEnterFrame(e:Event):Void {
        if (_widget == null) return;

        var now = Lib.getTimer();
        if (now - _lastTick < 80) return; // ~12 FPS throttle
        _lastTick = now;

        var enabled = isEnabled();
        if (!enabled && !_previewActive) {
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
    }

    // =========================================================================
    // DRAGGING MECHANICS
    // =========================================================================
    public static function onTileMouseDown(e:MouseEvent):Void {
        _isDragging = true;
        _hasDragged = false;
        _startDownX = e.stageX;
        _startDownY = e.stageY;
        _dragStartX = e.stageX - _widget.x;
        _dragStartY = e.stageY - _widget.y;

        if (_widget.parent != null) {
            _widget.parent.setChildIndex(_widget, _widget.parent.numChildren - 1);
        }
    }

    private static function setupDragging(theStage:Dynamic):Void {
        theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (_isDragging) {
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

                    var totalW:Float = isHorizontal() ? (_tiles.length * (TILE_W + GAP)) : TILE_W;
                    var totalH:Float = isHorizontal() ? TILE_H : (_tiles.length * (TILE_H + GAP));
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
                if (_hasDragged) {
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
        m1.hp = 3500; m1.maxHp = 3500;
        m1.mp = 100;  m1.maxMp = 100;
        m1.isLeader = true;
        m1.inRange = true;
        m1.inCell = true;

        var m2 = new PartyMemberDTO();
        m2.username = "ArchPaladin";
        m2.hp = 3120; m2.maxHp = 4000; // 78%
        m2.mp = 75;   m2.maxMp = 100;
        m2.isLeader = false;
        m2.inRange = true;
        m2.inCell = true;

        var m3 = new PartyMemberDTO();
        m3.username = "LordOfOrder";
        m3.hp = 1260; m3.maxHp = 3000; // 42%
        m3.mp = 35;   m3.maxMp = 100;
        m3.isLeader = false;
        m3.inRange = true;
        m3.inCell = true;

        var m4 = new PartyMemberDTO();
        m4.username = "LegionRev";
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
    private var _lastInCell:Bool              = true;

    public function new() {
        super();
        this.mouseChildren = false;
        this.buttonMode = true;
        this.useHandCursor = true;

        buildDisplay();
        setupEvents();
    }

    private function buildDisplay():Void {
        // 1. Tile Well Background
        _bgWell = new Shape();
        var g = _bgWell.graphics;
        g.beginFill(PartyUnitFrame.COLOR_BG, 0.95);
        g.drawRect(0, 0, PartyUnitFrame.TILE_W, PartyUnitFrame.TILE_H);
        g.endFill();
        addChild(_bgWell);

        // 2. Health Bar Well (main body of the square)
        var hpY:Float = PartyUnitFrame.HEADER_H;
        var hpH:Float = PartyUnitFrame.TILE_H - PartyUnitFrame.HEADER_H - PartyUnitFrame.MANA_H - 1.0;
        _hpBarWell = new Shape();
        var gw = _hpBarWell.graphics;
        gw.beginFill(PartyUnitFrame.COLOR_WELL, 0.9);
        gw.drawRect(0, hpY, PartyUnitFrame.TILE_W, hpH);
        gw.endFill();
        addChild(_hpBarWell);

        // 3. Health Bar Fill
        _hpBarFill = new Shape();
        addChild(_hpBarFill);

        // 4. Shield Overlay
        _shieldFill = new Shape();
        addChild(_shieldFill);

        // 5. Health Bar 1px Black Border
        _hpBarBorder = new Shape();
        var ghb = _hpBarBorder.graphics;
        ghb.lineStyle(1.0, PartyUnitFrame.COLOR_BORDER, 1.0, true);
        ghb.drawRect(0.5, hpY + 0.5, PartyUnitFrame.TILE_W - 1.0, hpH - 1.0);
        addChild(_hpBarBorder);

        // 6. Thin Mana Bar Well (at bottom of square, no text)
        var mpY:Float = PartyUnitFrame.TILE_H - PartyUnitFrame.MANA_H;
        _mpBarWell = new Shape();
        var gmw = _mpBarWell.graphics;
        gmw.beginFill(PartyUnitFrame.COLOR_MP_WELL, 0.9);
        gmw.drawRect(0, mpY, PartyUnitFrame.TILE_W, PartyUnitFrame.MANA_H);
        gmw.endFill();
        addChild(_mpBarWell);

        // 7. Mana Bar Fill
        _mpBarFill = new Shape();
        addChild(_mpBarFill);

        // 8. Mana Bar 1px Black Border
        _mpBarBorder = new Shape();
        var gmb = _mpBarBorder.graphics;
        gmb.lineStyle(1.0, PartyUnitFrame.COLOR_BORDER, 1.0, true);
        gmb.drawRect(0.5, mpY + 0.5, PartyUnitFrame.TILE_W - 1.0, PartyUnitFrame.MANA_H - 1.0);
        addChild(_mpBarBorder);

        // 9. Overall 1px Outer Tile Border
        _tileBorder = new Shape();
        var gtb = _tileBorder.graphics;
        gtb.lineStyle(1.0, PartyUnitFrame.COLOR_BORDER, 1.0, true);
        gtb.drawRect(0.5, 0.5, PartyUnitFrame.TILE_W - 1.0, PartyUnitFrame.TILE_H - 1.0);
        addChild(_tileBorder);

        // 10. Top Name Text Field
        _nameTxt = new TextField();
        _nameTxt.x = 2;
        _nameTxt.y = 0;
        _nameTxt.width = PartyUnitFrame.TILE_W - 4;
        _nameTxt.height = PartyUnitFrame.HEADER_H;
        _nameTxt.selectable = false;
        _nameTxt.mouseEnabled = false;
        var tfName = new TextFormat(ApiStyle.FONT_FAMILY, 9, PartyUnitFrame.COLOR_NAME, true);
        tfName.align = TextFormatAlign.CENTER;
        _nameTxt.defaultTextFormat = tfName;
        _nameTxt.filters = ApiStyle.getTextOutlineFilter();
        addChild(_nameTxt);

        // 11. Center 1 Single % Indicator Text Field
        _pctTxt = new TextField();
        _pctTxt.x = 0;
        _pctTxt.y = hpY + (hpH - 18) / 2.0;
        _pctTxt.width = PartyUnitFrame.TILE_W;
        _pctTxt.height = 20;
        _pctTxt.selectable = false;
        _pctTxt.mouseEnabled = false;
        var tfPct = new TextFormat(ApiStyle.FONT_FAMILY, 12, PartyUnitFrame.COLOR_WHITE, true);
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

        // Dim tile if not in cell / out of range
        if (inCell != _lastInCell) {
            _lastInCell = inCell;
            this.alpha = inCell ? 1.0 : 0.45;
        }

        // 1. Update Name Text
        if (name != _lastName || isLeader != _lastIsLeader) {
            _lastName = name;
            _lastIsLeader = isLeader;

            var displayName = (name.length > 7) ? (name.substr(0, 6) + "..") : name;
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
        if (hp != _lastHp || maxHp != _lastMaxHp || shield != _lastShield) {
            _lastHp = hp;
            _lastMaxHp = maxHp;
            _lastShield = shield;

            var hpY:Float = PartyUnitFrame.HEADER_H;
            var hpH:Float = PartyUnitFrame.TILE_H - PartyUnitFrame.HEADER_H - PartyUnitFrame.MANA_H - 1.0;

            if (hp <= 0) {
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
                var fillW = Math.round(PartyUnitFrame.TILE_W * hpRatio);
                var g = _hpBarFill.graphics;
                g.clear();
                if (fillW > 0) {
                    g.beginFill(color, 0.95);
                    g.drawRect(0, hpY, fillW, hpH);
                    g.endFill();
                }

                // Shield Fill (+SG overlay)
                var gs = _shieldFill.graphics;
                gs.clear();
                if (shield > 0 && maxHp > 0) {
                    var sRatio = Math.min(1.0, shield / maxHp);
                    var sW = Math.round(PartyUnitFrame.TILE_W * sRatio);
                    if (sW > 0) {
                        gs.beginFill(PartyUnitFrame.COLOR_SHIELD, 0.4);
                        gs.drawRect(0, hpY, sW, hpH);
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
            var fillW = Math.round(PartyUnitFrame.TILE_W * mpRatio);
            var mpY:Float = PartyUnitFrame.TILE_H - PartyUnitFrame.MANA_H;

            var gm = _mpBarFill.graphics;
            gm.clear();
            if (fillW > 0) {
                gm.beginFill(PartyUnitFrame.COLOR_MP, 0.95);
                gm.drawRect(0, mpY, fillW, PartyUnitFrame.MANA_H);
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
    public static function resetPosition():Void {}
    public static function testPreview():Void {}
    public static function reloadFromConfig():Void {}
}
#end
