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

    public static inline function isCdTimersEnabled():Bool {
        return ApiConfig.getBool("api_auras_cd_timers", false);
    }

    public static function setCdTimersEnabled(v:Bool):Void {
        ApiConfig.setBool("api_auras_cd_timers", v);
    }

    public static inline function isMyAurasOnly():Bool {
        return ApiConfig.getBool("api_auras_my_only", false);
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

    private static function onEnterFrame(e:Event):Void {
        if (!ApiMenus.isInGame() || Api.game == null) return;

        var nowMs:Float = Lib.getTimer();
        var cdEnabled:Bool = isCdTimersEnabled();
        var lagKiller:Bool = isLagKillerEnabled();
        var filterMyOnly:Bool = isMyAurasOnly();

        // 1. Process Player Auras (pAurasUI)
        var pUI:Dynamic = Reflect.field(Api.game, "pAurasUI");
        if (pUI != null && pUI.visible != false) {
            var pCells:Array<Dynamic> = getCells(pUI);
            for (cell in pCells) {
                processCell(cell, nowMs, cdEnabled, lagKiller);
            }
        }

        // 2. Process Target Auras (tAurasUI) with Filtering
        var tUI:Dynamic = Reflect.field(Api.game, "tAurasUI");
        if (tUI != null) {
            var tCells:Array<Dynamic> = getCells(tUI);
            var targetObj:Dynamic = (Api.game.world != null && Api.game.world.myAvatar != null) ? Api.game.world.myAvatar.target : null;
            var myEntId:Dynamic = (Api.game.world != null && Api.game.world.myAvatar != null && Api.game.world.myAvatar.dataLeaf != null) ? Api.game.world.myAvatar.dataLeaf.entID : null;

            var visibleIdx:Int = 0;
            for (cell in tCells) {
                processCell(cell, nowMs, cdEnabled, lagKiller);

                var auraName:String = (cell.nam != null) ? Std.string(cell.nam) : "";
                var isOtherPlayer:Bool = filterMyOnly && isAuraFromOtherPlayer(auraName, targetObj, myEntId);

                if (isOtherPlayer) {
                    cell.visible = false;
                } else {
                    cell.visible = true;
                    if (filterMyOnly) {
                        cell.x = (visibleIdx % PER_ROW) * PITCH_X;
                        cell.y = Std.int(visibleIdx / PER_ROW) * PITCH_Y;
                    }
                    visibleIdx++;
                }
            }

            // Hide the entire frame if all target debuffs belong to other players
            if (filterMyOnly && visibleIdx == 0 && tUI.visible == true) {
                tUI.visible = false;
            }
        }
    }

    /**
     * Optimizes a single AuraCell:
     * - Suppresses laggy ActMaskReverse dynamic stencil masks and BitmapData.draw
     *   by neutralizing them in the child display hierarchy (avoiding private member access)
     * - Manages centered numeric cooldown countdown text field
     */
    private static function processCell(cell:Dynamic, nowMs:Float, cdEnabled:Bool, lagKiller:Bool):Void {
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

        // B. Cooldown Timer Text
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
            cdTxt.filters = ApiStyle.getTextOutlineFilter();
            cdTxt.width = 26;
            cdTxt.height = 14;
            cdTxt.x = 0;
            cdTxt.y = 4;
            try {
                cell.addChild(cdTxt);
            } catch (_:Dynamic) {}
        }

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

    /**
     * Determines whether an aura on the target was applied exclusively by an external player.
     * Retains:
     * - Auras applied by the player (casterId == myEntId)
     * - The target's own self-auras, shields, passives, and boss mechanics (casterType == "m" or passive)
     */
    private static function isAuraFromOtherPlayer(auraName:String, targetObj:Dynamic, myEntId:Dynamic):Bool {
        if (targetObj == null || targetObj.dataLeaf == null || myEntId == null) return false;
        var leaf:Dynamic = targetObj.dataLeaf;
        var aurasList:Dynamic = leaf.auras;
        if (aurasList == null) return false;

        var targetEntId:Dynamic = leaf.entID;
        var foundOtherPlayer:Bool = false;
        var foundMineOrTarget:Bool = false;

        var len:Int = (Reflect.hasField(aurasList, "length")) ? Std.int(aurasList.length) : 0;
        for (i in 0...len) {
            var a:Dynamic = aurasList[i];
            if (a == null || a.nam == null) continue;
            if (Std.string(a.nam).toLowerCase() == auraName.toLowerCase()) {
                var ct:String = (a.casterType != null) ? Std.string(a.casterType) : "";
                var cid:Dynamic = a.casterId;
                if (ct == "m" || a.passive == true || cid == myEntId || (targetEntId != null && cid == targetEntId)) {
                    foundMineOrTarget = true;
                } else if (ct == "p" && cid != null && cid != myEntId) {
                    foundOtherPlayer = true;
                }
            }
        }

        if (foundMineOrTarget) return false; // Definitely keep
        return foundOtherPlayer; // Hide if only cast by an external third-party player
    }
}
#else
class AuraFramesManager {
    public static function init(pocket:Dynamic = null, overlay:Dynamic = null):Void {}
    public static inline function isCdTimersEnabled():Bool return false;
    public static inline function setCdTimersEnabled(v:Bool):Void {}
    public static inline function isMyAurasOnly():Bool return false;
    public static inline function setMyAurasOnly(v:Bool):Void {}
    public static inline function isLagKillerEnabled():Bool return false;
    public static inline function setLagKillerEnabled(v:Bool):Void {}
}
#end
