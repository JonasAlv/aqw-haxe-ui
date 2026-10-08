package ui;

#if flash
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.Event;
import flash.filters.GlowFilter;
import flash.geom.Point;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiLogger;
import ui.ApiDashboardModal;
import ui.ApiStyle;
import ui.Overlay;
import com.aqwapi.utils.ApiConfig;

/**
 * Lightweight, pooled particle for floating combat text numbers.
 */
class DamageParticle extends Sprite {
    public var tf:TextField;
    public var vx:Float = 0;
    public var vy:Float = 0;
    public var life:Float = 0;
    public var maxLife:Float = 0.85;
    public var isCrit:Bool = false;
    public var inUse:Bool = false;
    public var baseScale:Float = 1.0;

    public function new() {
        super();
        mouseEnabled = false;
        mouseChildren = false;
        visible = false;

        tf = new TextField();
        tf.autoSize = TextFieldAutoSize.CENTER;
        tf.selectable = false;
        tf.mouseEnabled = false;
        addChild(tf);
    }

    public function spawn(text:String, color:Int, fontSize:Int, isCritical:Bool, startX:Float, startY:Float, isDot:Bool) {
        isCrit = isCritical;
        inUse = true;
        life = 0;
        maxLife = isCrit ? 0.95 : (isDot ? 0.70 : 0.80);

        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, fontSize, color, true);
        fmt.align = TextFormatAlign.CENTER;
        tf.defaultTextFormat = fmt;
        tf.text = text;

        // Dark outline glow for high contrast against spell effects
        var glow = new GlowFilter(0x000000, 0.95, isCrit ? 4 : 3, isCrit ? 4 : 3, isCrit ? 4 : 3, 1);
        tf.filters = [glow];

        tf.x = -tf.width * 0.5;
        tf.y = -tf.height * 0.5;

        x = startX;
        y = startY;
        alpha = 1.0;

        if (isCrit) {
            baseScale = 1.35;
            scaleX = baseScale;
            scaleY = baseScale;
            vx = (Math.random() - 0.5) * 1.0;
            vy = -4.5;
        } else if (isDot) {
            baseScale = 0.9;
            scaleX = baseScale;
            scaleY = baseScale;
            vx = (Math.random() > 0.5 ? 1 : -1) * (1.0 + Math.random() * 1.2);
            vy = -2.2;
        } else {
            baseScale = 1.0;
            scaleX = baseScale;
            scaleY = baseScale;
            vx = (Math.random() - 0.5) * 0.8;
            vy = -3.2;
        }

        visible = true;
    }

    public function step(dt:Float):Bool {
        life += dt;
        if (life >= maxLife) {
            inUse = false;
            visible = false;
            return false;
        }

        x += vx;
        y += vy;

        if (isCrit) {
            vy *= 0.88;
            if (scaleX > 1.05) {
                scaleX -= dt * 1.6;
                if (scaleX < 1.05) scaleX = 1.05;
                scaleY = scaleX;
            }
        } else {
            vy *= 0.90;
        }

        // Fade out in last 35% of life
        var fadeStart = maxLife * 0.65;
        if (life > fadeStart) {
            alpha = (maxLife - life) / (maxLife - fadeStart);
        }

        return true;
    }
}

/**
 * Modern High-Performance Floating Combat Text (Damage Numbers).
 *
 * Features:
 * - Rendered directly at the chest/center of units (not above head nametags).
 * - Zero latency: listens directly to SmartFox extension packets (bypasses 250ms native cap).
 * - High-FPS object pool (no Flash timeline symbols, zero GC churn, zero lag).
 * - Automatically disables clunky native MovieClips (bDisDmgDisplay = true) when active.
 * - Distinct styling for hits, crits, heals, DoTs, and avoidance (Miss/Dodge/Parry).
 * - Configurable filtering: Self & Target, Self Only, All.
 */
class DamageNumbers {
    private static var _pocket:Dynamic = null;
    private static var _overlay:Overlay = null;
    private static var _container:Sprite = null;
    private static var _hookedSfc:Dynamic = null;
    private static var _initialized:Bool = false;

    // Object pool
    private static inline var POOL_SIZE:Int = 50;
    private static var _pool:Array<DamageParticle> = [];
    private static var _lastFrameTime:Int = 0;

