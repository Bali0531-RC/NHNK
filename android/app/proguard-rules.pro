# Referenced from build.gradle. Without this file R8 ran with no app-specific keeps.
#
# The Flutter embedding ships its own consumer ProGuard rules, so it is deliberately
# not kept wholesale here: a blanket keep retains FlutterPlayStoreSplitApplication,
# which references Play Core classes this app does not bundle, and R8 then fails.

# flutter_local_notifications deserialises its scheduled-notification models with
# Gson, so their fields must survive shrinking or restored alarms break.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Play Core is only needed for deferred components, which this app does not use.
-dontwarn com.google.android.play.core.**
