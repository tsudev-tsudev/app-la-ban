# PHIẾU YÊU CẦU AV1 - Antivirus / báo nhầm (app-la-ban)

- **Mã phiếu**: 20261122-AV1
- **Thời điểm**: 22/11/2026
- **Người gửi**: agent-tsuswico (phiên tsuswico-6e) theo uỷ quyền của chủ dự án
- **Phiếu điều phối**: `~/projects/logs/handover/20261122-AV1_bao-nham-antivirus-toan-he.md` (bảng kết quả cả hệ + thư soạn sẵn từng hãng)
- **Chuẩn**: `.standards/docs/DISTRIBUTION_TRUST.md` mục 3, 3.1
- **Trạng thái**: MỞ - chờ 👤 chủ dự án gửi thư báo nhầm Huorong (hạn 25/11/2026)

## 1. Hiện trạng 22/11/2026

Repo chưa phát hành tệp nhị phân trên GitHub Release (không có tệp để quét). Tên miền chung tsudev.com + swico./files./sound. sạch trên VirusTotal.

## 2. Việc cần làm (phòng ngừa)

1. Khi bắt đầu phát hành tệp chạy được (exe/msi/apk/dmg/AppImage/zip): Release NHÁP + job VirusTotal dùng chung (`tsudev-org/.github/.github/workflows/virustotal.yml`); sạch mới công bố; cờ ⇒ ghi `docs/store/antivirus.md` + nộp ≤ 48 giờ theo phiếu điều phối.
2. Repo có website riêng: kiểm tên miền trên VirusTotal (`/api/v3/domains/<tên miền>`) và Google Safe Browsing; bị gắn cờ ⇒ báo theo `DISTRIBUTION_TRUST.md` mục 3.
3. Không có việc khác ⇒ ghi kết quả kiểm vào phiếu rồi ĐÓNG.

## 4. Kết quả xử lý (23/11/2026)

- Hiện trạng ở mục 1 CHƯA đúng: repo CÓ phát hành APK (GitHub pre-release `v0.1.0-beta.*` + `compass-cdn.tsudev.com/android/`).
- Tên miền compass., compass-api., compass-admin., compass-cdn., compass-status.tsudev.com: 0 malicious / 0 suspicious.
- APK beta.17 chưa từng có trên VT -> gửi quét: **arm64 + armv7 đều 1/66 Huorong `Ransom/Android.LockScreen.m`** (báo nhầm - app
  không có quyền device admin / accessibility / overlay). Ghi + thư soạn sẵn: `docs/store/antivirus.md`.
- Phòng ngừa: `tools/build/kiem-virustotal.sh` (tra băm, chưa có thì tải lên, có cờ -> exit 1) gắn vào `phat-hanh-apk.sh` TRƯỚC
  khi tải lên R2 / GitHub Release (thay cho job CI dùng chung vì repo không chạy CI GitHub).
- Còn lại: 👤 gửi thư Huorong tới `seclab@huorong.cn`; agent sau kiểm lại Huorong (`kiem-virustotal.sh` hoặc API) rồi ĐÓNG.
