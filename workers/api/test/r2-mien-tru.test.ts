import { describe, expect, it } from 'vitest';
import { asnCua } from '../src/mw/dich-vu';
import { ASN_GOOGLE, chuanHoaChoPhep, SchemaThemChoPhep } from '../src/thuan/cho-phep';

describe('R2: miễn trừ theo ASN', () => {
  it('ASN lấy từ request.cf (số nguyên dương), thiếu -> null', () => {
    const rq = (cf?: unknown) => ({ req: { raw: Object.assign(new Request('https://x'), cf === undefined ? {} : { cf }) } });
    expect(asnCua(rq({ asn: 15169 }))).toBe(15169);
    expect(asnCua(rq({ asn: '15169' }))).toBeNull();
    expect(asnCua(rq())).toBeNull();
  });

  it('allow-list: chuẩn hoá AS15169, bỏ trùng, dải quá rộng hỏng; luôn có hạn <= 90 ngày', () => {
    expect(chuanHoaChoPhep([{ loai: 'asn', giaTri: 'AS15169' }, { loai: 'asn', giaTri: '15169' }, { loai: 'cidr', giaTri: '10.0.0.0/8' }])).toEqual({
      dich: [{ loai: 'asn', giaTri: '15169' }],
      loi: ['dich.2'],
    });
    expect(ASN_GOOGLE).toEqual(['15169', '396982']);
    const goc = { dich: [{ loai: 'asn', giaTri: '15169' }], thoiHan: '90d', lyDo: 'Google Play review' };
    expect(SchemaThemChoPhep.safeParse(goc).success).toBe(true);
    expect(SchemaThemChoPhep.safeParse({ ...goc, thoiHan: '365d' }).success).toBe(false);
    expect(SchemaThemChoPhep.safeParse({ ...goc, lyDo: 'ngắn' }).success).toBe(false);
  });
});
