# Thư viện kiểm tra môi trường của security_sdk (QUYET_DINH Q32: NDK C++ dùng chung đặt ở native/). Gradle của plugin
# (packages/security_sdk/android/build.gradle.kts) trỏ tới tệp này.
cmake_minimum_required(VERSION 3.22.1)
project(la_ban_kt LANGUAGES CXX)

add_library(la_ban_kt SHARED la_ban_kt.cpp)
set_target_properties(la_ban_kt PROPERTIES CXX_STANDARD 20 CXX_STANDARD_REQUIRED ON)

# Spec §7.3a: ẩn symbol, LTO, bỏ RTTI / exception (không cần, lộ thêm tên kiểu), strip khi liên kết.
target_compile_options(la_ban_kt PRIVATE -fvisibility=hidden -fvisibility-inlines-hidden -fno-rtti -fno-exceptions
  -O2 -flto -fstack-protector-strong -Wall -Wextra -Werror)
target_link_options(la_ban_kt PRIVATE -flto -Wl,--gc-sections -Wl,--exclude-libs,ALL -Wl,-z,max-page-size=16384 -s)
target_link_libraries(la_ban_kt PRIVATE log)
