// Quản trị viên SOC (Super Admin): danh sách + thêm / đổi vai trò / vô hiệu hoá. Server bắt step-up passkey; gặp
// `can-step-up` thì hỏi passkey rồi gửi lại đúng một lần.
import { useState, type FormEvent } from 'react';
import { goi, LoiSoc, maLoiPasskey, xacThucPasskey } from '../api';
import { ThongBaoLoi, useTai } from '../dung-chung';
import { dinhDangLuc } from '../i18n';
import { useSoc } from '../ngu-canh';

type Qt = { email: string; role: string; mfa_enrolled: number; last_login: number | null; disabled_at: number | null; so_passkey: number };
const VAI_TRO = ['viewer', 'analyst', 'responder', 'security_admin', 'super_admin'];

export function QuanTriVien() {
  const { t, nn, toi } = useSoc();
  const ds = useTai<{ ds: Qt[] }>('/quan-tri-vien');
  const [tb, datTb] = useState<{ loai: 'ok' | 'loi'; noiDung: string } | null>(null);
  const [ban, datBan] = useState(false);

  const gui = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const body = { email: String(f.get('email') ?? '').trim(), vaiTro: String(f.get('vaiTro')), voHieu: f.get('voHieu') === 'on' };
    datBan(true);
    datTb(null);
    try {
      try {
        await goi('/quan-tri-vien', { body });
      } catch (loi) {
        if (!(loi instanceof LoiSoc && loi.ma === 'can-step-up')) throw loi;
        datTb({ loai: 'ok', noiDung: t.canStepUp });
        await xacThucPasskey();
        await goi('/quan-tri-vien', { body });
      }
      datTb({ loai: 'ok', noiDung: t.daLuu });
      ds.napLai();
    } catch (loi) {
      const ma = loi instanceof LoiSoc ? loi.ma : null;
      datTb({ loai: 'loi', noiDung: ma === 'khong-tu-sua' ? t.khongTuSua : maLoiPasskey(loi) === 'huy' ? t.passkeyHuy : t.loiChung });
    } finally {
      datBan(false);
    }
  };

  return (
    <div className="luoi-chi-tiet">
      <section className="the">
        <h2>{t.themQt}</h2>
        <form className="bo-loc doc" onSubmit={(e) => void gui(e)}>
          <label>
            <span>{t.email}</span>
            <input name="email" type="email" required maxLength={254} autoComplete="off" />
          </label>
          <label>
            <span>{t.vaiTroNhan}</span>
            <select name="vaiTro" defaultValue="viewer">
              {VAI_TRO.map((v) => (
                <option key={v} value={v}>
                  {t.vaiTro[v]}
                </option>
              ))}
            </select>
          </label>
          <label className="hang">
            <input name="voHieu" type="checkbox" />
            <span>{t.voHieu}</span>
          </label>
          <button type="submit" className="nut nut-chinh" disabled={ban} aria-busy={ban}>
            {t.luu}
          </button>
          {tb && (
            <p role={tb.loai === 'loi' ? 'alert' : 'status'} className={tb.loai === 'loi' ? 'loi' : 'ghi-chu'}>
              {tb.noiDung}
            </p>
          )}
          <p className="o-so-phu">{t.ghiChuAccess}</p>
        </form>
      </section>
      <section className="the rong-2">
        <h2>{t.quanTriVien}</h2>
        {ds.loi ? (
          <ThongBaoLoi loi={ds.loi} napLai={ds.napLai} />
        ) : (
          <div className="cuon-ngang">
            <table className="bang">
              <thead>
                <tr>
                  <th>{t.email}</th>
                  <th>{t.vaiTroNhan}</th>
                  <th>MFA</th>
                  <th>{t.dangNhapCuoi}</th>
                </tr>
              </thead>
              <tbody>
                {(ds.duLieu?.ds ?? []).map((q) => (
                  <tr key={q.email} className={q.disabled_at ? 'mo' : undefined}>
                    <td>
                      {q.email}
                      {q.email === toi.email ? ' ★' : ''}
                    </td>
                    <td>
                      {t.vaiTro[q.role] ?? q.role}
                      {q.disabled_at ? <span className="nhan-phu"> {t.daVoHieu}</span> : null}
                    </td>
                    <td>{t.passkeyN(q.so_passkey)}</td>
                    <td>{dinhDangLuc(q.last_login, nn)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
