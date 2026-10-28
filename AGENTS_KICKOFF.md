# Khởi động phiên - repo app "La bàn"

Luật kỹ thuật ở `CLAUDE.md` (= `AGENTS.md`). Tệp này chỉ nói BƯỚC KHỞI ĐỘNG, CÁCH ĐỌC KẾ HOẠCH và LUẬT PHỐI HỢP.

## 1. Vai

| Agent | Vùng |
|---|---|
| `agent-laban` | mặc định - toàn repo (một agent thi công trọn MỘT phase mỗi phiên) |
| `agent-laban-may-chu` | `workers/`, `web/admin/`, `tools/cloudflare/` (chỉ khi người dùng chạy song song hai agent) |
| `agent-laban-app` | `app/`, `packages/`, `native/` (chỉ khi chạy song song) |

Không biết mình là agent nào thì là `agent-laban`.

## 2. Năm lệnh đầu phiên, rồi báo ngắn (<= 5 dòng: phase nào, phiếu nào, lock nào, cảnh báo nào)

```bash
./agents.sh brief                # LOCKS + lưu ý còn hiệu lực
./agents.sh inbox agent-laban    # phiếu bàn giao đang mở (mã HGLB-...)
./agents.sh runners              # ai đang chạy flutter test / build / wrangler / gradle
git log --oneline -10            # (phase N0: chưa có git - bỏ qua 2 lệnh git)
git status --short
```

## 3. Đọc gì (TIẾT KIỆM NGỮ CẢNH - đọc đúng đoạn, đừng đọc cả tệp)

1. `docs/ke-hoach/KE_HOACH_TONG_THE_LA_BAN.md` mục 0-3 (quyết định, kiến trúc, thứ tự phase, bảng Tiến độ) + ĐÚNG thẻ phase
   của mình ở mục 5 (`grep -n "^### " ` để tìm dòng, rồi đọc theo offset).
2. Thẻ phase có dòng `Đọc thêm:` - chỉ đọc đúng các mục được trỏ ở `KE_HOACH_BAO_MAT_CHONG_XAM_NHAP.md` (mã yêu cầu `SEC-...`).
3. `QUYET_DINH.md` (ngắn). Mục `[CẦN CHỐT]` liên quan phase mà chưa chốt -> HỎI người dùng trước khi làm phần đó.
4. ĐỪNG nạp 4 tài liệu gốc `2026*.md` ở gốc repo trừ khi thẻ phase yêu cầu một mục cụ thể - phần cần đã chép vào kế hoạch.
5. Tệp mã lớn: `grep -n` trước, đọc theo đoạn.

## 4. Luật phối hợp

- Agent TỰ lập kế hoạch chi tiết cho phase và TỰ làm hết; không chia việc, không sinh sub-agent (tốn token gấp nhiều lần).
- `./agents.sh lock "agent-laban · <tệp/thư mục> · <việc>"` TRƯỚC khi sửa; thấy lock của agent khác thì không đụng.
- Việc phát sinh ngoài phase: ghi vào thẻ phase phù hợp trong kế hoạch (dòng `Phát sinh:`), KHÔNG tự làm lan ra.
- Việc cần người dùng (tài khoản store, DNS, thiết bị thật, ký hợp đồng pentest...): ghi rõ ở báo cáo cuối phiên + phiếu bàn giao.
- Phase sẽ quá dài cho một phiên -> dừng ở ranh giới gọn (cổng xanh, commit), ghi `Tiến độ: x/y bước` và mở phiếu cho phiên sau.

## 5. Tiết kiệm thời gian build / test / deploy

- Giữa phase: `./tools/kiem-tra/cong.sh nhanh` (chỉ gói đã đổi). Cuối phase: `day-du` MỘT lần.
- Không chạy `flutter build apk/ipa` giữa chừng - chỉ cuối phase có đổi native, hoặc phase R*. Ưu tiên `flutter test` + golden.
- Không chạy chồng hai việc nặng (`./agents.sh runners`). Gradle daemon giữ lại giữa các lần build, đừng `--no-daemon`.
- Worker: `wrangler deploy --dry-run` để kiểm gói; deploy thật MỘT lần cuối phase (staging -> prod).
- Pages: chỉ deploy dự án web có đổi. Đổi CSP / header -> preview branch trước.
- Một phase = một nhánh = một PR = một squash merge. Không mở PR nháp lặt vặt.

## 6. Cuối phase (theo đúng thứ tự)

cổng `day-du` xanh -> commit -> push `phase/<mã>` -> PR base `main` -> merge -> deploy phần có đổi (mục Phát hành của
CLAUDE.md) -> đo bản đang phục vụ -> ghi bảng Tiến độ + dòng `Kết quả:` vào thẻ phase -> `./agents.sh log '...'` ->
`./agents.sh handoff agent-laban agent-laban "<phase kế>" "<việc + bẫy>"` -> commit `AGENTS_LOG.md` + kế hoạch ->
tắt tiến trình nền (`fuser -k 3030/tcp 3031/tcp 8797/tcp`) -> `./agents.sh unlock "agent-laban"` -> báo người dùng.

- `./agents.sh log` / `note`: dùng NHÁY ĐƠN (backtick trong nháy kép bị shell thực thi). `note` không chạy lại (sinh dòng trùng).
- Board chỉ giữ <= 8 lưu ý ĐANG hiệu lực; lưu ý hết hiệu lực thì xoá dòng, bản đầy đủ vẫn ở LOG.
