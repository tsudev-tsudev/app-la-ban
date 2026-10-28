// SEC-DATA DAT-02: audit log chuỗi băm chỉ thêm. hash_self = SHA-256(hash_prev + JSON chuẩn của bản ghi).
import { jsonChuan, sha256Hex } from './bam';

export const HASH_GOC = '0'.repeat(64);

export type NoiDungAudit = {
  id: string;
  actor: string;
  action: string;
  target: string | null;
  before: unknown;
  after: unknown;
  ip: string | null;
  ts: number;
};

export type DongAudit = Omit<NoiDungAudit, 'before' | 'after'> & {
  before: string | null;
  after: string | null;
  hash_prev: string;
  hash_self: string;
};

/** Bản ghi -> dòng D1 (before / after thành JSON chuẩn) kèm băm nối với [hashTruoc]. */
export async function taoDongAudit(noiDung: NoiDungAudit, hashTruoc: string): Promise<DongAudit> {
  const before = noiDung.before === undefined || noiDung.before === null ? null : jsonChuan(noiDung.before);
  const after = noiDung.after === undefined || noiDung.after === null ? null : jsonChuan(noiDung.after);
  const dong = { ...noiDung, before, after, hash_prev: hashTruoc };
  return { ...dong, hash_self: await bamDong(dong) };
}

async function bamDong(d: Omit<DongAudit, 'hash_self'>): Promise<string> {
  const { id, actor, action, target, before, after, ip, ts, hash_prev } = d;
  return sha256Hex(hash_prev + jsonChuan({ id, actor, action, target, before, after, ip, ts }));
}

/** Kiểm chuỗi theo thứ tự ghi: trả vị trí dòng đầu tiên sai (bị sửa / chèn / xoá giữa chuỗi), -1 nếu nguyên vẹn. */
export async function kiemChuoiAudit(dsDong: DongAudit[], hashDau: string = HASH_GOC): Promise<number> {
  let truoc = hashDau;
  for (const [i, d] of dsDong.entries()) {
    if (d.hash_prev !== truoc) return i;
    if ((await bamDong(d)) !== d.hash_self) return i;
    truoc = d.hash_self;
  }
  return -1;
}
