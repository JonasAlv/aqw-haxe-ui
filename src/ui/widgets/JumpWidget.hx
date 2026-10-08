package ui.widgets;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.FocusEvent;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiLogger;
import ui.ApiDashboardModal;
import ui.ApiMenus;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.Dropdown;
import ui.Overlay;
import util.HelperSetting;

/**
 * Standalone in-game Jump & Room Navigation Widget.
 *
 * Provides instant 1-tap controls for:
 * - Map Joiner: Text input to join any map or instance (with Enter key support)
 * - Room / Cell Dropdown: Lists all cells of current map, instant jump on select
 * - Pad Dropdown: Common pads (Spawn, Left, Right, Center, etc.) with forced autocorrect
 * - Current Button: Automatically populates dropdowns with current room and pad
 * - Jump Button: Instantly jumps to the selected room and pad
 * - Draggable, collapsible header with persistent positions and live map name badge
 */
class JumpWidget {
    private static var _pocket:Dynamic = null;
    private static var _overlay:Overlay = null;
    private static var _widget:Sprite = null;
    private static var _initialized:Bool = false;

    // Component references
    private static var _bg:Sprite = null;
    private static var _headerBar:Sprite = null;
    private static var _accentShape:Shape = null;
    private static var _headerTitleTxt:TextField = null;
    private static var _headerMapTxt:TextField = null;
    private static var _btnConfig:Sprite = null;
    private static var _btnCollapse:Sprite = null;
    private static var _bodyContainer:Sprite = null;

    // Row 1: Map input & join
    private static var _mapPlate:Sprite = null;
    private static var _mapInput:TextField = null;
    private static var _btnJoin:Sprite = null;

    // Row 2: Room & Pad dropdowns
    private static var _ddRoom:Dropdown = null;
    private static var _ddPad:Dropdown = null;

    // Row 3: Action buttons
    private static var _btnCurrent:Sprite = null;
    private static var _btnJump:Sprite = null;

    // State
    private static var _isCollapsed:Bool = false;
    private static var _lastMap:String = "";

    private static inline var WIDGET_W:Float = 320;
    private static inline var COMPACT_W:Float = 78;
    private static inline var COMPACT_H:Float = 26;
    private static inline var HEIGHT_EXPANDED:Float = 118;

    private static var COMMON_PADS:Array<String> = [
        "Spawn", "Left", "Right", "Center", "Top", "Bottom", "Up", "Down", "Pad", "Enter"
    ];

    public static function getFixedOptions():Array<String> {
        var str = HelperSetting.getString("api_widget_jump_fixed", "");
        if (str == "") return [];
        return str.split(",");
    }

    public static function isOptionFixed(optId:String):Bool {
        return getFixedOptions().indexOf(optId) >= 0;
    }

    private static function computeCollapsedHeight():Float {
        var fixedOpts = getFixedOptions();
        if (fixedOpts.length == 0) return COMPACT_H;
        var curY:Float = 6;
        if (isOptionFixed("map")) curY += 28;
        if (isOptionFixed("room") || isOptionFixed("pad")) curY += 28;
        if (isOptionFixed("jump")) curY += 30;
        return (curY > 6) ? (curY + 4) : COMPACT_H;
    }

    public static function openConfigModal():Void {
        if (_overlay == null) return;
        var fixedOpts = getFixedOptions();
        var isFixed = function(id:String) return fixedOpts.indexOf(id) >= 0;

        var options:Array<WidgetConfigModal.WidgetOptionItem> = [
            { id: "map", label: "Map Joiner", desc: "Keep Map input & Join button visible when collapsed", isFixed: isFixed("map") },
            { id: "room", label: "Room Dropdown", desc: "Keep Room selection dropdown visible when collapsed", isFixed: isFixed("room") },
            { id: "pad", label: "Pad Dropdown", desc: "Keep Pad selection dropdown visible when collapsed", isFixed: isFixed("pad") },
            { id: "jump", label: "Jump Action", desc: "Keep Current & Jump buttons visible when collapsed", isFixed: isFixed("jump") }
        ];

        WidgetConfigModal.show(_overlay, "Jump Widget", options, function(savedIds:Array<String>):Void {
            HelperSetting.setString("api_widget_jump_fixed", savedIds.join(","));
            clampToScreen();
            updateLayout();
        });
    }

