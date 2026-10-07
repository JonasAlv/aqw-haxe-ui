package ui;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import com.aqwapi.Api;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.utils.ApiLogger;
import ui.Overlay;
import ui.ApiDashboardModal;
import ui.ApiNotificationManager;
import util.HelperSetting;

/**
 * Compact in-game Quick Tools Widget.
 *
 * Groups all essential utility toggles into an elegant, draggable, collapsible widget:
 * - Row 1 (Always accessible): Script Runner | Lag Killer
 * - Row 2: Infinite Range | Accept Loot
 * - Row 3: Provoke All | Bank
 * - Row 4: Smart Enhance | Dashboard Menu
 */
class ApiToolsWidget {
    private static var _pocket:Dynamic = null;
    private static var _overlay:Overlay = null;
    private static var _widget:Sprite = null;
    private static var _initialized:Bool = false;

    // Component references
    private static var _bg:Sprite = null;
    private static var _headerBar:Sprite = null;
    private static var _bodyContainer:Sprite = null;

    private static var _btnScript:Sprite = null;
    private static var _btnLag:Sprite = null;
    private static var _btnRange:Sprite = null;
    private static var _btnLoot:Sprite = null;
    private static var _btnProvoke:Sprite = null;
    private static var _btnBank:Sprite = null;
    private static var _btnEnhance:Sprite = null;
    private static var _btnMenu:Sprite = null;

    private static var _btnCollapse:Sprite = null;
    private static var _txtCollapse:TextField = null;

    // State
    private static var _isCollapsed:Bool = false;

    private static inline var WIDGET_W:Float = 230;
    private static inline var HEIGHT_EXPANDED:Float = 148;
    private static inline var HEIGHT_COLLAPSED:Float = 56;

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
        _widget.name = "ApiToolsWidget";

        // Restore saved position
        var savedX = HelperSetting.getInt("api_widget_tools_x", -1);
        var savedY = HelperSetting.getInt("api_widget_tools_y", -1);
        var defaultX:Float = 445;
        var defaultY:Float = 82;

        var initX:Float = (savedX >= 0) ? savedX : defaultX;
        var initY:Float = (savedY >= 0) ? savedY : defaultY;

        var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
        var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
        if (initX > sw - WIDGET_W) initX = sw - WIDGET_W;
        if (initY > sh - HEIGHT_EXPANDED) initY = sh - HEIGHT_EXPANDED;
        if (initX < 0) initX = 0;
        if (initY < 0) initY = 0;

        _widget.x = initX;
        _widget.y = initY;

        _isCollapsed = HelperSetting.getBool("api_widget_tools_collapsed", false);

        // 1. Background plate
        _bg = new Sprite();
        _widget.addChild(_bg);

        // 2. Header Bar (Drag zone)
        _headerBar = new Sprite();
        _headerBar.buttonMode = true;
        _widget.addChild(_headerBar);

        // Header Cyan Accent
        var cyanAccent = new Shape();
        cyanAccent.graphics.beginFill(0x00BCD4, 1.0);
        cyanAccent.graphics.drawRoundRect(6, 4, 3, 12, 1, 1);
        cyanAccent.graphics.endFill();
        _headerBar.addChild(cyanAccent);

        // Header Title
        var titleTxt = new TextField();
        var titleFmt = new TextFormat("_sans", 10, 0xBBBBBB, true);
        titleTxt.defaultTextFormat = titleFmt;
        titleTxt.text = "Quick Tools";
        titleTxt.x = 13;
        titleTxt.y = 3;
        titleTxt.width = 150;
        titleTxt.height = 16;
        titleTxt.selectable = false;
        titleTxt.mouseEnabled = false;
        _headerBar.addChild(titleTxt);

        // Header Collapse Button [-] / [+]
        _btnCollapse = new Sprite();
        _btnCollapse.buttonMode = true;
        _btnCollapse.x = WIDGET_W - 22;
        _btnCollapse.y = 2;
        _txtCollapse = new TextField();
        var colFmt = new TextFormat("_sans", 11, 0x888888, true);
        colFmt.align = TextFormatAlign.CENTER;
        _txtCollapse.defaultTextFormat = colFmt;
        _txtCollapse.text = _isCollapsed ? "+" : "_";
        _txtCollapse.width = 18;
        _txtCollapse.height = 18;
        _txtCollapse.selectable = false;
        _txtCollapse.mouseEnabled = false;
        _btnCollapse.addChild(_txtCollapse);
        _headerBar.addChild(_btnCollapse);

