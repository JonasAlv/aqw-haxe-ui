package ui.components;

#if flash
import flash.display.Sprite;
import flash.events.Event;
import com.aqwapi.Api;
import com.aqwapi.modules.CombatEngine;
import com.aqwapi.utils.ApiConfig;
import com.aqwapi.utils.ApiLogger;
import ui.ApiStyle;
import ui.Dropdown;

/**
 * Reusable Class and Combat Mode Selector UI Component.
 *
 * Coordinates:
 * - Scanning and listing available classes (equipped, inventory, and known built-ins).
 * - Querying available combat modes per class (handling 'Current' and class-specific rules).
 * - A linked pair of Dropdowns with automated mode updating, color dot indicators,
 *   and optional config persistence binding.
 */
class ClassModeSelector extends Sprite {
    public static var lastInventoryClassKeys:Map<String, Bool> = new Map<String, Bool>();

    public var classDropdown:Dropdown;
    public var modeDropdown:Dropdown;

    private var _selectedClass:String = "Current";
    private var _selectedMode:String = "Auto";
    private var _classKey:String = null;
    private var _modeKey:String = null;
    private var _autoLabel:String = "Auto";
    private var _includeAllKnown:Bool = true;
    private var _onChange:String->String->Void = null;

    public var selectedClass(get, set):String;
    private inline function get_selectedClass():String return _selectedClass;
    private function set_selectedClass(val:String):String {
        if (val == null || val == "") val = "Current";
        _selectedClass = val;
        if (classDropdown != null) classDropdown.setSelectedItem(val);
        refreshModes();
        return _selectedClass;
    }

    public var selectedMode(get, set):String;
    private inline function get_selectedMode():String return _selectedMode;
    private function set_selectedMode(val:String):String {
        if (val == null || val == "") val = _autoLabel;
        _selectedMode = val;
        if (modeDropdown != null) modeDropdown.setSelectedItem(val);
        return _selectedMode;
    }

    public function new(
        classW:Float = 196,
        modeW:Float = 196,
        height:Float = 26,
        gap:Float = 10,
        includeAllKnown:Bool = true,
        autoLabel:String = "Auto",
        onChange:String->String->Void = null,
        vertical:Bool = false
    ) {
        super();
        _includeAllKnown = includeAllKnown;
        _autoLabel = (autoLabel != null && autoLabel != "") ? autoLabel : "Auto";
        _onChange = onChange;

        var availableClasses = getAvailableClasses(_includeAllKnown);
        if (availableClasses == null || availableClasses.length == 0) availableClasses = ["Current"];

        var availableModes = getModesForClass(_selectedClass, _autoLabel);

        // 1. Class Dropdown
        classDropdown = new Dropdown(classW, height, availableClasses, function(sel:String):Void {
            _selectedClass = sel;
            if (_classKey != null) {
                try { ApiConfig.setString(_classKey, sel); } catch (_:Dynamic) {}
            }
            refreshModes();
            notifyChange();
        });

        classDropdown.itemColorCallback = function(itemName:String):Null<Int> {
            if (itemName == null || itemName == "") return null;
            if (itemName.toLowerCase() == "current") return ApiStyle.COLOR_TEXT_YELLOW;
            var key = itemName.toLowerCase();
            if (lastInventoryClassKeys != null && lastInventoryClassKeys.exists(key)) {
                return ApiStyle.COLOR_STATUS_ACTIVE;
            }
            return ApiStyle.COLOR_TEXT_MUTED;
        };

        classDropdown.onBeforeOpen = function():Void {
            bringToFront(classDropdown);
            refreshClasses();
        };

        // 2. Mode Dropdown
        modeDropdown = new Dropdown(modeW, height, availableModes, function(sel:String):Void {
            _selectedMode = sel;
            saveModeToConfig(sel);
            notifyChange();
        });

        modeDropdown.onBeforeOpen = function():Void {
            bringToFront(modeDropdown);
            refreshModes();
        };

        // 3. Layout positioning
        classDropdown.x = 0;
        classDropdown.y = 0;

        if (vertical) {
            modeDropdown.x = 0;
            modeDropdown.y = height + gap;
        } else {
            modeDropdown.x = classW + gap;
            modeDropdown.y = 0;
        }

        addChild(modeDropdown);
        addChild(classDropdown);
    }

    private function bringToFront(dd:Dropdown):Void {
        if (parent != null) {
            try { parent.setChildIndex(this, parent.numChildren - 1); } catch (_:Dynamic) {}
        }
        try { setChildIndex(dd, numChildren - 1); } catch (_:Dynamic) {}
    }

