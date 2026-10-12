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
import com.aqwapi.utils.ApiConfig;
import ui.ApiMenus;
import ui.ApiStyle;

/**
 * NameplateDisplay:
 * Ultra-lightweight overhead display for a single character (player or enemy).
 * Attached directly as a child of the unit's MovieClip (AvatarMC or MonsterMC)
 * so it follows movement in hardware with zero latency, zero stutter, and zero CPU lag.
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

    public var targetMC:Dynamic = null;
    public var avatarRef:Dynamic = null;
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
        _nameTxt.x = -100;
        _nameTxt.y = NAME_Y;
        _nameTxt.width = 200;
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
        _subTxt.x = -100;
        _subTxt.y = SUB_Y;
        _subTxt.width = 200;
        _subTxt.height = SUB_H;
        _subTxt.selectable = false;
        _subTxt.mouseEnabled = false;
        _subTxt.filters = ApiStyle.getTextOutlineFilter();
        addChild(_subTxt);

        // Interactive Click-to-Target
        addEventListener(MouseEvent.CLICK, onClick);
    }

    private function onClick(e:MouseEvent):Void {
        try {
            e.stopPropagation();
            var g:Dynamic = Api.game;
            if (g != null && g.world != null) {
                var targetAvt:Dynamic = (avatarRef != null) ? avatarRef : ((targetMC != null) ? targetMC.pAV : null);
                if (targetAvt != null && Reflect.isFunction(g.world.setTarget)) {
                    g.world.setTarget(targetAvt);
                }
            }
        } catch (_:Dynamic) {}
    }

    public function update(pAV:Dynamic):Void {
        this.avatarRef = pAV;

        // 1. Alive / Dead Check
        var isDead:Bool = false;
        var curHp:Int = 0;
        var maxHp:Int = 0;
        var state:Int = 1;

        if (pAV != null && pAV.dataLeaf != null) {
            var dl:Dynamic = pAV.dataLeaf;
            if (dl.intHP != null) curHp = Std.int(dl.intHP);
            if (dl.intHPMax != null) maxHp = Std.int(dl.intHPMax);
            if (dl.intState != null) state = Std.int(dl.intState);
        }

        if (isEnemy) {
            if (state == 0 || curHp <= 0) isDead = true;
        } else {
            if (state == 0 && curHp <= 0) isDead = true;
        }

        if (isDead) {
            visible = false;
            return;
        }

        // Must match character's visibility
        if (targetMC != null && targetMC.visible == false) {
            visible = false;
            return;
        }
        visible = true;

        // 2. Position synchronization with native pname coordinates
        if (targetMC != null && targetMC.pname != null) {
            var ty:Float = targetMC.pname.y;
            var tx:Float = targetMC.pname.x;
            if (y != ty) y = ty;
            if (x != tx) x = tx;
        }

        // 3. Name & Subtitle Text Synchronization
        var rawName:String = "";
        var rawSub:String = "";

        if (isEnemy) {
            // Monster Name
            if (pAV != null && pAV.objData != null && pAV.objData.strMonName != null) {
                rawName = Std.string(pAV.objData.strMonName);
            } else if (targetMC != null && targetMC.pname != null && targetMC.pname.ti != null) {
                rawName = Std.string(targetMC.pname.ti.text);
            }

            // Monster Race / Type
            if (pAV != null && pAV.objData != null && pAV.objData.sRace != null) {
                var r:String = Std.string(pAV.objData.sRace);
                if (r != "" && r != "None" && r != "null") {
                    rawSub = "< " + r + " >";
                }
            } else if (targetMC != null && targetMC.pname != null && targetMC.pname.typ != null && targetMC.pname.typ.text != "") {
                var r:String = Std.string(targetMC.pname.typ.text);
                if (r.indexOf("None") == -1) rawSub = r;
            }
        } else {
            // Player Name
            if (pAV != null && pAV.objData != null && pAV.objData.strUsername != null) {
                rawName = Std.string(pAV.objData.strUsername);
            } else if (targetMC != null && targetMC.pname != null && targetMC.pname.ti != null) {
                rawName = Std.string(targetMC.pname.ti.text);
            }

            // Check AFK
            var isAfk:Bool = false;
            try {
                var world:Dynamic = (Api.game != null) ? Api.game.world : null;
                if (world != null && world.uoTree != null && pAV != null && pAV.pnm != null) {
                    var uoLeaf:Dynamic = Reflect.field(world.uoTree, pAV.pnm);
                    if (uoLeaf == null) uoLeaf = Reflect.field(world.uoTree, Std.string(pAV.pnm).toLowerCase());
                    if (uoLeaf != null && uoLeaf.afk == true) isAfk = true;
                }
            } catch (_:Dynamic) {}

            if (isAfk && rawName != "" && rawName.indexOf("<AFK>") == -1) {
                rawName = "<AFK> " + rawName;
            }

            // Guild Subtitle
            if (pAV != null && pAV.objData != null && pAV.objData.guild != null && pAV.objData.guild.Name != null) {
                var g:String = Std.string(pAV.objData.guild.Name);
                if (g != "" && g != "null") rawSub = "< " + g + " >";
            } else if (targetMC != null && targetMC.pname != null && targetMC.pname.tg != null && targetMC.pname.tg.text != "") {
                rawSub = Std.string(targetMC.pname.tg.text);
            }
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

        // 4. Target Highlight Border
        var isCurrentTarget:Bool = false;
        try {
            var g:Dynamic = Api.game;
            if (g != null && g.world != null && g.world.myAvatar != null && g.world.myAvatar.target != null) {
                isCurrentTarget = (g.world.myAvatar.target == avatarRef);
            }
        } catch (_:Dynamic) {}

        if (isCurrentTarget != _lastIsTarget) {
            _lastIsTarget = isCurrentCurrent(isCurrentTarget);
            drawBarBg(isCurrentTarget);
        }

        // 5. Health Bar Fill
        if (curHp != _lastHp || maxHp != _lastMaxHp) {
            _lastHp = curHp;
            _lastMaxHp = maxHp;
            drawHealthBar(curHp, maxHp);
        }
    }

    private inline function isCurrentCurrent(val:Bool):Bool {
        return val;
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
 * - Suppresses native pname and hpBar MovieClips to prevent frame drops in crowded rooms.
 * - Full interactive click-to-target support.
 */
