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
        return ApiConfig.getBool("api_auras_lag_killer", false);
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
        "inner fire"
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
                    if (Api.game.sfc != null && Api.game.sfc.myUserName != null && w.uoTree != null) {
                        var unm:String = Std.string(Api.game.sfc.myUserName).toLowerCase();
                        var ml:Dynamic = untyped w.uoTree[unm];
                        if (ml != null && ml.entID != null) uids.push(ml.entID);
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
        if (lagKiller && cell.numChildren != null && cell.numChildren > 0) {
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
                g.lineStyle(1.8, borderColor, 0.95, true);
                g.drawRoundRect(0.5, 0.5, 24.5, 22.5, 3.0, 3.0);

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
            cdTxt.width = 26;
            cdTxt.height = 14;
            cdTxt.x = 0;
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
                } else if (remSec >= 1.0) {
                    str = Math.ceil(remSec) + "s";
                } else {
                    str = (Math.round(remSec * 10) / 10.0) + "s";
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

    private static function onEnterFrame(e:Event):Void {
        try {
            if (!ApiMenus.isInGame() || Api.game == null) return;

            var nowMs:Float = Lib.getTimer();
            // Throttle to ~20Hz (50ms interval) matching native 100ms AuraHUD tick
            if (nowMs - _lastTick < 50.0) return;
            _lastTick = nowMs;

            var cdEnabled:Bool = isCdTimersEnabled();
            var lagKiller:Bool = isLagKillerEnabled();
            var filterMyOnly:Bool = isMyAurasOnly();
            var bordersEnabled:Bool = isColoredBordersEnabled();
            var myUids:Array<Dynamic> = (filterMyOnly || bordersEnabled) ? getMyUids() : null;

            // 1. Process Player Auras (pAurasUI)
            try {
                var pUI:Dynamic = Reflect.field(Api.game, "pAurasUI");
                if (pUI != null) {
                    var pCells:Array<Dynamic> = getCells(pUI);
                    if (pCells.length > 0) {
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
                                } else {
                                    cell.visible = true;
                                    if (filterMyOnly) {
                                        cell.x = (visibleIdx % PER_ROW) * PITCH_X;
                                        cell.y = Std.int(visibleIdx / PER_ROW) * PITCH_Y;
                                    }
                                    visibleIdx++;
                                }
                            } catch (_:Dynamic) {}
                        }

                        if (filterMyOnly && visibleIdx == 0 && pUI.visible == true) {
                            pUI.visible = false;
                        }
                    }
                }
            } catch (_:Dynamic) {}

            // 2. Process Target Auras (tAurasUI) with Filtering
            try {
                var tUI:Dynamic = Reflect.field(Api.game, "tAurasUI");
                if (tUI != null) {
                    var tCells:Array<Dynamic> = getCells(tUI);
                    if (tCells.length > 0) {
                        var targetObj:Dynamic = (Api.game.world != null && Api.game.world.myAvatar != null) ? Api.game.world.myAvatar.target : null;
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
                                } else {
                                    cell.visible = true;
                                    if (filterMyOnly) {
                                        cell.x = (visibleIdx % PER_ROW) * PITCH_X;
                                        cell.y = Std.int(visibleIdx / PER_ROW) * PITCH_Y;
                                    }
                                    visibleIdx++;
                                }
                            } catch (_:Dynamic) {}
                        }

                        // Hide the entire frame if all target debuffs belong to other players
                        if (filterMyOnly && visibleIdx == 0 && tUI.visible == true) {
                            tUI.visible = false;
                        }
                    }
                }
            } catch (_:Dynamic) {}
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
        if (auraName == "" || targetObj == null) return true;
        try {
            var searchName:String = auraName.toLowerCase();

            var isMonsterTarget:Bool = false;
            var targetMonMapId:Dynamic = null;
            try {
                if (targetObj.dataLeaf != null) {
                    if (targetObj.dataLeaf.MonMapID != null || targetObj.dataLeaf.MonID != null) {
                        isMonsterTarget = true;
                        targetMonMapId = targetObj.dataLeaf.MonMapID;
                    }
                }
                if (!isMonsterTarget && targetObj.objData != null) {
                    if (targetObj.objData.MonMapID != null || targetObj.objData.MonID != null) {
                        isMonsterTarget = true;
                        targetMonMapId = targetObj.objData.MonMapID;
                    }
                }
            } catch (_:Dynamic) {}

            var lists:Array<Dynamic> = getEntityAurasLists(targetObj, isMonsterTarget);

            var foundMine:Bool = false;
            var foundMonsterBuff:Bool = false;
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
                        var isMonster:Bool = (ct == "m" || a.passive == true || (targetMonMapId != null && Std.string(cid) == Std.string(targetMonMapId)));

                        if (isMine) {
                            foundMine = true;
                        } else if (isMonster && isMonsterTarget) {
                            foundMonsterBuff = true;
                        } else if (ct == "p" || (cid != null && !isMyId(cid, myUids))) {
                            foundOtherPlayer = true;
                        }
                    }
                }
            }

            if (foundMine) return true;
            if (isMonsterTarget && foundMonsterBuff) return true;
            if (foundOtherPlayer) return false;

            if (isMonsterTarget) {
                if (isKnownMonsterMechanic(searchName)) return true;
                return false;
            }

            return false;
        } catch (_:Dynamic) {
            return true;
        }
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
                    if (dStr.indexOf("damage over time") != -1 || dStr.indexOf("deals damage") != -1 ||
                        dStr.indexOf("decreases") != -1 || dStr.indexOf("reduces") != -1 ||
                        dStr.indexOf("cannot") != -1 || dStr.indexOf("prevent") != -1 ||
                        dStr.indexOf("takes more damage") != -1 || dStr.indexOf("damage taken increased") != -1) {
                        return true;
                    }
                    if (dStr.indexOf("increases") != -1 || dStr.indexOf("heals") != -1 ||
                        dStr.indexOf("restores") != -1 || dStr.indexOf("boosts") != -1 ||
                        dStr.indexOf("grants") != -1 || dStr.indexOf("absorbs") != -1 ||
                        dStr.indexOf("protects") != -1 || dStr.indexOf("damage reduced") != -1) {
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

            if (isKnownMonsterMechanic(searchName)) return false;

            var isMonsterTarget:Bool = false;
            try {
                if (targetObj.dataLeaf != null && (targetObj.dataLeaf.MonMapID != null || targetObj.dataLeaf.MonID != null)) {
                    isMonsterTarget = true;
                } else if (targetObj.objData != null && (targetObj.objData.MonMapID != null || targetObj.objData.MonID != null)) {
                    isMonsterTarget = true;
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
                        var ct:String = (a.casterType != null) ? Std.string(a.casterType) : "";
                        var cid:Dynamic = a.casterId;
                        if (isMonsterTarget && (ct == "p" || isMyId(cid, myUids))) {
                            return true;
                        }
                        if (isMonsterTarget && (ct == "m" || a.passive == true)) {
                            return false;
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

            var descDebuff = isDescriptionDebuff(auraName);
            if (descDebuff != null) return descDebuff;

            if (isNameMatchingDebuff(searchName)) return true;

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
                        var ct:String = (a.casterType != null) ? Std.string(a.casterType) : "";
                        if (ct == "m") return true;
                    }
                }
            }
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
