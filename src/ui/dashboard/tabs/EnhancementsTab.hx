package ui.dashboard.tabs;

#if flash
import com.aqwapi.Api;
import flash.display.Shape;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import ui.ApiDashboardModal;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.EnhancementColors;
import ui.dashboard.IDashboardTab;
import ui.prompts.ApiPrompts;

class EnhancementsTab implements IDashboardTab {
    public function new() {}

    public function render(modal:ApiDashboardModal):Void {
        var curClass = (Api.player != null && Api.player.className != null && Api.player.className != "") ? Api.player.className : "Equipped Class";

        addEnhancementLoadoutCard(modal);

        modal.addSectionHeader("Auto-Enhance");

        // 1. One-Click Smart Enhance (Equipped)
        modal.addItemRow(
            "Smart Enhance (Equipped)",
            "Auto-detects " + curClass + " & unlocks, then enhances equipped weapon, class, helm, and cape to the optimal build.",
            "button",
            "Enhance",
            true, // Primary red button!
            function():Void {
                if (Api.enhancement != null) {
                    if (Api.enhancement.isBusy) {
                        ApiNotificationManager.notify("Enhancement queue is currently busy!");
                        return;
                    }
                    ApiNotificationManager.notify("SmartEnhancing " + curClass + "...");
                    Api.enhancement.smartEnhance(null, function():Void {
                        ApiNotificationManager.notify("SmartEnhance finished!");
                    });
                }
            }
        );

        // 2. Custom Enhance Gear (Modal)
        modal.addItemRow(
            "Custom Enhance Gear...",
            "Choose custom base enhancement types and Awe/Forge special traits for equipped gear.",
            "button",
            "Configure",
            false,
            function():Void {
                ApiPrompts.showCustomEnhancePrompt(modal.overlay);
            }
        );

        modal.addSectionHeader("Enhancement Shops");

        // 3. Lvl 50+ Enhancements
        var lvl50Shops = [
            { name: "Healer Enh", id: 762 },
            { name: "Lucky Enh", id: 763 },
            { name: "Spellbreaker Enh", id: 764 },
            { name: "Wizard Enh", id: 765 },
            { name: "Hybrid Enh", id: 766 },
            { name: "Thief Enh", id: 767 },
            { name: "Fighter Enh", id: 768 }
        ];
        modal.addItemRow(
            "Lvl 50+ Enhancements",
            "Browse and load level 50+ normal enhancement shops.",
            "button",
            "Open Shop",
            false,
            function():Void {
                ApiPrompts.showEnhancementPrompt(modal.overlay, "Lvl 50+ Enhancements", lvl50Shops, false);
            }
        );

        // 4. Awe Enhancements
        var aweShops = [
            { name: "Fighter Awe", id: 635 },
            { name: "Wizard Awe", id: 636 },
            { name: "Thief Awe", id: 637 },
            { name: "Healer Awe", id: 638 },
            { name: "Lucky Awe", id: 639 },
            { name: "Hybrid Awe", id: 633 }
        ];
        modal.addItemRow(
            "Awe Enhancements",
            "Browse and load Blade of Awe enhancement shops.",
            "button",
            "Open Shop",
            false,
            function():Void {
                ApiPrompts.showEnhancementPrompt(modal.overlay, "Awe Enhancements", aweShops, false);
            }
        );

        // 5. Forge Enhancements
        var forgeShops = [
            { name: "Weapon Enh", id: 2142 },
            { name: "Cape Enh", id: 2143 },
            { name: "Helmet Enh", id: 2164 }
        ];
        modal.addItemRow(
            "Forge Enhancements",
            "Browse and load Forge enhancement shops (auto-joins /forge).",
            "button",
            "Open Shop",
            false,
            function():Void {
                ApiPrompts.showEnhancementPrompt(modal.overlay, "Forge Enhancements", forgeShops, true);
            }
        );
    }

