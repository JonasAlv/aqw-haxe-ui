package ui.dashboard;

#if flash
import ui.ApiDashboardModal;

interface IDashboardTab {
    public function render(modal:ApiDashboardModal):Void;
}
#else
interface IDashboardTab {
    public function render(modal:Dynamic):Void;
}
#end
