// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Murat Çeliker
//
// Adds a copy button to every code block. Built in script rather than markup so
// the two language pages do not have to carry duplicate copies of it.

(function () {
  var turkish = document.documentElement.lang === 'tr';
  var LABEL = turkish ? 'Kopyala' : 'Copy';
  var DONE = turkish ? 'Kopyalandı' : 'Copied';
  var FAILED = turkish ? 'Kopyalanamadı' : 'Copy failed';

  document.querySelectorAll('pre').forEach(function (pre) {
    var wrap = document.createElement('div');
    wrap.className = 'code';
    pre.parentNode.insertBefore(wrap, pre);
    wrap.appendChild(pre);

    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'copy';
    button.textContent = LABEL;
    wrap.appendChild(button);

    var timer;
    button.addEventListener('click', function () {
      var text = pre.textContent.trim();
      var settle = function (message, ok) {
        button.textContent = message;
        button.classList.toggle('done', ok);
        clearTimeout(timer);
        timer = setTimeout(function () {
          button.textContent = LABEL;
          button.classList.remove('done');
        }, 1600);
      };

      // Only available over https and with permission; fall back to the old
      // selection-based copy so the button still works where it is not.
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(
          function () { settle(DONE, true); },
          function () { settle(legacyCopy(text) ? DONE : FAILED, true); }
        );
      } else {
        settle(legacyCopy(text) ? DONE : FAILED, true);
      }
    });
  });

  function legacyCopy(text) {
    var field = document.createElement('textarea');
    field.value = text;
    field.setAttribute('readonly', '');
    field.style.position = 'fixed';
    field.style.opacity = '0';
    document.body.appendChild(field);
    field.select();
    var ok = false;
    try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
    document.body.removeChild(field);
    return ok;
  }
})();
