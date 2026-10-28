// Hàm THUẦN: nội dung design/icons/*.svg -> chuỗi Dart vẽ bằng Path (QUYET_DINH Q30). Không đọc ghi tệp.
// Mọi lệnh path (kể cả tương đối, S/T phản chiếu điểm điều khiển) được quy về toạ độ TUYỆT ĐỐI lúc sinh,
// nên mã Dart chỉ dùng moveTo / lineTo / cubicTo / quadraticBezierTo / arcToPoint / close.

const SO = /[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?/y;
const SO_THAM_SO = { M: 2, L: 2, H: 1, V: 1, C: 6, S: 4, Q: 4, T: 2, A: 7, Z: 0 };

/** Tách chuỗi `d` thành [{lenh, so: number[]}] (giữ hoa / thường). Cờ của A được đọc từng ký tự (`a7 7 0 0114 0`). */
export function tachPath(d) {
  const kq = [];
  let i = 0;
  let lenh = null;
  const boQua = () => {
    while (i < d.length && /[\s,]/.test(d[i])) i++;
  };
  const docSo = () => {
    boQua();
    SO.lastIndex = i;
    const m = SO.exec(d);
    if (!m) throw new Error(`path lỗi ở vị trí ${i}: "${d.slice(i, i + 12)}"`);
    i = SO.lastIndex;
    return Number(m[0]);
  };
  const docCo = () => {
    boQua();
    const c = d[i];
    if (c !== '0' && c !== '1') throw new Error(`cờ arc phải là 0/1 ở vị trí ${i}`);
    i++;
    return Number(c);
  };
  for (;;) {
    boQua();
    if (i >= d.length) break;
    const c = d[i];
    if (/[a-zA-Z]/.test(c)) {
      if (!(c.toUpperCase() in SO_THAM_SO)) throw new Error(`lệnh path không hỗ trợ: ${c}`);
      lenh = c;
      i++;
      if (lenh.toUpperCase() === 'Z') {
        kq.push({ lenh, so: [] });
        continue;
      }
    } else if (lenh === null) {
      throw new Error('path phải bắt đầu bằng lệnh');
    } else if (lenh.toUpperCase() === 'Z') {
      throw new Error('số sau Z');
    }
    const n = SO_THAM_SO[lenh.toUpperCase()];
    const so = [];
    for (let k = 0; k < n; k++)
      so.push(lenh.toUpperCase() === 'A' && (k === 3 || k === 4) ? docCo() : docSo());
    kq.push({ lenh, so });
    // Cặp toạ độ thừa sau M được hiểu là L (đặc tả SVG).
    if (lenh === 'M') lenh = 'L';
    else if (lenh === 'm') lenh = 'l';
  }
  return kq;
}

/** Quy về lệnh tuyệt đối: [{op: 'M'|'L'|'C'|'Q'|'A'|'Z', so}] - H/V -> L, S -> C, T -> Q. */
export function tuyetDoi(dsLenh) {
  const kq = [];
  let x = 0;
  let y = 0;
  let dauX = 0;
  let dauY = 0;
  let dkC = null; // điểm điều khiển thứ 2 của C/S trước đó
  let dkQ = null; // điểm điều khiển của Q/T trước đó
  for (const { lenh, so } of dsLenh) {
    const tuongDoi = lenh === lenh.toLowerCase();
    const L = lenh.toUpperCase();
    const ox = tuongDoi ? x : 0;
    const oy = tuongDoi ? y : 0;
    let moiC = null;
    let moiQ = null;
    switch (L) {
      case 'M':
        x = so[0] + ox;
        y = so[1] + oy;
        dauX = x;
        dauY = y;
        kq.push({ op: 'M', so: [x, y] });
        break;
      case 'L':
        x = so[0] + ox;
        y = so[1] + oy;
        kq.push({ op: 'L', so: [x, y] });
        break;
      case 'H':
        x = so[0] + ox;
        kq.push({ op: 'L', so: [x, y] });
        break;
      case 'V':
        y = so[0] + oy;
        kq.push({ op: 'L', so: [x, y] });
        break;
      case 'C': {
        const p = [so[0] + ox, so[1] + oy, so[2] + ox, so[3] + oy, so[4] + ox, so[5] + oy];
        kq.push({ op: 'C', so: p });
        moiC = [p[2], p[3]];
        [x, y] = [p[4], p[5]];
        break;
      }
      case 'S': {
        const c1 = dkC ? [2 * x - dkC[0], 2 * y - dkC[1]] : [x, y];
        const p = [...c1, so[0] + ox, so[1] + oy, so[2] + ox, so[3] + oy];
        kq.push({ op: 'C', so: p });
        moiC = [p[2], p[3]];
        [x, y] = [p[4], p[5]];
        break;
      }
      case 'Q': {
        const p = [so[0] + ox, so[1] + oy, so[2] + ox, so[3] + oy];
        kq.push({ op: 'Q', so: p });
        moiQ = [p[0], p[1]];
        [x, y] = [p[2], p[3]];
        break;
      }
      case 'T': {
        const c = dkQ ? [2 * x - dkQ[0], 2 * y - dkQ[1]] : [x, y];
        const p = [...c, so[0] + ox, so[1] + oy];
        kq.push({ op: 'Q', so: p });
        moiQ = c;
        [x, y] = [p[2], p[3]];
        break;
      }
      case 'A': {
        x = so[5] + ox;
        y = so[6] + oy;
        kq.push({ op: 'A', so: [so[0], so[1], so[2], so[3], so[4], x, y] });
        break;
      }
      case 'Z':
        kq.push({ op: 'Z', so: [] });
        x = dauX;
        y = dauY;
        break;
    }
    dkC = moiC;
    dkQ = moiQ;
  }
  return kq;
}

/** Số -> literal Dart gọn (tối đa 4 chữ số thập phân, bỏ số 0 thừa). */
export function soDart(n) {
  const r = Math.round(n * 1e4) / 1e4;
  return String(Object.is(r, -0) ? 0 : r);
}

function thuocTinh(the) {
  const kq = {};
  for (const m of the.matchAll(/([a-zA-Z-]+)="([^"]*)"/g)) kq[m[1]] = m[2];
  return kq;
}

/** Nội dung SVG -> danh sách câu lệnh Dart thao tác trên biến `p` (Path). */
export function cauLenhIcon(svg) {
  const than = svg.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
  const ds = [];
  const n = (v) => soDart(Number(v ?? 0));
  for (const m of than.matchAll(/<(path|circle|rect|ellipse)\b([^>]*)\/?>/g)) {
    const a = thuocTinh(m[2]);
    switch (m[1]) {
      case 'path':
        for (const { op, so } of tuyetDoi(tachPath(a.d ?? ''))) {
          const s = so.map(soDart);
          if (op === 'M') ds.push(`p.moveTo(${s[0]}, ${s[1]});`);
          else if (op === 'L') ds.push(`p.lineTo(${s[0]}, ${s[1]});`);
          else if (op === 'C') ds.push(`p.cubicTo(${s.join(', ')});`);
          else if (op === 'Q') ds.push(`p.quadraticBezierTo(${s.join(', ')});`);
          else if (op === 'Z') ds.push('p.close();');
          else
            ds.push(
              `p.arcToPoint(const Offset(${s[5]}, ${s[6]}), radius: const Radius.elliptical(${s[0]}, ${s[1]}), ` +
                `rotation: ${s[2]}, largeArc: ${so[3] === 1}, clockwise: ${so[4] === 1});`,
            );
        }
        break;
      case 'circle':
        ds.push(
          `p.addOval(Rect.fromCircle(center: const Offset(${n(a.cx)}, ${n(a.cy)}), radius: ${n(a.r)}));`,
        );
        break;
      case 'ellipse':
        ds.push(
          `p.addOval(Rect.fromCenter(center: const Offset(${n(a.cx)}, ${n(a.cy)}), width: ${soDart(2 * Number(a.rx))}, height: ${soDart(2 * Number(a.ry))}));`,
        );
        break;
      case 'rect': {
        const rx = a.rx ?? a.ry;
        const ry = a.ry ?? a.rx;
        const hcn = `Rect.fromLTWH(${n(a.x)}, ${n(a.y)}, ${n(a.width)}, ${n(a.height)})`;
        if (rx === undefined) ds.push(`p.addRect(${hcn});`);
        else
          ds.push(
            `p.addRRect(RRect.fromRectAndRadius(${hcn}, const Radius.elliptical(${n(rx)}, ${n(ry)})));`,
          );
        break;
      }
    }
  }
  if (!ds.length) throw new Error('SVG không có hình nào');
  return ds;
}

/** 'hieu-chuan-so-8' -> 'hieuChuanSo8'. */
export function tenDart(ten) {
  return ten.replace(/-([a-z0-9])/g, (_, c) => c.toUpperCase());
}

/** {tenTep: noiDungSvg} -> mã Dart của lb_icons.g.dart (chưa format). */
export function sinhIconDart(dsIcon) {
  const ten = Object.keys(dsIcon).sort();
  const hang = ten
    .map(
      (t) =>
        `  /// \`design/icons/${t}.svg\`\n  static const ${tenDart(t)} = LbIconData('${t}', _${tenDart(t)});`,
    )
    .join('\n');
  const ham = ten
    .map(
      (t) =>
        `void _${tenDart(t)}(Path p) {\n${cauLenhIcon(dsIcon[t])
          .map((c) => `  ${c}`)
          .join('\n')}\n}`,
    )
    .join('\n\n');
  return `// TỆP SINH - đừng sửa tay. Nguồn: design/icons/*.svg · lệnh: node tools/build/icon-dart.mjs

import 'dart:ui';

import 'package:design_system/src/icons/lb_icon_data.dart';

/// Bộ icon 24dp (khung 24 x 24, vẽ nét). Dùng với \`LbIcon\`.
abstract final class LbIcons {
${hang}

  /// Mọi icon, theo tên tệp.
  static const all = <LbIconData>[${ten.map(tenDart).join(', ')}];
}

${ham}
`;
}
