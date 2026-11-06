# Hướng dẫn điền Google Play Console - La bàn (`com.tsudev.laban`)

Cập nhật 04/11/2026 (bản 2: khoá ký Play, trang Được bảo vệ bằng Play, E0-E2 từng bước) theo ảnh chụp Play Console tiếng Việt của tài khoản cá nhân **TsuDev** (mã 6673606179625007616,
app 4973918380597875482). Người dùng bấm trong Play Console; agent chuẩn bị AAB, nội dung và bật / tắt kill-switch.
Nguồn nội dung dán: `docs/store/play-listing.md` (listing), `docs/store/data-safety.md` (An toàn dữ liệu),
`docs/store/ghi-chu-reviewer.md` (người duyệt), runbook `docs/runbook/phat-hanh-play.md` (PEPK, Pro, RTDN).

Trạng thái lúc chụp: "Hoàn tất bước thiết lập ứng dụng" **2/11** (xong: Chính sách quyền riêng tư, Thông tin đăng nhập).
Thứ tự làm đề xuất: Phần A (9 mục còn lại) -> Phần B (thử nội bộ, làm song song được) -> Phần C (thử kín 12 người x 14 ngày)
-> Phần D (đăng ký + phát hành công khai).

> **Ba bẫy chặn duyệt, đọc trước:**
> 1. **Chặn chế độ Nhà phát triển (Q57).** Bản prod hiện màn "Hãy tắt chế độ Nhà phát triển" khi máy bật Developer options
>    / gỡ lỗi USB (đã kiểm trên M32 04/11). Máy pre-launch report (Firebase Test Lab) LUÔN bật ADB, máy người duyệt thường
>    cũng bật -> họ chỉ thấy màn chặn -> báo "ứng dụng không hoạt động" (chính sách Chức năng tối thiểu / Ứng dụng bị hỏng).
>    TRƯỚC mỗi lần gửi duyệt (thử kín, công khai, bản cập nhật) làm E0 + E1; duyệt xong làm E2.
> 2. **Miễn trừ ASN Google ở SOC** (runbook phat-hanh-play mục 4) - để thiết bị duyệt không bị Threat Engine cấm.
> 3. **Khai báo phải khớp bản AAB.** Mục nào khai "Không" (quảng cáo, mã quảng cáo...) thì AAB không được có SDK / quyền
>    tương ứng (`build-aab.sh` đã kiểm quyền). Khi bật quảng cáo (M1b) hoặc bán Pro (R4) -> sửa khai báo TRƯỚC khi gửi bản đó.

---

## Phần A - "Hoàn tất bước thiết lập ứng dụng" (Trang tổng quan)

Vào: menu trái **Trang tổng quan** -> khối "Hoàn tất bước thiết lập ứng dụng" -> bấm từng dòng. Mỗi trang xong bấm **Lưu**
(góc dưới phải), rồi mũi tên "<- Trang tổng quan" để quay lại. Dòng xong sẽ bị gạch ngang.

### A1. Chính sách quyền riêng tư - ĐÃ XONG
Kiểm lại URL đã nhập là `https://compass.tsudev.com/quyen-rieng-tu` (đo 04/11: trả 200; bản en `/en/privacy` cũng 200).

### A2. Thông tin đăng nhập (trước là "Quyền truy cập vào ứng dụng") - ĐÃ XONG, giữ nguyên
- "Có phần nào trong ứng dụng của bạn bị hạn chế không?" -> **Không** (đúng: không tài khoản, không đăng nhập).
- Gói Pro (R4) KHÔNG làm đổi câu này: mua qua Google Play, không cần thông tin đăng nhập.
- Màn chặn chế độ Nhà phát triển KHÔNG khai ở đây (không phải "quyền truy cập bị hạn chế") - xử lý bằng kill-switch E1.

### A3. Quảng cáo (ảnh 03)
- Chọn **"Không, ứng dụng của tôi không chứa quảng cáo"** -> **Lưu**.
- Lý do: AAB hiện tại không có SDK quảng cáo (AdMob chỉ vào ở M1b sau Release Gate). Khi phát hành bản có AdMob ->
  quay lại đổi thành "Có" trước khi gửi bản đó (nhãn "Chứa quảng cáo" hiện trên Play).
- Mục này phải xong trước A5 (ảnh 05 báo "Hoàn thành phần Quảng cáo").

### A4. Mức phân loại nội dung - bảng câu hỏi IARC (ảnh 04)
Bấm **Bắt đầu trả lời bộ câu hỏi**.
1. **Danh mục / Category**
   - Địa chỉ email: `contact@tsudev.com` (IARC gửi chứng nhận phân loại về đây).
   - Chọn loại: **"Tất cả các loại ứng dụng khác"** (All Other App Types - tiện ích, công cụ). KHÔNG chọn Trò chơi /
     Mạng xã hội / Tham chiếu-Tin tức.
   - Tích đồng ý Điều khoản IARC -> **Tiếp theo**.
