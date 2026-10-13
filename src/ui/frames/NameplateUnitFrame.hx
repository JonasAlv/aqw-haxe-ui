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
import com.aqwapi.utils.ApiConfig;
import ui.ApiMenus;
import ui.ApiStyle;

/**
 * NameplateDisplay:
 * Ultra-lightweight overhead display for a single character (player or enemy).
 * Attached directly as a child of the unit's MovieClip (AvatarMC or MonsterMC)
 * so it follows movement in hardware with zero latency, zero stutter, and zero CPU lag.
 *
 * Consumes clean EntityDTO data from the API and performs ONLY UI presentation.
 */
class NameplateDisplay extends Sprite {
    public static inline var BAR_W:Float            = 66.0;  // Health bar width
    public static inline var BAR_H:Float            = 4.0;   // Health bar height
    public static inline var BAR_Y:Float            = -6.0;  // Position relative to pname.y (sits above name)
    public static inline var NAME_Y:Float           = -1.0;  // Name label top offset
    public static inline var NAME_H:Float           = 16.0;  // Name label height
    public static inline var SUB_Y:Float            = 13.0;  // Subtitle (guild / race) top offset
    public static inline var SUB_H:Float            = 14.0;  // Subtitle height

    // Palette Definitions
    // Players (friendly / neutral)
    public static inline var COLOR_NAME_PLAYER:Int     = 0x66CCFF; // Sky cyan
    public static inline var COLOR_SUB_PLAYER:Int      = 0xFFFFFF; // Crisp white
    public static inline var COLOR_BAR_BG_PLAYER:Int   = 0x0F1117; // Deep obsidian well
    public static inline var COLOR_BORDER_PLAYER:Int   = 0x1E2230; // Subtle hairline border
    public static inline var COLOR_TARGET_PLAYER:Int   = 0x38BDF8; // Targeted player cyan highlight

    // Enemies (monsters / hostile PvP)
    public static inline var COLOR_NAME_ENEMY:Int      = 0xEF4444; // Vibrant red name
    public static inline var COLOR_SUB_ENEMY:Int       = 0xF87171; // Coral / salmon red race
    public static inline var COLOR_HP_ENEMY:Int        = 0xEF4444; // Vibrant red health fill
    public static inline var COLOR_BAR_BG_ENEMY:Int    = 0x1A0505; // Dark maroon well
    public static inline var COLOR_BORDER_ENEMY:Int    = 0x450A0A; // Deep red hairline border
    public static inline var COLOR_TARGET_ENEMY:Int    = 0xF87171; // Targeted enemy bright red highlight

    public var entity:EntityDTO = null;
    public var isEnemy:Bool = false;

    private var _barBg:Shape = null;
    private var _barFill:Shape = null;
    private var _targetArrows:Shape = null;
    private var _nameTxt:TextField = null;
    private var _subTxt:TextField = null;

    // Cache to prevent redundant redraws / text layout updates
    private var _lastName:String = "";
    private var _lastSub:String = "";
    private var _lastHp:Int = -1;
    private var _lastMaxHp:Int = -1;
    private var _lastIsTarget:Bool = false;

    public function new(isEnemy:Bool) {
        super();
        this.isEnemy = isEnemy;
        this.name = "__nameplate";
        mouseChildren = false;
        buttonMode = true;
        useHandCursor = true;
        cacheAsBitmap = true;

        // 1. Health Bar Background & Outer Border
        _barBg = new Shape();
        addChild(_barBg);

        // 2. Health Bar Fill
        _barFill = new Shape();
        addChild(_barFill);

        // 3. Side Target Chevrons
        _targetArrows = new Shape();
        _targetArrows.visible = false;
        addChild(_targetArrows);

        // Initial draw of resting well
        drawBarBg();
        drawTargetIndicators(false);

        // 3. Name Label
        _nameTxt = new TextField();
        var nameFmt = new TextFormat(
            ApiStyle.FONT_FAMILY,
            11,
            isEnemy ? COLOR_NAME_ENEMY : COLOR_NAME_PLAYER,
            true,
            false,
            false,
            null,
            null,
            TextFormatAlign.CENTER
        );
        _nameTxt.defaultTextFormat = nameFmt;
        _nameTxt.x = -150;
        _nameTxt.y = NAME_Y;
        _nameTxt.width = 300;
        _nameTxt.height = NAME_H;
        _nameTxt.selectable = false;
        _nameTxt.mouseEnabled = false;
        _nameTxt.filters = ApiStyle.getTextOutlineFilter();
        addChild(_nameTxt);

        // 4. Subtitle Label (Guild for players, Race/Type for enemies)
        _subTxt = new TextField();
        var subFmt = new TextFormat(
            ApiStyle.FONT_FAMILY,
            9,
            isEnemy ? COLOR_SUB_ENEMY : COLOR_SUB_PLAYER,
            false,
            false,
            false,
            null,
            null,
            TextFormatAlign.CENTER
        );
        _subTxt.defaultTextFormat = subFmt;
        _subTxt.x = -150;
        _subTxt.y = SUB_Y;
        _subTxt.width = 300;
        _subTxt.height = SUB_H;
        _subTxt.selectable = false;
        _subTxt.mouseEnabled = false;
        _subTxt.filters = ApiStyle.getTextOutlineFilter();
        addChild(_subTxt);

        // Interactive Click-to-Target via API
        addEventListener(MouseEvent.CLICK, onClick);
    }

