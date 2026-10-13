package ui.frames;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import com.aqwapi.Api;
import com.aqwapi.data.EntityDTO;
import ui.ApiDashboardModal;
import ui.ApiMenus;
import ui.ApiStyle;
import com.aqwapi.utils.ApiConfig;

/**
 * Compact Target Unit Frame (WoW / ElvUI Style).
 *
 * Modern, minimalist target unit frame displaying:
 * - Row 1: [Level] Target Name (colored by target type: Cyan = Player, Yellow = Monster)
 * - Row 2: Target Class (if player) OR Type Tag (e.g. Undead, Dragon, Chaos if monster)
 * - Quick [x] cancel target button
 * - Health Bar with dynamic WoW color (Green -> Yellow -> Red):
 *   - Left edge: current HP / max HP (+SG)
 *   - Right edge: current %
 * - Mana Bar with current MP in the center
 * - Visible only when player has an active living target
 * - Draggable with persistent screen position
 */
class TargetUnitFrame {
    // =========================================================================
    // SIZING DEFINITIONS (WoW-Style Target Frame)
    // =========================================================================
    public static inline var FRAME_W:Float              = 130.0; // Horizontal width
    public static inline var FRAME_H:Float              = 54.0;  // Vertical height (expanded for clarity)
    public static inline var CORNER_RADIUS:Float        = 4.0;   // Outer frame roundness
    public static inline var PADDING_X:Float            = 4.0;   // Left/right content margin

    // Quick Close [x] Button
    public static inline var CLOSE_BTN_X:Float          = 115.0; // FRAME_W - PADDING_X - CLOSE_BTN_W
    public static inline var CLOSE_BTN_Y:Float          = 2.0;
    public static inline var CLOSE_BTN_W:Float          = 11.0;
    public static inline var CLOSE_BTN_H:Float          = 10.0;

    // Header Rows (Name & Class / Monster Type Tag)
    public static inline var NAME_Y:Float               = 2.0;   // Target name top offset
    public static inline var NAME_H:Float               = 11.0;  // Target name height
    public static inline var NAME_W:Float               = 109.0; // CLOSE_BTN_X - PADDING_X - 2 (avoids [x])
    public static inline var SUB_Y:Float                = 13.0;  // Subtitle (Class or Type Tag) top offset
    public static inline var SUB_H:Float                = 10.0;  // Subtitle height

    // Health Bar
    public static inline var HP_BAR_Y:Float             = 25.0;  // Health bar top offset
    public static inline var HP_BAR_H:Float             = 14.0;  // Health bar height
    public static inline var HP_BAR_W:Float             = 122.0; // FRAME_W - (PADDING_X * 2)

    // Mana Bar
    public static inline var MP_BAR_Y:Float             = 41.0;  // Mana bar top offset
    public static inline var MP_BAR_H:Float             = 9.0;   // Mana bar height
    public static inline var MP_BAR_W:Float             = 122.0; // FRAME_W - (PADDING_X * 2)

    // =========================================================================
    // COLOR DEFINITIONS
    // =========================================================================
    // Plate & Surface
    public static inline var COLOR_BG:Int               = 0x0F1117; // Deep dark obsidian surface
    public static inline var COLOR_BORDER:Int           = 0x242838; // Crisp slate outer border
    public static inline var COLOR_BAR_BG:Int           = 0x141721; // Bar well background

    // Health Bar Colors (WoW Style Gradient: Healthy Green -> Low Yellow -> Critical Red)
    public static inline var COLOR_HP_HEALTHY:Int       = 0x22C55E; // Healthy vibrant green (> 50%)
    public static inline var COLOR_HP_LOW:Int           = 0xEAB308; // Getting low gold/yellow (20% - 50%)
    public static inline var COLOR_HP_CRITICAL:Int      = 0xEF4444; // Critical danger red (< 20%)
    public static inline var HP_THRESHOLD_HEALTHY:Float = 0.50;    // Healthy threshold (50%)
    public static inline var HP_THRESHOLD_CRITICAL:Float= 0.20;    // Critical threshold (20%)

