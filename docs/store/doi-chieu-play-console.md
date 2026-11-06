# Đối chiếu Google Play Console - La bàn + La bàn Pro (giao diện tiếng Việt)

Tổng hợp 06/11/2026 từ video giao diện Play Console của người dùng (thư mục ngoài repo, không commit) + mã nguồn `main`.
Mục đích: điền / sửa / kiểm Play Console THEO ĐÚNG THỨ TỰ, không để hai nơi nói khác nhau (nguyên nhân hay bị từ chối).
Tệp chi tiết từng ô: `huong-dan-play-console.md` (Phần A-F) - tệp NÀY là danh sách đối chiếu + thứ tự + chỗ đang lệch.

Quy ước: **[ĐANG LỆCH]** = trạng thái trong video khác điều app / tài liệu khai -> phải sửa trước khi gửi duyệt.
**[GIỮ NGUYÊN]** = đã đúng, đừng đổi. Tên mục / nút ghi đúng chữ Play Console tiếng Việt.

---

## 0. Trạng thái thấy trong video (06/11/2026)

| Mục | Thấy trong video | Đánh giá |
|---|---|---|
| Danh sách ứng dụng (Trang chủ) | chỉ 1 app `La bàn - TsuDev Compass` (`com.tsudev.laban`), "Thử nghiệm nội bộ" | App Pro CHƯA tạo (Phần F) |
| Trang tổng quan app | "Bản nháp của ứng dụng", tên tạm `com.tsudev.laban (unreviewed)` | Bình thường tới khi Google duyệt lần đầu |
| Thử nghiệm nội bộ | Đang hoạt động, bản 17 (0.1.0-beta.17) | [GIỮ NGUYÊN] |
| Thử nghiệm khép kín | chưa có bản, "0 người kiểm thử chọn tham gia" | Việc kế tiếp (mục 3) |
| Phát hành công khai | khoá - cần >= 12 người thử kín x 14 ngày | Chờ |
| Được bảo vệ bằng Play | Tự động bảo vệ 1/1, API Tính toàn vẹn 3/7, Cửa hàng 6/7, Play Billing 4/4 - "Mức độ bảo vệ cao" | [GIỮ NGUYÊN] (xem lưu ý mục 2.4) |
| Xác minh nhà phát triển Android | 1 tên gói `com.tsudev.laban` "Đã đăng ký", 3 khoá | **Thiếu `com.tsudev.laban.pro`** (mục 5.2) |
| Người dùng và quyền | 3 người dùng (2 Gmail + service account `la-ban-integrity@...`) | [GIỮ NGUYÊN]; thêm quyền app Pro ở F4 |
| Danh sách Email (Nhóm người thử nghiệm) | 1 danh sách "TsuDev Compass noi bo" = 5 địa chỉ | **Thử kín cần >= 12** (mục 3) |
| Kiếm tiền qua Play > Giá ứng dụng (app La bàn) | "Miễn phí" + link "Thay đổi ứng dụng thành có tính phí" | **[GIỮ NGUYÊN] MIỄN PHÍ - TUYỆT ĐỐI KHÔNG bấm link đó** (mục 4.1) |
| Gói thuê bao | `pro_thang` "La bàn Pro - Tháng": 1 gói cơ bản `app-laban-thang` Đang hoạt động, 1/5 quốc gia; `pro_nam` "La bàn Pro - Năm": **0 gói cơ bản đang hoạt động** | [ĐANG LỆCH] mục 4.3 |
| Biểu tượng gói thuê bao | `pro_thang` dùng icon CÓ CHỮ "THÁNG" | [ĐANG LỆCH] - Play: "Đừng chèn văn bản" -> dùng bản không chữ (mục 4.3) |
| Sản phẩm tính phí một lần | "Không có kết quả" (mã `pro_vinh_vien` đã xoá -> không dùng lại được) | Tạo `pro_tron_doi` (mục 4.4) |

---

## 1. Thứ tự làm (đừng đảo)

