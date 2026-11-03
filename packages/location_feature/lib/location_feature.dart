/// Vị trí và telemetry: tọa độ, cao độ, từ trường, thước thủy.
library;

// Thiên văn chuyển sang sensors (A9a - la bàn Mặt Trời / Mặt Trăng dùng chung); giữ API cũ của gói.
export 'package:sensors/sensors.dart'
    show
        PhaTrang,
        SuKienNgay,
        TenPhaTrang,
        ViTriBauTroi,
        khucXa,
        ngayJulius,
        nguongMatTroi,
        phaMatTrang,
        suKienMatTrang,
        suKienMatTroi,
        tenPha,
        viTriMatTrang,
        viTriMatTroi;

export 'src/domain/cao_do.dart';
export 'src/domain/dia_gioi.dart';
export 'src/domain/doc_vi_tri.dart';
export 'src/domain/geoid.dart';
export 'src/domain/thuoc_thuy.dart';
export 'src/domain/toa_do.dart';
export 'src/domain/tu_truong.dart';
export 'src/domain/tuy_chon_vi_tri.dart';
export 'src/du_lieu/nguon_vi_tri.dart';
export 'src/giay_phep_du_lieu.dart';
export 'src/hien_thi.dart';
export 'src/man_vi_tri.dart';
export 'src/the_vi_tri.dart';
export 'src/vi_tri_provider.dart';
