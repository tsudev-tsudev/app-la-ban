# Kế hoạch bảo mật và chống can thiệp - app "La bàn"

28/10/2026 · Chuẩn hoá từ SPEC-SEC-2026-V2 (áp cho web/API), Spec §7-9 (app + SOC), hướng dẫn che comment (build web).
Agent chỉ đọc NHÓM được thẻ phase trỏ tới (`grep -n "^## SEC-"`). Ưu tiên: **P0** trước v1.0.0 · **P1** trong 8 tuần sau · **P2** backlog.

Chuẩn tham chiếu: OWASP MASVS v2 (L2 + R), MASTG, API Security Top 10, ASVS L2 (admin L3 cho xác thực), NIST CSF 2.0;
pháp lý: Luật ATTT mạng 2015, Luật An ninh mạng 2018, NĐ 13/2023/NĐ-CP. Nguyên tắc: quan sát trước, chặn sau (Report-Only /
log-only / shadow mode -> tinh chỉnh -> thực thi); mọi chặn có TTL, lý do, đường gỡ.

## SEC-SUP - Chuỗi cung ứng và mã nguồn (N0)
| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| SUP-01 | gitleaks pre-commit + trong cổng; không bí mật trong repo | P0 |
| SUP-02 | Lockfile (pubspec.lock, package-lock), Renovate, osv-scanner chặn Critical | P0 |
| SUP-03 | SBOM CycloneDX mỗi bản phát hành; chỉ SDK có trong QUYET_DINH | P1 |
| SUP-04 | Bảo vệ nhánh main, PR bắt buộc; vùng nhạy cảm cần ghi LOG lý do thay đổi | P0 |

## SEC-WEB-BUILD - Bản build web sạch (N0, S9)
| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| B-01 | Terser `comments: false`, `extractComments: false`, `drop_console`, `drop_debugger` | P0 |
| B-02 | CSS (lightningcss/cssnano) và HTML (html-minifier-terser / Astro compressHTML) xoá comment | P0 |
| B-03 | Không sourcemap công khai; nếu cần thì chỉ upload Sentry | P0 |
| B-04 | Comment không chứa bí mật / đường dẫn nội bộ / ghi chú bypass (ghi ở CONTRIBUTING.md) | P0 |
| B-05 | `tools/kiem-tra/ve-sinh-ban-build.mjs`: quét `dist/` - comment, console, `.map`, `*.LICENSE.txt` -> đỏ là chặn deploy | P0 |
| B-06 | `npm run dev` giữ nguyên comment | P0 |

## SEC-EDGE, SEC-TLS, SEC-HDR - Edge và header (N2, S8)
| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| EDG-01 | Mọi lưu lượng qua Cloudflare proxy; Worker/Pages không có origin lộ | P0 |
| EDG-02 | WAF Managed Rules + OWASP; log-only 1 tuần rồi chặn | P0 |
| EDG-03 | Rate-limit rule theo đường dẫn (API, appeal, signals); Bot Fight Mode | P0 |
| EDG-04 | Turnstile cho form công khai, xác minh token ở Worker | P0 |
| EDG-05 | DNSSEC, CAA, MFA phần cứng tài khoản Cloudflare/registrar | P0 |
| EDG-06 | Admin sau Cloudflare Access trước cả màn hình đăng nhập; chặn quốc gia ngoài danh sách cho admin | P0 |
| EDG-07 | Cấu hình Cloudflare là mã: `tools/cloudflare/*.json` + script dry-run/apply | P1 |
| TLS-01 | TLS >= 1.2 (ưu tiên 1.3), HSTS 1 năm + includeSubDomains (preload sau khi kiểm hết) | P0 |
| HDR-01 | nosniff, frame DENY + `frame-ancestors 'none'`, Referrer-Policy, Permissions-Policy tối thiểu, COOP/CORP | P0 |
| HDR-02 | Cookie admin `__Host-`, Secure, HttpOnly, SameSite=Strict | P0 |

