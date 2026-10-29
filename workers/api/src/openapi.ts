// Sinh tài liệu OpenAPI từ BoTuyen.ds. KHÔNG import từ mã chạy của Worker (giữ bundle nhỏ, không công khai - API-05);
// test/openapi.test.ts ghi workers/api/openapi.json.
import { z } from 'zod';
import type { DinhNghiaTuyen } from './tuyen';

const SchemaVanDe = z.object({
  type: z.literal('about:blank'),
  title: z.string(),
  status: z.number().int(),
  code: z.string().optional(),
  requestId: z.string().optional(),
});

/** Tài liệu OpenAPI 3.1 từ danh sách route (schema zod -> JSON Schema). */
export function taoOpenApi(ds: readonly DinhNghiaTuyen[], phienBan: string): Record<string, unknown> {
  const paths: Record<string, Record<string, unknown>> = {};
  const loi = { description: 'Lỗi RFC 7807', content: { 'application/problem+json': { schema: { $ref: '#/components/schemas/VanDe' } } } };
  for (const d of [...ds].sort((a, b) => a.duongDan.localeCompare(b.duongDan) || a.phuongThuc.localeCompare(b.phuongThuc))) {
    const duong = d.duongDan.replace(/:([A-Za-z0-9_]+)/g, '{$1}');
    const thamSo = [...d.duongDan.matchAll(/:([A-Za-z0-9_]+)/g)].map((m) => ({
      name: m[1],
      in: 'path',
      required: true,
      schema: { type: 'string' },
    }));
    if (d.phuongThuc === 'post' && d.idempotent !== false) {
      thamSo.push({ name: 'Idempotency-Key', in: 'header', required: true, schema: { type: 'string' } });
    }
    const thao: Record<string, unknown> = {
      summary: d.tomTat,
      responses: {
        [String(d.maThanhCong ?? 200)]: {
          description: 'Thành công',
          content: { 'application/json': { schema: z.toJSONSchema(d.phanHoi, { io: 'output' }) } },
        },
        default: loi,
      },
    };
    if (thamSo.length) thao.parameters = thamSo;
    if (d.xacThuc) thao.security = [{ phienThietBi: [], kyThietBi: [] }];
    if (d.body) {
      thao.requestBody = {
        required: true,
        content: { 'application/json': { schema: z.toJSONSchema(d.body, { io: 'input' }) } },
      };
    }
    paths[duong] = { ...paths[duong], [d.phuongThuc]: thao };
  }
  return {
    openapi: '3.1.0',
    info: { title: 'La bàn API', version: phienBan },
    servers: [{ url: 'https://compass-api.tsudev.com' }],
    paths,
    components: {
      schemas: { VanDe: z.toJSONSchema(SchemaVanDe) },
      securitySchemes: {
        phienThietBi: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT ES256' },
        kyThietBi: {
          type: 'apiKey',
          in: 'header',
          name: 'X-Signature',
          description:
            'ECDSA P-256 (DER, base64url) bằng khoá thiết bị trên "METHOD\\nPATH\\nSORTED_QUERY\\nSHA256_HEX(BODY)\\nX-Timestamp\\nX-Nonce"; kèm X-Timestamp (ms, lệch <= 60 s), X-Nonce (dùng 1 lần), X-Device-Id (tuỳ chọn).',
        },
      },
    },
  };
}
