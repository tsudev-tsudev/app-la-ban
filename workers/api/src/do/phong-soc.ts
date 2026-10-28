// DO PhongSoc: kênh realtime cho Admin SOC (WebSocket hibernation) - làm ở S6. Hiện trả 501.
// Lớp kiểu cũ (không kế thừa `cloudflare:workers`) để vitest chạy được ngoài workerd.
export class PhongSoc {
  async fetch(): Promise<Response> {
    return new Response(JSON.stringify({ type: 'about:blank', title: 'Not Implemented', status: 501 }), {
      status: 501,
      headers: { 'content-type': 'application/problem+json' },
    });
  }
}
