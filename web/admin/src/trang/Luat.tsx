// Rule UI (S7b, Spec §7.6d + §8.2): danh sách rule (chế độ, số lần kích hoạt 7 ngày, ngày được bật active), ngăn chỉnh
// sửa có mô phỏng 7 ngày trên sự kiện thật trước khi lưu, chuyển chế độ shadow / active / tắt, lịch sử phiên bản. Server
// kiểm lại mọi thứ (quyền, step-up, 7 ngày shadow, phiên bản) - giao diện chỉ hướng dẫn và chặn nhầm sớm.
import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { goi, LoiSoc, type ChiTietLuat, type DieuKienLuat, type KetQuaMoPhong, type Luat as KieuLuat, type ThanLuat } from '../api';
import { HopThoai } from '../giao-dien/HopThoai';
import { ThanhXepHang, ThongBaoLoi, useGhi, useTai } from '../dung-chung';
import { dinhDangLuc, dinhDangSo, truocDay } from '../i18n';
import { useSoc } from '../ngu-canh';

const HANH_DONG_CO_DINH = ['alert_low', 'alert_medium', 'alert_high', 'alert_critical', 'restrict_device', 'ban_device', 'block_ip', 'propose_cidr_block'] as const;
const MAU_SU_KIEN = /^[A-Z][A-Z0-9_]{2,47}$/;

/** Giây -> "10 phút" / "1 ngày" gọn theo đơn vị lớn nhất chia hết. */
export function dinhDangCuaSo(giay: number, nn: 'vi' | 'en'): string {
  const dv: [number, Intl.NumberFormatOptions['unit']][] = [
    [86_400, 'day'],
    [3600, 'hour'],
    [60, 'minute'],
  ];
  for (const [s, u] of dv) {
    if (giay % s === 0) return new Intl.NumberFormat(nn === 'en' ? 'en' : 'vi', { style: 'unit', unit: u, unitDisplay: 'long' }).format(giay / s);
  }
  return new Intl.NumberFormat(nn === 'en' ? 'en' : 'vi', { style: 'unit', unit: 'second', unitDisplay: 'long' }).format(giay);
}

/** Chuỗi "A, B c" -> danh sách mã sự kiện hợp lệ (chữ hoa, không trùng) + phần sai để báo. */
export function tachSuKien(s: string): { ds: string[]; sai: string[] } {
  const phan = s
    .split(/[\s,;]+/)
    .map((x) => x.trim().toUpperCase())
    .filter(Boolean);
  const ds = [...new Set(phan.filter((x) => MAU_SU_KIEN.test(x)))];
  return { ds, sai: phan.filter((x) => !MAU_SU_KIEN.test(x)) };
}

function NhanCheDo({ l }: { l: KieuLuat }) {
  const { t } = useSoc();
  if (!l.bat) return <span className="trang-thai cd-tat">{t.cheDoLuat.tat}</span>;
  return <span className={`trang-thai cd-${l.cheDo}`}>{t.cheDoLuat[l.cheDo]}</span>;
}