1. **App La bàn - hoàn tất "Nội dung ứng dụng"** (mục 2) -> kiểm từng dòng khớp tài liệu.
2. **App La bàn - Kiếm tiền**: sửa gói thuê bao + tạo sản phẩm một lần (mục 4) - KHÔNG đổi giá app.
3. **App La bàn - Thử nghiệm khép kín** với >= 12 Gmail, làm E0 + E1 rồi "Gửi để xem xét" (mục 3).
4. **App La bàn Pro** - Phần F: tạo app CÓ TÍNH PHÍ, DÙNG CHUNG khoá ký, nội dung riêng (mục 5).
5. Chờ Google duyệt -> E2 (bật lại chặn chế độ Nhà phát triển) -> agent làm việc sau duyệt (mục 6).

Mỗi lần đổi một mục trong Play Console: bấm **Lưu** ở góc dưới phải, rồi vào **Tổng quan về việc xuất bản** xem
"Thay đổi chưa xuất bản" - các thay đổi Nội dung ứng dụng / trang thông tin chỉ đến Google khi bấm **Gửi thay đổi để xem xét**.

---

## 2. App La bàn `com.tsudev.laban` - Nội dung ứng dụng (Theo dõi và cải thiện > Chính sách và chương trình > Nội dung ứng dụng)

| Mục Play Console | Trả lời ĐÚNG | Nguồn | Lỗi hay gặp |
|---|---|---|---|
| Chính sách quyền riêng tư | `https://compass.tsudev.com/quyen-rieng-tu` | landing (cập nhật 06/11, đã nêu app Pro) | dùng URL en hay trang chủ |
| Quyền truy cập vào ứng dụng (Thông tin đăng nhập) | "Tất cả chức năng đều có thể dùng mà không cần quyền truy cập đặc biệt" + hướng dẫn en | `ghi-chu-reviewer.md` phần đầu | chọn "có hạn chế" |
| Quảng cáo | **Không, ứng dụng của tôi không chứa quảng cáo** | M1b chưa bật (quảng cáo chỉ sau Release Gate) | chọn "Có" vì kế hoạch có AdMob - SAI cho bản hiện tại |
| Mã nhận dạng quảng cáo | **Không** dùng | APK không có `AD_ID` | |
| Mức phân loại nội dung (IARC) | Loại: **Tất cả các loại ứng dụng khác**; Không cho mọi câu bạo lực / tình dục / chất kích thích / cờ bạc; tương tác người dùng: **Không**; chia sẻ vị trí hiện tại: **Không**; **mua hàng kỹ thuật số: Có** | `huong-dan-play-console.md` A4 | quên "mua hàng kỹ thuật số" khi đã có gói thuê bao |
| Đối tượng mục tiêu | 13-15, 16-17, 18+ (KHÔNG chọn dưới 13) | A5 | chọn "mọi độ tuổi" -> kéo Chính sách gia đình |
| An toàn dữ liệu | đúng bảng `data-safety.md` mục 3 (Vị trí gần đúng, Mã thiết bị - chia sẻ Talsec, Nhật ký sự cố - tuỳ chọn, **Lịch sử mua hàng**, Chẩn đoán - chia sẻ Talsec); mã hoá khi truyền = Có; yêu cầu xoá = Có | `data-safety.md` | thiếu "Lịch sử mua hàng" trong khi đã có gói thuê bao -> lệch, bị từ chối |
| Ứng dụng của chính phủ | Không | | |
| Tính năng tài chính | "Ứng dụng của tôi không cung cấp tính năng tài chính" | | nhầm mua Pro là tính năng tài chính |
| Sức khoẻ | Không có tính năng sức khoẻ | | |
| Danh mục + liên hệ (Cài đặt cửa hàng) | Ứng dụng > Công cụ; email `contact@tsudev.com`; web `https://compass.tsudev.com` | `play-listing.md` | dùng website khác domain app (trang "Tài khoản nhà phát triển" đang để website khác - KHÔNG sao, nhưng ô Website của app phải là compass.tsudev.com) |
| Trang thông tin chính | dán `play-listing.md` (vi-VN mặc định + bản dịch en-US), ảnh `design/store/play/<vi|en>/light-*.png` (6 ảnh), biểu tượng `design/store/play-icon-512.png`, ảnh nổi bật `design/store/play-feature-1024x500.png` | `play-listing.md` | dán ảnh của app Pro (`design/store/pro/`) vào app miễn phí |

