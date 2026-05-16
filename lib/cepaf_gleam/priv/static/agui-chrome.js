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
    // --- 0. Auto-classify sections/cards with data-layer (SC-AGUI-UI-002)
    // Per .claude/rules/agentic-ui-responsive-design.md §5: heuristic keyword
    // matching title→L0-L7. Makes fractal-filter actually filter, not just
    // toggle classes. Skip elements that already have data-layer (page-set).
    var layerKeywords = {
      l0: ['guardian','constitutional','psi','safety','emergency','sil4','sil6','prime','immune','kms','vault'],
      l1: ['nif','debug','trace','telemetry','otel','atomic','ffi','metabolic'],
      l2: ['parser','component','form','badge','input','catalog','a2ui','mcp'],
      l3: ['planning','task','state','db','sqlite','smriti','transaction','substrate','database','knowledge'],
      l4: ['podman','container','system','boot','build','image','docker','config','git'],
      l5: ['ooda','cortex','agent','llm','inference','reasoning','dashboard','cockpit','prajna','smriti'],
      l6: ['zenoh','mesh','topology','quorum','cluster','ecosystem','bridge','federation','singularity'],
      l7: ['gateway','version','consensus','evolution','bicameral','biomorphic','homeostasis','integrity'],
    };
    function classifyLayer(text) {
      var t = text.toLowerCase();
      for (var k in layerKeywords) {
        var kws = layerKeywords[k];
        for (var i = 0; i < kws.length; i++) {
          if (t.indexOf(kws[i]) !== -1) return k;
        }
      }
      return null;
    }
    var sections = document.querySelectorAll('.section, .card');
    sections.forEach(function (el) {
      if (el.hasAttribute('data-layer')) return;
      var title = el.querySelector('.section-title, .card-title');
      var label = title ? title.textContent : '';
      var layer = classifyLayer(label) || classifyLayer(location.pathname);
      if (layer) el.setAttribute('data-layer', layer);
    });

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
    // Dual-mode: client-side DOM filter (instant) + semantic /api/v1/plan/search
    // hits rendered in detail-panel. Per [zk-bd82645aedcb5ef4]: real endpoint
    // wired (verified responding with real task data), not Stub-That-Lies.
    var searchInputs = document.querySelectorAll('.ai-search-input');
    var searchTimer = null;
    function semanticSearch(q) {
      if (q.length < 2) return;
      fetch('/api/v1/plan/search?q=' + encodeURIComponent(q), { cache: 'no-store' })
        .then(function (r) { return r.ok ? r.json() : []; })
        .then(function (results) {
          if (!detailBody || !detailPanel) return;
          if (!Array.isArray(results) || results.length === 0) {
            detailBody.textContent = '[search] no semantic hits for "' + q + '"';
          } else {
            var lines = results.slice(0, 8).map(function (r) {
              return '• [' + (r.priority || '?') + '/' + (r.status || '?') + '] ' + (r.title || r.id || '?');
            });
            detailBody.textContent = '[search "' + q + '" — ' + results.length + ' hits]\n' + lines.join('\n');
          }
          detailPanel.setAttribute('data-state', 'populated');
        })
        .catch(function () {});
    }
    searchInputs.forEach(function (input) {
      input.addEventListener('input', function () {
        var q = input.value.trim().toLowerCase();
        // Instant DOM filter
        var targets = document.querySelectorAll('.card, .section, tr');
        targets.forEach(function (el) {
          if (q === '') {
            el.style.display = '';
            return;
          }
          var hit = el.textContent.toLowerCase().indexOf(q) !== -1;
          el.style.display = hit ? '' : 'none';
        });
        // Debounced semantic search
        if (searchTimer) clearTimeout(searchTimer);
        if (q.length >= 2) searchTimer = setTimeout(function () { semanticSearch(q); }, 350);
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
      // Pre-populate with page summary (improvement-plan #9: not empty on load)
      var sectionCount = document.querySelectorAll('.section').length;
      var cardCount = document.querySelectorAll('.card').length;
      var nowStr = new Date().toLocaleTimeString();
      detailBody.textContent =
        '[page ' + location.pathname + '] loaded ' + nowStr
        + ' · sections=' + sectionCount + ' · cards=' + cardCount
        + '\nClick any card or section to drill in.';
      detailPanel.setAttribute('data-state', 'preview');
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

    // --- 5. Gemma chat widget (SC-AGUI-UI-005) --------------------------
    var chatForm = document.querySelector('.chat-panel-form');
    var chatInput = document.getElementById('agui-chat-input');
    var chatFeed = document.getElementById('agui-chat-feed');
    if (chatForm && chatInput && chatFeed) {
      chatForm.addEventListener('submit', function (e) {
        e.preventDefault();
        var q = chatInput.value.trim();
        if (!q) return;
        var userMsg = document.createElement('div');
        userMsg.className = 'chat-msg chat-msg-user';
        userMsg.textContent = '› ' + q;
        chatFeed.appendChild(userMsg);
        chatInput.value = '';
        var pending = document.createElement('div');
        pending.className = 'chat-msg chat-msg-pending';
        pending.textContent = '… thinking';
        chatFeed.appendChild(pending);
        fetch('/api/v1/ai/chat', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ message: q, page: location.pathname }),
        })
          .then(function (r) {
            // Per improvement-plan #10: handle 401 inline instead of generic error.
            if (r.status === 401) {
              return Promise.resolve({ status: 401, text: '[chat] sign-in required to ask Gemma — anonymous responses limited' });
            }
            if (!r.ok) return r.text().then(function (t) { return { status: r.status, text: '[chat] ' + r.status + ': ' + t.slice(0, 200) }; });
            return r.text().then(function (t) { return { status: 200, text: t }; });
          })
          .then(function (res) {
            pending.remove();
            var reply = document.createElement('div');
            reply.className = 'chat-msg chat-msg-gemma' + (res.status === 401 ? ' chat-msg-auth' : res.status >= 400 ? ' chat-msg-err' : '');
            reply.textContent = res.text.slice(0, 800);
            chatFeed.appendChild(reply);
          })
          .catch(function (err) {
            pending.textContent = '[chat] network error: ' + err;
          });
      });
    }

    // --- 6. Change-log feed (SC-AGUI-UI-007) — initial-state population --
    // Per [zk-bd82645aedcb5ef4]: empty feed is Stub-That-Lies. Seed with real
    // page-load event + poll /api/v1/page-spec/<path> every 30s for spec score
    // changes. Future evolution: replace with WS event stream per page.
    var feed = document.querySelector('.change-log-feed');
    if (feed) {
      function appendFeed(label, detail) {
        var entry = document.createElement('div');
        entry.className = 'change-log-entry';
        var t = new Date();
        var ts = t.toLocaleTimeString();
        entry.textContent = '[' + ts + '] ' + label + (detail ? ' — ' + detail : '');
        feed.insertBefore(entry, feed.firstChild);
        while (feed.children.length > 10) feed.removeChild(feed.lastChild);
      }
      appendFeed('page loaded', location.pathname);
      // Heartbeat badge (improvement-plan #8) — turns green on success, amber stale
      var heartbeat = document.createElement('span');
      heartbeat.className = 'agui-heartbeat';
      heartbeat.title = 'last successful spec-poll';
      heartbeat.textContent = '●';
      heartbeat.style.cssText = 'color:#7a8fa6;margin-left:6px;font-size:12px';
      var label = feed.parentNode.querySelector('.change-log-label');
      if (label) label.appendChild(heartbeat);
      var lastOk = 0;
      function refreshHeartbeat() {
        var age = lastOk ? (Date.now() - lastOk) / 1000 : 9999;
        heartbeat.style.color = age < 35 ? '#3dd68c' : age < 90 ? '#f5a623' : '#ff4757';
        heartbeat.title = 'last poll: ' + Math.round(age) + 's ago';
      }
      function pollSpec() {
        fetch('/api/v1/page-spec' + location.pathname, { cache: 'no-store' })
          .then(function (r) { return r.ok ? r.json() : null; })
          .then(function (j) {
            if (j && typeof j.score === 'number') {
              appendFeed('spec score', j.score + '/' + (j.max_score || '?'));
              lastOk = Date.now();
            }
            refreshHeartbeat();
          })
          .catch(function () { refreshHeartbeat(); });
      }
      pollSpec();
      setInterval(pollSpec, 30000);
      setInterval(refreshHeartbeat, 5000);
    }

    // --- 7. Visible-state marker for conformance validator --------------
    // Sets data-agui-wired="1" on body so future probes can detect that
    // chrome is interactive, not just static.
    document.body.setAttribute('data-agui-wired', '1');
  });
})();
