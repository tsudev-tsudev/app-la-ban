/// Vỏ app La bàn dùng chung (M2, QUYET_DINH Q56): entry, DI, router, theme.
/// `app/` (miễn phí) và `app_pro/` (La bàn Pro) chỉ còn `main` + Android,
/// gọi `khoiDong` với `CauHinhSanPham` của mình.
library;

export 'src/flavor.dart' show CauHinhSanPham, Flavor, LoaiApp;
export 'src/khoi_dong.dart' show khoiDong;
