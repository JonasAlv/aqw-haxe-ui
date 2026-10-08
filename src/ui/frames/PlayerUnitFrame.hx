package ui.frames;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import com.aqwapi.Api;
import ui.Overlay;
import ui.ApiDashboardModal;
import ui.ApiMenus;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import com.aqwapi.utils.ApiConfig;

/**
 * Compact Player Unit Frame (ElvUI / oUF Style).
 *
 * Modern, minimalist, portrait-less unit frame displaying:
 * - Level badge, Username, Class & Rank
 * - Health Bar with numeric HP and Shield (+SG)
 * - Mana / Power Bar with numeric MP
 * - Class Energy / Stamina (SP) hairline stripe
 * - Draggable with persistent screen position
 */
class PlayerUnitFrame {
    private static var _pocket:Dynamic = null;
    private static var _overlay:Overlay = null;
    private static var _widget:Sprite = null;
    private static var _initialized:Bool = false;

    // Dimensions
    public static inline var FRAME_W:Float = 180;
    public static inline var FRAME_H:Float = 32;

    // Visual elements
    private static var _bg:Sprite = null;
    private static var _headerTxt:TextField = null;
    private static var _hpBarBg:Shape = null;
    private static var _hpBarFill:Shape = null;
    private static var _shieldBarFill:Shape = null;
    private static var _hpTxt:TextField = null;
    private static var _mpBarBg:Shape = null;
    private static var _mpBarFill:Shape = null;
    private static var _mpTxt:TextField = null;
    private static var _spBarFill:Shape = null;

    // Cache to prevent redundant redraws
    private static var _lastHp:Int = -1;
    private static var _lastMaxHp:Int = -1;
    private static var _lastShield:Int = -1;
    private static var _lastMp:Int = -1;
    private static var _lastMaxMp:Int = -1;
    private static var _lastSp:Int = -1;
    private static var _lastHeaderStr:String = "";

    public static function init(pocket:Dynamic, overlay:Overlay):Void {
        if (_initialized) return;
        _initialized = true;
        _pocket = pocket;
        _overlay = overlay;

        var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);