### 2.1 Trang thông tin có câu "không quảng cáo theo dõi" + có gói Pro
Mô tả hiện tại hợp lệ vì chưa có quảng cáo. **Khi M1b bật AdMob**: sửa đồng thời `play-listing.md`, mục Quảng cáo = Có,
An toàn dữ liệu thêm loại AdMob - trong CÙNG một lần "Gửi thay đổi để xem xét".

### 2.2 Mua trong ứng dụng
Play tự hiện nhãn "Mua hàng trong ứng dụng" khi app có gói thuê bao / sản phẩm đang hoạt động. Bản prod hiện ĐÓNG bán
(`moBanProTrongProd = false`, Q61) - vẫn khai IARC "mua hàng kỹ thuật số" + An toàn dữ liệu "Lịch sử mua hàng" để không
phải khai lại khi mở bán.

### 2.3 Ghi chú cho người duyệt
Dán đúng bản en ở `ghi-chu-reviewer.md`. Nhãn nút trong ghi chú khớp app: "Agree and start" / "Use offline only".

### 2.4 Được bảo vệ bằng Play - "Tự động bảo vệ" đang BẬT
Chặn cài bản tải ngoài của các bản Play phân phối. KHÔNG ảnh hưởng APK tự ký tải trực tiếp ở `compass.tsudev.com/tai-ve`
(R0) vì APK đó không đi qua Play. Không tắt. Liên kết dự án Cloud Play Integrity giữ nguyên (Worker cần để giải mã token).

---

## 3. Thử nghiệm khép kín (BẮT BUỘC với tài khoản cá nhân trước khi phát hành công khai)

Đường dẫn: **Kiểm thử và phát hành > Thử nghiệm > Thử nghiệm khép kín > Bắt đầu**.

1. **Nhóm người thử nghiệm** (Quản lý tài khoản > Nhóm người thử nghiệm / Danh sách Email): danh sách hiện có 5 địa chỉ ->
   **thêm cho đủ >= 12 Gmail THẬT** (tốt nhất 14-15 để dự phòng người không chọn tham gia). Có thể dùng chung danh sách
   cho cả app Pro (Q56).
2. Kênh thử kín: Chọn quốc gia và khu vực = **Việt Nam** (thêm nước khác tuỳ ý); Người thử nghiệm = tick danh sách ở bước 1;
   **URL phản hồi** = `contact@tsudev.com`.
3. **Tạo bản phát hành mới** -> "Thêm từ thư viện" chọn bản ĐÃ có ở nội bộ (beta.17, mã phiên bản 17) hoặc bản mới hơn
   agent build -> Ghi chú phát hành vi + en (`play-listing.md` cuối tệp) -> Tiếp -> Lưu.
4. Trước khi bấm **Gửi để xem xét**: làm **E0** (danh sách kiểm) + **E1** (tắt chặn chế độ Nhà phát triển cho kỳ duyệt) ở
   `huong-dan-play-console.md` Phần E. Báo agent để agent kiểm Worker prod `CHAN_DEV_MODE = "0"` + Remote Config.
5. Gửi link tham gia (trang kênh > "Tham gia trên web") cho người thử; mỗi người phải **chọn tham gia** + **cài** app.
   Trang tổng quan đếm "Hiện có N người kiểm thử chọn tham gia" - cần >= 12 và giữ 14 ngày liên tục.
6. Sau 14 ngày: **Trang tổng quan > Đăng ký phát hành công khai** -> trả lời câu hỏi về đợt thử (Phần D1).

---

## 4. Kiếm tiền qua Play (app La bàn `com.tsudev.laban`)

### 4.1 Giá ứng dụng - **[GIỮ NGUYÊN] Miễn phí**
App La bàn là app MIỄN PHÍ có gói Pro trong app. App trả phí một lần là app RIÊNG `com.tsudev.laban.pro` (mục 5).
Play cảnh báo: sau khi phát hành không đổi được giữa miễn phí / có phí. **Không bấm "Thay đổi ứng dụng thành có tính phí".**

### 4.2 Hồ sơ thanh toán
Gói thuê bao đã tạo được -> hồ sơ thanh toán đã có. Kiểm "Chế độ cài đặt về thuế và tuân thủ" của từng sản phẩm =
"Doanh thu từ ứng dụng kỹ thuật số - Dịch vụ" (như `pro_thang` trong video).

