# Proguard rules for SmartPark AI

# Disable aggressive R8 optimization to prevent NullPointerExceptions in reflection-based ML Kit
-dontoptimize

# --- Google ML Kit & Play Services Rules ---
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-keep enum com.google.mlkit.** { *; }

-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.android.odml.** { *; }

-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.odml.**

# Text recognition specific rules
-keep class com.google.mlkit.vision.text.** { *; }
-keep interface com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }

-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep attributes required for reflection and serialization
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes SourceFile,LineNumberTable

# Flutter Plugin Internals
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core / Deferred Components
-dontwarn com.google.android.play.core.**
