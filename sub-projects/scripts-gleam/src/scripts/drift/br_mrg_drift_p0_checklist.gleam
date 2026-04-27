//// scripts/drift/br_mrg_drift_p0_checklist — BR-MRG + DRIFT P0 execution orchestrator.
////
//// SC-SCRIPT-GLEAM-001: gleam-only script.
//// SC-SCHED-TELE-003: publishes run lifecycle on indrajaal/l4/sched/run/**.
////
//// Purpose:
////   1) show the criticality/FMEA-prioritized checklist,
////   2) apply sa-plan status transitions for scoped tasks,
////   3) run baseline gates without shell wrappers,
////   4) support one-step advance (in_progress -> completed with optional gates).
////
//// Usage:
////   gleam run -m scripts/drift/br_mrg_drift_p0_checklist
////   gleam run -m scripts/drift/br_mrg_drift_p0_checklist -- --action transition --task-id 116442037278208911 --to in_progress --sync
////   gleam run -m scripts/drift/br_mrg_drift_p0_checklist -- --action gate-baseline
////   gleam run -m scripts/drift/br_mrg_drift_p0_checklist -- --action advance --task-id 116441945108635034 --run-gates --sync

import argv
import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import scripts/common/args as cargs
import scripts/common/fractal
import scripts/common/fsx
import scripts/common/logx
import scripts/common/manifest as mfst
import scripts/common/paths
import scripts/common/run
import scripts/common/saplan

const scope = "drift/br_mrg_drift_p0_checklist"

pub type Step {
  Step(
    order: Int,
    task_id: String,
    code: String,
    title: String,
    tier: String,
    rpn: Int,
    wave: String,
  )
}

pub type GateCheck {
  GateCheck(name: String, rc: Int, tail: String)
}

pub fn manifest() -> mfst.Manifest {
  mfst.Manifest(
    name: "drift/br_mrg_drift_p0_checklist",
    category: mfst.Drift,
    fractal_layer: fractal.L4,
    summary: "Criticality/FMEA execution checklist + sa-plan status transitions for BR-MRG + DRIFT P0 tasks.",
    inputs: [
      mfst.FlagSpec("action", "show | transition | gate-baseline | advance", "show", False),
      mfst.FlagSpec("task-id", "Target sa-plan task id (required for transition/advance)", "", False),
      mfst.FlagSpec("to", "transition target status: pending|in_progress|completed", "", False),
      mfst.FlagSpec("plan-id", "Logical plan id for run telemetry URN", "BR-MRG-DRIFT-P0", False),
      mfst.FlagSpec("run-task-id", "Fallback task id used for run telemetry URN when --task-id omitted", "116442037302915327", False),
    ],
    outputs_schema: "{action,ok,summary,steps:[{id,code,tier,rpn,wave}],gates:[{name,rc}],applied:[{id,to,rc}]}",
    retention_days: 30,
    auth_level: mfst.L1Trusted,
    sc_id: "SC-BR-MRG-DRIFT-PLAN-001",
  )
}

fn scoped_steps() -> List(Step) {
  [
    Step(1, "116442037278208911", "DRIFT-P0-GOV", "Governance drift remediation (rules/agents/skills/hooks parity)", "C0", 256, "A"),
    Step(2, "116442037281371869", "DRIFT-P0-CORE", "Core-code drift remediation (planning_daemon cohesion)", "C0", 252, "A"),
    Step(3, "116441945105813869", "BR-MRG-002", "Guardrail merge policy (ff-only, no-force-push, rollback tags)", "C1", 216, "B"),
    Step(4, "116441945101022483", "BR-MRG-001", "Branch convergence inventory (ahead/behind + risk tags)", "C1", 224, "B"),
    Step(5, "116441945108635034", "BR-MRG-003", "Low-delta tranche merges (ahead<=3) with gates", "C0", 240, "C"),
    Step(6, "116441945114064601", "BR-MRG-006", "Dual-repo sync after each tranche", "C2", 192, "C"),
    Step(7, "116441945111990807", "BR-MRG-005", "High-value salvage from SOP/TDG/STAMP", "C0", 240, "C"),
    Step(8, "116441953155429167", "BR-MRG-009", "T2 salvage batch-A", "C0", 240, "C"),
    Step(9, "116441953157197217", "BR-MRG-010", "T3 legacy extraction batch-B", "C1", 210, "C"),
    Step(10, "116442037302915327", "DRIFT-CLOSE", "Final KPI closure (CSI/Lyapunov thresholds)", "C3", 140, "D"),
  ]
}

