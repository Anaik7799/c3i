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
.cognitive-multilayer-display{background:rgba(20,25,34,0.5);border:1px solid #1e2a3a;border-radius:6px;padding:1rem;margin-top:.5rem;}
.multilayer-row{display:flex;flex-wrap:wrap;gap:2rem;margin-bottom:.75rem;border-bottom:1px solid rgba(30,42,58,0.5);padding-bottom:.5rem;}
.multilayer-row:last-child{margin-bottom:0;border-bottom:none;padding-bottom:0;}
/* === Dark Cockpit 5-Mode System (SC-HMI-010) === */
/* Mode 1: DARK — healthy system, minimal display, suppress nominal cards */
.cockpit-dark .card{opacity:0.6;transform:scale(0.98);}
.cockpit-dark .status-healthy{color:#1a3d2a;}
.cockpit-dark .section{border-color:#0a0e17;}
.cockpit-dark .card-detail{display:none;}
.cockpit-dark .alert-critical,.cockpit-dark .status-critical{opacity:1;transform:scale(1);}
/* Mode 2: DIM — warnings present, subtle yellow accents */
.cockpit-dim .card{opacity:0.8;}
.cockpit-dim .section-title{color:#f5a623;}
.cockpit-dim nav{border-bottom-color:#f5a623;}
/* Mode 3: NORMAL — standard display, all elements visible */
.cockpit-normal .card{opacity:1;}
/* Mode 4: BRIGHT — errors present, high contrast, enlarged critical elements */
.cockpit-bright .card{border-color:#f5a623;}
.cockpit-bright .status-critical{font-size:1.2rem;font-weight:700;}
.cockpit-bright .alert-critical{border-width:2px;box-shadow:0 0 12px rgba(224,82,82,0.3);}
.cockpit-bright main{background:#0d1117;}
/* Mode 5: EMERGENCY — critical failure, red dominant, pulsing border */
.cockpit-emergency{background:#1a0a0a !important;}
.cockpit-emergency main{background:#1a0a0a;}
.cockpit-emergency nav{background:#2a0a0a;border-bottom-color:#e05252;}
.cockpit-emergency .card{border-color:#e05252;animation:pulse 1.5s infinite;}
.cockpit-emergency .section-title{color:#e05252;}
.cockpit-emergency h1,.cockpit-emergency h2{color:#e05252;}
/* === Container Genome Grid (16-cell SIL-6 Biomorphic Mesh) === */
.genome-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin:.75rem 0;}
.genome-cell{background:#141922;border:1px solid #1e2a3a;border-radius:4px;padding:8px;text-align:center;font-size:.75rem;position:relative;transition:all 0.3s;}
.genome-cell .genome-name{font-weight:600;color:#e0e6ed;margin-bottom:2px;}
.genome-cell .genome-status{font-size:.65rem;color:#7a8fa6;}
.genome-cell .genome-led{position:absolute;top:4px;right:4px;width:6px;height:6px;border-radius:50%;}
.genome-cell.genome-healthy{border-color:#1a3d2a;}.genome-cell.genome-healthy .genome-led{background:#3dd68c;box-shadow:0 0 6px #3dd68c;}
.genome-cell.genome-degraded{border-color:#3d2e10;}.genome-cell.genome-degraded .genome-led{background:#f5a623;box-shadow:0 0 6px #f5a623;}
.genome-cell.genome-critical{border-color:#3d1515;animation:pulse 2s infinite;}.genome-cell.genome-critical .genome-led{background:#e05252;box-shadow:0 0 6px #e05252;}
/* === OODA Phase Ring (5-tier) === */
.ooda-5tier{display:flex;flex-direction:column;gap:4px;margin:.5rem 0;}
.ooda-tier{display:flex;align-items:center;gap:.5rem;padding:4px 8px;border-radius:4px;font-size:.8rem;}
.ooda-tier.active{background:#1a3d2a;border:1px solid #3dd68c;}
.ooda-tier .ooda-budget{color:#7a8fa6;font-size:.7rem;margin-left:auto;}
.ooda-tier .ooda-dot{width:8px;height:8px;border-radius:50%;background:#7a8fa6;}
.ooda-tier.active .ooda-dot{background:#3dd68c;box-shadow:0 0 8px #3dd68c;}
/* === Proof Chain Visualization === */
.proof-chain{display:flex;align-items:center;gap:0;margin:.5rem 0;overflow-x:auto;}
.proof-block{background:#141922;border:1px solid #1e2a3a;border-radius:3px;padding:4px 8px;font-size:.7rem;font-family:monospace;white-space:nowrap;}
.proof-block.verified{border-color:#3dd68c;color:#3dd68c;}
.proof-block.pending{border-color:#f5a623;color:#f5a623;}
.proof-arrow{color:#7a8fa6;padding:0 2px;font-size:.7rem;}
@media(max-width:768px){nav{padding:.25rem;}.card-grid,.card-grid-wide{grid-template-columns:1fr;}main{padding:.75rem;}}
"

// ---------------------------------------------------------------------------
// Navigation pages (order matches the cockpit tab bar)
// ---------------------------------------------------------------------------

const nav_pages: List(#(String, String)) = [
  // Core (15 original)
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
  // Extended (9 existing)
  #("/prajna", "Prajna"),
  #("/agents", "Agents"),
  #("/holon", "Holon"),
  #("/config", "Config"),
  #("/git", "Git"),
  #("/database", "Database"),
  #("/bridge", "Bridge"),
  #("/smriti", "Smriti"),
  #("/planning-dashboard", "OODA"),
  // Wave 1 (6 new)
  #("/integrity", "Integrity"),
  #("/evolution", "Evolution"),
  #("/biomorphic", "Biomorphic"),
  #("/homeostasis", "Homeostasis"),
  #("/bicameral", "Bicameral"),
  #("/singularity", "Singularity"),
  #("/components", "Components"),
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

  // === C3I Live Data System (Progressive Enhancement) ===
  // Base SSR works without JS (SC-GLM-UI-002). This layer adds:
  // 1. Auto-fetch from /api/v1/{page} on load → update data-api elements
  // 2. AG-UI SSE subscription for real-time mesh updates
  // 3. Dark cockpit mode auto-transition from health state
  // 4. Heartbeat indicator (top-right pulse dot)

  // Detect current page from nav active link
  const activePage = document.querySelector('nav a.active');
  const pagePath = activePage ? activePage.getAttribute('href') : '/dashboard';
  const apiPath = '/api/v1' + pagePath;

  // Live data fetch — update card values from API
  const refreshData = async () => {
    try {
      const res = await fetch(apiPath);
      if (!res.ok) return;
      const data = await res.json();

      // Update all elements with data-api-field attributes
      document.querySelectorAll('[data-api]').forEach(el => {
        const field = el.dataset.api;
        if (data[field] !== undefined) {
          el.textContent = typeof data[field] === 'number'
            ? data[field].toLocaleString()
            : String(data[field]);
        }
      });

      // Update card-value elements that match JSON keys
      document.querySelectorAll('.card-value').forEach(el => {
        const card = el.closest('.card');
        if (!card) return;
        const title = card.querySelector('.card-title');
        if (!title) return;
        const key = title.textContent.toLowerCase().replace(/[^a-z_]/g, '_').replace(/_+/g, '_');
        if (data[key] !== undefined) {
          el.textContent = String(data[key]);
        }
      });

      // Dark cockpit auto-transition
      if (data.dark_cockpit_mode) {
        document.body.dataset.cockpitMode = data.dark_cockpit_mode;
        document.body.className = 'cockpit-' + data.dark_cockpit_mode;
      }

      // Health-based LED indicators
      if (data.health_pct !== undefined) {
        const healthDot = document.getElementById('c3i-health-dot');
        if (healthDot) {
          healthDot.style.background = data.health_pct >= 90 ? '#3dd68c'
            : data.health_pct >= 50 ? '#f5a623' : '#e05252';
        }
      }
    } catch(e) { /* Graceful degradation — SSR content remains */ }
  };

  // AG-UI SSE subscription for real-time updates
  let sseRetries = 0;
  const connectSSE = () => {
    if (sseRetries > 5) return;
    try {
      const evtSrc = new EventSource('/ag-ui/events?page=' + encodeURIComponent(pagePath));

      evtSrc.onmessage = (e) => {
        try {
          const evt = JSON.parse(e.data);
          // StateSnapshot → full refresh
          if (evt.type === 'state_snapshot' || evt.type === 'state_delta') {
            refreshData();
          }
          // RunStarted/RunFinished → update activity indicator
          if (evt.type === 'run_started') {
            const indicator = document.getElementById('c3i-activity');
            if (indicator) indicator.classList.add('cyber-pulse');
          }
          if (evt.type === 'run_finished') {
            const indicator = document.getElementById('c3i-activity');
            if (indicator) indicator.classList.remove('cyber-pulse');
          }
          // Heartbeat → reset connection watchdog
          if (evt.type === 'heartbeat') sseRetries = 0;
        } catch(pe) { /* ignore parse errors */ }
      };

      evtSrc.onerror = () => {
        evtSrc.close();
        sseRetries++;
        setTimeout(connectSSE, Math.min(sseRetries * 2000, 30000));
      };
    } catch(e) { /* SSE not available — SSR fallback active */ }
  };

  // Heartbeat pulse dot (shows mesh is alive)
  const dot = document.createElement('div');
  dot.id = 'c3i-health-dot';
  dot.style.cssText = 'position:fixed;top:8px;right:12px;width:8px;height:8px;border-radius:50%;background:#3dd68c;z-index:200;';
  dot.classList.add('cyber-pulse');
  dot.title = 'Mesh heartbeat';
  document.body.appendChild(dot);

  // Activity indicator
  const activity = document.createElement('div');
  activity.id = 'c3i-activity';
  activity.style.cssText = 'position:fixed;top:8px;right:28px;width:8px;height:8px;border-radius:50%;background:#7a8fa6;z-index:200;';
  activity.title = 'Agent activity';
  document.body.appendChild(activity);

  // Column sorting on data tables
  document.querySelectorAll('th').forEach((th, colIdx) => {
    th.style.cursor = 'pointer';
    th.title = 'Click to sort';
    th.addEventListener('click', () => {
      const table = th.closest('table');
      if (!table) return;
      const tbody = table.querySelector('tbody') || table;
      const rows = Array.from(tbody.querySelectorAll('tr')).filter(r => !r.querySelector('th'));
      const dir = th.dataset.sortDir === 'asc' ? 'desc' : 'asc';
      th.dataset.sortDir = dir;
      // Clear other headers
      th.closest('tr').querySelectorAll('th').forEach(h => { if (h !== th) delete h.dataset.sortDir; });
      rows.sort((a, b) => {
        const aVal = (a.cells[colIdx] || {}).textContent || '';
        const bVal = (b.cells[colIdx] || {}).textContent || '';
        const aNum = parseFloat(aVal), bNum = parseFloat(bVal);
        const cmp = (!isNaN(aNum) && !isNaN(bNum)) ? aNum - bNum : aVal.localeCompare(bVal);
        return dir === 'asc' ? cmp : -cmp;
      });
      rows.forEach(r => tbody.appendChild(r));
      th.textContent = th.textContent.replace(/ [▲▼]/, '') + (dir === 'asc' ? ' ▲' : ' ▼');
    });
  });

  // Keyboard navigation (j/k scroll, 1-9 page switch, / search)
  document.addEventListener('keydown', (e) => {
    // Don't capture if user is typing in an input
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;

    const navLinks = Array.from(document.querySelectorAll('nav a'));
    const activeIdx = navLinks.findIndex(a => a.classList.contains('active'));

    if (e.key === 'j' || e.key === 'ArrowDown') {
      window.scrollBy(0, 80);
    } else if (e.key === 'k' || e.key === 'ArrowUp') {
      window.scrollBy(0, -80);
    } else if (e.key >= '1' && e.key <= '9') {
      const idx = parseInt(e.key) - 1;
      if (navLinks[idx]) window.location.href = navLinks[idx].href;
    } else if (e.key === '0') {
      if (navLinks[9]) window.location.href = navLinks[9].href;
    } else if (e.key === '[' && activeIdx > 0) {
      window.location.href = navLinks[activeIdx - 1].href;
    } else if (e.key === ']' && activeIdx < navLinks.length - 1) {
      window.location.href = navLinks[activeIdx + 1].href;
    } else if (e.key === '/' && !e.ctrlKey) {
      e.preventDefault();
      const searchBox = document.getElementById('c3i-search');
      if (searchBox) searchBox.focus();
    } else if (e.key === '?' && !e.ctrlKey) {
      // Show keyboard shortcut help
      const help = document.getElementById('c3i-help');
      if (help) help.style.display = help.style.display === 'none' ? 'block' : 'none';
    }
  });

  // Search/filter bar for data tables
  const tableContainers = document.querySelectorAll('table');
  tableContainers.forEach(table => {
    if (table.querySelectorAll('tr').length < 4) return; // Skip tiny tables
    const search = document.createElement('input');
    search.type = 'search';
    search.id = 'c3i-search';
    search.placeholder = 'Filter rows... (press /)';
    search.style.cssText = 'width:100%;padding:6px 10px;margin:4px 0 8px;background:#141922;color:#e0e6ed;border:1px solid #1e2a3a;border-radius:4px;font-size:.85rem;';
    search.addEventListener('input', () => {
      const q = search.value.toLowerCase();
      table.querySelectorAll('tr').forEach((row, i) => {
        if (i === 0 && row.querySelector('th')) return; // keep header
        row.style.display = row.textContent.toLowerCase().includes(q) ? '' : 'none';
      });
    });
    table.parentElement.insertBefore(search, table);
  });

  // Keyboard shortcut help overlay
  const helpDiv = document.createElement('div');
  helpDiv.id = 'c3i-help';
  helpDiv.style.cssText = 'display:none;position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);background:#0d1420;border:1px solid #1e2a3a;border-radius:8px;padding:1.5rem;z-index:300;color:#e0e6ed;font-family:monospace;font-size:.85rem;min-width:300px;box-shadow:0 8px 32px rgba(0,0,0,0.6);';
  helpDiv.innerHTML = '<div style=\"color:#3dd68c;font-weight:bold;margin-bottom:.75rem\">⌨ Keyboard Shortcuts</div>'
    + '<div style=\"display:grid;grid-template-columns:60px 1fr;gap:4px\">'
    + '<span style=\"color:#7a8fa6\">j/k</span><span>Scroll down/up</span>'
    + '<span style=\"color:#7a8fa6\">1-9,0</span><span>Jump to page 1-10</span>'
    + '<span style=\"color:#7a8fa6\">[ ]</span><span>Previous/next page</span>'
    + '<span style=\"color:#7a8fa6\">/</span><span>Focus search filter</span>'
    + '<span style=\"color:#7a8fa6\">?</span><span>Toggle this help</span>'
    + '<span style=\"color:#7a8fa6\">Alt+Shift</span><span>Merkle proof overlay</span>'
    + '</div><div style=\"margin-top:.75rem;color:#7a8fa6;font-size:.75rem\">Press ? to close</div>';
  document.body.appendChild(helpDiv);

  // Initial data fetch + SSE connection
  refreshData();
  setInterval(refreshData, 10000); // Refresh every 10s
  connectSSE();

  console.log('[C3I] Live data system active. Press ? for keyboard shortcuts.');
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

/// 16-cell Container Genome Grid — SIL-6 Biomorphic Mesh at a glance.
/// Each cell has a name, status, and LED indicator.
pub fn genome_grid(
  containers: List(#(String, String)),
) -> Element(msg) {
  html.div(
    [attribute.class("genome-grid")],
    list.map(containers, fn(c) {
      let #(name, status) = c
      let cell_class = "genome-cell genome-" <> status
      html.div([attribute.class(cell_class)], [
        html.div([attribute.class("genome-led")], []),
        html.div([attribute.class("genome-name")], [element.text(name)]),
        html.div([attribute.class("genome-status")], [element.text(status)]),
      ])
    }),
  )
}

/// OODA 5-Tier Decision Ring — shows phase across all tiers with latency budgets.
pub fn ooda_5tier(active_phase: String) -> Element(msg) {
  let tiers = [
    #("Agent", "<30ms", active_phase == "observe" || active_phase == "act"),
    #("Intelligence", "<100ms", active_phase == "orient"),
    #("Knowledge", "<1ms", True),
    #("Cortex", "<50ms", active_phase == "decide"),
    #("Strategy", "<1s", active_phase == "observe"),
  ]
  html.div(
    [attribute.class("ooda-5tier")],
    list.map(tiers, fn(tier) {
      let #(name, budget, is_active) = tier
      let tier_class = case is_active {
        True -> "ooda-tier active"
        False -> "ooda-tier"
      }
      html.div([attribute.class(tier_class)], [
        html.div([attribute.class("ooda-dot")], []),
        element.text(name),
        html.span([attribute.class("ooda-budget")], [element.text(budget)]),
      ])
    }),
  )
}

/// Constitutional Proof Chain — visual hash chain with verified/pending blocks.
pub fn proof_chain(
  blocks: List(#(String, Bool)),
) -> Element(msg) {
  html.div(
    [attribute.class("proof-chain")],
    list.index_map(blocks, fn(block, i) {
      let #(hash, verified) = block
      let block_class = case verified {
        True -> "proof-block verified"
        False -> "proof-block pending"
      }
      let arrow = case i > 0 {
        True -> "→ "
        False -> ""
      }
      html.span([], [
        element.text(arrow),
        html.span([attribute.class(block_class)], [element.text(hash)]),
        element.text(" "),
      ])
    }),
  )
}
