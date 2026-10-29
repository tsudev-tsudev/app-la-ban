// Hàm thuần: danh sách mục ở gốc dist -> `_routes.json` (Pages). Mọi đường dẫn gọi worker TRỪ tài sản tĩnh: thư mục không
// chứa trang HTML và tệp không phải HTML ở gốc. Thư mục trang (`/tai-ve/`, `/en/`...) vẫn qua worker để gắn nonce.
const THU_MUC_TINH = new Set(['_astro', 'fonts', 'js', '.well-known']);

/** @param {{ten: string, thuMuc: boolean}[]} muc @returns {{version: 1, include: string[], exclude: string[]}} */
export function tuyenWorker(muc) {
  const exclude = [];
  for (const { ten, thuMuc } of [...muc].sort((a, b) => a.ten.localeCompare(b.ten))) {
    if (ten.startsWith('_') && !thuMuc) continue;
    if (thuMuc) {
      if (THU_MUC_TINH.has(ten)) exclude.push(`/${ten}/*`);
    } else if (!/\.html$/.test(ten)) {
      exclude.push(`/${ten}`);
    }
  }
  if (exclude.length > 99) throw new Error(`_routes.json quá 100 luật (${exclude.length + 1})`);
  return { version: 1, include: ['/*'], exclude };
}
