package ui.widgets;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.Overlay;
import ui.prompts.ApiPromptModal;

typedef WidgetOptionItem = {
    id:String,
    label:String,
    desc:String,
    isFixed:Bool
};

/**
 * Universal configuration modal for default and standalone widgets.
 * Allows users to choose which options remain FIXED (pinned) when the widget is minimized.
 * If no options are fixed, the widget collapses into a compact 78x26 button (matching Main Menu).
 */
class WidgetConfigModal {
    public static function show(
        overlay:Overlay,
        widgetTitle:String,
        options:Array<WidgetOptionItem>,
        onSave:Array<String>->Void
    ):Void {
        if (overlay == null || options == null) return;

        var dlgW:Float = 360;
        var dlgH:Float = 390;
        var dlg = ApiPromptModal.createDialog(dlgW, dlgH, "Configure " + widgetTitle);

        // 1. Explanatory Note
        var noteTxt = new TextField();
        var noteFmt = new TextFormat(ApiStyle.FONT_FAMILY, 10, ApiStyle.COLOR_TEXT_MUTED);
        noteTxt.defaultTextFormat = noteFmt;
        noteTxt.text = "Check options to keep FIXED (visible when collapsed).\nIf none are fixed, the widget collapses into a compact 78x26 button (matching Main Menu).";
        noteTxt.x = 20;
        noteTxt.y = 38;
        noteTxt.width = 320;
        noteTxt.height = 34;
        noteTxt.selectable = false;
        noteTxt.wordWrap = true;
        dlg.addChild(noteTxt);

        // 2. Options Container Plate
        var listW:Float = 320;
        var listH:Float = 240;
        var listContainer = new Sprite();
        listContainer.x = 20;
        listContainer.y = 78;
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

        // Selection map
        var fixedMap:Map<String, Bool> = new Map<String, Bool>();
        for (opt in options) {
            if (opt.isFixed) fixedMap.set(opt.id, true);
        }

        var rowH:Float = 42;
        for (i in 0...options.length) {
            var opt = options[i];
            var row = new Sprite();
            row.y = i * rowH + 2;

            // Zebra background
            row.graphics.beginFill((i % 2 == 0) ? ApiStyle.COLOR_BG_MAIN : ApiStyle.COLOR_BG_SURFACE, 0.85);
            row.graphics.drawRoundRect(2, 0, listW - 4, rowH - 2, 4, 4);
            row.graphics.endFill();

            // Checkbox
            var isChecked = fixedMap.exists(opt.id) && fixedMap.get(opt.id);
            var chkBox = createCheckbox(opt.label, opt.desc, isChecked, function(c:Bool):Void {
                fixedMap.set(opt.id, c);
            });
            chkBox.x = 8;
            chkBox.y = 3;
            row.addChild(chkBox);

            content.addChild(row);
        }

        // 3. Action Buttons (Save & Cancel)
        var btnW:Float = 90;
        var btnH:Float = 28;
        var btnY:Float = dlgH - 42;

        var btnCancel = ApiPromptModal.createButton("Cancel", btnW, btnH, function():Void {
            ApiPromptModal.close();
        }, false);
        btnCancel.x = 20;
        btnCancel.y = btnY;
        dlg.addChild(btnCancel);

        var btnSave = ApiPromptModal.createButton("Save", btnW, btnH, function():Void {
            var selectedFixed:Array<String> = [];
            for (opt in options) {
                if (fixedMap.exists(opt.id) && fixedMap.get(opt.id)) {
                    selectedFixed.push(opt.id);
                }
            }
            ApiPromptModal.close();
            if (onSave != null) {
                onSave(selectedFixed);
            }
            ApiNotificationManager.notify(widgetTitle + " configuration updated!");
        }, true);
        btnSave.x = dlgW - btnW - 20;
        btnSave.y = btnY;
        dlg.addChild(btnSave);

        ApiPromptModal.show(overlay, dlg);
    }

    private static function createCheckbox(label:String, desc:String, checked:Bool, onToggle:Bool->Void):Sprite {
        var sp = new Sprite();
        sp.buttonMode = true;
        sp.useHandCursor = true;

        var box = new Shape();
        sp.addChild(box);

        var lblTxt = new TextField();
        var fmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_PRIMARY, true);
        lblTxt.defaultTextFormat = fmt;
        lblTxt.text = label;
        lblTxt.x = 22;
        lblTxt.y = 0;
        lblTxt.width = 280;
        lblTxt.height = 18;
        lblTxt.selectable = false;
        lblTxt.mouseEnabled = false;
        sp.addChild(lblTxt);

        var descTxt = new TextField();
        var dFmt = new TextFormat(ApiStyle.FONT_FAMILY, 9, ApiStyle.COLOR_TEXT_MUTED);
        descTxt.defaultTextFormat = dFmt;
        descTxt.text = desc;
        descTxt.x = 22;
        descTxt.y = 17;
        descTxt.width = 280;
        descTxt.height = 16;
        descTxt.selectable = false;
        descTxt.mouseEnabled = false;
        sp.addChild(descTxt);

        var curChecked = checked;
        var renderBox = function(c:Bool, hover:Bool):Void {
            box.graphics.clear();
            var bg = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_CARD;
            var border = c ? ApiStyle.COLOR_STATUS_ACTIVE : (hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT);
            box.graphics.beginFill(bg, 0.95);
            box.graphics.lineStyle(1, border);
            box.graphics.drawRoundRect(0, 3, 14, 14, 3, 3);
            box.graphics.endFill();

            if (c) {
                box.graphics.lineStyle(2, ApiStyle.COLOR_STATUS_ACTIVE, 1.0, true);
                box.graphics.moveTo(3, 10);
                box.graphics.lineTo(6, 13);
                box.graphics.lineTo(12, 6);
            }
        };
        renderBox(curChecked, false);

        sp.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void renderBox(curChecked, true));
        sp.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void renderBox(curChecked, false));
        sp.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            curChecked = !curChecked;
            renderBox(curChecked, false);
            if (onToggle != null) onToggle(curChecked);
        });

        return sp;
    }
}
#else
class WidgetConfigModal {
    public static function show(overlay:Dynamic, widgetTitle:String, options:Dynamic, onSave:Dynamic):Void {}
}
#end
