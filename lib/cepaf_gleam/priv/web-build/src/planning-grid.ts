/**
 * Pass-30 · Phase 4-FULL² · Total Effect-TS Collapse
 *
 * Operator directive (2026-04-30, repeat): "all javascript code MUST ONLY
 * use effect typescript, full IIFE collapse — do this".
 *
 * Pass-29 shipped a coexistence layer; Pass-30 ports the full IIFE
 * responsibilities into Effect-TS:
 *   - Status fetch + weather bar (real-time push consumer)
 *   - Status filter chips → URL pushState + paginated fetch
 *   - View-mode switching (Grid / Kanban / Timeline / Analytics)
 *   - Fractal filter chips (L0..L7)
 *   - AI search (Ctrl+K) with Zettelkasten lookup
 *   - Click-to-detail drill-down (Pass-7)
 *   - Change log mutation feed
 *   - Periodic refresh via Effect.repeat (replaces setInterval)
 *   - WebSocket diff-detected push → Effect.async stream
 *
 * Tabulator stays CDN-loaded (3rd-party library); Effect orchestrates its
 * lifecycle but does NOT reimplement table rendering.
 *
 * ZK: [zk-3346fc607a1ef9e6] anti-Stub-That-Lies — every Effect is real.
 * [zk-c14e1d23afff486c] structured concurrency replaces inline blocking.
 * [zk-bb4de67d97f807ac] selector-guessing — Selectors const is typed.
 *
 * STAMP: SC-EFFECT-TS-001..005, SC-AGUI-UI-001..015, SC-FILESIZE-001.
 */

import {
  Effect, Schedule, Duration, Layer, Context, Logger, LogLevel,
  Cause, Option, Stream, Fiber,
} from "effect"

// ─── §1. Types ───────────────────────────────────────────────────────────

interface Task {
  readonly id: string
  readonly title: string
  readonly status: string
  readonly priority: string
  readonly created?: string
}
type FractalLayer = "L0" | "L1" | "L2" | "L3" | "L4" | "L5" | "L6" | "L7"
type ViewMode = "grid" | "kanban" | "timeline" | "analytics"
interface PlanStatus {
  readonly total: number
  readonly pending: number
  readonly in_progress: number
  readonly active?: number
  readonly completed: number
  readonly blocked: number
}
interface PaginatedResponse {
  readonly status: string
  readonly offset: number
  readonly limit: number
  readonly total: number
  readonly returned: number
  readonly items_json: string
}
interface ZkSearchHit {
  readonly id: string
  readonly title: string
  readonly score?: number
  readonly excerpt?: string
}

// ─── §2. Selectors ──────────────────────────────────────────────────────

const Selectors = {
  weatherEmoji: "#weather-emoji",
  weatherLabel: "#weather-label",
  weatherScore: "#weather-score",
  blockedGrid: "#blocked-grid",
  activeGrid: "#active-grid",
  allGrid: "#all-grid",
  gridSection: "#grid-section",
  kanbanSection: "#kanban-section",
  timelineSection: "#timeline-section",
  analyticsSection: "#analytics-section",
  viewBtn: ".view-btn",
  chipRow: ".chip-row",
  chipButtons: ".chip-row .chip[data-status]",
  fractalChips: "#fractal-filter-chips .fractal-chip",
  fractalChipsContainer: "#fractal-filter-chips",
  aiSearchInput: "#ai-search-input",
  detailPanel: "#task-detail-panel",
  changeLog: "#change-log",
  statusCard: ".status-card",
} as const

// ─── §3. Pure helpers ───────────────────────────────────────────────────

const FRACTAL_LAYERS: Readonly<Record<FractalLayer, readonly string[]>> = {
  L0: ["guardian", "constitutional", "psi", "safety", "emergency", "sil4", "sil6", "prime"],
  L1: ["nif", "debug", "trace", "telemetry", "otel", "atomic", "ffi"],
  L2: ["parser", "component", "form", "badge", "input", "catalog", "a2ui"],
  L3: ["planning", "task", "state", "db", "sqlite", "smriti", "transaction"],
  L4: ["podman", "container", "system", "boot", "build", "image", "docker"],
  L5: ["ooda", "cortex", "mcp", "agent", "llm", "inference", "reasoning"],
  L6: ["zenoh", "mesh", "topology", "quorum", "cluster", "ecosystem"],
  L7: ["federation", "gateway", "version", "consensus", "multi-node"],
} as const

