// Cài đặt hệ thống SOC (S7b, chỉ Super Admin): thuỷ vân bật / tắt cho MỌI người xem, độ đậm tối thiểu, ép che dữ liệu
// khi rời cửa sổ. Lưu cần lý do + passkey; lịch sử đọc từ audit chuỗi băm. Áp dụng cho người khác ở lần tải /toi kế tiếp.
import { useState, type FormEvent } from 'react';
import type { CaiDatSoc } from '../api';
import { useThongBao } from '../giao-dien/ThongBao';
import { ThongBaoLoi, useGhi, useTai } from '../dung-chung';
import { dinhDangLuc } from '../i18n';
import { useSoc } from '../ngu-canh';
import { HopThoaiLyDo } from './Luat';

type DuLieu = { caiDat: CaiDatSoc; lichSu: { actor: string; ts: number; after: Partial<CaiDatSoc> & { ghiChu?: string } }[] };

export function CaiDatHeThong({ daDoi }: { daDoi: () => void }) {
  const { t, nn } = useSoc();
  const bao = useThongBao();
  const ghi = useGhi();
  const dl = useTai<DuLieu>('/cai-dat-soc');
  const [nhap, datNhap] = useState<CaiDatSoc | null>(null);
  const [choLuu, datChoLuu] = useState(false);
  if (dl.loi) return <ThongBaoLoi loi={dl.loi} napLai={dl.napLai} />;
  if (!dl.duLieu) return <p className="giua">{t.dangTai}</p>;
  const goc = dl.duLieu.caiDat;
  const cd = nhap ?? goc;
  const doi = JSON.stringify(cd) !== JSON.stringify(goc);
  const dat = (p: Partial<CaiDatSoc>) => datNhap({ ...cd, ...p });

  const gui = (e: FormEvent) => {
    e.preventDefault();
    if (doi) datChoLuu(true);
  };

  return (
    <div className="luoi-chi-tiet">
      <form className="the rong-2 bo-loc doc" onSubmit={gui}>
        <div className="tieu-de-the">
          <h2>{t.cdThuyVan}</h2>
          <span className={cd.thuyVan.bat ? 'trang-thai tt-clean' : 'trang-thai tt-suspicious'}>{cd.thuyVan.bat ? t.dangBat : t.dangTat}</span>
        </div>
        <p className="o-so-phu">{t.cdThuyVanMoTa}</p>
        <label className="cong-tac">
          <input type="checkbox" role="switch" checked={cd.thuyVan.bat} onChange={(e) => dat({ thuyVan: { ...cd.thuyVan, bat: e.target.checked } })} />
          <span>{t.cdBatThuyVan}</span>
        </label>
        {!cd.thuyVan.bat && <p className="canh-bao-chu">{t.cdCanhBaoTat}</p>}
        <fieldset className="nhom-chon" disabled={!cd.thuyVan.bat}>
          <legend>{t.cdMucToiThieu}</legend>
          {(
            [
              ['nhe', t.cdMucNguoiXemChon],
              ['chuan', t.thuyVanChuan],
            ] as const
          ).map(([v, nhan]) => (
            <label key={v} className="hang">
              <input type="radio" name="muc" checked={cd.thuyVan.mucToiThieu === v} onChange={() => dat({ thuyVan: { ...cd.thuyVan, mucToiThieu: v } })} />
              <span>{nhan}</span>
            </label>
          ))}
        </fieldset>
        <label className="cong-tac">
          <input type="checkbox" role="switch" checked={cd.epCheKhiRoi} onChange={(e) => dat({ epCheKhiRoi: e.target.checked })} />
          <span>{t.cdEpCheKhiRoi}</span>
        </label>
        <div className="hang-nut">
          <button type="button" className="nut nut-phu" disabled={!doi} onClick={() => datNhap(null)}>
            {t.hoanTac}
          </button>
          <button type="submit" className="nut nut-chinh" disabled={!doi}>
            {t.luu}
          </button>
        </div>
      </form>

      <section className="the rong-2">
        <h2>{t.lichSuThayDoi}</h2>
        {dl.duLieu.lichSu.length === 0 ? (
          <p className="trong">{t.dangDungMacDinh}</p>
        ) : (
          <ol className="dong-tg">
            {dl.duLieu.lichSu.map((x) => (
              <li key={x.ts}>
                <span className="dtg-chu">
                  {x.actor} · {dinhDangLuc(x.ts, nn)}
                </span>
                <span>
                  {t.cdThuyVan}: {x.after.thuyVan?.bat ? t.dangBat : t.dangTat}
                  {x.after.epCheKhiRoi ? ` · ${t.cdEpCheKhiRoi}` : ''}
                </span>
                {x.after.ghiChu && <span className="o-so-phu">{x.after.ghiChu}</span>}
              </li>
            ))}
          </ol>
        )}
      </section>

      <HopThoaiLyDo
        mo={choLuu}
        tieuDe={t.cdLuuTieuDe}
        canhBao={!cd.thuyVan.bat ? t.cdCanhBaoTat : null}
        dong={() => datChoLuu(false)}
        xong={async (ghiChu) => {
          if (await ghi('/cai-dat-soc', { caiDat: cd, ghiChu })) {
            bao(t.daLuu);
            datChoLuu(false);
            datNhap(null);
            dl.napLai();
            daDoi();
          }
        }}
      />
    </div>
  );
}