    // Secondary Bars
    public static inline var COLOR_SHIELD:Int           = 0x00E5FF; // Shield overlay (+SG) cyan
    public static inline var COLOR_MP:Int               = 0x2563EB; // Mana fill WoW blue

    // Typography & Targets
    public static inline var COLOR_TEXT_PLAYER:Int      = 0x38BDF8; // Sky cyan/blue for other players
    public static inline var COLOR_TEXT_ENEMY:Int       = 0xEF4444; // Vibrant red for enemies / monsters
    public static inline var COLOR_HP_ENEMY:Int         = 0xEF4444; // Vibrant red healthbar fill for enemies
    public static inline var COLOR_TEXT_SUB:Int         = 0x94A3B8; // Slate muted text for class / type tag
    public static inline var COLOR_TEXT_BAR:Int         = 0xFFFFFF; // Crisp white text for HP and MP values

    // =========================================================================
    // HEALTH COLOR INTERPOLATION (WoW ColorGradient)
    // =========================================================================
    public static function getHealthColor(ratio:Float):Int {
        if (ratio >= HP_THRESHOLD_HEALTHY) {
            // Smooth gradient between Low (Yellow) at 0.50 and Healthy (Green) at 1.00
            var t:Float = (ratio - HP_THRESHOLD_HEALTHY) / (1.0 - HP_THRESHOLD_HEALTHY);
            var r = Std.int(0xEA + (0x22 - 0xEA) * t);
            var g = Std.int(0xB3 + (0xC5 - 0xB3) * t);
            var b = Std.int(0x08 + (0x5E - 0x08) * t);
            return (r << 16) | (g << 8) | b;
        } else if (ratio >= HP_THRESHOLD_CRITICAL) {
            // Smooth gradient between Critical (Red) at 0.20 and Low (Yellow) at 0.50
            var t:Float = (ratio - HP_THRESHOLD_CRITICAL) / (HP_THRESHOLD_HEALTHY - HP_THRESHOLD_CRITICAL);
            var r = Std.int(0xEF + (0xEA - 0xEF) * t);
            var g = Std.int(0x44 + (0xB3 - 0x44) * t);
            var b = Std.int(0x44 + (0x08 - 0x44) * t);
            return (r << 16) | (g << 8) | b;
        } else {
            return COLOR_HP_CRITICAL;
        }
    }

    // =========================================================================
    // STATE & VISUAL ELEMENTS
    // =========================================================================
    private static var _pocket:Dynamic = null;
    private static var _overlay:Dynamic = null;
    private static var _widget:Sprite = null;
    private static var _initialized:Bool = false;

    // Visual components
    private static var _bg:Sprite = null;
    private static var _nameTxt:TextField = null;
    private static var _subTxt:TextField = null;
    private static var _btnClose:Sprite = null;
    private static var _hpBarBg:Shape = null;
    private static var _hpBarFill:Shape = null;
    private static var _shieldBarFill:Shape = null;
    private static var _hpBarBorder:Shape = null;
    private static var _hpLeftTxt:TextField = null;
    private static var _hpRightTxt:TextField = null;
    private static var _mpBarBg:Shape = null;
    private static var _mpBarFill:Shape = null;
    private static var _mpBarBorder:Shape = null;
    private static var _mpTxt:TextField = null;