    // Colors
    private static inline var COLOR_HIT:Int       = 0xFFFFFF; // Crisp white
    private static inline var COLOR_CRIT:Int      = 0xFFB020; // Radiant amber / gold
    private static inline var COLOR_HEAL:Int      = 0x34D399; // Emerald / mint green
    private static inline var COLOR_DOT:Int       = 0xC084FC; // Soft violet / purple
    private static inline var COLOR_DODGE:Int     = 0x38BDF8; // Sky cyan
    private static inline var COLOR_MISS:Int      = 0x94A3B8; // Slate grey
    private static inline var COLOR_INCOMING:Int  = 0xEF4444; // Danger red (damage taken)

    public static function init(pocket:Dynamic, overlay:Overlay):Void {
        if (_initialized) return;
        _initialized = true;
        _pocket = pocket;
        _overlay = overlay;

        var theStage:Dynamic = (_pocket != null && _pocket.stage != null) ? _pocket.stage : (_overlay != null ? _overlay.stage : null);

        var attach = function(stageObj:Dynamic):Void {
            if (stageObj == null || _container != null) return;
            buildContainer(stageObj);
        };

        if (theStage != null) {
            attach(theStage);
        } else if (_overlay != null) {
            _overlay.addEventListener(Event.ADDED_TO_STAGE, function(ev:Event):Void {
                if (_overlay.stage != null && _container == null) {
                    attach(_overlay.stage);
                }
            });
        }
    }

    private static function buildContainer(theStage:Dynamic):Void {
        _container = new Sprite();
        _container.name = "CustomDamageNumbersLayer";
        _container.mouseEnabled = false;
        _container.mouseChildren = false;

        // Populate object pool
        for (i in 0...POOL_SIZE) {
            var p = new DamageParticle();
            _pool.push(p);
            _container.addChild(p);
        }

        theStage.addChild(_container);

        // Frame ticker for smooth 60fps particle updates
        _lastFrameTime = ApiTime.getTimer();
        theStage.addEventListener(Event.ENTER_FRAME, onEnterFrame);

        // Hook socket packets
        ensureSocketHook();
    }

    private static function onEnterFrame(e:Event):Void {
        var now = ApiTime.getTimer();
        var dt:Float = (now - _lastFrameTime) / 1000.0;
        _lastFrameTime = now;
        if (dt > 0.1) dt = 0.1; // clamp lag spike

        if (_container == null) return;

        // Ensure socket hook is active
        ensureSocketHook();

        var inGame:Bool = (Api.isReady && !ApiDashboardModal.isOpen());
        var enabled:Bool = isEnabled();

        _container.visible = (inGame && enabled);
        if (!inGame || !enabled) return;

        // Sync native display suppression
        syncNativeDisplay();

        // Update active particles
        for (i in 0..._pool.length) {
            var p = _pool[i];
            if (p.inUse) {
                p.step(dt);
            }
        }
    }

    private static function ensureSocketHook():Void {
        try {
            var sfc:Dynamic = (Api.game != null) ? Api.game.sfc : null;
            if (sfc == null) {
                _hookedSfc = null;
                return;
            }
            if (_hookedSfc == sfc) return;
            _hookedSfc = sfc;
            sfc.addEventListener("onExtensionResponse", handlePacket, false, 100, false);
            ApiLogger.debug("DamageNumbers", "Hooked sfc onExtensionResponse (priority 100).");
        } catch (_:Dynamic) {}
    }

    private static function syncNativeDisplay():Void {
        try {
            if (Api.game != null && Api.game.litePreference != null && Api.game.litePreference.data != null) {
                // Suppress native 250ms capped movieclips when our module is active
                Api.game.litePreference.data.bDisDmgDisplay = true;
            }
        } catch (_:Dynamic) {}
    }

    // -------------------------------------------------------------------------
    // Packet Handling (Direct Server Action Stream)
    // -------------------------------------------------------------------------

