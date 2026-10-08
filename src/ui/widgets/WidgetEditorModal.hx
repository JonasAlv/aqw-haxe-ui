package ui.widgets;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.events.TimerEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.utils.Timer;
import ui.ApiDashboardModal;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.ApiToolRegistry;
import ui.Overlay;
import ui.prompts.ApiPromptModal;
import ui.widgets.CustomWidgetDef;

private class CheckboxView extends Sprite {
    public var isChecked(default, null):Bool;
    private var _box:Shape;
    private var _txt:TextField;
    private var _onChange:Bool->Void;
    private var _isScrollGestureActive:Void->Bool;

    public function new(label:String, initialChecked:Bool, onChange:Bool->Void, totalWidth:Float, ?isScrollGestureActive:Void->Bool) {
        super();
        this.buttonMode = true;
        this.isChecked = initialChecked;
        this._onChange = onChange;
        this._isScrollGestureActive = isScrollGestureActive;

        _box = new Shape();
        addChild(_box);

        _txt = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_PRIMARY);
        _txt.defaultTextFormat = fmt;
        _txt.text = label;
        _txt.x = 20;
        _txt.y = 0;
        _txt.width = totalWidth - 22;
        _txt.height = 18;
        _txt.selectable = false;
        _txt.mouseEnabled = false;
        addChild(_txt);

        redraw();

        addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (_isScrollGestureActive != null && _isScrollGestureActive()) {
                return;
            }
            setChecked(!isChecked, true);
        });
    }

    public function setChecked(val:Bool, notify:Bool = false):Void {
        if (isChecked == val) return;
        isChecked = val;
        redraw();
        if (notify && _onChange != null) {
            _onChange(isChecked);
        }
    }

    private function redraw():Void {
        _box.graphics.clear();
        _box.graphics.beginFill(isChecked ? ApiStyle.COLOR_ACCENT_PRIMARY : ApiStyle.COLOR_BG_SURFACE, 1);
        _box.graphics.lineStyle(1, isChecked ? ApiStyle.COLOR_ACCENT_HOVER : ApiStyle.COLOR_BORDER_DEFAULT);
        _box.graphics.drawRoundRect(0, 2, 14, 14, 3, 3);
        _box.graphics.endFill();
        if (isChecked) {
            _box.graphics.lineStyle(2, ApiStyle.COLOR_BG_BACKDROP);
            _box.graphics.moveTo(3, 9);
            _box.graphics.lineTo(6, 12);
            _box.graphics.lineTo(11, 5);
        }
    }
}

class WidgetEditorModal {
    public static function show(
        overlay:Overlay,
        def:CustomWidgetDef,
        getDefaultItems:Void->Array<WidgetItemConfig>,
        onSave:Void->Void,
        onDelete:String->Void
    ):Void {
        if (overlay == null || def == null) return;

        var dlgW:Float = 400;
        var dlgH:Float = 475;
        var dlg = ApiPromptModal.createDialog(dlgW, dlgH, "Configure Widget");

        // 1. Widget Name Input
        var lblName = ApiPromptModal.createLabel("Widget Title", 360, 11, true);
        lblName.x = 20;
        lblName.y = 36;
        dlg.addChild(lblName);

        var txtName = ApiPromptModal.createInput(360, 24, def.title);
        txtName.x = 20;
        txtName.y = 54;
        dlg.addChild(txtName);

        // 2. Instructions Subtitle
        var lblDesc = ApiPromptModal.createLabel("Select tools to include. Check 'Fixed' to pin tools when collapsed:", 360, 10, false);
        lblDesc.x = 20;
        lblDesc.y = 84;
        lblDesc.textColor = ApiStyle.COLOR_TEXT_MUTED;
        dlg.addChild(lblDesc);

        // 3. Tools Scroll Container
        var listW:Float = 360;
        var listH:Float = 290;
        var listContainer = new Sprite();
        listContainer.x = 20;
        listContainer.y = 104;
        listContainer.graphics.beginFill(ApiStyle.COLOR_BG_SURFACE, 0.95);
        listContainer.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT);
        listContainer.graphics.drawRoundRect(0, 0, listW, listH, 6, 6);
        listContainer.graphics.endFill();
        dlg.addChild(listContainer);

