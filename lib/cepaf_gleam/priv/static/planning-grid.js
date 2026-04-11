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
  var REFRESH_INTERVAL_MS = 60000; // Full refresh every 60s
  var ACTIVE_REFRESH_MS = 1000; // In-progress tasks refresh every 1s
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
       var styles={
         "P0":"background:linear-gradient(135deg,#e05252,#c0392b);color:#fff;",
         "P1":"background:linear-gradient(135deg,#f5a623,#e67e22);color:#1a1000;",
         "P2":"background:linear-gradient(135deg,#00d4aa,#2ecc71);color:#081008;",
         "P3":"background:rgba(122,143,166,0.15);color:#7a8fa6;"
       };
       var icons={"P0":"\u26a0","P1":"\u25b2","P2":"\u25cf","P3":"\u25cb"};
       return "<span style='"+styles[v]+"padding:3px 10px;border-radius:12px;font-size:0.75rem;font-weight:700;display:inline-flex;align-items:center;gap:4px;letter-spacing:0.5px'>"+icons[v]+" "+v+"</span>";
     },
     sorter:function(a,b){
       var order={"P0":0,"P1":1,"P2":2,"P3":3};
       return (order[a]||9) - (order[b]||9);
     }
    },
    {title:"Status", field:"status", width:125, headerFilter:"select",
     headerFilterParams:{values:{"":"All","pending":"Pending","in_progress":"Active","completed":"Done","blocked":"Blocked"}},
     headerSort:true,
     formatter:function(c){
       var v=c.getValue();
       var configs={
         "completed":{bg:"linear-gradient(135deg,rgba(61,214,140,0.25),rgba(46,204,113,0.15))",color:"#3dd68c",icon:"\u2713",label:"Done"},
         "blocked":{bg:"linear-gradient(135deg,rgba(224,82,82,0.25),rgba(192,57,43,0.15))",color:"#e05252",icon:"\u2717",label:"Blocked"},
         "in_progress":{bg:"linear-gradient(135deg,rgba(0,212,170,0.25),rgba(0,188,150,0.15))",color:"#00d4aa",icon:"\u25b6",label:"Active"},
         "pending":{bg:"rgba(122,143,166,0.08)",color:"#7a8fa6",icon:"\u25cb",label:"Pending"}
       };
       var cfg=configs[v]||configs["pending"];
       return "<span style='background:"+cfg.bg+";color:"+cfg.color+";padding:3px 10px;border-radius:12px;font-size:0.75rem;font-weight:600;display:inline-flex;align-items:center;gap:4px'>"+cfg.icon+" "+cfg.label+"</span>";
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

  // Auto-refresh: full every 60s, active tasks every 5s
  if (refreshTimer) clearInterval(refreshTimer);
  refreshTimer = setInterval(loadAndRefresh, REFRESH_INTERVAL_MS);

  // Fast refresh for in-progress tasks (dynamic status updates)
  var activeTimer = null;
  function refreshActiveTasks() {
    fetchWithRetry(API_BASE + "/api/v1/plan/list/in_progress", 1).then(function(data) {
      var activeEl = document.getElementById("active-grid");
      if (activeEl && activeEl.tabulator) {
        activeEl.tabulator.replaceData(data);
      }
      // Update status bar with live count
      var bar = document.getElementById("grid-status");
      if (bar) {
        var now = new Date().toLocaleTimeString();
        bar.textContent = bar.textContent.replace(/Active: \d+/, "Active: " + data.length).replace(/\d+:\d+:\d+\s*(AM|PM)?/i, now);
      }
    }).catch(function() {});
  }
  activeTimer = setInterval(refreshActiveTasks, ACTIVE_REFRESH_MS);

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
      if (query.length < 3) { resultsDiv.innerHTML = ""; return; }
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(function() {
        resultsDiv.innerHTML = "<span style='color:#f5a623'>Searching Zettelkasten...</span>";
        // Search via Wisp API (FTS5 on holons)
        fetch("/api/v1/plan/search?q=" + encodeURIComponent(query))
          .then(function(r) { return r.text(); })
          .then(function(text) {
            try {
              var data = JSON.parse(text);
              if (Array.isArray(data)) {
                // Filter all-grid in parallel
                if (window._c3iAllGrid) {
                  window._c3iAllGrid.setFilter("title", "like", query);
                }
                resultsDiv.innerHTML = "<span style='color:#3dd68c'>" + data.length + " tasks match '" + query + "'</span>";
              } else {
                // Zettelkasten search result
                resultsDiv.innerHTML = "<span style='color:#00d4aa'>Knowledge: " + text.substring(0, 200) + "</span>";
              }
            } catch(e) {
              resultsDiv.innerHTML = "<span style='color:#7a8fa6'>Results: " + text.substring(0, 200) + "</span>";
            }
          })
          .catch(function() {
            resultsDiv.innerHTML = "<span style='color:#e05252'>Search failed</span>";
          });
      }, 300);
    });

    // Clear filter on empty
    searchBox.addEventListener("keyup", function(e) {
      if (searchBox.value.trim() === "" && window._c3iAllGrid) {
        window._c3iAllGrid.clearFilter();
        resultsDiv.innerHTML = "";
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // Detail Panel (click task → expand details)
  // ═══════════════════════════════════════════════════════════════

  function showTaskDetail(taskData) {
    var panel = document.getElementById("task-detail-panel");
    if (!panel) return;

    var priorityColor = taskData.priority === "P0" ? "#e05252" :
                        taskData.priority === "P1" ? "#f5a623" :
                        taskData.priority === "P2" ? "#00d4aa" : "#7a8fa6";

    var statusColor = taskData.status === "completed" ? "#3dd68c" :
                      taskData.status === "blocked" ? "#e05252" :
                      taskData.status === "in_progress" ? "#00d4aa" : "#7a8fa6";

    panel.innerHTML =
      "<div style='background:var(--card-bg,#141922);border:1px solid var(--border,#1e2a3a);border-radius:8px;padding:16px;margin:12px 0'>" +
      "<div style='display:flex;justify-content:space-between;align-items:center;margin-bottom:12px'>" +
      "<h3 style='margin:0;color:var(--text,#e0e6ed);font-size:1.1rem'>Task Detail</h3>" +
      "<button onclick='document.getElementById(\"task-detail-panel\").innerHTML=\"\"' style='background:none;border:1px solid #7a8fa6;color:#7a8fa6;padding:4px 8px;border-radius:4px;cursor:pointer'>✕ Close</button>" +
      "</div>" +
      "<table style='width:100%;border-collapse:collapse'>" +
      "<tr><td style='color:#7a8fa6;padding:6px 12px 6px 0;width:120px'>ID</td><td style='padding:6px 0;font-family:monospace'>" + taskData.id + "</td></tr>" +
      "<tr><td style='color:#7a8fa6;padding:6px 12px 6px 0'>Priority</td><td style='padding:6px 0;color:" + priorityColor + ";font-weight:700'>" + taskData.priority + "</td></tr>" +
      "<tr><td style='color:#7a8fa6;padding:6px 12px 6px 0'>Status</td><td style='padding:6px 0;color:" + statusColor + ";font-weight:600'>" + taskData.status + "</td></tr>" +
      "<tr><td style='color:#7a8fa6;padding:6px 12px 6px 0'>Title</td><td style='padding:6px 0'>" + taskData.title + "</td></tr>" +
      "<tr><td style='color:#7a8fa6;padding:6px 12px 6px 0'>Owner</td><td style='padding:6px 0'>" + (taskData.owner || "Unassigned") + "</td></tr>" +
      "<tr><td style='color:#7a8fa6;padding:6px 12px 6px 0'>Created</td><td style='padding:6px 0'>" + (taskData.created ? taskData.created.substring(0, 19) : "—") + "</td></tr>" +
      "<tr><td style='color:#7a8fa6;padding:6px 12px 6px 0'>Parent</td><td style='padding:6px 0;font-family:monospace'>" + (taskData.parent_id || "None (top-level)") + "</td></tr>" +
      "</table>" +
      "<div style='margin-top:12px;display:flex;gap:8px'>" +
      "<button onclick='searchKnowledge(\"" + escapeHtml(taskData.title.substring(0,50)) + "\")' style='background:var(--accent,#00d4aa);color:#0a0e17;border:none;padding:6px 12px;border-radius:4px;cursor:pointer;font-size:0.85rem'>🔍 Search Knowledge</button>" +
      "<button onclick='searchRelated(\"" + taskData.id + "\")' style='background:transparent;color:#00d4aa;border:1px solid #00d4aa;padding:6px 12px;border-radius:4px;cursor:pointer;font-size:0.85rem'>🔗 Related Tasks</button>" +
      "</div>" +
      "<div id='knowledge-results' style='margin-top:12px'></div>" +
      "</div>";

    panel.scrollIntoView({behavior: "smooth", block: "start"});
  }

  // Make showTaskDetail available globally for row clicks
  window.showTaskDetail = showTaskDetail;

  function escapeHtml(str) {
    return str.replace(/'/g, "\\'").replace(/"/g, '\\"');
  }

  // ═══════════════════════════════════════════════════════════════
  // Knowledge Search (Zettelkasten FTS5)
  // ═══════════════════════════════════════════════════════════════

  window.searchKnowledge = function(query) {
    var div = document.getElementById("knowledge-results");
    if (!div) return;
    div.innerHTML = "<span style='color:#f5a623'>Searching Zettelkasten for: " + query + "...</span>";

    fetch("/api/v1/plan/search?q=" + encodeURIComponent(query))
      .then(function(r) { return r.text(); })
      .then(function(text) {
        div.innerHTML =
          "<div style='background:rgba(0,212,170,0.05);border:1px solid rgba(0,212,170,0.2);border-radius:6px;padding:12px;margin-top:8px'>" +
          "<div style='color:#00d4aa;font-weight:600;margin-bottom:8px'>📚 Zettelkasten Knowledge</div>" +
          "<pre style='color:var(--text,#e0e6ed);font-size:0.8rem;white-space:pre-wrap;max-height:200px;overflow-y:auto'>" + text.substring(0, 1000) + "</pre>" +
          "</div>";
      })
      .catch(function() {
        div.innerHTML = "<span style='color:#e05252'>Knowledge search failed</span>";
      });
  };

  // ═══════════════════════════════════════════════════════════════
  // Related Tasks Search
  // ═══════════════════════════════════════════════════════════════

  window.searchRelated = function(taskId) {
    var div = document.getElementById("knowledge-results");
    if (!div) return;

    // Find the task in allGrid data
    if (!window._c3iAllGrid) return;
    var allData = window._c3iAllGrid.getData();
    var task = allData.find(function(t) { return t.id === taskId; });
    if (!task) return;

    // Find related by matching words in title
    var words = task.title.toLowerCase().split(/\s+/).filter(function(w) { return w.length > 3; });
    var related = allData.filter(function(t) {
      if (t.id === taskId) return false;
      var title = t.title.toLowerCase();
      return words.some(function(w) { return title.indexOf(w) >= 0; });
    }).slice(0, 10);

    div.innerHTML =
      "<div style='background:rgba(0,212,170,0.05);border:1px solid rgba(0,212,170,0.2);border-radius:6px;padding:12px;margin-top:8px'>" +
      "<div style='color:#00d4aa;font-weight:600;margin-bottom:8px'>🔗 " + related.length + " Related Tasks</div>" +
      related.map(function(r) {
        var pColor = r.priority === "P0" ? "#e05252" : r.priority === "P1" ? "#f5a623" : "#00d4aa";
        return "<div style='padding:4px 0;border-bottom:1px solid rgba(122,143,166,0.1)'>" +
          "<span style='color:" + pColor + ";font-weight:700;margin-right:8px'>" + r.priority + "</span>" +
          "<span style='color:#7a8fa6;margin-right:8px'>" + r.status + "</span>" +
          r.title.substring(0, 80) +
          "</div>";
      }).join("") +
      (related.length === 0 ? "<span style='color:#7a8fa6'>No related tasks found</span>" : "") +
      "</div>";
  };

  // ═══════════════════════════════════════════════════════════════
  // Override row click handlers to show detail panel
  // ═══════════════════════════════════════════════════════════════

  // Patch the rowClick handler for all grids after they're created
  var origInit = initGrids;
  initGrids = function() {
    origInit.call(this);
    // After grids init, patch row click to show detail
    setTimeout(function() {
      document.querySelectorAll(".tabulator-row").forEach(function(row) {
        row.style.cursor = "pointer";
      });
    }, 2000);
  };

  // Global row click handler via event delegation
  document.addEventListener("click", function(e) {
    var row = e.target.closest(".tabulator-row");
    if (!row) return;
    var grid = row.closest(".tabulator");
    if (!grid) return;

    // Get Tabulator instance
    var tabulatorInstance = null;
    if (grid.id === "all-grid" && window._c3iAllGrid) tabulatorInstance = window._c3iAllGrid;
    if (!tabulatorInstance) return;

    // Find clicked row data
    var rows = tabulatorInstance.getRows();
    var rowIndex = Array.from(grid.querySelectorAll(".tabulator-row")).indexOf(row);
    if (rowIndex >= 0 && rows[rowIndex]) {
      showTaskDetail(rows[rowIndex].getData());
    }
  });

  // ═══════════════════════════════════════════════════════════════
  // Initialize
  // ═══════════════════════════════════════════════════════════════

  initGrids();
  setTimeout(initAISearch, 1000);

})();
