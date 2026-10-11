package ui;

/**
 * Compile-time contract for the Overlay supplied by aqw-mobile-mod (Overlay.as).
 *
 * Keep this class extern: the runtime implementation belongs to the host SWF and must
 * not be emitted/replaced by ModUI.swc. MovieClip already supplies the standard display
 * list, stage, frame navigation, and event APIs.
 */
#if flash
import flash.display.DisplayObject;
import flash.display.MovieClip;
import flash.display.SimpleButton;
import flash.display.Sprite;
import ui.option.Menu;

extern class Overlay extends MovieClip {
    /** Host menu collection. Dynamic intentionally accommodates the host Vector<Menu>
     * and menu collections temporarily replaced by API code. */
    public var menus:Dynamic;

    public var showPanelBtn:SimpleButton;
    public var hidePanelBtn:SimpleButton;
    public var reportBugBtn:SimpleButton;
    public var updateBtn:SimpleButton;
    public var discordBtn:SimpleButton;

    public var contentMenu:Sprite;
    public var contentOptions:Sprite;
    public var contentMask:DisplayObject;
    /** Host scroll controller (ui.util.Scroll in the original AS3 project). */
    public var contentScroll:Dynamic;

    /** Host Debug instance, exposing log/logError and display-list methods. */
    public var debug:Dynamic;
    public var notifications:Sprite;

    /** Selects a host menu and rebuilds the options/scroll area. */
    public function selectMenu(menu:Menu):Void;

    /** Displays a host notification card. */
    public function notification(message:String):Void;

    /** Keeps the floating menu button aligned with the current game screen. */
    public function setOverlayButtonTransform():Void;

    /** MovieClip.gotoAndStop with the host's frame labels (normally Init/Panel). */
    public function gotoAndStop(frame:Dynamic, scene:String = null):Void;
}
#else
extern class Overlay {}
#end