        var maskShape = new Shape();
        maskShape.graphics.beginFill(0xFF0000);
        maskShape.graphics.drawRoundRect(0, 0, listW, listH, 6, 6);
        maskShape.graphics.endFill();
        listContainer.addChild(maskShape);

        var content = new Sprite();
        content.mask = maskShape;
        listContainer.addChild(content);

        // State trackers for dialog
        var includedMap:Map<String, Bool> = new Map<String, Bool>();
        var fixedMap:Map<String, Bool> = new Map<String, Bool>();

        for (it in def.items) {
            includedMap.set(it.toolId, true);
            if (it.isFixed) fixedMap.set(it.toolId, true);
        }

        // Scroll gesture tracking
        var isScrollDragging:Bool = false;
        var hasScrolledGesture:Bool = false;
        var scrollStartY:Float = 0;
        var contentStartY:Float = 0;

        var isScrollingActive = function():Bool {
            return hasScrolledGesture;
        };

        var tools = ApiToolRegistry.getAll();
        var rowH:Float = 24;
        for (i in 0...tools.length) {
            var tool = tools[i];
            var row = new Sprite();
            row.y = i * rowH + 2;

            // Zebra striping
            row.graphics.beginFill((i % 2 == 0) ? ApiStyle.COLOR_BG_MAIN : ApiStyle.COLOR_BG_SURFACE, 0.8);
            row.graphics.drawRoundRect(2, 0, listW - 4, rowH - 2, 4, 4);
            row.graphics.endFill();

            var chkInc:CheckboxView = null;
            var chkFix:CheckboxView = null;

            var onIncChange = function(c:Bool):Void {
                includedMap.set(tool.id, c);
                if (!c && chkFix != null && chkFix.isChecked) {
                    chkFix.setChecked(false, false);
                    fixedMap.set(tool.id, false);
                }
            };

            var onFixChange = function(c:Bool):Void {
                fixedMap.set(tool.id, c);
                if (c && chkInc != null && !chkInc.isChecked) {
                    chkInc.setChecked(true, false);
                    includedMap.set(tool.id, true);
                }
            };

            var isInc = includedMap.exists(tool.id) && includedMap.get(tool.id);
            var isFix = fixedMap.exists(tool.id) && fixedMap.get(tool.id);

            chkInc = new CheckboxView(tool.name, isInc, onIncChange, 180, isScrollingActive);
            chkInc.x = 8;
            chkInc.y = 2;
            row.addChild(chkInc);

            chkFix = new CheckboxView("Fixed", isFix, onFixChange, 130, isScrollingActive);
            chkFix.x = 210;
            chkFix.y = 2;
            row.addChild(chkFix);

            content.addChild(row);
        }