2. **Bảng câu hỏi** - trả lời **Không** cho mọi câu về: bạo lực, máu, nỗi sợ, nội dung tình dục / khoả thân, ngôn ngữ
   thô tục, chất kích thích (rượu, thuốc lá, ma tuý), cờ bạc / mô phỏng cờ bạc, hài thô, biểu tượng thù ghét / Đức quốc xã.
   Các câu "Thông tin khác / Miscellaneous":

   | Câu hỏi (ý chính) | Trả lời | Lý do |
   |---|---|---|
   | Người dùng có thể tương tác / trao đổi nội dung với nhau trong ứng dụng? | **Không** | không chat, không bình luận; chia sẻ điểm mốc là link gửi qua bảng chia sẻ của hệ thống |
   | Ứng dụng chia sẻ vị trí thực tế HIỆN TẠI của người dùng với người khác? | **Không** | không tự gửi vị trí; người dùng chủ động chia sẻ một điểm mốc qua app khác |
   | Ứng dụng cho phép mua hàng kỹ thuật số? | **Có** | gói La bàn Pro (Play Billing) đã có trong mã, bán từ R4 - khai sẵn để khỏi làm lại |
   | Ứng dụng là trình duyệt web / công cụ tìm kiếm? | **Không** | |
   | Ứng dụng chủ yếu là tin tức / giáo dục? | **Không** | |

3. **Lưu** -> **Tiếp theo** -> xem kết quả (dự kiến: IARC 3+, PEGI 3, ESRB Everyone, có thể kèm "Mua hàng trong ứng dụng")
   -> **Gửi**.

### A5. Đối tượng mục tiêu và nội dung (ảnh 05)
Chỉ mở được sau A3.
1. **Nhóm tuổi mục tiêu**: tích **13-15**, **16-17**, **18 trở lên**. KHÔNG tích nhóm dưới 13 (sẽ kéo theo Chính sách
   Gia đình + yêu cầu SDK được chứng nhận cho trẻ em). -> **Tiếp theo**.
2. **"Ứng dụng có thể vô tình thu hút trẻ em không?"** -> **Không** (giao diện công cụ, không nhân vật hoạt hình / trò chơi).
3. Nếu có câu **"Ứng dụng tin tức?"** -> **Không**.
4. **Lưu**.

### A6. An toàn dữ liệu (ảnh 06) - khớp `docs/store/data-safety.md`
Bấm **Tiếp theo** ở bước 1 "Tổng quan".

**Bước 2 - Bảo mật và thu thập dữ liệu**
| Câu hỏi | Chọn |
|---|---|
| Ứng dụng có thu thập hoặc chia sẻ loại dữ liệu người dùng bắt buộc nào không? | **Có** |
| Mọi dữ liệu người dùng mà ứng dụng thu thập có được mã hoá khi truyền không? | **Có** |
| Ứng dụng cho phép người dùng tạo tài khoản theo cách nào? | **Ứng dụng của tôi không cho phép người dùng tạo tài khoản** |
| (nếu hỏi) Đường liên kết yêu cầu xoá dữ liệu | `https://compass.tsudev.com/quyen-rieng-tu` (mục quyền của bạn: email privacy@tsudev.com + mã thiết bị) |
| (nếu hỏi) Người dùng có thể yêu cầu xoá dữ liệu? | **Có** |

**Bước 3 - Loại dữ liệu**: tích ĐÚNG 5 loại, không tích gì khác:
- **Vị trí** > **Vị trí gần đúng**
- **Thông tin tài chính** > **Nhật ký mua hàng**
- **Thông tin và hiệu suất ứng dụng** > **Nhật ký sự cố**, **Thông tin chẩn đoán**
- **Mã thiết bị hoặc mã khác** > **Mã thiết bị hoặc mã khác**

KHÔNG tích: Vị trí chính xác (xử lý trên máy), Ảnh / Video (camera AR không lưu, ảnh điểm mốc ở trên máy), Thông tin cá
nhân, Danh bạ, Hoạt động ứng dụng, Tệp và tài liệu.

**Bước 4 - Sử dụng và xử lý dữ liệu**: bấm mũi tên từng loại, điền:

| Loại | Thu thập | Chia sẻ | Xử lý tạm thời? | Bắt buộc / tuỳ chọn | Mục đích |
|---|---|---|---|---|---|
| Vị trí gần đúng | Có | Không | Không | **Người dùng có thể chọn** | Ngăn chặn gian lận, bảo mật và tuân thủ |
| Nhật ký mua hàng | Có | Không | Không | **Bắt buộc** (chỉ phát sinh khi mua Pro) | Chức năng ứng dụng |
| Nhật ký sự cố | Có | Không | Không | **Người dùng có thể chọn** (công tắc "Gửi báo cáo sự cố", mặc định tắt) | Chức năng ứng dụng |
| Thông tin chẩn đoán | Có | **Có** (Talsec - freeRASP) | Không | **Người dùng có thể chọn** | Ngăn chặn gian lận, bảo mật và tuân thủ |
| Mã thiết bị hoặc mã khác | Có | **Có** (Talsec - freeRASP) | Không | **Người dùng có thể chọn** | Ngăn chặn gian lận, bảo mật và tuân thủ |

"Người dùng có thể chọn" đúng vì chọn "Chỉ dùng ngoại tuyến" ở màn giới thiệu thì app không gửi gì. KHÔNG tích mục đích
Quảng cáo, Phân tích, Cá nhân hoá, Liên lạc của nhà phát triển.

