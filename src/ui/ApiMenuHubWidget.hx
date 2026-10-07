package ui;

#if flash
import com.aqwapi.Api;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.utils.ApiConfig;
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import ui.Overlay;
import ui.prompts.ApiPrompts;
import util.HelperSetting;

/**
 * ApiMenuHubWidget:
 * Compact on-screen Mod Menu Hub.
 * When collapsed: exact same size as the old menu button (78x26px).
 * When clicked: smoothly expands downwards into a 230px wide category drawer
 * providing full access to all bot features, automation, and game tweaks.
 */
class ApiMenuHubWidget {
    public static inline var COLLAPSED_W:Float = 78;
    public static inline var COLLAPSED_H:Float = 26;
    public static inline var EXPANDED_W:Float = 230;

    private static var _pocket:Dynamic = null;
    private static var _overlay:Overlay = null;
    private static var _theStage:Dynamic = null;

    private static var _widget:Sprite = null;
    private static var _bg:Sprite = null;
    private static var _headerBar:Sprite = null;
    private static var _redAccent:Shape = null;
    private static var _titleTxt:TextField = null;
    private static var _btnConfig:Sprite = null;
    private static var _btnCollapse:Sprite = null;
    private static var _bodyContainer:Sprite = null;

    private static var _isCollapsed:Bool = true;
    private static var _activeCategory:String = "automation"; // "scripts", "automation", "enhancements", "tweaks", "widgets", or null
    private static var _currentTotalHeight:Float = COLLAPSED_H;

    // Track state for live updates
    private static var _liveStateButtons:Array<{ btn:Sprite, dot:Shape, lbl:TextField, getState:Void->Bool, activeText:String, inactiveText:String, w:Float, h:Float }> = [];

    public static function init(pocket:Dynamic, overlay:Overlay):Void {
        _pocket = pocket;
        _overlay = overlay;
        _theStage = (pocket != null && pocket.stage != null) ? pocket.stage : overlay.stage;

        _isCollapsed = HelperSetting.getBool("api_hub_widget_collapsed", true);

        if (_theStage != null) {
            buildUI();
        } else {
            overlay.addEventListener(Event.ADDED_TO_STAGE, function(e:Event):Void {
                _theStage = overlay.stage;
                buildUI();
            });
        }
    }

    public static function getWidget():Sprite {
        return _widget;
    }

    public static function resetPosition():Void {
        HelperSetting.setInt("api_hub_widget_x", 80);
        HelperSetting.setInt("api_hub_widget_y", 10);
        if (_widget != null) {
            _widget.x = 80;
            _widget.y = 10;
        }
    }

    public static function resetAllWidgets():Void {
        resetPosition();
        ApiCombatWidget.resetPosition();
        ApiToolsWidget.resetAllPositions();
        ApiNotificationManager.notify("All widgets reset to default positions!");
    }

