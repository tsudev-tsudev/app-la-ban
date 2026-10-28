(function () {
  var ua = navigator.userAgent || '';
  if (!/Zalo|FBAN|FBAV|FB_IAB|FBIOS|Messenger|Instagram|Line\/|MicroMessenger|TikTok|musical_ly|; wv\)/i.test(ua)) return;
  var b = document.getElementById('trong-app');
  if (b) b.hidden = false;
})();
