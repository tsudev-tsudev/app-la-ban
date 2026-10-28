// Toàn bộ chữ của landing, vi + en cùng cấu trúc (kiểu NoiDung bắt buộc đủ khoá cho cả hai ngôn ngữ).

export type NgonNgu = 'vi' | 'en';

export type TrangId = 'chu' | 'tai' | 'huong' | 'rieng' | 'khoan' | 'khieu';

/** Đường dẫn từng trang theo ngôn ngữ - nguồn duy nhất cho nav, hreflang, sitemap. */
export const DUONG_DAN: Record<TrangId, Record<NgonNgu, string>> = {
  chu: { vi: '/', en: '/en/' },
  tai: { vi: '/tai-ve/', en: '/en/download/' },
  huong: { vi: '/huong-dan/', en: '/en/guide/' },
  rieng: { vi: '/quyen-rieng-tu/', en: '/en/privacy/' },
  khoan: { vi: '/dieu-khoan/', en: '/en/terms/' },
  khieu: { vi: '/khieu-nai/', en: '/en/appeal/' },
};

type Muc = { tieuDe: string; noiDung: string };
type Icon = 'la-ban-hoa-gio' | 'bac-thuc' | 'hieu-chuan-so-8' | 'thuoc-thuy' | 'ghim-gps' | 'diem-moc' | 'ban-do' | 'camera-ar' | 'khien' | 'chia-se-qr' | 'mat-la-ban-3d' | 'cai-dat';

export type NoiDung = {
  lang: string;
  tenNgonNgu: string;
  doiNgonNgu: string;
  boQua: string;
  nav: { tinhNang: string; baoMat: string; huongDan: string; taiVe: string; menu: string };
  chan: { banQuyen: string; lienHe: string; giayPhepFont: string; trangThai: string };
  trang: Record<TrangId, { tieuDe: string; moTa: string }>;
  chu: {
    nhan: string;
    tieuDe: string;
    tieuDeNhan: string;
    moTa: string;
    nutApk: string;
    nutPlay: string;
    nutIos: string;
    ghiChuBeta: string;
    soLieu: { so: string; nhan: string }[];
    tinhNangTieuDe: string;
    tinhNangMoTa: string;
    tinhNang: (Muc & { icon: Icon; sapCo?: boolean })[];
    sapCo: string;
    chinhXacTieuDe: string;
    chinhXacMoTa: string;
    chinhXac: Muc[];
    baoMatTieuDe: string;
    baoMatMoTa: string;
    baoMat: (Muc & { icon: Icon })[];
    loTrinhTieuDe: string;
    loTrinh: { moc: string; tieuDe: string; noiDung: string; trangThai: 'xong' | 'dang' | 'sau' }[];
    trangThaiLoTrinh: Record<'xong' | 'dang' | 'sau', string>;
    hoiDapTieuDe: string;
    hoiDap: Muc[];
    cuoiTieuDe: string;
    cuoiMoTa: string;
  };
  tai: {
    tieuDe: string;
    moTa: string;
    phienBan: string;
    ngay: string;
    yeuCau: string;
    dungLuong: string;
    banArm64: string;
    banArm64MoTa: string;
    banUniversal: string;
    banUniversalMoTa: string;
    nutTai: string;
    sha: string;
    chungChi: string;
    quetQr: string;
    chuaCo: string;
    trongAppTieuDe: string;
    trongAppMoTa: string;
    moChrome: string;
    github: string;
    githubGhiChu: string;
    caiTieuDe: string;
    buocCai: Muc[];
    kiemTieuDe: string;
    kiemMoTa: string;
    canhBao: string;
    nenTangKhac: Muc[];
  };
  huong: { tieuDe: string; moTa: string; muc: (Muc & { icon: Icon; buoc?: string[] })[] };
  rieng: { capNhat: string; moTa: string; muc: Muc[] };
  khoan: { capNhat: string; moTa: string; muc: Muc[] };
  khieu: { moTa: string; buoc: Muc[]; nutEmail: string; chuDeEmail: string; thanEmail: string; luuY: string };
  loi404: { tieuDe: string; moTa: string; veTrangChu: string };
};

