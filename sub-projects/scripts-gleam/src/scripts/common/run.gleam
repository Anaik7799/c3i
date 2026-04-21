//// scripts/common/run — URN-keyed subprocess lifecycle publisher
////
//// SC-SCHED-TELE-003. Every gleam script that performs a unit-of-work
//// which should be visible to sa-plan + Pi + cepaf-gleam uses this module
//// to announce start/progress/complete events on the canonical topic:
////
////     indrajaal/l4/sched/run/<run_id>/<event>
////
//// Matches the taxonomy in docs/architecture/JOB_TELEMETRY_NAMING_TAXONOMY.md

import gleam/int
import gleam/string
import scripts/common/nif
import scripts/common/zenoh

pub type RunCtx {
  RunCtx(
    plan_id: String,
    task_id: String,
    run_id: String,
    source: String,
    worker: String,
  )
}

/// Build a new RunCtx for a script. `run_id` is derived from a monotonic
/// nanosecond timestamp + a short hex tag so two runs in the same script
/// cannot collide.
pub fn new(plan_id: String, task_id: String, source: String, worker: String) -> RunCtx {
  let ns = int.to_string(nif.now_nanos())
  let short = nif.sha256_hex(ns) |> string.slice(0, 8)
  RunCtx(
    plan_id: plan_id,
    task_id: task_id,
    run_id: ns <> "-" <> short,
    source: source,
    worker: worker,
  )
}

fn run_key(ctx: RunCtx, event: String) -> String {
  "indrajaal/l4/sched/run/" <> ctx.run_id <> "/" <> event
}

fn plan_key(ctx: RunCtx, event: String) -> String {
  "indrajaal/l4/sched/plan/" <> ctx.plan_id <> "/" <> event
}

fn task_key(ctx: RunCtx, event: String) -> String {
  "indrajaal/l4/sched/task/" <> ctx.task_id <> "/" <> event
}

fn envelope(ctx: RunCtx, event: String, extras: String) -> String {
  // Minimal JSON envelope matching the Rust side:
  //   { at, source, urn, id?, run_id, task_id, plan_id, event, <extras> }
  let urn =
    "urn:c3i:run:" <> ctx.task_id <> ":" <> ctx.run_id
  let base =
    "{\"source\":\""
    <> ctx.source
    <> "\",\"urn\":\""
    <> urn
    <> "\",\"plan_id\":\""
    <> ctx.plan_id
    <> "\",\"task_id\":\""
    <> ctx.task_id
    <> "\",\"run_id\":\""
    <> ctx.run_id
    <> "\",\"worker\":\""
    <> ctx.worker
    <> "\",\"event\":\""
    <> event
    <> "\""
  case extras {
    "" -> base <> "}"
    _ -> base <> "," <> extras <> "}"
  }
}

/// Fire a `started` event on run + mirror on plan and task.
pub fn started(ctx: RunCtx) -> Nil {
  let p = envelope(ctx, "started", "")
  let _ = zenoh.put(run_key(ctx, "started"), p)
  let _ = zenoh.put(plan_key(ctx, "started"), p)
  let _ = zenoh.put(task_key(ctx, "started"), p)
  Nil
}

/// Fire a `progress` event. `pct` is 0..100. `phase` is a short label.
pub fn progress(ctx: RunCtx, pct: Int, phase: String, detail: String) -> Nil {
  let extras =
    "\"pct\":" <> int.to_string(pct)
    <> ",\"phase\":\"" <> phase <> "\""
    <> ",\"detail\":\"" <> escape(detail) <> "\""
  let p = envelope(ctx, "progress", extras)
  let _ = zenoh.put(run_key(ctx, "progress"), p)
  Nil
}

/// Fire a terminal `completed` event.
pub fn completed(ctx: RunCtx, summary: String) -> Nil {
  let extras = "\"summary\":\"" <> escape(summary) <> "\""
  let p = envelope(ctx, "completed", extras)
  let _ = zenoh.put(run_key(ctx, "completed"), p)
  let _ = zenoh.put(plan_key(ctx, "completed"), p)
  let _ = zenoh.put(task_key(ctx, "completed"), p)
  Nil
}

/// Fire a terminal `failed` event.
pub fn failed(ctx: RunCtx, err: String) -> Nil {
  let extras = "\"error\":\"" <> escape(err) <> "\""
  let p = envelope(ctx, "failed", extras)
  let _ = zenoh.put(run_key(ctx, "failed"), p)
  let _ = zenoh.put(plan_key(ctx, "failed"), p)
  let _ = zenoh.put(task_key(ctx, "failed"), p)
  Nil
}

fn escape(s: String) -> String {
  // Extremely minimal JSON string escaping — caller's responsibility to
  // avoid control chars.
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", " ")
}
