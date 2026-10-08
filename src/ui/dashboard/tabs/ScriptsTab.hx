package ui.dashboard.tabs;

#if flash
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.utils.ApiLogger;
import ui.ApiDashboardModal;
import ui.ApiNotificationManager;
import ui.dashboard.IDashboardTab;
import ui.prompts.ApiPrompts;

class ScriptsTab implements IDashboardTab {
    public function new() {}

    public function render(modal:ApiDashboardModal):Void {
        modal.addSectionHeader("Script Execution");

        // 1. Script Manager
        modal.addItemRow(
            "Script Manager",
            "Manage, edit, create, save, and run automation scripts.",
            "button",
            "Open",
            true, // Primary red button!
            function():Void {
                ApiPrompts.showScriptManager(modal.overlay);
            }
        );

        // 2. Script Engine State (Run/Stop toggle)
        modal.addItemRow(
            "Script Runner",
            "Controls active script execution. Turn off to immediately abort any running script.",
            "toggle",
            "",
            false,
            function():Void {
                if (ScriptManager.SINGLETON.isRunning) {
                    ScriptManager.SINGLETON.stop();
                    ApiNotificationManager.notify("Script stopped.");
                } else {
                    ScriptManager.SINGLETON.start();
                    if (ScriptManager.SINGLETON.isRunning) {
                        ApiNotificationManager.notify("Script started.");
                    } else {
                        ApiNotificationManager.notify("No script loaded! Open Script Manager to select one.");
                    }
                }
            },
            function():Bool {
                return ScriptManager.SINGLETON.isRunning;
            }
        );

        // 3. Load Script from file
        #if air
        modal.addItemRow(
            "Load Script File",
            "Browse and load an .hscript or text file directly from your local filesystem.",
            "button",
            "Load",
            false,
            function():Void {
                try {
                    var fileCls:Dynamic = untyped __global__["flash.filesystem.File"];
                    var fsCls:Dynamic = untyped __global__["flash.filesystem.FileStream"];
                    var fmCls:Dynamic = untyped __global__["flash.filesystem.FileMode"];
                    var ffCls:Dynamic = untyped __global__["flash.net.FileFilter"];

                    var file = fileCls.desktopDirectory;
                    file.addEventListener("select", function(ev:Dynamic):Void {
                        var stream = Type.createInstance(fsCls, []);
                        stream.open(file, fmCls.READ);
                        var content:String = stream.readUTFBytes(stream.bytesAvailable);
                        stream.close();

                        ScriptManager.SINGLETON.loadScript(content);
                        ScriptManager.SINGLETON.start();
                        ApiNotificationManager.notify("Loaded: " + file.name);
                    });
                    file.browseForOpen("Select Script", [Type.createInstance(ffCls, ["HScript / Text (*.hscript, *.txt)", "*.hscript;*.txt"])]);
                } catch (e:Dynamic) {
                    ApiNotificationManager.notify("File error: " + e);
                }
            }
        );
        #end

        // 4. Paste Script
        modal.addItemRow(
            "Paste Script",
            "Paste raw HScript code and execute it immediately in the runtime engine.",
            "button",
            "Paste",
            false,
            function():Void {
                ApiPrompts.showPastePrompt(modal.overlay);
            }
        );

        modal.addSectionHeader("Automation & Logging");

        // 5. Class Loadouts (For Scripts)
        modal.addItemRow(
            "Class Loadouts (Scripting)",
            "Configure default Farm, Solo, Boss, and Dodge classes for script auto-swapping.",
            "button",
            "Setup",
            false,
            function():Void {
                ApiPrompts.showLoadoutsPrompt(modal.overlay);
            }
        );

        // 6. Clear Log
        modal.addItemRow(
            "Clear Bot Log",
            "Truncates bot.log to start fresh for monitoring and debugging sessions.",
            "button",
            "Clear Log",
            false,
            function():Void {
                ApiLogger.clearLog();
                ApiNotificationManager.notify("bot.log cleared!");
            }
        );
    }
}
#else
class ScriptsTab implements ui.dashboard.IDashboardTab {
    public function new() {}
    public function render(modal:Dynamic):Void {}
}
#end
