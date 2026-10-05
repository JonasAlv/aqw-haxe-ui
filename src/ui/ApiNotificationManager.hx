package ui;

import com.aqwapi.Api;
import com.aqwapi.events.ApiEvent;

#if flash
import flash.display.Sprite;
#end

class ApiNotificationManager {
    /** Ceiling on simultaneously visible cards. */
    // Cap and repeat folding are policy and live in the API (com.aqwapi.feedback.ApiFeedback);
    // this class is rendering only.
    private static inline function maxVisible():Int { return com.aqwapi.feedback.ApiFeedback.MAX_VISIBLE; }
    /** Same ceiling for messages buffered before `init()` runs. */
    private static inline var MAX_PENDING:Int = 8;
    /** Gap between the card stack and the right/top stage edges. */
    private static inline var SCREEN_MARGIN:Float = 12.0;

    private static var _instance:ApiNotificationManager;
    public static var instance(get, never):ApiNotificationManager;
    @:getter(instance)
    public static function get_instance_prop():ApiNotificationManager { return get_instance(); }
    public static function get_instance():ApiNotificationManager {
        if (_instance == null) _instance = new ApiNotificationManager();
        return _instance;
    }

    public static function notify(message:String):Void {
        if (message == null || message == "") return;
        if (instance._initialized) {
            instance.showNotification(null, message, false, 1);
        } else {
            instance._pendingMessages.push({ id: null, message: message, sticky: false, repeat: 1 });
        }
    }

    #if flash
    private var _container:Sprite;
    private var _notifications:Array<ApiNotification> = [];
    #end
    private var _initialized:Bool = false;
    private var _pendingMessages:Array<{ id:String, message:String, sticky:Bool, repeat:Int }> = [];

    public function new() {
        Api.dispatcher.addEventListener(ApiEvent.NOTIFICATION, onApiNotification);
        Api.dispatcher.addEventListener(ApiEvent.STICKY_NOTIFICATION, onStickyNotification);
        Api.dispatcher.addEventListener(ApiEvent.REMOVE_STICKY, onRemoveSticky);
        Api.dispatcher.addEventListener(ApiEvent.COMBAT_TOGGLED, onApiNotification);
        Api.dispatcher.addEventListener(ApiEvent.SCRIPT_STARTED, onApiNotification);
        Api.dispatcher.addEventListener(ApiEvent.SCRIPT_STOPPED, onApiNotification);
    }

    #if flash
    public function init(container:Sprite):Void {
        if (_initialized) return;
        _initialized = true;
        _container = container;
        for (item in _pendingMessages) {
            showNotification(item.id, item.message, item.sticky, item.repeat);
        }
        _pendingMessages = [];
    }
    #else
    public function init(container:Dynamic):Void {
        _initialized = true;
    }
    #end

    private function onApiNotification(e:ApiEvent):Void {
        if (e == null || e.message == null || e.message == "") return;
        // Identity and repeat count are decided by ApiFeedback in the API; this only draws the number.
        var repeat:Int = (e.data != null && Reflect.hasField(e.data, "repeat")) ? Std.int(Reflect.field(e.data, "repeat")) : 1;
        if (_initialized) {
            showNotification(null, e.message, false, repeat);
        } else {
            enqueue({ id: null, message: e.message, sticky: false, repeat: repeat });
        }
    }

    private function onStickyNotification(e:ApiEvent):Void {
        var id:String = (e.data != null && Reflect.hasField(e.data, "id")) ? Reflect.field(e.data, "id") : "default_sticky";
        if (_initialized) {
            createSticky(id, e.message);
        } else {
            enqueue({ id: id, message: e.message, sticky: true, repeat: 1 });
        }
    }

