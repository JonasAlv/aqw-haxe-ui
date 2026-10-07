package ui;

#if flash
import com.aqwapi.Api;
import com.aqwapi.modules.CombatEngine;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.utils.ApiLogger;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import ui.ApiDashboardModal;
import ui.Overlay;
import util.HelperSetting;

typedef HudButtonDef = {
    id:String,
    label:String,
    defaultX:Float,
    defaultY:Float,
    activeText:String,
    inactiveText:String,
    getState:Void->Bool,
    onToggle:Void->Void
};

class ApiHudManager {
    private static var _pocket:Dynamic = null;
    private static var _overlay:Overlay = null;
    private static var _buttons:Map<String, Sprite> = new Map<String, Sprite>();
    private static var _defs:Array<HudButtonDef> = [];
    private static var _initialized:Bool = false;

    public static function init(pocket:Dynamic, overlay:Overlay):Void {
        if (_initialized) return;
        _initialized = true;
        _pocket = pocket;
        _overlay = overlay;

        setupDefs();
        buildButtons();
    }

    private static function setupDefs():Void {
        _defs = [
            {
                id: "smart_combat",
                label: "Smart Combat",
                defaultX: 205,
                defaultY: 10,
                activeText: "Combat: ON",
                inactiveText: "Combat: OFF",
                getState: function():Bool {
                    return (Api.combat != null && Api.combat.isRunning());
                },
                onToggle: function():Void {
                    var current = (Api.combat != null && Api.combat.isRunning());
                    var next = !current;
                    HelperSetting.setBool("api_smart_combat_active", next);
                    if (Api.combat != null) {
                        if (next) {
                            var confClass = HelperSetting.getString("api_smart_class", "Current");
                            var confMode = HelperSetting.getString("api_smart_mode", "Auto");
                            Api.combat.startSmartStandalone(confClass, confMode);
                        } else {
                            Api.combat.stop();
                        }
                    }
                    ApiNotificationManager.notify("Smart Combat: " + (next ? "Enabled" : "Disabled"));
                }
            },
            {
                id: "script_runner",
                label: "Script Runner",
                defaultX: 318,
                defaultY: 10,
                activeText: "Script: RUN",
                inactiveText: "Script: STOP",
                getState: function():Bool {
                    return ScriptManager.SINGLETON.isRunning;
                },
                onToggle: function():Void {
                    if (ScriptManager.SINGLETON.isRunning) {
                        ScriptManager.SINGLETON.stop();
                        ApiNotificationManager.notify("Script stopped.");
                    } else {
                        ScriptManager.SINGLETON.start();
                        if (ScriptManager.SINGLETON.isRunning) {
                            ApiNotificationManager.notify("Script started.");
                        } else {
                            ApiNotificationManager.notify("No script loaded! Open Script Manager to select one.");
                        }
                    }
                }
            },
            {
                id: "smart_enhance",
                label: "Smart Enhance",
                defaultX: 431,
                defaultY: 10,
                activeText: "Enhancing...",
                inactiveText: "Smart Enhance",
                getState: function():Bool {
                    return (Api.enhancement != null && Api.enhancement.isBusy);
                },
                onToggle: function():Void {
                    if (Api.enhancement != null) {
                        if (Api.enhancement.isBusy) {
                            ApiNotificationManager.notify("Enhancement queue is busy!");
                            return;
                        }
                        var curClass = (Api.player != null && Api.player.className != null && Api.player.className != "") ? Api.player.className : "Equipped Class";
                        ApiNotificationManager.notify("SmartEnhancing " + curClass + "...");
                        Api.enhancement.smartEnhance(null, function():Void {
                            ApiNotificationManager.notify("SmartEnhance finished!");
                        });
                    }
                }
            },
            {
                id: "infinite_range",
                label: "Infinite Range",
                defaultX: 657,
                defaultY: 10,
                activeText: "Range: ON",
                inactiveText: "Range: OFF",
                getState: function():Bool {
                    return (Api.combat != null && Api.combat.infiniteRange);
                },
                onToggle: function():Void {
                    var cur = HelperSetting.getBool("api_infinite_range", false);
                    var next = !cur;
                    HelperSetting.setBool("api_infinite_range", next);
                    if (Api.combat != null) {
                        Api.combat.infiniteRange = next;
                        if (next) Api.combat.applyInfiniteRange();
                    }
                    ApiNotificationManager.notify("Infinite Range: " + (next ? "Enabled" : "Disabled"));
                }
            },
            {
                id: "accept_loot",
                label: "Accept Loot",
                defaultX: 770,
                defaultY: 10,
                activeText: "Loot: ON",
                inactiveText: "Loot: OFF",
                getState: function():Bool {
                    return (Api.drop != null && Api.drop.acceptAll);
                },
                onToggle: function():Void {
                    var cur = HelperSetting.getBool("api_accept_loot", false);
                    var next = !cur;
                    HelperSetting.setBool("api_accept_loot", next);
                    if (Api.drop != null) {
                        Api.drop.acceptAll = next;
                        if (next) {
                            Api.drop.scanScreenDrops();
                            Api.drop.acceptAllDrops();
                        }
                    }
                    ApiNotificationManager.notify("Accept Loot: " + (next ? "Enabled" : "Disabled"));
                }
            },
            {
                id: "toggle_bank",
                label: "Bank",
                defaultX: 544,
                defaultY: 10,
                activeText: "Bank",
                inactiveText: "Bank",
                getState: null,
                onToggle: function():Void {
                    if (Api.inventory != null) {
                        Api.inventory.toggleBank();
                    }
                }
            },
            {
                id: "provoke_all",
                label: "Provoke All",
                defaultX: 883,
                defaultY: 10,
                activeText: "Provoke: ON",
                inactiveText: "Provoke: OFF",
                getState: function():Bool {
                    return (Api.combat != null && Api.combat.autoProvoke);
                },
                onToggle: function():Void {
                    var cur = (Api.combat != null && Api.combat.autoProvoke);
                    var next = !cur;
                    if (Api.combat != null) {
                        Api.combat.provokeAll(next);
                    }
                    ApiNotificationManager.notify("Provoke All: " + (next ? "Enabled" : "Disabled"));
                }
            }
        ];
    }

