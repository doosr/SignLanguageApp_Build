# ProGuard rules for Google ML Kit
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-dontwarn com.google.mlkit.vision.text.devanagari.**
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-dontwarn com.google.mlkit.vision.text.japanese.**
-keep class com.google.mlkit.vision.text.korean.** { *; }
-dontwarn com.google.mlkit.vision.text.korean.**

# ProGuard rules for TensorFlow Lite GPU
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**

# General ML Kit rules
-keep class com.google.android.gms.internal.mlkit_vision_text.** { *; }
-keep class com.google.mlkit.vision.common.internal.Labels { *; }
-dontwarn com.google.mlkit.vision.**