    /** Buffers a pre-init message, keeping only the newest few so a burst cannot replay on init. */
    private function enqueue(item:{ id:String, message:String, sticky:Bool, repeat:Int }):Void {
        _pendingMessages.push(item);
        while (_pendingMessages.length > MAX_PENDING) {
            var drop:Int = 0;
            for (i in 0..._pendingMessages.length) {
                if (!_pendingMessages[i].sticky) { drop = i; break; }
            }
            _pendingMessages.splice(drop, 1);
        }
    }

    private function onRemoveSticky(e:ApiEvent):Void {
        var id:String = (e.data != null && Reflect.hasField(e.data, "id")) ? Reflect.field(e.data, "id") : "default_sticky";
        if (_initialized) {
            removeSticky(id);
        } else {
            var i = _pendingMessages.length - 1;
            while (i >= 0) {
                if (_pendingMessages[i].id == id) {
                    _pendingMessages.splice(i, 1);
                }
                i--;
            }
        }
    }

    public function createSticky(id:String, message:String):Void {
        if (id != null) {
            removeSticky(id);
        }
        showNotification(id, message, true);
    }

    public function removeSticky(id:String):Void {
        #if flash
        var i = _notifications.length - 1;
        while (i >= 0) {
            var notif = _notifications[i];
            if (notif.id == id) {
                notif.destroy();
                _notifications.splice(i, 1);
                positionNotifications();
                return;
            }
            i--;
        }
        #end
    }

    private function showNotification(id:String, message:String, sticky:Bool, repeat:Int = 1):Void {
        #if flash
        if (_container == null) return;
        if (!sticky) {
            // A repeating notify() folds into the card on screen instead of stacking identical ones.
            var last:ApiNotification = null;
            if (_notifications.length > 0) {
                var candidate = _notifications[_notifications.length - 1];
                if (!candidate.sticky && !candidate.isSameMessage(message)) candidate = null;
                last = candidate;
            }
            if (last != null) {
                last.bumpRepeat();
                return;
            }
        }
        var notif = new ApiNotification(id, message, sticky);
        // The API owns fold policy, so adopt its count rather than only counting locally.
        if (repeat > 1) notif.setRepeatCount(repeat);
        notif.setOnDismiss(onDismiss);
        _notifications.push(notif);
        _container.addChild(notif);
        enforceLimit();
        positionNotifications();
        #end
    }

    #if flash
    /**
     * Caps the stack so a script spamming `notify()` cannot bury the screen.
     *
     * Auto-dismissing cards go first, oldest out; sticky cards are deliberate state and are only
     * dropped when nothing else is left to make room.
     */
    private function enforceLimit():Void {
        while (_notifications.length > maxVisible()) {
            var victim:ApiNotification = null;
            for (n in _notifications) {
                if (!n.sticky) { victim = n; break; }
            }
            if (victim == null) victim = _notifications[0];
            victim.dismiss();
            if (_notifications.indexOf(victim) != -1) {
                // Fading cards leave on their own; take it out of the layout immediately.
                _notifications.remove(victim);
            }
        }
    }

    private function onDismiss(notif:ApiNotification):Void {
        var idx = _notifications.indexOf(notif);
        if (idx != -1) {
            _notifications.splice(idx, 1);
        }
        positionNotifications();
    }

    private function positionNotifications():Void {
        var currentY:Float = 0;
        for (notif in _notifications) {
            notif.y = currentY;
            currentY += notif.contentHeight + 6;
        }
        if (_container != null && _container.stage != null && _notifications.length > 0) {
            // Top right: the top-centre slot is where the game draws the unit frame.
            _container.x = _container.stage.stageWidth - ApiNotification.CARD_WIDTH - SCREEN_MARGIN;
            _container.y = SCREEN_MARGIN;
        }
    }
    #end

    public function destroy():Void {
        #if flash
        for (notif in _notifications) {
            notif.destroy();
        }
        _notifications = [];
        if (_container != null && _container.parent != null) {
            _container.parent.removeChild(_container);
        }
        _container = null;
        #end
        _initialized = false;
    }
}

