// C3I Dashboard Data Grid — Agentic UI with real-time updates
// Cloned from planning-grid.js, adapted for system overview data
// SC-AGUI-UI-001, SC-GLM-UI-001

(function() {
  "use strict";

  var API_BASE = "";
  var ws = null;
  var wsConnected = false;
  var lastRefreshTime = Date.now();

  // Inject CSS
  var style = document.createElement("style");
  style.textContent = [
    "@keyframes fadeIn{0%{opacity:0;transform:translateY(-6px)}100%{opacity:1;transform:translateY(0)}}",
    "@keyframes pulse{0%,100%{opacity:1}50%{opacity:0.6}}",
    ".view-toggle{display:flex;gap:4px;background:rgba(10,14,23,0.6);backdrop-filter:blur(12px);border:1px solid rgba(30,42,58,0.6);border-radius:10px;padding:4px;overflow-x:auto}",
    ".view-btn{padding:10px 16px;border:none;background:transparent;color:#7a8fa6;border-radius:8px;cursor:pointer;font-size:0.82rem;font-weight:600;transition:all 0.2s;min-height:44px;white-space:nowrap}",
    ".view-btn:hover{color:#e0e6ed;background:rgba(0,212,170,0.06)}",
    ".view-btn.active{background:linear-gradient(135deg,rgba(0,212,170,0.15),rgba(0,212,170,0.08));color:#00d4aa}",
    ".dash-search{flex:1;background:rgba(10,14,23,0.6);border:1px solid rgba(30,42,58,0.6);color:#e0e6ed;padding:11px 18px;border-radius:10px;font-size:0.92rem;outline:none;min-height:44px}",
    ".dash-chat{height:320px;background:rgba(10,14,23,0.4);border:1px solid rgba(30,42,58,0.4);border-radius:10px;overflow:hidden;display:flex;flex-direction:column}",
    ".dash-chat-msgs{flex:1;overflow-y:auto;padding:10px;font-size:0.82rem}",
    ".dash-chat-input{display:flex;gap:6px;padding:8px;border-top:1px solid rgba(30,42,58,0.4)}",
    ".change-feed{max-height:200px;overflow-y:auto;background:rgba(10,14,23,0.4);border:1px solid rgba(30,42,58,0.4);border-radius:10px;padding:10px;font-size:0.75rem}",
  ].join("\n");
  document.head.appendChild(style);

  // WebSocket for real-time dashboard updates
  function initWebSocket() {
    try {
      var protocol = location.protocol === "https:" ? "wss:" : "ws:";
      ws = new WebSocket(protocol + "//" + location.host + "/ws/planning");
      ws.onopen = function() {
        wsConnected = true;
        var indicator = document.getElementById("dash-ws-status");
        if (indicator) indicator.innerHTML = "<span style='color:#3dd68c'>WebSocket live</span>";
        // Start 1s ping
        setInterval(function() { if (ws && ws.readyState === 1) ws.send("ping"); }, 1000);
      };
      ws.onmessage = function(e) {
        lastRefreshTime = Date.now();
        try {
          var msg = JSON.parse(e.data);
          if (msg.type === "update" || msg.type === "connected") {
            updateDashboardFromWS(msg);
          }
        } catch(ex) {}
      };
      ws.onclose = function() {
        wsConnected = false;
        var indicator = document.getElementById("dash-ws-status");
        if (indicator) indicator.innerHTML = "<span style='color:#ff4757'>Reconnecting...</span>";
        setTimeout(initWebSocket, 3000);
      };
    } catch(ex) {}
  }

  function updateDashboardFromWS(msg) {
    var statusStr = msg.status || "{}";
    try {
      var s = JSON.parse(statusStr);
      var el = document.getElementById("dash-task-summary");
      if (el) {
        el.innerHTML = "<span style='color:#3dd68c'>" + (s.completed||0) + "</span> done · " +
          "<span style='color:#00d4aa'>" + (s.active||0) + "</span> active · " +
          "<span style='color:#ff4757'>" + (s.blocked||0) + "</span> blocked · " +
          "<span style='color:#7a8fa6'>" + (s.pending||0) + "</span> pending · " +
          "<b>" + (s.total||0) + "</b> total";
      }
    } catch(ex) {}
  }

  // Gemma AI Chat for dashboard
  function initChat() {
    var container = document.getElementById("dash-ai-chat");
    if (!container) return;
    container.innerHTML =
      "<div class='dash-chat'>" +
      "<div class='dash-chat-msgs' id='dash-chat-msgs'>" +
      "<div style='color:#7a8fa6;text-align:center;padding:20px'>Ask Gemma about system status...</div></div>" +
      "<div class='dash-chat-input'>" +
      "<input id='dash-chat-in' type='text' placeholder='Ask Gemma...' class='dash-search' style='min-height:40px'>" +
      "<button id='dash-chat-send' style='background:linear-gradient(135deg,#00d4aa,#00b894);color:#0a0e17;border:none;padding:10px 18px;border-radius:8px;font-weight:700;min-height:40px;cursor:pointer'>Send</button>" +
      "</div></div>";
    var input = document.getElementById("dash-chat-in");
    var btn = document.getElementById("dash-chat-send");
    if (input && btn) {
      btn.onclick = function() { sendChat(input.value.trim()); input.value = ""; };
      input.onkeydown = function(e) { if (e.key === "Enter") btn.click(); };
    }
  }

  function sendChat(query) {
    if (!query) return;
    var msgs = document.getElementById("dash-chat-msgs");
    if (!msgs) return;
    msgs.innerHTML += "<div style='padding:6px;margin:4px 0;background:rgba(224,230,237,0.05);border-radius:6px'><b style='color:#e0e6ed;font-size:0.7rem'>You</b><div>" + query + "</div></div>";
    msgs.innerHTML += "<div id='typing' style='color:#7a8fa6;padding:4px'>Thinking...</div>";
    msgs.scrollTop = msgs.scrollHeight;

    fetch(API_BASE + "/api/v1/plan/status").then(function(r){return r.json()}).then(function(status) {
      return fetch("http://localhost:11434/api/chat", {
        method: "POST",
        headers: {"Content-Type":"application/json"},
        body: JSON.stringify({
          model: "gemma3",
          messages: [
            {role:"system", content:"You are C3I dashboard AI. System: " + JSON.stringify(status) + ". Be concise."},
            {role:"user", content: query}
          ],
          stream: false,
          options: {temperature:0.3, num_predict:150}
        })
      });
    }).then(function(r){return r.json()}).then(function(data) {
      var t = document.getElementById("typing"); if(t) t.remove();
      var content = (data.message && data.message.content) || "No response";
      msgs.innerHTML += "<div style='padding:6px;margin:4px 0;background:rgba(0,212,170,0.05);border-radius:6px'><b style='color:#00d4aa;font-size:0.7rem'>Gemma 3</b><div>" + content + "</div></div>";
      msgs.scrollTop = msgs.scrollHeight;
    }).catch(function() {
      var t = document.getElementById("typing"); if(t) t.remove();
      msgs.innerHTML += "<div style='color:#ff4757;padding:4px'>AI unavailable</div>";
    });
  }

  // Periodic status refresh
  function refreshStatus() {
    fetch(API_BASE + "/api/v1/plan/status").then(function(r){return r.json()}).then(function(s) {
      updateDashboardFromWS({type:"update", status: JSON.stringify(s)});
    }).catch(function(){});
  }

  // Init
  initWebSocket();
  initChat();
  setInterval(function() { if (!wsConnected) refreshStatus(); }, 5000);
  refreshStatus();
})();
