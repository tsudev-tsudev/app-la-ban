// Khung SOC - giao diện thật ở phase S6. Vùng dữ liệu đã có watermark động (S9, SH-04).
import { chuoi, ngonNgu } from './i18n';
import { useEmailNguoiXem } from './khien/danh-tinh';
import { VungDuLieu } from './khien/Watermark';

export function App() {
  const t = chuoi(ngonNgu(document.documentElement.lang));
  const email = useEmailNguoiXem();
  return (
    <main>
      <h1>{t.tieuDe}</h1>
      <VungDuLieu email={email ?? t.chuaXacThuc}>
        <p>{t.dangXay}</p>
      </VungDuLieu>
    </main>
  );
}