    public function bindConfig(classKey:String, modeKey:String, defaultClass:String = "Current", defaultMode:String = null):Void {
        _classKey = classKey;
        _modeKey = modeKey;

        var initialClass = defaultClass;
        if (_classKey != null) {
            try {
                var saved = ApiConfig.getString(_classKey, defaultClass);
                if (saved != null && saved != "") initialClass = saved;
            } catch (_:Dynamic) {}
        }

        var availableClasses = classDropdown.options;
        if (availableClasses.indexOf(initialClass) == -1) {
            initialClass = (availableClasses.length > 0) ? availableClasses[0] : "Current";
        }
        _selectedClass = initialClass;
        classDropdown.setSelectedItem(_selectedClass);

        var modes = getModesForClass(_selectedClass, _autoLabel);
        modeDropdown.setOptions(modes, true);

        var initialMode = (defaultMode != null && defaultMode != "") ? defaultMode : _autoLabel;
        if (_modeKey != null) {
            try {
                var savedMode = ApiConfig.getString(_modeKey, initialMode);
                if (savedMode != null && savedMode != "") {
                    if (savedMode == "Auto" && _autoLabel.indexOf("First Available") != -1) {
                        initialMode = _autoLabel;
                    } else {
                        initialMode = savedMode;
                    }
                }
            } catch (_:Dynamic) {}
        }

        if (modes.indexOf(initialMode) == -1) {
            initialMode = (modes.length > 0) ? modes[0] : _autoLabel;
        }
        _selectedMode = initialMode;
        modeDropdown.setSelectedItem(_selectedMode);
    }

    public function refreshClasses():Void {
        var freshClasses = getAvailableClasses(_includeAllKnown);
        if (freshClasses == null || freshClasses.length == 0) freshClasses = ["Current"];
        classDropdown.setOptions(freshClasses, true);

        if (_selectedClass != "" && freshClasses.indexOf(_selectedClass) != -1) {
            classDropdown.setSelectedItem(_selectedClass);
        } else if (_selectedClass != "" && _selectedClass != "Current" && freshClasses.indexOf(_selectedClass) == -1) {
            _selectedClass = "Current";
            classDropdown.setSelectedItem("Current");
            if (_classKey != null) {
                try { ApiConfig.setString(_classKey, "Current"); } catch (_:Dynamic) {}
            }
        }
    }

    public function refreshModes():Void {
        var modes = getModesForClass(_selectedClass, _autoLabel);
        modeDropdown.setOptions(modes, true);

        if (modes.indexOf(_selectedMode) == -1) {
            _selectedMode = (modes.length > 0) ? modes[0] : _autoLabel;
            modeDropdown.setSelectedItem(_selectedMode);
            saveModeToConfig(_selectedMode);
        } else {
            modeDropdown.setSelectedItem(_selectedMode);
        }
    }

    private function saveModeToConfig(sel:String):Void {
        if (_modeKey != null) {
            var saveVal = (sel == "Auto (First Available)") ? "Auto" : sel;
            try { ApiConfig.setString(_modeKey, saveVal); } catch (_:Dynamic) {}
        }
    }

    private function notifyChange():Void {
        if (_onChange != null) {
            try {
                _onChange(_selectedClass, _selectedMode);
            } catch (e:Dynamic) {
                ApiLogger.error("UI", "ClassModeSelector onChange error: " + e);
            }
        }
    }

    // --- Static Helpers ---

    public static function getCurrentClass():String {
        try {
            var cur:String = CombatEngine.getCurrentClassName();
            if (cur != null && cur != "" && cur.toLowerCase() != "current") return cur;
            if (Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null) {
                var av:Dynamic = Api.game.world.myAvatar;
                if (av.objData != null && av.objData.strClassName != null) {
                    var c:String = Std.string(av.objData.strClassName);
                    if (c != "" && c != "null") return c;
                }
            }
        } catch (_:Dynamic) {}
        return "";
    }

