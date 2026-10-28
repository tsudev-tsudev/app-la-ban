# Đo trên điện thoại thật qua adb Wi-Fi (A2 / A3)

Mục đích: nối điện thoại Android với máy dev (WSL2) qua Wi-Fi để agent đo **khung hình/giây (FPS)**, **độ trễ khi xoay**
và **sai số hướng** của la bàn (phase A2 cảm biến + A3 mặt la bàn) - việc còn treo ở bảng Tiến độ. QUYET_DINH Q27.

Thời gian: ~10 phút lần đầu. Cần: điện thoại Android 11 trở lên, cùng mạng Wi-Fi với máy tính (không dùng Wi-Fi khách /
mạng có "cách ly máy khách" - router chặn các máy nhìn thấy nhau).

---

## Phần 1 - Người dùng làm trên điện thoại

### 1.1 Bật Tuỳ chọn nhà phát triển (một lần)

1. **Cài đặt -> Giới thiệu điện thoại** (Samsung: *Thông tin điện thoại -> Thông tin phần mềm*; Xiaomi: *Giới thiệu
   điện thoại*; Oppo / Realme: *Giới thiệu thiết bị -> Phiên bản*).
2. Chạm **7 lần** vào **Số hiệu bản tạo** (Build number; Xiaomi: *Phiên bản MIUI / HyperOS*; Oppo: *Phiên bản*).
   Nhập mã khoá màn hình nếu được hỏi -> báo "Bạn đã là nhà phát triển".
3. Mục mới **Tuỳ chọn nhà phát triển** nằm ở *Cài đặt -> Hệ thống* (Samsung: cuối danh sách Cài đặt; Xiaomi: *Cài đặt
   bổ sung*).

### 1.2 Bật Gỡ lỗi không dây (Wireless debugging)

1. Kết nối điện thoại vào **cùng Wi-Fi** với máy tính.
2. **Tuỳ chọn nhà phát triển** -> bật **Gỡ lỗi USB** (một số máy yêu cầu bật trước).
3. Bật **Gỡ lỗi không dây** (Wireless debugging) -> chọn **Cho phép** khi hỏi "Cho phép gỡ lỗi không dây trên mạng này?".
4. Chạm vào **chữ** "Gỡ lỗi không dây" (không phải công tắc) để mở trang chi tiết. Ghi lại dòng
   **Địa chỉ IP và cổng** - ví dụ `192.168.1.23:41237` -> đây là **cổng KẾT NỐI**.
5. Chạm **Ghép nối thiết bị bằng mã ghép nối** (Pair device with pairing code). Hộp thoại hiện:
   - **Mã ghép nối Wi-Fi** 6 chữ số, ví dụ `482915`
   - **Địa chỉ IP và cổng** ví dụ `192.168.1.23:37099` -> đây là **cổng GHÉP NỐI** (khác cổng kết nối).

   **Giữ nguyên hộp thoại này** khi gõ lệnh ở phần 2 (đóng là mã hết hiệu lực).

Xiaomi / HyperOS: bật thêm **Gỡ lỗi USB (Cài đặt bảo mật)** và **Cài đặt qua USB** (cần đăng nhập Mi account, có SIM)
- thiếu thì `flutter run` cài được nhưng không chạy được. Oppo / Realme / Vivo: tắt **Giám sát quyền** / **Tối ưu
hoá hệ thống** nếu cài APK bị chặn.

## Phần 2 - Ghép nối từ máy tính

Gõ trong ô nhắc của Claude Code với tiền tố `!` (chạy trong phiên, agent thấy kết quả), hoặc trong terminal WSL:

```bash
# Thay IP:CỔNG_GHÉP_NỐI và MÃ bằng số trên hộp thoại ở bước 1.2.5
! ~/tools/android-sdk/platform-tools/adb pair 192.168.1.23:37099 482915
# -> "Successfully paired to 192.168.1.23:37099 [guid=adb-...]"

# Kết nối bằng CỔNG KẾT NỐI (bước 1.2.4), không phải cổng ghép nối
! ~/tools/android-sdk/platform-tools/adb connect 192.168.1.23:41237
# -> "connected to 192.168.1.23:41237"

! ~/tools/android-sdk/platform-tools/adb devices -l
# -> "192.168.1.23:41237  device product:... model:..."
```

