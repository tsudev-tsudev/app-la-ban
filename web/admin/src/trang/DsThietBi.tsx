// Danh sách thiết bị (Spec §8.2 mục 2): bộ lọc nâng cao + bảng ẢO HOÁ (chỉ dựng dòng đang thấy) + tải tiếp theo cursor
// khi cuộn gần cuối. Bộ lọc nằm trên URL hash để chia sẻ / quay lại được.
import { useCallback, useEffect, useMemo, useRef, useState, type FormEvent } from 'react';
import { goi, LoiSoc, type DongThietBi } from '../api';
import { NhanTrangThai, ThongBaoLoi } from '../dung-chung';
import { laGoiPro } from '../giao-dien/goi-app';
import { dinhDangLuc } from '../i18n';
import { useSoc } from '../ngu-canh';

const CAO_DONG = 44;
const DU_TREN_DUOI = 8;
const KHOA_LOC = ['trangThai', 'ungDung', 'q', 'ip', 'asn', 'phienBan', 'suKien', 'sap'] as const;
type Loc = Partial<Record<(typeof KHOA_LOC)[number], string>>;

function docLocTuHash(): Loc {
  const q = new URLSearchParams(location.hash.split('?')[1] ?? '');
  const loc: Loc = {};
  for (const k of KHOA_LOC) {
    const v = q.get(k);
    if (v) loc[k] = v;
  }
  return loc;
}

function chuoiLoc(loc: Loc): string {
  const q = new URLSearchParams();
  for (const k of KHOA_LOC) if (loc[k]) q.set(k, loc[k] as string);
  return q.toString();
}

