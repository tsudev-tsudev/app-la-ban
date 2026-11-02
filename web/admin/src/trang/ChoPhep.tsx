// Allow-list (R2 - miễn trừ thiết bị duyệt store / IP văn phòng): xem (analyst), thêm / gỡ (Security Admin, lý do + passkey,
// có hạn tối đa 90 ngày). Đích khớp không bị Threat Engine cấm tự động và không bị chặn IP ở edge.
import { useState } from 'react';
import { useThongBao } from '../giao-dien/ThongBao';
import { ThongBaoLoi, useGhi, useTai } from '../dung-chung';
import { dinhDangLuc, truocDay } from '../i18n';
import { useSoc } from '../ngu-canh';
import { HopThoaiLyDo } from './Luat';

type Dong = { id: string; target_type: string; target_value: string; reason: string; created_by: string; created_at: number; expires_at: number | null; hieuLuc: boolean };
const LOAI = ['asn', 'ip', 'cidr', 'device'] as const;
const HAN = ['24h', '7d', '30d', '90d'] as const;

export function ChoPhep() {
  const { t, nn, coQuyen } = useSoc();
  const bao = useThongBao();
  const ghi = useGhi();
  const sua = coQuyen('cho-phep');
  const { duLieu: d, loi, napLai } = useTai<{ ds: Dong[]; asnGoogle: string[] }>('/cho-phep');
  const [loai, datLoai] = useState<(typeof LOAI)[number]>('asn');
  const [giaTri, datGiaTri] = useState('');
  const [han, datHan] = useState<(typeof HAN)[number]>('7d');
  const [them, datThem] = useState<{ loai: string; giaTri: string }[] | null>(null);
  const [go, datGo] = useState<Dong | null>(null);

  return (
    <section className="the" id="cho-phep">
      <div className="tieu-de-the">
        <h2>{t.cpTieuDe}</h2>
        <span className="o-so-phu">{t.cpMoTa}</span>
      </div>
      {loi && <ThongBaoLoi loi={loi} napLai={napLai} />}
      {d && d.ds.length === 0 && <p className="trong">{t.cpTrong}</p>}
      {d && d.ds.length > 0 && (
        <div className="cuon-ngang">
          <table className="bang">
            <thead>
              <tr>
                <th scope="col">{t.cpDich}</th>
                <th scope="col">{t.cotTt.lyDo}</th>
                <th scope="col">{t.cpTaoBoi}</th>
                <th scope="col">{t.cpHet}</th>
                {sua && <th scope="col">{t.cpThaoTac}</th>}
              </tr>
            </thead>
            <tbody>
              {d.ds.map((x) => (
                <tr key={x.id}>
                  <td className="ma">
                    {x.target_type}:{x.target_value}
                  </td>
                  <td>{x.reason}</td>
                  <td>
                    {x.created_by} <span className="o-so-phu">· {truocDay(x.created_at, nn)}</span>
                  </td>
                  <td title={dinhDangLuc(x.expires_at, nn)}>{x.expires_at ? truocDay(x.expires_at, nn) : '-'}</td>
                  {sua && (
                    <td>
                      <button type="button" className="nut nut-phu" onClick={() => datGo(x)}>
                        {t.cpGo}
                      </button>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {sua && d && (
        <form
          className="bo-loc"
          onSubmit={(e) => {
            e.preventDefault();
            if (giaTri.trim()) datThem([{ loai, giaTri: giaTri.trim() }]);
          }}
        >
          <label>
            <span>{t.cpLoai}</span>
            <select value={loai} onChange={(e) => datLoai(e.target.value as (typeof LOAI)[number])}>
              {LOAI.map((l) => (
                <option key={l} value={l}>
                  {l}
                </option>
              ))}
            </select>
          </label>
          <label>
            <span>{t.cpGiaTri}</span>
            <input value={giaTri} maxLength={64} onChange={(e) => datGiaTri(e.target.value)} placeholder={loai === 'asn' ? 'AS15169' : ''} />
          </label>
          <label>
            <span>{t.cpHan}</span>
            <select value={han} onChange={(e) => datHan(e.target.value as (typeof HAN)[number])}>
              {HAN.map((h) => (
                <option key={h} value={h}>
                  {t.cpTenHan[h]}
                </option>
              ))}
            </select>
          </label>
          <button type="submit" className="nut nut-chinh" disabled={!giaTri.trim()}>
            {t.cpThem}
          </button>
          <button type="button" className="nut nut-phu" onClick={() => datThem(d.asnGoogle.map((a) => ({ loai: 'asn', giaTri: a })))}>
            {t.cpGoogle}
          </button>
        </form>
      )}
      <HopThoaiLyDo
        mo={them !== null}
        tieuDe={t.cpThem}
        canhBao={t.cpCanhBao(them?.map((x) => `${x.loai}:${x.giaTri}`).join(', ') ?? '', t.cpTenHan[han] ?? han)}
        nhanXacNhan={t.cpThem}
        dong={() => datThem(null)}
        xong={async (lyDo) => {
          if (!them) return;
          const kq = await ghi('/cho-phep/them', { dich: them, thoiHan: han, lyDo });
          if (!kq) return;
          bao(t.cpDaThem);
          datThem(null);
          datGiaTri('');
          napLai();
        }}
      />
      <HopThoaiLyDo
        mo={go !== null}
        tieuDe={t.cpGo}
        nhanXacNhan={t.cpGo}
        dong={() => datGo(null)}
        xong={async (lyDo) => {
          if (!go) return;
          const kq = await ghi('/cho-phep/go', { id: go.id, lyDo });
          if (!kq) return;
          bao(t.cpDaGo);
          datGo(null);
          napLai();
        }}
      />
    </section>
  );
}