**Bước 5 - Xem trước** -> đối chiếu phần "Chia sẻ dữ liệu" chỉ có 2 dòng (Thông tin chẩn đoán, Mã thiết bị) -> **Lưu**.
Mẹo: sau khi lưu bấm **Xuất sang CSV**, gửi agent lưu vào `docs/store/` để lần sau **Nhập từ CSV**.

### A7. Ứng dụng của chính phủ (ảnh 07)
Chọn **Không** -> **Lưu**.

### A8. Tính năng tài chính (ảnh 08)
Cuộn xuống CUỐI danh sách, tích **"Ứng dụng của tôi không cung cấp bất kỳ tính năng tài chính nào"** (không tích ô nào
ở Ngân hàng / Thanh toán / Tiền mã hoá...) -> **Tiếp theo** -> **Lưu**. Bán gói Pro qua Play Billing KHÔNG phải tính năng
tài chính.

### A9. Sức khoẻ (ảnh 09)
Cuộn xuống cuối, tích **"Ứng dụng của tôi không có bất kỳ tính năng nào liên quan đến sức khoẻ"** -> **Tiếp theo** ->
**Lưu**. (Không tích "Hoạt động và thể dục" - la bàn không theo dõi vận động.)

### A10. Chọn danh mục ứng dụng và cung cấp thông tin liên hệ = "Cài đặt cửa hàng" (ảnh 10)
Menu **Tăng số lượng người dùng > Sự hiện diện trên Cửa hàng > Cài đặt cửa hàng**.
1. Khối **Danh mục ứng dụng** -> **Chỉnh sửa**:
   - Ứng dụng hay trò chơi: **Ứng dụng** (đã có).
   - Loại / danh mục: **Công cụ** (Tools) - khớp `play-listing.md`.
   - Thẻ -> **Quản lý thẻ**: chọn tối đa 5 thẻ gần nhất trong danh sách Google đưa (ưu tiên: La bàn / Compass,
     Điều hướng / Navigation, Ngoài trời / Outdoor, Bản đồ / Maps, Đi bộ đường dài / Hiking) -> **Áp dụng** -> **Lưu**.
2. Khối **Thông tin liên hệ** -> **Chỉnh sửa**:
   - Địa chỉ email: `contact@tsudev.com` (bắt buộc, hiển thị công khai - phải nhận được thư).
   - Số điện thoại: để trống (không bắt buộc, tránh lộ số cá nhân).
   - Trang web: `https://compass.tsudev.com`
   - **Lưu**.
3. (Nếu có mục **Thông tin bên ngoài / Tiếp thị**) để mặc định.

### A11. Thiết lập trang thông tin trên Cửa hàng Play (ảnh 11)
Menu **Tăng số lượng người dùng > Sự hiện diện trên Cửa hàng > Trang thông tin trên Cửa hàng Play > Trang thông tin mặc định**.
1. Ngôn ngữ: **Mặc định - Tiếng Việt - vi** (giữ). Khối "Nhập bản dịch bằng AI" -> **Đóng** (dùng bản dịch tay ở bước 4).
2. **Thành phần văn bản phổ biến** - chép từ `docs/store/play-listing.md` khối `listing:vi`:
   - Tên ứng dụng: `La bàn - TsuDev Compass` (23/30 ký tự).
   - Mô tả ngắn: dòng dưới "### Mô tả ngắn" (<= 80).
   - Mô tả đầy đủ: toàn bộ khối dưới "### Mô tả đầy đủ" (<= 4000; `node tools/build/kiem-listing.mjs` đã kiểm).
3. **Thành phần đồ hoạ**:
   - Biểu tượng ứng dụng 512 x 512: `design/store/play-icon-512.png`.
   - Hình ảnh nổi bật 1024 x 500: `design/store/play-feature-1024x500.png`.
   - Ảnh chụp màn hình điện thoại: `design/store/play/vi/light-1.png` ... `light-6.png` (đúng thứ tự tên tệp).
   - Máy tính bảng 7 / 10 inch, Chromebook, video YouTube: để trống (không bắt buộc).
   - Ảnh từ WSL: mở `\\wsl.localhost\Ubuntu\home\devtsuitstmy\projects\app-la-ban\design\store` trong hộp chọn tệp Windows.
4. **Thêm bản dịch**: nút ngôn ngữ -> **Quản lý bản dịch > Thêm bản dịch của riêng bạn** -> **English (United States) - en-US**
   -> dán khối `listing:en`; ảnh dùng `design/store/play/en/light-1..6.png`; biểu tượng + ảnh nổi bật dùng chung.
5. **Lưu** (hoặc **Lưu dưới dạng bản nháp** nếu chưa đủ ảnh). Bước 2 "Bài đánh giá" bỏ qua.

Kiểm lần cuối mô tả: không chữ "tốt nhất / số 1 / miễn phí" trong tên, không emoji trong tên, không nhắc tên ứng dụng khác.

