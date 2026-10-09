package ui.prompts;

#if flash
import com.aqwapi.Api;
import com.aqwapi.modules.CombatEngine;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.managers.SkillManager;
import com.aqwapi.utils.ApiConfig;
import com.aqwapi.utils.ApiLogger;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFieldType;
import ui.Dropdown;
import ui.EnhancementColors;
import ui.ApiStyle;
import ui.prompts.combat.CombatModeEditorModal;
import ui.prompts.scripts.ScriptManagerModal;
import ui.components.ClassModeSelector;

class ApiPrompts {
    private static var _lastQuests:String = "";
    private static var _lastCombat:String = "";

    public static function showQuestPrompt(overlay:Dynamic):Void {
        var isRunning:Bool = (Api.quest != null && Api.quest.isAutoRunning);
        var dlg = ApiPromptModal.createDialog(340, 200, "Auto-Quest (Safe Loop)");

        var lblInstruction = ApiPromptModal.createLabel("Enter Quest IDs (comma separated):", 300, 12, true);
        lblInstruction.x = 20;
        lblInstruction.y = 38;
        dlg.addChild(lblInstruction);

        var savedQuests = ApiConfig.getString("api_auto_quest_ids", "");
        if (savedQuests == "" && _lastQuests != "") savedQuests = _lastQuests;
        if (isRunning && Api.quest != null && Api.quest.autoQuestString != "") {
            savedQuests = Api.quest.autoQuestString;
        }

        var input = ApiPromptModal.createInput(300, 26, savedQuests);
        input.x = 20;
        input.y = 62;
        dlg.addChild(input);

        var statusColor = isRunning ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_STATUS_INACTIVE;
        var statusMsg = isRunning ? "Status: Active (Safe looping accept & turn-in)" : "Status: Inactive (Stopped)";
        var lblStatus = ApiPromptModal.createLabel(statusMsg, 300, 11, false);
        lblStatus.x = 20;
        lblStatus.y = 96;
        lblStatus.textColor = statusColor;
        dlg.addChild(lblStatus);

        var btnY = 145;

        if (isRunning) {
            var stopBtn = ApiPromptModal.createButton("Stop Auto-Quest", 140, 32, function():Void {
                if (Api.quest != null) Api.quest.stopAuto();
                ApiNotificationManager.notify("Auto-Quest stopped.");
                ApiPromptModal.close();
            }, true);
            stopBtn.x = 20;
            stopBtn.y = btnY;
            dlg.addChild(stopBtn);

            var updateBtn = ApiPromptModal.createButton("Update IDs", 140, 32, function():Void {
                var txt = StringTools.trim(input.text);
                ApiConfig.setString("api_auto_quest_ids", txt);
                _lastQuests = txt;
                var ids = txt.split(",");
                var validIds:Array<Int> = [];
                for (idStr in ids) {
                    var pQid:Null<Int> = Std.parseInt(StringTools.trim(idStr));
                    var qid = (pQid != null) ? pQid : 0;
                    if (qid > 0) validIds.push(qid);
                }
                if (validIds.length > 0 && Api.quest != null) {
                    Api.quest.startAuto(validIds.join(","));
                    ApiNotificationManager.notify("Auto-Quest updated: " + validIds.join(", "));
                }
                ApiPromptModal.close();
            }, false);
            updateBtn.x = 180;
            updateBtn.y = btnY;
            dlg.addChild(updateBtn);
        } else {
            var startBtn = ApiPromptModal.createButton("Start Loop", 140, 32, function():Void {
                var txt = StringTools.trim(input.text);
                ApiConfig.setString("api_auto_quest_ids", txt);
                _lastQuests = txt;
                var ids = txt.split(",");
                var validIds:Array<Int> = [];
                for (idStr in ids) {
                    var pQid:Null<Int> = Std.parseInt(StringTools.trim(idStr));
                    var qid = (pQid != null) ? pQid : 0;
                    if (qid > 0) validIds.push(qid);
                }
                if (validIds.length > 0 && Api.quest != null) {
                    Api.quest.startAuto(validIds.join(","));
                    ApiNotificationManager.notify("Auto-Quest started: " + validIds.join(", "));
                } else {
                    ApiNotificationManager.notify("Please enter at least one valid Quest ID.");
                }
                ApiPromptModal.close();
            }, true);
            startBtn.x = 20;
            startBtn.y = btnY;
            dlg.addChild(startBtn);

            var cancelBtn = ApiPromptModal.createButton("Cancel", 140, 32, function():Void {
                ApiPromptModal.close();
            }, false);
            cancelBtn.x = 180;
            cancelBtn.y = btnY;
            dlg.addChild(cancelBtn);
        }

        ApiPromptModal.show(overlay, dlg);
    }

