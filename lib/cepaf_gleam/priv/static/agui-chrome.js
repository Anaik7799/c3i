// agui-chrome.js — SC-AGUI-UI-002/003 functional wiring
// Loaded on all 32 pages via shell.gleam.
// Makes the static chrome (fractal chips + AI search + Ctrl+K) actually do
// something. Per [zk-bd82645aedcb5ef4] anti-Stub-That-Lies: chrome must not
// only be present in DOM, but also responsive to user interaction.
//
// Behavior:
//   - Fractal chips (L0..L7): click to toggle active class, multiple active
//     act as filter set; clicking active chip removes it. "All" hidden if
//     no specific chips active.
//   - AI search input: filters visible .card, .section, tr elements by
//     case-insensitive text match. Empty input clears filter.
//   - Ctrl+K (or Cmd+K on mac): focus the AI search input.
//   - Esc while search focused: clear and blur.
//
// All listeners are passive — no AJAX, no backend calls. Pure client-side
// DOM filtering. Future evolution can wire to /api/v1/search.

(function () {
  'use strict';

  function ready(fn) {
    if (document.readyState !== 'loading') fn();
    else document.addEventListener('DOMContentLoaded', fn);
  }

  ready(function () {
    // --- 1. Fractal chip click handlers (SC-AGUI-UI-002) -----------------
    var chips = document.querySelectorAll('.fractal-chip');
    chips.forEach(function (chip) {
      chip.addEventListener('click', function () {
        chip.classList.toggle('active');
        applyFractalFilter();
      });
    });

    function applyFractalFilter() {
      var active = Array.from(document.querySelectorAll('.fractal-chip.active'))
        .map(function (c) {
          var m = c.className.match(/fractal-(l[0-7])/);
          return m ? m[1] : null;
        })
        .filter(Boolean);
      var cards = document.querySelectorAll('.card, .section, tr[data-layer]');
      cards.forEach(function (el) {
        if (active.length === 0) {
          el.style.display = '';
          return;
        }
        var layer = (el.getAttribute('data-layer') || '').toLowerCase();
        // Also match text content for legacy cards without data-layer.
        var text = el.textContent.toLowerCase();
        var hit = active.some(function (l) {
          return layer === l || text.indexOf(' ' + l + ' ') !== -1 || text.indexOf(l.toUpperCase()) !== -1;
        });
        el.style.display = hit ? '' : 'none';
      });
    }

    // --- 2. AI search input (SC-AGUI-UI-003) -----------------------------
    var searchInputs = document.querySelectorAll('.ai-search-input');
    searchInputs.forEach(function (input) {
      input.addEventListener('input', function () {
        var q = input.value.trim().toLowerCase();
        var targets = document.querySelectorAll('.card, .section, tr');
        targets.forEach(function (el) {
          if (q === '') {
            el.style.display = '';
            return;
          }
          var hit = el.textContent.toLowerCase().indexOf(q) !== -1;
          el.style.display = hit ? '' : 'none';
        });
      });
      input.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
          input.value = '';
          input.dispatchEvent(new Event('input'));
          input.blur();
        }
      });
    });

    // --- 3. Ctrl+K / Cmd+K shortcut -------------------------------------
    document.addEventListener('keydown', function (e) {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        var first = document.querySelector('.ai-search-input');
        if (first) first.focus();
      }
    });

    // --- 4. Drill-down detail panel (SC-AGUI-UI-004) --------------------
    var detailBody = document.getElementById('agui-detail-body');
    var detailPanel = document.querySelector('.detail-panel.drill-down');
    if (detailBody && detailPanel) {
      document.addEventListener('click', function (e) {
        var target = e.target.closest('.card, .section, tr[data-layer]');
        if (!target) return;
        if (target.closest('.agui-chrome')) return;
        var title = target.querySelector('.section-title, .card-title, td:first-child');
        var label = title ? title.textContent.trim() : target.tagName.toLowerCase();
        var snippet = target.textContent.trim().slice(0, 280);
        detailBody.textContent = '[' + label + '] ' + snippet;
        detailPanel.setAttribute('data-state', 'populated');
      });
    }

    // --- 5. Visible-state marker for conformance validator --------------
    // Sets data-agui-wired="1" on body so future probes can detect that
    // chrome is interactive, not just static.
    document.body.setAttribute('data-agui-wired', '1');
  });
})();
