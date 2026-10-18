package ui.frames;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.filters.BitmapFilter;
import flash.filters.GlowFilter;
import flash.geom.Rectangle;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.Lib;
import com.aqwapi.Api;
import ui.ApiDashboardModal;
import ui.ApiMenus;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import com.aqwapi.utils.ApiConfig;
import com.aqwapi.utils.ApiUtils;

/**
 * QuestUnitFrame:
 * Modern ElvUI-style quest tracker docked at screen mid-right.
 * Replaces the native bulky AQLite Quest Tracker (QTrackerMC) with a sleek,
 * portrait-less, low-overhead draggable panel showing:
 * - Clean header with active quest count and collapse toggle
 * - Quest names in crisp white / emerald green when ready to turn in
 * - Click quest title to open native quest details / turn-in window
 * - Indented requirements with live [current / required] progress
 * - Green checkmarks (✓) when individual objectives or full quests are complete
 * - Draggable with persistent position and reset support
 */
class QuestUnitFrame {
    // =========================================================================
    // SIZING DEFINITIONS (ElvUI Style)
    // =========================================================================
    public static inline var DEFAULT_X:Float            = 730.0; // Mid-right edge (960 - 210 - 20)
    public static inline var DEFAULT_Y:Float            = 180.0; // Mid vertical start
    public static inline var FRAME_W:Float              = 210.0; // Compact readable width
    public static inline var HEADER_H:Float             = 20.0;  // Clean header height
    public static inline var MAX_CONTENT_H:Float        = 280.0; // Max vertical content height before scroll
    public static inline var CORNER_RADIUS:Float        = 3.0;   // Subtle rounded plate
    public static inline var PADDING_X:Float            = 7.0;   // Content margin left/right
    public static inline var PADDING_Y:Float            = 5.0;   // Content margin top/bottom

    // Config Keys
    public static inline var CONFIG_ENABLED:String      = "api_frame_quest_enabled";
    public static inline var CONFIG_POS_X:String        = "api_frame_quest_x";
    public static inline var CONFIG_POS_Y:String        = "api_frame_quest_y";
    public static inline var CONFIG_COLLAPSED:String    = "api_frame_quest_collapsed";
    public static inline var CONFIG_HIDE_PROGRESS_TEXT:String = "api_frame_quest_hide_progress_text";

    // Colors
    public static inline var COLOR_BG:Int               = 0x0A0B10; // Deep obsidian background
    public static inline var COLOR_BORDER:Int           = 0x1E222D; // Crisp slate hairline border
    public static inline var COLOR_HEADER_BG:Int        = 0x12141D; // Elevated header surface
    public static inline var COLOR_HEADER_BORDER:Int    = 0x1E222D; // Header separator line
    public static inline var COLOR_HEADER_TXT:Int       = 0x94A3B8; // Slate header label
    public static inline var COLOR_QUEST_NAME:Int       = 0xF8FAFC; // Crisp light quest title
    public static inline var COLOR_QUEST_COMPLETE:Int   = 0x22C55E; // Emerald green when complete
    public static inline var COLOR_OBJ_NAME:Int         = 0xCBD5E1; // Light gray requirement text
    public static inline var COLOR_OBJ_MUTED:Int        = 0x64748B; // Slate bullet / separator
    public static inline var COLOR_OBJ_DONE:Int         = 0x22C55E; // Green checkmark & count
    public static inline var COLOR_OBJ_PROG:Int         = 0xF59E0B; // Amber in-progress count
    public static inline var COLOR_SEP:Int              = 0x1A1D27; // Divider between multiple quests

    private static var TEXT_OUTLINE:Array<BitmapFilter> = [new GlowFilter(0x000000, 1.0, 2, 2, 4, 1)];

    // State & UI References
    private static var _pocket:Dynamic                  = null;
    private static var _overlay:Dynamic                 = null;
    private static var _widget:Sprite                   = null;
    private static var _initialized:Bool                = false;

    private static var _bg:Sprite                       = null;
    private static var _header:Sprite                   = null;
    private static var _headerBg:Shape                  = null;
    private static var _headerTxt:TextField             = null;
    private static var _collapseBtn:TextField           = null;