    private static var _lastCombatMode:String = "sequence";

    public static function showCombatPrompt(overlay:Dynamic):Void {
        var dlg = ApiPromptModal.createDialog(300, 210, "AutoCombat (Custom)");

        var lblSkills = ApiPromptModal.createLabel("Skills (e.g. 3,1,2,1,2,4):", 200);
        lblSkills.x = 20;
        lblSkills.y = 38;
        dlg.addChild(lblSkills);

        var input = ApiPromptModal.createInput(260, 25, _lastCombat);
        input.x = 20;
        input.y = 58;
        dlg.addChild(input);

        var lblMode = ApiPromptModal.createLabel("Mode:", 60);
        lblMode.x = 20;
        lblMode.y = 98;
        dlg.addChild(lblMode);

        var modeOptions = ["Sequence (ordered)", "Priority (first ready)"];
        var selectedMode = _lastCombatMode;

        var ddMode = new Dropdown(220, 25, modeOptions, function(sel:String):Void {
            selectedMode = (sel.indexOf("Sequence") != -1) ? "sequence" : "priority";
        });
        ddMode.x = 20;
        ddMode.y = 118;
        ddMode.setSelectedItem(selectedMode == "sequence" ? "Sequence (ordered)" : "Priority (first ready)");
        dlg.addChild(ddMode);

        var startBtn = ApiPromptModal.createButton("Start", 120, 30, function():Void {
            _lastCombat = input.text;
            _lastCombatMode = selectedMode;
            var seq = _lastCombat.split(",");
            var validSeq:Array<String> = [];
            for (s in seq) {
                var trimmed = StringTools.trim(s);
                if (trimmed.length > 0) validSeq.push(trimmed);
            }
            if (validSeq.length > 0 && Api.combat != null) {
                Api.combat.startCustom(validSeq.join(","), selectedMode);
            }
            ApiPromptModal.close();
        }, false);
        startBtn.x = 20;
        startBtn.y = 162;
        dlg.addChild(startBtn);

        var cancelBtn = ApiPromptModal.createButton("Cancel", 120, 30, function():Void {
            ApiPromptModal.close();
        }, false);
        cancelBtn.x = 160;
        cancelBtn.y = 162;
        dlg.addChild(cancelBtn);

        ApiPromptModal.show(overlay, dlg);
    }

    public static function showBlacklistPrompt(overlay:Dynamic):Void {
        _renderBlacklistPrompt(overlay);
    }

    private static function _renderBlacklistPrompt(overlay:Dynamic):Void {
        var dlgW:Int = 360;
        var dlgH:Int = 450;
        var dlg = ApiPromptModal.createDialog(dlgW, dlgH, "Item Blacklist");

        // Subtitle / Description
        var desc = ApiPromptModal.createLabel("Items here are never looted and can be mass-sold via 'Sell Blacklisted Items'.", dlgW - 40, 11, false);
        desc.x = 20;
        desc.y = 30;
        desc.wordWrap = true;
        desc.height = 32;
        dlg.addChild(desc);

        // List area
        var listY:Int = 68;
        var listH:Int = 240;
        var listW:Int = dlgW - 40;
        var listContainer = new Sprite();
        listContainer.x = 20;
        listContainer.y = listY;
        listContainer.graphics.beginFill(ApiStyle.COLOR_BG_PANEL, 0.95);
        listContainer.graphics.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT);
        listContainer.graphics.drawRoundRect(0, 0, listW, listH, 6, 6);
        listContainer.graphics.endFill();
        dlg.addChild(listContainer);

        var listMask = new flash.display.Shape();
        listMask.graphics.beginFill(0xFF0000);
        listMask.graphics.drawRoundRect(0, 0, listW, listH, 6, 6);
        listMask.graphics.endFill();
        listContainer.addChild(listMask);

        var listContent = new Sprite();
        listContent.mask = listMask;
        listContainer.addChild(listContent);

        var scrollbarTrack = new flash.display.Shape();
        var scrollbarThumb = new flash.display.Shape();
        listContainer.addChild(scrollbarTrack);
        listContainer.addChild(scrollbarThumb);

        var items = (Api.blacklist != null) ? Api.blacklist.getList() : [];
        var rowH:Int = 28;
        var totalRowsH:Float = items.length * rowH + 8;
        var hasScroll:Bool = (totalRowsH > listH);
        var innerRowW:Float = hasScroll ? (listW - 22) : (listW - 16);