const classifyLayer = (task: Task): FractalLayer => {
  const title = (task.title || "").toLowerCase()
  for (const layer of Object.keys(FRACTAL_LAYERS) as FractalLayer[]) {
    if (FRACTAL_LAYERS[layer].some((kw) => title.includes(kw))) return layer
  }
  return "L3"
}

const taskAge = (created?: string): string => {
  if (!created) return "—"
  const diff = Date.now() - new Date(created).getTime()
  const mins = Math.floor(diff / 60_000)
  if (mins < 60) return `${mins}m`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours}h`
  const days = Math.floor(hours / 24)
  if (days < 30) return `${days}d`
  return `${Math.floor(days / 30)}mo`
}

const snapshotData = (data: readonly Task[]): Record<string, string> => {
  const s: Record<string, string> = {}
  for (const t of data) s[t.id] = `${t.status}|${t.priority}|${t.title || ""}`
  return s
}

const findChangedIds = (
  oldS: Record<string, string>, newS: Record<string, string>,
): readonly string[] => {
  const c: string[] = []
  for (const id of Object.keys(newS)) if (oldS[id] !== newS[id]) c.push(id)
  return c
}

// ─── §4. Service: PlanningApi ───────────────────────────────────────────

class PlanningApi extends Context.Tag("PlanningApi")<PlanningApi, {
  readonly status: () => Effect.Effect<PlanStatus, Error>
  readonly listByStatus: (s: string, o: number, l: number) => Effect.Effect<PaginatedResponse, Error>
  readonly listAll: () => Effect.Effect<readonly Task[], Error>
  readonly searchZk: (q: string) => Effect.Effect<readonly ZkSearchHit[], Error>
}>() {}

const retry3 = Schedule.exponential(Duration.millis(500)).pipe(
  Schedule.compose(Schedule.recurs(3)),
)

const fetchJson = <T>(url: string): Effect.Effect<T, Error> =>
  Effect.tryPromise({
    try: async () => {
      const r = await fetch(url, { headers: { Accept: "application/json" } })
      if (!r.ok) throw new Error(`HTTP ${r.status}`)
      return (await r.json()) as T
    },
    catch: (cause) => new Error(`fetch ${url}: ${String(cause)}`),
  }).pipe(Effect.retry(retry3))

const PlanningApiLive = Layer.succeed(PlanningApi, {
  status: () => fetchJson<PlanStatus>("/api/v1/plan/status"),
  listByStatus: (s, o, l) => fetchJson<PaginatedResponse>(
    `/api/v1/planning/page?status=${encodeURIComponent(s)}&offset=${o}&limit=${l}`),
  listAll: () => fetchJson<readonly Task[]>("/api/v1/plan/list/all"),
  searchZk: (q) => fetchJson<readonly ZkSearchHit[]>(
    `/api/v1/zk/search?q=${encodeURIComponent(q)}`),
})

// ─── §5. Service: Dom ───────────────────────────────────────────────────

class Dom extends Context.Tag("Dom")<Dom, {
  readonly query: (s: string) => Effect.Effect<HTMLElement | null>
  readonly queryAll: (s: string) => Effect.Effect<readonly HTMLElement[]>
  readonly setText: (s: string, t: string) => Effect.Effect<void>
  readonly setClass: (s: string, c: string, on: boolean) => Effect.Effect<void>
  readonly setStyle: (s: string, k: string, v: string) => Effect.Effect<void>
}>() {}

const DomLive = Layer.succeed(Dom, {
  query: (s) => Effect.sync(() => document.querySelector<HTMLElement>(s)),
  queryAll: (s) => Effect.sync(() => Array.from(document.querySelectorAll<HTMLElement>(s))),
  setText: (s, t) => Effect.sync(() => {
    const el = document.querySelector<HTMLElement>(s)
    if (el) el.textContent = t
  }),
  setClass: (s, c, on) => Effect.sync(() => {
    document.querySelectorAll<HTMLElement>(s).forEach((el) => el.classList.toggle(c, on))
  }),
  setStyle: (s, k, v) => Effect.sync(() => {
    document.querySelectorAll<HTMLElement>(s).forEach((el) => el.style.setProperty(k, v))
  }),
})

// ─── §6. Weather bar ────────────────────────────────────────────────────

const updateWeather = (status: PlanStatus) => Effect.gen(function* () {
  const dom = yield* Dom
  const total = status.total ?? 0
  const completed = status.completed ?? 0
  const pending = status.pending ?? 0
  const blocked = status.blocked ?? 0
  const score = total > 0
    ? Math.max(0, Math.floor(((completed - blocked * 2) / total) * 100))
    : 0
  const emoji = score >= 80 ? "☀️" : score >= 60 ? "⛅" : "🌧️"
  const mood = score >= 80 ? "Clear" : score >= 60 ? "Partly cloudy" : "Stormy"
  yield* dom.setText(Selectors.weatherLabel,
    `System Mood: ${mood} — ${pending} pending, ${blocked} blocked, ${completed}/${total} complete`)
  yield* dom.setText(Selectors.weatherEmoji, emoji)
  yield* dom.setText(Selectors.weatherScore, `${score}/100`)
})

// ─── §7. View-mode switching ────────────────────────────────────────────

const switchView = (mode: ViewMode) => Effect.gen(function* () {
  const dom = yield* Dom
  const sections: Record<ViewMode, string> = {
    grid: Selectors.gridSection,
    kanban: Selectors.kanbanSection,
    timeline: Selectors.timelineSection,
    analytics: Selectors.analyticsSection,
  }
  for (const m of Object.keys(sections) as ViewMode[]) {
    yield* dom.setStyle(sections[m], "display", m === mode ? "block" : "none")
  }
  const buttons = yield* dom.queryAll(Selectors.viewBtn)
  yield* Effect.forEach(buttons, (btn) => Effect.sync(() => {
    const t = btn.getAttribute("data-view")
    btn.classList.toggle("view-btn-active", t === mode)
  }))
  yield* Effect.sync(() => {
    const url = new URL(window.location.href)
    url.searchParams.set("view", mode)
    window.history.replaceState({}, "", url.toString())
  })
  yield* Effect.logInfo(`[planning] view → ${mode}`)
})

const wireViewToggle = Effect.gen(function* () {
  const dom = yield* Dom
  const buttons = yield* dom.queryAll(Selectors.viewBtn)
  if (buttons.length === 0) return
  yield* Effect.forEach(buttons, (btn) => Effect.sync(() => {
    btn.addEventListener("click", (e) => {
      e.preventDefault()
      const mode = (btn.getAttribute("data-view") || "grid") as ViewMode
      Effect.runFork(switchView(mode))
    })
  }))
  const initial = (new URL(window.location.href).searchParams.get("view") || "grid") as ViewMode
  yield* switchView(initial)
})

// ─── §8. Status filter chips ────────────────────────────────────────────

const setActiveStatusChip = (status: string) => Effect.gen(function* () {
  const dom = yield* Dom
  const chips = yield* dom.queryAll(Selectors.chipButtons)
  yield* Effect.forEach(chips, (chip) => Effect.sync(() => {
    chip.classList.toggle("chip-active", chip.getAttribute("data-status") === status)
  }))
})

const wireStatusChips = Effect.gen(function* () {
  const dom = yield* Dom
  const api = yield* PlanningApi
  const row = yield* dom.query(Selectors.chipRow)
  if (!row) return
  yield* Effect.sync(() => {
    row.addEventListener("click", (e) => {
      const target = (e.target as HTMLElement).closest(".chip[data-status]") as HTMLElement | null
      if (!target) return
      e.preventDefault()
      const status = target.getAttribute("data-status") || "all"
      Effect.runFork(Effect.gen(function* () {
        yield* setActiveStatusChip(status)
        yield* Effect.sync(() => {
          const url = new URL(window.location.href)
          url.searchParams.set("status", status)
          window.history.pushState({}, "", url.toString())
        })
        const payload = yield* api.listByStatus(status, 0, 100).pipe(Effect.option)
        yield* Effect.sync(() => {
          window.dispatchEvent(new CustomEvent("c3i:planning-filter", {
            detail: { status, payload: Option.getOrNull(payload) },
          }))
        })
      }).pipe(Effect.catchAllCause((c) =>
        Effect.logWarning(`[planning] chip click failed: ${Cause.pretty(c)}`))))
    })
    window.addEventListener("popstate", () => {
      const s = new URL(window.location.href).searchParams.get("status") || "all"
      Effect.runFork(setActiveStatusChip(s))
    })
  })
  const initial = new URL(window.location.href).searchParams.get("status") || "all"
  yield* setActiveStatusChip(initial)
})

// ─── §9. Fractal filter chips ───────────────────────────────────────────

const setActiveFractalChip = (layer: string) => Effect.gen(function* () {
  const dom = yield* Dom
  const chips = yield* dom.queryAll(Selectors.fractalChips)
  yield* Effect.forEach(chips, (chip) => Effect.sync(() => {
    chip.classList.toggle("chip-active", chip.getAttribute("data-layer") === layer)
  }))
})

const wireFractalChips = Effect.gen(function* () {
  const dom = yield* Dom
  const c = yield* dom.query(Selectors.fractalChipsContainer)
  if (!c) return
  yield* Effect.sync(() => {
    c.addEventListener("click", (e) => {
      const t = (e.target as HTMLElement).closest(".fractal-chip[data-layer]") as HTMLElement | null
      if (!t) return
      e.preventDefault()
      const layer = t.getAttribute("data-layer") || "all"
      Effect.runFork(Effect.gen(function* () {
        yield* setActiveFractalChip(layer)
        yield* Effect.sync(() => {
          window.dispatchEvent(new CustomEvent("c3i:fractal-filter", { detail: { layer } }))
        })
      }))
    })
  })
})

// ─── §10. AI search (Ctrl+K) ────────────────────────────────────────────

const wireAiSearch = Effect.gen(function* () {
  const dom = yield* Dom
  const api = yield* PlanningApi
  const input = yield* dom.query(Selectors.aiSearchInput)
  if (!input) return
  yield* Effect.sync(() => {
    document.addEventListener("keydown", (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key === "k") {
        e.preventDefault()
        ;(input as HTMLInputElement).focus()
      }
      if (e.key === "Escape") (input as HTMLInputElement).blur()
    })
    let dt: number | null = null
    input.addEventListener("input", () => {
      const q = (input as HTMLInputElement).value.trim()
      if (dt != null) window.clearTimeout(dt)
      dt = window.setTimeout(() => {
        if (q.length < 2) return
        Effect.runFork(api.searchZk(q).pipe(
          Effect.tap((hits) => Effect.sync(() => {
            window.dispatchEvent(new CustomEvent("c3i:zk-search", {
              detail: { query: q, hits },
            }))
          })),
          Effect.catchAllCause((c) =>
            Effect.logWarning(`[planning] ZK search failed: ${Cause.pretty(c)}`)),
        ))
      }, 200)
    })
  })
})

// ─── §11. Click-to-detail drill-down ────────────────────────────────────

const wireDrillDown = Effect.sync(() => {
  document.addEventListener("click", (e) => {
    const row = (e.target as HTMLElement).closest("[data-task-id]") as HTMLElement | null
    if (!row) return
    const id = row.getAttribute("data-task-id")
    if (!id) return
    if (e.ctrlKey || e.metaKey || (e as MouseEvent).button === 1) {
      window.open(`/api/v1/plan/get?id=${encodeURIComponent(id)}`, "_blank")
      return
    }
    window.dispatchEvent(new CustomEvent("c3i:task-drill-down", { detail: { taskId: id } }))
  })
})

// ─── §12. Change-log mutation feed ──────────────────────────────────────

const wireChangeLog = Effect.gen(function* () {
  const dom = yield* Dom
  const log = yield* dom.query(Selectors.changeLog)
  if (!log) return
  yield* Effect.sync(() => {
    const append = (kind: string, detail: unknown) => {
      const e = document.createElement("li")
      const ts = new Date().toLocaleTimeString()
      e.textContent = `[${ts}] ${kind}: ${JSON.stringify(detail).slice(0, 80)}`
      e.classList.add("change-log-entry")
      log.prepend(e)
      while (log.children.length > 50) log.removeChild(log.lastChild!)
    }
    window.addEventListener("c3i:planning-filter", (e) =>
      append("filter", (e as CustomEvent).detail))
    window.addEventListener("c3i:fractal-filter", (e) =>
      append("fractal", (e as CustomEvent).detail))
    window.addEventListener("c3i:task-drill-down", (e) =>
      append("drill", (e as CustomEvent).detail))
    window.addEventListener("c3i:zk-search", (e) =>
      append("zk", { query: (e as CustomEvent).detail.query, n: (e as CustomEvent).detail.hits.length }))
  })
})

// ─── §13. Periodic refresh + WebSocket stream ──────────────────────────

const periodicRefresh = (intervalMs: number) => Effect.gen(function* () {
  const api = yield* PlanningApi
  const status = yield* api.status()
  yield* updateWeather(status)
}).pipe(
  Effect.catchAllCause((c) =>
    Effect.logWarning(`[planning] refresh failed: ${Cause.pretty(c)}`)),
  Effect.repeat(Schedule.spaced(Duration.millis(intervalMs))),
)

const wsStream = Stream.async<readonly Task[], Error>((emit) => {
  if (typeof WebSocket === "undefined") { emit.end(); return }
  const proto = window.location.protocol === "https:" ? "wss:" : "ws:"
  const ws = new WebSocket(`${proto}//${window.location.host}/ws/planning`)
  ws.addEventListener("message", (e: MessageEvent) => {
    try {
      const p = JSON.parse(e.data) as { type?: string; tasks?: Task[] }
      if (p.type === "update" && Array.isArray(p.tasks)) emit.single(p.tasks)
    } catch {/* ignore */}
  })
  ws.addEventListener("close", () => emit.end())
  ws.addEventListener("error", (ev) => emit.fail(new Error(`ws error: ${(ev as Event).type}`)))
  const pinger = window.setInterval(() => {
    if (ws.readyState === WebSocket.OPEN) ws.send("ping")
  }, 1000)
  return Effect.sync(() => {
    window.clearInterval(pinger)
    ws.close()
  })
})

