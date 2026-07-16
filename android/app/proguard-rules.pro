-keep class com.dexterous.** { *; }
-keep class * implements io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback {
    <init>();
}
