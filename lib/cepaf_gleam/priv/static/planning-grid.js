// C3I Planning Data Grid — Feature-Rich Tabulator 6.3
// Fetches live data from Rust Smriti API via Zenoh mesh
// Robust to failure, auto-retry, export, analytics, row-level refresh
// SC-TODO-001, SC-GLM-UI-001, SC-ZENOH-001

(function() {
  "use strict";

  // ═══════════════════════════════════════════════════════════════
  // Configuration
  // ═══════════════════════════════════════════════════════════════

  var API_BASE = "";
  var RETRY_COUNT = 3;
  var RETRY_DELAY_MS = 1000;
  var REFRESH_INTERVAL_MS = 60000;
  var ACTIVE_REFRESH_MS = 1000;
  var refreshTimer = null;
  var activeTimer = null;
  var lastRefreshTime = Date.now();
  var refreshCount = 0;

  // Grid instance registry
  var grids = {
    blocked: null,
    active: null,
    all: null
  };

  // Previous data snapshots for diff detection
  var prevSnapshots = {
    blocked: {},
    active: {},
    all: {}
  };

  // ═══════════════════════════════════════════════════════════════
  // Column Definitions
  // ═══════════════════════════════════════════════════════════════

  function taskAge(created) {
    if (!created) return "—";
    var diff = Date.now() - new Date(created).getTime();
    var mins = Math.floor(diff / 60000);
    if (mins < 60) return mins + "m";
    var hours = Math.floor(mins / 60);
    if (hours < 24) return hours + "h";
    var days = Math.floor(hours / 24);
    if (days < 30) return days + "d";
    return Math.floor(days / 30) + "mo";
  }

  var taskColumns = [
    {title:"ID", field:"id", width:80, headerSort:true,
     formatter:function(c){
       var v = c.getValue();
       return "<span style='font-family:\"JetBrains Mono\",monospace;font-size:0.7rem;opacity:0.7'>" + v.substring(0,8) + "</span>";
     },
     tooltip:function(e,c){return "Full: " + c.getValue();}
    },
    {title:"Pri", field:"priority", width:70, headerFilter:"select",
     headerFilterParams:{values:{"":"All","P0":"P0","P1":"P1","P2":"P2","P3":"P3"}},
     headerSort:true,
     formatter:function(c){
       var v=c.getValue();
       var styles={
         "P0":"background:linear-gradient(135deg,#ff4757,#c0392b);color:#fff;box-shadow:0 2px 8px rgba(255,71,87,0.3);",
         "P1":"background:linear-gradient(135deg,#ffa502,#e67e22);color:#1a1000;box-shadow:0 2px 8px rgba(255,165,2,0.2);",
         "P2":"background:linear-gradient(135deg,#2ed573,#00b894);color:#081008;",
         "P3":"background:rgba(122,143,166,0.12);color:#7a8fa6;border:1px solid rgba(122,143,166,0.15);"
       };
       var icons={"P0":"\u26a0","P1":"\u25b2","P2":"\u25cf","P3":"\u25cb"};
       return "<span style='"+styles[v]+"padding:2px 8px;border-radius:10px;font-size:0.7rem;font-weight:700;display:inline-flex;align-items:center;gap:3px;letter-spacing:0.5px'>"+icons[v]+" "+v+"</span>";
     },
     sorter:function(a,b){
       var order={"P0":0,"P1":1,"P2":2,"P3":3};
       return (order[a]||9) - (order[b]||9);
     }
    },
    {title:"Status", field:"status", width:110, headerFilter:"select",
     headerFilterParams:{values:{"":"All","pending":"Pending","in_progress":"Active","completed":"Done","blocked":"Blocked"}},
     headerSort:true,
     formatter:function(c){
       var v=c.getValue();
       var configs={
         "completed":{bg:"rgba(61,214,140,0.15)",color:"#3dd68c",icon:"\u2713",label:"Done",cls:""},
         "blocked":{bg:"rgba(255,71,87,0.12)",color:"#ff4757",icon:"\u2717",label:"Blocked",cls:"pulse-blocked"},
         "in_progress":{bg:"rgba(0,212,170,0.15)",color:"#00d4aa",icon:"\u25b6",label:"Active",cls:"pulse-active"},
         "pending":{bg:"rgba(122,143,166,0.06)",color:"#7a8fa6",icon:"\u25cb",label:"Pending",cls:""}
       };
       var cfg=configs[v]||configs["pending"];
       return "<span class='"+cfg.cls+"' style='background:"+cfg.bg+";color:"+cfg.color+";padding:2px 8px;border-radius:10px;font-size:0.7rem;font-weight:600;display:inline-flex;align-items:center;gap:3px'>"+cfg.icon+" "+cfg.label+"</span>";
     }
    },
    {title:"Description", field:"title", minWidth:320, headerFilter:"input",
     headerFilterPlaceholder:"Filter...",
     formatter:function(c){
       var v = c.getValue() || "";
       // Highlight STAMP refs
       var hl = v.replace(/(SC-[A-Z]+-\d+)/g, "<span style='color:#00d4aa;font-weight:600'>$1</span>");
       return "<span style='font-size:0.82rem;line-height:1.4'>" + hl + "</span>";
     },
     tooltip:true
    },
    {title:"Age", field:"created", width:60, headerSort:true,
     formatter:function(c){ return "<span style='color:#7a8fa6;font-size:0.72rem'>" + taskAge(c.getValue()) + "</span>"; },
     sorter:"date",
     headerTooltip:"Time since task creation"
    },
    {title:"Owner", field:"owner", width:90,
     formatter:function(c){
       var v = c.getValue();
       if (!v) return "<span style='color:rgba(122,143,166,0.4);font-size:0.75rem'>—</span>";
       return "<span style='font-size:0.78rem'>" + v + "</span>";
     }
    }
  ];

  // ═══════════════════════════════════════════════════════════════
  // Inject animations CSS
  // ═══════════════════════════════════════════════════════════════

  var styleEl = document.createElement("style");
  styleEl.textContent =
    "@keyframes rowPulse { 0%{background:rgba(0,212,170,0.15)} 100%{background:transparent} }" +
    "@keyframes pulseActive { 0%,100%{opacity:1} 50%{opacity:0.7} }" +
    "@keyframes pulseBlocked { 0%,100%{opacity:1} 50%{opacity:0.6} }" +
    ".pulse-active{animation:pulseActive 2s ease-in-out infinite}" +
    ".pulse-blocked{animation:pulseBlocked 3s ease-in-out infinite}" +
    ".row-changed{animation:rowPulse 1.5s ease-out}" +
    ".tabulator-row{cursor:pointer;transition:background 0.2s}" +
    ".tabulator-row:hover{background:rgba(0,212,170,0.06)!important}" +
    ".tabulator-row.tabulator-selected{background:rgba(0,212,170,0.12)!important}" +
    ".heartbeat-dot{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:6px;transition:background 0.3s}" +
    ".heartbeat-live{background:#3dd68c;box-shadow:0 0 6px rgba(61,214,140,0.5)}" +
    ".heartbeat-stale{background:#f5a623}" +
    ".heartbeat-dead{background:#ff4757}" +
    "#grid-status{font-family:'JetBrains Mono',monospace}";
  document.head.appendChild(styleEl);

  // ═══════════════════════════════════════════════════════════════
  // Fetch with retry + error handling
  // ═══════════════════════════════════════════════════════════════

  function fetchWithRetry(url, retries) {
    return fetch(url).then(function(r) {
      if (!r.ok) throw new Error("HTTP " + r.status);
      return r.json();
    }).catch(function(err) {
      if (retries > 0) {
        return new Promise(function(resolve) {
          setTimeout(function() { resolve(fetchWithRetry(url, retries - 1)); }, RETRY_DELAY_MS * (RETRY_COUNT - retries + 1));
        });
      }
      throw err;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // Status bar with heartbeat
  // ═══════════════════════════════════════════════════════════════

  function updateStatusBar(msg, type) {
    var bar = document.getElementById("grid-status");
    if (!bar) return;
    var colors = {ok:"#3dd68c", loading:"#f5a623", error:"#ff4757"};
    var dot = "<span class='heartbeat-dot heartbeat-" + (type === "ok" ? "live" : type === "loading" ? "stale" : "dead") + "'></span>";
    bar.innerHTML = dot + "<span style='color:" + (colors[type] || "#7a8fa6") + "'>" + msg + "</span>";
  }

  // Live countdown timer
  function startCountdown() {
    setInterval(function() {
      var bar = document.getElementById("grid-status");
      if (!bar) return;
      var elapsed = Math.floor((Date.now() - lastRefreshTime) / 1000);
      var countdownEl = document.getElementById("refresh-countdown");
      if (countdownEl) {
        countdownEl.textContent = elapsed + "s ago";
        countdownEl.style.color = elapsed < 5 ? "#3dd68c" : elapsed < 30 ? "#f5a623" : "#ff4757";
      }
    }, 1000);
  }

  // ═══════════════════════════════════════════════════════════════
  // Data snapshot + diff for row-level change detection
  // ═══════════════════════════════════════════════════════════════

  function snapshotData(data) {
    var snap = {};
    data.forEach(function(t) { snap[t.id] = t.status + "|" + t.priority + "|" + (t.title || ""); });
    return snap;
  }

  function findChangedIds(oldSnap, newSnap) {
    var changed = [];
    Object.keys(newSnap).forEach(function(id) {
      if (!oldSnap[id] || oldSnap[id] !== newSnap[id]) changed.push(id);
    });
    return changed;
  }

  function highlightChangedRows(gridInstance, changedIds) {
    if (!gridInstance || changedIds.length === 0) return;
    try {
      gridInstance.getRows().forEach(function(row) {
        var data = row.getData();
        if (changedIds.indexOf(data.id) >= 0) {
          var el = row.getElement();
          el.classList.remove("row-changed");
          void el.offsetWidth; // force reflow
          el.classList.add("row-changed");
        }
      });
    } catch(e) {}
  }

  // ═══════════════════════════════════════════════════════════════
  // Grid factory
  // ═══════════════════════════════════════════════════════════════

  function createGrid(selector, data, opts) {
    var defaults = {
      data: data,
      columns: taskColumns,
      layout: "fitColumns",
      placeholder: "No tasks",
      headerSortTristate: true,
      movableColumns: true,
      selectable: true,
      rowClick: function(e, row) {
        showTaskDetail(row.getData());
      }
    };
    Object.keys(opts || {}).forEach(function(k) { defaults[k] = opts[k]; });
    return new Tabulator(selector, defaults);
  }

  // ═══════════════════════════════════════════════════════════════
  // Grid initialization
  // ═══════════════════════════════════════════════════════════════

  function initGrids() {
    if (typeof Tabulator === "undefined") {
      setTimeout(initGrids, 200);
      return;
    }

    updateStatusBar("Connecting to Smriti...", "loading");

    Promise.all([
      fetchWithRetry(API_BASE + "/api/v1/plan/list/blocked", RETRY_COUNT),
      fetchWithRetry(API_BASE + "/api/v1/plan/list/in_progress", RETRY_COUNT),
      fetchWithRetry(API_BASE + "/api/v1/plan/list/all", RETRY_COUNT)
    ]).then(function(results) {
      var blockedData = results[0] || [];
      var activeData = results[1] || [];
      var allData = results[2] || [];

      refreshCount++;
      lastRefreshTime = Date.now();
      var stats = blockedData.length + " blocked | " + activeData.length + " active | " + allData.length + " total";

      // Store snapshots
      prevSnapshots.blocked = snapshotData(blockedData);
      prevSnapshots.active = snapshotData(activeData);
      prevSnapshots.all = snapshotData(allData);

      updateStatusBar(stats + "  \u00b7  " + new Date().toLocaleTimeString() + "  \u00b7  <span id='refresh-countdown' style='font-size:0.75rem'>0s ago</span>", "ok");
      startCountdown();

      // ── Blocked Tasks Grid ──
      var blockedEl = document.getElementById("blocked-grid");
      if (blockedEl) {
        if (blockedData.length > 0) {
          grids.blocked = createGrid("#blocked-grid", blockedData, {
            height: Math.min(blockedData.length * 38 + 55, 300)
          });
        } else {
          blockedEl.innerHTML = "<div style='text-align:center;padding:16px;color:#3dd68c;border:1px dashed rgba(61,214,140,0.2);border-radius:8px'>\u2713 No blocked tasks — all clear</div>";
        }
      }

      // ── Active Tasks Grid ──
      var activeEl = document.getElementById("active-grid");
      if (activeEl) {
        if (activeData.length > 0) {
          grids.active = createGrid("#active-grid", activeData, {
            height: Math.min(activeData.length * 38 + 55, 350)
          });
        } else {
          activeEl.innerHTML = "<div style='text-align:center;padding:16px;color:#7a8fa6;border:1px dashed rgba(122,143,166,0.15);border-radius:8px'>No active tasks</div>";
        }
      }

      // ── All Tasks Grid (paginated, full-featured) ──
      var allEl = document.getElementById("all-grid");
      if (allEl) {
        grids.all = createGrid("#all-grid", allData, {
          height: 480,
          pagination: "local",
          paginationSize: 25,
          paginationSizeSelector: [10, 25, 50, 100, true],
          paginationCounter: "rows",
          initialSort: [{column:"priority", dir:"asc"}],
          footerElement:
            "<div style='padding:4px 8px;display:flex;align-items:center;gap:8px'>" +
            "<button id='export-csv' style='background:var(--accent,#00d4aa);color:#0a0e17;border:none;padding:4px 12px;border-radius:6px;cursor:pointer;font-size:0.78rem;font-weight:600'>CSV</button>" +
            "<button id='export-json' style='background:transparent;color:#00d4aa;border:1px solid rgba(0,212,170,0.3);padding:4px 12px;border-radius:6px;cursor:pointer;font-size:0.78rem'>JSON</button>" +
            "<button id='refresh-btn' style='background:transparent;color:#f5a623;border:1px solid rgba(245,166,35,0.3);padding:4px 12px;border-radius:6px;cursor:pointer;font-size:0.78rem'>\u21bb Refresh</button>" +
            "<span style='flex:1'></span>" +
            "<span style='color:#7a8fa6;font-size:0.72rem'>#" + refreshCount + " refreshes</span>" +
            "</div>",
          dataLoaded: function() {
            setTimeout(function() {
              var csvBtn = document.getElementById("export-csv");
              var jsonBtn = document.getElementById("export-json");
              var refreshBtn = document.getElementById("refresh-btn");
              if (csvBtn) csvBtn.onclick = function() { grids.all.download("csv", "c3i-tasks.csv"); };
              if (jsonBtn) jsonBtn.onclick = function() { grids.all.download("json", "c3i-tasks.json"); };
              if (refreshBtn) refreshBtn.onclick = function() { loadAndRefreshAll(); };
            }, 100);
          }
        });
        window._c3iAllGrid = grids.all; // backward compat
      }

      // Analytics + mini chart
      var analytics = computeAnalytics(allData);
      renderAnalyticsBadges(analytics);
      renderMiniChart(analytics);

    }).catch(function(err) {
      console.error("Grid init failed:", err);
      updateStatusBar("Connection failed: " + err.message + " \u2014 retrying in 5s...", "error");
      setTimeout(initGrids, 5000);
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // Analytics computation
  // ═══════════════════════════════════════════════════════════════

  function computeAnalytics(data) {
    var total = data.length;
    var byStatus = {pending:0, in_progress:0, completed:0, blocked:0};
    var byPriority = {P0:0, P1:0, P2:0, P3:0};
    var oldestActive = null;

    data.forEach(function(t) {
      if (byStatus[t.status] !== undefined) byStatus[t.status]++;
      if (byPriority[t.priority] !== undefined) byPriority[t.priority]++;
      if (t.status === "in_progress" && t.created) {
        var age = Date.now() - new Date(t.created).getTime();
        if (!oldestActive || age > oldestActive) oldestActive = age;
      }
    });

    return {
      total: total,
      completionRate: total > 0 ? ((byStatus.completed / total) * 100).toFixed(1) : "0",
      blockedRate: total > 0 ? ((byStatus.blocked / total) * 100).toFixed(1) : "0",
      activeRate: total > 0 ? ((byStatus.in_progress / total) * 100).toFixed(1) : "0",
      velocity: byStatus.completed,
      oldestActive: oldestActive ? Math.floor(oldestActive / 86400000) + "d" : "—",
      byStatus: byStatus,
      byPriority: byPriority
    };
  }

  function renderAnalyticsBadges(a) {
    var container = document.getElementById("grid-analytics");
    if (!container) return;
    container.innerHTML =
      "<div style='display:flex;flex-wrap:wrap;gap:12px;align-items:center'>" +
      badge("#e0e6ed", a.total, "Total") +
      badge("#3dd68c", a.byStatus.completed, "Done " + a.completionRate + "%") +
      badge("#00d4aa", a.byStatus.in_progress, "Active") +
      badge("#ff4757", a.byStatus.blocked, "Blocked") +
      badge("#7a8fa6", a.byStatus.pending, "Pending") +
      "<span style='border-left:1px solid rgba(122,143,166,0.2);height:20px;margin:0 4px'></span>" +
      priBadge("#ff4757", "P0", a.byPriority.P0) +
      priBadge("#ffa502", "P1", a.byPriority.P1) +
      priBadge("#2ed573", "P2", a.byPriority.P2) +
      priBadge("#7a8fa6", "P3", a.byPriority.P3) +
      "<span style='border-left:1px solid rgba(122,143,166,0.2);height:20px;margin:0 4px'></span>" +
      "<span style='color:#7a8fa6;font-size:0.72rem'>Oldest active: " + a.oldestActive + "</span>" +
      "</div>";
  }

  function badge(color, count, label) {
    return "<span style='font-size:0.78rem'><b style='color:" + color + "'>" + count + "</b> <span style='color:#7a8fa6'>" + label + "</span></span>";
  }

  function priBadge(color, label, count) {
    return "<span style='color:" + color + ";font-size:0.72rem;font-weight:700'>" + label + "</span><span style='color:#7a8fa6;font-size:0.72rem;margin-right:4px'>:" + count + "</span>";
  }

  // Mini stacked bar chart
  function renderMiniChart(a) {
    var container = document.getElementById("grid-minichart");
    if (!container) return;
    var total = a.total || 1;
    var pcts = {
      completed: (a.byStatus.completed / total * 100).toFixed(1),
      active: (a.byStatus.in_progress / total * 100).toFixed(1),
      blocked: (a.byStatus.blocked / total * 100).toFixed(1),
      pending: (a.byStatus.pending / total * 100).toFixed(1)
    };
    container.innerHTML =
      "<div style='display:flex;height:6px;border-radius:3px;overflow:hidden;background:rgba(122,143,166,0.08);margin:8px 0'>" +
      "<div style='width:" + pcts.completed + "%;background:#3dd68c;transition:width 0.5s' title='Done: " + pcts.completed + "%'></div>" +
      "<div style='width:" + pcts.active + "%;background:#00d4aa;transition:width 0.5s' title='Active: " + pcts.active + "%'></div>" +
      "<div style='width:" + pcts.blocked + "%;background:#ff4757;transition:width 0.5s' title='Blocked: " + pcts.blocked + "%'></div>" +
      "<div style='width:" + pcts.pending + "%;background:rgba(122,143,166,0.15);transition:width 0.5s' title='Pending: " + pcts.pending + "%'></div>" +
      "</div>";
  }

  // ═══════════════════════════════════════════════════════════════
  // Refresh functions (with row-level change highlighting)
  // ═══════════════════════════════════════════════════════════════

  function loadAndRefreshAll() {
    updateStatusBar("Refreshing all grids...", "loading");
    Promise.all([
      fetchWithRetry(API_BASE + "/api/v1/plan/list/blocked", 1),
      fetchWithRetry(API_BASE + "/api/v1/plan/list/in_progress", 1),
      fetchWithRetry(API_BASE + "/api/v1/plan/list/all", RETRY_COUNT)
    ]).then(function(results) {
      var blockedData = results[0] || [];
      var activeData = results[1] || [];
      var allData = results[2] || [];

      refreshCount++;
      lastRefreshTime = Date.now();

      // Detect changes
      var newBlockedSnap = snapshotData(blockedData);
      var newActiveSnap = snapshotData(activeData);
      var newAllSnap = snapshotData(allData);

      var changedBlocked = findChangedIds(prevSnapshots.blocked, newBlockedSnap);
      var changedActive = findChangedIds(prevSnapshots.active, newActiveSnap);
      var changedAll = findChangedIds(prevSnapshots.all, newAllSnap);

      // Update data
      if (grids.blocked) { grids.blocked.replaceData(blockedData); highlightChangedRows(grids.blocked, changedBlocked); }
      if (grids.active) { grids.active.replaceData(activeData); highlightChangedRows(grids.active, changedActive); }
      if (grids.all) { grids.all.replaceData(allData); highlightChangedRows(grids.all, changedAll); }

      // Update snapshots
      prevSnapshots.blocked = newBlockedSnap;
      prevSnapshots.active = newActiveSnap;
      prevSnapshots.all = newAllSnap;

      var totalChanges = changedBlocked.length + changedActive.length + changedAll.length;
      var stats = blockedData.length + " blocked | " + activeData.length + " active | " + allData.length + " total";
      var changeNote = totalChanges > 0 ? " \u00b7 " + totalChanges + " changed" : "";
      updateStatusBar(stats + changeNote + "  \u00b7  " + new Date().toLocaleTimeString() + "  \u00b7  <span id='refresh-countdown'>0s ago</span>", "ok");

      var analytics = computeAnalytics(allData);
      renderAnalyticsBadges(analytics);
      renderMiniChart(analytics);
    }).catch(function(err) {
      updateStatusBar("Refresh failed: " + err.message, "error");
    });
  }

  // Fast refresh for active tasks only (1s interval)
  function refreshActiveTasks() {
    fetchWithRetry(API_BASE + "/api/v1/plan/list/in_progress", 1).then(function(data) {
      if (!grids.active) return;

      var newSnap = snapshotData(data);
      var changed = findChangedIds(prevSnapshots.active, newSnap);
      prevSnapshots.active = newSnap;

      grids.active.replaceData(data);
      if (changed.length > 0) {
        highlightChangedRows(grids.active, changed);
        lastRefreshTime = Date.now();
      }
    }).catch(function() {});
  }

  // ═══════════════════════════════════════════════════════════════
  // Auto-refresh setup
  // ═══════════════════════════════════════════════════════════════

  function startRefreshTimers() {
    if (refreshTimer) clearInterval(refreshTimer);
    if (activeTimer) clearInterval(activeTimer);
    refreshTimer = setInterval(loadAndRefreshAll, REFRESH_INTERVAL_MS);
    activeTimer = setInterval(refreshActiveTasks, ACTIVE_REFRESH_MS);
  }

  // ═══════════════════════════════════════════════════════════════
  // AI Search (Zettelkasten-powered)
  // ═══════════════════════════════════════════════════════════════

  function initAISearch() {
    var searchBox = document.getElementById("ai-search-input");
    var resultsDiv = document.getElementById("ai-search-results");
    if (!searchBox || !resultsDiv) return;

    var debounceTimer = null;
    searchBox.addEventListener("input", function() {
      var query = searchBox.value.trim();
      if (query.length < 2) {
        resultsDiv.innerHTML = "";
        if (grids.all) grids.all.clearFilter();
        return;
      }
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(function() {
        // Filter grid immediately (local)
        if (grids.all) grids.all.setFilter("title", "like", query);

        // Also search Zettelkasten (async)
        resultsDiv.innerHTML = "<span style='color:#f5a623;font-size:0.78rem'>Searching knowledge base...</span>";
        fetch("/api/v1/plan/search?q=" + encodeURIComponent(query))
          .then(function(r) { return r.text(); })
          .then(function(text) {
            try {
              var data = JSON.parse(text);
              if (Array.isArray(data)) {
                var filtered = grids.all ? grids.all.getDataCount("active") : "?";
                resultsDiv.innerHTML = "<span style='color:#00d4aa;font-size:0.78rem'>" + filtered + " tasks match \u00b7 " + data.length + " knowledge results</span>";
              } else {
                resultsDiv.innerHTML = "<span style='color:#00d4aa;font-size:0.78rem'>\uD83D\uDCD6 " + text.substring(0, 200) + "</span>";
              }
            } catch(e) {
              resultsDiv.innerHTML = "<span style='color:#7a8fa6;font-size:0.78rem'>" + text.substring(0, 200) + "</span>";
            }
          })
          .catch(function() {
            resultsDiv.innerHTML = "<span style='color:#ff4757;font-size:0.78rem'>Search unavailable</span>";
          });
      }, 250);
    });

    // Keyboard: Escape clears search
    searchBox.addEventListener("keydown", function(e) {
      if (e.key === "Escape") {
        searchBox.value = "";
        resultsDiv.innerHTML = "";
        if (grids.all) grids.all.clearFilter();
        searchBox.blur();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // Detail Panel (click task → expand details)
  // ═══════════════════════════════════════════════════════════════

  function showTaskDetail(taskData) {
    var panel = document.getElementById("task-detail-panel");
    if (!panel) return;

    var pColor = {"P0":"#ff4757","P1":"#ffa502","P2":"#2ed573","P3":"#7a8fa6"}[taskData.priority] || "#7a8fa6";
    var sColor = {"completed":"#3dd68c","blocked":"#ff4757","in_progress":"#00d4aa","pending":"#7a8fa6"}[taskData.status] || "#7a8fa6";
    var age = taskAge(taskData.created);

    panel.innerHTML =
      "<div style='background:var(--card-bg,#141922);border:1px solid rgba(0,212,170,0.15);border-radius:10px;padding:20px;margin:12px 0;box-shadow:0 4px 24px rgba(0,0,0,0.2)'>" +
      "<div style='display:flex;justify-content:space-between;align-items:center;margin-bottom:16px'>" +
      "<div style='display:flex;align-items:center;gap:12px'>" +
      "<span style='background:" + pColor + ";color:#fff;padding:3px 10px;border-radius:8px;font-weight:700;font-size:0.8rem'>" + taskData.priority + "</span>" +
      "<span style='color:" + sColor + ";font-weight:600;font-size:0.85rem'>" + (taskData.status || "unknown") + "</span>" +
      "<span style='color:#7a8fa6;font-size:0.75rem'>" + age + " old</span>" +
      "</div>" +
      "<button id='close-detail' style='background:none;border:1px solid rgba(122,143,166,0.2);color:#7a8fa6;padding:4px 10px;border-radius:6px;cursor:pointer;font-size:0.78rem'>\u2715 Close</button>" +
      "</div>" +
      "<div style='font-size:0.92rem;line-height:1.5;margin-bottom:16px;color:var(--text,#e0e6ed)'>" + (taskData.title || "Untitled") + "</div>" +
      "<div style='display:grid;grid-template-columns:120px 1fr;gap:6px 12px;font-size:0.8rem;color:#7a8fa6;margin-bottom:16px'>" +
      "<span>ID</span><span style='font-family:monospace;color:var(--text,#e0e6ed)'>" + taskData.id + "</span>" +
      "<span>Owner</span><span style='color:var(--text,#e0e6ed)'>" + (taskData.owner || "Unassigned") + "</span>" +
      "<span>Created</span><span style='color:var(--text,#e0e6ed)'>" + (taskData.created ? taskData.created.substring(0, 19) : "\u2014") + "</span>" +
      "<span>Parent</span><span style='font-family:monospace;color:var(--text,#e0e6ed)'>" + (taskData.parent_id || "None (root)") + "</span>" +
      "</div>" +
      "<div style='display:flex;gap:8px;flex-wrap:wrap'>" +
      "<button class='detail-action-btn' data-action='knowledge' style='background:rgba(0,212,170,0.1);color:#00d4aa;border:1px solid rgba(0,212,170,0.2);padding:6px 14px;border-radius:6px;cursor:pointer;font-size:0.8rem'>\uD83D\uDD0D Knowledge</button>" +
      "<button class='detail-action-btn' data-action='related' style='background:rgba(0,212,170,0.05);color:#00d4aa;border:1px solid rgba(0,212,170,0.15);padding:6px 14px;border-radius:6px;cursor:pointer;font-size:0.8rem'>\uD83D\uDD17 Related</button>" +
      "<button class='detail-action-btn' data-action='stamp' style='background:rgba(245,166,35,0.05);color:#f5a623;border:1px solid rgba(245,166,35,0.15);padding:6px 14px;border-radius:6px;cursor:pointer;font-size:0.8rem'>\uD83D\uDEE1 STAMP</button>" +
      "</div>" +
      "<div id='detail-results' style='margin-top:12px'></div>" +
      "</div>";

    // Bind detail buttons
    setTimeout(function() {
      var closeBtn = document.getElementById("close-detail");
      if (closeBtn) closeBtn.onclick = function() { panel.innerHTML = ""; };

      panel.querySelectorAll(".detail-action-btn").forEach(function(btn) {
        btn.onclick = function() {
          var action = btn.getAttribute("data-action");
          var div = document.getElementById("detail-results");
          if (!div) return;

          if (action === "knowledge") {
            searchKnowledgeInPanel(taskData.title.substring(0, 60), div);
          } else if (action === "related") {
            searchRelatedInPanel(taskData.id, div);
          } else if (action === "stamp") {
            showStampRefs(taskData.title, div);
          }
        };
      });
    }, 50);

    panel.scrollIntoView({behavior: "smooth", block: "nearest"});
  }

  window.showTaskDetail = showTaskDetail;

  function searchKnowledgeInPanel(query, div) {
    div.innerHTML = "<span style='color:#f5a623;font-size:0.78rem'>Searching: " + query + "...</span>";
    fetch("/api/v1/plan/search?q=" + encodeURIComponent(query))
      .then(function(r) { return r.text(); })
      .then(function(text) {
        div.innerHTML =
          "<div style='background:rgba(0,212,170,0.04);border:1px solid rgba(0,212,170,0.12);border-radius:8px;padding:14px;margin-top:8px'>" +
          "<div style='color:#00d4aa;font-weight:600;font-size:0.82rem;margin-bottom:8px'>\uD83D\uDCDA Zettelkasten Knowledge</div>" +
          "<pre style='color:var(--text,#e0e6ed);font-size:0.75rem;white-space:pre-wrap;max-height:200px;overflow-y:auto;margin:0'>" + text.substring(0, 1500) + "</pre>" +
          "</div>";
      })
      .catch(function() { div.innerHTML = "<span style='color:#ff4757;font-size:0.78rem'>Search failed</span>"; });
  }

  function searchRelatedInPanel(taskId, div) {
    if (!grids.all) return;
    var allData = grids.all.getData();
    var task = allData.find(function(t) { return t.id === taskId; });
    if (!task) return;

    var words = task.title.toLowerCase().split(/\s+/).filter(function(w) { return w.length > 3; });
    var related = allData.filter(function(t) {
      if (t.id === taskId) return false;
      var title = t.title.toLowerCase();
      var matches = words.filter(function(w) { return title.indexOf(w) >= 0; });
      return matches.length >= 2; // Require 2+ word matches for quality
    }).slice(0, 8);

    div.innerHTML =
      "<div style='background:rgba(0,212,170,0.04);border:1px solid rgba(0,212,170,0.12);border-radius:8px;padding:14px;margin-top:8px'>" +
      "<div style='color:#00d4aa;font-weight:600;font-size:0.82rem;margin-bottom:8px'>\uD83D\uDD17 " + related.length + " Related Tasks</div>" +
      (related.length === 0 ? "<span style='color:#7a8fa6;font-size:0.78rem'>No strongly related tasks found</span>" :
        related.map(function(r) {
          var pc = {"P0":"#ff4757","P1":"#ffa502","P2":"#2ed573","P3":"#7a8fa6"}[r.priority] || "#7a8fa6";
          return "<div style='padding:4px 0;border-bottom:1px solid rgba(122,143,166,0.06);font-size:0.78rem;display:flex;align-items:center;gap:6px'>" +
            "<span style='color:" + pc + ";font-weight:700;min-width:24px'>" + r.priority + "</span>" +
            "<span style='color:#7a8fa6;min-width:60px'>" + r.status + "</span>" +
            "<span style='flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap'>" + r.title + "</span>" +
            "</div>";
        }).join("")) +
      "</div>";
  }

  function showStampRefs(title, div) {
    var refs = title.match(/SC-[A-Z]+-\d+/g) || [];
    if (refs.length === 0) {
      div.innerHTML = "<span style='color:#7a8fa6;font-size:0.78rem'>No STAMP references in title</span>";
      return;
    }
    div.innerHTML =
      "<div style='background:rgba(245,166,35,0.04);border:1px solid rgba(245,166,35,0.12);border-radius:8px;padding:14px;margin-top:8px'>" +
      "<div style='color:#f5a623;font-weight:600;font-size:0.82rem;margin-bottom:8px'>\uD83D\uDEE1 " + refs.length + " STAMP References</div>" +
      refs.map(function(ref) {
        return "<span style='background:rgba(245,166,35,0.1);color:#f5a623;padding:3px 10px;border-radius:6px;font-size:0.75rem;font-weight:600;margin:0 4px 4px 0;display:inline-block'>" + ref + "</span>";
      }).join("") +
      "</div>";
  }

  // ═══════════════════════════════════════════════════════════════
  // Keyboard shortcuts
  // ═══════════════════════════════════════════════════════════════

  document.addEventListener("keydown", function(e) {
    // Escape closes detail panel
    if (e.key === "Escape") {
      var panel = document.getElementById("task-detail-panel");
      if (panel && panel.innerHTML !== "") {
        panel.innerHTML = "";
        e.preventDefault();
      }
    }
    // Ctrl+K focuses search
    if ((e.ctrlKey || e.metaKey) && e.key === "k") {
      var search = document.getElementById("ai-search-input");
      if (search) { search.focus(); e.preventDefault(); }
    }
    // R refreshes (when not in input)
    if (e.key === "r" && !e.ctrlKey && !e.metaKey && document.activeElement.tagName !== "INPUT") {
      loadAndRefreshAll();
    }
  });

  // ═══════════════════════════════════════════════════════════════
  // Initialize
  // ═══════════════════════════════════════════════════════════════

  initGrids();
  setTimeout(function() {
    initAISearch();
    startRefreshTimers();
  }, 1000);

})();