    // Cache to prevent redundant redraws
    private static var _lastTargetId:String = "";
    private static var _lastHp:Int = -1;
    private static var _lastMaxHp:Int = -1;
    private static var _lastShield:Int = -1;
    private static var _lastMp:Int = -1;
    private static var _lastMaxMp:Int = -1;
    private static var _lastNameStr:String = "";
    private static var _lastSubStr:String = "";

    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {
        if (_initialized) return;
        _initialized = true;
        _pocket = pocket;
        _overlay = overlay;

        var theStage:Dynamic = (_pocket != null && Std.isOfType(_pocket, Stage)) ? _pocket : ((_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null && _overlay.stage != null ? _overlay.stage : null));

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
        _widget.name = "TargetUnitFrame";

        // Restore saved position (default: x: 370, y: 380 - adjacent to PlayerUnitFrame)
        var savedX = ApiConfig.getInt("api_frame_target_x", -1);
        var savedY = ApiConfig.getInt("api_frame_target_y", -1);
        var initX:Float = (savedX >= 0) ? savedX : 370;
        var initY:Float = (savedY >= 0) ? savedY : 380;

        var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
        var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 550;
        if (initX > sw - FRAME_W - ApiStyle.SCREEN_MARGIN) initX = sw - FRAME_W - ApiStyle.SCREEN_MARGIN;
        if (initY > sh - FRAME_H - ApiStyle.SCREEN_MARGIN) initY = sh - FRAME_H - ApiStyle.SCREEN_MARGIN;
        if (initX < ApiStyle.SCREEN_MARGIN) initX = ApiStyle.SCREEN_MARGIN;
        if (initY < ApiStyle.SCREEN_MARGIN) initY = ApiStyle.SCREEN_MARGIN;

        _widget.x = initX;
        _widget.y = initY;
        _widget.visible = false; // Hidden until player selects a target

        // 1. Base Plate & Outer Border
        _bg = new Sprite();
        _bg.graphics.beginFill(COLOR_BG, 0.95);
        _bg.graphics.lineStyle(1, COLOR_BORDER, 0.95);
        _bg.graphics.drawRoundRect(0, 0, FRAME_W, FRAME_H, CORNER_RADIUS, CORNER_RADIUS);
        _bg.graphics.endFill();
        _bg.buttonMode = true;
        _bg.useHandCursor = true;
        _widget.addChild(_bg);

        // 2. Header Rows (Name & Class/Type Tag)
        _nameTxt = new TextField();
        var nameFmt = new TextFormat(ApiStyle.FONT_FAMILY, 8.0, COLOR_TEXT_ENEMY, true);
        _nameTxt.defaultTextFormat = nameFmt;
        _nameTxt.x = PADDING_X;
        _nameTxt.y = NAME_Y;
        _nameTxt.width = NAME_W;
        _nameTxt.height = NAME_H + 2;
        _nameTxt.selectable = false;
        _nameTxt.mouseEnabled = false;
        _nameTxt.filters = ApiStyle.getTextOutlineFilter();
        _widget.addChild(_nameTxt);

        _subTxt = new TextField();
        var subFmt = new TextFormat(ApiStyle.FONT_FAMILY, 7.5, COLOR_TEXT_SUB, true);
        _subTxt.defaultTextFormat = subFmt;
        _subTxt.x = PADDING_X;
        _subTxt.y = SUB_Y;
        _subTxt.width = FRAME_W - (PADDING_X * 2);
        _subTxt.height = SUB_H + 2;
        _subTxt.selectable = false;
        _subTxt.mouseEnabled = false;
        _subTxt.filters = ApiStyle.getTextOutlineFilter();
        _widget.addChild(_subTxt);

        // 3. Quick Cancel Target [X] Button
        _btnClose = new Sprite();
        _btnClose.buttonMode = true;
        _btnClose.x = CLOSE_BTN_X;
        _btnClose.y = CLOSE_BTN_Y;
        renderCloseBtn(false);

        _btnClose.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void renderCloseBtn(true));
        _btnClose.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void renderCloseBtn(false));
        _btnClose.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void e.stopPropagation());
        _btnClose.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            e.stopPropagation();
            cancelTarget();
        });
        _widget.addChild(_btnClose);

        // 4. Health Bar
        _hpBarBg = new Shape();
        _hpBarBg.x = PADDING_X;
        _hpBarBg.y = HP_BAR_Y;
        _hpBarBg.graphics.beginFill(COLOR_BAR_BG, 0.95);
        _hpBarBg.graphics.drawRect(0, 0, HP_BAR_W, HP_BAR_H);
        _hpBarBg.graphics.endFill();
        _widget.addChild(_hpBarBg);

        _hpBarFill = new Shape();
        _hpBarFill.x = PADDING_X;
        _hpBarFill.y = HP_BAR_Y;
        _widget.addChild(_hpBarFill);

        _shieldBarFill = new Shape();
        _shieldBarFill.x = PADDING_X;
        _shieldBarFill.y = HP_BAR_Y;
        _widget.addChild(_shieldBarFill);

        _hpBarBorder = new Shape();
        _hpBarBorder.x = PADDING_X;
        _hpBarBorder.y = HP_BAR_Y;
        _hpBarBorder.graphics.lineStyle(1.0, 0x000000, 1.0);
        _hpBarBorder.graphics.drawRect(0, 0, HP_BAR_W, HP_BAR_H);
        _widget.addChild(_hpBarBorder);

        // Left edge: current hp / max hp (+SG)
        _hpLeftTxt = new TextField();
        var hpLeftFmt = new TextFormat(ApiStyle.FONT_FAMILY, 7.5, COLOR_TEXT_BAR, true, false, false, null, null, TextFormatAlign.LEFT);
        _hpLeftTxt.defaultTextFormat = hpLeftFmt;
        _hpLeftTxt.x = PADDING_X + 2;
        _hpLeftTxt.y = HP_BAR_Y - 0.5;
        _hpLeftTxt.width = HP_BAR_W - 32;
        _hpLeftTxt.height = HP_BAR_H + 2;
        _hpLeftTxt.selectable = false;
        _hpLeftTxt.mouseEnabled = false;
        _hpLeftTxt.filters = ApiStyle.getBarTextOutlineFilter();
        _widget.addChild(_hpLeftTxt);

        // Right edge: current %
        _hpRightTxt = new TextField();
        var hpRightFmt = new TextFormat(ApiStyle.FONT_FAMILY, 7.5, COLOR_TEXT_BAR, true, false, false, null, null, TextFormatAlign.RIGHT);
        _hpRightTxt.defaultTextFormat = hpRightFmt;
        _hpRightTxt.x = PADDING_X;
        _hpRightTxt.y = HP_BAR_Y - 0.5;
        _hpRightTxt.width = HP_BAR_W - 2;
        _hpRightTxt.height = HP_BAR_H + 2;
        _hpRightTxt.selectable = false;
        _hpRightTxt.mouseEnabled = false;
        _hpRightTxt.filters = ApiStyle.getBarTextOutlineFilter();
        _widget.addChild(_hpRightTxt);

        // 5. Mana Bar
        _mpBarBg = new Shape();
        _mpBarBg.x = PADDING_X;
        _mpBarBg.y = MP_BAR_Y;
        _mpBarBg.graphics.beginFill(COLOR_BAR_BG, 0.95);
        _mpBarBg.graphics.drawRect(0, 0, MP_BAR_W, MP_BAR_H);
        _mpBarBg.graphics.endFill();
        _widget.addChild(_mpBarBg);

        _mpBarFill = new Shape();
        _mpBarFill.x = PADDING_X;
        _mpBarFill.y = MP_BAR_Y;
        _widget.addChild(_mpBarFill);

        _mpBarBorder = new Shape();
        _mpBarBorder.x = PADDING_X;
        _mpBarBorder.y = MP_BAR_Y;
        _mpBarBorder.graphics.lineStyle(1.0, 0x000000, 1.0);
        _mpBarBorder.graphics.drawRect(0, 0, MP_BAR_W, MP_BAR_H);
        _widget.addChild(_mpBarBorder);

        // Center: current mana number
        _mpTxt = new TextField();
        var mpFmt = new TextFormat(ApiStyle.FONT_FAMILY, 7.0, COLOR_TEXT_BAR, true, false, false, null, null, TextFormatAlign.CENTER);
        _mpTxt.defaultTextFormat = mpFmt;
        _mpTxt.x = PADDING_X;
        _mpTxt.y = MP_BAR_Y - 1.5;
        _mpTxt.width = MP_BAR_W;
        _mpTxt.height = MP_BAR_H + 3;
        _mpTxt.selectable = false;
        _mpTxt.mouseEnabled = false;
        _mpTxt.visible = true;
        _mpTxt.filters = ApiStyle.getBarTextOutlineFilter();
        _widget.addChild(_mpTxt);

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
            var isHostPanel:Bool = false;
            try {
                if (_overlay != null && Reflect.hasField(_overlay, "currentFrameLabel") && Reflect.field(_overlay, "currentFrameLabel") == "Panel") {
                    isHostPanel = true;
                }
            } catch (_:Dynamic) {}

            var isPanelOpen:Bool = isHostPanel || ApiDashboardModal.isOpen();
            if (isPanelOpen) {
                _widget.visible = false;
                return;
            }

            // Visible only when target is active and alive
            var t = (Api.player != null) ? Api.player.target : null;
            if (t == null || !t.isAlive) {
                _widget.visible = false;
                _lastTargetId = "";
                return;
            }

            _widget.visible = true;
            syncNativeUI();
            updateTargetState(t);
        });

        theStage.addChild(_widget);
    }

    private static function renderCloseBtn(hover:Bool):Void {
        var g = _btnClose.graphics;
        g.clear();
        g.beginFill(hover ? ApiStyle.COLOR_STATUS_ERROR : ApiStyle.COLOR_BG_CARD, 0.85);
        g.lineStyle(1, hover ? ApiStyle.COLOR_STATUS_ERROR_HOVER : ApiStyle.COLOR_BORDER_DEFAULT);
        g.drawRoundRect(0, 0, CLOSE_BTN_W, CLOSE_BTN_H, 2, 2);
        g.endFill();

        var col:Int = hover ? 0xFFFFFF : ApiStyle.COLOR_TEXT_MUTED;
        g.lineStyle(1.4, col, 1.0, true);
        g.moveTo(2.5, 2.0); g.lineTo(8.5, 8.0);
        g.moveTo(8.5, 2.0); g.lineTo(2.5, 8.0);
    }

    public static function cancelTarget():Void {
        if (Api.game != null && Api.game.world != null) {
            try {
                if (Reflect.hasField(Api.game.world, "cancelTarget")) {
                    Reflect.callMethod(Api.game.world, Reflect.field(Api.game.world, "cancelTarget"), []);
                } else if (Api.game.world.myAvatar != null) {
                    Api.game.world.myAvatar.target = null;
                }
            } catch (_:Dynamic) {}
        }
        _lastTargetId = "";
        _lastHp = -1;
        _lastMp = -1;
        if (_widget != null) _widget.visible = false;
    }

    private static function updateTargetState(t:EntityDTO):Void {
        if (t == null) return;

        var tId = (t.id != "") ? t.id : t.name;
        var hp = t.hp;
        var maxHp = (t.maxHp > 0) ? t.maxHp : hp;
        if (maxHp <= 0) maxHp = 1;
        var mp = t.mp;
        var maxMp = 100;

        var lvl:Int = 0;
        var subText:String = "";
        var isPlayerTarget:Bool = false;
        var shield:Int = 0;

        // 1. Check if target is a known player in world.uoTree
        if (Api.game != null && Api.game.world != null && Api.game.world.uoTree != null) {
            try {
                var uLeaf:Dynamic = Reflect.field(Api.game.world.uoTree, t.name.toLowerCase());
                if (uLeaf != null) {
                    isPlayerTarget = true;
                    if (uLeaf.strClassName != null && Std.string(uLeaf.strClassName) != "") {
                        subText = Std.string(uLeaf.strClassName);
                    } else if (uLeaf.objData != null && uLeaf.objData.strClassName != null) {
                        subText = Std.string(uLeaf.objData.strClassName);
                    }
                }
            } catch (_:Dynamic) {}
        }

        // 2. Check target's raw object data
        if (t.raw != null) {
            var od:Dynamic = Reflect.field(t.raw, "objData");
            var dl:Dynamic = Reflect.field(t.raw, "dataLeaf");
            if (od != null) {
                if (od.intLevel != null) lvl = Std.int(untyped od.intLevel);
                if (od.strUsername != null && Std.string(od.strUsername) != "") {
                    isPlayerTarget = true;
                }
                if (od.strClassName != null && Std.string(od.strClassName) != "") {
                    isPlayerTarget = true;
                    subText = Std.string(od.strClassName);
                }
                if (!isPlayerTarget && (subText == "" || subText == "None")) {
                    if (od.sRace != null && od.sRace != "None" && Std.string(od.sRace) != "") {
                        subText = Std.string(od.sRace);
                    }
                }
                if (od.intMPMax != null) maxMp = Std.int(untyped od.intMPMax);
            }
            if (dl != null) {
                if (dl.intLevel != null && lvl == 0) lvl = Std.int(untyped dl.intLevel);
                if (dl.intMPMax != null && maxMp == 100) maxMp = Std.int(untyped dl.intMPMax);
                if (dl.intSG != null) shield = Std.int(untyped dl.intSG);
                if (!isPlayerTarget && (subText == "" || subText == "None")) {
                    if (dl.sRace != null && dl.sRace != "None" && Std.string(dl.sRace) != "") {
                        subText = Std.string(dl.sRace);
                    }
                }
            }
        }

        // 3. Fallback for monster type tag via world.monTree
        if (!isPlayerTarget && (subText == "" || subText == "None") && Api.game != null && Api.game.world != null && Api.game.world.monTree != null) {
            try {
                var mKey:String = (t.mapId != "") ? t.mapId : t.id;
                if (mKey != "" && Reflect.hasField(Api.game.world.monTree, mKey)) {
                    var mLeaf:Dynamic = Reflect.field(Api.game.world.monTree, mKey);
                    if (mLeaf != null) {
                        if (mLeaf.intLevel != null && lvl == 0) lvl = Std.int(untyped mLeaf.intLevel);
                        if (mLeaf.sRace != null && mLeaf.sRace != "None" && Std.string(mLeaf.sRace) != "") {
                            subText = Std.string(mLeaf.sRace);
                        } else if (mLeaf.sDesc != null && Std.string(mLeaf.sDesc) != "") {
                            subText = Std.string(mLeaf.sDesc);
                        }
                    }
                }
            } catch (_:Dynamic) {}
        }

        // 4. Default fallback labels
        if (subText == "" || subText == "None") {
            subText = isPlayerTarget ? "Player" : "Monster";
        }
        if (maxMp <= 0) maxMp = 100;

        // 5. Update Name & Sub labels
        var nameStr = (t.name != "") ? t.name : "Target";
        var nameText = (lvl > 0 ? "[" + lvl + "] " : "") + nameStr;
        var targetChanged:Bool = (tId != _lastTargetId);

        if (nameText != _lastNameStr || targetChanged) {
            _lastNameStr = nameText;
            _nameTxt.text = nameText;
            _nameTxt.textColor = isPlayerTarget ? COLOR_TEXT_PLAYER : COLOR_TEXT_ENEMY;
            _nameTxt.filters = ApiStyle.getTextOutlineFilter();
        }

        if (subText != _lastSubStr || targetChanged) {
            _lastSubStr = subText;
            _subTxt.text = subText;
            _subTxt.filters = ApiStyle.getTextOutlineFilter();
        }
        _lastTargetId = tId;

        // 6. Health Bar Fill & Texts
        if (hp != _lastHp || maxHp != _lastMaxHp || shield != _lastShield || targetChanged) {
            _lastHp = hp;
            _lastMaxHp = maxHp;
            _lastShield = shield;

            var hpRatio = Math.max(0.0, Math.min(1.0, hp / maxHp));
            var fillW = Math.round(HP_BAR_W * hpRatio);
            var hpColor = isPlayerTarget ? getHealthColor(hpRatio) : COLOR_HP_ENEMY;

            var g = _hpBarFill.graphics;
            g.clear();
            if (fillW > 0) {
                g.beginFill(hpColor, 0.95);
                g.drawRect(0, 0, fillW, HP_BAR_H);
                g.endFill();
            }

            var sg = _shieldBarFill.graphics;
            sg.clear();
            if (shield > 0) {
                var shieldRatio = Math.min(1.0, shield / maxHp);
                var shieldW = Math.round(HP_BAR_W * shieldRatio);
                sg.beginFill(COLOR_SHIELD, 0.45);
                sg.drawRect(0, 0, shieldW, HP_BAR_H);
                sg.endFill();
            }

            var shieldText = (shield > 0) ? " +" + formatNumber(shield) : "";
            _hpLeftTxt.text = formatNumber(hp) + " / " + formatNumber(maxHp) + shieldText;

            var hpPercent = (hp > 0 && hpRatio < 0.01) ? 1 : Math.round(hpRatio * 100);
            _hpRightTxt.text = hpPercent + "%";
        }

        // 7. Mana Bar Fill & Center Text
        if (mp != _lastMp || maxMp != _lastMaxMp) {
            _lastMp = mp;
            _lastMaxMp = maxMp;

            var mpRatio = Math.max(0.0, Math.min(1.0, mp / maxMp));
            var fillW = Math.round(MP_BAR_W * mpRatio);

            var g = _mpBarFill.graphics;
            g.clear();
            if (fillW > 0) {
                g.beginFill(COLOR_MP, 0.95);
                g.drawRect(0, 0, fillW, MP_BAR_H);
                g.endFill();
            }

            _mpTxt.text = (maxMp > 0 && mp >= 0) ? formatNumber(mp) : "";
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
            _widget.cacheAsBitmap = true;
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
                    ApiConfig.setInt("api_frame_target_x", Math.round(_widget.x));
                    ApiConfig.setInt("api_frame_target_y", Math.round(_widget.y));
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
        var savedX = ApiConfig.getInt("api_frame_target_x", -1);
        var savedY = ApiConfig.getInt("api_frame_target_y", -1);
        _widget.x = (savedX >= 0) ? savedX : 370;
        _widget.y = (savedY >= 0) ? savedY : 380;
        var t = (Api.player != null) ? Api.player.target : null;
        _widget.visible = (isWidgetEnabled() && t != null && t.isAlive);
        UnitFramesManager.syncNativeHideUI();
    }

    public static function isWidgetEnabled():Bool {
        return ApiConfig.getBool("api_frame_target_enabled", false);
    }

    public static function setWidgetEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_target_enabled", enabled);
        if (_widget != null) {
            var t = (Api.player != null) ? Api.player.target : null;
            _widget.visible = (enabled && t != null && t.isAlive);
        }
        UnitFramesManager.syncNativeHideUI();
    }

    public static function resetPosition():Void {
        ApiConfig.setInt("api_frame_target_x", 370);
        ApiConfig.setInt("api_frame_target_y", 380);
        if (_widget != null) {
            _widget.x = 370;
            _widget.y = 380;
        }
    }

    public static inline function getWidget():Sprite return _widget;
    public static inline function getFrameX():Float return (_widget != null) ? _widget.x : 370;
    public static inline function getFrameY():Float return (_widget != null) ? _widget.y : 380;
    public static inline function isFrameVisible():Bool return (_widget != null && _widget.visible);
}
#else
class TargetUnitFrame {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isWidgetEnabled():Bool return false;
    public static function setWidgetEnabled(enabled:Bool):Void {}
    public static function resetPosition():Void {}
    public static function reloadFromConfig():Void {}
    public static inline function getFrameX():Float return 370;
    public static inline function getFrameY():Float return 380;
    public static inline function isFrameVisible():Bool return false;
}
#end