pub fn main() -> Nil {
  let a = cargs.parse(argv.load().arguments)
  let action = cargs.flag(a, "action", "show")
  let task_id = cargs.flag(a, "task-id", "")
  let to = cargs.flag(a, "to", "")
  let sync = cargs.bool(a, "sync")
  let run_gates = cargs.bool(a, "run-gates")
  let plan_id = cargs.flag(a, "plan-id", "BR-MRG-DRIFT-P0")
  let run_task_id =
    case task_id {
      "" -> cargs.flag(a, "run-task-id", "116442037302915327")
      _ -> task_id
    }

  let stamp = logx.stamp()
  let ctx = run.new(plan_id, run_task_id, "scripts-gleam", scope)

  run.started(ctx)
  run.progress(ctx, 5, "dispatch", "action=" <> action)

  let res =
    case action {
      "show" -> do_show(stamp)
      "transition" -> do_transition(stamp, task_id, to, sync)
      "gate-baseline" -> do_gate_baseline(stamp)
      "advance" -> do_advance(stamp, task_id, sync, run_gates)
      _ -> Error("unknown --action: " <> action)
    }

  case res {
    Ok(summary) -> {
      run.progress(ctx, 100, "done", summary)
      run.completed(ctx, summary)
      logx.info(scope, "done " <> summary)
    }
    Error(err) -> {
      run.failed(ctx, err)
      logx.error(scope, err)
      panic as err
    }
  }
}

fn do_show(stamp: String) -> Result(String, String) {
  let steps = scoped_steps()
  io.println("══ BR-MRG + DRIFT P0 criticality/FMEA plan ══")
  list.each(steps, fn(s) {
    io.println(
      int.to_string(s.order)
        <> ". "
        <> s.task_id
        <> " ["
        <> s.code
        <> "] tier="
        <> s.tier
        <> " rpn="
        <> int.to_string(s.rpn)
        <> " wave="
        <> s.wave,
    )
  })

  let md = checklist_markdown(steps)
  use _ <- result.try(write_outputs(stamp, "show", True, "rendered checklist", steps, [], [], md))
  Ok("show ok")
}

