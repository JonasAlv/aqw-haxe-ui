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
import ui.widgets.BaseWidget;
import ui.widgets.WidgetConfigModal;
import com.aqwapi.utils.ApiConfig;

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
class JumpWidget extends BaseWidget {
    public static var instance:JumpWidget = null;

    // Component references
    private var _headerMapTxt:TextField = null;

    // Row 1: Map input & join
    private var _mapPlate:Sprite = null;
    private var _mapInput:TextField = null;
    private var _btnJoin:Sprite = null;

    // Row 2: Room & Pad dropdowns
    private var _ddRoom:Dropdown = null;
    private var _ddPad:Dropdown = null;

    // Row 3: Action buttons
    private var _btnCurrent:Sprite = null;
    private var _btnJump:Sprite = null;

    // State
    private var _lastMap:String = "";

    public static inline var WIDGET_W:Float = 320;
    public static inline var HEIGHT_EXPANDED:Float = 118;

    private static var COMMON_PADS:Array<String> = [
        "Spawn", "Left", "Right", "Center", "Top", "Bottom", "Up", "Down", "Pad", "Enter"
    ];

    public function new() {
        super("jump", "Room Navigation", 180, 206, WIDGET_W, HEIGHT_EXPANDED, true, false, true);
        instance = this;
    }

    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {
        if (instance == null) {
            instance = new JumpWidget();
        }
        var theStage:Dynamic = (pocket != null && pocket.stage != null) ? pocket.stage : (overlay != null ? overlay.stage : null);
        if (theStage != null && instance.theStage == null) {
            instance.attach(theStage, overlay);
        }
    }

    public static function getFixedOptions():Array<String> {
        var str = ApiConfig.getString("api_widget_jump_fixed", "");
        if (str == "") return [];
        return str.split(",");
    }

    public static function isOptionFixed(optId:String):Bool {
        return getFixedOptions().indexOf(optId) >= 0;
    }

    override public function computeCollapsedWidth():Float {
        var fixedOpts = getFixedOptions();
        if (fixedOpts.length == 0) return BaseWidget.COMPACT_W;
        return defaultWidth;
    }

    override public function computeCollapsedHeight():Float {
        var fixedOpts = getFixedOptions();
        if (fixedOpts.length == 0) return BaseWidget.COMPACT_H;
        var curY:Float = 6;
        if (isOptionFixed("map")) curY += 28;
        if (isOptionFixed("room") || isOptionFixed("pad")) curY += 28;
        if (isOptionFixed("jump")) curY += 30;
        return (curY > 6) ? (curY + 4) : BaseWidget.COMPACT_H;
    }

