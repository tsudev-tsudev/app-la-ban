// Can thiệp (S7b, Spec §8.2-5): danh sách chặn (đang hiệu lực / chờ duyệt / đã hết) + lọc, chặn mới một hoặc nhiều đích
// (hàng loạt -> yêu cầu four-eyes), gỡ chặn, duyệt / bác đề xuất chặn dải, hàng đợi yêu cầu four-eyes. Mọi ghi cần lý do +
// passkey trong 5 phút; người tạo không tự duyệt (server + CHECK D1 chặn - nút ẩn chỉ để đỡ nhầm).
import { useCallback, useEffect, useState } from 'react';
import { goi, LoiSoc, type DsThucThi, type ThucThi, type YeuCauDuyet } from '../api';
import { HopThoai } from '../giao-dien/HopThoai';
import { useThongBao } from '../giao-dien/ThongBao';
import { ThongBaoLoi, useGhi, useTai } from '../dung-chung';
import { dinhDangLuc, dinhDangSo, truocDay } from '../i18n';
import { useSoc } from '../ngu-canh';
import { ChoPhep } from './ChoPhep';
import { HopThoaiLyDo } from './Luat';

type LoaiDich = 'device' | 'ip' | 'cidr' | 'asn';
const THOI_HAN = ['1h', '24h', '7d', '30d', '365d', 'leo-thang'] as const;

/** Mỗi dòng một đích; bỏ dòng trống và trùng. */
export function tachDich(s: string): string[] {
  return [
    ...new Set(
      s
        .split(/[\n,;]+/)
        .map((x) => x.trim())
        .filter(Boolean),
    ),
  ];
}

function NhanThucThi({ e }: { e: ThucThi }) {
  const { t } = useSoc();
  const bayGio = Date.now();
  const tt = e.revoked_at ? 'go' : e.expires_at <= bayGio ? 'het' : e.pending_approval && !e.approved_by ? 'cho' : 'hieu-luc';
  return <span className={`trang-thai tht-${tt}`}>{t.ttThucThi[tt]}</span>;
}