    private static var _contentContainer:Sprite         = null;
    private static var _content:Sprite                  = null;
    private static var _contentMask:Shape               = null;

    private static var _isCollapsed:Bool                = false;
    private static var _scrollY:Float                   = 0.0;
    private static var _lastSignature:String            = "";
    private static var _lastTick:Float                  = 0.0;
    private static var _hooksInstalled:Bool             = false;
    private static var _addUpdateHooked:Bool            = false;
    private static var RE_PROGRESS_TEXT:EReg            = new EReg("\\s+\\d+/\\d+$", "");

    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {
        if (_initialized) return;
        _initialized = true;
        _pocket = pocket;
        _overlay = overlay;

        var theStage:Dynamic = (_pocket != null && Std.isOfType(_pocket, Stage))
            ? _pocket
            : ((_pocket != null && _pocket.stage != null)
                ? _pocket.stage
                : (_overlay != null && _overlay.stage != null ? _overlay.stage : null));

        var attach = function(stageObj:Dynamic):Void {
            if (stageObj == null || _widget != null) return;
            buildFrame(stageObj);
        };

        if (theStage != null) {
            attach(theStage);
        } else if (_overlay != null) {
            _overlay.addEventListener(Event.ADDED_TO_STAGE, function(_:Event):Void {
                if (_overlay.stage != null && _widget == null) {
                    attach(_overlay.stage);
                }
            });
        }
    }

