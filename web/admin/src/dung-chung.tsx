// Thành phần dùng chung SOC: tải dữ liệu (tự khoá khi hết phiên), ô số liệu, thanh xếp hạng, nhãn trạng thái.
import { useCallback, useEffect, useState } from 'react';
import { goi, LoiSoc } from './api';
import { useSoc } from './ngu-canh';
import { dinhDangSo } from './i18n';

export type KetQuaTai<T> = { duLieu: T | null; loi: LoiSoc | null; tai: boolean; napLai: (nen?: boolean) => void };

/** GET [duong]; 401 (hết phiên / nhàn rỗi) -> về màn passkey. chuKyMs > 0: làm mới nền định kỳ. */
export function useTai<T>(duong: string | null, chuKyMs = 0): KetQuaTai<T> {
  const { hetPhien } = useSoc();
  const [duLieu, datDuLieu] = useState<T | null>(null);
  const [loi, datLoi] = useState<LoiSoc | null>(null);
  const [tai, datTai] = useState(false);
  const [lan, datLan] = useState<{ n: number; nen: boolean }>({ n: 0, nen: false });

  const napLai = useCallback((nen = false) => datLan((l) => ({ n: l.n + 1, nen })), []);

  useEffect(() => {
    if (!duong) return;
    const huy = new AbortController();
    datTai(true);
    goi<T>(duong, { signal: huy.signal, nen: lan.nen })
      .then((d) => {
        datDuLieu(d);
        datLoi(null);
      })
      .catch((e: unknown) => {
        if (e instanceof DOMException) return;
        const l = e instanceof LoiSoc ? e : new LoiSoc(0, null);
        if (l.status === 401) hetPhien();
        datLoi(l);
      })
      .finally(() => datTai(false));
    return () => huy.abort();
  }, [duong, lan, hetPhien]);

  useEffect(() => {
    if (!chuKyMs) return;
    const hen = setInterval(() => napLai(true), chuKyMs);
    return () => clearInterval(hen);
  }, [chuKyMs, napLai]);

  return { duLieu, loi, tai, napLai };
}

export function OSo({ nhan, giaTri, nhan2 }: { nhan: string; giaTri: number | undefined; nhan2?: string }) {
  const { nn } = useSoc();
  return (
    <div className="o-so">
      <span className="o-so-nhan">{nhan}</span>
      <span className="o-so-gia-tri">{giaTri === undefined ? '-' : dinhDangSo(giaTri, nn)}</span>
      {nhan2 && <span className="o-so-phu">{nhan2}</span>}
    </div>
  );
}

/** Thanh xếp hạng MỘT chuỗi (không cần chú giải - tiêu đề thẻ đã gọi tên): nhãn, thanh tỉ lệ, số. */
export function ThanhXepHang({ ds, nhan }: { ds: { k: string | number | null; n: number }[]; nhan?: (k: string) => string }) {
  const { t, nn } = useSoc();
  if (ds.length === 0) return <p className="trong">{t.khongCo}</p>;
  const lon = Math.max(...ds.map((x) => x.n), 1);
  return (
    <ul className="xep-hang">
      {ds.map((x) => {
        const k = x.k === null ? '-' : String(x.k);
        return (
          <li key={k} title={`${nhan ? nhan(k) : k}: ${dinhDangSo(x.n, nn)}`}>
            <span className="xh-nhan">{nhan ? nhan(k) : k}</span>
            <span className="xh-ray" aria-hidden="true">
              <span className="xh-thanh" style={{ inlineSize: `${(x.n / lon) * 100}%` }} />
            </span>
            <span className="xh-so">{dinhDangSo(x.n, nn)}</span>
          </li>
        );
      })}
    </ul>
  );
}

export function NhanTrangThai({ tt }: { tt: string }) {
  const { t } = useSoc();
  return <span className={`trang-thai tt-${tt}`}>{t.trangThai[tt] ?? tt}</span>;
}

export function MucDo({ muc }: { muc: string }) {
  const { t } = useSoc();
  return <span className={`muc-do md-${muc}`}>{t.mucDo[muc] ?? muc}</span>;
}

export function ThongBaoLoi({ loi, napLai }: { loi: LoiSoc; napLai: () => void }) {
  const { t } = useSoc();
  return (
    <div role="alert" className="the loi-the">
      <p>{loi.status === 0 ? t.loiMang : loi.ma === 'loc-loi' ? t.locLoi : t.loiChung}</p>
      <button type="button" className="nut" onClick={() => napLai()}>
        {t.thuLai}
      </button>
    </div>
  );
}
