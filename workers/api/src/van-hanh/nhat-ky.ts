// Cron xuất nhật ký bất biến D1 -> R2 NHAT_KY (S10a, MON-01) - xem thuan/nhat-ky-bat-bien.ts. Mỗi lượt tối đa LO_NHAT_KY
// dòng / bảng để nằm trong giới hạn CPU cron của gói Workers Free; còn tồn thì lượt 5 phút sau làm tiếp.
import type { Env } from '../moi-truong';
import { rutGonIp } from '../thuan/che-pii';
import {
  BANG_NHAT_KY,
  docDauChuoi,
  KHOA_DAU_CHUOI,
  LO_NHAT_KY,
  taoDoan,
  type DongXuat,
} from '../thuan/nhat-ky-bat-bien';

export type KetQuaNhatKy = { so: number; dong: number; con: boolean } | { bo: string };

export async function xuatNhatKy(env: Env, bayGio = Date.now()): Promise<KetQuaNhatKy> {
  const db = env.DB;
  const r2 = env.NHAT_KY;
  if (!db || !r2) return { bo: 'thieu-binding' };
  const vat = await r2.get(KHOA_DAU_CHUOI);
  const dau = docDauChuoi(vat ? await vat.text() : null);
  // Đầu chuỗi hỏng: dừng và báo lỗi (người vận hành sửa tay theo runbook) - tự tạo chuỗi mới sẽ che dấu vết.
  if (!dau) throw new Error('dau-chuoi-hong');

  const ds: DongXuat[] = [];
  let con = false;
  for (const bang of BANG_NHAT_KY) {
    // nosemgrep: la-ban-sql-noi-chuoi - bang lặp từ hằng BANG_NHAT_KY (as const)
    const { results } = await db
      .prepare(`SELECT rowid AS _so, * FROM ${bang} WHERE rowid > ? ORDER BY rowid LIMIT ?`)
      .bind(dau.conTro[bang], LO_NHAT_KY)
      .all<Record<string, unknown> & { _so: number }>();
    if (results.length === LO_NHAT_KY) con = true;
    for (const { _so, ...dong } of results) {
      // IP người dùng cuối chỉ giữ chi tiết 90 ngày (DAT-01) -> bản lưu 400 ngày chỉ có IP rút gọn.
      // audit_logs giữ nguyên (IP quản trị viên, nằm trong băm chuỗi audit - đổi là mất khả năng kiểm).
      if (bang === 'security_events' && typeof dong.ip === 'string') dong.ip = rutGonIp(dong.ip);
      ds.push({ bang, so: _so, dong });
    }
  }
  const doan = await taoDoan(dau, ds, bayGio);
  if (!doan) return { so: dau.so, dong: 0, con: false };

  await r2.put(doan.khoa, doan.ndjson, {
    httpMetadata: { contentType: 'application/x-ndjson; charset=utf-8' },
    customMetadata: doan.meta,
  });
  // Ghi đầu chuỗi có điều kiện: lượt cron chạy chồng (hiếm) không làm rẽ nhánh chuỗi.
  const moi = await r2.put(KHOA_DAU_CHUOI, JSON.stringify(doan.dau), {
    httpMetadata: { contentType: 'application/json' },
    ...(vat ? { onlyIf: { etagMatches: vat.etag } } : {}),
  });
  if (!moi) throw new Error('dau-chuoi-doi-giua-chung');
  return { so: doan.dau.so, dong: ds.length, con };
}