Ghép nối chỉ làm **một lần** cho mỗi máy tính. Các lần sau chỉ cần bật lại Gỡ lỗi không dây và chạy `adb connect`
với **cổng kết nối mới** (cổng đổi mỗi lần bật lại công tắc / khởi động lại điện thoại).

### Gặp lỗi

| Hiện tượng | Cách xử lý |
|---|---|
| `failed to connect` / treo khi `pair` | Hai máy khác mạng hoặc router cách ly máy khách: thử điểm phát Wi-Fi từ chính điện thoại khác, hoặc mạng nhà. Kiểm `ping 192.168.1.23` từ WSL. |
| WSL2 không tới được IP điện thoại | WSL2 chế độ NAT đi ra mạng LAN bình thường; nếu vẫn chặn: bật mirrored networking (`%UserProfile%\.wslconfig` -> `[wsl2]` `networkingMode=mirrored`, rồi `wsl --shutdown`), hoặc dùng `adb.exe` của Windows rồi báo agent. Tường lửa Windows có thể chặn - cho phép khi được hỏi. |
| `adb devices` hiện `unauthorized` / `offline` | Mở khoá màn hình điện thoại, `adb disconnect` rồi `adb connect` lại; vẫn lỗi thì tắt / bật công tắc Gỡ lỗi không dây và ghép nối lại. |
| `protocol fault` / mã sai | Mã hết hạn - mở lại hộp thoại ghép nối, dùng mã + cổng MỚI. |
| Kết nối rớt sau vài phút | Tắt chế độ tiết kiệm pin / Wi-Fi ngủ khi khoá màn hình trong lúc đo; để màn hình luôn bật (Tuỳ chọn nhà phát triển -> **Không khoá màn hình** khi sạc). |

### Cáp USB (khi Wi-Fi rớt liên tục)

Samsung tự tắt Gỡ lỗi không dây sau vài phút / khi Wi-Fi nối lại. WSL2 không thấy USB (cần usbipd-win - KHÔNG cài được từ
agent), nhưng `adb.exe` của Android SDK trên Windows thấy điện thoại:

```bash
W=/mnt/c/Users/<user>/AppData/Local/Android/Sdk/platform-tools/adb.exe
$W kill-server; $W devices -l          # "unauthorized" -> trên điện thoại chọn "Luôn cho phép" + Cho phép
cp app-dev-profile.apk /mnt/c/Users/<user>/AppData/Local/Temp/laban.apk
$W install -r 'C:\Users\<user>\AppData\Local\Temp\laban.apk'   # adb.exe cần đường dẫn Windows
```

Máy đang sạc qua cáp: KHÔNG đo pin được, và dòng sạc có thể lệch cảm biến từ (đừng đo sai số tuyệt đối khi cắm cáp).

Xong phần 2 thì báo agent: **"đã adb connect, model ..."**. Phần dưới agent chạy, người dùng chỉ cầm máy theo lời nhắc.

---

## Phần 3 - Agent đo (người dùng thao tác theo lời nhắc)

Biến môi trường như board (FLUTTER / GRADLE HOME / JAVA). Không chạy song song việc nặng khác (`./agents.sh runners`).

### 3.1 FPS + jank (cổng A3: 60 FPS, jank < 1%; 120 Hz: >= 110)

`dumpsys gfxinfo` KHÔNG đếm khung Flutter (vẽ trên SurfaceView) - dùng atrace (bẫy DO KHUNG FLUTTER):

```bash
cd app && flutter build apk --profile --flavor dev -t lib/main_dev.dart --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-dev-profile.apk
adb shell am start -n com.tsudev.laban.dev/com.tsudev.laban.MainActivity --ez trace-systrace true
adb shell atrace -b 65536 -t 120 gfx view > at.txt      # người dùng xoay máy liên tục ~30 s trong lúc này
adb shell dumpsys display | grep -m1 mActiveSfDisplayMode  # tần số màn hình thật
```

