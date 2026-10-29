// SH-06: bản /js/khien.js đã làm rối nhưng vẫn giữ nguyên tên trường đi qua mạng, không eval, không comment.
import { describe, expect, it } from 'vitest';
// @ts-expect-error - module .mjs không có khai báo kiểu
import { dongGoi, THUOC_TINH_NOI_BO } from '../dong-goi.mjs';

describe('dongGoi', () => {
  it('giữ tên trường giao tiếp, đổi tên thuộc tính nội bộ', async () => {
    const ma: string = await dongGoi();
    for (const t of ['duongDan', 'tinHieu', 'kich_thuoc', 'duLieu', 'chuKy', '/v1/web/signals', '/v1/web/cau-hinh', 'data-khien']) {
      expect(ma).toContain(t);
    }
    for (const t of THUOC_TINH_NOI_BO as string[]) expect(ma).not.toMatch(new RegExp(`\\.${t}\\b|[{,]${t}:`));
    expect(ma).not.toMatch(/\beval\s*\(|new Function|innerHTML|\/\*|console\./);
  });
});