    private static function buildFrame(theStage:Dynamic):Void {
        _widget = new Sprite();
        _widget.name = "QuestUnitFrame";

        _isCollapsed = ApiConfig.getBool(CONFIG_COLLAPSED, false);

        // Position restoring
        var savedX = ApiConfig.getInt(CONFIG_POS_X, -1);
        var savedY = ApiConfig.getInt(CONFIG_POS_Y, -1);
        var initX:Float = (savedX >= 0) ? savedX : DEFAULT_X;
        var initY:Float = (savedY >= 0) ? savedY : DEFAULT_Y;

        var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
        var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
        if (initX > sw - FRAME_W - ApiStyle.SCREEN_MARGIN) initX = sw - FRAME_W - ApiStyle.SCREEN_MARGIN;
        if (initY > sh - 80 - ApiStyle.SCREEN_MARGIN) initY = sh - 80 - ApiStyle.SCREEN_MARGIN;
        if (initX < ApiStyle.SCREEN_MARGIN) initX = ApiStyle.SCREEN_MARGIN;
        if (initY < ApiStyle.SCREEN_MARGIN) initY = ApiStyle.SCREEN_MARGIN;

        _widget.x = initX;
        _widget.y = initY;

        // 1. Background Plate
        _bg = new Sprite();
        _bg.buttonMode = true;
        _bg.useHandCursor = true;
        _widget.addChild(_bg);

        // 2. Header Bar
        _header = new Sprite();
        _header.buttonMode = true;
        _header.useHandCursor = true;
        _widget.addChild(_header);

        _headerBg = new Shape();
        _header.addChild(_headerBg);

        _headerTxt = new TextField();
        var hFmt = new TextFormat(ApiStyle.FONT_FAMILY, 8.0, COLOR_HEADER_TXT, true);
        _headerTxt.defaultTextFormat = hFmt;
        _headerTxt.x = PADDING_X;
        _headerTxt.y = 2.0;
        _headerTxt.width = FRAME_W - 35;
        _headerTxt.height = HEADER_H;
        _headerTxt.selectable = false;
        _headerTxt.mouseEnabled = false;
        _headerTxt.filters = TEXT_OUTLINE;
        _headerTxt.text = "QUEST TRACKER";
        _header.addChild(_headerTxt);

        // Collapse Button ([-] / [+])
        _collapseBtn = new TextField();
        var cFmt = new TextFormat(ApiStyle.FONT_FAMILY, 8.5, COLOR_HEADER_TXT, true, false, false, null, null, TextFormatAlign.CENTER);
        _collapseBtn.defaultTextFormat = cFmt;
        _collapseBtn.x = FRAME_W - 22;
        _collapseBtn.y = 1.0;
        _collapseBtn.width = 18;
        _collapseBtn.height = HEADER_H;
        _collapseBtn.selectable = false;
        _collapseBtn.text = _isCollapsed ? "[+]" : "[-]";
        _collapseBtn.filters = TEXT_OUTLINE;
        _collapseBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            e.stopPropagation();
            _isCollapsed = !_isCollapsed;
            ApiConfig.setBool(CONFIG_COLLAPSED, _isCollapsed);
            _collapseBtn.text = _isCollapsed ? "[+]" : "[-]";
            _lastSignature = ""; // Force redraw
            updateQuestList();
        });
        _header.addChild(_collapseBtn);

        // 3. Content Container & Mask
        _contentContainer = new Sprite();
        _contentContainer.x = 0;
        _contentContainer.y = HEADER_H;
        _widget.addChild(_contentContainer);

        _content = new Sprite();
        _contentContainer.addChild(_content);

        _contentMask = new Shape();
        _contentContainer.addChild(_contentMask);
        _content.mask = _contentMask;

        // Mouse Wheel Scrolling
        _widget.addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent):Void {
            if (_isCollapsed) return;
            var maxScroll = Math.max(0, _content.height - MAX_CONTENT_H);
            if (maxScroll <= 0) return;
            _scrollY += (e.delta > 0 ? 24 : -24);
            if (_scrollY > 0) _scrollY = 0;
            if (_scrollY < -maxScroll) _scrollY = -maxScroll;
            _content.y = _scrollY;
        });

        // 5. EnterFrame Loop (Throttled update ~400ms + visibility sync + active notification sweeper)
        _widget.addEventListener(Event.ENTER_FRAME, function(_:Event):Void {
            var inGame = ApiMenus.isInGame();
            if (!inGame) {
                _widget.visible = false;
                return;
            }

            if (isHideProgressTextEnabled()) {
                try {
                    var g:Dynamic = Api.game;
                    if (g != null) {
                        if (g.litePreference != null && g.litePreference.data != null && g.litePreference.data.bQuestNotif != false) {
                            g.litePreference.data.bQuestNotif = false;
                        }
                        if (g.ui != null && g.ui.mcUpdates != null) {
                            installMcUpdatesListener();
                            sweepMcUpdates(g.ui.mcUpdates);
                        }
                    }
                } catch (_:Dynamic) {}
            }

            var isEnabled = isWidgetEnabled();
            if (!isEnabled) {
                _widget.visible = false;
                return;
            }

            var isPanelOpen:Bool = ApiDashboardModal.isOpen();
            _widget.visible = !isPanelOpen;

            if (_widget.visible) {
                syncNativeQuestTracker();
                var now = Lib.getTimer();
                if (now - _lastTick > 400.0) {
                    _lastTick = now;
                    updateQuestList();
                }
            }
        });

        // Initial update and add to stage
        updateQuestList();
        _widget.visible = isWidgetEnabled();
        theStage.addChild(_widget);

        // Initial sync of native tracker
        syncNativeQuestTracker();
    }

    // =========================================================================
    // NATIVE QUEST TRACKER REPLACEMENT & HOOKS
    // =========================================================================
    public static function syncNativeQuestTracker():Void {
        try {
            var g:Dynamic = Api.game;
            if (g == null || g.ui == null) return;

            var enabled = isWidgetEnabled();
            if (enabled) {
                // 1. Hide native QTrackerMC
                if (g.ui.mcQTracker != null) {
                    g.ui.mcQTracker.visible = false;
                    g.ui.mcQTracker.alpha = 0.0;
                    g.ui.mcQTracker.y = -9999;
                }

                // 2. Set litePreference bDisQTracker = true to prevent native popups
                if (g.litePreference != null && g.litePreference.data != null) {
                    if (g.litePreference.data.bDisQTracker != true) {
                        g.litePreference.data.bDisQTracker = true;
                    }
                    if (isHideProgressTextEnabled() && g.litePreference.data.bQuestNotif != false) {
                        g.litePreference.data.bQuestNotif = false;
                    }
                }

                // 3. Install hooks on mcQTracker
                installTrackerHooks();

                // 4. Hook mcUpdates listener if progress text hiding is enabled
                if (isHideProgressTextEnabled()) {
                    installMcUpdatesListener();
                    sweepMcUpdates(g.ui.mcUpdates);
                }
            }
        } catch (_:Dynamic) {}
    }

    private static function installTrackerHooks():Void {
        if (_hooksInstalled) return;
        var g:Dynamic = Api.game;
        if (g == null || g.ui == null || g.ui.mcQTracker == null) return;
        _hooksInstalled = true;

        var mcQ = g.ui.mcQTracker;

        // Hook mcQTracker.updateQuest
        if (Reflect.isFunction(mcQ.updateQuest)) {
            var origUpdate = mcQ.updateQuest;
            mcQ.updateQuest = function():Void {
                if (isWidgetEnabled()) {
                    requestUpdate();
                } else {
                    origUpdate();
                }
            };
        }

        // Hook mcQTracker.toggle
        if (Reflect.isFunction(mcQ.toggle)) {
            var origToggle = mcQ.toggle;
            mcQ.toggle = function():Void {
                if (isWidgetEnabled()) {
                    toggle();
                } else {
                    origToggle();
                }
            };
        }
    }

    public static function toggle():Void {
        if (_widget == null) return;
        var next = !_widget.visible;
        _widget.visible = next;
        if (next) requestUpdate();
    }

    public static function requestUpdate():Void {
        _lastSignature = ""; // Force rebuild on next tick or immediate
        updateQuestList();
    }

    // =========================================================================
    // QUEST DATA RENDERING (ElvUI Style)
    // =========================================================================
    private static function updateQuestList():Void {
        if (_widget == null) return;
        var g:Dynamic = Api.game;
        if (g == null || g.world == null) return;

        var questTree:Dynamic = g.world.questTree;
        var invTree:Dynamic = g.world.invTree;

        // 1. Gather active quests
        var activeList:Array<Dynamic> = [];
        var signatureParts:Array<String> = [];

        if (questTree != null) {
            var keys:Array<String> = Reflect.fields(questTree);
            for (key in keys) {
                var q:Dynamic = Reflect.field(questTree, key);
                if (q == null) continue;
                var st:Dynamic = q.status;
                if (st != null && st != "" && st != "null") {
                    var qId:Int = (q.QuestID != null) ? Std.int(q.QuestID) : ApiUtils.parseInt(key, 0);
                    activeList.push(q);

                    // Compute signature item counts
                    var part:String = qId + ":" + st;
                    if (q.turnin != null && Std.isOfType(q.turnin, Array)) {
                        var turnin:Array<Dynamic> = cast q.turnin;
                        for (t in turnin) {
                            if (t == null) continue;
                            var tId:Int = (t.ItemID != null) ? Std.int(t.ItemID) : 0;
                            var reqQty:Int = (t.iQty != null) ? Std.int(t.iQty) : 1;
                            var curQty:Int = 0;
                            if (invTree != null && tId > 0) {
                                var inv:Dynamic = Reflect.field(invTree, Std.string(tId));
                                if (inv != null && inv.iQty != null) curQty = Std.int(inv.iQty);
                            }
                            part += "," + tId + "=" + curQty + "/" + reqQty;
                        }
                    }
                    signatureParts.push(part);
                }
            }
        }

        var newSig = (_isCollapsed ? "C|" : "E|") + signatureParts.join(";");
        if (newSig == _lastSignature) return; // Zero allocations, state unchanged!
        _lastSignature = newSig;

        // 2. Update Header Count
        var count = activeList.length;
        _headerTxt.text = (count > 0) ? ("QUESTS (" + count + ")") : "QUEST TRACKER";

        // 3. Render Content
        // Clear previous items
        while (_content.numChildren > 0) {
            _content.removeChildAt(0);
        }

        if (_isCollapsed) {
            _contentContainer.visible = false;
            redrawPlate(HEADER_H);
            return;
        }

        _contentContainer.visible = true;
        var curY:Float = PADDING_Y;

        if (count == 0) {
            var emptyTxt = new TextField();
            var eFmt = new TextFormat(ApiStyle.FONT_FAMILY, 7.5, COLOR_OBJ_MUTED, false, true);
            emptyTxt.defaultTextFormat = eFmt;
            emptyTxt.x = PADDING_X;
            emptyTxt.y = curY;
            emptyTxt.width = FRAME_W - (PADDING_X * 2);
            emptyTxt.height = 16;
            emptyTxt.selectable = false;
            emptyTxt.mouseEnabled = false;
            emptyTxt.text = "No active quests";
            emptyTxt.filters = TEXT_OUTLINE;
            _content.addChild(emptyTxt);
            curY += 18;
        } else {
            for (i in 0...count) {
                var q:Dynamic = activeList[i];
                var qId:Int = (q.QuestID != null) ? Std.int(q.QuestID) : 0;
                var qName:String = (q.sName != null) ? Std.string(q.sName) : ("Quest #" + qId);
                var isCompleteStatus:Bool = (q.status == "c");

                // Check requirements
                var turninList:Array<Dynamic> = (q.turnin != null && Std.isOfType(q.turnin, Array)) ? cast q.turnin : [];
                var allReqsMet:Bool = (turninList.length > 0);

                var reqLines:Array<{name:String, cur:Int, req:Int, done:Bool}> = [];
                for (t in turninList) {
                    if (t == null) continue;
                    var tId:Int = (t.ItemID != null) ? Std.int(t.ItemID) : 0;
                    var reqQty:Int = (t.iQty != null) ? Std.int(t.iQty) : 1;
                    var curQty:Int = 0;
                    var itmName:String = "";

                    if (invTree != null && tId > 0) {
                        var inv:Dynamic = Reflect.field(invTree, Std.string(tId));
                        if (inv != null) {
                            if (inv.iQty != null) curQty = Std.int(inv.iQty);
                            if (inv.sName != null && inv.sName != "") itmName = Std.string(inv.sName);
                        }
                    }
                    if (itmName == "" && t.sName != null && t.sName != "") {
                        itmName = Std.string(t.sName);
                    } else if (itmName == "" && q.oItems != null) {
                        var oi:Dynamic = Reflect.field(q.oItems, Std.string(tId));
                        if (oi != null && oi.sName != null) itmName = Std.string(oi.sName);
                    }
                    if (itmName == "") itmName = "Item #" + tId;

                    var isDone = (curQty >= reqQty);
                    if (!isDone) allReqsMet = false;

                    reqLines.push({name: itmName, cur: curQty, req: reqQty, done: isDone});
                }

                var isReadyToTurnIn:Bool = isCompleteStatus || allReqsMet;

                // Quest Title Button & Line
                var titleBtn = new Sprite();
                titleBtn.buttonMode = true;
                titleBtn.useHandCursor = true;

                var titleTxt = new TextField();
                titleTxt.x = PADDING_X;
                titleTxt.y = curY;
                titleTxt.width = FRAME_W - (PADDING_X * 2);
                titleTxt.autoSize = TextFieldAutoSize.LEFT;
                titleTxt.wordWrap = true;
                titleTxt.selectable = false;
                titleTxt.mouseEnabled = false;
                titleTxt.filters = TEXT_OUTLINE;

                if (isReadyToTurnIn) {
                    titleTxt.htmlText = "<font face='" + ApiStyle.FONT_FAMILY + "' size='9' color='#22C55E'><b>" + qName + "</b></font> <font face='" + ApiStyle.FONT_FAMILY + "' size='7' color='#86EFAC'>[Complete]</font>";
                } else {
                    titleTxt.htmlText = "<font face='" + ApiStyle.FONT_FAMILY + "' size='9' color='#F8FAFC'><b>" + qName + "</b></font>";
                }

                // Click to open quest detail / turn in dialog
                var targetQId = qId;
                titleBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
                    try {
                        var world:Dynamic = (Api.game != null) ? Api.game.world : null;
                        if (world != null && Reflect.isFunction(world.showQuests)) {
                            world.showQuests(targetQId, "q");
                        }
                    } catch (_:Dynamic) {}
                });

                titleBtn.addChild(titleTxt);
                _content.addChild(titleBtn);
                curY += titleTxt.height + 2;

                // Requirements lines
                if (reqLines.length > 0) {
                    for (rl in reqLines) {
                        var reqTxt = new TextField();
                        reqTxt.x = PADDING_X + 6.0; // Indented
                        reqTxt.y = curY;
                        reqTxt.width = FRAME_W - (PADDING_X * 2) - 6.0;
                        reqTxt.autoSize = TextFieldAutoSize.LEFT;
                        reqTxt.wordWrap = true;
                        reqTxt.selectable = false;
                        reqTxt.mouseEnabled = false;
                        reqTxt.filters = TEXT_OUTLINE;

                        var bullet = rl.done ? "<font color='#22C55E'>✓ </font>" : "<font color='#64748B'>• </font>";
                        var nameColor = rl.done ? "#86EFAC" : "#CBD5E1";
                        var countColor = rl.done ? "#22C55E" : "#F59E0B";

                        reqTxt.htmlText = bullet + "<font face='" + ApiStyle.FONT_FAMILY + "' size='8' color='" + nameColor + "'>" + rl.name + "</font> " +
                                          "<font face='" + ApiStyle.FONT_FAMILY + "' size='8' color='" + countColor + "'>" + rl.cur + "/" + rl.req + "</font>";

                        _content.addChild(reqTxt);
                        curY += reqTxt.height + 1;
                    }
                } else {
                    // Step quest with no inventory items
                    var stepTxt = new TextField();
                    stepTxt.x = PADDING_X + 6.0;
                    stepTxt.y = curY;
                    stepTxt.width = FRAME_W - (PADDING_X * 2) - 6.0;
                    stepTxt.autoSize = TextFieldAutoSize.LEFT;
                    stepTxt.selectable = false;
                    stepTxt.mouseEnabled = false;
                    stepTxt.filters = TEXT_OUTLINE;

                    if (isReadyToTurnIn) {
                        stepTxt.htmlText = "<font face='" + ApiStyle.FONT_FAMILY + "' size='8' color='#22C55E'>✓ Ready to turn in</font>";
                    } else {
                        stepTxt.htmlText = "<font face='" + ApiStyle.FONT_FAMILY + "' size='8' color='#94A3B8'>• In Progress</font>";
                    }
                    _content.addChild(stepTxt);
                    curY += stepTxt.height + 1;
                }

                // Separator between quests
                if (i < count - 1) {
                    curY += 3;
                    var sep = new Shape();
                    sep.graphics.lineStyle(1.0, COLOR_SEP, 0.8);
                    sep.graphics.moveTo(PADDING_X, curY);
                    sep.graphics.lineTo(FRAME_W - PADDING_X, curY);
                    _content.addChild(sep);
                    curY += 4;
                }
            }
        }

        curY += PADDING_Y;

        // 4. Update Mask and Frame Height
        var contentH = curY;
        var viewH = Math.min(contentH, MAX_CONTENT_H);

        _contentMask.graphics.clear();
        _contentMask.graphics.beginFill(0xFFFFFF);
        _contentMask.graphics.drawRect(0, 0, FRAME_W, viewH);
        _contentMask.graphics.endFill();

        // Clamp scroll
        var maxScroll = Math.max(0, contentH - MAX_CONTENT_H);
        if (_scrollY < -maxScroll) _scrollY = -maxScroll;
        if (_scrollY > 0) _scrollY = 0;
        _content.y = _scrollY;

        redrawPlate(HEADER_H + viewH);
    }

    private static function redrawPlate(totalH:Float):Void {
        // Outer Frame Plate
        _bg.graphics.clear();
        _bg.graphics.beginFill(COLOR_BG, 0.88);
        _bg.graphics.lineStyle(1.0, COLOR_BORDER, 0.95);
        _bg.graphics.drawRoundRect(0, 0, FRAME_W, totalH, CORNER_RADIUS, CORNER_RADIUS);
        _bg.graphics.endFill();

        // Header Background
        _headerBg.graphics.clear();
        _headerBg.graphics.beginFill(COLOR_HEADER_BG, 0.95);
        _headerBg.graphics.drawRoundRectComplex(0, 0, FRAME_W, HEADER_H, CORNER_RADIUS, CORNER_RADIUS, 0, 0);
        _headerBg.graphics.endFill();

        // Header Divider Line
        _headerBg.graphics.lineStyle(1.0, COLOR_HEADER_BORDER, 0.95);
        _headerBg.graphics.moveTo(0, HEADER_H);
        _headerBg.graphics.lineTo(FRAME_W, HEADER_H);
    }

    // =========================================================================
    // DRAGGING SYSTEM
    // =========================================================================
    private static function setupDragging(theStage:Dynamic):Void {
        var isDragging:Bool = false;
        var hasDragged:Bool = false;
        var startDownX:Float = 0;
        var startDownY:Float = 0;
        var dragStartX:Float = 0;
        var dragStartY:Float = 0;

        var startDragHandler = function(e:MouseEvent):Void {
            isDragging = true;
            hasDragged = false;
            startDownX = e.stageX;
            startDownY = e.stageY;
            dragStartX = e.stageX - _widget.x;
            dragStartY = e.stageY - _widget.y;
            theStage.setChildIndex(_widget, theStage.numChildren - 1);
        };

        _header.addEventListener(MouseEvent.MOUSE_DOWN, startDragHandler);
        _bg.addEventListener(MouseEvent.MOUSE_DOWN, startDragHandler);

        theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (isDragging) {
                var dx = e.stageX - startDownX;
                var dy = e.stageY - startDownY;
                if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
                    hasDragged = true;
                }
                if (hasDragged) {
                    var nx:Float = Math.round(e.stageX - dragStartX);
                    var ny:Float = Math.round(e.stageY - dragStartY);
                    var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
                    var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;

                    if (nx < ApiStyle.SCREEN_MARGIN) nx = ApiStyle.SCREEN_MARGIN;
                    if (ny < ApiStyle.SCREEN_MARGIN) ny = ApiStyle.SCREEN_MARGIN;
                    if (nx > sw - FRAME_W - ApiStyle.SCREEN_MARGIN) nx = sw - FRAME_W - ApiStyle.SCREEN_MARGIN;
                    if (ny > sh - HEADER_H - ApiStyle.SCREEN_MARGIN) ny = sh - HEADER_H - ApiStyle.SCREEN_MARGIN;

                    _widget.x = nx;
                    _widget.y = ny;
                }
            }
        });

        theStage.addEventListener(MouseEvent.MOUSE_UP, function(_:MouseEvent):Void {
            if (isDragging) {
                isDragging = false;
                if (hasDragged) {
                    ApiConfig.setInt(CONFIG_POS_X, Math.round(_widget.x));
                    ApiConfig.setInt(CONFIG_POS_Y, Math.round(_widget.y));
                }
            }
        });
    }

    // =========================================================================
    // CONFIG & POSITION MANAGEMENT
    // =========================================================================
    public static function reloadFromConfig():Void {
        if (_widget == null) return;
        var savedX = ApiConfig.getInt(CONFIG_POS_X, -1);
        var savedY = ApiConfig.getInt(CONFIG_POS_Y, -1);
        _widget.x = (savedX >= 0) ? savedX : DEFAULT_X;
        _widget.y = (savedY >= 0) ? savedY : DEFAULT_Y;
        _widget.visible = isWidgetEnabled();
        syncNativeQuestTracker();
    }

    public static function isWidgetEnabled():Bool {
        return ApiConfig.getBool(CONFIG_ENABLED, false);
    }

    public static function setWidgetEnabled(enabled:Bool):Void {
        ApiConfig.setBool(CONFIG_ENABLED, enabled);
        if (_widget != null) _widget.visible = enabled;
        syncNativeQuestTracker();
    }

    public static function resetPosition():Void {
        ApiConfig.setInt(CONFIG_POS_X, Std.int(DEFAULT_X));
        ApiConfig.setInt(CONFIG_POS_Y, Std.int(DEFAULT_Y));
        if (_widget != null) {
            _widget.x = DEFAULT_X;
            _widget.y = DEFAULT_Y;
        }
    }

    public static inline function isHideProgressTextEnabled():Bool {
        return ApiConfig.getBool(CONFIG_HIDE_PROGRESS_TEXT, false);
    }

    public static function setHideProgressTextEnabled(enabled:Bool):Void {
        ApiConfig.setBool(CONFIG_HIDE_PROGRESS_TEXT, enabled);
        try {
            var g:Dynamic = Api.game;
            if (g != null) {
                if (g.litePreference != null && g.litePreference.data != null) {
                    if (enabled) {
                        g.litePreference.data.bQuestNotif = false;
                    }
                }
                if (enabled && g.ui != null && g.ui.mcUpdates != null) {
                    installMcUpdatesListener();
                    sweepMcUpdates(g.ui.mcUpdates);
                }
            }
        } catch (_:Dynamic) {}
    }

    private static var _mcUpdatesHooked:Bool = false;
    public static function installMcUpdatesListener():Void {
        if (_mcUpdatesHooked) return;
        var g:Dynamic = Api.game;
        if (g == null || g.ui == null || g.ui.mcUpdates == null) return;
        _mcUpdatesHooked = true;
        try {
            g.ui.mcUpdates.addEventListener(Event.ADDED, function(_:Event):Void {
                if (isHideProgressTextEnabled()) {
                    sweepMcUpdates(g.ui.mcUpdates);
                }
            });
        } catch (_:Dynamic) {}
    }

    public static function sweepMcUpdates(mcUpdates:Dynamic):Void {
        if (mcUpdates == null) return;
        try {
            var num:Int = (mcUpdates.numChildren != null) ? mcUpdates.numChildren : 0;
            var i:Int = num - 1;
            while (i >= 0) {
                var ch:Dynamic = mcUpdates.getChildAt(i);
                if (ch != null && ch != mcUpdates.uproto) {
                    var txt:String = null;
                    try {
                        if (ch.t1 != null && ch.t1.ti != null && ch.t1.ti.text != null) {
                            txt = Std.string(ch.t1.ti.text);
                        }
                    } catch (_:Dynamic) {}
                    if (txt != null && isQuestProgressNotification(txt)) {
                        ch.visible = false;
                        try { ch.stop(); } catch (_:Dynamic) {}
                        try { mcUpdates.removeChild(ch); } catch (_:Dynamic) {}
                    }
                }
                i--;
            }
        } catch (_:Dynamic) {}
    }

    public static function installAddUpdateHook():Void {
        if (_addUpdateHooked) return;
        var g:Dynamic = Api.game;
        if (g == null || !Reflect.isFunction(g.addUpdate)) return;
        _addUpdateHooked = true;

        var origAddUpdate = g.addUpdate;
        g.addUpdate = function(msg:String, ?isDanger:Bool = false):Void {
            if (isHideProgressTextEnabled() && isQuestProgressNotification(msg)) {
                return; // Suppress the onscreen yellow quest notification text!
            }
            origAddUpdate(msg, isDanger);
        };
    }

    private static function isQuestProgressNotification(msg:String):Bool {
        if (msg == null || msg == "") return false;
        var trim:String = StringTools.trim(msg);
        if (StringTools.endsWith(trim, " complete!")) return true;
        if (trim.indexOf(": ") != -1 && RE_PROGRESS_TEXT.match(trim)) return true;
        if (RE_PROGRESS_TEXT.match(trim)) return true;
        return false;
    }
}
#else
class QuestUnitFrame {
    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {}
    public static function isWidgetEnabled():Bool return false;
    public static function setWidgetEnabled(enabled:Bool):Void {}
    public static function isHideProgressTextEnabled():Bool return false;
    public static function setHideProgressTextEnabled(enabled:Bool):Void {}
    public static function resetPosition():Void {}
    public static function toggle():Void {}
    public static function requestUpdate():Void {}
    public static function reloadFromConfig():Void {}
    public static function syncNativeQuestTracker():Void {}
}
#end