### A12. Các trang khác trong **Theo dõi và cải thiện > Chính sách và chương trình > Nội dung ứng dụng**
Không nằm trong 11 dòng nhưng Play có thể yêu cầu - mở trang **Nội dung ứng dụng**, tab "Việc cần làm":
| Trang | Trả lời |
|---|---|
| **Mã nhận dạng quảng cáo** (Advertising ID) | "Ứng dụng có sử dụng mã nhận dạng quảng cáo không?" -> **Không** (AAB không có quyền `AD_ID`). Đổi thành Có khi thêm AdMob (M1b) |
| Quyền truy cập ảnh và video / Dịch vụ trên nền trước / Vị trí ở chế độ nền | Không áp dụng - app không xin các quyền này. Nếu Play hỏi -> báo agent kiểm lại AAB |
| Ứng dụng VPN, Chính sách Gia đình, Tin tức | Không |

---

## Phần B - Thử nghiệm nội bộ (ảnh `thu-nghiem-noi-bo`, làm được ngay, không cần xong Phần A)

Menu **Kiểm thử và phát hành > Kiểm thử > Thử nghiệm nội bộ**. Tối đa 100 người, không qua duyệt, có sau vài phút.

### B1. Nhân viên kiểm thử (ảnh `..._nhan-vien-kiem-thu`)
1. Tab **Nhân viên kiểm thử** -> **Tạo danh sách email**.
2. Tên danh sách: `TsuDev noi bo`. Thêm email (Gmail đăng nhập Play trên M32 + email của bạn), mỗi dòng một email hoặc
   cách dấu phẩy -> **Lưu thay đổi**.
3. Tích chọn danh sách vừa tạo. **Phản hồi**: URL hoặc email -> `contact@tsudev.com`. -> **Lưu** (góc dưới phải).
4. Kéo xuống "Cách người thử nghiệm tham gia" -> **Sao chép đường liên kết** (dạng
   `https://play.google.com/apps/internaltest/...`) - mở trên M32 sau B3.

### B2. Khoá ký ứng dụng - ĐÃ CHỐT: Google Play tạo khoá (04/11/2026, Q63)
Bản AAB đầu (beta.16) đã tải lên mà không qua PEPK -> Play **tự tạo khoá ký ứng dụng**. Khoá này cố định cho
`com.tsudev.laban`, KHÔNG làm lại PEPK (Play chỉ cho "nâng cấp khoá" một lần, không cần).
- Đã đo trên M32 (bản cài từ Play, `apksigner`): chứng chỉ ký ứng dụng SHA-256
  `B8:4D:41:91:96:14:1B:48:C7:46:09:82:4B:3F:F4:1E:BC:C3:F5:1F:86:C9:4B:56:1F:BB:D2:04:40:F1:8B:7B`.
  Khoá upload (ký AAB agent tải lên + APK tải trực tiếp) vẫn là `CF:09:E7:...:F6:BD`.
- Agent đã thêm chứng chỉ Play vào: Worker prod `PI_CHUNG_CHI`, app (`Flavor.chungChiHopLe` - kiểm chữ ký native +
  freeRASP) từ bản beta.17, `assetlinks.json` (App Links). Bản beta.16 cài từ Play bị app tự báo `APP_REPACKAGED` ->
  dùng beta.17 trở đi cho mọi kênh Play.
- Hệ quả: bản APK tải trực tiếp và bản Play **không cập nhật đè lên nhau** (khác chữ ký) - người đang dùng APK muốn
  chuyển sang Play phải gỡ APK trước (dữ liệu trong máy mất; xuất JSON ở Cài đặt > Quyền riêng tư trước khi gỡ).
- Muốn tự xem trên Console: trang **Được bảo vệ bằng Play** (biểu tượng khiên ở menu trái) -> khối "Dịch vụ bảo vệ của
  Cửa hàng Play" -> mũi tên mở rộng -> **Ký ứng dụng Play** -> **Quản lý** (Console mới không còn tab "Ký ứng dụng"
  dưới "Tính toàn vẹn của ứng dụng").

### B2b. Trang "Được bảo vệ bằng Play" (biểu tượng khiên, URL `.../app/<id>/protect-with-play`)
| Khối | Trạng thái 04/11 | Làm gì |
|---|---|---|
| Tự động bảo vệ (1/1) | Đang bật | **Giữ bật.** Play chèn kiểm tra nguồn cài vào bản phân phối qua Play; không ảnh hưởng APK tải trực tiếp. |
| API Tính toàn vẹn của Play (0/7) | Chưa liên kết | **Bắt đầu** -> **Liên kết dự án trên Cloud** -> chọn `app-la-ban` (930761930572) -> **Liên kết**. Các mục "Phản hồi" / "Phân loại" khác để mặc định (Worker tự đọc phán quyết, không dùng tính năng thiết bị lặp lại / mã cảnh báo). Sau đó chờ ~10 phút rồi mở app trên M32 -> agent kiểm SOC `PLAY_RECOGNIZED`. |
| Dịch vụ bảo vệ của Cửa hàng Play (6/7) | Gần đủ | Mục còn thiếu thường là "Gói giải mã mã nguồn bị làm rối / ký hiệu gỡ lỗi" - không bắt buộc (cảnh báo vàng). |
| Dịch vụ bảo vệ của Play Billing (0/4) | Chưa | Để sau M1a bước 1 (khi tạo sản phẩm Pro); không ảnh hưởng duyệt. |

