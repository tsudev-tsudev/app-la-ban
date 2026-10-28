# ADR-0001: Flutter cho app, Cloudflare cho máy chủ và web

Ngày: 2026-10-28 · Trạng thái: Chấp nhận

## Bối cảnh
SPEC-COMPASS-MASTER-2026-V3 chọn Flutter và gợi ý backend NestJS/Go trên Kubernetes + PostgreSQL + Redis + Kafka. Chủ dự án đang
vận hành nhiều hệ thống trên Cloudflare (Workers, D1, Pages, Access) và muốn chi phí hạ tầng thấp, triển khai bằng wrangler.

## Quyết định
- App: Flutter (Dart 3, Impeller), pub workspace ở gốc repo.
- Máy chủ: Cloudflare Worker (Hono + zod) + D1 + Durable Objects + KV + R2 + Analytics Engine.
- Web: Astro (landing), Vite + React (admin SOC sau Cloudflare Access), Pages.
- Node 24 LTS cho repo (`.nvmrc`); TypeScript 6.0 (typescript-eslint chưa hỗ trợ 7).
- Cổng kiểm chạy cục bộ `tools/kiem-tra/cong.sh` (không GitHub Actions).

## Hệ quả
- Không có máy chủ để vá; giới hạn của D1 / Workers phải theo dõi (`docs/chi-phi.md`, phase N2).
- Nonce / rate limit cần nhất quán mạnh -> Durable Objects, không KV.
- Ánh xạ đầy đủ spec -> Cloudflare: kế hoạch tổng thể mục 1.