    private static function handlePacket(e:Dynamic):Void {
        if (!isEnabled() || !Api.isReady) return;
        try {
            if (e == null || e.params == null || e.params.dataObj == null) return;
            var d:Dynamic = e.params.dataObj;
            var cmd:String = null;
            if (d.cmd != null) cmd = Std.string(d.cmd);
            else if (d[0] != null) cmd = Std.string(d[0]);
            if (cmd == null) return;

            if (cmd == "sar") {
                processSingleResult(d.actionResult);
            } else if (cmd == "sars") {
                processMultiResult(d);
            } else if (cmd == "ct") {
                if (d.sara != null) {
                    var sara:Array<Dynamic> = cast d.sara;
                    for (s in sara) {
                        if (s != null && s.actionResult != null) processSingleResult(s.actionResult);
                    }
                }
                if (d.sarsa != null) {
                    var sarsa:Array<Dynamic> = cast d.sarsa;
                    for (s in sarsa) {
                        if (s != null) processMultiResult(s);
                    }
                }
            } else if (cmd == "showAuraResult") {
                processDotResult(d);
            }
        } catch (_:Dynamic) {}
    }

    private static function processSingleResult(r:Dynamic):Void {
        if (r == null) return;
        if (r.iRes != null && Std.int(r.iRes) != 1) return;
        var cInf:String = (r.cInf != null) ? Std.string(r.cInf) : "";
        var tInf:String = (r.tInf != null) ? Std.string(r.tInf) : "";
        var hp:Int = (r.hp != null) ? Std.int(r.hp) : 0;
        var type:String = (r.type != null) ? Std.string(r.type) : "hit";
        var isDot:Bool = (r.typ != null && Std.string(r.typ) == "d");

        spawnCombatNumber(cInf, tInf, hp, type, isDot);
    }

    private static function processMultiResult(m:Dynamic):Void {
        if (m == null) return;
        if (m.iRes != null && Std.int(m.iRes) != 1) return;
        var cInf:String = (m.cInf != null) ? Std.string(m.cInf) : "";
        if (m.a != null) {
            var hits:Array<Dynamic> = cast m.a;
            for (hit in hits) {
                if (hit == null) continue;
                var tInf:String = (hit.tInf != null) ? Std.string(hit.tInf) : "";
                var hp:Int = (hit.hp != null) ? Std.int(hit.hp) : 0;
                var type:String = (hit.type != null) ? Std.string(hit.type) : "hit";
                spawnCombatNumber(cInf, tInf, hp, type, false);
            }
        }
    }

    private static function processDotResult(d:Dynamic):Void {
        if (d == null) return;
        var tInf:String = (d.tInf != null) ? Std.string(d.tInf) : "";
        var hp:Int = (d.hp != null) ? Std.int(d.hp) : 0;
        spawnCombatNumber("", tInf, hp, "dot", true);
    }

    // -------------------------------------------------------------------------
    // Combat Number Generation & Center Positioning
    // -------------------------------------------------------------------------

