package ui.prompts;

#if flash
import com.aqwapi.AqwApi;
import com.aqwapi.modules.CombatEngine;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.modules.UserSkillsManager;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwUtils;
import flash.display.Sprite;
import ui.ApiNotificationManager;
import ui.Dropdown;
import util.HelperSetting;

class ApiPrompts {
    private static var _lastQuests:String = "";
    private static var _lastCombat:String = "";

    public static function showQuestPrompt(overlay:Dynamic):Void {
        var dlg = ApiPromptModal.createDialog(300, 160, "Enter Quest IDs (comma separated):");

        var input = ApiPromptModal.createInput(260, 25, _lastQuests);
        input.x = 20;
        input.y = 40;
        dlg.addChild(input);

        var startBtn = ApiPromptModal.createButton("Start", 120, 30, function():Void {
            _lastQuests = input.text;
            var ids = _lastQuests.split(",");
            var validIds:Array<Int> = [];
            for (idStr in ids) {
                var qid = AqwUtils.parseInt(StringTools.trim(idStr), 0);
                if (qid > 0) validIds.push(qid);
            }
            if (validIds.length > 0 && AqwApi.quest != null) {
                AqwApi.quest.startAuto(validIds.join(","));
            }
            ApiPromptModal.close();
        }, false);
        startBtn.x = 20;
        startBtn.y = 80;
        dlg.addChild(startBtn);

        var cancelBtn = ApiPromptModal.createButton("Cancel", 120, 30, function():Void {
            ApiPromptModal.close();
        }, false);
        cancelBtn.x = 160;
        cancelBtn.y = 80;
        dlg.addChild(cancelBtn);

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
            if (validSeq.length > 0 && AqwApi.combat != null) {
                AqwApi.combat.startCustom(validSeq.join(","), selectedMode);
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

    public static function showShopPrompt(overlay:Dynamic):Void {
        var dlg = ApiPromptModal.createDialog(300, 160, "Enter Shop ID:");

        var input = ApiPromptModal.createInput(260, 25, "");
        input.x = 20;
        input.y = 40;
        dlg.addChild(input);

        var loadBtn = ApiPromptModal.createButton("Load", 120, 30, function():Void {
            var shopId = AqwUtils.parseInt(StringTools.trim(input.text), 0);
            ApiPromptModal.close();
            if (shopId > 0 && AqwApi.shop != null) {
                AqwApi.shop.loadShop(shopId);
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
                if (AqwApi.map != null && AqwApi.map.name != null && AqwApi.map.name.toLowerCase() != "forge") {
                    AqwApi.map.join("forge", "Enter", "Spawn");
                    ApiNotificationManager.notify("Joining forge map...");
                    haxe.Timer.delay(function():Void {
                        if (AqwApi.shop != null) AqwApi.shop.loadShop(selectedId);
                        ApiNotificationManager.notify("Loading Shop: " + selectedName);
                    }, 3500);
                    return;
                }
            }
            if (AqwApi.shop != null) AqwApi.shop.loadShop(selectedId);
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

    public static function showSmartCombatPrompt(overlay:Dynamic):Void {
        try {
            var dlg = ApiPromptModal.createDialog(420, 250, "AutoCombat Setup");

            var lblClass = ApiPromptModal.createLabel("Class:", 60);
            lblClass.x = 20;
            lblClass.y = 50;
            dlg.addChild(lblClass);

            var lblMode = ApiPromptModal.createLabel("Mode:", 60);
            lblMode.x = 220;
            lblMode.y = 50;
            dlg.addChild(lblMode);

            var availableClasses = getAvailableClasses();
            if (availableClasses == null || availableClasses.length == 0) availableClasses = ["Current"];

            var selectedClassStr = HelperSetting.getString("api_smart_class", "Current");
            if (availableClasses.indexOf(selectedClassStr) == -1) {
                selectedClassStr = "Current";
            }

            var availableModes = CombatEngine.getAvailableModes(selectedClassStr);
            if (availableModes == null || availableModes.length == 0) availableModes = ["Base"];

            var selectedModeStr = HelperSetting.getString("api_smart_mode", "Base");
            if (availableModes.indexOf(selectedModeStr) == -1) {
                selectedModeStr = availableModes.length > 0 ? availableModes[0] : "Base";
            }

            var ddMode:Dropdown = null;
            ddMode = new Dropdown(150, 25, availableModes, function(sel:String):Void {
                selectedModeStr = sel;
            });
            ddMode.x = 220;
            ddMode.y = 80;
            ddMode.setSelectedItem(selectedModeStr);

            var ddClass:Dropdown = null;
            ddClass = new Dropdown(180, 25, availableClasses, function(sel:String):Void {
                selectedClassStr = sel;
                var modes = CombatEngine.getAvailableModes(selectedClassStr);
                if (modes == null || modes.length == 0) modes = ["Base"];
                ddMode.setOptions(modes);
                if (modes.indexOf(selectedModeStr) == -1) {
                    selectedModeStr = modes[0];
                }
                ddMode.setSelectedItem(selectedModeStr);
            });
            ddClass.x = 20;
            ddClass.y = 80;
            ddClass.setSelectedItem(selectedClassStr);

            dlg.addChild(ddMode);
            dlg.addChild(ddClass);

            var saveBtn = ApiPromptModal.createButton("Save & Apply", 130, 35, function():Void {
                HelperSetting.setString("api_smart_class", selectedClassStr);
                HelperSetting.setString("api_smart_mode", selectedModeStr);
                CombatEngine.smartClass = selectedClassStr;
                if (selectedClassStr != "" && selectedClassStr != "Current" && AqwApi.inventory != null) {
                    AqwApi.inventory.equip(selectedClassStr);
                }
                if (AqwApi.combat != null) {
                    AqwApi.combat.mode = selectedModeStr;
                }
                ApiNotificationManager.notify("Smart Combat Config: " + selectedClassStr + " [" + selectedModeStr + "]");
                ApiPromptModal.close();
            }, true);
            saveBtn.x = 20;
            saveBtn.y = 190;
            dlg.addChild(saveBtn);

            var editModesBtn = ApiPromptModal.createButton("Edit Modes", 120, 35, function():Void {
                ApiPromptModal.close();
                showCombatModeEditorPrompt(overlay, selectedClassStr, selectedModeStr);
            }, false);
            editModesBtn.x = 160;
            editModesBtn.y = 190;
            dlg.addChild(editModesBtn);

            var cancelBtn = ApiPromptModal.createButton("Cancel", 100, 35, function():Void {
                ApiPromptModal.close();
            }, false);
            cancelBtn.x = 295;
            cancelBtn.y = 190;
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
            try { UserSkillsManager.ensureStorageInitialized(); } catch (_:Dynamic) {}
            var dlg = ApiPromptModal.createDialog(560, 440, "Combat Mode Editor");

            // Gather class options (Current + Inventory + Bank + Custom)
            var getAllClassOptions = function():Array<String> {
                var classMap:Map<String, String> = new Map<String, String>();
                var opts:Array<String> = [];

                var addOption = function(c:Dynamic):Void {
                    if (c == null) return;
                    var str = StringTools.trim(Std.string(c));
                    if (str == "" || str == "null" || str.toLowerCase() == "current") return;
                    var key = str.toLowerCase();
                    if (!classMap.exists(key)) {
                        classMap.set(key, str);
                        opts.push(str);
                    }
                };

                // Inventory & equipped classes
                for (c in getAvailableClasses()) addOption(c);

                // Bank classes (if loaded)
                if (AqwApi.game != null && AqwApi.game.world != null) {
                    var world:Dynamic = AqwApi.game.world;
                    var checkItem = function(it:Dynamic):Void {
                        if (it == null || it.sName == null) return;
                        var isClass = false;
                        var sTypeStr = (it.sType != null) ? Std.string(it.sType).toLowerCase() : "";
                        if (sTypeStr == "class" || it.bClass == 1 || it.bClass == true || it.bClass == "1") {
                            isClass = true;
                        } else if (it.sES != null && Std.string(it.sES).toLowerCase() == "ar" && sTypeStr != "armor") {
                            if (CombatEngine.findClassConfig(it.sName) != null) isClass = true;
                        }
                        if (isClass) addOption(it.sName);
                    };

                    // Check world.bankinfo.items
                    try {
                        if (world.bankinfo != null && world.bankinfo.items != null) {
                            var bItems:Dynamic = world.bankinfo.items;
                            if (Std.isOfType(bItems, Array)) {
                                for (it in (cast bItems : Array<Dynamic>)) checkItem(it);
                            }
                        }
                    } catch (be1:Dynamic) {}

                    // Check world.myAvatar.bank.items
                    try {
                        if (world.myAvatar != null && world.myAvatar.bank != null && world.myAvatar.bank.items != null) {
                            var bItems:Dynamic = world.myAvatar.bank.items;
                            if (Std.isOfType(bItems, Array)) {
                                for (it in (cast bItems : Array<Dynamic>)) checkItem(it);
                            }
                        }
                    } catch (be2:Dynamic) {}

                    // Check world.bankTree
                    try {
                        if (world.bankTree != null) {
                            for (k in Reflect.fields(world.bankTree)) {
                                checkItem(Reflect.field(world.bankTree, k));
                            }
                        }
                    } catch (be3:Dynamic) {}
                }

                // User custom classes from userSkills.txt
                try {
                    var userTxt = UserSkillsManager.readUserSkills();
                    if (userTxt != null && userTxt.length > 0) {
                        var parsed = com.aqwapi.utils.SkillDslParser.parse(userTxt);
                        if (parsed != null) {
                            for (cKey in Reflect.fields(parsed)) addOption(cKey);
                        }
                    }
                } catch (ue:Dynamic) {}

                opts.sort(function(a, b) {
                    var la = a.toLowerCase();
                    var lb = b.toLowerCase();
                    if (la < lb) return -1;
                    if (la > lb) return 1;
                    return 0;
                });

                return ["Current"].concat(opts);
            };

            var classOptions:Array<String> = getAllClassOptions();
            var curEquipped = CombatEngine.getCurrentClassName();
            var selectedClass = (initialClass != null && initialClass != "") ? initialClass : (curEquipped != "" ? curEquipped : (classOptions.length > 1 ? classOptions[1] : "Current"));
            if (selectedClass.toLowerCase() == "current" && curEquipped != "") {
                selectedClass = curEquipped;
            }

            var lblClass = ApiPromptModal.createLabel("Select Class:", 120);
            lblClass.x = 25;
            lblClass.y = 40;
            dlg.addChild(lblClass);

            var lblCustomClass = ApiPromptModal.createLabel("Class Name:", 120);
            lblCustomClass.x = 265;
            lblCustomClass.y = 40;
            dlg.addChild(lblCustomClass);

            var inputClass = ApiPromptModal.createInput(270, 24, selectedClass);
            inputClass.x = 265;
            inputClass.y = 60;
            dlg.addChild(inputClass);

            var lblMode = ApiPromptModal.createLabel("Select Mode:", 120);
            lblMode.x = 25;
            lblMode.y = 92;
            dlg.addChild(lblMode);

            var lblCustomMode = ApiPromptModal.createLabel("Mode Name:", 120);
            lblCustomMode.x = 265;
            lblCustomMode.y = 92;
            dlg.addChild(lblCustomMode);

            var inputMode = ApiPromptModal.createInput(270, 24, "Base");
            inputMode.x = 265;
            inputMode.y = 112;
            dlg.addChild(inputMode);

            var lblExecMode = ApiPromptModal.createLabel("Execution Mode:", 120);
            lblExecMode.x = 25;
            lblExecMode.y = 144;
            dlg.addChild(lblExecMode);

            var lblTimeout = ApiPromptModal.createLabel("Timeout (ms):", 90);
            lblTimeout.x = 240;
            lblTimeout.y = 144;
            dlg.addChild(lblTimeout);

            var inputTimeout = ApiPromptModal.createInput(80, 24, "100");
            inputTimeout.x = 240;
            inputTimeout.y = 164;
            dlg.addChild(inputTimeout);

            var lblBadge = ApiPromptModal.createLabel("[Bundled Mode]", 200, 13, true);
            lblBadge.x = 340;
            lblBadge.y = 166;
            dlg.addChild(lblBadge);

            var lblCombo = ApiPromptModal.createLabel("Skill Combo / Rotation (1-Liner DSL):", 300);
            lblCombo.x = 25;
            lblCombo.y = 196;
            dlg.addChild(lblCombo);

            var inputCombo = ApiPromptModal.createInput(510, 48, "", true);
            inputCombo.x = 25;
            inputCombo.y = 216;
            dlg.addChild(inputCombo);

            var ddExecMode:Dropdown = null;
            var ddMode:Dropdown = null;
            var ddClass:Dropdown = null;

            var loadModeDetails = function(cName:String, mName:String):Void {
                if (mName == "[+ New Mode]") {
                    inputMode.text = "CustomMode";
                    if (ddExecMode != null) ddExecMode.setSelectedItem("WaitForCooldown");
                    inputTimeout.text = "100";
                    inputCombo.text = "";
                    lblBadge.text = "[New Mode]";
                    lblBadge.textColor = 0x55FF55;
                    return;
                }

                inputMode.text = mName;
                var details = UserSkillsManager.getModeDetails(cName, mName);
                if (details != null) {
                    if (ddExecMode != null) ddExecMode.setSelectedItem(details.skillUseMode);
                    inputTimeout.text = Std.string(details.timeout);
                    inputCombo.text = details.combo;
                    if (details.isUser) {
                        lblBadge.text = "[Custom Mode]";
                        lblBadge.textColor = 0x00D9FF;
                    } else {
                        lblBadge.text = "[Bundled Mode]";
                        lblBadge.textColor = 0xAAAAAA;
                    }
                } else {
                    if (ddExecMode != null) ddExecMode.setSelectedItem("WaitForCooldown");
                    inputTimeout.text = "100";
                    inputCombo.text = "";
                    lblBadge.text = "[New Mode]";
                    lblBadge.textColor = 0x55FF55;
                }
            };

            var getModeListForClass = function(cName:String):Array<String> {
                var modes = CombatEngine.getAvailableModes(cName);
                var list:Array<String> = [];
                if (modes != null) {
                    for (m in modes) list.push(m);
                }
                list.push("[+ New Mode]");
                return list;
            };

            ddExecMode = new Dropdown(200, 24, ["WaitForCooldown", "UseIfAvailable"], function(sel:String):Void {});
            ddExecMode.x = 25;
            ddExecMode.y = 164;
            ddExecMode.setSelectedItem("WaitForCooldown");

            var initialModes = getModeListForClass(selectedClass);
            var initialSelMode = (initialMode != null && initialMode != "" && initialModes.indexOf(initialMode) != -1) ? initialMode : initialModes[0];

            ddMode = new Dropdown(220, 24, initialModes, function(selMode:String):Void {
                var currentClass = StringTools.trim(inputClass.text);
                if (currentClass == "") currentClass = selectedClass;
                loadModeDetails(currentClass, selMode);
            });
            ddMode.x = 25;
            ddMode.y = 112;
            ddMode.setSelectedItem(initialSelMode);

            ddClass = new Dropdown(220, 24, classOptions, function(selClass:String):Void {
                var resolvedClass = selClass;
                if (resolvedClass.toLowerCase() == "current") {
                    var cur = CombatEngine.getCurrentClassName();
                    resolvedClass = (cur != "" ? cur : "Current");
                }
                selectedClass = resolvedClass;
                inputClass.text = resolvedClass;

                var modes = getModeListForClass(resolvedClass);
                ddMode.setOptions(modes);
                var firstMode = modes[0];
                ddMode.setSelectedItem(firstMode);
                loadModeDetails(resolvedClass, firstMode);
            });
            ddClass.x = 25;
            ddClass.y = 60;
            ddClass.setSelectedItem(classOptions.indexOf(selectedClass) != -1 ? selectedClass : "Current");

            loadModeDetails(selectedClass, initialSelMode);

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
            var b1 = ApiPromptModal.createButton("+1", 32, 24, function() appendSkill("1"), false);
            b1.x = 25; b1.y = 272; dlg.addChild(b1);

            var b2 = ApiPromptModal.createButton("+2", 32, 24, function() appendSkill("2"), false);
            b2.x = 61; b2.y = 272; dlg.addChild(b2);

            var b3 = ApiPromptModal.createButton("+3", 32, 24, function() appendSkill("3"), false);
            b3.x = 97; b3.y = 272; dlg.addChild(b3);

            var b4 = ApiPromptModal.createButton("+4", 32, 24, function() appendSkill("4"), false);
            b4.x = 133; b4.y = 272; dlg.addChild(b4);

            var b5 = ApiPromptModal.createButton("+5", 32, 24, function() appendSkill("5"), false);
            b5.x = 169; b5.y = 272; dlg.addChild(b5);

            var bArrow = ApiPromptModal.createButton("+ >", 36, 24, function():Void {
                var cur = StringTools.trim(inputCombo.text);
                if (cur.length > 0 && !StringTools.endsWith(cur, ">")) {
                    inputCombo.text = cur + " >";
                }
            }, false);
            bArrow.x = 205; bArrow.y = 272; dlg.addChild(bArrow);

            var b14 = ApiPromptModal.createButton("+ 1-4", 46, 24, function():Void {
                var cur = StringTools.trim(inputCombo.text);
                if (cur.length == 0) {
                    inputCombo.text = "1 > 2 > 3 > 4";
                } else if (StringTools.endsWith(cur, ">")) {
                    inputCombo.text = cur + " 1 > 2 > 3 > 4";
                } else {
                    inputCombo.text = cur + " > 1 > 2 > 3 > 4";
                }
            }, false);
            b14.x = 245; b14.y = 272; dlg.addChild(b14);

            var bClear = ApiPromptModal.createButton("Clear", 45, 24, function():Void {
                inputCombo.text = "";
            }, false);
            bClear.x = 295; bClear.y = 272; dlg.addChild(bClear);

            var bHp = ApiPromptModal.createButton("+[hp < 50%]", 95, 24, function() appendRule("[hp < 50%]"), false);
            bHp.x = 344; bHp.y = 272; dlg.addChild(bHp);

            var bMp = ApiPromptModal.createButton("+[mp < 20%]", 95, 24, function() appendRule("[mp < 20%]"), false);
            bMp.x = 442; bMp.y = 272; dlg.addChild(bMp);

            // Quick helper row 2: auras and conditions
            var bAuraSelf = ApiPromptModal.createButton("+[!aura(self:Name)]", 132, 24, function() appendRule("[!aura(self:Name)]"), false);
            bAuraSelf.x = 25; bAuraSelf.y = 302; dlg.addChild(bAuraSelf);

            var bAuraTgt = ApiPromptModal.createButton("+[aura(target:Name)]", 142, 24, function() appendRule("[aura(target:Name)]"), false);
            bAuraTgt.x = 162; bAuraTgt.y = 302; dlg.addChild(bAuraTgt);

            var bParty = ApiPromptModal.createButton("+[party:hp < 50%]", 120, 24, function() appendRule("[party:hp < 50%]"), false);
            bParty.x = 309; bParty.y = 302; dlg.addChild(bParty);

            var bWait = ApiPromptModal.createButton("+[wait(500ms)]", 100, 24, function() appendRule("[wait(500ms)]"), false);
            bWait.x = 434; bWait.y = 302; dlg.addChild(bWait);

            var lblHint = ApiPromptModal.createLabel("Syntax: 3[!aura(self:Name)] > 1 > 2 > 4[mp < 20 | hp < 50%] (raw & %) | &, |", 510, 11);
            lblHint.x = 25;
            lblHint.y = 336;
            lblHint.textColor = 0x888888;
            dlg.addChild(lblHint);

            var saveBtn = ApiPromptModal.createButton("Save Mode", 100, 36, function():Void {
                var cName = StringTools.trim(inputClass.text);
                var mName = StringTools.trim(inputMode.text);
                var execMode = ddExecMode.selectedItem;
                var timeout = AqwUtils.parseInt(StringTools.trim(inputTimeout.text), 100);
                var combo = StringTools.trim(inputCombo.text);

                if (cName == "") {
                    ApiNotificationManager.notify("Error: Class name cannot be empty!");
                    return;
                }
                if (mName == "" || mName == "[+ New Mode]") {
                    ApiNotificationManager.notify("Error: Please provide a valid mode name!");
                    return;
                }
                if (combo == "") {
                    ApiNotificationManager.notify("Error: Skill combo rotation cannot be empty!");
                    return;
                }

                var ok = UserSkillsManager.saveMode(cName, mName, execMode, timeout, combo);
                if (ok) {
                    // Automatically activate for Smart Combat
                    HelperSetting.setString("api_smart_class", cName);
                    HelperSetting.setString("api_smart_mode", mName);
                    CombatEngine.smartClass = cName;
                    CombatEngine.skillMode = mName;
                    if (AqwApi.combat != null) {
                        AqwApi.combat.mode = mName;
                    }

                    ApiNotificationManager.notify("Saved & Activated [" + cName + " : " + mName + "]!");
                    var freshClassOpts = getAllClassOptions();
                    ddClass.setOptions(freshClassOpts);
                    ddClass.setSelectedItem(cName);

                    var freshModes = getModeListForClass(cName);
                    ddMode.setOptions(freshModes);
                    ddMode.setSelectedItem(mName);
                    loadModeDetails(cName, mName);
                } else {
                    ApiNotificationManager.notify("Error: Failed to write to userSkills.txt!");
                }
            }, true);
            saveBtn.x = 20;
            saveBtn.y = 370;
            dlg.addChild(saveBtn);

            var applyBtn = ApiPromptModal.createButton("Apply Mode", 100, 36, function():Void {
                var cName = StringTools.trim(inputClass.text);
                var mName = StringTools.trim(inputMode.text);
                if (cName == "" || mName == "" || mName == "[+ New Mode]") {
                    ApiNotificationManager.notify("Error: Select a valid class and mode to apply!");
                    return;
                }
                HelperSetting.setString("api_smart_class", cName);
                HelperSetting.setString("api_smart_mode", mName);
                CombatEngine.smartClass = cName;
                CombatEngine.skillMode = mName;
                if (AqwApi.combat != null) {
                    AqwApi.combat.mode = mName;
                }
                ApiNotificationManager.notify("Activated [" + cName + " : " + mName + "] for Smart Combat!");
            }, true);
            applyBtn.x = 125;
            applyBtn.y = 370;
            dlg.addChild(applyBtn);

            var delBtn = ApiPromptModal.createButton("Delete Mode", 95, 36, function():Void {
                var cName = StringTools.trim(inputClass.text);
                var mName = StringTools.trim(inputMode.text);

                if (cName == "" || mName == "" || mName == "[+ New Mode]") {
                    ApiNotificationManager.notify("Error: Select a valid mode to delete!");
                    return;
                }

                if (!UserSkillsManager.isUserMode(cName, mName)) {
                    ApiNotificationManager.notify("Cannot delete default bundled mode from skills.txt!");
                    return;
                }

                var deleted = UserSkillsManager.deleteMode(cName, mName);
                if (deleted) {
                    ApiNotificationManager.notify("Deleted [" + cName + " : " + mName + "] from userSkills.txt!");
                    var freshClassOpts = getAllClassOptions();
                    ddClass.setOptions(freshClassOpts);
                    ddClass.setSelectedItem(freshClassOpts.indexOf(cName) != -1 ? cName : (freshClassOpts.length > 0 ? freshClassOpts[0] : "Current"));
                    var modes = getModeListForClass(cName);
                    ddMode.setOptions(modes);
                    var nextMode = (modes.length > 0) ? modes[0] : "[+ New Mode]";
                    ddMode.setSelectedItem(nextMode);
                    loadModeDetails(cName, nextMode);
                } else {
                    ApiNotificationManager.notify("Mode was not found in userSkills.txt!");
                }
            }, false);
            delBtn.x = 230;
            delBtn.y = 370;
            dlg.addChild(delBtn);

            var backBtn = ApiPromptModal.createButton("AutoCombat Setup", 125, 36, function():Void {
                ApiPromptModal.close();
                showSmartCombatPrompt(overlay);
            }, false);
            backBtn.x = 330;
            backBtn.y = 370;
            dlg.addChild(backBtn);

            var closeBtn = ApiPromptModal.createButton("Close", 75, 36, function():Void {
                ApiPromptModal.close();
            }, false);
            closeBtn.x = 460;
            closeBtn.y = 370;
            dlg.addChild(closeBtn);

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
            var dlg = ApiPromptModal.createDialog(420, 390, "Class Loadouts (For Scripts)");

            var availableClasses = getAvailableClasses();
            if (availableClasses == null || availableClasses.length == 0) availableClasses = ["Current"];

            setupLoadoutRow(dlg, "FARM Loadout:", 45, 70, availableClasses, "api_farm_class", "api_farm_mode", function(c:String, m:String):Void {
                CombatEngine.farmClass = c;
                CombatEngine.farmMode = m;
            });

            setupLoadoutRow(dlg, "SOLO Loadout:", 110, 135, availableClasses, "api_solo_class", "api_solo_mode", function(c:String, m:String):Void {
                CombatEngine.soloClass = c;
                CombatEngine.soloMode = m;
            });

            setupLoadoutRow(dlg, "BOSS Loadout:", 175, 200, availableClasses, "api_boss_class", "api_boss_mode", function(c:String, m:String):Void {
                CombatEngine.bossClass = c;
                CombatEngine.bossMode = m;
            });

            setupLoadoutRow(dlg, "DODGE Loadout:", 240, 265, availableClasses, "api_dodge_class", "api_dodge_mode", function(c:String, m:String):Void {
                CombatEngine.dodgeClass = c;
                CombatEngine.dodgeMode = m;
            });

            var doneBtn = ApiPromptModal.createButton("Done", 140, 35, function():Void {
                ApiPromptModal.close();
                ApiNotificationManager.notify("Class Loadouts Saved!");
            }, true);
            doneBtn.x = 140;
            doneBtn.y = 330;
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
        var lbl = ApiPromptModal.createLabel(title, 150, 14, true);
        lbl.x = 20;
        lbl.y = lblY;
        dlg.addChild(lbl);

        var curClass = HelperSetting.getString(classKey, "Current");
        if (classes.indexOf(curClass) == -1) curClass = classes[0];
        var modes = CombatEngine.getAvailableModes(curClass);
        if (modes == null || modes.length == 0) modes = ["Base"];
        var curMode = HelperSetting.getString(modeKey, modes[0]);
        if (modes.indexOf(curMode) == -1) curMode = modes[0];

        var ddMode:Dropdown = null;
        ddMode = new Dropdown(120, 25, modes, function(sel:String):Void {
            curMode = sel;
            HelperSetting.setString(modeKey, sel);
            if (onUpdate != null) onUpdate(curClass, curMode);
        });
        ddMode.x = 280;
        ddMode.y = ddY;

        var ddClass:Dropdown = null;
        ddClass = new Dropdown(240, 25, classes, function(sel:String):Void {
            curClass = sel;
            HelperSetting.setString(classKey, sel);
            var nm = CombatEngine.getAvailableModes(curClass);
            if (nm == null || nm.length == 0) nm = ["Base"];
            ddMode.setOptions(nm);
            if (nm.indexOf(curMode) == -1) {
                curMode = nm[0];
            }
            ddMode.setSelectedItem(curMode);
            HelperSetting.setString(modeKey, curMode);
            if (onUpdate != null) onUpdate(curClass, curMode);
        });
        ddClass.x = 20;
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

        // Inventory armors/classes
        if (AqwApi.game != null && AqwApi.game.world != null && AqwApi.game.world.myAvatar != null && AqwApi.game.world.myAvatar.items != null) {
            try {
                var items:Dynamic = AqwApi.game.world.myAvatar.items;
                if (Std.isOfType(items, Array)) {
                    for (item in (cast items : Array<Dynamic>)) {
                        if (item == null || item.sName == null) continue;
                        var isClass:Bool = false;
                        var sTypeStr:String = (item.sType != null) ? Std.string(item.sType).toLowerCase() : "";
                        if (sTypeStr == "class" || item.bClass == 1 || item.bClass == true) {
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

        // Custom classes from userSkills.txt
        try {
            var userTxt = UserSkillsManager.readUserSkills();
            if (userTxt != null && userTxt.length > 0) {
                var parsed = com.aqwapi.utils.SkillDslParser.parse(userTxt);
                if (parsed != null) {
                    for (cKey in Reflect.fields(parsed)) addClass(cKey);
                }
            }
        } catch (_:Dynamic) {}

        try {
            invClasses.sort(function(a, b) {
                var la:String = a.toLowerCase();
                var lb:String = b.toLowerCase();
                if (la < lb) return -1;
                if (la > lb) return 1;
                return 0;
            });
        } catch (e:Dynamic) {}

        // Always put "Current" as the first option
        return ["Current"].concat(invClasses);
    }

    private static function getCurrentClass():String {
        try {
            if (AqwApi.game != null && AqwApi.game.world != null && AqwApi.game.world.myAvatar != null) {
                var av:Dynamic = AqwApi.game.world.myAvatar;
                if (av.objData != null && av.objData.strClassName != null) {
                    var c:String = Std.string(av.objData.strClassName);
                    if (c != "" && c != "null") return c;
                }
                if (av.items != null) {
                    try {
                        var items:Array<Dynamic> = cast av.items;
                        for (it in items) {
                            if (it == null) continue;
                            var equipped:Bool = (it.bEquip == 1 || it.bEquip == "1" || it.bEquip == true);
                            if (!equipped) continue;
                            var isClass:Bool = false;
                            if (it.sType != null && Std.string(it.sType).toLowerCase() == "class") isClass = true;
                            else if (it.bClass == 1 || it.bClass == true) isClass = true;
                            else if (it.sES != null && Std.string(it.sES).toLowerCase() == "ar") isClass = true;
                            if (isClass && it.sName != null) {
                                var s:String = Std.string(it.sName);
                                if (s != "" && s != "null") return s;
                            }
                        }
                    } catch (ie:Dynamic) {}
                }
            }
        } catch (e:Dynamic) {}
        return "";
    }
}
#else
class ApiPrompts {
    public static function showCombatModeEditorPrompt(overlay:Dynamic, initialClass:String = null, initialMode:String = null):Void {}
}
#end

