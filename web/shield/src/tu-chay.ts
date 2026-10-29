// Điểm vào bản đóng gói `/js/khien.js` (IIFE, tệp NGOÀI để nhận nonce CSP): `<script src="/js/khien.js" data-trang="admin">`.
import { khoiDong } from './khien';
import { chuanHoaTrang } from './muc';

const API = 'https://compass-api.tsudev.com';

const the = document.currentScript;
khoiDong({ trang: chuanHoaTrang(the instanceof HTMLScriptElement ? the.dataset.trang : undefined), api: API });