    private static function spawnCombatNumber(cInf:String, tInf:String, hp:Int, type:String, isDot:Bool):Void {
        if (tInf == "" || _container == null) return;

        // Avoid DoT if disabled
        if (isDot && !isShowDots()) return;

        // Identify attacker and target roles
        var myUid:Dynamic = (Api.game != null && Api.game.sfc != null) ? Api.game.sfc.myUserId : null;
        var myTag:String = (myUid != null) ? ("p:" + myUid) : "";

        var isMyAttack:Bool = (cInf != "" && cInf == myTag);
        var isTargetingMe:Bool = (tInf != "" && tInf == myTag);

        var isCurrentTarget:Bool = false;
        try {
            var targetEnt:Dynamic = (Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null) ? Api.game.world.myAvatar.target : null;
            if (targetEnt != null && targetEnt.objData != null) {
                if (tInf.indexOf("m:") == 0 && targetEnt.objData.MonMapID != null) {
                    isCurrentTarget = (tInf == ("m:" + targetEnt.objData.MonMapID));
                } else if (tInf.indexOf("p:") == 0 && targetEnt.objData.EntID != null) {
                    isCurrentTarget = (tInf == ("p:" + targetEnt.objData.EntID));
                }
            }
        } catch (_:Dynamic) {}

        // Filter evaluation
        // 0 = Self & Target, 1 = Self Only, 2 = Target Only, 3 = All
        var mode:Int = getFilterMode();
        var passesFilter:Bool = false;

        switch (mode) {
            case 0: passesFilter = isMyAttack || isCurrentTarget || (isTargetingMe && isShowIncoming());
            case 1: passesFilter = isMyAttack || (isTargetingMe && isShowIncoming());
            case 2: passesFilter = isCurrentTarget;
            case 3: passesFilter = true;
        }

        if (!passesFilter) return;

        // Skip heals if disabled
        var isHeal:Bool = (hp < 0);
        if (isHeal && !isShowHeals()) return;

        // Locate target character MovieClip
        var targetMC:Dynamic = getTargetMC(tInf);
        if (targetMC == null || targetMC.stage == null) return;

        // =====================================================================
        // CENTER OF UNIT COORDINATE CALCULATION
        // Places damage numbers right at the chest / torso center of the character
        // instead of above nametags.
        // =====================================================================
        var localCenterX:Float = 0;
        var localCenterY:Float = -50;
        try {
            if (targetMC.mcChar != null) localCenterX = targetMC.mcChar.x;
            if (targetMC.pname != null && targetMC.pname.y != 0) {
                localCenterY = targetMC.pname.y * 0.55; // 50-55% height from ground to nametag
            }
        } catch (_:Dynamic) {}

        var globalCenter:Point = null;
        try {
            globalCenter = targetMC.localToGlobal(new Point(localCenterX, localCenterY));
        } catch (_:Dynamic) {
            return;
        }
        if (globalCenter == null) return;

        var screenCenter:Point = _container.globalToLocal(globalCenter);

        // Add subtle random jitter (+/- 12px X, +/- 8px Y) to prevent identical overlaps
        var spawnX:Float = screenCenter.x + (Math.random() - 0.5) * 24;
        var spawnY:Float = screenCenter.y + (Math.random() - 0.5) * 16;

        // Determine formatting, text, color, and size
        var isCrit:Bool = (type == "crit");
        var textStr:String = "";
        var textColor:Int = COLOR_HIT;
        var fontSize:Int = 14;

        if (isHeal) {
            var healAmount:Int = -hp;
            textStr = "+" + formatNumber(healAmount);
            textColor = COLOR_HEAL;
            fontSize = isCrit ? 16 : 13;
        } else if (type == "hit") {
            textStr = formatNumber(hp);
            textColor = isTargetingMe ? COLOR_INCOMING : COLOR_HIT;
            fontSize = 13;
        } else if (type == "crit") {
            textStr = formatNumber(hp);
            textColor = isTargetingMe ? COLOR_INCOMING : COLOR_CRIT;
            fontSize = 18;
        } else if (type == "miss") {
            textStr = "Miss";
            textColor = COLOR_MISS;
            fontSize = 12;
        } else if (type == "dodge") {
            textStr = "Dodge";
            textColor = COLOR_DODGE;
            fontSize = 12;
        } else if (type == "parry") {
            textStr = "Parry";
            textColor = COLOR_CRIT;
            fontSize = 12;
        } else if (type == "block") {
            textStr = "Block";
            textColor = COLOR_DODGE;
            fontSize = 12;
        } else if (isDot) {
            textStr = formatNumber(hp);
            textColor = isTargetingMe ? COLOR_INCOMING : COLOR_DOT;
            fontSize = 12;
        } else {
            textStr = formatNumber(hp);
            textColor = COLOR_HIT;
            fontSize = 13;
        }

        // Acquire particle from pool
        var p = acquireParticle();
        if (p != null) {
            p.spawn(textStr, textColor, fontSize, isCrit, spawnX, spawnY, isDot);
        }
    }

    private static function acquireParticle():DamageParticle {
        for (i in 0..._pool.length) {
            if (!_pool[i].inUse) {
                return _pool[i];
            }
        }
        // Pool saturated: recycle oldest particle
        var recycled = _pool.shift();
        _pool.push(recycled);
        return recycled;
    }

