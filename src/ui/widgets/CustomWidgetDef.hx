package ui.widgets;

typedef WidgetItemConfig = {
    toolId:String,
    isFixed:Bool
};

typedef CustomWidgetDef = {
    id:String,
    title:String,
    x:Float,
    y:Float,
    isCollapsed:Bool,
    enabled:Bool,
    items:Array<WidgetItemConfig>
};