### 4.3 Gói thuê bao (Sản phẩm > Gói thuê bao)

| Mã sản phẩm | Tên (vi) | Gói cơ bản | Ưu đãi | Giá (Q55) | Trạng thái video |
|---|---|---|---|---|---|
| `pro_thang` | La bàn Pro - Tháng | 1 gói, tự động gia hạn **Hằng tháng** (mã gói cơ bản tuỳ ý, hiện `app-laban-thang`) | không | 19.000 đ | Đang hoạt động, **1/5 quốc gia** |
| `pro_nam` | La bàn Pro - Năm | 1 gói, tự động gia hạn **Hằng năm** (vd mã `app-laban-nam`) | **Dùng thử miễn phí 7 ngày** (mã ưu đãi tuỳ ý, vd `dung-thu-7-ngay`), điều kiện: người mua mới | 99.000 đ | **[ĐANG LỆCH] 0 gói cơ bản đang hoạt động** |

Việc cần làm:
- `pro_nam` -> **Thêm gói cơ bản** -> Tự động gia hạn, Hằng năm, "Tương thích ngược" (như gói tháng) -> Đặt giá 99.000 đ
  -> **Kích hoạt**. Rồi **Thêm ưu đãi** -> Dùng thử miễn phí 7 ngày -> Kích hoạt.
- Phạm vi quốc gia: `pro_thang` đang 1/5 - nếu chỉ bán ở Việt Nam thì hai gói phải CÙNG phạm vi (Việt Nam). App đọc giá /
  kỳ / ưu đãi từ Play nên mã gói cơ bản / ưu đãi đặt tên gì cũng được (không ghi cứng trong mã).
- **Biểu tượng**: thay icon có chữ "THÁNG" bằng bản không chữ `design/store/san-pham/khong-chu/pro_thang.png`
  (1 chấm) / `pro_nam.png` (2 chấm) - Play yêu cầu không chèn văn bản vào biểu tượng sản phẩm.
- Lợi ích (tối đa 40 ký tự / dòng): "Không quảng cáo", "Ủng hộ nhà phát triển" [GIỮ NGUYÊN].
- Phân loại theo độ tuổi: "Tất cả độ tuổi" [GIỮ NGUYÊN].

### 4.4 Sản phẩm tính phí một lần (Sản phẩm > Sản phẩm tính phí một lần > Tạo sản phẩm tính phí một lần)

| Ô | Giá trị |
|---|---|
| **Mã sản phẩm** | **`pro_tron_doi`** (Q67 - mã cũ `pro_vinh_vien` đã xoá, Play cấm dùng lại) |
| Thẻ | `pro` |
| Tên | Bản quyền La bàn Pro Vĩnh Viễn |
| Mô tả | Mua một lần: không quảng cáo và mọi tính năng Pro trên các máy dùng cùng tài khoản Google. |
| Biểu tượng | `design/store/san-pham/khong-chu/pro_tron_doi.png` (3 chấm) |
| Bước 2 "Tình trạng còn hàng và giá" > **Mã lựa chọn mua hàng** | **`pro-tron-doi`** (ô KHÁC "Mã sản phẩm": chỉ nhận chữ số, chữ thường, **gạch ngang**; người dùng không thấy; app + Worker KHÔNG dùng mã này) |
| Loại giao dịch mua hàng | **Mua** (không tiêu hao được - app xử lý như non-consumable) |
| Giá | 149.000 đ |
| Thuế | Doanh thu từ ứng dụng kỹ thuật số - Dịch vụ |

**Hai ô mã khác nhau (đo 06/11):** bước 1 "Mã sản phẩm" = product ID (gạch dưới / dấu chấm, KHÔNG gạch ngang) ->
`pro_tron_doi`, chính là mã app + Worker dùng; bước 2 "Mã lựa chọn mua hàng" = purchase option ID (mô hình sản phẩm một lần
mới của Play, giống mã gói cơ bản của gói thuê bao: CHỈ gạch ngang) -> `pro-tron-doi`. Không phải mâu thuẫn, không cần đổi mã.

