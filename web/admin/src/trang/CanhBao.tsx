// Trung tâm cảnh báo (S7a, Spec §8.2 mục 3): ô đếm nhanh, bộ lọc trên URL hash, bảng chọn nhiều + thanh thao tác hàng loạt,
// bảng chi tiết trượt bên phải (rule, đối tượng, lần kích hoạt, dòng thời gian xử lý + ghi chú). Server kiểm quyền / trạng
// thái lần nữa - giao diện chỉ ẩn nút cho đỡ nhầm.
import { useCallback, useEffect, useMemo, useRef, useState, type FormEvent, type ReactNode } from 'react';
import { goi, LoiSoc, type CanhBao as DongCanhBao, type ChiTietCanhBao, type DemCanhBao, type DsCanhBao } from '../api';
import { BieuTuong } from '../giao-dien/BieuTuong';
import { HopThoai } from '../giao-dien/HopThoai';
import { useThongBao } from '../giao-dien/ThongBao';
import { MucDo, NhanTrangThai, ThongBaoLoi, useTai } from '../dung-chung';
import { dinhDangLuc, dinhDangSo, truocDay } from '../i18n';
import { useSoc } from '../ngu-canh';

const KHOA_LOC = ['trangThai', 'mucDo', 'rule', 'nguoi', 'shadow', 'q'] as const;
type Loc = Partial<Record<(typeof KHOA_LOC)[number], string>>;
type HanhDong = 'nhan' | 'ack' | 'dong' | 'mo-lai' | 'phan-cong' | 'ghi-chu';

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

function hashCanhBao(id: string | null, loc: Loc): string {
  const q = chuoiLoc(loc);
  return `#/canh-bao${id ? `/${id}` : ''}${q ? `?${q}` : ''}`;
}

/** Khoá nhóm -> liên kết trong SOC (thiết bị / danh sách thiết bị lọc theo IP hoặc dải). */
function LienKetNhom({ khoa }: { khoa: string }) {
  const { coQuyen } = useSoc();
  const i = khoa.indexOf(':');
  const loai = khoa.slice(0, i);
  const gt = khoa.slice(i + 1);
  if (loai === 'device' && coQuyen('thiet-bi:chi-tiet')) return <a className="ma" href={`#/thiet-bi/${gt}`}>{khoa}</a>;
  if ((loai === 'ip' || loai === 'cidr24') && !gt.includes('/48')) return <a className="ma" href={`#/thiet-bi?ip=${encodeURIComponent(gt)}`}>{khoa}</a>;
  return <span className="ma">{khoa}</span>;
}

function NhanCb({ tt }: { tt: string }) {
  const { t } = useSoc();
  return <span className={`trang-thai cb-${tt}`}>{t.ttCb[tt] ?? tt}</span>;
}

