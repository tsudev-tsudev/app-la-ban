import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { Hono } from 'hono';
import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { boTuyen } from '../src/index';
import type { MoiTruongHono } from '../src/moi-truong';
import { taoOpenApi } from '../src/openapi';
import { BoTuyen } from '../src/tuyen';

// openapi.json KHÔNG phục vụ công khai (SEC-API API-05); sinh lại: CAP_NHAT_OPENAPI=1 npx vitest run test/openapi.test.ts
const TEP = join(__dirname, '../openapi.json');

describe('OpenAPI sinh từ định nghĩa route', () => {
  it('openapi.json khớp mã nguồn', () => {
    const tai = `${JSON.stringify(taoOpenApi(boTuyen.ds, '1'), null, 2)}\n`;
    if (process.env.CAP_NHAT_OPENAPI === '1' || !existsSync(TEP)) writeFileSync(TEP, tai);
    expect(readFileSync(TEP, 'utf8')).toBe(tai);
  });

  it('POST có Idempotency-Key, requestBody chặn trường lạ, tham số đường dẫn', () => {
    const bo = new BoTuyen(new Hono<MoiTruongHono>());
    bo.dangKy(
      { phuongThuc: 'post', duongDan: '/v1/a/:id', tomTat: 'a', body: z.strictObject({ x: z.string() }), phanHoi: z.object({}), maThanhCong: 201 },
      (c) => c.json({}),
    );
    const tl = taoOpenApi(bo.ds, '1') as { paths: Record<string, Record<string, Record<string, unknown>>> };
    const thao = tl.paths['/v1/a/{id}']?.post ?? {};
    expect(thao.parameters).toEqual([
      { name: 'id', in: 'path', required: true, schema: { type: 'string' } },
      { name: 'Idempotency-Key', in: 'header', required: true, schema: { type: 'string' } },
    ]);
    expect(JSON.stringify(thao.requestBody)).toContain('"additionalProperties":false');
    expect(Object.keys(thao.responses as object)).toEqual(['201', 'default']);
  });

  it('POST thiếu schema body bị từ chối khi đăng ký', () => {
    const bo = new BoTuyen(new Hono<MoiTruongHono>());
    expect(() => bo.dangKy({ phuongThuc: 'post', duongDan: '/x', tomTat: 'x', phanHoi: z.object({}) }, (c) => c.json({}))).toThrow(/cần schema body/);
  });
});