    private static function getTargetMC(tInf:String):Dynamic {
        try {
            var world:Dynamic = (Api.game != null) ? Api.game.world : null;
            if (world == null) return null;

            if (tInf.indexOf("m:") == 0) {
                var monId:Int = Std.parseInt(tInf.substr(2));
                if (Reflect.hasField(world, "getMonster")) {
                    var mon:Dynamic = world.getMonster(monId);
                    if (mon != null && mon.pMC != null) return mon.pMC;
                }
                if (world.monsters != null) {
                    var mon:Dynamic = Reflect.field(world.monsters, Std.string(monId));
                    if (mon != null && mon.pMC != null) return mon.pMC;
                }
            } else if (tInf.indexOf("p:") == 0) {
                var uid:Int = Std.parseInt(tInf.substr(2));
                if (world.myAvatar != null && world.myAvatar.dataLeaf != null && world.myAvatar.dataLeaf.EntID == uid) {
                    return world.myAvatar.pMC;
                }
                if (Reflect.hasField(world, "getAvatarByUserID")) {
                    var avt:Dynamic = world.getAvatarByUserID(uid);
                    if (avt != null && avt.pMC != null) return avt.pMC;
                }
                if (world.avatars != null) {
                    var avt:Dynamic = Reflect.field(world.avatars, Std.string(uid));
                    if (avt != null && avt.pMC != null) return avt.pMC;
                }
            }
        } catch (_:Dynamic) {}
        return null;
    }

    private static function formatNumber(val:Int):String {
        if (isCompactFormat()) {
            if (val >= 1000000) {
                var m = Math.round(val / 100000) / 10.0;
                return m + "M";
            } else if (val >= 10000) {
                var k = Math.round(val / 100) / 10.0;
                return k + "K";
            }
        }

        // Comma formatting (e.g. 1,234,567)
        var s:String = Std.string(val);
        var len:Int = s.length;
        if (len <= 3) return s;

        var res:String = "";
        var count:Int = 0;
        var i:Int = len - 1;
        while (i >= 0) {
            res = s.charAt(i) + res;
            count++;
            if (count % 3 == 0 && i > 0) {
                res = "," + res;
            }
            i--;
        }
        return res;
    }

    // -------------------------------------------------------------------------
    // Settings Getters & Setters
    // -------------------------------------------------------------------------

    public static inline function isEnabled():Bool {
        return ApiConfig.getBool("api_fct_enabled", true);
    }

    public static function setEnabled(v:Bool):Void {
        ApiConfig.setBool("api_fct_enabled", v);
        if (_container != null) _container.visible = v;
        try {
            if (Api.game != null && Api.game.litePreference != null && Api.game.litePreference.data != null) {
                Api.game.litePreference.data.bDisDmgDisplay = v;
            }
        } catch (_:Dynamic) {}
    }

    public static inline function getFilterMode():Int {
        return ApiConfig.getInt("api_fct_mode", 0); // 0 = Self & Target, 1 = Self Only, 2 = Target Only, 3 = All
    }

    public static inline function setFilterMode(mode:Int):Void {
        ApiConfig.setInt("api_fct_mode", mode);
    }

    public static inline function isCompactFormat():Bool {
        return ApiConfig.getBool("api_fct_compact", false);
    }

    public static inline function setCompactFormat(v:Bool):Void {
        ApiConfig.setBool("api_fct_compact", v);
    }

    public static inline function isShowIncoming():Bool {
        return ApiConfig.getBool("api_fct_incoming", true);
    }

    public static inline function setShowIncoming(v:Bool):Void {
        ApiConfig.setBool("api_fct_incoming", v);
    }

    public static inline function isShowDots():Bool {
        return ApiConfig.getBool("api_fct_dots", true);
    }

    public static inline function setShowDots(v:Bool):Void {
        ApiConfig.setBool("api_fct_dots", v);
    }

    public static inline function isShowHeals():Bool {
        return ApiConfig.getBool("api_fct_heals", true);
    }

    public static inline function setShowHeals(v:Bool):Void {
        ApiConfig.setBool("api_fct_heals", v);
    }
}
#else
class DamageNumbers {
    public static function init(pocket:Dynamic, overlay:Dynamic):Void {}
    public static function isEnabled():Bool return false;
    public static function setEnabled(v:Bool):Void {}
    public static function getFilterMode():Int return 0;
    public static function setFilterMode(mode:Int):Void {}
    public static function isCompactFormat():Bool return false;
    public static function setCompactFormat(v:Bool):Void {}
    public static function isShowIncoming():Bool return false;
    public static function setShowIncoming(v:Bool):Void {}
    public static function isShowDots():Bool return false;
    public static function setShowDots(v:Bool):Void {}
    public static function isShowHeals():Bool return false;
    public static function setShowHeals(v:Bool):Void {}
}
#end