const vi: NoiDung = {
  lang: 'vi',
  tenNgonNgu: 'Tiếng Việt',
  doiNgonNgu: 'English',
  boQua: 'Bỏ qua tới nội dung',
  nav: { tinhNang: 'Tính năng', baoMat: 'Bảo mật', huongDan: 'Hướng dẫn', taiVe: 'Tải về', menu: 'Mở menu' },
  chan: { banQuyen: '© 2026 TsuDev. Bảo lưu mọi quyền.', lienHe: 'Liên hệ', giayPhepFont: 'Phông Be Vietnam Pro (OFL)', trangThai: 'Trạng thái dịch vụ' },
  trang: {
    chu: { tieuDe: 'La bàn - La bàn thông minh, chính xác, riêng tư', moTa: 'La bàn thông minh cho Android: bắc thực theo mô hình từ trường WMM, hiệu chuẩn hướng dẫn, toạ độ, độ cao, thước thuỷ - không quảng cáo theo dõi, dữ liệu mã hoá trên máy.' },
    tai: { tieuDe: 'Tải La bàn cho Android - bản thử nghiệm', moTa: 'Tải tệp APK La bàn bản thử nghiệm cho Android, kèm mã SHA-256 để kiểm toàn vẹn và hướng dẫn cài đặt từng bước.' },
    huong: { tieuDe: 'Hướng dẫn sử dụng và hiệu chuẩn - La bàn', moTa: 'Cách hiệu chuẩn la bàn hình số 8, phân biệt bắc từ và bắc thực, tránh nhiễu từ và cấp quyền vị trí đúng cách.' },
    rieng: { tieuDe: 'Chính sách quyền riêng tư - La bàn', moTa: 'La bàn thu thập gì, vì sao, lưu bao lâu và quyền của bạn theo Nghị định 13/2023/NĐ-CP.' },
    khoan: { tieuDe: 'Điều khoản sử dụng - La bàn', moTa: 'Điều khoản sử dụng ứng dụng La bàn và bản thử nghiệm.' },
    khieu: { tieuDe: 'Khiếu nại hạn chế tài khoản / thiết bị - La bàn', moTa: 'Gửi khiếu nại khi ứng dụng La bàn báo thiết bị bị hạn chế, kèm mã tham chiếu REF.' },
  },
  chu: {
    nhan: 'Android · bản thử nghiệm',
    tieuDe: 'La bàn chính xác,',
    tieuDeNhan: 'riêng tư tuyệt đối.',
    moTa: 'Bắc thực tính bằng mô hình từ trường thế giới WMM, hợp nhất cảm biến mượt 60 khung hình mỗi giây, hoạt động ngoại tuyến. Dữ liệu của bạn được mã hoá ngay trên máy.',
    nutApk: 'Tải APK cho Android',
    nutPlay: 'Google Play - sắp có',
    nutIos: 'iPhone - đầu năm 2027',
    ghiChuBeta: 'Bản thử nghiệm đang hoàn thiện từng tính năng. Cảm ơn bạn đã dùng thử và góp ý.',
    soLieu: [
      { so: '±0,5°', nhan: 'mục tiêu sai số sau hiệu chuẩn' },
      { so: '60 FPS', nhan: 'mặt la bàn mượt, tiết kiệm pin' },
      { so: '0', nhan: 'quảng cáo theo dõi trong bản thử' },
      { so: '2', nhan: 'ngôn ngữ: Tiếng Việt, English' },
    ],
    tinhNangTieuDe: 'Mọi thứ bạn cần để định hướng',
    tinhNangMoTa: 'Thiết kế cho đi rừng, đi biển, đo hướng nhà và làm việc ngoài trời - rõ ràng dưới nắng, dễ dùng bằng một tay.',
    tinhNang: [
      { icon: 'la-ban-hoa-gio', tieuDe: 'Mặt la bàn trực quan', noiDung: 'Hoa gió, độ, 16 hướng, chế độ sáng / tối và chữ lớn cho người khó nhìn.' },
      { icon: 'bac-thuc', tieuDe: 'Bắc thực và bắc từ', noiDung: 'Tự hiệu chỉnh độ lệch từ theo vị trí bằng mô hình WMM chạy ngoại tuyến.' },
      { icon: 'hieu-chuan-so-8', tieuDe: 'Hiệu chuẩn có hướng dẫn', noiDung: 'Báo độ tin cậy cảm biến và hướng dẫn vẽ hình số 8 khi cần.' },
      { icon: 'ghim-gps', tieuDe: 'Toạ độ và độ cao', noiDung: 'DD, DMS, UTM, MGRS; độ cao GPS kết hợp khí áp; tốc độ và độ chính xác.', sapCo: true },
      { icon: 'thuoc-thuy', tieuDe: 'Thước thuỷ', noiDung: 'Kiểm mặt phẳng ngang hai trục với độ nhạy cao.', sapCo: true },
      { icon: 'diem-moc', tieuDe: 'Điểm mốc và dẫn đường', noiDung: 'Lưu điểm, chỉ hướng và khoảng cách tới đích, nhập / xuất GPX, KML.', sapCo: true },
      { icon: 'ban-do', tieuDe: 'Bản đồ ngoại tuyến', noiDung: 'Bản đồ Việt Nam tải một lần, dùng cả khi ở chế độ máy bay.', sapCo: true },
      { icon: 'camera-ar', tieuDe: 'Camera AR', noiDung: 'Chồng hướng và điểm mốc lên hình camera để tìm đường trực quan.', sapCo: true },
    ],
    sapCo: 'Sắp có',
    chinhXacTieuDe: 'Chính xác từ cảm biến tới con số',
    chinhXacMoTa: 'La bàn điện thoại thường sai vì nhiễu từ và cảm biến chưa hiệu chuẩn. Chúng tôi xử lý từng nguồn sai số.',
    chinhXac: [
      { tieuDe: 'Hợp nhất cảm biến', noiDung: 'Kết hợp từ kế, gia tốc kế và con quay để kim ổn định, không giật khi bạn di chuyển.' },
      { tieuDe: 'Mô hình WMM', noiDung: 'Độ lệch từ tính theo vị trí và ngày, không cần mạng - cho ra bắc thực đúng như bản đồ.' },
      { tieuDe: 'Cảnh báo nhiễu từ', noiDung: 'Theo dõi cường độ từ trường (25-65 µT); báo ngay khi gần nam châm, kim loại hoặc thiết bị điện.' },
    ],
    baoMatTieuDe: 'Riêng tư và an toàn ngay từ thiết kế',
    baoMatMoTa: 'Ứng dụng không cần tài khoản. Dữ liệu nằm trên máy của bạn và được bảo vệ bằng nhiều lớp.',
    baoMat: [
      { icon: 'khien', tieuDe: 'Mã hoá trên máy', noiDung: 'Điểm mốc lưu trong cơ sở dữ liệu SQLCipher, khoá bọc bằng Android Keystore, không đi theo bản sao lưu đám mây.' },
      { icon: 'cai-dat', tieuDe: 'Không định danh phần cứng', noiDung: 'Không đọc IMEI, số sê-ri hay địa chỉ MAC. Không bán dữ liệu, không quảng cáo theo dõi.' },
      { icon: 'mat-la-ban-3d', tieuDe: 'Chống can thiệp', noiDung: 'Phát hiện bản bị sửa đổi hoặc môi trường không tin cậy; máy chủ quyết định, có quy trình khiếu nại minh bạch.' },
      { icon: 'chia-se-qr', tieuDe: 'Cập nhật an toàn', noiDung: 'Sao lưu trước mỗi lần nâng cấp dữ liệu, tự khôi phục khi lỗi, chế độ an toàn khi ứng dụng gặp sự cố.' },
    ],
    loTrinhTieuDe: 'Lộ trình',
    loTrinh: [
      { moc: 'Tháng 10/2026', tieuDe: 'Nền tảng', noiDung: 'Thương hiệu, khung ứng dụng, lưu trữ mã hoá, máy chủ và hệ thống phát hiện bất thường.', trangThai: 'xong' },
      { moc: 'Cuối 2026', tieuDe: 'Bản thử Android', noiDung: 'Tải APK trực tiếp tại đây; cảm biến, mặt la bàn, toạ độ, điểm mốc.', trangThai: 'dang' },
      { moc: 'Đầu 2027', tieuDe: 'Google Play', noiDung: 'Phát hành chính thức v1.0 trên Google Play sau kiểm thử bảo mật độc lập.', trangThai: 'sau' },
      { moc: 'Đầu 2027', tieuDe: 'iPhone', noiDung: 'Phiên bản iOS trên App Store.', trangThai: 'sau' },
    ],
    trangThaiLoTrinh: { xong: 'Hoàn thành', dang: 'Đang làm', sau: 'Kế hoạch' },
    hoiDapTieuDe: 'Câu hỏi thường gặp',
    hoiDap: [
      { tieuDe: 'Ứng dụng có miễn phí không?', noiDung: 'Có. Bản thử nghiệm miễn phí và không có quảng cáo. Sau khi phát hành chính thức có thể có gói Pro tuỳ chọn; các tính năng la bàn cơ bản luôn miễn phí.' },
      { tieuDe: 'Vì sao chưa có trên Google Play?', noiDung: 'Ứng dụng đang ở giai đoạn thử nghiệm. Bạn có thể tải APK trực tiếp từ trang này; khi lên Google Play, bản trên Play dùng cùng chữ ký nên cập nhật đè lên được.' },
      { tieuDe: 'Khi nào có bản iPhone?', noiDung: 'Dự kiến đầu năm 2027. Chúng tôi ưu tiên hoàn thiện Android trước.' },
      { tieuDe: 'Cài APK ngoài Google Play có an toàn không?', noiDung: 'Chỉ tải từ compass.tsudev.com hoặc trang phát hành GitHub chính thức. Mỗi bản có mã SHA-256 và chữ ký số cố định để bạn tự kiểm.' },
      { tieuDe: 'Ứng dụng có cần mạng không?', noiDung: 'Không. La bàn, bắc thực và toạ độ hoạt động ngoại tuyến. Mạng chỉ dùng cho tính năng chia sẻ và kiểm tra cập nhật.' },
      { tieuDe: 'Vì sao la bàn đôi khi lệch?', noiDung: 'Do nhiễu từ (ốp lưng có nam châm, xe, dầm thép) hoặc cảm biến chưa hiệu chuẩn. Xem trang Hướng dẫn để hiệu chuẩn hình số 8.' },
    ],
    cuoiTieuDe: 'Sẵn sàng dùng thử?',
    cuoiMoTa: 'Tải bản thử nghiệm mới nhất cho Android và gửi góp ý cho chúng tôi.',
  },
  tai: {
    tieuDe: 'Tải La bàn cho Android',
    moTa: 'Bản thử nghiệm ký bằng khoá phát hành của TsuDev. Chọn bản phù hợp máy của bạn.',
    phienBan: 'Phiên bản',
    ngay: 'Ngày phát hành',
    yeuCau: 'Yêu cầu',
    dungLuong: 'Dung lượng',
    banArm64: 'Bản khuyên dùng (arm64)',
    banArm64MoTa: 'Cho hầu hết điện thoại Android từ 2017 trở lại đây. Nhẹ hơn.',
    banUniversal: 'Bản đầy đủ (universal)',
    banUniversalMoTa: 'Chạy trên mọi máy, kể cả máy 32-bit đời cũ. Dung lượng lớn hơn.',
    nutTai: 'Tải xuống',
    sha: 'SHA-256',
    chungChi: 'Chứng chỉ ký (SHA-256)',
    quetQr: 'Quét mã bằng điện thoại để mở trang này',
    chuaCo: 'Bản thử nghiệm đầu tiên đang được chuẩn bị. Vui lòng quay lại sau ít phút.',
    trongAppTieuDe: 'Hãy mở trang này bằng Chrome',
    trongAppMoTa: 'Bạn đang xem trong trình duyệt của Zalo / Facebook / Messenger - trình duyệt này không tải được tệp APK (báo "định dạng không được hỗ trợ"). Bấm nút bên dưới, hoặc bấm ⋮ ở góc trên rồi chọn "Mở bằng trình duyệt".',
    moChrome: 'Mở bằng Chrome',
    github: 'Trang phát hành GitHub',
    githubGhiChu: 'Kho mã đang để riêng tư - chỉ thành viên dự án mở được trang GitHub.',
    caiTieuDe: 'Cài đặt trong 4 bước',
    buocCai: [
      { tieuDe: 'Tải tệp APK', noiDung: 'Mở trang này bằng Chrome (không mở trong Zalo / Facebook), bấm "Tải xuống" ở bản khuyên dùng. Trình duyệt có thể hỏi xác nhận vì đây là tệp cài đặt - chọn Tải xuống.' },
      { tieuDe: 'Cho phép cài từ nguồn này', noiDung: 'Mở tệp vừa tải. Android sẽ yêu cầu cho phép trình duyệt cài ứng dụng không rõ nguồn: Cài đặt -> bật "Cho phép từ nguồn này", rồi quay lại.' },
      { tieuDe: 'Cài đặt', noiDung: 'Bấm Cài đặt. Nếu Google Play Protect hỏi, chọn "Vẫn cài đặt" (ứng dụng chưa có trên Play nên Play Protect chưa nhận diện).' },
      { tieuDe: 'Mở và hiệu chuẩn', noiDung: 'Mở La bàn, làm theo màn giới thiệu. Lần đầu nên hiệu chuẩn hình số 8 để kim chính xác nhất.' },
    ],
    kiemTieuDe: 'Kiểm toàn vẹn (tuỳ chọn)',
    kiemMoTa: 'So mã SHA-256 của tệp đã tải với mã ở trên. Trên máy tính:',
    canhBao: 'Chỉ tải La bàn từ compass.tsudev.com. Bản ở nơi khác có thể đã bị sửa đổi - ứng dụng sẽ phát hiện và hạn chế bản bị sửa.',
    nenTangKhac: [
      { tieuDe: 'Google Play', noiDung: 'Sắp có - phát hành chính thức đầu năm 2027.' },
      { tieuDe: 'iPhone / iPad', noiDung: 'Dự kiến đầu năm 2027 trên App Store.' },
    ],
  },
  huong: {
    tieuDe: 'Hướng dẫn sử dụng',
    moTa: 'Vài phút để la bàn của bạn chính xác nhất.',
    muc: [
      {
        icon: 'hieu-chuan-so-8',
        tieuDe: 'Hiệu chuẩn hình số 8',
        noiDung: 'Khi ứng dụng báo độ tin cậy thấp hoặc kim lệch:',
        buoc: ['Tránh xa kim loại, nam châm, loa và thiết bị điện khoảng 1 m.', 'Cầm máy, xoay cổ tay vẽ hình số 8 trong không trung 3-5 lần, đổi cả mặt máy.', 'Chờ chỉ báo độ tin cậy chuyển sang xanh.'],
      },
      { icon: 'bac-thuc', tieuDe: 'Bắc thực và bắc từ', noiDung: 'Bắc từ là hướng kim nam châm chỉ; bắc thực là hướng về Bắc Cực địa lý, trùng với bản đồ. Ở Việt Nam hai hướng lệch nhau dưới 1 độ nhưng ở nhiều nơi khác có thể hơn 10 độ. Mặc định ứng dụng hiển thị bắc thực, tính bằng mô hình WMM theo vị trí và ngày.' },
      { icon: 'khien', tieuDe: 'Nhiễu từ', noiDung: 'Từ trường Trái Đất khoảng 25-65 µT. Khi số đo vượt khoảng này, ứng dụng cảnh báo: hãy tháo ốp lưng có nam châm, tránh xa ô tô, dầm thép và thử lại.' },
      {
        icon: 'ghim-gps',
        tieuDe: 'Quyền vị trí',
        noiDung: 'Vị trí chỉ cần để tính bắc thực, toạ độ và dẫn đường. Ứng dụng hỏi khi bạn dùng tính năng đó, ưu tiên vị trí gần đúng và chỉ khi đang mở ứng dụng.',
        buoc: ['Chọn "Chỉ khi dùng ứng dụng".', 'Có thể chọn "Vị trí gần đúng" - bắc thực vẫn chính xác.', 'Từ chối vẫn dùng được la bàn bắc từ.'],
      },
      { icon: 'la-ban-hoa-gio', tieuDe: 'Đọc la bàn', noiDung: 'Cầm máy song song mặt đất, đỉnh máy hướng về phía cần đo. Số độ ở giữa là hướng của đỉnh máy: 0° Bắc, 90° Đông, 180° Nam, 270° Tây.' },
      { icon: 'cai-dat', tieuDe: 'Chế độ an toàn', noiDung: 'Nếu ứng dụng gặp sự cố liên tiếp, nó tự vào chế độ an toàn với tính năng cơ bản để bạn vẫn dùng được la bàn và xuất dữ liệu. Cập nhật lên bản mới sẽ tự thoát chế độ này.' },
    ],
  },
  rieng: {
    capNhat: 'Cập nhật: 28/10/2026 · Bản dành cho giai đoạn thử nghiệm',
    moTa: 'Chính sách này giải thích cách ứng dụng La bàn và website compass.tsudev.com (do TsuDev vận hành) xử lý dữ liệu cá nhân theo Nghị định 13/2023/NĐ-CP.',
    muc: [
      { tieuDe: '1. Dữ liệu trên máy của bạn', noiDung: 'Điểm mốc, cài đặt và lịch sử được lưu trong cơ sở dữ liệu mã hoá trên máy, khoá bảo vệ bởi Android Keystore. Dữ liệu này không gửi về máy chủ và không nằm trong bản sao lưu đám mây.' },
      { tieuDe: '2. Vị trí', noiDung: 'Vị trí chỉ xử lý trên máy để tính bắc thực, toạ độ và dẫn đường; không gửi lên máy chủ trừ khi bạn chủ động chia sẻ một điểm mốc.' },
      { tieuDe: '3. Dữ liệu bảo mật kỹ thuật', noiDung: 'Để chống gian lận và bản bị sửa đổi, các phiên bản có kết nối máy chủ sẽ gửi: mã cài đặt ngẫu nhiên (không phải định danh phần cứng), loại máy, phiên bản Android và ứng dụng, kết quả xác thực thiết bị của Google, tín hiệu môi trường (ví dụ máy đã root, trình gỡ lỗi) và địa chỉ IP. Bản thử nghiệm hiện tại chưa gửi dữ liệu này.' },
      { tieuDe: '4. Thời hạn lưu', noiDung: 'Sự kiện bảo mật chi tiết lưu 180 ngày; địa chỉ IP chi tiết được rút gọn sau 90 ngày nếu không liên quan vi phạm; nhật ký kiểm toán lưu 24 tháng.' },
      { tieuDe: '5. Không bán, không quảng cáo theo dõi', noiDung: 'Chúng tôi không bán dữ liệu và không dùng dữ liệu để quảng cáo theo dõi. Nhà cung cấp hạ tầng: Cloudflare (máy chủ, lưu trữ), Google (xác thực thiết bị).' },
      { tieuDe: '6. Quyền của bạn', noiDung: 'Bạn có quyền được biết, truy cập, chỉnh sửa, xoá, hạn chế xử lý, rút lại đồng ý và khiếu nại. Xoá ứng dụng sẽ xoá toàn bộ dữ liệu trên máy. Gửi yêu cầu tới privacy@tsudev.com - chúng tôi phản hồi trong 72 giờ làm việc.' },
      { tieuDe: '7. Website', noiDung: 'compass.tsudev.com là trang tĩnh: không cookie theo dõi, không công cụ phân tích bên thứ ba. Cloudflare có thể ghi nhật ký kỹ thuật (IP, thời điểm) để chống tấn công.' },
      { tieuDe: '8. Trẻ em', noiDung: 'Ứng dụng dành cho người từ 13 tuổi trở lên.' },
      { tieuDe: '9. Liên hệ', noiDung: 'TsuDev - privacy@tsudev.com. Báo lỗ hổng bảo mật: security@tsudev.com.' },
    ],
  },
  khoan: {
    capNhat: 'Cập nhật: 28/10/2026',
    moTa: 'Khi cài đặt hoặc sử dụng La bàn, bạn đồng ý với các điều khoản sau.',
    muc: [
      { tieuDe: '1. Bản thử nghiệm', noiDung: 'Bản thử nghiệm được cung cấp "như hiện có" để đánh giá, có thể còn lỗi hoặc thay đổi mà không báo trước.' },
      { tieuDe: '2. Không thay thế thiết bị chuyên dụng', noiDung: 'La bàn điện thoại có thể sai do nhiễu từ hoặc cảm biến. Không dùng làm công cụ định hướng duy nhất trong tình huống nguy hiểm đến tính mạng, hàng hải hay hàng không.' },
      { tieuDe: '3. Sử dụng hợp lệ', noiDung: 'Không dịch ngược, sửa đổi, đóng gói lại, phân phối lại ứng dụng, hoặc can thiệp vào máy chủ và cơ chế bảo mật.' },
      { tieuDe: '4. Hạn chế và khiếu nại', noiDung: 'Thiết bị vi phạm có thể bị hạn chế tính năng trực tuyến trong thời hạn nhất định. Bạn có thể khiếu nại kèm mã tham chiếu REF.' },
      { tieuDe: '5. Sở hữu trí tuệ', noiDung: 'Tên, logo và mã nguồn La bàn thuộc TsuDev. Phần mềm nguồn mở bên thứ ba tuân theo giấy phép riêng, liệt kê trong màn Giấy phép của ứng dụng.' },
      { tieuDe: '6. Giới hạn trách nhiệm', noiDung: 'Trong phạm vi pháp luật cho phép, TsuDev không chịu trách nhiệm cho thiệt hại gián tiếp phát sinh từ việc sử dụng ứng dụng.' },
      { tieuDe: '7. Luật áp dụng', noiDung: 'Điều khoản điều chỉnh bởi pháp luật Việt Nam. Liên hệ: contact@tsudev.com.' },
    ],
  },
  khieu: {
    moTa: 'Nếu ứng dụng báo thiết bị của bạn bị hạn chế và hiển thị mã REF, bạn có thể khiếu nại. Chúng tôi xem xét thủ công, không tự động từ chối.',
    buoc: [
      { tieuDe: 'Ghi lại mã REF', noiDung: 'Mã dạng REF-XXXXXX hiển thị trên màn thông báo của ứng dụng.' },
      { tieuDe: 'Gửi email', noiDung: 'Bấm nút bên dưới, điền mã REF và mô tả ngắn (ví dụ: máy đã root để phát triển, dùng VPN công ty...).' },
      { tieuDe: 'Nhận phản hồi', noiDung: 'Chúng tôi phản hồi trong 3 ngày làm việc. Nếu hạn chế là nhầm, thiết bị được gỡ hạn chế và khôi phục điểm uy tín.' },
    ],
    nutEmail: 'Gửi khiếu nại qua email',
    chuDeEmail: 'Khieu nai La ban REF-',
    thanEmail: 'Mã REF: REF-\nMô tả:\n',
    luuY: 'Đừng gửi mật khẩu hay thông tin nhạy cảm. Chúng tôi không bao giờ yêu cầu bạn cài thêm ứng dụng khác.',
  },
  loi404: { tieuDe: 'Không tìm thấy trang', moTa: 'Kim la bàn chưa tìm ra đường tới trang này.', veTrangChu: 'Về trang chủ' },
};