### B3. Tạo bản phát hành nội bộ
1. **Tạo bản phát hành mới** -> **Tải lên** -> chọn AAB
   `\\wsl.localhost\Ubuntu\home\devtsuitstmy\projects\app-la-ban\build\phat-hanh\0.1.0-beta.16\la-ban-0.1.0-beta.16.aab`
   (hoặc bản agent chép sẵn ở `C:\Users\devng\Downloads\laban\`).
2. Tên bản phát hành: để mặc định `16 (0.1.0-beta.16)`.
3. Ghi chú phát hành - dán nguyên khối:
   ```
   <vi-VN>
   Bản thử nội bộ đầu tiên trên Google Play: la bàn bắc thực, điểm mốc, bản đồ ngoại tuyến, Camera AR, trợ năng.
   </vi-VN>
   <en-US>
   First internal test on Google Play: true-north compass, waypoints, offline maps, Camera AR, accessibility.
   </en-US>
   ```
4. **Tiếp theo** -> trang xem lại: cảnh báo vàng (vd thiếu tệp gỡ rối mã gốc / deobfuscation) chấp nhận được; lỗi đỏ ->
   chụp gửi agent. -> **Lưu và xuất bản** (hoặc **Lưu** rồi **Tổng quan về việc xuất bản > Gửi thay đổi**).
5. Trên M32 (đăng nhập Gmail có trong danh sách): mở link B1.4 -> **Chấp nhận / Become a tester** -> **Tải xuống trên Google
   Play** -> cài. Bản prod chặn khi bật ADB -> muốn mở app phải tắt Developer options, hoặc agent bật E1 tạm thời.
6. Agent kiểm SOC: thiết bị mới có phán quyết app `PLAY_RECOGNIZED` (cổng R2) + so download size với `kich-thuoc.txt`.

Đã xong 04/11/2026: bản `16 (0.1.0-beta.16)` lên Thử nghiệm nội bộ, danh sách `TsuDev Compass noi bo` (2 người), link
tham gia `https://play.google.com/apps/internaltest/4700876326543944136`; M32 cài từ Play (installer
`com.android.vending`) và mở được. Bản kế tiếp (beta.17, có chứng chỉ Play) tải lên cùng kênh: **Tạo bản phát hành
mới** -> tải AAB -> ghi chú -> **Lưu và xuất bản**; người thử nhận cập nhật qua Play (vài phút - vài giờ).

---

## Phần C - Thử nghiệm khép kín (ảnh `thu-nghiem-khep-kin`) - BẮT BUỘC với tài khoản cá nhân

Mở được khi Phần A xong 11/11. Điều kiện để xin phát hành công khai (ảnh `phat-hanh-cong-khai`): **>= 12 người thử chọn
tham gia, liên tục >= 14 ngày**. Nên mời 15-20 người để dư khi có người rời.

### C1. Chọn quốc gia và khu vực
**Kiểm thử > Thử nghiệm khép kín > Kênh "Alpha" (Closed testing) > Quản lý kênh > Quốc gia / khu vực** -> **Thêm quốc gia /
khu vực** -> **Việt Nam** (thêm nước khác nếu người thử ở nước ngoài) -> **Lưu**.

### C2. Chọn người thử nghiệm
- Tab **Người kiểm thử** -> **Tạo danh sách email** `TsuDev thu kin` -> dán >= 12 Gmail (người dùng gom) -> **Lưu**; hoặc dùng
  một Google Group (`...@googlegroups.com`) để người thử tự vào.
- Email phản hồi: `contact@tsudev.com` -> **Lưu** -> sao chép link tham gia gửi cho từng người.
- Mỗi người PHẢI: mở link bằng đúng Gmail đó -> **Trở thành người thử nghiệm** -> cài từ Play -> giữ app cài suốt 14 ngày,
  mở vài lần / tuần (Play đếm "người đã chọn tham gia"; số này hiện ở mục C trên Trang tổng quan).

### C3. Tạo và gửi bản phát hành
1. **Tạo bản phát hành mới** -> **Thêm từ thư viện** chọn AAB đã tải ở B3 (hoặc **Thăng cấp bản phát hành** từ Thử nội bộ).
2. Ghi chú phát hành vi / en (như B3, đổi chữ "nội bộ" -> "thử kín").
3. **TRƯỚC khi gửi: làm mục E1** (kill-switch chế độ Nhà phát triển + miễn trừ ASN Google).
4. **Tiếp theo** -> **Lưu** -> **Tổng quan về việc xuất bản** -> **Gửi N thay đổi để xem xét**. Duyệt lần đầu thường 1-7 ngày.
5. Có bản bị từ chối -> email + **Trung tâm chính sách**: chụp gửi agent, KHÔNG gửi lại khi chưa sửa.
6. Ngày đủ 12 người ghi vào `AGENTS_LOG.md` (agent) - mốc 14 ngày tính từ đó.

---

## Phần D - Phát hành công khai (ảnh `phat-hanh-cong-khai`)

### D1. Đăng ký phát hành công khai (sau >= 14 ngày thử kín, >= 12 người)
Trang tổng quan -> **Đăng ký phát hành công khai** (nút sáng khi đủ 3 điều kiện). Câu trả lời gợi ý (tiếng Việt, cụ thể,
không bịa số liệu - điền số thật lúc đó):
- **Bạn tuyển người thử thế nào?** Người quen, đồng nghiệp và người dùng bản beta APK trên compass.tsudev.com; đủ máy
  Samsung / Xiaomi / Oppo, Android 8-14, có máy không có từ kế.