    private function onClick(e:MouseEvent):Void {
        try {
            e.stopPropagation();
            if (entity != null) {
                entity.select();
            }
        } catch (_:Dynamic) {}
    }

    public function setBarVisible(show:Bool):Void {
        updateDisplay();
    }

    public function updateDisplay():Void {
        var showBar:Bool = isEnemy ? NameplateUnitFrame.isEnemiesEnabled() : NameplateUnitFrame.isPlayersEnabled();
        var showNames:Bool = isEnemy ? NameplateUnitFrame.isEnemyNamesEnabled() : NameplateUnitFrame.isPlayerNamesEnabled();

        if (!showBar && !showNames) {
            visible = false;
            return;
        }
        if (entity != null && entity.isAlive && entity.pMC != null && entity.pMC.visible != false) {
            visible = true;
        }

        _barBg.visible = showBar;
        _barFill.visible = showBar;
        _nameTxt.visible = showNames;
        _subTxt.visible = (showNames && _lastSub != "");

        drawBarBg();
        drawTargetIndicators(_lastIsTarget);
        if (_lastHp > 0 && _lastMaxHp > 0) {
            drawHealthBar(_lastHp, _lastMaxHp);
        }
    }

    public function update(ent:EntityDTO):Void {
        this.entity = ent;

        // 1. Alive / Dead Check
        if (ent == null || !ent.isAlive) {
            visible = false;
            return;
        }

        var mc = ent.pMC;
        if (mc == null || mc.visible == false) {
            visible = false;
            return;
        }

        // 2. Position synchronization: dead-center horizontally above character
        try {
            var targetX:Float = (mc.mcChar != null && mc.mcChar.x != null) ? mc.mcChar.x : 0.0;
            if (x != targetX) x = targetX;

            var pn = Reflect.field(mc, "pname");
            if (pn != null && pn.y != 0) {
                var ty:Float = pn.y;
                if (y != ty) y = ty;
            } else if (mc.mcChar != null) {
                var ty:Float = -mc.mcChar.height - 10;
                if (y != ty) y = ty;
            }
        } catch (_:Dynamic) {}

        // 3. Name & Subtitle Text from EntityDTO
        var showNames:Bool = isEnemy ? NameplateUnitFrame.isEnemyNamesEnabled() : NameplateUnitFrame.isPlayerNamesEnabled();
        var rawName:String = (ent.isAfk ? "<AFK> " : "") + ent.name;
        var rawSub:String = "";

        if (isEnemy) {
            if (ent.race != "") rawSub = "< " + ent.race + " >";
        } else {
            if (ent.guild != "") rawSub = "< " + ent.guild + " >";
        }

        // Apply text only when changed
        if (rawName != _lastName) {
            _lastName = rawName;
            _nameTxt.text = rawName;
        }
        if (rawSub != _lastSub) {
            _lastSub = rawSub;
            _subTxt.text = rawSub;
        }

        _nameTxt.visible = showNames;
        _subTxt.visible = (showNames && rawSub != "");

        // 4. Target Chevrons via API
        var isTarget:Bool = ent.isCurrentTarget;
        if (isTarget != _lastIsTarget) {
            _lastIsTarget = isTarget;
            drawTargetIndicators(isTarget);
        }

        // 5. Health Bar Fill & Visibility via API
        var showBar:Bool = isEnemy ? NameplateUnitFrame.isEnemiesEnabled() : NameplateUnitFrame.isPlayersEnabled();
        _barBg.visible = showBar;
        _barFill.visible = showBar;

        if (!showBar && !showNames) {
            visible = false;
            return;
        }
        visible = true;

        if (showBar && (ent.hp != _lastHp || ent.maxHp != _lastMaxHp)) {
            _lastHp = ent.hp;
            _lastMaxHp = ent.maxHp;
            drawHealthBar(ent.hp, ent.maxHp);
        }
    }

