// Cấu hình Threat Engine (S7b, Spec §7.6c): bật / tắt Under Attack, ngưỡng trạng thái, bảng điểm sự kiện, hồi phục uy
// tín, bậc TTL. Lưu = phiên bản threat_config mới (server kiểm schema + phiên bản đang sửa, audit chuỗi băm).
import { useState, type FormEvent } from 'react';
import type { CauHinhNguyCo as KieuCauHinh } from '../api';
import { useThongBao } from '../giao-dien/ThongBao';
import { ThongBaoLoi, useGhi, useTai } from '../dung-chung';
import { dinhDangLuc } from '../i18n';
import { useSoc } from '../ngu-canh';
import { HopThoaiLyDo } from './Luat';

type DuLieu = { phienBan: number; cauHinh: KieuCauHinh; macDinh: KieuCauHinh; lichSu: { version: number; created_by: string; created_at: number }[] };

const NGAY_MS = 86_400_000;

/** Đọc biểu mẫu -> cấu hình đầy đủ (giữ trường không có trên form từ bản hiện tại). */
export function docCauHinhForm(f: FormData, goc: KieuCauHinh): KieuCauHinh {
  const so = (k: string, mac: number) => {
    const tho = f.get(k);
    const v = typeof tho === 'string' && tho.trim() !== '' ? Number(tho) : NaN;
    return Number.isFinite(v) ? Math.round(v) : mac;
  };
  const diem: Record<string, number> = {};
  for (const k of Object.keys(goc.diem)) diem[k] = so(`diem.${k}`, goc.diem[k] ?? 0);
  const moi = String(f.get('diemMoi.loai') ?? '')
    .trim()
    .toUpperCase();
  if (/^[A-Z][A-Z0-9_]{2,47}$/.test(moi)) diem[moi] = so('diemMoi.diem', 0);
  return {
    ...goc,
    diem,
    nguong: { suspicious: so('nguong.suspicious', goc.nguong.suspicious), restricted: so('nguong.restricted', goc.nguong.restricted), banned: so('nguong.banned', goc.nguong.banned) },
    hoiPhuc: { diemMoiTuan: so('hoiPhuc.diemMoiTuan', goc.hoiPhuc.diemMoiTuan), san: so('hoiPhuc.san', goc.hoiPhuc.san) },
    ttlBac: goc.ttlBac.map((x, i) => so(`ttl.${i}`, Math.round(x / NGAY_MS)) * NGAY_MS),
    diemToiDa: so('diemToiDa', goc.diemToiDa),
  };
}

