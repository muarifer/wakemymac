// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Murat Çeliker
//
// Screenshot slider. Dots and arrows are built here rather than in markup so
// the two language pages stay identical apart from their text, and so the page
// still shows the first capture when JavaScript does not run.

(function () {
  var slider = document.querySelector('[data-slider]');
  if (!slider) { return; }

  var slides = Array.prototype.slice.call(slider.querySelectorAll('.slide'));
  if (slides.length < 2) { return; }

  var turkish = document.documentElement.lang === 'tr';
  var caption = slider.querySelector('.slider-caption');
  var nav = slider.querySelector('.slider-nav');
  var index = 0;

  var prev = button('‹', turkish ? 'Önceki' : 'Previous', function () { go(index - 1); });
  var dots = document.createElement('div');
  dots.className = 'dots';
  var next = button('›', turkish ? 'Sonraki' : 'Next', function () { go(index + 1); });

  slides.forEach(function (slide, i) {
    var dot = document.createElement('button');
    dot.type = 'button';
    dot.setAttribute('aria-label', (turkish ? 'Görsel ' : 'Screenshot ') + (i + 1));
    dot.addEventListener('click', function () { go(i); });
    dots.appendChild(dot);
  });

  nav.appendChild(prev);
  nav.appendChild(dots);
  nav.appendChild(next);

  function button(glyph, label, onClick) {
    var el = document.createElement('button');
    el.type = 'button';
    el.className = 'arrow';
    el.textContent = glyph;
    el.setAttribute('aria-label', label);
    el.addEventListener('click', onClick);
    return el;
  }

  function go(target) {
    index = (target + slides.length) % slides.length;
    slides.forEach(function (slide, i) {
      slide.classList.toggle('is-active', i === index);
      slide.setAttribute('aria-hidden', String(i !== index));
    });
    Array.prototype.forEach.call(dots.children, function (dot, i) {
      dot.setAttribute('aria-current', String(i === index));
    });
    if (caption) { caption.textContent = slides[index].dataset.caption || ''; }
  }

  // Retires the no-JavaScript fallback that keeps the first slide visible.
  slider.classList.add('ready');
  slider.setAttribute('tabindex', '0');
  slider.addEventListener('keydown', function (event) {
    if (event.key === 'ArrowLeft') { go(index - 1); event.preventDefault(); }
    if (event.key === 'ArrowRight') { go(index + 1); event.preventDefault(); }
  });

  // Horizontal swipe, ignoring gestures that are mostly vertical scrolling.
  var startX = null, startY = null;
  slider.addEventListener('touchstart', function (e) {
    startX = e.touches[0].clientX;
    startY = e.touches[0].clientY;
  }, { passive: true });
  slider.addEventListener('touchend', function (e) {
    if (startX === null) { return; }
    var dx = e.changedTouches[0].clientX - startX;
    var dy = e.changedTouches[0].clientY - startY;
    if (Math.abs(dx) > 40 && Math.abs(dx) > Math.abs(dy)) { go(index + (dx < 0 ? 1 : -1)); }
    startX = startY = null;
  }, { passive: true });

  go(0);
})();