        // Mouse wheel and touch drag scrolling for tools container
        listContainer.addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent):Void {
            var totalContentH = tools.length * rowH;
            if (totalContentH <= listH) return;
            var maxScroll = listH - totalContentH;
            content.y += e.delta * 20;
            if (content.y > 0) content.y = 0;
            if (content.y < maxScroll) content.y = maxScroll;
        });

        listContainer.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            var totalContentH = tools.length * rowH;
            if (totalContentH <= listH) return;
            isScrollDragging = true;
            hasScrolledGesture = false;
            scrollStartY = e.stageY;
            contentStartY = content.y;
        });

        var onStageMouseMove = function(e:MouseEvent):Void {
            if (isScrollDragging) {
                var deltaY = e.stageY - scrollStartY;
                if (Math.abs(deltaY) > 5) {
                    hasScrolledGesture = true;
                }
                var totalContentH = tools.length * rowH;
                var maxScroll = listH - totalContentH;
                var targetY = contentStartY + deltaY;
                if (targetY > 0) targetY = 0;
                if (targetY < maxScroll) targetY = maxScroll;
                content.y = targetY;
            }
        };

        var onStageMouseUp = function(e:MouseEvent):Void {
            if (isScrollDragging) {
                isScrollDragging = false;
                if (hasScrolledGesture) {
                    haxe.Timer.delay(function():Void {
                        hasScrolledGesture = false;
                    }, 80);
                }
            }
        };

        if (overlay != null && overlay.stage != null) {
            overlay.stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
            overlay.stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
        }

        var resetDelTimer:Timer = null;

        var cleanup = function():Void {
            if (overlay != null && overlay.stage != null) {
                overlay.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
                overlay.stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
            }
            if (resetDelTimer != null) {
                resetDelTimer.stop();
                resetDelTimer = null;
            }
        };

        dlg.addEventListener(Event.REMOVED_FROM_STAGE, function(e:Event):Void {
            cleanup();
        });

        // 4. Dialog Action Buttons
        var btnY:Float = 405;

        // [Save]
        var btnSave = ApiPromptModal.createButton("Save", 85, 28, function():Void {
            var newTitle = StringTools.trim(txtName.text);
            if (newTitle == "") newTitle = "Quick Tools";
            def.title = newTitle;

            var newItems:Array<WidgetItemConfig> = [];
            for (t in tools) {
                if (includedMap.exists(t.id) && includedMap.get(t.id)) {
                    newItems.push({
                        toolId: t.id,
                        isFixed: (fixedMap.exists(t.id) && fixedMap.get(t.id))
                    });
                }
            }
            if (newItems.length == 0) {
                newItems.push({ toolId: "script_runner", isFixed: true });
            }
            def.items = newItems;

            if (onSave != null) onSave();
            cleanup();
            ApiPromptModal.close();
            ApiNotificationManager.notify("Widget '" + newTitle + "' saved!");
            ApiDashboardModal.refreshCurrentTab();
        }, true);
        btnSave.x = 20;
        btnSave.y = btnY;
        dlg.addChild(btnSave);

        // [Reset]
        var btnReset = ApiPromptModal.createButton("Reset", 75, 28, function():Void {
            if (getDefaultItems != null) {
                def.items = getDefaultItems();
            }
            def.title = "Quick Tools";
            if (onSave != null) onSave();
            cleanup();
            ApiPromptModal.close();
            ApiNotificationManager.notify("Widget reset to defaults.");
            ApiDashboardModal.refreshCurrentTab();
        }, false);
        btnReset.x = 122;
        btnReset.y = btnY;
        dlg.addChild(btnReset);

        // [Delete] (Two-tap confirmation: "Delete" -> "Confirm?")
        var deletePending:Bool = false;
        var btnDel:Sprite = null;

        btnDel = ApiPromptModal.createButton("Delete", 75, 28, function():Void {
            if (!deletePending) {
                deletePending = true;
                var txt:TextField = cast btnDel.getChildAt(0);
                if (txt != null) txt.text = "Confirm?";

                resetDelTimer = new Timer(3000, 1);
                resetDelTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function(te:TimerEvent):Void {
                    deletePending = false;
                    if (txt != null) txt.text = "Delete";
                });
                resetDelTimer.start();
            } else {
                cleanup();
                if (onDelete != null) onDelete(def.id);
                ApiPromptModal.close();
            }
        }, false, ApiStyle.COLOR_STATUS_ERROR, ApiStyle.COLOR_STATUS_ERROR_HOVER);
        btnDel.x = 214;
        btnDel.y = btnY;
        dlg.addChild(btnDel);

        // [Cancel]
        var btnCancel = ApiPromptModal.createButton("Cancel", 75, 28, function():Void {
            cleanup();
            ApiPromptModal.close();
        }, false);
        btnCancel.x = 305;
        btnCancel.y = btnY;
        dlg.addChild(btnCancel);

        ApiPromptModal.show(overlay, dlg);
    }
}
#else
class WidgetEditorModal {
    public static function show(overlay:Dynamic, def:Dynamic, getDefaultItems:Dynamic, onSave:Dynamic, onDelete:Dynamic):Void {}
}
#end
