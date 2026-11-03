// S11 (QUYET_DINH Q57) - chặn chế độ Nhà phát triển: hàm thuần. App báo trạng thái sống của Developer options / ADB qua
// tham số `pt` của GET /v1/status (đã ký); Worker lưu devices.dev_mode_at và là nơi quyết định chặn route nghiệp vụ.

/** `pt` = '1' (đang bật) / '0' (đã tắt); thiếu hoặc lạ (app cũ) -> giữ nguyên. Trả giá trị mới + có cần ghi D1 không. */
export function capNhatPhatTrien(cu: number | null, pt: string | undefined, bayGio: number): { moi: number | null; doi: boolean } {
  if (pt === '1') return cu === null ? { moi: bayGio, doi: true } : { moi: cu, doi: false };
  if (pt === '0') return { moi: null, doi: cu !== null };
  return { moi: cu, doi: false };
}

/** Prod bật chặn (`CHAN_DEV_MODE=1`) + thiết bị đang báo bật -> chặn. Staging / dev chỉ ghi nhận. */
export function biChanPhatTrien(chanBat: string | undefined, devModeAt: number | null | undefined): boolean {
  return chanBat === '1' && devModeAt !== null && devModeAt !== undefined;
}
