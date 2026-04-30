//// scripts/verify/cpig_validator — CPIG drift detector.
////
//// Reads the CPIG matrix JSON, prints system_score_pct, and emits
//// sa-plan task creation hints for any gates below score=1.
//// Exits 0 always — drift detection is informational, not a hard gate.
////
//// Usage:
////   gleam run -m scripts/verify/cpig_validator
////
//// Scheduled hourly via sa-plan-daemon workflow_schedules.

import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import simplifile

const matrix_path: String = "/home/an/dev/ver/c3i/docs/journal/task-116480247290237220/cpig-matrix.json"

const gate_names: List(String) = [
  "formal_spec",
  "wiring_guard",
  "sa_plan_tracking",
  "zk_ingestion",
  "email_closure",
]

pub fn main() -> Nil {
  io.println("══ CPIG Validator (SC-FRAC-RRF) ══")
  io.println("matrix: " <> matrix_path)

  case simplifile.read(matrix_path) {
    Error(_) -> {
      io.println("✗ unable to read CPIG matrix; treating as drift")
      io.println(
        "hint: sa-plan add --priority P1 'Restore CPIG matrix at "
        <> matrix_path
        <> "'",
      )
      Nil
    }
    Ok(body) ->
      case parse(body) {
        Error(e) -> {
          io.println("✗ unable to parse CPIG matrix: " <> e)
          Nil
        }
        Ok(#(score, missing)) -> emit_report(score, missing)
      }
  }
}

type GateMiss {
  GateMiss(subsystem: String, gate: String, score: Int)
}

fn parse(body: String) -> Result(#(Int, List(GateMiss)), String) {
  let gate_decoder = {
    use score <- decode.field("score", decode.int)
    decode.success(score)
  }
  let gates_decoder = {
    use formal <- decode.optional_field("formal_spec", 1, gate_decoder)
    use wiring <- decode.optional_field("wiring_guard", 1, gate_decoder)
    use saplan <- decode.optional_field("sa_plan_tracking", 1, gate_decoder)
    use zk <- decode.optional_field("zk_ingestion", 1, gate_decoder)
    use email <- decode.optional_field("email_closure", 1, gate_decoder)
    decode.success([formal, wiring, saplan, zk, email])
  }
  let subsystem_decoder = {
    use id <- decode.field("id", decode.string)
    use gates_field <- decode.field("gates", gates_decoder)
    decode.success(#(id, gates_field))
  }
  let top_decoder = {
    use score <- decode.field("system_score_pct", decode.int)
    use subs <- decode.field("subsystems", decode.list(subsystem_decoder))
    decode.success(#(score, subs))
  }
  use #(score, subs) <- result.try(
    json.parse(body, top_decoder)
    |> result.map_error(fn(_) { "json parse failed" }),
  )

  let missing =
    list.flat_map(subs, fn(pair) {
      let #(id, scores) = pair
      let zipped = list.zip(gate_names, scores)
      list.filter_map(zipped, fn(g) {
        let #(name, s) = g
        case s < 1 {
          True -> Ok(GateMiss(subsystem: id, gate: name, score: s))
          False -> Error(Nil)
        }
      })
    })

  Ok(#(score, missing))
}

fn emit_report(score_pct: Int, missing: List(GateMiss)) -> Nil {
  io.println("system_score_pct: " <> int.to_string(score_pct))
  case score_pct >= 100 {
    True -> {
      io.println("✓ CPIG at 100% — no drift")
      Nil
    }
    False -> {
      io.println(
        "⚠ CPIG below 100% — "
        <> int.to_string(list.length(missing))
        <> " gates missing:",
      )
      list.each(missing, fn(m) {
        io.println(
          "  ✗ "
          <> m.subsystem
          <> "/"
          <> m.gate
          <> " (score="
          <> int.to_string(m.score)
          <> ")",
        )
        io.println(
          "    hint: sa-plan add --priority P1 'CPIG gate: "
          <> m.subsystem
          <> "/"
          <> m.gate
          <> " — bring score to 1'",
        )
      })
      Nil
    }
  }
}