fn do_transition(
  stamp: String,
  task_id: String,
  to: String,
  sync: Bool,
) -> Result(String, String) {
  use _ <- result.try(require_nonempty("--task-id", task_id))
  use _ <- result.try(require_valid_status(to))
  use _ <- result.try(require_scoped(task_id))

  let upd = saplan.update_task(task_id, to)
  let applied = [#(task_id, to, upd.rc)]

  case upd.rc == 0 {
    False -> {
      let msg = "sa-plan update failed: " <> trim(upd.stdout)
      case write_outputs(stamp, "transition", False, "sa-plan update failed", scoped_steps(), [], applied, "") {
        Ok(_) -> Error(msg)
        Error(e) -> Error(e)
      }
    }
    True -> {
      use _ <- result.try(sync_if(sync))
      use _ <- result.try(write_outputs(stamp, "transition", True, "updated " <> task_id <> " -> " <> to, scoped_steps(), [], applied, ""))
      Ok("transition ok")
    }
  }
}

fn do_gate_baseline(stamp: String) -> Result(String, String) {
  let repo = paths.repo_root()
  let c3i = repo <> "/sub-projects/c3i"
  let cepaf = repo <> "/lib/cepaf_gleam"
  let pi = repo <> "/sub-projects/pi-mono"
  let scripts = repo <> "/sub-projects/scripts-gleam"

  let checks = [
    run_check("cargo build", "cargo", ["build"], c3i),
    run_check("gleam build (cepaf)", "gleam", ["build"], cepaf),
    run_check("gleam test (cepaf)", "gleam", ["test"], cepaf),
    run_check("npm run build (pi-mono)", "npm", ["run", "build"], pi),
    run_check(
      "formal_check",
      "gleam",
      [
        "run", "-m", "scripts/verify/formal_check", "--", "--apalache-length", "5", "--max-steps", "50",
      ],
      scripts,
    ),
  ]

  let ok = all_ok(checks)
  let summary =
    case ok {
      True -> "baseline gates PASS"
      False -> "baseline gates FAIL"
    }

  use _ <- result.try(write_outputs(stamp, "gate-baseline", ok, summary, scoped_steps(), checks, [], ""))
  case ok {
    True -> Ok(summary)
    False -> Error(summary)
  }
}

fn do_advance(
  stamp: String,
  task_id: String,
  sync: Bool,
  run_gates: Bool,
) -> Result(String, String) {
  use _ <- result.try(require_nonempty("--task-id", task_id))
  use _ <- result.try(require_scoped(task_id))

  let start = saplan.update_task(task_id, "in_progress")
  let start_applied = [#(task_id, "in_progress", start.rc)]

  case start.rc == 0 {
    False -> {
      case write_outputs(stamp, "advance", False, "failed to set in_progress", scoped_steps(), [], start_applied, "") {
        Ok(_) -> Error("failed to set in_progress")
        Error(e) -> Error(e)
      }
    }
    True -> {
      use _ <- result.try(sync_if(sync))

      let gate_result =
        case run_gates {
          True -> do_gate_baseline(stamp)
          False -> Ok("gates skipped")
        }

      case gate_result {
        Error(e) -> {
          let rollback = saplan.update_task(task_id, "pending")
          let applied = [#(task_id, "in_progress", start.rc), #(task_id, "pending", rollback.rc)]
          let _ = sync_if(sync)
          case write_outputs(stamp, "advance", False, "gate failed, rolled back to pending", scoped_steps(), [], applied, "") {
            Ok(_) -> Error("advance failed: " <> e)
            Error(w) -> Error(w)
          }
        }
        Ok(_) -> {
          let done = saplan.update_task(task_id, "completed")
          let applied = [
            #(task_id, "in_progress", start.rc),
            #(task_id, "completed", done.rc),
          ]
          case done.rc == 0 {
            False -> {
              case write_outputs(stamp, "advance", False, "failed to set completed", scoped_steps(), [], applied, "") {
                Ok(_) -> Error("failed to set completed")
                Error(e) -> Error(e)
              }
            }
            True -> {
              use _ <- result.try(sync_if(sync))
              use _ <- result.try(write_outputs(stamp, "advance", True, "advance completed", scoped_steps(), [], applied, ""))
              Ok("advance completed")
            }
          }
        }
      }
    }
  }
}

fn run_check(name: String, cmd: String, args: List(String), cwd: String) -> GateCheck {
  let #(out, rc) = sh_run_capture_in(cmd, args, cwd)
  let tail = last_n_lines(out, 10)
  logx.info(scope, "gate " <> name <> " rc=" <> int.to_string(rc))
  case rc == 0 {
    True -> logx.info(scope, "  PASS " <> name)
    False -> logx.error(scope, "  FAIL " <> name <> "\n" <> tail)
  }
  GateCheck(name:, rc:, tail:)
}

fn all_ok(xs: List(GateCheck)) -> Bool {
  list.fold(xs, True, fn(acc, x) { acc && x.rc == 0 })
}

fn sync_if(sync: Bool) -> Result(Nil, String) {
  case sync {
    False -> Ok(Nil)
    True -> {
      let s = saplan.invoke(["sync"])
      case s.rc == 0 {
        True -> Ok(Nil)
        False -> Error("sa-plan sync failed: " <> trim(s.stdout))
      }
    }
  }
}

fn require_nonempty(name: String, v: String) -> Result(Nil, String) {
  case v == "" {
    True -> Error("missing " <> name)
    False -> Ok(Nil)
  }
}

fn require_valid_status(v: String) -> Result(Nil, String) {
  case v == "pending" || v == "in_progress" || v == "completed" {
    True -> Ok(Nil)
    False -> Error("invalid --to status: " <> v)
  }
}

fn require_scoped(task_id: String) -> Result(Nil, String) {
  case list.any(scoped_steps(), fn(s) { s.task_id == task_id }) {
    True -> Ok(Nil)
    False -> Error("task not in BR-MRG/DRIFT P0 scope: " <> task_id)
  }
}

fn checklist_markdown(steps: List(Step)) -> String {
  "# BR-MRG + DRIFT P0 Criticality/FMEA Checklist\n\n"
  <> "Execution order (criticality-first):\n\n"
  <> string.join(list.map(steps, fn(s) {
    "- [ ] "
      <> int.to_string(s.order)
      <> ". ``"
      <> s.task_id
      <> "`` ["
      <> s.code
      <> "] tier="
      <> s.tier
      <> " rpn="
      <> int.to_string(s.rpn)
      <> " wave="
      <> s.wave
  }), "\n")
  <> "\n\n## Ready-to-run transitions (gleam-only)\n\n"
  <> "```bash\n"
  <> "cd /home/an/dev/ver/c3i/sub-projects/scripts-gleam\n"
  <> "gleam run -m scripts/drift/br_mrg_drift_p0_checklist -- --action show\n"
  <> "gleam run -m scripts/drift/br_mrg_drift_p0_checklist -- --action gate-baseline\n"
  <> "gleam run -m scripts/drift/br_mrg_drift_p0_checklist -- --action transition --task-id <id> --to in_progress --sync\n"
  <> "gleam run -m scripts/drift/br_mrg_drift_p0_checklist -- --action transition --task-id <id> --to completed --sync\n"
  <> "gleam run -m scripts/drift/br_mrg_drift_p0_checklist -- --action transition --task-id <id> --to pending --sync\n"
  <> "gleam run -m scripts/drift/br_mrg_drift_p0_checklist -- --action advance --task-id <id> --run-gates --sync\n"
  <> "```\n"
}

fn write_outputs(
  stamp: String,
  action: String,
  ok: Bool,
  summary: String,
  steps: List(Step),
  gates: List(GateCheck),
  applied: List(#(String, String, Int)),
  checklist_md: String,
) -> Result(Nil, String) {
  case fsx.run_dir("drift", "br_mrg_drift_p0_checklist", stamp) {
    Error(e) -> Error(e)
    Ok(dir) -> {
      let body =
        "{"
        <> "\"stamp\":\"" <> stamp <> "\""
        <> ",\"action\":\"" <> action <> "\""
        <> ",\"ok\":" <> bool_json(ok)
        <> ",\"summary\":\"" <> esc(summary) <> "\""
        <> ",\"steps\":[" <> string.join(list.map(steps, step_json), ",") <> "]"
        <> ",\"gates\":[" <> string.join(list.map(gates, gate_json), ",") <> "]"
        <> ",\"applied\":[" <> string.join(list.map(applied, applied_json), ",") <> "]"
        <> "}"

      use _ <- result.try(fsx.write_file(dir, "result.json", body))
      case checklist_md == "" {
        True -> Ok(Nil)
        False -> fsx.write_file(dir, "checklist.md", checklist_md)
      }
    }
  }
}

fn step_json(s: Step) -> String {
  "{"
    <> "\"order\":" <> int.to_string(s.order)
    <> ",\"id\":\"" <> s.task_id <> "\""
    <> ",\"code\":\"" <> s.code <> "\""
    <> ",\"tier\":\"" <> s.tier <> "\""
    <> ",\"rpn\":" <> int.to_string(s.rpn)
    <> ",\"wave\":\"" <> s.wave <> "\""
    <> "}"
}

fn gate_json(g: GateCheck) -> String {
  "{"
    <> "\"name\":\"" <> esc(g.name) <> "\""
    <> ",\"rc\":" <> int.to_string(g.rc)
    <> ",\"tail\":\"" <> esc(g.tail) <> "\""
    <> "}"
}

fn applied_json(a: #(String, String, Int)) -> String {
  let #(id, to, rc) = a
  "{"
    <> "\"id\":\"" <> id <> "\""
    <> ",\"to\":\"" <> to <> "\""
    <> ",\"rc\":" <> int.to_string(rc)
    <> "}"
}

fn bool_json(b: Bool) -> String {
  case b {
    True -> "true"
    False -> "false"
  }
}

fn esc(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", " ")
}

fn trim(s: String) -> String {
  s |> string.replace("\n", " ")
}

@external(erlang, "scripts_sh_ffi", "run_capture_in")
fn sh_run_capture_raw(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
  cwd: charlist.Charlist,
) -> #(charlist.Charlist, Int)

fn sh_run_capture_in(
  cmd: String,
  args: List(String),
  cwd: String,
) -> #(String, Int) {
  let args_cl = list.map(args, charlist.from_string)
  let #(out_cl, rc) =
    sh_run_capture_raw(
      charlist.from_string(cmd),
      args_cl,
      charlist.from_string(cwd),
    )
  #(charlist.to_string(out_cl), rc)
}

fn last_n_lines(s: String, n: Int) -> String {
  s
  |> string.split("\n")
  |> list.reverse
  |> take(n)
  |> list.reverse
  |> string.join("\n")
}

fn take(xs: List(a), n: Int) -> List(a) {
  case n <= 0 {
    True -> []
    False ->
      case xs {
        [] -> []
        [h, ..t] -> [h, ..take(t, n - 1)]
      }
  }
}