- **Người thử dùng những tính năng nào?** La bàn bắc thực + hiệu chuẩn, điểm mốc + dẫn đường, bản đồ ngoại tuyến, Camera AR,
  chia sẻ điểm bằng link / QR, chế độ sáng / tối, TalkBack.
- **Phản hồi nhận được và bạn đã thay đổi gì?** Liệt kê thật (vd nhãn nút bản đồ khó đọc -> viền chữ; độ tin cậy nhảy ->
  ô cố định; máy thiếu từ kế -> chuỗi nguồn hướng GPS / Mặt Trời). Agent tổng hợp từ `AGENTS_LOG.md` + SOC.
- **Ai là đối tượng, giá trị gì?** Người đi rừng / biển / làm việc ngoài trời, cần la bàn chính xác, chạy ngoại tuyến, không
  quảng cáo theo dõi.
- **Ứng dụng đã sẵn sàng thế nào?** Tỷ lệ không sự cố (Android vitals), kiểm thử bảo mật R3, chính sách quyền riêng tư vi / en.
Google trả lời trong ~7 ngày. Bị từ chối -> kéo dài thử kín thêm rồi đăng ký lại.

### D2. Bản phát hành công khai (R4 - sau Release Gate)
1. **Kiểm thử và phát hành > Phát hành công khai > Quốc gia / khu vực**: Việt Nam (+ nước khác nếu muốn) -> **Lưu**.
2. **Tạo bản phát hành mới** -> AAB R4 (versionCode mới, agent build) -> ghi chú vi / en.
3. **Phát hành theo giai đoạn**: 20 % -> theo dõi Android vitals 2-3 ngày -> 50 % -> 100 %.
4. Làm **E1** -> **Tổng quan về việc xuất bản** -> bật **Quản lý việc xuất bản** (để tự bấm xuất bản sau khi duyệt) ->
   **Gửi để xem xét**.
5. Duyệt xong: agent đổi nút "Google Play - sắp có" ở `/tai-ve` thành link Play; làm **E2**.
6. Nếu R4 bật bán Pro / quảng cáo: trước đó sửa A3 (Quảng cáo), A12 (Mã quảng cáo), A6 (thêm loại dữ liệu AdMob), tạo sản
   phẩm `pro_thang` / `pro_nam` / `pro_vinh_vien` + RTDN theo runbook phat-hanh-play mục 6.

---

## Phần E - Trước và sau MỖI lần gửi duyệt (thử kín, công khai, mọi bản cập nhật)

Mục tiêu: máy của người duyệt / pre-launch report (luôn bật ADB, nhiều máy là giả lập, IP thuộc mạng Google) mở app thấy
đầy đủ tính năng, không bị màn chặn chế độ Nhà phát triển (Q57) và không bị Threat Engine cấm. Ba lớp phải tắt đủ
(thiếu một lớp vẫn có thể bị từ chối "ứng dụng không hoạt động"):

| Lớp | Ai làm | Tắt gì |
|---|---|---|
| E1.1 App | người dùng ở SOC (four-eyes) | màn chặn trong app (cờ `chanDevMode` của Remote Config ký số) |
| E1.2 Worker | agent (`./tools/build/ky-duyet-play.sh bat`) | 403 `che-do-nha-phat-trien` ở route nghiệp vụ (`CHAN_DEV_MODE=0`) |
| E1.3 Threat Engine | người dùng ở SOC | cấm / hạn chế tự động thiết bị qua ASN Google (miễn trừ AS15169 + AS396982) |

### E0. Danh sách kiểm trước khi bấm "Gửi để xem xét" (đánh dấu từng dòng)
1. **Trang tổng quan**: "Hoàn tất bước thiết lập ứng dụng" 11/11 gạch ngang (Phần A). Thiếu mục nào Play không cho gửi.
2. **Tổng quan về việc xuất bản**: không còn lỗi đỏ; cảnh báo vàng đọc hết (thiếu ký hiệu gỡ lỗi = chấp nhận được).
3. **Chính sách quyền riêng tư** mở được: `https://compass.tsudev.com/quyen-rieng-tu` (agent đo `curl -sL`).
4. **Bản AAB** là bản mới nhất agent build (versionCode cao hơn mọi bản đã tải), targetSdk 36, đã có chứng chỉ Play (>= beta.17).
5. **An toàn dữ liệu (A6)** và **Quảng cáo (A3)** khớp bản AAB: chưa có AdMob -> "Không có quảng cáo"; chưa mở bán Pro
   trong prod (`moBanProTrongProd = false`) -> giữ khai báo như A4 / A6.
6. **Thông tin đăng nhập (A2)**: "Không cần đăng nhập" - app không có tài khoản; mọi tính năng mở ngay.
7. **Ghi chú cho người duyệt** (`docs/store/ghi-chu-reviewer.md`, dán vào ô ghi chú bản phát hành nếu Play hỏi): giải thích
   app cần cảm biến từ trường / vị trí, chạy ngoại tuyến, cơ chế bảo mật chỉ chặn máy root / bị can thiệp.
8. **E1.1 - E1.3 đã xong** và agent đã báo "kiểm E1 đạt" (bước E1.4).
9. Gửi -> ghi ngày giờ gửi vào `AGENTS_LOG.md` (báo agent) để đếm hạn E1 (30 ngày).

