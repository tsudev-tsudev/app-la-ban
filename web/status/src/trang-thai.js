const API = 'https://compass-api.tsudev.com/v1/health';

async function kiemTra() {
  const nhan = document.getElementById('api');
  const build = document.getElementById('build');
  if (!nhan || !build) return;
  try {
    const res = await fetch(API, { cache: 'no-store', credentials: 'omit' });
    const du = res.ok ? await res.json() : null;
    if (du && du.ok === true) {
      nhan.textContent = 'Hoạt động / Operational';
      nhan.className = 'nhan tot';
      build.textContent = 'Build: ' + String(du.build).slice(0, 12);
      return;
    }
  } catch {
    nhan.className = 'nhan loi';
  }
  nhan.textContent = 'Sự cố / Outage';
  nhan.className = 'nhan loi';
}

kiemTra();
