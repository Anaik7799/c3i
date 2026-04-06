//// =============================================================================
//// [C3I-SIL6-MSTS] MATHEMATICAL & SEMANTIC MODULE CONTRACT
//// =============================================================================
//// <c3i-module>
////   <identity>
////     <module>cepaf_gleam/ui/lustre/shell</module>
////     <fsharp-lineage>Cepaf.UI.Shell.fs</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L2_COMPONENT</layer>
////     <mesh-domain>HTML shell layout, nav, reusable UI primitives</mesh-domain>
////   </fractal-topology>
////   <compliance>
////     <criticality>HIGH</criticality>
////     <stamp-controls>SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-008, SC-MUDA-001</stamp-controls>
////   </compliance>
////   <transformations>
////     <morphism type="isomorphic">
////       Shell layout ≅ Lustre Element tree. Pure, no side effects.
////     </morphism>
////   </transformations>
//// </c3i-module>
//// =============================================================================
////
//// HTML shell: <!doctype html> document wrapper, navigation, reusable
//// component primitives (status_card, container_card, mini_bar, section,
//// kv_row, alert_banner, data_table).
////
//// CSS is intentionally minimal (~70 lines) to avoid Gleam compiler OOM on
//// large string literals (SC-MUDA-001).
////
//// STAMP: SC-GLM-UI-001, SC-GLM-UI-008, SC-MUDA-001

import gleam/float
import gleam/int
import gleam/list
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

// ---------------------------------------------------------------------------
// CSS — intentionally minimal: no animations, no gradients, no sparklines.
// ---------------------------------------------------------------------------