export function CanThiep() {
  const { t, nn, toi, coQuyen } = useSoc();
  const bao = useThongBao();
  const ghi = useGhi();
  const canThiep = coQuyen('can-thiep');
  const duyet = coQuyen('can-thiep:duyet');
  const [loc, datLoc] = useState<{ trangThai: string; loai: string; q: string }>({ trangThai: 'hieu-luc', loai: '', q: '' });
  const [ds, datDs] = useState<ThucThi[]>([]);
  const [tiep, datTiep] = useState<string | null>(null);
  const [dem, datDem] = useState<DsThucThi['dem']>({});
  const [underAttack, datUnderAttack] = useState(false);
  const [loi, datLoi] = useState<LoiSoc | null>(null);
  const [tai, datTai] = useState(false);
  const [chon, datChon] = useState<Set<string>>(new Set());
  const [hop, datHop] = useState<'chan' | 'go' | null>(null);
  const [lanNap, datLanNap] = useState(0);
  const yc = useTai<{ ds: YeuCauDuyet[]; toi: string }>('/yeu-cau-duyet');

  const nap = useCallback(
    async (cursor: string | null) => {
      datTai(true);
      const q = new URLSearchParams({ trangThai: loc.trangThai });
      if (loc.loai) q.set('loai', loc.loai);
      if (loc.q) q.set('q', loc.q);
      if (cursor) q.set('cursor', cursor);
      try {
        const d = await goi<DsThucThi>(`/thuc-thi?${q.toString()}`);
        datDs((cu) => (cursor ? [...cu, ...d.ds] : d.ds));
        datTiep(d.tiepTheo);
        datDem(d.dem);
        datUnderAttack(d.underAttack);
        datLoi(null);
      } catch (e) {
        datLoi(e instanceof LoiSoc ? e : new LoiSoc(0, null));
      } finally {
        datTai(false);
      }
    },
    [loc],
  );
  useEffect(() => {
    datChon(new Set());
    void nap(null);
  }, [nap, lanNap]);

  const napLai = () => {
    datLanNap((n) => n + 1);
    yc.napLai();
  };

  const quyetDeXuat = async (e: ThucThi, dongY: boolean) => {
    if (await ghi('/thuc-thi/duyet', { id: e.id, dongY })) {
      bao(dongY ? t.daDuyet : t.daBac);
      napLai();
    }
  };

  const quyetYeuCau = async (y: YeuCauDuyet, dongY: boolean) => {
    if (await ghi('/yeu-cau-duyet/quyet', { id: y.id, dongY })) {
      bao(dongY ? t.daDuyet : t.daBac);
      napLai();
    }
  };

  const huyYeuCau = async (y: YeuCauDuyet) => {
    if (await ghi('/yeu-cau-duyet/huy', { id: y.id })) {
      bao(t.daHuyYeuCau);
      napLai();
    }
  };

  const dsChon = [...chon];
  const choDuyetYc = (yc.duLieu?.ds ?? []).filter((y) => y.status === 'pending');

  return (
    <div className="trang-chinh">
      {underAttack && (
        <p className="bang-under-attack" role="status">
          <strong>{t.underAttackDangBat}</strong> {t.underAttackGiaiThich}
        </p>
      )}
      <div className="hang-o-dem">
        <button type="button" className="o-dem" aria-pressed={loc.trangThai === 'hieu-luc'} onClick={() => datLoc({ ...loc, trangThai: 'hieu-luc' })}>
          <span className="o-so-nhan">{t.thucThiHieuLuc}</span>
          <span className="o-so-gia-tri">{dinhDangSo(dem.hieuLuc ?? 0, nn)}</span>
        </button>
        <button type="button" className="o-dem" aria-pressed={loc.trangThai === 'cho-duyet'} onClick={() => datLoc({ ...loc, trangThai: 'cho-duyet' })}>
          <span className="o-so-nhan">{t.deXuatChoDuyet}</span>
          <span className="o-so-gia-tri">{dinhDangSo(dem.choDuyet ?? 0, nn)}</span>
        </button>
        <a className="o-dem" href="#yeu-cau-four-eyes">
          <span className="o-so-nhan">{t.yeuCauFourEyes}</span>
          <span className="o-so-gia-tri">{dinhDangSo(dem.yeuCau ?? 0, nn)}</span>
        </a>
      </div>

      <form
        className="bo-loc thanh-loc"
        role="search"
        onSubmit={(e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          datLoc({ trangThai: String(f.get('trangThai')), loai: String(f.get('loai')), q: String(f.get('q') ?? '').trim() });
        }}
      >
        <label>
          <span>{t.locTrangThai}</span>
          <select name="trangThai" value={loc.trangThai} onChange={(e) => datLoc({ ...loc, trangThai: e.target.value })}>
            {(['hieu-luc', 'cho-duyet', 'het', 'tat-ca'] as const).map((k) => (
              <option key={k} value={k}>
                {t.locThucThi[k]}
              </option>
            ))}
          </select>
        </label>
        <label>
          <span>{t.loaiDich}</span>
          <select name="loai" value={loc.loai} onChange={(e) => datLoc({ ...loc, loai: e.target.value })}>
            <option value="">{t.tatCa}</option>
            {(['device', 'ip', 'cidr', 'asn'] as const).map((k) => (
              <option key={k} value={k}>
                {t.tenLoaiDich[k]}
              </option>
            ))}
          </select>
        </label>
        <label>
          <span>{t.timDich}</span>
          <input name="q" data-o-tim="" defaultValue={loc.q} maxLength={64} pattern="[0-9A-Za-z.:/\-]+" autoComplete="off" spellCheck={false} />
        </label>
        <div className="bo-loc-nut">
          <button type="submit" className="nut nut-phu">
            {t.apDung}
          </button>
          {canThiep && (
            <button type="button" className="nut nut-chinh" onClick={() => datHop('chan')}>
              {t.chanMoi}
            </button>
          )}
        </div>
      </form>

      {!canThiep && <p className="ghi-chu-vai-tro">{t.chiXemCanThiep}</p>}

      {canThiep && chon.size > 0 && (
        <div className="thanh-hang-loat" role="toolbar" aria-label={t.daChon(chon.size)}>
          <strong>{t.daChon(chon.size)}</strong>
          <button type="button" className="nut" onClick={() => datHop('go')}>
            {chon.size > 1 ? t.goChanHangLoat : t.goChan}
          </button>
          <button type="button" className="nut nut-phu" onClick={() => datChon(new Set())}>
            {t.boChon}
          </button>
        </div>
      )}

      {loi && <ThongBaoLoi loi={loi} napLai={napLai} />}
      <div className="bang-khung" aria-busy={tai}>
        <table className="bang">
          <thead>
            <tr>
              {canThiep && <th className="cot-chon" aria-label={t.chonTatCa} />}
              <th>{t.cotTt.dich}</th>
              <th>{t.cotTt.hanhDong}</th>
              <th>{t.cotTt.trangThai}</th>
              <th>{t.cotTt.lyDo}</th>
              <th>{t.cotTt.nguoi}</th>
              <th>{t.cotTt.tao}</th>
              <th>{t.cotTt.het}</th>
              {duyet && loc.trangThai === 'cho-duyet' && <th>{t.hanhDong}</th>}
            </tr>
          </thead>
          <tbody>
            {ds.map((e) => {
              const conHieuLuc = !e.revoked_at && e.expires_at > Date.now();
              return (
                <tr key={e.id} className={conHieuLuc ? undefined : 'mo'}>
                  {canThiep && (
                    <td className="cot-chon">
                      {conHieuLuc && (
                        <input
                          type="checkbox"
                          aria-label={t.chonDong(e.id)}
                          checked={chon.has(e.id)}
                          onChange={(x) =>
                            datChon((c) => {
                              const m = new Set(c);
                              if (x.target.checked) m.add(e.id);
                              else m.delete(e.id);
                              return m;
                            })
                          }
                        />
                      )}
                    </td>
                  )}
                  <td>
                    <span className="nhan-phu">{t.tenLoaiDich[e.target_type]}</span>{' '}
                    {e.target_type === 'device' ? (
                      <a className="ma" href={`#/thiet-bi/${e.target_value}`}>
                        {e.target_value}
                      </a>
                    ) : (
                      <span className="ma">{e.target_value}</span>
                    )}
                  </td>
                  <td>
                    {t.tenHanhDongChan[e.action] ?? e.action}
                    {e.level > 0 && <span className="o-so-phu"> · {t.bacSo(e.level)}</span>}
                  </td>
                  <td>
                    <NhanThucThi e={e} />
                    <span className="nhan-phu">{e.source === 'auto' ? (e.rule_id ?? t.nguonTuDong) : t.nguonThuCong}</span>
                  </td>
                  <td className="o-ly-do">{e.reason}</td>
                  <td className="o-nguoi">
                    {e.created_by}
                    {e.approved_by && <span className="o-so-phu"> ✓ {e.approved_by}</span>}
                  </td>
                  <td title={dinhDangLuc(e.created_at, nn)}>{truocDay(e.created_at, nn)}</td>
                  <td title={dinhDangLuc(e.expires_at, nn)}>{truocDay(e.expires_at, nn)}</td>
                  {duyet && loc.trangThai === 'cho-duyet' && (
                    <td>
                      {e.created_by !== toi.email ? (
                        <div className="hang-nut trai">
                          <button type="button" className="nut nut-chinh" onClick={() => void quyetDeXuat(e, true)}>
                            {t.duyet}
                          </button>
                          <button type="button" className="nut nut-phu" onClick={() => void quyetDeXuat(e, false)}>
                            {t.bac}
                          </button>
                        </div>
                      ) : (
                        <span className="o-so-phu">{t.khongTuDuyet}</span>
                      )}
                    </td>
                  )}
                </tr>
              );
            })}
          </tbody>
        </table>
        {!tai && ds.length === 0 && !loi && <p className="trong o-trong">{t.khongCo}</p>}
      </div>
      {tiep && (
        <div className="chan-bang">
          <button type="button" className="nut nut-phu" disabled={tai} onClick={() => void nap(tiep)}>
            {t.taiThemNut}
          </button>
        </div>
      )}

      <section className="the" id="yeu-cau-four-eyes">
        <div className="tieu-de-the">
          <h2>{t.yeuCauFourEyes}</h2>
          <span className="o-so-phu">{t.fourEyesGiaiThich}</span>
        </div>
        {yc.loi && <ThongBaoLoi loi={yc.loi} napLai={yc.napLai} />}
        {choDuyetYc.length === 0 ? (
          <p className="trong">{t.khongCoYeuCau}</p>
        ) : (
          <ul className="ds-yeu-cau">
            {choDuyetYc.map((y) => (
              <li key={y.id} className="the-yeu-cau">
                <div className="hang-tom-tat">
                  <strong>{y.kind === 'chan' ? t.ycChan(y.payload.dich?.length ?? 0, t.tenHanhDongChan[y.payload.hanhDong ?? ''] ?? '') : t.ycGoChan(y.payload.ids?.length ?? 0)}</strong>
                  <span className="o-so-phu">
                    {y.created_by} · {truocDay(y.created_at, nn)} · {t.hetHanLuc(truocDay(y.expires_at, nn))}
                  </span>
                </div>
                <p>{y.reason}</p>
                {y.payload.dich && (
                  <p className="ma o-so-phu danh-sach-dich">
                    {y.payload.dich
                      .slice(0, 20)
                      .map((d) => `${d.loai}:${d.giaTri}`)
                      .join(' · ')}
                    {y.payload.dich.length > 20 ? ` … +${y.payload.dich.length - 20}` : ''}
                  </p>
                )}
                <div className="hang-nut trai">
                  {duyet && y.created_by !== toi.email && (
                    <>
                      <button type="button" className="nut nut-chinh" onClick={() => void quyetYeuCau(y, true)}>
                        {t.duyet}
                      </button>
                      <button type="button" className="nut nut-phu" onClick={() => void quyetYeuCau(y, false)}>
                        {t.bac}
                      </button>
                    </>
                  )}
                  {y.created_by === toi.email && (
                    <>
                      <span className="o-so-phu">{t.choNguoiKhacDuyet}</span>
                      <button type="button" className="nut nut-phu" onClick={() => void huyYeuCau(y)}>
                        {t.huyYeuCau}
                      </button>
                    </>
                  )}
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>

      <ChoPhep />

      <HopThoaiChan
        mo={hop === 'chan'}
        dong={() => datHop(null)}
        xong={() => {
          datHop(null);
          napLai();
        }}
      />
      <HopThoaiLyDo
        mo={hop === 'go'}
        tieuDe={chon.size > 1 ? t.goChanHangLoat : t.goChan}
        canhBao={chon.size > 1 ? t.canhBaoHangLoat(chon.size) : null}
        dong={() => datHop(null)}
        xong={async (lyDo) => {
          const kq = await ghi<{ loai: string }>('/thuc-thi/go', { ids: dsChon, lyDo });
          if (kq) {
            bao(kq.loai === 'yeu-cau' ? t.daGuiYeuCau : t.daGoChan);
            datHop(null);
            napLai();
          }
        }}
      />
    </div>
  );
}

/**
 * Hộp thoại chặn: loại đích, danh sách đích (mỗi dòng một), hành động, thời hạn, lý do. [dichSan] = mở từ trang thiết bị
 * (đích cố định). Nhiều đích -> server tạo yêu cầu four-eyes (202).
 */
export function HopThoaiChan({ mo, dong, xong, dichSan }: { mo: boolean; dong: () => void; xong: () => void; dichSan?: { loai: LoaiDich; giaTri: string } }) {
  const { t } = useSoc();
  const bao = useThongBao();
  const ghi = useGhi();
  const [loai, datLoai] = useState<LoaiDich>(dichSan?.loai ?? 'ip');
  const [ban, datBan] = useState(false);
  useEffect(() => {
    if (mo) datLoai(dichSan?.loai ?? 'ip');
  }, [mo, dichSan?.loai]);
  return (
    <HopThoai mo={mo} tieuDe={dichSan ? t.chanDich(dichSan.giaTri) : t.chanMoi} dong={dong}>
      <form
        className="bo-loc doc"
        onSubmit={(e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          const ds = dichSan ? [dichSan.giaTri] : tachDich(String(f.get('dich') ?? ''));
          datBan(true);
          void ghi<{ loai: string; tao?: string[]; boQua?: string[] }>('/thuc-thi/chan', {
            dich: ds.map((giaTri) => ({ loai, giaTri })),
            hanhDong: loai === 'device' ? String(f.get('hanhDong')) : 'block',
            thoiHan: String(f.get('thoiHan')),
            lyDo: String(f.get('lyDo') ?? '').trim(),
          })
            .then((kq) => {
              if (!kq) return;
              bao(kq.loai === 'yeu-cau' ? t.daGuiYeuCau : kq.loai === 'de-xuat' ? t.daTaoDeXuat : kq.tao?.length ? t.daChan : t.daCoChan);
              xong();
            })
            .finally(() => datBan(false));
        }}
      >
        {!dichSan && (
          <label>
            <span>{t.loaiDich}</span>
            <select value={loai} onChange={(e) => datLoai(e.target.value as LoaiDich)}>
              {(['device', 'ip', 'cidr', 'asn'] as const).map((k) => (
                <option key={k} value={k}>
                  {t.tenLoaiDich[k]}
                </option>
              ))}
            </select>
          </label>
        )}
        {!dichSan && (
          <label>
            <span>{t.dsDich}</span>
            <textarea name="dich" rows={3} required className="ma" spellCheck={false} placeholder={t.goiYDich[loai]} />
            <span className="o-so-phu">{t.mocDichGhiChu}</span>
          </label>
        )}
        {loai === 'device' && (
          <fieldset className="nhom-chon">
            <legend>{t.hanhDong}</legend>
            {(['restrict', 'ban'] as const).map((h, i) => (
              <label key={h} className="hang">
                <input type="radio" name="hanhDong" value={h} defaultChecked={i === 0} />
                <span>{t.tenHanhDongChan[h]}</span>
              </label>
            ))}
          </fieldset>
        )}
        <label>
          <span>{t.thoiHan}</span>
          <select name="thoiHan" defaultValue="24h">
            {THOI_HAN.map((k) => (
              <option key={k} value={k}>
                {t.tenThoiHan[k]}
              </option>
            ))}
          </select>
        </label>
        {(loai === 'cidr' || loai === 'asn') && <p className="canh-bao-chu">{t.canhBaoDai}</p>}
        <label>
          <span>{t.lyDoBatBuoc}</span>
          <textarea name="lyDo" rows={3} minLength={10} maxLength={500} required placeholder={t.lyDoGoiY} />
        </label>
        <p className="o-so-phu">{t.canPasskeyGhiChu}</p>
        <div className="hang-nut">
          <button type="button" className="nut nut-phu" onClick={dong}>
            {t.huy}
          </button>
          <button type="submit" className="nut nut-nguy" disabled={ban} aria-busy={ban}>
            {t.chan}
          </button>
        </div>
      </form>
    </HopThoai>
  );
}