### E1. Tắt chặn cho kỳ duyệt (làm TRƯỚC khi gửi, cùng ngày)
**E1.1 - App (SOC, cần 2 Security Admin):**
1. Mở `https://compass-admin.tsudev.com` -> đăng nhập Access (mã PIN email) -> passkey.
2. Menu **Cấu hình từ xa** -> thẻ **Ứng dụng (Remote Config)**.
3. Khối **Tắt tính năng từ xa (kill-switch)** -> tích **Chặn chế độ Nhà phát triển**. KHÔNG tích ô nào khác (Bản đồ, Camera
   AR... sẽ biến mất với người duyệt). Giữ nguyên mã build tối thiểu / khuyến nghị và CA gốc.
4. **Hiệu lực (ngày)**: `30`. Lý do: `Google Play duyet ban <versionCode>`. -> **Đề xuất thay đổi** -> passkey.
5. Người thứ hai (Security Admin khác) đăng nhập -> **Cấu hình từ xa** -> mục **Yêu cầu** -> **Duyệt và ký** -> passkey.
   Thông báo "Đã ký và đưa gói mới lên" + **Chữ ký hợp lệ** ở gói đang phục vụ.
6. Chỉ có MỘT Security Admin: báo agent - agent ký bằng công cụ ngoại tuyến (`tools/cau-hinh/ky-cau-hinh.mjs dua-len-app
   --env prod --tat chanDevMode ...` giữ nguyên các giá trị đang phục vụ), ghi audit thủ công vào `AGENTS_LOG.md`.

**E1.2 - Worker (agent):** `./tools/build/ky-duyet-play.sh bat` -> đặt `CHAN_DEV_MODE = "0"` ở env prod, deploy prod, in
phiên bản Worker; agent commit thay đổi `wrangler.toml` qua PR nhỏ (để deploy sau không bật lại chặn ngoài ý muốn).

**E1.3 - Miễn trừ ASN Google (SOC, 1 Security Admin):**
1. Menu **Can thiệp** -> kéo xuống **Danh sách cho phép (miễn trừ)**.
2. Bấm **ASN Google Play review** (tự điền AS15169 + AS396982) -> **Thời hạn** `30 ngày` -> lý do `Google Play duyet` ->
   **Thêm miễn trừ** -> passkey. Bảng hiện 2 dòng `asn` còn hạn.

**E1.4 - Kiểm (agent + người dùng, 5 phút):** trên M32 bật Developer options + gỡ lỗi USB -> mở bản cài từ Play -> vuốt
xuống làm mới (hoặc đóng / mở lại app sau 1-2 phút để app lấy `/v1/config`) -> app dùng bình thường, KHÔNG màn chặn.
Agent đo `./tools/build/ky-duyet-play.sh trang-thai` (giá trị `CHAN_DEV_MODE` trong `wrangler.toml` prod + bản Worker
đang chạy). Đạt -> gửi duyệt (E0.9).

**Pre-launch report** (Kiểm thử > Báo cáo trước khi ra mắt): giữ BẬT khi E1 đã xong - báo cáo có ảnh từng màn, giúp thấy lỗi
trước người duyệt. Báo cáo có màn "Hãy tắt chế độ Nhà phát triển" = E1 chưa có hiệu lực lúc máy thử chạy -> sửa E1 rồi
gửi lại (không cần bản AAB mới).

### E2. Sau khi được duyệt (bật lại chặn theo Q57)
1. Email "Bản cập nhật đã được phê duyệt" / trạng thái **Đã xuất bản** -> báo agent.
2. SOC -> **Cấu hình từ xa** -> bỏ tích **Chặn chế độ Nhà phát triển** -> Đề xuất -> người thứ hai **Duyệt và ký**.
3. Agent: `./tools/build/ky-duyet-play.sh tat` (`CHAN_DEV_MODE = "1"` + deploy prod + PR).
4. SOC -> **Can thiệp** -> **Danh sách cho phép** -> **Gỡ miễn trừ** cả hai dòng ASN Google.
5. Kiểm: M32 bật gỡ lỗi USB -> bản Play hiện màn chặn; tắt -> dùng lại <= 5 s.
6. Agent ghi `AGENTS_LOG.md` thời điểm bật / tắt. Mỗi bản cập nhật gửi duyệt sau này lặp lại E0 -> E1 -> E2.

---

## Phần F - App "La bàn Pro" `com.tsudev.laban.pro` (M2, Q56, Q65) - NGƯỜI DÙNG làm, agent hướng dẫn theo ảnh chụp

Mã nguồn sẵn sàng (M2a): `app_pro/`, Worker đã nhận gói Pro (`PI_GOI`), SOC lọc theo ứng dụng. Làm SAU khi app miễn phí
ổn định kỳ duyệt (không làm hai app cùng lúc nếu Google còn đang duyệt app miễn phí).

### F1. Tạo ứng dụng
- Play Console -> **Tạo ứng dụng**: tên `La bàn Pro - TsuDev Compass`, ngôn ngữ mặc định Tiếng Việt, **Ứng dụng**,
  **Có phí** (KHÔNG đổi sang miễn phí được về sau - chọn đúng ngay), tick 2 cam kết -> Tạo.