**Quy tắc mã sản phẩm của Play** (đúng chữ trong ảnh lỗi người dùng gửi 06/11): *"Phải bắt đầu bằng một chữ số hoặc chữ cái
viết thường. Có thể chứa chữ số, chữ cái viết thường, dấu gạch dưới và dấu chấm."* -> **dấu gạch ngang `-` KHÔNG hợp lệ**
cho mã sản phẩm (lỗi đỏ khi gõ `pro-vinh-vien`), dấu gạch dưới `_` HỢP LỆ (`pro_thang`, `pro_nam` đã tạo được). Riêng **mã
gói cơ bản / mã ưu đãi** của gói thuê bao thì ngược lại: dùng gạch ngang (`app-laban-thang`).
Nếu `pro_tron_doi` vẫn bị từ chối: chụp NGUYÊN màn hình kèm dòng chữ đỏ dưới ô mã gửi agent - không tự đổi sang tên có
`-`; agent đổi mã ở `workers/api/src/thuan/quyen-loi.ts` + `packages/quyen_loi/lib/src/domain/san_pham.dart` cùng lúc
(mã trong Play phải trùng từng ký tự với mã trong app + Worker, lệch = mua xong không nhận Pro).
Chỉ **Kích hoạt** sản phẩm SAU khi agent báo Worker prod đã có mã mới.

### 4.5 Thông báo theo thời gian thực (RTDN)
Kiếm tiền qua Play > Thiết lập tính năng kiếm tiền: chủ đề `projects/app-la-ban/topics/play-rtdn`, nội dung "Gói thuê bao,
giao dịch mua hàng vô hiệu và tất cả các sản phẩm tính phí một lần" (runbook `phat-hanh-play.md` mục 6).

### 4.6 Thử nghiệm giấy phép (Quản lý tài khoản > Cài đặt ứng dụng Play > Thử nghiệm giấy phép)
Thêm Gmail người thử mua (license tester) -> mua thử không mất tiền. Cần cho cổng M1a và cho app Pro (LICENSED).

---

## 5. App La bàn Pro `com.tsudev.laban.pro` (CHƯA tạo - Phần F)

### 5.1 Tạo ứng dụng (Trang chủ > Tạo ứng dụng)
- Tên: `La bàn Pro - TsuDev Compass`; Ngôn ngữ mặc định: Tiếng Việt; **Ứng dụng**; **Có tính phí** (chọn đúng ngay - không
  đổi được về sau); tick 2 cam kết.
- Kiếm tiền qua Play > **Giá ứng dụng** -> 99.000 đ (Q56).
- KHÔNG tạo gói thuê bao / sản phẩm một lần cho app Pro.

### 5.2 Xác minh nhà phát triển Android
Quản lý tài khoản > **Xác minh nhà phát triển Android** > **Đăng ký tên gói** -> `com.tsudev.laban.pro` (hiện chỉ có
`com.tsudev.laban`). Khoá: cùng khoá upload + khoá ký Play như app La bàn.

### 5.3 Khoá ký - **DÙNG CHUNG với La bàn** (bắt buộc)
Lần tải AAB đầu: Thử nghiệm nội bộ > Tạo bản phát hành > Khoá ký ứng dụng > Chọn khoá ký -> **"Dùng cùng khoá với một
ứng dụng khác trong tài khoản nhà phát triển"** -> chọn La bàn. Sai bước này = không chuyển dữ liệu được từ app miễn phí
(quyền `signature`) và Worker không nhận chứng chỉ -> báo agent NGAY, đừng phát hành tiếp.

### 5.4 Bản AAB đầu tiên
Agent build `./tools/build/build-aab.sh --pro` (tự kiểm: không lớp quảng cáo, không `AD_ID`, không `BILLING`) -> người dùng
tải lên **Thử nghiệm nội bộ**, thêm cùng danh sách người thử.

### 5.5 Được bảo vệ bằng Play (app Pro)
Tính toàn vẹn của ứng dụng > Play Integrity API > **Liên kết dự án Cloud** cùng dự án với La bàn (`huong-dan-play-console.md`
B2b). Người dùng và quyền > service account `la-ban-integrity@...` > Quyền đối với ứng dụng > thêm La bàn Pro (xem thông tin
ứng dụng; KHÔNG cần quyền tài chính).

### 5.6 Nội dung ứng dụng (app Pro) - KHÁC app La bàn

