package ui.prompts.combat;

#if flash
import com.aqwapi.Api;
import com.aqwapi.managers.SkillManager;
import com.aqwapi.modules.CombatEngine;
import com.aqwapi.utils.ApiConfig;
import com.aqwapi.utils.ApiLogger;
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.Dropdown;
import ui.prompts.ApiPromptModal;
import ui.prompts.ApiPrompts;

class CombatModeEditorModal {
    public static function show(overlay:Dynamic, initialClass:String = null, initialMode:String = null):Void {
        try {
            try { SkillManager.ensureStorageInitialized(); } catch (_:Dynamic) {}
            var dlg = ApiPromptModal.createDialog(800, 494, "Combat Mode Editor");

            // Gather class options (Strictly classes currently in inventory + Current)
            var classOptions:Array<String> = ApiPrompts.getAvailableClasses();
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

            var lblClass = ApiPromptModal.createLabel("Select Class:", 250);
            lblClass.x = 25;
            lblClass.y = 36;
            dlg.addChild(lblClass);

            var lblCustomClass = ApiPromptModal.createLabel("Class Name:", 250);
            lblCustomClass.x = 415;
            lblCustomClass.y = 36;
            dlg.addChild(lblCustomClass);

            var inputClass = ApiPromptModal.createInput(360, 26, initialInputClass);
            inputClass.x = 415;
            inputClass.y = 54;
            dlg.addChild(inputClass);

            var lblMode = ApiPromptModal.createLabel("Select Mode:", 250);
            lblMode.x = 25;
            lblMode.y = 85;
            dlg.addChild(lblMode);

            var lblCustomMode = ApiPromptModal.createLabel("Mode Name:", 100);
            lblCustomMode.x = 415;
            lblCustomMode.y = 85;
            dlg.addChild(lblCustomMode);

            var lblBadge = ApiPromptModal.createLabel("[Bundled Mode]", 260, 11, true);
            var bFmt = new flash.text.TextFormat(ApiStyle.FONT_FAMILY, 11, ApiStyle.COLOR_TEXT_MUTED, true);
            bFmt.align = flash.text.TextFormatAlign.RIGHT;
            lblBadge.defaultTextFormat = bFmt;
            lblBadge.x = 515;
            lblBadge.y = 85;
            dlg.addChild(lblBadge);

            var updateBadge = function(text:String, color:Int):Void {
                if (lblBadge == null) return;
                var fmt = new flash.text.TextFormat(ApiStyle.FONT_FAMILY, 11, color, true);
                fmt.align = flash.text.TextFormatAlign.RIGHT;
                lblBadge.defaultTextFormat = fmt;
                lblBadge.text = text;
                lblBadge.textColor = color;
            };

            var inputMode = ApiPromptModal.createInput(360, 26, "Base");
            inputMode.x = 415;
            inputMode.y = 103;
            dlg.addChild(inputMode);

            var lblExecMode = ApiPromptModal.createLabel("Execution Mode:", 250);
            lblExecMode.x = 25;
            lblExecMode.y = 134;
            dlg.addChild(lblExecMode);

            var lblTimeout = ApiPromptModal.createLabel("Timeout (ms):", 90);
            lblTimeout.x = 415;
            lblTimeout.y = 134;
            dlg.addChild(lblTimeout);

            var lblBehavior = ApiPromptModal.createLabel("Combat Behavior:", 250);
            lblBehavior.x = 505;
            lblBehavior.y = 134;
            dlg.addChild(lblBehavior);

            var inputTimeout = ApiPromptModal.createInput(80, 26, "0");
            inputTimeout.x = 415;
            inputTimeout.y = 152;
            dlg.addChild(inputTimeout);

            var currentResetOnTarget:Bool = false;
            var btnResetTarget:flash.display.Sprite = null;
            var updateResetTargetBtn = function():Void {
                if (btnResetTarget == null) return;
                var targetText = currentResetOnTarget ? "Reset: ON" : "Reset: OFF";
                var targetColor = currentResetOnTarget ? ApiStyle.COLOR_TEXT_SUCCESS : ApiStyle.COLOR_TEXT_MUTED;
                var txt = (btnResetTarget.numChildren > 0 && Std.isOfType(btnResetTarget.getChildAt(0), flash.text.TextField))
                    ? cast(btnResetTarget.getChildAt(0), flash.text.TextField)
                    : null;
                if (txt != null) {
                    txt.text = targetText;
                    txt.textColor = targetColor;
                }
            };

            btnResetTarget = ApiPromptModal.createButton("Reset: OFF", 125, 26, function():Void {
                currentResetOnTarget = !currentResetOnTarget;
                updateResetTargetBtn();
            }, false);
            btnResetTarget.x = 505;
            btnResetTarget.y = 152;
            dlg.addChild(btnResetTarget);

            // Tri-state Auto Attack: null = inherit (the class default decides), true/false = mode
            // override. The mode is the more specific setting, so it always wins; the class object is
            // only a default for modes that do not declare their own. That is why "Mode ON" is
            // meaningful here unconditionally - it used to be greyed out whenever the class had a flag.
            var currentAutoAttack:Null<Bool> = null;
            var btnAutoAttack:flash.display.Sprite = null;
            var updateAutoAttackBtn = function():Void {
                if (btnAutoAttack == null) return;
                var targetText:String = "";
                var targetColor:Int = ApiStyle.COLOR_TEXT_MUTED;
                if (currentAutoAttack == null) {
                    targetText = "AA: Inherit";
                    targetColor = ApiStyle.COLOR_TEXT_MUTED;
                } else if (currentAutoAttack == true) {
                    targetText = "AA: Mode ON";
                    targetColor = ApiStyle.COLOR_TEXT_SUCCESS;
                } else {
                    targetText = "AA: Mode OFF";
                    targetColor = ApiStyle.COLOR_TEXT_WARNING;
                }
                var txt = (btnAutoAttack.numChildren > 0 && Std.isOfType(btnAutoAttack.getChildAt(0), flash.text.TextField))
                    ? cast(btnAutoAttack.getChildAt(0), flash.text.TextField)
                    : null;
                if (txt != null) {
                    txt.text = targetText;
                    txt.textColor = targetColor;
                }
            };

            btnAutoAttack = ApiPromptModal.createButton("AA: Inherit", 135, 26, function():Void {
                currentAutoAttack = (currentAutoAttack == null) ? true : ((currentAutoAttack == true) ? false : null);
                updateAutoAttackBtn();
            }, false);
            btnAutoAttack.x = 640;
            btnAutoAttack.y = 152;
            dlg.addChild(btnAutoAttack);

            var lblStopAuras = ApiPromptModal.createLabel("Stop on Target Auras (Reflect / Shields - comma separated):", 750);
            lblStopAuras.x = 25;
            lblStopAuras.y = 184;
            dlg.addChild(lblStopAuras);

            var inputStopAuras = ApiPromptModal.createInput(750, 24, "");
            inputStopAuras.x = 25;
            inputStopAuras.y = 202;
            dlg.addChild(inputStopAuras);

            var lblCombo = ApiPromptModal.createLabel("Skill Combo / Rotation (1-Liner DSL):", 750);
            lblCombo.x = 25;
            lblCombo.y = 230;
            dlg.addChild(lblCombo);

            var inputCombo = ApiPromptModal.createInput(750, 44, "", true);
            inputCombo.x = 25;
            inputCombo.y = 248;
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
                tf.backgroundColor = enabled ? ApiStyle.COLOR_BG_INPUT : ApiStyle.COLOR_BG_SURFACE;
                tf.borderColor = enabled ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT;
                tf.textColor = enabled ? ApiStyle.COLOR_TEXT_PRIMARY : ApiStyle.COLOR_TEXT_MUTED;
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
                    updateBadge("[New Mode]", ApiStyle.COLOR_TEXT_SUCCESS);
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
                    var classAA = SkillManager.getClassAutoAttackFlag(effectiveClass);
                    var aaSuffix = (classAA == null) ? "" : (classAA ? "  (Class AA: ON)" : "  (Class AA: OFF)");
                    if (isUser) {
                        updateBadge("[User Mode]" + aaSuffix, ApiStyle.COLOR_TEXT_CYAN);
                    } else {
                        updateBadge("[Bundled Mode]" + aaSuffix, ApiStyle.COLOR_TEXT_MUTED);
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
                    updateBadge("[New Mode]", ApiStyle.COLOR_TEXT_SUCCESS);
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

            ddExecMode = new Dropdown(360, 26, ["WaitForCooldown", "UseIfAvailable"], function(sel:String):Void {});
            ddExecMode.x = 25;
            ddExecMode.y = 152;
            ddExecMode.setSelectedItem("WaitForCooldown");

            var initialModes = getModeListForClass(selectedClass);
            var initialSelMode = (initialMode != null && initialMode != "" && initialModes.indexOf(initialMode) != -1) ? initialMode : (initialModes.length > 0 ? initialModes[0] : "[+ New Mode]");

            ddMode = new Dropdown(360, 26, initialModes, function(selMode:String):Void {
                var currentClass = (inputClass != null && inputClass.text != null) ? StringTools.trim(inputClass.text) : "";
                if (currentClass == "") currentClass = selectedClass;
                loadModeDetails(currentClass, selMode);
            });
            ddMode.x = 25;
            ddMode.y = 103;
            ddMode.setSelectedItem(initialSelMode);

            ddClass = new Dropdown(360, 26, classOptions, function(selClass:String):Void {
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
            ddClass.y = 54;
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

            // Quick helper row 1: Skills & Flow (left) + HP/MP/Party triggers (right)
            var b0 = ApiPromptModal.createButton("0", 28, 24, function() appendSkill("0"), false, null, null, 12);
            b0.x = 25; b0.y = 298; dlg.addChild(b0); helperButtons.push(b0);

            var b1 = ApiPromptModal.createButton("1", 28, 24, function() appendSkill("1"), false, null, null, 12);
            b1.x = 57; b1.y = 298; dlg.addChild(b1); helperButtons.push(b1);

            var b2 = ApiPromptModal.createButton("2", 28, 24, function() appendSkill("2"), false, null, null, 12);
            b2.x = 89; b2.y = 298; dlg.addChild(b2); helperButtons.push(b2);

            var b3 = ApiPromptModal.createButton("3", 28, 24, function() appendSkill("3"), false, null, null, 12);
            b3.x = 121; b3.y = 298; dlg.addChild(b3); helperButtons.push(b3);

            var b4 = ApiPromptModal.createButton("4", 28, 24, function() appendSkill("4"), false, null, null, 12);
            b4.x = 153; b4.y = 298; dlg.addChild(b4); helperButtons.push(b4);

            var b5 = ApiPromptModal.createButton("5", 28, 24, function() appendSkill("5"), false, null, null, 12);
            b5.x = 185; b5.y = 298; dlg.addChild(b5); helperButtons.push(b5);

            var bArrow = ApiPromptModal.createButton(">", 32, 24, function():Void {
                var cur = StringTools.trim(inputCombo.text);
                if (cur.length > 0 && !StringTools.endsWith(cur, ">")) {
                    inputCombo.text = cur + " >";
                }
            }, false, null, null, 12);
            bArrow.x = 217; bArrow.y = 298; dlg.addChild(bArrow); helperButtons.push(bArrow);

            var b14 = ApiPromptModal.createButton("1-4", 42, 24, function():Void {
                var cur = StringTools.trim(inputCombo.text);
                if (cur.length == 0) {
                    inputCombo.text = "1 > 2 > 3 > 4";
                } else if (StringTools.endsWith(cur, ">")) {
                    inputCombo.text = cur + " 1 > 2 > 3 > 4";
                } else {
                    inputCombo.text = cur + " > 1 > 2 > 3 > 4";
                }
            }, false, null, null, 12);
            b14.x = 253; b14.y = 298; dlg.addChild(b14); helperButtons.push(b14);

            var bClear = ApiPromptModal.createButton("Clear", 50, 24, function():Void {
                inputCombo.text = "";
            }, false, null, null, 11);
            bClear.x = 299; bClear.y = 298; dlg.addChild(bClear); helperButtons.push(bClear);

            var bHp = ApiPromptModal.createButton("hp < 50%", 90, 24, function() appendRule("[hp < 50%]"), false, ApiStyle.COLOR_BTN_BG_SUCCESS, ApiStyle.COLOR_BTN_BORDER_SUCCESS, 11, ApiStyle.COLOR_TEXT_SUCCESS);
            bHp.x = 370; bHp.y = 298; dlg.addChild(bHp); helperButtons.push(bHp);

            var bTgtHp = ApiPromptModal.createButton("tgt:hp < 50%", 110, 24, function() appendRule("[tgt:hp < 50%]"), false, ApiStyle.COLOR_BTN_BG_SUCCESS, ApiStyle.COLOR_BTN_BORDER_SUCCESS, 11, ApiStyle.COLOR_TEXT_SUCCESS);
            bTgtHp.x = 468; bTgtHp.y = 298; dlg.addChild(bTgtHp); helperButtons.push(bTgtHp);

            var bMp = ApiPromptModal.createButton("mp < 20%", 85, 24, function() appendRule("[mp < 20%]"), false, ApiStyle.COLOR_BTN_BG_SUCCESS, ApiStyle.COLOR_BTN_BORDER_SUCCESS, 11, ApiStyle.COLOR_TEXT_SUCCESS);
            bMp.x = 586; bMp.y = 298; dlg.addChild(bMp); helperButtons.push(bMp);

            var bParty = ApiPromptModal.createButton("party < 50%", 96, 24, function() appendRule("[party:hp < 50%]"), false, ApiStyle.COLOR_BTN_BG_SUCCESS, ApiStyle.COLOR_BTN_BORDER_SUCCESS, 11, ApiStyle.COLOR_TEXT_SUCCESS);
            bParty.x = 679; bParty.y = 298; dlg.addChild(bParty); helperButtons.push(bParty);

            // Quick helper row 2: Auras & Timers
            var bAuraSelf = ApiPromptModal.createButton("!aura(self)", 135, 24, function() appendRule("[!aura(self:Name)]"), false, ApiStyle.COLOR_BTN_BG_PURPLE, ApiStyle.COLOR_BTN_BORDER_PURPLE, 11, ApiStyle.COLOR_TEXT_PURPLE);
            bAuraSelf.x = 25; bAuraSelf.y = 328; dlg.addChild(bAuraSelf); helperButtons.push(bAuraSelf);

            var bAuraSelfHas = ApiPromptModal.createButton("aura(self)", 130, 24, function() appendRule("[aura(self:Name)]"), false, ApiStyle.COLOR_BTN_BG_PURPLE, ApiStyle.COLOR_BTN_BORDER_PURPLE, 11, ApiStyle.COLOR_TEXT_PURPLE);
            bAuraSelfHas.x = 168; bAuraSelfHas.y = 328; dlg.addChild(bAuraSelfHas); helperButtons.push(bAuraSelfHas);

            var bAuraTgt = ApiPromptModal.createButton("aura(target)", 135, 24, function() appendRule("[aura(target:Name)]"), false, ApiStyle.COLOR_BTN_BG_PURPLE, ApiStyle.COLOR_BTN_BORDER_PURPLE, 11, ApiStyle.COLOR_TEXT_PURPLE);
            bAuraTgt.x = 306; bAuraTgt.y = 328; dlg.addChild(bAuraTgt); helperButtons.push(bAuraTgt);

            var bAuraTime = ApiPromptModal.createButton("auraTime <= 1.5s", 175, 24, function() appendRule("[auraTime(self:Name) <= 1.5s]"), false, ApiStyle.COLOR_BTN_BG_PURPLE, ApiStyle.COLOR_BTN_BORDER_PURPLE, 11, ApiStyle.COLOR_TEXT_PURPLE);
            bAuraTime.x = 449; bAuraTime.y = 328; dlg.addChild(bAuraTime); helperButtons.push(bAuraTime);

            var bWait = ApiPromptModal.createButton("wait(500ms)", 143, 24, function() appendRule("[wait(500ms)]"), false, ApiStyle.COLOR_BTN_BG_PURPLE, ApiStyle.COLOR_BTN_BORDER_PURPLE, 11, ApiStyle.COLOR_TEXT_PURPLE);
            bWait.x = 632; bWait.y = 328; dlg.addChild(bWait); helperButtons.push(bWait);

            // Quick helper row 3: Attack Counter Conditions
            var bCounterPlain = ApiPromptModal.createButton("[counter]", 120, 24, function() appendRule("[counter]"), false, ApiStyle.COLOR_BTN_BG_WARN, ApiStyle.COLOR_BTN_BORDER_WARN, 11, ApiStyle.COLOR_TEXT_WARNING);
            bCounterPlain.x = 25; bCounterPlain.y = 358; dlg.addChild(bCounterPlain); helperButtons.push(bCounterPlain);

            var bCounter = ApiPromptModal.createButton("[counter <= 1.5s]", 165, 24, function() appendRule("[counter <= 1.5s]"), false, ApiStyle.COLOR_BTN_BG_WARN, ApiStyle.COLOR_BTN_BORDER_WARN, 11, ApiStyle.COLOR_TEXT_WARNING);
            bCounter.x = 153; bCounter.y = 358; dlg.addChild(bCounter); helperButtons.push(bCounter);

            var bCounterMiss = ApiPromptModal.createButton("[counter=miss]", 140, 24, function() appendRule("[counter=miss]"), false, ApiStyle.COLOR_BTN_BG_WARN, ApiStyle.COLOR_BTN_BORDER_WARN, 11, ApiStyle.COLOR_TEXT_WARNING);
            bCounterMiss.x = 326; bCounterMiss.y = 358; dlg.addChild(bCounterMiss); helperButtons.push(bCounterMiss);

            var bCounterDodge = ApiPromptModal.createButton("[counter=dodge]", 145, 24, function() appendRule("[counter=dodge]"), false, ApiStyle.COLOR_BTN_BG_WARN, ApiStyle.COLOR_BTN_BORDER_WARN, 11, ApiStyle.COLOR_TEXT_WARNING);
            bCounterDodge.x = 474; bCounterDodge.y = 358; dlg.addChild(bCounterDodge); helperButtons.push(bCounterDodge);

            var bCounterCount = ApiPromptModal.createButton("[counter x2]", 148, 24, function() appendRule("[counter x2]"), false, ApiStyle.COLOR_BTN_BG_WARN, ApiStyle.COLOR_BTN_BORDER_WARN, 11, ApiStyle.COLOR_TEXT_WARNING);
            bCounterCount.x = 627; bCounterCount.y = 358; dlg.addChild(bCounterCount); helperButtons.push(bCounterCount);

            var lblCounterHint = ApiPromptModal.createLabel(
                "Slots: 0 (Auto Attack), 1-4 (Class Skills), 5 (Potion). Syntax: 3[auraTime(target:Seal) <= 1.5s] > 4 | 1[hp < 50%]\n" +
                "[counter] gates skill until enemy attacks (packet-based). Use time window (<= 1.5s) to avoid hard locking.",
                750, 11);
            lblCounterHint.x = 25;
            lblCounterHint.y = 388;
            lblCounterHint.textColor = ApiStyle.COLOR_TEXT_MUTED;
            dlg.addChild(lblCounterHint);

            saveBtn = ApiPromptModal.createButton("Save Mode", 125, 30, function():Void {
                try {
                    if (lblBadge != null && lblBadge.text != null && lblBadge.text.indexOf("[Bundled Mode]") != -1) {
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
                            var freshClassOpts = ApiPrompts.getAvailableClasses();
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
            saveBtn.y = 448;
            dlg.addChild(saveBtn);

            applyBtn = ApiPromptModal.createButton("Apply Mode", 125, 30, function():Void {
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
                        ApiConfig.setString("api_smart_class", cName);
                        ApiConfig.setString("api_smart_mode", mName);
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
            }, false);
            applyBtn.x = 158;
            applyBtn.y = 448;
            dlg.addChild(applyBtn);

            cloneBtn = ApiPromptModal.createButton("Clone Mode", 120, 30, function():Void {
                try {
                    var baseName = (inputMode != null && inputMode.text != null) ? StringTools.trim(inputMode.text) : "Mode";
                    if (baseName == "" || baseName == "[+ New Mode]") baseName = "CustomMode";
                    if (inputMode != null) inputMode.text = baseName + " Custom";
                    updateBadge("[New Mode]", ApiStyle.COLOR_TEXT_SUCCESS);
                    setFormEditable(true, true);
                    cloneBtn.visible = false;
                    delBtn.visible = false;
                    ApiNotificationManager.notify("Cloned [" + baseName + "] into editable New Mode!");
                } catch (ce:Dynamic) {
                    ApiNotificationManager.notify("Clone error: " + ce);
                }
            }, false);
            cloneBtn.x = 291;
            cloneBtn.y = 448;
            cloneBtn.visible = false;
            dlg.addChild(cloneBtn);

            delBtn = ApiPromptModal.createButton("Delete Mode", 120, 30, function():Void {
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
                                try { ApiConfig.setString("api_smart_mode", fallbackMode); } catch (_:Dynamic) {}
                                try { if (Api.combat != null) Api.combat.mode = fallbackMode; } catch (_:Dynamic) {}
                            }

                            var freshClassOpts = ApiPrompts.getAvailableClasses();
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
            }, false, ApiStyle.COLOR_BTN_BG_DANGER, ApiStyle.COLOR_BTN_BG_DANGER_HOVER, 11, ApiStyle.COLOR_TEXT_TITLE);
            delBtn.x = 291;
            delBtn.y = 448;
            dlg.addChild(delBtn);

            var backBtn = ApiPromptModal.createButton("AutoCombat Setup", 155, 30, function():Void {
                ApiPromptModal.close();
                ApiPrompts.showSmartCombatPrompt(overlay);
            }, false);
            backBtn.x = 502;
            backBtn.y = 448;
            dlg.addChild(backBtn);

            var closeBtn = ApiPromptModal.createButton("Close", 110, 30, function():Void {
                ApiPromptModal.close();
            }, false);
            closeBtn.x = 665;
            closeBtn.y = 448;
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

}
#else
class CombatModeEditorModal {
    public static function show(overlay:Dynamic, initialClass:String = null, initialMode:String = null):Void {}
}
#end
