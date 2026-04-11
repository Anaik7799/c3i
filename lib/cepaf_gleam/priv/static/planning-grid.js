// C3I Planning Data Grid — Feature-Rich Tabulator 6.3
// Fetches live data from Rust Smriti API via Zenoh mesh
// Robust to failure, auto-retry, export, analytics
// SC-TODO-001, SC-GLM-UI-001, SC-ZENOH-001

(function() {
  "use strict";

  // ═══════════════════════════════════════════════════════════════
  // Configuration
  // ═══════════════════════════════════════════════════════════════

  var API_BASE = "";
  var RETRY_COUNT = 3;
  var RETRY_DELAY_MS = 1000;
  var REFRESH_INTERVAL_MS = 60000; // Auto-refresh every 60s
  var refreshTimer = null;

  // ═══════════════════════════════════════════════════════════════
  // Column Definitions
  // ═══════════════════════════════════════════════════════════════

  var taskColumns = [
    {title:"ID", field:"id", width:90, headerSort:true,
     formatter:function(c){return c.getValue().substring(0,8);},
     tooltip:function(e,c){return "Full ID: " + c.getValue();}
    },
    {title:"Priority", field:"priority", width:85, headerFilter:"select",
     headerFilterParams:{values:{"":"All","P0":"P0","P1":"P1","P2":"P2","P3":"P3"}},
     headerSort:true,
     formatter:function(c){
       var v=c.getValue();
       var color=v==="P0"?"#e05252":v==="P1"?"#f5a623":v==="P2"?"#00d4aa":"#7a8fa6";
       return "<span style='color:"+color+";font-weight:700'>"+v+"</span>";
     },
     sorter:function(a,b){
       var order={"P0":0,"P1":1,"P2":2,"P3":3};
       return (order[a]||9) - (order[b]||9);
     }
    },
    {title:"Status", field:"status", width:120, headerFilter:"select",
     headerFilterParams:{values:{"":"All","pending":"Pending","in_progress":"Active","completed":"Done","blocked":"Blocked"}},
     headerSort:true,
     formatter:function(c){
       var v=c.getValue();
       var bg=v==="completed"?"rgba(61,214,140,0.2)":v==="blocked"?"rgba(224,82,82,0.2)":v==="in_progress"?"rgba(0,212,170,0.2)":"rgba(122,143,166,0.1)";
       var color=v==="completed"?"#3dd68c":v==="blocked"?"#e05252":v==="in_progress"?"#00d4aa":"#7a8fa6";
       var label=v==="in_progress"?"Active":v.charAt(0).toUpperCase()+v.slice(1);
       return "<span style='background:"+bg+";color:"+color+";padding:2px 8px;border-radius:4px;font-size:0.8rem;font-weight:600'>"+label+"</span>";
     }
    },
    {title:"Description", field:"title", minWidth:350, headerFilter:"input",
     headerFilterPlaceholder:"Search tasks...",
     formatter:"textarea",
     tooltip:true
    },
    {title:"Owner", field:"owner", width:100,
     formatter:function(c){return c.getValue() || "<span style='color:#7a8fa6'>—</span>";}
    },
    {title:"Created", field:"created", width:110, headerSort:true,
     formatter:function(c){
       var v=c.getValue(); return v ? v.substring(0,10) : "—";
     },
     sorter:"date"
    }
  ];

  // ═══════════════════════════════════════════════════════════════
  // Fetch with retry + error handling
  // ═══════════════════════════════════════════════════════════════

  function fetchWithRetry(url, retries) {
    return fetch(url).then(function(r) {
      if (!r.ok) throw new Error("HTTP " + r.status);
      return r.json();
    }).catch(function(err) {
      if (retries > 0) {
        console.log("Retry " + (RETRY_COUNT - retries + 1) + "/" + RETRY_COUNT + " for " + url);
        return new Promise(function(resolve) {
          setTimeout(function() { resolve(fetchWithRetry(url, retries - 1)); }, RETRY_DELAY_MS);
        });
      }
      throw err;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // Status bar
  // ═══════════════════════════════════════════════════════════════

  function updateStatusBar(msg, type) {
    var bar = document.getElementById("grid-status");
    if (!bar) return;
    var colors = {ok:"#3dd68c", loading:"#f5a623", error:"#e05252"};
    bar.style.color = colors[type] || "#7a8fa6";
    bar.textContent = msg;
  }

  // ═══════════════════════════════════════════════════════════════
  // Grid initialization
  // ═══════════════════════════════════════════════════════════════

  function initGrids() {
    if (typeof Tabulator === "undefined") {
      setTimeout(initGrids, 200);
      return;
    }

    updateStatusBar("Loading task data from Smriti...", "loading");

    Promise.all([
      fetchWithRetry(API_BASE + "/api/v1/plan/list/blocked", RETRY_COUNT),
      fetchWithRetry(API_BASE + "/api/v1/plan/list/in_progress", RETRY_COUNT),
      fetchWithRetry(API_BASE + "/api/v1/plan/list/all", RETRY_COUNT)
    ]).then(function(results) {
      var blockedData = results[0] || [];
      var activeData = results[1] || [];
      var allData = results[2] || [];

      var stats = blockedData.length + " blocked, " + activeData.length + " active, " + allData.length + " total";
      console.log("C3I Grid: " + stats);
      updateStatusBar("Loaded: " + stats + " | Last refresh: " + new Date().toLocaleTimeString(), "ok");

      // ── Blocked Tasks Grid ──
      var blockedEl = document.getElementById("blocked-grid");
      if (blockedEl) {
        if (blockedData.length > 0) {
          new Tabulator("#blocked-grid", {
            data: blockedData,
            columns: taskColumns,
            layout: "fitColumns",
            height: Math.min(blockedData.length * 40 + 60, 350),
            placeholder: "No blocked tasks",
            headerSortTristate: true,
            movableColumns: true,
            resizableRows: true,
            selectable: true,
            rowClick: function(e, row) {
              var d = row.getData();
              console.log("Selected task: " + d.id + " — " + d.title);
            }
          });
        } else {
          blockedEl.innerHTML = "<p style='color:#3dd68c;padding:12px;text-align:center'>✓ No blocked tasks</p>";
        }
      }

      // ── Active Tasks Grid ──
      var activeEl = document.getElementById("active-grid");
      if (activeEl) {
        if (activeData.length > 0) {
          new Tabulator("#active-grid", {
            data: activeData,
            columns: taskColumns,
            layout: "fitColumns",
            height: Math.min(activeData.length * 40 + 60, 400),
            placeholder: "No active tasks",
            headerSortTristate: true,
            movableColumns: true,
            selectable: true
          });
        } else {
          activeEl.innerHTML = "<p style='color:#7a8fa6;padding:12px;text-align:center'>No active tasks</p>";
        }
      }

      // ── All Tasks Grid (paginated, full-featured) ──
      var allEl = document.getElementById("all-grid");
      if (allEl) {
        var allGrid = new Tabulator("#all-grid", {
          data: allData,
          columns: taskColumns,
          layout: "fitColumns",
          height: 500,
          pagination: "local",
          paginationSize: 25,
          paginationSizeSelector: [10, 25, 50, 100, true],
          paginationCounter: "rows",
          placeholder: "No tasks found",
          headerSortTristate: true,
          movableColumns: true,
          resizableRows: true,
          selectable: true,
          initialSort: [{column:"priority", dir:"asc"}],
          footerElement: "<div style='padding:4px 8px;color:#7a8fa6;font-size:0.8rem'>" +
            "<button id='export-csv' style='background:var(--accent,#00d4aa);color:#0a0e17;border:none;padding:4px 12px;border-radius:4px;cursor:pointer;margin-right:8px'>Export CSV</button>" +
            "<button id='export-json' style='background:transparent;color:#00d4aa;border:1px solid #00d4aa;padding:4px 12px;border-radius:4px;cursor:pointer;margin-right:8px'>Export JSON</button>" +
            "<button id='refresh-btn' style='background:transparent;color:#f5a623;border:1px solid #f5a623;padding:4px 12px;border-radius:4px;cursor:pointer'>↻ Refresh</button>" +
            "</div>",
          dataLoaded: function() {
            // Bind export buttons after grid renders
            setTimeout(function() {
              var csvBtn = document.getElementById("export-csv");
              var jsonBtn = document.getElementById("export-json");
              var refreshBtn = document.getElementById("refresh-btn");
              if (csvBtn) csvBtn.onclick = function() { allGrid.download("csv", "c3i-tasks.csv"); };
              if (jsonBtn) jsonBtn.onclick = function() { allGrid.download("json", "c3i-tasks.json"); };
              if (refreshBtn) refreshBtn.onclick = function() { loadAndRefresh(); };
            }, 100);
          }
        });

        // Store grid reference for refresh
        window._c3iAllGrid = allGrid;
      }

      // Analytics summary
      var analytics = computeAnalytics(allData);
      renderAnalyticsBadges(analytics);

    }).catch(function(err) {
      console.error("Grid data fetch failed:", err);
      updateStatusBar("Failed to load data: " + err.message + " — retrying...", "error");
      // Retry after 5 seconds
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

    data.forEach(function(t) {
      if (byStatus[t.status] !== undefined) byStatus[t.status]++;
      if (byPriority[t.priority] !== undefined) byPriority[t.priority]++;
    });

    return {
      total: total,
      completionRate: total > 0 ? ((byStatus.completed / total) * 100).toFixed(1) : "0",
      blockedRate: total > 0 ? ((byStatus.blocked / total) * 100).toFixed(1) : "0",
      p0Done: byPriority.P0 > 0 ? "100%" : "N/A",
      velocity: byStatus.completed,
      byStatus: byStatus,
      byPriority: byPriority
    };
  }

  function renderAnalyticsBadges(a) {
    var container = document.getElementById("grid-analytics");
    if (!container) return;
    container.innerHTML =
      "<span style='margin-right:16px'>Total: <b>" + a.total + "</b></span>" +
      "<span style='margin-right:16px;color:#3dd68c'>Done: <b>" + a.byStatus.completed + "</b> (" + a.completionRate + "%)</span>" +
      "<span style='margin-right:16px;color:#f5a623'>Active: <b>" + a.byStatus.in_progress + "</b></span>" +
      "<span style='margin-right:16px;color:#e05252'>Blocked: <b>" + a.byStatus.blocked + "</b></span>" +
      "<span style='color:#7a8fa6'>P0:" + a.byPriority.P0 + " P1:" + a.byPriority.P1 + " P2:" + a.byPriority.P2 + " P3:" + a.byPriority.P3 + "</span>";
  }

  // ═══════════════════════════════════════════════════════════════
  // Auto-refresh
  // ═══════════════════════════════════════════════════════════════

  function loadAndRefresh() {
    updateStatusBar("Refreshing...", "loading");
    fetchWithRetry(API_BASE + "/api/v1/plan/list/all", RETRY_COUNT).then(function(data) {
      if (window._c3iAllGrid) {
        window._c3iAllGrid.replaceData(data);
        var analytics = computeAnalytics(data);
        renderAnalyticsBadges(analytics);
        updateStatusBar("Refreshed: " + data.length + " tasks | " + new Date().toLocaleTimeString(), "ok");
      }
    }).catch(function(err) {
      updateStatusBar("Refresh failed: " + err.message, "error");
    });
  }

  // Auto-refresh every 60s
  if (refreshTimer) clearInterval(refreshTimer);
  refreshTimer = setInterval(loadAndRefresh, REFRESH_INTERVAL_MS);

  // ═══════════════════════════════════════════════════════════════
  // Initialize
  // ═══════════════════════════════════════════════════════════════

  initGrids();

})();
