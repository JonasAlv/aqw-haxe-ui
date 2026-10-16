package ui.vibeskua;

import flash.display.Sprite;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;

/**
 * Experimental AQW top-bar inspired by VibeSkua's Avalonia client.
 *
 * This is an original Haxe/Flash implementation of the interaction pattern:
 * compact top-level menus, dark surfaces, nested dropdowns, and right-side
 * quick actions. Wire onAction to the host application's existing commands.
 */
class TopBarMenuPrototype extends Sprite {
    public var onAction:String->Void;
    public var onAutoToggle:Bool->Void;
    public var onJumpToggle:Bool->Void;
    public var onToolsRequested:Void->Void;

    static inline var BAR_HEIGHT:Float = 34;
    static inline var SURFACE:Int = 0x20242B;
    static inline var SURFACE_HOVER:Int = 0x303640;
    static inline var MENU_SURFACE:Int = 0x262B33;
    static inline var BORDER:Int = 0x3A414C;
    static inline var TEXT:Int = 0xE6EAF0;
    static inline var MUTED:Int = 0x9AA4B2;
    static inline var ACCENT:Int = 0x4F9CF9;

    var menuLayer:Sprite;
    var openMenu:Sprite;
    var autoActive:Bool = false;
    var jumpActive:Bool = false;
    var menuData:Array<MenuEntry>;

    public function new() {
        super();
        menuData = [
            { label: "Scripts", items: ["Script Loader", "Scheduler", "Script Repo", "Loadouts Manager"] },
            { label: "Options", items: ["Game", "Application", "Themes", "Hotkeys"] },
            { label: "Tools & Helpers", items: ["Fast Travel", "Loader", "Grabber", "Current Drops", "Junk Items"] },
            { label: "Combat", items: ["Skills", "Stats", "Runtime Helpers"] },
            { label: "Bank", items: [] },
            { label: "Diagnostics", items: ["Logs", "Console", "Packet Spammer", "Packet Logger", "Packet Interceptor"] },
            { label: "Plugins", items: ["Plugin Manager"] }
        ];

        drawBar();
        menuLayer = new Sprite();
        addChild(menuLayer);
        addEventListener(MouseEvent.MOUSE_DOWN, onBarMouseDown);
    }

    function drawBar():Void {
        graphics.clear();
        graphics.beginFill(SURFACE);
        graphics.drawRect(0, 0, 760, BAR_HEIGHT);
        graphics.endFill();
        graphics.lineStyle(1, BORDER);
        graphics.moveTo(0, BAR_HEIGHT - 1);
        graphics.lineTo(760, BAR_HEIGHT - 1);

        var x:Float = 6;
        for (entry in menuData) {
            var width = entry.label == "Tools & Helpers" ? 104.0 : (entry.label == "Diagnostics" ? 88.0 : 72.0);
            var item = makeLabel(entry.label, 12, TEXT, false, width - 8, 28);
            item.x = x + 4;
            item.y = 3;
            item.mouseEnabled = false;
            var hit = new Sprite();
            hit.name = "menu:" + entry.label;
            hit.graphics.beginFill(SURFACE, 0.001);
            hit.graphics.drawRoundRect(x, 3, width, 28, 5, 5);
            hit.graphics.endFill();
            hit.addChild(item);
            hit.buttonMode = true;
            hit.addEventListener(MouseEvent.CLICK, function(_:MouseEvent):Void {
                if (entry.items.length == 0) {
                    closeMenu();
                    dispatchAction(entry.label);
                } else {
                    toggleMenu(entry, hit.x, BAR_HEIGHT);
                }
            });
            hit.addEventListener(MouseEvent.MOUSE_OVER, function(_:MouseEvent):Void {
                hit.graphics.clear();
                hit.graphics.beginFill(SURFACE_HOVER);
                hit.graphics.drawRoundRect(0, 0, width, 28, 5, 5);
                hit.graphics.endFill();
            });
            hit.addEventListener(MouseEvent.MOUSE_OUT, function(_:MouseEvent):Void {
                hit.graphics.clear();
                hit.graphics.beginFill(SURFACE, 0.001);
                hit.graphics.drawRoundRect(0, 0, width, 28, 5, 5);
                hit.graphics.endFill();
            });
            addChild(hit);
            x += width;
        }

        // Right aligned quick actions, intentionally separate from the menu groups.
        addQuickAction("Auto", 550, function():Void {
            autoActive = !autoActive;
            onAutoToggle == null ? null : onAutoToggle(autoActive);
            drawQuickState();
        });
        addQuickAction("Jump", 608, function():Void {
            jumpActive = !jumpActive;
            onJumpToggle == null ? null : onJumpToggle(jumpActive);
            drawQuickState();
        });
        addQuickAction("+", 690, function():Void {
            if (onToolsRequested != null) onToolsRequested();
            else dispatchAction("Show Bot Windows & Tools");
        });
        drawQuickState();
    }