| Mục | App Pro |
|---|---|
| Chính sách quyền riêng tư | cùng URL `https://compass.tsudev.com/quyen-rieng-tu` (đã nêu app Pro) |
| Quyền truy cập | Không cần quyền đặc biệt + ghi chú en `ghi-chu-reviewer.md` mục "La bàn Pro" |
| Quảng cáo | **Không** |
| Mã nhận dạng quảng cáo | **Không** |
| IARC | như La bàn nhưng **KHÔNG** "mua hàng kỹ thuật số" (app có phí khi tải, không IAP) |
| Đối tượng mục tiêu | 13+ như La bàn |
| An toàn dữ liệu | `data-safety-pro.md`: KHÔNG "Lịch sử mua hàng", KHÔNG mã quảng cáo; còn lại như La bàn |
| Danh mục / liên hệ | Công cụ; contact@tsudev.com; compass.tsudev.com |
| Trang thông tin | `play-listing-pro.md` (vi-VN + en-US), icon `design/store/pro/play-icon-512.png`, ảnh nổi bật dùng chung, ảnh điện thoại `design/store/pro/<vi|en>/light-*.png` (7 ảnh) |

### 5.7 Thử kín app Pro
>= 12 người x 14 ngày RIÊNG cho app này (dùng chung danh sách người thử, chạy song song với La bàn). Người thử phải
**mua** app (99.000 đ) - thêm họ vào **Thử nghiệm giấy phép** để không mất tiền.

---

## 6. Những chỗ dễ mâu thuẫn -> bị từ chối (kiểm lần cuối)

| # | Mâu thuẫn | Cách tránh |
|---|---|---|
| 1 | Trang thông tin La bàn nói "không quảng cáo" nhưng mục Quảng cáo = Có (hoặc ngược lại) | Hiện tại: cả hai "không". Đổi thì đổi cùng lúc |
| 2 | Có gói thuê bao nhưng An toàn dữ liệu thiếu "Lịch sử mua hàng" / IARC thiếu "mua hàng kỹ thuật số" | khai đủ ở app La bàn |
| 3 | App Pro khai "Lịch sử mua hàng" hoặc "Mã quảng cáo" | app Pro KHÔNG khai hai mục này |
| 4 | Hai listing gần giống nhau (nội dung lặp lại / spam) | dùng đúng `play-listing.md` cho La bàn và `play-listing-pro.md` cho Pro, ảnh Pro có ảnh 7 riêng |
| 5 | Đổi app La bàn sang "có tính phí" | không bao giờ - Pro là app riêng |
| 6 | Mã sản phẩm trên Play khác mã trong app / Worker | `pro_thang`, `pro_nam`, `pro_tron_doi` - đúng từng ký tự |
| 7 | Ghi chú người duyệt nói nút "Agree and start" nhưng app đổi nhãn | đối chiếu ARB trước khi gửi |
| 8 | Gửi duyệt khi chặn chế độ Nhà phát triển còn bật | làm E1 trước, E2 sau duyệt |
| 9 | App Pro ký khoá khác | mục 5.3 |
| 10 | Chính sách quyền riêng tư không nhắc app Pro | đã sửa 06/11 (landing prod) |
| 11 | Ảnh store của app này dán sang app kia | `design/store/play/` = La bàn, `design/store/pro/` = Pro |
| 12 | Gói thuê bao không có gói cơ bản hoạt động (`pro_nam`) nhưng app / Paywall hiện "Theo năm" | kích hoạt gói cơ bản năm (mục 4.3) - app chỉ hiện gói Play trả về, nhưng người duyệt có thể ghi nhận Paywall thiếu |

---

## 7. Sau khi làm xong - báo agent

Gửi ảnh chụp (hoặc video) các trang: Gói thuê bao (2 gói, mỗi gói >= 1 gói cơ bản đang hoạt động), Sản phẩm tính phí
một lần (`pro_tron_doi`), Thử nghiệm khép kín (số người chọn tham gia), danh sách app (có La bàn Pro), Xác minh nhà phát
triển Android (2 tên gói). Agent sẽ: deploy Worker nếu mã sản phẩm đổi, build AAB Pro, kiểm Integrity LICENSED / UNLICENSED,
thêm gói Pro vào `assetlinks.json`, ghi tiến độ.
