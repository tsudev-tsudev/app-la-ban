import { test } from 'node:test';
import assert from 'node:assert/strict';
import { tachPath, tuyetDoi, soDart, cauLenhIcon, tenDart, sinhIconDart } from './icon-dart-sinh.mjs';

const svg = (than) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">${than}</svg>`;

test('tachPath: số dính nhau, dấu chấm đầu, cặp thừa sau M thành L', () => {
  assert.deepEqual(tachPath('M12 21s-7-6.2-7-11.5'), [
    { lenh: 'M', so: [12, 21] },
    { lenh: 's', so: [-7, -6.2, -7, -11.5] },
  ]);
  assert.deepEqual(tachPath('M14 21v-.01'), [
    { lenh: 'M', so: [14, 21] },
    { lenh: 'v', so: [-0.01] },
  ]);
  assert.deepEqual(tachPath('M1 2 3 4m1 1 2 2'), [
    { lenh: 'M', so: [1, 2] },
    { lenh: 'L', so: [3, 4] },
    { lenh: 'm', so: [1, 1] },
    { lenh: 'l', so: [2, 2] },
  ]);
  assert.deepEqual(tachPath('M0 0L1e1 2.5E-1z'), [
    { lenh: 'M', so: [0, 0] },
    { lenh: 'L', so: [10, 0.25] },
    { lenh: 'z', so: [] },
  ]);
});

test('tachPath: cờ arc đọc từng ký tự, báo lỗi lệnh lạ', () => {
  assert.deepEqual(tachPath('M5 9a7 7 0 0114 0'), [
    { lenh: 'M', so: [5, 9] },
    { lenh: 'a', so: [7, 7, 0, 0, 1, 14, 0] },
  ]);
  assert.throws(() => tachPath('M0 0 B1 1'), /không hỗ trợ/);
  assert.throws(() => tachPath('1 1'), /bắt đầu bằng lệnh/);
  assert.throws(() => tachPath('M0 0a1 1 0 2 1 3 3'), /cờ arc/);
});

test('tuyetDoi: đủ M/L/H/V/C/S/Q/T/A/Z cả hoa và thường', () => {
  const kq = tuyetDoi(tachPath('M1 1h2v3H0V0l1 1L2 2z m1 1 c1 0 1 1 0 1s-1 1 0 2C0 0 0 0 0 0S1 1 2 2'));
  assert.deepEqual(kq.slice(0, 8), [
    { op: 'M', so: [1, 1] },
    { op: 'L', so: [3, 1] },
    { op: 'L', so: [3, 4] },
    { op: 'L', so: [0, 4] },
    { op: 'L', so: [0, 0] },
    { op: 'L', so: [1, 1] },
    { op: 'L', so: [2, 2] },
    { op: 'Z', so: [] },
  ]);
  // Sau Z bút về điểm đầu (1,1) -> m1 1 = (2,2).
  assert.deepEqual(kq[8], { op: 'M', so: [2, 2] });
  assert.deepEqual(kq[9], { op: 'C', so: [3, 2, 3, 3, 2, 3] });
  // S phản chiếu điểm điều khiển (3,3) qua (2,3) -> (1,3).
  assert.deepEqual(kq[10], { op: 'C', so: [1, 3, 1, 4, 2, 5] });
  assert.deepEqual(kq[11], { op: 'C', so: [0, 0, 0, 0, 0, 0] });
  // S sau C: phản chiếu (0,0) qua (0,0).
  assert.deepEqual(kq[12], { op: 'C', so: [0, 0, 1, 1, 2, 2] });

  const q = tuyetDoi(tachPath('M0 0Q1 2 2 0T4 0t2 0q1 1 2 0T10 0'));
  assert.deepEqual(q, [
    { op: 'M', so: [0, 0] },
    { op: 'Q', so: [1, 2, 2, 0] },
    { op: 'Q', so: [3, -2, 4, 0] },
    { op: 'Q', so: [5, 2, 6, 0] },
    { op: 'Q', so: [7, 1, 8, 0] },
    { op: 'Q', so: [9, -1, 10, 0] },
  ]);
  // S / T không đứng sau C / Q: điểm điều khiển = điểm hiện tại.
  assert.deepEqual(tuyetDoi(tachPath('M1 1S2 2 3 3'))[1], { op: 'C', so: [1, 1, 2, 2, 3, 3] });
  assert.deepEqual(tuyetDoi(tachPath('M1 1T3 3'))[1], { op: 'Q', so: [1, 1, 3, 3] });

  assert.deepEqual(tuyetDoi(tachPath('M5 9a7 7 0 0 1 14 0A2 3 30 1 0 1 1')), [
    { op: 'M', so: [5, 9] },
    { op: 'A', so: [7, 7, 0, 0, 1, 19, 9] },
    { op: 'A', so: [2, 3, 30, 1, 0, 1, 1] },
  ]);
});

test('soDart gọn và không có -0', () => {
  assert.equal(soDart(12), '12');
  assert.equal(soDart(0.30000000000000004), '0.3');
  assert.equal(soDart(-0.00001), '0');
  assert.equal(soDart(-6.25), '-6.25');
});

test('cauLenhIcon: circle / ellipse / rect (có và không rx) / chấm v.01 vẫn giữ', () => {
  assert.deepEqual(cauLenhIcon(svg('<circle cx="12" cy="9.5" r="2.5"/>')), [
    'p.addOval(Rect.fromCircle(center: const Offset(12, 9.5), radius: 2.5));',
  ]);
  assert.deepEqual(cauLenhIcon(svg('<ellipse cx="12" cy="11" rx="9" ry="5"/>')), [
    'p.addOval(Rect.fromCenter(center: const Offset(12, 11), width: 18, height: 10));',
  ]);
  assert.deepEqual(
    cauLenhIcon(svg('<rect x="3" y="3" width="7" height="7" rx="1"/><rect width="2" height="2"/>')),
    [
      'p.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(3, 3, 7, 7), const Radius.elliptical(1, 1)));',
      'p.addRect(Rect.fromLTWH(0, 0, 2, 2));',
    ],
  );
  assert.deepEqual(cauLenhIcon(svg('<path d="M21 14v.01"/>')), ['p.moveTo(21, 14);', 'p.lineTo(21, 14.01);']);
  assert.deepEqual(cauLenhIcon(svg('<path d="M5 9a7 7 0 0 1 14 0z"/>')), [
    'p.moveTo(5, 9);',
    'p.arcToPoint(const Offset(19, 9), radius: const Radius.elliptical(7, 7), rotation: 0, largeArc: false, clockwise: true);',
    'p.close();',
  ]);
  assert.throws(() => cauLenhIcon(svg('<g/>')), /không có hình/);
});

test('sinhIconDart: tên camelCase, danh sách all theo thứ tự tên', () => {
  assert.equal(tenDart('hieu-chuan-so-8'), 'hieuChuanSo8');
  const ma = sinhIconDart({ 'b-c': svg('<path d="M0 0L1 1"/>'), a: svg('<circle cx="1" cy="1" r="1"/>') });
  assert.match(ma, /static const bC = LbIconData\('b-c', _bC\);/);
  assert.match(ma, /static const all = <LbIconData>\[a, bC\];/);
  assert.match(ma, /void _a\(Path p\) \{\n {2}p\.addOval/);
});
