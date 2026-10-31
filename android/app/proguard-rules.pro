# flutter_stripe — push provisioning (thêm thẻ vào Google Pay) không dùng & không bundle.
# Chặn R8 báo thiếu class khi minify release (AAB). Dùng wildcard cho cả package.
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.reactnativestripesdk.**
-keep class com.stripe.android.pushProvisioning.** { *; }
-keep class com.reactnativestripesdk.** { *; }
