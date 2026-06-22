# ==============================================================
#  Reglas ProGuard / R8  —  Práctica de ofuscación de código
#  Proyecto: appmobile_security (Flutter + Firebase + Supabase)
# ==============================================================
#
#  Estas reglas SOLO se aplican cuando se compila con
#  -Pobfuscate=true (ver android/app/build.gradle.kts), es decir,
#  en la versión OFUSCADA de la aplicación.
#
#  Su propósito es doble:
#    1) Permitir que R8 renombre/elimine el código de la app.
#    2) "Mantener" (keep) las clases que se acceden por reflexión o
#       desde código nativo (JNI), que NO deben renombrarse o la app
#       fallaría en tiempo de ejecución. Este es exactamente el caso
#       descrito en el tema "ofuscación y bibliotecas de terceros".
# --------------------------------------------------------------

# ---- Motor y plugins de Flutter --------------------------------
# El embedding de Flutter y los plugins se invocan por reflexión y JNI.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ---- Métodos nativos (JNI) -------------------------------------
# libapp.so y los plugins resuelven estos métodos por nombre: no renombrar.
-keepclasseswithmembernames class * {
    native <methods>;
}

# ---- Firebase Core / Messaging / Google Play Services ----------
# Usan reflexión y servicios registrados en el manifiesto.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ---- flutter_secure_storage / EncryptedSharedPreferences -------
# androidx.security.crypto se instancia por reflexión (Keystore AES).
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# ---- Atributos necesarios para depurar y para stacktraces ------
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses,EnclosingMethod
# Conserva números de línea pero oculta el nombre real del archivo fuente.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ---- Enumeraciones ---------------------------------------------
# R8 puede romper values()/valueOf() si elimina estos miembros.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ---- Parcelables -----------------------------------------------
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# ---- Serialización (Gson/JSON por reflexión, si aplica) --------
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations
