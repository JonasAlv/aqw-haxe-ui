package ui.prompts;

#if flash
import com.aqwapi.Api;
import com.aqwapi.modules.CombatEngine;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.managers.SkillManager;
import com.aqwapi.utils.ApiLogger;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFieldType;
import ui.Dropdown;
import ui.EnhancementColors;
import util.HelperSetting;

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

        var savedQuests = HelperSetting.getString("api_auto_quest_ids", "");
        if (savedQuests == "" && _lastQuests != "") savedQuests = _lastQuests;
        if (isRunning && Api.quest != null && Api.quest.autoQuestString != "") {
            savedQuests = Api.quest.autoQuestString;
        }

        var input = ApiPromptModal.createInput(300, 26, savedQuests);
        input.x = 20;
        input.y = 62;
        dlg.addChild(input);

        var statusColor = isRunning ? 0x00FF88 : 0x888888;
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
                HelperSetting.setString("api_auto_quest_ids", txt);
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
                HelperSetting.setString("api_auto_quest_ids", txt);
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
        listContainer.graphics.beginFill(0x161616, 0.95);
        listContainer.graphics.lineStyle(1, 0x333333);
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
            scrollbarTrack.graphics.beginFill(0x222222, 0.7);
            scrollbarTrack.graphics.drawRoundRect(sbX, 4, sbW, listH - 8, 2, 2);
            scrollbarTrack.graphics.endFill();

            var viewRatio:Float = listH / totalRowsH;
            var thumbH:Float = Math.max(16, (listH - 8) * viewRatio);
            var scrollRatio:Float = -listContent.y / (totalRowsH - listH);
            var thumbY:Float = 4 + scrollRatio * (listH - 8 - thumbH);

            scrollbarThumb.graphics.beginFill(0x666666, 0.9);
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
                    row.graphics.beginFill(0x222222, 0.4);
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
            lblSub.textColor = 0x888888;
            dlg.addChild(lblSub);

            var lblClass = ApiPromptModal.createLabel("Class:", 196, 12, true);
            lblClass.x = 24;
            lblClass.y = 66;
            dlg.addChild(lblClass);

            var lblMode = ApiPromptModal.createLabel("Mode:", 196, 12, true);
            lblMode.x = 240;
            lblMode.y = 66;
            dlg.addChild(lblMode);

            var availableClasses = getAvailableClasses();
            if (availableClasses == null || availableClasses.length == 0) availableClasses = ["Current"];

            var selectedClassStr = HelperSetting.getString("api_smart_class", "Current");
            if (selectedClassStr == "" || availableClasses.indexOf(selectedClassStr) == -1) {
                selectedClassStr = "Current";
            }

            var getModesForClass = function(cName:String):Array<String> {
                var modes:Array<String> = [];
                var isCurrent = (cName == null || cName == "" || cName.toLowerCase() == "current");
                if (isCurrent) {
                    modes.push("Auto (First Available)");
                    var curName = CombatEngine.getCurrentClassName();
                    if (curName != "") {
                        try {
                            var detectedModes = CombatEngine.getAvailableModes(curName);
                            if (detectedModes != null) {
                                for (m in detectedModes) if (modes.indexOf(m) == -1) modes.push(m);
                            }
                        } catch (_:Dynamic) {}
                    }
                } else {
                    try {
                        modes = CombatEngine.getAvailableModes(cName);
                    } catch (_:Dynamic) {}
                }
                if (modes == null || modes.length == 0) modes = ["Base"];
                return modes;
            };

            var availableModes:Array<String> = getModesForClass(selectedClassStr);
            var selectedModeStr = HelperSetting.getString("api_smart_mode", "Auto");
            if (selectedClassStr == "Current" && (selectedModeStr == "" || selectedModeStr == "Auto")) {
                selectedModeStr = "Auto (First Available)";
            } else if (selectedModeStr == null || selectedModeStr == "" || availableModes.indexOf(selectedModeStr) == -1) {
                selectedModeStr = availableModes.length > 0 ? availableModes[0] : "Base";
            }

            var ddMode:Dropdown = null;
            ddMode = new Dropdown(196, 26, availableModes, function(sel:String):Void {
                selectedModeStr = sel;
            });
            ddMode.x = 240;
            ddMode.y = 88;
            ddMode.setSelectedItem(selectedModeStr);

            var ddClass:Dropdown = null;
            ddClass = new Dropdown(196, 26, availableClasses, function(sel:String):Void {
                selectedClassStr = sel;
                var modes = getModesForClass(selectedClassStr);
                ddMode.setOptions(modes);
                if (modes.indexOf(selectedModeStr) == -1) {
                    selectedModeStr = (selectedClassStr == "Current") ? "Auto (First Available)" : (modes.length > 0 ? modes[0] : "Base");
                }
                ddMode.setSelectedItem(selectedModeStr);
            });
            ddClass.x = 24;
            ddClass.y = 88;
            ddClass.setSelectedItem(selectedClassStr);

            dlg.addChild(ddMode);
            dlg.addChild(ddClass);

            var saveBtn = ApiPromptModal.createButton("Save Config", 130, 35, function():Void {
                var saveModeVal = (selectedModeStr == "Auto (First Available)") ? "Auto" : selectedModeStr;
                HelperSetting.setString("api_smart_class", selectedClassStr);
                HelperSetting.setString("api_smart_mode", saveModeVal);
                CombatEngine.smartClass = selectedClassStr;
                CombatEngine.skillMode = saveModeVal;
                if (Api.combat != null) {
                    Api.combat.mode = saveModeVal;
                }
                ApiNotificationManager.notify("Smart Combat Config: " + selectedClassStr + " [" + saveModeVal + "]");
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

    public static function showCombatModeEditorPrompt(overlay:Dynamic, initialClass:String = null, initialMode:String = null):Void {
        try {
            try { SkillManager.ensureStorageInitialized(); } catch (_:Dynamic) {}
            var dlg = ApiPromptModal.createDialog(800, 496, "Combat Mode Editor");

            // Gather class options (Strictly classes currently in inventory + Current)
            var classOptions:Array<String> = getAvailableClasses();
            var curEquipped = CombatEngine.getCurrentClassName();
            var selectedClass = (initialClass != null && initialClass != "" && classOptions.indexOf(initialClass) != -1)
                ? initialClass
                : "Current";
            if (selectedClass == null || selectedClass == "" || classOptions.indexOf(selectedClass) == -1) {
                selectedClass = classOptions.length > 0 ? classOptions[0] : "Current";
            }

            var initialInputClass = selectedClass;
            if (selectedClass.toLowerCase() == "current" && curEquipped != null && curEquipped != "" && curEquipped.toLowerCase() != "current") {
                initialInputClass = curEquipped;
            }

            var lblClass = ApiPromptModal.createLabel("Select Class:", 120);
            lblClass.x = 25;
            lblClass.y = 40;
            dlg.addChild(lblClass);

            var lblCustomClass = ApiPromptModal.createLabel("Class Name:", 120);
            lblCustomClass.x = 240;
            lblCustomClass.y = 40;
            dlg.addChild(lblCustomClass);

            var inputClass = ApiPromptModal.createInput(455, 26, initialInputClass);
            inputClass.x = 240;
            inputClass.y = 60;
            dlg.addChild(inputClass);

            var lblMode = ApiPromptModal.createLabel("Select Mode:", 120);
            lblMode.x = 25;
            lblMode.y = 88;
            dlg.addChild(lblMode);

            var lblCustomMode = ApiPromptModal.createLabel("Mode Name:", 120);
            lblCustomMode.x = 240;
            lblCustomMode.y = 88;
            dlg.addChild(lblCustomMode);

            var inputMode = ApiPromptModal.createInput(455, 26, "Base");
            inputMode.x = 240;
            inputMode.y = 108;
            dlg.addChild(inputMode);

            var lblExecMode = ApiPromptModal.createLabel("Execution Mode:", 120);
            lblExecMode.x = 25;
            lblExecMode.y = 136;
            dlg.addChild(lblExecMode);

            var lblTimeout = ApiPromptModal.createLabel("Timeout (ms):", 90);
            lblTimeout.x = 240;
            lblTimeout.y = 136;
            dlg.addChild(lblTimeout);

            var inputTimeout = ApiPromptModal.createInput(70, 26, "0");
            inputTimeout.x = 240;
            inputTimeout.y = 156;
            dlg.addChild(inputTimeout);

            var currentResetOnTarget:Bool = false;
            var btnResetTarget:flash.display.Sprite = null;
            var updateResetTargetBtn = function():Void {
                if (btnResetTarget == null) return;
                var txt = (btnResetTarget.numChildren > 0 && Std.isOfType(btnResetTarget.getChildAt(0), flash.text.TextField))
                    ? cast(btnResetTarget.getChildAt(0), flash.text.TextField)
                    : null;
                if (txt != null) {
                    txt.text = currentResetOnTarget ? "Reset: ON" : "Reset: OFF";
                    txt.textColor = currentResetOnTarget ? 0x55FF55 : 0xAAAAAA;
                }
            };

            btnResetTarget = ApiPromptModal.createButton("Reset: OFF", 130, 26, function():Void {
                currentResetOnTarget = !currentResetOnTarget;
                updateResetTargetBtn();
            }, false);
            btnResetTarget.x = 325;
            btnResetTarget.y = 156;
            dlg.addChild(btnResetTarget);

            // Tri-state Auto Attack: null = inherit (the class default decides), true/false = mode
            // override. The mode is the more specific setting, so it always wins; the class object is
            // only a default for modes that do not declare their own. That is why "Mode ON" is
            // meaningful here unconditionally - it used to be greyed out whenever the class had a flag.
            var currentAutoAttack:Null<Bool> = null;
            var btnAutoAttack:flash.display.Sprite = null;
            var updateAutoAttackBtn = function():Void {
                if (btnAutoAttack == null) return;
                var txt = (btnAutoAttack.numChildren > 0 && Std.isOfType(btnAutoAttack.getChildAt(0), flash.text.TextField))
                    ? cast(btnAutoAttack.getChildAt(0), flash.text.TextField)
                    : null;
                if (txt == null) return;
                if (currentAutoAttack == null) {
                    txt.text = "AA: Inherit";
                    txt.textColor = 0xAAAAAA;
                } else if (currentAutoAttack == true) {
                    txt.text = "AA: Mode ON";
                    txt.textColor = 0x55FF55;
                } else {
                    txt.text = "AA: Mode OFF";
                    txt.textColor = 0xFFAA55;
                }
            };

            btnAutoAttack = ApiPromptModal.createButton("AA: Inherit", 155, 26, function():Void {
                currentAutoAttack = (currentAutoAttack == null) ? true : ((currentAutoAttack == true) ? false : null);
                updateAutoAttackBtn();
            }, false);
            btnAutoAttack.x = 465;
            btnAutoAttack.y = 156;
            dlg.addChild(btnAutoAttack);

            // Full-width on its own line: the badge text carries the class-level AA state as a
            // suffix, so "[Bundled Mode]  (Class AA: OFF)" is far wider than a column slot allowed
            // and used to be clipped at the right edge.
            var lblBadge = ApiPromptModal.createLabel("[Bundled Mode]", 750, 13, true);
            lblBadge.x = 25;
            lblBadge.y = 192;
            dlg.addChild(lblBadge);

            var lblStopAuras = ApiPromptModal.createLabel("Stop on Target Auras (Reflect / Shields):", 500);
            lblStopAuras.x = 25;
            lblStopAuras.y = 214;
            dlg.addChild(lblStopAuras);

            var inputStopAuras = ApiPromptModal.createInput(560, 24, "");
            inputStopAuras.x = 25;
            inputStopAuras.y = 234;
            dlg.addChild(inputStopAuras);

            var lblCombo = ApiPromptModal.createLabel("Skill Combo / Rotation (1-Liner DSL):", 400);
            lblCombo.x = 25;
            lblCombo.y = 262;
            dlg.addChild(lblCombo);

            var inputCombo = ApiPromptModal.createInput(750, 50, "", true);
            inputCombo.x = 25;
            inputCombo.y = 282;
            dlg.addChild(inputCombo);

            var ddExecMode:Dropdown = null;
            var ddMode:Dropdown = null;
            var ddClass:Dropdown = null;
            var helperButtons:Array<flash.display.Sprite> = [];
            helperButtons.push(btnResetTarget);
            helperButtons.push(btnAutoAttack);
            var saveBtn:flash.display.Sprite = null;
            var applyBtn:flash.display.Sprite = null;
            var delBtn:flash.display.Sprite = null;
            var cloneBtn:flash.display.Sprite = null;

            var setInputEnabled = function(tf:TextField, enabled:Bool):Void {
                if (tf == null) return;
                #if flash
                tf.type = enabled ? flash.text.TextFieldType.INPUT : flash.text.TextFieldType.DYNAMIC;
                #end
                tf.selectable = true;
                tf.mouseEnabled = true;
                tf.backgroundColor = enabled ? 0x222222 : 0x141414;
                tf.borderColor = enabled ? 0x555555 : 0x333333;
                tf.textColor = enabled ? 0xFFFFFF : 0xAAAAAA;
                tf.alpha = enabled ? 1.0 : 0.8;
            };

            var setButtonEnabled = function(btn:flash.display.Sprite, enabled:Bool):Void {
                if (btn == null) return;
                btn.mouseEnabled = enabled;
                btn.mouseChildren = false;
                btn.buttonMode = enabled;
                btn.alpha = enabled ? 1.0 : 0.35;
            };

            var setFormEditable = function(isEditable:Bool, isNewMode:Bool):Void {
                setInputEnabled(inputClass, isEditable);
                setInputEnabled(inputMode, isEditable);
                setInputEnabled(inputTimeout, isEditable);
                setInputEnabled(inputStopAuras, isEditable);
                setInputEnabled(inputCombo, isEditable);

                if (ddExecMode != null) {
                    ddExecMode.mouseEnabled = isEditable;
                    ddExecMode.mouseChildren = isEditable;
                    ddExecMode.alpha = isEditable ? 1.0 : 0.4;
                }

                if (helperButtons != null) {
                    for (b in helperButtons) {
                        setButtonEnabled(b, isEditable);
                    }
                }

                setButtonEnabled(saveBtn, isEditable);
                setButtonEnabled(delBtn, isEditable && !isNewMode);
                setButtonEnabled(applyBtn, !isNewMode);

                if (cloneBtn != null) {
                    cloneBtn.visible = (!isEditable && !isNewMode);
                }
                if (delBtn != null) {
                    delBtn.visible = (isEditable && !isNewMode);
                }
            };

            var loadModeDetails = function(cName:String, mName:String):Void {
                if (mName == null || mName == "" || mName == "[+ New Mode]") {
                    if (inputMode != null) inputMode.text = "CustomMode";
                    if (ddExecMode != null) ddExecMode.setSelectedItem("WaitForCooldown");
                    if (inputTimeout != null) inputTimeout.text = "0";
                    currentResetOnTarget = false;
                    updateResetTargetBtn();
                    currentAutoAttack = null;
                    updateAutoAttackBtn();
                    if (inputStopAuras != null) inputStopAuras.text = "";
                    if (inputCombo != null) inputCombo.text = "";
                    if (lblBadge != null) {
                        lblBadge.text = "[New Mode]";
                        lblBadge.textColor = 0x55FF55;
                    }
                    setFormEditable(true, true);
                    return;
                }

                var effectiveClass = cName;
                if (effectiveClass == null || effectiveClass == "" || effectiveClass.toLowerCase() == "current") {
                    var cur = CombatEngine.getCurrentClassName();
                    if (cur != null && cur != "" && cur.toLowerCase() != "current") {
                        effectiveClass = cur;
                    }
                }

                if (inputMode != null) inputMode.text = (mName != null) ? mName : "";
                var details = SkillManager.getModeDetails(effectiveClass, mName);
                if (details == null && effectiveClass != cName) {
                    details = SkillManager.getModeDetails(cName, mName);
                }
                if (details != null) {
                    if (ddExecMode != null) {
                        var eMode:String = (details.skillUseMode != null && details.skillUseMode != "") ? details.skillUseMode : "WaitForCooldown";
                        ddExecMode.setSelectedItem(eMode);
                    }
                    if (inputTimeout != null) {
                        var toVal:Int = (details.timeout != null) ? details.timeout : 0;
                        inputTimeout.text = (toVal > 1500) ? Std.string(toVal) : "0";
                    }
                    if (inputStopAuras != null) inputStopAuras.text = (details.stopOnTargetAuras != null) ? details.stopOnTargetAuras : "";
                    if (inputCombo != null) inputCombo.text = (details.combo != null) ? details.combo : "";

                    currentResetOnTarget = (details.resetComboOnTargetChange == true);
                    updateResetTargetBtn();

                    var aaRaw = (details != null && details.autoattack != null) ? details.autoattack : null;
                    currentAutoAttack = (aaRaw == true) ? true : ((aaRaw == false) ? false : null);
                    updateAutoAttackBtn();

                    var isUser:Bool = (details.isUser == true) || SkillManager.isUserMode(effectiveClass, mName) || SkillManager.isUserMode(cName, mName);
                    if (lblBadge != null) {
                        // Surface a class-level flag too: it outranks whatever this mode says.
                        var classAA = SkillManager.getClassAutoAttackFlag(effectiveClass);
                        var aaSuffix = (classAA == null) ? "" : (classAA ? "  (Class AA: ON)" : "  (Class AA: OFF)");
                        if (isUser) {
                            lblBadge.text = "[User Mode]" + aaSuffix;
                            lblBadge.textColor = 0x00D9FF;
                        } else {
                            lblBadge.text = "[Bundled Mode]" + aaSuffix;
                            lblBadge.textColor = 0x888888;
                        }
                    }
                    setFormEditable(isUser, false);
                } else {
                    if (ddExecMode != null) ddExecMode.setSelectedItem("WaitForCooldown");
                    if (inputTimeout != null) inputTimeout.text = "0";
                    currentResetOnTarget = false;
                    updateResetTargetBtn();
                    currentAutoAttack = null;
                    updateAutoAttackBtn();
                    if (inputStopAuras != null) inputStopAuras.text = "";
                    if (inputCombo != null) inputCombo.text = "";
                    if (lblBadge != null) {
                        lblBadge.text = "[New Mode]";
                        lblBadge.textColor = 0x55FF55;
                    }
                    setFormEditable(true, true);
                }
            };

            var getModeListForClass = function(cName:String):Array<String> {
                var list:Array<String> = [];
                try {
                    var modes = CombatEngine.getAvailableModes(cName);
                    if (modes != null) {
                        for (m in modes) {
                            // "Auto" is a resolver sentinel ("use the class default"), not a mode
                            // that can be edited - no class defines one, so never offer it here.
                            if (m != null && m != "" && m.toLowerCase() != "auto" && list.indexOf(m) == -1) list.push(m);
                        }
                    }
                } catch (_:Dynamic) {}
                list.push("[+ New Mode]");
                return list;
            };

            ddExecMode = new Dropdown(190, 26, ["WaitForCooldown", "UseIfAvailable"], function(sel:String):Void {});
            ddExecMode.x = 25;
            ddExecMode.y = 156;
            ddExecMode.setSelectedItem("WaitForCooldown");

            var initialModes = getModeListForClass(selectedClass);
            var initialSelMode = (initialMode != null && initialMode != "" && initialModes.indexOf(initialMode) != -1) ? initialMode : (initialModes.length > 0 ? initialModes[0] : "[+ New Mode]");

            ddMode = new Dropdown(190, 26, initialModes, function(selMode:String):Void {
                var currentClass = (inputClass != null && inputClass.text != null) ? StringTools.trim(inputClass.text) : "";
                if (currentClass == "") currentClass = selectedClass;
                loadModeDetails(currentClass, selMode);
            });
            ddMode.x = 25;
            ddMode.y = 108;
            ddMode.setSelectedItem(initialSelMode);

            ddClass = new Dropdown(190, 26, classOptions, function(selClass:String):Void {
                selectedClass = selClass;
                if (inputClass != null) {
                    if (selClass.toLowerCase() == "current") {
                        var cur = CombatEngine.getCurrentClassName();
                        inputClass.text = (cur != null && cur != "" && cur.toLowerCase() != "current") ? cur : "";
                    } else {
                        inputClass.text = selClass;
                    }
                }

                var modes = getModeListForClass(selClass);
                if (ddMode != null) ddMode.setOptions(modes);
                var firstMode = (modes.length > 0 && modes[0] != null) ? modes[0] : "[+ New Mode]";
                if (ddMode != null) ddMode.setSelectedItem(firstMode);
                loadModeDetails(selClass, firstMode);
            });
            ddClass.x = 25;
            ddClass.y = 60;
            ddClass.setSelectedItem(classOptions.indexOf(selectedClass) != -1 ? selectedClass : (classOptions.length > 0 ? classOptions[0] : ""));

            dlg.addChild(ddExecMode);
            dlg.addChild(ddMode);
            dlg.addChild(ddClass);

            var appendSkill = function(sid:String):Void {
                var cur = StringTools.trim(inputCombo.text);
                if (cur.length == 0) {
                    inputCombo.text = sid;
                } else if (StringTools.endsWith(cur, ">")) {
                    inputCombo.text = cur + " " + sid;
                } else {
                    inputCombo.text = cur + " > " + sid;
                }
            };

            var appendRule = function(rule:String):Void {
                var cur = StringTools.trim(inputCombo.text);
                if (cur.length == 0) {
                    inputCombo.text = "1" + rule;
                } else if (StringTools.endsWith(cur, ">")) {
                    inputCombo.text = cur + " 1" + rule;
                } else {
                    if (StringTools.endsWith(cur, "]")) {
                        var innerRule = rule.substring(1, rule.length - 1);
                        inputCombo.text = cur.substring(0, cur.length - 1) + " & " + innerRule + "]";
                    } else {
                        inputCombo.text = cur + rule;
                    }
                }
            };

            // Quick helper row 1: skills and basic operators
            var b1 = ApiPromptModal.createButton("+1", 33, 24, function() appendSkill("1"), false);
            b1.x = 25; b1.y = 350; dlg.addChild(b1); helperButtons.push(b1);

            var b2 = ApiPromptModal.createButton("+2", 33, 24, function() appendSkill("2"), false);
            b2.x = 64; b2.y = 350; dlg.addChild(b2); helperButtons.push(b2);

            var b3 = ApiPromptModal.createButton("+3", 33, 24, function() appendSkill("3"), false);
            b3.x = 103; b3.y = 350; dlg.addChild(b3); helperButtons.push(b3);

            var b4 = ApiPromptModal.createButton("+4", 33, 24, function() appendSkill("4"), false);
            b4.x = 142; b4.y = 350; dlg.addChild(b4); helperButtons.push(b4);

            var b5 = ApiPromptModal.createButton("+5", 33, 24, function() appendSkill("5"), false);
            b5.x = 181; b5.y = 350; dlg.addChild(b5); helperButtons.push(b5);

            var bArrow = ApiPromptModal.createButton("+ >", 40, 24, function():Void {
                var cur = StringTools.trim(inputCombo.text);
                if (cur.length > 0 && !StringTools.endsWith(cur, ">")) {
                    inputCombo.text = cur + " >";
                }
            }, false);
            bArrow.x = 234; bArrow.y = 350; dlg.addChild(bArrow); helperButtons.push(bArrow);

            var b14 = ApiPromptModal.createButton("+ 1-4", 55, 24, function():Void {
                var cur = StringTools.trim(inputCombo.text);
                if (cur.length == 0) {
                    inputCombo.text = "1 > 2 > 3 > 4";
                } else if (StringTools.endsWith(cur, ">")) {
                    inputCombo.text = cur + " 1 > 2 > 3 > 4";
                } else {
                    inputCombo.text = cur + " > 1 > 2 > 3 > 4";
                }
            }, false);
            b14.x = 294; b14.y = 350; dlg.addChild(b14); helperButtons.push(b14);

            var bClear = ApiPromptModal.createButton("Clear", 55, 24, function():Void {
                inputCombo.text = "";
            }, false);
            bClear.x = 355; bClear.y = 350; dlg.addChild(bClear); helperButtons.push(bClear);

            var bHp = ApiPromptModal.createButton("+[hp < 50%]", 100, 24, function() appendRule("[hp < 50%]"), false);
            bHp.x = 430; bHp.y = 350; dlg.addChild(bHp); helperButtons.push(bHp);

            var bTgtHp = ApiPromptModal.createButton("+[tgt:hp < 50%]", 130, 24, function() appendRule("[tgt:hp < 50%]"), false);
            bTgtHp.x = 536; bTgtHp.y = 350; dlg.addChild(bTgtHp); helperButtons.push(bTgtHp);

            var bMp = ApiPromptModal.createButton("+[mp < 20%]", 100, 24, function() appendRule("[mp < 20%]"), false);
            bMp.x = 672; bMp.y = 350; dlg.addChild(bMp); helperButtons.push(bMp);

            // Quick helper row 2: auras and conditions
            var bAuraSelf = ApiPromptModal.createButton("+[!aura(self:Name)]", 160, 24, function() appendRule("[!aura(self:Name)]"), false);
            bAuraSelf.x = 25; bAuraSelf.y = 380; dlg.addChild(bAuraSelf); helperButtons.push(bAuraSelf);

            var bAuraTgt = ApiPromptModal.createButton("+[aura(target:Name)]", 168, 24, function() appendRule("[aura(target:Name)]"), false);
            bAuraTgt.x = 191; bAuraTgt.y = 380; dlg.addChild(bAuraTgt); helperButtons.push(bAuraTgt);

            var bAuraTime = ApiPromptModal.createButton("+[auraTime(self:Name)]", 183, 24, function() appendRule("[auraTime(self:Name) <= 1.5s]"), false);
            bAuraTime.x = 365; bAuraTime.y = 380; dlg.addChild(bAuraTime); helperButtons.push(bAuraTime);

            var bParty = ApiPromptModal.createButton("+[party:hp < 50%]", 145, 24, function() appendRule("[party:hp < 50%]"), false);
            bParty.x = 554; bParty.y = 380; dlg.addChild(bParty); helperButtons.push(bParty);

            var bWait = ApiPromptModal.createButton("+wait", 55, 24, function() appendRule("[wait(500ms)]"), false);
            bWait.x = 705; bWait.y = 380; dlg.addChild(bWait); helperButtons.push(bWait);

            // Counter rule: gates the slot until the mob's attack has resolved against us. Driven by the
            // server's hit packet, so a dodged, missed or parried swing all count equally.
            var bCounter = ApiPromptModal.createButton("+[counter <= 1.5s]", 153, 24, function() appendRule("[counter <= 1.5s]"), false);
            bCounter.x = 25; bCounter.y = 410; dlg.addChild(bCounter); helperButtons.push(bCounter);

            var bCounterPlain = ApiPromptModal.createButton("+[counter]", 93, 24, function() appendRule("[counter]"), false);
            bCounterPlain.x = 186; bCounterPlain.y = 410; dlg.addChild(bCounterPlain); helperButtons.push(bCounterPlain);

            var bCounterMiss = ApiPromptModal.createButton("+[counter=miss]", 130, 24, function() appendRule("[counter=miss]"), false);
            bCounterMiss.x = 287; bCounterMiss.y = 410; dlg.addChild(bCounterMiss); helperButtons.push(bCounterMiss);

            var bCounterDodge = ApiPromptModal.createButton("+[counter=dodge]", 138, 24, function() appendRule("[counter=dodge]"), false);
            bCounterDodge.x = 425; bCounterDodge.y = 410; dlg.addChild(bCounterDodge); helperButtons.push(bCounterDodge);

            // Count form. Swapped in for the crit button: it fits the row and is far more broadly
            // useful, and every resolution type is still typeable by hand and listed in the hint.
            var bCounterCount = ApiPromptModal.createButton("+[counter x2]", 115, 24, function() appendRule("[counter x2]"), false);
            bCounterCount.x = 571; bCounterCount.y = 410; dlg.addChild(bCounterCount); helperButtons.push(bCounterCount);

            // One wrapped hint instead of two single-line labels: at 11px the two together needed more width
            // than the dialog has, which pushed the text past the right edge.
            var lblCounterHint = ApiPromptModal.createLabel(
                "Quick-insert appends to the combo.  Syntax: 3[auraTime(target:Seal) <= 1.5s] > 4 | 2[tgt:hp < 50%] | 1[hp < 50%]\n" +
                "[counter] is packet-based. No time value = HARD LOCK: waits for the mob to attack. Add a window for a timed gate.",
                750, 11);
            lblCounterHint.x = 25;
            lblCounterHint.y = 436;
            lblCounterHint.textColor = 0x888888;
            dlg.addChild(lblCounterHint);

            saveBtn = ApiPromptModal.createButton("Save Mode", 100, 30, function():Void {
                try {
                    if (lblBadge != null && lblBadge.text == "[Bundled Mode]") {
                        ApiNotificationManager.notify("Cannot overwrite default bundled mode!");
                        return;
                    }

                    var cName = (inputClass != null && inputClass.text != null) ? StringTools.trim(inputClass.text) : "";
                    var mName = (inputMode != null && inputMode.text != null) ? StringTools.trim(inputMode.text) : "";
                    var execMode = (ddExecMode != null && ddExecMode.selectedItem != null && ddExecMode.selectedItem != "") ? ddExecMode.selectedItem : "WaitForCooldown";
                    var timeoutStr = (inputTimeout != null && inputTimeout.text != null) ? StringTools.trim(inputTimeout.text) : "0";
                    var pTimeout:Null<Int> = Std.parseInt(timeoutStr);
                    var rawTimeout = (pTimeout != null) ? pTimeout : 0;
                    var timeout = (rawTimeout > 1500) ? rawTimeout : 0;
                    var stopAuras = (inputStopAuras != null && inputStopAuras.text != null) ? StringTools.trim(inputStopAuras.text) : "";
                    var combo = (inputCombo != null && inputCombo.text != null) ? StringTools.trim(inputCombo.text) : "";

                    if (cName == "" || cName.toLowerCase() == "current") {
                        var cur = CombatEngine.getCurrentClassName();
                        if (cur != null && cur != "" && cur.toLowerCase() != "current") {
                            cName = cur;
                            if (inputClass != null) inputClass.text = cur;
                        } else {
                            ApiNotificationManager.notify("Error: Please provide a specific class name (cannot save under 'Current')!");
                            return;
                        }
                    }
                    if (mName == "" || mName == "[+ New Mode]") {
                        ApiNotificationManager.notify("Error: Please provide a valid mode name!");
                        return;
                    }
                    if (combo == "") {
                        ApiNotificationManager.notify("Error: Skill combo rotation cannot be empty!");
                        return;
                    }

                    var ok = SkillManager.saveMode(cName, mName, execMode, timeout, combo, stopAuras, currentResetOnTarget, currentAutoAttack);
                    if (ok) {
                        ApiNotificationManager.notify("Saved [" + cName + " : " + mName + "] to userSkills.json!");

                        try {
                            var freshClassOpts = getAvailableClasses();
                            if (ddClass != null) {
                                ddClass.setOptions(freshClassOpts);
                                ddClass.setSelectedItem(cName);
                            }

                            var freshModes = getModeListForClass(cName);
                            if (ddMode != null) {
                                ddMode.setOptions(freshModes);
                                ddMode.setSelectedItem(mName);
                            }
                            loadModeDetails(cName, mName);
                        } catch (ue:Dynamic) {}
                    } else {
                        ApiNotificationManager.notify("Error: Failed to write to userSkills.json!");
                    }
                } catch (e:Dynamic) {
                    var errDetail:String = Std.string(e);
                    #if flash
                    try {
                        if (Std.isOfType(e, flash.errors.Error)) {
                            var fe:flash.errors.Error = cast e;
                            if (fe.message != null && fe.message != "") errDetail += " (" + fe.message + ")";
                            var st:String = fe.getStackTrace();
                            if (st != null && st != "") {
                                var lines = st.split("\n");
                                if (lines.length > 1) errDetail += " at " + StringTools.trim(lines[1]);
                            }
                        }
                    } catch (_:Dynamic) {}
                    #end
                    ApiLogger.error("Prompt", "Save error: " + errDetail);
                    ApiNotificationManager.notify("Save error: " + errDetail);
                }
            }, true);
            saveBtn.x = 25;
            saveBtn.y = 464;
            dlg.addChild(saveBtn);

            applyBtn = ApiPromptModal.createButton("Apply Mode", 100, 30, function():Void {
                try {
                    var cName = (inputClass != null && inputClass.text != null) ? StringTools.trim(inputClass.text) : "";
                    var mName = (inputMode != null && inputMode.text != null) ? StringTools.trim(inputMode.text) : "";
                    if (cName == "" || mName == "" || mName == "[+ New Mode]") {
                        ApiNotificationManager.notify("Error: Select a valid class and mode to apply!");
                        return;
                    }
                    if (cName.toLowerCase() == "current") {
                        var cur = CombatEngine.getCurrentClassName();
                        if (cur != null && cur != "" && cur.toLowerCase() != "current") {
                            cName = cur;
                        }
                    }
                    try {
                        HelperSetting.setString("api_smart_class", cName);
                        HelperSetting.setString("api_smart_mode", mName);
                    } catch (se:Dynamic) {}
                    CombatEngine.smartClass = cName;
                    CombatEngine.skillMode = mName;
                    try {
                        if (Api.combat != null) {
                            Api.combat.mode = mName;
                        }
                    } catch (_:Dynamic) {}
                    ApiNotificationManager.notify("Activated [" + cName + " : " + mName + "] for Smart Combat!");
                } catch (e:Dynamic) {
                    var errDetail:String = Std.string(e);
                    #if flash
                    try {
                        if (Std.isOfType(e, flash.errors.Error)) {
                            var fe:flash.errors.Error = cast e;
                            if (fe.message != null && fe.message != "") errDetail += " (" + fe.message + ")";
                            var st:String = fe.getStackTrace();
                            if (st != null && st != "") {
                                var lines = st.split("\n");
                                if (lines.length > 1) errDetail += " at " + StringTools.trim(lines[1]);
                            }
                        }
                    } catch (_:Dynamic) {}
                    #end
                    ApiLogger.error("Prompt", "Apply error: " + errDetail);
                    ApiNotificationManager.notify("Apply error: " + errDetail);
                }
            }, true);
            applyBtn.x = 137;
            applyBtn.y = 464;
            dlg.addChild(applyBtn);

            cloneBtn = ApiPromptModal.createButton("Clone Mode", 95, 30, function():Void {
                try {
                    var baseName = (inputMode != null && inputMode.text != null) ? StringTools.trim(inputMode.text) : "Mode";
                    if (baseName == "" || baseName == "[+ New Mode]") baseName = "CustomMode";
                    if (inputMode != null) inputMode.text = baseName + " Custom";
                    if (lblBadge != null) {
                        lblBadge.text = "[New Mode]";
                        lblBadge.textColor = 0x55FF55;
                    }
                    setFormEditable(true, true);
                    cloneBtn.visible = false;
                    delBtn.visible = false;
                    ApiNotificationManager.notify("Cloned [" + baseName + "] into editable New Mode!");
                } catch (ce:Dynamic) {
                    ApiNotificationManager.notify("Clone error: " + ce);
                }
            }, false);
            cloneBtn.x = 249;
            cloneBtn.y = 464;
            cloneBtn.visible = false;
            dlg.addChild(cloneBtn);

            delBtn = ApiPromptModal.createButton("Delete Mode", 104, 30, function():Void {
                try {
                    var cName = (inputClass != null && inputClass.text != null) ? StringTools.trim(inputClass.text) : "";
                    var mName = (inputMode != null && inputMode.text != null) ? StringTools.trim(inputMode.text) : "";

                    if (cName == "" && ddClass != null && ddClass.selectedItem != null) {
                        cName = StringTools.trim(ddClass.selectedItem);
                    }

                    if (cName == "" || cName.toLowerCase() == "current") {
                        var cur = CombatEngine.getCurrentClassName();
                        if (cur != null && cur != "" && cur.toLowerCase() != "current") {
                            cName = cur;
                        } else if (CombatEngine.smartClass != null && CombatEngine.smartClass != "" && CombatEngine.smartClass.toLowerCase() != "current") {
                            cName = CombatEngine.smartClass;
                        }
                    }

                    if ((mName == "" || mName == "[+ New Mode]") && ddMode != null && ddMode.selectedItem != null && ddMode.selectedItem != "[+ New Mode]") {
                        mName = StringTools.trim(ddMode.selectedItem);
                    }

                    if (cName == "" || mName == "" || mName == "[+ New Mode]") {
                        ApiNotificationManager.notify("Error: Select a valid mode to delete!");
                        return;
                    }

                    if (!SkillManager.isUserMode(cName, mName)) {
                        ApiNotificationManager.notify("Cannot delete default bundled mode from skills.json!");
                        return;
                    }

                    var deleted = SkillManager.deleteMode(cName, mName);
                    if (deleted) {
                        ApiNotificationManager.notify("Deleted [" + cName + " : " + mName + "] from userSkills.json!");
                        try {
                            // If active smart mode was the one deleted, fall back
                            if (CombatEngine.skillMode != null && CombatEngine.skillMode.toLowerCase() == mName.toLowerCase()) {
                                var remainingModes = CombatEngine.getAvailableModes(cName);
                                var fallbackMode = (remainingModes.length > 0 && remainingModes[0] != "[+ New Mode]") ? remainingModes[0] : "Base";
                                CombatEngine.skillMode = fallbackMode;
                                try { HelperSetting.setString("api_smart_mode", fallbackMode); } catch (_:Dynamic) {}
                                try { if (Api.combat != null) Api.combat.mode = fallbackMode; } catch (_:Dynamic) {}
                            }

                            var freshClassOpts = getAvailableClasses();
                            var classToSelect = (freshClassOpts.indexOf(cName) != -1) ? cName : (freshClassOpts.length > 0 ? freshClassOpts[0] : "");
                            if (ddClass != null) {
                                ddClass.setOptions(freshClassOpts);
                                ddClass.setSelectedItem(classToSelect);
                            }
                            var modes = getModeListForClass(classToSelect);
                            if (ddMode != null) {
                                ddMode.setOptions(modes);
                                var nextMode = (modes.length > 0 && modes[0] != "[+ New Mode]") ? modes[0] : (modes.length > 1 ? modes[0] : "[+ New Mode]");
                                ddMode.setSelectedItem(nextMode);
                                loadModeDetails(classToSelect, nextMode);
                            }
                        } catch (de:Dynamic) {}
                    } else {
                        ApiNotificationManager.notify("Mode was not found in userSkills.json!");
                    }
                } catch (e:Dynamic) {
                    var errDetail:String = Std.string(e);
                    #if flash
                    try {
                        if (Std.isOfType(e, flash.errors.Error)) {
                            var fe:flash.errors.Error = cast e;
                            if (fe.message != null && fe.message != "") errDetail += " (" + fe.message + ")";
                            var st:String = fe.getStackTrace();
                            if (st != null && st != "") {
                                var lines = st.split("\n");
                                if (lines.length > 1) errDetail += " at " + StringTools.trim(lines[1]);
                            }
                        }
                    } catch (_:Dynamic) {}
                    #end
                    ApiLogger.error("Prompt", "Delete error: " + errDetail);
                    ApiNotificationManager.notify("Delete error: " + errDetail);
                }
            }, false);
            delBtn.x = 249;
            delBtn.y = 464;
            dlg.addChild(delBtn);

            var backBtn = ApiPromptModal.createButton("AutoCombat Setup", 138, 30, function():Void {
                ApiPromptModal.close();
                showSmartCombatPrompt(overlay);
            }, false);
            backBtn.x = 365;
            backBtn.y = 464;
            dlg.addChild(backBtn);

            var closeBtn = ApiPromptModal.createButton("Close", 100, 30, function():Void {
                ApiPromptModal.close();
            }, false);
            closeBtn.x = 515;
            closeBtn.y = 464;
            dlg.addChild(closeBtn);

            // Initial load of selected mode details now that all UI elements and buttons exist
            loadModeDetails(selectedClass, initialSelMode);

            ApiPromptModal.show(overlay, dlg);
        } catch (e:Dynamic) {
            var msg = Std.string(e);
            #if flash
            if (Std.isOfType(e, flash.errors.Error)) {
                msg += "\n" + (cast e : flash.errors.Error).getStackTrace();
            }
            #end
            ApiLogger.error("Prompt", "Failed to show Combat Mode Editor: " + msg);
            ApiNotificationManager.notify("Error opening editor: " + e);
        }
    }

    public static function showLoadoutsPrompt(overlay:Dynamic):Void {
        try {
            var dlg = ApiPromptModal.createDialog(460, 390, "Class Loadouts (For Scripts)");

            var availableClasses = getAvailableClasses();
            if (availableClasses == null || availableClasses.length == 0) availableClasses = ["Current"];

            var lblClassHdr = ApiPromptModal.createLabel("Class:", 210, 11, true);
            lblClassHdr.x = 24;
            lblClassHdr.y = 34;
            lblClassHdr.textColor = 0x888888;
            dlg.addChild(lblClassHdr);

            var lblModeHdr = ApiPromptModal.createLabel("Combat Mode:", 188, 11, true);
            lblModeHdr.x = 248;
            lblModeHdr.y = 34;
            lblModeHdr.textColor = 0x888888;
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

        var getModesForClass = function(cName:String):Array<String> {
            var modes:Array<String> = [];
            var isCurrent = (cName == null || cName == "" || cName.toLowerCase() == "current");
            if (isCurrent) {
                modes.push("Auto (First Available)");
                var curName = CombatEngine.getCurrentClassName();
                if (curName != "") {
                    try {
                        var detectedModes = CombatEngine.getAvailableModes(curName);
                        if (detectedModes != null) {
                            for (m in detectedModes) if (modes.indexOf(m) == -1) modes.push(m);
                        }
                    } catch (_:Dynamic) {}
                }
            } else {
                try {
                    modes = CombatEngine.getAvailableModes(cName);
                } catch (_:Dynamic) {}
            }
            if (modes == null || modes.length == 0) modes = ["Base"];
            return modes;
        };

        var curClass = HelperSetting.getString(classKey, "Current");
        if (classes.indexOf(curClass) == -1) curClass = classes[0];

        var modes:Array<String> = getModesForClass(curClass);
        var curMode = HelperSetting.getString(modeKey, "Auto");
        if (curClass == "Current" && (curMode == "" || curMode == "Auto")) {
            curMode = "Auto (First Available)";
        } else if (curMode == null || curMode == "" || modes.indexOf(curMode) == -1) {
            curMode = modes.length > 0 ? modes[0] : "Base";
        }

        var ddMode:Dropdown = null;
        ddMode = new Dropdown(188, 25, modes, function(sel:String):Void {
            curMode = sel;
            var saveMode = (sel == "Auto (First Available)") ? "Auto" : sel;
            HelperSetting.setString(modeKey, saveMode);
            if (onUpdate != null) onUpdate(curClass, saveMode);
        });
        ddMode.x = 248;
        ddMode.y = ddY;

        var ddClass:Dropdown = null;
        ddClass = new Dropdown(215, 25, classes, function(sel:String):Void {
            curClass = sel;
            HelperSetting.setString(classKey, sel);
            var nm:Array<String> = getModesForClass(curClass);
            ddMode.setOptions(nm);
            if (curClass == "Current") {
                curMode = "Auto (First Available)";
            } else if (nm.indexOf(curMode) == -1) {
                curMode = nm.length > 0 ? nm[0] : "Base";
            }
            ddMode.setSelectedItem(curMode);
            var saveMode = (curMode == "Auto (First Available)") ? "Auto" : curMode;
            HelperSetting.setString(modeKey, saveMode);
            if (onUpdate != null) onUpdate(curClass, saveMode);
        });
        ddClass.x = 24;
        ddClass.y = ddY;

        ddClass.setSelectedItem(curClass);
        ddMode.setSelectedItem(curMode);
        dlg.addChild(ddMode);
        dlg.addChild(ddClass);
    }

    private static function getAvailableClasses():Array<String> {
        var classMap:Map<String, String> = new Map<String, String>();
        var invClasses:Array<String> = [];

        var addClass = function(name:Dynamic):Void {
            if (name == null) return;
            var str:String = Std.string(name);
            var trimmed:String = StringTools.trim(str);
            if (trimmed == "" || trimmed == "null" || trimmed == "No Classes Found" || trimmed.toLowerCase() == "current") return;
            var key:String = trimmed.toLowerCase();
            if (!classMap.exists(key)) {
                classMap.set(key, trimmed);
                invClasses.push(trimmed);
            }
        };

        // Inventory classes
        if (Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null && Api.game.world.myAvatar.items != null) {
            try {
                var items:Dynamic = Api.game.world.myAvatar.items;
                if (Std.isOfType(items, Array)) {
                    for (item in (cast items : Array<Dynamic>)) {
                        if (item == null || item.sName == null) continue;
                        var isClass:Bool = false;
                        var sTypeStr:String = (item.sType != null) ? Std.string(item.sType).toLowerCase() : "";
                        if (sTypeStr == "class" || item.bClass == 1 || item.bClass == true || item.bClass == "1") {
                            isClass = true;
                        } else if (item.sES != null && Std.string(item.sES).toLowerCase() == "ar" && sTypeStr != "armor") {
                            if (CombatEngine.findClassConfig(item.sName) != null) isClass = true;
                        }
                        if (isClass) addClass(item.sName);
                    }
                }
            } catch (e:Dynamic) {}
        }

        // Currently equipped class
        try {
            var cur:String = getCurrentClass();
            if (cur != "" && cur.toLowerCase() != "current") {
                addClass(cur);
            }
        } catch (e:Dynamic) {}

        try {
            invClasses.sort(function(a, b) {
                var la:String = a.toLowerCase();
                var lb:String = b.toLowerCase();
                if (la < lb) return -1;
                if (la > lb) return 1;
                return 0;
            });
        } catch (e:Dynamic) {}

        var result:Array<String> = ["Current"];
        for (c in invClasses) {
            result.push(c);
        }
        return result;
    }

    private static function getCurrentClass():String {
        try {
            var cur:String = CombatEngine.getCurrentClassName();
            if (cur != "" && cur.toLowerCase() != "current") return cur;
            if (Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null) {
                var av:Dynamic = Api.game.world.myAvatar;
                if (av.objData != null && av.objData.strClassName != null) {
                    var c:String = Std.string(av.objData.strClassName);
                    if (c != "" && c != "null") return c;
                }
            }
        } catch (e:Dynamic) {}
        return "";
    }

    public static function showScriptManager(overlay:Dynamic):Void {
        try {
            var dlg = ApiPromptModal.createDialog(620, 500, "Script Manager & Editor");

            var currentScriptName:String = "";
            var isUser:Bool = false;
            var isBundled:Bool = false;
            var currentCategory:String = "All Scripts";

            // Category Selection Dropdown
            var lblCategory = ApiPromptModal.createLabel("Category:", 130);
            lblCategory.x = 20;
            lblCategory.y = 36;
            dlg.addChild(lblCategory);

            // Script Selection Dropdown
            var lblSelect = ApiPromptModal.createLabel("Select Script:", 205);
            lblSelect.x = 160;
            lblSelect.y = 36;
            dlg.addChild(lblSelect);

            // Script Name Input
            var lblName = ApiPromptModal.createLabel("Script Name (.hxs):", 225);
            lblName.x = 375;
            lblName.y = 36;
            dlg.addChild(lblName);

            var inputName = ApiPromptModal.createInput(225, 26, "");
            inputName.x = 375;
            inputName.y = 56;
            dlg.addChild(inputName);

            // Live Status Indicator (Native vector LED dot + ASCII label)
            var statusDot = new flash.display.Shape();
            statusDot.x = 28;
            statusDot.y = 96;
            dlg.addChild(statusDot);

            var lblStatus = ApiPromptModal.createLabel("STATUS: STOPPED", 540, 12, true);
            lblStatus.x = 38;
            lblStatus.y = 89;
            lblStatus.textColor = 0x888888;
            dlg.addChild(lblStatus);

            // Code Editor
            var lblCode = ApiPromptModal.createLabel("Script Code (HScript / .hxs):", 300);
            lblCode.x = 20;
            lblCode.y = 114;
            dlg.addChild(lblCode);

            var inputCode = ApiPromptModal.createInput(580, 290, "", true);
            var codeFmt = new flash.text.TextFormat("_typewriter", 12, 0xFFFFFF);
            inputCode.defaultTextFormat = codeFmt;
            inputCode.x = 20;
            inputCode.y = 136;
            dlg.addChild(inputCode);

            // Buttons
            var runBtn:Sprite = null;
            var runBtnTxt:TextField = null;
            var saveBtn:Sprite = null;
            var deleteBtn:Sprite = null;

            var ddScript:Dropdown = null;
            var ddCategory:Dropdown = null;

            // Map option labels to raw script paths
            var optToRaw:Map<String, String> = new Map<String, String>();

            var getCategoryForScript = function(rawName:String):String {
                if (StringTools.startsWith(rawName, "saga/")) return "Lord of Chaos";
                if (StringTools.startsWith(rawName, "rep/")) return "Reputation";
                if (ScriptManager.SINGLETON.isBundledScript(rawName)) return "General";
                return "User Scripts";
            };

            var formatScriptLabel = function(rawName:String, category:String):String {
                if (rawName == "[+ New Script]") return rawName;
                if (category == "Lord of Chaos") {
                    var s = rawName;
                    if (StringTools.startsWith(s, "saga/LordofChaos/")) s = s.substring(17);
                    else if (StringTools.startsWith(s, "saga/")) s = s.substring(5);
                    return s;
                } else if (category == "Reputation") {
                    var s = rawName;
                    if (StringTools.startsWith(s, "rep/")) s = s.substring(4);
                    return s;
                } else if (category == "General") {
                    return rawName;
                } else if (category == "User Scripts") {
                    return rawName;
                } else {
                    // All Scripts: prefix category tag
                    var cat = getCategoryForScript(rawName);
                    var shortTag = (cat == "Lord of Chaos") ? "[Chaos] " : (cat == "Reputation") ? "[Rep] " : (cat == "General") ? "[Gen] " : "[User] ";
                    var clean = rawName;
                    if (StringTools.startsWith(clean, "saga/LordofChaos/")) clean = clean.substring(17);
                    else if (StringTools.startsWith(clean, "rep/")) clean = clean.substring(4);
                    return shortTag + clean;
                }
            };

            var buildFilteredOptions = function(category:String):Array<String> {
                optToRaw = new Map<String, String>();
                var rawScripts = ScriptManager.SINGLETON.listScripts();
                var opts:Array<String> = [];

                for (s in rawScripts) {
                    var scriptCat = getCategoryForScript(s);
                    if (category == "All Scripts" || category == scriptCat) {
                        var lbl = formatScriptLabel(s, category);
                        if (optToRaw.exists(lbl)) {
                            lbl = "[" + s + "]";
                        }
                        optToRaw.set(lbl, s);
                        opts.push(lbl);
                    }
                }

                if (category == "All Scripts" || category == "User Scripts") {
                    opts.push("[+ New Script]");
                    optToRaw.set("[+ New Script]", "[+ New Script]");
                }

                return opts;
            };

            var updateStatusDisplay = function():Void {
                var running = ScriptManager.SINGLETON.isRunning;
                statusDot.graphics.clear();
                if (running) {
                    var actName = ScriptManager.SINGLETON.activeScriptName;
                    statusDot.graphics.beginFill(0x2ECC71, 0.35);
                    statusDot.graphics.drawCircle(0, 0, 4.5);
                    statusDot.graphics.endFill();
                    statusDot.graphics.beginFill(0x00E676, 1.0);
                    statusDot.graphics.drawCircle(0, 0, 2.5);
                    statusDot.graphics.endFill();

                    lblStatus.text = "STATUS: RUNNING (" + (actName != null ? actName : "Custom Script") + ")";
                    lblStatus.textColor = 0x55FF55;
                    if (runBtnTxt != null) runBtnTxt.text = "Stop Script";
                } else {
                    statusDot.graphics.beginFill(0x555555, 0.9);
                    statusDot.graphics.drawCircle(0, 0, 2.5);
                    statusDot.graphics.endFill();

                    lblStatus.text = "STATUS: STOPPED";
                    lblStatus.textColor = 0x888888;
                    if (runBtnTxt != null) runBtnTxt.text = "Start Script";
                }
            };

            var setDeleteEnabled = function(enabled:Bool):Void {
                if (deleteBtn != null) {
                    deleteBtn.mouseEnabled = enabled;
                    deleteBtn.alpha = enabled ? 1.0 : 0.35;
                }
            };

            var loadSelectedScript = function(optLabel:String):Void {
                var raw = optToRaw.exists(optLabel) ? optToRaw.get(optLabel) : optLabel;
                if (raw == "[+ New Script]" || optLabel == "[+ New Script]") {
                    currentScriptName = "MyScript";
                    isUser = true;
                    isBundled = false;
                    lblName.text = "New Script Name (.hxs):";
                    inputName.type = TextFieldType.INPUT;
                    inputName.text = "MyScript";
                    inputName.selectable = true;
                    inputCode.text = "// New HScript\nfunction onStart() {\n    bot.log(\"Started script!\");\n}\n\nfunction onTick() {\n    // Bot logic here\n}\n\nfunction onStop() {\n    bot.log(\"Stopped script!\");\n}\n";
                    try { inputCode.setTextFormat(codeFmt); } catch (_:Dynamic) {}
                    setDeleteEnabled(false);
                } else {
                    currentScriptName = raw;
                    isBundled = ScriptManager.SINGLETON.isBundledScript(raw);
                    isUser = !isBundled;
                    if (isBundled) {
                        lblName.text = "Save As User Script (.hxs):";
                        var leafName = raw;
                        if (leafName.indexOf("/") != -1) leafName = leafName.substring(leafName.lastIndexOf("/") + 1);
                        inputName.text = leafName + "_Edited";
                        setDeleteEnabled(false);
                    } else {
                        lblName.text = "Script Name (.hxs):";
                        inputName.text = raw;
                        setDeleteEnabled(true);
                    }
                    inputName.type = TextFieldType.INPUT;
                    inputName.selectable = true;
                    inputCode.text = ScriptManager.SINGLETON.getScriptContent(raw);
                    try { inputCode.setTextFormat(codeFmt); } catch (_:Dynamic) {}
                }
                updateStatusDisplay();
            };

            var categories = ["All Scripts", "Lord of Chaos", "Reputation", "General", "User Scripts"];
            var scriptOptions = buildFilteredOptions(currentCategory);

            ddScript = new Dropdown(205, 26, scriptOptions, function(sel:String):Void {
                loadSelectedScript(sel);
            });
            ddScript.x = 160;
            ddScript.y = 56;

            ddCategory = new Dropdown(130, 26, categories, function(cat:String):Void {
                currentCategory = cat;
                var filtered = buildFilteredOptions(cat);
                ddScript.setOptions(filtered);
                var sel = filtered.length > 0 ? filtered[0] : "[+ New Script]";
                ddScript.setSelectedItem(sel);
                loadSelectedScript(sel);
            });
            ddCategory.x = 20;
            ddCategory.y = 56;

            dlg.addChild(ddCategory);
            dlg.addChild(ddScript);

            var initialLabel = scriptOptions.length > 0 ? scriptOptions[0] : "[+ New Script]";
            if (ScriptManager.SINGLETON.activeScriptName != null) {
                var act = ScriptManager.SINGLETON.activeScriptName;
                for (k in optToRaw.keys()) {
                    if (optToRaw.get(k) == act) {
                        initialLabel = k;
                        break;
                    }
                }
            }
            ddScript.setSelectedItem(initialLabel);
            loadSelectedScript(initialLabel);

            // Bottom action buttons (y = 445)
            runBtn = ApiPromptModal.createButton(ScriptManager.SINGLETON.isRunning ? "Stop Script" : "Start Script", 130, 32, function():Void {
                if (ScriptManager.SINGLETON.isRunning) {
                    ScriptManager.SINGLETON.stop();
                    ApiNotificationManager.notify("Script stopped.");
                } else {
                    var code = inputCode.text;
                    if (code == null || StringTools.trim(code) == "") {
                        ApiNotificationManager.notify("Cannot run empty script!");
                        return;
                    }
                    var sName = StringTools.trim(inputName.text);
                    if (isBundled && sName.indexOf("_Edited") != -1) {
                        sName = currentScriptName;
                    } else if (sName == "") {
                        sName = currentScriptName != "" ? currentScriptName : "CustomScript";
                    }
                    ScriptManager.SINGLETON.loadScript(code);
                    ScriptManager.SINGLETON.start();
                    ScriptManager.SINGLETON.activeScriptName = sName;
                    ApiNotificationManager.notify("Started script: " + sName);
                }
                updateStatusDisplay();
            }, false);
            runBtn.x = 24;
            runBtn.y = 445;
            for (i in 0...runBtn.numChildren) {
                if (Std.isOfType(runBtn.getChildAt(i), TextField)) {
                    runBtnTxt = cast runBtn.getChildAt(i);
                    break;
                }
            }
            dlg.addChild(runBtn);

            saveBtn = ApiPromptModal.createButton("Save Script", 130, 32, function():Void {
                var sName = StringTools.trim(inputName.text);
                if (StringTools.endsWith(sName.toLowerCase(), ".hxs")) {
                    sName = sName.substring(0, sName.length - 4);
                }
                if (sName == "") {
                    ApiNotificationManager.notify("Please enter a valid script name.");
                    return;
                }
                if (ScriptManager.SINGLETON.isBundledScript(sName)) {
                    sName = sName + "_Edited";
                }
                var code = inputCode.text;
                var saved = ScriptManager.SINGLETON.saveScript(sName, code);
                if (saved) {
                    ApiNotificationManager.notify("Saved script: " + sName);
                    var refreshed = buildFilteredOptions(currentCategory);
                    ddScript.setOptions(refreshed);
                    var newSel = optToRaw.exists(sName) ? sName : (refreshed.length > 0 ? refreshed[0] : "[+ New Script]");
                    ddScript.setSelectedItem(newSel);
                    loadSelectedScript(newSel);
                } else {
                    ApiNotificationManager.notify("Failed to save script.");
                }
            }, false);
            saveBtn.x = 178;
            saveBtn.y = 445;
            dlg.addChild(saveBtn);

            deleteBtn = ApiPromptModal.createButton("Delete Script", 130, 32, function():Void {
                if (isBundled || ScriptManager.SINGLETON.isBundledScript(currentScriptName)) {
                    ApiNotificationManager.notify("Cannot delete bundled scripts!");
                    return;
                }
                var toDelete = currentScriptName;
                if (toDelete == "" || toDelete == "MyScript") return;
                var deleted = ScriptManager.SINGLETON.deleteScript(toDelete);
                if (deleted) {
                    ApiNotificationManager.notify("Deleted script: " + toDelete);
                    var refreshed = buildFilteredOptions(currentCategory);
                    ddScript.setOptions(refreshed);
                    var nextSel = refreshed.length > 0 ? refreshed[0] : "[+ New Script]";
                    ddScript.setSelectedItem(nextSel);
                    loadSelectedScript(nextSel);
                } else {
                    ApiNotificationManager.notify("Failed to delete script.");
                }
            }, false);
            deleteBtn.x = 332;
            deleteBtn.y = 445;
            dlg.addChild(deleteBtn);
            setDeleteEnabled(!isBundled && currentScriptName != "MyScript" && currentScriptName != "");

            var closeBtn = ApiPromptModal.createButton("Close", 110, 32, function():Void {
                ApiPromptModal.close();
            }, false);
            closeBtn.x = 486;
            closeBtn.y = 445;
            dlg.addChild(closeBtn);

            // Real-time synchronization
            var onFrame:Event->Void = null;
            onFrame = function(e:Event):Void {
                if (dlg.parent == null) {
                    dlg.removeEventListener(Event.ENTER_FRAME, onFrame);
                    return;
                }
                updateStatusDisplay();
            };
            dlg.addEventListener(Event.ENTER_FRAME, onFrame);

            ApiPromptModal.show(overlay, dlg);
        } catch (e:Dynamic) {
            com.aqwapi.utils.ApiLogger.error("UI", "Script Manager error: " + e);
            ApiNotificationManager.notify("Script Manager error: " + e);
        }
    }
}
#else
class ApiPrompts {
    public static function showCombatModeEditorPrompt(overlay:Dynamic, initialClass:String = null, initialMode:String = null):Void {}
    public static function showScriptManager(overlay:Dynamic):Void {}
}
#end

