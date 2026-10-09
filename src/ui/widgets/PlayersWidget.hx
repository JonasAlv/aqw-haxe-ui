package ui.widgets;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiLogger;
import ui.ApiDashboardModal;
import ui.ApiMenus;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.Overlay;
import ui.prompts.ApiPromptModal;
import com.aqwapi.utils.ApiConfig;

typedef MapPlayerInfo = {
    username:String,
    level:Int,
    cell:String,
    pad:String,
    isSelf:Bool,
    hp:Int,
    maxHp:Int
};

/**
 * Compact Area Players Widget.
 *
 * Displays a sleek, border-styled pill showing:
 * "X player(s) in <map>"
 *
 * Clicking toggles the compact list of players either below or above
 * depending on screen room. Draggable with persistent coordinates.
 */
class PlayersWidget {
    private static var _pocket:Dynamic = null;
    private static var _overlay:Overlay = null;
    private static var _widget:Sprite = null;
    private static var _initialized:Bool = false;

    // Component references
    private static var _bg:Sprite = null;
    private static var _headerBar:Sprite = null;
    private static var _headerCountTxt:TextField = null;
    private static var _bodyContainer:Sprite = null;
    private static var _listContainer:Sprite = null;
    private static var _listContent:Sprite = null;
    private static var _listMask:Shape = null;

    // State
    private static var _isCollapsed:Bool = true;
    private static var _isUpward:Bool = false;
    private static var _currentW:Float = 150.0;
    private static var _lastPlayerHash:String = "";

    // Scrolling state
    private static var _isDraggingList:Bool = false;
    private static var _dragStartY:Float = 0;
    private static var _dragStartContentY:Float = 0;

    private static inline var COMPACT_H:Float = 24.0;
    private static inline var ROW_H:Float = 20.0;
    private static inline var MAX_VISIBLE_ROWS:Int = 6;

    public static function openConfigModal():Void {
        // Configuration modal removed per user request: "will have no config buttom anymore, will just be it"
    }

    private static function clampToScreen():Void {
        if (_widget == null) return;
        var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);
        if (theStage == null) return;
        var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960.0;
        var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550.0;

        // X clamping
        if (_widget.x > sw - _currentW - ApiStyle.SCREEN_MARGIN) {
            _widget.x = Math.max(ApiStyle.SCREEN_MARGIN, sw - _currentW - ApiStyle.SCREEN_MARGIN);
        }
        if (_widget.x < ApiStyle.SCREEN_MARGIN) {
            _widget.x = ApiStyle.SCREEN_MARGIN;
        }

        // Y clamping
        if (_isCollapsed) {
            if (_widget.y > sh - COMPACT_H - ApiStyle.SCREEN_MARGIN) {
                _widget.y = Math.max(ApiStyle.SCREEN_MARGIN, sh - COMPACT_H - ApiStyle.SCREEN_MARGIN);
            }
            if (_widget.y < ApiStyle.SCREEN_MARGIN) {
                _widget.y = ApiStyle.SCREEN_MARGIN;
            }
        } else {
            var listH = getVisibleListHeight();
            if (_isUpward) {
                if (_widget.y - (listH + 4) < ApiStyle.SCREEN_MARGIN) {
                    _widget.y = ApiStyle.SCREEN_MARGIN + (listH + 4);
                }
                if (_widget.y + COMPACT_H > sh - ApiStyle.SCREEN_MARGIN) {
                    _widget.y = Math.max(ApiStyle.SCREEN_MARGIN + (listH + 4), sh - COMPACT_H - ApiStyle.SCREEN_MARGIN);
                }
            } else {
                var totalH = COMPACT_H + listH + 4;
                if (_widget.y + totalH > sh - ApiStyle.SCREEN_MARGIN) {
                    _widget.y = Math.max(ApiStyle.SCREEN_MARGIN, sh - totalH - ApiStyle.SCREEN_MARGIN);
                }
                if (_widget.y < ApiStyle.SCREEN_MARGIN) {
                    _widget.y = ApiStyle.SCREEN_MARGIN;
                }
            }
        }