Đọc `at.txt`: thời gian `Animator::BeginFrame` (UI, chạy trên luồng platform) và `GPURasterizer::Draw` (raster) theo cặp
B/E mỗi luồng; FPS = số `GPURasterizer::Draw` / giây; **rớt khung** = khoảng giữa hai lần bắt đầu raster > 1,5 vsync (bỏ
khoảng > 100 ms = app nghỉ). Raster > vsync chưa chắc là rớt (gồm chờ `eglSwapBuffers`). Muốn so với cổng 60 Hz trên máy
90 / 120 Hz: Samsung `adb shell settings put secure refresh_rate_mode 0` (ghi giá trị cũ, trả lại sau khi đo).

Bản profile còn VM service (`adb logcat | grep "VM service"` -> `adb forward`): `getVMTimeline` cho cùng số liệu, chỉ dùng
được khi adb chạy trong WSL (Wi-Fi), không dùng được qua `adb.exe` Windows (cổng forward nằm ở localhost Windows).

Số đo tham chiếu (29/10, Galaxy M32 90 Hz): 60 Hz 58 FPS, rớt 0,35%, UI/raster p99 10,0/10,8 ms; 90 Hz 86 FPS, rớt 1,9%.

### 3.2 Sai số hướng (A2 + A3)

Chuẩn bị (người dùng): đặt máy nằm ngửa trên bàn gỗ / nhựa, xa máy tính, loa, sạc không dây, khung kim loại >= 50 cm.
Hiệu chuẩn hình số 8 trong app trước (nút hình số 8 trên thanh tiêu đề) tới khi "Độ tin cậy: Cao".

| Phép đo | Cách làm | Cổng / ghi lại |
|---|---|---|
| Rung khi đứng yên | Để yên 60 s, người dùng đọc số độ đầu / cuối và dao động lớn nhất (hoặc agent đọc qua `adb shell uiautomator dump` mỗi 2 s) | dao động <= ±0,5°, trôi <= 1° / phút |
| Sai số tuyệt đối | Đặt cạnh máy song song một hướng đã biết: mép tường / đường phố đo trên bản đồ vệ tinh (Google Maps, thước góc), hoặc bóng nắng giữa trưa (hướng Nam). So số độ với hướng chuẩn, theo **bắc từ** (A4 mới có bắc thực) - hướng chuẩn địa lý cộng độ lệch từ (~ -1,5° ở VN, app hiện ở bảng Tuỳ chọn khi có vị trí) | sai số <= ±3° sau hiệu chuẩn |
| Xoay qua 0° | Xoay chậm qua Bắc nhiều lần | không nhảy 359 -> 0 sai, không rung lặp |
| Độ trễ | Xoay nhanh 90° rồi dừng; quay video màn hình 60 fps (`adb shell screenrecord`) đếm khung tới khi số độ ổn định | ổn định < 300 ms, không vượt quá đích > 3° |
| Nhiễu từ | Đưa nam châm / loa lại gần rồi ra xa | hiện cảnh báo nhiễu từ, hướng giữ bằng con quay, hết nhiễu tự hồi phục |
| Dựng đứng / xoay ngang | Dựng đứng máy (camera sau), xoay màn hình ngang | nhãn "Theo hướng camera sau", ngang không lệch 90° (bẫy CAM BIEN HUONG MAN HINH) |
| Madgwick vs hệ thống | Agent tạm truyền `uuTienHeThong: true` cho `DichVuHuong` (`dichVuHuongProvider`, chỉ build profile thử, không commit), lặp "Sai số tuyệt đối" | nếu ROTATION_VECTOR tốt hơn rõ -> đổi mặc định (Phát sinh thẻ A3) |
| Pin | 30 phút để tab La bàn mở, màn hình sáng cố định: `adb shell dumpsys batterystats --reset` trước, `dumpsys batterystats com.tsudev.laban.dev` sau | < 3% / giờ phần app (Spec §15) |

### 3.3 Ghi kết quả

`./agents.sh log 'agent-laban | TEST | Đo máy thật <model>, Android <x>, <Hz>: FPS p50/p99 ..., jank ...%, đứng yên ±..°,
sai số ..°, trễ .. ms, pin ..%/giờ, nguồn ...'` -> sửa dòng A2 / A3 ở bảng Tiến độ (bỏ "⛔ chờ adb") -> commit.

Đo xong: `adb disconnect`, người dùng tắt **Gỡ lỗi không dây** (để công tắc bật trên Wi-Fi công cộng là rủi ro).
