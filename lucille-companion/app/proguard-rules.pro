# Lucille Companion ProGuard rules  v1.0.0  2026-09-24
# Keep data classes used for Gson deserialization
-keep class com.swarm.lucille.data.network.** { *; }
-keepclassmembers class com.swarm.lucille.data.network.** { *; }

# Gson
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.google.gson.**

# OkHttp
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Kotlin coroutines
-keepclassmembers class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Compose (generated classes)
-keep class androidx.compose.** { *; }
-dontwarn androidx.compose.**

# DataStore
-keep class androidx.datastore.** { *; }

# General Android keep rules
-keepclassmembers class * extends android.app.Activity { *; }
-keepclassmembers enum * { *; }