class NameplateUnitFrame {
    private static var _initialized:Bool = false;
    private static var _ticker:Sprite = null;
    private static var _activePlates:Array<NameplateDisplay> = [];

    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {
        if (_initialized) return;
        _initialized = true;

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
        } else if (overlay != null) {
            overlay.addEventListener(Event.ADDED_TO_STAGE, function(_:Event):Void {
                if (overlay.stage != null && _ticker == null) {
                    attachTicker(overlay.stage);
                }
            });
        }
    }

    private static var _pocket:Dynamic = null;
    private static var _overlay:Dynamic = null;

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

    public static inline function setEnemiesEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_nameplates_enemies", enabled);
        if (!enabled) {
            pruneEnemyPlates();
        }
    }

    public static inline function isPlayersEnabled():Bool {
        return ApiConfig.getBool("api_frame_nameplates_players", true);
    }

    public static inline function setPlayersEnabled(enabled:Bool):Void {
        ApiConfig.setBool("api_frame_nameplates_players", enabled);
        if (!enabled) {
            prunePlayerPlates();
        }
    }

    public static function reloadFromConfig():Void {
        if (!isWidgetEnabled()) {
            disableAllPlates();
        }
    }

    private static function onEnterFrame(e:Event):Void {
        if (!ApiMenus.isInGame()) {
            if (_activePlates.length > 0) disableAllPlates();
            return;
        }

        if (!isWidgetEnabled()) {
            if (_activePlates.length > 0) disableAllPlates();
            return;
        }

        var g:Dynamic = Api.game;
        if (g == null || g.world == null) return;
        var world:Dynamic = g.world;

        // 1. Prune detached or destroyed plates
        var i:Int = _activePlates.length - 1;
        while (i >= 0) {
            var p = _activePlates[i];
            if (p.targetMC == null || p.targetMC.stage == null || p.targetMC.parent == null) {
                p.destroy();
                try { Reflect.deleteField(p.targetMC, "__nameplate"); } catch (_:Dynamic) {}
                _activePlates.splice(i, 1);
            }
            i--;
        }

        // 2. Scan all active rendered characters in world.CHARS
        var chars:Dynamic = world.CHARS;
        if (chars != null && chars.numChildren != null) {
            var allowEnemies:Bool = isEnemiesEnabled();
            var allowPlayers:Bool = isPlayersEnabled();
            var count:Int = chars.numChildren;

            for (idx in 0...count) {
                var mc:Dynamic = null;
                try { mc = chars.getChildAt(idx); } catch (_:Dynamic) { continue; }
                if (mc == null) continue;

                // Character MovieClip verification: must possess pAV and pname
                if (mc.pAV != null && mc.pname != null) {
                    var isEnemy:Bool = (mc.isMonster == true);

                    // Check PvP hostility if it is a player avatar
                    if (!isEnemy && world.bPvP == true) {
                        try {
                            if (world.myAvatar != null && world.myAvatar.dataLeaf != null && mc.pAV.dataLeaf != null) {
                                var myTeam = world.myAvatar.dataLeaf.pvpTeam;
                                var theirTeam = mc.pAV.dataLeaf.pvpTeam;
                                if (myTeam != null && theirTeam != null && myTeam != theirTeam) {
                                    isEnemy = true;
                                }
                            }
                        } catch (_:Dynamic) {}
                    }

                    if (isEnemy && !allowEnemies) continue;
                    if (!isEnemy && !allowPlayers) continue;

                    attachOrUpdate(mc, mc.pAV, isEnemy);
                }
            }
        }
    }

    private static function attachOrUpdate(mc:Dynamic, pAV:Dynamic, isEnemy:Bool):Void {
        if (mc == null || pAV == null) return;

        // 1. Suppress native vector pname and hpBar MovieClips
        if (mc.pname != null && mc.pname.visible == true) {
            mc.pname.visible = false;
        }
        if (mc.hpBar != null && mc.hpBar.visible == true) {
            mc.hpBar.visible = false;
        }

        // 2. Retrieve existing or create new NameplateDisplay
        var plate:NameplateDisplay = null;
        if (Reflect.hasField(mc, "__nameplate")) {
            plate = Reflect.field(mc, "__nameplate");
        }

        if (plate == null) {
            plate = new NameplateDisplay(isEnemy);
            plate.targetMC = mc;
            plate.avatarRef = pAV;
            Reflect.setField(mc, "__nameplate", plate);
            mc.addChild(plate);
            _activePlates.push(plate);
        } else {
            if (plate.parent != mc) {
                mc.addChild(plate);
            }
            plate.avatarRef = pAV;
        }

        // 3. Update plate contents
        plate.update(pAV);
    }

    private static function disableAllPlates():Void {
        for (p in _activePlates) {
            restoreNative(p.targetMC);
            p.destroy();
            try { Reflect.deleteField(p.targetMC, "__nameplate"); } catch (_:Dynamic) {}
        }
        _activePlates = [];
    }

    private static function pruneEnemyPlates():Void {
        var i:Int = _activePlates.length - 1;
        while (i >= 0) {
            var p = _activePlates[i];
            if (p.isEnemy) {
                restoreNative(p.targetMC);
                p.destroy();
                try { Reflect.deleteField(p.targetMC, "__nameplate"); } catch (_:Dynamic) {}
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
                restoreNative(p.targetMC);
                p.destroy();
                try { Reflect.deleteField(p.targetMC, "__nameplate"); } catch (_:Dynamic) {}
                _activePlates.splice(i, 1);
            }
            i--;
        }
    }

    private static function restoreNative(mc:Dynamic):Void {
        if (mc == null) return;
        try {
            if (mc.pname != null) mc.pname.visible = true;
            if (mc.hpBar != null) {
                var world:Dynamic = (Api.game != null) ? Api.game.world : null;
                mc.hpBar.visible = (world != null && world.showHPBar == true);
            }
        } catch (_:Dynamic) {}
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
