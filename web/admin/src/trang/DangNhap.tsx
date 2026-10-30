// Màn passkey: tạo passkey lần đầu hoặc xác thực mở phiên (MFA bắt buộc, Spec §8.1).
import { useState, type ReactNode } from 'react';
import { dangKyPasskey, hoTroPasskey, maLoiPasskey, xacThucPasskey, type Toi } from '../api';
import type { ChuoiSoc } from '../i18n';

export function DangNhap({ t, toi, khoa, xong, congCu }: { t: ChuoiSoc; toi: Toi; khoa: boolean; xong: () => void; congCu: ReactNode }) {
  const [ban, datBan] = useState(false);
  const [loi, datLoi] = useState<string | null>(null);
  const dangKy = toi.soPasskey === 0;

  const lam = async () => {
    datBan(true);
    datLoi(null);
    try {
      if (dangKy) {
        const het = await dangKyPasskey();
        if (het === null) await xacThucPasskey();
      } else {
        await xacThucPasskey();
      }
      xong();
    } catch (e) {
      datLoi(maLoiPasskey(e) === 'huy' ? t.passkeyHuy : t.passkeyLoi);
    } finally {
      datBan(false);
    }
  };

  return (
    <main className="giua the-don">
      <img src="/favicon.svg" alt="" width="56" height="56" />
      <h1>{dangKy ? t.dangKyTieuDe : t.xacThucTieuDe}</h1>
      {khoa && <p className="ghi-chu">{t.hetPhien}</p>}
      <p>{dangKy ? t.dangKyMoTa : t.xacThucMoTa}</p>
      <p className="email">{toi.email}</p>
      {hoTroPasskey() ? (
        <button type="button" className="nut nut-chinh" onClick={() => void lam()} disabled={ban} aria-busy={ban}>
          {dangKy ? t.dangKy : t.dangNhap}
        </button>
      ) : (
        <p role="alert">{t.khongHoTroPasskey}</p>
      )}
      {loi && (
        <p role="alert" className="loi">
          {loi}
        </p>
      )}
      {congCu}
    </main>
  );
}