    private static function buildButtons():Void {
        var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);

        var attachToStage = function(stageObj:Dynamic):Void {
            if (stageObj == null) return;
            for (def in _defs) {
                if (!_buttons.exists(def.id)) {
                    var btn = createButton(def, stageObj);
                    _buttons.set(def.id, btn);
                    stageObj.addChild(btn);
                }
            }
        };

        if (theStage != null) {
            attachToStage(theStage);
        } else if (_overlay != null) {
            _overlay.addEventListener(Event.ADDED_TO_STAGE, function(ev:Event):Void {
                if (_overlay.stage != null) {
                    attachToStage(_overlay.stage);
                }
            });
        }
    }

    private static function createButton(def:HudButtonDef, theStage:Dynamic):Sprite {
        var btnW:Float = 106;
        var btnH:Float = 30;

        var btn = new Sprite();
        btn.buttonMode = true;
        btn.mouseChildren = false;

        // Position restoring
        var savedX = HelperSetting.getInt("api_hud_" + def.id + "_x", -1);
        var savedY = HelperSetting.getInt("api_hud_" + def.id + "_y", -1);
        btn.x = (savedX >= 0) ? savedX : def.defaultX;
        btn.y = (savedY >= 0) ? savedY : def.defaultY;

        var hasIndicator:Bool = (def.id != "toggle_bank");

        var txt = new TextField();
        var fmt = new TextFormat("_sans", 11, 0xEEEEEE, true);
        fmt.align = hasIndicator ? TextFormatAlign.LEFT : TextFormatAlign.CENTER;
        txt.defaultTextFormat = fmt;
        txt.x = hasIndicator ? 21 : 0;
        txt.y = 6;
        txt.width = hasIndicator ? (btnW - 24) : btnW;
        txt.height = 20;
        txt.selectable = false;
        txt.mouseEnabled = false;
        btn.addChild(txt);

        var lastActive:Int = -1;
        var isHovered:Bool = false;

        var renderBtn = function(active:Bool, hover:Bool):Void {
            btn.graphics.clear();
            var bg:Int = 0x161616;
            var border:Int = 0x2E2E2E;
            var textColor:Int = 0xCCCCCC;

            if (active) {
                if (def.id == "smart_enhance") {
                    bg = hover ? 0x2A1C0E : 0x1E1408;
                    border = hover ? 0xFFA726 : 0xD97706;
                    textColor = hover ? 0xFFE082 : 0xFFB74D;
                } else {
                    bg = hover ? 0x122B18 : 0x0C1F11;
                    border = hover ? 0x2ECC71 : 0x27AE60;
                    textColor = hover ? 0x76FF9F : 0x4CE87A;
                }
                txt.text = def.activeText;
            } else {
                bg = hover ? 0x242424 : 0x161616;
                border = hover ? 0x484848 : 0x2E2E2E;
                textColor = hover ? 0xFFFFFF : 0xCCCCCC;
                txt.text = def.inactiveText;
            }

            // Plate fill
            btn.graphics.beginFill(bg, 0.94);
            btn.graphics.lineStyle(1, border);
            btn.graphics.drawRoundRect(0, 0, btnW, btnH, 5, 5);
            btn.graphics.endFill();

            // Subtle top highlight line for crisp glass bevel look
            btn.graphics.lineStyle(1, hover ? 0x555555 : 0x383838, 0.55);
            btn.graphics.moveTo(3, 1);
            btn.graphics.lineTo(btnW - 3, 1);

            // Native vector LED status indicator dot
            if (hasIndicator) {
                var dotX:Float = 12;
                var dotY:Float = btnH / 2;
                btn.graphics.lineStyle(0, 0, 0);

                if (active) {
                    if (def.id == "smart_enhance") {
                        // Amber glow & core
                        btn.graphics.beginFill(0xFFA726, 0.35);
                        btn.graphics.drawCircle(dotX, dotY, 4.5);
                        btn.graphics.endFill();
                        btn.graphics.beginFill(0xFFB74D, 1.0);
                        btn.graphics.drawCircle(dotX, dotY, 2.5);
                        btn.graphics.endFill();
                    } else {
                        // Luminous green glow & core
                        btn.graphics.beginFill(0x2ECC71, 0.35);
                        btn.graphics.drawCircle(dotX, dotY, 4.5);
                        btn.graphics.endFill();
                        btn.graphics.beginFill(0x00E676, 1.0);
                        btn.graphics.drawCircle(dotX, dotY, 2.5);
                        btn.graphics.endFill();
                    }
                } else {
                    // Muted dark grey inactive dot
                    btn.graphics.beginFill(0x444444, 0.85);
                    btn.graphics.drawCircle(dotX, dotY, 2.5);
                    btn.graphics.endFill();
                }
            }

            txt.textColor = textColor;
        };

        var updateVisual = function():Void {
            var active = (def.getState != null) ? def.getState() : false;
            var activeInt = active ? 1 : 0;
            if (activeInt != lastActive) {
                lastActive = activeInt;
                renderBtn(active, isHovered);
            }
        };

        btn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            isHovered = true;
            renderBtn(lastActive == 1, true);
        });

        btn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            isHovered = false;
            renderBtn(lastActive == 1, false);
        });

        // Fast bitmap caching for Flash AIR rendering performance
        btn.cacheAsBitmap = true;

        // Drag & Drop
        var isDragging:Bool = false;
        var hasDragged:Bool = false;
        var dragStartX:Float = 0;
        var dragStartY:Float = 0;

        btn.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            isDragging = true;
            hasDragged = false;
            btn.cacheAsBitmap = false;
            dragStartX = e.stageX - btn.x;
            dragStartY = e.stageY - btn.y;
        });

        theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (isDragging) {
                var dx = (e.stageX - dragStartX) - btn.x;
                var dy = (e.stageY - dragStartY) - btn.y;
                if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
                    hasDragged = true;
                }
                var nx:Float = Math.round(e.stageX - dragStartX);
                var ny:Float = Math.round(e.stageY - dragStartY);
                var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
                var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 500;
                if (nx < 0) nx = 0;
                if (ny < 0) ny = 0;
                if (nx > sw - btnW) nx = sw - btnW;
                if (ny > sh - btnH) ny = sh - btnH;
                btn.x = nx;
                btn.y = ny;
            }
        });

        theStage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            if (isDragging) {
                btn.cacheAsBitmap = true;
                if (hasDragged) {
                    HelperSetting.setInt("api_hud_" + def.id + "_x", Math.round(btn.x));
                    HelperSetting.setInt("api_hud_" + def.id + "_y", Math.round(btn.y));
                }
            }
            isDragging = false;
        });

        btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (hasDragged) {
                hasDragged = false;
                return;
            }
            if (def.onToggle != null) {
                def.onToggle();
                lastActive = -1; // Force immediate visual refresh
                updateVisual();
            }
        });

        // Visibility and live state update loop
        btn.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            var isEnabled = HelperSetting.getBool("api_hud_" + def.id + "_enabled", false);
            if (!isEnabled) {
                btn.visible = false;
                return;
            }
            var isPanelOpen:Bool = (_overlay != null && (_overlay.currentFrameLabel == "Panel" || ApiDashboardModal.isOpen()));
            btn.visible = !isPanelOpen;
            if (btn.visible) {
                updateVisual();
            }
        });

        updateVisual();
        return btn;
    }

    public static function isButtonEnabled(id:String):Bool {
        return HelperSetting.getBool("api_hud_" + id + "_enabled", false);
    }

    public static function setButtonEnabled(id:String, enabled:Bool):Void {
        HelperSetting.setBool("api_hud_" + id + "_enabled", enabled);
    }

    public static function resetAllPositions():Void {
        for (def in _defs) {
            HelperSetting.setInt("api_hud_" + def.id + "_x", Math.round(def.defaultX));
            HelperSetting.setInt("api_hud_" + def.id + "_y", Math.round(def.defaultY));
            var btn = _buttons.get(def.id);
            if (btn != null) {
                btn.x = def.defaultX;
                btn.y = def.defaultY;
            }
        }
        try {
            ApiMenus.resetMenuButtonPosition();
        } catch (_:Dynamic) {}
    }
}
#else
class ApiHudManager {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isButtonEnabled(id:String):Bool return false;
    public static function setButtonEnabled(id:String, enabled:Bool):Void {}
    public static function resetAllPositions():Void {}
}
#end
