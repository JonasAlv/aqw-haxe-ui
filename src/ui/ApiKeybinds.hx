package ui;

#if flash
import com.aqwapi.Api;
import com.aqwapi.modules.CombatEngine;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.utils.ApiConfig;
import flash.display.Stage;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import ui.topbar.TopBar;

/**
 * Central registry and dispatcher for API/UI keybinds.
 *
 * Actions register one time with a stable id, then the Keybinds tab can
 * expose them without each feature implementing its own capture/settings
 * code. Bindings are global client preferences, not account gameplay state.
 */
class ApiKeybinds {
    private static inline var ENABLE_KEY:String = "shortcut_api_keybinds_enabled";
    private static inline var LEGACY_ENABLE_KEY:String = "api_dialog_keybinds";
    private static inline var YES_ID:String = "dialog_yes";
    private static inline var NO_ID:String = "dialog_no";
    private static inline var DEFAULT_YES_KEY:Int = 69; // E
    private static inline var DEFAULT_NO_KEY:Int = 82; // R
    private static inline var ENTER_KEY:Int = 13;
    private static inline var ESCAPE_KEY:Int = 27;
    private static inline var SPACE_KEY:Int = 32;
    private static inline var TAB_KEY:Int = 9;
    private static inline var BACKSPACE_KEY:Int = 8;
    private static inline var DELETE_KEY:Int = 46;
    private static inline var UP_KEY:Int = 38;
    private static inline var DOWN_KEY:Int = 40;
    private static inline var LEFT_KEY:Int = 37;
    private static inline var RIGHT_KEY:Int = 39;
    private static inline var SHIFT_KEY:Int = 16;
    private static inline var CONTROL_KEY:Int = 17;
    private static inline var ALT_KEY:Int = 18;

    private static var _stage:Stage = null;
    private static var _host:Dynamic = null;
    private static var _initialized:Bool = false;
    private static var _captureId:String = null;
    private static var _actions:Array<Dynamic> = [];
    private static var _actionMap:Map<String, Dynamic> = new Map<String, Dynamic>();

