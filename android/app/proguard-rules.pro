# Keep attributes R8 needs to not break reflection-based libraries below.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Flutter engine / plugin embedding.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase / Google Play Services (Auth, Firestore, Storage, Functions,
# Messaging, Google Sign-In all live under these packages).
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Play Core — referenced by Flutter's deferred-components support even
# though this app doesn't use split APKs; missing classes here are a
# well-known R8 build-time warning otherwise.
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Stripe (flutter_stripe) — payment SDK with reflection-heavy internals.
-keep class com.stripe.android.** { *; }
-dontwarn com.stripe.android.**

# Facebook Login (flutter_facebook_auth).
-keep class com.facebook.** { *; }
-dontwarn com.facebook.**

# ExoPlayer — backs video_player and just_audio.
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
