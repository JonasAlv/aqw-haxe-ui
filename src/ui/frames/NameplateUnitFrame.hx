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
    public static inline var BAR_H:Float            = 6.0;   // Health bar height (increased from 4px for solid visibility)
    public static inline var BAR_Y:Float            = -8.0;  // Position relative to pname.y (sits above name)
    public static inline var NAME_Y:Float           = -1.0;  // Name label top offset
    public static inline var NAME_H:Float           = 16.0;  // Name label height
    public static inline var SUB_Y:Float            = 13.0;  // Subtitle (guild / race) top offset
    public static inline var SUB_H:Float            = 14.0;  // Subtitle height

    // Palette Definitions
    // Players (friendly / neutral)
    public static inline var COLOR_NAME_PLAYER:Int     = 0x66CCFF; // Sky cyan
    public static inline var COLOR_SUB_PLAYER:Int      = 0xFFFFFF; // Crisp white
    public static inline var COLOR_BAR_BG_PLAYER:Int   = 0x0A0B10; // High-contrast solid dark charcoal well
    public static inline var COLOR_BORDER_PLAYER:Int   = 0x000000; // Solid black border
    public static inline var COLOR_TARGET_PLAYER:Int   = 0x38BDF8; // Targeted player cyan highlight

    // Enemies (monsters / hostile PvP)
    public static inline var COLOR_NAME_ENEMY:Int      = 0xEF4444; // Vibrant red name
    public static inline var COLOR_SUB_ENEMY:Int       = 0xF87171; // Coral / salmon red race
    public static inline var COLOR_HP_ENEMY:Int        = 0xEF4444; // Vibrant red health fill
    public static inline var COLOR_BAR_BG_ENEMY:Int    = 0x0A0B10; // High-contrast solid dark charcoal well
    public static inline var COLOR_BORDER_ENEMY:Int    = 0x000000; // Solid black border
    public static inline var COLOR_TARGET_ENEMY:Int    = 0xF87171; // Targeted enemy bright red highlight

    public var entity:EntityDTO = null;
    public var isEnemy:Bool = false;
    public var targetMC:Dynamic = null;
    public var rawUnit:Dynamic = null;

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
    private var _lastShowNames:Bool = true;

    public function new(isEnemy:Bool) {
        super();
        this.isEnemy = isEnemy;
        this.name = "__nameplate";
        mouseChildren = false;
        buttonMode = true;
        useHandCursor = true;

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

    /** Parents this plate inside the unit clip, directly above the native `pname`, sharing its coordinate space. */
    public function mountOnNative(mc:Dynamic, pn:Dynamic):Void {
        if (mc == null || pn == null) return;
        try {
            if (this.parent != mc) {
                var idx:Int = Std.int(mc.getChildIndex(pn)) + 1;
                mc.addChildAt(this, idx);
            }
        } catch (_:Dynamic) {
            try { if (this.parent != mc) mc.addChild(this); } catch (_:Dynamic) {}
        }
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

        _lastHp = -1;
        drawBarBg();
        drawTargetIndicators(_lastIsTarget);
        if (entity != null && entity.maxHp > 0) {
            _lastHp = entity.hp;
            _lastMaxHp = entity.maxHp;
            drawHealthBar(entity.hp, entity.maxHp);
        } else if (_lastMaxHp > 0) {
            drawHealthBar(_lastHp, _lastMaxHp);
        }
    }

    public function forceUpdateSub():Void {
        _lastSub = "";
        if (entity != null) {
            update(entity);
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
        if (mc == null || mc.visible == false || mc.stage == null) {
            visible = false;
            return;
        }
        targetMC = mc;
        if (ent.raw != null) rawUnit = ent.raw;

        // 2. Name & Subtitle Text from EntityDTO
        var showNames:Bool = isEnemy ? NameplateUnitFrame.isEnemyNamesEnabled() : NameplateUnitFrame.isPlayerNamesEnabled();
        var rawName:String = (ent.isAfk ? "<AFK> " : "") + ent.name;
        var rawSub:String = "";

        if (isEnemy) {
            if (ent.race != "") rawSub = "< " + ent.race + " >";
        } else {
            if (UnitFramesManager.isShowClassNames() && ent.className != "") {
                rawName = (ent.isAfk ? "<AFK> " : "") + ent.className;
            }
            if (NameplateUnitFrame.isShowGuildNames() && ent.guild != "") rawSub = "< " + ent.guild + " >";
        }

        // 3. Native anchor parity: sit exactly at the character's horizontal center,
        // matching the game's dynamic vertical position (pname.y, computed by scale() from headPoint).
        // Note: pname.x in Flash is -68.0 (an internal left-offset for a 136px box), whereas
        // mcChar.x (0.0) is the true unit center. Since NameplateDisplay is already centered around 0,
        // x must be mcChar.x (0.0).
        var nativeNameVisible:Bool = true;
        try {
            var pn:Dynamic = com.aqwapi.utils.ApiUtils.safeField(mc, "pname");
            if (pn != null) {
                mountOnNative(mc, pn);
                var targetX:Float = 0.0;
                try {
                    if (mc.mcChar != null && mc.mcChar.x != null) targetX = mc.mcChar.x;
                } catch (_:Dynamic) {}
                if (x != targetX) x = targetX;

                // Anchor monster nameplates fixed at their feet (ground level)
                // so large/scaled enemies don't push them hundreds of pixels into the sky!
                // Player nameplates sit overhead at pn.y.
                if (isEnemy) {
                    var feetY:Float = 12.0;
                    try {
                        if (mc.shadow != null && mc.shadow.height != null && mc.shadow.height > 0) {
                            feetY = Math.max(12.0, (mc.shadow.height / 2.0) + 4.0);
                        }
                    } catch (_:Dynamic) {}
                    if (y != feetY) y = feetY;
                } else {
                    if (y != pn.y) y = pn.y;
                }

                // Counteract any non-uniform or inverted scaling from parent clip
                try {
                    var sX:Float = (mc.scaleX != null && mc.scaleX != 0.0) ? (1.0 / mc.scaleX) : 1.0;
                    var sY:Float = (mc.scaleY != null && mc.scaleY != 0.0) ? (1.0 / mc.scaleY) : 1.0;
                    if (scaleX != sX) scaleX = sX;
                    if (scaleY != sY) scaleY = sY;
                } catch (_:Dynamic) {}

                nativeNameVisible = (pn.visible != false);
            }
        } catch (_:Dynamic) {}

        // Apply text only when changed
        if (rawName != _lastName) {
            _lastName = rawName;
            _nameTxt.text = rawName;
            _nameTxt.filters = ApiStyle.getTextOutlineFilter();
        }
        if (rawSub != _lastSub) {
            _lastSub = rawSub;
            _subTxt.text = rawSub;
            _subTxt.filters = ApiStyle.getTextOutlineFilter();
        }

        showNames = showNames && nativeNameVisible;
        _nameTxt.visible = showNames;
        _subTxt.visible = (showNames && rawSub != "");

        // Sync bar graphics if showNames toggled
        if (showNames != _lastShowNames) {
            _lastShowNames = showNames;
            drawBarBg();
            drawTargetIndicators(_lastIsTarget);
            if (_lastMaxHp > 0) {
                drawHealthBar(_lastHp, _lastMaxHp);
            }
        }

        // 4. Target Chevrons via API
        var pTarget:EntityDTO = (Api.player != null && Api.player.hasTarget) ? Api.player.target : null;
        var isTarget:Bool = ent.isCurrentTarget;
        if (!isTarget && pTarget != null) {
            var tRaw = pTarget.raw;
            if (tRaw == ent.raw || (ent.pMC != null && (tRaw == ent.pMC || tRaw.pMC == ent.pMC))) {
                isTarget = true;
            }
        }
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

        // Ensure targeted entity's live HP/MaxHP strictly syncs with Api.player.target (matches TargetUnitFrame)
        if (isTarget && pTarget != null) {
            if (pTarget.hp >= 0) ent.hp = pTarget.hp;
            if (pTarget.maxHp > 0) ent.maxHp = pTarget.maxHp;
        } else if (ent.isMyAvatar && Api.player != null) {
            ent.hp = Api.player.hp;
            ent.maxHp = Api.player.maxHp;
        }

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

        // Transparent hit area for easy click-to-target even on thin bar
        g.beginFill(0x000000, 0.0);
        g.drawRect(-BAR_W / 2 - 4, barY - 6, BAR_W + 8, BAR_H + 12);
        g.endFill();

        // High-contrast solid dark background well + solid black border
        g.beginFill(isEnemy ? COLOR_BAR_BG_ENEMY : COLOR_BAR_BG_PLAYER, 1.0);
        g.lineStyle(1.0, isEnemy ? COLOR_BORDER_ENEMY : COLOR_BORDER_PLAYER, 1.0);
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
            var ratio:Float = Math.max(0.0, Math.min(1.0, (hp : Float) / (maxHp : Float)));
            var fillW:Float = Math.round((BAR_W - 2.0) * ratio);
            if (fillW > 0) {
                var color:Int = isEnemy ? COLOR_HP_ENEMY : NativeFramesEnhancer.getHealthColor(ratio);
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
        targetMC = null;
        rawUnit = null;
        entity = null;
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
    private static var _theStage:Dynamic = null;

    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {
        if (_initialized) return;
        _initialized = true;
        _pocket = pocket;
        _overlay = overlay;

        var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);
        if (theStage == null && Api.game != null && Api.game.stage != null) {
            theStage = Api.game.stage;
        }
        _theStage = theStage;

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
    }

    public static inline function isWidgetEnabled():Bool {
        return ApiConfig.getBool("api_frame_nameplates_enabled", false);
    }

    public static inline function setWidgetEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_nameplates_enabled", enabled);
        if (!enabled) {
            disableAllPlates();
        }
    }

    public static inline function isEnemiesEnabled():Bool {
        return ApiConfig.getBool("api_frame_nameplates_enemies", false);
    }

    public static function setEnemiesEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_nameplates_enemies", enabled);
        for (p in _activePlates) {
            if (p.isEnemy) p.updateDisplay();
        }
    }

    public static inline function isEnemyNamesEnabled():Bool {
        return ApiConfig.getBool("api_frame_nameplates_enemy_names", false);
    }

    public static function setEnemyNamesEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_nameplates_enemy_names", enabled);
        for (p in _activePlates) {
            if (p.isEnemy) p.updateDisplay();
        }
    }

    public static inline function isPlayersEnabled():Bool {
        return ApiConfig.getBool("api_frame_nameplates_players", false);
    }

    public static function setPlayersEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_nameplates_players", enabled);
        for (p in _activePlates) {
            if (!p.isEnemy) p.updateDisplay();
        }
    }

    public static inline function isPlayerNamesEnabled():Bool {
        return ApiConfig.getBool("api_frame_nameplates_player_names", false);
    }

    public static function setPlayerNamesEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_nameplates_player_names", enabled);
        for (p in _activePlates) {
            if (!p.isEnemy) p.updateDisplay();
        }
    }

    public static inline function isShowGuildNames():Bool {
        return ApiConfig.getBool("api_frame_nameplates_guild_names", false);
    }

    public static function setShowGuildNames(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_nameplates_guild_names", enabled);
        for (p in _activePlates) {
            if (!p.isEnemy) p.forceUpdateSub();
        }
    }

    public static function reloadFromConfig():Void {
        if (!isWidgetEnabled()) {
            disableAllPlates();
        } else {
            for (p in _activePlates) {
                p.forceUpdateSub();
                p.updateDisplay();
            }
        }
    }

    private static inline function isTypeReplaced(isEnemy:Bool):Bool {
        return isEnemy ? (isEnemiesEnabled() || isEnemyNamesEnabled()) : (isPlayersEnabled() || isPlayerNamesEnabled());
    }

    private static function onEnterFrame(e:Event):Void {
        if (!ApiMenus.isInGame() || !isWidgetEnabled()) {
            if (_activePlates.length > 0) disableAllPlates();
            return;
        }

        // 1. Prune detached, dead, off-stage, or no-longer-replaced plates (restoring the native one)
        var i:Int = _activePlates.length - 1;
        while (i >= 0) {
            var p = _activePlates[i];
            var dead:Bool = false;
            if (p.entity == null || !p.entity.hasGraphic || p.entity.pMC == null || !isTypeReplaced(p.isEnemy)) {
                dead = true;
            } else {
                try {
                    if (p.entity.pMC.stage == null || p.entity.pMC.parent == null || !p.entity.isAlive) dead = true;
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

        // 2. Query entities on screen directly from the API
        var entities:Array<EntityDTO> = (Api.map != null) ? Api.map.getEntitiesOnScreen() : [];

        for (ent in entities) {
            if (ent == null || !ent.hasGraphic || ent.pMC == null) continue;
            var isEnemy:Bool = ent.isMonster || ent.isHostilePvP;
            if (!isTypeReplaced(isEnemy)) continue;
            attachOrUpdate(ent, isEnemy);
        }
    }

    private static function attachOrUpdate(ent:EntityDTO, isEnemy:Bool):Void {
        var mc:Dynamic = ent.pMC;
        if (mc == null) return;

        // Suppress native pname / hpBar (alpha only; the game keeps owning position and visibility)
        ent.hideNativeName();

        var plate:NameplateDisplay = null;
        for (p in _activePlates) {
            if (p.rawUnit == ent.raw || p.targetMC == mc) {
                plate = p;
                break;
            }
        }

        if (plate == null) {
            plate = new NameplateDisplay(isEnemy);
            plate.entity = ent;
            plate.targetMC = mc;
            plate.rawUnit = ent.raw;
            _activePlates.push(plate);
        } else {
            plate.entity = ent;
            plate.targetMC = mc;
            if (ent.raw != null) plate.rawUnit = ent.raw;
            if (plate.isEnemy != isEnemy) {
                plate.isEnemy = isEnemy;
                plate.updateDisplay();
            }
        }

        // Mounts on the native pname and syncs contents from the EntityDTO
        plate.update(ent);
    }

    private static function disableAllPlates():Void {
        for (p in _activePlates) {
            if (p.entity != null) p.entity.showNativeName();
            p.destroy();
        }
        _activePlates = [];
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
    public static inline function isShowGuildNames():Bool return true;
    public static inline function setShowGuildNames(enabled:Bool):Void {}
    public static function reloadFromConfig():Void {}
}
#end