        var attach = function(stageObj:Dynamic):Void {
            if (stageObj == null || _widget != null) return;
            buildFrame(stageObj);
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

    private static function buildFrame(theStage:Dynamic):Void {
        _widget = new Sprite();
        _widget.name = "PlayerUnitFrame";

        // Restore saved position (default: x: 180, y: 380)
        var savedX = ApiConfig.getInt("api_frame_player_x", -1);
        var savedY = ApiConfig.getInt("api_frame_player_y", -1);
        var initX:Float = (savedX >= 0) ? savedX : 180;
        var initY:Float = (savedY >= 0) ? savedY : 380;

        var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
        var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
        if (initX > sw - FRAME_W - ApiStyle.SCREEN_MARGIN) initX = sw - FRAME_W - ApiStyle.SCREEN_MARGIN;
        if (initY > sh - FRAME_H - ApiStyle.SCREEN_MARGIN) initY = sh - FRAME_H - ApiStyle.SCREEN_MARGIN;
        if (initX < ApiStyle.SCREEN_MARGIN) initX = ApiStyle.SCREEN_MARGIN;
        if (initY < ApiStyle.SCREEN_MARGIN) initY = ApiStyle.SCREEN_MARGIN;

        _widget.x = initX;
        _widget.y = initY;

        // 1. Base Plate & Outer Border (ElvUI style dark obsidian)
        _bg = new Sprite();
        _bg.graphics.beginFill(ApiStyle.COLOR_BG_SURFACE, 0.95);
        _bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.95);
        _bg.graphics.drawRoundRect(0, 0, FRAME_W, FRAME_H, 4, 4);
        _bg.graphics.endFill();
        _bg.buttonMode = true;
        _bg.useHandCursor = true;
        _widget.addChild(_bg);

        // 2. Header text: [Level] Class R10 (no username)
        _headerTxt = new TextField();
        var hdrFmt = new TextFormat(ApiStyle.FONT_FAMILY, 8.5, ApiStyle.COLOR_TEXT_PRIMARY, true);
        _headerTxt.defaultTextFormat = hdrFmt;
        _headerTxt.x = 4;
        _headerTxt.y = 1;
        _headerTxt.width = FRAME_W - 8;
        _headerTxt.height = 12;
        _headerTxt.selectable = false;
        _headerTxt.mouseEnabled = false;
        _widget.addChild(_headerTxt);

        // 3. Health Bar (y: 13, h: 11)
        _hpBarBg = new Shape();
        _hpBarBg.x = 4;
        _hpBarBg.y = 13;
        _hpBarBg.graphics.beginFill(0x2A1115, 0.95);
        _hpBarBg.graphics.drawRect(0, 0, FRAME_W - 8, 11);
        _hpBarBg.graphics.endFill();
        _widget.addChild(_hpBarBg);

        _hpBarFill = new Shape();
        _hpBarFill.x = 4;
        _hpBarFill.y = 13;
        _widget.addChild(_hpBarFill);

        _shieldBarFill = new Shape();
        _shieldBarFill.x = 4;
        _shieldBarFill.y = 13;
        _widget.addChild(_shieldBarFill);

        _hpTxt = new TextField();
        var hpFmt = new TextFormat(ApiStyle.FONT_FAMILY, 8.5, 0xFFFFFF, true);
        hpFmt.align = TextFormatAlign.CENTER;
        _hpTxt.defaultTextFormat = hpFmt;
        _hpTxt.x = 4;
        _hpTxt.y = 12;
        _hpTxt.width = FRAME_W - 8;
        _hpTxt.height = 13;
        _hpTxt.selectable = false;
        _hpTxt.mouseEnabled = false;
        _widget.addChild(_hpTxt);

        // 4. Mana / Power Bar (y: 25, h: 5)
        _mpBarBg = new Shape();
        _mpBarBg.x = 4;
        _mpBarBg.y = 25;
        _mpBarBg.graphics.beginFill(0x0A1828, 0.95);
        _mpBarBg.graphics.drawRect(0, 0, FRAME_W - 8, 5);
        _mpBarBg.graphics.endFill();
        _widget.addChild(_mpBarBg);

        _mpBarFill = new Shape();
        _mpBarFill.x = 4;
        _mpBarFill.y = 25;
        _widget.addChild(_mpBarFill);

        _mpTxt = new TextField();
        _mpTxt.visible = false;
        _widget.addChild(_mpTxt);

        // 5. SP hairline indicator (y: 30.5, h: 1.5)
        _spBarFill = new Shape();
        _spBarFill.x = 4;
        _spBarFill.y = 30.5;
        _widget.addChild(_spBarFill);

        // 6. Setup Dragging
        setupDragging(theStage);

        // 7. Update Loop
        _widget.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            var inGame = ApiMenus.isInGame();
            if (!inGame) {
                _widget.visible = false;
                return;
            }
            var isEnabled = isWidgetEnabled();
            if (!isEnabled) {
                _widget.visible = false;
                return;
            }
            var isPanelOpen:Bool = (_overlay != null && (_overlay.currentFrameLabel == "Panel" || ApiDashboardModal.isOpen()));
            _widget.visible = !isPanelOpen;
            if (_widget.visible) {
                syncNativeUI();
                updateState();
            }
        });

        updateState();
        theStage.addChild(_widget);
    }

    private static function updateState():Void {
        if (Api.player == null) return;

        var hp = Api.player.hp;
        var maxHp = Api.player.maxHp;
        if (maxHp <= 0) maxHp = (hp > 0) ? hp : 1;
        var mp = Api.player.mp;
        var maxMp = Api.player.maxMp;
        if (maxMp <= 0) maxMp = 100;

        var lvl = Api.player.level;
        var cName = Api.player.className;
        if (cName == "") cName = "Class";
        var rankStr = "";
        var shield:Int = 0;
        var sp:Int = 100;

        if (Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null) {
            var avt:Dynamic = Api.game.world.myAvatar;
            if (avt.objData != null && avt.objData.iRank != null) {
                rankStr = " R" + Std.string(avt.objData.iRank);
            }
            if (avt.dataLeaf != null) {
                if (avt.dataLeaf.intSG != null) shield = Std.int(untyped avt.dataLeaf.intSG);
                if (avt.dataLeaf.intSP != null) sp = Std.int(untyped avt.dataLeaf.intSP);
            }
        }

        // 1. Header Text: [Level] Class Rank (no username)
        var fullHeader = "[" + lvl + "] " + cName + rankStr;
        if (fullHeader != _lastHeaderStr) {
            _lastHeaderStr = fullHeader;
            _headerTxt.text = fullHeader;
        }

        var barW:Float = FRAME_W - 8;

        // 2. Health Bar Fill & Text
        if (hp != _lastHp || maxHp != _lastMaxHp || shield != _lastShield) {
            _lastHp = hp;
            _lastMaxHp = maxHp;
            _lastShield = shield;

            var hpRatio = Math.max(0.0, Math.min(1.0, hp / maxHp));
            var fillW = Math.round(barW * hpRatio);

            var g = _hpBarFill.graphics;
            g.clear();
            if (fillW > 0) {
                g.beginFill(ApiStyle.COLOR_STATUS_ERROR, 0.95);
                g.drawRect(0, 0, fillW, 11);
                g.endFill();
            }

            var sg = _shieldBarFill.graphics;
            sg.clear();
            if (shield > 0) {
                var shieldRatio = Math.min(1.0, shield / maxHp);
                var shieldW = Math.round(barW * shieldRatio);
                sg.beginFill(ApiStyle.COLOR_ACCENT_CYAN, 0.45);
                sg.drawRect(0, 0, shieldW, 11);
                sg.endFill();
            }

            var shieldText = (shield > 0) ? " +" + formatNumber(shield) : "";
            _hpTxt.text = formatNumber(hp) + " / " + formatNumber(maxHp) + shieldText;
        }

        // 3. Mana Bar Fill & Text
        if (mp != _lastMp || maxMp != _lastMaxMp) {
            _lastMp = mp;
            _lastMaxMp = maxMp;

            var mpRatio = Math.max(0.0, Math.min(1.0, mp / maxMp));
            var fillW = Math.round(barW * mpRatio);

            var g = _mpBarFill.graphics;
            g.clear();
            if (fillW > 0) {
                g.beginFill(0x2563EB, 0.95);
                g.drawRect(0, 0, fillW, 5);
                g.endFill();
            }

            _mpTxt.text = formatNumber(mp) + " / " + formatNumber(maxMp);
        }

        // 4. SP Hairline Stripe
        if (sp != _lastSp) {
            _lastSp = sp;
            var spRatio = Math.max(0.0, Math.min(1.0, sp / 100.0));
            var fillW = Math.round(barW * spRatio);

            var g = _spBarFill.graphics;
            g.clear();
            if (fillW > 0) {
                g.beginFill(ApiStyle.COLOR_STATUS_ACTIVE, 0.9);
                g.drawRect(0, 0, fillW, 1.5);
                g.endFill();
            }
        }
    }

    private static function formatNumber(n:Int):String {
        if (n >= 1000000) {
            return (Math.round(n / 100000) / 10.0) + "M";
        }
        if (n >= 100000) {
            return (Math.round(n / 1000)) + "k";
        }
        return Std.string(n);
    }

    private static function setupDragging(theStage:Dynamic):Void {
        var isDragging:Bool = false;
        var hasDragged:Bool = false;
        var startDownX:Float = 0;
        var startDownY:Float = 0;
        var dragStartX:Float = 0;
        var dragStartY:Float = 0;

        _bg.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            isDragging = true;
            hasDragged = false;
            startDownX = e.stageX;
            startDownY = e.stageY;
            _widget.cacheAsBitmap = false;
            dragStartX = e.stageX - _widget.x;
            dragStartY = e.stageY - _widget.y;
            theStage.setChildIndex(_widget, theStage.numChildren - 1);
        });

        theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
            if (isDragging) {
                var dx = e.stageX - startDownX;
                var dy = e.stageY - startDownY;
                if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
                    hasDragged = true;
                }
                if (hasDragged) {
                    var nx:Float = Math.round(e.stageX - dragStartX);
                    var ny:Float = Math.round(e.stageY - dragStartY);
                    var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
                    var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;

                    if (nx < ApiStyle.SCREEN_MARGIN) nx = ApiStyle.SCREEN_MARGIN;
                    if (ny < ApiStyle.SCREEN_MARGIN) ny = ApiStyle.SCREEN_MARGIN;
                    if (nx > sw - FRAME_W - ApiStyle.SCREEN_MARGIN) nx = sw - FRAME_W - ApiStyle.SCREEN_MARGIN;
                    if (ny > sh - FRAME_H - ApiStyle.SCREEN_MARGIN) ny = sh - FRAME_H - ApiStyle.SCREEN_MARGIN;

                    _widget.x = nx;
                    _widget.y = ny;
                }
            }
        });

        theStage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
            if (isDragging) {
                isDragging = false;
                _widget.cacheAsBitmap = true;
                if (hasDragged) {
                    ApiConfig.setInt("api_frame_player_x", Math.round(_widget.x));
                    ApiConfig.setInt("api_frame_player_y", Math.round(_widget.y));
                }
            }
        });
    }

    private static function syncNativeUI():Void {
        try {
            var g:Dynamic = Api.game;
            if (g != null && g.ui != null && g.ui.mcPortrait != null && g.ui.mcPortrait.visible) {
                UnitFramesManager.syncNativeHideUI();
            }
        } catch (_:Dynamic) {}
    }

    public static function reloadFromConfig():Void {
        if (_widget == null) return;
        var savedX = ApiConfig.getInt("api_frame_player_x", -1);
        var savedY = ApiConfig.getInt("api_frame_player_y", -1);
        _widget.x = (savedX >= 0) ? savedX : 180;
        _widget.y = (savedY >= 0) ? savedY : 380;
        _widget.visible = isWidgetEnabled();
        UnitFramesManager.syncNativeHideUI();
    }

    public static function isWidgetEnabled():Bool {
        return ApiConfig.getBool("api_frame_player_enabled", false);
    }

    public static function setWidgetEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_player_enabled", enabled);
        if (_widget != null) _widget.visible = enabled;
        UnitFramesManager.syncNativeHideUI();
    }

    public static function resetPosition():Void {
        ApiConfig.setInt("api_frame_player_x", 180);
        ApiConfig.setInt("api_frame_player_y", 380);
        if (_widget != null) {
            _widget.x = 180;
            _widget.y = 380;
        }
    }

    public static inline function getWidget():Sprite return _widget;
    public static inline function getFrameX():Float return (_widget != null) ? _widget.x : 180;
    public static inline function getFrameY():Float return (_widget != null) ? _widget.y : 380;
    public static inline function isFrameVisible():Bool return (_widget != null && _widget.visible);
}
#else
class PlayerUnitFrame {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isWidgetEnabled():Bool return false;
    public static function setWidgetEnabled(enabled:Bool):Void {}
    public static function resetPosition():Void {}
    public static function reloadFromConfig():Void {}
    public static inline function getFrameX():Float return 180;
    public static inline function getFrameY():Float return 380;
    public static inline function isFrameVisible():Bool return false;
}
#end