    private static function clampToScreen():Void {
        if (_widget == null) return;
        var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);
        if (theStage == null) return;
        var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
        var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
        var isCompact:Bool = _isCollapsed && (getFixedOptions().length == 0);
        var curW:Float = isCompact ? COMPACT_W : WIDGET_W;
        var curH:Float = isCompact ? COMPACT_H : (_isCollapsed ? computeCollapsedHeight() : HEIGHT_EXPANDED);

        if (_widget.x > sw - curW - ApiStyle.SCREEN_MARGIN) _widget.x = Math.max(ApiStyle.SCREEN_MARGIN, sw - curW - ApiStyle.SCREEN_MARGIN);
        if (_widget.y > sh - curH - ApiStyle.SCREEN_MARGIN) _widget.y = Math.max(ApiStyle.SCREEN_MARGIN, sh - curH - ApiStyle.SCREEN_MARGIN);
        if (_widget.x < ApiStyle.SCREEN_MARGIN) _widget.x = ApiStyle.SCREEN_MARGIN;
        if (_widget.y < ApiStyle.SCREEN_MARGIN) _widget.y = ApiStyle.SCREEN_MARGIN;

        HelperSetting.setInt("api_widget_jump_x", Math.round(_widget.x));
        HelperSetting.setInt("api_widget_jump_y", Math.round(_widget.y));
    }

    private static function renderCollapseIcon(collapsed:Bool, hover:Bool = false):Void {
        if (_btnCollapse == null) return;
        var g = _btnCollapse.graphics;
        g.clear();

        // Extended touch hit area for mobile
        g.beginFill(0x000000, 0.0);
        g.drawRect(-4, -2, 28, 24);
        g.endFill();

        var bg = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE;
        var border = hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT;
        g.beginFill(bg, 0.85);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 20, 18, 4, 4);
        g.endFill();

        var color:Int = hover ? ApiStyle.COLOR_ACCENT_PRIMARY : ApiStyle.COLOR_TEXT_MUTED;
        g.lineStyle(2.2, color, 1.0, true);
        var cx = 10.0;
        var cy = 9.0;
        if (collapsed) {
            g.moveTo(cx - 4.5, cy - 2.5);
            g.lineTo(cx, cy + 2.5);
            g.lineTo(cx + 4.5, cy - 2.5);
        } else {
            g.moveTo(cx - 4.5, cy + 2.5);
            g.lineTo(cx, cy - 2.5);
            g.lineTo(cx + 4.5, cy + 2.5);
        }
    }

    private static function renderMiniChevronDown():Void {
        if (_btnCollapse == null) return;
        var g = _btnCollapse.graphics;
        g.clear();
        g.lineStyle(2.0, ApiStyle.COLOR_TEXT_MUTED, 0.9, true);
        var cx:Float = 4.0;
        var cy:Float = 9.0;
        g.moveTo(cx - 3.5, cy - 2.0);
        g.lineTo(cx, cy + 2.0);
        g.lineTo(cx + 3.5, cy - 2.0);
    }

    private static function renderConfigIcon(hover:Bool = false):Void {
        if (_btnConfig == null) return;
        var g = _btnConfig.graphics;
        g.clear();

        g.beginFill(0x000000, 0.0);
        g.drawRect(-4, -2, 28, 24);
        g.endFill();

        var bg = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE;
        var border = hover ? ApiStyle.COLOR_ACCENT_PRIMARY : ApiStyle.COLOR_BORDER_DEFAULT;
        g.beginFill(bg, 0.85);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 20, 18, 4, 4);
        g.endFill();

        var color = hover ? ApiStyle.COLOR_ACCENT_HOVER : ApiStyle.COLOR_ACCENT_PRIMARY;
        var cx = 10.0;
        var cy = 9.0;

        g.lineStyle(2.2, color, 1.0, true);
        g.moveTo(cx - 5.0, cy); g.lineTo(cx + 5.0, cy);
        g.moveTo(cx, cy - 5.0); g.lineTo(cx, cy + 5.0);
        var d = 3.6;
        g.moveTo(cx - d, cy - d); g.lineTo(cx + d, cy + d);
        g.moveTo(cx - d, cy + d); g.lineTo(cx + d, cy - d);

        g.lineStyle(1.4, color, 1.0, true);
        g.beginFill(bg, 1.0);
        g.drawCircle(cx, cy, 3.4);
        g.endFill();

        g.lineStyle(0, 0, 0);
        g.beginFill(color, 1.0);
        g.drawCircle(cx, cy, 1.3);
        g.endFill();
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
        _widget.name = "JumpWidget";

        // Restore saved position (default stacked neatly below CombatWidget at y = 82)
        var savedX = HelperSetting.getInt("api_widget_jump_x", -1);
        var savedY = HelperSetting.getInt("api_widget_jump_y", -1);
        var defaultX:Float = 180;
        var defaultY:Float = 206;

        var initX:Float = (savedX >= 0) ? savedX : defaultX;
        var initY:Float = (savedY >= 0) ? savedY : defaultY;

        var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
        var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
        if (initX > sw - WIDGET_W - ApiStyle.SCREEN_MARGIN) initX = sw - WIDGET_W - ApiStyle.SCREEN_MARGIN;
        if (initY > sh - HEIGHT_EXPANDED - ApiStyle.SCREEN_MARGIN) initY = sh - HEIGHT_EXPANDED - ApiStyle.SCREEN_MARGIN;
        if (initX < ApiStyle.SCREEN_MARGIN) initX = ApiStyle.SCREEN_MARGIN;
        if (initY < ApiStyle.SCREEN_MARGIN) initY = ApiStyle.SCREEN_MARGIN;

        _widget.x = initX;
        _widget.y = initY;

        _isCollapsed = HelperSetting.getBool("api_widget_jump_collapsed", false);

        // 1. Background plate
        _bg = new Sprite();
        _widget.addChild(_bg);

        // 2. Header Bar (Drag & Click-to-collapse zone)
        _headerBar = new Sprite();
        _headerBar.buttonMode = true;
        _headerBar.useHandCursor = true;

        _headerBar.graphics.beginFill(0x000000, 0.0);
        _headerBar.graphics.drawRect(0, 0, WIDGET_W, 24);
        _headerBar.graphics.endFill();
        _widget.addChild(_headerBar);

        // Header Accent Bar (Cool Cyan / Navigation theme)
        _accentShape = new Shape();
        _accentShape.graphics.beginFill(0x00B4D8, 1.0);
        _accentShape.graphics.drawRoundRect(6, 4, 3, 14, 1, 1);
        _accentShape.graphics.endFill();
        _headerBar.addChild(_accentShape);

        // Header Title
        _headerTitleTxt = new TextField();
        var titleFmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_PRIMARY, true);
        _headerTitleTxt.defaultTextFormat = titleFmt;
        _headerTitleTxt.text = "Room Navigation";
        _headerTitleTxt.x = 13;
        _headerTitleTxt.y = 3;
        _headerTitleTxt.width = 110;
        _headerTitleTxt.height = 18;
        _headerTitleTxt.selectable = false;
        _headerTitleTxt.mouseEnabled = false;
        _headerBar.addChild(_headerTitleTxt);

        // Live Map Badge on Header
        _headerMapTxt = new TextField();
        var mapFmt = new TextFormat(ApiStyle.FONT_FAMILY, 10, ApiStyle.COLOR_TEXT_MUTED, false);
        mapFmt.align = TextFormatAlign.RIGHT;
        _headerMapTxt.defaultTextFormat = mapFmt;
        _headerMapTxt.x = 125;
        _headerMapTxt.y = 3;
        _headerMapTxt.width = 140;
        _headerMapTxt.height = 18;
        _headerMapTxt.selectable = false;
        _headerMapTxt.mouseEnabled = false;
        _headerBar.addChild(_headerMapTxt);

        // Header Collapse Indicator (Vector Chevron)
        _btnCollapse = new Sprite();
        _btnCollapse.mouseEnabled = false;
        _btnCollapse.mouseChildren = false;
        _btnCollapse.x = WIDGET_W - 25;
        _btnCollapse.y = 3;
        renderCollapseIcon(_isCollapsed, false);
        _headerBar.addChild(_btnCollapse);

        // Header Config Gear Button
        _btnConfig = new Sprite();
        _btnConfig.buttonMode = true;
        _btnConfig.useHandCursor = true;
        _btnConfig.x = WIDGET_W - 48;
        _btnConfig.y = 3;
        renderConfigIcon(false);

        _btnConfig.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void renderConfigIcon(true));
        _btnConfig.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void renderConfigIcon(false));
        _btnConfig.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void e.stopPropagation());
        _btnConfig.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void e.stopPropagation());
        _btnConfig.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            e.stopPropagation();
            openConfigModal();
        });
        _headerBar.addChild(_btnConfig);

        _headerBar.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            _headerTitleTxt.textColor = ApiStyle.COLOR_TEXT_TITLE;
            var isCompact = _isCollapsed && (getFixedOptions().length == 0);
            if (!isCompact) renderCollapseIcon(_isCollapsed, true);
            _bg.alpha = 1.0;
        });
        _headerBar.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            _headerTitleTxt.textColor = ApiStyle.COLOR_TEXT_PRIMARY;
            var isCompact = _isCollapsed && (getFixedOptions().length == 0);
            if (!isCompact) renderCollapseIcon(_isCollapsed, false);
            _bg.alpha = _isCollapsed ? 0.78 : 0.94;
        });

        // 3. Body Container
        _bodyContainer = new Sprite();
        _widget.addChild(_bodyContainer);

        setupBodyComponents();
        setupDragging(theStage);

        // 4. Live frame state loop
        _widget.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            var inGame = ApiMenus.isInGame();
            if (!inGame) {
                _widget.visible = false;
                return;
            }
            var isEnabled = HelperSetting.getBool("api_widget_jump_enabled", true);
            if (!isEnabled) {
                _widget.visible = false;
                return;
            }
            var isPanelOpen:Bool = (_overlay != null && (_overlay.currentFrameLabel == "Panel" || ApiDashboardModal.isOpen()));
            _widget.visible = !isPanelOpen;
            if (_widget.visible) {
                updateLiveState();
            }
        });

        updateLayout();
        theStage.addChild(_widget);
    }

    private static function setupBodyComponents():Void {
        // --- Row 1 (y = 28): Map Name Input & Join Button ---
        _mapPlate = new Sprite();
        _mapPlate.graphics.beginFill(ApiStyle.COLOR_BG_INPUT, 0.95);
        _mapPlate.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT);
        _mapPlate.graphics.drawRoundRect(0, 0, 236, 24, 4, 4);
        _mapPlate.graphics.endFill();
        _mapPlate.x = 8;
        _mapPlate.y = 28;
        _bodyContainer.addChild(_mapPlate);

        _mapInput = new TextField();
        _mapInput.type = TextFieldType.INPUT;
        var inFmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_PRIMARY);
        _mapInput.defaultTextFormat = inFmt;
        _mapInput.x = 12;
        _mapInput.y = 31;
        _mapInput.width = 228;
        _mapInput.height = 18;
        _mapInput.selectable = true;
        _mapInput.text = "Map (e.g. yulgar-1)";
        _mapInput.textColor = ApiStyle.COLOR_TEXT_MUTED;

        _mapInput.addEventListener(FocusEvent.FOCUS_IN, function(e:FocusEvent):Void {
            if (_mapInput.text == "Map (e.g. yulgar-1)") {
                _mapInput.text = "";
                _mapInput.textColor = ApiStyle.COLOR_TEXT_PRIMARY;
            }
        });

        _mapInput.addEventListener(FocusEvent.FOCUS_OUT, function(e:FocusEvent):Void {
            var trimmed = StringTools.trim(_mapInput.text);
            if (trimmed == "") {
                _mapInput.text = "Map (e.g. yulgar-1)";
                _mapInput.textColor = ApiStyle.COLOR_TEXT_MUTED;
            }
        });

        _mapInput.addEventListener(KeyboardEvent.KEY_DOWN, function(e:KeyboardEvent):Void {
            if (e.keyCode == 13) { // Enter key
                handleJoin();
            }
        });

        _bodyContainer.addChild(_mapInput);

        _btnJoin = createButton(64, 24, "Join", false);
        _btnJoin.x = 248;
        _btnJoin.y = 28;
        _btnJoin.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            handleJoin();
        });
        _bodyContainer.addChild(_btnJoin);

        // --- Row 2 (y = 56): Room & Pad Dropdowns ---
        _ddRoom = new Dropdown(148, 24, ["Enter"], function(room:String):Void {
            handleRoomSelected(room);
        });
        _ddRoom.x = 8;
        _ddRoom.y = 56;
        _ddRoom.onBeforeOpen = refreshRoomList;
        _bodyContainer.addChild(_ddRoom);

        _ddPad = new Dropdown(148, 24, COMMON_PADS, function(pad:String):Void {
            // Selecting pad updates selection
        });
        _ddPad.x = 164;
        _ddPad.y = 56;
        _ddPad.onBeforeOpen = refreshPadList;
        _bodyContainer.addChild(_ddPad);

        // --- Row 3 (y = 84): Current & Jump Action Buttons ---
        _btnCurrent = createButton(148, 26, "Current", false);
        _btnCurrent.x = 8;
        _btnCurrent.y = 84;
        _btnCurrent.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            handleSetCurrent();
        });
        _bodyContainer.addChild(_btnCurrent);

        _btnJump = createButton(148, 26, "Jump", true);
        _btnJump.x = 164;
        _btnJump.y = 84;
        _btnJump.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            handleJump();
        });
        _bodyContainer.addChild(_btnJump);
    }

    private static function createButton(w:Float, h:Float, label:String, isAccent:Bool = false):Sprite {
        var btn = new Sprite();
        btn.buttonMode = true;
        btn.useHandCursor = true;

        renderButtonVisual(btn, w, h, label, isAccent, false);

        btn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            renderButtonVisual(btn, w, h, label, isAccent, true);
        });
        btn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            renderButtonVisual(btn, w, h, label, isAccent, false);
        });

        return btn;
    }

    private static function renderButtonVisual(btn:Sprite, w:Float, h:Float, label:String, isAccent:Bool, hover:Bool):Void {
        var g = btn.graphics;
        g.clear();

        var bg = hover ? ApiStyle.COLOR_BTN_BG_HOVER : (isAccent ? ApiStyle.COLOR_BG_SURFACE : ApiStyle.COLOR_BG_CARD);
        var border = hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : (isAccent ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_BORDER_DEFAULT);
        var textCol = hover ? ApiStyle.COLOR_TEXT_TITLE : (isAccent ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_TEXT_PRIMARY);

        g.beginFill(bg, 0.94);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, w, h, 4, 4);
        g.endFill();

        // Top subtle bevel
        g.lineStyle(1, isAccent ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_BEVEL_LIGHT, hover ? 0.6 : 0.35);
        g.moveTo(2, 1);
        g.lineTo(w - 2, 1);

        var lbl:TextField = cast btn.getChildByName("label");
        if (lbl == null) {
            lbl = new TextField();
            lbl.name = "label";
            var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, textCol, true);
            fmt.align = TextFormatAlign.CENTER;
            lbl.defaultTextFormat = fmt;
            lbl.x = 2;
            lbl.y = Math.round((h - 18) / 2);
            lbl.width = w - 4;
            lbl.height = 18;
            lbl.selectable = false;
            lbl.mouseEnabled = false;
            btn.addChild(lbl);
        } else {
            lbl.text = label;
            lbl.textColor = textCol;
        }
    }

    private static function flashButton(btn:Sprite, w:Float, h:Float, isAccent:Bool = false):Void {
        if (btn == null) return;
        var g = btn.graphics;
        g.clear();
        g.beginFill(ApiStyle.COLOR_BTN_BG_HOVER, 0.98);
        g.lineStyle(1.8, ApiStyle.COLOR_BORDER_HIGHLIGHT);
        g.drawRoundRect(0, 0, w, h, 4, 4);
        g.endFill();

        var lbl:TextField = cast btn.getChildByName("label");
        var text = (lbl != null) ? lbl.text : "";

        haxe.Timer.delay(function():Void {
            renderButtonVisual(btn, w, h, text, isAccent, false);
        }, 120);
    }

    private static function updateLiveState():Void {
        var curMap = (Api.map != null && Api.map.name != null) ? Api.map.name : "";
        if (curMap != _lastMap) {
            _lastMap = curMap;
            if (_headerMapTxt != null) {
                _headerMapTxt.text = (_lastMap != "") ? "[ " + _lastMap + " ]" : "";
            }
            refreshRoomList();
            refreshPadList();
            var curCell = (Api.player != null && Api.player.cell != null) ? Api.player.cell : "";
            if (curCell != "" && _ddRoom != null) {
                _ddRoom.selectedItem = curCell;
            }
            var curPad = (Api.player != null && Api.player.pad != null) ? Api.player.pad : "";
            if (curPad != "" && _ddPad != null) {
                _ddPad.selectedItem = curPad;
            }
        }
    }

    private static function handleJoin():Void {
        var raw = (_mapInput != null) ? StringTools.trim(_mapInput.text) : "";
        if (raw == "" || raw == "Map (e.g. yulgar-1)") {
            var cur = (Api.map != null) ? Api.map.name : "";
            if (cur != "") {
                raw = cur;
            } else {
                ApiNotificationManager.notify("Enter a map name to join!");
                return;
            }
        }
        flashButton(_btnJoin, 64, 24, false);
        if (Api.map != null) {
            Api.map.join(raw);
            ApiNotificationManager.notify("Joining: " + raw);
        }
    }

    private static function handleRoomSelected(room:String):Void {
        if (room == null || room == "") return;
        var pad = (_ddPad != null && _ddPad.selectedItem != "") ? _ddPad.selectedItem : "Spawn";
        if (Api.map != null) {
            Api.map.jump(room, pad, true, true);
            ApiNotificationManager.notify("Jump: " + room + " [" + pad + "]");
        }
    }

    private static function handleJump():Void {
        flashButton(_btnJump, 148, 26, true);
        var room = (_ddRoom != null) ? _ddRoom.selectedItem : "";
        var pad = (_ddPad != null && _ddPad.selectedItem != "") ? _ddPad.selectedItem : "Spawn";
        if (room == "" && Api.player != null) room = Api.player.cell;
        if (room == null || room == "") room = "Enter";

        if (Api.map != null) {
            Api.map.jump(room, pad, true, true);
            ApiNotificationManager.notify("Jump: " + room + " [" + pad + "]");
        }
    }

    private static function handleSetCurrent():Void {
        flashButton(_btnCurrent, 148, 26, false);
        var curCell = (Api.player != null && Api.player.cell != null) ? Api.player.cell : "";
        var curPad = (Api.player != null && Api.player.pad != null) ? Api.player.pad : "";
        var curMap = (Api.map != null && Api.map.name != null) ? Api.map.name : "";

        refreshRoomList();
        refreshPadList();

        if (curCell != "" && _ddRoom != null) {
            _ddRoom.selectedItem = curCell;
        }
        if (curPad != "" && _ddPad != null) {
            _ddPad.selectedItem = curPad;
        }
        if (curMap != "" && _mapInput != null) {
            _mapInput.text = curMap;
            _mapInput.textColor = ApiStyle.COLOR_TEXT_PRIMARY;
        }

        ApiNotificationManager.notify("Current: " + (curCell != "" ? curCell : "Enter") + " [" + (curPad != "" ? curPad : "Spawn") + "]");
    }

    public static function refreshRoomList():Void {
        if (_ddRoom == null) return;
        var cells:Array<String> = [];
        if (Api.map != null) {
            cells = Api.map.getMapCells();
        }
        var cur = (Api.player != null && Api.player.cell != null) ? Api.player.cell : "";
        if (cells == null || cells.length == 0) {
            cells = (cur != "") ? [cur] : ["Enter"];
        } else if (cur != "" && cells.indexOf(cur) == -1) {
            cells.unshift(cur);
        }
        _ddRoom.setOptions(cells, true);
    }

    public static function refreshPadList():Void {
        if (_ddPad == null) return;
        var pads:Array<String> = COMMON_PADS.copy();
        if (Api.map != null) {
            var detected = Api.map.getCellPads();
            if (detected != null) {
                for (p in detected) {
                    if (p != null && p != "" && pads.indexOf(p) == -1) {
                        pads.push(p);
                    }
                }
            }
        }
        var curPad = (Api.player != null && Api.player.pad != null) ? Api.player.pad : "";
        if (curPad != "" && pads.indexOf(curPad) == -1) {
            pads.push(curPad);
        }
        _ddPad.setOptions(pads, true);
    }

    public static function toggleCollapse():Void {
        _isCollapsed = !_isCollapsed;
        HelperSetting.setBool("api_widget_jump_collapsed", _isCollapsed);
        clampToScreen();
        updateLayout();
    }

    private static function updateLayout():Void {
        var fixedOpts = getFixedOptions();
        var isCompact:Bool = _isCollapsed && (fixedOpts.length == 0);

        if (isCompact) {
            // COMPACT MINIMIZED MODE: 78x26 (matching Main Menu button)
            var w:Float = COMPACT_W;
            var h:Float = COMPACT_H;

            _bg.graphics.clear();
            _bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.88);
            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.85);
            _bg.graphics.drawRoundRect(0, 0, w, h, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
            _bg.graphics.endFill();

            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
            _bg.graphics.moveTo(3, 1);
            _bg.graphics.lineTo(w - 3, 1);

            _accentShape.visible = true;
            _accentShape.graphics.clear();
            _accentShape.graphics.beginFill(0x00B4D8, 1.0);
            _accentShape.graphics.drawRoundRect(5, 5, 3.5, 16, 1.5, 1.5);
            _accentShape.graphics.endFill();

            _headerTitleTxt.visible = true;
            _headerTitleTxt.text = "Jump";
            _headerTitleTxt.x = 13;
            _headerTitleTxt.y = 4;
            _headerTitleTxt.width = COMPACT_W - 16;

            _headerBar.graphics.clear();
            _headerBar.graphics.beginFill(0x000000, 0.0);
            _headerBar.graphics.drawRect(0, 0, w, h);
            _headerBar.graphics.endFill();

            _btnCollapse.visible = false;
            _btnConfig.visible = false;
            _headerMapTxt.visible = false;
            _bodyContainer.visible = false;
        } else if (_isCollapsed) {
            // COLLAPSED WITH FIXED PINNED OPTIONS
            // When at least one option is fixed, label text and accent bar are hidden!
            _headerTitleTxt.visible = false;
            _accentShape.visible = false;
            _headerMapTxt.visible = false;
            _btnCollapse.visible = false;
            _btnConfig.visible = false; // Setting icon only shows when widget is opened!

            var curY:Float = 6;
            var hasMap = isOptionFixed("map");
            if (hasMap) {
                _mapPlate.visible = true;
                _mapPlate.y = curY;
                _mapInput.visible = true;
                _mapInput.y = curY + 3;
                _btnJoin.visible = true;
                _btnJoin.y = curY;
                curY += 28;
            } else {
                _mapPlate.visible = false;
                _mapInput.visible = false;
                _btnJoin.visible = false;
            }

            var hasRoom = isOptionFixed("room");
            var hasPad = isOptionFixed("pad");
            if (hasRoom && hasPad) {
                _ddRoom.visible = true;
                _ddRoom.x = 8;
                _ddRoom.y = curY;
                _ddPad.visible = true;
                _ddPad.x = 164;
                _ddPad.y = curY;
                curY += 28;
            } else if (hasRoom) {
                _ddRoom.visible = true;
                _ddRoom.x = 8;
                _ddRoom.y = curY;
                _ddPad.visible = false;
                curY += 28;
            } else if (hasPad) {
                _ddPad.visible = true;
                _ddPad.x = 8;
                _ddPad.y = curY;
                _ddRoom.visible = false;
                curY += 28;
            } else {
                _ddRoom.visible = false;
                _ddPad.visible = false;
            }

            var hasJump = isOptionFixed("jump");
            if (hasJump) {
                _btnCurrent.visible = true;
                _btnCurrent.y = curY;
                _btnJump.visible = true;
                _btnJump.y = curY;
                curY += 30;
            } else {
                _btnCurrent.visible = false;
                _btnJump.visible = false;
            }

            var totalH:Float = (curY > 6) ? (curY + 4) : COMPACT_H;
            _bodyContainer.visible = (curY > 6);

            _bg.graphics.clear();
            _bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.88);
            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.85);
            _bg.graphics.drawRoundRect(0, 0, WIDGET_W, totalH, 6, 6);
            _bg.graphics.endFill();

            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
            _bg.graphics.moveTo(3, 1);
            _bg.graphics.lineTo(WIDGET_W - 3, 1);

            _headerBar.graphics.clear();
            _headerBar.graphics.beginFill(0x000000, 0.0);
            _headerBar.graphics.drawRect(0, 0, WIDGET_W, totalH);
            _headerBar.graphics.endFill();
        } else {
            // FULLY EXPANDED
            _headerTitleTxt.visible = true;
            _headerTitleTxt.text = "Room Navigation";
            _headerTitleTxt.x = 13;
            _headerTitleTxt.y = 3;
            _headerTitleTxt.width = 110;

            _accentShape.visible = true;
            _accentShape.graphics.clear();
            _accentShape.graphics.beginFill(0x00B4D8, 1.0);
            _accentShape.graphics.drawRoundRect(6, 4, 3, 14, 1, 1);
            _accentShape.graphics.endFill();

            _headerMapTxt.visible = true;
            _headerMapTxt.x = 125;
            _headerMapTxt.y = 3;
            _headerMapTxt.width = 140;

            _btnCollapse.visible = false; // Chevron removed everywhere

            _btnConfig.visible = true; // Settings icon only when opened
            _btnConfig.x = WIDGET_W - 25;
            _btnConfig.y = 3;
            renderConfigIcon(false);

            _mapPlate.visible = true;
            _mapPlate.y = 28;
            _mapInput.visible = true;
            _mapInput.y = 31;
            _btnJoin.visible = true;
            _btnJoin.y = 28;

            _ddRoom.visible = true;
            _ddRoom.x = 8;
            _ddRoom.y = 56;
            _ddPad.visible = true;
            _ddPad.x = 164;
            _ddPad.y = 56;

            _btnCurrent.visible = true;
            _btnCurrent.y = 84;
            _btnJump.visible = true;
            _btnJump.y = 84;

            _bodyContainer.visible = true;

            _bg.graphics.clear();
            _bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.94);
            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 1.0);
            _bg.graphics.drawRoundRect(0, 0, WIDGET_W, HEIGHT_EXPANDED, 6, 6);
            _bg.graphics.endFill();

            _bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.55);
            _bg.graphics.moveTo(3, 1);
            _bg.graphics.lineTo(WIDGET_W - 3, 1);

            _headerBar.graphics.clear();
            _headerBar.graphics.beginFill(0x000000, 0.0);
            _headerBar.graphics.drawRect(0, 0, WIDGET_W, 24);
            _headerBar.graphics.endFill();
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
            _widget.cacheAsBitmap = false;
            dragStartX = e.stageX - _widget.x;
            dragStartY = e.stageY - _widget.y;
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
                    var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
                    var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
                    var isCompact:Bool = _isCollapsed && (getFixedOptions().length == 0);
                    var curW:Float = isCompact ? COMPACT_W : WIDGET_W;
                    var curH:Float = isCompact ? COMPACT_H : (_isCollapsed ? computeCollapsedHeight() : HEIGHT_EXPANDED);

                    if (nx < ApiStyle.SCREEN_MARGIN) nx = ApiStyle.SCREEN_MARGIN;
                    if (ny < ApiStyle.SCREEN_MARGIN) ny = ApiStyle.SCREEN_MARGIN;
                    if (nx > sw - curW - ApiStyle.SCREEN_MARGIN) nx = sw - curW - ApiStyle.SCREEN_MARGIN;
                    if (ny > sh - curH - ApiStyle.SCREEN_MARGIN) ny = sh - curH - ApiStyle.SCREEN_MARGIN;

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
                    var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
                    var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
                    var isCompact:Bool = _isCollapsed && (getFixedOptions().length == 0);
                    var curW:Float = isCompact ? COMPACT_W : WIDGET_W;
                    var curH:Float = isCompact ? COMPACT_H : (_isCollapsed ? computeCollapsedHeight() : HEIGHT_EXPANDED);
                    if (_widget.x < ApiStyle.SCREEN_MARGIN) _widget.x = ApiStyle.SCREEN_MARGIN;
                    if (_widget.y < ApiStyle.SCREEN_MARGIN) _widget.y = ApiStyle.SCREEN_MARGIN;
                    if (_widget.x > sw - curW - ApiStyle.SCREEN_MARGIN) _widget.x = sw - curW - ApiStyle.SCREEN_MARGIN;
                    if (_widget.y > sh - curH - ApiStyle.SCREEN_MARGIN) _widget.y = sh - curH - ApiStyle.SCREEN_MARGIN;

                    HelperSetting.setInt("api_widget_jump_x", Math.round(_widget.x));
                    HelperSetting.setInt("api_widget_jump_y", Math.round(_widget.y));
                } else {
                    toggleCollapse();
                }
            }
        });
    }

    public static function isWidgetEnabled():Bool {
        return HelperSetting.getBool("api_widget_jump_enabled", true);
    }

    public static function setWidgetEnabled(enabled:Bool):Void {
        HelperSetting.setBool("api_widget_jump_enabled", enabled);
        if (_widget != null) _widget.visible = enabled;
    }

    public static function resetPosition():Void {
        HelperSetting.setInt("api_widget_jump_x", 180);
        HelperSetting.setInt("api_widget_jump_y", 206);
        if (_widget != null) {
            _widget.x = 180;
            _widget.y = 206;
        }
    }
}
#else
class JumpWidget {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isWidgetEnabled():Bool return false;
    public static function setWidgetEnabled(enabled:Bool):Void {}
    public static function resetPosition():Void {}
    public static function openConfigModal():Void {}
}
#end
