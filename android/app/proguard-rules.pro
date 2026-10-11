# Flutter Wrapper & Engine ProGuard / R8 Keep Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Google Mobile Ads & User Messaging Platform (UMP)
-keep class com.google.android.gms.ads.** { *; }
-keep interface com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-keep interface com.google.android.ump.** { *; }
-dontwarn com.google.android.gms.ads.**
-dontwarn com.google.android.ump.**
