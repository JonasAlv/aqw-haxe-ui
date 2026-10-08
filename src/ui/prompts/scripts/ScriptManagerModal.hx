package ui.prompts.scripts;

#if flash
import com.aqwapi.Api;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.utils.ApiLogger;
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import ui.ApiNotificationManager;
import ui.ApiStyle;
import ui.Dropdown;
import ui.prompts.ApiPromptModal;

class ScriptManagerModal {
    public static function show(overlay:Dynamic):Void {
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
            lblStatus.textColor = ApiStyle.COLOR_STATUS_INACTIVE;
            dlg.addChild(lblStatus);

            // Code Editor
            var lblCode = ApiPromptModal.createLabel("Script Code (HScript / .hxs):", 300);
            lblCode.x = 20;
            lblCode.y = 114;
            dlg.addChild(lblCode);

            var inputCode = ApiPromptModal.createInput(580, 290, "", true);
            var codeFmt = new flash.text.TextFormat("_typewriter", 12, ApiStyle.COLOR_TEXT_PRIMARY);
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
                    statusDot.graphics.beginFill(ApiStyle.COLOR_STATUS_ACTIVE, 0.35);
                    statusDot.graphics.drawCircle(0, 0, 4.5);
                    statusDot.graphics.endFill();
                    statusDot.graphics.beginFill(ApiStyle.COLOR_STATUS_ACTIVE, 1.0);
                    statusDot.graphics.drawCircle(0, 0, 2.5);
                    statusDot.graphics.endFill();

                    lblStatus.text = "STATUS: RUNNING (" + (actName != null ? actName : "Custom Script") + ")";
                    lblStatus.textColor = ApiStyle.COLOR_STATUS_ACTIVE;
                    if (runBtnTxt != null) runBtnTxt.text = "Stop Script";
                } else {
                    statusDot.graphics.beginFill(ApiStyle.COLOR_STATUS_INACTIVE, 0.9);
                    statusDot.graphics.drawCircle(0, 0, 2.5);
                    statusDot.graphics.endFill();

                    lblStatus.text = "STATUS: STOPPED";
                    lblStatus.textColor = ApiStyle.COLOR_STATUS_INACTIVE;
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
class ScriptManagerModal {
    public static function show(overlay:Dynamic):Void {}
}
#end
