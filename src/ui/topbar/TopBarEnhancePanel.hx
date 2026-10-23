package ui.topbar;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import com.aqwapi.Api;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.Dropdown;
import ui.EnhancementColors;

/** Compact enhancement setup attached to the topbar's ENH button. */
class TopBarEnhancePanel extends Sprite {
    public static inline var PANEL_WIDTH:Float = 286.0;
    public static inline var PANEL_HEIGHT:Float = 174.0;

    private var _status:TextField;
    private var _base:Dropdown;
    private var _weapon:Dropdown;
    private var _helm:Dropdown;
    private var _cape:Dropdown;
    private var _selectedBase:String = "Lucky";
    private var _selectedWeapon:String = "None";
    private var _selectedHelm:String = "None";
    private var _selectedCape:String = "None";

    private static var BASE_OPTIONS:Array<String> = ["Lucky", "Wizard", "Fighter", "Thief", "Healer", "Hybrid", "Spellbreaker"];
    private static var WEAPON_OPTIONS:Array<String> = ["None", "Spiral Carve", "Awe Blast", "Health Vamp", "Mana Vamp", "Powerword Die", "Smite", "Valiance", "Arcana's Concerto", "Elysium", "Acheron", "Dauntless", "Praxis", "Ravenous", "Lacerate"];
    private static var HELM_OPTIONS:Array<String> = ["None", "Forge", "Vim", "Examen", "Anima", "Pneuma", "Hearty"];
    private static var CAPE_OPTIONS:Array<String> = ["None", "Forge", "Absolution", "Vainglory", "Avarice", "Penitence", "Lament"];

    public function new() {
        super();
        buildUI();
        refresh();
    }

    public function refresh():Void {
        if (_status == null) return;
        var className:String = (Api.player != null && Api.player.className != null && Api.player.className != "")
            ? Api.player.className : "Class";
        _status.text = className + " | enhancement setup";
    }

