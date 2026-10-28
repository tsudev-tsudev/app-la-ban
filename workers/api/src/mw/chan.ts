import type { MiddlewareHandler } from 'hono';
import { napChan, napChoPhep } from '../threat/nap';
import { rutGonIp } from '../thuan/che-pii';
import { LoiApi } from '../thuan/loi';
import { khopQuyTac } from '../thuan/thuc-thi';
import type { MoiTruongHono } from '../moi-truong';
import { ghiLog } from './ghi-log';

/**
 * Chặn ở tầng Worker IP / dải / ASN có enforcement còn hiệu lực (trước cả WAF List, có hiệu lực ngay ở isolate ghi và
 * <= 15 s ở isolate khác). Allow-list thắng. Lỗi D1 -> cho qua (ưu tiên sẵn sàng) + log.
 */
export const chanTheoThucThi: MiddlewareHandler<MoiTruongHono> = async (c, next) => {
  const db = c.env.DB;
  const ip = c.get('ip');
  if (db && ip) {
    const asn = (c.req.raw as { cf?: { asn?: number } }).cf?.asn ?? null;
    let bi = false;
    try {
      const chan = await napChan(db);
      if (chan.length && khopQuyTac(chan, { ip, asn })) bi = !khopQuyTac(await napChoPhep(db), { ip, asn });
    } catch (e) {
      ghiLog('error', 'chan-loi', { loi: String(e) });
    }
    if (bi) throw new LoiApi(403, 'bi-chan', { ip: rutGonIp(ip) });
  }
  await next();
};
