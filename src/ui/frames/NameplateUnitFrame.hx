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

        // Initial draw of resting well
        drawBarBg(false);

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
        _barBg.visible = show;
        _barFill.visible = show;
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
        visible = true;

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
            _subTxt.visible = (rawSub != "");
        }

        // 4. Target Highlight Border via API
        var isTarget:Bool = ent.isCurrentTarget;
        if (isTarget != _lastIsTarget) {
            _lastIsTarget = isTarget;
            drawBarBg(isTarget);
        }

        // 5. Health Bar Fill & Visibility via API
        var showBar:Bool = isEnemy ? NameplateUnitFrame.isEnemiesEnabled() : NameplateUnitFrame.isPlayersEnabled();
        _barBg.visible = showBar;
        _barFill.visible = showBar;

        if (showBar && (ent.hp != _lastHp || ent.maxHp != _lastMaxHp)) {
            _lastHp = ent.hp;
            _lastMaxHp = ent.maxHp;
            drawHealthBar(ent.hp, ent.maxHp);
        }
    }

    private function drawBarBg(isTarget:Bool):Void {
        var g = _barBg.graphics;
        g.clear();
        g.beginFill(isEnemy ? COLOR_BAR_BG_ENEMY : COLOR_BAR_BG_PLAYER, 0.85);
        if (isTarget) {
            g.lineStyle(1.5, isEnemy ? COLOR_TARGET_ENEMY : COLOR_TARGET_PLAYER, 1.0);
        } else {
            g.lineStyle(1.0, isEnemy ? COLOR_BORDER_ENEMY : COLOR_BORDER_PLAYER, 0.85);
        }
        g.drawRoundRect(-BAR_W / 2, BAR_Y, BAR_W, BAR_H, 2, 2);
        g.endFill();
    }

    private function drawHealthBar(hp:Int, maxHp:Int):Void {
        var g = _barFill.graphics;
        g.clear();
        if (hp > 0 && maxHp > 0) {
            var ratio:Float = Math.max(0.0, Math.min(1.0, hp / maxHp));
            var fillW:Float = Math.round((BAR_W - 2.0) * ratio);
            if (fillW > 0) {
                var color:Int = isEnemy ? COLOR_HP_ENEMY : PlayerUnitFrame.getHealthColor(ratio);
                g.beginFill(color, 1.0);
                g.drawRoundRect(-BAR_W / 2 + 1, BAR_Y + 1, fillW, BAR_H - 2, 1, 1);
                g.endFill();
            }
        }
    }

    public function destroy():Void {
        removeEventListener(MouseEvent.CLICK, onClick);
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
    }

    public static inline function isWidgetEnabled():Bool {
        return ApiConfig.getBool("api_frame_nameplates_enabled", true);
    }

    public static inline function setWidgetEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_nameplates_enabled", enabled);
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
            if (p.isEnemy) p.setBarVisible(enabled);
        }
    }

    public static inline function isPlayersEnabled():Bool {
        return ApiConfig.getBool("api_frame_nameplates_players", true);
    }

    public static function setPlayersEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_nameplates_players", enabled);
        for (p in _activePlates) {
            if (!p.isEnemy) p.setBarVisible(enabled);
        }
    }

    public static function reloadFromConfig():Void {
        if (!isWidgetEnabled()) {
            disableAllPlates();
        } else {
            var showEnemies = isEnemiesEnabled();
            var showPlayers = isPlayersEnabled();
            for (p in _activePlates) {
                p.setBarVisible(p.isEnemy ? showEnemies : showPlayers);
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
    public static inline function isPlayersEnabled():Bool return false;
    public static inline function setPlayersEnabled(enabled:Bool):Void {}
    public static function reloadFromConfig():Void {}
}
#end