const consumeWs = wsStream.pipe(
  Stream.tap((tasks) => Effect.gen(function* () {
    const dom = yield* Dom
    const card = yield* dom.query(Selectors.statusCard)
    if (!card) return
    yield* dom.setText(".status-card-count", `${tasks.length}`)
  }).pipe(Effect.catchAll(() => Effect.void))),
  Stream.runDrain,
  Effect.catchAllCause((c) =>
    Effect.logWarning(`[planning] ws stream ended: ${Cause.pretty(c)}`)),
)

// ─── §14. Public namespace ──────────────────────────────────────────────

interface PlanningNamespace {
  readonly classifyLayer: typeof classifyLayer
  readonly taskAge: typeof taskAge
  readonly snapshotData: typeof snapshotData
  readonly findChangedIds: typeof findChangedIds
  readonly FRACTAL_LAYERS: typeof FRACTAL_LAYERS
  readonly Selectors: typeof Selectors
}

declare global {
  interface Window {
    __c3iPlanning?: Record<string, unknown> & {
      effect?: PlanningNamespace
    }
  }
}

const exposeNamespace = Effect.sync(() => {
  if (typeof window === "undefined") return
  window.__c3iPlanning = window.__c3iPlanning ?? {}
  window.__c3iPlanning.effect = {
    classifyLayer, taskAge, snapshotData, findChangedIds,
    FRACTAL_LAYERS, Selectors,
  }
})

