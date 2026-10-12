package ui.widgets;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import com.aqwapi.utils.ApiConfig;
import ui.ApiStyle;

/**
 * BaseWidget:
 * Unified base class for all in-game floating widgets (Combat, Jump, Players, Custom).
 *
 * Provides shared:
 * - Header bar (accent pill, title, collapse button, gear config button)
 * - Vector icons (6-tooth gear, collapsible chevron)
 * - Background drawing (main card, border, top bevel)
 * - Touch & mouse dragging with mobile deadzone threshold (4px)
 * - Stage boundary clamping (ApiStyle.SCREEN_MARGIN)
 * - Position & collapse state persistence (ApiConfig)
 * - Lifecycle attach, detach, and per-frame update tick hook
 */
class BaseWidget extends Sprite {
    public static inline var COMPACT_W:Float = ApiStyle.WIDGET_WIDTH_COMPACT;
    public static inline var COMPACT_H:Float = ApiStyle.WIDGET_HEIGHT_COMPACT;

    public var widgetId(default, null):String;
    public var widgetTitle:String;
    public var defaultX:Float;
    public var defaultY:Float;
    public var defaultWidth:Float;
    public var defaultHeight:Float;

    public var isCollapsed:Bool = false;
    public var isEnabled:Bool = true;
    public var hasConfigButton:Bool = true;
    public var hasCollapseButton:Bool = true;
    public var allowHeaderClickToCollapse:Bool = true;

    // Display Components
    public var bg:Sprite;
    public var headerBar:Sprite;
    public var accentShape:Shape;
    public var titleTxt:TextField;
    public var btnConfig:Sprite;
    public var btnCollapse:Sprite;
    public var bodyContainer:Sprite;

    // Stage references
    public var theStage(default, null):Stage = null;
    public var overlay(default, null):Dynamic = null;

    // Dragging state
    private var _isDragging:Bool = false;
    private var _hasDragged:Bool = false;
    private var _startDownX:Float = 0;
    private var _startDownY:Float = 0;
    private var _dragStartX:Float = 0;
    private var _dragStartY:Float = 0;

    // Stage listeners (for clean removal)
    private var _onStageMouseMove:Dynamic = null;
    private var _onStageMouseUp:Dynamic = null;

    public function new(
        id:String,
        title:String,
        defX:Float,
        defY:Float,
        defW:Float,
        defH:Float,
        defaultEnabled:Bool = true,
        defaultCollapsed:Bool = false,
        hasConfig:Bool = true
    ) {
        super();
        this.widgetId = id;
        this.widgetTitle = title;
        this.defaultX = defX;
        this.defaultY = defY;
        this.defaultWidth = defW;
        this.defaultHeight = defH;
        this.hasConfigButton = hasConfig;
        this.name = id + "Widget";

        // Read persistence
        this.isEnabled = ApiConfig.getBool("api_widget_" + id + "_enabled", defaultEnabled);
        this.isCollapsed = ApiConfig.getBool("api_widget_" + id + "_collapsed", defaultCollapsed);

        initChrome();
    }

