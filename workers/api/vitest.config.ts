import { defineConfig } from 'vitest/config';

// Máy dev chạy song song flutter test / gradle (WSL, không card đồ hoạ): test nặng (s10a - mã hoá sao lưu, chuỗi audit)
// có lúc vượt 5 s mặc định -> nâng ngưỡng, không đổi logic test.
export default defineConfig({ test: { testTimeout: 20_000 } });