    private function buildUI():Void {
        var bg = new Shape();
        bg.graphics.beginFill(ApiStyle.COLOR_BG_CARD, 0.97);
        bg.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.95);
        bg.graphics.drawRoundRect(0, 0, PANEL_WIDTH, PANEL_HEIGHT, ApiStyle.CORNER_RADIUS_SM, ApiStyle.CORNER_RADIUS_SM);
        bg.graphics.endFill();
        bg.graphics.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.5);
        bg.graphics.moveTo(3, 1);
        bg.graphics.lineTo(PANEL_WIDTH - 3, 1);
        addChild(bg);

        _status = new TextField();
        _status.defaultTextFormat = new TextFormat(ApiStyle.FONT_FAMILY, 10, ApiStyle.COLOR_TEXT_MUTED, false);
        _status.x = 10;
        _status.y = 7;
        _status.width = PANEL_WIDTH - 20;
        _status.height = 16;
        _status.selectable = false;
        _status.mouseEnabled = false;
        addChild(_status);

        var className:String = (Api.player != null && Api.player.className != null) ? Api.player.className : "";
        var rec:Dynamic = (Api.enhancement != null) ? Api.enhancement.getRecommendation(className) : null;
        if (rec != null) {
            if (rec.type != null && rec.type != "") _selectedBase = rec.type;
            if (rec.weapon != null && rec.weapon != "") _selectedWeapon = rec.weapon;
            if (rec.helm != null && rec.helm != "") _selectedHelm = rec.helm;
            if (rec.cape != null && rec.cape != "") _selectedCape = rec.cape;
        }

        _base = makeDropdown("Base", BASE_OPTIONS, _selectedBase, 10, 35, function(value:String):Void {
            _selectedBase = value;
            refreshColors();
        });
        _weapon = makeDropdown("Weapon", WEAPON_OPTIONS, _selectedWeapon, 146, 35, function(value:String):Void {
            _selectedWeapon = value;
        });
        _helm = makeDropdown("Helm", HELM_OPTIONS, _selectedHelm, 10, 87, function(value:String):Void {
            _selectedHelm = value;
        });
        _cape = makeDropdown("Cape", CAPE_OPTIONS, _selectedCape, 146, 87, function(value:String):Void {
            _selectedCape = value;
        });

        var applyBtn = createButton(266, 26, "Enhance Equipped", true);
        applyBtn.x = 10;
        applyBtn.y = 140;
        applyBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void applyEnhancements());
        addChild(applyBtn);

        var note = new TextField();
        note.defaultTextFormat = new TextFormat(ApiStyle.FONT_FAMILY, 9, ApiStyle.COLOR_TEXT_MUTED, false);
        note.text = "Equipped only | Forge/Awe optional";
        note.x = 10;
        note.y = 157;
        note.width = PANEL_WIDTH - 20;
        note.height = 14;
        note.selectable = false;
        note.mouseEnabled = false;
        addChild(note);
    }

    private function makeDropdown(label:String, options:Array<String>, selected:String, xPos:Float, yPos:Float, onChange:String->Void):Dropdown {
        var title = new TextField();
        title.defaultTextFormat = new TextFormat(ApiStyle.FONT_FAMILY, 9, ApiStyle.COLOR_TEXT_MUTED, true);
        title.text = label;
        title.x = xPos;
        title.y = yPos - 14;
        title.width = 130;
        title.height = 14;
        title.selectable = false;
        title.mouseEnabled = false;
        addChild(title);

        var dd = new Dropdown(130, 25, options, function(value:String):Void onChange(value));
        dd.x = xPos;
        dd.y = yPos;
        dd.itemColorCallback = function(value:String):Null<Int> {
            return EnhancementColors.getColor(value, _selectedBase);
        };
        dd.setSelectedItem(selected);
        addChild(dd);
        return dd;
    }

    private function createButton(w:Float, h:Float, label:String, primary:Bool):Sprite {
        var btn = new Sprite();
        btn.buttonMode = true;
        btn.useHandCursor = true;
        var text = new TextField();
        text.defaultTextFormat = new TextFormat(ApiStyle.FONT_FAMILY, 9, ApiStyle.COLOR_TEXT_PRIMARY, true);
        text.text = label;
        text.width = w;
        text.height = h - 5;
        text.y = 4;
        text.selectable = false;
        text.mouseEnabled = false;
        text.autoSize = flash.text.TextFieldAutoSize.CENTER;
        text.x = (w - text.width) / 2;
        btn.addChild(text);

        var draw = function(hover:Bool):Void {
            btn.graphics.clear();
            var fill:Int = primary ? (hover ? ApiStyle.COLOR_ACCENT_HOVER : ApiStyle.COLOR_ACCENT_PRIMARY)
                : (hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE);
            var border:Int = primary ? ApiStyle.COLOR_ACCENT_HOVER
                : (hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT);
            btn.graphics.beginFill(fill, 0.96);
            btn.graphics.lineStyle(1, border);
            btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
            btn.graphics.endFill();
        };
        draw(false);
        btn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void draw(true));
        btn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void draw(false));
        return btn;
    }

    private function refreshColors():Void {
        if (_weapon != null) _weapon.updateBtnDisplay();
        if (_helm != null) _helm.updateBtnDisplay();
        if (_cape != null) _cape.updateBtnDisplay();
    }

    private function applyEnhancements():Void {
        if (Api.enhancement == null) return;
        if (Api.enhancement.isBusy) {
            ApiNotificationManager.notify("Enhancement queue is busy.");
            return;
        }
        ApiNotificationManager.notify("Enhancing equipped gear...");
        Api.enhancement.enhanceEquipped(_selectedBase, _selectedCape, _selectedHelm, _selectedWeapon, function():Void {
            ApiNotificationManager.notify("Enhancement complete.");
        });
    }
}
#else
class TopBarEnhancePanel {}
#end