        var updateScrollbar = function():Void {
            scrollbarTrack.graphics.clear();
            scrollbarThumb.graphics.clear();
            if (totalRowsH <= listH) {
                scrollbarTrack.visible = false;
                scrollbarThumb.visible = false;
                return;
            }
            scrollbarTrack.visible = true;
            scrollbarThumb.visible = true;

            var sbW:Float = 4;
            var sbX:Float = listW - sbW - 3;
            scrollbarTrack.graphics.beginFill(ApiStyle.COLOR_BG_SURFACE, 0.7);
            scrollbarTrack.graphics.drawRoundRect(sbX, 4, sbW, listH - 8, 2, 2);
            scrollbarTrack.graphics.endFill();

            var viewRatio:Float = listH / totalRowsH;
            var thumbH:Float = Math.max(16, (listH - 8) * viewRatio);
            var scrollRatio:Float = -listContent.y / (totalRowsH - listH);
            var thumbY:Float = 4 + scrollRatio * (listH - 8 - thumbH);

            scrollbarThumb.graphics.beginFill(ApiStyle.COLOR_BORDER_HIGHLIGHT, 0.9);
            scrollbarThumb.graphics.drawRoundRect(sbX, thumbY, sbW, thumbH, 2, 2);
            scrollbarThumb.graphics.endFill();
        };