    private function addEnhancementLoadoutCard(modal:ApiDashboardModal):Void {
        var rowW:Float = modal.contentWidth - 20;
        var cardH:Float = 88;
        var card = new Sprite();

        var curClass = (Api.player != null && Api.player.className != null && Api.player.className != "") ? Api.player.className : "Equipped Class";
        var playerLvl:Int = (Api.player != null) ? Api.player.level : 100;
        var slots = (Api.enhancement != null) ? Api.enhancement.getEquippedSlots() : null;
        var rec = (Api.enhancement != null) ? Api.enhancement.getRecommendation(curClass) : null;

        var wItem = (slots != null) ? slots.weapon : null;
        var wBase = (wItem != null && Api.enhancement != null) ? Api.enhancement.patternIdToName(wItem.enhPatternId) : "None";
        var wSpec = (Api.enhancement != null) ? Api.enhancement.currentWeaponSpecial() : "None";
        var wName = (wSpec != "None" && wSpec != "") ? wSpec : wBase;
        var wLvl:Int = (wItem != null) ? wItem.enhLevel : 0;

        var cTarget = (slots != null) ? ((slots.classItem != null) ? slots.classItem : slots.armor) : null;
        var cEnh = (Api.enhancement != null) ? Api.enhancement.currentClassEnh() : "None";
        var cLvl:Int = (cTarget != null) ? cTarget.enhLevel : 0;

        var hItem = (slots != null) ? slots.helm : null;
        var hBase = (hItem != null && Api.enhancement != null) ? Api.enhancement.patternIdToName(hItem.enhPatternId) : "None";
        var hSpec = (Api.enhancement != null) ? Api.enhancement.currentHelmSpecial() : "None";
        var hName = (hSpec != "None" && hSpec != "") ? hSpec : hBase;
        var hLvl:Int = (hItem != null) ? hItem.enhLevel : 0;

        var capeItem = (slots != null) ? slots.cape : null;
        var capeBase = (capeItem != null && Api.enhancement != null) ? Api.enhancement.patternIdToName(capeItem.enhPatternId) : "None";
        var capeSpec = (Api.enhancement != null) ? Api.enhancement.currentCapeSpecial() : "None";
        var capeName = (capeSpec != "None" && capeSpec != "") ? capeSpec : capeBase;
        var capeLvl:Int = (capeItem != null) ? capeItem.enhLevel : 0;

        var isOptimal:Bool = false;
        if (rec != null && slots != null) {
            var wMaxLvl = (Api.enhancement != null) ? Api.enhancement.getMaxAvailableLevel("Weapon", rec.type, rec.weapon) : playerLvl;
            var cMaxLvl = (Api.enhancement != null) ? Api.enhancement.getMaxAvailableLevel("ar", rec.type, "None") : playerLvl;
            var hMaxLvl = (Api.enhancement != null) ? Api.enhancement.getMaxAvailableLevel("he", rec.type, rec.helm) : playerLvl;
            var capeMaxLvl = (Api.enhancement != null) ? Api.enhancement.getMaxAvailableLevel("ba", rec.type, rec.cape) : playerLvl;

            var wMatches = (rec.weapon == "None" || rec.weapon == wSpec) && (wLvl >= wMaxLvl);
            var cMatches = (rec.type == cEnh) && (cLvl >= cMaxLvl);
            var hMatches = (rec.helm == "None" || rec.helm == hSpec) && (hLvl >= hMaxLvl);
            var capeMatches = (rec.cape == "None" || rec.cape == capeSpec) && (capeLvl >= capeMaxLvl);
            isOptimal = (wMatches && cMatches && hMatches && capeMatches);
        }

        card.graphics.beginFill(ApiStyle.COLOR_BG_CARD, 1);
        card.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_CARD);
        card.graphics.drawRoundRect(0, 0, rowW, cardH, 6, 6);

        card.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DIVIDER);
        card.graphics.moveTo(12, 28);
        card.graphics.lineTo(rowW - 12, 28);
        card.graphics.endFill();

        var titleTxt = new TextField();
        var titleFmt = new TextFormat(ApiStyle.FONT_FAMILY, 12, ApiStyle.COLOR_TEXT_PRIMARY, true);
        titleTxt.defaultTextFormat = titleFmt;
        titleTxt.text = "Active Loadout: " + curClass + " (Lvl " + playerLvl + ")";
        titleTxt.x = 12;
        titleTxt.y = 7;
        titleTxt.width = rowW - 150;
        titleTxt.height = 18;
        titleTxt.selectable = false;
        titleTxt.mouseEnabled = false;
        card.addChild(titleTxt);

        var tagTxt = new TextField();
        var tagColor:Int = isOptimal ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_STATUS_WARN;
        var tagFmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, tagColor, true);
        tagFmt.align = TextFormatAlign.RIGHT;
        tagTxt.defaultTextFormat = tagFmt;
        tagTxt.text = isOptimal ? "[Optimal]" : "[Upgrade Available]";
        tagTxt.x = rowW - 145;
        tagTxt.y = 7;
        tagTxt.width = 135;
        tagTxt.height = 18;
        tagTxt.selectable = false;
        tagTxt.mouseEnabled = false;
        card.addChild(tagTxt);

        var drawSlotEntry = function(label:String, val:String, lvl:Int, dotColor:Null<Int>, sx:Float, sy:Float, maxW:Float):Void {
            var dot = new Shape();
            dot.graphics.beginFill(dotColor != null ? dotColor : ApiStyle.COLOR_TEXT_MUTED, 1);
            dot.graphics.drawCircle(sx + 4, sy + 7, 3.5);
            dot.graphics.endFill();
            card.addChild(dot);

            var sTxt = new TextField();
            var sFmt = new TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_PRIMARY, false);
            sTxt.defaultTextFormat = sFmt;
            var lvlStr = (lvl > 0) ? " (Lvl " + lvl + ")" : "";
            sTxt.text = label + ": " + val + lvlStr;
            sTxt.x = sx + 12;
            sTxt.y = sy;
            sTxt.width = maxW - 14;
            sTxt.height = 18;
            sTxt.selectable = false;
            sTxt.mouseEnabled = false;
            card.addChild(sTxt);
        };

        var halfW:Float = (rowW - 24) / 2;
        var col1X:Float = 12;
        var col2X:Float = 12 + halfW + 6;

        var wCol = EnhancementColors.getColor(wName, wBase);
        drawSlotEntry("Weapon", wName, wLvl, wCol, col1X, 36, halfW);

        var cCol = EnhancementColors.getColor(cEnh);
        drawSlotEntry("Class", cEnh, cLvl, cCol, col2X, 36, halfW);

        var hCol = EnhancementColors.getColor(hName, hBase);
        drawSlotEntry("Helm", hName, hLvl, hCol, col1X, 58, halfW);

        var capeCol = EnhancementColors.getColor(capeName, capeBase);
        drawSlotEntry("Cape", capeName, capeLvl, capeCol, col2X, 58, halfW);

        card.cacheAsBitmap = true;
        card.x = 0;
        card.y = modal.totalContentHeight;
        modal.contentContainer.addChild(card);

        modal.totalContentHeight += cardH + 10;
        modal.updateScrollbar();
    }
}
#else
class EnhancementsTab implements ui.dashboard.IDashboardTab {
    public function new() {}
    public function render(modal:Dynamic):Void {}
}
#end