export function Luat({ moId }: { moId: string | null }) {
  const { t, nn } = useSoc();
  const ds = useTai<{ ds: KieuLuat[] }>('/luat');
  const mo = (id: string | null) => {
    location.hash = id ? `#/luat/${id}` : '#/luat';
  };
  return (
    <div className={moId ? 'trang-co-ngan mo rong' : 'trang-co-ngan'}>
      <div className="trang-chinh">
        <p className="mo-ta-trang">{t.luatMoTa}</p>
        {ds.loi && <ThongBaoLoi loi={ds.loi} napLai={ds.napLai} />}
        <div className="bang-khung" aria-busy={ds.tai}>
          <table className="bang">
            <thead>
              <tr>
                <th>{t.cotLuat.id}</th>
                <th>{t.cotLuat.ten}</th>
                <th>{t.cotLuat.cheDo}</th>
                <th>{t.cotLuat.dieuKien}</th>
                <th className="so">{t.cotLuat.kichHoat}</th>
                <th>{t.cotLuat.cuoi}</th>
              </tr>
            </thead>
            <tbody>
              {(ds.duLieu?.ds ?? []).map((l) => (
                <tr key={l.id} className={l.id === moId ? 'dang-chon' : !l.bat ? 'mo' : undefined}>
                  <td>
                    <button type="button" className="nut-chu ma" onClick={() => mo(l.id)}>
                      <strong>{l.id}</strong>
                    </button>
                    <span className="o-so-phu"> v{l.phienBan}</span>
                  </td>
                  <td>
                    {l.ten}
                    {l.hong && <span className="nhan-phu nhan-loi">{t.luatHong}</span>}
                  </td>
                  <td>
                    <NhanCheDo l={l} />
                    {l.bat && l.cheDo === 'shadow' && l.batDuocLuc !== null && (
                      <span className="o-so-phu" title={dinhDangLuc(l.batDuocLuc, nn)}>
                        {' '}
                        {l.coTheBat ? t.duocBatActive : t.batDuocTu(truocDay(l.batDuocLuc, nn))}
                      </span>
                    )}
                  </td>
                  <td className="o-dieu-kien">
                    {l.dieuKien ? (
                      <>
                        <span className="ma">{l.dieuKien.event.join(', ')}</span>
                        <span className="o-so-phu">{t.tomTatDieuKien(t.nhomTheo[l.dieuKien.group_by] ?? l.dieuKien.group_by, t.demTheo[l.dieuKien.count] ?? l.dieuKien.count, l.nguong, dinhDangCuaSo(l.cuaSo, nn))}</span>
                      </>
                    ) : (
                      '-'
                    )}
                  </td>
                  <td className="so">
                    {dinhDangSo(l.kichHoat7n?.that ?? 0, nn)}
                    <span className="o-so-phu"> / {t.shadowSo(dinhDangSo(l.kichHoat7n?.shadow ?? 0, nn))}</span>
                  </td>
                  <td title={dinhDangLuc(l.kichHoat7n?.cuoi, nn)}>{truocDay(l.kichHoat7n?.cuoi, nn)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      {moId && <NganLuat key={moId} id={moId} dong={() => mo(null)} xong={() => ds.napLai()} />}
    </div>
  );
}

function NganLuat({ id, dong, xong }: { id: string; dong: () => void; xong: () => void }) {
  const { t, nn, coQuyen } = useSoc();
  const ct = useTai<ChiTietLuat>(`/luat/${id}`);
  const ghi = useGhi();
  const suaDuoc = coQuyen('luat:sua');
  const [ban, datBan] = useState(false);
  const [mp, datMp] = useState<KetQuaMoPhong | null>(null);
  const [loiForm, datLoiForm] = useState<string | null>(null);
  const [hopCheDo, datHopCheDo] = useState<'active' | 'shadow' | 'tat' | null>(null);
  const l = ct.duLieu?.luat;

  useEffect(() => {
    const nghe = (e: KeyboardEvent) => e.key === 'Escape' && !document.querySelector('dialog[open]') && dong();
    addEventListener('keydown', nghe);
    return () => removeEventListener('keydown', nghe);
  }, [dong]);

  const docForm = (f: HTMLFormElement): ThanLuat | null => {
    const d = new FormData(f);
    const sk = tachSuKien(String(d.get('event') ?? ''));
    if (sk.ds.length === 0 || sk.sai.length > 0) {
      datLoiForm(t.suKienSai(sk.sai.join(', ')));
      return null;
    }
    const hanhDong = d.getAll('hanhDong').map(String);
    const diem = Number(d.get('addRisk') ?? 0);
    if (diem > 0) hanhDong.push(`add_risk_${Math.min(999, Math.floor(diem))}`);
    if (hanhDong.length === 0) {
      datLoiForm(t.canHanhDong);
      return null;
    }
    datLoiForm(null);
    return {
      ten: String(d.get('ten') ?? '').trim(),
      dieuKien: { event: sk.ds, group_by: String(d.get('groupBy')) as DieuKienLuat['group_by'], count: String(d.get('count')) as DieuKienLuat['count'] },
      cuaSo: Math.round(Number(d.get('cuaSo')) * Number(d.get('donVi'))),
      nguong: Number(d.get('nguong')),
      hanhDong,
    };
  };

  const moPhong = async (f: HTMLFormElement | null) => {
    if (!f) return;
    const than = docForm(f);
    if (!than) return;
    datBan(true);
    try {
      datMp(await goi<KetQuaMoPhong>('/luat/mo-phong', { body: { id, than } }));
    } catch (e) {
      datLoiForm(e instanceof LoiSoc && e.status === 422 ? t.loiMa['sai-du-lieu'] ?? t.loiChung : t.loiChung);
    } finally {
      datBan(false);
    }
  };

  const luu = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!l) return;
    const than = docForm(e.currentTarget);
    if (!than) return;
    datBan(true);
    const kq = await ghi<{ phienBan: number; veShadow: boolean }>('/luat/sua', { id, phienBan: l.phienBan, than, ghiChu: String(new FormData(e.currentTarget).get('ghiChu') ?? '').trim() });
    datBan(false);
    if (kq) {
      datMp(null);
      ct.napLai();
      xong();
    }
  };

  const donVi = l ? (l.cuaSo % 86_400 === 0 ? 86_400 : l.cuaSo % 3600 === 0 ? 3600 : 60) : 60;
  const hanhDongCo = new Set(l?.hanhDong ?? []);
  const diemCong = l?.hanhDong.map((h) => /^add_risk_(\d+)$/.exec(h)?.[1]).find(Boolean) ?? '';
  const lonNhat = useMemo(() => Math.max(1, ...(mp?.theoNgay.map((x) => x.n) ?? [1])), [mp]);

  return (
    <aside className="ngan-chi-tiet" aria-label={t.luatChiTiet(id)}>
      <div className="ngan-dau">
        <h2>
          <span className="ma">{id}</span> {l?.ten}
        </h2>
        <button type="button" className="nut-bieu-tuong" onClick={dong} aria-label={t.dongChiTiet}>
          ×
        </button>
      </div>
      {ct.loi && <ThongBaoLoi loi={ct.loi} napLai={ct.napLai} />}
      {l && (
        <div className="ngan-than">
          <section className="ngan-muc">
            <div className="hang-tom-tat">
              <NhanCheDo l={l} />
              <span className="o-so-phu">v{l.phienBan}</span>
              {l.suaBoi && <span className="o-so-phu">{t.suaBoi(l.suaBoi)}</span>}
            </div>
            {suaDuoc ? (
              <div className="hang-nut trai">
                <button type="button" className="nut nut-chinh" disabled={!l.coTheBat || (l.bat && l.cheDo === 'active')} title={l.coTheBat ? undefined : t.chuaDuShadow(dinhDangLuc(l.batDuocLuc, nn))} onClick={() => datHopCheDo('active')}>
                  {t.batActive}
                </button>
                <button type="button" className="nut" disabled={l.bat && l.cheDo === 'shadow'} onClick={() => datHopCheDo('shadow')}>
                  {t.veShadow}
                </button>
                <button type="button" className="nut nut-nguy" disabled={!l.bat} onClick={() => datHopCheDo('tat')}>
                  {t.tatLuat}
                </button>
              </div>
            ) : (
              <p className="ghi-chu-vai-tro">{t.chiXemLuat}</p>
            )}
          </section>

          <form className="ngan-muc bo-loc doc form-luat" onSubmit={(e) => void luu(e)} onInput={() => datMp(null)}>
            <h3>{t.dinhNghiaLuat}</h3>
            <label>
              <span>{t.cotLuat.ten}</span>
              <input name="ten" defaultValue={l.ten} required minLength={3} maxLength={120} disabled={!suaDuoc} />
            </label>
            <label>
              <span>{t.suKienXet}</span>
              <input name="event" defaultValue={l.dieuKien?.event.join(', ') ?? ''} required className="ma" spellCheck={false} autoComplete="off" disabled={!suaDuoc} />
            </label>
            <div className="luoi-2">
              <label>
                <span>{t.nhomTheoNhan}</span>
                <select name="groupBy" defaultValue={l.dieuKien?.group_by ?? 'device'} disabled={!suaDuoc}>
                  {Object.entries(t.nhomTheo).map(([k, v]) => (
                    <option key={k} value={k}>
                      {v}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                <span>{t.demTheoNhan}</span>
                <select name="count" defaultValue={l.dieuKien?.count ?? 'events'} disabled={!suaDuoc}>
                  {Object.entries(t.demTheo).map(([k, v]) => (
                    <option key={k} value={k}>
                      {v}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                <span>{t.nguongNhan}</span>
                <input name="nguong" type="number" min={1} max={100000} defaultValue={l.nguong} required disabled={!suaDuoc} />
              </label>
              <div className="hang-o">
                <label>
                  <span>{t.cuaSoNhan}</span>
                  <input name="cuaSo" type="number" min={1} max={43200} defaultValue={l.cuaSo / donVi} required disabled={!suaDuoc} />
                </label>
                <label>
                  <span className="an-nhan">{t.donViNhan}</span>
                  <select name="donVi" defaultValue={donVi} disabled={!suaDuoc} aria-label={t.donViNhan}>
                    <option value={60}>{t.donVi.phut}</option>
                    <option value={3600}>{t.donVi.gio}</option>
                    <option value={86400}>{t.donVi.ngay}</option>
                  </select>
                </label>
              </div>
            </div>
            <fieldset className="nhom-chon luoi-chon">
              <legend>{t.hanhDongLuat}</legend>
              {HANH_DONG_CO_DINH.map((h) => (
                <label key={h} className="hang">
                  <input type="checkbox" name="hanhDong" value={h} defaultChecked={hanhDongCo.has(h)} disabled={!suaDuoc} />
                  <span>{t.tenHanhDong[h] ?? h}</span>
                </label>
              ))}
              <label className="hang">
                <span>{t.congDiemRuiRo}</span>
                <input name="addRisk" type="number" min={0} max={999} defaultValue={diemCong} className="o-ngan" disabled={!suaDuoc} />
              </label>
            </fieldset>
            {loiForm && (
              <p role="alert" className="loi-chu">
                {loiForm}
              </p>
            )}
            <p className="o-so-phu">{t.goiYShadow}</p>
            {suaDuoc && (
              <label>
                <span>{t.lyDoThayDoi}</span>
                <textarea name="ghiChu" rows={2} minLength={10} maxLength={500} required placeholder={t.lyDoGoiY} />
              </label>
            )}
            <div className="hang-nut trai">
              <button type="button" className="nut" disabled={ban} onClick={(e) => void moPhong(e.currentTarget.form)}>
                {t.moPhong7n}
              </button>
              {suaDuoc && (
                <button type="submit" className="nut nut-chinh" disabled={ban} aria-busy={ban}>
                  {t.luuPhienBan}
                </button>
              )}
            </div>
          </form>

          {mp && (
            <section className="ngan-muc ket-qua-mo-phong" aria-live="polite">
              <h3>{t.ketQuaMoPhong}</h3>
              <div className="hang-o-dem">
                <div className="o-so">
                  <span className="o-so-nhan">{t.mpLanKichHoat}</span>
                  <span className="o-so-gia-tri">{dinhDangSo(mp.soLanKichHoat, nn)}</span>
                  {mp.hienTai && <span className="o-so-phu">{t.mpHienTai(dinhDangSo((mp.hienTai.that ?? 0) + (mp.hienTai.shadow ?? 0), nn))}</span>}
                </div>
                <div className="o-so">
                  <span className="o-so-nhan">{t.mpSoNhom}</span>
                  <span className="o-so-gia-tri">{dinhDangSo(mp.soNhom, nn)}</span>
                </div>
                <div className="o-so">
                  <span className="o-so-nhan">{t.mpSuKien}</span>
                  <span className="o-so-gia-tri">{dinhDangSo(mp.soSuKien, nn)}</span>
                  <span className="o-so-phu">{t.mpMs(mp.ms)}</span>
                </div>
              </div>
              {mp.catBot && <p className="ghi-chu-vai-tro">{t.mpCatBot}</p>}
              <ol className="cot-ngay" aria-label={t.mpTheoNgay}>
                {mp.theoNgay.map((x) => {
                  const nhan = new Intl.DateTimeFormat(nn === 'en' ? 'en-GB' : 'vi-VN', { timeZone: 'Asia/Ho_Chi_Minh', day: '2-digit', month: '2-digit' }).format(x.ngay);
                  return (
                    <li key={x.ngay} title={`${nhan}: ${dinhDangSo(x.n, nn)}`}>
                      <span className="cot-ngay-thanh" style={{ blockSize: `${(x.n / lonNhat) * 100}%` }} />
                      <span className="cot-ngay-so">{x.n}</span>
                      <span className="cot-ngay-nhan">{nhan}</span>
                    </li>
                  );
                })}
              </ol>
              <h4>{t.mpTopNhom}</h4>
              <ThanhXepHang ds={mp.topNhom.map((x) => ({ k: x.khoa, n: x.n }))} />
            </section>
          )}

          <section className="ngan-muc">
            <h3>{t.lichSuPhienBan}</h3>
            <ol className="dong-tg">
              {ct.duLieu?.phienBan.map((p) => (
                <li key={p.version}>
                  <span className="dtg-chu">
                    <strong>v{p.version}</strong> · {p.created_by} · {dinhDangLuc(p.created_at, nn)}
                  </span>
                  {p.note && <span>{p.note}</span>}
                  <span className="o-so-phu ma">
                    {p.condition?.event.join(', ')} · {p.threshold} / {dinhDangCuaSo(p.window, nn)} · {(p.action ?? []).join(', ')}
                  </span>
                </li>
              ))}
            </ol>
          </section>

          <section className="ngan-muc">
            <h3>{t.lanKichHoatGanDay}</h3>
            {(ct.duLieu?.lanKichHoat.length ?? 0) === 0 ? (
              <p className="trong">{t.khongCo}</p>
            ) : (
              <ul className="ds-gon">
                {ct.duLieu?.lanKichHoat.map((k, i) => (
                  <li key={`${k.ts}-${i}`}>
                    <span title={dinhDangLuc(k.ts, nn)}>{truocDay(k.ts, nn)}</span> <span className="ma">{k.group_key}</span> <span className="o-so-phu">v{k.rule_version}</span>
                    {k.shadow ? <span className="nhan-phu">{t.shadow}</span> : null}
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      )}
      <HopThoaiLyDo
        mo={hopCheDo !== null}
        tieuDe={hopCheDo ? t.doiCheDoTieuDe(t.cheDoLuat[hopCheDo] ?? hopCheDo) : ''}
        canhBao={hopCheDo === 'active' ? t.canhBaoActive : null}
        dong={() => datHopCheDo(null)}
        xong={async (ghiChu) => {
          if (!l || !hopCheDo) return;
          const kq = await ghi('/luat/che-do', { id, phienBan: l.phienBan, cheDo: hopCheDo, ghiChu });
          if (kq) {
            datHopCheDo(null);
            ct.napLai();
            xong();
          }
        }}
      />
    </aside>
  );
}

/** Hộp thoại hỏi lý do (>= 10 ký tự) trước thao tác nhạy cảm; dùng chung cho các trang S7b. */
export function HopThoaiLyDo({
  mo,
  tieuDe,
  canhBao,
  dong,
  xong,
  nhanXacNhan,
}: {
  mo: boolean;
  tieuDe: string;
  canhBao?: string | null;
  dong: () => void;
  xong: (lyDo: string) => Promise<unknown>;
  nhanXacNhan?: string;
}) {
  const { t } = useSoc();
  const [ban, datBan] = useState(false);
  return (
    <HopThoai mo={mo} tieuDe={tieuDe} dong={dong}>
      <form
        className="bo-loc doc"
        onSubmit={(e) => {
          e.preventDefault();
          datBan(true);
          void xong(String(new FormData(e.currentTarget).get('lyDo') ?? '').trim()).finally(() => datBan(false));
        }}
      >
        {canhBao && <p className="canh-bao-chu">{canhBao}</p>}
        <label>
          <span>{t.lyDoBatBuoc}</span>
          <textarea name="lyDo" rows={3} minLength={10} maxLength={500} required placeholder={t.lyDoGoiY} />
        </label>
        <p className="o-so-phu">{t.canPasskeyGhiChu}</p>
        <div className="hang-nut">
          <button type="button" className="nut nut-phu" onClick={dong}>
            {t.huy}
          </button>
          <button type="submit" className="nut nut-chinh" disabled={ban} aria-busy={ban}>
            {nhanXacNhan ?? t.xacNhan}
          </button>
        </div>
      </form>
    </HopThoai>
  );
}