## SEC-WEB-CSP - Client web (S8)
| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| CSP-01 | CSP L3 nonce theo từng lượt (Pages middleware) + `strict-dynamic`; không `unsafe-inline/eval`; `report-to` -> Worker | P0 |
| CSP-02 | Tự host thư viện; SRI cho mọi tài nguyên ngoài | P0 |
| CSP-03 | Trusted Types; cấm `innerHTML` thô (DOMPurify nếu bắt buộc) | P1 |

## SEC-WEB-SHIELD - Bảo vệ nội dung web (S9)
Lớp răn đe + thu tín hiệu; cấu hình mức (`tat` / `nhe` / `chat`) qua Remote Config ký số, mặc định `chat` cho landing và admin.
| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| SH-01 | Chặn menu chuột phải, kéo-thả ảnh, chọn/sao chép nội dung trình bày; ô nhập liệu và trình đọc màn hình KHÔNG bị ảnh hưởng | P0 |
| SH-02 | Chặn các phím tắt xem nguồn / lưu / in / công cụ nhà phát triển mà trang được phép chặn; CSS `@media print` ẩn nội dung | P0 |
| SH-03 | Nhận biết công cụ nhà phát triển theo nhiều tín hiệu; khi nghi ngờ: phủ màn hình tối + tạm ẩn dữ liệu nhạy cảm (admin) và gửi tín hiệu `/v1/web/signals`; ngưỡng chống báo nhầm, không treo trình duyệt | P1 |
| SH-04 | Admin: watermark động (email + thời gian) trên bảng dữ liệu; xuất CSV ghi audit | P0 |
| SH-05 | Ảnh/tài nguyên qua URL ký có hạn; chặn hotlink | P1 |
| SH-06 | Làm rối mã cho `web/shield` và module nhạy cảm (tùy chọn tương thích CSP, không eval) | P1 |
| SH-07 | Dữ liệu thật sự nhạy cảm không gửi xuống client (phân quyền ở Worker) - đây là lớp bảo vệ chính | P0 |

## SEC-API, SEC-DATA - API và dữ liệu (S1)
| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| API-01 | Rate-limit đa chiều (IP, thiết bị, phiên, endpoint); 429 + Retry-After; leo thang chậm -> challenge -> chặn tạm | P0 |
| API-02 | Validate zod: allowlist trường, giới hạn kích thước/độ sâu; truy vấn D1 tham số hóa 100% | P0 |
| API-03 | Idempotency-Key cho POST; ID dạng UUID/ULID | P0 |
| API-04 | Lỗi RFC 7807 chung chung, chi tiết chỉ ở log | P0 |
| API-05 | CORS allowlist chính xác; OpenAPI/debug không công khai | P0 |
| API-06 | `/admin/v1/*` chỉ nhận JWT Access hợp lệ + vai trò; thiếu cấu hình -> 503 (đóng khi lỗi) | P0 |
| DAT-01 | PII mask trong log; IP băm/rút gọn sau 90 ngày nếu không liên quan vi phạm; lưu trữ theo Spec §6.4 | P0 |
| DAT-02 | Audit log chuỗi băm, chỉ thêm | P0 |

## SEC-APP-STORAGE - Dữ liệu trên máy (A5)
SQLCipher + khóa bọc Keystore/Keychain; loại khỏi backup; không log token/tọa độ chính xác ở release; che app switcher ở màn nhạy cảm. P0.

## SEC-ID - Định danh và attestation (S2)
| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| ID-01 | Installation ID (Keychain ThisDeviceOnly / Keystore); không định danh phần cứng cố định | P0 |
| ID-02 | Khóa ECDSA P-256 không xuất được (Secure Enclave / StrongBox / TEE) | P0 |
| ID-03 | Play Integrity Standard + App Attest; nonce do server cấp gắn hành động; xác minh CHỈ ở server | P0 |
| ID-04 | Phiên ES256 15 phút gắn khóa; refresh xoay vòng, dùng lại -> thu hồi chuỗi | P0 |
| ID-05 | Dịch vụ attestation lỗi -> `UNVERIFIED`, hạn chế tính năng nhạy cảm | P0 |
| ID-06 | DeviceCheck bit đánh dấu thiết bị vi phạm bền qua cài lại (iOS) | P1 |

