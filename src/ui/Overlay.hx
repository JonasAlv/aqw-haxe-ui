package ui;

#if flash
import flash.display.MovieClip;
import flash.display.SimpleButton;
import flash.display.Sprite;
import ui.option.Menu;

#if standalone
/**
 * Self-contained overlay for launchers that don't ship one (official AQWorlds launcher).
 * Mirrors the members the UI reads from the aqw-mobile-mod Overlay; the panel buttons are
 * invisible stubs; a frameless MovieClip reports a null currentFrameLabel, so the UI never sees "Panel".
 */
class Overlay extends MovieClip {
    public var showPanelBtn:SimpleButton;
    public var hidePanelBtn:SimpleButton;
    public var reportBugBtn:SimpleButton;
    public var updateBtn:SimpleButton;
    public var discordBtn:SimpleButton;
    public var contentMenu:Sprite;
    public var contentOptions:Sprite;
    public var notifications:Sprite;
    public var menus:Dynamic;

    public function new() {
        super();
        showPanelBtn = stub();
        hidePanelBtn = stub();
        reportBugBtn = stub();
        updateBtn = stub();
        discordBtn = stub();
        contentMenu = new Sprite();
        contentOptions = new Sprite();
        notifications = new Sprite();
        menus = new flash.Vector<Dynamic>();
        mouseEnabled = false;
    }

    function stub():SimpleButton {
        var b = new SimpleButton();
        b.visible = false;
        return b;
    }

    public function selectMenu(menu:Menu):Void {}
}
#else
extern class Overlay extends MovieClip {
    public var showPanelBtn:SimpleButton;
    public var hidePanelBtn:SimpleButton;
    public var reportBugBtn:SimpleButton;
    public var updateBtn:SimpleButton;
    public var discordBtn:SimpleButton;
    public var contentMenu:Sprite;
    public var contentOptions:Sprite;
    public var notifications:Sprite;
    public var menus:Dynamic;

    public function selectMenu(menu:Menu):Void;
    public function gotoAndStop(frame:Dynamic, scene:String = null):Void;
}
#end
#else
extern class Overlay {}
#end