export function DsThietBi() {
  const { t, nn, hetPhien, coQuyen } = useSoc();
  const [loc, datLoc] = useState<Loc>(docLocTuHash);
  const [ds, datDs] = useState<DongThietBi[]>([]);
  const [tiep, datTiep] = useState<string | null>(null);
  const [ms, datMs] = useState(0);
  const [tai, datTai] = useState(false);
  const [loi, datLoi] = useState<LoiSoc | null>(null);
  const [cuon, datCuon] = useState(0);
  const [caoKhung, datCaoKhung] = useState(600);
  const khung = useRef<HTMLDivElement>(null);
  const dangTai = useRef(false);
  const xemChiTiet = coQuyen('thiet-bi:chi-tiet');

  const taiTrang = useCallback(
    async (cursor: string | null, dau: boolean) => {
      if (dangTai.current) return;
      dangTai.current = true;
      datTai(true);
      try {
        const q = chuoiLoc(loc);
        const kq = await goi<{ ds: DongThietBi[]; tiepTheo: string | null; ms: number }>(
          `/thiet-bi?${q}${q ? '&' : ''}limit=100${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`,
        );
        datDs((cu) => (dau ? kq.ds : [...cu, ...kq.ds]));
        datTiep(kq.tiepTheo);
        datMs(kq.ms);
        datLoi(null);
      } catch (e) {
        const l = e instanceof LoiSoc ? e : new LoiSoc(0, null);
        if (l.status === 401) hetPhien();
        datLoi(l);
      } finally {
        dangTai.current = false;
        datTai(false);
      }
    },
    [loc, hetPhien],
  );

  useEffect(() => {
    khung.current?.scrollTo({ top: 0 });
    datCuon(0);
    void taiTrang(null, true);
  }, [taiTrang]);

  useEffect(() => {
    const el = khung.current;
    if (!el) return;
    const ro = new ResizeObserver(() => datCaoKhung(el.clientHeight));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const onCuon = () => {
    const el = khung.current;
    if (!el) return;
    datCuon(el.scrollTop);
    if (tiep && el.scrollTop + el.clientHeight > el.scrollHeight - CAO_DONG * 20) void taiTrang(tiep, false);
  };

  const dau = Math.max(0, Math.floor(cuon / CAO_DONG) - DU_TREN_DUOI);
  const cuoi = Math.min(ds.length, Math.ceil((cuon + caoKhung) / CAO_DONG) + DU_TREN_DUOI);
  const hien = useMemo(() => ds.slice(dau, cuoi), [ds, dau, cuoi]);

  const guiLoc = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const moi: Loc = {};
    for (const k of KHOA_LOC) {
      const v = String(f.get(k) ?? '').trim();
      if (v) moi[k] = v;
    }
    history.replaceState(null, '', `#/thiet-bi${chuoiLoc(moi) ? `?${chuoiLoc(moi)}` : ''}`);
    datLoc(moi);
  };
  const xoaLoc = () => {
    history.replaceState(null, '', '#/thiet-bi');
    datLoc({});
  };

  const cot = t.cot;
  return (
    <div className="trang-ds">
      <form className="bo-loc" onSubmit={guiLoc} key={chuoiLoc(loc)}>
        <label>
          <span>{t.locTrangThai}</span>
          <select name="trangThai" defaultValue={loc.trangThai ?? ''}>
            <option value="">{t.tatCa}</option>
            {['clean', 'suspicious', 'restricted', 'banned'].map((k) => (
              <option key={k} value={k}>
                {t.trangThai[k]}
              </option>
            ))}
          </select>
        </label>
        <label>
          <span>{t.locUngDung}</span>
          <select name="ungDung" defaultValue={loc.ungDung ?? ''}>
            <option value="">{t.tatCa}</option>
            {['mien-phi', 'pro'].map((k) => (
              <option key={k} value={k}>
                {t.ungDung[k]}
              </option>
            ))}
          </select>
        </label>
        <label>
          <span>{t.timId}</span>
          <input name="q" defaultValue={loc.q ?? ''} pattern="[0-9A-Za-z\-]{2,36}" autoComplete="off" spellCheck={false} />
        </label>
        <label>
          <span>{t.locIp}</span>
          <input name="ip" defaultValue={loc.ip ?? ''} maxLength={64} autoComplete="off" spellCheck={false} />
        </label>
        <label>
          <span>{t.locAsn}</span>
          <input name="asn" defaultValue={loc.asn ?? ''} inputMode="numeric" pattern="\d{1,10}" />
        </label>
        <label>
          <span>{t.locPhienBan}</span>
          <input name="phienBan" defaultValue={loc.phienBan ?? ''} maxLength={32} />
        </label>
        <label>
          <span>{t.locSuKien}</span>
          <input name="suKien" defaultValue={loc.suKien ?? ''} pattern="[A-Z][A-Z0-9_]{1,40}" placeholder="ROOT_DETECTED" />
        </label>
        <label>
          <span>{t.sapXep}</span>
          <select name="sap" defaultValue={loc.sap ?? ''}>
            <option value="">{t.moiNhat}</option>
            <option value="rui-ro">{t.ruiRo}</option>
          </select>
        </label>
        <div className="bo-loc-nut">
          <button type="submit" className="nut nut-chinh">
            {t.apDung}
          </button>
          <button type="button" className="nut nut-phu" onClick={xoaLoc}>
            {t.xoaLoc}
          </button>
        </div>
      </form>

      {loi && <ThongBaoLoi loi={loi} napLai={() => void taiTrang(null, true)} />}
      <p className="o-so-phu" aria-live="polite">
        {t.soDong(ds.length, ms)} {!xemChiTiet && `· ${t.chiTietCanQuyen}`}
      </p>

      <div className="bang-ao" role="table" aria-rowcount={ds.length + 1}>
        <div className="bang-ao-dau" role="row">
          {[cot.id, cot.mau, cot.os, cot.app, cot.ip, cot.asn, cot.quocGia, cot.mucTin, cot.diem, cot.trangThai, cot.cuoi].map((c) => (
            <span key={c} role="columnheader">
              {c}
            </span>
          ))}
        </div>
        <div className="bang-ao-than" ref={khung} onScroll={onCuon} tabIndex={0}>
          <div style={{ blockSize: `${ds.length * CAO_DONG}px` }} className="bang-ao-dem">
            {hien.map((d, i) => (
              <div
                key={d.id}
                role="row"
                aria-rowindex={dau + i + 2}
                className="bang-ao-dong"
                style={{ transform: `translateY(${(dau + i) * CAO_DONG}px)` }}
              >
                <span role="cell" className="ma">
                  {xemChiTiet ? <a href={`#/thiet-bi/${d.id}`}>{d.id.slice(0, 12)}</a> : d.id.slice(0, 12)}
                </span>
                <span role="cell">{d.model ?? '-'}</span>
                <span role="cell">
                  {d.platform} {d.os_version ?? ''}
                </span>
                <span role="cell">
                  {d.app_version ?? '-'} / {d.build ?? '-'}
                  {laGoiPro(d.package_name) && <span className="nhan-phu nhan-pro">{t.ungDung.pro}</span>}
                </span>
                <span role="cell" className="ma">
                  {d.ip ?? '-'}
                </span>
                <span role="cell">{d.asn ?? '-'}</span>
                <span role="cell">{d.country ?? '-'}</span>
                <span role="cell">{d.attestation_level}</span>
                <span role="cell" className="so">
                  {d.risk_score}
                </span>
                <span role="cell">
                  <NhanTrangThai tt={d.status} />
                </span>
                <span role="cell">{dinhDangLuc(d.last_seen, nn)}</span>
              </div>
            ))}
          </div>
        </div>
        <p className="o-so-phu chan-bang">{tai ? t.taiThem : tiep ? '' : t.hetDuLieu}</p>
      </div>
    </div>
  );
}
