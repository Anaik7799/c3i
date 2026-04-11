// अन्धकारात् प्रकाशं प्राप्नोति — From darkness one reaches light
// C3I Dark Cockpit — Operator Primary View
// SC-HMI-010, SC-AGUI-UI-001, SC-GLM-UI-010
// Only shows anomalies. Silence = health. Light = alarm.
(function() {
  "use strict";

  var WS_PATH = "/ws/dashboard";
  var RECONNECT_BASE = 1000;
  var RECONNECT_MAX = 30000;
  var ws = null;
  var reconnectDelay = RECONNECT_BASE;
  var reconnectTimer = null;
  var lastMessageTime = Date.now();
  var cockpitMode = "dark";
  var healthScore = 1.0;
  var alarms = [];

  // ─── CSS (शैली) ───
  function initCSS() {
    var s = document.createElement("style");
    s.textContent = [
      ":root{--bg:#0a0e17;--card:#141922;--text:#e0e6ed;--muted:#7a8fa6;--border:#1e2a3a;--accent:#00d4aa}",
      ".cockpit-mode-dark{background:#0a0e17;color:#7a8fa6}",
      ".cockpit-mode-dim{background:#0e1320;color:#b8a95a}",
      ".cockpit-mode-normal{background:#0a0e17;color:#e0e6ed}",
      ".cockpit-mode-bright{background:#1a1510;color:#ffd93d}",
      ".cockpit-mode-emergency{background:#1a0a0a;color:#ff4757;animation:emergencyPulse 1s infinite}",
      "@keyframes emergencyPulse{0%,100%{opacity:1}50%{opacity:0.7}}",
      "@keyframes fadeIn{from{opacity:0}to{opacity:1}}",
      ".cockpit-health-ring{display:flex;justify-content:center;margin:20px 0}",
      ".alarm-item{padding:8px 12px;margin:4px 0;border-radius:6px;font-size:0.8rem;font-family:'JetBrains Mono',monospace;animation:fadeIn 0.3s}",
      ".alarm-critical{background:rgba(255,71,87,0.15);border-left:3px solid #ff4757;color:#ff4757}",
      ".alarm-warning{background:rgba(245,166,35,0.15);border-left:3px solid #f5a623;color:#f5a623}",
      ".alarm-caution{background:rgba(255,217,61,0.15);border-left:3px solid #ffd93d;color:#ffd93d}",
      ".alarm-advisory{background:rgba(77,150,255,0.15);border-left:3px solid #4d96ff;color:#4d96ff}",
      ".alarm-normal{background:rgba(61,214,140,0.05);border-left:3px solid #1e2a3a;color:#7a8fa6}",
      ".node-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(120px,1fr));gap:6px}",
      ".node-card{padding:6px 10px;border-radius:6px;font-size:0.75rem;text-align:center}",
      ".node-connected{background:rgba(61,214,140,0.1);border:1px solid rgba(61,214,140,0.3);color:#3dd68c}",
      ".node-stale{background:rgba(245,166,35,0.1);border:1px solid rgba(245,166,35,0.3);color:#f5a623}",
      ".node-degraded{background:rgba(255,71,87,0.1);border:1px solid rgba(255,71,87,0.3);color:#ff4757}",
      ".node-disconnected{background:rgba(122,143,166,0.1);border:1px solid rgba(122,143,166,0.3);color:#7a8fa6}",
      ".heartbeat-live{width:8px;height:8px;border-radius:50%;background:#3dd68c;animation:pulse 1s infinite}",
      ".heartbeat-stale{width:8px;height:8px;border-radius:50%;background:#f5a623}",
      ".heartbeat-dead{width:8px;height:8px;border-radius:50%;background:#ff4757}",
      "@keyframes pulse{0%,100%{opacity:1}50%{opacity:0.3}}",
      "@media(max-width:768px){.node-grid{grid-template-columns:repeat(2,1fr)}}",
      "@media(min-width:1400px){.node-grid{grid-template-columns:repeat(8,1fr)}}"
    ].join("\n");
    document.head.appendChild(s);
  }

  // ─── WebSocket (सम्पर्क) ───
  function initWS() {
    if (reconnectTimer) { clearTimeout(reconnectTimer); reconnectTimer = null; }
    var protocol = location.protocol === "https:" ? "wss:" : "ws:";
    try { ws = new WebSocket(protocol + "//" + location.host + WS_PATH); } catch(e) { scheduleReconnect(); return; }

    ws.onopen = function() {
      reconnectDelay = RECONNECT_BASE;
      lastMessageTime = Date.now();
      updateStatus("Connected", true);
      setInterval(function() { if (ws && ws.readyState === 1) ws.send("ping"); }, 1000);
    };
    ws.onmessage = function(e) {
      lastMessageTime = Date.now();
      try { handleMsg(JSON.parse(e.data)); } catch(err) {}
    };
    ws.onclose = function() { updateStatus("Disconnected", false); scheduleReconnect(); };
    ws.onerror = function() {};
  }

  function scheduleReconnect() {
    reconnectTimer = setTimeout(function() {
      reconnectDelay = Math.min(reconnectDelay * 2, RECONNECT_MAX);
      initWS();
    }, reconnectDelay);
  }

  // ─── Message Handler (संदेश) ───
  function handleMsg(msg) {
    if (msg.type === "connected" || msg.type === "update") {
      updateDashboardData(msg);
    }
  }

  function updateDashboardData(msg) {
    var el = document.getElementById("cockpit-task-summary");
    if (!el) return;
    try {
      var snap = typeof msg.snapshot === "string" ? JSON.parse(msg.snapshot) : (msg.snapshot || {});
      var st = typeof snap.plan_status === "string" ? JSON.parse(snap.plan_status) : (snap.plan_status || {});
      var total = st.total || 0;
      var blocked = st.blocked || 0;
      var active = st.in_progress || 0;
      // Health score: simple heuristic
      healthScore = total > 0 ? Math.max(0, 1 - (blocked / total) - (active > 10 ? 0.2 : 0)) : 0.95;
      updateCockpitMode();
      el.innerHTML = blocked > 0
        ? '<span style="color:#ff4757">' + blocked + ' BLOCKED</span> | <span style="color:#00d4aa">' + active + ' active</span> | ' + total + ' total'
        : '<span style="color:#3dd68c">All nominal</span> — ' + total + ' tasks, ' + active + ' active';
    } catch(e) { el.textContent = "Receiving data..."; }
  }

  // ─── Cockpit Mode (कॉकपिट मोड) ───
  function updateCockpitMode() {
    var newMode = healthScore >= 0.9 ? "dark" : healthScore >= 0.7 ? "dim" : healthScore >= 0.5 ? "normal" : healthScore >= 0.3 ? "bright" : "emergency";
    if (newMode !== cockpitMode) {
      cockpitMode = newMode;
      var body = document.body;
      body.className = body.className.replace(/cockpit-mode-\w+/g, "") + " cockpit-mode-" + cockpitMode;
      var modeEl = document.getElementById("cockpit-mode-display");
      if (modeEl) {
        var colors = { dark: "#3dd68c", dim: "#f5a623", normal: "#e0e6ed", bright: "#ffd93d", emergency: "#ff4757" };
        modeEl.innerHTML = '<span style="color:' + (colors[cockpitMode] || "#e0e6ed") + ';font-weight:700;text-transform:uppercase">' + cockpitMode + '</span>';
      }
    }
    var scoreEl = document.getElementById("cockpit-health-score");
    if (scoreEl) scoreEl.textContent = (healthScore * 100).toFixed(0) + "%";
  }

  function updateStatus(text, connected) {
    var el = document.getElementById("cockpit-ws-status");
    if (el) { el.textContent = text; el.style.color = connected ? "#3dd68c" : "#ff4757"; }
  }

  // ─── Heartbeat (हृदयस्पन्दन) ───
  setInterval(function() {
    var hb = document.getElementById("cockpit-heartbeat");
    if (!hb) return;
    var elapsed = Date.now() - lastMessageTime;
    hb.className = elapsed < 3000 ? "heartbeat-live" : elapsed < 10000 ? "heartbeat-stale" : "heartbeat-dead";
  }, 500);

  // ─── Alarm Fetch (अलार्म) ───
  function fetchAlarms() {
    fetch("/api/v1/cockpit/alarms")
      .then(function(r) { return r.json(); })
      .then(function(data) {
        alarms = data.alarms || [];
        renderAlarms();
      })
      .catch(function() {});
  }

  function renderAlarms() {
    var container = document.getElementById("cockpit-alarms");
    if (!container) return;
    if (alarms.length === 0) {
      container.innerHTML = '<div style="color:#3dd68c;font-size:0.8rem;padding:12px;text-align:center">No alarms — system in homeostasis</div>';
      return;
    }
    var html = "";
    var order = ["critical","warning","caution","advisory","normal"];
    alarms.sort(function(a, b) { return order.indexOf(a.level) - order.indexOf(b.level); });
    for (var i = 0; i < alarms.length; i++) {
      var a = alarms[i];
      html += '<div class="alarm-item alarm-' + a.level + '">[' + a.source + '] ' + a.message + '</div>';
    }
    container.innerHTML = html;
  }

  // ─── Init (आरम्भ) ───
  function init() {
    initCSS();
    initWS();
    fetchAlarms();
    setInterval(fetchAlarms, 30000);
    updateCockpitMode();
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
