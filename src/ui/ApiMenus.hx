package ui;

#if flash
import com.aqwapi.Api;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.utils.ApiConfig;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiStorage;
import flash.display.DisplayObject;
import flash.display.Shape;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import ui.ApiDashboardModal;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.ScreenFilterManager;

class ApiMenus {
    private static var _injected:Bool = false;
    private static var _stage:Stage = null;
    private static var _host:Dynamic = null;
    private static var _floatingMenuBtn:Sprite = null;

    public static function isInGame():Bool {
        try {
            if (Api.game == null || Api.game.world == null) return false;
            var w:Dynamic = Api.game.world;
            if (w.myAvatar == null) return false;
            if (w.myAvatar.objData == null || w.myAvatar.objData.strUsername == null) return false;
            var mapStr:String = (w.strMapName != null) ? Std.string(w.strMapName) : "";
            if (mapStr == "" || mapStr == "null") return false;
            if (Api.game.sfc != null && Api.game.sfc.isConnected == false) return false;
            return true;
        } catch (_:Dynamic) {
            return false;
        }
    }

    public static function resetMenuButtonPosition():Void {
        ApiConfig.setInt("api_floating_menu_x", 80);
        ApiConfig.setInt("api_floating_menu_y", 10);
        if (_floatingMenuBtn != null) {
            _floatingMenuBtn.x = 80;
            _floatingMenuBtn.y = 10;
        }
    }

    /**
     * Universal mod UI entry point. Works with any container:
     * - The Flash Stage (official AQWorlds launcher)
     * - A DisplayObject/Sprite container (aqw-mobile-mod or any custom host)
     */
    public static function inject(target:Dynamic = null):Void {
        if (_injected) return;

        var theStage:Stage = null;
        if (target != null && Std.isOfType(target, Stage)) {
            theStage = cast target;
        } else if (target != null && target.stage != null) {
            theStage = cast target.stage;
        } else {
            try {
                if (flash.Lib.current != null && flash.Lib.current.stage != null) {
                    theStage = flash.Lib.current.stage;
                }
            } catch (_:Dynamic) {}
        }

        if (theStage != null) {
            initOnStage(theStage, target);
        } else if (target != null && Std.isOfType(target, DisplayObject)) {
            var disp:DisplayObject = cast target;
            var onAdded:Dynamic = null;
            onAdded = function(e:Event):Void {
                disp.removeEventListener(Event.ADDED_TO_STAGE, onAdded);
                if (disp.stage != null) {
                    initOnStage(disp.stage, target);
                }
            };
            disp.addEventListener(Event.ADDED_TO_STAGE, onAdded);
        } else {
            ApiLogger.error("UI", "inject failed: could not resolve stage from target: " + Std.string(target));
        }
    }

    /**
     * Backwards-compatible entry point for standalone launchers.
     */
    public static function injectStandalone(stage:Dynamic):Void {
        inject(stage);
    }

    private static function initOnStage(theStage:Stage, host:Dynamic):Void {
        if (_injected) return;
        _injected = true;
        _stage = theStage;
        _host = host;

        // Initialize ScreenFilterManager (respecting native stage frame rate)
        try {
            ScreenFilterManager.init(theStage);
        } catch (_:Dynamic) {}

        // 1. Initialize notification HUD container
        var apiNotifs = new Sprite();
        apiNotifs.name = "ApiNotificationsHUD";
        apiNotifs.mouseEnabled = false;
        theStage.addChild(apiNotifs);
        ApiNotificationManager.instance.init(apiNotifs);

        // 2. Restore Combat Manager state from persistent settings (account-bound via ApiConfig)
        ApiConfig.reload();

        if (Api.dispatcher != null) {
            Api.dispatcher.addEventListener(ApiEvent.ACCOUNT_CHANGED, function(e:Dynamic):Void {
                ApiConfig.reload();
                var acc = (ApiStorage.currentAccount != null) ? ApiStorage.currentAccount : "";
                if (acc != "") {
                    ApiNotificationManager.notify("Active profile: " + acc);
                }
            });
        }

        // 3. Restore loot and AC settings
        var initialLootState = ApiConfig.getBool("api_accept_loot", false);
        if (Api.drop != null) {
            Api.drop.acceptAll = initialLootState;
            if (initialLootState) {
                Api.drop.scanScreenDrops();
                Api.drop.acceptAllDrops();
            }
        }
        var initialACState = ApiConfig.getBool("api_accept_ac_drops", false);
        if (Api.drop != null) {
            Api.drop.acceptACs = initialACState;
            if (initialACState && !initialLootState) {
                Api.drop.scanScreenDrops();
                Api.drop.acceptACDrops();
            }
        }

        // 4. Floating On-Screen Menu Button (opens fullscreen standalone dashboard)
        setupFloatingMenuButton(theStage, host);

        // 5. Master Modular Widgets & Widget Creation System (ApiMenuHubWidget)
        ApiMenuHubWidget.init(theStage, host);

        // 6. Frame hooks (cutscenes, infinite range, death spawn)
        setupFrameHooks(theStage);
    }

