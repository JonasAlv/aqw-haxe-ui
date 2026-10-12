package ui;

#if flash
import flash.display.MovieClip;
import flash.display.SimpleButton;
import flash.display.Sprite;
import ui.option.Menu;

/**
 * Self-contained Overlay implementation.
 *
 * Always a concrete class — no extern dependency on aqw-mobile-mod's Overlay.as.
 * When compiled into ModUI.swc for aqw-mobile-mod, it is excluded from the SWC
 * output via `--macro exclude('ui.Overlay')` in build.hxml so the AS3 runtime
 * class wins at load time.  When compiled into the standalone SWC (aqworlds),
 * it is included and acts as a stub panel with invisible buttons.
 *
 * Members mirror the AS3 Overlay exactly so the rest of the UI code compiles
 * cleanly against either runtime implementation.
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
        showPanelBtn  = stub();
        hidePanelBtn  = stub();
        reportBugBtn  = stub();
        updateBtn     = stub();
        discordBtn    = stub();
        contentMenu   = new Sprite();
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

    // AS3 compat shim so code that calls gotoAndStop() doesn't crash at runtime
    // when this stub is the active implementation.
    override public function gotoAndStop(frame:Dynamic, scene:String = null):Void {}
}
#else
extern class Overlay {}
#end
