// Dọn định kỳ (cron) theo chính sách lưu trữ Spec §6.4 + SEC-DATA DAT-01. Hàm chỉ SINH câu lệnh tham số hoá.

const NGAY = 24 * 60 * 60 * 1000;
export const LUU_SU_KIEN_MS = 180 * NGAY;
export const LUU_IP_CHI_TIET_MS = 90 * NGAY;

export type CauLenh = { sql: string; thamSo: (string | number | null)[] };

/**
 * - xoá idempotency_keys hết hạn;
 * - xoá security_events quá 180 ngày (bản tổng hợp 13 tháng ở Analytics Engine - S5);
 * - IP chi tiết quá 90 ngày của thiết bị KHÔNG có enforcement nào -> đánh dấu để Worker rút gọn (cần băm ở JS).
 */
export function cauLenhDonDep(bayGio: number): CauLenh[] {
  return [
    { sql: 'DELETE FROM idempotency_keys WHERE het_han <= ?', thamSo: [bayGio] },
    { sql: 'DELETE FROM security_events WHERE ts < ?', thamSo: [bayGio - LUU_SU_KIEN_MS] },
  ];
}

/** Câu chọn IP cần rút gọn (giới hạn lô để không vượt thời gian CPU của cron). */
export function cauChonIpCanRutGon(bayGio: number, lo = 500): CauLenh {
  return {
    sql:
      'SELECT device_id, ip, asn, country, first_seen, last_seen, count FROM device_ips WHERE ip_masked = 0 AND last_seen < ? AND device_id NOT IN ' +
      "(SELECT target_value FROM enforcements WHERE target_type = 'device') LIMIT ?",
    thamSo: [bayGio - LUU_IP_CHI_TIET_MS, lo],
  };
}

export type DongIp = {
  device_id: string;
  ip: string;
  asn: number | null;
  country: string | null;
  first_seen: number;
  last_seen: number;
  count: number;
};

/**
 * Câu lệnh rút gọn MỘT dòng IP: gộp vào dòng của dải đã rút gọn (cộng count, giữ first/last_seen rộng nhất) rồi xoá
 * dòng chi tiết. [ipRutGon] tính bằng `rutGonIp` (che-pii.ts).
 */
export function cauLenhRutGonIp(d: DongIp, ipRutGon: string): CauLenh[] {
  return [
    {
      sql:
        'INSERT INTO device_ips (device_id, ip, asn, country, first_seen, last_seen, count, ip_masked) ' +
        'VALUES (?, ?, ?, ?, ?, ?, ?, 1) ON CONFLICT (device_id, ip) DO UPDATE SET ' +
        'count = device_ips.count + excluded.count, first_seen = min(device_ips.first_seen, excluded.first_seen), ' +
        'last_seen = max(device_ips.last_seen, excluded.last_seen), ip_masked = 1',
      thamSo: [d.device_id, ipRutGon, d.asn, d.country, d.first_seen, d.last_seen, d.count],
    },
    { sql: 'DELETE FROM device_ips WHERE device_id = ? AND ip = ? AND ip_masked = 0', thamSo: [d.device_id, d.ip] },
  ];
}