    public static function getAvailableClasses(includeAllKnown:Bool = true):Array<String> {
        var classMap:Map<String, String> = new Map<String, String>();
        var invClasses:Array<String> = [];
        var otherClasses:Array<String> = [];
        lastInventoryClassKeys = new Map<String, Bool>();

        var addClass = function(name:Dynamic, isInventory:Bool = false):Void {
            if (name == null) return;
            var str:String = Std.string(name);
            var trimmed:String = StringTools.trim(str);
            if (trimmed == "" || trimmed == "null" || trimmed == "No Classes Found" || trimmed.toLowerCase() == "current") return;
            var key:String = trimmed.toLowerCase();
            if (!classMap.exists(key)) {
                classMap.set(key, trimmed);
                if (isInventory) {
                    invClasses.push(trimmed);
                    lastInventoryClassKeys.set(key, true);
                } else {
                    otherClasses.push(trimmed);
                }
            }
        };

        // 1. Currently equipped class
        try {
            var cur:String = getCurrentClass();
            if (cur != "" && cur.toLowerCase() != "current") {
                addClass(cur, true);
            }
        } catch (_:Dynamic) {}

        // 2. Inventory classes
        try {
            var rawItems:Array<Dynamic> = null;
            if (Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null && Api.game.world.myAvatar.items != null) {
                if (Std.isOfType(Api.game.world.myAvatar.items, Array)) {
                    rawItems = cast Api.game.world.myAvatar.items;
                }
            }
            if (rawItems == null && Api.inventory != null) {
                var dtoList = Api.inventory.getItems();
                if (dtoList != null && dtoList.length > 0) {
                    rawItems = [];
                    for (d in dtoList) {
                        if (d != null && d.raw != null) rawItems.push(d.raw);
                    }
                }
            }
            if (rawItems != null) {
                for (item in rawItems) {
                    if (item == null || item.sName == null) continue;
                    var isClass:Bool = false;
                    var sTypeStr:String = (item.sType != null) ? Std.string(item.sType).toLowerCase() : "";
                    if (sTypeStr == "class" || item.bClass == 1 || item.bClass == true || item.bClass == "1") {
                        isClass = true;
                    } else if (item.sES != null && Std.string(item.sES).toLowerCase() == "ar" && sTypeStr != "armor") {
                        if (CombatEngine.findClassConfig(item.sName) != null) isClass = true;
                    }
                    if (isClass) addClass(item.sName, true);
                }
            }
        } catch (_:Dynamic) {}

        // 3. Known built-in classes from CombatEngine
        if (includeAllKnown) {
            try {
                var known = CombatEngine.getKnownClasses();
                if (known != null) {
                    for (kc in known) {
                        addClass(kc, false);
                    }
                }
            } catch (_:Dynamic) {}
        }

        try {
            invClasses.sort(function(a, b) {
                var la:String = a.toLowerCase();
                var lb:String = b.toLowerCase();
                if (la < lb) return -1;
                if (la > lb) return 1;
                return 0;
            });
            if (includeAllKnown) {
                otherClasses.sort(function(a, b) {
                    var la:String = a.toLowerCase();
                    var lb:String = b.toLowerCase();
                    if (la < lb) return -1;
                    if (la > lb) return 1;
                    return 0;
                });
            }
        } catch (_:Dynamic) {}

        var result:Array<String> = ["Current"];
        for (c in invClasses) result.push(c);
        if (includeAllKnown) {
            for (c in otherClasses) result.push(c);
        }
        return result;
    }

    public static function getModesForClass(cName:String, autoLabel:String = "Auto"):Array<String> {
        var modes:Array<String> = [];
        var isCurrent = (cName == null || cName == "" || cName.toLowerCase() == "current");
        var targetClass:String = cName;

        if (isCurrent) {
            modes.push(autoLabel);
            try {
                var cur = CombatEngine.getCurrentClassName();
                if (cur != null && cur != "" && cur.toLowerCase() != "current") {
                    targetClass = cur;
                }
            } catch (_:Dynamic) {}
        }

        if (targetClass != null && targetClass != "" && targetClass.toLowerCase() != "current") {
            try {
                var engineModes = CombatEngine.getAvailableModes(targetClass);
                if (engineModes != null) {
                    for (m in engineModes) {
                        if (m != null && m != "" && modes.indexOf(m) == -1) {
                            modes.push(m);
                        }
                    }
                }
            } catch (_:Dynamic) {}
        }

        if (modes.length == 0) {
            modes = [autoLabel, "Solo", "Farm"];
        } else if (modes.indexOf(autoLabel) == -1 && isCurrent) {
            modes.unshift(autoLabel);
        }
        return modes;
    }
}
#else
class ClassModeSelector {
    public static var lastInventoryClassKeys:Map<String, Bool> = new Map<String, Bool>();
    public static function getCurrentClass():String return "";
    public static function getAvailableClasses(includeAllKnown:Bool = true):Array<String> return ["Current"];
    public static function getModesForClass(cName:String, autoLabel:String = "Auto"):Array<String> return ["Auto"];
}
#end