        if (items.length == 0) {
            var emptyLbl = ApiPromptModal.createLabel("No items blacklisted yet.", listW - 20, 12, false);
            emptyLbl.x = 14;
            emptyLbl.y = 14;
            listContent.addChild(emptyLbl);
            updateScrollbar();
        } else {
            for (i in 0...items.length) {
                var itemName:String = items[i];
                var row = new Sprite();
                row.x = 8;
                row.y = i * rowH + 6;

                if (i % 2 == 1) {
                    row.graphics.beginFill(ApiStyle.COLOR_BG_CARD, 0.4);
                    row.graphics.drawRoundRect(0, 0, innerRowW, rowH - 4, 4, 4);
                    row.graphics.endFill();
                }

                var lbl = ApiPromptModal.createLabel(itemName, innerRowW - 40, 12, false);
                lbl.x = 8;
                lbl.y = 3;
                lbl.height = 20;
                row.addChild(lbl);

                var removeBtn = ApiPromptModal.createButton("X", 26, 20, function():Void {
                    if (Api.blacklist != null) Api.blacklist.remove(itemName);
                    _renderBlacklistPrompt(overlay);
                }, false);
                removeBtn.x = innerRowW - 30;
                removeBtn.y = 1;
                row.addChild(removeBtn);

                listContent.addChild(row);
            }
            updateScrollbar();

            listContainer.addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent):Void {
                if (totalRowsH <= listH) return;
                var maxScroll:Float = listH - totalRowsH;
                listContent.y += e.delta * 20;
                if (listContent.y > 0) listContent.y = 0;
                if (listContent.y < maxScroll) listContent.y = maxScroll;
                updateScrollbar();
            });

            var isDragging:Bool = false;
            var dragStartY:Float = 0;
            var dragStartContentY:Float = 0;

            listContainer.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
                if (dlg.stage == null || totalRowsH <= listH) return;
                isDragging = false;
                dragStartY = dlg.stage.mouseY;
                dragStartContentY = listContent.y;

                var onMove:MouseEvent->Void = null;
                var onUp:MouseEvent->Void = null;

                onMove = function(me:MouseEvent):Void {
                    if (dlg.stage == null) return;
                    var dy = dlg.stage.mouseY - dragStartY;
                    if (!isDragging && Math.abs(dy) > 4) isDragging = true;
                    if (isDragging) {
                        var newY:Float = dragStartContentY + dy;
                        var maxScroll:Float = listH - totalRowsH;
                        if (newY > 0) newY = 0;
                        if (newY < maxScroll) newY = maxScroll;
                        listContent.y = newY;
                        updateScrollbar();
                    }
                };

                onUp = function(ue:MouseEvent):Void {
                    if (dlg.stage != null) {
                        dlg.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMove);
                        dlg.stage.removeEventListener(MouseEvent.MOUSE_UP, onUp);
                    }
                };

                dlg.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMove);
                dlg.stage.addEventListener(MouseEvent.MOUSE_UP, onUp);
            });
        }

        // Add section
        var addY:Int = listY + listH + 12;
        var addLabel = ApiPromptModal.createLabel("Add item by name:", 200, 11, true);
        addLabel.x = 20;
        addLabel.y = addY;
        addLabel.height = 18;
        dlg.addChild(addLabel);

        var inputW:Int = dlgW - 40 - 74;
        var input = ApiPromptModal.createInput(inputW, 26, "");
        input.x = 20;
        input.y = addY + 18;
        dlg.addChild(input);

        var addBtn = ApiPromptModal.createButton("Add", 66, 26, function():Void {
            var name = StringTools.trim(input.text);
            if (name != "" && Api.blacklist != null) {
                Api.blacklist.add(name);
                _renderBlacklistPrompt(overlay);
            }
        }, false);
        addBtn.x = 20 + inputW + 8;
        addBtn.y = addY + 18;
        dlg.addChild(addBtn);

        // Close button
        var closeBtn = ApiPromptModal.createButton("Close", 120, 30, function():Void {
            ApiPromptModal.close();
        }, false);
        closeBtn.x = (dlgW - 120) / 2;
        closeBtn.y = dlgH - 42;
        dlg.addChild(closeBtn);

        ApiPromptModal.show(overlay, dlg);
    }

    public static function showShopPrompt(overlay:Dynamic):Void {
        var dlg = ApiPromptModal.createDialog(300, 160, "Enter Shop ID:");

        var input = ApiPromptModal.createInput(260, 25, "");
        input.x = 20;
        input.y = 40;
        dlg.addChild(input);

        var loadBtn = ApiPromptModal.createButton("Load", 120, 30, function():Void {
            var pShopId:Null<Int> = Std.parseInt(StringTools.trim(input.text));
            var shopId = (pShopId != null) ? pShopId : 0;
            ApiPromptModal.close();
            if (shopId > 0 && Api.shop != null) {
                Api.shop.loadShop(shopId);
                ApiNotificationManager.notify("Loading Shop: " + shopId);
            }
        }, false);
        loadBtn.x = 20;
        loadBtn.y = 80;
        dlg.addChild(loadBtn);

        var cancelBtn = ApiPromptModal.createButton("Cancel", 120, 30, function():Void {
            ApiPromptModal.close();
        }, false);
        cancelBtn.x = 160;
        cancelBtn.y = 80;
        dlg.addChild(cancelBtn);

        ApiPromptModal.show(overlay, dlg);
    }

    public static function showPastePrompt(overlay:Dynamic):Void {
        var dlg = ApiPromptModal.createDialog(600, 400, "Paste Script Below");

        var input = ApiPromptModal.createInput(560, 300, "", true);
        input.x = 20;
        input.y = 40;
        dlg.addChild(input);

        var loadBtn = ApiPromptModal.createButton("Load Script", 120, 30, function():Void {
            var txt = input.text;
            ApiPromptModal.close();
            ScriptManager.SINGLETON.loadScript(txt);
            ApiNotificationManager.notify("Script loaded successfully!");
        }, false);
        loadBtn.x = 160;
        loadBtn.y = 350;
        dlg.addChild(loadBtn);

        var cancelBtn = ApiPromptModal.createButton("Cancel", 120, 30, function():Void {
            ApiPromptModal.close();
        }, false);
        cancelBtn.x = 320;
        cancelBtn.y = 350;
        dlg.addChild(cancelBtn);

        ApiPromptModal.show(overlay, dlg);
    }

    public static function showEnhancementPrompt(
        overlay:Dynamic,
        promptTitle:String,
        shops:Array<{ name:String, id:Int }>,
        requireForge:Bool = false
    ):Void {
        var dlg = ApiPromptModal.createDialog(340, 180, promptTitle);

        var shopNames:Array<String> = [];
        for (s in shops) shopNames.push(s.name);

        var selectedId:Int = shops.length > 0 ? shops[0].id : 0;
        var selectedName:String = shops.length > 0 ? shops[0].name : "";

        var ddShop = new Dropdown(260, 30, shopNames, function(sel:String):Void {
            selectedName = sel;
            for (s in shops) {
                if (s.name == sel) {
                    selectedId = s.id;
                    break;
                }
            }
        });
        ddShop.x = 40;
        ddShop.y = 55;
        dlg.addChild(ddShop);

        var loadBtn = ApiPromptModal.createButton("Load Shop", 120, 35, function():Void {
            ApiPromptModal.close();
            if (requireForge) {
                if (Api.map != null && Api.map.name != null && Api.map.name.toLowerCase() != "forge") {
                    Api.map.join("forge", "Enter", "Spawn");
                    ApiNotificationManager.notify("Joining forge map...");
                    haxe.Timer.delay(function():Void {
                        if (Api.shop != null) Api.shop.loadShop(selectedId);
                        ApiNotificationManager.notify("Loading Shop: " + selectedName);
                    }, 3500);
                    return;
                }
            }
            if (Api.shop != null) Api.shop.loadShop(selectedId);
            ApiNotificationManager.notify("Loading Shop: " + selectedName);
        }, true);
        loadBtn.x = 40;
        loadBtn.y = 120;
        dlg.addChild(loadBtn);

        var cancelBtn = ApiPromptModal.createButton("Cancel", 100, 35, function():Void {
            ApiPromptModal.close();
        }, false);
        cancelBtn.x = 180;
        cancelBtn.y = 120;
        dlg.addChild(cancelBtn);

        ApiPromptModal.show(overlay, dlg);
    }

    public static function showCustomEnhancePrompt(overlay:Dynamic):Void {
        try {
            var dlg = ApiPromptModal.createDialog(460, 305, "Custom Enhancement Setup");

            var curClass:String = (Api.player != null && Api.player.className != null && Api.player.className != "") ? Api.player.className : "Equipped Class";
            var rec = (Api.enhancement != null) ? Api.enhancement.getRecommendation(curClass) : null;

            var recSummary:String = "Equipped: " + curClass;
            if (rec != null) {
                recSummary += "  |  Optimal: " + rec.type;
                if (rec.weapon != null && rec.weapon != "" && rec.weapon != "None") recSummary += " + " + rec.weapon;
                if (rec.helm != null && rec.helm != "" && rec.helm != "None") recSummary += " / " + rec.helm;
                if (rec.cape != null && rec.cape != "" && rec.cape != "None") recSummary += " / " + rec.cape;
            }

            var lblSummary = ApiPromptModal.createLabel(recSummary, 420, 11, false);
            lblSummary.x = 20;
            lblSummary.y = 38;
            dlg.addChild(lblSummary);

            // Left Column (x=24, w=195): Class Armor & Helm Slot
            var lblBase = ApiPromptModal.createLabel("Class Armor (Base Type):", 195, 12, true);
            lblBase.x = 24;
            lblBase.y = 65;
            dlg.addChild(lblBase);

            var lblHelm = ApiPromptModal.createLabel("Helm Slot (Trait / Base):", 195, 12, true);
            lblHelm.x = 24;
            lblHelm.y = 125;
            dlg.addChild(lblHelm);

            // Right Column (x=240, w=195): Weapon Slot & Cape Slot
            var lblWeapon = ApiPromptModal.createLabel("Weapon Slot (Trait / Special):", 195, 12, true);
            lblWeapon.x = 240;
            lblWeapon.y = 65;
            dlg.addChild(lblWeapon);

            var lblCape = ApiPromptModal.createLabel("Cape Slot (Trait / Base):", 195, 12, true);
            lblCape.x = 240;
            lblCape.y = 125;
            dlg.addChild(lblCape);

            var baseOptions = ["Lucky", "Wizard", "Fighter", "Thief", "Healer", "Hybrid", "Spellbreaker"];
            var weaponOptions = ["None", "Spiral Carve", "Awe Blast", "Health Vamp", "Mana Vamp", "Powerword Die", "Smite", "Valiance", "Arcana's Concerto", "Elysium", "Acheron", "Dauntless", "Praxis", "Ravenous", "Lacerate"];
            var helmOptions = ["None", "Forge", "Vim", "Examen", "Anima", "Pneuma", "Hearty"];
            var capeOptions = ["None", "Forge", "Absolution", "Vainglory", "Avarice", "Penitence", "Lament"];

            var selectedBase:String = (rec != null && rec.type != null) ? rec.type : "Lucky";
            var selectedWeapon:String = (rec != null && rec.weapon != null) ? rec.weapon : "None";
            var selectedHelm:String = (rec != null && rec.helm != null) ? rec.helm : "None";
            var selectedCape:String = (rec != null && rec.cape != null) ? rec.cape : "None";

            var ddBase:Dropdown = null;
            var ddWeapon:Dropdown = null;
            var ddHelm:Dropdown = null;
            var ddCape:Dropdown = null;

            ddBase = new Dropdown(195, 26, baseOptions, function(sel:String):Void {
                selectedBase = sel;
                if (ddWeapon != null) ddWeapon.updateBtnDisplay();
                if (ddHelm != null) ddHelm.updateBtnDisplay();
                if (ddCape != null) ddCape.updateBtnDisplay();
            });
            ddBase.itemColorCallback = function(opt:String):Null<Int> {
                return EnhancementColors.getColor(opt);
            };
            ddBase.x = 24;
            ddBase.y = 85;
            ddBase.setSelectedItem(selectedBase);

            ddWeapon = new Dropdown(195, 26, weaponOptions, function(sel:String):Void {
                selectedWeapon = sel;
            });
            ddWeapon.itemColorCallback = function(opt:String):Null<Int> {
                return EnhancementColors.getColor(opt, selectedBase);
            };
            ddWeapon.x = 240;
            ddWeapon.y = 85;
            ddWeapon.setSelectedItem(selectedWeapon);

            ddHelm = new Dropdown(195, 26, helmOptions, function(sel:String):Void {
                selectedHelm = sel;
            });
            ddHelm.itemColorCallback = function(opt:String):Null<Int> {
                return EnhancementColors.getColor(opt, selectedBase);
            };
            ddHelm.x = 24;
            ddHelm.y = 145;
            ddHelm.setSelectedItem(selectedHelm);

            ddCape = new Dropdown(195, 26, capeOptions, function(sel:String):Void {
                selectedCape = sel;
            });
            ddCape.itemColorCallback = function(opt:String):Null<Int> {
                return EnhancementColors.getColor(opt, selectedBase);
            };
            ddCape.x = 240;
            ddCape.y = 145;
            ddCape.setSelectedItem(selectedCape);

            dlg.addChild(ddBase);
            dlg.addChild(ddWeapon);
            dlg.addChild(ddHelm);
            dlg.addChild(ddCape);

            // Quick Shortcut: Apply Recommended & Base Only (No Forge)
            var bestBtn = ApiPromptModal.createButton("Apply Recommended", 150, 26, function():Void {
                var c = (Api.player != null && Api.player.className != null && Api.player.className != "") ? Api.player.className : "";
                var r = (Api.enhancement != null) ? Api.enhancement.getRecommendation(c) : null;
                if (r != null) {
                    selectedBase = r.type;
                    selectedWeapon = r.weapon;
                    selectedHelm = r.helm;
                    selectedCape = r.cape;
                    ddBase.setSelectedItem(selectedBase);
                    ddWeapon.setSelectedItem(selectedWeapon);
                    ddHelm.setSelectedItem(selectedHelm);
                    ddCape.setSelectedItem(selectedCape);
                    ApiNotificationManager.notify("Applied recommendation: " + r.type);
                }
            }, false);
            bestBtn.x = 65;
            bestBtn.y = 192;
            dlg.addChild(bestBtn);

            var resetBtn = ApiPromptModal.createButton("Base Only (No Forge)", 150, 26, function():Void {
                selectedWeapon = "None";
                selectedHelm = "None";
                selectedCape = "None";
                ddWeapon.setSelectedItem("None");
                ddHelm.setSelectedItem("None");
                ddCape.setSelectedItem("None");
                ApiNotificationManager.notify("Cleared special traits (Base only)");
            }, false);
            resetBtn.x = 235;
            resetBtn.y = 192;
            dlg.addChild(resetBtn);

            // Bottom Action Buttons: Enhance Equipped (Primary Red) & Cancel (Neutral)
            var enhanceBtn = ApiPromptModal.createButton("Enhance Equipped", 180, 36, function():Void {
                ApiPromptModal.close();
                if (Api.enhancement != null) {
                    if (Api.enhancement.isBusy) {
                        ApiNotificationManager.notify("Enhancement queue is currently busy!");
                        return;
                    }
                    ApiNotificationManager.notify("Enhancing: " + selectedBase + " (W:" + selectedWeapon + ", H:" + selectedHelm + ", C:" + selectedCape + ")");
                    Api.enhancement.enhanceEquipped(selectedBase, selectedCape, selectedHelm, selectedWeapon, function():Void {
                        ApiNotificationManager.notify("Custom enhancement complete!");
                    });
                }
            }, true);
            enhanceBtn.x = 75;
            enhanceBtn.y = 245;
            dlg.addChild(enhanceBtn);

            var cancelBtn = ApiPromptModal.createButton("Cancel", 110, 36, function():Void {
                ApiPromptModal.close();
            }, false);
            cancelBtn.x = 275;
            cancelBtn.y = 245;
            dlg.addChild(cancelBtn);

            ApiPromptModal.show(overlay, dlg);
        } catch (e:Dynamic) {
            ApiLogger.error("Prompt", "Error showing custom enhance prompt: " + e);
            ApiNotificationManager.notify("Error: " + e);
        }
    }

    public static function showSmartCombatPrompt(overlay:Dynamic):Void {
        try {
            var dlg = ApiPromptModal.createDialog(460, 230, "Smart Combat Setup (Standalone)");
            var curEquipped = CombatEngine.getCurrentClassName();
            var subText = (curEquipped != "")
                ? "Active class: " + curEquipped + " (For scripts, use Loadouts in Scripts tab)"
                : "Standalone setup. For scripts, use Loadouts in Scripts tab.";
            var lblSub = ApiPromptModal.createLabel(subText, 412, 11);
            lblSub.x = 24;
            lblSub.y = 38;
            lblSub.textColor = ApiStyle.COLOR_TEXT_MUTED;
            dlg.addChild(lblSub);

            var lblClass = ApiPromptModal.createLabel("Class:", 196, 12, true);
            lblClass.x = 24;
            lblClass.y = 66;
            dlg.addChild(lblClass);

            var lblMode = ApiPromptModal.createLabel("Mode:", 196, 12, true);
            lblMode.x = 240;
            lblMode.y = 66;
            dlg.addChild(lblMode);

            var selectedClassStr:String = "Current";
            var selectedModeStr:String = "Auto (First Available)";

            var selector = new ClassModeSelector(196, 196, 26, 20, true, "Auto (First Available)", function(c:String, m:String):Void {
                selectedClassStr = c;
                selectedModeStr = m;
            });
            selector.x = 24;
            selector.y = 88;
            selector.bindConfig("api_smart_class", "api_smart_mode");
            selectedClassStr = selector.selectedClass;
            selectedModeStr = selector.selectedMode;
            dlg.addChild(selector);

            var currentCounter:Bool = CombatEngine.counterHandler;
            var counterBtn:flash.display.Sprite = null;
            var updateCounterBtnText:Void->Void = function():Void {
                if (counterBtn != null) {
                    var lbl:flash.text.TextField = cast counterBtn.getChildByName("label");
                    if (lbl != null) {
                        lbl.text = "Counter Handler: " + (currentCounter ? "ON (Hold Attacks on Reflect/Shields)" : "OFF");
                        lbl.textColor = currentCounter ? ApiStyle.COLOR_STATUS_ACTIVE : ApiStyle.COLOR_TEXT_MUTED;
                    }
                }
            };

            counterBtn = ApiPromptModal.createButton(
                "Counter Handler: " + (currentCounter ? "ON (Hold Attacks on Reflect/Shields)" : "OFF"),
                412, 28, function():Void {
                    currentCounter = !currentCounter;
                    updateCounterBtnText();
                }, false
            );
            counterBtn.x = 24;
            counterBtn.y = 124;
            updateCounterBtnText();
            dlg.addChild(counterBtn);

            var saveBtn = ApiPromptModal.createButton("Save Config", 130, 35, function():Void {
                var saveModeVal = (selectedModeStr == "Auto (First Available)") ? "Auto" : selectedModeStr;
                ApiConfig.setString("api_smart_class", selectedClassStr);
                ApiConfig.setString("api_smart_mode", saveModeVal);
                ApiConfig.setBool("api_counter_handler", currentCounter);
                CombatEngine.counterHandler = currentCounter;
                CombatEngine.smartClass = selectedClassStr;
                CombatEngine.skillMode = saveModeVal;
                if (Api.combat != null) {
                    Api.combat.mode = saveModeVal;
                }
                ApiNotificationManager.notify("Smart Combat: " + selectedClassStr + " [" + saveModeVal + "], Ctr: " + (currentCounter ? "ON" : "OFF"));
                ApiPromptModal.close();
            }, true);
            saveBtn.x = 26;
            saveBtn.y = 165;
            dlg.addChild(saveBtn);

            var editModesBtn = ApiPromptModal.createButton("Edit Modes", 130, 35, function():Void {
                ApiPromptModal.close();
                showCombatModeEditorPrompt(overlay, selectedClassStr, selectedModeStr);
            }, false);
            editModesBtn.x = 175;
            editModesBtn.y = 165;
            dlg.addChild(editModesBtn);

            var cancelBtn = ApiPromptModal.createButton("Cancel", 110, 35, function():Void {
                ApiPromptModal.close();
            }, false);
            cancelBtn.x = 324;
            cancelBtn.y = 165;
            dlg.addChild(cancelBtn);

            ApiPromptModal.show(overlay, dlg);
        } catch (e:Dynamic) {
            var stackTrace:String = "";
            #if flash
            if (Std.isOfType(e, flash.errors.Error)) {
                stackTrace = "\n" + (cast e : flash.errors.Error).getStackTrace();
            }
            #end
            ApiLogger.error("Prompt", "Failed to show AutoCombat setup prompt: " + e + stackTrace);
            ApiNotificationManager.notify("Error opening setup: " + e);
        }
    }

    public static inline function showCombatModeEditorPrompt(overlay:Dynamic, initialClass:String = null, initialMode:String = null):Void {
        CombatModeEditorModal.show(overlay, initialClass, initialMode);
    }

    public static function showLoadoutsPrompt(overlay:Dynamic):Void {
        try {
            var dlg = ApiPromptModal.createDialog(460, 390, "Class Loadouts (For Scripts)");

            var availableClasses = getAvailableClasses();
            if (availableClasses == null || availableClasses.length == 0) availableClasses = ["Current"];

            var lblClassHdr = ApiPromptModal.createLabel("Class:", 210, 11, true);
            lblClassHdr.x = 24;
            lblClassHdr.y = 34;
            lblClassHdr.textColor = ApiStyle.COLOR_TEXT_MUTED;
            dlg.addChild(lblClassHdr);

            var lblModeHdr = ApiPromptModal.createLabel("Combat Mode:", 188, 11, true);
            lblModeHdr.x = 248;
            lblModeHdr.y = 34;
            lblModeHdr.textColor = ApiStyle.COLOR_TEXT_MUTED;
            dlg.addChild(lblModeHdr);

            setupLoadoutRow(dlg, "FARM Loadout:", 52, 74, availableClasses, "api_farm_class", "api_farm_mode", function(c:String, m:String):Void {
                CombatEngine.farmClass = c;
                CombatEngine.farmMode = m;
            });

            setupLoadoutRow(dlg, "SOLO Loadout:", 116, 138, availableClasses, "api_solo_class", "api_solo_mode", function(c:String, m:String):Void {
                CombatEngine.soloClass = c;
                CombatEngine.soloMode = m;
            });

            setupLoadoutRow(dlg, "BOSS Loadout:", 180, 202, availableClasses, "api_boss_class", "api_boss_mode", function(c:String, m:String):Void {
                CombatEngine.bossClass = c;
                CombatEngine.bossMode = m;
            });

            setupLoadoutRow(dlg, "DODGE Loadout:", 244, 266, availableClasses, "api_dodge_class", "api_dodge_mode", function(c:String, m:String):Void {
                CombatEngine.dodgeClass = c;
                CombatEngine.dodgeMode = m;
            });

            var doneBtn = ApiPromptModal.createButton("Done", 150, 35, function():Void {
                ApiPromptModal.close();
                ApiNotificationManager.notify("Class Loadouts Saved!");
            }, true);
            doneBtn.x = 155;
            doneBtn.y = 335;
            dlg.addChild(doneBtn);

            ApiPromptModal.show(overlay, dlg);
        } catch (e:Dynamic) {
            var stackTrace:String = "";
            #if flash
            if (Std.isOfType(e, flash.errors.Error)) {
                stackTrace = "\n" + (cast e : flash.errors.Error).getStackTrace();
            }
            #end
            ApiLogger.error("Prompt", "Failed to show Class Loadouts prompt: " + e + stackTrace);
            ApiNotificationManager.notify("Error opening loadouts: " + e);
        }
    }

    private static function setupLoadoutRow(
        dlg:Sprite,
        title:String,
        lblY:Float,
        ddY:Float,
        classes:Array<String>,
        classKey:String,
        modeKey:String,
        onUpdate:String->String->Void
    ):Void {
        var lbl = ApiPromptModal.createLabel(title, 210, 14, true);
        lbl.x = 24;
        lbl.y = lblY;
        dlg.addChild(lbl);

        var selector = new ClassModeSelector(215, 188, 25, 9, false, "Auto (First Available)", onUpdate);
        selector.x = 24;
        selector.y = ddY;
        selector.bindConfig(classKey, modeKey);
        dlg.addChild(selector);
    }

    public static var lastInventoryClassKeys(get, never):Map<String, Bool>;
    private static inline function get_lastInventoryClassKeys():Map<String, Bool> {
        return ClassModeSelector.lastInventoryClassKeys;
    }

    public static inline function getAvailableClasses(includeAllKnown:Bool = true):Array<String> {
        return ClassModeSelector.getAvailableClasses(includeAllKnown);
    }

    public static inline function getCurrentClass():String {
        return ClassModeSelector.getCurrentClass();
    }

    public static inline function showScriptManager(overlay:Dynamic):Void {
        ScriptManagerModal.show(overlay);
    }
}
#else
class ApiPrompts {
    public static function showCombatModeEditorPrompt(overlay:Dynamic, initialClass:String = null, initialMode:String = null):Void {}
    public static function showScriptManager(overlay:Dynamic):Void {}
    public static function getAvailableClasses(includeAllKnown:Bool = true):Array<String> return ["Current"];
    public static function getCurrentClass():String return "";
}
#end

