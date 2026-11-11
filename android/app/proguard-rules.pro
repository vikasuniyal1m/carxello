# Flutter通用规则
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# 你的应用包名（改成你的）
-keep class com.carauction.androidios.** { *; }

# 保持所有Model类
-keep class **.model.** { *; }
-keep class **.models.** { *; }

# R8常见警告忽略
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
-dontwarn com.google.common.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.lang.**
-dontwarn org.slf4j.**
-dontwarn com.bumptech.glide.**
-dontwarn com.google.android.**
-dontwarn androidx.**

# 保持Parcelable
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# 保持Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# 保持枚举类
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# 保持所有原生方法
-keepclasseswithmembernames class * {
    native <methods>;
}