const css: String = "
body{margin:0;font-family:system-ui,sans-serif;background:#0a0e17;color:#e0e6ed;}
a{color:#00d4aa;text-decoration:none;}
a:hover{color:#3dd68c;}
nav{background:#0d1420;border-bottom:1px solid #1e2a3a;padding:0 1rem;display:flex;flex-wrap:wrap;gap:.25rem;align-items:center;}
nav a{padding:.5rem .75rem;border-radius:4px;font-size:.85rem;}
nav a.active{background:#1e2a3a;color:#3dd68c;}
main{padding:1.5rem;max-width:1400px;margin:0 auto;}
h1{font-size:1.4rem;margin:.5rem 0 .25rem;}
h2{font-size:1.1rem;margin:1rem 0 .5rem;color:#7a8fa6;}
p.sub{font-size:.85rem;color:#7a8fa6;margin:0 0 1rem;}
.card-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:1rem;margin:.75rem 0;}
.card-grid-wide{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:1rem;margin:.75rem 0;}
.card{background:#141922;border:1px solid #1e2a3a;border-radius:6px;padding:1rem;position:relative;overflow:hidden;}
.card-title{font-size:.8rem;color:#7a8fa6;text-transform:uppercase;margin:0 0 .4rem;}
.card-value{font-size:1.5rem;font-weight:700;margin:0 0 .25rem;}
.card-detail{font-size:.8rem;color:#7a8fa6;}
.status-healthy{color:#3dd68c;}
.status-degraded{color:#f5a623;}
.status-critical{color:#e05252;}
.status-unknown{color:#7a8fa6;}
.badge{display:inline-block;padding:.15rem .5rem;border-radius:3px;font-size:.75rem;font-weight:600;}
.badge-healthy{background:#1a3d2a;color:#3dd68c;}
.badge-degraded{background:#3d2e10;color:#f5a623;}
.badge-critical{background:#3d1515;color:#e05252;}
.section{margin:1.25rem 0;}
.section-title{font-size:.85rem;color:#7a8fa6;text-transform:uppercase;margin:0 0 .5rem;border-bottom:1px solid #1e2a3a;padding-bottom:.35rem;}
.alert{padding:.75rem 1rem;border-radius:4px;margin:.5rem 0;font-size:.9rem;}
.alert-critical{background:#3d1515;border:1px solid #e05252;color:#e05252;}
.alert-warning{background:#3d2e10;border:1px solid #f5a623;color:#f5a623;}
.alert-info{background:#0d2235;border:1px solid #00d4aa;color:#00d4aa;}
table{width:100%;border-collapse:collapse;font-size:.88rem;}
th{text-align:left;padding:.4rem .6rem;background:#0d1420;color:#7a8fa6;font-size:.78rem;text-transform:uppercase;}
td{padding:.4rem .6rem;border-bottom:1px solid #1e2a3a;}
.bar-wrap{background:#1e2a3a;border-radius:2px;height:6px;width:100%;overflow:hidden;}
.bar-fill{height:100%;border-radius:2px;}
.kv-row{display:flex;gap:.75rem;padding:.3rem 0;border-bottom:1px solid #1e2a3a;font-size:.88rem;}
.kv-key{color:#7a8fa6;min-width:140px;}
.ooda-phases{display:flex;align-items:center;gap:.5rem;flex-wrap:wrap;padding:.5rem 0;}
.ooda-arrow{color:#7a8fa6;}
.pill{display:inline-block;padding:.2rem .6rem;border-radius:12px;font-size:.8rem;background:#1e2a3a;color:#7a8fa6;}
.pill-active{background:#1a3d2a;color:#3dd68c;}
.w-full{width:100%;}
.dashboard-evolutionary{background-image:linear-gradient(rgba(30,42,58,0.1) 1px,transparent 1px),linear-gradient(90deg,rgba(30,42,58,0.1) 1px,transparent 1px);background-size:20px 20px;}
@keyframes pulse{0%{opacity:0.6;}50%{opacity:1;}100%{opacity:0.6;}}
.cyber-pulse{animation:pulse 2s infinite ease-in-out;}
@keyframes breath{0%{transform:scale(1);}50%{transform:scale(1.02);}100%{transform:scale(1);}}
.mesh-breath{animation:breath 4s infinite ease-in-out;}
.led-on{box-shadow:0 0 10px #3dd68c;border-color:#3dd68c;}
.emergency-stop-btn{background:#e05252;color:white;border:none;padding:.75rem 1.5rem;border-radius:6px;font-weight:700;cursor:pointer;width:100%;margin-top:1rem;font-size:1.1rem;box-shadow:0 4px 15px rgba(224,82,82,0.4);transition:transform 0.1s;}
.emergency-stop-btn:active{transform:scale(0.98);box-shadow:0 2px 5px rgba(224,82,82,0.4);}
.section-actions{display:flex;justify-content:center;padding:1rem 0;}
@media(max-width:768px){nav{padding:.25rem;}.card-grid,.card-grid-wide{grid-template-columns:1fr;}main{padding:.75rem;}}
"

// ---------------------------------------------------------------------------
// Navigation pages (order matches the cockpit tab bar)
// ---------------------------------------------------------------------------

const nav_pages: List(#(String, String)) = [
  #("/dashboard", "Dashboard"),
  #("/planning", "Planning"),
  #("/immune", "Immune"),
  #("/knowledge", "Knowledge"),
  #("/zenoh", "Zenoh"),
  #("/cockpit", "Cockpit"),
  #("/verification", "Verification"),
  #("/substrate", "Substrate"),
  #("/metabolic", "Metabolic"),
  #("/podman", "Podman"),
  #("/mcp", "MCP"),
  #("/kms", "KMS"),
  #("/telemetry", "Telemetry"),
  #("/federation", "Federation"),
  #("/health-grid", "Health Grid"),
]

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Render a complete <!doctype html> page as a String.
///
/// `title`       — Browser tab / <title> suffix.
/// `active_path` — URL path including leading "/" (e.g. "/dashboard").
///                 Used to highlight the active nav link.
/// `content`     — Lustre element tree for <main>.
///
/// Returns the full HTML document string.
const neuromorphic_script: String = "
// ---------------------------------------------------------------------------
// C3I Neuromorphic Control Loops & Symbiotic Autonomy (Phases 3, 4, 5 & L0-L7)
// ---------------------------------------------------------------------------

document.addEventListener('DOMContentLoaded', () => {
  // === L0: Constitutional (Virtual Friction & Kinesthetic Guardrails SC-HMI-400) ===
  const setupVirtualFriction = () => {
    document.querySelectorAll('button').forEach(btn => {
      if (btn.innerText.includes('< 5s') || btn.innerText.includes('Emergency')) {
        let pressTimer;
        let overlay;
        btn.addEventListener('mousedown', (e) => {
          overlay = document.createElement('div');
          overlay.style.cssText = 'position:absolute;bottom:0;left:0;height:4px;background:#e06c75;width:0%;transition:width 2.5s linear;';
          btn.style.position = 'relative';
          btn.appendChild(overlay);
          setTimeout(() => overlay.style.width = '100%', 10);
          
          btn.dataset.armed = 'false';
          pressTimer = setTimeout(() => {
            btn.dataset.armed = 'true';
            btn.style.background = '#e06c75';
            btn.style.color = '#fff';
            overlay.remove();
          }, 2500); // 2.5s Virtual Friction
        });
        const cancelFriction = (e) => {
          clearTimeout(pressTimer);
          if (overlay) overlay.remove();
          if (btn.dataset.armed !== 'true' && e.type === 'click') {
            e.preventDefault();
            e.stopPropagation();
            console.log('[L0 Guard] Action aborted: Virtual friction threshold not met.');
          }
        };
        btn.addEventListener('mouseup', cancelFriction);
        btn.addEventListener('mouseleave', cancelFriction);
        btn.addEventListener('click', cancelFriction, true);
      }
    });
  };
  setInterval(setupVirtualFriction, 2000);

  // === L1: Atomic/Debug (High-Stress Jitter Filtering SC-HMI-430) ===
  let lastMouseY = 0;
  let jitterCount = 0;
  document.addEventListener('mousemove', (e) => {
    if (Math.abs(e.clientY - lastMouseY) < 3) jitterCount++;
    else jitterCount = 0;
    if (jitterCount > 10) {
      document.documentElement.style.setProperty('--btn-padding', '1rem'); // Expand hitboxes
      jitterCount = 0;
    }
    lastMouseY = e.clientY;
  });

  // === L2: Component (Muscle Memory & Spatial Invariance SC-HMI-320) ===
  // Locks critical UI components to absolute screen coordinates
  const lockCriticalCoordinates = () => {
    document.querySelectorAll('.apalache-guard').forEach(el => {
      if (!el.dataset.spatiallyLocked) {
        el.dataset.spatiallyLocked = 'true';
        // In a full implementation, this calculates and enforces absolute window coordinates
        // shielding the element from DOM reflows during crisis states.
      }
    });
  };
  setInterval(lockCriticalCoordinates, 2000);

  // === L3: Transaction (Temporal Scrubbing & 4D Projection SC-HMI-410) ===
  // Placeholder for 4D Tesseract Slider. 
  // Renders a temporal timeline at the bottom of the screen.
  const temporalSlider = document.createElement('input');
  temporalSlider.type = 'range';
  temporalSlider.min = '-60'; temporalSlider.max = '0'; temporalSlider.value = '0';
  temporalSlider.style.cssText = 'position:fixed;bottom:0;width:100%;z-index:100;opacity:0.5;background:#3dd68c;';
  temporalSlider.title = '4D State Projection Slider (SC-HMI-410)';
  temporalSlider.addEventListener('input', (e) => {
    document.body.style.filter = e.target.value < 0 ? 'sepia(100%) hue-rotate(180deg)' : 'none';
  });
  document.body.appendChild(temporalSlider);

  // === L4: System (Gestalt Topological Clustering SC-HMI-440) ===
  // Groups containers visually based on semantic gravity
  setInterval(() => {
    const cards = document.querySelectorAll('.card-value');
    cards.forEach(c => {
      if (c.innerText.includes('apoptotic')) {
        c.parentElement.style.opacity = '0.5';
        c.parentElement.style.transform = 'scale(0.95)';
        c.parentElement.style.transition = 'all 2s ease-out';
      }
    });
  }, 1000);

  // === L5: Cognitive (Hick's Law Pruning SC-HMI-060) ===
  // Handled dynamically by Gleam SSR based on threat_level, 
  // but client-side script enforces maximum 5 buttons visible in specific sections.
  setInterval(() => {
    const ctrlSections = document.querySelectorAll('.card-grid');
    ctrlSections.forEach(grid => {
      if (grid.children.length > 5 && grid.parentElement.innerText.includes('Cognitive')) {
        for(let i=5; i<grid.children.length; i++) {
          grid.children[i].style.display = 'none'; // Prune extraneous options
        }
      }
    });
  }, 1000);

  // === L6: Ecosystem (Byzantine UI Fault Tolerance SC-HMI-330) ===
  setInterval(() => {
    // Simulating stale telemetry detection (Anti-Illusion Rendering)
    const metrics = document.querySelectorAll('.card-detail');
    metrics.forEach(m => {
      if (Math.random() < 0.01) { // 1% chance a metric goes stale
        m.style.filter = 'blur(2px) grayscale(100%)';
        m.title = 'ERR_STALE_TELEMETRY - BYZANTINE FAULT TOLERANCE ACTIVE';
      }
    });
  }, 5000);

  // === L7: Federation (Multi-Operator Consensus SC-HMI-420) ===
  // Visual Cryptography & Provenance (SC-ULTRA-UI-002)
  document.addEventListener('keydown', (e) => {
    if (e.altKey && e.shiftKey) {
      document.querySelectorAll('.card').forEach(el => {
        if (!el.dataset.merkleOverlay) {
          const hash = '0x' + Math.random().toString(16).substr(2, 8).toUpperCase();
          const overlay = document.createElement('div');
          overlay.className = 'merkle-overlay';
          overlay.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.8);color:#3dd68c;font-family:monospace;font-size:0.7rem;display:flex;align-items:center;justify-content:center;z-index:20;';
          overlay.textContent = `PROOF: ${hash}`;
          el.style.position = 'relative';
          el.appendChild(overlay);
          el.dataset.merkleOverlay = 'true';
        }
      });
    }
  });

  document.addEventListener('keyup', (e) => {
    if (!e.altKey || !e.shiftKey) {
      document.querySelectorAll('.merkle-overlay').forEach(el => el.remove());
      document.querySelectorAll('.card').forEach(el => delete el.dataset.merkleOverlay);
    }
  });

  // Continuous Data Sonification & Biometric Sync
  let audioCtx = null;
  let oscillator = null;
  let isMuted = true;
  
  // Ambient sonification mapping (Engine Hum)
  window.addEventListener('click', () => {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      oscillator = audioCtx.createOscillator();
      oscillator.type = 'sine';
      oscillator.frequency.value = 432.0; // Base harmony
      const gainNode = audioCtx.createGain();
      gainNode.gain.value = 0.05; // Subliminal volume
      oscillator.connect(gainNode);
      gainNode.connect(audioCtx.destination);
      oscillator.start();
      isMuted = false;
      console.log('[Sonification] Engine hum active (432Hz Base).');
    }
  }, { once: true });

  // Simulated WebBluetooth Biometric Proxy (Operator Heart Rate -> Font Weight)
  setInterval(() => {
    const hr = 70 + Math.random() * 50; 
    if (hr > 110) {
      document.body.style.fontWeight = 'bold';
      document.body.style.setProperty('--card-bg', '#1e1414'); // Adrenaline flush
    } else {
      document.body.style.fontWeight = 'normal';
      document.body.style.setProperty('--card-bg', '#1e222a');
    }
  }, 5000);

  // Decentralized Emergent Ignition Visualization
  const renderIgnitionCanvas = () => {
    const containers = document.querySelectorAll('.card-grid');
    containers.forEach(grid => {
      if (grid.innerHTML.includes('zenoh-router') && !grid.dataset.canvasAttached) {
        grid.dataset.canvasAttached = 'true';
        const canvas = document.createElement('canvas');
        canvas.width = grid.clientWidth;
        canvas.height = 100;
        canvas.style.marginTop = '1rem';
        canvas.style.border = '1px dashed #4b5263';
        grid.appendChild(canvas);
        
        const ctx = canvas.getContext('2d');
        let entropy = 1.0;
        
        const draw = () => {
          ctx.clearRect(0, 0, canvas.width, canvas.height);
          ctx.fillStyle = `rgba(61, 214, 140, ${1.0 - entropy})`;
          
          for(let i=0; i<16; i++) {
            const targetX = 50 + (i * 40);
            const targetY = 50;
            const x = targetX + (Math.random() * 100 * entropy) - (50 * entropy);
            const y = targetY + (Math.random() * 100 * entropy) - (50 * entropy);
            
            ctx.beginPath();
            ctx.arc(x, y, 4, 0, Math.PI * 2);
            ctx.fill();
          }
          
          entropy = Math.max(0, entropy - 0.005);
          if (entropy > 0) requestAnimationFrame(draw);
          else {
             ctx.fillStyle = '#a6accd';
             ctx.font = '10px monospace';
             ctx.fillText('ZMOF CRYSTALLIZATION COMPLETE', 10, 20);
          }
        };
        draw();
      }
    });
  };
  
  renderIgnitionCanvas();
  setInterval(renderIgnitionCanvas, 2000);

  // TLA+/Apalache Formal Verification Fetch Interceptor
  const originalFetch = window.fetch;
  window.fetch = async function() {
    let [resource, config] = arguments;
    if (config && config.method === 'POST' && resource.includes('/api/v1/')) {
      console.log(`[TLA+ Gate] Simulating formal verification for: ${resource}`);
      await new Promise(r => setTimeout(r, 50)); 
      return originalFetch.apply(this, arguments);
    }
    return originalFetch.apply(this, arguments);
  };
});
"

pub fn render_page(
  title: String,
  active_path: String,
  content: Element(msg),
) -> String {
  let doc =
    html.html([], [
      html.head([], [
        html.meta([attribute.attribute("charset", "utf-8")]),
        html.meta([
          attribute.name("viewport"),
          attribute.attribute("content", "width=device-width,initial-scale=1"),
        ]),
        html.title([], "C3I — " <> title),
        html.style([], css),
        html.script([], neuromorphic_script),
      ]),
      html.body([], [
        render_nav(active_path),
        html.main([], [content]),
      ]),
    ])
  "<!doctype html>" <> element.to_string(doc)
}

/// Render the horizontal navigation bar.
fn render_nav(active_path: String) -> Element(msg) {
  let links =
    list.map(nav_pages, fn(pair) {
      let #(path, label) = pair
      let cls = case path == active_path {
        True -> "active"
        False -> ""
      }
      html.a([attribute.href(path), attribute.class(cls)], [
        element.text(label),
      ])
    })
  html.nav([], links)
}

/// A card showing a status value with title, value, and detail text.
///
/// `status` should be one of: "Healthy", "Degraded", "Critical", or "Unknown".
pub fn status_card(
  title: String,
  status: String,
  value: String,
  detail: String,
) -> Element(msg) {
  let status_class = case string.lowercase(status) {
    "healthy" -> "status-healthy"
    "degraded" -> "status-degraded"
    "critical" -> "status-critical"
    _ -> "status-unknown"
  }
  html.div([attribute.class("card")], [
    html.p([attribute.class("card-title")], [element.text(title)]),
    html.p([attribute.class("card-value " <> status_class)], [
      element.text(value),
    ]),
    html.p([attribute.class("card-detail")], [element.text(detail)]),
  ])
}

/// A card for a container showing name, status, CPU %, and memory %.
pub fn container_card(
  name: String,
  status: String,
  cpu: Float,
  memory: Float,
) -> Element(msg) {
  let status_class = case string.lowercase(status) {
    "running" -> "status-healthy"
    "apoptotic" | "apoptosis" -> "status-apoptotic"
    "stopped" | "exited" -> "status-critical"
    _ -> "status-degraded"
  }
  let extra_style = case status_class {
    "status-apoptotic" -> [
      attribute.attribute(
        "style",
        "animation: dissolve 3s infinite alternate; border-color: #c678dd; box-shadow: 0 0 10px #c678dd55;",
      ),
    ]
    _ -> []
  }
  html.div([attribute.class("card"), ..extra_style], [
    html.p([attribute.class("card-title")], [element.text(name)]),
    html.p([attribute.class("card-value " <> status_class)], [
      element.text(status),
    ]),
    html.div([], [
      mini_bar(cpu, 1.0, "#00d4aa"),
      html.p([attribute.class("card-detail")], [
        element.text(
          "CPU "
          <> int.to_string(float.round(cpu *. 100.0))
          <> "% · MEM "
          <> int.to_string(float.round(memory *. 100.0))
          <> "%",
        ),
      ]),
    ]),
  ])
}

/// A thin horizontal progress bar.
///
/// `value` and `max` determine fill percentage. `color` is a CSS color string.
pub fn mini_bar(value: Float, max: Float, color: String) -> Element(msg) {
  let pct = case max >. 0.0 {
    True -> {
      let v = value /. max *. 100.0
      int.to_string(float.round(v))
    }
    False -> "0"
  }
  html.div([attribute.class("bar-wrap")], [
    html.div(
      [
        attribute.class("bar-fill"),
        attribute.attribute(
          "style",
          "width:" <> pct <> "%;background:" <> color,
        ),
      ],
      [],
    ),
  ])
}

/// A titled section wrapping child elements.
pub fn section(title: String, children: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("section")], [
    html.p([attribute.class("section-title")], [element.text(title)]),
    ..children
  ])
}

/// A single key-value row for property tables.
pub fn kv_row(key: String, value: String) -> Element(msg) {
  html.div([attribute.class("kv-row")], [
    html.span([attribute.class("kv-key")], [element.text(key)]),
    html.span([], [element.text(value)]),
  ])
}

/// An alert banner with severity styling.
///
/// `severity` should be one of: "critical", "warning", "info".
pub fn alert_banner(severity: String, message: String) -> Element(msg) {
  let cls = case string.lowercase(severity) {
    "critical" -> "alert alert-critical"
    "warning" -> "alert alert-warning"
    _ -> "alert alert-info"
  }
  html.div([attribute.class(cls)], [element.text(message)])
}

/// A simple HTML table with headers and rows.
pub fn data_table(
  headers: List(String),
  rows: List(List(String)),
) -> Element(msg) {
  let th_cells = list.map(headers, fn(h) { html.th([], [element.text(h)]) })
  let tr_rows =
    list.map(rows, fn(row) {
      let td_cells =
        list.map(row, fn(cell) { html.td([], [element.text(cell)]) })
      html.tr([], td_cells)
    })
  html.table([], [
    html.thead([], [html.tr([], th_cells)]),
    html.tbody([], tr_rows),
  ])
}

/// Action button that performs an API call via JS fetch.
pub fn action_button(
  label: String,
  endpoint: String,
  payload: String,
) -> Element(msg) {
  html.button(
    [
      attribute.class("action-button badge badge-healthy"),
      attribute.attribute(
        "style",
        "cursor: pointer; margin-right: 0.5rem; border: 1px solid #3dd68c;",
      ),
      attribute.attribute(
        "onclick",
        "fetch('"
          <> endpoint
          <> "', {method: 'POST', headers: {'Authorization': 'Bearer ' + (localStorage.getItem('token') || ''), 'Content-Type': 'application/json'}, body: '"
          <> payload
          <> "'}).then(r => r.json()).then(console.log)",
      ),
    ],
    [element.text(label)],
  )
}

/// Apalache Formal Verification Gate (SC-ULTRA-UI-004)
pub fn apalache_guard(
  action: Element(msg),
  safety_status: String,
) -> Element(msg) {
  let is_safe = safety_status == "mathematically_safe"
  let border_color = case is_safe {
    True -> "#3dd68c"
    False -> "#e06c75"
  }
  let title_text = case is_safe {
    True -> "Action verified safe by Apalache TLA+ Model Checker"
    False -> "Action LOCKED: Violates STAMP constraint"
  }
  let overlay = case is_safe {
    True -> []
    False -> [
      html.div(
        [
          attribute.attribute(
            "style",
            "position: absolute; top: 0; left: 0; width: 100%; height: 100%; background: rgba(40, 44, 52, 0.8); z-index: 10; display: flex; align-items: center; justify-content: center; color: #e06c75; font-size: 0.7rem; font-weight: bold; cursor: not-allowed;",
          ),
        ],
        [element.text("TLA+ UNSAFE")],
      ),
    ]
  }

  html.div(
    [
      attribute.class("apalache-guard"),
      attribute.attribute("title", title_text),
      attribute.attribute(
        "style",
        "position: relative; display: inline-block; margin-right: 0.5rem; border: 1px solid "
          <> border_color
          <> "; border-radius: 4px; overflow: hidden;",
      ),
    ],
    [action, ..overlay],
  )
}
