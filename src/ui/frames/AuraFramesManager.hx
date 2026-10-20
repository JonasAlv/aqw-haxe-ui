package ui.frames;

#if flash
import flash.display.DisplayObject;
import flash.display.MovieClip;
import flash.display.Sprite;
import flash.events.Event;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.Lib;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiConfig;
import ui.ApiMenus;
import ui.ApiStyle;

/**
 * AuraFramesManager:
 * Native AQW Aura HUD Optimizer, Cooldown Timer Engine, and Combat Filter.
 *
 * Uses ONLY public DisplayObject and entity data properties to avoid Flash Error #1069
 * on sealed private AS3 class members.
 */
class AuraFramesManager {
    private static var _initialized:Bool = false;
    private static var _ticker:Sprite = null;
    private static var _lastTick:Float = 0.0;
    private static var _lastTAurasUI:Dynamic = null;
    private static var _lastPAurasUI:Dynamic = null;
    private static var CD_GLOW:Array<flash.filters.BitmapFilter> = [new flash.filters.GlowFilter(0x000000, 1.0, 3, 3, 4, 1)];

    private static inline var PITCH_X:Float = 32.0;
    private static inline var PITCH_Y:Float = 28.0;
    private static inline var PER_ROW:Int   = 4;

    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {
        if (_initialized) return;
        _initialized = true;

        var theStage:Dynamic = (pocket != null && pocket.stage != null) ? pocket.stage : (overlay != null ? overlay.stage : null);
        if (theStage == null && Api.game != null && Api.game.stage != null) {
            theStage = Api.game.stage;
        }

        var attachTicker = function(stageObj:Dynamic):Void {
            if (stageObj == null || _ticker != null) return;
            _ticker = new Sprite();
            _ticker.addEventListener(Event.ENTER_FRAME, onPreFrame, false, 100, true);
            _ticker.addEventListener(Event.ENTER_FRAME, onPostFrame, false, -100, true);
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

    public static function resetPositions():Void {
        try {
            var g:Dynamic = Api.game;
            if (g != null) {
                if (g.pAurasUI != null && Reflect.isFunction(g.pAurasUI.resetPosition)) {
                    g.pAurasUI.resetPosition();
                }
                if (g.tAurasUI != null && Reflect.isFunction(g.tAurasUI.resetPosition)) {
                    g.tAurasUI.resetPosition();
                }
                if (g.litePreference != null && g.litePreference.data != null) {
                    g.litePreference.data.posAurasP = { "x": 130, "y": 100 };
                    g.litePreference.data.posAurasT = { "x": 320, "y": 104 };
                    try { g.litePreference.flush(); } catch (_:Dynamic) {}
                }
            }
        } catch (_:Dynamic) {}
    }

    public static inline function isCdTimersEnabled():Bool {
        return ApiConfig.getBool("api_auras_cd_timers", true);
    }

    public static function setCdTimersEnabled(v:Bool):Void {
        ApiConfig.setBool("api_auras_cd_timers", v);
    }

    public static inline function isMyAurasOnly():Bool {
        return ApiConfig.getBool("api_auras_my_only", true);
    }

    public static function setMyAurasOnly(v:Bool):Void {
        ApiConfig.setBool("api_auras_my_only", v);
    }

    public static inline function isLagKillerEnabled():Bool {
        return ApiConfig.getBool("api_auras_lag_killer", true);
    }

    public static function setLagKillerEnabled(v:Bool):Void {
        ApiConfig.setBool("api_auras_lag_killer", v);
    }

    public static inline var COLOR_BORDER_BUFF:Int   = 0x3B82F6; // Vibrant blue for Buffs
    public static inline var COLOR_BORDER_DEBUFF:Int = 0xEF4444; // Vibrant crimson red for Debuffs

    public static inline function isColoredBordersEnabled():Bool {
        return ApiConfig.getBool("api_auras_colored_borders", true);
    }

    public static function setColoredBordersEnabled(v:Bool):Void {
        ApiConfig.setBool("api_auras_colored_borders", v);
    }

    public static inline function isAuraBackingEnabled():Bool {
        return ApiConfig.getBool("api_auras_backing", true);
    }

    public static function setAuraBackingEnabled(v:Bool):Void {
        ApiConfig.setBool("api_auras_backing", v);
    }

    /**
     * Safely retrieves all child AuraCell instances from an AuraHUD container
     * without accessing the private 'order' or 'cells' members.
     */
    private static function getCells(hud:Dynamic):Array<Dynamic> {
        var cells:Array<Dynamic> = [];
        if (hud == null) return cells;
        try {
            var num:Int = (hud.numChildren != null) ? hud.numChildren : 0;
            for (i in 0...num) {
                var ch:Dynamic = hud.getChildAt(i);
                if (ch != null && ch.nam != null) {
                    cells.push(ch);
                }
            }
            cells.sort(function(a:Dynamic, b:Dynamic):Int {
                var sa:Int = (a.seq != null) ? a.seq : 0;
                var sb:Int = (b.seq != null) ? b.seq : 0;
                return sa - sb;
            });
        } catch (_:Dynamic) {}
        return cells;
    }

    private static var KNOWN_MONSTER_AURAS:Array<String> = [
        "counter attack",
        "retaliate",
        "fox",
        "damage reflect",
        "reflect",
        "reflective shield",
        "talon twisting",
        "safeguard",
        "focus",
        "enraged",
        "shield",
        "absolute defense",
        "defiance",
        "stone skin",
        "absorb",
        "inner fire",
        "unstoppable",
        "invulnerable",
        "damage shield",
        "radiance",
        "overcharge",
        "frenzy",
        "berserk",
        "charge",
        "preparation",
        "prepared",
        "empowered",
        "defense"
    ];

    private static function isKnownMonsterMechanic(searchName:String):Bool {
        for (m in KNOWN_MONSTER_AURAS) {
            if (searchName == m || searchName.indexOf(m) != -1) return true;
        }
        return false;
    }

    private static function getMyUids():Array<Dynamic> {
        var uids:Array<Dynamic> = [];
        try {
            if (Api.game != null) {
                if (Api.game.sfc != null && Api.game.sfc.myUserId != null) {
                    uids.push(Api.game.sfc.myUserId);
                }
                if (Api.game.world != null) {
                    var w:Dynamic = Api.game.world;
                    if (w.myAvatar != null) {
                        var av:Dynamic = w.myAvatar;
                        if (av.uid != null) uids.push(av.uid);
                        if (av.dataLeaf != null) {
                            if (av.dataLeaf.entID != null) uids.push(av.dataLeaf.entID);
                            if (av.dataLeaf.EntID != null) uids.push(av.dataLeaf.EntID);
                        }
                    }
                    if (Reflect.isFunction(w.myLeaf)) {
                        var ml:Dynamic = w.myLeaf();
                        if (ml != null) {
                            if (ml.entID != null) uids.push(ml.entID);
                            if (ml.EntID != null) uids.push(ml.EntID);
                        }
                    }
                    if (Api.game.sfc != null && Api.game.sfc.myUserName != null && w.uoTree != null) {
                        var unm:String = Std.string(Api.game.sfc.myUserName).toLowerCase();
                        var ml:Dynamic = untyped w.uoTree[unm];
                        if (ml != null) {
                            if (ml.entID != null) uids.push(ml.entID);
                            if (ml.EntID != null) uids.push(ml.EntID);
                        }
                    }
                }
            }
        } catch (_:Dynamic) {}
        return uids;
    }

    private static function isMyId(id:Dynamic, myUids:Array<Dynamic>):Bool {
        if (id == null || myUids == null) return false;
        var sId:String = Std.string(id);
        for (m in myUids) {
            if (m != null && Std.string(m) == sId) return true;
        }
        return false;
    }

    private static function getEntityAurasLists(entity:Dynamic, isMonster:Bool):Array<Dynamic> {
        var lists:Array<Dynamic> = [];
        if (entity == null) return lists;

        try {
            if (entity.dataLeaf != null) {
                if (entity.dataLeaf.auras != null) lists.push(entity.dataLeaf.auras);
                if (entity.dataLeaf.passives != null) lists.push(entity.dataLeaf.passives);
            }
            if (entity.auras != null) {
                lists.push(entity.auras);
            }

            if (Api.game != null && Api.game.world != null) {
                var w:Dynamic = Api.game.world;
                if (isMonster) {
                    var mmid:Dynamic = null;
                    if (entity.dataLeaf != null && entity.dataLeaf.MonMapID != null) mmid = entity.dataLeaf.MonMapID;
                    else if (entity.objData != null && entity.objData.MonMapID != null) mmid = entity.objData.MonMapID;
                    if (mmid != null && w.monTree != null) {
                        var monLeaf:Dynamic = untyped w.monTree[mmid];
                        if (monLeaf == null) monLeaf = untyped w.monTree[Std.string(mmid)];
                        if (monLeaf != null) {
                            if (monLeaf.auras != null) lists.push(monLeaf.auras);
                            if (monLeaf.passives != null) lists.push(monLeaf.passives);
                        }
                    }
                } else {
                    var pnm:String = null;
                    if (entity.pnm != null) pnm = Std.string(entity.pnm);
                    else if (entity.dataLeaf != null && entity.dataLeaf.strUsername != null) pnm = Std.string(entity.dataLeaf.strUsername);
                    if (pnm == null && w.myAvatar == entity && Api.game.sfc != null && Api.game.sfc.myUserName != null) {
                        pnm = Std.string(Api.game.sfc.myUserName);
                    }
                    if (pnm != null && w.uoTree != null) {
                        var uoLeaf:Dynamic = untyped w.uoTree[pnm.toLowerCase()];
                        if (uoLeaf != null) {
                            if (uoLeaf.auras != null) lists.push(uoLeaf.auras);
                            if (uoLeaf.passives != null) lists.push(uoLeaf.passives);
                        }
                    }
                }
            }
        } catch (_:Dynamic) {}
        return lists;
    }

    /**
     * Optimizes a single AuraCell:
     * - Suppresses laggy ActMaskReverse dynamic stencil masks and BitmapData.draw
     *   by neutralizing them in the child display hierarchy (avoiding private member access)
     * - Manages centered numeric cooldown countdown text field
     * - Renders high-contrast colored borders: Red for Debuffs, Blue for Buffs
     */
    private static function processCell(cell:Dynamic, nowMs:Float, cdEnabled:Bool, lagKiller:Bool, isDebuff:Bool = false, bordersEnabled:Bool = true):Void {
        // A. Lag Killer: disable ActMaskReverse dynamic vector mask and software rasterization
        // Automatically suppresses the sweep mask when Lag Killer is enabled OR Cooldown Timers are enabled.
        var suppressSweep:Bool = lagKiller || cdEnabled;
        if (suppressSweep && cell.numChildren != null && cell.numChildren > 0) {
            try {
                var base:Dynamic = cell.getChildAt(0);
                if (base != null && base.numChildren != null) {
                    var n:Int = base.numChildren;
                    for (j in 0...n) {
                        var ch:Dynamic = base.getChildAt(j);
                        if (ch != null) {
                            if (Std.isOfType(ch, flash.display.Bitmap)) {
                                ch.visible = false;
                                ch.mask = null;
                            } else if (Std.isOfType(ch, flash.display.MovieClip) && ch != base.cnt) {
                                ch.visible = false;
                                try { cast(ch, flash.display.MovieClip).stop(); } catch (_:Dynamic) {}
                            }
                        }
                    }
                }
            } catch (_:Dynamic) {}
        }

        var backingEnabled:Bool = isAuraBackingEnabled();

        // Calculate outer boundary enclosing the aura button frame:
        var bx:Float = -1.0;
        var by:Float = -1.0;
        var bw:Float = 28.5;
        var bh:Float = 26.0;

        try {
            var base:Dynamic = (cell.numChildren != null && cell.numChildren > 0) ? cell.getChildAt(0) : null;
            if (base != null) {
                var bounds:flash.geom.Rectangle = null;
                if (base.bg != null) {
                    bounds = base.bg.getBounds(cell);
                } else {
                    bounds = base.getBounds(cell);
                }
                if (bounds != null && bounds.width >= 20.0 && bounds.height >= 18.0) {
                    bx = bounds.x - 1.0;
                    by = bounds.y - 1.0;
                    bw = bounds.width + 2.0;
                    bh = bounds.height + 2.0;
                }
            }
        } catch (_:Dynamic) {}

        // Semi-transparent dark background backing (behind icon and text for maximum readability)
        var backing:flash.display.Shape = null;
        try {
            var childObj:Dynamic = cell.getChildByName("__backing");
            if (childObj != null && Std.isOfType(childObj, flash.display.Shape)) {
                backing = cast childObj;
            }
        } catch (_:Dynamic) {}

        if (backing == null && backingEnabled) {
            backing = new flash.display.Shape();
            backing.name = "__backing";
            try {
                cell.addChildAt(backing, 0);
            } catch (_:Dynamic) {
                try { cell.addChild(backing); } catch (_:Dynamic) {}
            }
        }

        if (backing != null) {
            if (!backingEnabled) {
                backing.visible = false;
            } else {
                backing.visible = true;
                var bgG = backing.graphics;
                bgG.clear();
                bgG.beginFill(0x0A0B10, 0.72); // Semi-transparent dark slate backing
                bgG.drawRoundRect(bx, by, bw, bh, 3.5, 3.5);
                bgG.endFill();
                try {
                    if (cell.numChildren != null && cell.getChildIndex(backing) > 0) {
                        cell.setChildIndex(backing, 0);
                    }
                } catch (_:Dynamic) {}
            }
        }

        // B. Colored Border (Red for Debuffs, Blue for Buffs)
        var border:flash.display.Shape = null;
        try {
            var childObj:Dynamic = cell.getChildByName("__border");
            if (childObj != null && Std.isOfType(childObj, flash.display.Shape)) {
                border = cast childObj;
            }
        } catch (_:Dynamic) {}

        if (border == null && bordersEnabled) {
            border = new flash.display.Shape();
            border.name = "__border";
            try {
                cell.addChild(border);
            } catch (_:Dynamic) {}
        }

        if (border != null) {
            if (!bordersEnabled) {
                border.visible = false;
            } else {
                border.visible = true;
                var borderColor:Int = isDebuff ? COLOR_BORDER_DEBUFF : COLOR_BORDER_BUFF;
                var g = border.graphics;
                g.clear();
                g.lineStyle(1.8, borderColor, 0.95, true, flash.display.LineScaleMode.NORMAL, flash.display.CapsStyle.ROUND, flash.display.JointStyle.ROUND);
                g.drawRoundRect(bx, by, bw, bh, 3.5, 3.5);

                try {
                    if (cell.numChildren != null && cell.getChildIndex(border) < cell.numChildren - 2) {
                        cell.setChildIndex(border, cell.numChildren - 2);
                    }
                } catch (_:Dynamic) {}
            }
        }

        // C. Cooldown Timer Text
        var cdTxt:TextField = null;
        try {
            var childObj:Dynamic = cell.getChildByName("__cdTxt");
            if (childObj != null && Std.isOfType(childObj, TextField)) {
                cdTxt = cast childObj;
            }
        } catch (_:Dynamic) {}

        if (cdTxt == null) {
            cdTxt = new TextField();
            cdTxt.name = "__cdTxt";
            var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 10, 0xFFFFFF, true, null, null, null, null, TextFormatAlign.CENTER);
            cdTxt.defaultTextFormat = fmt;
            cdTxt.selectable = false;
            cdTxt.mouseEnabled = false;
            cdTxt.filters = CD_GLOW;
            cdTxt.width = 28;
            cdTxt.height = 14;
            cdTxt.x = -0.5;
            cdTxt.y = 4;
            try {
                cell.addChild(cdTxt);
            } catch (_:Dynamic) {}
        }

        try {
            if (cdTxt.parent == cell && cell.numChildren != null && cell.getChildIndex(cdTxt) != cell.numChildren - 1) {
                cell.setChildIndex(cdTxt, cell.numChildren - 1);
            }
        } catch (_:Dynamic) {}

        if (cdEnabled && cell.h != null && cell.h.end != null && cell.h.end > 0) {
            var endMs:Float = cell.h.end;
            var remMs:Float = endMs - nowMs;
            if (remMs > 0) {
                var remSec:Float = remMs / 1000.0;
                var str:String;
                if (remSec >= 60.0) {
                    str = Math.ceil(remSec / 60.0) + "m";
                } else if (remSec >= 10.0) {
                    str = Math.ceil(remSec) + "s";
                } else if (remSec >= 5.0) {
                    str = Math.ceil(remSec) + "s";
                } else {
                    var tenths:Float = Math.round(remSec * 10.0) / 10.0;
                    str = (tenths == Math.floor(tenths) ? tenths + ".0" : Std.string(tenths)) + "s";
                }

                if (cdTxt.text != str) {
                    cdTxt.text = str;
                    // Warning highlight when aura is expiring soon (<= 3 seconds)
                    var color:Int = (remSec <= 3.0) ? 0xFACC15 : 0xFFFFFF;
                    var fmt = cdTxt.defaultTextFormat;
                    if (fmt.color != color) {
                        fmt.color = color;
                        cdTxt.defaultTextFormat = fmt;
                        cdTxt.setTextFormat(fmt);
                    }
                }
                cdTxt.visible = true;
            } else {
                cdTxt.visible = false;
            }
        } else {
            cdTxt.visible = false;
        }
    }

    private static function checkHookAuraHUDs():Void {
        try {
            if (Api.game == null) return;
            var tUI:Dynamic = Reflect.field(Api.game, "tAurasUI");
            if (tUI != null && tUI != _lastTAurasUI) {
                _lastTAurasUI = tUI;
                try {
                    tUI.addEventListener(Event.ENTER_FRAME, onTargetPreTick, false, 100, true);
                    tUI.addEventListener(Event.ENTER_FRAME, onTargetPostTick, false, -100, true);
                } catch (_:Dynamic) {}
            }
            var pUI:Dynamic = Reflect.field(Api.game, "pAurasUI");
            if (pUI != null && pUI != _lastPAurasUI) {
                _lastPAurasUI = pUI;
                try {
                    pUI.addEventListener(Event.ENTER_FRAME, onPlayerPreTick, false, 100, true);
                    pUI.addEventListener(Event.ENTER_FRAME, onPlayerPostTick, false, -100, true);
                } catch (_:Dynamic) {}
            }
        } catch (_:Dynamic) {}
    }

    /**
     * Pre-Tick Target HUD Sanitizer:
     * Purges third-party auras from target.dataLeaf.hudAuras BEFORE native AuraHUD.onTick runs,
     * completely eliminating any 1-frame third-party visual flicker or layout displacement.
     * Re-sequences valid auras so Debuffs always display first (seq = 0, 1, 2...) followed by Buffs (seq = 10000+).
     */
    private static function sanitizeTargetHudAuras(targetObj:Dynamic, myUids:Array<Dynamic>, filterMyOnly:Bool):Void {
        if (targetObj == null) {
            var tUI:Dynamic = (Api.game != null) ? Reflect.field(Api.game, "tAurasUI") : null;
            if (tUI != null) {
                tUI.visible = false;
                var tCells:Array<Dynamic> = getCells(tUI);
                for (cell in tCells) {
                    cell.visible = false;
                    cell.x = -9999;
                    cell.y = -9999;
                }
            }
            return;
        }

        if (targetObj.dataLeaf == null || targetObj.dataLeaf.hudAuras == null) return;
        var hudAuras:Dynamic = targetObj.dataLeaf.hudAuras;
        var fields:Array<String> = Reflect.fields(hudAuras);
        if (fields == null || fields.length == 0) return;

        var modified:Bool = false;
        var validAuras:Array<{ name:String, seq:Int, isDebuff:Bool, entry:Dynamic }> = [];

        for (k in fields) {
            var entry:Dynamic = Reflect.field(hudAuras, k);
            if (entry == null) continue;

            if (filterMyOnly && !shouldShowTargetAura(k, targetObj, myUids)) {
                // Third-party aura on target: wipe it out before AuraHUD.sync ever sees it!
                untyped __delete__(hudAuras, k);
                modified = true;
            } else {
                var origSeq:Int = (entry.seq != null) ? entry.seq : 0;
                var isDebuff:Bool = isTargetAuraDebuff(k, targetObj, myUids);
                validAuras.push({ name: k, seq: origSeq, isDebuff: isDebuff, entry: entry });
            }
        }

        // Always sort Debuffs FIRST on target, preserving relative chronological order within groups
        validAuras.sort(function(a, b) {
            if (a.isDebuff != b.isDebuff) {
                return a.isDebuff ? -1 : 1;
            }
            return a.seq - b.seq;
        });

        var debuffSeq:Int = 0;
        var buffSeq:Int = 10000;
        for (item in validAuras) {
            var newSeq:Int = item.isDebuff ? (debuffSeq++) : (buffSeq++);
            if (item.entry.seq != newSeq) {
                item.entry.seq = newSeq;
                modified = true;
            }
        }

        if (modified) {
            targetObj.dataLeaf.hudAurasV = Std.int(targetObj.dataLeaf.hudAurasV) + 1;
        }
    }

    /**
     * Pre-Tick Player HUD Sanitizer:
     * Purges third-party external party buffs from myAvatar.dataLeaf.hudAuras when filterMyOnly is enabled.
     */
    private static function sanitizePlayerHudAuras(myAvatar:Dynamic, myUids:Array<Dynamic>, filterMyOnly:Bool):Void {
        if (myAvatar == null || myAvatar.dataLeaf == null || myAvatar.dataLeaf.hudAuras == null) return;
        var hudAuras:Dynamic = myAvatar.dataLeaf.hudAuras;
        var fields:Array<String> = Reflect.fields(hudAuras);
        if (fields == null || fields.length == 0) return;

        var modified:Bool = false;
        if (filterMyOnly) {
            for (k in fields) {
                var entry:Dynamic = Reflect.field(hudAuras, k);
                if (entry == null) continue;

                if (!shouldShowPlayerAura(k, myAvatar, myUids)) {
                    // Third-party buff on player: delete immediately
                    untyped __delete__(hudAuras, k);
                    modified = true;
                }
            }
        }

        if (modified) {
            myAvatar.dataLeaf.hudAurasV = Std.int(myAvatar.dataLeaf.hudAurasV) + 1;
        }
    }

    private static function onPreFrame(e:Event):Void {
        try {
            if (!ApiMenus.isInGame() || Api.game == null) return;
            checkHookAuraHUDs();

            var filterMyOnly:Bool = isMyAurasOnly();
            var myUids:Array<Dynamic> = (filterMyOnly || isColoredBordersEnabled()) ? getMyUids() : null;

            var targetObj:Dynamic = (Api.game.world != null && Api.game.world.myAvatar != null) ? Api.game.world.myAvatar.target : null;
            sanitizeTargetHudAuras(targetObj, myUids, filterMyOnly);

            var myAvatar:Dynamic = (Api.game.world != null) ? Api.game.world.myAvatar : null;
            sanitizePlayerHudAuras(myAvatar, myUids, filterMyOnly);
        } catch (_:Dynamic) {}
    }

    private static function onTargetPreTick(e:Event):Void {
        try {
            if (!ApiMenus.isInGame() || Api.game == null) return;
            var filterMyOnly:Bool = isMyAurasOnly();
            var myUids:Array<Dynamic> = (filterMyOnly || isColoredBordersEnabled()) ? getMyUids() : null;
            var targetObj:Dynamic = (Api.game.world != null && Api.game.world.myAvatar != null) ? Api.game.world.myAvatar.target : null;
            sanitizeTargetHudAuras(targetObj, myUids, filterMyOnly);
        } catch (_:Dynamic) {}
    }

    private static function onPlayerPreTick(e:Event):Void {
        try {
            if (!ApiMenus.isInGame() || Api.game == null) return;
            var filterMyOnly:Bool = isMyAurasOnly();
            var myUids:Array<Dynamic> = (filterMyOnly || isColoredBordersEnabled()) ? getMyUids() : null;
            var myAvatar:Dynamic = (Api.game.world != null) ? Api.game.world.myAvatar : null;
            sanitizePlayerHudAuras(myAvatar, myUids, filterMyOnly);
        } catch (_:Dynamic) {}
    }

    private static function runTargetPostTickProcessing(nowMs:Float, cdEnabled:Bool, lagKiller:Bool, filterMyOnly:Bool, bordersEnabled:Bool, myUids:Array<Dynamic>):Void {
        try {
            if (Api.game == null) return;
            var tUI:Dynamic = Reflect.field(Api.game, "tAurasUI");
            if (tUI == null) return;

            var targetObj:Dynamic = (Api.game.world != null && Api.game.world.myAvatar != null) ? Api.game.world.myAvatar.target : null;
            if (targetObj == null) {
                tUI.visible = false;
                var tCells:Array<Dynamic> = getCells(tUI);
                for (cell in tCells) {
                    cell.visible = false;
                    cell.x = -9999;
                    cell.y = -9999;
                }
                return;
            }

            var tCells:Array<Dynamic> = getCells(tUI);
            if (tCells.length == 0) {
                tUI.visible = false;
                return;
            }

            // Always enforce Debuffs FIRST on target frame
            tCells.sort(function(a:Dynamic, b:Dynamic):Int {
                var aName:String = (a.nam != null) ? Std.string(a.nam) : "";
                var bName:String = (b.nam != null) ? Std.string(b.nam) : "";
                var aDebuff:Bool = isTargetAuraDebuff(aName, targetObj, myUids);
                var bDebuff:Bool = isTargetAuraDebuff(bName, targetObj, myUids);
                if (aDebuff != bDebuff) return aDebuff ? -1 : 1;
                var sa:Int = (a.seq != null) ? a.seq : 0;
                var sb:Int = (b.seq != null) ? b.seq : 0;
                return sa - sb;
            });

            var visibleIdx:Int = 0;
            for (cell in tCells) {
                try {
                    var auraName:String = (cell.nam != null) ? Std.string(cell.nam) : "";
                    var isDebuff:Bool = isTargetAuraDebuff(auraName, targetObj, myUids);
                    processCell(cell, nowMs, cdEnabled, lagKiller, isDebuff, bordersEnabled);

                    var showCell:Bool = true;
                    if (filterMyOnly) {
                        showCell = shouldShowTargetAura(auraName, targetObj, myUids);
                    }

                    if (!showCell) {
                        cell.visible = false;
                        cell.x = -9999;
                        cell.y = -9999;
                    } else {
                        cell.visible = true;
                        cell.x = (visibleIdx % PER_ROW) * PITCH_X;
                        cell.y = Std.int(visibleIdx / PER_ROW) * PITCH_Y;
                        visibleIdx++;
                    }
                } catch (_:Dynamic) {}
            }

            if (filterMyOnly) {
                if (visibleIdx == 0 && tUI.visible == true) {
                    tUI.visible = false;
                } else if (visibleIdx > 0 && tUI.visible == false) {
                    tUI.visible = true;
                }
            }
        } catch (_:Dynamic) {}
    }

    private static function runPlayerPostTickProcessing(nowMs:Float, cdEnabled:Bool, lagKiller:Bool, filterMyOnly:Bool, bordersEnabled:Bool, myUids:Array<Dynamic>):Void {
        try {
            if (Api.game == null) return;
            var pUI:Dynamic = Reflect.field(Api.game, "pAurasUI");
            if (pUI == null) return;

            var pCells:Array<Dynamic> = getCells(pUI);
            if (pCells.length == 0) return;

            var myAvatar:Dynamic = (Api.game.world != null) ? Api.game.world.myAvatar : null;
            var visibleIdx:Int = 0;
            for (cell in pCells) {
                try {
                    var auraName:String = (cell.nam != null) ? Std.string(cell.nam) : "";
                    var isDebuff:Bool = isPlayerAuraDebuff(auraName, myAvatar, myUids);
                    processCell(cell, nowMs, cdEnabled, lagKiller, isDebuff, bordersEnabled);

                    var showCell:Bool = true;
                    if (filterMyOnly) {
                        showCell = shouldShowPlayerAura(auraName, myAvatar, myUids);
                    }

                    if (!showCell) {
                        cell.visible = false;
                        cell.x = -9999;
                        cell.y = -9999;
                    } else {
                        cell.visible = true;
                        cell.x = (visibleIdx % PER_ROW) * PITCH_X;
                        cell.y = Std.int(visibleIdx / PER_ROW) * PITCH_Y;
                        visibleIdx++;
                    }
                } catch (_:Dynamic) {}
            }

            if (filterMyOnly) {
                if (visibleIdx == 0 && pUI.visible == true) {
                    pUI.visible = false;
                } else if (visibleIdx > 0 && pUI.visible == false) {
                    pUI.visible = true;
                }
            }
        } catch (_:Dynamic) {}
    }

    private static function onPostFrame(e:Event):Void {
        try {
            if (!ApiMenus.isInGame() || Api.game == null) return;

            var nowMs:Float = Lib.getTimer();
            var cdEnabled:Bool = isCdTimersEnabled();
            var lagKiller:Bool = isLagKillerEnabled();
            var filterMyOnly:Bool = isMyAurasOnly();
            var bordersEnabled:Bool = isColoredBordersEnabled();
            var myUids:Array<Dynamic> = (filterMyOnly || bordersEnabled) ? getMyUids() : null;

            runPlayerPostTickProcessing(nowMs, cdEnabled, lagKiller, filterMyOnly, bordersEnabled, myUids);
            runTargetPostTickProcessing(nowMs, cdEnabled, lagKiller, filterMyOnly, bordersEnabled, myUids);
        } catch (_:Dynamic) {}
    }

    private static function onTargetPostTick(e:Event):Void {
        try {
            if (!ApiMenus.isInGame() || Api.game == null) return;
            var nowMs:Float = Lib.getTimer();
            var cdEnabled:Bool = isCdTimersEnabled();
            var lagKiller:Bool = isLagKillerEnabled();
            var filterMyOnly:Bool = isMyAurasOnly();
            var bordersEnabled:Bool = isColoredBordersEnabled();
            var myUids:Array<Dynamic> = (filterMyOnly || bordersEnabled) ? getMyUids() : null;
            runTargetPostTickProcessing(nowMs, cdEnabled, lagKiller, filterMyOnly, bordersEnabled, myUids);
        } catch (_:Dynamic) {}
    }

    private static function onPlayerPostTick(e:Event):Void {
        try {
            if (!ApiMenus.isInGame() || Api.game == null) return;
            var nowMs:Float = Lib.getTimer();
            var cdEnabled:Bool = isCdTimersEnabled();
            var lagKiller:Bool = isLagKillerEnabled();
            var filterMyOnly:Bool = isMyAurasOnly();
            var bordersEnabled:Bool = isColoredBordersEnabled();
            var myUids:Array<Dynamic> = (filterMyOnly || bordersEnabled) ? getMyUids() : null;
            runPlayerPostTickProcessing(nowMs, cdEnabled, lagKiller, filterMyOnly, bordersEnabled, myUids);
        } catch (_:Dynamic) {}
    }

    /**
     * Determines whether an aura on the player should be displayed:
     * - Retains: Player's own buffs, potions, passives, and ALL debuffs on player (monster attacks, boss DoTs, etc.)
     * - Excludes: Buffs cast by external party members (LoO, SC, LR, AP buffs)
     */
    private static function shouldShowPlayerAura(auraName:String, myAvatar:Dynamic, myUids:Array<Dynamic>):Bool {
        if (auraName == "" || myAvatar == null) return true;
        try {
            var searchName:String = auraName.toLowerCase();
            var lists:Array<Dynamic> = getEntityAurasLists(myAvatar, false);

            var isPvP:Bool = false;
            try {
                if (Api.game != null && Api.game.world != null) {
                    isPvP = (Api.game.world.bPvP == true);
                }
            } catch (_:Dynamic) {}

            var foundFromOtherPlayer:Bool = false;
            var foundFromSelfOrMonster:Bool = false;

            for (arr in lists) {
                var len:Int = 0;
                try {
                    if (arr != null && untyped arr.length != null) {
                        len = Std.int(untyped arr.length);
                    }
                } catch (_:Dynamic) {}

                for (i in 0...len) {
                    var a:Dynamic = untyped arr[i];
                    if (a == null || a.nam == null) continue;
                    if (Std.string(a.nam).toLowerCase() == searchName) {
                        var ct:String = (a.casterType != null) ? Std.string(a.casterType) : "";
                        var cid:Dynamic = a.casterId;

                        var isMine:Bool = isMyId(cid, myUids) || (cid == null && ct != "p") || a.passive == true || a.potionType != null;
                        var isMonster:Bool = (ct == "m");

                        if (isMine || isMonster) {
                            foundFromSelfOrMonster = true;
                        } else if (ct == "p" && cid != null && !isMyId(cid, myUids)) {
                            if (!isPvP) {
                                foundFromOtherPlayer = true;
                            } else {
                                var isEnemy:Bool = false;
                                try {
                                    var otherLeaf:Dynamic = (Api.game.world != null && Reflect.isFunction(Api.game.world.getUoLeafById)) ? Api.game.world.getUoLeafById(cid) : null;
                                    var myLeaf:Dynamic = (Api.game.world != null && Reflect.isFunction(Api.game.world.myLeaf)) ? Api.game.world.myLeaf() : null;
                                    if (otherLeaf != null && myLeaf != null && otherLeaf.pvpTeam != null && myLeaf.pvpTeam != null) {
                                        if (otherLeaf.pvpTeam != myLeaf.pvpTeam) isEnemy = true;
                                    }
                                } catch (_:Dynamic) {}
                                if (isEnemy) {
                                    foundFromSelfOrMonster = true;
                                } else {
                                    foundFromOtherPlayer = true;
                                }
                            }
                        }
                    }
                }
            }

            if (foundFromSelfOrMonster) return true;
            if (foundFromOtherPlayer) return false;
            return true;
        } catch (_:Dynamic) {
            return true;
        }
    }

    /**
     * Determines whether an aura on the target should be displayed:
     * - Retains: Player's debuffs on target (casterId == myEntId)
     * - Retains: Monster's own buffs, passives, stances, shields, and mechanics (casterType == "m" or passive)
     * - Excludes: Other players' debuffs and buffs completely
     */
    private static function shouldShowTargetAura(auraName:String, targetObj:Dynamic, myUids:Array<Dynamic>):Bool {
        if (auraName == "" || targetObj == null) return false;
        try {
            var searchName:String = auraName.toLowerCase();

            var isMonsterTarget:Bool = false;
            var targetMonMapId:Dynamic = null;
            var targetEntId:Dynamic = null;
            try {
                if (targetObj.dataLeaf != null) {
                    if (targetObj.dataLeaf.MonMapID != null || targetObj.dataLeaf.MonID != null) {
                        isMonsterTarget = true;
                        targetMonMapId = targetObj.dataLeaf.MonMapID;
                    } else if (targetObj.dataLeaf.entID != null) {
                        targetEntId = targetObj.dataLeaf.entID;
                    } else if (targetObj.dataLeaf.EntID != null) {
                        targetEntId = targetObj.dataLeaf.EntID;
                    }
                }
                if (!isMonsterTarget && targetObj.objData != null) {
                    if (targetObj.objData.MonMapID != null || targetObj.objData.MonID != null) {
                        isMonsterTarget = true;
                        targetMonMapId = targetObj.objData.MonMapID;
                    }
                }
                if (targetEntId == null && targetObj.uid != null) {
                    targetEntId = targetObj.uid;
                }
            } catch (_:Dynamic) {}

            var lists:Array<Dynamic> = getEntityAurasLists(targetObj, isMonsterTarget);

            var foundMine:Bool = false;
            var foundTargetSelf:Bool = false;
            var foundOtherPlayer:Bool = false;

            for (arr in lists) {
                var len:Int = 0;
                try {
                    if (arr != null && untyped arr.length != null) {
                        len = Std.int(untyped arr.length);
                    }
                } catch (_:Dynamic) {}

                for (i in 0...len) {
                    var a:Dynamic = untyped arr[i];
                    if (a == null || a.nam == null) continue;
                    if (Std.string(a.nam).toLowerCase() == searchName) {
                        var ct:String = (a.casterType != null) ? Std.string(a.casterType) : "";
                        var cid:Dynamic = a.casterId;

                        var isMine:Bool = isMyId(cid, myUids);
                        var isTargetOwn:Bool = false;
                        if (isMonsterTarget) {
                            isTargetOwn = (ct == "m" || a.passive == true || (targetMonMapId != null && Std.string(cid) == Std.string(targetMonMapId)));
                        } else {
                            isTargetOwn = (cid != null && targetEntId != null && Std.string(cid) == Std.string(targetEntId)) || a.passive == true;
                        }

                        if (isMine) {
                            foundMine = true;
                        } else if (isTargetOwn) {
                            foundTargetSelf = true;
                        } else if (ct == "p" || (cid != null && !isMyId(cid, myUids))) {
                            foundOtherPlayer = true;
                        }
                    }
                }
            }

            if (foundMine) return true;
            if (foundTargetSelf) return true;
            if (foundOtherPlayer) return false;

            if (isMonsterTarget) {
                if (isKnownMonsterMechanic(searchName)) return true;
                return false;
            }

            return false;
        } catch (_:Dynamic) {
            return false;
        }
    }

    private static var BUFF_KEYWORDS:Array<String> = [
        "heal", "regen", "rejuvenat", "mend", "recovery", "restoration",
        "blessing", "shield", "absorb", "barrier", "ward", "aegis", "protect",
        "boost", "vigor", "might", "empower", "haste", "swift",
        "clarity", "focus", "grace", "radiance", "resolve", "endurance", "fortitude"
    ];

    private static function isNameMatchingBuff(nameLower:String):Bool {
        // Explicit HoT (Heal over Time) detection by name
        if (nameLower == "hot" || nameLower.indexOf(" hot") != -1 || nameLower.indexOf("hot ") != -1 ||
            nameLower.indexOf("(hot)") != -1 || nameLower.indexOf("[hot]") != -1 ||
            nameLower.indexOf("heal over time") != -1 || nameLower.indexOf("healing over time") != -1) {
            return true;
        }
        for (kw in BUFF_KEYWORDS) {
            if (nameLower.indexOf(kw) != -1) return true;
        }
        return false;
    }

    private static var DEBUFF_KEYWORDS:Array<String> = [
        "bleed", "burn", "corrupt", "decay", "poison", "toxin", "venom",
        "stun", "petrif", "paralyz", "freeze", "frostbite", "silence",
        "locked", "curse", "drain", "weaken", "vulnerab", "doom", "rot",
        "wither", "slow", "chill", "exhaust", "fatigue", "blind", "wound",
        "shackled", "dot"
    ];

    private static function isNameMatchingDebuff(nameLower:String):Bool {
        for (kw in DEBUFF_KEYWORDS) {
            if (nameLower.indexOf(kw) != -1) return true;
        }
        return false;
    }

    private static function isDescriptionDebuff(name:String):Null<Bool> {
        try {
            if (Api.game != null && Api.game.world != null && Api.game.world.auraDescs != null) {
                var desc:Dynamic = untyped Api.game.world.auraDescs[name];
                if (desc != null && desc != "") {
                    var dStr:String = Std.string(desc).toLowerCase();

                    // 1. Explicit HoT (Heal over Time) detection -> ALWAYS BUFF
                    if (dStr.indexOf("heal over time") != -1 || dStr.indexOf("healing over time") != -1 ||
                        dStr.indexOf("health over time") != -1 || dStr.indexOf("heals over time") != -1 ||
                        dStr.indexOf("heals every") != -1 || dStr.indexOf("restores health every") != -1 ||
                        dStr.indexOf("regenerates health") != -1 || dStr.indexOf("a hot") != -1 ||
                        dStr.indexOf("(hot)") != -1 || dStr.indexOf(" hot ") != -1) {
                        return false;
                    }

                    // 2. Defensive damage reduction: "damage taken reduced/decreased" -> BUFF
                    if (dStr.indexOf("damage taken") != -1 && (dStr.indexOf("decreas") != -1 || dStr.indexOf("reduc") != -1 || dStr.indexOf("less") != -1)) {
                        return false;
                    }

                    // 3. Vulnerability: "damage taken increased / takes more damage" -> DEBUFF
                    if (dStr.indexOf("damage taken") != -1 && (dStr.indexOf("increas") != -1 || dStr.indexOf("more") != -1)) {
                        return true;
                    }
                    if (dStr.indexOf("takes more damage") != -1) {
                        return true;
                    }

                    // 4. Harmful DoTs / Damage -> DEBUFF
                    if (dStr.indexOf("damage over time") != -1 || dStr.indexOf("deals damage") != -1 || dStr.indexOf("damage every") != -1) {
                        return true;
                    }

                    // 5. Crowd Control / Disables -> DEBUFF
                    if (dStr.indexOf("cannot act") != -1 || dStr.indexOf("cannot move") != -1 ||
                        dStr.indexOf("stun") != -1 || dStr.indexOf("petrif") != -1 ||
                        dStr.indexOf("silenc") != -1 || dStr.indexOf("prevent") != -1) {
                        return true;
                    }

                    // 6. Weakness / Stat reduction -> DEBUFF
                    if (dStr.indexOf("decreases") != -1 || dStr.indexOf("reduces damage dealt") != -1 || dStr.indexOf("reduces outgoing") != -1) {
                        return true;
                    }

                    // 7. Positive / Buff keywords (including heals, shields, buffs) -> BUFF
                    if (dStr.indexOf("heal") != -1 || dStr.indexOf("regen") != -1 ||
                        dStr.indexOf("rejuvenat") != -1 || dStr.indexOf("mend") != -1 ||
                        dStr.indexOf("increases") != -1 || dStr.indexOf("restores") != -1 ||
                        dStr.indexOf("boosts") != -1 || dStr.indexOf("grants") != -1 ||
                        dStr.indexOf("absorbs") != -1 || dStr.indexOf("protects") != -1 ||
                        dStr.indexOf("damage reduced") != -1) {
                        return false;
                    }
                }
            }
        } catch (_:Dynamic) {}
        return null;
    }

    private static function isTargetAuraDebuff(auraName:String, targetObj:Dynamic, myUids:Array<Dynamic>):Bool {
        if (auraName == "" || targetObj == null) return false;
        try {
            var searchName:String = auraName.toLowerCase();

            // Known monster mechanics (Reflect, Counter Attack, Focus, etc.) are buffs
            if (isKnownMonsterMechanic(searchName)) return false;

            // Explicit HoT or Buff name detection -> Buff
            if (isNameMatchingBuff(searchName)) return false;

            var isMonsterTarget:Bool = false;
            var targetMonMapId:Dynamic = null;
            try {
                if (targetObj.dataLeaf != null && (targetObj.dataLeaf.MonMapID != null || targetObj.dataLeaf.MonID != null)) {
                    isMonsterTarget = true;
                    targetMonMapId = targetObj.dataLeaf.MonMapID;
                } else if (targetObj.objData != null && (targetObj.objData.MonMapID != null || targetObj.objData.MonID != null)) {
                    isMonsterTarget = true;
                    targetMonMapId = targetObj.objData.MonMapID;
                }
            } catch (_:Dynamic) {}

            var lists:Array<Dynamic> = getEntityAurasLists(targetObj, isMonsterTarget);
            for (arr in lists) {
                var len:Int = 0;
                try {
                    if (arr != null && untyped arr.length != null) len = Std.int(untyped arr.length);
                } catch (_:Dynamic) {}

                for (i in 0...len) {
                    var a:Dynamic = untyped arr[i];
                    if (a == null || a.nam == null) continue;
                    if (Std.string(a.nam).toLowerCase() == searchName) {
                        // Check server aura category (HoT and heals are explicitly Buffs)
                        if (a.cat != null) {
                            var catStr:String = Std.string(a.cat).toLowerCase();
                            if (catStr.indexOf("buff") != -1 || catStr.indexOf("hot") != -1 ||
                                catStr.indexOf("heal") != -1 || catStr.indexOf("shield") != -1 ||
                                catStr.indexOf("passive") != -1) {
                                return false; // HoT is a BUFF -> Blue border
                            }
                            if (catStr.indexOf("debuff") != -1 || catStr.indexOf("dot") != -1 ||
                                catStr.indexOf("stun") != -1 || catStr.indexOf("stone") != -1 ||
                                catStr.indexOf("paralyze") != -1 || catStr.indexOf("disable") != -1 ||
                                catStr.indexOf("curse") != -1 || catStr.indexOf("bleed") != -1 ||
                                catStr.indexOf("poison") != -1) {
                                return true; // DoT is a DEBUFF -> Red border
                            }
                        }

                        var ct:String = (a.casterType != null) ? Std.string(a.casterType) : "";
                        var cid:Dynamic = a.casterId;
                        if (isMonsterTarget) {
                            if (ct == "p" || isMyId(cid, myUids)) {
                                return true; // Player casts on monster -> Debuff
                            }
                            if (ct == "m" || a.passive == true || (targetMonMapId != null && Std.string(cid) == Std.string(targetMonMapId))) {
                                return false; // Monster self-cast -> Buff
                            }
                        }
                    }
                }
            }

            var descDebuff = isDescriptionDebuff(auraName);
            if (descDebuff != null) return descDebuff;

            if (isNameMatchingDebuff(searchName)) return true;

            if (isMonsterTarget) return true;
        } catch (_:Dynamic) {}
        return false;
    }

    private static function isPlayerAuraDebuff(auraName:String, myAvatar:Dynamic, myUids:Array<Dynamic>):Bool {
        if (auraName == "" || myAvatar == null) return false;
        try {
            var searchName:String = auraName.toLowerCase();

            // Explicit HoT or Buff name detection -> Buff
            if (isNameMatchingBuff(searchName)) return false;

            var lists:Array<Dynamic> = getEntityAurasLists(myAvatar, false);
            for (arr in lists) {
                var len:Int = 0;
                try {
                    if (arr != null && untyped arr.length != null) len = Std.int(untyped arr.length);
                } catch (_:Dynamic) {}

                for (i in 0...len) {
                    var a:Dynamic = untyped arr[i];
                    if (a == null || a.nam == null) continue;
                    if (Std.string(a.nam).toLowerCase() == searchName) {
                        // Check server aura category (HoT and heals are explicitly Buffs)
                        if (a.cat != null) {
                            var catStr:String = Std.string(a.cat).toLowerCase();
                            if (catStr.indexOf("buff") != -1 || catStr.indexOf("hot") != -1 ||
                                catStr.indexOf("heal") != -1 || catStr.indexOf("shield") != -1 ||
                                catStr.indexOf("passive") != -1) {
                                return false; // HoT is a BUFF -> Blue border
                            }
                            if (catStr.indexOf("debuff") != -1 || catStr.indexOf("dot") != -1 ||
                                catStr.indexOf("stun") != -1 || catStr.indexOf("stone") != -1 ||
                                catStr.indexOf("paralyze") != -1 || catStr.indexOf("disable") != -1 ||
                                catStr.indexOf("curse") != -1 || catStr.indexOf("bleed") != -1 ||
                                catStr.indexOf("poison") != -1) {
                                return true; // DoT is a DEBUFF -> Red border
                            }
                        }

                        var ct:String = (a.casterType != null) ? Std.string(a.casterType) : "";
                        if (ct == "m") return true; // Monster attack on player -> Debuff
                        if (a.potionType != null || a.passive == true) return false; // Potion/passive -> Buff
                    }
                }
            }

            var descDebuff = isDescriptionDebuff(auraName);
            if (descDebuff != null) return descDebuff;

            if (isNameMatchingDebuff(searchName)) return true;
        } catch (_:Dynamic) {}
        return false;
    }
}
#else
class AuraFramesManager {
    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {}
    public static inline function resetPositions():Void {}
    public static inline function isCdTimersEnabled():Bool return false;
    public static inline function setCdTimersEnabled(v:Bool):Void {}
    public static inline function isMyAurasOnly():Bool return false;
    public static inline function setMyAurasOnly(v:Bool):Void {}
    public static inline function isLagKillerEnabled():Bool return false;
    public static inline function setLagKillerEnabled(v:Bool):Void {}
    public static inline function isColoredBordersEnabled():Bool return false;
    public static inline function setColoredBordersEnabled(v:Bool):Void {}
}
#end
