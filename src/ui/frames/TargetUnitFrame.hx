package ui.frames;

#if flash
import flash.display.GradientType;
import flash.display.Graphics;
import flash.display.Shape;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.geom.Matrix;
import flash.geom.Point;
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
    public static inline var DEFAULT_X:Float            = 154.0; // Adjacent to PlayerUnitFrame (16 + 130 + 8)
    public static inline var DEFAULT_Y:Float            = 14.0;  // Top edge, replaces native mcPortraitTarget
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

    // Health Bar (Adaptive: 14px when target has mana, 24px when target has 0 mana!)
    public static inline var HP_BAR_Y:Float             = 25.0;  // Health bar top offset
    public static inline var HP_BAR_H_NORMAL:Float      = 14.0;  // Standard health bar height
    public static inline var HP_BAR_H_EXPANDED:Float    = 24.0;  // Expanded health bar height (0-MP monsters)
    public static inline var HP_BAR_W:Float             = 122.0; // FRAME_W - (PADDING_X * 2)

    // Mana Bar
    public static inline var MP_BAR_Y:Float             = 41.0;  // Mana bar top offset
    public static inline var MP_BAR_H:Float             = 9.0;   // Mana bar height
    public static inline var MP_BAR_W:Float             = 122.0; // FRAME_W - (PADDING_X * 2)

    // Additional Typography & Colors
    public static inline var COLOR_TEXT_FRIENDLY_NPC:Int = 0x34D399; // Mint/emerald green for friendly NPCs
    public static inline var COLOR_TEXT_BOSS:Int         = 0xF59E0B; // Amber gold for Bosses

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
    public static inline var COLOR_TEXT_PLAYER:Int          = 0x38BDF8; // Sky cyan/blue for other players
    public static inline var COLOR_TEXT_FRIENDLY_PLAYER:Int = 0xFBBF24; // Radiant Gold for friendly players (native AQW style)
    public static inline var COLOR_TEXT_ENEMY:Int           = 0xEF4444; // Vibrant red for enemies / monsters
    public static inline var COLOR_HP_ENEMY:Int             = 0xEF4444; // Vibrant red healthbar fill for enemies
    public static inline var COLOR_TEXT_SUB:Int             = 0x94A3B8; // Slate muted text for class / type tag
    public static inline var COLOR_TEXT_BAR:Int             = 0xFFFFFF; // Crisp white text for HP and MP values

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

    public static function drawModernBar(g:Graphics, x:Float, y:Float, w:Float, h:Float, baseColor:Int, alpha:Float = 0.95):Void {
        if (w <= 0 || h <= 0) return;
        var r = (baseColor >> 16) & 0xFF;
        var gCol = (baseColor >> 8) & 0xFF;
        var b = baseColor & 0xFF;

        // Top color: 18% brighter + subtle tint lift for sheen
        var topR = Std.int(Math.min(255, r * 1.18 + 12));
        var topG = Std.int(Math.min(255, gCol * 1.18 + 12));
        var topB = Std.int(Math.min(255, b * 1.18 + 12));
        var topColor = (topR << 16) | (topG << 8) | topB;

        // Bottom color: 22% deeper rich shade
        var botR = Std.int(r * 0.78);
        var botG = Std.int(gCol * 0.78);
        var botB = Std.int(b * 0.78);
        var botColor = (botR << 16) | (botG << 8) | botB;

        var mat:Matrix = new Matrix();
        mat.createGradientBox(w, h, Math.PI / 2, x, y);
        g.beginGradientFill(GradientType.LINEAR, [topColor, botColor], [alpha, alpha], [0, 255], mat);
        g.drawRect(x, y, w, h);
        g.endFill();

        // 1px subtle glossy top highlight line across the bar width
        g.lineStyle(1, 0xFFFFFF, 0.30);
        g.moveTo(x, y + 0.5);
        g.lineTo(x + w, y + 0.5);
        g.lineStyle();
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
    private static var _lastHasMana:Bool = true;
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

        // Restore saved position (default: x: DEFAULT_X, y: DEFAULT_Y - adjacent to PlayerUnitFrame)
        var savedX = ApiConfig.getInt("api_frame_target_x", -1);
        var savedY = ApiConfig.getInt("api_frame_target_y", -1);
        if (savedX == 370 && savedY == 380) {
            savedX = -1;
            savedY = -1;
            ApiConfig.setInt("api_frame_target_x", Std.int(DEFAULT_X));
            ApiConfig.setInt("api_frame_target_y", Std.int(DEFAULT_Y));
        }
        var initX:Float = (savedX >= 0) ? savedX : DEFAULT_X;
        var initY:Float = (savedY >= 0) ? savedY : DEFAULT_Y;

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
        _hpBarBg.graphics.drawRect(0, 0, HP_BAR_W, HP_BAR_H_NORMAL);
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
        _hpBarBorder.graphics.drawRect(0, 0, HP_BAR_W, HP_BAR_H_NORMAL);
        _widget.addChild(_hpBarBorder);

        // Left edge: current hp / max hp (+SG)
        _hpLeftTxt = new TextField();
        var hpLeftFmt = new TextFormat(ApiStyle.FONT_FAMILY, 7.5, COLOR_TEXT_BAR, true, false, false, null, null, TextFormatAlign.LEFT);
        _hpLeftTxt.defaultTextFormat = hpLeftFmt;
        _hpLeftTxt.x = PADDING_X + 2;
        _hpLeftTxt.y = HP_BAR_Y - 0.5;
        _hpLeftTxt.width = HP_BAR_W - 28;
        _hpLeftTxt.height = HP_BAR_H_NORMAL + 2;
        _hpLeftTxt.selectable = false;
        _hpLeftTxt.mouseEnabled = false;
        _hpLeftTxt.filters = ApiStyle.getBarTextOutlineFilter();
        _widget.addChild(_hpLeftTxt);

        // Right edge: current %
        _hpRightTxt = new TextField();
        var hpRightFmt = new TextFormat(ApiStyle.FONT_FAMILY, 7.5, COLOR_TEXT_BAR, true, false, false, null, null, TextFormatAlign.RIGHT);
        _hpRightTxt.defaultTextFormat = hpRightFmt;
        _hpRightTxt.x = FRAME_W - PADDING_X - 26;
        _hpRightTxt.y = HP_BAR_Y - 0.5;
        _hpRightTxt.width = 24;
        _hpRightTxt.height = HP_BAR_H_NORMAL + 2;
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

            // Visible while player has an active target
            var hasTarget:Bool = (Api.player != null && Api.player.hasTarget);
            var t = hasTarget ? Api.player.target : null;
            if (t == null) {
                _widget.visible = false;
                _lastTargetId = "";
                return;
            }

            _widget.visible = true;

            var targetContainer:Dynamic = (Api.game != null && Api.game.ui != null) ? Api.game.ui : theStage;
            if (targetContainer != null && _widget.parent != targetContainer) {
                try {
                    if (_widget.parent != null) _widget.parent.removeChild(_widget);
                    if (targetContainer == Api.game.ui && Api.game.ui.mcPortraitTarget != null) {
                        var idx:Int = Api.game.ui.getChildIndex(Api.game.ui.mcPortraitTarget) + 1;
                        Api.game.ui.addChildAt(_widget, Math.min(idx, Api.game.ui.numChildren));
                    } else {
                        targetContainer.addChild(_widget);
                    }
                } catch (_:Dynamic) {
                    try { theStage.addChild(_widget); } catch (_:Dynamic) {}
                }
            }

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
        var isDead:Bool = (!t.isAlive || t.hp <= 0);
        var hp:Int = isDead ? 0 : t.hp;
        var maxHp:Int = (t.maxHp > 0) ? t.maxHp : (hp > 0 ? hp : 1);
        if (maxHp <= 0) maxHp = 1;
        var mp:Int = t.mp;
        var maxMp:Int = t.maxMp;
        var shield:Int = isDead ? 0 : t.shield;
        var lvl:Int = t.level;

        var isPlayerTarget:Bool = t.isPlayer;
        var isSelf:Bool = t.isMyAvatar;
        var isHostile:Bool = t.isHostilePvP;

        // 1. Adaptive Mana Bar Layout (Monsters without mana get expanded 24px HP bar!)
        var hasMana:Bool = (maxMp > 0);
        var hpBarH:Float = hasMana ? HP_BAR_H_NORMAL : HP_BAR_H_EXPANDED;
        var hasManaChanged:Bool = (hasMana != _lastHasMana);

        if (hasManaChanged) {
            _lastHasMana = hasMana;
            _hpBarBg.graphics.clear();
            _hpBarBg.graphics.beginFill(COLOR_BAR_BG, 0.95);
            _hpBarBg.graphics.drawRect(0, 0, HP_BAR_W, hpBarH);
            _hpBarBg.graphics.endFill();

            _hpBarBorder.graphics.clear();
            _hpBarBorder.graphics.lineStyle(1.0, 0x000000, 1.0);
            _hpBarBorder.graphics.drawRect(0, 0, HP_BAR_W, hpBarH);

            _mpBarBg.visible = hasMana;
            _mpBarFill.visible = hasMana;
            _mpBarBorder.visible = hasMana;
            _mpTxt.visible = hasMana;

            var textY:Float = hasMana ? (HP_BAR_Y - 0.5) : (HP_BAR_Y + 4.5);
            _hpLeftTxt.y = textY;
            _hpRightTxt.y = textY;
        }

        // 2. Subtitle Resolution (Class/Rank or Race/Boss/Stars or [DEAD])
        var subText:String = "";
        var subColor:Int = COLOR_TEXT_SUB;
        if (isSelf) {
            var cName = (t.className != "" && t.className != "Class") ? t.className : (Api.player != null ? Api.player.className : "Class");
            var r = (t.classRank > 0) ? t.classRank : (Api.player != null ? Api.player.classRank : 1);
            subText = cName + (r > 0 ? " R" + r : "");
        } else if (isPlayerTarget) {
            var cName = (t.className != "" && t.className != "Class") ? t.className : "Player";
            subText = cName + (t.classRank > 0 ? " R" + t.classRank : "");
        } else {
            var race = (t.race != "" && t.race != "None") ? t.race : "Monster";
            if (t.isBoss) {
                subText = "[BOSS] " + race;
                subColor = COLOR_TEXT_BOSS;
            } else if (t.stars > 1) {
                subText = race + " (" + t.stars + ")";
            } else {
                subText = race;
            }
        }

        if (isDead) {
            subText = "[DEAD] " + subText;
            subColor = COLOR_TEXT_ENEMY;
        }

        // 3. Name & Hostility Colors
        var showClasses = UnitFramesManager.isShowClassNames();
        var nameStr = (t.name != "") ? t.name : "Target";
        if (isSelf) {
            nameStr = t.name + " (You)";
        } else if (showClasses && isPlayerTarget && t.className != "" && t.className != "Class") {
            nameStr = t.className;
        }
        var nameText = (lvl > 0 ? "[" + lvl + "] " : "") + nameStr;
        var targetChanged:Bool = (tId != _lastTargetId);

        var hpRatio:Float = Math.max(0.0, Math.min(1.0, hp / maxHp));
        var nameColor:Int;
        var hpColor:Int = getHealthColor(hpRatio);

        if (isSelf) {
            nameColor = COLOR_TEXT_FRIENDLY_PLAYER;
        } else if (isPlayerTarget) {
            if (isHostile) {
                nameColor = COLOR_TEXT_ENEMY;
            } else {
                nameColor = COLOR_TEXT_FRIENDLY_PLAYER;
            }
        } else {
            if (!isHostile) {
                nameColor = COLOR_TEXT_FRIENDLY_NPC;
            } else {
                nameColor = t.isBoss ? COLOR_TEXT_BOSS : COLOR_TEXT_ENEMY;
            }
        }

        if (nameText != _lastNameStr || targetChanged) {
            _lastNameStr = nameText;
            _nameTxt.text = nameText;
            _nameTxt.textColor = nameColor;
            _nameTxt.filters = ApiStyle.getTextOutlineFilter();
        }

        if (subText != _lastSubStr || targetChanged) {
            _lastSubStr = subText;
            _subTxt.text = subText;
            _subTxt.textColor = subColor;
            _subTxt.filters = ApiStyle.getTextOutlineFilter();
        }
        _lastTargetId = tId;

        // 4. Health Bar Fill & Texts
        if (hp != _lastHp || maxHp != _lastMaxHp || shield != _lastShield || targetChanged || hasManaChanged) {
            _lastHp = hp;
            _lastMaxHp = maxHp;
            _lastShield = shield;

            var fillW = Math.round(HP_BAR_W * hpRatio);

            var g = _hpBarFill.graphics;
            g.clear();
            if (fillW > 0) {
                drawModernBar(g, 0, 0, fillW, hpBarH, hpColor, 0.95);
            }

            var sg = _shieldBarFill.graphics;
            sg.clear();
            if (shield > 0) {
                var shieldRatio = Math.min(1.0, shield / maxHp);
                var shieldW = Math.round(HP_BAR_W * shieldRatio);
                drawModernBar(sg, 0, 0, shieldW, hpBarH, COLOR_SHIELD, 0.55);
            }

            if (isDead) {
                _hpLeftTxt.text = "0 / " + formatNumber(maxHp);
                _hpRightTxt.text = "0%";
            } else {
                var shieldText = (shield > 0) ? " +" + formatNumber(shield) : "";
                _hpLeftTxt.text = formatNumber(hp) + " / " + formatNumber(maxHp) + shieldText;

                var hpPercent = (hp > 0 && hpRatio < 0.01) ? 1 : Math.round(hpRatio * 100);
                _hpRightTxt.text = hpPercent + "%";
            }
        }

        // 5. Mana Bar Fill & Center Text (only if entity has mana)
        if (hasMana && (mp != _lastMp || maxMp != _lastMaxMp || targetChanged)) {
            _lastMp = mp;
            _lastMaxMp = maxMp;

            var mpRatio = Math.max(0.0, Math.min(1.0, mp / maxMp));
            var fillW = Math.round(MP_BAR_W * mpRatio);

            var g = _mpBarFill.graphics;
            g.clear();
            if (fillW > 0) {
                drawModernBar(g, 0, 0, fillW, MP_BAR_H, COLOR_MP, 0.95);
            }

            _mpTxt.text = (maxMp > 0 && mp >= 0) ? formatNumber(mp) : "";
        }
    }

    private static function formatNumber(n:Int):String {
        if (n >= 10000000) {
            return Std.string(Math.round(n / 1000000)) + "M";
        }
        if (n >= 1000000) {
            return (Math.round(n / 100000) / 10.0) + "M";
        }
        if (n >= 10000) {
            var kVal:Float = n / 1000.0;
            var r10:Float = Math.round(kVal * 10.0) / 10.0;
            if (r10 == Math.round(kVal)) {
                return Std.string(Math.round(kVal)) + "k";
            }
            return r10 + "k";
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
            dragStartX = e.stageX - _widget.x;
            dragStartY = e.stageY - _widget.y;
            try {
                if (_widget.parent != null) {
                    _widget.parent.setChildIndex(_widget, _widget.parent.numChildren - 1);
                    var g:Dynamic = Api.game;
                    if (g != null && g.ui != null && _widget.parent == g.ui) {
                        if (g.ui.cMenu != null && g.ui.cMenu.parent == g.ui) {
                            g.ui.setChildIndex(g.ui.cMenu, g.ui.numChildren - 1);
                        }
                        if (g.ui.ToolTip != null && g.ui.ToolTip.parent == g.ui) {
                            g.ui.setChildIndex(g.ui.ToolTip, g.ui.numChildren - 1);
                        }
                    }
                }
            } catch (_:Dynamic) {}
        });

        var onTargetRightClick = function(e:MouseEvent):Void {
            e.stopPropagation();
            try {
                var g:Dynamic = Api.game;
                if (g == null || g.ui == null || g.ui.cMenu == null || g.world == null || g.world.myAvatar == null) return;
                var target:Dynamic = g.world.myAvatar.target;
                if (target == null) return;

                var isMonster:Bool = false;
                try {
                    if (target.objData != null && (target.objData.MonMapID != null || target.objData.MonID != null)) {
                        isMonster = true;
                    } else if (target.dataLeaf != null && target.dataLeaf.MonID != null) {
                        isMonster = true;
                    }
                } catch (_:Dynamic) {}

                if (!isMonster) {
                    var isSelf:Bool = (target == g.world.myAvatar);
                    var charId:Int = 0;
                    var uName:String = "";
                    try {
                        if (target.objData != null) {
                            if (target.objData.CharID != null) charId = Std.int(target.objData.CharID);
                            if (target.objData.strUsername != null) uName = Std.string(target.objData.strUsername);
                        }
                    } catch (_:Dynamic) {}
                    var params:Dynamic = {
                        "ID": charId,
                        "strUsername": uName
                    };
                    g.ui.cMenu.fOpenWith(isSelf ? "self" : "user", params);
                } else {
                    var monId:Int = 0;
                    var monName:String = "";
                    try {
                        if (target.objData != null) {
                            if (target.objData.MonMapID != null) monId = Std.int(target.objData.MonMapID);
                            if (target.objData.strMonName != null) monName = Std.string(target.objData.strMonName);
                        }
                    } catch (_:Dynamic) {}
                    var monObj:Dynamic = null;
                    try {
                        if (g.world.getMonster != null) monObj = g.world.getMonster(monId);
                    } catch (_:Dynamic) {}
                    var monMc:Dynamic = (monObj != null && monObj.pMC != null) ? monObj.pMC : ((target.pMC != null) ? target.pMC : null);
                    var params:Dynamic = {
                        "ID": monId,
                        "strUsername": monName,
                        "target": monMc
                    };
                    g.ui.cMenu.fOpenWith("mons", params);
                }

                // Bring cMenu to top of ui container and position near cursor
                try {
                    if (g.ui.cMenu.parent != null) {
                        g.ui.cMenu.parent.setChildIndex(g.ui.cMenu, g.ui.cMenu.parent.numChildren - 1);
                        if (theStage != null && g.ui != null) {
                            var pt:Point = g.ui.globalToLocal(new Point(theStage.mouseX, theStage.mouseY));
                            g.ui.cMenu.x = pt.x;
                            g.ui.cMenu.y = pt.y;
                        }
                    }
                } catch (_:Dynamic) {}
            } catch (_:Dynamic) {}
        };

        _bg.addEventListener(MouseEvent.RIGHT_CLICK, onTargetRightClick);
        _widget.addEventListener(MouseEvent.RIGHT_CLICK, onTargetRightClick);

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
        if (savedX == 370 && savedY == 380) {
            savedX = -1;
            savedY = -1;
            ApiConfig.setInt("api_frame_target_x", Std.int(DEFAULT_X));
            ApiConfig.setInt("api_frame_target_y", Std.int(DEFAULT_Y));
        }
        var curX:Float = (savedX >= 0) ? savedX : DEFAULT_X;
        var curY:Float = (savedY >= 0) ? savedY : DEFAULT_Y;
        if (_widget.stage != null) {
            var sw:Float = _widget.stage.stageWidth > 0 ? _widget.stage.stageWidth : 960;
            var sh:Float = _widget.stage.stageHeight > 0 ? _widget.stage.stageHeight : 550;
            if (curX > sw - FRAME_W - ApiStyle.SCREEN_MARGIN) curX = sw - FRAME_W - ApiStyle.SCREEN_MARGIN;
            if (curY > sh - FRAME_H - ApiStyle.SCREEN_MARGIN) curY = sh - FRAME_H - ApiStyle.SCREEN_MARGIN;
            if (curX < ApiStyle.SCREEN_MARGIN) curX = ApiStyle.SCREEN_MARGIN;
            if (curY < ApiStyle.SCREEN_MARGIN) curY = ApiStyle.SCREEN_MARGIN;
        }
        _widget.x = curX;
        _widget.y = curY;
        var hasTarget:Bool = (Api.player != null && Api.player.hasTarget);
        _widget.visible = (isWidgetEnabled() && hasTarget);
        UnitFramesManager.syncNativeHideUI();
    }

    public static function isWidgetEnabled():Bool {
        return ApiConfig.getBool("api_frame_target_enabled", false);
    }

    public static function setWidgetEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_target_enabled", enabled);
        if (_widget != null) {
            var hasTarget:Bool = (Api.player != null && Api.player.hasTarget);
            _widget.visible = (enabled && hasTarget);
        }
        UnitFramesManager.syncNativeHideUI();
    }

    public static function resetPosition():Void {
        ApiConfig.setInt("api_frame_target_x", Std.int(DEFAULT_X));
        ApiConfig.setInt("api_frame_target_y", Std.int(DEFAULT_Y));
        if (_widget != null) {
            _widget.x = DEFAULT_X;
            _widget.y = DEFAULT_Y;
        }
    }

    public static inline function getWidget():Sprite return _widget;
    public static inline function getFrameX():Float return (_widget != null) ? _widget.x : DEFAULT_X;
    public static inline function getFrameY():Float return (_widget != null) ? _widget.y : DEFAULT_Y;
    public static inline function isFrameVisible():Bool return (_widget != null && _widget.visible);
}
#else
class TargetUnitFrame {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isWidgetEnabled():Bool return false;
    public static function setWidgetEnabled(enabled:Bool):Void {}
    public static function resetPosition():Void {}
    public static function reloadFromConfig():Void {}
    public static inline function getFrameX():Float return 154.0;
    public static inline function getFrameY():Float return 14.0;
    public static inline function isFrameVisible():Bool return false;
}
#end