    function drawQuickState():Void {
        for (child in getChildren()) {
            if (child.name == "quick:Auto" || child.name == "quick:Jump") {
                var active = child.name == "quick:Auto" ? autoActive : jumpActive;
                var button:Sprite = cast child;
                button.graphics.clear();
                button.graphics.beginFill(active ? 0x244D3D : SURFACE_HOVER);
                button.graphics.drawRoundRect(0, 0, button.width, 27, 5, 5);
                button.graphics.endFill();
                button.graphics.lineStyle(1, active ? 0x10B981 : BORDER);
                button.graphics.drawRoundRect(0, 0, button.width, 27, 5, 5);
            }
        }
    }

    function addQuickAction(label:String, x:Float, action:Void->Void):Void {
        var width = label == "+" ? 28.0 : 52.0;
        var button = new Sprite();
        button.name = "quick:" + label;
        button.x = x;
        button.y = 4;
        button.buttonMode = true;
        button.graphics.beginFill(SURFACE_HOVER);
        button.graphics.drawRoundRect(0, 0, width, 27, 5, 5);
        button.graphics.endFill();
        button.graphics.lineStyle(1, BORDER);
        button.graphics.drawRoundRect(0, 0, width, 27, 5, 5);
        var text = makeLabel(label, 12, TEXT, true, width, 25);
        text.y = 1;
        text.mouseEnabled = false;
        button.addChild(text);
        button.addEventListener(MouseEvent.CLICK, function(_:MouseEvent):Void action());
        addChild(button);
    }

    function toggleMenu(entry:MenuEntry, x:Float, y:Float):Void {
        if (openMenu != null && openMenu.name == "dropdown:" + entry.label) {
            closeMenu();
            return;
        }
        closeMenu();
        var popup = new Sprite();
        popup.name = "dropdown:" + entry.label;
        popup.x = x;
        popup.y = y;
        popup.graphics.beginFill(MENU_SURFACE);
        popup.graphics.drawRoundRect(0, 0, 190, entry.items.length * 30 + 10, 7, 7);
        popup.graphics.endFill();
        popup.graphics.lineStyle(1, BORDER);
        popup.graphics.drawRoundRect(0, 0, 190, entry.items.length * 30 + 10, 7, 7);
        var index = 0;
        for (itemName in entry.items) {
            var row = new Sprite();
            row.y = 5 + index * 30;
            row.buttonMode = true;
            row.graphics.beginFill(MENU_SURFACE, 0.001);
            row.graphics.drawRoundRect(5, 0, 180, 28, 4, 4);
            row.graphics.endFill();
            var text = makeLabel(itemName, 12, TEXT, false, 164, 28);
            text.x = 14;
            text.mouseEnabled = false;
            row.addChild(text);
            row.addEventListener(MouseEvent.MOUSE_OVER, function(_:MouseEvent):Void {
                row.graphics.clear();
                row.graphics.beginFill(SURFACE_HOVER);
                row.graphics.drawRoundRect(5, 0, 180, 28, 4, 4);
                row.graphics.endFill();
            });
            row.addEventListener(MouseEvent.MOUSE_OUT, function(_:MouseEvent):Void {
                row.graphics.clear();
                row.graphics.beginFill(MENU_SURFACE, 0.001);
                row.graphics.drawRoundRect(5, 0, 180, 28, 4, 4);
                row.graphics.endFill();
            });
            row.addEventListener(MouseEvent.CLICK, function(_:MouseEvent):Void {
                closeMenu();
                dispatchAction(itemName);
            });
            popup.addChild(row);
            index++;
        }
        menuLayer.addChild(popup);
        openMenu = popup;
    }

    function closeMenu():Void {
        if (openMenu != null && menuLayer.contains(openMenu)) menuLayer.removeChild(openMenu);
        openMenu = null;
    }

    function onBarMouseDown(event:MouseEvent):Void {
        // Clicking the bar background dismisses an open dropdown.
        if (event.target == this) closeMenu();
    }

    function dispatchAction(action:String):Void {
        if (onAction != null) onAction(action);
    }

    function makeLabel(value:String, size:Int, color:Int, bold:Bool, width:Float, height:Float):TextField {
        var field = new TextField();
        field.selectable = false;
        field.mouseEnabled = false;
        field.width = width;
        field.height = height;
        field.defaultTextFormat = new TextFormat("_sans", size, color, bold, null, null, null, null, TextFormatAlign.LEFT);
        field.text = value;
        field.y = 0;
        return field;
    }

    function getChildren():Array<flash.display.DisplayObject> {
        var result:Array<flash.display.DisplayObject> = [];
        for (i in 0...numChildren) result.push(getChildAt(i));
        return result;
    }
}

private typedef MenuEntry = {
    var label:String;
    var items:Array<String>;
}