        _btnCollapse.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            e.stopPropagation();
            _isCollapsed = !_isCollapsed;
            HelperSetting.setBool("api_widget_tools_collapsed", _isCollapsed);
            _txtCollapse.text = _isCollapsed ? "+" : "_";
            updateLayout();
        });

        // 3. Row 1: Script Runner | Lag Killer (104px each, permanent on row 1)
        var btnW:Float = 104;
        var btnH:Float = 26;

        _btnScript = createActionButton(btnW, btnH);
        _btnScript.x = 8;
        _btnScript.y = 22;
        _widget.addChild(_btnScript);

        _btnLag = createActionButton(btnW, btnH);
        _btnLag.x = 118;
        _btnLag.y = 22;
        _widget.addChild(_btnLag);

        _btnScript.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            toggleScript();
        });

        _btnLag.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            toggleLagKiller();
        });

        // 4. Body Container (Rows 2, 3, 4)
        _bodyContainer = new Sprite();
        _widget.addChild(_bodyContainer);

        // Row 2: Infinite Range | Accept Loot
        _btnRange = createActionButton(btnW, btnH);
        _btnRange.x = 8;
        _btnRange.y = 52;
        _bodyContainer.addChild(_btnRange);

        _btnLoot = createActionButton(btnW, btnH);
        _btnLoot.x = 118;
        _btnLoot.y = 52;
        _bodyContainer.addChild(_btnLoot);

        _btnRange.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            toggleInfiniteRange();
        });

        _btnLoot.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            toggleAcceptLoot();
        });

        // Row 3: Provoke All | Bank
        _btnProvoke = createActionButton(btnW, btnH);
        _btnProvoke.x = 8;
        _btnProvoke.y = 82;
        _bodyContainer.addChild(_btnProvoke);

        _btnBank = createActionButton(btnW, btnH, false);
        _btnBank.x = 118;
        _btnBank.y = 82;
        _bodyContainer.addChild(_btnBank);

        _btnProvoke.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            toggleProvokeAll();
        });

        _btnBank.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            toggleBank();
        });

        // Row 4: Smart Enhance | Dashboard Menu
        _btnEnhance = createActionButton(btnW, btnH);
        _btnEnhance.x = 8;
        _btnEnhance.y = 112;
        _bodyContainer.addChild(_btnEnhance);

        _btnMenu = createActionButton(btnW, btnH, false);
        _btnMenu.x = 118;
        _btnMenu.y = 112;
        _bodyContainer.addChild(_btnMenu);

        _btnEnhance.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            triggerSmartEnhance();
        });

        _btnMenu.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            openDashboard();
        });

        // 5. Drag & Drop Handling
        setupDragging(theStage);

        // 6. Live frame state loop
        _widget.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            var isEnabled = HelperSetting.getBool("api_widget_tools_enabled", true);
            if (!isEnabled) {
                _widget.visible = false;
                return;
            }
            var isPanelOpen:Bool = (_overlay != null && (_overlay.currentFrameLabel == "Panel" || ApiDashboardModal.isOpen()));
            _widget.visible = !isPanelOpen;
            if (_widget.visible) {
                updateButtonVisuals();
            }
        });

        updateLayout();
        updateButtonVisuals();

        theStage.addChild(_widget);
    }

    private static function createActionButton(w:Float, h:Float, hasDot:Bool = true):Sprite {
        var sp = new Sprite();
        sp.buttonMode = true;
        sp.mouseChildren = false;

        if (hasDot) {
            var dot = new Shape();
            dot.name = "dot";
            sp.addChild(dot);
        }

        var txt = new TextField();
        txt.name = "label";
        var fmt = new TextFormat("_sans", 11, 0xCCCCCC, true);
        fmt.align = hasDot ? TextFormatAlign.LEFT : TextFormatAlign.CENTER;
        txt.defaultTextFormat = fmt;
        txt.x = hasDot ? 21 : 0;
        txt.y = 4;
        txt.width = hasDot ? (w - 24) : w;
        txt.height = 18;
        txt.selectable = false;
        txt.mouseEnabled = false;
        sp.addChild(txt);

        return sp;
    }

    private static function updateLayout():Void {
        var h:Float = _isCollapsed ? HEIGHT_COLLAPSED : HEIGHT_EXPANDED;

        _bg.graphics.clear();
        _bg.graphics.beginFill(0x161616, 0.94);
        _bg.graphics.lineStyle(1, 0x2E2E2E);
        _bg.graphics.drawRoundRect(0, 0, WIDGET_W, h, 6, 6);
        _bg.graphics.endFill();

        // Top bevel highlight line
        _bg.graphics.lineStyle(1, 0x383838, 0.55);
        _bg.graphics.moveTo(3, 1);
        _bg.graphics.lineTo(WIDGET_W - 3, 1);

        _bodyContainer.visible = !_isCollapsed;
    }

    // Cached states for zero-garbage rendering
    private static var _lastScriptActive:Int = -1;
    private static var _lastLagActive:Int = -1;
    private static var _lastRangeActive:Int = -1;
    private static var _lastLootActive:Int = -1;
    private static var _lastProvokeActive:Int = -1;
    private static var _lastEnhanceActive:Int = -1;

    private static function updateButtonVisuals():Void {
        // 1. Script Runner
        var isScript = ScriptManager.SINGLETON.isRunning;
        var sInt = isScript ? 1 : 0;
        if (sInt != _lastScriptActive) {
            _lastScriptActive = sInt;
            renderBtnStyle(_btnScript, isScript, "Script: RUN", "Script: STOP", 104, 26);
        }

        // 2. Lag Killer
        var isLag = (Api.visual != null && Api.visual.lagKiller);
        var lInt = isLag ? 1 : 0;
        if (lInt != _lastLagActive) {
            _lastLagActive = lInt;
            renderBtnStyle(_btnLag, isLag, "Lag: ON", "Lag: OFF", 104, 26);
        }

        // If collapsed, only Row 1 buttons are visible
        if (_isCollapsed) return;

        // 3. Infinite Range
        var isRange = (Api.combat != null && Api.combat.infiniteRange);
        var rInt = isRange ? 1 : 0;
        if (rInt != _lastRangeActive) {
            _lastRangeActive = rInt;
            renderBtnStyle(_btnRange, isRange, "Range: ON", "Range: OFF", 104, 26);
        }

        // 4. Accept Loot
        var isLoot = (Api.drop != null && Api.drop.acceptAll);
        var loInt = isLoot ? 1 : 0;
        if (loInt != _lastLootActive) {
            _lastLootActive = loInt;
            renderBtnStyle(_btnLoot, isLoot, "Loot: ON", "Loot: OFF", 104, 26);
        }

        // 5. Provoke All
        var isProvoke = (Api.combat != null && Api.combat.autoProvoke);
        var pInt = isProvoke ? 1 : 0;
        if (pInt != _lastProvokeActive) {
            _lastProvokeActive = pInt;
            renderBtnStyle(_btnProvoke, isProvoke, "Provoke: ON", "Provoke: OFF", 104, 26);
        }

        // 6. Bank (Static action button)
        renderActionBtnStyle(_btnBank, "Bank", 104, 26);

        // 7. Smart Enhance
        var isEnhBusy = (Api.enhancement != null && Api.enhancement.isBusy);
        var eInt = isEnhBusy ? 1 : 0;
        if (eInt != _lastEnhanceActive) {
            _lastEnhanceActive = eInt;
            if (isEnhBusy) {
                renderAmberBtnStyle(_btnEnhance, "Enhancing...", 104, 26);
            } else {
                renderBtnStyle(_btnEnhance, false, "Enhance", "Enhance", 104, 26);
            }
        }

        // 8. Menu / Dashboard (Static action button)
        renderActionBtnStyle(_btnMenu, "Menu", 104, 26);
    }

    private static function renderBtnStyle(btn:Sprite, active:Bool, onText:String, offText:String, w:Float, h:Float):Void {
        btn.graphics.clear();
        var bg = active ? 0x0C1F11 : 0x161616;
        var border = active ? 0x2ECC71 : 0x2E2E2E;
        var textColor = active ? 0x76FF9F : 0xCCCCCC;

        btn.graphics.beginFill(bg, 0.94);
        btn.graphics.lineStyle(1, border);
        btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
        btn.graphics.endFill();

        btn.graphics.lineStyle(1, active ? 0x2ECC71 : 0x383838, 0.55);
        btn.graphics.moveTo(2, 1);
        btn.graphics.lineTo(w - 2, 1);

        var dot:Shape = cast btn.getChildByName("dot");
        if (dot != null) {
            dot.graphics.clear();
            var dotX:Float = 11;
            var dotY:Float = h / 2;
            dot.graphics.lineStyle(0, 0, 0);
            if (active) {
                dot.graphics.beginFill(0x2ECC71, 0.35);
                dot.graphics.drawCircle(dotX, dotY, 4.5);
                dot.graphics.endFill();
                dot.graphics.beginFill(0x00E676, 1.0);
                dot.graphics.drawCircle(dotX, dotY, 2.5);
                dot.graphics.endFill();
            } else {
                dot.graphics.beginFill(0x444444, 0.85);
                dot.graphics.drawCircle(dotX, dotY, 2.5);
                dot.graphics.endFill();
            }
        }

        var lbl:TextField = cast btn.getChildByName("label");
        if (lbl != null) {
            lbl.text = active ? onText : offText;
            lbl.textColor = textColor;
        }
    }

    private static function renderAmberBtnStyle(btn:Sprite, text:String, w:Float, h:Float):Void {
        btn.graphics.clear();
        btn.graphics.beginFill(0x1E1408, 0.94);
        btn.graphics.lineStyle(1, 0xD97706);
        btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
        btn.graphics.endFill();

        btn.graphics.lineStyle(1, 0xFFA726, 0.55);
        btn.graphics.moveTo(2, 1);
        btn.graphics.lineTo(w - 2, 1);

        var dot:Shape = cast btn.getChildByName("dot");
        if (dot != null) {
            dot.graphics.clear();
            var dotX:Float = 11;
            var dotY:Float = h / 2;
            dot.graphics.lineStyle(0, 0, 0);
            dot.graphics.beginFill(0xFFA726, 0.35);
            dot.graphics.drawCircle(dotX, dotY, 4.5);
            dot.graphics.endFill();
            dot.graphics.beginFill(0xFFB74D, 1.0);
            dot.graphics.drawCircle(dotX, dotY, 2.5);
            dot.graphics.endFill();
        }

        var lbl:TextField = cast btn.getChildByName("label");
        if (lbl != null) {
            lbl.text = text;
            lbl.textColor = 0xFFE082;
        }
    }

    private static function renderActionBtnStyle(btn:Sprite, text:String, w:Float, h:Float):Void {
        btn.graphics.clear();
        btn.graphics.beginFill(0x161616, 0.94);
        btn.graphics.lineStyle(1, 0x2E2E2E);
        btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
        btn.graphics.endFill();

        btn.graphics.lineStyle(1, 0x383838, 0.55);
        btn.graphics.moveTo(2, 1);
        btn.graphics.lineTo(w - 2, 1);

        var lbl:TextField = cast btn.getChildByName("label");
        if (lbl != null) {
            lbl.text = text;
            lbl.textColor = 0xCCCCCC;
        }
    }

    // Toggle Handlers
    private static function toggleScript():Void {
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
        _lastScriptActive = -1;
        updateButtonVisuals();
    }

    private static function toggleLagKiller():Void {
        if (Api.visual != null) {
            var cur = Api.visual.lagKiller;
            var next = !cur;
            Api.visual.lagKiller = next;
            ApiNotificationManager.notify("Lag Killer: " + (next ? "Enabled (High FPS)" : "Disabled"));
        }
        _lastLagActive = -1;
        updateButtonVisuals();
    }

    private static function toggleInfiniteRange():Void {
        var cur = HelperSetting.getBool("api_infinite_range", false);
        var next = !cur;
        HelperSetting.setBool("api_infinite_range", next);
        if (Api.combat != null) {
            Api.combat.infiniteRange = next;
            if (next) Api.combat.applyInfiniteRange();
        }
        ApiNotificationManager.notify("Infinite Range: " + (next ? "Enabled" : "Disabled"));
        _lastRangeActive = -1;
        updateButtonVisuals();
    }

    private static function toggleAcceptLoot():Void {
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
        _lastLootActive = -1;
        updateButtonVisuals();
    }

    private static function toggleProvokeAll():Void {
        var cur = (Api.combat != null && Api.combat.autoProvoke);
        var next = !cur;
        if (Api.combat != null) {
            Api.combat.provokeAll(next);
        }
        ApiNotificationManager.notify("Provoke All: " + (next ? "Enabled" : "Disabled"));
        _lastProvokeActive = -1;
        updateButtonVisuals();
    }

    private static function toggleBank():Void {
        if (Api.inventory != null) {
            Api.inventory.toggleBank();
        }
    }

    private static function triggerSmartEnhance():Void {
        if (Api.enhancement != null) {
            if (Api.enhancement.isBusy) {
                ApiNotificationManager.notify("Enhancement queue is busy!");
                return;
            }
            var curClass = (Api.player != null && Api.player.className != null && Api.player.className != "") ? Api.player.className : "Equipped Class";
            ApiNotificationManager.notify("SmartEnhancing " + curClass + "...");
            _lastEnhanceActive = -1;
            updateButtonVisuals();
            Api.enhancement.smartEnhance(null, function():Void {
                ApiNotificationManager.notify("SmartEnhance finished!");
                _lastEnhanceActive = -1;
                updateButtonVisuals();
            });
        }
    }

    private static function openDashboard():Void {
        ApiDashboardModal.show(_overlay);
    }

    // Dragging setup
    private static function setupDragging(theStage:Dynamic):Void {
        var isDragging:Bool = false;
        var hasDragged:Bool = false;
        var dragStartX:Float = 0;
        var dragStartY:Float = 0;

        _headerBar.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            isDragging = true;
            hasDragged = false;
            _widget.cacheAsBitmap = false;
            dragStartX = e.stageX - _widget.x;
            dragStartY = e.stageY - _widget.y;
        });

        theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (isDragging) {
                var dx = (e.stageX - dragStartX) - _widget.x;
                var dy = (e.stageY - dragStartY) - _widget.y;
                if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
                    hasDragged = true;
                }
                var nx:Float = Math.round(e.stageX - dragStartX);
                var ny:Float = Math.round(e.stageY - dragStartY);
                var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
                var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
                var curH:Float = _isCollapsed ? HEIGHT_COLLAPSED : HEIGHT_EXPANDED;
                if (nx < 0) nx = 0;
                if (ny < 0) ny = 0;
                if (nx > sw - WIDGET_W) nx = sw - WIDGET_W;
                if (ny > sh - curH) ny = sh - curH;
                _widget.x = nx;
                _widget.y = ny;
            }
        });

        theStage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            if (isDragging) {
                isDragging = false;
                _widget.cacheAsBitmap = true;
                if (hasDragged) {
                    HelperSetting.setInt("api_widget_tools_x", Math.round(_widget.x));
                    HelperSetting.setInt("api_widget_tools_y", Math.round(_widget.y));
                }
            }
        });
    }

    public static function isWidgetEnabled():Bool {
        return HelperSetting.getBool("api_widget_tools_enabled", true);
    }

    public static function setWidgetEnabled(enabled:Bool):Void {
        HelperSetting.setBool("api_widget_tools_enabled", enabled);
        if (_widget != null) {
            _widget.visible = enabled;
        }
    }

    public static function resetPosition():Void {
        HelperSetting.setInt("api_widget_tools_x", 445);
        HelperSetting.setInt("api_widget_tools_y", 82);
        if (_widget != null) {
            _widget.x = 445;
            _widget.y = 82;
        }
    }
}
#else
class ApiToolsWidget {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isWidgetEnabled():Bool return false;
    public static function setWidgetEnabled(enabled:Bool):Void {}
    public static function resetPosition():Void {}
}
#end