    public static function init(stageObj:Stage, hostObj:Dynamic = null):Void {
        _host = hostObj;
        registerDefaults();
        if (_initialized || stageObj == null) return;
        _stage = stageObj;
        _stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, false, 0, true);
        _initialized = true;
    }

    public static function dispose():Void {
        cancelCapture();
        if (_stage != null) {
            _stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
        }
        _stage = null;
        _host = null;
        _initialized = false;
    }

    public static function register(id:String, title:String, description:String, defaultKey:Int, handler:Void->Void):Void {
        if (id == null || id == "" || handler == null) return;
        if (_actionMap.exists(id)) return;
        var entry:Dynamic = {
            id: id,
            title: title,
            description: description,
            defaultKey: defaultKey,
            handler: handler
        };
        _actionMap.set(id, entry);
        _actions.push(entry);
    }

    public static function getActions():Array<Dynamic> {
        registerDefaults();
        return _actions;
    }

    public static function isEnabled():Bool {
        return ApiConfig.getBool(ENABLE_KEY, ApiConfig.getBool(LEGACY_ENABLE_KEY, false));
    }

    public static function setEnabled(enabled:Bool):Void {
        ApiConfig.setBool(ENABLE_KEY, enabled);
        // Keep profiles compatible with the previous dialog-only setting.
        ApiConfig.setBool(LEGACY_ENABLE_KEY, enabled);
    }

    public static function getKeyCode(id:String):Int {
        var action:Dynamic = _actionMap.get(id);
        var fallback:Int = (action != null) ? Std.int(action.defaultKey) : 0;
        var legacyKey:String = legacyKeyFor(id);
        var saved:Int = ApiConfig.getInt(configKeyFor(id),
            legacyKey != null ? ApiConfig.getInt(legacyKey, fallback) : fallback);
        return saved >= 0 ? saved : fallback;
    }

    public static function getKeyLabel(id:String):String {
        return keyLabel(getKeyCode(id));
    }

    public static function beginCapture(id:String):Void {
        if (id == null || !_actionMap.exists(id)) return;
        _captureId = id;
        var action:Dynamic = _actionMap.get(id);
        ApiNotificationManager.notify("Press an input for " + action.title + " (Esc cancels)");
    }

    public static function cancelCapture():Void {
        _captureId = null;
    }

    public static function resetAll():Void {
        for (action in getActions()) {
            ApiConfig.setInt(configKeyFor(action.id), Std.int(action.defaultKey));
        }
        ApiNotificationManager.notify("Keybinds restored to defaults");
    }

    private static function registerDefaults():Void {
        if (_actionMap.exists(YES_ID)) return;

        register(YES_ID, "Dialog: Yes", "Accept every native AQW Yes / No confirmation dialog.", DEFAULT_YES_KEY,
            function():Void { clickDialog(true); });
        register(NO_ID, "Dialog: No", "Decline every native AQW Yes / No confirmation dialog.", DEFAULT_NO_KEY,
            function():Void { clickDialog(false); });
        register("combat_toggle", "Smart Combat", "Start or stop the API smart combat engine.", 0,
            function():Void { toggleCombat(); });
        register("script_toggle", "Script Runner", "Start or stop the active API script.", 0,
            function():Void { toggleScript(); });
        register("script_manager", "Script Manager", "Open the API script editor and script list.", 0,
            function():Void { TopBar.openScriptManager(); });
        register("menu_toggle", "API Menu", "Open or close the API control center.", 0,
            function():Void { toggleMenu(); });
        register("auto_panel", "Auto Panel", "Open or close the combat and hunt controls.", 0,
            function():Void { TopBar.toggleAuto(); });
        register("jump_panel", "Jump Panel", "Open or close the map navigation controls.", 0,
            function():Void { TopBar.toggleJump(); });
        register("players_panel", "Players Panel", "Open or close the room player list.", 0,
            function():Void { TopBar.togglePlayers(); });
        register("bank_toggle", "Bank", "Open or close bank storage through the API.", 0,
            function():Void {
                if (Api.inventory != null) Api.inventory.toggleBank();
            });
        register("counter_toggle", "Counter Handler", "Toggle protection against counter and reflect auras.", 0,
            function():Void { toggleCounterHandler(); });
        register("vigil_guard_toggle", "Vigil Guard", "Toggle automatic slot-6 Vigil protection for server warnings.", 0,
            function():Void { toggleVigilGuard(); });
    }

    private static function onKeyDown(e:KeyboardEvent):Void {
        if (e == null) return;

        if (_captureId != null) {
            captureKey(e);
            return;
        }
        if (!isEnabled()) return;

        var code:Int = Std.int(e.keyCode);
        if (code <= 0) return;
        for (action in _actions) {
            if (getKeyCode(action.id) == code) {
                try {
                    action.handler();
                    consume(e);
                } catch (_:Dynamic) {}
                return;
            }
        }
    }

    private static function captureKey(e:KeyboardEvent):Void {
        var code:Int = Std.int(e.keyCode);
        if (code == ESCAPE_KEY) {
            cancelCapture();
            ApiNotificationManager.notify("Keybind capture cancelled");
            consume(e);
            return;
        }
        if (code <= 0) return;

        for (action in _actions) {
            if (action.id != _captureId && getKeyCode(action.id) == code) {
                ApiNotificationManager.notify("That input is already bound to " + action.title);
                consume(e);
                return;
            }
        }

        ApiConfig.setInt(configKeyFor(_captureId), code);
        var captured:Dynamic = _actionMap.get(_captureId);
        cancelCapture();
        ApiNotificationManager.notify(captured.title + " bound to " + keyLabel(code));
        consume(e);
    }

    private static function clickDialog(accept:Bool):Void {
        try {
            if (Api.game == null || Api.game.ui == null) return;
            var stack:Dynamic = Reflect.field(Api.game.ui, "ModalStack");
            if (stack == null) return;
            var count:Int = Std.int(Reflect.field(stack, "numChildren"));
            var i:Int = count - 1;
            while (i >= 0) {
                var modal:Dynamic = stack.getChildAt(i);
                var button:Dynamic = getDualButton(modal, accept);
                if (button != null) {
                    button.dispatchEvent(new MouseEvent(MouseEvent.CLICK, true, false));
                    return;
                }
                i--;
            }
        } catch (_:Dynamic) {}
    }

    private static function getDualButton(modal:Dynamic, accept:Bool):Dynamic {
        if (modal == null) return null;
        try {
            var cnt:Dynamic = Reflect.field(modal, "cnt");
            var btns:Dynamic = (cnt != null) ? Reflect.field(cnt, "btns") : null;
            var dual:Dynamic = (btns != null) ? Reflect.field(btns, "dual") : null;
            if (dual == null) return null;
            var yes:Dynamic = Reflect.field(dual, "ybtn");
            var no:Dynamic = Reflect.field(dual, "nbtn");
            return (yes != null && no != null) ? Reflect.field(dual, accept ? "ybtn" : "nbtn") : null;
        } catch (_:Dynamic) {
            return null;
        }
    }

    private static function toggleCombat():Void {
        if (Api.combat == null) return;
        if (Api.combat.isRunning()) {
            Api.combat.stop();
        } else {
            Api.combat.startSmartStandalone(ApiConfig.getString("api_smart_class", "Current"), ApiConfig.getString("api_smart_mode", "Auto"));
        }
    }

    private static function toggleScript():Void {
        if (ScriptManager.SINGLETON.isRunning) ScriptManager.SINGLETON.stop();
        else ScriptManager.SINGLETON.start();
    }

    private static function toggleMenu():Void {
        if (_stage == null) return;
        if (ApiDashboardModal.isOpen()) ApiDashboardModal.close();
        else ApiDashboardModal.show(_stage, _host);
    }

    private static function toggleCounterHandler():Void {
        var next:Bool = !CombatEngine.counterHandler;
        if (Api.combat != null) Api.combat.enableCounterHandler(next);
        else CombatEngine.counterHandler = next;
    }

    private static function toggleVigilGuard():Void {
        var next:Bool = !CombatEngine.vigilGuardEnabled;
        if (Api.combat != null) Api.combat.enableVigilGuard(next, "Vigil");
        else CombatEngine.vigilGuardEnabled = next;
    }

    private static function consume(e:KeyboardEvent):Void {
        e.preventDefault();
        e.stopImmediatePropagation();
    }

    private static function configKeyFor(id:String):String {
        return "shortcut_api_" + id;
    }

    private static function legacyKeyFor(id:String):String {
        if (id == YES_ID) return "api_dialog_yes_key";
        if (id == NO_ID) return "api_dialog_no_key";
        return null;
    }

    private static function keyLabel(code:Int):String {
        switch (code) {
            case 0: return "Unbound";
            case ENTER_KEY: return "Enter";
            case ESCAPE_KEY: return "Escape";
            case SPACE_KEY: return "Space";
            case TAB_KEY: return "Tab";
            case BACKSPACE_KEY: return "Backspace";
            case DELETE_KEY: return "Delete";
            case UP_KEY: return "Up";
            case DOWN_KEY: return "Down";
            case LEFT_KEY: return "Left";
            case RIGHT_KEY: return "Right";
            case SHIFT_KEY: return "Shift";
            case CONTROL_KEY: return "Ctrl";
            case ALT_KEY: return "Alt";
            case DEFAULT_YES_KEY: return "E";
            case DEFAULT_NO_KEY: return "R";
            default: return "Key " + code;
        }
    }
}
#else
class ApiKeybinds {
    public static function init(stageObj:Dynamic, hostObj:Dynamic = null):Void {}
    public static function dispose():Void {}
    public static function register(id:String, title:String, description:String, defaultKey:Int, handler:Void->Void):Void {}
    public static function getActions():Array<Dynamic> return [];
    public static function isEnabled():Bool return false;
    public static function setEnabled(enabled:Bool):Void {}
    public static function getKeyCode(id:String):Int return 0;
    public static function getKeyLabel(id:String):String return "Unbound";
    public static function beginCapture(id:String):Void {}
    public static function cancelCapture():Void {}
    public static function resetAll():Void {}
}
#end