    override public function buildContent(container:Sprite):Void {
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
        headerBar.addChild(_headerMapTxt);

        // --- Row 1 (y = 28): Map Name Input & Join Button ---
        _mapPlate = new Sprite();
        _mapPlate.graphics.beginFill(ApiStyle.COLOR_BG_INPUT, 0.95);
        _mapPlate.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT);
        _mapPlate.graphics.drawRoundRect(0, 0, 236, 24, 4, 4);
        _mapPlate.graphics.endFill();
        _mapPlate.x = 8;
        _mapPlate.y = 28;
        bodyContainer.addChild(_mapPlate);

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
            if (e.keyCode == 13) {
                handleJoin();
            }
        });

        bodyContainer.addChild(_mapInput);

        _btnJoin = createButton(64, 24, "Join", false);
        _btnJoin.x = 248;
        _btnJoin.y = 28;
        _btnJoin.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            handleJoin();
        });
        bodyContainer.addChild(_btnJoin);

        // --- Row 2 (y = 56): Room & Pad Dropdowns ---
        _ddRoom = new Dropdown(148, 24, ["Enter"], function(room:String):Void {
            handleRoomSelected(room);
        });
        _ddRoom.x = 8;
        _ddRoom.y = 56;
        _ddRoom.onBeforeOpen = refreshRoomList;
        bodyContainer.addChild(_ddRoom);

        _ddPad = new Dropdown(148, 24, COMMON_PADS, function(pad:String):Void {});
        _ddPad.x = 164;
        _ddPad.y = 56;
        _ddPad.onBeforeOpen = refreshPadList;
        bodyContainer.addChild(_ddPad);

        // --- Row 3 (y = 84): Current & Jump Action Buttons ---
        _btnCurrent = createButton(148, 26, "Current", false);
        _btnCurrent.x = 8;
        _btnCurrent.y = 84;
        _btnCurrent.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            handleSetCurrent();
        });
        bodyContainer.addChild(_btnCurrent);

        _btnJump = createButton(148, 26, "Jump", true);
        _btnJump.x = 164;
        _btnJump.y = 84;
        _btnJump.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            handleJump();
        });
        bodyContainer.addChild(_btnJump);
    }

    private function createButton(w:Float, h:Float, label:String, isAccent:Bool = false):Sprite {
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

    private function renderButtonVisual(btn:Sprite, w:Float, h:Float, label:String, isAccent:Bool, hover:Bool):Void {
        var g = btn.graphics;
        g.clear();

        var bgCol = hover ? ApiStyle.COLOR_BTN_BG_HOVER : (isAccent ? ApiStyle.COLOR_BG_SURFACE : ApiStyle.COLOR_BG_CARD);
        var border = hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : (isAccent ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_BORDER_DEFAULT);
        var textCol = hover ? ApiStyle.COLOR_TEXT_TITLE : (isAccent ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_TEXT_PRIMARY);

        g.beginFill(bgCol, 0.94);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, w, h, 4, 4);
        g.endFill();

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
            lbl.text = label;
            btn.addChild(lbl);
        } else {
            lbl.text = label;
            lbl.textColor = textCol;
        }
    }

    private function flashButton(btn:Sprite, w:Float, h:Float, isAccent:Bool = false):Void {
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

    override public function onTick():Void {
        updateLiveState();
    }

    private function updateLiveState():Void {
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

    private function handleJoin():Void {
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

    private function handleRoomSelected(room:String):Void {
        if (room == null || room == "") return;
        var pad = (_ddPad != null && _ddPad.selectedItem != "") ? _ddPad.selectedItem : "Spawn";
        if (Api.map != null) {
            Api.map.jump(room, pad, true, true);
            ApiNotificationManager.notify("Jump: " + room + " [" + pad + "]");
        }
    }

    private function handleJump():Void {
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

    private function handleSetCurrent():Void {
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

    public function refreshRoomList():Void {
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

    public function refreshPadList():Void {
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

    override public function updateLayout():Void {
        var fixedOpts = getFixedOptions();
        var isCompact:Bool = isCollapsed && (fixedOpts.length == 0);

        if (isCompact) {
            var w:Float = BaseWidget.COMPACT_W;
            var h:Float = BaseWidget.COMPACT_H;

            bg.graphics.clear();
            bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.88);
            bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.85);
            bg.graphics.drawRoundRect(0, 0, w, h, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
            bg.graphics.endFill();

            bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
            bg.graphics.moveTo(3, 1);
            bg.graphics.lineTo(w - 3, 1);

            accentShape.visible = true;
            accentShape.graphics.clear();
            accentShape.graphics.beginFill(0x00B4D8, 1.0);
            accentShape.graphics.drawRoundRect(5, 5, 3.5, 16, 1.5, 1.5);
            accentShape.graphics.endFill();

            titleTxt.visible = true;
            titleTxt.text = "Jump";
            titleTxt.x = 13;
            titleTxt.y = 4;
            titleTxt.width = BaseWidget.COMPACT_W - 16;

            headerBar.graphics.clear();
            headerBar.graphics.beginFill(0x000000, 0.0);
            headerBar.graphics.drawRect(0, 0, w, h);
            headerBar.graphics.endFill();

            btnCollapse.visible = false;
            if (btnConfig != null) btnConfig.visible = false;
            _headerMapTxt.visible = false;
            bodyContainer.visible = false;
        } else if (isCollapsed) {
            titleTxt.visible = false;
            accentShape.visible = false;
            _headerMapTxt.visible = false;
            btnCollapse.visible = false;
            if (btnConfig != null) btnConfig.visible = false;

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

            var totalH:Float = (curY > 6) ? (curY + 4) : BaseWidget.COMPACT_H;
            bodyContainer.visible = (curY > 6);

            bg.graphics.clear();
            bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.88);
            bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.85);
            bg.graphics.drawRoundRect(0, 0, WIDGET_W, totalH, 6, 6);
            bg.graphics.endFill();

            bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
            bg.graphics.moveTo(3, 1);
            bg.graphics.lineTo(WIDGET_W - 3, 1);

            headerBar.graphics.clear();
            headerBar.graphics.beginFill(0x000000, 0.0);
            headerBar.graphics.drawRect(0, 0, WIDGET_W, totalH);
            headerBar.graphics.endFill();
        } else {
            // FULLY EXPANDED
            titleTxt.visible = true;
            titleTxt.text = "Room Navigation";
            titleTxt.x = 13;
            titleTxt.y = 3;
            titleTxt.width = 110;

            accentShape.visible = true;
            accentShape.graphics.clear();
            accentShape.graphics.beginFill(0x00B4D8, 1.0);
            accentShape.graphics.drawRoundRect(6, 4, 3, 14, 1, 1);
            accentShape.graphics.endFill();

            _headerMapTxt.visible = true;
            _headerMapTxt.x = 125;
            _headerMapTxt.y = 3;
            _headerMapTxt.width = 140;

            btnCollapse.visible = false;

            if (btnConfig != null) {
                btnConfig.visible = true;
                btnConfig.x = WIDGET_W - 25;
                btnConfig.y = 3;
                renderConfigIcon(false);
            }

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

            bodyContainer.visible = true;

            bg.graphics.clear();
            bg.graphics.beginFill(ApiStyle.COLOR_BG_MAIN, 0.94);
            bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 1.0);
            bg.graphics.drawRoundRect(0, 0, WIDGET_W, HEIGHT_EXPANDED, 6, 6);
            bg.graphics.endFill();

            bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.55);
            bg.graphics.moveTo(3, 1);
            bg.graphics.lineTo(WIDGET_W - 3, 1);

            headerBar.graphics.clear();
            headerBar.graphics.beginFill(0x000000, 0.0);
            headerBar.graphics.drawRect(0, 0, WIDGET_W, 24);
            headerBar.graphics.endFill();
        }
    }

    override public function openConfig():Void {
        if (overlay == null) return;
        var fixedOpts = getFixedOptions();
        var isFixed = function(id:String) return fixedOpts.indexOf(id) >= 0;

        var options:Array<WidgetConfigModal.WidgetOptionItem> = [
            { id: "map", label: "Map Joiner", desc: "Keep Map input & Join button visible when collapsed", isFixed: isFixed("map") },
            { id: "room", label: "Room Dropdown", desc: "Keep Room selection dropdown visible when collapsed", isFixed: isFixed("room") },
            { id: "pad", label: "Pad Dropdown", desc: "Keep Pad selection dropdown visible when collapsed", isFixed: isFixed("pad") },
            { id: "jump", label: "Jump Action", desc: "Keep Current & Jump buttons visible when collapsed", isFixed: isFixed("jump") }
        ];

        WidgetConfigModal.show(overlay, "Jump Widget", options, function(savedIds:Array<String>):Void {
            ApiConfig.setString("api_widget_jump_fixed", savedIds.join(","));
            clampToScreen();
            updateLayout();
        });
    }

    // --- Static Facades for Backwards Compatibility ---

    public static function isWidgetEnabled():Bool {
        if (instance != null) return instance.isEnabled;
        return ApiConfig.getBool("api_widget_jump_enabled", true);
    }

    public static function setWidgetEnabled(enabled:Bool):Void {
        if (instance != null) instance.setEnabled(enabled);
        else ApiConfig.setBool("api_widget_jump_enabled", enabled);
    }

    public static function resetPosition():Void {
        if (instance != null) instance.resetToDefaultPosition();
        else {
            ApiConfig.setInt("api_widget_jump_x", 180);
            ApiConfig.setInt("api_widget_jump_y", 206);
        }
    }

    public static function openConfigModal():Void {
        if (instance != null) instance.openConfig();
    }
}
#else
class JumpWidget {
    public static var instance:JumpWidget = null;
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isWidgetEnabled():Bool return false;
    public static function setWidgetEnabled(enabled:Bool):Void {}
    public static function resetPosition():Void {}
    public static function openConfigModal():Void {}
}
#end
