# Runbook - công cụ quét bảo mật (R3a, SEC-TEST)

Tất cả cài vào `~/tools/` NGOÀI repo, không docker, chi phí 0. Cổng `./tools/kiem-tra/cong.sh day-du` coi thiếu
gitleaks / osv-scanner / semgrep là ĐỎ. ZAP và MobSF chạy tay theo phase (không nằm trong cổng - cần mạng + staging).

## 1. Cài (một lần mỗi máy)

```bash
mkdir -p ~/tools/bin ~/tools/dl && cd ~/tools/dl
export GH_TOKEN=$(gh auth token --user tsudev-tsudev)
# gitleaks (so checksum với gitleaks_<ver>_checksums.txt của release)
GL=$(gh api repos/gitleaks/gitleaks/releases/latest --jq .tag_name)
curl -sSLo gl.tgz "https://github.com/gitleaks/gitleaks/releases/download/$GL/gitleaks_${GL#v}_linux_x64.tar.gz"
tar xzf gl.tgz gitleaks && mv gitleaks ~/tools/bin/
# osv-scanner (so với osv-scanner_SHA256SUMS)
OSV=$(gh api repos/google/osv-scanner/releases/latest --jq .tag_name)
curl -sSLo ~/tools/bin/osv-scanner "https://github.com/google/osv-scanner/releases/download/$OSV/osv-scanner_linux_amd64"
chmod +x ~/tools/bin/osv-scanner
# semgrep (venv; Python 3.14 của máy chạy được)
python3 -m venv ~/tools/semgrep && ~/tools/semgrep/bin/pip install semgrep && ln -sf ~/tools/semgrep/bin/semgrep ~/tools/bin/semgrep
# ZAP bản cross-platform (JDK ~/tools/java/jdk >= 17; checksum ở release notes)
curl -sSLo zap.zip https://github.com/zaproxy/zaproxy/releases/download/v2.17.0/ZAP_2.17.0_Crossplatform.zip
unzip -q zap.zip -d ~/tools/
# MobSF (venv, chỉ phân tích tĩnh) - xem mục 4
```

## 2. Trong cổng `day-du`

| Bước | Lệnh | Ghi chú |
|---|---|---|
| gitleaks | `gitleaks git .` (toàn lịch sử) + `gitleaks dir .` | cấu hình `.gitleaks.toml`; báo nhầm đã kiểm tay ở `.gitleaksignore` (fingerprint + lý do) |
| Semgrep | `.semgrep/la-ban.yml` + `p/typescript` + `p/secrets` + `p/kotlin` | luật repo có test `semgrep --test` (`.semgrep/la-ban.ts`) |
| osv-scanner | `package-lock.json` + `pubspec.lock` | mọi mức đều đỏ; Medium không sửa được ngay -> `osv-scanner.toml` `[[IgnoredVulns]]` có `ignoreUntil` + lý do |

Luật Semgrep riêng: `la-ban-sql-noi-chuoi` (SQL D1 nội suy giá trị), `la-ban-admin-thieu-canquyen` (route SOC không
`canQuyen`), `la-ban-worker-log-bi-mat`, `la-ban-web-eval`. Chặn có chủ ý: `// nosemgrep: <id> - <lý do>` dòng ngay trước.

## 3. ZAP baseline (spider + thụ động, KHÔNG active scan)

```bash
./tools/thu/zap-baseline.sh https://compass-api-stg.tsudev.com/v1/health /v1/status /v1/device/me /admin/v1/toi
./tools/build/deploy-web.sh landing r3a   # preview, rồi:
./tools/thu/zap-baseline.sh https://r3a.la-ban-landing.pages.dev/ /en/ /tai-ve/ /khieu-nai/ /.well-known/security.txt
./tools/thu/zap-baseline.sh https://staging.la-ban-admin.pages.dev/ --access /api/toi
```

- Script TỪ CHỐI host prod. Proxy ZAP nghe `:8798` (8080 dùng chung với repo khác). Báo cáo `~/tools/zap-bao-cao/`.
- `--access` gửi service token `~/.config/la-ban/cau-hinh/access-svc-e2e.json`. Bẫy: replacer của Automation Framework
  KHÔNG thay `${VAR}` -> script ghi token vào kế hoạch trong thư mục tạm 0700 (xoá khi thoát). Không có token thì ZAP chỉ
  thấy trang đăng nhập Access (cảnh báo CSP `unsafe-inline` của Cloudflare - không phải của SOC).
- Tỷ lệ request tự động không token bị chặn: `node tools/thu/ty-le-chan.mjs` (staging, mục tiêu >= 99 %).
- Header / TLS: SSL Labs `https://api.ssllabs.com/api/v3/analyze?host=<host>&startNew=on`; securityheaders.com chặn
  curl (403) -> kiểm header bằng `curl -sSI` theo bảng ở báo cáo R3a.

## 4. MobSF (phân tích tĩnh APK)

```bash
python3 -m venv ~/tools/mobsf && ~/tools/mobsf/bin/pip install mobsf
```

Chạy (RAM ~1,5 GB, tắt Gradle daemon trước; cổng 8795 riêng repo này):

```bash
cd ~/tools/mobsf-home && MOBSF_HOME_DIR=$HOME/tools/mobsf-home nohup ~/tools/mobsf/bin/mobsf 127.0.0.1:8795 >> server.log 2>&1 &
K=<REST API Key in ở server.log>   # khoá cục bộ, không ghi vào repo
H=$(curl -s -F file=@<apk> -H "Authorization: $K" http://127.0.0.1:8795/api/v1/upload | jq -r .hash)
curl -s -X POST -H "Authorization: $K" --data "hash=$H" http://127.0.0.1:8795/api/v1/scan -o scan.json
curl -s -X POST -H "Authorization: $K" --data "hash=$H" http://127.0.0.1:8795/api/v1/scorecard -o score.json
fuser -k 8795/tcp
```

Lần đầu MobSF tự tải JADX / apktool vào `~/tools/mobsf-home/tools`. Kết quả + giới hạn: `docs/kiem-thu/R3a-*.md` mục 5.