    private function drawBarBg():Void {
        var showNames:Bool = isEnemy ? NameplateUnitFrame.isEnemyNamesEnabled() : NameplateUnitFrame.isPlayerNamesEnabled();
        var barY:Float = showNames ? BAR_Y : 0.0;

        var g = _barBg.graphics;
        g.clear();

        // Transparent hit area for easy click-to-target even on thin 4px bar
        g.beginFill(0x000000, 0.0);
        g.drawRect(-BAR_W / 2 - 4, barY - 6, BAR_W + 8, BAR_H + 12);
        g.endFill();

        g.beginFill(isEnemy ? COLOR_BAR_BG_ENEMY : COLOR_BAR_BG_PLAYER, 0.85);
        g.lineStyle(1.0, isEnemy ? COLOR_BORDER_ENEMY : COLOR_BORDER_PLAYER, 0.85);
        g.drawRoundRect(-BAR_W / 2, barY, BAR_W, BAR_H, 2, 2);
        g.endFill();
    }

    private function drawTargetIndicators(isTarget:Bool):Void {
        var g = _targetArrows.graphics;
        g.clear();

        if (!isTarget) {
            _targetArrows.visible = false;
            return;
        }

        var showBar:Bool = isEnemy ? NameplateUnitFrame.isEnemiesEnabled() : NameplateUnitFrame.isPlayersEnabled();
        var showNames:Bool = isEnemy ? NameplateUnitFrame.isEnemyNamesEnabled() : NameplateUnitFrame.isPlayerNamesEnabled();

        if (!showBar && !showNames) {
            _targetArrows.visible = false;
            return;
        }

        _targetArrows.visible = true;

        var barY:Float = showNames ? BAR_Y : 0.0;
        var centerY:Float = showBar ? (barY + BAR_H / 2.0) : (NAME_Y + NAME_H / 2.0);

        var halfW:Float;
        if (showBar) {
            halfW = (BAR_W / 2.0) + 3.5;
        } else {
            var txtW:Float = (_nameTxt != null && _nameTxt.textWidth > 0) ? _nameTxt.textWidth : 60.0;
            halfW = (txtW / 2.0) + 6.0;
        }

        var arrowW:Float = 5.0;   // Chevron width
        var arrowH:Float = 7.0;   // Chevron height
        var halfH:Float = arrowH / 2.0;

        var color:Int = 0xFACC15; // Crisp WoW golden yellow
        var outlineColor:Int = 0x000000;

        // Left Chevron (points right ► towards the bar)
        g.lineStyle(1.0, outlineColor, 0.9);
        g.beginFill(color, 1.0);
        g.moveTo(-halfW, centerY);
        g.lineTo(-halfW - arrowW, centerY - halfH);
        g.lineTo(-halfW - arrowW, centerY + halfH);
        g.lineTo(-halfW, centerY);
        g.endFill();

        // Right Chevron (points left ◄ towards the bar)
        g.lineStyle(1.0, outlineColor, 0.9);
        g.beginFill(color, 1.0);
        g.moveTo(halfW, centerY);
        g.lineTo(halfW + arrowW, centerY - halfH);
        g.lineTo(halfW + arrowW, centerY + halfH);
        g.lineTo(halfW, centerY);
        g.endFill();
    }

