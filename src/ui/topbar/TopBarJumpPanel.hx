package ui.topbar;

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
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.Dropdown;

/**
 * Dropdown panel for Map & Room navigation attached directly beneath the TopBar.
 * 100% pure ASCII strings and Flash vector graphics (zero Unicode glyphs).
 */
class TopBarJumpPanel extends Sprite {
    public static inline var PANEL_WIDTH:Float = 220.0;
    public static inline var PANEL_HEIGHT:Float = 120.0;

    private var _bg:Shape;
    private var _mapInput:TextField;
    private var _mapPlate:Sprite;
    private var _btnJoin:Sprite;

    private var _ddRoom:Dropdown;
    private var _ddPad:Dropdown;

    private var _btnCurrent:Sprite;
    private var _btnJump:Sprite;

    private var _lastMap:String = "";

    private static var COMMON_PADS:Array<String> = [
        "Spawn", "Center", "Left", "Right", "Top", "Bottom", "Pad", "Wait"
    ];

    public function new() {
        super();
        buildUI();
    }

    private function buildUI():Void {
        _bg = new Shape();
        var g = _bg.graphics;
        g.beginFill(ApiStyle.COLOR_BG_CARD, 0.96);
        g.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.95);
        g.drawRoundRect(0, 0, PANEL_WIDTH, PANEL_HEIGHT, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
        g.endFill();

        g.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.5);
        g.moveTo(3, 1);
        g.lineTo(PANEL_WIDTH - 3, 1);
        addChild(_bg);

