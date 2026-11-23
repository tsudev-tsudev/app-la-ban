# Antivirus / báo nhầm - La bàn

Chuẩn: `.standards/docs/DISTRIBUTION_TRUST.md` mục 3, 3.1 · phiếu `logs/handover/20261122-AV1_bao-nham-antivirus.md`.

## Cách kiểm

- Mỗi lần phát hành APK: `tools/build/phat-hanh-apk.sh` gọi `tools/build/kiem-virustotal.sh` TRƯỚC khi tải lên R2 /
  GitHub Release. Có hãng báo malicious / suspicious -> script dừng, KHÔNG công bố; ghi bảng dưới và nộp báo nhầm cho hãng
  trong <= 48 giờ (thư soạn sẵn: `~/projects/logs/handover/20261122-AV1_bao-nham-antivirus-toan-he.md` mục 2-3).
- Khoá API ở `~/.config/tsudev/virustotal.env` (ngoài repo). Không có khoá -> script bỏ qua (exit 2), kiểm tay trên
  https://www.virustotal.com trước khi công bố.
- Tên miền: `GET /api/v3/domains/<tên miền>` + Google Safe Browsing (https://transparencyreport.google.com/safe-browsing/search).
- Không dùng job GitHub Actions dùng chung (`virustotal.yml`) vì repo không chạy CI GitHub (billing) - cổng là máy local.

## Kết quả

| Ngày | Đối tượng | Kết quả | Ghi chú |
| --- | --- | --- | --- |
| 23/11/2026 | compass., compass-api., compass-admin., compass-cdn., compass-status.tsudev.com | 0 malicious / 0 suspicious | VirusTotal domains |
| 24/11/2026 | `la-ban-0.1.0-beta.17-arm64.apk` (360045395cb3...) | **1/66: Huorong `Ransom/Android.LockScreen.m`** | báo nhầm - ĐÃ GỬI 24/11/2026 |
| 23/11/2026 | `la-ban-0.1.0-beta.17-armv7.apk` (ce075abd3332...) | **1/66: Huorong `Ransom/Android.LockScreen.m`** | báo nhầm - ĐÃ GỬI 24/11/2026 |

## Thư báo nhầm Huorong - ĐÃ GỬI 24/11/2026

Gửi qua Resend (team tsudev.com, khoá `~/.config/tsudev/resend.env`) theo uỷ quyền chủ dự án, From / Reply-To
`security@tsudev.com` (Cloudflare Email Routing), Resend id `01a20aad-e162-70fe-a487-f7892f8b21da`. Đo lại VT 3-7 ngày sau
(27-30/11/2026); hết cờ -> ghi ngày gỡ + ĐÓNG phiếu AV1.

Kênh: `seclab@huorong.cn` (https://docs.virustotal.com/docs/false-positive-contacts, cập nhật 20/10/2026).

**Subject:** False positive report: La bàn (Smart Compass) Android APKs (2 files) - Ransom/Android.LockScreen.m

```text
Hello Huorong Security Lab,

We are TsuDEV (https://tsudev.com), the publisher of the Android app "La bàn" (Smart Compass,
package com.tsudev.laban). Your engine on VirusTotal reports the files below as
Ransom/Android.LockScreen.m. We believe this is a false positive.

File: la-ban-0.1.0-beta.17-arm64.apk
SHA-256: 360045395cb3f66f2c81c2459e74b29d7d49ed03e16e522acff3042269d6b331
VirusTotal: https://www.virustotal.com/gui/file/360045395cb3f66f2c81c2459e74b29d7d49ed03e16e522acff3042269d6b331
Download: https://compass-cdn.tsudev.com/android/la-ban-0.1.0-beta.17-arm64.apk

File: la-ban-0.1.0-beta.17-armv7.apk
SHA-256: ce075abd33326021f17e5e3bb5d26c2ed8d794e34ea2d1a1980b6ba3ad214432
VirusTotal: https://www.virustotal.com/gui/file/ce075abd33326021f17e5e3bb5d26c2ed8d794e34ea2d1a1980b6ba3ad214432
Download: https://compass-cdn.tsudev.com/android/la-ban-0.1.0-beta.17-armv7.apk
Product page: https://compass.tsudev.com

The app is a compass / navigation tool. It does not lock the screen, does not request device
administrator or accessibility permissions, does not encrypt user files and does not ask for
payment to unlock anything. It contains an in-app security module (root / tamper detection)
that only reports signals to our own server. Requested permissions: location, camera (AR view),
internet, receive boot completed - no device admin, accessibility, overlay or keyguard permissions.

Please review and remove the detection. We are happy to provide any further information.

Best regards,
TsuDEV
```