        ApiConfig.setInt("api_widget_players_x", Math.round(_widget.x));
        ApiConfig.setInt("api_widget_players_y", Math.round(_widget.y));
    }

    public static function init(pocket:Dynamic, overlay:Overlay):Void {
        if (_initialized) return;
        _initialized = true;
        _pocket = pocket;
        _overlay = overlay;

        var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);

        var attach = function(stageObj:Dynamic):Void {
            if (stageObj == null || _widget != null) return;
            buildWidget(stageObj);
        };

        if (theStage != null) {
            attach(theStage);
        } else if (_overlay != null) {
            _overlay.addEventListener(Event.ADDED_TO_STAGE, function(ev:Event):Void {
                if (_overlay.stage != null && _widget == null) {
                    attach(_overlay.stage);
                }
            });
        }
    }

    private static function buildWidget(theStage:Dynamic):Void {
        _widget = new Sprite();
        _widget.name = "PlayersWidget";

        // Restore saved position
        var savedX = ApiConfig.getInt("api_widget_players_x", -1);
        var savedY = ApiConfig.getInt("api_widget_players_y", -1);
        var defaultX:Float = 180;
        var defaultY:Float = 330;

        var initX:Float = (savedX >= 0) ? savedX : defaultX;
        var initY:Float = (savedY >= 0) ? savedY : defaultY;

        var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960.0;
        var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550.0;
        if (initX > sw - _currentW - ApiStyle.SCREEN_MARGIN) initX = sw - _currentW - ApiStyle.SCREEN_MARGIN;
        if (initY > sh - COMPACT_H - ApiStyle.SCREEN_MARGIN) initY = sh - COMPACT_H - ApiStyle.SCREEN_MARGIN;
        if (initX < ApiStyle.SCREEN_MARGIN) initX = ApiStyle.SCREEN_MARGIN;
        if (initY < ApiStyle.SCREEN_MARGIN) initY = ApiStyle.SCREEN_MARGIN;

        _widget.x = initX;
        _widget.y = initY;

        // Default state is collapsed pill (like uploaded image)
        _isCollapsed = ApiConfig.getBool("api_widget_players_collapsed", true);

        // 1. Background plate
        _bg = new Sprite();
        _widget.addChild(_bg);

        // 2. Header Bar (Drag & Click-to-toggle zone)
        _headerBar = new Sprite();
        _headerBar.buttonMode = true;
        _headerBar.useHandCursor = true;
        _widget.addChild(_headerBar);

        // 3. Header Count Text ("1 player in classhall")
        _headerCountTxt = new TextField();
        var countFmt = new TextFormat(ApiStyle.FONT_FAMILY, 10, 0xB0B4C3, false);
        countFmt.align = TextFormatAlign.CENTER;
        _headerCountTxt.defaultTextFormat = countFmt;
        _headerCountTxt.selectable = false;
        _headerCountTxt.mouseEnabled = false;
        _headerBar.addChild(_headerCountTxt);

        _headerBar.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            _bg.alpha = 1.0;
        });
        _headerBar.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            _bg.alpha = 0.94;
        });

        // 4. Body Container
        _bodyContainer = new Sprite();
        _bodyContainer.visible = !_isCollapsed;
        _widget.addChild(_bodyContainer);

        setupBodyComponents(theStage);
        setupDragging(theStage);

        // 5. Live frame state loop
        _widget.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            var inGame = ApiMenus.isInGame();
            if (!inGame) {
                _widget.visible = false;
                return;
            }
            var isEnabled = ApiConfig.getBool("api_widget_players_enabled", true);
            if (!isEnabled) {
                _widget.visible = false;
                return;
            }
            var isBlocked:Bool = isBlockedByWindowOrModal();
            if (isBlocked) {
                _widget.visible = false;
                return;
            }
            _widget.visible = true;
            updateLivePlayers();
        });

        updateLayout();
        theStage.addChild(_widget);
    }

    public static function isBlockedByWindowOrModal():Bool {
        if (_overlay != null && _overlay.currentFrameLabel == "Panel") return true;
        if (ApiDashboardModal.isOpen()) return true;
        if (ApiPromptModal.isOpen()) return true;
        try {
            if (Api.game != null && Api.game.ui != null && Api.game.ui.mcPopup != null) {
                var cur = Std.string(Api.game.ui.mcPopup.currentLabel);
                if (cur != null && cur != "" && cur != "Init" && cur != "Idle" && cur != "null") return true;
            }
        } catch (_:Dynamic) {}
        return false;
    }

    private static function setupBodyComponents(theStage:Dynamic):Void {
        _listContainer = new Sprite();
        _bodyContainer.addChild(_listContainer);

        _listMask = new Shape();
        _listContainer.addChild(_listMask);

        _listContent = new Sprite();
        _listContent.mask = _listMask;
        _listContainer.addChild(_listContent);

        // Touch drag scrolling for mobile
        _listContainer.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            e.stopPropagation();
            _isDraggingList = true;
            _dragStartY = e.stageY;
            _dragStartContentY = _listContent.y;
        });

        theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (_isDraggingList) {
                var dy = e.stageY - _dragStartY;
                var newY = _dragStartContentY + dy;
                var curListH = getVisibleListHeight();
                var maxScroll = curListH - _listContent.height;
                if (maxScroll > 0) maxScroll = 0;
                if (newY > 0) newY = 0;
                if (newY < maxScroll) newY = maxScroll;
                _listContent.y = newY;
            }
        });

        theStage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            _isDraggingList = false;
        });

        // Mouse wheel scroll for desktop
        _listContainer.addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent):Void {
            var curListH = getVisibleListHeight();
            if (_listContent.height <= curListH) return;
            var maxScroll = curListH - _listContent.height;
            var nextY = _listContent.y + (e.delta * 16);
            if (nextY > 0) nextY = 0;
            if (nextY < maxScroll) nextY = maxScroll;
            _listContent.y = nextY;
        });
    }

    private static function getVisibleListHeight():Float {
        var players = getMapPlayers();
        var rowCount = players.length > 0 ? players.length : 1;
        var visibleCount = (rowCount > MAX_VISIBLE_ROWS) ? MAX_VISIBLE_ROWS : rowCount;
        return visibleCount * ROW_H;
    }

    public static function getMapPlayers():Array<MapPlayerInfo> {
        var result:Array<MapPlayerInfo> = [];
        var g:Dynamic = Api.game;
        if (g == null || g.world == null) return result;

        var world:Dynamic = g.world;
        var myName:String = (Api.player != null && Api.player.username != null) ? Api.player.username.toLowerCase() : "";
        var uoTree:Dynamic = world.uoTree;
        var areaUsers:Dynamic = world.areaUsers;
        var seen:Map<String, Bool> = new Map<String, Bool>();

        // 1. Process users reported in areaUsers
        if (areaUsers != null) {
            var userLen:Int = 0;
            try { userLen = (areaUsers.length != null) ? Std.int(areaUsers.length) : 0; } catch (_:Dynamic) {}
            for (i in 0...userLen) {
                var u:Dynamic = null;
                try { u = untyped areaUsers[i]; } catch (_:Dynamic) {}
                if (u == null) continue;
                var uName = Std.string(u);
                if (uName == "" || seen.exists(uName.toLowerCase())) continue;
                seen.set(uName.toLowerCase(), true);

                var leaf:Dynamic = null;
                if (uoTree != null) {
                    try { leaf = Reflect.field(uoTree, uName.toLowerCase()); } catch (_:Dynamic) {}
                    if (leaf == null) {
                        try { leaf = untyped uoTree[uName.toLowerCase()]; } catch (_:Dynamic) {}
                    }
                }

                var lvl:Int = (leaf != null && leaf.intLevel != null) ? Std.int(leaf.intLevel) : 1;
                var cell:String = (leaf != null && leaf.strFrame != null) ? Std.string(leaf.strFrame) : "";
                var pad:String = (leaf != null && leaf.strPad != null) ? Std.string(leaf.strPad) : "";
                var hp:Int = (leaf != null && leaf.intHP != null) ? Std.int(leaf.intHP) : 0;
                var maxHp:Int = (leaf != null && leaf.intHPMax != null) ? Std.int(leaf.intHPMax) : 0;

                result.push({
                    username: uName,
                    level: lvl,
                    cell: cell,
                    pad: pad,
                    isSelf: (uName.toLowerCase() == myName),
                    hp: hp,
                    maxHp: maxHp
                });
            }
        }

        // 2. Also check active avatars in room
        if (world.avatars != null) {
            var avLen:Int = 0;
            try { avLen = (world.avatars.length != null) ? Std.int(world.avatars.length) : 0; } catch (_:Dynamic) {}
            for (i in 0...avLen) {
                var av:Dynamic = null;
                try { av = untyped world.avatars[i]; } catch (_:Dynamic) {}
                if (av == null || av.dataLeaf == null) continue;
                var avName = (av.pnm != null) ? Std.string(av.pnm) : ((av.dataLeaf.strUsername != null) ? Std.string(av.dataLeaf.strUsername) : "");
                if (avName == "" || seen.exists(avName.toLowerCase())) continue;
                seen.set(avName.toLowerCase(), true);

                var lvl:Int = (av.dataLeaf.intLevel != null) ? Std.int(av.dataLeaf.intLevel) : 1;
                var cell:String = (av.strFrame != null) ? Std.string(av.strFrame) : ((world.strFrame != null) ? Std.string(world.strFrame) : "");
                var pad:String = (av.strPad != null) ? Std.string(av.strPad) : "";
                var hp:Int = (av.dataLeaf.intHP != null) ? Std.int(av.dataLeaf.intHP) : 0;
                var maxHp:Int = (av.dataLeaf.intHPMax != null) ? Std.int(av.dataLeaf.intHPMax) : 0;

                result.push({
                    username: avName,
                    level: lvl,
                    cell: cell,
                    pad: pad,
                    isSelf: (avName.toLowerCase() == myName),
                    hp: hp,
                    maxHp: maxHp
                });
            }
        }

        // Sort: Self first, then alphabetically
        result.sort(function(a, b) {
            if (a.isSelf) return -1;
            if (b.isSelf) return 1;
            return a.username.toLowerCase() < b.username.toLowerCase() ? -1 : 1;
        });

        return result;
    }

    private static var _tickCounter:Int = 0;

    private static function updateLivePlayers():Void {
        _tickCounter++;
        // Throttle player scan to every 8 frames (~7.5 times/sec at 60 FPS) unless initial scan
        if (_lastPlayerHash != "" && _tickCounter % 8 != 0) return;

        var players = getMapPlayers();
        var mapName = (Api.map != null && Api.map.name != null) ? Api.map.name : "";

        // Build state signature
        var hash = mapName + ":" + players.length;
        for (p in players) {
            hash += "|" + p.username + ":" + p.level + ":" + p.cell + ":" + p.pad;
        }

        if (hash == _lastPlayerHash) return;
        _lastPlayerHash = hash;

        // Format pill text exactly as user requested: "1 player in classhall"
        var countStr = (players.length == 1) ? "1 player in " : (players.length + " players in ");
        if (mapName != "") {
            _headerCountTxt.htmlText = "<font color='#B0B4C3'>" + countStr + "</font><font color='#FFE100'>" + mapName + "</font>";
        } else {
            _headerCountTxt.htmlText = "<font color='#B0B4C3'>" + countStr + "</font>";
        }

        var textW:Float = _headerCountTxt.textWidth;
        var neededW:Float = Math.max(140.0, Math.ceil(textW) + 24.0);
        _currentW = neededW;

        updateLayout();

        // Rebuild list rows
        while (_listContent.numChildren > 0) _listContent.removeChildAt(0);

        var curY:Float = 0;
        var rowW:Float = _currentW - 4;

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

        // Scroll clamp
        var curListH = getVisibleListHeight();
        var maxScroll = curListH - _listContent.height;
        if (maxScroll > 0) maxScroll = 0;
        if (_listContent.y < maxScroll) _listContent.y = maxScroll;
        if (_listContent.y > 0) _listContent.y = 0;
    }

    private static function createPlayerRow(w:Float, h:Float, player:MapPlayerInfo, altBg:Bool):Sprite {
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

        // 1. Level (Green, bold, 9pt)
        var lvlTxt = new TextField();
        var lvlFmt = new TextFormat(ApiStyle.FONT_FAMILY, 9, 0x2ECC71, true);
        lvlTxt.defaultTextFormat = lvlFmt;
        lvlTxt.text = Std.string(player.level);
        lvlTxt.x = 4;
        lvlTxt.y = 1;
        lvlTxt.width = 16;
        lvlTxt.height = 16;
        lvlTxt.selectable = false;
        lvlTxt.mouseEnabled = false;
        row.addChild(lvlTxt);

        // 2. Player Name (White or Cyan if self, 9pt)
        var nameTxt = new TextField();
        var nameColor = player.isSelf ? ApiStyle.COLOR_ACCENT_PRIMARY : ApiStyle.COLOR_TEXT_PRIMARY;
        var nameFmt = new TextFormat(ApiStyle.FONT_FAMILY, 9, nameColor, player.isSelf);
        nameTxt.defaultTextFormat = nameFmt;
        nameTxt.text = player.username;
        nameTxt.x = 21;
        nameTxt.y = 1;
        nameTxt.height = 16;
        nameTxt.selectable = false;
        nameTxt.mouseEnabled = false;

        if (player.isSelf) {
            nameTxt.width = w - 21 - 32;
            row.addChild(nameTxt);

            // "(You)" indicator
            var selfLbl = new TextField();
            var sFmt = new TextFormat(ApiStyle.FONT_FAMILY, 8, ApiStyle.COLOR_ACCENT_PRIMARY, true);
            sFmt.align = TextFormatAlign.RIGHT;
            selfLbl.defaultTextFormat = sFmt;
            selfLbl.text = "(You)";
            selfLbl.x = w - 34;
            selfLbl.y = 2;
            selfLbl.width = 30;
            selfLbl.height = 14;
            selfLbl.selectable = false;
            selfLbl.mouseEnabled = false;
            row.addChild(selfLbl);
        } else {
            var btnW:Float = 28.0;
            var btnH:Float = 14.0;
            var btnX:Float = w - btnW - 3;

            // Cell text if there is enough room (e.g. w >= 155)
            if (w >= 155 && player.cell != "") {
                var cellTxt = new TextField();
                var cFmt = new TextFormat(ApiStyle.FONT_FAMILY, 8, ApiStyle.COLOR_TEXT_MUTED);
                cFmt.align = TextFormatAlign.RIGHT;
                cellTxt.defaultTextFormat = cFmt;
                cellTxt.text = player.cell;
                cellTxt.x = btnX - 32;
                cellTxt.y = 2;
                cellTxt.width = 30;
                cellTxt.height = 14;
                cellTxt.selectable = false;
                cellTxt.mouseEnabled = false;
                row.addChild(cellTxt);

                nameTxt.width = cellTxt.x - 23;
            } else {
                nameTxt.width = btnX - 23;
            }
            row.addChild(nameTxt);

            // "Goto" Mini Button
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
                gotoPlayer(player);
            });
            row.addChild(btnGoto);
        }

        // Clicking row opens context menu
        row.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            openPlayerMenu(player);
        });

        return row;
    }

    public static function gotoPlayer(player:MapPlayerInfo):Void {
        if (player == null || player.username == "") return;

        // 1. Direct cell/pad jump if player's room is known in this map
        if (player.cell != "" && Api.map != null) {
            var targetPad = (player.pad != "") ? player.pad : "Spawn";
            Api.map.jump(player.cell, targetPad, true, true);
            ApiNotificationManager.notify("Jumped to " + player.username + " in " + player.cell + " [" + targetPad + "]");
            return;
        }

        // 2. Native world.goto(username)
        var g:Dynamic = Api.game;
        if (g != null && g.world != null && g.world.goto != null) {
            try {
                g.world.goto(player.username);
                ApiNotificationManager.notify("Goto: " + player.username);
                return;
            } catch (_:Dynamic) {}
        }

        // 3. Server packet fallback
        if (Api.transport != null) {
            Api.transport.send("zm", "cmd", ["goto", player.username.toLowerCase()]);
            ApiNotificationManager.notify("Sent goto packet for: " + player.username);
        }
    }

    private static function openPlayerMenu(player:MapPlayerInfo):Void {
        var g:Dynamic = Api.game;
        if (g == null || g.ui == null || g.ui.cMenu == null) {
            ApiNotificationManager.notify("Player: " + player.username + " (Lv. " + player.level + ")");
            return;
        }

        try {
            var userObj:Dynamic = {
                "strUsername": player.username,
                "ID": player.username
            };
            if (player.isSelf) {
                g.ui.cMenu.fOpenWith("self", userObj);
            } else {
                g.ui.cMenu.fOpenWith("user", userObj);
            }
        } catch (_:Dynamic) {
            ApiNotificationManager.notify("Player: " + player.username + " (Lv. " + player.level + ")");
        }
    }

    public static function toggleCollapse():Void {
        _isCollapsed = !_isCollapsed;
        ApiConfig.setBool("api_widget_players_collapsed", _isCollapsed);
        updateLayout();
        clampToScreen();
    }

    private static function updateLayout():Void {
        if (_widget == null) return;

        var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);
        var sw:Float = (theStage != null && theStage.stageWidth > 0) ? theStage.stageWidth : 960.0;
        var sh:Float = (theStage != null && theStage.stageHeight > 0) ? theStage.stageHeight : 550.0;

        var textW:Float = (_headerCountTxt != null) ? _headerCountTxt.textWidth : 100.0;
        _currentW = Math.max(140.0, Math.ceil(textW) + 24.0);

        _headerCountTxt.width = _currentW;
        _headerCountTxt.x = 0;
        _headerCountTxt.y = 3;
        _headerCountTxt.height = 18;

        _headerBar.graphics.clear();
        _headerBar.graphics.beginFill(0x000000, 0.0);
        _headerBar.graphics.drawRect(0, 0, _currentW, COMPACT_H);
        _headerBar.graphics.endFill();

        if (_isCollapsed) {
            _bodyContainer.visible = false;

            _bg.graphics.clear();
            _bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.92);
            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.9);
            _bg.graphics.drawRoundRect(0, 0, _currentW, COMPACT_H, 4, 4);
            _bg.graphics.endFill();

            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.4);
            _bg.graphics.moveTo(3, 1);
            _bg.graphics.lineTo(_currentW - 3, 1);
        } else {
            _bodyContainer.visible = true;

            var listH:Float = getVisibleListHeight();

            // Determine open direction based on available room
            var spaceBelow:Float = sh - (_widget.y + COMPACT_H);
            var spaceAbove:Float = _widget.y;
            _isUpward = (spaceAbove > spaceBelow);

            var rowW:Float = _currentW - 4;

            _listMask.graphics.clear();
            _listMask.graphics.beginFill(0xFF0000);
            _listMask.graphics.drawRoundRect(0, 0, rowW, listH, 3, 3);
            _listMask.graphics.endFill();

            if (_isUpward) {
                _bodyContainer.x = 2;
                _bodyContainer.y = -(listH + 2);

                _bg.graphics.clear();
                _bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.94);
                _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.95);
                _bg.graphics.drawRoundRect(0, -(listH + 4), _currentW, COMPACT_H + listH + 4, 4, 4);
                _bg.graphics.endFill();

                // Divider line between list and pill
                _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.45);
                _bg.graphics.moveTo(3, 0);
                _bg.graphics.lineTo(_currentW - 3, 0);

                // Top bevel highlight
                _bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.4);
                _bg.graphics.moveTo(3, -(listH + 3));
                _bg.graphics.lineTo(_currentW - 3, -(listH + 3));
            } else {
                _bodyContainer.x = 2;
                _bodyContainer.y = COMPACT_H + 2;

                _bg.graphics.clear();
                _bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.94);
                _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.95);
                _bg.graphics.drawRoundRect(0, 0, _currentW, COMPACT_H + listH + 4, 4, 4);
                _bg.graphics.endFill();

                // Divider line between pill and list
                _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.45);
                _bg.graphics.moveTo(3, COMPACT_H + 1);
                _bg.graphics.lineTo(_currentW - 3, COMPACT_H + 1);

                // Top bevel highlight
                _bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.4);
                _bg.graphics.moveTo(3, 1);
                _bg.graphics.lineTo(_currentW - 3, 1);
            }
        }
    }

    private static function setupDragging(theStage:Dynamic):Void {
        var isDragging:Bool = false;
        var hasDragged:Bool = false;
        var startDownX:Float = 0;
        var startDownY:Float = 0;
        var dragStartX:Float = 0;
        var dragStartY:Float = 0;

        _headerBar.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            isDragging = true;
            hasDragged = false;
            startDownX = e.stageX;
            startDownY = e.stageY;
            _widget.cacheAsBitmap = true;
            dragStartX = e.stageX - _widget.x;
            dragStartY = e.stageY - _widget.y;
            theStage.setChildIndex(_widget, theStage.numChildren - 1);
        });

        theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (isDragging) {
                var dx = e.stageX - startDownX;
                var dy = e.stageY - startDownY;
                if (Math.abs(dx) > 4 || Math.abs(dy) > 4) {
                    hasDragged = true;
                }
                if (hasDragged) {
                    var nx:Float = Math.round(e.stageX - dragStartX);
                    var ny:Float = Math.round(e.stageY - dragStartY);
                    var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960.0;
                    var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550.0;

                    if (nx < ApiStyle.SCREEN_MARGIN) nx = ApiStyle.SCREEN_MARGIN;
                    if (ny < ApiStyle.SCREEN_MARGIN) ny = ApiStyle.SCREEN_MARGIN;
                    if (nx > sw - _currentW - ApiStyle.SCREEN_MARGIN) nx = sw - _currentW - ApiStyle.SCREEN_MARGIN;
                    if (ny > sh - COMPACT_H - ApiStyle.SCREEN_MARGIN) ny = sh - COMPACT_H - ApiStyle.SCREEN_MARGIN;

                    _widget.x = nx;
                    _widget.y = ny;
                }
            }
        });

        theStage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            if (isDragging) {
                isDragging = false;
                _widget.cacheAsBitmap = true;
                if (hasDragged) {
                    clampToScreen();
                } else {
                    toggleCollapse();
                }
            }
        });
    }

    public static function reloadFromConfig():Void {
        if (_widget == null) return;
        var savedX = ApiConfig.getInt("api_widget_players_x", -1);
        var savedY = ApiConfig.getInt("api_widget_players_y", -1);
        _widget.x = (savedX >= 0) ? savedX : 180;
        _widget.y = (savedY >= 0) ? savedY : 330;
        _isCollapsed = ApiConfig.getBool("api_widget_players_collapsed", true);
        _widget.visible = isWidgetEnabled();
        updateLayout();
        clampToScreen();
    }

    public static function isWidgetEnabled():Bool {
        return ApiConfig.getBool("api_widget_players_enabled", false);
    }

    public static function setWidgetEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_widget_players_enabled", enabled);
        if (_widget != null) _widget.visible = enabled;
    }

    public static function resetPosition():Void {
        ApiConfig.setInt("api_widget_players_x", 180);
        ApiConfig.setInt("api_widget_players_y", 330);
        if (_widget != null) {
            _widget.x = 180;
            _widget.y = 330;
        }
    }
}
#else
class PlayersWidget {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isWidgetEnabled():Bool return false;
    public static function setWidgetEnabled(enabled:Bool):Void {}
    public static function resetPosition():Void {}
    public static function reloadFromConfig():Void {}
    public static function openConfigModal():Void {}
}
#end