    private static function buildUI():Void {
        if (_widget != null) return;

        _widget = new Sprite();
        _widget.name = "ApiMenuHubWidget";

        var savedX = HelperSetting.getInt("api_hub_widget_x", 80);
        var savedY = HelperSetting.getInt("api_hub_widget_y", 10);
        var sw:Float = (_theStage != null && _theStage.stageWidth > 0) ? _theStage.stageWidth : 960;
        var sh:Float = (_theStage != null && _theStage.stageHeight > 0) ? _theStage.stageHeight : 550;

        if (savedX > sw - EXPANDED_W) savedX = Math.round(sw - EXPANDED_W - 4);
        if (savedY > sh - 100) savedY = Math.round(sh - 100);
        if (savedX < 0) savedX = 4;
        if (savedY < 0) savedY = 4;

        _widget.x = savedX;
        _widget.y = savedY;

        // 1. Background Plate
        _bg = new Sprite();
        _widget.addChild(_bg);

        // 2. Header Bar
        _headerBar = new Sprite();
        _headerBar.buttonMode = true;
        _headerBar.useHandCursor = true;
        _widget.addChild(_headerBar);

        // Header Crimson Accent Bar (Left)
        _redAccent = new Shape();
        _redAccent.graphics.beginFill(0xC82333, 1.0);
        _redAccent.graphics.drawRoundRect(5, 5, 3, 16, 1, 1);
        _redAccent.graphics.endFill();
        _headerBar.addChild(_redAccent);

        // Header Title Text
        _titleTxt = new TextField();
        var titleFmt = new TextFormat("_sans", 11, 0xEEEEEE, true);
        _titleTxt.defaultTextFormat = titleFmt;
        _titleTxt.x = 12;
        _titleTxt.y = 4;
        _titleTxt.height = 18;
        _titleTxt.selectable = false;
        _titleTxt.mouseEnabled = false;
        _headerBar.addChild(_titleTxt);

        // Config Gear Button (Opens Dashboard Modal) - only visible when expanded
        _btnConfig = new Sprite();
        _btnConfig.buttonMode = true;
        _btnConfig.y = 3;
        renderConfigIcon(false);
        _headerBar.addChild(_btnConfig);

        _btnConfig.addEventListener(MouseEvent.MOUSE_OVER, function(e) renderConfigIcon(true));
        _btnConfig.addEventListener(MouseEvent.MOUSE_OUT, function(e) renderConfigIcon(false));
        _btnConfig.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            e.stopPropagation();
            if (ApiDashboardModal.isOpen()) {
                ApiDashboardModal.close();
            } else {
                ApiDashboardModal.show(_overlay, _pocket);
            }
        });

        // Collapse/Expand Chevron
        _btnCollapse = new Sprite();
        _btnCollapse.mouseEnabled = false;
        _btnCollapse.mouseChildren = false;
        _btnCollapse.y = 3;
        renderCollapseIcon(_isCollapsed, false);
        _headerBar.addChild(_btnCollapse);

        // Header Hover feedback
        _headerBar.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            _titleTxt.textColor = 0xFFFFFF;
            renderCollapseIcon(_isCollapsed, true);
            _bg.alpha = 1.0;
        });
        _headerBar.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            _titleTxt.textColor = 0xEEEEEE;
            renderCollapseIcon(_isCollapsed, false);
            _bg.alpha = _isCollapsed ? 0.78 : 0.94;
        });

        // 3. Body Container
        _bodyContainer = new Sprite();
        _bodyContainer.x = 0;
        _bodyContainer.y = 0;
        _widget.addChild(_bodyContainer);

        // 4. Drag & Drop Handling
        setupDragging();

        // 5. Live State Loop
        _widget.addEventListener(Event.ENTER_FRAME, onEnterFrame);

        // Attach to stage
        if (_theStage != null) {
            _theStage.addChild(_widget);
        }

        rebuildBodyLayout();
    }

    private static function toggleCollapse():Void {
        _isCollapsed = !_isCollapsed;
        HelperSetting.setBool("api_hub_widget_collapsed", _isCollapsed);
        renderCollapseIcon(_isCollapsed, false);
        rebuildBodyLayout();
    }

    private static function toggleCategory(catId:String):Void {
        if (_activeCategory == catId) {
            _activeCategory = null; // Fold closed
        } else {
            _activeCategory = catId; // Expand category
        }
        rebuildBodyLayout();
    }

    private static function rebuildBodyLayout():Void {
        while (_bodyContainer.numChildren > 0) _bodyContainer.removeChildAt(0);
        _liveStateButtons = [];

        var curW:Float = _isCollapsed ? COLLAPSED_W : EXPANDED_W;

        // Header sizing & visual state
        _headerBar.graphics.clear();
        _headerBar.graphics.beginFill(0x000000, 0.0);
        _headerBar.graphics.drawRect(0, 0, curW, COLLAPSED_H);
        _headerBar.graphics.endFill();

        if (_isCollapsed) {
            _titleTxt.text = "Menu";
            _titleTxt.width = 44;
            _btnConfig.visible = false;
            _btnCollapse.x = COLLAPSED_W - 20;

            _bodyContainer.visible = false;
            _currentTotalHeight = COLLAPSED_H;
            updateBackgroundGraphics();
            return;
        }

        // Expanded State
        _titleTxt.text = "Mod Hub";
        _titleTxt.width = EXPANDED_W - 58;
        _btnConfig.visible = true;
        _btnConfig.x = EXPANDED_W - 48;
        _btnCollapse.x = EXPANDED_W - 24;

        _bodyContainer.visible = true;
        var currY:Float = 26; // Start right below header bar

        // Category 1: Scripts & Bots
        currY = renderCategorySection("cat_scripts", "Scripts & Bots", 0x2196F3, currY, function(bodyY:Float):Float {
            var y = bodyY;
            // Row 1: Script Manager & Paste Script
            var btnMgr = createActionButton("Script Mgr", 104, 24, 8, y, function():Void {
                _overlay.gotoAndStop("Init");
                ApiPrompts.showScriptManager(_overlay);
            });
            var btnPaste = createActionButton("Paste Script", 104, 24, 118, y, function():Void {
                _overlay.gotoAndStop("Init");
                ApiPrompts.showPastePrompt(_overlay);
            });
            _bodyContainer.addChild(btnMgr);
            _bodyContainer.addChild(btnPaste);
            y += 28;

            // Row 2: Live Run/Stop Toggle
            var btnRun = createLiveToggleButton(
                "Run Script",
                214,
                24,
                8,
                y,
                function() return (ScriptManager.SINGLETON != null && ScriptManager.SINGLETON.isRunning),
                function() {
                    if (ScriptManager.SINGLETON.isRunning) {
                        ScriptManager.SINGLETON.stop();
                        ApiNotificationManager.notify("Script stopped.");
                    } else {
                        ScriptManager.SINGLETON.reset();
                        ScriptManager.SINGLETON.start();
                        ApiNotificationManager.notify("Script started.");
                    }
                },
                "Script: RUNNING",
                "Script: STOPPED"
            );
            _bodyContainer.addChild(btnRun);
            y += 28;
            return y;
        });

        // Category 2: Automation & Farm
        currY = renderCategorySection("cat_automation", "Automation & Farm", 0x00E676, currY, function(bodyY:Float):Float {
            var y = bodyY;
            // Row 1: Cutscenes & Death Spawn
            var tCutscenes = createCompactToggle("Cutscenes", 104, 22, 8, y, function() return ApiConfig.getBool("api_skip_cutscenes", false), function() {
                var next = !ApiConfig.getBool("api_skip_cutscenes", false);
                ApiConfig.setBool("api_skip_cutscenes", next);
                if (Api.map != null) Api.map.skipCutscenes = next;
                ApiNotificationManager.notify("Skip Cutscenes: " + (next ? "Enabled" : "Disabled"));
            });
            var tDeathSpawn = createCompactToggle("Death Spawn", 104, 22, 118, y, function() return ApiConfig.getBool("api_death_spawn", false), function() {
                var next = !ApiConfig.getBool("api_death_spawn", false);
                ApiConfig.setBool("api_death_spawn", next);
                if (Api.map != null) Api.map.autoDeathSpawn = next;
                ApiNotificationManager.notify("Death Spawn: " + (next ? "Enabled" : "Disabled"));
            });
            _bodyContainer.addChild(tCutscenes);
            _bodyContainer.addChild(tDeathSpawn);
            y += 25;

            // Row 2: Auto Loot & Accept ACs
            var tLoot = createCompactToggle("Auto Loot", 104, 22, 8, y, function() return ApiConfig.getBool("api_accept_loot", false), function() {
                var next = !ApiConfig.getBool("api_accept_loot", false);
                ApiConfig.setBool("api_accept_loot", next);
                if (Api.drop != null) {
                    Api.drop.acceptAll = next;
                    if (next) Api.drop.scanScreenDrops();
                }
                ApiNotificationManager.notify("Auto Loot: " + (next ? "Enabled" : "Disabled"));
            });
            var tAC = createCompactToggle("Accept ACs", 104, 22, 118, y, function() return ApiConfig.getBool("api_accept_ac_drops", false), function() {
                var next = !ApiConfig.getBool("api_accept_ac_drops", false);
                ApiConfig.setBool("api_accept_ac_drops", next);
                if (Api.drop != null) {
                    Api.drop.acceptACs = next;
                    if (next) Api.drop.scanScreenDrops();
                }
                ApiNotificationManager.notify("Accept AC Drops: " + (next ? "Enabled" : "Disabled"));
            });
            _bodyContainer.addChild(tLoot);
            _bodyContainer.addChild(tAC);
            y += 25;

            // Row 3: Provoke All & Infinite Range
            var tProvoke = createCompactToggle("Provoke All", 104, 22, 8, y, function() return (Api.combat != null && Api.combat.autoProvoke), function() {
                var cur = (Api.combat != null && Api.combat.autoProvoke);
                var next = !cur;
                if (Api.combat != null) Api.combat.provokeAll(next);
                ApiNotificationManager.notify("Provoke All: " + (next ? "Enabled" : "Disabled"));
            });
            var tRange = createCompactToggle("Inf Range", 104, 22, 118, y, function() return ApiConfig.getBool("api_infinite_range", false), function() {
                var next = !ApiConfig.getBool("api_infinite_range", false);
                ApiConfig.setBool("api_infinite_range", next);
                if (Api.combat != null) {
                    Api.combat.infiniteRange = next;
                    if (next) Api.combat.applyInfiniteRange();
                }
                ApiNotificationManager.notify("Infinite Range: " + (next ? "Enabled" : "Disabled"));
            });
            _bodyContainer.addChild(tProvoke);
            _bodyContainer.addChild(tRange);
            y += 25;

            // Row 4: Auto Relogin & Private Rooms
            var tRelogin = createCompactToggle("Auto Relogin", 104, 22, 8, y, function() return HelperSetting.getBool("api_auto_relogin", false), function() {
                var next = !HelperSetting.getBool("api_auto_relogin", false);
                HelperSetting.setBool("api_auto_relogin", next);
                ApiNotificationManager.notify("Auto Relogin: " + (next ? "Enabled" : "Disabled"));
            });
            var tPrivate = createCompactToggle("Private Room", 104, 22, 118, y, function() return ApiConfig.getBool("api_private_rooms", true), function() {
                var next = !ApiConfig.getBool("api_private_rooms", true);
                ApiConfig.setBool("api_private_rooms", next);
                if (Api.map != null) Api.map.usePrivateRoom = next;
                ApiNotificationManager.notify("Private Rooms: " + (next ? "Enabled" : "Disabled"));
            });
            _bodyContainer.addChild(tRelogin);
            _bodyContainer.addChild(tPrivate);
            y += 26;

            // Row 5: Auto-Quest & Bank Toggle
            var btnQuest = createActionButton("Auto-Quest Helper", 104, 24, 8, y, function():Void {
                _overlay.gotoAndStop("Init");
                ApiPrompts.showQuestPrompt(_overlay);
            });
            var btnBank = createActionButton("Toggle Bank", 104, 24, 118, y, function():Void {
                if (Api.inventory != null) Api.inventory.toggleBank();
            });
            _bodyContainer.addChild(btnQuest);
            _bodyContainer.addChild(btnBank);
            y += 28;

            // Row 6: Shop Loader
            var btnShop = createActionButton("Open Shop by ID", 214, 24, 8, y, function():Void {
                _overlay.gotoAndStop("Init");
                ApiPrompts.showShopPrompt(_overlay);
            });
            _bodyContainer.addChild(btnShop);
            y += 28;

            return y;
        });

        // Category 3: Enhancements & Loadouts
        currY = renderCategorySection("cat_enhancements", "Enhancements", 0xFFB300, currY, function(bodyY:Float):Float {
            var y = bodyY;
            var tSmart = createLiveToggleButton(
                "Smart Enhance",
                214,
                24,
                8,
                y,
                function() return ApiConfig.getBool("api_smart_enhance", false),
                function() {
                    var next = !ApiConfig.getBool("api_smart_enhance", false);
                    ApiConfig.setBool("api_smart_enhance", next);
                    ApiNotificationManager.notify("Smart Enhance: " + (next ? "Enabled" : "Disabled"));
                },
                "Smart Enhance: ON",
                "Smart Enhance: OFF",
                0xD97706
            );
            _bodyContainer.addChild(tSmart);
            y += 28;

            var btnCustom = createActionButton("Custom Enhancer", 104, 24, 8, y, function():Void {
                _overlay.gotoAndStop("Init");
                ApiPrompts.showCustomEnhancePrompt(_overlay);
            });
            var btnLoadouts = createActionButton("Class Loadouts", 104, 24, 118, y, function():Void {
                _overlay.gotoAndStop("Init");
                ApiPrompts.showLoadoutsPrompt(_overlay);
            });
            _bodyContainer.addChild(btnCustom);
            _bodyContainer.addChild(btnLoadouts);
            y += 28;

            return y;
        });

        // Category 4: Game & Lag Tweaks
        currY = renderCategorySection("cat_tweaks", "Game & Lag Tweaks", 0x00BCD4, currY, function(bodyY:Float):Float {
            var y = bodyY;
            var tArena = createCompactToggle("Clean Arena", 104, 22, 8, y, function() return ApiConfig.getBool("api_clean_arena", false), function() {
                var next = !ApiConfig.getBool("api_clean_arena", false);
                ApiConfig.setBool("api_clean_arena", next);
                if (Api.visual != null) Api.visual.cleanArena = next;
                ApiNotificationManager.notify("Clean Arena: " + (next ? "Enabled" : "Disabled"));
            });
            var tHidePlayers = createCompactToggle("Hide Players", 104, 22, 118, y, function() return (Api.visual != null && Api.visual.hidePlayers), function() {
                var cur = (Api.visual != null && Api.visual.hidePlayers);
                var next = !cur;
                if (Api.visual != null) Api.visual.hidePlayers = next;
                ApiNotificationManager.notify("Hide Players: " + (next ? "Enabled" : "Disabled"));
            });
            _bodyContainer.addChild(tArena);
            _bodyContainer.addChild(tHidePlayers);
            y += 25;

            var tHideMonsters = createCompactToggle("Hide Mobs", 104, 22, 8, y, function() return (Api.visual != null && Api.visual.hideMonsters), function() {
                var cur = (Api.visual != null && Api.visual.hideMonsters);
                var next = !cur;
                if (Api.visual != null) Api.visual.hideMonsters = next;
                ApiNotificationManager.notify("Hide Monsters: " + (next ? "Enabled" : "Disabled"));
            });
            var btnBlacklist = createActionButton("Blacklist Mgr", 104, 22, 118, y, function():Void {
                _overlay.gotoAndStop("Init");
                ApiPrompts.showBlacklistPrompt(_overlay);
            });
            _bodyContainer.addChild(tHideMonsters);
            _bodyContainer.addChild(btnBlacklist);
            y += 28;

            return y;
        });

        // Category 5: Widgets & HUD
        currY = renderCategorySection("cat_widgets", "Widgets & HUD", 0xAB47BC, currY, function(bodyY:Float):Float {
            var y = bodyY;
            var tCombat = createCompactToggle("Combat HUD", 104, 24, 8, y, function() return ApiCombatWidget.isWidgetEnabled(), function() {
                var next = !ApiCombatWidget.isWidgetEnabled();
                ApiCombatWidget.setWidgetEnabled(next);
                ApiNotificationManager.notify("Combat Widget: " + (next ? "Shown" : "Hidden"));
            });
            var btnAddWidget = createActionButton("+ Custom Widget", 104, 24, 118, y, function():Void {
                ApiToolsWidget.createNewWidget();
            });
            _bodyContainer.addChild(tCombat);
            _bodyContainer.addChild(btnAddWidget);
            y += 28;

            var btnResetAll = createActionButton("Reset All Widget Positions", 214, 24, 8, y, function():Void {
                resetAllWidgets();
            });
            _bodyContainer.addChild(btnResetAll);
            y += 28;

            return y;
        });

        // Footer Divider & Full Dashboard Button
        var div = new Shape();
        div.graphics.lineStyle(1, 0x2A2A2A, 0.7);
        div.graphics.moveTo(10, currY + 2);
        div.graphics.lineTo(EXPANDED_W - 10, currY + 2);
        _bodyContainer.addChild(div);
        currY += 7;

        var btnDash = createActionButton("Open Full Dashboard", 214, 26, 8, currY, function():Void {
            if (ApiDashboardModal.isOpen()) {
                ApiDashboardModal.close();
            } else {
                ApiDashboardModal.show(_overlay, _pocket);
            }
        }, 0xC82333);
        _bodyContainer.addChild(btnDash);
        currY += 31;

        _currentTotalHeight = currY;
        updateBackgroundGraphics();
    }

    private static function renderCategorySection(catId:String, title:String, accentColor:Int, startY:Float, renderContent:Float->Float):Float {
        var isOpened:Bool = (_activeCategory == catId);

        // Category Header Bar
        var catHeader = new Sprite();
        catHeader.buttonMode = true;
        catHeader.useHandCursor = true;
        catHeader.x = 6;
        catHeader.y = startY;

        var w = EXPANDED_W - 12;
        var h:Float = 24;

        var redrawCatHeader = function(hover:Bool):Void {
            catHeader.graphics.clear();
            catHeader.graphics.beginFill(hover ? 0x242424 : 0x1A1A1A, 0.95);
            catHeader.graphics.lineStyle(1, isOpened ? accentColor : (hover ? 0x444444 : 0x282828));
            catHeader.graphics.drawRoundRect(0, 0, w, h, 4, 4);
            catHeader.graphics.endFill();

            // Accent Pill
            catHeader.graphics.beginFill(accentColor, 1.0);
            catHeader.graphics.drawRoundRect(3, 4, 3, h - 8, 1, 1);
            catHeader.graphics.endFill();
        };
        redrawCatHeader(false);

        catHeader.addEventListener(MouseEvent.MOUSE_OVER, function(e) redrawCatHeader(true));
        catHeader.addEventListener(MouseEvent.MOUSE_OUT, function(e) redrawCatHeader(false));

        var titleTxt = new TextField();
        var fmt = new TextFormat("_sans", 11, 0xDDDDDD, true);
        titleTxt.defaultTextFormat = fmt;
        titleTxt.text = title;
        titleTxt.x = 12;
        titleTxt.y = 3;
        titleTxt.width = w - 35;
        titleTxt.height = 18;
        titleTxt.selectable = false;
        titleTxt.mouseEnabled = false;
        catHeader.addChild(titleTxt);

        // Vector Chevron (Right arrow when closed, Down arrow when open)
        var chev = new Shape();
        chev.graphics.lineStyle(2.0, isOpened ? accentColor : 0x888888, 1.0, true);
        var cx = w - 12.0;
        var cy = 12.0;
        if (isOpened) {
            // Down arrow
            chev.graphics.moveTo(cx - 3.5, cy - 2.0);
            chev.graphics.lineTo(cx, cy + 2.0);
            chev.graphics.lineTo(cx + 3.5, cy - 2.0);
        } else {
            // Right arrow
            chev.graphics.moveTo(cx - 2.0, cy - 3.5);
            chev.graphics.lineTo(cx + 2.0, cy);
            chev.graphics.lineTo(cx - 2.0, cy + 3.5);
        }
        catHeader.addChild(chev);

        catHeader.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            flashActionButton(catHeader);
            toggleCategory(catId);
        });

        _bodyContainer.addChild(catHeader);

        var nextY = startY + h + 4;
        if (isOpened) {
            nextY = renderContent(nextY);
            nextY += 2;
        }

        return nextY;
    }

    private static function updateBackgroundGraphics():Void {
        var w:Float = _isCollapsed ? COLLAPSED_W : EXPANDED_W;
        var h:Float = _isCollapsed ? COLLAPSED_H : _currentTotalHeight;
        var alpha:Float = _isCollapsed ? 0.78 : 0.94;

        _bg.graphics.clear();
        _bg.graphics.beginFill(0x161616, alpha);
        _bg.graphics.lineStyle(1, 0x2E2E2E, _isCollapsed ? 0.75 : 1.0);
        _bg.graphics.drawRoundRect(0, 0, w, h, 6, 6);
        _bg.graphics.endFill();

        // Top highlight line
        _bg.graphics.lineStyle(1, 0x383838, _isCollapsed ? 0.4 : 0.55);
        _bg.graphics.moveTo(3, 1);
        _bg.graphics.lineTo(w - 3, 1);
    }

    private static function flashActionButton(btn:Sprite):Void {
        if (btn == null) return;
        var prevAlpha = btn.alpha;
        btn.alpha = 1.0;
        var highlight = new Shape();
        highlight.graphics.lineStyle(1.8, 0x00FF88);
        highlight.graphics.drawRoundRect(0, 0, btn.width, btn.height, 4, 4);
        btn.addChild(highlight);
        haxe.Timer.delay(function():Void {
            if (highlight.parent != null) highlight.parent.removeChild(highlight);
            btn.alpha = prevAlpha;
        }, 120);
    }

    private static function createActionButton(label:String, w:Float, h:Float, x:Float, y:Float, onClick:Void->Void, ?accentBorder:Null<Int>):Sprite {
        var sp = new Sprite();
        sp.buttonMode = true;
        sp.x = x;
        sp.y = y;

        var baseBorder = (accentBorder != null) ? accentBorder : 0x2E2E2E;
        var baseBg = (accentBorder != null) ? 0x1E1212 : 0x161616;

        var redraw = function(hover:Bool):Void {
            sp.graphics.clear();
            sp.graphics.beginFill(hover ? 0x282828 : baseBg, 0.95);
            sp.graphics.lineStyle(1, hover ? 0x555555 : baseBorder);
            sp.graphics.drawRoundRect(0, 0, w, h, 4, 4);
            sp.graphics.endFill();

            sp.graphics.lineStyle(1, hover ? 0x555555 : 0x383838, 0.5);
            sp.graphics.moveTo(2, 1);
            sp.graphics.lineTo(w - 2, 1);
        };
        redraw(false);

        sp.addEventListener(MouseEvent.MOUSE_OVER, function(e) redraw(true));
        sp.addEventListener(MouseEvent.MOUSE_OUT, function(e) redraw(false));

        var txt = new TextField();
        var fmt = new TextFormat("_sans", 11, (accentBorder != null) ? 0xFF8888 : 0xCCCCCC, true);
        fmt.align = TextFormatAlign.CENTER;
        txt.defaultTextFormat = fmt;
        txt.text = label;
        txt.x = 0;
        txt.y = 3;
        txt.width = w;
        txt.height = h - 4;
        txt.selectable = false;
        txt.mouseEnabled = false;
        sp.addChild(txt);

        sp.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            flashActionButton(sp);
            if (onClick != null) onClick();
        });

        return sp;
    }

    private static function createCompactToggle(label:String, w:Float, h:Float, x:Float, y:Float, getState:Void->Bool, onToggle:Void->Void):Sprite {
        var sp = new Sprite();
        sp.buttonMode = true;
        sp.x = x;
        sp.y = y;

        var dot = new Shape();
        sp.addChild(dot);

        var txt = new TextField();
        var fmt = new TextFormat("_sans", 10, 0xCCCCCC, true);
        fmt.align = TextFormatAlign.LEFT;
        txt.defaultTextFormat = fmt;
        txt.text = label;
        txt.x = 19;
        txt.y = 2;
        txt.width = w - 21;
        txt.height = h - 2;
        txt.selectable = false;
        txt.mouseEnabled = false;
        sp.addChild(txt);

        var redraw = function(active:Bool):Void {
            sp.graphics.clear();
            var bg = active ? 0x0C1F11 : 0x161616;
            var border = active ? 0x2ECC71 : 0x2E2E2E;
            sp.graphics.beginFill(bg, 0.94);
            sp.graphics.lineStyle(1, border);
            sp.graphics.drawRoundRect(0, 0, w, h, 4, 4);
            sp.graphics.endFill();

            sp.graphics.lineStyle(1, active ? border : 0x383838, 0.5);
            sp.graphics.moveTo(2, 1);
            sp.graphics.lineTo(w - 2, 1);

            dot.graphics.clear();
            var dotX:Float = 10;
            var dotY:Float = h / 2;
            if (active) {
                dot.graphics.beginFill(0x2ECC71, 0.35);
                dot.graphics.drawCircle(dotX, dotY, 4.0);
                dot.graphics.endFill();
                dot.graphics.beginFill(0x00E676, 1.0);
                dot.graphics.drawCircle(dotX, dotY, 2.2);
                dot.graphics.endFill();
                txt.textColor = 0x76FF9F;
            } else {
                dot.graphics.beginFill(0x444444, 0.85);
                dot.graphics.drawCircle(dotX, dotY, 2.2);
                dot.graphics.endFill();
                txt.textColor = 0xAAAAAA;
            }
        };

        _liveStateButtons.push({
            btn: sp,
            dot: dot,
            lbl: txt,
            getState: getState,
            activeText: label,
            inactiveText: label,
            w: w,
            h: h
        });

        redraw(getState());

        sp.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            flashActionButton(sp);
            if (onToggle != null) onToggle();
            redraw(getState());
        });

        return sp;
    }

    private static function createLiveToggleButton(label:String, w:Float, h:Float, x:Float, y:Float, getState:Void->Bool, onToggle:Void->Void, onText:String, offText:String, ?accentColor:Null<Int>):Sprite {
        var sp = new Sprite();
        sp.buttonMode = true;
        sp.x = x;
        sp.y = y;

        var dot = new Shape();
        sp.addChild(dot);

        var txt = new TextField();
        var fmt = new TextFormat("_sans", 11, 0xCCCCCC, true);
        fmt.align = TextFormatAlign.LEFT;
        txt.defaultTextFormat = fmt;
        txt.x = 22;
        txt.y = 3;
        txt.width = w - 24;
        txt.height = h - 4;
        txt.selectable = false;
        txt.mouseEnabled = false;
        sp.addChild(txt);

        var glow = (accentColor != null) ? accentColor : 0x2ECC71;
        var core = (accentColor != null) ? 0xFFB74D : 0x00E676;

        var redraw = function(active:Bool):Void {
            sp.graphics.clear();
            var bg = active ? (accentColor != null ? 0x1E1408 : 0x0C1F11) : 0x161616;
            var border = active ? glow : 0x2E2E2E;
            sp.graphics.beginFill(bg, 0.94);
            sp.graphics.lineStyle(1, border);
            sp.graphics.drawRoundRect(0, 0, w, h, 4, 4);
            sp.graphics.endFill();

            sp.graphics.lineStyle(1, active ? border : 0x383838, 0.5);
            sp.graphics.moveTo(2, 1);
            sp.graphics.lineTo(w - 2, 1);

            dot.graphics.clear();
            var dotX:Float = 11;
            var dotY:Float = h / 2;
            if (active) {
                dot.graphics.beginFill(glow, 0.35);
                dot.graphics.drawCircle(dotX, dotY, 4.5);
                dot.graphics.endFill();
                dot.graphics.beginFill(core, 1.0);
                dot.graphics.drawCircle(dotX, dotY, 2.5);
                dot.graphics.endFill();
                txt.textColor = (accentColor != null) ? 0xFFE082 : 0x76FF9F;
                txt.text = onText;
            } else {
                dot.graphics.beginFill(0x444444, 0.85);
                dot.graphics.drawCircle(dotX, dotY, 2.5);
                dot.graphics.endFill();
                txt.textColor = 0xAAAAAA;
                txt.text = offText;
            }
        };

        _liveStateButtons.push({
            btn: sp,
            dot: dot,
            lbl: txt,
            getState: getState,
            activeText: onText,
            inactiveText: offText,
            w: w,
            h: h
        });

        redraw(getState());

        sp.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            flashActionButton(sp);
            if (onToggle != null) onToggle();
            redraw(getState());
        });

        return sp;
    }

    private static function setupDragging():Void {
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

        if (_theStage != null) {
            _theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
                if (isDragging) {
                    var dx = e.stageX - startDownX;
                    var dy = e.stageY - startDownY;
                    if (Math.abs(dx) > 4 || Math.abs(dy) > 4) {
                        hasDragged = true;
                    }
                    if (hasDragged) {
                        var curW:Float = _isCollapsed ? COLLAPSED_W : EXPANDED_W;
                        var curH:Float = _isCollapsed ? COLLAPSED_H : _currentTotalHeight;
                        var nx:Float = Math.round(e.stageX - dragStartX);
                        var ny:Float = Math.round(e.stageY - dragStartY);
                        var sw:Float = _theStage.stageWidth > 0 ? _theStage.stageWidth : 960;
                        var sh:Float = _theStage.stageHeight > 0 ? _theStage.stageHeight : 550;
                        if (nx < 0) nx = 0;
                        if (ny < 0) ny = 0;
                        if (nx > sw - curW) nx = sw - curW;
                        if (ny > sh - curH) ny = sh - curH;
                        _widget.x = nx;
                        _widget.y = ny;
                    }
                }
            });

            _theStage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
                if (isDragging) {
                    isDragging = false;
                    _widget.cacheAsBitmap = true;
                    if (hasDragged) {
                        // Mobile Edge Snap (18px threshold)
                        var curW:Float = _isCollapsed ? COLLAPSED_W : EXPANDED_W;
                        var curH:Float = _isCollapsed ? COLLAPSED_H : _currentTotalHeight;
                        var sw:Float = _theStage.stageWidth > 0 ? _theStage.stageWidth : 960;
                        var sh:Float = _theStage.stageHeight > 0 ? _theStage.stageHeight : 550;
                        var snapDist:Float = 18;
                        if (_widget.x < snapDist) _widget.x = 4;
                        else if (_widget.x > sw - curW - snapDist) _widget.x = sw - curW - 4;
                        if (_widget.y < snapDist) _widget.y = 4;
                        else if (_widget.y > sh - curH - snapDist) _widget.y = sh - curH - 4;

                        HelperSetting.setInt("api_hub_widget_x", Math.round(_widget.x));
                        HelperSetting.setInt("api_hub_widget_y", Math.round(_widget.y));
                    } else {
                        toggleCollapse();
                    }
                }
            });
        }
    }

    private static function onEnterFrame(e:Event):Void {
        var inGame = ApiMenus.isInGame();
        if (!inGame) {
            _widget.visible = false;
            return;
        }

        var isPanelOpen:Bool = (_overlay != null && (_overlay.currentFrameLabel == "Panel" || ApiDashboardModal.isOpen()));
        _widget.visible = !isPanelOpen;

        if (_widget.visible && !_isCollapsed) {
            // Live poll state toggles
            for (item in _liveStateButtons) {
                var active = item.getState();
                item.lbl.text = active ? item.activeText : item.inactiveText;
            }
        }
    }

    private static function renderCollapseIcon(collapsed:Bool, hover:Bool = false):Void {
        if (_btnCollapse == null) return;
        var g = _btnCollapse.graphics;
        g.clear();

        g.beginFill(0x000000, 0.0);
        g.drawRect(-4, -2, 28, 24);
        g.endFill();

        var bg = hover ? 0x2A2A2A : 0x1A1A1A;
        var border = hover ? 0x444444 : 0x282828;
        g.beginFill(bg, 0.85);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 20, 18, 4, 4);
        g.endFill();

        var color:Int = hover ? 0x00FF88 : 0xAAAAAA;
        g.lineStyle(2.2, color, 1.0, true);
        var cx = 10.0;
        var cy = 9.0;
        if (collapsed) {
            // Chevron Down
            g.moveTo(cx - 4.5, cy - 2.5);
            g.lineTo(cx, cy + 2.5);
            g.lineTo(cx + 4.5, cy - 2.5);
        } else {
            // Chevron Up
            g.moveTo(cx - 4.5, cy + 2.5);
            g.lineTo(cx, cy - 2.5);
            g.lineTo(cx + 4.5, cy + 2.5);
        }
    }

    private static function renderConfigIcon(hover:Bool = false):Void {
        if (_btnConfig == null) return;
        var g = _btnConfig.graphics;
        g.clear();

        g.beginFill(0x000000, 0.0);
        g.drawRect(-4, -2, 28, 24);
        g.endFill();

        var bg = hover ? 0x2A2A2A : 0x1A1A1A;
        var border = hover ? 0x444444 : 0x282828;
        g.beginFill(bg, 0.85);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 20, 18, 4, 4);
        g.endFill();

        var color:Int = hover ? 0x00E5FF : 0x999999;
        var cx = 10.0;
        var cy = 9.0;

        g.lineStyle(1.8, color, 1.0, true);
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
}
#else
class ApiMenuHubWidget {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function resetPosition():Void {}
}
#end