    private function initChrome():Void {
        // 1. Background plate
        bg = new Sprite();
        addChild(bg);

        // 2. Header Bar
        headerBar = new Sprite();
        headerBar.buttonMode = true;
        headerBar.useHandCursor = true;
        addChild(headerBar);

        // Header Accent Pill
        accentShape = new Shape();
        accentShape.graphics.beginFill(ApiStyle.COLOR_ACCENT_PRIMARY, 1.0);
        accentShape.graphics.drawRoundRect(6, 4, 3, 14, 1, 1);
        accentShape.graphics.endFill();
        headerBar.addChild(accentShape);

        // Title text
        titleTxt = new TextField();
        var titleFmt = new TextFormat(ApiStyle.FONT_FAMILY, ApiStyle.FONT_SIZE_BODY, ApiStyle.COLOR_TEXT_PRIMARY, true);
        titleTxt.defaultTextFormat = titleFmt;
        titleTxt.text = widgetTitle;
        titleTxt.x = 13;
        titleTxt.y = 3;
        titleTxt.width = 120;
        titleTxt.height = 18;
        titleTxt.selectable = false;
        titleTxt.mouseEnabled = false;
        headerBar.addChild(titleTxt);

        // Collapse button (Chevron)
        btnCollapse = new Sprite();
        btnCollapse.mouseEnabled = false;
        btnCollapse.mouseChildren = false;
        headerBar.addChild(btnCollapse);

        // Config button (Gear)
        if (hasConfigButton) {
            btnConfig = new Sprite();
            btnConfig.buttonMode = true;
            btnConfig.useHandCursor = true;
            renderConfigIcon(false);

            btnConfig.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void renderConfigIcon(true));
            btnConfig.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void renderConfigIcon(false));
            btnConfig.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void e.stopPropagation());
            btnConfig.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void e.stopPropagation());
            btnConfig.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
                e.stopPropagation();
                openConfig();
            });
            headerBar.addChild(btnConfig);
        }

        // Title bar hover feedback
        headerBar.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            titleTxt.textColor = ApiStyle.COLOR_TEXT_TITLE;
            renderCollapseIcon(isCollapsed, true);
            bg.alpha = 1.0;
        });
        headerBar.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            titleTxt.textColor = ApiStyle.COLOR_TEXT_PRIMARY;
            renderCollapseIcon(isCollapsed, false);
            bg.alpha = isCollapsed ? 0.82 : 0.94;
        });

        // 3. Body Container
        bodyContainer = new Sprite();
        addChild(bodyContainer);
    }

    public function attach(stageObj:Dynamic, overlayObj:Dynamic = null):Void {
        this.theStage = cast stageObj;
        this.overlay = overlayObj;

        loadPosition();
        setupDragging();
        buildContent(bodyContainer);
        updateLayout();

        if (theStage != null && this.parent == null) {
            theStage.addChild(this);
        }
    }

    public function detach():Void {
        cleanupDragging();
        if (this.parent != null) {
            this.parent.removeChild(this);
        }
        theStage = null;
        overlay = null;
    }

    public function destroy():Void {
        detach();
    }

    private function setupDragging():Void {
        if (theStage == null || headerBar == null) return;
        cleanupDragging();

        headerBar.addEventListener(MouseEvent.MOUSE_DOWN, onHeaderMouseDown);

        _onStageMouseMove = function(e:MouseEvent):Void {
            if (_isDragging) {
                var dx = e.stageX - _startDownX;
                var dy = e.stageY - _startDownY;
                if (Math.abs(dx) > 4 || Math.abs(dy) > 4) {
                    _hasDragged = true;
                }
                if (_hasDragged) {
                    var nx:Float = Math.round(e.stageX - _dragStartX);
                    var ny:Float = Math.round(e.stageY - _dragStartY);
                    var sw:Float = (theStage.stageWidth > 0) ? theStage.stageWidth : 960.0;
                    var sh:Float = (theStage.stageHeight > 0) ? theStage.stageHeight : 550.0;
                    var curW:Float = getCurrentWidth();
                    var curH:Float = getCurrentHeight();

                    if (nx < ApiStyle.SCREEN_MARGIN) nx = ApiStyle.SCREEN_MARGIN;
                    if (ny < ApiStyle.SCREEN_MARGIN) ny = ApiStyle.SCREEN_MARGIN;
                    if (nx > sw - curW - ApiStyle.SCREEN_MARGIN) nx = sw - curW - ApiStyle.SCREEN_MARGIN;
                    if (ny > sh - curH - ApiStyle.SCREEN_MARGIN) ny = sh - curH - ApiStyle.SCREEN_MARGIN;

                    this.x = nx;
                    this.y = ny;
                }
            }
        };

        _onStageMouseUp = function(e:MouseEvent):Void {
            if (_isDragging) {
                _isDragging = false;
                this.cacheAsBitmap = true;
                if (_hasDragged) {
                    clampToScreen();
                    savePosition();
                } else if (allowHeaderClickToCollapse) {
                    toggleCollapse();
                }
            }
        };

        theStage.addEventListener(MouseEvent.MOUSE_MOVE, _onStageMouseMove);
        theStage.addEventListener(MouseEvent.MOUSE_UP, _onStageMouseUp);
    }

    private function onHeaderMouseDown(e:MouseEvent):Void {
        _isDragging = true;
        _hasDragged = false;
        _startDownX = e.stageX;
        _startDownY = e.stageY;
        _dragStartX = e.stageX - this.x;
        _dragStartY = e.stageY - this.y;
        this.cacheAsBitmap = true;
        if (theStage != null && this.parent == theStage) {
            theStage.setChildIndex(this, theStage.numChildren - 1);
        }
    }

    private function cleanupDragging():Void {
        if (headerBar != null) {
            headerBar.removeEventListener(MouseEvent.MOUSE_DOWN, onHeaderMouseDown);
        }
        if (theStage != null) {
            if (_onStageMouseMove != null) theStage.removeEventListener(MouseEvent.MOUSE_MOVE, _onStageMouseMove);
            if (_onStageMouseUp != null) theStage.removeEventListener(MouseEvent.MOUSE_UP, _onStageMouseUp);
        }
        _onStageMouseMove = null;
        _onStageMouseUp = null;
        _isDragging = false;
    }

    public function clampToScreen():Void {
        if (theStage == null) return;
        var sw:Float = (theStage.stageWidth > 0) ? theStage.stageWidth : 960.0;
        var sh:Float = (theStage.stageHeight > 0) ? theStage.stageHeight : 550.0;
        var curW:Float = getCurrentWidth();
        var curH:Float = getCurrentHeight();

        if (this.x > sw - curW - ApiStyle.SCREEN_MARGIN) {
            this.x = Math.max(ApiStyle.SCREEN_MARGIN, sw - curW - ApiStyle.SCREEN_MARGIN);
        }
        if (this.y > sh - curH - ApiStyle.SCREEN_MARGIN) {
            this.y = Math.max(ApiStyle.SCREEN_MARGIN, sh - curH - ApiStyle.SCREEN_MARGIN);
        }
        if (this.x < ApiStyle.SCREEN_MARGIN) this.x = ApiStyle.SCREEN_MARGIN;
        if (this.y < ApiStyle.SCREEN_MARGIN) this.y = ApiStyle.SCREEN_MARGIN;

        savePosition();
    }

    public function loadPosition():Void {
        var savedX = ApiConfig.getInt("api_widget_" + widgetId + "_x", -1);
        var savedY = ApiConfig.getInt("api_widget_" + widgetId + "_y", -1);
        this.x = (savedX >= 0) ? savedX : defaultX;
        this.y = (savedY >= 0) ? savedY : defaultY;
        clampToScreen();
    }

    public function savePosition():Void {
        ApiConfig.setInt("api_widget_" + widgetId + "_x", Math.round(this.x));
        ApiConfig.setInt("api_widget_" + widgetId + "_y", Math.round(this.y));
    }

    public function resetToDefaultPosition():Void {
        this.x = defaultX;
        this.y = defaultY;
        savePosition();
        clampToScreen();
    }

    public function setEnabled(enabled:Bool):Void {
        this.isEnabled = enabled;
        ApiConfig.setBool("api_widget_" + widgetId + "_enabled", enabled);
        this.visible = enabled;
    }

    public function toggleCollapse():Void {
        this.isCollapsed = !this.isCollapsed;
        ApiConfig.setBool("api_widget_" + widgetId + "_collapsed", this.isCollapsed);
        updateLayout();
        clampToScreen();
    }

    public function renderConfigIcon(hover:Bool = false):Void {
        if (btnConfig == null) return;
        var g = btnConfig.graphics;
        g.clear();

        // Extended transparent hit boundary for mobile touch
        g.beginFill(0x000000, 0.0);
        g.drawRect(-4, -2, 28, 24);
        g.endFill();

        var bgCol = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE;
        var border = hover ? ApiStyle.COLOR_ACCENT_PRIMARY : ApiStyle.COLOR_BORDER_DEFAULT;
        g.beginFill(bgCol, 0.85);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 20, 18, 4, 4);
        g.endFill();

        var color = hover ? ApiStyle.COLOR_ACCENT_HOVER : ApiStyle.COLOR_ACCENT_PRIMARY;
        var cx = 10.0;
        var cy = 9.0;

        // 6-tooth gear spokes
        g.lineStyle(2.2, color, 1.0, true);
        g.moveTo(cx - 5.0, cy); g.lineTo(cx + 5.0, cy);
        g.moveTo(cx, cy - 5.0); g.lineTo(cx, cy + 5.0);
        var d = 3.6;
        g.moveTo(cx - d, cy - d); g.lineTo(cx + d, cy + d);
        g.moveTo(cx - d, cy + d); g.lineTo(cx + d, cy - d);

        // Gear body circle
        g.lineStyle(1.4, color, 1.0, true);
        g.beginFill(bgCol, 1.0);
        g.drawCircle(cx, cy, 3.4);
        g.endFill();

        // Center cutout
        g.lineStyle(0, 0, 0);
        g.beginFill(color, 1.0);
        g.drawCircle(cx, cy, 1.3);
        g.endFill();
    }

    public function renderCollapseIcon(collapsed:Bool, hover:Bool = false):Void {
        if (btnCollapse == null || !hasCollapseButton) return;
        var g = btnCollapse.graphics;
        g.clear();

        g.beginFill(0x000000, 0.0);
        g.drawRect(-4, -2, 28, 24);
        g.endFill();

        var bgCol = hover ? ApiStyle.COLOR_BTN_BG_HOVER : ApiStyle.COLOR_BG_SURFACE;
        var border = hover ? ApiStyle.COLOR_BORDER_HIGHLIGHT : ApiStyle.COLOR_BORDER_DEFAULT;
        g.beginFill(bgCol, 0.85);
        g.lineStyle(1, border);
        g.drawRoundRect(0, 0, 20, 18, 4, 4);
        g.endFill();

        var color:Int = hover ? ApiStyle.COLOR_ACCENT_PRIMARY : ApiStyle.COLOR_TEXT_MUTED;
        g.lineStyle(2.2, color, 1.0, true);
        var cx = 10.0;
        var cy = 9.0;
        if (collapsed) {
            // Modern Chevron Down
            g.moveTo(cx - 4.5, cy - 2.5);
            g.lineTo(cx, cy + 2.5);
            g.lineTo(cx + 4.5, cy - 2.5);
        } else {
            // Modern Chevron Up
            g.moveTo(cx - 4.5, cy + 2.5);
            g.lineTo(cx, cy - 2.5);
            g.lineTo(cx + 4.5, cy + 2.5);
        }
    }

    public function drawDefaultBackground(w:Float, h:Float, alpha:Float = 0.94, radius:Float = 6.0):Void {
        if (bg == null) return;
        var g = bg.graphics;
        g.clear();
        g.beginFill(ApiStyle.COLOR_BG_MAIN, alpha);
        g.lineStyle(1, ApiStyle.COLOR_BORDER_DEFAULT, 0.9);
        g.drawRoundRect(0, 0, w, h, radius, radius);
        g.endFill();

        // Top bevel highlight
        g.lineStyle(1, ApiStyle.COLOR_BEVEL_LIGHT, 0.45);
        g.moveTo(3, 1);
        g.lineTo(w - 3, 1);
    }

    public function getCurrentWidth():Float {
        return isCollapsed ? computeCollapsedWidth() : defaultWidth;
    }

    public function getCurrentHeight():Float {
        return isCollapsed ? computeCollapsedHeight() : defaultHeight;
    }

    public function computeCollapsedWidth():Float {
        return COMPACT_W;
    }

    public function computeCollapsedHeight():Float {
        return COMPACT_H;
    }

    public function buildContent(container:Sprite):Void {
        // Subclasses populate body controls here
    }

    public function updateLayout():Void {
        var curW = getCurrentWidth();
        var curH = getCurrentHeight();
        drawDefaultBackground(curW, curH, isCollapsed ? 0.85 : 0.94);

        headerBar.graphics.clear();
        headerBar.graphics.beginFill(0x000000, 0.0);
        headerBar.graphics.drawRect(0, 0, curW, isCollapsed ? curH : 24);
        headerBar.graphics.endFill();

        if (btnCollapse != null) {
            btnCollapse.x = curW - 25;
            btnCollapse.y = 3;
            renderCollapseIcon(isCollapsed, false);
        }

        if (btnConfig != null) {
            btnConfig.x = curW - (hasCollapseButton ? 48 : 25);
            btnConfig.y = 3;
            renderConfigIcon(false);
        }

        if (bodyContainer != null) {
            bodyContainer.visible = !isCollapsed;
        }
    }

    public function onTick():Void {
        // Subclasses implement per-frame status updates here
    }

    public function openConfig():Void {
        // Subclasses implement config dialog here
    }
}
#else
class BaseWidget {
    public function new(id:String, title:String, defX:Float, defY:Float, defW:Float, defH:Float, defaultEnabled:Bool = true, defaultCollapsed:Bool = false, hasConfig:Bool = true) {}
}
#end