const en: NoiDung = {
  lang: 'en',
  tenNgonNgu: 'English',
  doiNgonNgu: 'Tiếng Việt',
  boQua: 'Skip to content',
  nav: { tinhNang: 'Features', baoMat: 'Security', huongDan: 'Guide', taiVe: 'Download', menu: 'Open menu' },
  chan: { banQuyen: '© 2026 TsuDev. All rights reserved.', lienHe: 'Contact', giayPhepFont: 'Be Vietnam Pro font (OFL)', trangThai: 'Service status' },
  trang: {
    chu: { tieuDe: 'La bàn - Smart Compass, accurate and private', moTa: 'A smart compass for Android: true north from the World Magnetic Model, guided calibration, coordinates, altitude and a bubble level - no tracking ads, data encrypted on device.' },
    tai: { tieuDe: 'Download La bàn for Android - beta', moTa: 'Download the La bàn beta APK for Android with its SHA-256 checksum and step-by-step install guide.' },
    huong: { tieuDe: 'User guide and calibration - La bàn', moTa: 'How to calibrate with a figure 8, magnetic vs true north, avoiding interference and granting location the right way.' },
    rieng: { tieuDe: 'Privacy policy - La bàn', moTa: 'What La bàn collects, why, how long it is kept, and your rights under Vietnam Decree 13/2023.' },
    khoan: { tieuDe: 'Terms of use - La bàn', moTa: 'Terms for using the La bàn app and its beta builds.' },
    khieu: { tieuDe: 'Appeal a device restriction - La bàn', moTa: 'Appeal when the La bàn app reports your device is restricted, using your REF code.' },
  },
  chu: {
    nhan: 'Android · beta',
    tieuDe: 'An accurate compass,',
    tieuDeNhan: 'private by design.',
    moTa: 'True north from the World Magnetic Model, smooth 60 fps sensor fusion, fully offline. Your data is encrypted right on your device.',
    nutApk: 'Download APK for Android',
    nutPlay: 'Google Play - coming soon',
    nutIos: 'iPhone - early 2027',
    ghiChuBeta: 'The beta is being completed feature by feature. Thanks for trying it and sharing feedback.',
    soLieu: [
      { so: '±0.5°', nhan: 'target error after calibration' },
      { so: '60 FPS', nhan: 'smooth dial, battery friendly' },
      { so: '0', nhan: 'tracking ads in the beta' },
      { so: '2', nhan: 'languages: Vietnamese, English' },
    ],
    tinhNangTieuDe: 'Everything you need to find your way',
    tinhNangMoTa: 'Built for hiking, sailing, house orientation and outdoor work - readable in sunlight, easy with one hand.',
    tinhNang: [
      { icon: 'la-ban-hoa-gio', tieuDe: 'Clear compass dial', noiDung: 'Compass rose, degrees, 16 directions, light / dark themes and large text.' },
      { icon: 'bac-thuc', tieuDe: 'True and magnetic north', noiDung: 'Automatic declination for your location using an offline WMM model.' },
      { icon: 'hieu-chuan-so-8', tieuDe: 'Guided calibration', noiDung: 'Shows sensor accuracy and guides a figure-8 calibration when needed.' },
      { icon: 'ghim-gps', tieuDe: 'Coordinates and altitude', noiDung: 'DD, DMS, UTM, MGRS; GPS plus barometric altitude; speed and accuracy.', sapCo: true },
      { icon: 'thuoc-thuy', tieuDe: 'Bubble level', noiDung: 'Check level surfaces on two axes with high sensitivity.', sapCo: true },
      { icon: 'diem-moc', tieuDe: 'Waypoints and navigation', noiDung: 'Save places, see bearing and distance, import / export GPX and KML.', sapCo: true },
      { icon: 'ban-do', tieuDe: 'Offline maps', noiDung: 'Download the Vietnam map once and use it even in airplane mode.', sapCo: true },
      { icon: 'camera-ar', tieuDe: 'Camera AR', noiDung: 'Overlay headings and waypoints on the camera view.', sapCo: true },
    ],
    sapCo: 'Coming soon',
    chinhXacTieuDe: 'Accurate from sensor to number',
    chinhXacMoTa: 'Phone compasses drift because of magnetic interference and uncalibrated sensors. We handle each source of error.',
    chinhXac: [
      { tieuDe: 'Sensor fusion', noiDung: 'Magnetometer, accelerometer and gyroscope combined for a steady needle while you move.' },
      { tieuDe: 'WMM model', noiDung: 'Declination from your location and date, no network needed - true north that matches the map.' },
      { tieuDe: 'Interference warning', noiDung: 'Watches field strength (25-65 µT) and warns near magnets, metal or electronics.' },
    ],
    baoMatTieuDe: 'Private and secure by design',
    baoMatMoTa: 'No account required. Your data stays on your device, protected in layers.',
    baoMat: [
      { icon: 'khien', tieuDe: 'Encrypted on device', noiDung: 'Waypoints live in an SQLCipher database with a key wrapped by Android Keystore, excluded from cloud backups.' },
      { icon: 'cai-dat', tieuDe: 'No hardware identifiers', noiDung: 'Never reads IMEI, serial number or MAC address. No data selling, no tracking ads.' },
      { icon: 'mat-la-ban-3d', tieuDe: 'Tamper protection', noiDung: 'Detects modified builds and untrusted environments; the server decides, with a transparent appeal process.' },
      { icon: 'chia-se-qr', tieuDe: 'Safe updates', noiDung: 'Snapshot before every data migration, automatic restore on failure, safe mode after repeated crashes.' },
    ],
    loTrinhTieuDe: 'Roadmap',
    loTrinh: [
      { moc: 'October 2026', tieuDe: 'Foundation', noiDung: 'Brand, app shell, encrypted storage, backend and anomaly detection.', trangThai: 'xong' },
      { moc: 'Late 2026', tieuDe: 'Android beta', noiDung: 'Direct APK download here; sensors, dial, coordinates, waypoints.', trangThai: 'dang' },
      { moc: 'Early 2027', tieuDe: 'Google Play', noiDung: 'Official v1.0 on Google Play after an independent security test.', trangThai: 'sau' },
      { moc: 'Early 2027', tieuDe: 'iPhone', noiDung: 'iOS version on the App Store.', trangThai: 'sau' },
    ],
    trangThaiLoTrinh: { xong: 'Done', dang: 'In progress', sau: 'Planned' },
    hoiDapTieuDe: 'Frequently asked questions',
    hoiDap: [
      { tieuDe: 'Is it free?', noiDung: 'Yes. The beta is free with no ads. After launch there may be an optional Pro plan; core compass features stay free.' },
      { tieuDe: 'Why is it not on Google Play yet?', noiDung: 'The app is in beta. You can download the APK here; the Play version will use the same signature, so it updates in place.' },
      { tieuDe: 'When is the iPhone version coming?', noiDung: 'Planned for early 2027. Android comes first.' },
      { tieuDe: 'Is installing an APK outside Google Play safe?', noiDung: 'Only download from compass.tsudev.com or the official GitHub release page. Every build has a SHA-256 checksum and a fixed signing certificate you can verify.' },
      { tieuDe: 'Does it need internet?', noiDung: 'No. Compass, true north and coordinates work offline. Network is only used for sharing and update checks.' },
      { tieuDe: 'Why is the compass sometimes off?', noiDung: 'Magnetic interference (magnetic cases, cars, steel beams) or an uncalibrated sensor. See the Guide for figure-8 calibration.' },
    ],
    cuoiTieuDe: 'Ready to try it?',
    cuoiMoTa: 'Get the latest Android beta and send us your feedback.',
  },
  tai: {
    tieuDe: 'Download La bàn for Android',
    moTa: 'Beta build signed with the TsuDev release key. Pick the build that fits your phone.',
    phienBan: 'Version',
    ngay: 'Released',
    yeuCau: 'Requires',
    dungLuong: 'Size',
    banArm64: 'Recommended (arm64)',
    banArm64MoTa: 'For most Android phones from 2017 onwards. Smaller download.',
    banUniversal: 'Full build (universal)',
    banUniversalMoTa: 'Runs on every device, including older 32-bit phones. Larger download.',
    nutTai: 'Download',
    sha: 'SHA-256',
    chungChi: 'Signing certificate (SHA-256)',
    quetQr: 'Scan with your phone to open this page',
    chuaCo: 'The first beta build is being prepared. Please check back in a few minutes.',
    trongAppTieuDe: 'Open this page in Chrome',
    trongAppMoTa: 'You are viewing this inside the Zalo / Facebook / Messenger browser, which cannot download APK files ("unsupported file format"). Tap the button below, or tap ⋮ at the top and choose "Open in browser".',
    moChrome: 'Open in Chrome',
    github: 'GitHub release page',
    githubGhiChu: 'The repository is private - only project members can open the GitHub page.',
    caiTieuDe: 'Install in 4 steps',
    buocCai: [
      { tieuDe: 'Download the APK', noiDung: 'Open this page in Chrome (not inside Zalo / Facebook), then tap "Download" on the recommended build. Your browser may ask for confirmation because it is an installer - choose Download.' },
      { tieuDe: 'Allow this source', noiDung: 'Open the downloaded file. Android asks to allow your browser to install unknown apps: Settings -> enable "Allow from this source", then go back.' },
      { tieuDe: 'Install', noiDung: 'Tap Install. If Google Play Protect asks, choose "Install anyway" (the app is not on Play yet, so Play Protect does not know it).' },
      { tieuDe: 'Open and calibrate', noiDung: 'Open La bàn and follow the intro. Calibrate with a figure 8 the first time for the best accuracy.' },
    ],
    kiemTieuDe: 'Verify integrity (optional)',
    kiemMoTa: 'Compare the SHA-256 of the downloaded file with the value above. On a computer:',
    canhBao: 'Only download La bàn from compass.tsudev.com. Copies elsewhere may be modified - the app detects and restricts modified builds.',
    nenTangKhac: [
      { tieuDe: 'Google Play', noiDung: 'Coming soon - official release in early 2027.' },
      { tieuDe: 'iPhone / iPad', noiDung: 'Planned for early 2027 on the App Store.' },
    ],
  },
  huong: {
    tieuDe: 'User guide',
    moTa: 'A few minutes to get the most accurate compass.',
    muc: [
      {
        icon: 'hieu-chuan-so-8',
        tieuDe: 'Figure-8 calibration',
        noiDung: 'When the app reports low accuracy or the needle looks off:',
        buoc: ['Move about 1 m away from metal, magnets, speakers and electronics.', 'Hold the phone and draw a figure 8 in the air 3-5 times, flipping the phone as you go.', 'Wait for the accuracy indicator to turn green.'],
      },
      { icon: 'bac-thuc', tieuDe: 'True vs magnetic north', noiDung: 'Magnetic north is where a magnetic needle points; true north points to the geographic North Pole and matches maps. In Vietnam the difference is under 1 degree, but elsewhere it can exceed 10 degrees. The app shows true north by default, computed with the WMM model from your location and date.' },
      { icon: 'khien', tieuDe: 'Magnetic interference', noiDung: 'Earth\'s field is about 25-65 µT. Outside that range the app warns you: remove magnetic cases, step away from cars and steel beams, and try again.' },
      {
        icon: 'ghim-gps',
        tieuDe: 'Location permission',
        noiDung: 'Location is only needed for true north, coordinates and navigation. The app asks when you use those features, preferring approximate location while in use.',
        buoc: ['Choose "Only while using the app".', 'You may pick "Approximate location" - true north stays accurate.', 'Declining still lets you use the magnetic compass.'],
      },
      { icon: 'la-ban-hoa-gio', tieuDe: 'Reading the compass', noiDung: 'Hold the phone flat with the top pointing where you want to measure. The number in the middle is the heading of the top edge: 0° North, 90° East, 180° South, 270° West.' },
      { icon: 'cai-dat', tieuDe: 'Safe mode', noiDung: 'After repeated crashes the app opens in safe mode with core features so you can still use the compass and export data. Updating to a new version exits safe mode automatically.' },
    ],
  },
  rieng: {
    capNhat: 'Updated: 28 October 2026 · Beta-stage policy',
    moTa: 'This policy explains how the La bàn app and compass.tsudev.com (operated by TsuDev) process personal data under Vietnam Decree 13/2023/ND-CP.',
    muc: [
      { tieuDe: '1. Data on your device', noiDung: 'Waypoints, settings and history are stored in an encrypted database on your device with a key protected by Android Keystore. This data is not sent to our servers and is excluded from cloud backups.' },
      { tieuDe: '2. Location', noiDung: 'Location is processed on device for true north, coordinates and navigation; it is not sent to our servers unless you choose to share a waypoint.' },
      { tieuDe: '3. Technical security data', noiDung: 'To prevent fraud and modified builds, versions that connect to our server will send: a random installation ID (not a hardware identifier), device model, Android and app version, Google device attestation results, environment signals (for example root or debugger) and IP address. The current beta does not send this data yet.' },
      { tieuDe: '4. Retention', noiDung: 'Detailed security events are kept for 180 days; detailed IP addresses are truncated after 90 days unless tied to a violation; audit logs are kept for 24 months.' },
      { tieuDe: '5. No selling, no tracking ads', noiDung: 'We do not sell data or use it for tracking ads. Infrastructure providers: Cloudflare (servers, storage), Google (device attestation).' },
      { tieuDe: '6. Your rights', noiDung: 'You may know, access, correct, delete, restrict processing, withdraw consent and complain. Uninstalling the app deletes all on-device data. Email privacy@tsudev.com - we reply within 72 business hours.' },
      { tieuDe: '7. Website', noiDung: 'compass.tsudev.com is a static site: no tracking cookies and no third-party analytics. Cloudflare may log technical data (IP, time) to stop attacks.' },
      { tieuDe: '8. Children', noiDung: 'The app is intended for users aged 13 and over.' },
      { tieuDe: '9. Contact', noiDung: 'TsuDev - privacy@tsudev.com. Report security issues: security@tsudev.com.' },
    ],
  },
  khoan: {
    capNhat: 'Updated: 28 October 2026',
    moTa: 'By installing or using La bàn you agree to these terms.',
    muc: [
      { tieuDe: '1. Beta builds', noiDung: 'Beta builds are provided "as is" for evaluation and may contain bugs or change without notice.' },
      { tieuDe: '2. Not a professional instrument', noiDung: 'Phone compasses can be wrong due to interference or sensors. Do not rely on it as your only navigation tool in life-threatening, marine or aviation situations.' },
      { tieuDe: '3. Acceptable use', noiDung: 'Do not reverse engineer, modify, repackage or redistribute the app, or interfere with our servers and security mechanisms.' },
      { tieuDe: '4. Restrictions and appeals', noiDung: 'Violating devices may have online features restricted for a limited time. You can appeal with your REF code.' },
      { tieuDe: '5. Intellectual property', noiDung: 'The La bàn name, logo and source code belong to TsuDev. Third-party open-source software follows its own licenses, listed in the app\'s Licenses screen.' },
      { tieuDe: '6. Limitation of liability', noiDung: 'To the extent permitted by law, TsuDev is not liable for indirect damages arising from use of the app.' },
      { tieuDe: '7. Governing law', noiDung: 'These terms are governed by the laws of Vietnam. Contact: contact@tsudev.com.' },
    ],
  },
  khieu: {
    moTa: 'If the app says your device is restricted and shows a REF code, you can appeal. Appeals are reviewed by a person, never auto-rejected.',
    buoc: [
      { tieuDe: 'Note your REF code', noiDung: 'It looks like REF-XXXXXX and appears on the app\'s notice screen.' },
      { tieuDe: 'Send an email', noiDung: 'Tap the button below, fill in your REF code and a short description (for example: rooted for development, company VPN...).' },
      { tieuDe: 'Get a reply', noiDung: 'We reply within 3 business days. If the restriction was a mistake, it is lifted and your reputation score restored.' },
    ],
    nutEmail: 'Send appeal by email',
    chuDeEmail: 'La ban appeal REF-',
    thanEmail: 'REF code: REF-\nDescription:\n',
    luuY: 'Never send passwords or sensitive information. We will never ask you to install another app.',
  },
  loi404: { tieuDe: 'Page not found', moTa: 'Our compass could not find a way to this page.', veTrangChu: 'Back to home' },
};

export const NOI_DUNG: Record<NgonNgu, NoiDung> = { vi, en };
