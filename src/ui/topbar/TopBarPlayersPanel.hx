package ui.topbar;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import com.aqwapi.Api;
import ui.ApiStyle;
import ui.widgets.PlayersWidget;

/**
 * Dropdown panel for Area Players attached directly beneath the TopBar.
 * 100% pure ASCII strings and Flash vector graphics (zero Unicode glyphs).
 */
class TopBarPlayersPanel extends Sprite {
    public static inline var PANEL_WIDTH:Float = 250.0;
    private static inline var ROW_H:Float = 20.0;
    private static inline var MAX_VISIBLE_ROWS:Int = 6;

    private var _bg:Shape;
    private var _headerTxt:TextField;
    private var _listContainer:Sprite;
    private var _listContent:Sprite;
    private var _listMask:Shape;

    private var _isDraggingList:Bool = false;
    private var _scrollDragStartY:Float = 0;
    private var _dragStartContentY:Float = 0;

    private var _lastPlayerHash:String = "";
    private var _tickCounter:Int = 0;

    public function new() {
        super();
        buildUI();
    }

    private function buildUI():Void {
        _bg = new Shape();
        addChild(_bg);

        // Header info text
        _headerTxt = new TextField();
        var hFmt = new TextFormat(ApiStyle.FONT_FAMILY, 10, ApiStyle.COLOR_TEXT_MUTED, false);
        hFmt.align = TextFormatAlign.LEFT;
        _headerTxt.defaultTextFormat = hFmt;
        _headerTxt.x = 8.0;
        _headerTxt.y = 5.0;
        _headerTxt.width = PANEL_WIDTH - 16.0;
        _headerTxt.height = 18.0;
        _headerTxt.selectable = false;
        _headerTxt.mouseEnabled = false;
        addChild(_headerTxt);

        // List container
        _listContainer = new Sprite();
        _listContainer.x = 4.0;
        _listContainer.y = 24.0;
        addChild(_listContainer);

        _listMask = new Shape();
        _listContainer.addChild(_listMask);

        _listContent = new Sprite();
        _listContent.mask = _listMask;
        _listContainer.addChild(_listContent);

        // Touch drag scrolling
        _listContainer.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            e.stopPropagation();
            _isDraggingList = true;
            _scrollDragStartY = e.stageY;
            _dragStartContentY = _listContent.y;
        });

        // Mouse wheel scroll
        _listContainer.addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent):Void {
            var curListH = getVisibleListHeight();
            if (_listContent.height <= curListH) return;
            var maxScroll = curListH - _listContent.height;
            var nextY = _listContent.y + (e.delta * 16);
            if (nextY > 0) nextY = 0;
            if (nextY < maxScroll) nextY = maxScroll;
            _listContent.y = nextY;
        });

        refreshPlayers();
    }

    private var theStage(get, never):flash.display.Stage;
    private function get_theStage():flash.display.Stage {
        return (this.stage != null) ? this.stage : flash.Lib.current.stage;
    }

    public function handleStageMouseMove(e:MouseEvent):Void {
        if (_isDraggingList) {
            var dy = e.stageY - _scrollDragStartY;
            var newY = _dragStartContentY + dy;
            var curListH = getVisibleListHeight();
            var maxScroll = curListH - _listContent.height;
            if (maxScroll > 0) maxScroll = 0;
            if (newY > 0) newY = 0;
            if (newY < maxScroll) newY = maxScroll;
            _listContent.y = newY;
        }
    }

    public function handleStageMouseUp(e:MouseEvent):Void {
        _isDraggingList = false;
    }

    private function getVisibleListHeight():Float {
        var players = PlayersWidget.getMapPlayers();
        var rowCount = (players.length > 0) ? players.length : 1;
        var visibleCount = (rowCount > MAX_VISIBLE_ROWS) ? MAX_VISIBLE_ROWS : rowCount;
        return visibleCount * ROW_H;
    }

    public function refreshPlayers():Void {
        var players = PlayersWidget.getMapPlayers();
        var mapName = (Api.map != null && Api.map.name != null) ? Api.map.name : "";

        var countStr = (players.length == 1) ? "1 player in " : (players.length + " players in ");
        if (mapName != "") {
            _headerTxt.htmlText = "<font color='#B0B4C3'>" + countStr + "</font><font color='#FFE100'>" + mapName + "</font>";
        } else {
            _headerTxt.htmlText = "<font color='#B0B4C3'>" + countStr + "</font>";
        }

        while (_listContent.numChildren > 0) _listContent.removeChildAt(0);

        var curY:Float = 0.0;
        var rowW:Float = PANEL_WIDTH - 8.0;

        if (players.length == 0) {
            var emptyTxt = new TextField();
            var eFmt = new TextFormat(ApiStyle.FONT_FAMILY, 9, ApiStyle.COLOR_TEXT_MUTED);
            eFmt.align = TextFormatAlign.CENTER;
            emptyTxt.defaultTextFormat = eFmt;
            emptyTxt.text = "No players";
            emptyTxt.x = 0;
            emptyTxt.y = 2;
            emptyTxt.width = rowW;
            emptyTxt.height = 16;
            emptyTxt.selectable = false;
            _listContent.addChild(emptyTxt);
        } else {
            for (i in 0...players.length) {
                var p = players[i];
                var row = createPlayerRow(rowW, ROW_H, p, i % 2 == 0);
                row.y = curY;
                _listContent.addChild(row);
                curY += ROW_H;
            }
        }

        var listH = getVisibleListHeight();
        var totalH = 28.0 + listH + 4.0;

        _listMask.graphics.clear();
        _listMask.graphics.beginFill(0xFF0000);
        _listMask.graphics.drawRoundRect(0, 0, rowW, listH, 3, 3);
        _listMask.graphics.endFill();

        var g = _bg.graphics;
        g.clear();
        g.beginFill(ApiStyle.COLOR_BG_CARD, 0.96);
        g.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.95);
        g.drawRoundRect(0, 0, PANEL_WIDTH, totalH, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
        g.endFill();

        g.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.4);
        g.moveTo(3, 23);
        g.lineTo(PANEL_WIDTH - 3, 23);

        g.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.5);
        g.moveTo(3, 1);
        g.lineTo(PANEL_WIDTH - 3, 1);

        var maxScroll = listH - _listContent.height;
        if (maxScroll > 0) maxScroll = 0;
        if (_listContent.y < maxScroll) _listContent.y = maxScroll;
        if (_listContent.y > 0) _listContent.y = 0;
    }

    private function createPlayerRow(w:Float, h:Float, player:MapPlayerInfo, altBg:Bool):Sprite {
        var row = new Sprite();
        row.buttonMode = true;
        row.useHandCursor = true;

        var normalBg = altBg ? ApiStyle.COLOR_BG_MAIN : ApiStyle.COLOR_BG_CARD;
        var drawBg = function(hover:Bool):Void {
            row.graphics.clear();
            var bgCol = hover ? ApiStyle.COLOR_BTN_BG_HOVER : normalBg;
            var alphaVal = hover ? 0.98 : 0.92;
            row.graphics.beginFill(bgCol, alphaVal);
            if (hover) {
                row.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_HIGHLIGHT, 0.8);
            }
            row.graphics.drawRoundRect(0, 0, w, h - 2, 3, 3);
            row.graphics.endFill();
        };
        drawBg(false);

        row.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void drawBg(true));
        row.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void drawBg(false));

        var lvlTxt = new TextField();
        var lvlFmt = new TextFormat(ApiStyle.FONT_FAMILY, 9, 0x2ECC71, true);
        lvlTxt.defaultTextFormat = lvlFmt;
        lvlTxt.text = Std.string(player.level);
        lvlTxt.x = 4;
        lvlTxt.y = 1;
        lvlTxt.width = 18;
        lvlTxt.height = 16;
        lvlTxt.selectable = false;
        lvlTxt.mouseEnabled = false;
        row.addChild(lvlTxt);

        var nameTxt = new TextField();
        var nameColor = player.isSelf ? ApiStyle.COLOR_ACCENT_PRIMARY : ApiStyle.COLOR_TEXT_PRIMARY;
        var nameFmt = new TextFormat(ApiStyle.FONT_FAMILY, 9, nameColor, player.isSelf);
        nameTxt.defaultTextFormat = nameFmt;
        nameTxt.text = player.username;
        nameTxt.x = 24;
        nameTxt.y = 1;
        nameTxt.height = 16;
        nameTxt.selectable = false;
        nameTxt.mouseEnabled = false;

        if (player.isSelf) {
            nameTxt.width = w - 24 - 36;
            row.addChild(nameTxt);

            var selfLbl = new TextField();
            var sFmt = new TextFormat(ApiStyle.FONT_FAMILY, 8, ApiStyle.COLOR_ACCENT_PRIMARY, true);
            sFmt.align = TextFormatAlign.RIGHT;
            selfLbl.defaultTextFormat = sFmt;
            selfLbl.text = "(You)";
            selfLbl.x = w - 38;
            selfLbl.y = 2;
            selfLbl.width = 34;
            selfLbl.height = 14;
            selfLbl.selectable = false;
            selfLbl.mouseEnabled = false;
            row.addChild(selfLbl);
        } else {
            var btnW:Float = 32.0;
            var btnH:Float = 14.0;
            var btnX:Float = w - btnW - 3;

            if (w >= 180 && player.cell != "") {
                var cellTxt = new TextField();
                var cFmt = new TextFormat(ApiStyle.FONT_FAMILY, 8, ApiStyle.COLOR_TEXT_MUTED);
                cFmt.align = TextFormatAlign.RIGHT;
                cellTxt.defaultTextFormat = cFmt;
                cellTxt.text = player.cell;
                cellTxt.x = btnX - 36;
                cellTxt.y = 2;
                cellTxt.width = 34;
                cellTxt.height = 14;
                cellTxt.selectable = false;
                cellTxt.mouseEnabled = false;
                row.addChild(cellTxt);

                nameTxt.width = cellTxt.x - 26;
            } else {
                nameTxt.width = btnX - 26;
            }
            row.addChild(nameTxt);

            var btnGoto = new Sprite();
            btnGoto.buttonMode = true;
            btnGoto.useHandCursor = true;
            btnGoto.x = btnX;
            btnGoto.y = Math.round((h - 2 - btnH) / 2);

            var renderGoto = function(hover:Bool):Void {
                var g = btnGoto.graphics;
                g.clear();
                g.beginFill(hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE, 0.95);
                g.lineStyle(1, hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT);
                g.drawRoundRect(0, 0, btnW, btnH, 2, 2);
                g.endFill();
            };
            renderGoto(false);

            var gotoLbl = new TextField();
            var gFmt = new TextFormat(ApiStyle.FONT_FAMILY, 8, ApiStyle.COLOR_STATUS_ACTIVE, true);
            gFmt.align = TextFormatAlign.CENTER;
            gotoLbl.defaultTextFormat = gFmt;
            gotoLbl.text = "Goto";
            gotoLbl.x = 0;
            gotoLbl.y = 0;
            gotoLbl.width = btnW;
            gotoLbl.height = btnH;
            gotoLbl.selectable = false;
            gotoLbl.mouseEnabled = false;
            btnGoto.addChild(gotoLbl);

            btnGoto.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void renderGoto(true));
            btnGoto.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void renderGoto(false));
            btnGoto.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void e.stopPropagation());
            btnGoto.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
                e.stopPropagation();
                PlayersWidget.gotoPlayer(player);
            });
            row.addChild(btnGoto);
        }

        return row;
    }

    public function onTick():Void {
        _tickCounter++;
        if (_lastPlayerHash != "" && _tickCounter % 8 != 0) return;

        var players = PlayersWidget.getMapPlayers();
        var mapName = (Api.map != null && Api.map.name != null) ? Api.map.name : "";

        var hash = mapName + ":" + players.length;
        for (p in players) {
            hash += "|" + p.username + ":" + p.level + ":" + p.cell + ":" + p.pad;
        }

        if (hash == _lastPlayerHash) return;
        _lastPlayerHash = hash;

        refreshPlayers();
    }
}
#else
class TopBarPlayersPanel {}
#end
