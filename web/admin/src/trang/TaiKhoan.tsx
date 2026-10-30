// Tài khoản và bảo mật (S7a): quyền, phiên hiện tại, passkey của chính mình (thêm / đổi tên / xoá - xoá cần step-up, server
// không cho xoá passkey cuối), tuỳ chọn hiển thị (giao diện, mật độ, độ đậm thuỷ vân, che khi rời cửa sổ), thử Telegram.
import { useState } from 'react';
import { dangKyPasskey, goi, goiStepUp, LoiSoc, maLoiPasskey, xacThucPasskey, type Passkey } from '../api';
import { HopThoai } from '../giao-dien/HopThoai';
import { useThongBao } from '../giao-dien/ThongBao';
import { ThongBaoLoi, useTai } from '../dung-chung';
import { dinhDangLuc, truocDay } from '../i18n';
import { useSoc } from '../ngu-canh';

const TEN_ALG: Record<number, string> = { [-7]: 'ES256', [-8]: 'EdDSA', [-257]: 'RS256' };

export function TaiKhoan() {
  const { t, nn, toi, coQuyen, tuyChon, doiTuyChon } = useSoc();
  const bao = useThongBao();
  const ds = useTai<{ ds: Passkey[] }>('/passkey');
  const [sua, datSua] = useState<Passkey | null>(null);
  const [xoa, datXoa] = useState<Passkey | null>(null);
  const [ban, datBan] = useState(false);

  const loiPasskey = (e: unknown) => {
    const ma = e instanceof LoiSoc ? e.ma : null;
    bao(ma === 'passkey-cuoi' ? t.passkeyCuoi : maLoiPasskey(e) === 'huy' ? t.passkeyHuy : t.loiChung, 'loi');
  };

  const them = async () => {
    datBan(true);
    try {
      try {
        await dangKyPasskey();
      } catch (e) {
        if (!(e instanceof LoiSoc && e.ma === 'can-step-up')) throw e;
        bao(t.canStepUp, 'tin');
        await xacThucPasskey();
        await dangKyPasskey();
      }
      bao(t.daLuu);
      ds.napLai();
    } catch (e) {
      loiPasskey(e);
    } finally {
      datBan(false);
    }
  };

  const doiTen = async (pk: Passkey, ten: string) => {
    try {
      await goi('/passkey/doi-ten', { body: { id: pk.id, ten } });
      bao(t.daLuu);
      datSua(null);
      ds.napLai();
    } catch (e) {
      loiPasskey(e);
    }
  };

  const xoaPk = async (pk: Passkey) => {
    datBan(true);
    try {
      await goiStepUp('/passkey/xoa', { id: pk.id }, () => bao(t.canStepUp, 'tin'));
      bao(t.daXoa);
      datXoa(null);
      ds.napLai();
    } catch (e) {
      loiPasskey(e);
    } finally {
      datBan(false);
    }
  };

  const thuTelegram = async () => {
    datBan(true);
    try {
      await goiStepUp('/canh-bao/thu-telegram', {}, () => bao(t.canStepUp, 'tin'));
      bao(t.telegramOk);
    } catch (e) {
      const ma = e instanceof LoiSoc ? e.ma : null;
      bao(ma === 'chua-cau-hinh-telegram' ? t.telegramChuaCauHinh : ma === 'telegram-loi' ? t.telegramLoi : maLoiPasskey(e) === 'huy' ? t.passkeyHuy : t.loiChung, 'loi');
    } finally {
      datBan(false);
    }
  };

  return (
    <div className="luoi-chi-tiet">
      <section className="the">
        <h2>{t.phienHienTai}</h2>
        <dl className="dl">
          <dt>{t.email}</dt>
          <dd>{toi.email}</dd>
          <dt>{t.vaiTroNhan}</dt>
          <dd>{t.vaiTro[toi.vaiTro] ?? toi.vaiTro}</dd>
          <dt>{t.phienHetLuc}</dt>
          <dd>{dinhDangLuc(toi.phien?.het, nn)}</dd>
          <dt>{t.stepUpLuc}</dt>
          <dd>{dinhDangLuc(toi.phien?.stepUpLuc, nn)}</dd>
        </dl>
        <h3 className="tieu-de-phu">{t.quyenCuaToi}</h3>
        <ul className="ds-the">
          {toi.quyen.map((q) => (
            <li key={q} className="nhan-phu ma">
              {q}
            </li>
          ))}
        </ul>
      </section>

      <section className="the rong-2">
        <div className="tieu-de-the">
          <h2>{t.passkeyCuaToi}</h2>
          <button type="button" className="nut nut-chinh" onClick={() => void them()} disabled={ban} aria-busy={ban}>
            {t.themPasskey}
          </button>
        </div>
        {ds.loi ? (
          <ThongBaoLoi loi={ds.loi} napLai={ds.napLai} />
        ) : (
          <div className="cuon-ngang">
            <table className="bang">
              <thead>
                <tr>
                  <th>{t.tenPasskey}</th>
                  <th>Alg</th>
                  <th>{t.taoLuc}</th>
                  <th>{t.dungCuoi}</th>
                  <th>
                    <span className="an-nhan">{t.hanhDong}</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {(ds.duLieu?.ds ?? []).map((pk) => (
                  <tr key={pk.id}>
                    <td>
                      {pk.name ?? <span className="o-so-phu">{t.chuaDatTen}</span>} <span className="ma o-so-phu">{pk.id.slice(0, 8)}</span>
                    </td>
                    <td>{TEN_ALG[pk.alg] ?? pk.alg}</td>
                    <td>{dinhDangLuc(pk.created_at, nn)}</td>
                    <td title={dinhDangLuc(pk.last_used, nn)}>{truocDay(pk.last_used, nn)}</td>
                    <td>
                      <div className="hang-nut trai">
                        <button type="button" className="nut nut-phu" onClick={() => datSua(pk)}>
                          {t.doiTen}
                        </button>
                        <button type="button" className="nut nut-nguy" onClick={() => datXoa(pk)} disabled={(ds.duLieu?.ds.length ?? 0) <= 1} title={(ds.duLieu?.ds.length ?? 0) <= 1 ? t.passkeyCuoi : undefined}>
                          {t.xoa}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="the rong-2">
        <h2>{t.hienThi}</h2>
        <div className="luoi-tuy-chon">
          <fieldset className="nhom-chon">
            <legend>{t.giaoDienNhan}</legend>
            {(
              [
                ['', t.theoHeThong],
                ['light', t.giaoDienSang],
                ['dark', t.giaoDienToi],
              ] as const
            ).map(([v, nhan]) => (
              <label key={v} className="hang">
                <input type="radio" name="chuDe" checked={(tuyChon.chuDe ?? '') === v} onChange={() => doiTuyChon({ chuDe: v === '' ? null : v })} />
                <span>{nhan}</span>
              </label>
            ))}
          </fieldset>
          <fieldset className="nhom-chon">
            <legend>{t.matDo}</legend>
            {(
              [
                ['thoang', t.matDoThoang],
                ['gon', t.matDoGon],
              ] as const
            ).map(([v, nhan]) => (
              <label key={v} className="hang">
                <input type="radio" name="matDo" checked={tuyChon.matDo === v} onChange={() => doiTuyChon({ matDo: v })} />
                <span>{nhan}</span>
              </label>
            ))}
          </fieldset>
          <fieldset className="nhom-chon">
            <legend>{t.thuyVan}</legend>
            {(
              [
                ['nhe', t.thuyVanNhe],
                ['chuan', t.thuyVanChuan],
              ] as const
            ).map(([v, nhan]) => (
              <label key={v} className="hang">
                <input type="radio" name="thuyVan" checked={tuyChon.thuyVan === v} onChange={() => doiTuyChon({ thuyVan: v })} />
                <span>{nhan}</span>
              </label>
            ))}
            <label className="hang">
              <input type="checkbox" checked={tuyChon.cheKhiRoi} onChange={(e) => doiTuyChon({ cheKhiRoi: e.target.checked })} />
              <span>{t.cheKhiRoi}</span>
            </label>
            <p className="o-so-phu">{t.thuyVanMoTa}</p>
          </fieldset>
        </div>
      </section>

      {coQuyen('quan-tri-vien') && (
        <section className="the">
          <h2>{t.kenhCanhBao}</h2>
          <button type="button" className="nut" onClick={() => void thuTelegram()} disabled={ban} aria-busy={ban}>
            {t.thuTelegram}
          </button>
        </section>
      )}

      <HopThoai mo={sua !== null} tieuDe={t.doiTen} dong={() => datSua(null)}>
        {sua && (
          <form
            className="bo-loc doc"
            onSubmit={(e) => {
              e.preventDefault();
              const ten = String(new FormData(e.currentTarget).get('ten') ?? '').trim();
              if (ten) void doiTen(sua, ten);
            }}
          >
            <label>
              <span>{t.tenPasskey}</span>
              <input name="ten" defaultValue={sua.name ?? ''} maxLength={40} required autoComplete="off" />
            </label>
            <div className="hang-nut">
              <button type="button" className="nut nut-phu" onClick={() => datSua(null)}>
                {t.huy}
              </button>
              <button type="submit" className="nut nut-chinh">
                {t.luu}
              </button>
            </div>
          </form>
        )}
      </HopThoai>

      <HopThoai mo={xoa !== null} tieuDe={t.xoa} dong={() => datXoa(null)}>
        {xoa && (
          <>
            <p>{t.xacNhanXoaPasskey}</p>
            <p className="ma o-so-phu">
              {xoa.name ?? t.chuaDatTen} · {xoa.id.slice(0, 16)}
            </p>
            <div className="hang-nut">
              <button type="button" className="nut nut-phu" onClick={() => datXoa(null)}>
                {t.huy}
              </button>
              <button type="button" className="nut nut-nguy" onClick={() => void xoaPk(xoa)} disabled={ban} aria-busy={ban}>
                {t.xoa}
              </button>
            </div>
          </>
        )}
      </HopThoai>
    </div>
  );
}
