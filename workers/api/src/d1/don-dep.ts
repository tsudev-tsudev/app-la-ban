// Cron dọn dữ liệu theo hạn lưu (Spec §6.4, DAT-01). Chạy lô nhỏ để nằm trong giới hạn CPU của cron.
import { rutGonIp } from '../thuan/che-pii';
import { cauDonDem } from '../thuan/dem-d1';
import { cauChonIpCanRutGon, cauLenhDonDep, cauLenhRutGonIp, type CauLenh, type DongIp } from '../thuan/don-dep';

const chuanBi = (db: D1Database, l: CauLenh) => db.prepare(l.sql).bind(...l.thamSo);

export async function donDep(db: D1Database, bayGio: number = Date.now()): Promise<{ ipRutGon: number }> {
  await db.batch(cauLenhDonDep(bayGio).map((l) => chuanBi(db, l)));
  const chon = cauChonIpCanRutGon(bayGio);
  const { results } = await chuanBi(db, chon).all<DongIp>();
  if (results.length) {
    await db.batch(results.flatMap((d) => cauLenhRutGonIp(d, rutGonIp(d.ip)).map((l) => chuanBi(db, l))));
  }
  return { ipRutGon: results.length };
}

/** R3c (Q52): bảng tạm nonce / bộ đếm giới hạn - mỗi lượt cron 5 phút (dòng sống <= 2 cửa sổ / 5 phút). */
export async function donDem(db: D1Database, bayGio: number = Date.now()): Promise<{ xoa: number }> {
  const kq = await db.batch(cauDonDem(bayGio).map((l) => chuanBi(db, l)));
  return { xoa: kq.reduce((t, k) => t + (k.meta.changes ?? 0), 0) };
}