## SEC-NET - Kênh truyền (S3)
Chữ ký request + nonce/timestamp (lệch > 60 s hoặc nonce trùng -> từ chối); SPKI pinning >= 2 pin, xoay qua config ký số; chặn
cleartext và CA người dùng ở release; Remote Config ký Ed25519, app từ chối config sai chữ ký. P0.

## SEC-APP - Làm cứng app (S4)
| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| APP-01 | Obfuscation Dart + R8 full + strip symbol iOS; symbol map chỉ lưu nội bộ / Crashlytics | P0 |
| APP-02 | Bộ tín hiệu môi trường không tin cậy theo Spec §7.3b qua freeRASP + kiểm tra native; mỗi tín hiệu có trọng số, chỉ báo server | P0 |
| APP-03 | Kiểm tra toàn vẹn chữ ký gói; kết quả là tín hiệu | P0 |
| APP-04 | Phản ứng theo Risk Level (Spec §7.3 bảng); không hiện nguyên nhân kỹ thuật, chỉ mã REF | P0 |
| APP-05 | Kiểm tra ở nhiều thời điểm (mở app, định kỳ, trước thao tác nhạy cảm) | P1 |
| APP-06 | Bản release `debuggable=false`, component `exported=false`, deep link xác thực | P0 |

## SEC-DET - Phát hiện và phản ứng (S5)
Bảng điểm + ngưỡng clean/suspicious/restricted/banned (Spec §7.6c); rule có cửa sổ thời gian, phiên bản, shadow mode >= 7 ngày;
chặn thiết bị/IP đơn lẻ TTL 24h -> 7d -> 30d; CIDR/ASN/quốc gia chỉ là ĐỀ XUẤT cần duyệt (trừ chế độ Under Attack do người bật);
allow-list (IP văn phòng, thiết bị review store); uy tín phục hồi theo thời gian; đồng bộ Cloudflare Lists <= 30 s. P0.

## SEC-ADM - Admin SOC (S6, S7)
Access + passkey step-up; RBAC 5 vai trò (Spec §8.1) kiểm ở Worker từng đối tượng; phiên ngắn + timeout nhàn rỗi; four-eyes cho
hành động hàng loạt; audit bất biến (không ai sửa/xóa); CSV có kiểm soát; khiếu nại có Turnstile. P0.

## SEC-MON - Giám sát và ứng phó (S10)
| ID | Yêu cầu | Ưu tiên |
|---|---|---|
| MON-01 | Log tập trung JSON có `request_id`; Tail Worker -> R2 object lock, lưu >= 12 tháng | P0 |
| MON-02 | Cảnh báo Telegram: tăng đột biến 4xx/5xx, chặn hàng loạt, honeypot, đăng nhập admin lạ, attestation lỗi tăng | P0 |
| MON-03 | Backup D1 hằng ngày -> R2 mã hóa; diễn tập khôi phục hằng quý (RPO <= 24h, RTO <= 4h) | P0 |
| MON-04 | IR playbook: phát hiện -> cô lập -> loại bỏ -> khôi phục -> rút kinh nghiệm; thông báo theo NĐ 13/2023 | P0 |
| MON-05 | `security.txt` + chính sách báo lỗ hổng | P1 |

## SEC-TEST - Kiểm thử và nghiệm thu (R3)
| Hạng mục | Tiêu chí |
|---|---|
| Tự động | Semgrep, osv-scanner, gitleaks, MobSF, ZAP baseline: 0 Critical/High |
| Kịch bản nội bộ | Trên thiết bị thử của dự án: môi trường không tin cậy, bản đóng gói lại, phát lại request, giả vị trí, proxy chặn giữa -> >= 95% được ghi nhận, 100% request nhạy cảm không hợp lệ bị từ chối |
| Chặn nhầm | < 0,5% trên người dùng thật (đo sau R4) |
| Web | securityheaders A+, SSL Labs A+, CSP không unsafe-*; request tự động không token tới API bảo vệ bị chặn/challenge >= 99% |
| SOC | cảnh báo < 1,5 s, kill-switch <= 5 s, đồng bộ WAF <= 30 s, four-eyes + audit đúng |
| Pentest độc lập | 0 Critical/High mở trước v1.0.0 (Q25); Medium có hạn xử lý; retest |