    private function drawHealthBar(hp:Int, maxHp:Int):Void {
        var showNames:Bool = isEnemy ? NameplateUnitFrame.isEnemyNamesEnabled() : NameplateUnitFrame.isPlayerNamesEnabled();
        var barY:Float = showNames ? BAR_Y : 0.0;

        var g = _barFill.graphics;
        g.clear();
        if (hp > 0 && maxHp > 0) {
            var ratio:Float = Math.max(0.0, Math.min(1.0, hp / maxHp));
            var fillW:Float = Math.round((BAR_W - 2.0) * ratio);
            if (fillW > 0) {
                var color:Int = isEnemy ? COLOR_HP_ENEMY : PlayerUnitFrame.getHealthColor(ratio);
                g.beginFill(color, 1.0);
                g.drawRoundRect(-BAR_W / 2 + 1, barY + 1, fillW, BAR_H - 2, 1, 1);
                g.endFill();
            }
        }
    }

    public function destroy():Void {
        removeEventListener(MouseEvent.CLICK, onClick);
        if (_targetArrows != null) {
            _targetArrows.graphics.clear();
        }
        if (parent != null) {
            try { parent.removeChild(this); } catch (_:Dynamic) {}
        }
    }
}

/**
 * NameplateUnitFrame:
 * High-performance, zero-lag WoW-style overhead nameplates for AQW characters.
 *
 * Coordinates:
 * - Replaces AQW's heavy, embedded-font vector names with bitmap-cached fast font (_sans).
 * - Player Nameplates: Green overhead health bar + Sky Cyan name + White guild subtitle.
 * - Enemy Nameplates: Red overhead health bar + Vibrant Red name + Coral race subtitle.
 * - Consumes clean EntityDTO data from the API; handles ONLY UI rendering and events.
 * - Full interactive click-to-target support.
 */
class NameplateUnitFrame {
    private static var _initialized:Bool = false;
    private static var _ticker:Sprite = null;
    private static var _activePlates:Array<NameplateDisplay> = [];
    private static var _pocket:Dynamic = null;
    private static var _overlay:Dynamic = null;

    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {
        if (_initialized) return;
        _initialized = true;
        _pocket = pocket;
        _overlay = overlay;

        var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);
        if (theStage == null && Api.game != null && Api.game.stage != null) {
            theStage = Api.game.stage;
        }

        var attachTicker = function(stageObj:Dynamic):Void {
            if (stageObj == null || _ticker != null) return;
            _ticker = new Sprite();
            _ticker.addEventListener(Event.ENTER_FRAME, onEnterFrame);
            try {
                stageObj.addChild(_ticker);
            } catch (_:Dynamic) {}
        };

        if (theStage != null) {
            attachTicker(theStage);
        } else if (_overlay != null) {
            _overlay.addEventListener(Event.ADDED_TO_STAGE, function(_:Event):Void {
                if (_overlay.stage != null && _ticker == null) {
                    attachTicker(_overlay.stage);
                }
            });
        }

