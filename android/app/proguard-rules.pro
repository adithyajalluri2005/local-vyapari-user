# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase / Google Play services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# flutter_local_notifications uses Gson + reflection on its scheduled-notification models
-keep class com.dexterous.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-dontwarn com.google.gson.**

# Play Core (used by Flutter deferred components / split installs)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep annotations and generic signatures for reflection-based libraries
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
