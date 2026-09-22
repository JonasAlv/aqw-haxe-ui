package util;

extern class HelperSetting {
    public static inline var OPTION_SWF_CACHE:String = "option_swf_cache";

    public static function getBool(key:String, defaultValue:Bool = false):Bool;
    public static function setBool(key:String, value:Bool):Void;
    public static function getInt(key:String, defaultValue:Int = 0):Int;
    public static function setInt(key:String, value:Int):Void;
    public static function getString(key:String, defaultValue:String = ""):String;
    public static function setString(key:String, value:String):Void;
}