export function CanhBao({ moId }: { moId: string | null }) {
  const { t, nn, coQuyen, hetPhien } = useSoc();
  const bao = useThongBao();
  const xuLy = coQuyen('canh-bao:xu-ly');
  const [loc, datLoc] = useState<Loc>(docLocTuHash);
  const [ds, datDs] = useState<DongCanhBao[]>([]);
  const [dem, datDem] = useState<DemCanhBao>({});
  const [tiep, datTiep] = useState<string | null>(null);
  const [ms, datMs] = useState(0);
  const [tai, datTai] = useState(false);
  const [loi, datLoi] = useState<LoiSoc | null>(null);
  const [chon, datChon] = useState<Set<string>>(() => new Set());
  const [hop, datHop] = useState<null | 'dong' | 'phan-cong'>(null);
  const [lanNap, datLanNap] = useState(0);
  const daTaiThem = useRef(false);

  const nap = useCallback(
    async (cursor: string | null, nen = false) => {
      const q = new URLSearchParams(chuoiLoc(loc));
      if (cursor) q.set('cursor', cursor);
      q.set('limit', '50');
      if (!nen) datTai(true);
      try {
        const d = await goi<DsCanhBao>(`/canh-bao?${q}`, { nen });
        datDs((cu) => (cursor ? [...cu, ...d.ds] : d.ds));
        datTiep(d.tiepTheo);
        datDem(d.dem);
        datMs(d.ms);
        datLoi(null);
      } catch (e) {
        const l = e instanceof LoiSoc ? e : new LoiSoc(0, null);
        if (l.status === 401) hetPhien();
        datLoi(l);
      } finally {
        datTai(false);
      }
    },
    [loc, hetPhien],
  );

  useEffect(() => {
    daTaiThem.current = false;
    datChon(new Set());
    void nap(null);
  }, [nap, lanNap]);

  // Làm mới nền 30 giây (chỉ khi đang xem trang đầu - không xoá phần người dùng đã tải thêm).
  useEffect(() => {
    const hen = setInterval(() => {
      if (!daTaiThem.current && !document.hidden) void nap(null, true);
    }, 30_000);
    return () => clearInterval(hen);
  }, [nap]);

  const apLoc = (moi: Loc) => {
    const sach: Loc = {};
    for (const k of KHOA_LOC) if (moi[k]) sach[k] = moi[k];
    datLoc(sach);
    history.replaceState(null, '', hashCanhBao(moId, sach));
  };

  const guiLoc = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    apLoc({ ...loc, rule: String(f.get('rule') ?? '').trim(), q: String(f.get('q') ?? '').trim() });
  };

  const thaoTac = useCallback(
    async (ids: string[], hanhDong: HanhDong, them: Record<string, unknown> = {}): Promise<boolean> => {
      try {
        const kq = await goi<{ capNhat: number; boQua: number }>('/canh-bao/thao-tac', { body: { ids, hanhDong, ...them } });
        bao(t.ketQuaThaoTac(kq.capNhat, kq.boQua), kq.capNhat ? 'ok' : 'tin');
        datLanNap((n) => n + 1);
        return true;
      } catch (e) {
        const l = e instanceof LoiSoc ? e : null;
        if (l?.status === 401) hetPhien();
        bao(l?.ma === 'da-co-canh-bao-hoat-dong' ? t.daCoCbHoatDong : t.loiChung, 'loi');
        return false;
      }
    },
    [bao, t, hetPhien],
  );

  const moChiTiet = (id: string | null) => {
    location.hash = hashCanhBao(id, loc);
  };

  const dsChon = [...chon];
  const tatCaDaChon = ds.length > 0 && ds.every((a) => chon.has(a.id));
  const dongChon = (id: string, co: boolean) =>
    datChon((cu) => {
      const m = new Set(cu);
      if (co) m.add(id);
      else m.delete(id);
      return m;
    });

  const oDem: [string, number | null | undefined, Loc | null][] = [
    [t.demMo, dem.mo, { trangThai: 'open' }],
    [t.demAck, dem.ack, { trangThai: 'ack' }],
    [t.demChuaGiao, dem.chuaGiao, { nguoi: 'chua' }],
    [t.demCuaToi, dem.cuaToi, { nguoi: 'toi' }],
    [t.demCao, dem.cao, null],
  ];

  return (
    <div className={moId ? 'trang-co-ngan mo' : 'trang-co-ngan'}>
      <div className="trang-chinh">
        <section className="hang-o-dem" aria-label={t.tieuDeCanhBao}>
          {oDem.map(([nhan, so, locNhanh]) => {
            const noiDung = (
              <>
                <span className="o-so-nhan">{nhan}</span>
                <span className="o-so-gia-tri">{so === undefined || so === null ? '-' : dinhDangSo(so, nn)}</span>
              </>
            );
            return locNhanh ? (
              <button key={nhan} type="button" className="o-dem" onClick={() => apLoc(locNhanh)}>
                {noiDung}
              </button>
            ) : (
              <div key={nhan} className={so ? 'o-dem nong' : 'o-dem'}>
                {noiDung}
              </div>
            );
          })}
        </section>

        <form className="bo-loc thanh-loc" onSubmit={guiLoc} aria-label={t.apDung}>
          <label>
            <span>{t.locTrangThai}</span>
            <select value={loc.trangThai ?? 'hoat-dong'} onChange={(e) => apLoc({ ...loc, trangThai: e.target.value === 'hoat-dong' ? '' : e.target.value })}>
              {Object.entries(t.locTtCb).map(([k, v]) => (
                <option key={k} value={k}>
                  {v}
                </option>
              ))}
            </select>
          </label>
          <label>
            <span>{t.mucDoNhan}</span>
            <select value={loc.mucDo ?? ''} onChange={(e) => apLoc({ ...loc, mucDo: e.target.value })}>
              <option value="">{t.tatCa}</option>
              {['critical', 'high', 'medium', 'low'].map((m) => (
                <option key={m} value={m}>
                  {t.mucDo[m]}
                </option>
              ))}
            </select>
          </label>
          <label>
            <span>{t.locNguoi}</span>
            <select value={loc.nguoi && loc.nguoi !== 'toi' && loc.nguoi !== 'chua' ? '' : (loc.nguoi ?? '')} onChange={(e) => apLoc({ ...loc, nguoi: e.target.value })}>
              <option value="">{t.tatCa}</option>
              <option value="toi">{t.nguoiToi}</option>
              <option value="chua">{t.nguoiChua}</option>
            </select>
          </label>
          <label>
            <span>{t.locShadow}</span>
            <select value={loc.shadow ?? ''} onChange={(e) => apLoc({ ...loc, shadow: e.target.value })}>
              <option value="">{t.tatCa}</option>
              <option value="an">{t.shadowAn}</option>
              <option value="chi">{t.shadowChi}</option>
            </select>
          </label>
          <label>
            <span>{t.locRule}</span>
            <input name="rule" defaultValue={loc.rule ?? ''} key={`r${loc.rule ?? ''}`} placeholder="R-001" maxLength={40} autoComplete="off" />
          </label>
          <label>
            <span>{t.timNhom}</span>
            <input name="q" data-o-tim="" defaultValue={loc.q ?? ''} key={`q${loc.q ?? ''}`} maxLength={64} autoComplete="off" spellCheck={false} />
          </label>
          <div className="bo-loc-nut">
            <button type="submit" className="nut nut-chinh">
              {t.apDung}
            </button>
            <button type="button" className="nut nut-phu" onClick={() => apLoc({})} disabled={Object.keys(loc).length === 0}>
              {t.xoaLoc}
            </button>
          </div>
        </form>

        {!xuLy && <p className="ghi-chu-vai-tro">{t.chiXemCb}</p>}

        {xuLy && chon.size > 0 && (
          <div className="thanh-hang-loat" role="toolbar" aria-label={t.daChon(chon.size)}>
            <strong>{t.daChon(chon.size)}</strong>
            <button type="button" className="nut" onClick={() => void thaoTac(dsChon, 'nhan')}>
              {t.hdNhan}
            </button>
            <button type="button" className="nut" onClick={() => void thaoTac(dsChon, 'ack')}>
              {t.hdAck}
            </button>
            <button type="button" className="nut" onClick={() => datHop('phan-cong')}>
              {t.hdPhanCong}
            </button>
            <button type="button" className="nut" onClick={() => datHop('dong')}>
              {t.hdDong}
            </button>
            <button type="button" className="nut" onClick={() => void thaoTac(dsChon, 'mo-lai')}>
              {t.hdMoLai}
            </button>
            <button type="button" className="nut nut-phu" onClick={() => datChon(new Set())}>
              {t.boChon}
            </button>
          </div>
        )}

        {loi && <ThongBaoLoi loi={loi} napLai={() => datLanNap((n) => n + 1)} />}

        <div className="bang-khung" aria-busy={tai}>
          <table className="bang bang-cb">
            <thead>
              <tr>
                {xuLy && (
                  <th className="cot-chon">
                    <input type="checkbox" aria-label={t.chonTatCa} checked={tatCaDaChon} onChange={(e) => datChon(e.target.checked ? new Set(ds.map((a) => a.id)) : new Set())} />
                  </th>
                )}
                <th>{t.cotCb.muc}</th>
                <th>{t.cotCb.rule}</th>
                <th>{t.cotCb.nhom}</th>
                <th className="so">{t.cotCb.lan}</th>
                <th>{t.cotCb.trangThai}</th>
                <th>{t.cotCb.nguoi}</th>
                <th>{t.cotCb.cuoi}</th>
              </tr>
            </thead>
            <tbody>
              {ds.map((a) => (
                <tr key={a.id} className={a.id === moId ? 'dang-chon' : a.status === 'closed' ? 'mo' : undefined} aria-selected={chon.has(a.id)}>
                  {xuLy && (
                    <td className="cot-chon">
                      <input type="checkbox" aria-label={t.chonDong(a.id)} checked={chon.has(a.id)} onChange={(e) => dongChon(a.id, e.target.checked)} />
                    </td>
                  )}
                  <td>
                    <MucDo muc={a.severity} />
                  </td>
                  <td className="o-rule">
                    <button type="button" className="nut-chu" onClick={() => moChiTiet(a.id)}>
                      <strong>{a.rule_id}</strong> {a.rule_name}
                    </button>
                    {a.shadow ? <span className="nhan-phu">{t.shadow}</span> : null}
                  </td>
                  <td>
                    <LienKetNhom khoa={a.group_key} />
                  </td>
                  <td className="so">{dinhDangSo(a.count, nn)}</td>
                  <td>
                    <NhanCb tt={a.status} />
                    {a.resolution ? <span className="nhan-phu">{t.ketLuan[a.resolution] ?? a.resolution}</span> : null}
                  </td>
                  <td className="o-nguoi">{a.assignee ?? '-'}</td>
                  <td title={dinhDangLuc(a.last_ts, nn)}>{truocDay(a.last_ts, nn)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {!tai && ds.length === 0 && !loi && <p className="trong o-trong">{t.canhBaoTrong}</p>}
        </div>
        <div className="chan-bang">
          <span className="o-so-phu">{t.thuGon(ds.length, ms)}</span>
          {tiep && (
            <button
              type="button"
              className="nut nut-phu"
              disabled={tai}
              onClick={() => {
                daTaiThem.current = true;
                void nap(tiep);
              }}
            >
              {t.taiThemNut}
            </button>
          )}
        </div>
      </div>

      {moId && <NganChiTiet key={moId} id={moId} dong={() => moChiTiet(null)} thaoTac={thaoTac} lanNap={lanNap} />}

      <HopThoaiDong mo={hop === 'dong'} dong={() => datHop(null)} xong={async (kl, ghi) => (await thaoTac(dsChon, 'dong', { ketLuan: kl, ...(ghi ? { ghiChu: ghi } : {}) })) && datHop(null)} />
      <HopThoaiPhanCong mo={hop === 'phan-cong'} dong={() => datHop(null)} xong={async (nguoi) => (await thaoTac(dsChon, 'phan-cong', { nguoi })) && datHop(null)} />
    </div>
  );
}

function HopThoaiDong({ mo, dong, xong }: { mo: boolean; dong: () => void; xong: (ketLuan: string, ghiChu: string) => Promise<unknown> }) {
  const { t } = useSoc();
  const [ban, datBan] = useState(false);
  return (
    <HopThoai mo={mo} tieuDe={t.dongCanhBao} dong={dong}>
      <form
        className="bo-loc doc"
        onSubmit={(e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          datBan(true);
          void xong(String(f.get('ketLuan')), String(f.get('ghiChu') ?? '').trim()).finally(() => datBan(false));
        }}
      >
        <fieldset className="nhom-chon">
          <legend>{t.ketLuanNhan}</legend>
          {Object.entries(t.ketLuan).map(([k, v], i) => (
            <label key={k} className="hang">
              <input type="radio" name="ketLuan" value={k} required defaultChecked={i === 0} />
              <span>{v}</span>
            </label>
          ))}
        </fieldset>
        <label>
          <span>{t.ghiChuNhan}</span>
          <textarea name="ghiChu" rows={3} maxLength={2000} placeholder={t.ghiChuGoiY} />
        </label>
        <div className="hang-nut">
          <button type="button" className="nut nut-phu" onClick={dong}>
            {t.huy}
          </button>
          <button type="submit" className="nut nut-chinh" disabled={ban} aria-busy={ban}>
            {t.xacNhan}
          </button>
        </div>
      </form>
    </HopThoai>
  );
}

function HopThoaiPhanCong({ mo, dong, xong }: { mo: boolean; dong: () => void; xong: (nguoi: string | null) => Promise<unknown> }) {
  const { t, toi } = useSoc();
  const ds = useTai<{ ds: string[] }>(mo ? '/canh-bao/nguoi-xu-ly' : null);
  const [ban, datBan] = useState(false);
  return (
    <HopThoai mo={mo} tieuDe={t.phanCongCanhBao} dong={dong}>
      <form
        className="bo-loc doc"
        onSubmit={(e) => {
          e.preventDefault();
          const v = String(new FormData(e.currentTarget).get('nguoi') ?? '');
          datBan(true);
          void xong(v === '-' ? null : v).finally(() => datBan(false));
        }}
      >
        <label>
          <span>{t.nguoiXuLy}</span>
          <select name="nguoi" defaultValue={toi.email} key={ds.duLieu ? 'co' : 'chua'}>
            <option value="-">{t.boPhanCong}</option>
            {(ds.duLieu?.ds ?? [toi.email]).map((e) => (
              <option key={e} value={e}>
                {e}
              </option>
            ))}
          </select>
        </label>
        <div className="hang-nut">
          <button type="button" className="nut nut-phu" onClick={dong}>
            {t.huy}
          </button>
          <button type="submit" className="nut nut-chinh" disabled={ban} aria-busy={ban}>
            {t.xacNhan}
          </button>
        </div>
      </form>
    </HopThoai>
  );
}

function Dong({ nhan, children }: { nhan: string; children: ReactNode }) {
  return (
    <div className="dl-dong">
      <dt>{nhan}</dt>
      <dd>{children}</dd>
    </div>
  );
}

function NganChiTiet({
  id,
  dong,
  thaoTac,
  lanNap,
}: {
  id: string;
  dong: () => void;
  thaoTac: (ids: string[], hd: HanhDong, them?: Record<string, unknown>) => Promise<boolean>;
  lanNap: number;
}) {
  const { t, nn, coQuyen } = useSoc();
  const ct = useTai<ChiTietCanhBao>(`/canh-bao/${id}`);
  const { napLai } = ct;
  const xuLy = coQuyen('canh-bao:xu-ly');
  const [hop, datHop] = useState<null | 'dong' | 'phan-cong'>(null);
  const tieuDe = useRef<HTMLHeadingElement>(null);

  useEffect(() => {
    if (lanNap > 0) napLai(true);
  }, [lanNap, napLai]);
  useEffect(() => {
    tieuDe.current?.focus();
  }, []);
  useEffect(() => {
    const esc = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !document.querySelector('dialog[open]')) dong();
    };
    addEventListener('keydown', esc);
    return () => removeEventListener('keydown', esc);
  }, [dong]);

  const d = ct.duLieu;
  const a = d?.canhBao;
  const dongTg = useMemo(
    () =>
      (d?.dongThoiGian ?? []).map((g) => {
        if (g.kind === 'assign') return { ...g, chu: t.ghiPhanCong(g.body) };
        if (g.kind === 'status') {
          const [doi = '', kl = null] = g.body.split(':');
          const [tu = '', den = ''] = doi.split('>');
          return { ...g, chu: t.ghiTrangThai(t.ttCb[tu] ?? tu, t.ttCb[den] ?? den, kl ? (t.ketLuan[kl] ?? kl) : null) };
        }
        return { ...g, chu: g.body };
      }),
    [d, t],
  );

  return (
    <aside className="ngan-chi-tiet" aria-labelledby="tieu-de-cb">
      <div className="ngan-dau">
        <h2 id="tieu-de-cb" ref={tieuDe} tabIndex={-1}>
          {t.chiTietCb}
        </h2>
        <button type="button" className="nut-bieu-tuong" aria-label={t.dongChiTiet} onClick={dong}>
          <BieuTuong ten="dong" />
        </button>
      </div>
      {ct.loi && !d ? (
        <ThongBaoLoi loi={ct.loi} napLai={ct.napLai} />
      ) : !d || !a ? (
        <p>{t.dangTai}</p>
      ) : (
        <div className="ngan-than">
          <div className="ngan-tom-tat">
            <MucDo muc={a.severity} />
            <NhanCb tt={a.status} />
            {a.shadow ? <span className="nhan-phu">{t.shadow}</span> : null}
          </div>
          <p className="ngan-rule">
            <strong>{a.rule_id}</strong> {d.rule?.name}
          </p>

          {xuLy && (
            <div className="hang-nut trai">
              {a.status !== 'closed' && (
                <>
                  <button type="button" className="nut nut-chinh" onClick={() => void thaoTac([a.id], 'nhan')}>
                    {t.hdNhan}
                  </button>
                  {a.status === 'open' && (
                    <button type="button" className="nut" onClick={() => void thaoTac([a.id], 'ack')}>
                      {t.hdAck}
                    </button>
                  )}
                  <button type="button" className="nut" onClick={() => datHop('phan-cong')}>
                    {t.hdPhanCong}
                  </button>
                  <button type="button" className="nut" onClick={() => datHop('dong')}>
                    {t.hdDong}
                  </button>
                </>
              )}
              {a.status === 'closed' && (
                <button type="button" className="nut" onClick={() => void thaoTac([a.id], 'mo-lai')}>
                  {t.hdMoLai}
                </button>
              )}
            </div>
          )}

          <dl className="dl">
            <Dong nhan={t.doiTuong}>
              <LienKetNhom khoa={a.group_key} />
            </Dong>
            <Dong nhan={t.soLan}>{dinhDangSo(a.count, nn)}</Dong>
            <Dong nhan={t.lanDau}>{dinhDangLuc(a.first_ts, nn)}</Dong>
            <Dong nhan={t.lanCuoi}>{dinhDangLuc(a.last_ts, nn)}</Dong>
            <Dong nhan={t.nguoiXuLy}>{a.assignee ?? '-'}</Dong>
            <Dong nhan={t.ketLuanNhan}>{a.resolution ? (t.ketLuan[a.resolution] ?? a.resolution) : '-'}</Dong>
            {a.updated_by && (
              <Dong nhan={t.capNhatBoi}>
                {a.updated_by} · {truocDay(a.updated_at, nn)}
              </Dong>
            )}
            <Dong nhan={t.telegramNhan}>{!d.telegram ? t.telegramTat : a.notified_at ? t.daBao(dinhDangLuc(a.notified_at, nn)) : t.chuaBao}</Dong>
          </dl>

          {d.thietBi && (
            <section className="ngan-muc">
              <h3>{t.thietBiLienQuan}</h3>
              <p>
                <NhanTrangThai tt={d.thietBi.status} /> {t.ruiRoNhan} {d.thietBi.risk_score} · {d.thietBi.model ?? '?'} · {d.thietBi.app_version ?? '?'}
              </p>
              {coQuyen('thiet-bi:chi-tiet') && <a href={`#/thiet-bi/${d.thietBi.id}`}>{t.moThietBi}</a>}
            </section>
          )}

          {d.rule && (
            <section className="ngan-muc">
              <h3>{t.quyTac}</h3>
              <dl className="dl">
                <Dong nhan={t.cheDo}>
                  {d.rule.enabled ? t.dangBat : t.dangTat} · {t.phienBanRule(d.rule.version)}
                </Dong>
                <Dong nhan={t.cuaSo}>{Math.round(d.rule.window / 60_000)} min</Dong>
                <Dong nhan={t.nguong}>{d.rule.threshold}</Dong>
                <Dong nhan={t.hanhDong}>
                  <span className="ma">{d.rule.action}</span>
                </Dong>
              </dl>
              <details>
                <summary>{t.dieuKien}</summary>
                <pre className="json">{JSON.stringify(d.rule.condition, null, 2)}</pre>
              </details>
            </section>
          )}

          <section className="ngan-muc">
            <h3>{t.dongThoiGianXuLy}</h3>
            {xuLy && <FormGhiChu gui={(ghi) => thaoTac([a.id], 'ghi-chu', { ghiChu: ghi })} />}
            {dongTg.length === 0 ? (
              <p className="trong">{t.khongCo}</p>
            ) : (
              <ol className="dong-tg">
                {dongTg.map((g) => (
                  <li key={g.id} className={`dtg-${g.kind}`}>
                    <span className="dtg-chu">{g.chu}</span>
                    <span className="o-so-phu">
                      {g.actor} · <time title={dinhDangLuc(g.ts, nn)}>{truocDay(g.ts, nn)}</time>
                    </span>
                  </li>
                ))}
              </ol>
            )}
          </section>

          <section className="ngan-muc">
            <h3>{t.lanKichHoat}</h3>
            {d.lanKichHoat.length === 0 ? (
              <p className="trong">{t.khongCo}</p>
            ) : (
              <ul className="ds-gon">
                {d.lanKichHoat.map((l, i) => (
                  <li key={`${l.ts}-${i}`}>
                    <time>{dinhDangLuc(l.ts, nn)}</time>
                    <span className="o-so-phu">
                      v{l.rule_version}
                      {l.shadow ? ` · ${t.shadow}` : ''}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      )}
      {a && (
        <>
          <HopThoaiDong mo={hop === 'dong'} dong={() => datHop(null)} xong={async (kl, ghi) => (await thaoTac([a.id], 'dong', { ketLuan: kl, ...(ghi ? { ghiChu: ghi } : {}) })) && datHop(null)} />
          <HopThoaiPhanCong mo={hop === 'phan-cong'} dong={() => datHop(null)} xong={async (nguoi) => (await thaoTac([a.id], 'phan-cong', { nguoi })) && datHop(null)} />
        </>
      )}
    </aside>
  );
}

function FormGhiChu({ gui }: { gui: (ghiChu: string) => Promise<boolean> }) {
  const { t } = useSoc();
  const [ban, datBan] = useState(false);
  return (
    <form
      className="form-ghi-chu"
      onSubmit={(e) => {
        e.preventDefault();
        const f = e.currentTarget;
        const v = String(new FormData(f).get('ghiChu') ?? '').trim();
        if (!v) return;
        datBan(true);
        void gui(v)
          .then((ok) => ok && f.reset())
          .finally(() => datBan(false));
      }}
    >
      <textarea name="ghiChu" rows={2} maxLength={2000} placeholder={t.ghiChuGoiY} aria-label={t.ghiChuNhan} required />
      <button type="submit" className="nut" disabled={ban} aria-busy={ban}>
        {t.themGhiChu}
      </button>
    </form>
  );
}
