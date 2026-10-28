import { cheLog } from '../thuan/che-pii';

export type MucLog = 'info' | 'warn' | 'error';

/** Log JSON một dòng (Workers Logs). MỌI dữ liệu đi qua cheLog - không bao giờ ghi token / toạ độ / IP đầy đủ. */
export function ghiLog(muc: MucLog, thongDiep: string, du: Record<string, unknown> = {}): void {
  const dong = JSON.stringify({ muc, thongDiep, ...(cheLog(du) as Record<string, unknown>) });
  // eslint-disable-next-line no-console -- đầu ra log có chủ đích của Worker
  console[muc === 'info' ? 'log' : muc](dong);
}
