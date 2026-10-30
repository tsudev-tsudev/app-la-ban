// Nhật ký kiểm toán (S7c1, SEC-DATA DAT-02, chỉ Security Admin trở lên): xem chuỗi băm chỉ thêm (lọc người làm / tiền tố
// hành động, phân trang theo rowid) + kiểm lại toàn chuỗi ở server để phát hiện dòng bị sửa tay ngoài API.
import { Fragment, useCallback, useEffect, useState } from 'react';
import { goi, LoiSoc, type DongAudit, type KetQuaKiemAudit } from '../api';
import { ThongBaoLoi, useGhi } from '../dung-chung';
import { dinhDangLuc } from '../i18n';
import { useSoc } from '../ngu-canh';

function GiaTri({ v }: { v: unknown }) {
  if (v === null || v === undefined) return <span className="o-so-phu">-</span>;
  return <pre className="au-json">{JSON.stringify(v, null, 2)}</pre>;
}

export function NhatKyAudit() {
  const { t, nn } = useSoc();
  const ghi = useGhi();
  const [loc, datLoc] = useState<{ tacNhan: string; hanhDong: string }>({ tacNhan: '', hanhDong: '' });
  const [ds, datDs] = useState<DongAudit[]>([]);
  const [tiep, datTiep] = useState<string | null>(null);
  const [loi, datLoi] = useState<LoiSoc | null>(null);
  const [tai, datTai] = useState(false);
  const [lanNap, datLanNap] = useState(0);
  const [mo, datMo] = useState<number | null>(null);
  const [kiem, datKiem] = useState<KetQuaKiemAudit | 'dang' | null>(null);

  const nap = useCallback(
    async (truoc: string | null) => {
      datTai(true);
      const q = new URLSearchParams();
      if (loc.tacNhan) q.set('tacNhan', loc.tacNhan);
      if (loc.hanhDong) q.set('hanhDong', loc.hanhDong);
      if (truoc) q.set('truoc', truoc);
      try {
        const d = await goi<{ ds: DongAudit[]; tiepTheo: string | null }>(`/audit?${q.toString()}`);
        datDs((cu) => (truoc ? [...cu, ...d.ds] : d.ds));
        datTiep(d.tiepTheo);
        datLoi(null);
      } catch (e) {
        datLoi(e instanceof LoiSoc ? e : new LoiSoc(0, null));
      } finally {
        datTai(false);
      }
    },
    [loc],
  );
  useEffect(() => void nap(null), [nap, lanNap]);

  const kiemChuoi = async () => {
    datKiem('dang');
    const kq = await ghi<KetQuaKiemAudit>('/audit/kiem', {});
    datKiem(kq);
    // Lượt kiểm cũng là một dòng audit mới -> tải lại để thấy.
    datLanNap((n) => n + 1);
  };

  return (
    <div className="trang-chinh">
      <section className="the">
        <p className="o-so-phu">{t.auMoTa}</p>
        <div className="hang-nut trai">
          <button type="button" className="nut nut-chinh" disabled={kiem === 'dang'} aria-busy={kiem === 'dang'} onClick={() => void kiemChuoi()}>
            {kiem === 'dang' ? t.auDangKiem : t.auKiem}
          </button>
        </div>
        {kiem && kiem !== 'dang' && (
          <p role="status" className={kiem.nguyenVen ? 'trang-thai tt-clean' : 'canh-bao-chu'}>
            {kiem.nguyenVen ? t.auNguyenVen(kiem.soDongDung, kiem.ms) : t.auHong(kiem.dongLoi?.so ?? 0, kiem.soDongDung)}
          </p>
        )}
      </section>

      <form
        className="bo-loc thanh-loc"
        role="search"
        onSubmit={(e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          datLoc({ tacNhan: String(f.get('tacNhan') ?? '').trim(), hanhDong: String(f.get('hanhDong') ?? '').trim() });
        }}
      >
        <label>
          <span>{t.auTacNhan}</span>
          <input name="tacNhan" type="email" data-o-tim="" defaultValue={loc.tacNhan} maxLength={254} autoComplete="off" spellCheck={false} />
        </label>
        <label>
          <span>{t.auHanhDong}</span>
          <input name="hanhDong" defaultValue={loc.hanhDong} maxLength={40} pattern="[a-z0-9:\-]{2,40}" autoComplete="off" spellCheck={false} placeholder="can-thiep" />
        </label>
        <div className="bo-loc-nut">
          <button type="submit" className="nut nut-phu">
            {t.apDung}
          </button>
        </div>
      </form>

      {loi && <ThongBaoLoi loi={loi} napLai={() => datLanNap((n) => n + 1)} />}
      <div className="bang-khung" aria-busy={tai}>
        <table className="bang">
          <thead>
            <tr>
              <th>{t.auCot.so}</th>
              <th>{t.auCot.luc}</th>
              <th>{t.auCot.tacNhan}</th>
              <th>{t.auCot.hanhDong}</th>
              <th>{t.auCot.doiTuong}</th>
              <th>{t.auCot.ip}</th>
              <th>{t.auCot.bam}</th>
            </tr>
          </thead>
          <tbody>
            {ds.map((d) => (
              <Fragment key={d.so}>
                <tr className={kiem && kiem !== 'dang' && kiem.dongLoi?.so === d.so ? 'dong-loi' : undefined}>
                  <td>
                    <button type="button" className="nut-chu" aria-expanded={mo === d.so} onClick={() => datMo(mo === d.so ? null : d.so)}>
                      {d.so}
                    </button>
                  </td>
                  <td title={dinhDangLuc(d.ts, nn)}>{dinhDangLuc(d.ts, nn)}</td>
                  <td className="o-nguoi">{d.actor}</td>
                  <td className="ma">{d.action}</td>
                  <td className="ma">{d.target ?? '-'}</td>
                  <td className="ma">{d.ip ?? '-'}</td>
                  <td className="ma" title={d.hash_self}>
                    {d.hash_self.slice(0, 10)}
                  </td>
                </tr>
                {mo === d.so && (
                  <tr className="dong-chi-tiet">
                    <td colSpan={7}>
                      <div className="au-chi-tiet">
                        <div>
                          <h3>{t.auTruoc}</h3>
                          <GiaTri v={d.before} />
                        </div>
                        <div>
                          <h3>{t.auSau}</h3>
                          <GiaTri v={d.after} />
                        </div>
                      </div>
                    </td>
                  </tr>
                )}
              </Fragment>
            ))}
          </tbody>
        </table>
      </div>
      {tiep && (
        <button type="button" className="nut nut-phu" disabled={tai} onClick={() => void nap(tiep)}>
          {t.taiThemNut}
        </button>
      )}
    </div>
  );
}
