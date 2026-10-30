// Bảng lệnh Ctrl K (mẫu combobox ARIA): gõ để lọc trang / thao tác, dán ID thiết bị / cảnh báo / IP để nhảy thẳng tới.
import { useEffect, useId, useMemo, useRef, useState } from 'react';
import { BieuTuong } from './BieuTuong';
import { HopThoai } from './HopThoai';
import { locLenh, nhanDang, type Lenh } from './lenh';

export type ChuoiBangLenh = { bangLenh: string; timLenh: string; khongThayLenh: string; lenhMoThietBi: (id: string) => string; lenhMoCanhBao: (id: string) => string; lenhLocIp: (ip: string) => string };

export function BangLenh({ mo, dong, ds, t, di }: { mo: boolean; dong: () => void; ds: Lenh[]; t: ChuoiBangLenh; di: (hash: string) => void }) {
  const [q, datQ] = useState('');
  const [chon, datChon] = useState(0);
  const o = useRef<HTMLInputElement>(null);
  const idDs = useId();

  useEffect(() => {
    if (!mo) return;
    datQ('');
    datChon(0);
    requestAnimationFrame(() => o.current?.focus());
  }, [mo]);

  const kq = useMemo<Lenh[]>(() => {
    const nd = nhanDang(q);
    const dong: Lenh[] = [];
    if (nd?.loai === 'id') {
      dong.push({ id: 'mo-tb', nhom: '', nhan: t.lenhMoThietBi(nd.giaTri), chay: () => di(`#/thiet-bi/${nd.giaTri}`) });
      dong.push({ id: 'mo-cb', nhom: '', nhan: t.lenhMoCanhBao(nd.giaTri), chay: () => di(`#/canh-bao/${nd.giaTri}`) });
    } else if (nd?.loai === 'ip') {
      dong.push({ id: 'loc-ip', nhom: '', nhan: t.lenhLocIp(nd.giaTri), chay: () => di(`#/thiet-bi?ip=${encodeURIComponent(nd.giaTri)}`) });
    }
    return [...dong, ...locLenh(ds, nd ? '' : q)];
  }, [q, ds, t, di]);

  const chay = (l: Lenh | undefined) => {
    if (!l) return;
    dong();
    l.chay();
  };

  return (
    <HopThoai mo={mo} tieuDe={t.bangLenh} dong={dong} rong>
      <div className="bang-lenh">
        <label className="bang-lenh-o">
          <BieuTuong ten="tim" />
          <input
            ref={o}
            type="text"
            role="combobox"
            aria-expanded="true"
            aria-controls={idDs}
            aria-activedescendant={kq[chon] ? `${idDs}-${chon}` : undefined}
            aria-label={t.timLenh}
            placeholder={t.timLenh}
            value={q}
            autoComplete="off"
            spellCheck={false}
            onChange={(e) => {
              datQ(e.target.value);
              datChon(0);
            }}
            onKeyDown={(e) => {
              if (e.key === 'ArrowDown') {
                e.preventDefault();
                datChon((c) => Math.min(kq.length - 1, c + 1));
              } else if (e.key === 'ArrowUp') {
                e.preventDefault();
                datChon((c) => Math.max(0, c - 1));
              } else if (e.key === 'Enter') {
                e.preventDefault();
                chay(kq[chon]);
              }
            }}
          />
          <kbd>Esc</kbd>
        </label>
        {kq.length === 0 ? (
          <p className="trong">{t.khongThayLenh}</p>
        ) : (
          <ul id={idDs} role="listbox" className="bang-lenh-ds" aria-label={t.bangLenh}>
            {kq.map((l, i) => (
              <li
                key={l.id}
                id={`${idDs}-${i}`}
                role="option"
                aria-selected={i === chon}
                onMouseMove={() => datChon(i)}
                onClick={() => chay(l)}
              >
                <span>{l.nhan}</span>
                {l.nhom && <span className="nhan-phu">{l.nhom}</span>}
              </li>
            ))}
          </ul>
        )}
      </div>
    </HopThoai>
  );
}