    private static function setupFrameHooks(theStage:Stage):Void {
        theStage.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            var isScriptRunning = ScriptManager.SINGLETON.isRunning;

            // Cutscene skipping (Skua logic - always active during scripts or when enabled in settings)
            var skipCutscenesActive = isScriptRunning || ApiConfig.getBool("api_skip_cutscenes", false) || ApiConfig.getBool("option_disable_cutscenes", false);
            if (Api.map != null) {
                Api.map.skipCutscenes = skipCutscenesActive;
                if (skipCutscenesActive) {
                    Api.map.checkSkipCutscenes();
                }
            }

            // Infinite range & Death spawn tick
            var infiniteRangeActive = isScriptRunning || ApiConfig.getBool("api_infinite_range", false);
            var deathSpawnActive = isScriptRunning || ApiConfig.getBool("api_death_spawn", false);

            if (Api.map != null) {
                Api.map.autoDeathSpawn = deathSpawnActive;
                if (deathSpawnActive) {
                    Api.map.checkAutoDeathSpawn();
                }
            }
            if (Api.combat != null) {
                Api.combat.infiniteRange = infiniteRangeActive;
                if (infiniteRangeActive) {
                    Api.combat.applyInfiniteRange();
                }
            }
        });
    }

    private static function setupFloatingMenuButton(theStage:Stage, host:Dynamic):Void {
        var btnW:Float = 78;
        var btnH:Float = 26;

        var icon = new Sprite();
        icon.name = "ApiMenuFloatingButton";
        icon.buttonMode = true;
        icon.useHandCursor = true;

        var bg = new Sprite();
        icon.addChild(bg);

        var redAccent = new Shape();
        redAccent.graphics.beginFill(ApiStyle.COLOR_ACCENT_CRIMSON, 1.0);
        redAccent.graphics.drawRoundRect(5, 5, 3.5, 16, 1.5, 1.5);
        redAccent.graphics.endFill();
        icon.addChild(redAccent);

        var txt = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_PRIMARY, true);
        txt.defaultTextFormat = fmt;
        txt.text = "Menu";
        txt.x = 13;
        txt.y = 4;
        txt.width = btnW - 16;
        txt.height = 18;
        txt.selectable = false;
        txt.mouseEnabled = false;
        icon.addChild(txt);

        var renderBtn = function(isHover:Bool):Void {
            bg.graphics.clear();
            var bgCol = isHover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_WIDGET;
            var borderCol = isHover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT;

            bg.graphics.beginFill(bgCol, ApiStyle.ALPHA_WIDGET);
            bg.graphics.lineStyle(1, borderCol);
            bg.graphics.drawRoundRect(0, 0, btnW, btnH, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
            bg.graphics.endFill();

            bg.graphics.lineStyle(1, isHover ? ApiStyle.COLOR_BEVEL_LIGHT : ApiStyle.COLOR_BEVEL_SUBTLE, 0.55);
            bg.graphics.moveTo(3, 1);
            bg.graphics.lineTo(btnW - 3, 1);
        };
        renderBtn(false);

        icon.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void renderBtn(true));
        icon.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void renderBtn(false));

        _floatingMenuBtn = icon;
        var savedX = ApiConfig.getInt("api_floating_menu_x", 80);
        var savedY = ApiConfig.getInt("api_floating_menu_y", 10);
        icon.x = savedX;
        icon.y = savedY;

        theStage.addChild(icon);

        var isDragging:Bool = false;
        var hasDragged:Bool = false;
        var startDownX:Float = 0;
        var startDownY:Float = 0;
        var dragStartX:Float = 0;
        var dragStartY:Float = 0;

        icon.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            isDragging = true;
            hasDragged = false;
            startDownX = e.stageX;
            startDownY = e.stageY;
            dragStartX = e.stageX - icon.x;
            dragStartY = e.stageY - icon.y;
            icon.cacheAsBitmap = false;
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
                    var sw:Float = (theStage.stageWidth > 0) ? theStage.stageWidth : 960;
                    var sh:Float = (theStage.stageHeight > 0) ? theStage.stageHeight : 550;

                    if (nx < ApiStyle.SCREEN_MARGIN) nx = ApiStyle.SCREEN_MARGIN;
                    if (ny < ApiStyle.SCREEN_MARGIN) ny = ApiStyle.SCREEN_MARGIN;
                    if (nx > sw - btnW - ApiStyle.SCREEN_MARGIN) nx = sw - btnW - ApiStyle.SCREEN_MARGIN;
                    if (ny > sh - btnH - ApiStyle.SCREEN_MARGIN) ny = sh - btnH - ApiStyle.SCREEN_MARGIN;

                    icon.x = nx;
                    icon.y = ny;
                }
            }
        });

        theStage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            if (isDragging) {
                isDragging = false;
                icon.cacheAsBitmap = true;
                if (hasDragged) {
                    ApiConfig.setInt("api_floating_menu_x", Math.round(icon.x));
                    ApiConfig.setInt("api_floating_menu_y", Math.round(icon.y));
                } else {
                    if (ApiDashboardModal.isOpen()) {
                        ApiDashboardModal.close();
                    } else {
                        ApiDashboardModal.show(theStage, host);
                    }
                }
            }
        });

        // Visible immediately at app launch, hidden ONLY when dashboard modal is open
        icon.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            var isHostPanelOpen:Bool = false;
            try {
                if (host != null && Reflect.hasField(host, "currentFrameLabel") && Reflect.field(host, "currentFrameLabel") == "Panel") {
                    isHostPanelOpen = true;
                }
            } catch (_:Dynamic) {}

            var isPanelOpen:Bool = isHostPanelOpen || ApiDashboardModal.isOpen();
            icon.visible = !isPanelOpen;

            if (icon.visible && theStage != null) {
                var sw:Float = (theStage.stageWidth > 0) ? theStage.stageWidth : 960;
                var sh:Float = (theStage.stageHeight > 0) ? theStage.stageHeight : 550;
                if (icon.x > sw - btnW - ApiStyle.SCREEN_MARGIN) icon.x = Math.max(ApiStyle.SCREEN_MARGIN, sw - btnW - ApiStyle.SCREEN_MARGIN);
                if (icon.y > sh - btnH - ApiStyle.SCREEN_MARGIN) icon.y = Math.max(ApiStyle.SCREEN_MARGIN, sh - btnH - ApiStyle.SCREEN_MARGIN);
                if (icon.x < ApiStyle.SCREEN_MARGIN) icon.x = ApiStyle.SCREEN_MARGIN;
                if (icon.y < ApiStyle.SCREEN_MARGIN) icon.y = ApiStyle.SCREEN_MARGIN;
            }
        });
    }
}
#else
class ApiMenus {
    public static function inject(target:Dynamic = null):Void {}
    public static function injectStandalone(stage:Dynamic):Void {}
    public static function resetMenuButtonPosition():Void {}
}
#end