        if (isWidgetEnabled() && Api.visual != null) {
            Api.visual.suppressTargetGlow = true;
        }
    }

    public static inline function isWidgetEnabled():Bool {
        return ApiConfig.getBool("api_frame_nameplates_enabled", true);
    }

    public static inline function setWidgetEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_nameplates_enabled", enabled);
        if (Api.visual != null) {
            Api.visual.suppressTargetGlow = enabled;
        }
        if (!enabled) {
            disableAllPlates();
        }
    }

    public static inline function isEnemiesEnabled():Bool {
        return ApiConfig.getBool("api_frame_nameplates_enemies", true);
    }

    public static function setEnemiesEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_nameplates_enemies", enabled);
        for (p in _activePlates) {
            if (p.isEnemy) p.updateDisplay();
        }
    }

    public static inline function isEnemyNamesEnabled():Bool {
        return ApiConfig.getBool("api_frame_nameplates_enemy_names", true);
    }

    public static function setEnemyNamesEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_nameplates_enemy_names", enabled);
        for (p in _activePlates) {
            if (p.isEnemy) p.updateDisplay();
        }
    }

    public static inline function isPlayersEnabled():Bool {
        return ApiConfig.getBool("api_frame_nameplates_players", true);
    }

    public static function setPlayersEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_nameplates_players", enabled);
        for (p in _activePlates) {
            if (!p.isEnemy) p.updateDisplay();
        }
    }

    public static inline function isPlayerNamesEnabled():Bool {
        return ApiConfig.getBool("api_frame_nameplates_player_names", true);
    }

    public static function setPlayerNamesEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_nameplates_player_names", enabled);
        for (p in _activePlates) {
            if (!p.isEnemy) p.updateDisplay();
        }
    }

    public static function reloadFromConfig():Void {
        if (!isWidgetEnabled()) {
            disableAllPlates();
        } else {
            for (p in _activePlates) {
                p.updateDisplay();
            }
        }
    }

    private static function onEnterFrame(e:Event):Void {
        if (!ApiMenus.isInGame() || !isWidgetEnabled()) {
            if (_activePlates.length > 0) disableAllPlates();
            return;
        }

        // 1. Prune detached or destroyed plates
        var i:Int = _activePlates.length - 1;
        while (i >= 0) {
            var p = _activePlates[i];
            var dead:Bool = false;
            if (p.entity == null || !p.entity.hasGraphic || p.entity.pMC == null) {
                dead = true;
            } else {
                try {
                    if (p.entity.pMC.stage == null || p.entity.pMC.parent == null) dead = true;
                } catch (_:Dynamic) {
                    dead = true;
                }
            }

            if (dead) {
                if (p.entity != null) p.entity.showNativeName();
                p.destroy();
                _activePlates.splice(i, 1);
            }
            i--;
        }

        // 2. Query entities on screen directly from the API!
        var entities:Array<EntityDTO> = (Api.map != null) ? Api.map.getEntitiesOnScreen() : [];

        for (ent in entities) {
            if (ent == null || !ent.hasGraphic || ent.pMC == null) continue;
            var isEnemy:Bool = ent.isMonster || ent.isHostilePvP;
            attachOrUpdate(ent, isEnemy);
        }
    }

    private static function attachOrUpdate(ent:EntityDTO, isEnemy:Bool):Void {
        var mc:Dynamic = ent.pMC;
        if (mc == null) return;

        // Suppress native vector pname and hpBar via API
        ent.hideNativeName();

        // Retrieve existing child or create new NameplateDisplay using native getChildByName
        var plate:NameplateDisplay = null;
        try {
            var existingChild:Dynamic = mc.getChildByName("__nameplate");
            if (existingChild != null && Std.isOfType(existingChild, NameplateDisplay)) {
                plate = cast existingChild;
            }
        } catch (_:Dynamic) {}

        if (plate == null) {
            plate = new NameplateDisplay(isEnemy);
            plate.entity = ent;
            mc.addChild(plate);
            _activePlates.push(plate);
        } else {
            plate.entity = ent;
            if (plate.parent != mc) {
                mc.addChild(plate);
            }
        }

        // Update plate contents using clean EntityDTO
        plate.update(ent);
    }

    private static function disableAllPlates():Void {
        for (p in _activePlates) {
            if (p.entity != null) p.entity.showNativeName();
            p.destroy();
        }
        _activePlates = [];
    }

    private static function pruneEnemyPlates():Void {
        var i:Int = _activePlates.length - 1;
        while (i >= 0) {
            var p = _activePlates[i];
            if (p.isEnemy) {
                if (p.entity != null) p.entity.showNativeName();
                p.destroy();
                _activePlates.splice(i, 1);
            }
            i--;
        }
    }

    private static function prunePlayerPlates():Void {
        var i:Int = _activePlates.length - 1;
        while (i >= 0) {
            var p = _activePlates[i];
            if (!p.isEnemy) {
                if (p.entity != null) p.entity.showNativeName();
                p.destroy();
                _activePlates.splice(i, 1);
            }
            i--;
        }
    }
}
#else
class NameplateUnitFrame {
    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {}
    public static inline function isWidgetEnabled():Bool return false;
    public static inline function setWidgetEnabled(enabled:Bool):Void {}
    public static inline function isEnemiesEnabled():Bool return false;
    public static inline function setEnemiesEnabled(enabled:Bool):Void {}
    public static inline function isEnemyNamesEnabled():Bool return false;
    public static inline function setEnemyNamesEnabled(enabled:Bool):Void {}
    public static inline function isPlayersEnabled():Bool return false;
    public static inline function setPlayersEnabled(enabled:Bool):Void {}
    public static inline function isPlayerNamesEnabled():Bool return false;
    public static inline function setPlayerNamesEnabled(enabled:Bool):Void {}
    public static function reloadFromConfig():Void {}
}
#end