export function CauHinhNguyCo() {
  const { t, nn, coQuyen } = useSoc();
  const bao = useThongBao();
  const ghi = useGhi();
  const sua = coQuyen('cau-hinh-nguy-co');
  const dl = useTai<DuLieu>('/cau-hinh-nguy-co');
  const [hopUa, datHopUa] = useState(false);
  const [choLuu, datChoLuu] = useState<KieuCauHinh | null>(null);
  const [khoaForm, datKhoaForm] = useState(0);
  const d = dl.duLieu;
  if (dl.loi) return <ThongBaoLoi loi={dl.loi} napLai={dl.napLai} />;
  if (!d) return <p className="giua">{t.dangTai}</p>;
  const c = d.cauHinh;
  const ua = c.underAttack;

  const guiForm = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    datChoLuu(docCauHinhForm(new FormData(e.currentTarget), c));
  };

  return (
    <div className="luoi-chi-tiet">
      <section className={ua ? 'the rong-2 the-under-attack bat' : 'the rong-2 the-under-attack'}>
        <div className="tieu-de-the">
          <h2>{t.underAttack}</h2>
          <span className={ua ? 'trang-thai tt-banned' : 'trang-thai tt-clean'}>{ua ? t.dangBat : t.dangTat}</span>
        </div>
        <p>{t.underAttackMoTa}</p>
        {sua && (
          <button type="button" className={ua ? 'nut' : 'nut nut-nguy'} onClick={() => datHopUa(true)}>
            {ua ? t.tatUnderAttack : t.batUnderAttack}
          </button>
        )}
      </section>

      <form key={khoaForm} className="the rong-2 bo-loc doc" onSubmit={guiForm}>
        <div className="tieu-de-the">
          <h2>{t.bangDiemNguong}</h2>
          <span className="o-so-phu">v{d.phienBan}</span>
        </div>
        {!sua && <p className="ghi-chu-vai-tro">{t.chiXemCauHinh}</p>}
        <fieldset className="nhom-chon luoi-3" disabled={!sua}>
          <legend>{t.nguongTrangThai}</legend>
          {(['suspicious', 'restricted', 'banned'] as const).map((k) => (
            <label key={k}>
              <span>{t.trangThai[k]}</span>
              <input name={`nguong.${k}`} type="number" min={1} max={10000} defaultValue={c.nguong[k]} required />
            </label>
          ))}
          <label>
            <span>{t.diemToiDa}</span>
            <input name="diemToiDa" type="number" min={100} max={100000} defaultValue={c.diemToiDa} required />
          </label>
        </fieldset>
        <fieldset className="nhom-chon luoi-3" disabled={!sua}>
          <legend>{t.hoiPhucUyTin}</legend>
          <label>
            <span>{t.diemMoiTuan}</span>
            <input name="hoiPhuc.diemMoiTuan" type="number" min={0} max={1000} defaultValue={c.hoiPhuc.diemMoiTuan} required />
          </label>
          <label>
            <span>{t.diemSan}</span>
            <input name="hoiPhuc.san" type="number" min={0} max={10000} defaultValue={c.hoiPhuc.san} required />
          </label>
        </fieldset>
        <fieldset className="nhom-chon luoi-3" disabled={!sua}>
          <legend>{t.bacTtl}</legend>
          {c.ttlBac.map((x, i) => (
            <label key={i}>
              <span>{t.bacNgay(i + 1)}</span>
              <input name={`ttl.${i}`} type="number" min={1} max={400} defaultValue={Math.round(x / NGAY_MS)} required />
            </label>
          ))}
        </fieldset>
        <fieldset className="nhom-chon" disabled={!sua}>
          <legend>{t.diemSuKien}</legend>
          <div className="luoi-diem">
            {Object.entries(c.diem)
              .sort(([a], [b]) => a.localeCompare(b))
              .map(([k, v]) => (
                <label key={k} className="hang-diem">
                  <span className="ma">{k}</span>
                  <input name={`diem.${k}`} type="number" min={0} max={1000} defaultValue={v} required className="o-ngan" />
                  {d.macDinh.diem[k] !== undefined && d.macDinh.diem[k] !== v && <span className="o-so-phu">{t.macDinhLa(d.macDinh.diem[k] ?? 0)}</span>}
                </label>
              ))}
            <label className="hang-diem">
              <input name="diemMoi.loai" placeholder={t.loaiMoi} className="ma" maxLength={48} pattern="[A-Za-z][A-Za-z0-9_]{2,47}" />
              <input name="diemMoi.diem" type="number" min={0} max={1000} className="o-ngan" aria-label={t.diemLoaiMoi} />
            </label>
          </div>
        </fieldset>
        {sua && (
          <div className="hang-nut">
            <button type="reset" className="nut nut-phu" onClick={() => datKhoaForm((n) => n + 1)}>
              {t.hoanTac}
            </button>
            <button type="submit" className="nut nut-chinh">
              {t.luuPhienBan}
            </button>
          </div>
        )}
      </form>

      <section className="the rong-2">
        <h2>{t.lichSuPhienBan}</h2>
        {d.lichSu.length === 0 ? (
          <p className="trong">{t.dangDungMacDinh}</p>
        ) : (
          <ul className="ds-gon">
            {d.lichSu.map((x) => (
              <li key={x.version}>
                <strong>v{x.version}</strong> · {x.created_by} · {dinhDangLuc(x.created_at, nn)}
              </li>
            ))}
          </ul>
        )}
      </section>

      <HopThoaiLyDo
        mo={hopUa}
        tieuDe={ua ? t.tatUnderAttack : t.batUnderAttack}
        canhBao={ua ? null : t.canhBaoBatUa}
        dong={() => datHopUa(false)}
        xong={async (ghiChu) => {
          if (await ghi('/under-attack', { bat: !ua, ghiChu })) {
            bao(t.daLuu);
            datHopUa(false);
            dl.napLai();
          }
        }}
      />
      <HopThoaiLyDo
        mo={choLuu !== null}
        tieuDe={t.luuCauHinhTieuDe}
        dong={() => datChoLuu(null)}
        xong={async (ghiChu) => {
          if (choLuu && (await ghi('/cau-hinh-nguy-co', { phienBan: d.phienBan, cauHinh: choLuu, ghiChu }))) {
            bao(t.daLuu);
            datChoLuu(null);
            dl.napLai();
            datKhoaForm((n) => n + 1);
          }
        }}
      />
    </div>
  );
}
