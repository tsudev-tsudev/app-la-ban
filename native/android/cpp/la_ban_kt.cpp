// Kiểm tra môi trường không tin cậy ở tầng native (Spec §7.3a-b, SEC-APP APP-02). Kết quả là MỘT bitmask gửi lên Dart
// rồi lên server - không chặn gì ở đây (server quyết định, Q8).
//
// - Chuỗi nhạy cảm (đường dẫn su, tên thư viện hook...) mã hoá XOR lúc biên dịch: không nằm nguyên văn trong .rodata.
// - Không xuất hàm Java_*: chỉ JNI_OnLoad + RegisterNatives; mọi symbol khác ẩn (-fvisibility=hidden).
// - Bit phải khớp KetQuaNative (packages/security_sdk/lib/src/domain/rasp.dart).
#include <arpa/inet.h>
#include <dirent.h>
#include <fcntl.h>
#include <jni.h>
#include <netinet/in.h>
#include <poll.h>
#include <sys/socket.h>
#include <sys/system_properties.h>
#include <stddef.h>
#include <stdint.h>
#include <unistd.h>

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

namespace {

enum : int {
  kTracer = 1,
  kFridaMaps = 1 << 1,
  kHookMaps = 1 << 2,
  kSu = 1 << 3,
  kMagisk = 1 << 4,
  kFridaCong = 1 << 5,
  kFridaLuong = 1 << 6,
  kRoDebuggable = 1 << 7,
  kQemu = 1 << 8,
  kXposedLop = 1 << 9,
};

// Chuỗi mã hoá lúc biên dịch: mỗi byte XOR với khoá đổi theo vị trí.
template <size_t N>
struct ChuoiAn {
  unsigned char d[N];
  unsigned char k;
  constexpr ChuoiAn(const char (&s)[N], unsigned char khoa) : d{}, k(khoa) {
    for (size_t i = 0; i < N; ++i) d[i] = static_cast<unsigned char>(s[i]) ^ static_cast<unsigned char>(khoa + i * 29);
  }
  void giai(char* ra) const {
    volatile unsigned char khoa = k;  // chặn trình biên dịch gập lại thành hằng chuỗi gốc
    for (size_t i = 0; i < N; ++i) ra[i] = static_cast<char>(d[i] ^ static_cast<unsigned char>(khoa + i * 29));
  }
};

#define AN(ten, s)                                                                            \
  static constexpr ChuoiAn<sizeof(s)> ten##_m(s, static_cast<unsigned char>(__LINE__ * 131 + 17)); \
  char ten[sizeof(s)];                                                                          \
  ten##_m.giai(ten)

bool coTep(const char* p) { return access(p, F_OK) == 0; }

// Đọc tệp văn bản nhỏ theo dòng, dừng khi [xet] trả true.
template <typename F>
bool quetDong(const char* duong, F xet) {
  FILE* f = fopen(duong, "re");
  if (!f) return false;
  char dong[512];
  bool thay = false;
  while (!thay && fgets(dong, sizeof(dong), f)) thay = xet(dong);
  fclose(f);
  return thay;
}

int kiemTracer() {
  AN(st, "/proc/self/status");
  AN(tp, "TracerPid:");
  int pid = 0;
  quetDong(st, [&](const char* d) {
    if (strncmp(d, tp, strlen(tp)) != 0) return false;
    pid = atoi(d + strlen(tp));
    return true;
  });
  return pid != 0 ? kTracer : 0;
}

int kiemMaps() {
  AN(maps, "/proc/self/maps");
  AN(f1, "frida");
  AN(f2, "gadget");
  AN(f3, "gum-js");
  AN(h1, "xposed");
  AN(h2, "lspd");
  AN(h3, "substrate");
  AN(h4, "libhooker");
  AN(h5, "edxp");
  AN(h6, "sandhook");
  const char* frida[] = {f1, f2, f3};
  const char* hook[] = {h1, h2, h3, h4, h5, h6};
  int kq = 0;
  quetDong(maps, [&](const char* d) {
    for (const char* s : frida)
      if (strcasestr(d, s)) kq |= kFridaMaps;
    for (const char* s : hook)
      if (strcasestr(d, s)) kq |= kHookMaps;
    return kq == (kFridaMaps | kHookMaps);
  });
  return kq;
}

int kiemSu() {
  AN(p1, "/system/bin/su");
  AN(p2, "/system/xbin/su");
  AN(p3, "/sbin/su");
  AN(p4, "/su/bin/su");
  AN(p5, "/data/local/xbin/su");
  AN(p6, "/data/local/bin/su");
  AN(p7, "/system/sd/xbin/su");
  AN(p8, "/vendor/bin/su");
  const char* ds[] = {p1, p2, p3, p4, p5, p6, p7, p8};
  for (const char* p : ds)
    if (coTep(p)) return kSu;
  return 0;
}

int kiemMagisk() {
  AN(m1, "/sbin/.magisk");
  AN(m2, "/system/app/Superuser.apk");
  AN(m3, "/system/xbin/daemonsu");
  AN(m4, "/cache/magisk.log");
  AN(m5, "/dev/.magisk.unblock");
  const char* ds[] = {m1, m2, m3, m4, m5};
  for (const char* p : ds)
    if (coTep(p)) return kMagisk;
  return 0;
}

// frida-server mặc định nghe 27042 (27047 cho bản cũ): kết nối thử 127.0.0.1, chờ tối đa 60 ms.
bool congMo(uint16_t cong) {
  int s = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
  if (s < 0) return false;
  sockaddr_in a{};
  a.sin_family = AF_INET;
  a.sin_port = htons(cong);
  a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  bool mo = false;
  if (connect(s, reinterpret_cast<sockaddr*>(&a), sizeof(a)) == 0) {
    mo = true;
  } else if (errno == EINPROGRESS) {
    pollfd p{s, POLLOUT, 0};
    if (poll(&p, 1, 60) == 1) {
      int loi = 0;
      socklen_t n = sizeof(loi);
      mo = getsockopt(s, SOL_SOCKET, SO_ERROR, &loi, &n) == 0 && loi == 0;
    }
  }
  close(s);
  return mo;
}

int kiemCongFrida() { return congMo(27042) || congMo(27047) ? kFridaCong : 0; }

int kiemLuong() {
  AN(task, "/proc/self/task");
  AN(l1, "gum-js-loop");
  AN(l2, "pool-frida");
  AN(l3, "gmain");
  AN(l4, "gdbus");
  DIR* d = opendir(task);
  if (!d) return 0;
  bool gmain = false, gdbus = false, frida = false;
  char duong[96];
  while (dirent* e = readdir(d)) {
    if (e->d_name[0] == '.') continue;
    snprintf(duong, sizeof(duong), "%s/%s/comm", task, e->d_name);
    quetDong(duong, [&](const char* ten) {
      if (strstr(ten, l1) || strstr(ten, l2)) frida = true;
      if (strstr(ten, l3)) gmain = true;
      if (strstr(ten, l4)) gdbus = true;
      return true;
    });
    if (frida) break;
  }
  closedir(d);
  // gmain + gdbus cùng lúc là dấu vết GLib của frida-agent (app Flutter không dùng GLib).
  return frida || (gmain && gdbus) ? kFridaLuong : 0;
}

bool thuocTinh(const char* ten, char* gt) {
  gt[0] = '\0';
  return __system_property_get(ten, gt) > 0;
}

int kiemThuocTinh() {
  char gt[PROP_VALUE_MAX];
  int kq = 0;
  AN(dbg, "ro.debuggable");
  if (thuocTinh(dbg, gt) && strcmp(gt, "1") == 0) kq |= kRoDebuggable;
  AN(q1, "ro.kernel.qemu");
  AN(q2, "ro.boot.qemu");
  if ((thuocTinh(q1, gt) && strcmp(gt, "1") == 0) || (thuocTinh(q2, gt) && strcmp(gt, "1") == 0)) kq |= kQemu;
  AN(hw, "ro.hardware");
  AN(e1, "goldfish");
  AN(e2, "ranchu");
  AN(e3, "vbox86");
  AN(e4, "nox");
  AN(e5, "ttvm");
  if (thuocTinh(hw, gt)) {
    const char* ds[] = {e1, e2, e3, e4, e5};
    for (const char* s : ds)
      if (strcasestr(gt, s)) kq |= kQemu;
  }
  AN(sp, "ro.product.model");
  AN(s1, "sdk_gphone");
  AN(s2, "Android SDK built for");
  if (thuocTinh(sp, gt) && (strstr(gt, s1) || strstr(gt, s2))) kq |= kQemu;
  return kq;
}

int kiemLopXposed(JNIEnv* env) {
  AN(l1, "de/robv/android/xposed/XposedBridge");
  AN(l2, "com/saurik/substrate/MS$2");
  const char* ds[] = {l1, l2};
  int kq = 0;
  for (const char* l : ds) {
    jclass c = env->FindClass(l);
    if (env->ExceptionCheck()) env->ExceptionClear();
    if (c) {
      kq = kXposedLop;
      env->DeleteLocalRef(c);
    }
  }
  return kq;
}

jint kiemTra(JNIEnv* env, jclass) {
  return kiemTracer() | kiemMaps() | kiemSu() | kiemMagisk() | kiemCongFrida() | kiemLuong() | kiemThuocTinh() |
         kiemLopXposed(env);
}

}  // namespace

extern "C" __attribute__((visibility("default"))) jint JNI_OnLoad(JavaVM* vm, void*) {
  JNIEnv* env = nullptr;
  if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) return JNI_ERR;
  AN(lop, "com/tsudev/laban/security/MoiTruong");
  jclass c = env->FindClass(lop);
  if (!c) return JNI_ERR;
  AN(ten, "k");
  AN(ky, "()I");
  const JNINativeMethod pp[] = {{ten, ky, reinterpret_cast<void*>(kiemTra)}};
  if (env->RegisterNatives(c, pp, 1) != JNI_OK) return JNI_ERR;
  return JNI_VERSION_1_6;
}
