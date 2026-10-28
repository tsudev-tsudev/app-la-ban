// Khung Durable Object khai báo ở N2 để binding + migration có sẵn; hành vi thật ở S1 (nonce, rate) và S6 (SOC realtime).
// Lớp kiểu cũ (không kế thừa `cloudflare:workers`) để vitest chạy được ngoài workerd.
function chuaHoTro(): Response {
  return new Response(JSON.stringify({ type: 'about:blank', title: 'Not Implemented', status: 501 }), {
    status: 501,
    headers: { 'content-type': 'application/problem+json' },
  });
}

export class KhoNonce {
  async fetch(): Promise<Response> {
    return chuaHoTro();
  }
}

export class GioiHanToc {
  async fetch(): Promise<Response> {
    return chuaHoTro();
  }
}

export class PhongSoc {
  async fetch(): Promise<Response> {
    return chuaHoTro();
  }
}
