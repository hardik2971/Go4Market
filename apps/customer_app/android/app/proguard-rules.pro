# ---- Razorpay ----
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/
-keepclasseswithmembers class * {
  public void onPayment*(...);
}
-keep class proguard.annotation.Keep
-keep class proguard.annotation.KeepClassMembers
-dontwarn proguard.annotation.Keep
-dontwarn proguard.annotation.KeepClassMembers

# ---- Firebase / Play services ----
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ---- flutter_local_notifications (Gson generic types) ----
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# ---- Flutter deferred components (Play Core) referenced by the engine ----
-dontwarn com.google.android.play.core.**

# ---- Google sign-in (google_sign_in 7 uses Credential Manager) ----
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-dontwarn com.google.android.libraries.identity.googleid.**
