// Khiếu nại (S7c1, Spec §8.2-6): khiếu nại từ form landing (mã REF + Turnstile) kèm thiết bị + chặn bị khiếu nại. Chấp
// nhận = gỡ mọi chặn thiết bị + điểm rủi ro về 0; từ chối giữ nguyên. Mọi quyết định cần lý do + passkey (server kiểm).
import { useCallback, useEffect, useState } from 'react';
import { goi, LoiSoc, type DsKhieuNai, type KhieuNai as DongKhieuNai } from '../api';
import { useThongBao } from '../giao-dien/ThongBao';
import { NhanTrangThai, ThongBaoLoi, useGhi } from '../dung-chung';
import { dinhDangLuc, dinhDangSo, truocDay } from '../i18n';
import { useSoc } from '../ngu-canh';
import { HopThoaiLyDo } from './Luat';

const TRANG_THAI = ['open', 'approved', 'rejected', 'tat-ca'] as const;

export function KhieuNai({ doiDem }: { doiDem: () => void }) {
  const { t, nn, coQuyen } = useSoc();
  const bao = useThongBao();
  const ghi = useGhi();
  const xuLy = coQuyen('khieu-nai:xu-ly');
  const [tt, datTt] = useState<(typeof TRANG_THAI)[number]>('open');
  const [ds, datDs] = useState<DongKhieuNai[]>([]);
  const [tiep, datTiep] = useState<string | null>(null);
  const [dem, datDem] = useState<Record<string, number>>({});
  const [loi, datLoi] = useState<LoiSoc | null>(null);
  const [tai, datTai] = useState(false);
  const [lanNap, datLanNap] = useState(0);
  const [hop, datHop] = useState<{ kn: DongKhieuNai; quyet: 'chap-nhan' | 'tu-choi' } | null>(null);

  const nap = useCallback(
    async (cursor: string | null) => {
      datTai(true);
      const q = new URLSearchParams({ trangThai: tt });
      if (cursor) q.set('cursor', cursor);
      try {
        const d = await goi<DsKhieuNai>(`/khieu-nai?${q.toString()}`);
        datDs((cu) => (cursor ? [...cu, ...d.ds] : d.ds));
        datTiep(d.tiepTheo);
        datDem(d.dem);
        datLoi(null);
      } catch (e) {
        datLoi(e instanceof LoiSoc ? e : new LoiSoc(0, null));
      } finally {
        datTai(false);
      }
    },
    [tt],
  );
  useEffect(() => void nap(null), [nap, lanNap]);

  return (
    <div className="trang-chinh">
      <div className="hang-o-dem">
        {TRANG_THAI.map((k) => (
          <button key={k} type="button" className="o-dem" aria-pressed={tt === k} onClick={() => datTt(k)}>
            <span className="o-so-nhan">{t.ttKhieuNai[k]}</span>
            <span className="o-so-gia-tri">
              {dinhDangSo(k === 'tat-ca' ? Object.values(dem).reduce((a, n) => a + n, 0) : (dem[k] ?? 0), nn)}
            </span>
          </button>
        ))}
      </div>
      {!xuLy && <p className="ghi-chu-vai-tro">{t.knChiXem}</p>}
      {loi && <ThongBaoLoi loi={loi} napLai={() => datLanNap((n) => n + 1)} />}

      <div className="ds-khieu-nai" aria-busy={tai}>
        {ds.length === 0 && !tai && <p className="trong">{t.knTrong}</p>}
        {ds.map((k) => (
          <article key={k.id} className="the the-khieu-nai">
            <header className="tieu-de-the">
              <h2>
                <span className="ma">{k.ref}</span>
              </h2>
              <span className={`trang-thai tkn-${k.status}`}>{t.ttKhieuNai[k.status]}</span>
            </header>
            <p className="o-so-phu" title={dinhDangLuc(k.ts, nn)}>
              {truocDay(k.ts, nn)} · {k.lang ? (t.knNgonNgu[k.lang] ?? k.lang) : '-'} · {t.knLienHe}: {k.contact ?? t.knKhongLienHe}
            </p>
            <blockquote className="kn-noi-dung">{k.message}</blockquote>
            <dl className="kn-thong-tin">
              <div>
                <dt>{t.thietBi}</dt>
                <dd>
                  <a className="ma" href={`#/thiet-bi/${k.device_id}`}>
                    {k.model ?? k.device_id}
                  </a>{' '}
                  <NhanTrangThai tt={k.device_status} />
                </dd>
              </div>
              <div>
                <dt>{t.knDiem}</dt>
                <dd>{dinhDangSo(k.risk_score, nn)}</dd>
              </div>
              <div>
                <dt>{t.knChanGoc}</dt>
                <dd>
                  {k.e_action ? (
                    <>
                      {t.tenHanhDongChan[k.e_action] ?? k.e_action} · {k.e_source === 'auto' ? t.nguonTuDong : t.nguonThuCong} · {k.e_reason}
                      {k.e_created_at !== null && <span className="o-so-phu"> · {truocDay(k.e_created_at, nn)}</span>}
                    </>
                  ) : (
                    t.knKhongChan
                  )}
                </dd>
              </div>
              {k.reviewed_by && (
                <div>
                  <dt>{t.knXuLyBoi}</dt>
                  <dd>
                    {k.reviewed_by}
                    {k.reviewed_at !== null && <span className="o-so-phu"> · {dinhDangLuc(k.reviewed_at, nn)}</span>}
                    {k.decision_note && <span className="o-so-phu"> · {k.decision_note}</span>}
                  </dd>
                </div>
              )}
            </dl>
            {xuLy && k.status === 'open' && (
              <div className="hang-nut trai">
                <button type="button" className="nut nut-chinh" onClick={() => datHop({ kn: k, quyet: 'chap-nhan' })}>
                  {t.knChapNhan}
                </button>
                <button type="button" className="nut nut-phu" onClick={() => datHop({ kn: k, quyet: 'tu-choi' })}>
                  {t.knTuChoi}
                </button>
              </div>
            )}
          </article>
        ))}
      </div>
      {tiep && (
        <button type="button" className="nut nut-phu" disabled={tai} onClick={() => void nap(tiep)}>
          {t.taiThemNut}
        </button>
      )}

      <HopThoaiLyDo
        mo={hop !== null}
        tieuDe={hop?.quyet === 'chap-nhan' ? t.knChapNhanTieuDe : t.knTuChoiTieuDe}
        canhBao={hop?.quyet === 'chap-nhan' ? t.knChapNhanCanhBao : null}
        nhanXacNhan={hop?.quyet === 'chap-nhan' ? t.knChapNhan : t.knTuChoi}
        dong={() => datHop(null)}
        xong={async (ghiChu) => {
          if (!hop) return;
          const kq = await ghi<{ goChan: number; trangThaiThietBi: string | null }>('/khieu-nai/quyet', { id: hop.kn.id, quyet: hop.quyet, ghiChu });
          if (!kq) return;
          bao(hop.quyet === 'chap-nhan' ? t.knDaChapNhan(kq.goChan, t.trangThai[kq.trangThaiThietBi ?? ''] ?? '-') : t.knDaTuChoi);
          datHop(null);
          datLanNap((n) => n + 1);
          doiDem();
        }}
      />
    </div>
  );
}
