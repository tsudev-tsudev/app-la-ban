# JNI_OnLoad của la_ban_kt tìm lớp + hàm native theo tên (RegisterNatives) -> giữ tên qua R8.
-keep class com.tsudev.laban.security.MoiTruong {
    native <methods>;
}