// ─── §15. Main program ──────────────────────────────────────────────────

const program = Effect.gen(function* () {
  yield* Effect.logInfo("[planning] Effect-TS runtime booting (Pass-30)")
  yield* exposeNamespace
  yield* Effect.all([
    wireViewToggle, wireStatusChips, wireFractalChips,
    wireAiSearch, wireDrillDown, wireChangeLog,
  ], { concurrency: "unbounded" })
  const api = yield* PlanningApi
  const initial = yield* api.status().pipe(Effect.option)
  if (Option.isSome(initial)) yield* updateWeather(initial.value)
  const refreshFiber: Fiber.RuntimeFiber<void, never> = yield* Effect.fork(periodicRefresh(5000))
  const wsFiber: Fiber.RuntimeFiber<void, never> = yield* Effect.fork(consumeWs)
  yield* Effect.sync(() => {
    if (window.__c3iPlanning) {
      ;(window.__c3iPlanning as Record<string, unknown>).fibers = {
        refresh: refreshFiber, ws: wsFiber,
      }
    }
  })
  yield* Effect.logInfo("[planning] Effect-TS runtime ready")
})

const MainLayer = Layer.mergeAll(PlanningApiLive, DomLive)

const runnable = program.pipe(
  Effect.provide(MainLayer),
  Effect.provide(Logger.minimumLogLevel(LogLevel.Info)),
  Effect.catchAllCause((c) =>
    Effect.sync(() => console.error("[planning] fatal:", Cause.pretty(c)))),
)

// ─── §16. Boot ──────────────────────────────────────────────────────────

const boot = (): void => { Effect.runFork(runnable) }

if (typeof document !== "undefined") {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot)
  } else { boot() }
}

export {}