- Giá: Kiếm tiền -> **Giá ứng dụng** -> 99.000 đ (Q56), để Play quy đổi các nước khác. Cần hồ sơ thanh toán (đã làm ở M1a bước 1).

### F2. Khoá ký ứng dụng - DÙNG CHUNG với La bàn (BẮT BUỘC chọn đúng ở lần tải AAB đầu)
- Thử nghiệm nội bộ -> Tạo bản phát hành -> mục **Khoá ký ứng dụng** -> **Chọn khoá ký** ->
  **"Dùng cùng khoá với một ứng dụng khác trong tài khoản nhà phát triển"** (Use the same key as another app) -> chọn
  `La bàn` (`com.tsudev.laban`). KHÔNG chọn "Google tạo khoá mới".
- Lý do: M2b chuyển điểm mốc từ app miễn phí sang Pro qua permission `signature` (hai app phải cùng chữ ký), và Worker
  (`PI_CHUNG_CHI`) + app (`Flavor.chungChiHopLe`) đã có sẵn chứng chỉ này. Nếu Play không hiện lựa chọn -> chụp ảnh gửi
  agent (agent thêm chứng chỉ mới và chuyển M2b sang phương án tệp xuất mã hoá).

### F3. Bản AAB đầu tiên
- Agent build: `./tools/build/build-aab.sh --pro` -> `build/phat-hanh/pro/<pb>/la-ban-pro-<pb>.aab` (script tự kiểm không có
  lớp / quyền quảng cáo). Người dùng tải lên kênh **Thử nghiệm nội bộ**, thêm cùng danh sách tester với app miễn phí.

### F4. Liên kết Play Integrity + quyền service account
- **Được bảo vệ bằng Play** / Tính toàn vẹn của ứng dụng -> Play Integrity API -> **Liên kết dự án Cloud** `930761930572`
  (giống B2b của app miễn phí). Thiếu bước này -> Worker không giải mã được token -> app Pro không nhận quyền lợi `pro_app`.
- Trang **Người dùng và quyền** (cấp tài khoản) -> service account Play Integrity / Play Developer API hiện có -> **Quyền đối với
  ứng dụng** -> thêm `La bàn Pro` (xem thông tin ứng dụng). Không cần quyền tài chính cho app Pro (không bán trong app).

### F5. Thiết lập app (giống Phần A) - khác biệt so với app miễn phí
- A3 Quảng cáo: **Không, ứng dụng không chứa quảng cáo**. A6 An toàn dữ liệu: KHÔNG khai Advertising ID, KHÔNG khai lịch sử
  mua hàng (mua app trả phí do Google xử lý, app không xử lý dữ liệu mua) - điền đúng theo `docs/store/data-safety-pro.md`.
- A2 Thông tin đăng nhập / ghi chú người duyệt: `docs/store/ghi-chu-reviewer.md` mục "La bàn Pro".
- A11 Trang thông tin: dán `docs/store/play-listing-pro.md` (vi-VN mặc định + bản dịch en-US; nêu rõ quan hệ bản miễn
  phí / Pro - tránh vi phạm chính sách nội dung lặp lại). Biểu tượng `design/store/pro/play-icon-512.png`, ảnh nổi bật dùng
  chung `design/store/play-feature-1024x500.png`, ảnh điện thoại `design/store/pro/<vi|en>/light-*.png`.
- Thử kín >= 12 người x 14 ngày RIÊNG cho app này (dùng chung 12 tester, chạy cùng lúc với app miễn phí - Q56).

### F6. Kiểm sau khi cài từ Play (agent làm cùng người dùng)
- Cài từ link thử nội bộ -> mở app -> Cài đặt -> **Bản quyền La bàn Pro** phải hiện "Đã xác minh qua Google Play" sau lần
  đồng bộ đầu; SOC -> Thiết bị -> lọc **Ứng dụng: La bàn Pro** thấy máy; SOC -> Quyền lợi Pro thấy `pro_app:<thiết bị>`.
- Bản sideload (APK tự build) phải hiện "Chưa xác minh", chạm -> hộp thoại "Tải từ Google Play" của Play.

## Phụ lục - đối chiếu ảnh chụp (`ky-ung-dung-la-ban/`, thư mục cục bộ, không commit)

| Ảnh | Mục |
|---|---|
| `Google Play Console.png` | Trang tổng quan, khối thử kín + phát hành công khai -> C, D |
| `hoan-tat-cac-buoc-thiet-lap/00` | danh sách 11 việc -> A |
| `02.thong-tin-dang-nhap` | A2 |
| `03.quang-cao` | A3 |
| `04.muc-phan-loai-noi-dung` | A4 |
| `05.noi-dung-va-doi-tuong-muc-tieu` | A5 |
| `06.an-toan-du-lieu` | A6 |
| `07.ung-dung-cua-chinh-phu` | A7 |
| `08.tinh-nang-tai-chinh` | A8 |
| `09.ung-dung-suc-khoe` | A9 |
| `10.cai-dat-cua-hang` | A10 |
| `11.trang-thong-tin-mac-dinh...` | A11 |
| `thu-nghiem-noi-bo/*` | B |
| `thu-nghiem-khep-kin/00` | C |
| `phat-hanh-cong-khai/*` | D |