        // --- Row 1 (y = 8): Map Input & Join Button ---
        _mapPlate = new Sprite();
        _mapPlate.graphics.beginFill(ApiStyle.COLOR_BG_INPUT, 0.95);
        _mapPlate.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT);
        _mapPlate.graphics.drawRoundRect(0, 0, 154.0, 24.0, 4, 4);
        _mapPlate.graphics.endFill();
        _mapPlate.x = 8.0;
        _mapPlate.y = 8.0;
        addChild(_mapPlate);

        _mapInput = new TextField();
        _mapInput.type = TextFieldType.INPUT;
        var inFmt = new TextFormat(ApiStyle.FONT_FAMILY, 10, ApiStyle.COLOR_TEXT_PRIMARY);
        _mapInput.defaultTextFormat = inFmt;
        _mapInput.x = 12.0;
        _mapInput.y = 11.0;
        _mapInput.width = 146.0;
        _mapInput.height = 18.0;
        _mapInput.selectable = true;
        _mapInput.text = "Map (e.g. yulgar)";
        _mapInput.textColor = ApiStyle.COLOR_TEXT_MUTED;

        _mapInput.addEventListener(FocusEvent.FOCUS_IN, function(e:FocusEvent):Void {
            if (_mapInput.text == "Map (e.g. yulgar)" || _mapInput.text == "Map (e.g. yulgar-1)") {
                _mapInput.text = "";
                _mapInput.textColor = ApiStyle.COLOR_TEXT_PRIMARY;
            }
        });

        _mapInput.addEventListener(FocusEvent.FOCUS_OUT, function(e:FocusEvent):Void {
            var trimmed = StringTools.trim(_mapInput.text);
            if (trimmed == "") {
                _mapInput.text = "Map (e.g. yulgar)";
                _mapInput.textColor = ApiStyle.COLOR_TEXT_MUTED;
            }
        });

        _mapInput.addEventListener(KeyboardEvent.KEY_DOWN, function(e:KeyboardEvent):Void {
            if (e.keyCode == 13) {
                handleJoin();
            }
        });
        addChild(_mapInput);

        _btnJoin = createButton(44.0, 24.0, "Join", false);
        _btnJoin.x = 168.0;
        _btnJoin.y = 8.0;
        _btnJoin.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void handleJoin());
        addChild(_btnJoin);

        // --- Row 2 (y = 36): Room & Pad Dropdowns ---
        _ddRoom = new Dropdown(99.0, 24.0, ["Enter"], function(room:String):Void {
            handleRoomSelected(room);
        });
        _ddRoom.x = 8.0;
        _ddRoom.y = 36.0;
        _ddRoom.onBeforeOpen = refreshRoomList;
        addChild(_ddRoom);

        _ddPad = new Dropdown(99.0, 24.0, COMMON_PADS, function(pad:String):Void {});
        _ddPad.x = 113.0;
        _ddPad.y = 36.0;
        _ddPad.onBeforeOpen = refreshPadList;
        addChild(_ddPad);

        // --- Row 3 (y = 64): Current & Jump Buttons ---
        _btnCurrent = createButton(99.0, 24.0, "Current", false);
        _btnCurrent.x = 8.0;
        _btnCurrent.y = 64.0;
        _btnCurrent.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void handleSetCurrent());
        addChild(_btnCurrent);

        _btnJump = createButton(99.0, 24.0, "Jump", true);
        _btnJump.x = 113.0;
        _btnJump.y = 64.0;
        _btnJump.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void handleJump());
        addChild(_btnJump);

        // --- Row 4 (y = 92): Common Pad Quick Chips ---
        var quickPads = ["Spawn", "Center", "Left", "Right"];
        var chipW:Float = 48.0;
        var chipGap:Float = 4.0;
        for (i in 0...quickPads.length) {
            var padName = quickPads[i];
            var chip = createQuickPadChip(chipW, 20.0, padName);
            chip.x = 8.0 + (i * (chipW + chipGap));
            chip.y = 92.0;
            addChild(chip);
        }
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

        btn.graphics.beginFill(bgCol, 0.94);
        btn.graphics.lineStyle(1, border);
        btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
        btn.graphics.endFill();

        btn.graphics.lineStyle(1, isAccent ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_BEVEL_LIGHT, hover ? 0.6 : 0.35);
        btn.graphics.moveTo(2, 1);
        btn.graphics.lineTo(w - 2, 1);

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

    private function createQuickPadChip(w:Float, h:Float, padName:String):Sprite {
        var chip = new Sprite();
        chip.buttonMode = true;
        chip.useHandCursor = true;

        var drawChip = function(hover:Bool):Void {
            chip.graphics.clear();
            var bgCol = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_MAIN;
            var border = hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT;
            var textCol = hover ? ApiStyle.COLOR_TEXT_PRIMARY : ApiStyle.COLOR_TEXT_MUTED;

            chip.graphics.beginFill(bgCol, 0.92);
            chip.graphics.lineStyle(1, border);
            chip.graphics.drawRoundRect(0, 0, w, h, 3, 3);
            chip.graphics.endFill();

            var lbl:TextField = cast chip.getChildByName("label");
            if (lbl != null) lbl.textColor = textCol;
        };

        var lbl = new TextField();
        lbl.name = "label";
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 9, ApiStyle.COLOR_TEXT_MUTED, false);
        fmt.align = TextFormatAlign.CENTER;
        lbl.defaultTextFormat = fmt;
        lbl.x = 0;
        lbl.y = 1;
        lbl.width = w;
        lbl.height = 16;
        lbl.selectable = false;
        lbl.mouseEnabled = false;
        lbl.text = padName;
        chip.addChild(lbl);

        drawChip(false);

        chip.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void drawChip(true));
        chip.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void drawChip(false));
        chip.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (_ddPad != null) _ddPad.selectedItem = padName;
            handleJump();
        });

        return chip;
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
        if (Api.map != null) {
            Api.map.join(raw);
            ApiNotificationManager.notify("Joining: " + raw);
        }
    }

    private function handleRoomSelected(room:String):Void {
        refreshPadList();
    }

    private function handleSetCurrent():Void {
        if (Api.player == null) return;
        var cell = (Api.player.cell != null) ? Api.player.cell : "Enter";
        var pad = (Api.player.pad != null) ? Api.player.pad : "Spawn";
        if (_ddRoom != null) _ddRoom.selectedItem = cell;
        if (_ddPad != null) _ddPad.selectedItem = pad;
        ApiNotificationManager.notify("Set Current: " + cell + " [" + pad + "]");
    }

    private function handleJump():Void {
        var cell = (_ddRoom != null && _ddRoom.selectedItem != null) ? _ddRoom.selectedItem : "Enter";
        var pad = (_ddPad != null && _ddPad.selectedItem != null) ? _ddPad.selectedItem : "Spawn";
        if (Api.map != null) {
            Api.map.jump(cell, pad, true, true);
            ApiNotificationManager.notify("Jumped: " + cell + " [" + pad + "]");
        }
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

    public function onTick():Void {
        var curMap = (Api.map != null && Api.map.name != null) ? Api.map.name : "";
        if (curMap != _lastMap) {
            _lastMap = curMap;
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
}
#else
class TopBarJumpPanel {}
#end
